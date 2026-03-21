/**
 * AIInferenceServiceTest
 * Unit tests for AIInferenceService using mock HTTP callouts.
 */
@IsTest
private class AIInferenceServiceTest {

    private class MockOpenAISuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse resp = new HttpResponse();
            resp.setStatusCode(200);
            resp.setHeader('Content-Type', 'application/json');
            resp.setBody(JSON.serialize(new Map<String, Object>{
                'choices' => new List<Object>{
                    new Map<String, Object>{
                        'message' => new Map<String, Object>{
                            'role'    => 'assistant',
                            'content' => 'Test AI response content'
                        },
                        'finish_reason' => 'stop'
                    }
                },
                'usage' => new Map<String, Object>{
                    'prompt_tokens'     => 10,
                    'completion_tokens' => 20,
                    'total_tokens'      => 30
                },
                'model' => 'gpt-4o'
            }));
            return resp;
        }
    }

    private class MockProviderError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse resp = new HttpResponse();
            resp.setStatusCode(429);
            resp.setBody('{"error":{"message":"Rate limit exceeded","type":"rate_limit_error"}}');
            return resp;
        }
    }

    private class MockAnthropicSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse resp = new HttpResponse();
            resp.setStatusCode(200);
            resp.setBody(JSON.serialize(new Map<String, Object>{
                'content' => new List<Object>{
                    new Map<String, Object>{'type' => 'text', 'text' => 'Anthropic response'}
                },
                'usage' => new Map<String, Object>{
                    'input_tokens'  => 15,
                    'output_tokens' => 25
                },
                'model' => 'claude-3-5-sonnet-20241022'
            }));
            return resp;
        }
    }

    @IsTest
    static void testSanitisesBlankPrompt() {
        AIInferenceService.AIInferenceRequest req = new AIInferenceService.AIInferenceRequest();
        req.providerDeveloperName = 'OpenAI_GPT4o';
        req.userPrompt = '';
        Test.startTest();
        try {
            AIInferenceService.run(req);
            Assert.fail('Should throw for blank prompt');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(e.getMessage().contains('blank'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testNullRequestThrows() {
        Test.startTest();
        try {
            AIInferenceService.run(null);
            Assert.fail('Should throw for null request');
        } catch (AIInferenceService.InferenceException e) {
            Assert.isTrue(e.getMessage().contains('null'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testBlankProviderNameThrows() {
        AIInferenceService.AIInferenceRequest req = new AIInferenceService.AIInferenceRequest();
        req.providerDeveloperName = '';
        req.userPrompt = 'Hello';
        Test.startTest();
        try {
            AIInferenceService.run(req);
            Assert.fail('Should throw for blank provider name');
        } catch (AIInferenceService.ProviderNotFoundException e) {
            Assert.isTrue(true, 'Correctly rejected blank provider name');
        }
        Test.stopTest();
    }

    @IsTest
    static void testCalloutUsesNamedCredential() {
        Test.setMock(HttpCalloutMock.class, new MockOpenAISuccess());
        Test.startTest();
        HttpResponse resp = AIInferenceService.callout('AI_OpenAI', '/v1/chat/completions', 'POST', null, '{"test":1}', 30);
        Test.stopTest();
        Assert.areEqual(200, resp.getStatusCode());
    }

    @IsTest
    static void testCalloutInvalidNamedCredentialNameThrows() {
        String badName = 'bad name!';
        Test.startTest();
        try {
            AIInferenceService.callout(badName, '/v1', 'POST', null, '{}', 30);
            Assert.fail('Should throw for invalid named credential name');
        } catch (AISecurityUtil.InputException e) {
            Assert.isTrue(true, 'Correctly rejected invalid named credential name');
        }
        Test.stopTest();
    }

    @IsTest
    static void testOpenAIAdapterParsesSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockOpenAISuccess());
        AIAdapterOpenAI adapter = new AIAdapterOpenAI();
        Assert.areEqual('OPENAI', adapter.getProviderType());

        AIInferenceService.AIInferenceRequest req = new AIInferenceService.AIInferenceRequest();
        req.providerDeveloperName = 'OpenAI_GPT4o';
        req.userPrompt            = 'Test prompt';
        req.modelOverride         = 'gpt-4o';
        req.temperature           = 0.7;
        req.maxTokens             = 1000;
        req.responseFormat        = 'TEXT';

        Test.startTest();
        AIInferenceService.AIInferenceResponse resp = adapter.inference(req);
        Test.stopTest();

        Assert.isTrue(resp.success);
        Assert.areEqual('Test AI response content', resp.content);
        Assert.areEqual(10, resp.promptTokens);
        Assert.areEqual(20, resp.completionTokens);
        Assert.areEqual(30, resp.totalTokens);
    }

    @IsTest
    static void testOpenAIAdapterHandlesError() {
        Test.setMock(HttpCalloutMock.class, new MockProviderError());
        AIAdapterOpenAI adapter = new AIAdapterOpenAI();

        AIInferenceService.AIInferenceRequest req = new AIInferenceService.AIInferenceRequest();
        req.providerDeveloperName = 'OpenAI_GPT4o';
        req.userPrompt            = 'Test prompt';
        req.modelOverride         = 'gpt-4o';

        Test.startTest();
        AIInferenceService.AIInferenceResponse resp = adapter.inference(req);
        Test.stopTest();

        Assert.isFalse(resp.success);
        Assert.areEqual(429, resp.httpStatusCode);
    }

    @IsTest
    static void testAnthropicAdapterParsesSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockAnthropicSuccess());
        AIAdapterAnthropic adapter = new AIAdapterAnthropic();
        Assert.areEqual('ANTHROPIC', adapter.getProviderType());

        AIInferenceService.AIInferenceRequest req = new AIInferenceService.AIInferenceRequest();
        req.providerDeveloperName = 'Anthropic_Claude';
        req.userPrompt            = 'Test';
        req.modelOverride         = 'claude-3-5-sonnet-20241022';
        req.systemPrompt          = 'You are helpful';

        Test.startTest();
        AIInferenceService.AIInferenceResponse resp = adapter.inference(req);
        Test.stopTest();

        Assert.isTrue(resp.success);
        Assert.areEqual('Anthropic response', resp.content);
        Assert.areEqual(15, resp.promptTokens);
        Assert.areEqual(25, resp.completionTokens);
        Assert.areEqual(40, resp.totalTokens);
    }

    @IsTest
    static void testMistralAdapterProviderType() {
        AIAdapterMistral adapter = new AIAdapterMistral();
        Assert.areEqual('MISTRAL', adapter.getProviderType());
    }

    @IsTest
    static void testCohereAdapterProviderType() {
        AIAdapterCohere adapter = new AIAdapterCohere();
        Assert.areEqual('COHERE', adapter.getProviderType());
    }

    @IsTest
    static void testGoogleAdapterProviderType() {
        AIAdapterGoogle adapter = new AIAdapterGoogle();
        Assert.areEqual('GOOGLE', adapter.getProviderType());
    }

    @IsTest
    static void testAzureOpenAIAdapterProviderType() {
        AIAdapterAzureOpenAI adapter = new AIAdapterAzureOpenAI();
        Assert.areEqual('AZURE_OPENAI', adapter.getProviderType());
    }
}
