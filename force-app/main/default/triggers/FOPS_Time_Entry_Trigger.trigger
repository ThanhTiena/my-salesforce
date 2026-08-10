/**
 * One trigger per object. All logic lives in FOPS_TimeEntryTriggerHandler.
 * before-save so field stamping needs no extra DML.
 */
trigger FOPS_Time_Entry_Trigger on FOPS_Time_Entry__c(
  before insert,
  before update
) {
  FOPS_TimeEntryTriggerHandler.handleBeforeSave(Trigger.new, Trigger.isInsert);
}
