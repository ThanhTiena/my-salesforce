/**
 * AIStepHandlerApex
 *
 * Dynamically invokes a custom Apex class for APEX_ACTION steps.
 * The target class must implement AIStepHandler.
 *
 * Configuration in step.Condition__c:
 * { "className": "MyCustomHandler" }
 *
 * Security: class name validated — must implement AIStepHandler.
 */
public with sharing class AIStepHandlerApex implements AIStepHandler {

    public AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId) {
        Map<String, Object> config;
        try {
            config = (Map<String, Object>) AISecurityUtil.safeDeserialise(step.Condition__c);
        } catch (Exception e) {
            return AIStepResult.fail('APEX_ACTION config is not valid JSON: ' + e.getMessage());
        }

        String className = (String) config.get('className');
        if (String.isBlank(className)) {
            return AIStepResult.fail('APEX_ACTION requires "className" in Condition__c JSON.');
        }

        // Sanitise: only allow alphanumeric + underscore
        if (!Pattern.matches('[A-Za-z][A-Za-z0-9_]*', className)) {
            return AIStepResult.fail('Invalid className: ' + className);
        }

        Type handlerType = Type.forName(className);
        if (handlerType == null) {
            return AIStepResult.fail('Apex class not found: ' + className);
        }

        Object instance;
        try {
            instance = handlerType.newInstance();
        } catch (Exception e) {
            return AIStepResult.fail('Cannot instantiate ' + className + ': ' + e.getMessage());
        }

        if (!(instance instanceof AIStepHandler)) {
            return AIStepResult.fail(className + ' does not implement AIStepHandler.');
        }

        return ((AIStepHandler) instance).execute(step, context, triggerRecordId);
    }
}
