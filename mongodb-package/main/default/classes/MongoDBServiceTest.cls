/**
 * Test class for MongoDBService
 */
@isTest
public class MongoDBServiceTest {

    /**
     * Mock HTTP callout for MongoDB responses
     */
    @TestVisible
    public class MongoDBMock implements HttpCalloutMock {
        private Integer statusCode;
        private String responseBody;

        public MongoDBMock(Integer statusCode, String responseBody) {
            this.statusCode = statusCode;
            this.responseBody = responseBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(statusCode);
            res.setBody(responseBody);
            res.setHeader('Content-Type', 'application/json');
            return res;
        }
    }

    @isTest
    static void testFind() {
        // Setup mock response
        String mockResponse = '{"documents": [{"_id": {"$oid": "123"}, "name": "John Doe", "email": "john@example.com"}]}';
        Test.setMock(HttpCalloutMock.class, new MongoDBMock(200, mockResponse));

        Test.startTest();
        MongoDBService service = new MongoDBService('MongoDB_Credential');
        Map<String, Object> filter = new Map<String, Object>{'name' => 'John Doe'};
        List<Map<String, Object>> results = service.find('users', filter, null);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one document');
        Map<String, Object> doc = results[0];
        System.assertEquals('John Doe', doc.get('name'), 'Name should match');
    }

    @isTest
    static void testFindOne() {
        // Setup mock response
        String mockResponse = '{"documents": [{"_id": {"$oid": "123"}, "name": "John Doe"}]}';
        Test.setMock(HttpCalloutMock.class, new MongoDBMock(200, mockResponse));

        Test.startTest();
        MongoDBService service = new MongoDBService('MongoDB_Credential');
        Map<String, Object> result = service.findOne('users', '123');
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return a document');
        System.assertEquals('John Doe', result.get('name'), 'Name should match');
    }

    @isTest
    static void testInsertOne() {
        // Setup mock response
        String mockResponse = '{"insertedId": "12345"}';
        Test.setMock(HttpCalloutMock.class, new MongoDBMock(201, mockResponse));

        Test.startTest();
        MongoDBService service = new MongoDBService('MongoDB_Credential');
        Map<String, Object> document = new Map<String, Object>{
            'name' => 'Jane Doe',
            'email' => 'jane@example.com'
        };
        String insertedId = service.insertOne('users', document);
        Test.stopTest();

        System.assertEquals('12345', insertedId, 'Should return inserted ID');
    }

    @isTest
    static void testUpdateOne() {
        // Setup mock response
        String mockResponse = '{"modifiedCount": 1}';
        Test.setMock(HttpCalloutMock.class, new MongoDBMock(200, mockResponse));

        Test.startTest();
        MongoDBService service = new MongoDBService('MongoDB_Credential');
        Map<String, Object> filter = new Map<String, Object>{'_id' => '123'};
        Map<String, Object> updateDoc = new Map<String, Object>{
            '$set' => new Map<String, Object>{'name' => 'Updated Name'}
        };
        Integer modifiedCount = service.updateOne('users', filter, updateDoc);
        Test.stopTest();

        System.assertEquals(1, modifiedCount, 'Should update one document');
    }

    @isTest
    static void testDeleteOne() {
        // Setup mock response
        String mockResponse = '{"deletedCount": 1}';
        Test.setMock(HttpCalloutMock.class, new MongoDBMock(200, mockResponse));

        Test.startTest();
        MongoDBService service = new MongoDBService('MongoDB_Credential');
        Map<String, Object> filter = new Map<String, Object>{'_id' => '123'};
        Integer deletedCount = service.deleteOne('users', filter);
        Test.stopTest();

        System.assertEquals(1, deletedCount, 'Should delete one document');
    }

    @isTest
    static void testMongoDBException() {
        // Setup mock error response
        String mockResponse = '{"error": "Bad request"}';
        Test.setMock(HttpCalloutMock.class, new MongoDBMock(400, mockResponse));

        Test.startTest();
        MongoDBService service = new MongoDBService('MongoDB_Credential');
        Boolean exceptionThrown = false;
        try {
            service.find('users', null, null);
        } catch (MongoDBService.MongoDBException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw MongoDBException on error');
    }
}
