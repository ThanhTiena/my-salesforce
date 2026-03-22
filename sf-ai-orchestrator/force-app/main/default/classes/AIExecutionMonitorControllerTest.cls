@IsTest
private class AIExecutionMonitorControllerTest {

    @TestSetup
    static void setup() {
        AI_Workflow__c wf = new AI_Workflow__c(
            Name          = 'Test Monitor WF',
            Is_Active__c  = true,
            Version__c    = 1,
            Max_Retries__c = 3,
            Retry_Delay_Seconds__c = 60
        );
        insert wf;

        AI_Execution__c ex = new AI_Execution__c(
            AI_Workflow__c       = wf.Id,
            Status__c            = 'COMPLETED',
            Started_At__c        = Datetime.now().addMinutes(-5),
            Completed_At__c      = Datetime.now(),
            Duration_Seconds__c  = 12.5,
            Total_Tokens_Used__c = 150,
            Initiated_By__c      = UserInfo.getUserId()
        );
        insert ex;

        AI_Step__c step = new AI_Step__c(
            Name                          = 'Test Step',
            AI_Workflow__c                = wf.Id,
            Step_Type__c                  = 'AI_INFERENCE',
            AI_Provider_Developer_Name__c = 'OpenAI_GPT4o',
            Order__c                      = 1,
            Is_Active__c                  = true
        );
        insert step;

        AI_Step_Execution__c se = new AI_Step_Execution__c(
            AI_Execution__c  = ex.Id,
            AI_Step__c       = step.Id,
            Status__c        = 'COMPLETED',
            Provider_Used__c = 'OPENAI',
            Tokens_Used__c   = 150,
            Duration_Ms__c   = 3200
        );
        insert se;
    }

    @IsTest
    static void testGetDashboardMetrics() {
        Test.startTest();
        AIExecutionMonitorController.DashboardMetrics m =
            AIExecutionMonitorController.getDashboardMetrics(7);
        Test.stopTest();
        Assert.isNotNull(m);
        Assert.isTrue(m.totalExecutions >= 0);
    }

    @IsTest
    static void testGetDashboardMetricsNullDefault() {
        Test.startTest();
        AIExecutionMonitorController.DashboardMetrics m =
            AIExecutionMonitorController.getDashboardMetrics(null);
        Test.stopTest();
        Assert.isNotNull(m);
    }

    @IsTest
    static void testGetRecentExecutions() {
        Test.startTest();
        List<AIExecutionMonitorController.ExecutionSummary> execs =
            AIExecutionMonitorController.getRecentExecutions(10);
        Test.stopTest();
        Assert.isNotNull(execs);
        Assert.isTrue(execs.size() > 0);
        Assert.areEqual('COMPLETED', execs[0].status);
    }

    @IsTest
    static void testGetRecentExecutionsNullDefault() {
        Test.startTest();
        List<AIExecutionMonitorController.ExecutionSummary> execs =
            AIExecutionMonitorController.getRecentExecutions(null);
        Test.stopTest();
        Assert.isNotNull(execs);
    }

    @IsTest
    static void testGetTokenUsageByProvider() {
        Test.startTest();
        List<AIExecutionMonitorController.TokenUsageByProvider> usage =
            AIExecutionMonitorController.getTokenUsageByProvider(30);
        Test.stopTest();
        Assert.isNotNull(usage);
        Assert.isTrue(usage.size() > 0);
        Assert.areEqual('OPENAI', usage[0].providerName);
        Assert.areEqual(150, usage[0].totalTokens);
    }

    @IsTest
    static void testGetStepExecutions() {
        AI_Execution__c ex = [SELECT Id FROM AI_Execution__c LIMIT 1];
        Test.startTest();
        List<AI_Step_Execution__c> steps =
            AIExecutionMonitorController.getStepExecutions(ex.Id);
        Test.stopTest();
        Assert.isNotNull(steps);
        Assert.areEqual(1, steps.size());
        Assert.areEqual('COMPLETED', steps[0].Status__c);
    }
}
