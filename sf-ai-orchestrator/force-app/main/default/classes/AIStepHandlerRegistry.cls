/**
 * AIStepHandlerRegistry
 * Returns the correct AIStepHandler for a given step type.
 * Add new handlers here as new step types are introduced.
 */
public class AIStepHandlerRegistry {

    private static final Map<String, AIStepHandler> REGISTRY = buildRegistry();

    private static Map<String, AIStepHandler> buildRegistry() {
        return new Map<String, AIStepHandler>{
            'DECISION'     => new AIStepHandlerDecision(),
            'HTTP_CALLOUT' => new AIStepHandlerHttp(),
            'APEX_ACTION'  => new AIStepHandlerApex(),
            'FLOW_LAUNCH'  => new AIStepHandlerFlow(),
            'WAIT'         => new AIStepHandlerWait(),
            'NOTIFICATION' => new AIStepHandlerNotification(),
            'START'        => new AIStepHandlerPassthrough(),
            'END'          => new AIStepHandlerPassthrough()
        };
    }

    /**
     * Returns the handler for the given step type.
     * Returns null if no handler is registered (caller falls back to AIInferenceService).
     */
    public static AIStepHandler get(String stepType) {
        return REGISTRY.get(stepType);
    }
}
