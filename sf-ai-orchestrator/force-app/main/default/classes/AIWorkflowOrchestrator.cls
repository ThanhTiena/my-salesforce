/**
 * AIWorkflowOrchestrator
 *
 * Orchestrates execution of an AI_Workflow__c — runs each AI_Step__c in order,
 * chains outputs as inputs to subsequent steps, writes results to record fields,
 * and handles retries via Queueable chaining.
 *
 * Security:
 *  - Runs with sharing (respects user's record access)
 *  - CRUD/FLS enforced before every DML operation
 *  - Prompt sanitised before each inference call
 *  - Execution audit records created in System context (without sharing)
 *    using AIWorkflowOrchestrator.SystemWriter inner class
 *
 * @author  AI Orchestration Package
 * @version 1.0
 */
public with sharing class AIWorkflowOrchestrator {

    public class OrchestratorException extends Exception {}

    // ─── Entry Point ─────────────────────────────────────────────────────────

    /**
     * Kicks off a workflow execution asynchronously.
     * Safe to call from triggers (no callout in trigger context).
     *
     * @param workflowId   Id of the AI_Workflow__c record
     * @param triggerRecordId  Id of the record that triggered the workflow
     */
    public static void executeAsync(Id workflowId, Id triggerRecordId) {
        if (workflowId == null) {
            throw new OrchestratorException('workflowId cannot be null');
        }
        System.enqueueJob(new AIWorkflowQueueable(workflowId, triggerRecordId, null, 0));
    }

    /**
     * Synchronous execution for Flow/Process Builder invocations.
     * Only use in contexts that allow callouts (e.g. future methods, queueable).
     */
    public static void executeSync(Id workflowId, Id triggerRecordId) {
        if (workflowId == null) {
            throw new OrchestratorException('workflowId cannot be null');
        }
        runWorkflow(workflowId, triggerRecordId, null, 0);
    }

    // ─── Core Execution Logic ────────────────────────────────────────────────

    /**
     * Executes all active steps of a workflow in order.
     * Each step's output is added to the execution context for subsequent steps.
     */
    public static void runWorkflow(Id workflowId, Id triggerRecordId, Id executionId, Integer retryCount) {

        SystemWriter writer = new SystemWriter();

        // 1. Load workflow + steps
        AI_Workflow__c workflow = loadWorkflow(workflowId);
        List<AI_Step__c> steps = loadSteps(workflowId);

        // 2. Create or reuse execution record
        AI_Execution__c execution;
        if (executionId == null) {
            execution = writer.createExecution(workflow, triggerRecordId);
        } else {
            execution = [SELECT Id, Status__c, Context_JSON__c, Retry_Count__c
                         FROM AI_Execution__c WHERE Id = :executionId LIMIT 1];
        }

        Map<String, Object> context = AISecurityUtil.safeDeserialise(execution.Context_JSON__c);

        // 3. Update status to RUNNING
        writer.updateExecutionStatus(execution.Id, 'RUNNING', null);

        Datetime startTime = Datetime.now();
        Boolean  allPassed = true;
        String   lastError = null;

        try {
            for (AI_Step__c step : steps) {
                if (!step.Is_Active__c) continue;

                AI_Step_Execution__c stepExec = writer.createStepExecution(execution.Id, step.Id);
                Datetime stepStart = Datetime.now();

                // Route to registered handler OR fall back to AI inference
                AIStepHandler handler = AIStepHandlerRegistry.get(step.Step_Type__c);

                AIStepResult stepResult;
                if (handler != null) {
                    // Non-AI step (DECISION, HTTP, APEX, FLOW, WAIT, NOTIFICATION, START, END)
                    stepResult = handler.execute(step, context, triggerRecordId);
                } else {
                    // AI_INFERENCE (and any unregistered type) — use inference service
                    String resolvedPrompt;
                    try {
                        String triggerObj = step.AI_Workflow__r != null ? step.AI_Workflow__r.Trigger_Object__c : null;
                        if (triggerRecordId != null && String.isNotBlank(triggerObj)) {
                            resolvedPrompt = AIPromptTemplateService.resolve(step.Prompt_Template__c, triggerRecordId, triggerObj);
                        } else {
                            Map<String, String> contextStr = new Map<String, String>();
                            for (String k : context.keySet()) { contextStr.put(k, String.valueOf(context.get(k))); }
                            resolvedPrompt = AIPromptTemplateService.resolveWithMap(step.Prompt_Template__c, contextStr);
                        }
                    } catch (Exception e) {
                        writer.failStepExecution(stepExec.Id, 'Prompt resolution failed: ' + e.getMessage());
                        allPassed = false; lastError = e.getMessage(); break;
                    }

                    AIInferenceService.AIInferenceRequest req = new AIInferenceService.AIInferenceRequest();
                    req.providerDeveloperName = step.AI_Provider_Developer_Name__c;
                    req.modelOverride         = step.Model_Override__c;
                    req.systemPrompt          = step.System_Prompt__c;
                    req.userPrompt            = resolvedPrompt;
                    req.temperature           = step.Temperature_Override__c;
                    req.maxTokens             = step.Max_Tokens_Override__c != null ? step.Max_Tokens_Override__c.intValue() : null;
                    req.responseFormat        = step.Response_Format__c;

                    writer.updateStepPrompt(stepExec.Id, resolvedPrompt);
                    AIInferenceService.AIInferenceResponse aiResp = AIInferenceService.run(req);
                    Long dur = Datetime.now().getTime() - stepStart.getTime();

                    if (aiResp.success) {
                        stepResult = AIStepResult.ok(aiResp.content);
                        stepResult.durationMs = dur.intValue();
                        writer.completeStepExecution(stepExec.Id, aiResp, dur.intValue());
                    } else {
                        writer.failStepExecution(stepExec.Id, aiResp.errorMessage);
                        allPassed = false; lastError = aiResp.errorMessage; break;
                    }
                }

                // Process stepResult (from non-AI handler)
                if (handler != null) {
                    Long dur = Datetime.now().getTime() - stepStart.getTime();
                    if (stepResult.success) {
                        if (String.isNotBlank(step.Output_Field__c) && triggerRecordId != null && String.isNotBlank(stepResult.output)) {
                            writeOutputToRecord(triggerRecordId, workflow.Trigger_Object__c, step.Output_Field__c, stepResult.output);
                        }
                        context.put('step_' + step.Order__c + '_output', stepResult.output != null ? stepResult.output : '');
                        context.put('step_' + step.Order__c + '_branch', stepResult.nextBranch != null ? stepResult.nextBranch : 'SUCCESS');
                        writer.completeHandlerStepExecution(stepExec.Id, stepResult, dur.intValue());
                    } else {
                        writer.failStepExecution(stepExec.Id, stepResult.errorMessage);
                        allPassed = false; lastError = stepResult.errorMessage; break;
                    }
                } else {
                    // AI result — context already written above in the else branch
                    if (stepResult.success) {
                        if (String.isNotBlank(step.Output_Field__c) && triggerRecordId != null) {
                            writeOutputToRecord(triggerRecordId, workflow.Trigger_Object__c, step.Output_Field__c, stepResult.output);
                        }
                        context.put('step_' + step.Order__c + '_output', stepResult.output != null ? stepResult.output : '');
                    } else {
                        allPassed = false; lastError = stepResult.errorMessage; break;
                    }
                }
            }
        } catch (Exception e) {
            allPassed = false;
            lastError = e.getMessage();
        }

        Long totalDuration = Datetime.now().getTime() - startTime.getTime();

        if (allPassed) {
            writer.updateExecutionStatus(execution.Id, 'COMPLETED', null);
            writer.updateExecutionDuration(execution.Id, totalDuration, context);
            writer.updateWorkflowStats(workflowId);
        } else {
            Integer maxRetries = workflow.Max_Retries__c != null ? workflow.Max_Retries__c.intValue() : 3;
            if (retryCount < maxRetries) {
                writer.updateExecutionStatus(execution.Id, 'RETRYING', lastError);
                System.enqueueJob(new AIWorkflowQueueable(workflowId, triggerRecordId, execution.Id, retryCount + 1));
            } else {
                writer.updateExecutionStatus(execution.Id, 'FAILED', lastError);
            }
        }
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static AI_Workflow__c loadWorkflow(Id workflowId) {
        AISecurityUtil.assertReadable(AI_Workflow__c.SObjectType);
        List<AI_Workflow__c> wfs = [
            SELECT Id, Name, Trigger_Object__c, Is_Active__c,
                   Max_Retries__c, Retry_Delay_Seconds__c, Total_Executions__c
            FROM AI_Workflow__c
            WHERE Id = :workflowId AND Is_Active__c = true
            LIMIT 1
        ];
        if (wfs.isEmpty()) {
            throw new OrchestratorException('Workflow not found or not active: ' + workflowId);
        }
        return wfs[0];
    }

    private static List<AI_Step__c> loadSteps(Id workflowId) {
        AISecurityUtil.assertReadable(AI_Step__c.SObjectType);
        return [
            SELECT Id, Name, Order__c, Is_Active__c, AI_Provider_Developer_Name__c,
                   Model_Override__c, Prompt_Template__c, System_Prompt__c,
                   Output_Field__c, Temperature_Override__c, Max_Tokens_Override__c,
                   Response_Format__c, Step_Type__c, Condition__c,
                   AI_Workflow__r.Trigger_Object__c
            FROM AI_Step__c
            WHERE AI_Workflow__c = :workflowId
            ORDER BY Order__c ASC
        ];
    }

    /**
     * Writes AI output to a field on the trigger record.
     * Full CRUD + FLS enforcement.
     */
    private static void writeOutputToRecord(Id recordId, String objectName, String fieldName, String value) {
        AISecurityUtil.sanitiseFieldName(fieldName);
        AISecurityUtil.sanitiseObjectName(objectName);

        SObjectType objType = Schema.getGlobalDescribe().get(objectName.toLowerCase());
        if (objType == null) return;

        AISecurityUtil.assertUpdatable(objType);
        AISecurityUtil.assertFieldsWritable(objType, new List<String>{fieldName});

        SObject record = objType.newSObject(recordId);
        record.put(fieldName, value.left(131072)); // Guard against field overflow
        update record;
    }

    // ─── Inner: System-context writer for audit records ──────────────────────

    /**
     * Uses without sharing to write audit/execution records,
     * which the running user may not own but the system must record.
     * This is intentional and documented — audit records need system access.
     */
    private without sharing class SystemWriter {

        AI_Execution__c createExecution(AI_Workflow__c workflow, Id triggerRecordId) {
            AI_Execution__c exec = new AI_Execution__c(
                AI_Workflow__c      = workflow.Id,
                Status__c           = 'PENDING',
                Trigger_Record_Id__c= triggerRecordId != null ? String.valueOf(triggerRecordId) : null,
                Trigger_Object__c   = workflow.Trigger_Object__c,
                Started_At__c       = Datetime.now(),
                Initiated_By__c     = UserInfo.getUserId(),
                Retry_Count__c      = 0
            );
            insert exec;
            return exec;
        }

        void updateExecutionStatus(Id execId, String status, String errorMsg) {
            update new AI_Execution__c(
                Id            = execId,
                Status__c     = status,
                Error_Message__c = errorMsg
            );
        }

        void updateExecutionDuration(Id execId, Long durationMs, Map<String, Object> context) {
            update new AI_Execution__c(
                Id                = execId,
                Completed_At__c   = Datetime.now(),
                Duration_Seconds__c = durationMs / 1000.0,
                Context_JSON__c   = AISecurityUtil.safeSerialise(context)
            );
        }

        void updateWorkflowStats(Id workflowId) {
            AI_Workflow__c wf = [SELECT Id, Total_Executions__c FROM AI_Workflow__c WHERE Id = :workflowId LIMIT 1];
            wf.Total_Executions__c = (wf.Total_Executions__c != null ? wf.Total_Executions__c : 0) + 1;
            wf.Last_Executed__c    = Datetime.now();
            update wf;
        }

        AI_Step_Execution__c createStepExecution(Id executionId, Id stepId) {
            AI_Step_Execution__c se = new AI_Step_Execution__c(
                AI_Execution__c = executionId,
                AI_Step__c      = stepId,
                Status__c       = 'RUNNING'
            );
            insert se;
            return se;
        }

        void updateStepPrompt(Id stepExecId, String prompt) {
            update new AI_Step_Execution__c(
                Id           = stepExecId,
                Prompt_Sent__c = prompt.left(131072)
            );
        }

        void completeStepExecution(Id stepExecId, AIInferenceService.AIInferenceResponse resp, Integer durationMs) {
            update new AI_Step_Execution__c(
                Id                  = stepExecId,
                Status__c           = 'COMPLETED',
                Provider_Used__c    = resp.providerUsed,
                Model_Used__c       = resp.modelUsed,
                Raw_Response__c     = resp.rawResponse != null ? resp.rawResponse.left(131072) : null,
                Parsed_Output__c    = resp.content != null ? resp.content.left(131072) : null,
                Tokens_Used__c      = resp.totalTokens,
                Prompt_Tokens__c    = resp.promptTokens,
                Completion_Tokens__c= resp.completionTokens,
                HTTP_Status_Code__c = resp.httpStatusCode,
                Duration_Ms__c      = durationMs
            );
        }

        void completeHandlerStepExecution(Id stepExecId, AIStepResult result, Integer durationMs) {
            update new AI_Step_Execution__c(
                Id               = stepExecId,
                Status__c        = 'COMPLETED',
                Parsed_Output__c = result.output != null ? result.output.left(131072) : null,
                Error_Message__c = null,
                Duration_Ms__c   = durationMs
            );
        }

        void failStepExecution(Id stepExecId, String errorMsg) {
            update new AI_Step_Execution__c(
                Id            = stepExecId,
                Status__c     = 'FAILED',
                Error_Message__c = errorMsg != null ? errorMsg.left(32768) : null
            );
        }
    }
}
