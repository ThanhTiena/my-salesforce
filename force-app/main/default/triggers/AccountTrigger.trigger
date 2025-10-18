trigger AccountTrigger on Account (before insert) {
    if(Trigger.isInsert && Trigger.isBefore){
        AccountTriggerHandler.CreateAccounts((List<Account>)Trigger.new);
    } 
}