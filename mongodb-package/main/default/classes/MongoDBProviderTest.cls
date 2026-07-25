/**
 * Test class for MongoDBProvider and MongoDBConnection
 */
@isTest
private class MongoDBProviderTest {

    @isTest
    static void testGetCapabilities() {
        Test.startTest();
        MongoDBProvider provider = new MongoDBProvider();
        List<DataSource.Capability> capabilities = provider.getCapabilities();
        Test.stopTest();

        System.assert(capabilities.size() > 0, 'Should return capabilities');
        System.assert(capabilities.contains(DataSource.Capability.ROW_QUERY), 'Should support row query');
        System.assert(capabilities.contains(DataSource.Capability.ROW_CREATE), 'Should support row create');
        System.assert(capabilities.contains(DataSource.Capability.ROW_UPDATE), 'Should support row update');
        System.assert(capabilities.contains(DataSource.Capability.ROW_DELETE), 'Should support row delete');
    }

    @isTest
    static void testGetAuthenticationCapabilities() {
        Test.startTest();
        MongoDBProvider provider = new MongoDBProvider();
        List<DataSource.AuthenticationCapability> authCapabilities = provider.getAuthenticationCapabilities();
        Test.stopTest();

        System.assert(authCapabilities.size() > 0, 'Should return auth capabilities');
        System.assert(authCapabilities.contains(DataSource.AuthenticationCapability.ANONYMOUS),
            'Should support anonymous auth');
    }

    @isTest
    static void testGetConnection() {
        Test.startTest();
        MongoDBProvider provider = new MongoDBProvider();
        DataSource.ConnectionParams params = new DataSource.ConnectionParams();
        params.principalType = DataSource.IdentityType.NAMED_USER;
        params.endpoint = 'MongoDB_Credential';

        DataSource.Connection connection = provider.getConnection(params);
        Test.stopTest();

        System.assertNotEquals(null, connection, 'Should return a connection');
        System.assert(connection instanceof MongoDBConnection, 'Should be MongoDBConnection instance');
    }

    @isTest
    static void testSync() {
        // Setup connection
        DataSource.ConnectionParams params = new DataSource.ConnectionParams();
        params.principalType = DataSource.IdentityType.NAMED_USER;
        params.endpoint = 'MongoDB_Credential';

        Test.startTest();
        MongoDBConnection connection = new MongoDBConnection(params);
        List<DataSource.Table> tables = connection.sync();
        Test.stopTest();

        System.assert(tables.size() > 0, 'Should return at least one table');
        System.assertEquals('users', tables[0].name, 'First table should be users');
    }

    @isTest
    static void testQuery() {
        // Setup mock
        String mockResponse = '{"documents": [{"_id": {"$oid": "123"}, "name": "Test User", "email": "test@example.com"}]}';
        Test.setMock(HttpCalloutMock.class, new MongoDBServiceTest.MongoDBMock(200, mockResponse));

        // Setup connection and query context
        DataSource.ConnectionParams params = new DataSource.ConnectionParams();
        params.principalType = DataSource.IdentityType.NAMED_USER;
        params.endpoint = 'MongoDB_Credential';

        MongoDBConnection connection = new MongoDBConnection(params);

        DataSource.QueryContext queryContext = new DataSource.QueryContext();
        queryContext.tableSelection = new DataSource.TableSelection();
        queryContext.tableSelection.tableSelected = 'users';
        queryContext.tableSelection.columnsSelected = new List<DataSource.ColumnSelection>();

        Test.startTest();
        DataSource.TableResult result = connection.query(queryContext);
        Test.stopTest();

        System.assert(result.success, 'Query should succeed');
        System.assertEquals('users', result.tableName, 'Table name should match');
        System.assert(result.rows.size() > 0, 'Should return rows');
    }

    @isTest
    static void testUpsertRows() {
        // Setup mock
        String mockResponse = '{"insertedId": "12345"}';
        Test.setMock(HttpCalloutMock.class, new MongoDBServiceTest.MongoDBMock(201, mockResponse));

        // Setup connection
        DataSource.ConnectionParams params = new DataSource.ConnectionParams();
        params.principalType = DataSource.IdentityType.NAMED_USER;
        params.endpoint = 'MongoDB_Credential';

        MongoDBConnection connection = new MongoDBConnection(params);

        // Setup upsert context
        DataSource.UpsertContext upsertContext = new DataSource.UpsertContext();
        upsertContext.tableSelected = 'users';
        upsertContext.rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'name' => 'New User',
                'email' => 'newuser@example.com'
            }
        };

        Test.startTest();
        List<DataSource.UpsertResult> results = connection.upsertRows(upsertContext);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assert(results[0].success, 'Upsert should succeed');
    }

    @isTest
    static void testDeleteRows() {
        // Setup mock
        String mockResponse = '{"deletedCount": 1}';
        Test.setMock(HttpCalloutMock.class, new MongoDBServiceTest.MongoDBMock(200, mockResponse));

        // Setup connection
        DataSource.ConnectionParams params = new DataSource.ConnectionParams();
        params.principalType = DataSource.IdentityType.NAMED_USER;
        params.endpoint = 'MongoDB_Credential';

        MongoDBConnection connection = new MongoDBConnection(params);

        // Setup delete context
        DataSource.DeleteContext deleteContext = new DataSource.DeleteContext();
        deleteContext.tableSelected = 'users';
        deleteContext.externalIds = new List<String>{'123'};

        Test.startTest();
        List<DataSource.DeleteResult> results = connection.deleteRows(deleteContext);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assert(results[0].success, 'Delete should succeed');
    }
}
