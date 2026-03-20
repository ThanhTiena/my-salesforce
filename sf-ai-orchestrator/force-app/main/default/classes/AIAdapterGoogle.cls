/**
 * AIAdapterGoogle
 *
 * Adapter for the Google Gemini API (Generative Language API).
 * Supports: gemini-1.5-pro, gemini-1.5-flash, gemini-2.0-flash, gemini-2.0-pro, etc.
 *
 * Wire format (POST /v1beta/models/{model}:generateContent):
 * {
 *   "system_instruction": {"parts": [{"text": "..."}]},
 *   "contents": [{"role":"user","parts":[{"text":"..."}]}],
 *   "generationConfig": {"temperature": 0.7, "maxOutputTokens": 4096}
 * }
 */
public with sharing class AIAdapterGoogle implements AIProviderAdapter {

    private static final String PROVIDER_TYPE    = 'GOOGLE';
    private static final String NAMED_CREDENTIAL = 'AI_Google_Gemini';

    public String getProviderType() {
        return PROVIDER_TYPE;
    }

    public AIInferenceService.AIInferenceResponse inference(
        AIInferenceService.AIInferenceRequest request
    ) {
        String path = '/v1beta/models/' + EncodingUtil.urlEncode(request.modelOverride, 'UTF-8')
                    + ':generateContent';

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
        List<Map<String, Object>> parts = new List<Map<String, Object>>{
            new Map<String, Object>{'text' => request.userPrompt}
        };
        List<Map<String, Object>> contents = new List<Map<String, Object>>{
            new Map<String, Object>{'role' => 'user', 'parts' => parts}
        };

        Map<String, Object> body = new Map<String, Object>{
            'contents' => contents
        };

        if (String.isNotBlank(request.systemPrompt)) {
            body.put('system_instruction', new Map<String, Object>{
                'parts' => new List<Map<String, Object>>{
                    new Map<String, Object>{'text' => request.systemPrompt}
                }
            });
        }

        Map<String, Object> genConfig = new Map<String, Object>();
        if (request.temperature != null) {
            genConfig.put('temperature', request.temperature);
        }
        if (request.maxTokens != null) {
            genConfig.put('maxOutputTokens', request.maxTokens);
        }
        if (!genConfig.isEmpty()) {
            body.put('generationConfig', genConfig);
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
                List<Object> candidates = (List<Object>) parsed.get('candidates');
                if (candidates != null && !candidates.isEmpty()) {
                    Map<String, Object> candidate = (Map<String, Object>) candidates[0];
                    Map<String, Object> content   = (Map<String, Object>) candidate.get('content');
                    List<Object> parts = (List<Object>) content.get('parts');
                    if (parts != null && !parts.isEmpty()) {
                        Map<String, Object> part = (Map<String, Object>) parts[0];
                        resp.content = (String) part.get('text');
                    }
                }
                Map<String, Object> usage = (Map<String, Object>) parsed.get('usageMetadata');
                if (usage != null) {
                    resp.promptTokens     = Integer.valueOf(usage.get('promptTokenCount'));
                    resp.completionTokens = Integer.valueOf(usage.get('candidatesTokenCount'));
                    resp.totalTokens      = Integer.valueOf(usage.get('totalTokenCount'));
                }
                resp.success = true;
            } catch (Exception e) {
                resp.success      = false;
                resp.errorMessage = 'Failed to parse Google response: ' + e.getMessage();
            }
        } else {
            resp.success      = false;
            resp.errorMessage = 'Google API error ' + httpResp.getStatusCode() + ': ' + httpResp.getBody();
        }
        return resp;
    }
}
