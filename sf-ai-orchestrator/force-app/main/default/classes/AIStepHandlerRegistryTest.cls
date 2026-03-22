@IsTest
private class AIStepHandlerRegistryTest {

    @IsTest
    static void testRegisteredTypes() {
        // Registered types must return a non-null handler
        List<String> registered = new List<String>{
            'DECISION', 'HTTP_CALLOUT', 'APEX_ACTION', 'FLOW_LAUNCH',
            'WAIT', 'NOTIFICATION', 'START', 'END'
        };
        Test.startTest();
        for (String t : registered) {
            AIStepHandler h = AIStepHandlerRegistry.get(t);
            Assert.isNotNull(h, 'Expected handler for: ' + t);
        }
        Test.stopTest();
    }

    @IsTest
    static void testAiInferenceNotRegistered() {
        // AI_INFERENCE falls through to the inference service — registry must return null
        Test.startTest();
        AIStepHandler h = AIStepHandlerRegistry.get('AI_INFERENCE');
        Test.stopTest();
        Assert.isNull(h, 'AI_INFERENCE must not be in registry');
    }

    @IsTest
    static void testUnknownTypeReturnsNull() {
        Test.startTest();
        AIStepHandler h = AIStepHandlerRegistry.get('TOTALLY_UNKNOWN');
        Test.stopTest();
        Assert.isNull(h);
    }
}
