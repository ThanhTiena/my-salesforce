@IsTest
public class OtherCSVTests {
	
    @TestSetup
  static void loadTestDataFromStaticResource() {
    List<sObject> accounts = Test.loadData(Account.SObjectType, 'otherAccountData');
  }
    
  @IsTest
  static void testLoadOtherAccountsFromStaticResource() {
    // WHEN
    Test.startTest();
      List<Account> accts = [SELECT ID FROM Account];
    Test.stopTest();
    // THEN
    Assert.isTrue(accts.size() == 15, 'Expected 15 accounts');
  }
}