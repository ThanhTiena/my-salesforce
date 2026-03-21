/**
 * AIStepHandlerDecision
 *
 * Evaluates the step's Condition__c against the execution context.
 * Supported condition syntax (Phase 3):
 *   CONTEXT_KEY==value           e.g.  sentiment==POSITIVE
 *   LAST_OUTPUT_CONTAINS:keyword e.g.  LAST_OUTPUT_CONTAINS:approved
 *
 * Sets nextBranch to 'SUCCESS' (condition met) or 'FAILURE' (not met).
 */
public with sharing class AIStepHandlerDecision implements AIStepHandler {

    public AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId) {
        String condition = step.Condition__c;
        if (String.isBlank(condition)) {
            return AIStepResult.ok('No condition — defaulting to SUCCESS');
        }

        Boolean met = evaluate(condition.trim(), context);
        AIStepResult result = new AIStepResult();
        result.success    = true;  // DECISION itself always succeeds
        result.output     = 'Condition [' + condition + '] evaluated to: ' + (met ? 'TRUE' : 'FALSE');
        result.nextBranch = met ? 'SUCCESS' : 'FAILURE';
        return result;
    }

    private Boolean evaluate(String condition, Map<String, Object> context) {
        // Mode 1: LAST_OUTPUT_CONTAINS:keyword
        if (condition.startsWithIgnoreCase('LAST_OUTPUT_CONTAINS:')) {
            String keyword = condition.substringAfter(':').trim().toLowerCase();
            // Find the highest-order step output in context
            String lastOutput = getLastOutput(context);
            return String.isNotBlank(lastOutput) && lastOutput.toLowerCase().contains(keyword);
        }

        // Mode 2: CONTEXT_KEY==value
        if (condition.contains('==')) {
            String key   = condition.substringBefore('==').trim();
            String value = condition.substringAfter('==').trim();
            Object ctxVal = context.get(key);
            return ctxVal != null && String.valueOf(ctxVal).trim().equalsIgnoreCase(value);
        }

        // Unknown syntax — treat as false (safe default)
        return false;
    }

    private String getLastOutput(Map<String, Object> context) {
        Integer maxOrder = 0;
        String lastOutput = null;
        for (String key : context.keySet()) {
            if (key.startsWith('step_') && key.endsWith('_output')) {
                String orderStr = key.substringBetween('step_', '_output');
                try {
                    Integer order = Integer.valueOf(orderStr);
                    if (order > maxOrder) {
                        maxOrder   = order;
                        lastOutput = String.valueOf(context.get(key));
                    }
                } catch (Exception e) { /* skip */ }
            }
        }
        return lastOutput;
    }
}
