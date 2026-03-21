/**
 * AIStepResult
 * Returned by every AIStepHandler implementation.
 */
public class AIStepResult {
    public Boolean  success      { get; set; }
    public String   output       { get; set; }   // written to context + Output_Field__c
    public String   errorMessage { get; set; }
    public String   nextBranch   { get; set; }   // 'SUCCESS' | 'FAILURE' | custom label (for DECISION)
    public Integer  durationMs   { get; set; }

    public static AIStepResult ok(String output) {
        AIStepResult r = new AIStepResult();
        r.success    = true;
        r.output     = output;
        r.nextBranch = 'SUCCESS';
        return r;
    }

    public static AIStepResult fail(String errorMsg) {
        AIStepResult r = new AIStepResult();
        r.success      = false;
        r.errorMessage = errorMsg;
        r.nextBranch   = 'FAILURE';
        return r;
    }
}
