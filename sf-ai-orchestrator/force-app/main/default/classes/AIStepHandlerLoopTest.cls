@IsTest
private class AIStepHandlerLoopTest {

    private static AI_Workflow__c makeWorkflow() {
        AI_Workflow__c wf = new AI_Workflow__c(
            Name                   = 'Loop Test Workflow',
            Is_Active__c           = true,
            Version__c             = 1,
            Max_Retries__c         = 2,
            Retry_Delay_Seconds__c = 30
        );
        insert wf;
        return wf;
    }

    private static AI_Step__c makeStep(AI_Workflow__c wf, String condition) {
        AI_Step__c step = new AI_Step__c(
            AI_Workflow__c                = wf.Id,
            Name                          = 'Loop Step',
            Order__c                      = 1,
            Step_Type__c                  = 'LOOP',
            AI_Provider_Developer_Name__c = 'OpenAI_GPT4o',
            Is_Active__c                  = true,
            Condition__c                  = condition
        );
        insert step;
        return step;
    }

    @IsTest
    static void testMissingConfig() {
        AI_Workflow__c wf  = makeWorkflow();
        AI_Step__c     step = makeStep(wf, null);
        Test.startTest();
        AIStepResult result = new AIStepHandlerLoop().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
        Assert.isTrue(result.errorMessage.contains('config missing'));
    }

    @IsTest
    static void testEmptyCollection() {
        AI_Workflow__c wf   = makeWorkflow();
        AI_Step__c     step = makeStep(wf, '{"collectionKey":"items","itemKey":"current_item","indexKey":"loop_index"}');
        Map<String, Object> ctx = new Map<String, Object>{
            'items' => new List<Object>()
        };
        Test.startTest();
        AIStepResult result = new AIStepHandlerLoop().execute(step, ctx, null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.isTrue(result.output.contains('empty'));
    }

    @IsTest
    static void testFirstIteration() {
        AI_Workflow__c wf   = makeWorkflow();
        AI_Step__c     step = makeStep(wf, '{"collectionKey":"leads_list","itemKey":"current_item","indexKey":"loop_index"}');
        Map<String, Object> ctx = new Map<String, Object>{
            'leads_list' => new List<Object>{ 'Lead A', 'Lead B', 'Lead C' }
        };
        Test.startTest();
        AIStepResult result = new AIStepHandlerLoop().execute(step, ctx, null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.areEqual(0, ctx.get('loop_index'));
        Assert.areEqual('Lead A', ctx.get('current_item'));
        Assert.isTrue(result.output.contains('0'));
    }

    @IsTest
    static void testLoopComplete() {
        AI_Workflow__c wf   = makeWorkflow();
        AI_Step__c     step = makeStep(wf, '{"collectionKey":"leads_list","itemKey":"current_item","indexKey":"loop_index"}');
        // index is already at last position (2), so advancing to 3 which >= size 3
        Map<String, Object> ctx = new Map<String, Object>{
            'leads_list' => new List<Object>{ 'Lead A', 'Lead B', 'Lead C' },
            'loop_index' => 2
        };
        Test.startTest();
        AIStepResult result = new AIStepHandlerLoop().execute(step, ctx, null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.isTrue(result.output.contains('complete'));
        Assert.isNull(ctx.get('current_item'));
    }
}
