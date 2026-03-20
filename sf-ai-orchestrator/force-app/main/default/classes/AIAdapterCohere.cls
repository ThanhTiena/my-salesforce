/**
 * AIAdapterCohere
 *
 * Adapter for Cohere Chat API.
 * Supports: command-r, command-r-plus, command-light, etc.
 *
 * Wire format (POST /v2/chat):
 * {
 *   "model": "command-r-plus",
 *   "messages": [{"role":"system","content":"..."}, {"role":"user","content":"..."}],
 *   "max_tokens": 4096,
 *   "temperature": 0.7
 * }
 */
public with sharing class AIAdapterCohere implements AIProviderAdapter {

    private static final String PROVIDER_TYPE    = 'COHERE';
    private static final String NAMED_CREDENTIAL = 'AI_Cohere';
    private static final String PATH             = '/v2/chat';

    public String getProviderType() {
        return PROVIDER_TYPE;
    }

    public AIInferenceService.AIInferenceResponse inference(
        AIInferenceService.AIInferenceRequest request
    ) {
        String requestBody = buildRequestBody(request);

        HttpResponse httpResp = AIInferenceService.callout(
            NAMED_CREDENTIAL,
            PATH,
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
            'model'       => request.modelOverride,
            'messages'    => messages,
            'max_tokens'  => request.maxTokens != null ? request.maxTokens : 4096,
            'temperature' => request.temperature != null ? request.temperature : 0.7
        };

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
                // Cohere v2 response: message.content[0].text
                Map<String, Object> message = (Map<String, Object>) parsed.get('message');
                if (message != null) {
                    List<Object> content = (List<Object>) message.get('content');
                    if (content != null && !content.isEmpty()) {
                        Map<String, Object> block = (Map<String, Object>) content[0];
                        resp.content = (String) block.get('text');
                    }
                }
                Map<String, Object> usage = (Map<String, Object>) parsed.get('usage');
                if (usage != null) {
                    Map<String, Object> tokens = (Map<String, Object>) usage.get('tokens');
                    if (tokens != null) {
                        resp.promptTokens     = Integer.valueOf(tokens.get('input_tokens'));
                        resp.completionTokens = Integer.valueOf(tokens.get('output_tokens'));
                        resp.totalTokens      = resp.promptTokens + resp.completionTokens;
                    }
                }
                resp.success = true;
            } catch (Exception e) {
                resp.success      = false;
                resp.errorMessage = 'Failed to parse Cohere response: ' + e.getMessage();
            }
        } else {
            resp.success      = false;
            resp.errorMessage = 'Cohere API error ' + httpResp.getStatusCode() + ': ' + httpResp.getBody();
        }
        return resp;
    }
}
