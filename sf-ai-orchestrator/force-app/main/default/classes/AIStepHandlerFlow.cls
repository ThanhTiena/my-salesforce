/**
 * AIStepHandlerFlow
 *
 * Launches an Autolaunched Flow for FLOW_LAUNCH steps.
 * Config in step.Condition__c JSON:
 * {
 *   "flowApiName": "My_Autolaunched_Flow",
 *   "inputVariables": { "varName": "value" }
 * }
 */
public with sharing class AIStepHandlerFlow implements AIStepHandler {

    public AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId) {
        Map<String, Object> config;
        try {
            config = (Map<String, Object>) AISecurityUtil.safeDeserialise(step.Condition__c);
        } catch (Exception e) {
            return AIStepResult.fail('FLOW_LAUNCH config is not valid JSON: ' + e.getMessage());
        }

        String flowApiName = (String) config.get('flowApiName');
        if (String.isBlank(flowApiName)) {
            return AIStepResult.fail('FLOW_LAUNCH requires "flowApiName" in Condition__c JSON.');
        }

        // Sanitise: only allow alphanumeric, underscore, dot (namespace)
        if (!Pattern.matches('[A-Za-z][A-Za-z0-9_.]*', flowApiName)) {
            return AIStepResult.fail('Invalid flowApiName: ' + flowApiName);
        }

        Map<String, Object> inputVars = config.containsKey('inputVariables')
            ? (Map<String, Object>) config.get('inputVariables')
            : new Map<String, Object>();

        // Inject triggerRecordId if flow expects it
        if (triggerRecordId != null && !inputVars.containsKey('recordId')) {
            inputVars.put('recordId', triggerRecordId);
        }

        try {
            // Flow.Interview.createInterview accepts Map<String,Object> directly
            Flow.Interview interview = Flow.Interview.createInterview(flowApiName, inputVars);
            interview.start();
            return AIStepResult.ok('Flow ' + flowApiName + ' launched successfully.');
        } catch (Exception e) {
            return AIStepResult.fail('Flow launch failed for ' + flowApiName + ': ' + e.getMessage());
        }
    }
}
