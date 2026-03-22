@IsTest
private class MongoDBLogServiceTest {

    // ─── Mock HTTP responses ──────────────────────────────────────────────────

    private class InsertOneMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(201);
            res.setBody('{"insertedId":"64abc123"}');
            return res;
        }
    }

    private class UpdateOneMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"matchedCount":1,"modifiedCount":1}');
            return res;
        }
    }

    private class FindMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"documents":[{"sf_execution_id":"exec001","workflow_name":"Test WF","status":"COMPLETED","initiated_by":"005xxx","retry_count":0,"total_tokens_used":200,"duration_seconds":5.2,"started_at":{"$date":{"$numberLong":"1700000000000"}},"completed_at":{"$date":{"$numberLong":"1700000005000"}},"trigger_record_id":null,"error_message":null}]}');
            return res;
        }
    }

    private class AggregateDashboardMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"documents":[{"totalExecutions":10,"successCount":8,"failedCount":1,"runningCount":1,"avgDurationSeconds":4.5,"totalTokensUsed":3000,"successRate":80.0}]}');
            return res;
        }
    }

    private class AggregateTokenMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"documents":[{"_id":"ANTHROPIC","totalTokens":2000,"executionCount":5},{"_id":"OPENAI","totalTokens":1000,"executionCount":3}]}');
            return res;
        }
    }

    private class StepsFindMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"documents":[{"sf_execution_id":"exec001","steps":[{"sf_step_execution_id":"step001","step_name":"Classify Lead","step_type":"AI_INFERENCE","status":"COMPLETED","provider_used":"ANTHROPIC","model_used":"claude-3-5-sonnet","tokens_used":350,"duration_ms":3200,"error_message":null,"parsed_output":"HIGH_PRIORITY"}]}]}');
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    // ─── Shared config builder ────────────────────────────────────────────────

    private static AI_MongoDB_Config__mdt buildConfig() {
        AI_MongoDB_Config__mdt cfg = new AI_MongoDB_Config__mdt(
            Named_Credential_API_Name__c = 'AI_MongoDB_Atlas',
            App_Id__c                    = 'testApp123',
            Data_Source__c               = 'Cluster0',
            Database_Name__c             = 'sf_ai_orchestrator',
            Executions_Collection__c     = 'ai_executions',
            Org_Id__c                    = UserInfo.getOrganizationId(),
            Is_Active__c                 = true,
            Timeout_Seconds__c           = 30,
            Write_Mode__c                = 'ASYNC_BEST_EFFORT'
        );
        return cfg;
    }

    // ─── Tests — Write API ────────────────────────────────────────────────────

    @IsTest
    static void testInsertExecution() {
        MongoDBLogService.setConfig(buildConfig());
        Test.setMock(HttpCalloutMock.class, new InsertOneMock());

        MongoDBLogService.ExecutionDocument doc = new MongoDBLogService.ExecutionDocument();
        doc.sfExecutionId   = 'exec001';
        doc.sfWorkflowId    = 'wf001';
        doc.workflowName    = 'Test Workflow';
        doc.workflowVersion = 1;
        doc.sfOrgId         = UserInfo.getOrganizationId();
        doc.status          = 'PENDING';
        doc.initiatedBy     = UserInfo.getUserId();
        doc.startedAtEpochMs = Datetime.now().getTime();
        doc.retryCount      = 0;
        doc.steps           = new List<MongoDBLogService.StepDocument>();
        doc.schemaVersion   = 1;

        Test.startTest();
        MongoDBLogService.insertExecution(doc);
        Test.stopTest();

        // No exception = pass
        System.assert(true, 'insertExecution completed without exception');
    }

    @IsTest
    static void testUpdateExecutionStatus() {
        MongoDBLogService.setConfig(buildConfig());
        Test.setMock(HttpCalloutMock.class, new UpdateOneMock());

        Test.startTest();
        MongoDBLogService.updateExecutionStatus('exec001', 'RUNNING', null);
        Test.stopTest();

        System.assert(true, 'updateExecutionStatus completed without exception');
    }

    @IsTest
    static void testPushStep() {
        MongoDBLogService.setConfig(buildConfig());
        Test.setMock(HttpCalloutMock.class, new UpdateOneMock());

        MongoDBLogService.StepDocument step = new MongoDBLogService.StepDocument();
        step.sfStepExecutionId = 'step001';
        step.sfStepId          = 'stepDef001';
        step.stepName          = 'Test Step';
        step.stepType          = 'AI_INFERENCE';
        step.stepOrder         = 1;
        step.status            = 'RUNNING';

        Test.startTest();
        MongoDBLogService.pushStep('exec001', step);
        Test.stopTest();

        System.assert(true, 'pushStep completed without exception');
    }

    @IsTest
    static void testUpdateStep() {
        MongoDBLogService.setConfig(buildConfig());
        Test.setMock(HttpCalloutMock.class, new UpdateOneMock());

        MongoDBLogService.StepDocument step = new MongoDBLogService.StepDocument();
        step.sfStepExecutionId = 'step001';
        step.status            = 'COMPLETED';
        step.tokensUsed        = 150;
        step.durationMs        = 1200;
        step.parsedOutput      = 'result text';

        Test.startTest();
        MongoDBLogService.updateStep('exec001', step);
        Test.stopTest();

        System.assert(true, 'updateStep completed without exception');
    }

    @IsTest
    static void testFinaliseExecution() {
        MongoDBLogService.setConfig(buildConfig());
        Test.setMock(HttpCalloutMock.class, new UpdateOneMock());

        Test.startTest();
        MongoDBLogService.finaliseExecution('exec001', 'COMPLETED', 12.5, 500, '{}', null);
        Test.stopTest();

        System.assert(true, 'finaliseExecution completed without exception');
    }

    // ─── Tests — Read API ─────────────────────────────────────────────────────

    @IsTest
    static void testGetDashboardMetrics() {
        AI_MongoDB_Config__mdt cfg = buildConfig();
        cfg.Write_Mode__c = 'SYNC_REQUIRED'; // surface exceptions in read methods too
        MongoDBLogService.setConfig(cfg);
        Test.setMock(HttpCalloutMock.class, new AggregateDashboardMock());

        Test.startTest();
        MongoDBLogService.DashboardResult r = MongoDBLogService.getDashboardMetrics(7);
        Test.stopTest();

        Assert.areEqual(10, r.totalExecutions);
        Assert.areEqual(8,  r.successCount);
        Assert.areEqual(1,  r.failedCount);
        Assert.areEqual(1,  r.runningCount);
        Assert.areEqual(3000, r.totalTokensUsed);
        Assert.isTrue(r.successRate > 0, 'Expected successRate > 0');
    }

    @IsTest
    static void testGetDashboardMetricsNullDefault() {
        MongoDBLogService.setConfig(buildConfig());
        Test.setMock(HttpCalloutMock.class, new AggregateDashboardMock());

        Test.startTest();
        MongoDBLogService.DashboardResult r = MongoDBLogService.getDashboardMetrics(null);
        Test.stopTest();

        Assert.isNotNull(r);
    }

    @IsTest
    static void testGetRecentExecutions() {
        AI_MongoDB_Config__mdt cfg = buildConfig();
        cfg.Write_Mode__c = 'SYNC_REQUIRED';
        MongoDBLogService.setConfig(cfg);
        Test.setMock(HttpCalloutMock.class, new FindMock());

        Test.startTest();
        List<MongoDBLogService.ExecutionSummary> rows = MongoDBLogService.getRecentExecutions(10);
        Test.stopTest();

        Assert.areEqual(1, rows.size());
        Assert.areEqual('exec001', rows[0].sfExecutionId);
        Assert.areEqual('COMPLETED', rows[0].status);
        Assert.areEqual('Test WF', rows[0].workflowName);
    }

    @IsTest
    static void testGetTokenUsageByProvider() {
        AI_MongoDB_Config__mdt cfg = buildConfig();
        cfg.Write_Mode__c = 'SYNC_REQUIRED';
        MongoDBLogService.setConfig(cfg);
        Test.setMock(HttpCalloutMock.class, new AggregateTokenMock());

        Test.startTest();
        List<MongoDBLogService.TokenUsageSummary> rows = MongoDBLogService.getTokenUsageByProvider(30);
        Test.stopTest();

        Assert.areEqual(2, rows.size());
        Assert.areEqual('ANTHROPIC', rows[0].providerName);
        Assert.areEqual(2000, rows[0].totalTokens);
    }

    @IsTest
    static void testGetStepExecutions() {
        AI_MongoDB_Config__mdt cfg = buildConfig();
        cfg.Write_Mode__c = 'SYNC_REQUIRED';
        MongoDBLogService.setConfig(cfg);
        Test.setMock(HttpCalloutMock.class, new StepsFindMock());

        Test.startTest();
        List<MongoDBLogService.StepSummary> steps = MongoDBLogService.getStepExecutions('exec001');
        Test.stopTest();

        Assert.areEqual(1, steps.size());
        Assert.areEqual('Classify Lead', steps[0].stepName);
        Assert.areEqual('COMPLETED', steps[0].status);
        Assert.areEqual(350, steps[0].tokensUsed);
    }

    // ─── Tests — Inactive config / error handling ─────────────────────────────

    @IsTest
    static void testNoOpWhenInactive() {
        AI_MongoDB_Config__mdt inactiveCfg = buildConfig();
        inactiveCfg.Is_Active__c = false;
        MongoDBLogService.setConfig(inactiveCfg);

        Test.startTest();
        // All calls should silently no-op — no mock needed
        MongoDBLogService.insertExecution(new MongoDBLogService.ExecutionDocument());
        MongoDBLogService.updateExecutionStatus('exec001', 'RUNNING', null);
        MongoDBLogService.DashboardResult r = MongoDBLogService.getDashboardMetrics(7);
        List<MongoDBLogService.ExecutionSummary> execs = MongoDBLogService.getRecentExecutions(5);
        List<MongoDBLogService.TokenUsageSummary> tokens = MongoDBLogService.getTokenUsageByProvider(7);
        List<MongoDBLogService.StepSummary> steps = MongoDBLogService.getStepExecutions('exec001');
        Test.stopTest();

        Assert.areEqual(0, r.totalExecutions, 'Expected empty result when inactive');
        Assert.areEqual(0, execs.size());
        Assert.areEqual(0, tokens.size());
        Assert.areEqual(0, steps.size());
    }

    @IsTest
    static void testWriteErrorBestEffortDoesNotThrow() {
        MongoDBLogService.setConfig(buildConfig()); // ASYNC_BEST_EFFORT
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        // Should not throw even though HTTP returns 500
        Boolean threw = false;
        try {
            MongoDBLogService.insertExecution(new MongoDBLogService.ExecutionDocument());
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isFalse(threw, 'ASYNC_BEST_EFFORT mode must not propagate write errors');
    }

    @IsTest
    static void testWriteErrorSyncRequiredThrows() {
        AI_MongoDB_Config__mdt syncCfg = buildConfig();
        syncCfg.Write_Mode__c = 'SYNC_REQUIRED';
        MongoDBLogService.setConfig(syncCfg);
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();
        Boolean threw = false;
        try {
            MongoDBLogService.insertExecution(new MongoDBLogService.ExecutionDocument());
        } catch (MongoDBLogService.MongoDBException e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'SYNC_REQUIRED mode must re-throw write errors');
    }
}
