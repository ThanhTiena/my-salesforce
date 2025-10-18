public with sharing class AccountHandler {
    public static void insertAccount(Integer num){
        List<Account> addAccounts = new List<Account>();
        for(; num > 0; num--){
            addAccounts.add(new Account(
                Name = 'Acme Inc ' + String.valueOf(num),
                AccountNumber = 'A000' + String.valueOf(num)
            ));
        }

        insert addAccounts;
    }
}