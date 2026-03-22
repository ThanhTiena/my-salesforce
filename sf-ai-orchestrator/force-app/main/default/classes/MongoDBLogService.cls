/**
 * MongoDBLogService
 *
 * All reads and writes to the MongoDB Atlas execution log store.
 * Uses the Atlas Data API (HTTPS REST) via the AI_MongoDB_Atlas Named Credential.
 *
 * Write safety:
 *   - In ASYNC_BEST_EFFORT mode (default) every write is fire-and-forget.
 *     A MongoDB failure NEVER kills a workflow execution.
 *   - In SYNC_REQUIRED mode, failures are re-thrown (for testing/debugging).
 *
 * Connection config is loaded from AI_MongoDB_Config__mdt.Default.
 * If the record does not exist or Is_Active__c = false, all methods no-op.
 *
 * Atlas Data API endpoint pattern:
 *   POST callout:AI_MongoDB_Atlas/app/{appId}/endpoint/data/v1/action/{action}
 *   Headers: api-key: {!$Credential.Password}   (stored in External Credential)
 *
 * @author  AI Orchestration Package
 * @version 1.0
 */
public with sharing class MongoDBLogService {

    public class MongoDBException extends Exception {}

    // ─── Config ──────────────────────────────────────────────────────────────

    private static AI_MongoDB_Config__mdt CONFIG;
    private static Boolean CONFIG_LOADED = false;

    @TestVisible
    private static AI_MongoDB_Config__mdt getConfig() {
        if (!CONFIG_LOADED) {
            List<AI_MongoDB_Config__mdt> rows = [
                SELECT Named_Credential_API_Name__c, App_Id__c, Data_Source__c,
                       Database_Name__c, Executions_Collection__c, Org_Id__c,
                       Is_Active__c, Timeout_Seconds__c, Write_Mode__c
                FROM AI_MongoDB_Config__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            CONFIG        = rows.isEmpty() ? null : rows[0];
            CONFIG_LOADED = true;
        }
        return CONFIG;
    }

    // Allow tests to inject a mock config without a CMDT record in the org
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

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class ExecutionDocument {
        public String  sfExecutionId;
        public String  sfWorkflowId;
        public String  workflowName;
        public Integer workflowVersion;
        public String  sfOrgId;
        public String  status;
        public String  initiatedBy;
        public String  triggerRecordId;
        public String  triggerObject;
        public Long    startedAtEpochMs;
        public Long    completedAtEpochMs;
        public Decimal durationSeconds;
        public Integer retryCount;
        public Integer totalTokensUsed;
        public String  errorMessage;
        public String  finalContextJson;
        public List<StepDocument> steps;
        public Integer schemaVersion;
    }

    public class StepDocument {
        public String  sfStepExecutionId;
        public String  sfStepId;
        public String  stepName;
        public String  stepType;
        public Integer stepOrder;
        public String  status;
        public String  providerUsed;
        public String  modelUsed;
        public String  promptSent;
        public String  rawResponse;
        public String  parsedOutput;
        public Integer promptTokens;
        public Integer completionTokens;
        public Integer tokensUsed;
        public Integer httpStatusCode;
        public Integer durationMs;
        public Integer retryAttempt;
        public String  errorMessage;
    }

    // ─── Write API ───────────────────────────────────────────────────────────

    /**
     * Inserts a new execution document (status = PENDING, empty steps array).
     * Called at the very start of a workflow run by SystemWriter.
     */
    public static void insertExecution(ExecutionDocument doc) {
        if (!isActive()) return;
        try {
            AI_MongoDB_Config__mdt cfg = getConfig();
            Map<String, Object> document = executionToMap(doc);
            Map<String, Object> payload = new Map<String, Object>{
                'collection' => cfg.Executions_Collection__c,
                'document'   => document
            };
            atlasAction('insertOne', payload, cfg);
        } catch (Exception e) {
            handleWriteError('insertExecution', e);
        }
    }

    /**
     * Updates the status and optional error message of an existing execution.
     * Uses MongoDB updateOne with $set.
     */
    public static void updateExecutionStatus(String sfExecutionId, String status, String errorMessage) {
        if (!isActive()) return;
        try {
            AI_MongoDB_Config__mdt cfg = getConfig();
            Map<String, Object> setFields = new Map<String, Object>{
                'status'        => status,
                'error_message' => errorMessage
            };
            if (status == 'RUNNING') {
                // no extra fields
            }
            Map<String, Object> payload = new Map<String, Object>{
                'collection' => cfg.Executions_Collection__c,
                'filter'     => new Map<String, Object>{ 'sf_execution_id' => sfExecutionId },
                'update'     => new Map<String, Object>{ '$set' => setFields }
            };
            atlasAction('updateOne', payload, cfg);
        } catch (Exception e) {
            handleWriteError('updateExecutionStatus', e);
        }
    }

    /**
     * Appends a step document to the steps array of an execution.
     * Called when a step starts (status = RUNNING).
     */
    public static void pushStep(String sfExecutionId, StepDocument step) {
        if (!isActive()) return;
        try {
            AI_MongoDB_Config__mdt cfg = getConfig();
            Map<String, Object> payload = new Map<String, Object>{
                'collection' => cfg.Executions_Collection__c,
                'filter'     => new Map<String, Object>{ 'sf_execution_id' => sfExecutionId },
                'update'     => new Map<String, Object>{
                    '$push' => new Map<String, Object>{ 'steps' => stepToMap(step) }
                }
            };
            atlasAction('updateOne', payload, cfg);
        } catch (Exception e) {
            handleWriteError('pushStep', e);
        }
    }

    /**
     * Updates a specific step inside the steps array by sfStepExecutionId.
     * Uses positional filtered update: steps.$[elem].field
     */
    public static void updateStep(String sfExecutionId, StepDocument step) {
        if (!isActive()) return;
        try {
            AI_MongoDB_Config__mdt cfg = getConfig();
            Map<String, Object> stepFields = new Map<String, Object>();
            for (String key : stepToMap(step).keySet()) {
                stepFields.put('steps.$[elem].' + key, stepToMap(step).get(key));
            }
            Map<String, Object> payload = new Map<String, Object>{
                'collection'    => cfg.Executions_Collection__c,
                'filter'        => new Map<String, Object>{ 'sf_execution_id' => sfExecutionId },
                'update'        => new Map<String, Object>{ '$set' => stepFields },
                'arrayFilters'  => new List<Object>{
                    new Map<String, Object>{ 'elem.sf_step_execution_id' => step.sfStepExecutionId }
                }
            };
            atlasAction('updateOne', payload, cfg);
        } catch (Exception e) {
            handleWriteError('updateStep', e);
        }
    }

    /**
     * Finalises an execution record — sets COMPLETED or FAILED with duration,
     * total token count, and the final serialised context.
     */
    public static void finaliseExecution(
        String  sfExecutionId,
        String  status,
        Decimal durationSeconds,
        Integer totalTokens,
        String  finalContextJson,
        String  errorMessage
    ) {
        if (!isActive()) return;
        try {
            AI_MongoDB_Config__mdt cfg = getConfig();
            Map<String, Object> payload = new Map<String, Object>{
                'collection' => cfg.Executions_Collection__c,
                'filter'     => new Map<String, Object>{ 'sf_execution_id' => sfExecutionId },
                'update'     => new Map<String, Object>{
                    '$set' => new Map<String, Object>{
                        'status'             => status,
                        'completed_at'       => new Map<String, Object>{ '$date' => Datetime.now().getTime() },
                        'duration_seconds'   => durationSeconds,
                        'total_tokens_used'  => totalTokens,
                        'final_context_json' => finalContextJson,
                        'error_message'      => errorMessage
                    }
                }
            };
            atlasAction('updateOne', payload, cfg);
        } catch (Exception e) {
            handleWriteError('finaliseExecution', e);
        }
    }

    // ─── Read API ─────────────────────────────────────────────────────────────

    /**
     * Returns aggregated dashboard metrics via MongoDB aggregation pipeline.
     * Returns an empty DashboardResult on error or when MongoDB is inactive.
     */
    public static DashboardResult getDashboardMetrics(Integer daysBack) {
        DashboardResult result = new DashboardResult();
        if (!isActive()) return result;
        try {
            AI_MongoDB_Config__mdt cfg = getConfig();
            Integer days = (daysBack != null && daysBack > 0) ? daysBack : 7;
            Long sinceMs = Datetime.now().addDays(-days).getTime();

            List<Object> pipeline = new List<Object>{
                new Map<String, Object>{
                    '$match' => new Map<String, Object>{
                        'sf_org_id'  => UserInfo.getOrganizationId(),
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
                        'runningCount'       => new Map<String, Object>{ '$sum' => new Map<String, Object>{ '$cond' => new List<Object>{ new Map<String, Object>{ '$in' => new List<Object>{ '$status', new List<String>{ 'RUNNING', 'RETRYING' } } }, 1, 0 } } },
                        'avgDurationSeconds' => new Map<String, Object>{ '$avg' => '$duration_seconds' },
                        'totalTokensUsed'    => new Map<String, Object>{ '$sum' => '$total_tokens_used' }
                    }
                },
                new Map<String, Object>{
                    '$addFields' => new Map<String, Object>{
                        'successRate' => new Map<String, Object>{
                            '$multiply' => new List<Object>{
                                new Map<String, Object>{ '$divide' => new List<Object>{ '$successCount', new Map<String, Object>{ '$max' => new List<Object>{ '$totalExecutions', 1 } } } },
                                100
                            }
                        }
                    }
                }
            };

            Map<String, Object> payload = new Map<String, Object>{
                'collection' => cfg.Executions_Collection__c,
                'pipeline'   => pipeline
            };
            Map<String, Object> resp = atlasAction('aggregate', payload, cfg);
            List<Object> docs = (List<Object>) resp.get('documents');
            if (docs != null && !docs.isEmpty()) {
                Map<String, Object> doc = (Map<String, Object>) docs[0];
                result.totalExecutions    = intVal(doc, 'totalExecutions');
                result.successCount       = intVal(doc, 'successCount');
                result.failedCount        = intVal(doc, 'failedCount');
                result.runningCount       = intVal(doc, 'runningCount');
                result.avgDurationSeconds = decVal(doc, 'avgDurationSeconds');
                result.totalTokensUsed    = intVal(doc, 'totalTokensUsed');
                result.successRate        = decVal(doc, 'successRate');
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'MongoDBLogService.getDashboardMetrics error: ' + e.getMessage());
            if (isSyncRequired()) throw new MongoDBException('getDashboardMetrics failed: ' + e.getMessage(), e);
        }
        return result;
    }

    /**
     * Returns the most recent N execution documents (without the steps array).
     */
    public static List<ExecutionSummary> getRecentExecutions(Integer limitRows) {
        List<ExecutionSummary> out = new List<ExecutionSummary>();
        if (!isActive()) return out;
        try {
            AI_MongoDB_Config__mdt cfg = getConfig();
            Integer lim = (limitRows != null && limitRows > 0) ? Math.min(limitRows, 200) : 20;
            Map<String, Object> payload = new Map<String, Object>{
                'collection'  => cfg.Executions_Collection__c,
                'filter'      => new Map<String, Object>{ 'sf_org_id' => UserInfo.getOrganizationId() },
                'projection'  => new Map<String, Object>{ 'steps' => 0 },
                'sort'        => new Map<String, Object>{ 'started_at' => -1 },
                'limit'       => lim
            };
            Map<String, Object> resp = atlasAction('find', payload, cfg);
            List<Object> docs = (List<Object>) resp.get('documents');
            if (docs != null) {
                for (Object raw : docs) {
                    Map<String, Object> doc = (Map<String, Object>) raw;
                    ExecutionSummary s = new ExecutionSummary();
                    s.sfExecutionId    = strVal(doc, 'sf_execution_id');
                    s.workflowName     = strVal(doc, 'workflow_name');
                    s.status           = strVal(doc, 'status');
                    s.initiatedBy      = strVal(doc, 'initiated_by');
                    s.startedAtEpochMs = longVal(doc, 'started_at');
                    s.completedAtEpochMs = longVal(doc, 'completed_at');
                    s.durationSeconds  = decVal(doc, 'duration_seconds');
                    s.retryCount       = intVal(doc, 'retry_count');
                    s.totalTokensUsed  = intVal(doc, 'total_tokens_used');
                    s.errorMessage     = strVal(doc, 'error_message');
                    s.triggerRecordId  = strVal(doc, 'trigger_record_id');
                    out.add(s);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'MongoDBLogService.getRecentExecutions error: ' + e.getMessage());
            if (isSyncRequired()) throw new MongoDBException('getRecentExecutions failed: ' + e.getMessage(), e);
        }
        return out;
    }

    /**
     * Returns token usage aggregated by provider for the last N days.
     * Unwinds the steps array and groups by provider_used.
     */
    public static List<TokenUsageSummary> getTokenUsageByProvider(Integer daysBack) {
        List<TokenUsageSummary> out = new List<TokenUsageSummary>();
        if (!isActive()) return out;
        try {
            AI_MongoDB_Config__mdt cfg = getConfig();
            Integer days = (daysBack != null && daysBack > 0) ? daysBack : 30;
            Long sinceMs = Datetime.now().addDays(-days).getTime();

            List<Object> pipeline = new List<Object>{
                new Map<String, Object>{
                    '$match' => new Map<String, Object>{
                        'sf_org_id'  => UserInfo.getOrganizationId(),
                        'started_at' => new Map<String, Object>{
                            '$gte' => new Map<String, Object>{ '$date' => new Map<String, Object>{ '$numberLong' => String.valueOf(sinceMs) } }
                        }
                    }
                },
                new Map<String, Object>{ '$unwind' => '$steps' },
                new Map<String, Object>{
                    '$match' => new Map<String, Object>{
                        'steps.provider_used' => new Map<String, Object>{ '$ne' => null }
                    }
                },
                new Map<String, Object>{
                    '$group' => new Map<String, Object>{
                        '_id'            => '$steps.provider_used',
                        'totalTokens'    => new Map<String, Object>{ '$sum' => '$steps.tokens_used' },
                        'executionCount' => new Map<String, Object>{ '$sum' => 1 }
                    }
                },
                new Map<String, Object>{ '$sort' => new Map<String, Object>{ 'totalTokens' => -1 } }
            };

            Map<String, Object> payload = new Map<String, Object>{
                'collection' => cfg.Executions_Collection__c,
                'pipeline'   => pipeline
            };
            Map<String, Object> resp = atlasAction('aggregate', payload, cfg);
            List<Object> docs = (List<Object>) resp.get('documents');
            if (docs != null) {
                for (Object raw : docs) {
                    Map<String, Object> doc = (Map<String, Object>) raw;
                    TokenUsageSummary t = new TokenUsageSummary();
                    t.providerName   = strVal(doc, '_id');
                    t.totalTokens    = intVal(doc, 'totalTokens');
                    t.executionCount = intVal(doc, 'executionCount');
                    out.add(t);
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'MongoDBLogService.getTokenUsageByProvider error: ' + e.getMessage());
            if (isSyncRequired()) throw new MongoDBException('getTokenUsageByProvider failed: ' + e.getMessage(), e);
        }
        return out;
    }

    /**
     * Returns the steps array for a given sfExecutionId.
     */
    public static List<StepSummary> getStepExecutions(String sfExecutionId) {
        List<StepSummary> out = new List<StepSummary>();
        if (!isActive()) return out;
        try {
            AI_MongoDB_Config__mdt cfg = getConfig();
            Map<String, Object> payload = new Map<String, Object>{
                'collection' => cfg.Executions_Collection__c,
                'filter'     => new Map<String, Object>{ 'sf_execution_id' => sfExecutionId },
                'projection' => new Map<String, Object>{ 'steps' => 1 },
                'limit'      => 1
            };
            Map<String, Object> resp = atlasAction('find', payload, cfg);
            List<Object> docs = (List<Object>) resp.get('documents');
            if (docs != null && !docs.isEmpty()) {
                Map<String, Object> doc = (Map<String, Object>) docs[0];
                List<Object> steps = (List<Object>) doc.get('steps');
                if (steps != null) {
                    for (Object rawStep : steps) {
                        Map<String, Object> s = (Map<String, Object>) rawStep;
                        StepSummary ss = new StepSummary();
                        ss.id           = strVal(s, 'sf_step_execution_id');
                        ss.stepName     = strVal(s, 'step_name');
                        ss.stepType     = strVal(s, 'step_type');
                        ss.status       = strVal(s, 'status');
                        ss.providerUsed = strVal(s, 'provider_used');
                        ss.modelUsed    = strVal(s, 'model_used');
                        ss.tokensUsed   = intVal(s, 'tokens_used');
                        ss.durationMs   = intVal(s, 'duration_ms');
                        ss.errorMessage = strVal(s, 'error_message');
                        ss.parsedOutput = strVal(s, 'parsed_output');
                        out.add(ss);
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'MongoDBLogService.getStepExecutions error: ' + e.getMessage());
            if (isSyncRequired()) throw new MongoDBException('getStepExecutions failed: ' + e.getMessage(), e);
        }
        return out;
    }

    // ─── Read Result DTOs ─────────────────────────────────────────────────────

    public class DashboardResult {
        public Integer totalExecutions    = 0;
        public Integer successCount       = 0;
        public Integer failedCount        = 0;
        public Integer runningCount       = 0;
        public Decimal avgDurationSeconds = 0;
        public Integer totalTokensUsed    = 0;
        public Decimal successRate        = 0;
    }

    public class ExecutionSummary {
        public String  sfExecutionId;
        public String  workflowName;
        public String  status;
        public String  initiatedBy;
        public Long    startedAtEpochMs;
        public Long    completedAtEpochMs;
        public Decimal durationSeconds;
        public Integer retryCount;
        public Integer totalTokensUsed;
        public String  errorMessage;
        public String  triggerRecordId;
    }

    public class TokenUsageSummary {
        public String  providerName;
        public Integer totalTokens;
        public Integer executionCount;
    }

    public class StepSummary {
        public String  id;
        public String  stepName;
        public String  stepType;
        public String  status;
        public String  providerUsed;
        public String  modelUsed;
        public Integer tokensUsed;
        public Integer durationMs;
        public String  errorMessage;
        public String  parsedOutput;
    }

    // ─── Internal HTTP Helper ─────────────────────────────────────────────────

    @TestVisible
    private static Map<String, Object> atlasAction(
        String action,
        Map<String, Object> payload,
        AI_MongoDB_Config__mdt cfg
    ) {
        // Path: /<basePath>/action/<action>
        // basePath is optional (App_Id__c field re-purposed as proxy base path)
        String basePath = String.isBlank(cfg.App_Id__c) ? '' : '/' + cfg.App_Id__c.removeStart('/');
        String path = basePath + '/action/' + action;
        payload.put('dataSource', cfg.Data_Source__c);
        payload.put('database',   cfg.Database_Name__c);

        Integer timeoutSec = cfg.Timeout_Seconds__c != null
            ? cfg.Timeout_Seconds__c.intValue()
            : 30;

        HttpResponse resp = AIInferenceService.callout(
            cfg.Named_Credential_API_Name__c,
            path,
            'POST',
            new Map<String, String>{ 'api-key' => '{!$Credential.Password}' },
            JSON.serialize(payload),
            timeoutSec
        );

        if (resp.getStatusCode() >= 400) {
            throw new MongoDBException(
                'Atlas API error ' + resp.getStatusCode() + ' on ' + action + ': ' + resp.getBody()
            );
        }
        return (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
    }

    // ─── Serialisation Helpers ────────────────────────────────────────────────

    private static Map<String, Object> executionToMap(ExecutionDocument doc) {
        Map<String, Object> m = new Map<String, Object>{
            'sf_execution_id'    => doc.sfExecutionId,
            'sf_workflow_id'     => doc.sfWorkflowId,
            'workflow_name'      => doc.workflowName,
            'workflow_version'   => doc.workflowVersion,
            'sf_org_id'          => doc.sfOrgId,
            'status'             => doc.status,
            'initiated_by'       => doc.initiatedBy,
            'trigger_record_id'  => doc.triggerRecordId,
            'trigger_object'     => doc.triggerObject,
            'started_at'         => new Map<String, Object>{ '$date' => new Map<String, Object>{ '$numberLong' => String.valueOf(doc.startedAtEpochMs) } },
            'retry_count'        => doc.retryCount,
            'total_tokens_used'  => doc.totalTokensUsed,
            'error_message'      => doc.errorMessage,
            'final_context_json' => doc.finalContextJson,
            'steps'              => new List<Object>(),
            'schema_version'     => doc.schemaVersion != null ? doc.schemaVersion : 1
        };
        return m;
    }

    private static Map<String, Object> stepToMap(StepDocument s) {
        return new Map<String, Object>{
            'sf_step_execution_id' => s.sfStepExecutionId,
            'sf_step_id'           => s.sfStepId,
            'step_name'            => s.stepName,
            'step_type'            => s.stepType,
            'step_order'           => s.stepOrder,
            'status'               => s.status,
            'provider_used'        => s.providerUsed,
            'model_used'           => s.modelUsed,
            'prompt_sent'          => s.promptSent,
            'raw_response'         => s.rawResponse,
            'parsed_output'        => s.parsedOutput,
            'prompt_tokens'        => s.promptTokens,
            'completion_tokens'    => s.completionTokens,
            'tokens_used'          => s.tokensUsed,
            'http_status_code'     => s.httpStatusCode,
            'duration_ms'          => s.durationMs,
            'retry_attempt'        => s.retryAttempt,
            'error_message'        => s.errorMessage
        };
    }

    // ─── Write Error Handler ──────────────────────────────────────────────────

    private static void handleWriteError(String method, Exception e) {
        System.debug(LoggingLevel.ERROR,
            'MongoDBLogService.' + method + ' failed (mode=' +
            (isSyncRequired() ? 'SYNC_REQUIRED' : 'ASYNC_BEST_EFFORT') + '): ' +
            e.getMessage()
        );
        if (isSyncRequired()) throw new MongoDBException(method + ' failed: ' + e.getMessage(), e);
    }

    // ─── Value Extraction Helpers ─────────────────────────────────────────────

    private static String  strVal(Map<String, Object> m, String k) {
        Object v = m.get(k);
        return v != null ? String.valueOf(v) : null;
    }

    private static Integer intVal(Map<String, Object> m, String k) {
        Object v = m.get(k);
        if (v == null) return 0;
        if (v instanceof Integer) return (Integer) v;
        if (v instanceof Decimal) return ((Decimal) v).intValue();
        if (v instanceof Long)    return ((Long) v).intValue();
        return 0;
    }

    private static Decimal decVal(Map<String, Object> m, String k) {
        Object v = m.get(k);
        if (v == null) return 0;
        if (v instanceof Decimal) return (Decimal) v;
        if (v instanceof Integer) return Decimal.valueOf((Integer) v);
        if (v instanceof Long)    return Decimal.valueOf((Long) v);
        return 0;
    }

    private static Long longVal(Map<String, Object> m, String k) {
        Object v = m.get(k);
        if (v == null) return null;
        // Atlas Date fields come back as { "$date": { "$numberLong": "..." } }
        if (v instanceof Map<String, Object>) {
            Map<String, Object> dateMap = (Map<String, Object>) v;
            Object dateVal = dateMap.get('$date');
            if (dateVal instanceof Map<String, Object>) {
                Object nl = ((Map<String, Object>) dateVal).get('$numberLong');
                if (nl != null) return Long.valueOf(String.valueOf(nl));
            }
            if (dateVal instanceof Long)    return (Long) dateVal;
            if (dateVal instanceof Decimal) return ((Decimal) dateVal).longValue();
        }
        if (v instanceof Long)    return (Long) v;
        if (v instanceof Decimal) return ((Decimal) v).longValue();
        return null;
    }
}
