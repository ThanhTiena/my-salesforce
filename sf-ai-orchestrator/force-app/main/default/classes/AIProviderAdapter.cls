/**
 * AIProviderAdapter
 *
 * Interface that every AI provider adapter must implement.
 * The AIInferenceService uses this interface — it never calls provider APIs directly.
 *
 * Request/Response model is provider-agnostic. Each adapter translates to/from
 * the provider's native wire format internally.
 */
public interface AIProviderAdapter {

    /**
     * Sends a prompt to the AI provider and returns a structured response.
     *
     * @param request  AIInferenceRequest – provider-agnostic input
     * @return         AIInferenceResponse – provider-agnostic output
     */
    AIInferenceService.AIInferenceResponse inference(AIInferenceService.AIInferenceRequest request);

    /**
     * Returns the provider type key (e.g. 'OPENAI', 'ANTHROPIC').
     * Must match the Provider_Type__c field on AI_Provider__mdt.
     */
    String getProviderType();
}
