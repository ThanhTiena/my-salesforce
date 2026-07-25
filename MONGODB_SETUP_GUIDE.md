# MongoDB Salesforce Connect Integration - Setup Guide

This guide will help you set up Salesforce Connect with MongoDB using the custom Apex adapter.

## Prerequisites

1. MongoDB Atlas account with Data API enabled
2. Salesforce org with API enabled
3. System Administrator access to Salesforce

## Architecture Overview

The integration consists of:
- **MongoDBService.cls** - HTTP callout handler for MongoDB Data API
- **MongoDBConnection.cls** - DataSource.Connection implementation
- **MongoDBProvider.cls** - DataSource.Provider implementation
- **Test Classes** - MongoDBServiceTest and MongoDBProviderTest

## Setup Steps

### 1. MongoDB Atlas Configuration

1. **Enable MongoDB Data API:**
   - Go to your MongoDB Atlas dashboard
   - Navigate to "Data API" section
   - Enable the Data API
   - Create an API key and save it securely
   - Note your App ID and Data Source name

2. **Get your connection details:**
   ```
   Endpoint: https://data.mongodb-api.com/app/{YOUR_APP_ID}/endpoint/data/v1
   API Key: {YOUR_API_KEY}
   Database: {YOUR_DATABASE_NAME}
   Data Source: {YOUR_CLUSTER_NAME}
   ```

### 2. Deploy Apex Classes to Salesforce

Deploy all the created Apex classes using Salesforce CLI:

```bash
sf project deploy start --source-dir force-app/main/default/classes
```

Or use your preferred deployment method (Change Sets, VS Code, etc.)

### 3. Create Named Credential

**Option A: Using Setup UI (Recommended)**

1. Go to **Setup** → **Named Credentials**
2. Click **New Named Credential**
3. Configure as follows:
   - **Label:** MongoDB Credential
   - **Name:** MongoDB_Credential
   - **URL:** `https://data.mongodb-api.com/app/YOUR_APP_ID/endpoint/data/v1`
   - **Identity Type:** Named Principal
   - **Authentication Protocol:** Password Authentication
   - **Username:** (leave blank or use any value)
   - **Password:** YOUR_API_KEY
4. Under **Callout Options:**
   - Check "Generate Authorization Header": **Unchecked**
   - Check "Allow Merge Fields in HTTP Header": **Checked**
   - Check "Allow Merge Fields in HTTP Body": **Checked**
5. Add **Custom Headers:**
   - Header Name: `api-key`
   - Value: `{!$Credential.Password}`
   - Header Name: `Content-Type`
   - Value: `application/json`
6. Add **Custom Parameters:**
   - Parameter Name: `Database`
   - Value: YOUR_DATABASE_NAME
   - Parameter Name: `DataSource`
   - Value: YOUR_CLUSTER_NAME
7. Click **Save**

**Option B: Using Metadata API**

Edit the file `force-app/main/default/namedCredentials/MongoDB_Credential.namedCredential-meta.xml` with your values and deploy it.

### 4. Add Remote Site Settings

1. Go to **Setup** → **Remote Site Settings**
2. Click **New Remote Site**
3. Configure:
   - **Remote Site Name:** MongoDB_API
   - **Remote Site URL:** `https://data.mongodb-api.com`
   - **Active:** Checked
4. Click **Save**

### 5. Create External Data Source

1. Go to **Setup** → **External Data Sources**
2. Click **New External Data Source**
3. Configure:
   - **Label:** MongoDB External Data
   - **Name:** MongoDB_External_Data
   - **Type:** Select "Salesforce Connect: Custom (Apex)"
   - **Apex Class:** MongoDBProvider
   - **Identity Type:** Named Principal
   - **Named Credential:** MongoDB_Credential
4. Click **Save**
5. Click **Validate and Sync** to retrieve tables from MongoDB

### 6. Customize Collections (Optional)

To add more MongoDB collections, edit the `sync()` method in `MongoDBConnection.cls`:

```apex
global override List<DataSource.Table> sync() {
    List<DataSource.Table> tables = new List<DataSource.Table>();

    // Example: Add a "products" collection
    List<DataSource.Column> productColumns = new List<DataSource.Column>();
    productColumns.add(DataSource.Column.text('ExternalId', 255));
    productColumns.add(DataSource.Column.text('DisplayUrl', 255));
    productColumns.add(DataSource.Column.text('name', 255));
    productColumns.add(DataSource.Column.number('price', 18, 2));
    productColumns.add(DataSource.Column.text('category', 100));

    tables.add(DataSource.Table.get('products', 'name', productColumns));

    return tables;
}
```

## Usage Examples

### Query External Objects (SOQL)

Once set up, you can query MongoDB data using SOQL:

```apex
// Query all users
List<users__x> mongoUsers = [SELECT ExternalId, name__c, email__c FROM users__x];

// Query with filter
List<users__x> activeUsers = [SELECT name__c, email__c FROM users__x WHERE status__c = 'active'];

// Query with LIMIT
List<users__x> topUsers = [SELECT name__c FROM users__x LIMIT 10];
```

### Direct API Usage

You can also use the MongoDBService class directly:

```apex
// Initialize service
MongoDBService mongo = new MongoDBService('MongoDB_Credential');

// Find documents
Map<String, Object> filter = new Map<String, Object>{'status' => 'active'};
List<Map<String, Object>> results = mongo.find('users', filter, null);

// Insert document
Map<String, Object> newUser = new Map<String, Object>{
    'name' => 'John Doe',
    'email' => 'john@example.com',
    'status' => 'active'
};
String insertedId = mongo.insertOne('users', newUser);

// Update document
Map<String, Object> updateFilter = new Map<String, Object>{
    '_id' => new Map<String, Object>{'$oid' => insertedId}
};
Map<String, Object> update = new Map<String, Object>{
    '$set' => new Map<String, Object>{'status' => 'inactive'}
};
mongo.updateOne('users', updateFilter, update);

// Delete document
mongo.deleteOne('users', updateFilter);
```

### Search (SOSL)

```apex
List<List<SObject>> searchResults = [
    FIND 'John' IN ALL FIELDS
    RETURNING users__x(name__c, email__c)
];
```

## Testing

Run the test classes to ensure everything is working:

```bash
sf apex run test --class-names MongoDBServiceTest,MongoDBProviderTest --result-format human
```

## Troubleshooting

### Common Issues

1. **"Unauthorized" Error:**
   - Verify your API key is correct
   - Check that the api-key header is properly configured in Named Credential

2. **"Remote Site Not Allowed":**
   - Add `https://data.mongodb-api.com` to Remote Site Settings

3. **"No data returned":**
   - Verify your database and collection names are correct
   - Check that your MongoDB cluster is accessible
   - Review the Data API logs in MongoDB Atlas

4. **"External object not visible":**
   - After syncing, go to Setup → External Objects
   - Click on your external object (e.g., users__x)
   - Add it to page layouts or create tabs as needed

## Security Considerations

1. **API Key Security:**
   - Never hardcode API keys in code
   - Use Named Credentials to store credentials securely
   - Rotate API keys regularly

2. **Field-Level Security:**
   - Configure field permissions on external objects
   - Use profiles and permission sets to control access

3. **Callout Limits:**
   - Salesforce has a limit of 100 callouts per transaction
   - Implement pagination for large datasets
   - Consider caching strategies for frequently accessed data

## Performance Tips

1. **Use filters in queries** to reduce data transfer
2. **Select only needed fields** using projection
3. **Implement pagination** for large result sets
4. **Create indexes** in MongoDB for filtered fields
5. **Monitor API usage** in MongoDB Atlas

## Advanced Configuration

### Pagination Support

To add pagination, modify the `query()` method in MongoDBConnection.cls to handle DataSource.QueryContext offset and limit.

### Caching

Consider implementing Platform Cache to reduce MongoDB API calls for frequently accessed data.

### Batch Operations

For bulk operations, use MongoDB's `insertMany`, `updateMany`, and `deleteMany` endpoints.

## Support

For issues or questions:
- MongoDB Atlas: https://docs.atlas.mongodb.com/api/data-api/
- Salesforce Connect: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_connector_start.htm

## Next Steps

1. Create custom Lightning Web Components to display MongoDB data
2. Set up bi-directional sync workflows
3. Implement change data capture for real-time updates
4. Add custom validation rules on external objects
