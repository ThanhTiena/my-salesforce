/**
 * AIExecutionMonitorController
 *
 * Apex controller for the aiExecutionMonitor LWC.
 * Enforces CRUD + FLS via AISecurityUtil before returning any data.
 *
 * with sharing: users only see executions visible to them per sharing rules.
 *
 * @author  AI Orchestration Package
 * @version 1.0
 */
public with sharing class AIExecutionMonitorController {

    @AuraEnabled(cacheable=true)
    public static List<AI_Execution__c> getExecutions(String statusFilter, String searchTerm) {
        AISecurityUtil.assertReadable(AI_Execution__c.SObjectType);

        // Safe filter — statusFilter validated against picklist on query
        String statusClause = '';
        List<String> validStatuses = new List<String>{
            'PENDING','RUNNING','COMPLETED','FAILED','RETRYING','CANCELLED'
        };
        if (String.isNotBlank(statusFilter) && validStatuses.contains(statusFilter.toUpperCase())) {
            statusClause = ' AND Status__c = :statusFilter';
        }

        // Safe search — bind variable, no concatenation
        String searchPattern = '%' + (String.isBlank(searchTerm) ? '' : String.escapeSingleQuotes(searchTerm)) + '%';
        Boolean hasSearch = String.isNotBlank(searchTerm);

        String soql = 'SELECT Id, Name, Status__c, Started_At__c, Completed_At__c, '
                    + '       Duration_Seconds__c, Total_Tokens_Used__c, Error_Message__c, '
                    + '       Retry_Count__c, Trigger_Object__c, Trigger_Record_Id__c, '
                    + '       AI_Workflow__r.Name, Initiated_By__r.Name '
                    + 'FROM AI_Execution__c '
                    + 'WHERE Id != null'
                    + statusClause
                    + (hasSearch ? ' AND AI_Workflow__r.Name LIKE :searchPattern' : '')
                    + ' ORDER BY Started_At__c DESC LIMIT 200';

        return Database.query(soql);
    }

    @AuraEnabled(cacheable=true)
    public static List<AI_Step_Execution__c> getStepExecutions(Id executionId) {
        AISecurityUtil.assertReadable(AI_Step_Execution__c.SObjectType);
        AISecurityUtil.sanitiseRecordId(String.valueOf(executionId));

        return [
            SELECT Id, Name, Status__c, Provider_Used__c, Model_Used__c,
                   Tokens_Used__c, Prompt_Tokens__c, Completion_Tokens__c,
                   HTTP_Status_Code__c, Duration_Ms__c, Error_Message__c,
                   Retry_Attempt__c, AI_Step__c
            FROM AI_Step_Execution__c
            WHERE AI_Execution__c = :executionId
            ORDER BY CreatedDate ASC
        ];
    }
}
