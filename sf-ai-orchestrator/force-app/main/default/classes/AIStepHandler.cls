/**
 * AIStepHandler
 * Interface for all non-AI step type handlers.
 * Each implementation handles one Step_Type__c value.
 */
public interface AIStepHandler {
    /**
     * Execute the step.
     * @param step     The AI_Step__c record for this step
     * @param context  Mutable execution context map (read previous outputs, write new ones)
     * @param triggerRecordId  The record that triggered the workflow (may be null)
     * @return AIStepResult
     */
    AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId);
}
