@IsTest
private class AIStepHandlerWaitTest {

    private static AI_Step__c makeStep(String condition) {
        AI_Step__c step = new AI_Step__c();
        step.Condition__c = condition;
        step.Order__c     = 1;
        step.Step_Type__c = 'WAIT';
        return step;
    }

    @IsTest
    static void testRecordsWaitInContext() {
        AI_Step__c step = makeStep('{"delayMinutes":60}');
        Map<String, Object> ctx = new Map<String, Object>();
        Test.startTest();
        AIStepResult result = new AIStepHandlerWait().execute(step, ctx, null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.areEqual(60, ctx.get('wait_step_1_delay_minutes'));
        Assert.isNotNull(ctx.get('wait_step_1_recorded_at'));
    }

    @IsTest
    static void testNullConditionDefaultsZeroDelay() {
        AI_Step__c step = makeStep(null);
        Map<String, Object> ctx = new Map<String, Object>();
        Test.startTest();
        AIStepResult result = new AIStepHandlerWait().execute(step, ctx, null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.areEqual(0, ctx.get('wait_step_1_delay_minutes'));
    }
}
