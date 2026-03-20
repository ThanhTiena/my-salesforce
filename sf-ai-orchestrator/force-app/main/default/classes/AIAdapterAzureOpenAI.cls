/**
 * AIAdapterAzureOpenAI
 *
 * Adapter for Azure OpenAI Service.
 * Endpoint pattern: https://{resource}.openai.azure.com/openai/deployments/{deployment}/chat/completions?api-version={version}
 *
 * The Named Credential endpoint should be set to:
 *   https://{your-resource-name}.openai.azure.com
 * The API_Version__c on AI_Provider__mdt should be e.g. "2024-02-01"
 * The DeveloperName should map to a deployment name via the model field.
 */
public with sharing class AIAdapterAzureOpenAI implements AIProviderAdapter {

    private static final String PROVIDER_TYPE    = 'AZURE_OPENAI';
    private static final String NAMED_CREDENTIAL = 'AI_Azure_OpenAI';

    public String getProviderType() {
        return PROVIDER_TYPE;
    }

    public AIInferenceService.AIInferenceResponse inference(
        AIInferenceService.AIInferenceRequest request
    ) {
        // Deployment name = model override field
        String deployment = EncodingUtil.urlEncode(request.modelOverride, 'UTF-8');
        // API version comes via extraParams
        String apiVersion = '2024-02-01';
        if (request.extraParams != null && request.extraParams.containsKey('api_version')) {
            apiVersion = (String) request.extraParams.get('api_version');
        }
        String path = '/openai/deployments/' + deployment + '/chat/completions?api-version=' + apiVersion;

        String requestBody = buildRequestBody(request);

        HttpResponse httpResp = AIInferenceService.callout(
            NAMED_CREDENTIAL,
            path,
            'POST',
            new Map<String, String>(),
            requestBody,
            120
        );

        return parseResponse(httpResp, request.modelOverride);
    }

    private String buildRequestBody(AIInferenceService.AIInferenceRequest request) {
        List<Map<String, String>> messages = new List<Map<String, String>>();
        if (String.isNotBlank(request.systemPrompt)) {
            messages.add(new Map<String, String>{'role' => 'system', 'content' => request.systemPrompt});
        }
        messages.add(new Map<String, String>{'role' => 'user', 'content' => request.userPrompt});

        Map<String, Object> body = new Map<String, Object>{
            'messages'    => messages,
            'temperature' => request.temperature != null ? request.temperature : 0.7,
            'max_tokens'  => request.maxTokens != null ? request.maxTokens : 4096
        };

        if (request.responseFormat == 'JSON') {
            body.put('response_format', new Map<String, String>{'type' => 'json_object'});
        }

        return JSON.serialize(body);
    }

    private AIInferenceService.AIInferenceResponse parseResponse(HttpResponse httpResp, String model) {
        AIInferenceService.AIInferenceResponse resp = new AIInferenceService.AIInferenceResponse();
        resp.httpStatusCode = httpResp.getStatusCode();
        resp.rawResponse    = httpResp.getBody();
        resp.modelUsed      = model;

        if (httpResp.getStatusCode() == 200) {
            try {
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(httpResp.getBody());
                List<Object> choices = (List<Object>) parsed.get('choices');
                if (choices != null && !choices.isEmpty()) {
                    Map<String, Object> choice  = (Map<String, Object>) choices[0];
                    Map<String, Object> message = (Map<String, Object>) choice.get('message');
                    resp.content = (String) message.get('content');
                }
                Map<String, Object> usage = (Map<String, Object>) parsed.get('usage');
                if (usage != null) {
                    resp.promptTokens     = Integer.valueOf(usage.get('prompt_tokens'));
                    resp.completionTokens = Integer.valueOf(usage.get('completion_tokens'));
                    resp.totalTokens      = Integer.valueOf(usage.get('total_tokens'));
                }
                resp.success = true;
            } catch (Exception e) {
                resp.success      = false;
                resp.errorMessage = 'Failed to parse Azure OpenAI response: ' + e.getMessage();
            }
        } else {
            resp.success      = false;
            resp.errorMessage = 'Azure OpenAI error ' + httpResp.getStatusCode() + ': ' + httpResp.getBody();
        }
        return resp;
    }
}
