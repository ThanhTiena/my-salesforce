public class AccountTriggerHandler {

    public static void CreateAccounts(List<Account> accounts){
        for(Account acc: accounts){
            acc.ShippingState = acc.BillingState;
        }
    }
}