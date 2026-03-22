trigger AIExecutionAlertTrigger on AI_Execution__c (after update) {
    AIExecutionAlertHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
}
