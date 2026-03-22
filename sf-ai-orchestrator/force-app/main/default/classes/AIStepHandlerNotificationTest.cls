@IsTest
private class AIStepHandlerNotificationTest {

    private static AI_Step__c makeStep(String configJson) {
        AI_Step__c step = new AI_Step__c();
        step.Condition__c = configJson;
        step.Order__c     = 1;
        step.Step_Type__c = 'NOTIFICATION';
        return step;
    }

    @IsTest
    static void testSendsEmailSuccessfully() {
        String config = '{"toAddress":"test@example.com","subject":"Test","body":"Hello from workflow"}';
        AI_Step__c step = makeStep(config);
        Test.startTest();
        AIStepResult result = new AIStepHandlerNotification().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.isTrue(result.output.contains('test@example.com'));
    }

    @IsTest
    static void testInterpolatesContextInBody() {
        String config = '{"toAddress":"test@example.com","subject":"Done","body":"Output: {step_1_output}"}';
        AI_Step__c step = makeStep(config);
        Map<String, Object> ctx = new Map<String, Object>{ 'step_1_output' => 'great result' };
        Test.startTest();
        AIStepResult result = new AIStepHandlerNotification().execute(step, ctx, null);
        Test.stopTest();
        Assert.isTrue(result.success);
    }

    @IsTest
    static void testMissingToAddressReturnsFailure() {
        AI_Step__c step = makeStep('{"subject":"Test","body":"Hello"}');
        Test.startTest();
        AIStepResult result = new AIStepHandlerNotification().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
    }

    @IsTest
    static void testInvalidEmailReturnsFailure() {
        AI_Step__c step = makeStep('{"toAddress":"notanemail","subject":"Test","body":"body"}');
        Test.startTest();
        AIStepResult result = new AIStepHandlerNotification().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
    }

    @IsTest
    static void testInvalidJsonReturnsFailure() {
        AI_Step__c step = makeStep('NOT JSON');
        Test.startTest();
        AIStepResult result = new AIStepHandlerNotification().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
    }
}
