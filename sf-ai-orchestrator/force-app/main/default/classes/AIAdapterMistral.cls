/**
 * AIAdapterMistral
 *
 * Adapter for Mistral AI Chat API.
 * Supports: mistral-large-latest, mistral-small-latest, codestral-latest, etc.
 *
 * Wire format (POST /v1/chat/completions) — OpenAI-compatible:
 * {
 *   "model": "mistral-large-latest",
 *   "messages": [{"role":"system","content":"..."}, {"role":"user","content":"..."}],
 *   "temperature": 0.7,
 *   "max_tokens": 4096
 * }
 */
public with sharing class AIAdapterMistral implements AIProviderAdapter {

    private static final String PROVIDER_TYPE    = 'MISTRAL';
    private static final String NAMED_CREDENTIAL = 'AI_Mistral';
    private static final String PATH             = '/v1/chat/completions';

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
            'temperature' => request.temperature != null ? request.temperature : 0.7,
            'max_tokens'  => request.maxTokens != null ? request.maxTokens : 4096
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
                resp.errorMessage = 'Failed to parse Mistral response: ' + e.getMessage();
            }
        } else {
            resp.success      = false;
            resp.errorMessage = 'Mistral API error ' + httpResp.getStatusCode() + ': ' + httpResp.getBody();
        }
        return resp;
    }
}
