@IsTest
public class ParkLocatorTest {

    @IsTest static void testCallout(){
        Test.setMock(WebServiceMock.Class, new ParkServiceMock());
        
        String[] a = ParkLocator.country('India');
        System.assertEquals(1,a.size());
    }
}