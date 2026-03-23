/**
 * MongoDB connection test — NO DML, callout-only transaction.
 *
 * Run via:
 *   sf apex run --file scripts/test-mongodb-connection.apex --target-org <alias>
 *
 * This must be a separate script from create-sample-template.apex because
 * Salesforce prohibits callouts after DML in the same transaction.
 *
 * Prerequisites:
 *   - AI_MongoDB_Config__mdt.Default is configured and Is_Active__c = true
 *   - Named Credential (AI_MongoDB_Atlas or equivalent) is set up
 *   - Set Write_Mode__c = 'SYNC_REQUIRED' to surface errors instead of swallowing them
 */

// Force SYNC_REQUIRED so any error throws instead of being silently logged
AI_MongoDB_Config__mdt cfg = new AI_MongoDB_Config__mdt(
    Named_Credential_API_Name__c = 'AI_MongoDB_Atlas',  // adjust if your NC name differs
    Is_Active__c                 = true,
    Timeout_Seconds__c           = 30,
    Write_Mode__c                = 'SYNC_REQUIRED',
    Org_Id__c                    = UserInfo.getOrganizationId()
);
MongoDBLogService.setConfig(cfg);

String testExecId = 'test_' + EncodingUtil.convertToHex(Crypto.generateAESKey(128)).left(20);
System.debug('Test execution ID: ' + testExecId);

try {
    // ── Test 1: insertExecution (POST) ────────────────────────────────────────
    MongoDBLogService.ExecutionDocument doc = new MongoDBLogService.ExecutionDocument();
    doc.sfExecutionId    = testExecId;
    doc.sfWorkflowId     = 'test-workflow-id';
    doc.workflowName     = 'MongoDB Connection Test';
    doc.workflowVersion  = 1;
    doc.sfOrgId          = UserInfo.getOrganizationId();
    doc.status           = 'PENDING';
    doc.initiatedBy      = UserInfo.getUserId();
    doc.startedAtEpochMs = Datetime.now().getTime();
    doc.retryCount       = 0;
    doc.steps            = new List<MongoDBLogService.StepDocument>();
    doc.schemaVersion    = 1;

    MongoDBLogService.insertExecution(doc);
    System.debug('TEST 1 PASSED — insertExecution OK');

    // ── Test 2: updateExecutionStatus (PATCH) ─────────────────────────────────
    MongoDBLogService.updateExecutionStatus(testExecId, 'RUNNING', null);
    System.debug('TEST 2 PASSED — updateExecutionStatus OK');

    // ── Test 3: pushStep (PATCH) ──────────────────────────────────────────────
    MongoDBLogService.StepDocument step = new MongoDBLogService.StepDocument();
    step.sfStepExecutionId = 'step_' + EncodingUtil.convertToHex(Crypto.generateAESKey(128)).left(20);
    step.sfStepId          = 'step-def-001';
    step.stepName          = 'Test Step';
    step.stepType          = 'AI_INFERENCE';
    step.stepOrder         = 1;
    step.status            = 'RUNNING';
    step.retryAttempt      = 0;

    MongoDBLogService.pushStep(testExecId, step);
    System.debug('TEST 3 PASSED — pushStep OK');

    // ── Test 4: updateStep (PATCH) ────────────────────────────────────────────
    step.status       = 'COMPLETED';
    step.tokensUsed   = 42;
    step.durationMs   = 800;
    step.parsedOutput = 'HIGH';

    MongoDBLogService.updateStep(testExecId, step);
    System.debug('TEST 4 PASSED — updateStep OK');

    // ── Test 5: finaliseExecution (PATCH) ─────────────────────────────────────
    MongoDBLogService.finaliseExecution(testExecId, 'COMPLETED', 1.5, 42, '{}', null);
    System.debug('TEST 5 PASSED — finaliseExecution OK');

    System.debug('ALL TESTS PASSED — MongoDB connection is working correctly.');

} catch (MongoDBLogService.MongoDBException ex) {
    System.debug(LoggingLevel.ERROR, 'FAILED: ' + ex.getMessage());
    System.debug(LoggingLevel.ERROR, 'Check: 1) Named Credential URL  2) x-api-key header  3) Vercel API is running');
} catch (Exception ex) {
    System.debug(LoggingLevel.ERROR, 'Unexpected error: ' + ex.getTypeName() + ' — ' + ex.getMessage());
}
