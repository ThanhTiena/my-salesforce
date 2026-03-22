@IsTest
private class AIStepHandlerHttpTest {

    private class MockSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('{"result":"ok"}');
            return r;
        }
    }

    private class Mock404 implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(404);
            r.setBody('Not found');
            return r;
        }
    }

    private static AI_Step__c makeStep(String configJson) {
        AI_Step__c step = new AI_Step__c();
        step.Condition__c = configJson;
        step.Order__c     = 1;
        step.Step_Type__c = 'HTTP_CALLOUT';
        return step;
    }

    @IsTest
    static void testSuccessfulCallout() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        String config = '{"namedCredential":"AI_OpenAI","path":"/v1/test","method":"GET"}';
        AI_Step__c step = makeStep(config);
        Test.startTest();
        AIStepResult result = new AIStepHandlerHttp().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isTrue(result.success);
        Assert.isTrue(result.output.contains('ok'));
    }

    @IsTest
    static void test404ReturnsFailure() {
        Test.setMock(HttpCalloutMock.class, new Mock404());
        String config = '{"namedCredential":"AI_OpenAI","path":"/v1/bad","method":"GET"}';
        AI_Step__c step = makeStep(config);
        Test.startTest();
        AIStepResult result = new AIStepHandlerHttp().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
        Assert.isTrue(result.errorMessage.contains('404'));
    }

    @IsTest
    static void testMissingConfigReturnsFailure() {
        AI_Step__c step = makeStep(null);
        Test.startTest();
        AIStepResult result = new AIStepHandlerHttp().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
    }

    @IsTest
    static void testInvalidNamedCredentialReturnsFailure() {
        String config = '{"namedCredential":"bad name!","path":"/v1/test"}';
        AI_Step__c step = makeStep(config);
        Test.startTest();
        AIStepResult result = new AIStepHandlerHttp().execute(step, new Map<String, Object>(), null);
        Test.stopTest();
        Assert.isFalse(result.success);
    }

    @IsTest
    static void testContextInterpolationInBody() {
        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        // Use a simple string body (not nested JSON) to avoid double-escape issues
        String config = '{"namedCredential":"AI_OpenAI","path":"/v1/test","method":"POST","body":"value={step_1_output}"}';
        AI_Step__c step = makeStep(config);
        Map<String, Object> ctx = new Map<String, Object>{ 'step_1_output' => 'hello' };
        Test.startTest();
        AIStepResult result = new AIStepHandlerHttp().execute(step, ctx, null);
        Test.stopTest();
        Assert.isTrue(result.success);
    }
}
