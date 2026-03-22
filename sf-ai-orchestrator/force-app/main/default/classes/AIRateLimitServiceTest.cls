@IsTest
private class AIRateLimitServiceTest {

    @TestSetup
    static void setup() {
        AIRateLimitService.resetCounts();
    }

    @IsTest
    static void testNoLimitAllowed() {
        AIRateLimitService.resetCounts();
        // rpmLimit = 0 means unlimited — 100 calls must not throw
        for (Integer i = 0; i < 100; i++) {
            AIRateLimitService.checkAndIncrement('TestProvider', 0);
        }
        // Count stays 0 because limit = 0 short-circuits before incrementing
        System.assertEquals(0, AIRateLimitService.getTransactionCount('TestProvider'),
            'Count should remain 0 when rpmLimit is 0 (unlimited)');
    }

    @IsTest
    static void testLimitEnforced() {
        AIRateLimitService.resetCounts();
        Integer rpmLimit = 3;

        // First 3 calls should succeed
        for (Integer i = 0; i < rpmLimit; i++) {
            AIRateLimitService.checkAndIncrement('TestProvider', rpmLimit);
        }
        System.assertEquals(3, AIRateLimitService.getTransactionCount('TestProvider'),
            'Count should be 3 after 3 allowed calls');

        // 4th call must throw RateLimitException
        Boolean exceptionThrown = false;
        try {
            AIRateLimitService.checkAndIncrement('TestProvider', rpmLimit);
        } catch (AIRateLimitService.RateLimitException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Rate limit reached for provider TestProvider'),
                'Exception message should identify the provider');
        }
        System.assert(exceptionThrown, 'RateLimitException should have been thrown on the 4th call');
    }

    @IsTest
    static void testResetCounts() {
        AIRateLimitService.resetCounts();
        // Make 2 calls
        AIRateLimitService.checkAndIncrement('TestProvider', 10);
        AIRateLimitService.checkAndIncrement('TestProvider', 10);
        System.assertEquals(2, AIRateLimitService.getTransactionCount('TestProvider'),
            'Count should be 2 before reset');

        // Reset and verify
        AIRateLimitService.resetCounts();
        System.assertEquals(0, AIRateLimitService.getTransactionCount('TestProvider'),
            'Count should be 0 after resetCounts()');
    }

    @IsTest
    static void testNullLimitAllowed() {
        AIRateLimitService.resetCounts();
        // rpmLimit = null means no limit — must not throw
        AIRateLimitService.checkAndIncrement('TestProvider', null);
        AIRateLimitService.checkAndIncrement('TestProvider', null);
        System.assertEquals(0, AIRateLimitService.getTransactionCount('TestProvider'),
            'Count should remain 0 when rpmLimit is null');
    }
}
