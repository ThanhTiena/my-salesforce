public with sharing class AIStepHandlerLoop implements AIStepHandler {

    public AIStepResult execute(AI_Step__c step, Map<String, Object> context, Id triggerRecordId) {
        String configJson = step.Condition__c;
        if (String.isBlank(configJson)) {
            return AIStepResult.fail('LOOP config missing in Condition__c');
        }

        Map<String, Object> config;
        try {
            config = (Map<String, Object>) JSON.deserializeUntyped(configJson);
        } catch (Exception e) {
            return AIStepResult.fail('LOOP config JSON invalid: ' + e.getMessage());
        }

        String collectionKey = (String) config.get('collectionKey');
        String itemKey       = (String) config.get('itemKey');
        String indexKey      = (String) config.get('indexKey');

        if (String.isBlank(collectionKey) || String.isBlank(itemKey)) {
            return AIStepResult.fail('LOOP requires collectionKey and itemKey in config');
        }
        if (String.isBlank(indexKey)) indexKey = 'loop_index';

        // Get collection from context
        Object collectionObj = context.get(collectionKey);
        if (collectionObj == null) {
            return AIStepResult.fail('LOOP collection not found in context: ' + collectionKey);
        }

        List<Object> collection;
        try {
            collection = (List<Object>) collectionObj;
        } catch (Exception e) {
            return AIStepResult.fail('LOOP collection is not a list: ' + collectionKey);
        }

        if (collection.isEmpty()) {
            // Empty collection — loop complete, output signals done
            context.put(indexKey, -1);
            context.put(itemKey, null);
            return AIStepResult.ok('LOOP complete — collection empty');
        }

        // Get/advance index
        Integer currentIndex = context.containsKey(indexKey)
            ? Integer.valueOf(String.valueOf(context.get(indexKey))) + 1
            : 0;

        if (currentIndex >= collection.size()) {
            // All items processed
            context.put(indexKey, currentIndex);
            context.put(itemKey, null);
            return AIStepResult.ok('LOOP complete — all ' + collection.size() + ' items processed');
        }

        // Set current item in context
        context.put(indexKey, currentIndex);
        context.put(itemKey, collection[currentIndex]);

        return AIStepResult.ok('LOOP item ' + currentIndex + ' of ' + collection.size());
    }
}
