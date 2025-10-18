public class AccountUtility {

    public static void viewAnnualRevenue(){
        List<Account> accountsList = [SELECT Name, AnnualRevenue FROM Account ];
        String acctRev = '';
        for(Account accountList : accountsList){
            acctRev += accountList.Name + ':' + accountList.AnnualRevenue;
        }
        System.debug(acctRev);
    }
}