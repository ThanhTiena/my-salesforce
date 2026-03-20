/**
 * AIWorkflowQueueable
 *
 * Queueable Apex class that executes AI workflow steps asynchronously.
 * Supports retry chaining with configurable delay.
 *
 * Implements Database.AllowsCallouts so it can perform HTTP callouts to AI APIs.
 *
 * @author  AI Orchestration Package
 * @version 1.0
 */
public with sharing class AIWorkflowQueueable implements Queueable, Database.AllowsCallouts {

    private final Id      workflowId;
    private final Id      triggerRecordId;
    private final Id      executionId;
    private final Integer retryCount;

    public AIWorkflowQueueable(Id workflowId, Id triggerRecordId, Id executionId, Integer retryCount) {
        this.workflowId      = workflowId;
        this.triggerRecordId = triggerRecordId;
        this.executionId     = executionId;
        this.retryCount      = retryCount != null ? retryCount : 0;
    }

    public void execute(QueueableContext context) {
        AIWorkflowOrchestrator.runWorkflow(workflowId, triggerRecordId, executionId, retryCount);
    }
}
