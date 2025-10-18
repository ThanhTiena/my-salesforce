public with sharing class DailyLeadProcessor implements Schedulable{
    public DailyLeadProcessor() {

    }

    public void execute(SchedulableContext context){
        List<Lead> records = [SELECT Id, LeadSource FROM Lead WHERE LeadSource = NULL LIMIT 200];
        for(Lead l : records){
            l.LeadSource = 'Dreamforce';
        }

        update records;
    }
}