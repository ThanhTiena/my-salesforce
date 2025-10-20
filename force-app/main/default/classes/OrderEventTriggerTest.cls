/**
 * Test class for OrderEventTrigger
 * This test class provides coverage for the platform event trigger that creates Tasks
 * when Order_Event__e platform events are published with Has_Shipped__c = true
 */
@IsTest
public class OrderEventTriggerTest {

    /**
     * Test that Tasks are created when Order_Event__e is published with Has_Shipped__c = true
     * This tests the main functionality of OrderEventTrigger
     */
    @IsTest
    static void testOrderEventCreatesTask() {
        // Start test context
        Test.startTest();

        // Create and publish a platform event with Has_Shipped__c = true
        Order_Event__e orderEvent = new Order_Event__e(
            Has_Shipped__c = true
        );

        // Publish the platform event
        Database.SaveResult result = EventBus.publish(orderEvent);

        // Stop test context - this is when platform event triggers fire
        Test.stopTest();

        // Verify the event was published successfully
        System.assertEquals(true, result.isSuccess(), 'Order Event should be published successfully');

        // Query for Tasks created by the trigger
        List<Task> createdTasks = [
            SELECT Id, Subject, Priority, OwnerId
            FROM Task
            WHERE Subject = 'Follow up on shipped order 105'
        ];

        // Verify that at least one Task was created
        System.assertNotEquals(0, createdTasks.size(), 'At least one Task should be created');

        // Verify Task properties
        Task createdTask = createdTasks[0];
        System.assertEquals('Medium', createdTask.Priority, 'Task priority should be Medium');
        System.assertEquals('Follow up on shipped order 105', createdTask.Subject, 'Task subject should match');
    }

    /**
     * Test that no Tasks are created when Order_Event__e is published with Has_Shipped__c = false
     * This ensures the trigger only processes events that meet the criteria
     */
    @IsTest
    static void testOrderEventWithoutShippingDoesNotCreateTask() {
        // Start test context
        Test.startTest();

        // Create and publish a platform event with Has_Shipped__c = false
        Order_Event__e orderEvent = new Order_Event__e(
            Has_Shipped__c = false
        );

        // Publish the platform event
        Database.SaveResult result = EventBus.publish(orderEvent);

        // Stop test context
        Test.stopTest();

        // Verify the event was published successfully
        System.assertEquals(true, result.isSuccess(), 'Order Event should be published successfully');

        // Query for Tasks - there should be none since Has_Shipped__c = false
        List<Task> createdTasks = [
            SELECT Id
            FROM Task
            WHERE Subject = 'Follow up on shipped order 105'
        ];

        // Verify no Tasks were created
        System.assertEquals(0, createdTasks.size(), 'No Tasks should be created when Has_Shipped__c is false');
    }

    /**
     * Test bulk processing of multiple Order_Event__e platform events
     * This ensures the trigger can handle multiple events efficiently
     */
    @IsTest
    static void testBulkOrderEvents() {
        // Start test context
        Test.startTest();

        // Create multiple platform events
        List<Order_Event__e> orderEvents = new List<Order_Event__e>();
        for (Integer i = 0; i < 5; i++) {
            orderEvents.add(new Order_Event__e(Has_Shipped__c = true));
        }

        // Add some events with Has_Shipped__c = false to test filtering
        for (Integer i = 0; i < 3; i++) {
            orderEvents.add(new Order_Event__e(Has_Shipped__c = false));
        }

        // Publish all events
        List<Database.SaveResult> results = EventBus.publish(orderEvents);

        // Stop test context
        Test.stopTest();

        // Verify all events were published successfully
        for (Database.SaveResult result : results) {
            System.assertEquals(true, result.isSuccess(), 'All Order Events should be published successfully');
        }

        // Query for Tasks created by the trigger
        List<Task> createdTasks = [
            SELECT Id
            FROM Task
            WHERE Subject = 'Follow up on shipped order 105'
        ];

        // Verify that 5 Tasks were created (only from events with Has_Shipped__c = true)
        System.assertEquals(5, createdTasks.size(), 'Exactly 5 Tasks should be created from 5 shipped events');
    }
}
