@IsTest
private class AIStepHandlerDecisionTest {

    private static AI_Step__c makeStep(String condition) {
        // Build a minimal step without DML — we only need Condition__c and Order__c
        AI_Step__c step = new AI_Step__c();
        step.Condition__c = condition;
        step.Order__c     = 1;
        step.Step_Type__c = 'DECISION';
        return step;
    }

    @IsTest
    static void testContextKeyEqualsTrue() {
        AI_Step__c step = makeStep('sentiment==POSITIVE');
        Map<String, Object> ctx = new Map<String, Object>{ 'sentiment' => 'POSITIVE' };
        Test.startTest();
        AIStepResult result = new AIStepHandlerDecision().execute(step, ctx, null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.areEqual('SUCCESS', result.nextBranch);
    }

    @IsTest
    static void testContextKeyEqualsFalse() {
        AI_Step__c step = makeStep('sentiment==POSITIVE');
        Map<String, Object> ctx = new Map<String, Object>{ 'sentiment' => 'NEGATIVE' };
        Test.startTest();
        AIStepResult result = new AIStepHandlerDecision().execute(step, ctx, null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.areEqual('FAILURE', result.nextBranch);
    }

    @IsTest
    static void testLastOutputContainsTrue() {
        AI_Step__c step = makeStep('LAST_OUTPUT_CONTAINS:approved');
        Map<String, Object> ctx = new Map<String, Object>{
            'step_1_output' => 'The request has been approved by manager'
        };
        Test.startTest();
        AIStepResult result = new AIStepHandlerDecision().execute(step, ctx, null);
        Test.stopTest();
        Assert.areEqual('SUCCESS', result.nextBranch);
    }

    @IsTest
    static void testLastOutputContainsFalse() {
        AI_Step__c step = makeStep('LAST_OUTPUT_CONTAINS:approved');
        Map<String, Object> ctx = new Map<String, Object>{
            'step_1_output' => 'Request has been rejected'
        };
        Test.startTest();
        AIStepResult result = new AIStepHandlerDecision().execute(step, ctx, null);
        Test.stopTest();
        Assert.areEqual('FAILURE', result.nextBranch);
    }

    @IsTest
    static void testBlankConditionDefaultsSuccess() {
        AI_Step__c step = makeStep(null);
        Test.startTest();
        AIStepResult result = new AIStepHandlerDecision().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.areEqual('SUCCESS', result.nextBranch);
    }

    @IsTest
    static void testUnknownSyntaxReturnsFalse() {
        AI_Step__c step = makeStep('SOME_UNKNOWN_EXPR>>value');
        Test.startTest();
        AIStepResult result = new AIStepHandlerDecision().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.areEqual('FAILURE', result.nextBranch);
    }
}
