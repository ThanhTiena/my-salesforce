/**
 * AIStepHandlerWait
 *
 * Records a wait marker in the execution context.
 * In Phase 3: passes through immediately (no actual delay).
 * Phase 5 will add Scheduled Apex or Platform Events to re-resume.
 *
 * Config in step.Condition__c JSON:
 * { "delayMinutes": 60 }
 */
public with sharing class AIStepHandlerWait implements AIStepHandler {

    public AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId) {
        Integer delayMinutes = 0;
        if (String.isNotBlank(step.Condition__c)) {
            try {
                Map<String, Object> config = (Map<String, Object>) AISecurityUtil.safeDeserialise(step.Condition__c);
                if (config.containsKey('delayMinutes')) {
                    delayMinutes = ((Decimal) config.get('delayMinutes')).intValue();
                }
            } catch (Exception e) { /* ignore — treat as 0 delay */ }
        }

        context.put('wait_step_' + step.Order__c + '_delay_minutes', delayMinutes);
        context.put('wait_step_' + step.Order__c + '_recorded_at', String.valueOf(Datetime.now()));

        return AIStepResult.ok('Wait recorded: ' + delayMinutes + ' minutes (pass-through in Phase 3).');
    }
}
