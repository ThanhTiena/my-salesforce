/**
 * Service class for MongoDB HTTP API callouts
 * Handles REST API calls to MongoDB Data API
 */
public class MongoDBService {
    private String endpoint;
    private String apiKey;
    private String database;
    private String dataSource;

    /**
     * Constructor using Named Credential
     * @param namedCredential Name of the Named Credential for MongoDB
     */
    public MongoDBService(String namedCredential) {
        this.endpoint = 'callout:' + namedCredential;
    }

    /**
     * Find documents in MongoDB collection
     * @param collection Collection name
     * @param filter Query filter in JSON format
     * @param projection Fields to return
     * @return List of documents as Map
     */
    public List<Map<String, Object>> find(String collection, Map<String, Object> filter, Map<String, Object> projection) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint + '/action/find');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'collection' => collection,
            'database' => '{!$Credential.Database}',
            'dataSource' => '{!$Credential.DataSource}'
        };

        if (filter != null && !filter.isEmpty()) {
            body.put('filter', filter);
        }

        if (projection != null && !projection.isEmpty()) {
            body.put('projection', projection);
        }

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (List<Map<String, Object>>) result.get('documents');
        } else {
            throw new MongoDBException('MongoDB find failed: ' + res.getStatus() + ' - ' + res.getBody());
        }
    }

    /**
     * Find one document by ID
     * @param collection Collection name
     * @param id Document ID
     * @return Document as Map
     */
    public Map<String, Object> findOne(String collection, String id) {
        Map<String, Object> filter = new Map<String, Object>{
            '_id' => new Map<String, Object>{ '$oid' => id }
        };

        List<Map<String, Object>> results = find(collection, filter, null);
        return (results != null && !results.isEmpty()) ? results[0] : null;
    }

    /**
     * Insert a document into MongoDB
     * @param collection Collection name
     * @param document Document to insert
     * @return Inserted document ID
     */
    public String insertOne(String collection, Map<String, Object> document) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint + '/action/insertOne');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'collection' => collection,
            'database' => '{!$Credential.Database}',
            'dataSource' => '{!$Credential.DataSource}',
            'document' => document
        };

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 201 || res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('insertedId');
        } else {
            throw new MongoDBException('MongoDB insert failed: ' + res.getStatus() + ' - ' + res.getBody());
        }
    }

    /**
     * Update a document in MongoDB
     * @param collection Collection name
     * @param filter Query filter
     * @param updateDoc Update operations
     * @return Number of modified documents
     */
    public Integer updateOne(String collection, Map<String, Object> filter, Map<String, Object> updateDoc) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint + '/action/updateOne');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'collection' => collection,
            'database' => '{!$Credential.Database}',
            'dataSource' => '{!$Credential.DataSource}',
            'filter' => filter,
            'update' => updateDoc
        };

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (Integer) result.get('modifiedCount');
        } else {
            throw new MongoDBException('MongoDB update failed: ' + res.getStatus() + ' - ' + res.getBody());
        }
    }

    /**
     * Delete a document from MongoDB
     * @param collection Collection name
     * @param filter Query filter
     * @return Number of deleted documents
     */
    public Integer deleteOne(String collection, Map<String, Object> filter) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint + '/action/deleteOne');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> body = new Map<String, Object>{
            'collection' => collection,
            'database' => '{!$Credential.Database}',
            'dataSource' => '{!$Credential.DataSource}',
            'filter' => filter
        };

        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (Integer) result.get('deletedCount');
        } else {
            throw new MongoDBException('MongoDB delete failed: ' + res.getStatus() + ' - ' + res.getBody());
        }
    }

    /**
     * Custom exception for MongoDB operations
     */
    public class MongoDBException extends Exception {}
}
