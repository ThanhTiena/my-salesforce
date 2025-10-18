@IsTest
public class ParkServiceMock implements WebServiceMock{

    public void doInvoke(
    	Object stub,
        Object request,
        Map<String, Object> response,
        String endpoint,
        String soapAction,
        String requestName,
        String responseNS,
        String responseName,
        String responseType
    ) {
        ParkService.byCountryResponse res_x = new ParkService.byCountryResponse();
        res_x.return_x = new List<String>{'Test Park'};
        response.put('response_x', res_x);
    }
}