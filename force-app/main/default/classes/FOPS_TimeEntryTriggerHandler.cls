/**
 * Trigger handler for FOPS_Time_Entry__c. One trigger per object delegates to
 * this handler, which honors the bypass custom setting and routes to services.
 */
public with sharing class FOPS_TimeEntryTriggerHandler {
  /** True when automation is switched off via the hierarchy custom setting. */
  @TestVisible
  private static Boolean isBypassed() {
    FOPS_Trigger_Setting__c settings = FOPS_Trigger_Setting__c.getInstance();
    return settings != null && settings.FOPS_Bypass_Time_Entry__c == true;
  }

  /** before insert / before update: freeze rates (insert only) + amount. */
  public static void handleBeforeSave(
    List<FOPS_Time_Entry__c> newEntries,
    Boolean isInsert
  ) {
    if (isBypassed()) {
      return;
    }
    FOPS_TimeEntryService.applyFinancials(newEntries, isInsert);
  }
}
