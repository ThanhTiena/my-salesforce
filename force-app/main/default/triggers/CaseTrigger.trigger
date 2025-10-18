trigger CaseTrigger on Case (before update) {

    // This trigger is executed before a Case record is updated.
    // You can add your logic here to manipulate the Case records before they are saved to the database.

    for (CaseHistory c : [SELECT CaseId, CreatedDate, Field, OldValue, NewValue FROM CaseHistory WHERE CaseId IN :Trigger.new]) {
        System.debug(c);
    }
}