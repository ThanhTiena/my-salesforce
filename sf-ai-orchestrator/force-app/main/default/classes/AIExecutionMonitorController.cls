/**
 * AIExecutionMonitorController
 *
 * Apex controller for the aiExecutionMonitor LWC.
 *
 * Phase 3 (read switch): all four @AuraEnabled methods now read from MongoDB
 * via MongoDBLogService. When MongoDB is inactive (Is_Active__c = false or
 * no CMDT record), the service returns empty results and this controller
 * falls back to Salesforce SOQL seamlessly.
 *
 * cacheable=true is NOT used on methods that call MongoDB — callouts are
 * incompatible with the Salesforce Apex caching mechanism.
 *
 * Security: runs with sharing, CRUD checked via AISecurityUtil.
 */
public with sharing class AIExecutionMonitorController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class ExecutionSummary {
        @AuraEnabled public String   execId;
        @AuraEnabled public String   workflowName;
        @AuraEnabled public String   status;
        @AuraEnabled public String   initiatedBy;
        @AuraEnabled public Datetime startedAt;
        @AuraEnabled public Datetime completedAt;
        @AuraEnabled public Decimal  durationSeconds;
        @AuraEnabled public Integer  retryCount;
        @AuraEnabled public Integer  totalTokens;
        @AuraEnabled public String   errorMessage;
        @AuraEnabled public String   triggerRecordId;
    }

    public class DashboardMetrics {
        @AuraEnabled public Integer totalExecutions;
        @AuraEnabled public Integer successCount;
        @AuraEnabled public Integer failedCount;
        @AuraEnabled public Integer runningCount;
        @AuraEnabled public Decimal avgDurationSeconds;
        @AuraEnabled public Integer totalTokensUsed;
        @AuraEnabled public Decimal successRate;
    }

    public class TokenUsageByProvider {
        @AuraEnabled public String  providerName;
        @AuraEnabled public Integer totalTokens;
        @AuraEnabled public Integer executionCount;
    }

    public class StepExecutionSummary {
        @AuraEnabled public String  stepExecId;
        @AuraEnabled public String  stepName;
        @AuraEnabled public String  stepType;
        @AuraEnabled public String  status;
        @AuraEnabled public String  providerUsed;
        @AuraEnabled public String  modelUsed;
        @AuraEnabled public Integer tokensUsed;
        @AuraEnabled public Integer durationMs;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public String  parsedOutput;
    }

    // ─── Public API ──────────────────────────────────────────────────────────

    /**
     * Returns high-level dashboard metrics across all workflows.
     * Reads from MongoDB when active; falls back to Salesforce SOQL otherwise.
     * @param daysBack  Number of days to look back (default 7)
     */
    @AuraEnabled(cacheable=false)
    public static DashboardMetrics getDashboardMetrics(Integer daysBack) {
        Integer days = (daysBack != null && daysBack > 0) ? daysBack : 7;

        // ── MongoDB read ──────────────────────────────────────────────────────
        MongoDBLogService.DashboardResult mongoResult = MongoDBLogService.getDashboardMetrics(days);
        if (mongoResult.totalExecutions > 0 || isMongoActive()) {
            DashboardMetrics m = new DashboardMetrics();
            m.totalExecutions    = mongoResult.totalExecutions;
            m.successCount       = mongoResult.successCount;
            m.failedCount        = mongoResult.failedCount;
            m.runningCount       = mongoResult.runningCount;
            m.avgDurationSeconds = mongoResult.avgDurationSeconds;
            m.totalTokensUsed    = mongoResult.totalTokensUsed;
            m.successRate        = mongoResult.successRate;
            return m;
        }

        // ── Salesforce fallback ───────────────────────────────────────────────
        AISecurityUtil.assertReadable(AI_Execution__c.SObjectType);
        Datetime since = Datetime.now().addDays(-days);

        List<AggregateResult> results = [
            SELECT Status__c status, COUNT(Id) cnt,
                   AVG(Duration_Seconds__c) avgDur,
                   SUM(Total_Tokens_Used__c) totalTok
            FROM AI_Execution__c
            WHERE CreatedDate >= :since
            GROUP BY Status__c
        ];

        DashboardMetrics m = new DashboardMetrics();
        m.totalExecutions    = 0;
        m.successCount       = 0;
        m.failedCount        = 0;
        m.runningCount       = 0;
        m.totalTokensUsed    = 0;
        m.avgDurationSeconds = 0;

        Decimal weightedDur = 0;
        for (AggregateResult r : results) {
            Integer cnt      = ((Decimal) r.get('cnt')).intValue();
            String  status   = (String)  r.get('status');
            Decimal avgDur   = (Decimal) r.get('avgDur');
            Decimal totalTok = (Decimal) r.get('totalTok');

            m.totalExecutions += cnt;
            if (totalTok != null) m.totalTokensUsed    += totalTok.intValue();
            if (avgDur   != null) weightedDur           += avgDur * cnt;

            if (status == 'COMPLETED')                          m.successCount += cnt;
            else if (status == 'FAILED')                        m.failedCount  += cnt;
            else if (status == 'RUNNING' || status == 'RETRYING') m.runningCount += cnt;
        }

        if (m.totalExecutions > 0) {
            m.avgDurationSeconds = weightedDur / m.totalExecutions;
            m.successRate        = (Decimal) m.successCount / m.totalExecutions * 100;
        }
        return m;
    }

    /**
     * Returns the most recent N executions.
     * Reads from MongoDB when active; falls back to Salesforce SOQL otherwise.
     */
    @AuraEnabled(cacheable=false)
    public static List<ExecutionSummary> getRecentExecutions(Integer limitRows) {
        Integer lim = (limitRows != null && limitRows > 0) ? Math.min(limitRows, 200) : 20;

        // ── MongoDB read ──────────────────────────────────────────────────────
        if (isMongoActive()) {
            List<MongoDBLogService.ExecutionSummary> mongoRows = MongoDBLogService.getRecentExecutions(lim);
            List<ExecutionSummary> out = new List<ExecutionSummary>();
            for (MongoDBLogService.ExecutionSummary r : mongoRows) {
                ExecutionSummary s  = new ExecutionSummary();
                s.execId           = r.sfExecutionId;
                s.workflowName     = r.workflowName;
                s.status           = r.status;
                s.initiatedBy      = r.initiatedBy;
                s.startedAt        = r.startedAtEpochMs != null ? Datetime.newInstance(r.startedAtEpochMs) : null;
                s.completedAt      = r.completedAtEpochMs != null ? Datetime.newInstance(r.completedAtEpochMs) : null;
                s.durationSeconds  = r.durationSeconds;
                s.retryCount       = r.retryCount;
                s.totalTokens      = r.totalTokensUsed;
                s.errorMessage     = r.errorMessage;
                s.triggerRecordId  = r.triggerRecordId;
                out.add(s);
            }
            return out;
        }

        // ── Salesforce fallback ───────────────────────────────────────────────
        AISecurityUtil.assertReadable(AI_Execution__c.SObjectType);
        List<AI_Execution__c> recs = [
            SELECT Id, AI_Workflow__r.Name, Status__c, Initiated_By__c,
                   Started_At__c, Completed_At__c, Duration_Seconds__c,
                   Retry_Count__c, Total_Tokens_Used__c, Error_Message__c,
                   Trigger_Record_Id__c
            FROM AI_Execution__c
            ORDER BY CreatedDate DESC
            LIMIT :lim
        ];

        List<ExecutionSummary> out = new List<ExecutionSummary>();
        for (AI_Execution__c r : recs) {
            ExecutionSummary s  = new ExecutionSummary();
            s.execId           = r.Id;
            s.workflowName     = r.AI_Workflow__r?.Name;
            s.status           = r.Status__c;
            s.initiatedBy      = r.Initiated_By__c;
            s.startedAt        = r.Started_At__c;
            s.completedAt      = r.Completed_At__c;
            s.durationSeconds  = r.Duration_Seconds__c;
            s.retryCount       = r.Retry_Count__c != null ? r.Retry_Count__c.intValue() : 0;
            s.totalTokens      = r.Total_Tokens_Used__c != null ? r.Total_Tokens_Used__c.intValue() : 0;
            s.errorMessage     = r.Error_Message__c;
            s.triggerRecordId  = r.Trigger_Record_Id__c;
            out.add(s);
        }
        return out;
    }

    /**
     * Returns token usage aggregated by provider.
     * Reads from MongoDB when active; falls back to Salesforce SOQL otherwise.
     */
    @AuraEnabled(cacheable=false)
    public static List<TokenUsageByProvider> getTokenUsageByProvider(Integer daysBack) {
        Integer days = (daysBack != null && daysBack > 0) ? daysBack : 30;

        // ── MongoDB read ──────────────────────────────────────────────────────
        if (isMongoActive()) {
            List<MongoDBLogService.TokenUsageSummary> mongoRows = MongoDBLogService.getTokenUsageByProvider(days);
            List<TokenUsageByProvider> out = new List<TokenUsageByProvider>();
            for (MongoDBLogService.TokenUsageSummary r : mongoRows) {
                TokenUsageByProvider t = new TokenUsageByProvider();
                t.providerName   = r.providerName;
                t.totalTokens    = r.totalTokens;
                t.executionCount = r.executionCount;
                out.add(t);
            }
            return out;
        }

        // ── Salesforce fallback ───────────────────────────────────────────────
        AISecurityUtil.assertReadable(AI_Step_Execution__c.SObjectType);
        Datetime since = Datetime.now().addDays(-days);

        List<AggregateResult> results = [
            SELECT Provider_Used__c provider, SUM(Tokens_Used__c) totalTok, COUNT(Id) cnt
            FROM AI_Step_Execution__c
            WHERE CreatedDate >= :since AND Provider_Used__c != null
            GROUP BY Provider_Used__c
            ORDER BY SUM(Tokens_Used__c) DESC
        ];

        List<TokenUsageByProvider> out = new List<TokenUsageByProvider>();
        for (AggregateResult r : results) {
            TokenUsageByProvider t = new TokenUsageByProvider();
            t.providerName   = (String)  r.get('provider');
            t.totalTokens    = r.get('totalTok') != null ? ((Decimal) r.get('totalTok')).intValue() : 0;
            t.executionCount = ((Decimal) r.get('cnt')).intValue();
            out.add(t);
        }
        return out;
    }

    /**
     * Returns step-level execution detail for a given execution.
     * executionId may be a Salesforce Id or a MongoDB execution ID string.
     * Reads from MongoDB when active; falls back to Salesforce SOQL otherwise.
     */
    @AuraEnabled(cacheable=false)
    public static List<StepExecutionSummary> getStepExecutions(String executionId) {
        // ── MongoDB read ──────────────────────────────────────────────────────
        if (isMongoActive()) {
            // If executionId looks like a Salesforce Id, resolve to Mongo ID first
            String mongoId = resolveMongoId(executionId);
            List<MongoDBLogService.StepSummary> steps = MongoDBLogService.getStepExecutions(mongoId);
            List<StepExecutionSummary> out = new List<StepExecutionSummary>();
            for (MongoDBLogService.StepSummary s : steps) {
                StepExecutionSummary ss = new StepExecutionSummary();
                ss.stepExecId   = s.sfStepExecutionId;
                ss.stepName     = s.stepName;
                ss.stepType     = s.stepType;
                ss.status       = s.status;
                ss.providerUsed = s.providerUsed;
                ss.modelUsed    = s.modelUsed;
                ss.tokensUsed   = s.tokensUsed;
                ss.durationMs   = s.durationMs;
                ss.errorMessage = s.errorMessage;
                ss.parsedOutput = s.parsedOutput;
                out.add(ss);
            }
            return out;
        }

        // ── Salesforce fallback ───────────────────────────────────────────────
        AISecurityUtil.assertReadable(AI_Step_Execution__c.SObjectType);
        Id sfExecId = (Id) executionId;
        List<AI_Step_Execution__c> recs = [
            SELECT Id, AI_Step__r.Name, AI_Step__r.Step_Type__c, Status__c,
                   Provider_Used__c, Model_Used__c, Tokens_Used__c,
                   Duration_Ms__c, Error_Message__c, Parsed_Output__c
            FROM AI_Step_Execution__c
            WHERE AI_Execution__c = :sfExecId
            ORDER BY CreatedDate ASC
        ];

        List<StepExecutionSummary> out = new List<StepExecutionSummary>();
        for (AI_Step_Execution__c r : recs) {
            StepExecutionSummary ss = new StepExecutionSummary();
            ss.stepExecId   = r.Id;
            ss.stepName     = r.AI_Step__r?.Name;
            ss.stepType     = r.AI_Step__r?.Step_Type__c;
            ss.status       = r.Status__c;
            ss.providerUsed = r.Provider_Used__c;
            ss.modelUsed    = r.Model_Used__c;
            ss.tokensUsed   = r.Tokens_Used__c != null ? r.Tokens_Used__c.intValue() : 0;
            ss.durationMs   = r.Duration_Ms__c != null ? r.Duration_Ms__c.intValue() : 0;
            ss.errorMessage = r.Error_Message__c;
            ss.parsedOutput = r.Parsed_Output__c;
            out.add(ss);
        }
        return out;
    }

    /**
     * Returns the full execution progress for one execution:
     * the ordered step definitions merged with their live step-execution statuses.
     * Used by the aiExecutionProgress LWC for animated real-time polling.
     * executionId = Salesforce AI_Execution__c Id.
     */
    @AuraEnabled(cacheable=false)
    public static ExecutionProgress getExecutionProgress(String executionId) {
        if (String.isBlank(executionId)) {
            throw new AuraHandledException('executionId is required');
        }

        AISecurityUtil.assertReadable(AI_Execution__c.SObjectType);
        AISecurityUtil.assertReadable(AI_Step__c.SObjectType);
        AISecurityUtil.assertReadable(AI_Step_Execution__c.SObjectType);

        Id sfExecId = (Id) executionId;

        // Load execution header
        AI_Execution__c exec = [
            SELECT Id, Status__c, Started_At__c, Completed_At__c,
                   Duration_Seconds__c, Error_Message__c, Retry_Count__c,
                   Total_Tokens_Used__c, Trigger_Record_Id__c,
                   AI_Workflow__c, AI_Workflow__r.Name, AI_Workflow__r.Canvas_JSON__c
            FROM AI_Execution__c
            WHERE Id = :sfExecId
            LIMIT 1
        ];

        // Load ordered step definitions for the workflow
        List<AI_Step__c> stepDefs = [
            SELECT Id, Name, Step_Type__c, Order__c, Is_Active__c
            FROM AI_Step__c
            WHERE AI_Workflow__c = :exec.AI_Workflow__c
            ORDER BY Order__c ASC
        ];

        // Load step executions for this run (keyed by Step Id)
        List<AI_Step_Execution__c> stepExecs = [
            SELECT Id, AI_Step__c, Status__c, Duration_Ms__c, Tokens_Used__c,
                   Provider_Used__c, Model_Used__c, Error_Message__c,
                   Parsed_Output__c, Prompt_Sent__c, Raw_Response__c
            FROM AI_Step_Execution__c
            WHERE AI_Execution__c = :sfExecId
            ORDER BY CreatedDate ASC
        ];

        Map<Id, AI_Step_Execution__c> execByStep = new Map<Id, AI_Step_Execution__c>();
        for (AI_Step_Execution__c se : stepExecs) {
            execByStep.put(se.AI_Step__c, se);
        }

        // Merge
        List<StepProgress> steps = new List<StepProgress>();
        for (AI_Step__c sd : stepDefs) {
            StepProgress sp    = new StepProgress();
            sp.stepId          = sd.Id;
            sp.stepName        = sd.Name;
            sp.stepType        = sd.Step_Type__c;
            sp.stepOrder       = sd.Order__c != null ? sd.Order__c.intValue() : 0;
            sp.isActive        = sd.Is_Active__c;

            AI_Step_Execution__c se = execByStep.get(sd.Id);
            if (se != null) {
                sp.stepExecId  = se.Id;
                sp.status      = se.Status__c;
                sp.durationMs  = se.Duration_Ms__c != null ? se.Duration_Ms__c.intValue() : null;
                sp.tokensUsed  = se.Tokens_Used__c != null ? se.Tokens_Used__c.intValue() : null;
                sp.providerUsed = se.Provider_Used__c;
                sp.modelUsed   = se.Model_Used__c;
                sp.errorMessage = se.Error_Message__c;
                sp.parsedOutput = se.Parsed_Output__c;
                sp.promptSent  = se.Prompt_Sent__c;
                sp.rawResponse = se.Raw_Response__c;
            } else {
                sp.status = 'PENDING';
            }
            steps.add(sp);
        }

        ExecutionProgress progress      = new ExecutionProgress();
        progress.executionId            = exec.Id;
        progress.workflowName           = exec.AI_Workflow__r?.Name;
        progress.canvasJson             = exec.AI_Workflow__r?.Canvas_JSON__c;
        progress.status                 = exec.Status__c;
        progress.startedAt              = exec.Started_At__c;
        progress.completedAt            = exec.Completed_At__c;
        progress.durationSeconds        = exec.Duration_Seconds__c;
        progress.errorMessage           = exec.Error_Message__c;
        progress.retryCount             = exec.Retry_Count__c != null ? exec.Retry_Count__c.intValue() : 0;
        progress.totalTokens            = exec.Total_Tokens_Used__c != null ? exec.Total_Tokens_Used__c.intValue() : 0;
        progress.triggerRecordId        = exec.Trigger_Record_Id__c;
        progress.steps                  = steps;
        return progress;
    }

    public class ExecutionProgress {
        @AuraEnabled public String          executionId;
        @AuraEnabled public String          workflowName;
        @AuraEnabled public String          canvasJson;
        @AuraEnabled public String          status;
        @AuraEnabled public Datetime        startedAt;
        @AuraEnabled public Datetime        completedAt;
        @AuraEnabled public Decimal         durationSeconds;
        @AuraEnabled public String          errorMessage;
        @AuraEnabled public Integer         retryCount;
        @AuraEnabled public Integer         totalTokens;
        @AuraEnabled public String          triggerRecordId;
        @AuraEnabled public List<StepProgress> steps;
    }

    public class StepProgress {
        @AuraEnabled public String  stepId;
        @AuraEnabled public String  stepExecId;
        @AuraEnabled public String  stepName;
        @AuraEnabled public String  stepType;
        @AuraEnabled public Integer stepOrder;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String  status;       // PENDING | RUNNING | COMPLETED | FAILED
        @AuraEnabled public Integer durationMs;
        @AuraEnabled public Integer tokensUsed;
        @AuraEnabled public String  providerUsed;
        @AuraEnabled public String  modelUsed;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public String  parsedOutput;
        @AuraEnabled public String  promptSent;
        @AuraEnabled public String  rawResponse;
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────

    private static Boolean isMongoActive() {
        List<AI_MongoDB_Config__mdt> rows = [
            SELECT Is_Active__c FROM AI_MongoDB_Config__mdt
            WHERE DeveloperName = 'Default' LIMIT 1
        ];
        return !rows.isEmpty() && rows[0].Is_Active__c;
    }

    /**
     * If the caller passes a Salesforce 15/18-char Id, look up the
     * Mongo_Execution_Id__c on the AI_Execution__c record.
     * Otherwise assume it's already a Mongo ID string and return as-is.
     */
    private static String resolveMongoId(String executionId) {
        if (String.isBlank(executionId)) return executionId;
        // Salesforce Ids are 15 or 18 chars of alphanumeric
        if (executionId.length() == 15 || executionId.length() == 18) {
            try {
                Id sfId = (Id) executionId;
                List<AI_Execution__c> rows = [
                    SELECT Mongo_Execution_Id__c FROM AI_Execution__c WHERE Id = :sfId LIMIT 1
                ];
                if (!rows.isEmpty() && String.isNotBlank(rows[0].Mongo_Execution_Id__c)) {
                    return rows[0].Mongo_Execution_Id__c;
                }
            } catch (Exception e) {
                // Not a valid SF Id — treat as Mongo ID directly
            }
        }
        return executionId;
    }
}
