public class AccountProcessor 
{
  @future
  public static void countContacts(Set<id> setId) 
  {
      List<Account> lstAccount = [select id,Number_of_Contacts__c , (select id from contacts ) from account where id in :setId ];
      for( Account acc : lstAccount )
      {          
          acc.Number_of_Contacts__c = acc.contacts.size();
      }
      update lstAccount;
  }
}