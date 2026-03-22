@IsTest
private class AIStepHandlerSubflowTest {

    private static AI_Step__c makeStep(String condition) {
        AI_Step__c step = new AI_Step__c();
        step.Condition__c                  = condition;
        step.Order__c                      = 1;
        step.Step_Type__c                  = 'SUBFLOW';
        step.AI_Provider_Developer_Name__c = 'OpenAI_GPT4o';
        return step;
    }

    @IsTest
    static void testMissingConfig() {
        AI_Step__c step = makeStep(null);
        Test.startTest();
        AIStepResult result = new AIStepHandlerSubflow().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
        Assert.isTrue(result.errorMessage.contains('config missing'));
    }

    @IsTest
    static void testInvalidJson() {
        AI_Step__c step = makeStep('not json');
        Test.startTest();
        AIStepResult result = new AIStepHandlerSubflow().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
        Assert.isTrue(result.errorMessage.contains('JSON invalid'));
    }

    @IsTest
    static void testChildWorkflowNotFound() {
        AI_Step__c step = makeStep('{"childWorkflowName": "NonExistentWorkflow_XYZ"}');
        Test.startTest();
        AIStepResult result = new AIStepHandlerSubflow().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
        Assert.isTrue(result.errorMessage.contains('not found or inactive'));
    }
}
