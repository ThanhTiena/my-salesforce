/**
 * AIExecutionAlertHandler
 *
 * Fires an email notification when an AI_Execution__c record transitions to
 * FAILED status. Also tracks consecutive failure counts and logs a warning
 * when 3+ consecutive failures occur for the same workflow.
 */
public with sharing class AIExecutionAlertHandler {

    private static final Integer CONSECUTIVE_THRESHOLD = 3;

    public static void handleAfterUpdate(
        List<AI_Execution__c> newRecords,
        Map<Id, AI_Execution__c> oldMap
    ) {
        List<AI_Execution__c> newFailures = new List<AI_Execution__c>();
        for (AI_Execution__c exec : newRecords) {
            AI_Execution__c old = oldMap.get(exec.Id);
            if (exec.Status__c == 'FAILED' && old.Status__c != 'FAILED') {
                newFailures.add(exec);
            }
        }
        if (newFailures.isEmpty()) return;

        // Collect workflow IDs that have notification emails configured
        Set<Id> workflowIds = new Set<Id>();
        for (AI_Execution__c e : newFailures) {
            if (e.AI_Workflow__c != null) workflowIds.add(e.AI_Workflow__c);
        }

        Map<Id, AI_Workflow__c> workflowMap = new Map<Id, AI_Workflow__c>([
            SELECT Id, Name, Notification_Email__c
            FROM AI_Workflow__c
            WHERE Id IN :workflowIds
        ]);

        // Count consecutive failures per workflow (last 10 executions)
        Map<Id, Integer> consecutiveCounts = countConsecutiveFailures(workflowIds);

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (AI_Execution__c exec : newFailures) {
            AI_Workflow__c wf = workflowMap.get(exec.AI_Workflow__c);
            if (wf == null || String.isBlank(wf.Notification_Email__c)) continue;

            Integer consecutive = consecutiveCounts.get(exec.AI_Workflow__c) ?? 0;
            String subject = consecutive >= CONSECUTIVE_THRESHOLD
                ? '[ALERT] ' + consecutive + ' consecutive failures — ' + wf.Name
                : '[FAILED] AI Workflow execution failed — ' + wf.Name;

            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new List<String>{ wf.Notification_Email__c });
            msg.setSubject(subject);
            msg.setPlainTextBody(
                'Workflow: '  + wf.Name + '\n' +
                'Execution: ' + exec.Id + '\n' +
                'Status: FAILED\n' +
                (consecutive >= CONSECUTIVE_THRESHOLD
                    ? '\nWARNING: ' + consecutive + ' consecutive failures detected. Manual intervention may be required.\n'
                    : '') +
                '\nView in Salesforce: ' + URL.getOrgDomainUrl().toExternalForm() + '/' + exec.Id
            );
            msg.setSaveAsActivity(false);
            emails.add(msg);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false); // false = don't throw on partial failure
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'AIExecutionAlertHandler.sendEmail failed: ' + e.getMessage());
            }
        }
    }

    private static Map<Id, Integer> countConsecutiveFailures(Set<Id> workflowIds) {
        Map<Id, Integer> counts = new Map<Id, Integer>();

        // Get last 10 executions per workflow, ordered newest first
        List<AI_Execution__c> recent = [
            SELECT Id, AI_Workflow__c, Status__c
            FROM AI_Execution__c
            WHERE AI_Workflow__c IN :workflowIds
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];

        // Group by workflow
        Map<Id, List<AI_Execution__c>> byWorkflow = new Map<Id, List<AI_Execution__c>>();
        for (AI_Execution__c e : recent) {
            if (!byWorkflow.containsKey(e.AI_Workflow__c)) {
                byWorkflow.put(e.AI_Workflow__c, new List<AI_Execution__c>());
            }
            byWorkflow.get(e.AI_Workflow__c).add(e);
        }

        for (Id wfId : byWorkflow.keySet()) {
            Integer count = 0;
            for (AI_Execution__c e : byWorkflow.get(wfId)) {
                if (e.Status__c == 'FAILED') count++;
                else break; // stop at first non-failure
            }
            counts.put(wfId, count);
        }
        return counts;
    }
}
