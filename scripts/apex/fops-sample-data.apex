/**
 * FreelanceOps — sample data loader (Anonymous Apex).
 *
 * Run against a scratch/dev org AFTER deploying the FreelanceOps metadata:
 *   sf apex run --file scripts/apex/fops-sample-data.apex --target-org <alias>
 *
 * Creates a coherent slice of the pipeline so the FreelanceHub React app (the
 * "Salesforce Data" page) shows real records:
 *   Accounts (clients) -> Contacts (consultants) -> Contract -> Opportunity
 *   -> Assignment (bill/cost rates) -> Timesheet -> Time Entries
 *   -> Order (invoice) -> Payment
 *
 * Defensive by design: it resolves an active Opportunity stage dynamically and
 * only sets required + safe fields, so it works whether or not the optional
 * Setup steps (custom stages, record types) are complete. Re-runnable — it
 * skips creation if sample Accounts already exist.
 */
if ([SELECT COUNT() FROM Account WHERE Name LIKE 'FOPS Sample —%'] > 0) {
    System.debug('Sample data already present — nothing to do.');
} else {
    // --- Accounts (clients) ------------------------------------------------
    List<Account> accounts = new List<Account>{
        new Account(Name = 'FOPS Sample — Acme Analytics', FOPS_Account_Role__c = 'Direct Client'),
        new Account(Name = 'FOPS Sample — Northwind Studio', FOPS_Account_Role__c = 'Direct Client'),
        new Account(Name = 'FOPS Sample — Lumen Health', FOPS_Account_Role__c = 'End Client')
    };
    // FOPS_Account_Role__c is a restricted picklist; drop the value if it isn't valid in this org.
    try {
        insert accounts;
    } catch (Exception e) {
        for (Account a : accounts) a.FOPS_Account_Role__c = null;
        insert accounts;
    }
    Account acme = accounts[0], northwind = accounts[1], lumen = accounts[2];

    // --- Contacts (consultants) -------------------------------------------
    List<Contact> contacts = new List<Contact>{
        new Contact(FirstName = 'Dana', LastName = 'Whitfield (FOPS)', AccountId = acme.Id),
        new Contact(FirstName = 'Miguel', LastName = 'Santos (FOPS)', AccountId = northwind.Id),
        new Contact(FirstName = 'Priya', LastName = 'Nair (FOPS)', AccountId = lumen.Id)
    };
    insert contacts;

    // --- Contract (required by Assignment) --------------------------------
    Contract acmeContract = new Contract(
        AccountId = acme.Id,
        StartDate = Date.today().addMonths(-3),
        ContractTerm = 12,
        Status = 'Draft'
    );
    insert acmeContract;

    // --- Opportunity (uses whatever stage is active in this org) -----------
    List<OpportunityStage> activeStages = [
        SELECT MasterLabel FROM OpportunityStage WHERE IsActive = true ORDER BY SortOrder LIMIT 1
    ];
    if (!activeStages.isEmpty()) {
        insert new Opportunity(
            Name = 'FOPS Sample — Acme Dashboard v2',
            AccountId = acme.Id,
            StageName = activeStages[0].MasterLabel,
            CloseDate = Date.today().addMonths(1)
        );
    }

    // --- Assignments (the commercial core: bill rate + cost rate) ----------
    List<FOPS_Assignment__c> assignments = new List<FOPS_Assignment__c>{
        new FOPS_Assignment__c(
            FOPS_Consultant__c = contacts[0].Id,
            FOPS_Contract__c = acmeContract.Id,
            FOPS_End_Client__c = acme.Id,
            FOPS_Start_Date__c = Date.today().addMonths(-2),
            FOPS_Hours_Per_Week__c = 40,
            FOPS_Bill_Rate__c = 140,
            FOPS_Cost_Rate__c = 95,
            FOPS_Exchange_Rate_Used__c = 1,
            FOPS_Exchange_Rate_Date__c = Date.today()
        ),
        new FOPS_Assignment__c(
            FOPS_Consultant__c = contacts[1].Id,
            FOPS_Contract__c = acmeContract.Id,
            FOPS_End_Client__c = northwind.Id,
            FOPS_Start_Date__c = Date.today().addMonths(-1),
            FOPS_Hours_Per_Week__c = 24,
            FOPS_Bill_Rate__c = 120,
            FOPS_Cost_Rate__c = 80,
            FOPS_Exchange_Rate_Used__c = 1,
            FOPS_Exchange_Rate_Date__c = Date.today()
        )
    };
    insert assignments;

    // --- Timesheet + Time Entries -----------------------------------------
    FOPS_Timesheet__c ts = new FOPS_Timesheet__c(
        FOPS_Assignment__c = assignments[0].Id,
        FOPS_Period_Start__c = Date.today().toStartOfWeek(),
        FOPS_Period_End__c = Date.today().toStartOfWeek().addDays(6)
    );
    insert ts;

    List<FOPS_Time_Entry__c> entries = new List<FOPS_Time_Entry__c>();
    for (Integer i = 0; i < 4; i++) {
        entries.add(new FOPS_Time_Entry__c(
            FOPS_Timesheet__c = ts.Id,
            FOPS_Work_Date__c = Date.today().addDays(-i),
            FOPS_Hours__c = 6 + Math.mod(i, 3),
            FOPS_Is_Billable__c = true,
            FOPS_Description__c = 'Sample work log #' + (i + 1)
        ));
    }
    insert entries;

    // --- Order (invoice) + Payment ----------------------------------------
    Order inv = new Order(
        AccountId = acme.Id,
        EffectiveDate = Date.today().addDays(-10),
        Status = 'Draft',
        FOPS_Invoice_Number__c = 'INV-SAMPLE-0001',
        FOPS_Due_Date__c = Date.today().addDays(4),
        FOPS_Total_Amount_Base__c = 5600,
        FOPS_Exchange_Rate_Used__c = 1,
        FOPS_Exchange_Rate_Date__c = Date.today()
    );
    insert inv;

    insert new FOPS_Payment__c(
        FOPS_Account__c = acme.Id,
        FOPS_Order__c = inv.Id,
        FOPS_Payment_Date__c = Date.today(),
        FOPS_Amount_Received__c = 5600,
        FOPS_Amount_Received_Base__c = 5600,
        FOPS_Actual_Settlement_Rate__c = 1
    );

    System.debug('FreelanceOps sample data created: '
        + accounts.size() + ' accounts, '
        + contacts.size() + ' contacts, '
        + assignments.size() + ' assignments, '
        + entries.size() + ' time entries, 1 invoice, 1 payment.');
}
