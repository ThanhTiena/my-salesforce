public with sharing class AClass {
    
    @InvocableMethod(label='My Action Label' callout=true)
    public static List<String> aMethod(List<String> toEmails) {
        List<String> output = new List<String>();
        Map<String, String> mapQueueByEmailRoutingAddress = new Map<String, String>();

        // Pre-Tooling API query to get EmailToCaseRoutingAddress records
        String query = 'SELECT CaseOwner, EmailAddress FROM EmailToCaseRoutingAddress WHERE EmailAddress IN ({0})';
        query = String.format(query, new List<String>{'\'' + String.join(toEmails, '\',\'') + '\''});
        
        // Do query using Tooling API
        HttpRequest req = new HttpRequest();
        req.setEndpoint(
            'callout:ToolingApi/services/data/v62.0/tooling/query?q='+
            EncodingUtil.urlEncode(query, 'UTF-8')
        );
        req.setMethod('GET');
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if(res.getStatusCode() == 200) {
            Map<String, String> mapEmailAdressByCaseOwnerName = new Map<String, String>();
            EmailToCaseRoutingResponse result = (EmailToCaseRoutingResponse) JSON.deserialize(res.getBody(), EmailToCaseRoutingResponse.class);
            for(CaseSetting setting : result.records) {
                mapEmailAdressByCaseOwnerName.put(setting.CaseOwner, setting.EmailAddress);
            }

            for(Group queue: [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName IN :mapEmailAdressByCaseOwnerName.keySet()]) {
                if (mapEmailAdressByCaseOwnerName.containsKey(queue.DeveloperName)) {
                    String emailAddress = mapEmailAdressByCaseOwnerName.get(queue.DeveloperName);
                    mapQueueByEmailRoutingAddress.put(emailAddress, queue.Id);
                }
            }
        }

        // Process the queues and prepare output
        for(String email : toEmails) {
            output.add(mapQueueByEmailRoutingAddress.get(email));
        }

        return output;
    }

    public class EmailToCaseRoutingResponse {
        public List<CaseSetting> records;
    }

    public class CaseSetting {
        public String CaseOwner;
        public String EmailAddress;
    }
}