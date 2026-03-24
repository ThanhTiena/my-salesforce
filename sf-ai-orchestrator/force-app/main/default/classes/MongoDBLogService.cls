/**
 * MongoDBLogService
 *
 * Writes workflow execution logs to MongoDB via the Vercel proxy API and reads
 * them back for the Execution Monitor dashboard.
 *
 * Architecture — the proxy exposes a thin REST layer over MongoDB Atlas Data API:
 *   POST   /api/executions            — insert a new execution document
 *   PATCH  /api/executions/:id/status — update status / error
 *   PATCH  /api/executions/:id/steps  — push a new step sub-document
 *   PATCH  /api/executions/:id/steps/:stepExecId — update an existing step
 *   PATCH  /api/executions/:id/finalise — set completed_at, duration, tokens
 *   POST   /api/executions/query      — find documents (filter + projection)
 *   POST   /api/executions/aggregate  — run an aggregation pipeline
 *
 * Write safety:
 *   ASYNC_BEST_EFFORT (default) — failures are logged but never throw, so a
 *   MongoDB/Vercel error will never kill a workflow execution.
 *   SYNC_REQUIRED — failures re-throw MongoDBException (use for dev/testing).
 *
 * Config is loaded from AI_MongoDB_Config__mdt.Default.
 * If the record is absent or Is_Active__c = false, all methods no-op.
 *
 * @author  AI Orchestration Package
 * @version 3.0
 */
public with sharing class MongoDBLogService {

    public class MongoDBException extends Exception {}

    // ─── API paths ────────────────────────────────────────────────────────────

    private static final String PATH_EXECUTIONS           = '/api/executions';
    private static final String PATH_EXECUTIONS_QUERY     = '/api/executions/query';
    private static final String PATH_EXECUTIONS_AGGREGATE = '/api/executions/aggregate';

    // ─── Config ──────────────────────────────────────────────────────────────

    private static AI_MongoDB_Config__mdt CONFIG;
    private static Boolean CONFIG_LOADED = false;

    @TestVisible
    private static AI_MongoDB_Config__mdt getConfig() {
        if (!CONFIG_LOADED) {
            List<AI_MongoDB_Config__mdt> rows = [
                SELECT Named_Credential_API_Name__c, App_Id__c,
                       Data_Source__c, Database_Name__c, Executions_Collection__c,
                       Is_Active__c, Timeout_Seconds__c, Write_Mode__c, Org_Id__c
                FROM AI_MongoDB_Config__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            CONFIG        = rows.isEmpty() ? null : rows[0];
            CONFIG_LOADED = true;
        }
        return CONFIG;
    }

    @TestVisible
    private static void setConfig(AI_MongoDB_Config__mdt mockConfig) {
        CONFIG        = mockConfig;
        CONFIG_LOADED = true;
    }

    private static Boolean isActive() {
        AI_MongoDB_Config__mdt cfg = getConfig();
        return cfg != null && cfg.Is_Active__c;
    }

    private static Boolean isSyncRequired() {
        AI_MongoDB_Config__mdt cfg = getConfig();
        return cfg != null && cfg.Write_Mode__c == 'SYNC_REQUIRED';
    }

    private static Integer timeoutSec() {
        AI_MongoDB_Config__mdt cfg = getConfig();
        return (cfg != null && cfg.Timeout_Seconds__c != null)
            ? cfg.Timeout_Seconds__c.intValue()
            : 30;
    }

    private static String ncName() {
        return getConfig().Named_Credential_API_Name__c;
    }

    // ─── DTOs ─────────────────────────────────────────────────────────────────

    /**
     * Full execution document written to MongoDB on workflow start.
     * Mirrors the MongoDB collection schema.
     */
    public class ExecutionDocument {
        public String  sfExecutionId;       // Mongo_Execution_Id__c (24-char hex)
        public String  sfWorkflowId;
        public String  workflowName;
        public Integer workflowVersion;
        public String  sfOrgId;
        public String  status;              // PENDING | RUNNING | COMPLETED | FAILED | RETRYING
        public String  initiatedBy;
        public String  triggerRecordId;
        public String  triggerObject;
        public Long    startedAtEpochMs;
        public Integer retryCount;
        public List<StepDocument> steps;
        public Integer schemaVersion;
    }

    /**
     * Step sub-document embedded in the execution document.
     */
    public class StepDocument {
        public String  sfStepExecutionId;
        public String  sfStepId;
        public String  stepName;
        public String  stepType;
        public Integer stepOrder;
        public String  status;              // RUNNING | COMPLETED | FAILED
        public Integer retryAttempt;
        public String  providerUsed;
        public String  modelUsed;
        public String  promptSent;
        public String  rawResponse;
        public String  parsedOutput;
        public Integer tokensUsed;
        public Integer promptTokens;
        public Integer completionTokens;
        public Integer httpStatusCode;
        public Integer durationMs;
        public String  errorMessage;
    }

    /**
     * Flat summary row returned by getRecentExecutions().
     */
    public class ExecutionSummary {
        @AuraEnabled public String  sfExecutionId;
        @AuraEnabled public String  workflowName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  initiatedBy;
        @AuraEnabled public String  triggerRecordId;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public Integer retryCount;
        @AuraEnabled public Integer totalTokensUsed;
        @AuraEnabled public Decimal durationSeconds;
        @AuraEnabled public Long    startedAtEpochMs;
        @AuraEnabled public Long    completedAtEpochMs;
    }

    /**
     * Per-provider token usage row returned by getTokenUsageByProvider().
     */
    public class TokenUsageSummary {
        @AuraEnabled public String  providerName;
        @AuraEnabled public Integer totalTokens;
        @AuraEnabled public Integer executionCount;
    }

    /**
     * Aggregate dashboard metrics returned by getDashboardMetrics().
     */
    public class DashboardResult {
        @AuraEnabled public Integer totalExecutions  = 0;
        @AuraEnabled public Integer successCount     = 0;
        @AuraEnabled public Integer failedCount      = 0;
        @AuraEnabled public Integer runningCount     = 0;
        @AuraEnabled public Decimal avgDurationSeconds = 0;
        @AuraEnabled public Integer totalTokensUsed  = 0;
        @AuraEnabled public Decimal successRate      = 0;
    }

    /**
     * Per-step summary row returned by getStepExecutions().
     */
    public class StepSummary {
        @AuraEnabled public String  sfStepExecutionId;
        @AuraEnabled public String  stepName;
        @AuraEnabled public String  stepType;
        @AuraEnabled public Integer stepOrder;
        @AuraEnabled public String  status;
        @AuraEnabled public String  providerUsed;
        @AuraEnabled public String  modelUsed;
        @AuraEnabled public Integer tokensUsed;
        @AuraEnabled public Integer promptTokens;
        @AuraEnabled public Integer completionTokens;
        @AuraEnabled public Integer durationMs;
        @AuraEnabled public Integer httpStatusCode;
        @AuraEnabled public Integer retryAttempt;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public String  parsedOutput;
        @AuraEnabled public String  promptSent;
        @AuraEnabled public String  rawResponse;
    }

    /**
     * Full execution log row (with steps) returned by queryExecutionLogs().
     */
    public class ExecutionLogRow {
        @AuraEnabled public String  sfExecutionId;
        @AuraEnabled public String  workflowName;
        @AuraEnabled public Integer workflowVersion;
        @AuraEnabled public String  status;
        @AuraEnabled public String  initiatedBy;
        @AuraEnabled public String  triggerRecordId;
        @AuraEnabled public String  triggerObject;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public Integer retryCount;
        @AuraEnabled public Integer totalTokensUsed;
        @AuraEnabled public Decimal durationSeconds;
        @AuraEnabled public Long    startedAtEpochMs;
        @AuraEnabled public Long    completedAtEpochMs;
        @AuraEnabled public List<StepSummary> steps;
    }

    /**
     * Paged result wrapper returned by queryExecutionLogs().
     */
    public class LogPage {
        @AuraEnabled public List<ExecutionLogRow> rows;
        @AuraEnabled public Integer               totalCount;
        @AuraEnabled public Integer               pageSize;
        @AuraEnabled public Integer               pageNumber;
    }

    // ─── Write API ────────────────────────────────────────────────────────────

    /**
     * Inserts a new execution document.
     * POST /api/executions
     */
    public static void insertExecution(ExecutionDocument doc) {
        if (!isActive()) return;
        try {
            Map<String, Object> body = executionDocToMap(doc);
            HttpResponse resp = post(PATH_EXECUTIONS, body);
            if (resp.getStatusCode() != 201) {
                throw new MongoDBException('insertExecution HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
        } catch (Exception e) {
            handleError('insertExecution', e);
        }
    }

    /**
     * Updates status (and optionally errorMessage) on an existing execution.
     * PATCH /api/executions/:id/status
     */
    public static void updateExecutionStatus(String sfExecutionId, String status, String errorMessage) {
        if (!isActive()) return;
        try {
            Map<String, Object> body = new Map<String, Object>{
                'status' => status
            };
            if (errorMessage != null) body.put('errorMessage', errorMessage);
            HttpResponse resp = patch(PATH_EXECUTIONS + '/' + sfExecutionId + '/status', body);
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('updateExecutionStatus HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
        } catch (Exception e) {
            handleError('updateExecutionStatus', e);
        }
    }

    /**
     * Pushes a new step sub-document onto the execution's steps array.
     * PATCH /api/executions/:id/steps
     */
    public static void pushStep(String sfExecutionId, StepDocument step) {
        if (!isActive()) return;
        try {
            Map<String, Object> body = new Map<String, Object>{
                'step' => stepDocToMap(step)
            };
            HttpResponse resp = patch(PATH_EXECUTIONS + '/' + sfExecutionId + '/steps', body);
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('pushStep HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
        } catch (Exception e) {
            handleError('pushStep', e);
        }
    }

    /**
     * Updates an existing step sub-document (matched by sfStepExecutionId).
     * PATCH /api/executions/:id/steps/:stepExecId
     */
    public static void updateStep(String sfExecutionId, StepDocument step) {
        if (!isActive()) return;
        try {
            Map<String, Object> body = stepDocToMap(step);
            HttpResponse resp = patch(
                PATH_EXECUTIONS + '/' + sfExecutionId + '/steps/' + step.sfStepExecutionId,
                body
            );
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('updateStep HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
        } catch (Exception e) {
            handleError('updateStep', e);
        }
    }

    /**
     * Finalises an execution: sets completedAt, duration, total tokens, and final status.
     * PATCH /api/executions/:id/finalise
     */
    public static void finaliseExecution(
        String sfExecutionId,
        String status,
        Decimal durationSeconds,
        Integer totalTokensUsed,
        String contextJson,
        String errorMessage
    ) {
        if (!isActive()) return;
        try {
            Map<String, Object> body = new Map<String, Object>{
                'status'          => status,
                'durationSeconds' => durationSeconds,
                'totalTokensUsed' => totalTokensUsed,
                'completedAtEpochMs' => Datetime.now().getTime()
            };
            if (contextJson    != null) body.put('contextJson',    contextJson);
            if (errorMessage   != null) body.put('errorMessage',   errorMessage);
            HttpResponse resp = patch(PATH_EXECUTIONS + '/' + sfExecutionId + '/finalise', body);
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('finaliseExecution HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
        } catch (Exception e) {
            handleError('finaliseExecution', e);
        }
    }

    // ─── Read API ─────────────────────────────────────────────────────────────

    /**
     * Returns aggregate dashboard stats for the last N days.
     * POST /api/executions/aggregate
     */
    @AuraEnabled(cacheable=false)
    public static DashboardResult getDashboardMetrics(Integer lastDays) {
        DashboardResult result = new DashboardResult();
        if (!isActive()) return result;
        try {
            Integer days = lastDays != null ? lastDays : 7;
            Long sinceMs = Datetime.now().addDays(-days).getTime();
            Map<String, Object> body = new Map<String, Object>{
                'pipeline' => new List<Object>{
                    new Map<String, Object>{
                        '$match' => new Map<String, Object>{
                            'started_at' => new Map<String, Object>{
                                '$gte' => new Map<String, Object>{ '$date' => new Map<String, Object>{ '$numberLong' => String.valueOf(sinceMs) } }
                            }
                        }
                    },
                    new Map<String, Object>{
                        '$group' => new Map<String, Object>{
                            '_id'                => null,
                            'totalExecutions'    => new Map<String, Object>{ '$sum' => 1 },
                            'successCount'       => new Map<String, Object>{ '$sum' => new Map<String, Object>{ '$cond' => new List<Object>{ new Map<String, Object>{ '$eq' => new List<Object>{ '$status', 'COMPLETED' } }, 1, 0 } } },
                            'failedCount'        => new Map<String, Object>{ '$sum' => new Map<String, Object>{ '$cond' => new List<Object>{ new Map<String, Object>{ '$eq' => new List<Object>{ '$status', 'FAILED' } }, 1, 0 } } },
                            'runningCount'       => new Map<String, Object>{ '$sum' => new Map<String, Object>{ '$cond' => new List<Object>{ new Map<String, Object>{ '$eq' => new List<Object>{ '$status', 'RUNNING' } }, 1, 0 } } },
                            'avgDurationSeconds' => new Map<String, Object>{ '$avg' => '$duration_seconds' },
                            'totalTokensUsed'    => new Map<String, Object>{ '$sum' => '$total_tokens_used' }
                        }
                    }
                }
            };
            HttpResponse resp = post(PATH_EXECUTIONS_AGGREGATE, body);
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('getDashboardMetrics HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            List<Object> docs = (List<Object>) parsed.get('documents');
            if (docs != null && !docs.isEmpty()) {
                Map<String, Object> row = (Map<String, Object>) docs[0];
                result.totalExecutions    = toInt(row.get('totalExecutions'));
                result.successCount       = toInt(row.get('successCount'));
                result.failedCount        = toInt(row.get('failedCount'));
                result.runningCount       = toInt(row.get('runningCount'));
                result.avgDurationSeconds = toDecimal(row.get('avgDurationSeconds'));
                result.totalTokensUsed    = toInt(row.get('totalTokensUsed'));
                if (result.totalExecutions > 0) {
                    result.successRate = (result.successCount * 100.0) / result.totalExecutions;
                }
            }
        } catch (Exception e) {
            handleError('getDashboardMetrics', e);
        }
        return result;
    }

    /**
     * Returns the N most recent execution summaries.
     * POST /api/executions/query
     */
    @AuraEnabled(cacheable=false)
    public static List<ExecutionSummary> getRecentExecutions(Integer limitRows) {
        List<ExecutionSummary> out = new List<ExecutionSummary>();
        if (!isActive()) return out;
        try {
            Integer lim = limitRows != null ? limitRows : 20;
            Map<String, Object> body = new Map<String, Object>{
                'filter'  => new Map<String, Object>(),
                'sort'    => new Map<String, Object>{ 'started_at' => -1 },
                'limit'   => lim
            };
            HttpResponse resp = post(PATH_EXECUTIONS_QUERY, body);
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('getRecentExecutions HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            List<Object> docs = (List<Object>) parsed.get('documents');
            if (docs != null) {
                for (Object d : docs) {
                    Map<String, Object> row = (Map<String, Object>) d;
                    ExecutionSummary s = new ExecutionSummary();
                    s.sfExecutionId    = (String)  row.get('sf_execution_id');
                    s.workflowName     = (String)  row.get('workflow_name');
                    s.status           = (String)  row.get('status');
                    s.initiatedBy      = (String)  row.get('initiated_by');
                    s.triggerRecordId  = (String)  row.get('trigger_record_id');
                    s.errorMessage     = (String)  row.get('error_message');
                    s.retryCount       = toInt(row.get('retry_count'));
                    s.totalTokensUsed  = toInt(row.get('total_tokens_used'));
                    s.durationSeconds  = toDecimal(row.get('duration_seconds'));
                    s.startedAtEpochMs   = toEpochMs(row.get('started_at'));
                    s.completedAtEpochMs = toEpochMs(row.get('completed_at'));
                    out.add(s);
                }
            }
        } catch (Exception e) {
            handleError('getRecentExecutions', e);
        }
        return out;
    }

    /**
     * Returns per-provider token usage for the last N days.
     * POST /api/executions/aggregate
     */
    @AuraEnabled(cacheable=false)
    public static List<TokenUsageSummary> getTokenUsageByProvider(Integer lastDays) {
        List<TokenUsageSummary> out = new List<TokenUsageSummary>();
        if (!isActive()) return out;
        try {
            Integer days = lastDays != null ? lastDays : 30;
            Long sinceMs = Datetime.now().addDays(-days).getTime();
            Map<String, Object> body = new Map<String, Object>{
                'pipeline' => new List<Object>{
                    new Map<String, Object>{
                        '$match' => new Map<String, Object>{
                            'started_at' => new Map<String, Object>{
                                '$gte' => new Map<String, Object>{ '$date' => new Map<String, Object>{ '$numberLong' => String.valueOf(sinceMs) } }
                            }
                        }
                    },
                    new Map<String, Object>{ '$unwind' => '$steps' },
                    new Map<String, Object>{
                        '$group' => new Map<String, Object>{
                            '_id'            => '$steps.provider_used',
                            'totalTokens'    => new Map<String, Object>{ '$sum' => '$steps.tokens_used' },
                            'executionCount' => new Map<String, Object>{ '$sum' => 1 }
                        }
                    },
                    new Map<String, Object>{ '$sort' => new Map<String, Object>{ 'totalTokens' => -1 } }
                }
            };
            HttpResponse resp = post(PATH_EXECUTIONS_AGGREGATE, body);
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('getTokenUsageByProvider HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            List<Object> docs = (List<Object>) parsed.get('documents');
            if (docs != null) {
                for (Object d : docs) {
                    Map<String, Object> row = (Map<String, Object>) d;
                    TokenUsageSummary t = new TokenUsageSummary();
                    t.providerName   = (String) row.get('_id');
                    t.totalTokens    = toInt(row.get('totalTokens'));
                    t.executionCount = toInt(row.get('executionCount'));
                    out.add(t);
                }
            }
        } catch (Exception e) {
            handleError('getTokenUsageByProvider', e);
        }
        return out;
    }

    /**
     * Paginated, filtered query of execution logs from MongoDB.
     * Supports text search (workflow name), status filter, date range, and sort.
     *
     * POST /api/executions/aggregate  — for count
     * POST /api/executions/query      — for rows
     *
     * @param searchText  Partial match on workflow_name (null = all)
     * @param statusFilter  COMPLETED|FAILED|RUNNING|RETRYING|null (null = all)
     * @param daysBack    How many days back to look (null = all time)
     * @param sortField   MongoDB field name to sort by (default started_at)
     * @param sortAsc     true = ASC, false = DESC
     * @param pageNumber  1-based page number
     * @param pageSize    Rows per page (max 100)
     */
    @AuraEnabled(cacheable=false)
    public static LogPage queryExecutionLogs(
        String  searchText,
        String  statusFilter,
        Integer daysBack,
        String  sortField,
        Boolean sortAsc,
        Integer pageNumber,
        Integer pageSize
    ) {
        LogPage page = new LogPage();
        page.rows       = new List<ExecutionLogRow>();
        page.totalCount = 0;
        page.pageSize   = (pageSize  != null && pageSize  > 0) ? Math.min(pageSize,  100) : 25;
        page.pageNumber = (pageNumber != null && pageNumber > 0) ? pageNumber : 1;

        if (!isActive()) return page;

        try {
            // ── Build filter ──────────────────────────────────────────────────
            Map<String, Object> filter = new Map<String, Object>();

            if (daysBack != null && daysBack > 0) {
                Long sinceMs = Datetime.now().addDays(-daysBack).getTime();
                filter.put('started_at', new Map<String, Object>{
                    '$gte' => new Map<String, Object>{
                        '$date' => new Map<String, Object>{ '$numberLong' => String.valueOf(sinceMs) }
                    }
                });
            }

            if (String.isNotBlank(statusFilter) && statusFilter != 'ALL') {
                filter.put('status', statusFilter);
            }

            if (String.isNotBlank(searchText)) {
                filter.put('workflow_name', new Map<String, Object>{
                    '$regex' => searchText,
                    '$options' => 'i'
                });
            }

            // ── Count query ───────────────────────────────────────────────────
            Map<String, Object> countBody = new Map<String, Object>{
                'pipeline' => new List<Object>{
                    new Map<String, Object>{ '$match' => filter },
                    new Map<String, Object>{ '$count' => 'total' }
                }
            };
            HttpResponse countResp = post(PATH_EXECUTIONS_AGGREGATE, countBody);
            if (countResp.getStatusCode() == 200) {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(countResp.getBody());
                List<Object> docs = (List<Object>) parsed.get('documents');
                if (docs != null && !docs.isEmpty()) {
                    page.totalCount = toInt(((Map<String, Object>) docs[0]).get('total'));
                }
            }

            // ── Rows query ────────────────────────────────────────────────────
            String  sf   = String.isNotBlank(sortField) ? sortField : 'started_at';
            Integer dir  = (sortAsc != null && sortAsc) ? 1 : -1;
            Integer skip = (page.pageNumber - 1) * page.pageSize;

            Map<String, Object> rowBody = new Map<String, Object>{
                'filter' => filter,
                'sort'   => new Map<String, Object>{ sf => dir },
                'limit'  => page.pageSize,
                'skip'   => skip
            };
            HttpResponse rowResp = post(PATH_EXECUTIONS_QUERY, rowBody);
            if (rowResp.getStatusCode() != 200) {
                throw new MongoDBException('queryExecutionLogs HTTP ' + rowResp.getStatusCode() + ': ' + rowResp.getBody());
            }
            Map<String, Object> parsedRows = (Map<String, Object>) JSON.deserializeUntyped(rowResp.getBody());
            List<Object> rowDocs = (List<Object>) parsedRows.get('documents');
            if (rowDocs != null) {
                for (Object d : rowDocs) {
                    Map<String, Object> row = (Map<String, Object>) d;
                    ExecutionLogRow r = new ExecutionLogRow();
                    r.sfExecutionId    = (String)  row.get('sf_execution_id');
                    r.workflowName     = (String)  row.get('workflow_name');
                    r.workflowVersion  = toInt(row.get('workflow_version'));
                    r.status           = (String)  row.get('status');
                    r.initiatedBy      = (String)  row.get('initiated_by');
                    r.triggerRecordId  = (String)  row.get('trigger_record_id');
                    r.triggerObject    = (String)  row.get('trigger_object');
                    r.errorMessage     = (String)  row.get('error_message');
                    r.retryCount       = toInt(row.get('retry_count'));
                    r.totalTokensUsed  = toInt(row.get('total_tokens_used'));
                    r.durationSeconds  = toDecimal(row.get('duration_seconds'));
                    r.startedAtEpochMs   = toEpochMs(row.get('started_at'));
                    r.completedAtEpochMs = toEpochMs(row.get('completed_at'));

                    // Map embedded steps
                    List<StepSummary> stepList = new List<StepSummary>();
                    List<Object> steps = (List<Object>) row.get('steps');
                    if (steps != null) {
                        for (Object s : steps) {
                            Map<String, Object> sr = (Map<String, Object>) s;
                            StepSummary ss = new StepSummary();
                            ss.sfStepExecutionId = (String) sr.get('sf_step_execution_id');
                            ss.stepName          = (String) sr.get('step_name');
                            ss.stepType          = (String) sr.get('step_type');
                            ss.stepOrder         = toInt(sr.get('step_order'));
                            ss.status            = (String) sr.get('status');
                            ss.providerUsed      = (String) sr.get('provider_used');
                            ss.modelUsed         = (String) sr.get('model_used');
                            ss.tokensUsed        = toInt(sr.get('tokens_used'));
                            ss.promptTokens      = toInt(sr.get('prompt_tokens'));
                            ss.completionTokens  = toInt(sr.get('completion_tokens'));
                            ss.durationMs        = toInt(sr.get('duration_ms'));
                            ss.httpStatusCode    = toInt(sr.get('http_status_code'));
                            ss.retryAttempt      = toInt(sr.get('retry_attempt'));
                            ss.errorMessage      = (String) sr.get('error_message');
                            ss.parsedOutput      = (String) sr.get('parsed_output');
                            ss.promptSent        = (String) sr.get('prompt_sent');
                            ss.rawResponse       = (String) sr.get('raw_response');
                            stepList.add(ss);
                        }
                    }
                    r.steps = stepList;
                    page.rows.add(r);
                }
            }
        } catch (Exception e) {
            handleError('queryExecutionLogs', e);
        }
        return page;
    }

    /**
     * Returns step-level details for a single execution.
     * POST /api/executions/query  — projects the steps array only
     */
    @AuraEnabled(cacheable=false)
    public static List<StepSummary> getStepExecutions(String sfExecutionId) {
        List<StepSummary> out = new List<StepSummary>();
        if (!isActive()) return out;
        try {
            Map<String, Object> body = new Map<String, Object>{
                'filter'     => new Map<String, Object>{ 'sf_execution_id' => sfExecutionId },
                'projection' => new Map<String, Object>{ 'steps' => 1 },
                'limit'      => 1
            };
            HttpResponse resp = post(PATH_EXECUTIONS_QUERY, body);
            if (resp.getStatusCode() != 200) {
                throw new MongoDBException('getStepExecutions HTTP ' + resp.getStatusCode() + ': ' + resp.getBody());
            }
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            List<Object> docs = (List<Object>) parsed.get('documents');
            if (docs != null && !docs.isEmpty()) {
                Map<String, Object> doc = (Map<String, Object>) docs[0];
                List<Object> steps = (List<Object>) doc.get('steps');
                if (steps != null) {
                    for (Object s : steps) {
                        Map<String, Object> row = (Map<String, Object>) s;
                        StepSummary ss = new StepSummary();
                        ss.sfStepExecutionId = (String) row.get('sf_step_execution_id');
                        ss.stepName          = (String) row.get('step_name');
                        ss.stepType          = (String) row.get('step_type');
                        ss.stepOrder         = toInt(row.get('step_order'));
                        ss.status            = (String) row.get('status');
                        ss.providerUsed      = (String) row.get('provider_used');
                        ss.modelUsed         = (String) row.get('model_used');
                        ss.tokensUsed        = toInt(row.get('tokens_used'));
                        ss.promptTokens      = toInt(row.get('prompt_tokens'));
                        ss.completionTokens  = toInt(row.get('completion_tokens'));
                        ss.durationMs        = toInt(row.get('duration_ms'));
                        ss.httpStatusCode    = toInt(row.get('http_status_code'));
                        ss.retryAttempt      = toInt(row.get('retry_attempt'));
                        ss.errorMessage      = (String) row.get('error_message');
                        ss.parsedOutput      = (String) row.get('parsed_output');
                        ss.promptSent        = (String) row.get('prompt_sent');
                        ss.rawResponse       = (String) row.get('raw_response');
                        out.add(ss);
                    }
                }
            }
        } catch (Exception e) {
            handleError('getStepExecutions', e);
        }
        return out;
    }

    // ─── Serialisation helpers ────────────────────────────────────────────────

    private static Map<String, Object> executionDocToMap(ExecutionDocument doc) {
        Map<String, Object> m = new Map<String, Object>{
            'sf_execution_id'  => doc.sfExecutionId,
            'sf_workflow_id'   => doc.sfWorkflowId,
            'workflow_name'    => doc.workflowName,
            'workflow_version' => doc.workflowVersion,
            'sf_org_id'        => doc.sfOrgId,
            'status'           => doc.status,
            'initiated_by'     => doc.initiatedBy,
            'retry_count'      => doc.retryCount,
            'schema_version'   => doc.schemaVersion
        };
        if (doc.triggerRecordId  != null) m.put('trigger_record_id', doc.triggerRecordId);
        if (doc.triggerObject    != null) m.put('trigger_object',    doc.triggerObject);
        if (doc.startedAtEpochMs != null) m.put('started_at',
            new Map<String, Object>{ '$date' => new Map<String, Object>{ '$numberLong' => String.valueOf(doc.startedAtEpochMs) } }
        );
        List<Object> stepMaps = new List<Object>();
        if (doc.steps != null) {
            for (StepDocument s : doc.steps) stepMaps.add(stepDocToMap(s));
        }
        m.put('steps', stepMaps);
        return m;
    }

    private static Map<String, Object> stepDocToMap(StepDocument s) {
        Map<String, Object> m = new Map<String, Object>();
        if (s.sfStepExecutionId != null) m.put('sf_step_execution_id', s.sfStepExecutionId);
        if (s.sfStepId          != null) m.put('sf_step_id',           s.sfStepId);
        if (s.stepName          != null) m.put('step_name',            s.stepName);
        if (s.stepType          != null) m.put('step_type',            s.stepType);
        if (s.stepOrder         != null) m.put('step_order',           s.stepOrder);
        if (s.status            != null) m.put('status',               s.status);
        if (s.retryAttempt      != null) m.put('retry_attempt',        s.retryAttempt);
        if (s.providerUsed      != null) m.put('provider_used',        s.providerUsed);
        if (s.modelUsed         != null) m.put('model_used',           s.modelUsed);
        if (s.promptSent        != null) m.put('prompt_sent',          s.promptSent);
        if (s.rawResponse       != null) m.put('raw_response',         s.rawResponse);
        if (s.parsedOutput      != null) m.put('parsed_output',        s.parsedOutput);
        if (s.tokensUsed        != null) m.put('tokens_used',          s.tokensUsed);
        if (s.promptTokens      != null) m.put('prompt_tokens',        s.promptTokens);
        if (s.completionTokens  != null) m.put('completion_tokens',    s.completionTokens);
        if (s.httpStatusCode    != null) m.put('http_status_code',     s.httpStatusCode);
        if (s.durationMs        != null) m.put('duration_ms',          s.durationMs);
        if (s.errorMessage      != null) m.put('error_message',        s.errorMessage);
        return m;
    }

    // ─── Type coercion helpers ────────────────────────────────────────────────

    private static Integer toInt(Object val) {
        if (val == null) return 0;
        if (val instanceof Integer) return (Integer) val;
        if (val instanceof Long)    return ((Long) val).intValue();
        if (val instanceof Decimal) return ((Decimal) val).intValue();
        if (val instanceof Double)  return ((Double) val).intValue();
        return 0;
    }

    private static Decimal toDecimal(Object val) {
        if (val == null) return 0;
        if (val instanceof Decimal) return (Decimal) val;
        if (val instanceof Double)  return Decimal.valueOf((Double) val);
        if (val instanceof Integer) return Decimal.valueOf((Integer) val);
        if (val instanceof Long)    return Decimal.valueOf((Long) val);
        return 0;
    }

    /**
     * Reads an epoch-ms value from a MongoDB Extended JSON date object
     * { "$date": { "$numberLong": "..." } } or a plain number.
     */
    private static Long toEpochMs(Object val) {
        if (val == null) return null;
        if (val instanceof Long)    return (Long) val;
        if (val instanceof Integer) return Long.valueOf(String.valueOf((Integer) val));
        if (val instanceof Decimal) return ((Decimal) val).longValue();
        if (val instanceof Map<String, Object>) {
            Map<String, Object> dateObj = (Map<String, Object>) val;
            Object dateVal = dateObj.get('$date');
            if (dateVal instanceof Map<String, Object>) {
                Map<String, Object> innerMap = (Map<String, Object>) dateVal;
                Object nl = innerMap.get('$numberLong');
                if (nl != null) return Long.valueOf(String.valueOf(nl));
            }
            if (dateVal != null) return Long.valueOf(String.valueOf(dateVal));
        }
        return null;
    }

    // ─── Internal HTTP helpers ────────────────────────────────────────────────

    private static HttpResponse post(String path, Map<String, Object> body) {
        return AIInferenceService.callout(
            ncName(), path, 'POST',
            new Map<String, String>{ 'x-api-key' => '{!$Credential.x-api-key}' },
            JSON.serialize(body),
            timeoutSec()
        );
    }

    private static HttpResponse patch(String path, Map<String, Object> body) {
        return AIInferenceService.callout(
            ncName(), path, 'PATCH',
            new Map<String, String>{ 'x-api-key' => '{!$Credential.x-api-key}' },
            JSON.serialize(body),
            timeoutSec()
        );
    }

    // ─── Error handler ────────────────────────────────────────────────────────

    private static void handleError(String method, Exception e) {
        System.debug(LoggingLevel.ERROR,
            'MongoDBLogService.' + method + ' failed (mode=' +
            (isSyncRequired() ? 'SYNC_REQUIRED' : 'ASYNC_BEST_EFFORT') + '): ' +
            e.getMessage()
        );
        if (isSyncRequired()) throw new MongoDBException(method + ' failed: ' + e.getMessage(), e);
    }
}
