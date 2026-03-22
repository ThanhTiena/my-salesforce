/**
 * AIExecutionMonitorController
 *
 * Apex controller for the aiExecutionMonitor LWC.
 * Provides aggregated execution metrics and recent execution lists.
 *
 * Security: runs with sharing, CRUD checked via AISecurityUtil.
 */
public with sharing class AIExecutionMonitorController {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class ExecutionSummary {
        @AuraEnabled public Id     id;
        @AuraEnabled public String workflowName;
        @AuraEnabled public String status;
        @AuraEnabled public String initiatedBy;
        @AuraEnabled public Datetime startedAt;
        @AuraEnabled public Datetime completedAt;
        @AuraEnabled public Decimal durationSeconds;
        @AuraEnabled public Integer retryCount;
        @AuraEnabled public Integer totalTokens;
        @AuraEnabled public String  errorMessage;
        @AuraEnabled public String  triggerRecordId;
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

    // ─── Public API ──────────────────────────────────────────────────────────

    /**
     * Returns high-level dashboard metrics across all workflows.
     * @param daysBack  Number of days to look back (default 7)
     */
    @AuraEnabled(cacheable=true)
    public static DashboardMetrics getDashboardMetrics(Integer daysBack) {
        AISecurityUtil.assertReadable(AI_Execution__c.SObjectType);

        Integer days = (daysBack != null && daysBack > 0) ? daysBack : 7;
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

        Decimal weightedDur  = 0;
        for (AggregateResult r : results) {
            Integer cnt      = ((Decimal) r.get('cnt')).intValue();
            String  status   = (String)  r.get('status');
            Decimal avgDur   = (Decimal) r.get('avgDur');
            Decimal totalTok = (Decimal) r.get('totalTok');

            m.totalExecutions += cnt;
            if (totalTok  != null) m.totalTokensUsed    += totalTok.intValue();
            if (avgDur    != null) weightedDur           += avgDur * cnt;

            if (status == 'COMPLETED') m.successCount  += cnt;
            else if (status == 'FAILED') m.failedCount += cnt;
            else if (status == 'RUNNING' || status == 'RETRYING') m.runningCount += cnt;
        }

        if (m.totalExecutions > 0) {
            m.avgDurationSeconds = weightedDur / m.totalExecutions;
            m.successRate        = (Decimal) m.successCount / m.totalExecutions * 100;
        }

        return m;
    }

    /**
     * Returns the most recent N executions with workflow name.
     */
    @AuraEnabled(cacheable=false)
    public static List<ExecutionSummary> getRecentExecutions(Integer limitRows) {
        AISecurityUtil.assertReadable(AI_Execution__c.SObjectType);

        Integer lim = (limitRows != null && limitRows > 0) ? Math.min(limitRows, 200) : 20;

        List<AI_Execution__c> recs = [
            SELECT Id, AI_Workflow__r.Name, Status__c, Initiated_By__c,
                   Started_At__c, Completed_At__c, Duration_Seconds__c,
                   Retry_Count__c, Total_Tokens_Used__c, Error_Message__c,
                   Trigger_Record_Id__c
            FROM AI_Execution__c
            ORDER BY CreatedDate DESC
            LIMIT :lim
        ];

        List<ExecutionSummary> summaries = new List<ExecutionSummary>();
        for (AI_Execution__c r : recs) {
            ExecutionSummary s  = new ExecutionSummary();
            s.id               = r.Id;
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
            summaries.add(s);
        }
        return summaries;
    }

    /**
     * Returns token usage aggregated by provider for the last N days.
     */
    @AuraEnabled(cacheable=true)
    public static List<TokenUsageByProvider> getTokenUsageByProvider(Integer daysBack) {
        AISecurityUtil.assertReadable(AI_Step_Execution__c.SObjectType);

        Integer days  = (daysBack != null && daysBack > 0) ? daysBack : 30;
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
            t.providerName    = (String)  r.get('provider');
            t.totalTokens     = r.get('totalTok') != null ? ((Decimal) r.get('totalTok')).intValue() : 0;
            t.executionCount  = ((Decimal) r.get('cnt')).intValue();
            out.add(t);
        }
        return out;
    }

    /**
     * Returns step-level execution detail for a given AI_Execution__c.
     */
    @AuraEnabled(cacheable=false)
    public static List<AI_Step_Execution__c> getStepExecutions(Id executionId) {
        AISecurityUtil.assertReadable(AI_Step_Execution__c.SObjectType);
        return [
            SELECT Id, AI_Step__r.Name, AI_Step__r.Step_Type__c, Status__c,
                   Provider_Used__c, Model_Used__c, Tokens_Used__c,
                   Duration_Ms__c, Error_Message__c, Parsed_Output__c
            FROM AI_Step_Execution__c
            WHERE AI_Execution__c = :executionId
            ORDER BY CreatedDate ASC
        ];
    }
}
