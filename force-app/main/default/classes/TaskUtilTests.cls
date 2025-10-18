@IsTest
public class TaskUtilTests {
    static testmethod void testGetTaskPriorityNormal(){
        String leadState = 'NO';
        String result = '';
        
        Test.startTest();
        result = TaskUtil.getTaskPriority(leadState);
        Test.stopTest();
        
        System.assertEquals('Normal', result,'');
    }
    
    static testmethod void testGetTaskPriorityHigh (){
        String leadState = 'CA';
        String result = '';
        
        Test.startTest();
        result = TaskUtil.getTaskPriority(leadState);
        Test.stopTest();
        
        System.assertEquals('High', result,'');
    }
    
    static testmethod void testGetTaskPriorityInvalid (){
        String leadState = 'INVALID';
        String result = '';
        
        Test.startTest();
        result = TaskUtil.getTaskPriority(leadState);
        Test.stopTest();
        
        System.assertEquals(null, result,'');
    }
}