@IsTest
private class WorkflowTemplateServiceTest {

    // ─── Helpers ─────────────────────────────────────────────────────────────

    private static AI_Workflow__c makeTemplateWorkflow() {
        AI_Workflow__c wf = new AI_Workflow__c(
            Name                   = 'Test Template',
            Description__c         = 'A test template workflow',
            Version__c             = 1,
            Is_Active__c           = false,
            Is_Template__c         = true,
            Max_Retries__c         = 3,
            Retry_Delay_Seconds__c = 60
        );
        insert wf;
        return wf;
    }

    private static AI_Step__c makeStep(Id workflowId) {
        AI_Step__c step = new AI_Step__c(
            Name                          = 'Test Step',
            AI_Workflow__c                = workflowId,
            Step_Type__c                  = 'AI_INFERENCE',
            Order__c                      = 1,
            Is_Active__c                  = true,
            AI_Provider_Developer_Name__c = 'OpenAI_GPT4o'
        );
        insert step;
        return step;
    }

    // ─── Test 1: getTemplates ────────────────────────────────────────────────

    @IsTest
    static void testGetTemplates() {
        AI_Workflow__c tmpl = makeTemplateWorkflow();

        // Insert a non-template to confirm it is excluded
        AI_Workflow__c nonTemplate = new AI_Workflow__c(
            Name                   = 'Not A Template',
            Version__c             = 1,
            Is_Active__c           = false,
            Is_Template__c         = false,
            Max_Retries__c         = 3,
            Retry_Delay_Seconds__c = 60
        );
        insert nonTemplate;

        Test.startTest();
        List<AI_Workflow__c> results = WorkflowTemplateService.getTemplates();
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one template');
        System.assertEquals(tmpl.Id, results[0].Id, 'Returned template Id should match');
        System.assertEquals('Test Template', results[0].Name, 'Returned template name should match');
    }

    // ─── Test 2: cloneTemplate ───────────────────────────────────────────────

    @IsTest
    static void testCloneTemplate() {
        AI_Workflow__c tmpl = makeTemplateWorkflow();
        makeStep(tmpl.Id);

        Test.startTest();
        Id newWfId = WorkflowTemplateService.cloneTemplate(tmpl.Id, 'New Name');
        Test.stopTest();

        // Assert workflow was created
        System.assertNotEquals(null, newWfId, 'cloneTemplate should return a non-null Id');

        AI_Workflow__c newWf = [
            SELECT Id, Name, Is_Template__c, Is_Active__c, Max_Retries__c, Retry_Delay_Seconds__c
            FROM AI_Workflow__c
            WHERE Id = :newWfId
        ];
        System.assertEquals('New Name', newWf.Name, 'Cloned workflow name should be "New Name"');
        System.assertEquals(false, newWf.Is_Template__c, 'Cloned workflow should not be a template');
        System.assertEquals(false, newWf.Is_Active__c, 'Cloned workflow should not be active');
        System.assertEquals(3, newWf.Max_Retries__c, 'Max retries should be copied from template');
        System.assertEquals(60, newWf.Retry_Delay_Seconds__c, 'Retry delay should be copied from template');

        // Assert step was cloned
        List<AI_Step__c> clonedSteps = [
            SELECT Id, Name, Step_Type__c, AI_Provider_Developer_Name__c
            FROM AI_Step__c
            WHERE AI_Workflow__c = :newWfId
        ];
        System.assertEquals(1, clonedSteps.size(), 'Expected 1 cloned step');
        System.assertEquals('Test Step', clonedSteps[0].Name, 'Cloned step name should match');
        System.assertEquals('AI_INFERENCE', clonedSteps[0].Step_Type__c, 'Step type should be copied');
        System.assertEquals('OpenAI_GPT4o', clonedSteps[0].AI_Provider_Developer_Name__c, 'Provider should be copied');
    }

    // ─── Test 3: cloneTemplate — blank name throws TemplateException ─────────

    @IsTest
    static void testCloneTemplateBlankName() {
        AI_Workflow__c tmpl = makeTemplateWorkflow();

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            WorkflowTemplateService.cloneTemplate(tmpl.Id, '');
        } catch (WorkflowTemplateService.TemplateException e) {
            exceptionThrown = true;
            System.assert(
                e.getMessage().containsIgnoreCase('blank'),
                'Exception message should mention blank name'
            );
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'TemplateException should have been thrown for blank name');
    }
}
