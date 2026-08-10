/**
 * Tests for the Time Entry frozen-rate stamping (trigger → handler → service →
 * selector). Covers billable, non-billable, and the bypass switch.
 */
@isTest
private class FOPS_TimeEntryServiceTest {
  /** Builds Account → Contact → Contract → Assignment → Timesheet and returns
   *  the Timesheet Id. Assignment bill rate 140, cost rate 95. */
  private static Id buildChain() {
    Account acc = new Account(Name = 'FOPS Test Client');
    insert acc;

    Contact con = new Contact(LastName = 'Tester', AccountId = acc.Id);
    insert con;

    Contract ctr = new Contract(
      AccountId = acc.Id,
      StartDate = Date.today(),
      ContractTerm = 12,
      Status = 'Draft'
    );
    insert ctr;

    FOPS_Assignment__c asg = new FOPS_Assignment__c(
      FOPS_Consultant__c = con.Id,
      FOPS_Contract__c = ctr.Id,
      FOPS_Bill_Rate__c = 140,
      FOPS_Cost_Rate__c = 95
    );
    insert asg;

    FOPS_Timesheet__c ts = new FOPS_Timesheet__c(FOPS_Assignment__c = asg.Id);
    insert ts;
    return ts.Id;
  }

  @isTest
  static void stampsSnapshotsAndBillableAmount() {
    Id tsId = buildChain();

    Test.startTest();
    FOPS_Time_Entry__c te = new FOPS_Time_Entry__c(
      FOPS_Timesheet__c = tsId,
      FOPS_Work_Date__c = Date.today(),
      FOPS_Hours__c = 4,
      FOPS_Is_Billable__c = true
    );
    insert te;
    Test.stopTest();

    FOPS_Time_Entry__c saved = [
      SELECT
        FOPS_Bill_Rate_Snapshot__c,
        FOPS_Cost_Rate_Snapshot__c,
        FOPS_Billable_Amount__c
      FROM FOPS_Time_Entry__c
      WHERE Id = :te.Id
    ];
    System.assertEquals(140, saved.FOPS_Bill_Rate_Snapshot__c, 'bill snapshot');
    System.assertEquals(95, saved.FOPS_Cost_Rate_Snapshot__c, 'cost snapshot');
    System.assertEquals(
      560,
      saved.FOPS_Billable_Amount__c,
      'billable amount = 4h × 140 × 1'
    );
  }

  @isTest
  static void nonBillableIsZeroButStillSnapshots() {
    Id tsId = buildChain();

    FOPS_Time_Entry__c te = new FOPS_Time_Entry__c(
      FOPS_Timesheet__c = tsId,
      FOPS_Work_Date__c = Date.today(),
      FOPS_Hours__c = 3,
      FOPS_Is_Billable__c = false
    );
    insert te;

    FOPS_Time_Entry__c saved = [
      SELECT FOPS_Bill_Rate_Snapshot__c, FOPS_Billable_Amount__c
      FROM FOPS_Time_Entry__c
      WHERE Id = :te.Id
    ];
    System.assertEquals(
      140,
      saved.FOPS_Bill_Rate_Snapshot__c,
      'rate still snapshotted for margin'
    );
    System.assertEquals(
      0,
      saved.FOPS_Billable_Amount__c,
      'non-billable amount is 0'
    );
  }

  @isTest
  static void bypassSkipsStamping() {
    insert new FOPS_Trigger_Setting__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      FOPS_Bypass_Time_Entry__c = true
    );
    Id tsId = buildChain();

    FOPS_Time_Entry__c te = new FOPS_Time_Entry__c(
      FOPS_Timesheet__c = tsId,
      FOPS_Work_Date__c = Date.today(),
      FOPS_Hours__c = 2,
      FOPS_Is_Billable__c = true
    );
    insert te;

    FOPS_Time_Entry__c saved = [
      SELECT FOPS_Bill_Rate_Snapshot__c, FOPS_Billable_Amount__c
      FROM FOPS_Time_Entry__c
      WHERE Id = :te.Id
    ];
    System.assertEquals(
      null,
      saved.FOPS_Bill_Rate_Snapshot__c,
      'bypass leaves snapshot untouched'
    );
    System.assertEquals(
      null,
      saved.FOPS_Billable_Amount__c,
      'bypass leaves amount untouched'
    );
  }

  @isTest
  static void updateKeepsFrozenRateAndRecomputesAmount() {
    Id tsId = buildChain(); // assignment bill rate 140

    FOPS_Time_Entry__c te = new FOPS_Time_Entry__c(
      FOPS_Timesheet__c = tsId,
      FOPS_Work_Date__c = Date.today(),
      FOPS_Hours__c = 2,
      FOPS_Is_Billable__c = true
    );
    insert te;

    // Change the Assignment rate AFTER the entry was created.
    FOPS_Timesheet__c ts = [
      SELECT FOPS_Assignment__c
      FROM FOPS_Timesheet__c
      WHERE Id = :tsId
    ];
    update new FOPS_Assignment__c(
      Id = ts.FOPS_Assignment__c,
      FOPS_Bill_Rate__c = 200
    );

    // Update the entry's hours; the snapshot must stay frozen at 140.
    te.FOPS_Hours__c = 5;
    update te;

    FOPS_Time_Entry__c saved = [
      SELECT FOPS_Bill_Rate_Snapshot__c, FOPS_Billable_Amount__c
      FROM FOPS_Time_Entry__c
      WHERE Id = :te.Id
    ];
    System.assertEquals(
      140,
      saved.FOPS_Bill_Rate_Snapshot__c,
      'snapshot stays frozen at the original 140'
    );
    System.assertEquals(
      700,
      saved.FOPS_Billable_Amount__c,
      'amount recomputes with the frozen rate: 5h × 140'
    );
  }
}
