public with sharing class AIStepHandlerPassthrough implements AIStepHandler {
    public AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId) {
        return AIStepResult.ok(step.Step_Type__c);
    }
}
