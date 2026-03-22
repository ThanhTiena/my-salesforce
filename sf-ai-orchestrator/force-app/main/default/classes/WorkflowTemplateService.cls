public with sharing class WorkflowTemplateService {

    public class TemplateException extends Exception {}

    /**
     * Returns all AI_Workflow__c records marked as templates.
     */
    @AuraEnabled(cacheable=true)
    public static List<AI_Workflow__c> getTemplates() {
        AISecurityUtil.assertReadable(AI_Workflow__c.SObjectType);
        return [
            SELECT Id, Name, Description__c, Version__c
            FROM AI_Workflow__c
            WHERE Is_Template__c = true
            ORDER BY Name ASC
        ];
    }

    /**
     * Clones a template workflow (and its steps) into a new active workflow.
     *
     * @param templateId   Id of the template AI_Workflow__c record
     * @param newName      Name for the cloned workflow
     * @return             Id of the newly created workflow
     */
    @AuraEnabled
    public static Id cloneTemplate(Id templateId, String newName) {
        AISecurityUtil.assertReadable(AI_Workflow__c.SObjectType);
        AISecurityUtil.assertCreatable(AI_Workflow__c.SObjectType);
        AISecurityUtil.assertCreatable(AI_Step__c.SObjectType);

        if (String.isBlank(newName)) {
            throw new TemplateException('New workflow name cannot be blank');
        }

        // Load template workflow
        List<AI_Workflow__c> templates = [
            SELECT Id, Name, Description__c, Version__c, Max_Retries__c, Retry_Delay_Seconds__c
            FROM AI_Workflow__c
            WHERE Id = :templateId AND Is_Template__c = true
            LIMIT 1
        ];
        if (templates.isEmpty()) {
            throw new TemplateException('Template not found: ' + templateId);
        }
        AI_Workflow__c template = templates[0];

        // Load template steps
        List<AI_Step__c> templateSteps = [
            SELECT Name, Step_Type__c, Order__c, Is_Active__c, Condition__c,
                   AI_Provider_Developer_Name__c, Model_Override__c, Prompt_Template__c,
                   System_Prompt__c, Output_Field__c, Response_Format__c,
                   Temperature_Override__c, Max_Tokens_Override__c
            FROM AI_Step__c
            WHERE AI_Workflow__c = :templateId
            ORDER BY Order__c ASC
        ];

        // Create new workflow
        AI_Workflow__c newWf = new AI_Workflow__c(
            Name                   = newName,
            Description__c         = template.Description__c,
            Version__c             = 1,
            Is_Active__c           = false,
            Is_Template__c         = false,
            Max_Retries__c         = template.Max_Retries__c,
            Retry_Delay_Seconds__c = template.Retry_Delay_Seconds__c
        );
        insert newWf;

        // Clone steps
        if (!templateSteps.isEmpty()) {
            List<AI_Step__c> newSteps = new List<AI_Step__c>();
            for (AI_Step__c ts : templateSteps) {
                newSteps.add(new AI_Step__c(
                    Name                          = ts.Name,
                    AI_Workflow__c                = newWf.Id,
                    Step_Type__c                  = ts.Step_Type__c,
                    Order__c                      = ts.Order__c,
                    Is_Active__c                  = ts.Is_Active__c,
                    Condition__c                  = ts.Condition__c,
                    AI_Provider_Developer_Name__c = ts.AI_Provider_Developer_Name__c,
                    Model_Override__c             = ts.Model_Override__c,
                    Prompt_Template__c            = ts.Prompt_Template__c,
                    System_Prompt__c              = ts.System_Prompt__c,
                    Output_Field__c               = ts.Output_Field__c,
                    Response_Format__c            = ts.Response_Format__c,
                    Temperature_Override__c       = ts.Temperature_Override__c,
                    Max_Tokens_Override__c        = ts.Max_Tokens_Override__c
                ));
            }
            insert newSteps;
        }

        return newWf.Id;
    }
}
