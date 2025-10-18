public with sharing class CaseSLAHandler {
    
    @InvocableMethod (label='Handle Case SLA' description='Handles the SLA for Case records')
    public static void handleCaseSLA(List<Case> cases) {
        // This method is called to handle the SLA for the given list of Case records.
        // You can implement your logic here to check and update the SLA status of the cases.
        Set<Id> caseIds = new Set<Id>();
        for(Case c: cases){
                caseIds.add(c.Id);
            
        }
        for (CaseHistory c : [SELECT CaseId, CreatedDate, Field, OldValue, NewValue FROM CaseHistory WHERE CaseId IN :caseIds]) {
            System.debug(c);
        }
    }
}