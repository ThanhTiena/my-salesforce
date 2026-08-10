/**
 * Selector for FOPS_Timesheet__c. All Timesheet SOQL lives here (one-query-per
 * layer discipline).
 */
public with sharing class FOPS_TimesheetSelector {
  /**
   * Returns Timesheets by Id, each with its Assignment's bill and cost rate.
   *
   * SYSTEM context by design (no WITH USER_MODE): this reads the CONFIDENTIAL
   * bill/cost rate so it can be snapshotted onto the Time Entry — a value the
   * running sub-contractor is not allowed to see. The snapshot target fields
   * are themselves FLS-protected (readable=false on FOPS_Consultant), so the
   * sub-contractor still cannot read the result. This is the one deliberate
   * exception to WITH USER_MODE, and it is safe because no confidential value
   * is ever returned to a user who lacks access.
   */
  public Map<Id, FOPS_Timesheet__c> ratesByTimesheetId(Set<Id> timesheetIds) {
    Map<Id, FOPS_Timesheet__c> result = new Map<Id, FOPS_Timesheet__c>();
    if (timesheetIds == null || timesheetIds.isEmpty()) {
      return result;
    }
    for (
      FOPS_Timesheet__c ts : [
        SELECT
          Id,
          FOPS_Assignment__r.FOPS_Bill_Rate__c,
          FOPS_Assignment__r.FOPS_Cost_Rate__c
        FROM FOPS_Timesheet__c
        WHERE Id IN :timesheetIds
      ]
    ) {
      result.put(ts.Id, ts);
    }
    return result;
  }
}
