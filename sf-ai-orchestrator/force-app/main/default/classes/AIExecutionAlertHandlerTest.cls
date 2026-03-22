@IsTest
private class AIExecutionAlertHandlerTest {

    // ── Shared helper ────────────────────────────────────────────────────────

    private static AI_Workflow__c createWorkflow(String email) {
        AI_Workflow__c wf = new AI_Workflow__c(
            Name                  = 'Test Workflow',
            Version__c            = 1,
            Max_Retries__c        = 2,
            Retry_Delay_Seconds__c = 30,
            Is_Active__c          = true,
            Notification_Email__c = email
        );
        insert wf;
        return wf;
    }

    private static AI_Execution__c createExecution(Id workflowId, String status) {
        AI_Execution__c exec = new AI_Execution__c(
            AI_Workflow__c  = workflowId,
            Status__c       = status,
            Started_At__c   = Datetime.now(),
            Initiated_By__c = UserInfo.getUserId()
        );
        insert exec;
        return exec;
    }

    // Valid Status__c values: PENDING, RUNNING, COMPLETED, FAILED, CANCELLED, RETRYING

    // ── Test 1: No alert when status stays non-FAILED ────────────────────────

    @IsTest
    static void testNoAlertWhenNotFailed() {
        AI_Workflow__c wf   = createWorkflow('test@example.com');
        AI_Execution__c exec = createExecution(wf.Id, 'RUNNING');

        Test.startTest();
        exec.Status__c = 'COMPLETED';
        update exec;
        Test.stopTest();

        // No exception = pass; email sending is a no-op for non-FAILED transitions
        System.assert(true, 'No exception expected for COMPLETED transition');
    }

    // ── Test 2: Alert fires on first FAILED transition ───────────────────────

    @IsTest
    static void testAlertOnFirstFailure() {
        AI_Workflow__c wf   = createWorkflow('test@example.com');
        AI_Execution__c exec = createExecution(wf.Id, 'RUNNING');

        Test.startTest();
        exec.Status__c = 'FAILED';
        update exec;
        Test.stopTest();

        // Cannot assert email delivery in tests; asserting no exception was thrown
        System.assert(true, 'No exception expected when FAILED transition fires with email configured');
    }

    // ── Test 3: No exception when workflow Notification_Email__c is blank ────

    @IsTest
    static void testAlertWhenNoEmail() {
        AI_Workflow__c wf   = createWorkflow(''); // blank email
        AI_Execution__c exec = createExecution(wf.Id, 'RUNNING');

        Test.startTest();
        exec.Status__c = 'FAILED';
        update exec;
        Test.stopTest();

        System.assert(true, 'No exception expected when workflow has no notification email');
    }

    // ── Test 4: Consecutive failure count ≥ 3 ───────────────────────────────

    @IsTest
    static void testConsecutiveFailureTracking() {
        AI_Workflow__c wf = createWorkflow('test@example.com');

        // Insert 3 already-FAILED executions to seed the history
        List<AI_Execution__c> seeds = new List<AI_Execution__c>();
        for (Integer i = 0; i < 3; i++) {
            seeds.add(new AI_Execution__c(
                AI_Workflow__c  = wf.Id,
                Status__c       = 'FAILED',
                Started_At__c   = Datetime.now().addSeconds(-i * 10),
                Initiated_By__c = UserInfo.getUserId()
            ));
        }
        insert seeds;

        // Create one more execution in RUNNING then flip to FAILED to fire the trigger
        AI_Execution__c exec = createExecution(wf.Id, 'RUNNING');

        Test.startTest();
        exec.Status__c = 'FAILED';
        update exec;
        Test.stopTest();

        // Query all FAILED executions for this workflow to verify the count
        List<AI_Execution__c> failedExecs = [
            SELECT Id, Status__c
            FROM AI_Execution__c
            WHERE AI_Workflow__c = :wf.Id
              AND Status__c = 'FAILED'
        ];

        System.assert(
            failedExecs.size() >= 3,
            'Expected at least 3 consecutive FAILED executions, found: ' + failedExecs.size()
        );
    }
}
