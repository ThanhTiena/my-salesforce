@IsTest
private class AIStepResultTest {

    @IsTest
    static void testOkFactory() {
        Test.startTest();
        AIStepResult r = AIStepResult.ok('my output');
        Test.stopTest();
        Assert.isTrue(r.success);
        Assert.areEqual('my output', r.output);
        Assert.areEqual('SUCCESS', r.nextBranch);
        Assert.isNull(r.errorMessage);
    }

    @IsTest
    static void testFailFactory() {
        Test.startTest();
        AIStepResult r = AIStepResult.fail('something went wrong');
        Test.stopTest();
        Assert.isFalse(r.success);
        Assert.areEqual('something went wrong', r.errorMessage);
        Assert.areEqual('FAILURE', r.nextBranch);
        Assert.isNull(r.output);
    }
}
