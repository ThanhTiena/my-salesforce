/**
 * Test class for orderTrigger
 * This test class provides coverage for the Order trigger that calls OrderItemUtility
 * to add bonus bouquets when orders are activated
 */
@IsTest
public class orderTriggerTest {

    /**
     * Setup test data that will be used across all test methods
     * Creates necessary Account, Product, Pricebook, and Order records
     */
    @TestSetup
    static void setupTestData() {
        // Create a test Account (required for Order)
        Account testAccount = new Account(
            Name = 'Test Flower Shop'
        );
        insert testAccount;

        // Create the bonus product with the specific ProductCode that OrderItemUtility looks for
        Product2 bonusProduct = new Product2(
            Name = 'Bonus Bouquet',
            ProductCode = 'BOT-BB-12',
            IsActive = true
        );
        insert bonusProduct;

        // Get the standard price book
        Id standardPricebookId = Test.getStandardPricebookId();

        // Create a PricebookEntry for the bonus product
        PricebookEntry bonusEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = bonusProduct.Id,
            UnitPrice = 0.00,
            IsActive = true
        );
        insert bonusEntry;

        // Create another product for the regular order item
        Product2 regularProduct = new Product2(
            Name = 'Regular Bouquet',
            ProductCode = 'REG-001',
            IsActive = true
        );
        insert regularProduct;

        // Create a PricebookEntry for the regular product
        PricebookEntry regularEntry = new PricebookEntry(
            Pricebook2Id = standardPricebookId,
            Product2Id = regularProduct.Id,
            UnitPrice = 50.00,
            IsActive = true
        );
        insert regularEntry;
    }

    /**
     * Test that the trigger fires and OrderItemUtility adds a bonus bouquet
     * when an Order is updated to 'Activated' status
     */
    @IsTest
    static void testOrderActivationAddsBonusBouquet() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product2 regularProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'REG-001' LIMIT 1];
        PricebookEntry regularEntry = [SELECT Id FROM PricebookEntry WHERE Product2Id = :regularProduct.Id LIMIT 1];

        // Create a Draft Order
        Order testOrder = new Order(
            AccountId = testAccount.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert testOrder;

        // Add a regular order item (required before activating order)
        OrderItem regularItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = regularEntry.Id,
            Quantity = 1,
            UnitPrice = 50.00
        );
        insert regularItem;

        // Start test context
        Test.startTest();

        // Update the Order to 'Activated' status - this should trigger the bonus bouquet addition
        testOrder.Status = 'Activated';
        update testOrder;

        // Stop test context
        Test.stopTest();

        // Query for OrderItems - should include the original item + bonus bouquet
        List<OrderItem> orderItems = [
            SELECT Id, Description, Quantity, UnitPrice, numberOfFlowers__c, colorTheme__c
            FROM OrderItem
            WHERE OrderId = :testOrder.Id
        ];

        // Verify that 2 OrderItems exist (1 regular + 1 bonus)
        System.assertEquals(2, orderItems.size(), 'Should have 2 OrderItems: 1 regular + 1 bonus bouquet');

        // Find the bonus bouquet
        OrderItem bonusBouquet = null;
        for (OrderItem item : orderItems) {
            if (item.Description == 'FREE Bouquet') {
                bonusBouquet = item;
                break;
            }
        }

        // Verify the bonus bouquet was created
        System.assertNotEquals(null, bonusBouquet, 'Bonus bouquet should be created');

        // Verify bonus bouquet properties
        System.assertEquals(1, bonusBouquet.Quantity, 'Bonus bouquet quantity should be 1');
        System.assertEquals(0.00, bonusBouquet.UnitPrice, 'Bonus bouquet should be free');
        System.assertEquals(3, bonusBouquet.numberOfFlowers__c, 'Bonus bouquet should have 3 flowers');
        System.assertEquals('Spectacular Sunset', bonusBouquet.colorTheme__c, 'Bonus bouquet should have correct color theme');
    }

    /**
     * Test that no bonus bouquet is added when Order status is not 'Activated'
     * This ensures the trigger logic only fires for activated orders
     */
    @IsTest
    static void testNonActivatedOrderDoesNotAddBonusBouquet() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product2 regularProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'REG-001' LIMIT 1];
        PricebookEntry regularEntry = [SELECT Id FROM PricebookEntry WHERE Product2Id = :regularProduct.Id LIMIT 1];

        // Create a Draft Order
        Order testOrder = new Order(
            AccountId = testAccount.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert testOrder;

        // Add a regular order item
        OrderItem regularItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = regularEntry.Id,
            Quantity = 1,
            UnitPrice = 50.00
        );
        insert regularItem;

        // Start test context
        Test.startTest();

        // Update the Order but keep it as 'Draft' - should NOT trigger bonus bouquet
        testOrder.Description = 'Updated description';
        update testOrder;

        // Stop test context
        Test.stopTest();

        // Query for OrderItems - should only have the regular item
        List<OrderItem> orderItems = [
            SELECT Id, Description
            FROM OrderItem
            WHERE OrderId = :testOrder.Id
        ];

        // Verify only 1 OrderItem exists (no bonus bouquet added)
        System.assertEquals(1, orderItems.size(), 'Should have only 1 OrderItem (no bonus bouquet)');

        // Verify no bonus bouquet exists
        Integer bonusCount = 0;
        for (OrderItem item : orderItems) {
            if (item.Description == 'FREE Bouquet') {
                bonusCount++;
            }
        }
        System.assertEquals(0, bonusCount, 'No bonus bouquet should be added for non-activated orders');
    }

    /**
     * Test bulk processing of multiple Order activations
     * This ensures the trigger can handle multiple orders efficiently
     */
    @IsTest
    static void testBulkOrderActivation() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product2 regularProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'REG-001' LIMIT 1];
        PricebookEntry regularEntry = [SELECT Id FROM PricebookEntry WHERE Product2Id = :regularProduct.Id LIMIT 1];

        // Create multiple Draft Orders
        List<Order> orders = new List<Order>();
        for (Integer i = 0; i < 10; i++) {
            orders.add(new Order(
                AccountId = testAccount.Id,
                EffectiveDate = Date.today(),
                Status = 'Draft',
                Pricebook2Id = Test.getStandardPricebookId()
            ));
        }
        insert orders;

        // Add regular order items to each order
        List<OrderItem> regularItems = new List<OrderItem>();
        for (Order ord : orders) {
            regularItems.add(new OrderItem(
                OrderId = ord.Id,
                PricebookEntryId = regularEntry.Id,
                Quantity = 1,
                UnitPrice = 50.00
            ));
        }
        insert regularItems;

        // Start test context
        Test.startTest();

        // Activate all orders at once
        for (Order ord : orders) {
            ord.Status = 'Activated';
        }
        update orders;

        // Stop test context
        Test.stopTest();

        // Query for all OrderItems
        List<OrderItem> allOrderItems = [
            SELECT Id, OrderId, Description
            FROM OrderItem
            WHERE OrderId IN :orders
        ];

        // Should have 20 total items (10 regular + 10 bonus)
        System.assertEquals(20, allOrderItems.size(), 'Should have 20 OrderItems total (10 regular + 10 bonus)');

        // Count bonus bouquets
        Integer bonusCount = 0;
        for (OrderItem item : allOrderItems) {
            if (item.Description == 'FREE Bouquet') {
                bonusCount++;
            }
        }

        // Verify 10 bonus bouquets were added
        System.assertEquals(10, bonusCount, 'Should have 10 bonus bouquets for 10 activated orders');
    }

    /**
     * Test that OrderItemUtility handles the case when bonus product doesn't exist
     * This ensures the code doesn't break if the bonus product is deleted
     */
    @IsTest
    static void testOrderActivationWithoutBonusProduct() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Product2 regularProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'REG-001' LIMIT 1];
        PricebookEntry regularEntry = [SELECT Id FROM PricebookEntry WHERE Product2Id = :regularProduct.Id LIMIT 1];

        // Delete the bonus product to test the scenario where it doesn't exist
        Product2 bonusProduct = [SELECT Id FROM Product2 WHERE ProductCode = 'BOT-BB-12' LIMIT 1];
        delete bonusProduct;

        // Create a Draft Order
        Order testOrder = new Order(
            AccountId = testAccount.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert testOrder;

        // Add a regular order item
        OrderItem regularItem = new OrderItem(
            OrderId = testOrder.Id,
            PricebookEntryId = regularEntry.Id,
            Quantity = 1,
            UnitPrice = 50.00
        );
        insert regularItem;

        // Start test context
        Test.startTest();

        // Update the Order to 'Activated' - should not fail even without bonus product
        testOrder.Status = 'Activated';
        update testOrder;

        // Stop test context
        Test.stopTest();

        // Query for OrderItems - should only have the regular item
        List<OrderItem> orderItems = [
            SELECT Id
            FROM OrderItem
            WHERE OrderId = :testOrder.Id
        ];

        // Verify only 1 OrderItem exists (no bonus added since product doesn't exist)
        System.assertEquals(1, orderItems.size(), 'Should have only 1 OrderItem when bonus product does not exist');
    }
}
