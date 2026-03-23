/**
 * Anonymous Apex script — run via:
 *   sf apex run --file scripts/create-sample-template.apex --target-org <alias>
 *
 * Creates a "Lead Qualification & Enrichment" workflow template with 5 steps:
 *   1. START        — entry node
 *   2. AI_INFERENCE — classify lead priority (Anthropic Claude)
 *   3. DECISION     — route based on priority
 *   4. NOTIFICATION — notify sales rep for high-priority leads
 *   5. END          — exit node
 *
 * The workflow is marked Is_Template__c = true so it appears in the Template
 * Browser and can be cloned via WorkflowTemplateService.cloneTemplate().
 *
 * Execution results (when cloned workflows run) are stored ONLY in MongoDB —
 * the template itself lives in Salesforce as AI_Workflow__c / AI_Step__c records.
 */

// ── Delete any existing template with the same name so this script is idempotent ──
List<AI_Workflow__c> existing = [
    SELECT Id FROM AI_Workflow__c
    WHERE Name = 'Lead Qualification & Enrichment' AND Is_Template__c = true
    LIMIT 1
];
if (!existing.isEmpty()) delete existing;

// ── 1. Create the template workflow ──────────────────────────────────────────
AI_Workflow__c template = new AI_Workflow__c(
    Name                    = 'Lead Qualification & Enrichment',
    Description__c          = 'Automatically classifies incoming leads by priority using Claude, '
                            + 'routes high-priority leads to immediate follow-up, and notifies '
                            + 'the assigned sales rep. Designed to run on the Lead object.',
    Trigger_Object__c       = 'Lead',
    Trigger_Condition__c    = 'Status = "Open - Not Contacted"',
    Is_Active__c            = false,
    Is_Template__c          = true,
    Version__c              = 1,
    Max_Retries__c          = 2,
    Retry_Delay_Seconds__c  = 30,
    Notification_Email__c   = 'sales-ops@example.com'
);
insert template;
System.debug('Template workflow created: ' + template.Id);

// ── 2. Create steps ──────────────────────────────────────────────────────────
List<AI_Step__c> steps = new List<AI_Step__c>{

    // Step 1 — START
    new AI_Step__c(
        Name                          = 'Start',
        AI_Workflow__c                = template.Id,
        Step_Type__c                  = 'START',
        Order__c                      = 1,
        Is_Active__c                  = true,
        AI_Provider_Developer_Name__c = 'N/A'
    ),

    // Step 2 — AI_INFERENCE: classify lead priority
    new AI_Step__c(
        Name                          = 'Classify Lead Priority',
        AI_Workflow__c                = template.Id,
        Step_Type__c                  = 'AI_INFERENCE',
        Order__c                      = 2,
        Is_Active__c                  = true,
        AI_Provider_Developer_Name__c = 'Anthropic',          // must match AI_Provider__mdt DeveloperName
        Model_Override__c             = 'claude-3-5-haiku-20251001',
        Temperature_Override__c       = 0.2,
        Max_Tokens_Override__c        = 200,
        Response_Format__c            = 'TEXT',
        Output_Field__c               = 'Description',        // writes output back to Lead.Description
        System_Prompt__c              = 'You are a sales intelligence assistant. '
                                      + 'Classify leads as HIGH, MEDIUM, or LOW priority. '
                                      + 'Reply with exactly one word: HIGH, MEDIUM, or LOW.',
        Prompt_Template__c            = 'Evaluate this lead and classify its priority.\n\n'
                                      + 'Company: {{Company}}\n'
                                      + 'Title: {{Title}}\n'
                                      + 'Annual Revenue: {{AnnualRevenue}}\n'
                                      + 'Number of Employees: {{NumberOfEmployees}}\n'
                                      + 'Lead Source: {{LeadSource}}\n'
                                      + 'Industry: {{Industry}}\n\n'
                                      + 'Priority:'
    ),

    // Step 3 — DECISION: branch on priority
    new AI_Step__c(
        Name                          = 'Route by Priority',
        AI_Workflow__c                = template.Id,
        Step_Type__c                  = 'DECISION',
        Order__c                      = 3,
        Is_Active__c                  = true,
        AI_Provider_Developer_Name__c = 'N/A',
        Condition__c                  = '{"field":"step_2_output","operator":"equals","value":"HIGH","trueBranch":"SUCCESS","falseBranch":"SKIP"}'
    ),

    // Step 4 — NOTIFICATION: alert sales rep for high-priority leads
    new AI_Step__c(
        Name                          = 'Notify Sales Rep',
        AI_Workflow__c                = template.Id,
        Step_Type__c                  = 'NOTIFICATION',
        Order__c                      = 4,
        Is_Active__c                  = true,
        AI_Provider_Developer_Name__c = 'N/A',
        Condition__c                  = '{"type":"email","template":"High-priority lead assigned: {{FirstName}} {{LastName}} from {{Company}}. AI Priority Score: HIGH."}'
    ),

    // Step 5 — END
    new AI_Step__c(
        Name                          = 'End',
        AI_Workflow__c                = template.Id,
        Step_Type__c                  = 'END',
        Order__c                      = 5,
        Is_Active__c                  = true,
        AI_Provider_Developer_Name__c = 'N/A'
    )
};

insert steps;
System.debug('Inserted ' + steps.size() + ' steps for template ' + template.Id);

System.debug('Done. Template Id = ' + template.Id);
System.debug('To test the MongoDB connection run: sf apex run --file scripts/test-mongodb-connection.apex --target-org <alias>');
