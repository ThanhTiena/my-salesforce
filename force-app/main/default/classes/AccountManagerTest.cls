@IsTest
public class AccountManagerTest {

    private static String prepareData(){
        Account acc = new Account(Name = 'Account Test');
        insert acc;
        
        Contact con = new Contact(AccountId = acc.Id, LastName = 'A', FirstName = 'aaaa');
        insert con;
        return acc.Id;
    }
    
    @isTest static void testGetAccount(){
        String accountId = prepareData();
        
        RestRequest request = new RestRequest();
        request.requestUri = 'https://playful-impala-gmpj2f-dev-ed.trailblaze.my.salesforce.com/services/apexrest/Accounts/' + accountId + '/contacts';
        RestContext.request = request;
        
        Account acc = AccountManager.getAccount();
        Assert.isTrue(acc != null);
        Assert.areEqual('Account Test', acc.Name);
    }
}