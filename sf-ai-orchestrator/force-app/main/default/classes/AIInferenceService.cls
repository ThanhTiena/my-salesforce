/**
 * AIInferenceService
 *
 * Central orchestration service for all AI inference calls.
 * Routes requests to the correct provider adapter based on AI_Provider__mdt.
 *
 * Security highlights:
 *  - Reads provider config from CMDT (no DML, no sharing concern)
 *  - Never stores or logs API keys
 *  - All HTTP calls use Named Credentials
 *  - Input sanitised before dispatch
 *  - Callout exceptions caught and surfaced as typed exceptions
 *
 * @author  AI Orchestration Package
 * @version 1.0
 */
public with sharing class AIInferenceService {

    // ─── DTOs ────────────────────────────────────────────────────────────────

    public class AIInferenceRequest {
        public String  providerDeveloperName;   // AI_Provider__mdt.DeveloperName
        public String  modelOverride;            // null = use provider default
        public String  systemPrompt;
        public String  userPrompt;
        public Decimal temperature;              // null = use provider default
        public Integer maxTokens;               // null = use provider default
        public String  responseFormat;          // TEXT | JSON
        public Map<String, Object> extraParams; // provider-specific extras
    }

    public class AIInferenceResponse {
        public Boolean success;
        public String  content;          // the AI-generated text
        public String  rawResponse;      // full JSON from the provider
        public Integer promptTokens;
        public Integer completionTokens;
        public Integer totalTokens;
        public Integer httpStatusCode;
        public String  errorMessage;
        public String  modelUsed;
        public String  providerUsed;
    }

    // ─── Exceptions ──────────────────────────────────────────────────────────

    public class ProviderNotFoundException  extends Exception {}
    public class InferenceException         extends Exception {}
    public class RateLimitException         extends Exception {}

    // ─── Provider Registry ───────────────────────────────────────────────────

    private static final Map<String, AIProviderAdapter> ADAPTER_REGISTRY = buildRegistry();

    private static Map<String, AIProviderAdapter> buildRegistry() {
        Map<String, AIProviderAdapter> registry = new Map<String, AIProviderAdapter>();
        registry.put('OPENAI',       new AIAdapterOpenAI());
        registry.put('ANTHROPIC',    new AIAdapterAnthropic());
        registry.put('GOOGLE',       new AIAdapterGoogle());
        registry.put('AZURE_OPENAI', new AIAdapterAzureOpenAI());
        registry.put('COHERE',       new AIAdapterCohere());
        registry.put('MISTRAL',      new AIAdapterMistral());
        return registry;
    }

    // ─── Public API ──────────────────────────────────────────────────────────

    /**
     * Primary entry point for all AI inference calls.
     *
     * @param request  Sanitised inference request
     * @return         Structured response
     */
    public static AIInferenceResponse run(AIInferenceRequest request) {
        // 1. Validate input
        if (request == null) {
            throw new InferenceException('AIInferenceRequest cannot be null');
        }
        request.userPrompt = AISecurityUtil.sanitisePrompt(request.userPrompt);
        if (String.isNotBlank(request.systemPrompt)) {
            request.systemPrompt = AISecurityUtil.sanitisePrompt(request.systemPrompt);
        }

        // 2. Load provider config from CMDT
        AI_Provider__mdt providerConfig = loadProviderConfig(request.providerDeveloperName);

        if (!providerConfig.Is_Active__c) {
            throw new ProviderNotFoundException(
                'AI Provider ' + request.providerDeveloperName + ' is not active'
            );
        }

        // 3. Look up adapter
        String providerType = providerConfig.Provider_Type__c.toUpperCase();
        AIProviderAdapter adapter = ADAPTER_REGISTRY.get(providerType);
        if (adapter == null) {
            throw new ProviderNotFoundException(
                'No adapter registered for provider type: ' + providerType
            );
        }

        // 4. Apply provider defaults where request doesn't override
        applyDefaults(request, providerConfig);

        // 5. Dispatch
        AIInferenceResponse response;
        try {
            response = adapter.inference(request);
        } catch (CalloutException ce) {
            AIInferenceResponse errResp = new AIInferenceResponse();
            errResp.success      = false;
            errResp.errorMessage = 'Callout failed: ' + ce.getMessage();
            errResp.providerUsed = providerType;
            return errResp;
        }

        response.providerUsed = providerType;
        return response;
    }

    // ─── Private Helpers ─────────────────────────────────────────────────────

    private static AI_Provider__mdt loadProviderConfig(String developerName) {
        if (String.isBlank(developerName)) {
            throw new ProviderNotFoundException('Provider developer name cannot be blank');
        }
        // CMDT queries are safe from sharing/FLS concerns (metadata, not data)
        List<AI_Provider__mdt> configs = [
            SELECT DeveloperName, Label, Endpoint_URL__c, Named_Credential_API_Name__c,
                   Default_Model__c, Provider_Type__c, Max_Tokens__c, Temperature__c,
                   Rate_Limit_RPM__c, Rate_Limit_TPM__c, Is_Active__c, API_Version__c,
                   Timeout_Seconds__c, Supports_Streaming__c, Custom_Headers_JSON__c
            FROM AI_Provider__mdt
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        if (configs.isEmpty()) {
            throw new ProviderNotFoundException(
                'No AI_Provider__mdt record found for: ' + developerName
            );
        }
        return configs[0];
    }

    private static void applyDefaults(AIInferenceRequest req, AI_Provider__mdt config) {
        if (String.isBlank(req.modelOverride)) {
            req.modelOverride = config.Default_Model__c;
        }
        if (req.temperature == null && config.Temperature__c != null) {
            req.temperature = config.Temperature__c;
        }
        if (req.maxTokens == null && config.Max_Tokens__c != null) {
            req.maxTokens = config.Max_Tokens__c.intValue();
        }
        if (String.isBlank(req.responseFormat)) {
            req.responseFormat = 'TEXT';
        }
    }

    // ─── Shared HTTP Helper ──────────────────────────────────────────────────

    /**
     * Executes an HTTP callout using a Named Credential.
     * All provider adapters must use this method — direct Http.send() is forbidden.
     *
     * @param namedCredentialName  e.g. 'AI_OpenAI'
     * @param path                 e.g. '/v1/chat/completions'
     * @param method               'POST' | 'GET'
     * @param headers              additional HTTP headers (do not include Authorization)
     * @param body                 JSON request body
     * @param timeoutMs            milliseconds
     */
    public static HttpResponse callout(
        String namedCredentialName,
        String path,
        String method,
        Map<String, String> headers,
        String body,
        Integer timeoutMs
    ) {
        AISecurityUtil.sanitiseNamedCredentialName(namedCredentialName);

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + namedCredentialName + path);
        req.setMethod(method);
        req.setTimeout(timeoutMs != null ? timeoutMs * 1000 : 120000);
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');

        if (headers != null) {
            for (String key : headers.keySet()) {
                req.setHeader(key, headers.get(key));
            }
        }
        if (String.isNotBlank(body)) {
            req.setBody(body);
        }

        Http http = new Http();
        return http.send(req);
    }
}
