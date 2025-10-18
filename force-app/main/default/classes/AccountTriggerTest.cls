@IsTest
public class AccountTriggerTest {

    @IsTest
    public static void testCreateAccount(){
        Integer num = 200;
        Test.startTest();
        List<Account> addAccounts = new List<Account>();
        for(; num > 0; num--){
            addAccounts.add(new Account(
                Name = 'Acme Inc ' + String.valueOf(num),
                AccountNumber = 'A000' + String.valueOf(num),
                BillingState = 'CA'
            ));
        }

        insert addAccounts;
        Test.stopTest();
        
        Integer countCAAccounts = [SELECT Count() FROM Account WHERE ShippingState = 'CA'];
        System.assert(countCAAccounts == 200, '');
    }
}