@IsTest
private class AIStepHandlerPassthroughTest {

    @IsTest
    static void testStartReturnsSuccess() {
        AI_Step__c step = new AI_Step__c(Step_Type__c = 'START', Order__c = 1);
        Test.startTest();
        AIStepResult result = new AIStepHandlerPassthrough().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.areEqual('SUCCESS', result.nextBranch);
    }

    @IsTest
    static void testEndReturnsSuccess() {
        AI_Step__c step = new AI_Step__c(Step_Type__c = 'END', Order__c = 2);
        Test.startTest();
        AIStepResult result = new AIStepHandlerPassthrough().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isTrue(result.success);
    }
}
