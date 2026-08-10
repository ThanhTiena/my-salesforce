/**
 * Domain/service logic for FOPS_Time_Entry__c.
 *
 * Frozen-rate pattern: at INSERT we snapshot the Assignment's bill and cost
 * rate onto the entry. On UPDATE we do NOT re-read the Assignment — the snapshot
 * is frozen so historical entries keep their value even after rates change
 * later (Toggl non-retroactive pattern). The billable amount is (re)computed on
 * both from the entry's own snapshot:
 *
 *   billable amount = hours × bill-rate snapshot × rate multiplier   (billable)
 *                   = 0                                              (non-billable)
 *
 * NOTE (MVP): the rate is treated as hourly. When mixed rate units
 * (daily/weekly/monthly) are needed, route through a RateNormalisationService
 * before multiplying by hours.
 */
public with sharing class FOPS_TimeEntryService {
  /**
   * @param entries    Trigger.new records (mutated in place; before-save).
   * @param stampRates true on insert — read + freeze the Assignment rates;
   *                   false on update — keep the existing snapshot.
   */
  public static void applyFinancials(
    List<FOPS_Time_Entry__c> entries,
    Boolean stampRates
  ) {
    if (entries == null || entries.isEmpty()) {
      return;
    }

    Map<Id, FOPS_Timesheet__c> byTimesheet = new Map<Id, FOPS_Timesheet__c>();
    if (stampRates) {
      Set<Id> timesheetIds = new Set<Id>();
      for (FOPS_Time_Entry__c e : entries) {
        if (e.FOPS_Timesheet__c != null) {
          timesheetIds.add(e.FOPS_Timesheet__c);
        }
      }
      byTimesheet = new FOPS_TimesheetSelector()
        .ratesByTimesheetId(timesheetIds);
    }

    for (FOPS_Time_Entry__c e : entries) {
      if (stampRates) {
        FOPS_Timesheet__c ts = byTimesheet.get(e.FOPS_Timesheet__c);
        if (ts != null && ts.FOPS_Assignment__r != null) {
          e.FOPS_Bill_Rate_Snapshot__c = ts.FOPS_Assignment__r.FOPS_Bill_Rate__c;
          e.FOPS_Cost_Rate_Snapshot__c = ts.FOPS_Assignment__r.FOPS_Cost_Rate__c;
        }
      }

      Decimal hours = e.FOPS_Hours__c == null ? 0 : e.FOPS_Hours__c;
      Decimal multiplier = e.FOPS_Rate_Multiplier__c == null
        ? 1
        : e.FOPS_Rate_Multiplier__c;
      Decimal billRate = e.FOPS_Bill_Rate_Snapshot__c;
      Boolean billable = e.FOPS_Is_Billable__c == true;

      e.FOPS_Billable_Amount__c = (billable && billRate != null)
        ? (hours * billRate * multiplier)
        : 0;
    }
  }
}
