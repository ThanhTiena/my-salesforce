/**
 * AIAdapterAnthropic
 *
 * Adapter for the Anthropic Messages API.
 * Supports: claude-3-5-sonnet, claude-3-opus, claude-3-haiku, claude-3-5-haiku, etc.
 *
 * Wire format (POST /v1/messages):
 * {
 *   "model": "claude-3-5-sonnet-20241022",
 *   "max_tokens": 4096,
 *   "system": "...",
 *   "messages": [{"role":"user","content":"..."}]
 * }
 *
 * Required headers:
 *   anthropic-version: 2023-06-01
 *   x-api-key: {from Named Credential}
 */
public with sharing class AIAdapterAnthropic implements AIProviderAdapter {

    private static final String PROVIDER_TYPE    = 'ANTHROPIC';
    private static final String NAMED_CREDENTIAL = 'AI_Anthropic';
    private static final String PATH             = '/v1/messages';
    private static final String API_VERSION      = '2023-06-01';

    public String getProviderType() {
        return PROVIDER_TYPE;
    }

    public AIInferenceService.AIInferenceResponse inference(
        AIInferenceService.AIInferenceRequest request
    ) {
        String requestBody = buildRequestBody(request);

        Map<String, String> headers = new Map<String, String>{
            'anthropic-version' => API_VERSION
        };

        HttpResponse httpResp = AIInferenceService.callout(
            NAMED_CREDENTIAL,
            PATH,
            'POST',
            headers,
            requestBody,
            120
        );

        return parseResponse(httpResp, request.modelOverride);
    }

    private String buildRequestBody(AIInferenceService.AIInferenceRequest request) {
        List<Map<String, String>> messages = new List<Map<String, String>>{
            new Map<String, String>{'role' => 'user', 'content' => request.userPrompt}
        };

        Map<String, Object> body = new Map<String, Object>{
            'model'      => request.modelOverride,
            'max_tokens' => request.maxTokens != null ? request.maxTokens : 4096,
            'messages'   => messages
        };

        if (String.isNotBlank(request.systemPrompt)) {
            body.put('system', request.systemPrompt);
        }
        if (request.temperature != null) {
            body.put('temperature', request.temperature);
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
                List<Object> content = (List<Object>) parsed.get('content');
                if (content != null && !content.isEmpty()) {
                    Map<String, Object> block = (Map<String, Object>) content[0];
                    resp.content = (String) block.get('text');
                }
                Map<String, Object> usage = (Map<String, Object>) parsed.get('usage');
                if (usage != null) {
                    resp.promptTokens     = Integer.valueOf(usage.get('input_tokens'));
                    resp.completionTokens = Integer.valueOf(usage.get('output_tokens'));
                    resp.totalTokens      = resp.promptTokens + resp.completionTokens;
                }
                resp.success = true;
            } catch (Exception e) {
                resp.success      = false;
                resp.errorMessage = 'Failed to parse Anthropic response: ' + e.getMessage();
            }
        } else {
            resp.success      = false;
            resp.errorMessage = 'Anthropic API error ' + httpResp.getStatusCode() + ': ' + httpResp.getBody();
        }
        return resp;
    }
}
