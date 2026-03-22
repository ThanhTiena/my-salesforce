public with sharing class AIRateLimitService {

    // Tracks call counts per provider in the current transaction
    private static final Map<String, Integer> TX_COUNTS = new Map<String, Integer>();

    public class RateLimitException extends Exception {}

    /**
     * Call this BEFORE making an inference call.
     * Throws RateLimitException if the provider's per-minute RPM limit would be exceeded
     * within the current transaction.
     *
     * In production, swap TX_COUNTS for Platform Cache (OrgCache) if license available.
     *
     * @param providerDeveloperName  e.g. 'OpenAI_GPT4o'
     * @param rpmLimit               from AI_Provider__mdt.Rate_Limit_RPM__c (0 = no limit)
     */
    public static void checkAndIncrement(String providerDeveloperName, Integer rpmLimit) {
        if (rpmLimit == null || rpmLimit <= 0) return;  // 0 = unlimited

        Integer current = TX_COUNTS.containsKey(providerDeveloperName)
            ? TX_COUNTS.get(providerDeveloperName) : 0;

        if (current >= rpmLimit) {
            throw new RateLimitException(
                'Rate limit reached for provider ' + providerDeveloperName +
                ' (' + rpmLimit + ' RPM). Retry after 1 minute.'
            );
        }
        TX_COUNTS.put(providerDeveloperName, current + 1);
    }

    /** Returns the current transaction call count for a provider (for testing). */
    public static Integer getTransactionCount(String providerDeveloperName) {
        return TX_COUNTS.containsKey(providerDeveloperName)
            ? TX_COUNTS.get(providerDeveloperName) : 0;
    }

    /** Resets all counts — call in @TestSetup or between test methods. */
    @TestVisible
    private static void resetCounts() {
        TX_COUNTS.clear();
    }
}
