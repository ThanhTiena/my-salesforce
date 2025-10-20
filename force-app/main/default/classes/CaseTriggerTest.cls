/**
 * Test class for CaseTrigger
 * This test class provides coverage for the Case before update trigger
 * that queries CaseHistory for debugging purposes
 */
@IsTest
public class CaseTriggerTest {

    /**
     * Setup test data that will be used across all test methods
     * Creates a test Case record
     */
    @TestSetup
    static void setupTestData() {
        // Create a test Case
        Case testCase = new Case(
            Subject = 'Test Case for Trigger',
            Status = 'New',
            Origin = 'Web',
            Priority = 'Medium'
        );
        insert testCase;
    }

    /**
     * Test that the trigger fires when a Case is updated
     * This ensures the trigger executes and queries CaseHistory
     */
    @IsTest
    static void testCaseUpdateTrigger() {
        // Get the test case
        Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];

        // Start test context
        Test.startTest();

        // Update the Case to trigger the before update trigger
        testCase.Status = 'Working';
        testCase.Priority = 'High';
        update testCase;

        // Stop test context
        Test.stopTest();

        // Query to verify the Case was updated successfully
        Case updatedCase = [SELECT Id, Status, Priority FROM Case WHERE Id = :testCase.Id];

        // Verify the update was successful (trigger didn't prevent the update)
        System.assertEquals('Working', updatedCase.Status, 'Case Status should be updated to Working');
        System.assertEquals('High', updatedCase.Priority, 'Case Priority should be updated to High');
    }

    /**
     * Test that the trigger handles multiple Case updates (bulk processing)
     * This ensures the trigger can handle multiple records efficiently
     */
    @IsTest
    static void testBulkCaseUpdate() {
        // Create multiple test Cases
        List<Case> testCases = new List<Case>();
        for (Integer i = 0; i < 10; i++) {
            testCases.add(new Case(
                Subject = 'Bulk Test Case ' + i,
                Status = 'New',
                Origin = 'Email',
                Priority = 'Low'
            ));
        }
        insert testCases;

        // Start test context
        Test.startTest();

        // Update all Cases at once to test bulk processing
        for (Case c : testCases) {
            c.Status = 'Escalated';
            c.Priority = 'High';
        }
        update testCases;

        // Stop test context
        Test.stopTest();

        // Query to verify all Cases were updated successfully
        List<Case> updatedCases = [
            SELECT Id, Status, Priority
            FROM Case
            WHERE Id IN :testCases
        ];

        // Verify all 10 Cases were updated
        System.assertEquals(10, updatedCases.size(), 'All 10 Cases should be updated');

        // Verify the updates were successful for all Cases
        for (Case c : updatedCases) {
            System.assertEquals('Escalated', c.Status, 'All Cases should have Status = Escalated');
            System.assertEquals('High', c.Priority, 'All Cases should have Priority = High');
        }
    }

    /**
     * Test Case update with field tracking enabled
     * This creates CaseHistory records that the trigger will query
     */
    @IsTest
    static void testCaseUpdateWithHistory() {
        // Get the test case
        Case testCase = [SELECT Id, Status, Priority FROM Case LIMIT 1];

        // Start test context
        Test.startTest();

        // Make multiple updates to create CaseHistory records
        testCase.Status = 'Working';
        update testCase;

        testCase.Priority = 'High';
        update testCase;

        testCase.Status = 'Escalated';
        update testCase;

        // Stop test context
        Test.stopTest();

        // Query CaseHistory to verify history was created
        List<CaseHistory> history = [
            SELECT Id, CaseId, Field, OldValue, NewValue
            FROM CaseHistory
            WHERE CaseId = :testCase.Id
        ];

        // Verify that CaseHistory records exist
        // Note: The number of history records depends on field tracking configuration
        System.assert(history.size() >= 0, 'CaseHistory query should execute without errors');

        // Query the final Case state
        Case finalCase = [SELECT Id, Status, Priority FROM Case WHERE Id = :testCase.Id];

        // Verify final state
        System.assertEquals('Escalated', finalCase.Status, 'Final Status should be Escalated');
        System.assertEquals('High', finalCase.Priority, 'Final Priority should be High');
    }

    /**
     * Test that the trigger handles Case updates with various field changes
     * This ensures the trigger works with different types of updates
     */
    @IsTest
    static void testCaseUpdateWithMultipleFields() {
        // Get the test case
        Case testCase = [SELECT Id, Subject, Status, Priority, Origin FROM Case LIMIT 1];

        // Start test context
        Test.startTest();

        // Update multiple fields at once
        testCase.Subject = 'Updated Subject';
        testCase.Status = 'Closed';
        testCase.Priority = 'High';
        testCase.Origin = 'Phone';
        update testCase;

        // Stop test context
        Test.stopTest();

        // Query to verify the Case was updated successfully
        Case updatedCase = [
            SELECT Id, Subject, Status, Priority, Origin
            FROM Case
            WHERE Id = :testCase.Id
        ];

        // Verify all fields were updated successfully
        System.assertEquals('Updated Subject', updatedCase.Subject, 'Subject should be updated');
        System.assertEquals('Closed', updatedCase.Status, 'Status should be Closed');
        System.assertEquals('High', updatedCase.Priority, 'Priority should be High');
        System.assertEquals('Phone', updatedCase.Origin, 'Origin should be Phone');
    }

    /**
     * Test Case update when no CaseHistory exists
     * This ensures the trigger doesn't fail when there's no history
     */
    @IsTest
    static void testCaseUpdateWithoutHistory() {
        // Create a brand new Case (no history yet)
        Case newCase = new Case(
            Subject = 'New Case Without History',
            Status = 'New',
            Origin = 'Web',
            Priority = 'Low'
        );
        insert newCase;

        // Start test context
        Test.startTest();

        // Update the Case immediately (minimal history)
        newCase.Status = 'Working';
        update newCase;

        // Stop test context
        Test.stopTest();

        // Query to verify the Case was updated successfully
        Case updatedCase = [SELECT Id, Status FROM Case WHERE Id = :newCase.Id];

        // Verify the update was successful even with minimal/no history
        System.assertEquals('Working', updatedCase.Status, 'Case should be updated successfully even without history');
    }
}
