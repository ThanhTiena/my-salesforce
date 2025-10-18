public with sharing class LeadProcessor implements Database.Batchable<SObject>{
    
    
    public Database.QueryLocator start(Database.BatchableContext context){
        return Database.getQueryLocator('SELECT Id, LeadSource FROM Lead', AccessLevel.SYSTEM_MODE);
    }

    public void execute(Database.BatchableContext context, List<Lead> leads){
        for(Lead lead : leads){
            lead.LeadSource = 'Dreamforce';
        }

        update leads;
    }

    public void finish(Database.BatchableContext context){

    }
}