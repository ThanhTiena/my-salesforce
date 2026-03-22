public with sharing class AIStepHandlerSubflow implements AIStepHandler {

    public AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId) {
        String configJson = step.Condition__c;
        if (String.isBlank(configJson)) {
            return AIStepResult.fail('SUBFLOW config missing in Condition__c');
        }

        Map<String, Object> config;
        try {
            config = (Map<String, Object>) JSON.deserializeUntyped(configJson);
        } catch (Exception e) {
            return AIStepResult.fail('SUBFLOW config JSON invalid: ' + e.getMessage());
        }

        String childWorkflowName = (String) config.get('childWorkflowName');
        if (String.isBlank(childWorkflowName)) {
            return AIStepResult.fail('SUBFLOW childWorkflowName is required');
        }

        // Look up child workflow by name
        List<AI_Workflow__c> workflows = [
            SELECT Id, Name, Is_Active__c
            FROM AI_Workflow__c
            WHERE Name = :childWorkflowName AND Is_Active__c = true
            LIMIT 1
        ];
        if (workflows.isEmpty()) {
            return AIStepResult.fail('SUBFLOW child workflow not found or inactive: ' + childWorkflowName);
        }

        try {
            // Run child workflow asynchronously — context is passed via executeAsync
            AIWorkflowOrchestrator.executeAsync(workflows[0].Id, triggerRecordId);
            return AIStepResult.ok('SUBFLOW started: ' + childWorkflowName);
        } catch (Exception e) {
            return AIStepResult.fail('SUBFLOW execution error: ' + e.getMessage());
        }
    }
}
