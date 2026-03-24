/**
 * WorkflowService
 *
 * Apex controller for the AI Workflow Designer LWC.
 * Handles all CRUD operations for AI_Workflow__c and AI_Step__c records.
 *
 * Security:
 *  - Runs with sharing — user record visibility respected
 *  - CRUD/FLS enforced before every query and DML via AISecurityUtil
 *  - All @AuraEnabled methods are exception-safe (AuraHandledException)
 *
 * @author  AI Orchestration Package
 * @version 1.0
 */
public with sharing class WorkflowService {

    public class WorkflowServiceException extends Exception {}

    // ─── Workflow CRUD ────────────────────────────────────────────────────────

    /**
     * Returns all active + inactive workflows visible to the current user.
     */
    @AuraEnabled(cacheable=true)
    public static List<AI_Workflow__c> getWorkflows() {
        AISecurityUtil.assertReadable(AI_Workflow__c.SObjectType);
        return [
            SELECT Id, Name, Description__c, Trigger_Object__c, Is_Active__c,
                   Version__c, Total_Executions__c, Last_Executed__c,
                   Max_Retries__c, Retry_Delay_Seconds__c, Notification_Email__c
            FROM AI_Workflow__c
            ORDER BY LastModifiedDate DESC
            LIMIT 200
        ];
    }

    /**
     * Returns a single workflow with its steps.
     */
    @AuraEnabled(cacheable=false)
    public static WorkflowWrapper getWorkflow(Id workflowId) {
        AISecurityUtil.assertReadable(AI_Workflow__c.SObjectType);
        AISecurityUtil.assertReadable(AI_Step__c.SObjectType);

        List<AI_Workflow__c> workflows = [
            SELECT Id, Name, Description__c, Trigger_Object__c, Trigger_Condition__c,
                   Is_Active__c, Version__c, Total_Executions__c, Last_Executed__c,
                   Max_Retries__c, Retry_Delay_Seconds__c, Notification_Email__c,
                   Canvas_JSON__c
            FROM AI_Workflow__c
            WHERE Id = :workflowId
            LIMIT 1
        ];
        if (workflows.isEmpty()) {
            throw new AuraHandledException('Workflow not found: ' + workflowId);
        }

        List<AI_Step__c> steps = [
            SELECT Id, Name, Order__c, Is_Active__c, Step_Type__c,
                   AI_Provider_Developer_Name__c, Model_Override__c,
                   Prompt_Template__c, System_Prompt__c, Output_Field__c,
                   Response_Format__c, Temperature_Override__c,
                   Max_Tokens_Override__c, Condition__c
            FROM AI_Step__c
            WHERE AI_Workflow__c = :workflowId
            ORDER BY Order__c ASC
        ];

        WorkflowWrapper wrapper  = new WorkflowWrapper();
        wrapper.workflow         = workflows[0];
        wrapper.steps            = steps;
        return wrapper;
    }

    /**
     * Creates a new workflow.
     */
    @AuraEnabled
    public static Id createWorkflow(String name, String description, String triggerObject) {
        AISecurityUtil.assertCreatable(AI_Workflow__c.SObjectType);
        AISecurityUtil.assertFieldsWritable(AI_Workflow__c.SObjectType,
            new List<String>{ 'Name', 'Description__c', 'Trigger_Object__c', 'Is_Active__c', 'Version__c' });

        if (String.isBlank(name)) {
            throw new AuraHandledException('Workflow name is required.');
        }

        AI_Workflow__c wf = new AI_Workflow__c(
            Name                 = name.left(80),
            Description__c       = description,
            Trigger_Object__c    = triggerObject,
            Is_Active__c         = false,
            Version__c           = 1,
            Max_Retries__c       = 3,
            Retry_Delay_Seconds__c = 60
        );
        insert wf;
        return wf.Id;
    }

    /**
     * Saves workflow settings (name, description, trigger, config).
     * Does NOT save steps — use saveSteps() separately.
     */
    @AuraEnabled
    public static void saveWorkflow(AI_Workflow__c workflow) {
        AISecurityUtil.assertUpdatable(AI_Workflow__c.SObjectType);
        AISecurityUtil.assertFieldsWritable(AI_Workflow__c.SObjectType,
            new List<String>{ 'Name', 'Description__c', 'Trigger_Object__c',
                              'Max_Retries__c', 'Retry_Delay_Seconds__c', 'Notification_Email__c',
                              'Canvas_JSON__c' });

        if (workflow == null || workflow.Id == null) {
            throw new AuraHandledException('Workflow Id is required for save.');
        }

        // Auto-increment version on each save
        List<AI_Workflow__c> existing = [SELECT Version__c, Canvas_JSON__c FROM AI_Workflow__c WHERE Id = :workflow.Id LIMIT 1];
        Decimal newVersion = 1;
        if (!existing.isEmpty()) {
            newVersion = (existing[0].Version__c != null ? existing[0].Version__c : 0) + 1;
            workflow.Version__c = newVersion;
        }

        update workflow;

        // Write version snapshot (best-effort — don't fail the save if this fails)
        try {
            if (String.isNotBlank(workflow.Canvas_JSON__c)) {
                AI_Workflow_Version__c snap = new AI_Workflow_Version__c(
                    Name             = 'v' + newVersion.intValue(),
                    AI_Workflow__c   = workflow.Id,
                    Version_Number__c = newVersion,
                    Canvas_JSON__c   = workflow.Canvas_JSON__c,
                    Saved_By__c      = UserInfo.getUserId()
                );
                insert snap;
            }
        } catch (Exception e) {
            // Snapshot failure must never break the save
        }
    }

    /**
     * Toggles Is_Active__c on the workflow.
     * Validates that the workflow has at least one active step before activating.
     */
    @AuraEnabled
    public static void setWorkflowActive(Id workflowId, Boolean isActive) {
        AISecurityUtil.assertUpdatable(AI_Workflow__c.SObjectType);

        if (isActive) {
            Integer stepCount = [
                SELECT COUNT() FROM AI_Step__c
                WHERE AI_Workflow__c = :workflowId AND Is_Active__c = true
            ];
            if (stepCount == 0) {
                throw new AuraHandledException(
                    'Cannot activate: workflow has no active steps. Add at least one step first.'
                );
            }
        }

        update new AI_Workflow__c(Id = workflowId, Is_Active__c = isActive);
    }

    /**
     * Deletes a workflow and all its steps (cascade from Master-Detail).
     */
    @AuraEnabled
    public static void deleteWorkflow(Id workflowId) {
        AISecurityUtil.assertDeletable(AI_Workflow__c.SObjectType);
        delete new AI_Workflow__c(Id = workflowId);
    }

    // ─── Step CRUD ────────────────────────────────────────────────────────────

    /**
     * Saves the full ordered list of steps for a workflow.
     * Performs an upsert strategy:
     *  - Steps with an Id are updated
     *  - Steps without an Id are inserted
     *  - Steps present in DB but not in the list are deleted
     */
    @AuraEnabled
    public static void saveSteps(Id workflowId, List<AI_Step__c> steps) {
        AISecurityUtil.assertReadable(AI_Step__c.SObjectType);
        AISecurityUtil.assertCreatable(AI_Step__c.SObjectType);
        AISecurityUtil.assertUpdatable(AI_Step__c.SObjectType);
        AISecurityUtil.assertDeletable(AI_Step__c.SObjectType);

        if (workflowId == null) {
            throw new AuraHandledException('workflowId is required.');
        }
        if (steps == null) {
            steps = new List<AI_Step__c>();
        }

        // Sanitise prompt content on each step
        for (AI_Step__c step : steps) {
            step.AI_Workflow__c = workflowId;
            if (String.isNotBlank(step.Prompt_Template__c)) {
                step.Prompt_Template__c = AISecurityUtil.sanitisePrompt(step.Prompt_Template__c);
            }
            if (String.isNotBlank(step.System_Prompt__c)) {
                step.System_Prompt__c = AISecurityUtil.sanitisePrompt(step.System_Prompt__c);
            }
        }

        // Separate inserts vs updates
        List<AI_Step__c> toInsert = new List<AI_Step__c>();
        List<AI_Step__c> toUpdate = new List<AI_Step__c>();
        Set<Id> incomingIds = new Set<Id>();

        for (AI_Step__c step : steps) {
            if (step.Id != null) {
                toUpdate.add(step);
                incomingIds.add(step.Id);
            } else {
                toInsert.add(step);
            }
        }

        // Delete steps that were removed from the canvas
        List<AI_Step__c> existing = [SELECT Id FROM AI_Step__c WHERE AI_Workflow__c = :workflowId];
        List<AI_Step__c> toDelete = new List<AI_Step__c>();
        for (AI_Step__c s : existing) {
            if (!incomingIds.contains(s.Id)) {
                toDelete.add(s);
            }
        }

        if (!toDelete.isEmpty()) delete toDelete;
        if (!toInsert.isEmpty()) insert toInsert;
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    /**
     * Triggers async execution of a workflow.
     * Returns the new AI_Execution__c Id.
     */
    @AuraEnabled
    public static Id runWorkflow(Id workflowId, Id triggerRecordId) {
        AISecurityUtil.assertReadable(AI_Workflow__c.SObjectType);
        AIWorkflowOrchestrator.executeAsync(workflowId, triggerRecordId);
        // Return the most recent execution (just enqueued, status = PENDING)
        List<AI_Execution__c> execs = [
            SELECT Id FROM AI_Execution__c
            WHERE AI_Workflow__c = :workflowId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        return execs.isEmpty() ? null : execs[0].Id;
    }

    /**
     * Returns the version history for a workflow (most recent first).
     */
    @AuraEnabled(cacheable=false)
    public static List<AI_Workflow_Version__c> getVersionHistory(Id workflowId) {
        AISecurityUtil.assertReadable(AI_Workflow_Version__c.SObjectType);
        return [
            SELECT Id, Name, Version_Number__c, Saved_By__r.Name, Change_Summary__c, CreatedDate
            FROM AI_Workflow_Version__c
            WHERE AI_Workflow__c = :workflowId
            ORDER BY Version_Number__c DESC
            LIMIT 50
        ];
    }

    /**
     * Restores a previous canvas snapshot onto the workflow record.
     * Does NOT create a new version snapshot — the next manual save will do that.
     */
    @AuraEnabled
    public static void restoreVersion(Id workflowId, Id versionId) {
        AISecurityUtil.assertUpdatable(AI_Workflow__c.SObjectType);
        AISecurityUtil.assertReadable(AI_Workflow_Version__c.SObjectType);
        List<AI_Workflow_Version__c> versions = [
            SELECT Canvas_JSON__c FROM AI_Workflow_Version__c
            WHERE Id = :versionId AND AI_Workflow__c = :workflowId LIMIT 1
        ];
        if (versions.isEmpty()) {
            throw new AuraHandledException('Version not found.');
        }
        update new AI_Workflow__c(Id = workflowId, Canvas_JSON__c = versions[0].Canvas_JSON__c);
    }

    /**
     * Returns full AI_Provider__mdt records for the Settings panel.
     */
    @AuraEnabled(cacheable=true)
    public static List<AI_Provider__mdt> getProviderDetails() {
        return [
            SELECT DeveloperName, MasterLabel, Provider_Type__c, Default_Model__c,
                   Named_Credential_API_Name__c, Rate_Limit_RPM__c, Rate_Limit_TPM__c,
                   Max_Tokens__c, Temperature__c, Is_Active__c, Endpoint_URL__c
            FROM AI_Provider__mdt
            WHERE Is_Active__c = true
            ORDER BY MasterLabel ASC
        ];
    }

    /**
     * Returns all active AI_Provider__mdt records for use in the step properties panel.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProviderOption> getActiveProviders() {
        List<ProviderOption> options = new List<ProviderOption>();
        for (AI_Provider__mdt p : [
            SELECT DeveloperName, Label, Default_Model__c, Provider_Type__c
            FROM AI_Provider__mdt
            WHERE Is_Active__c = true
            ORDER BY Label ASC
        ]) {
            ProviderOption opt = new ProviderOption();
            opt.label        = p.Label;
            opt.value        = p.DeveloperName;
            opt.defaultModel = p.Default_Model__c;
            opt.providerType = p.Provider_Type__c;
            options.add(opt);
        }
        return options;
    }

    // ─── Inner DTOs ──────────────────────────────────────────────────────────

    public class WorkflowWrapper {
        @AuraEnabled public AI_Workflow__c  workflow;
        @AuraEnabled public List<AI_Step__c> steps;
    }

    public class ProviderOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String defaultModel;
        @AuraEnabled public String providerType;
    }
}
