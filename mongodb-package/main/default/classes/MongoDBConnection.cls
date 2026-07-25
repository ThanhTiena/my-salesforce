/**
 * Salesforce Connect DataSource.Connection implementation for MongoDB
 * This class handles the synchronization between Salesforce and MongoDB
 */
global class MongoDBConnection extends DataSource.Connection {
    private DataSource.ConnectionParams connectionParams;
    private MongoDBService mongoService;

    /**
     * Constructor
     * @param params Connection parameters from the External Data Source
     */
    global MongoDBConnection(DataSource.ConnectionParams params) {
        this.connectionParams = params;
        // Get the named credential from connection params
        String namedCredential = params.principalType == DataSource.IdentityType.NAMED_USER
            ? params.endpoint
            : 'MongoDB_Credential';
        this.mongoService = new MongoDBService(namedCredential);
    }

    /**
     * Sync method - called when Salesforce Connect needs to retrieve data
     * @return Query results as DataSource.TableResult
     */
    global override DataSource.TableResult query(DataSource.QueryContext context) {
        DataSource.Filter filter = context.tableSelection.filter;
        String tableName = context.tableSelection.tableSelected;
        List<DataSource.ColumnSelection> columns = context.tableSelection.columnsSelected;

        // Build MongoDB filter from Salesforce query
        Map<String, Object> mongoFilter = buildMongoFilter(filter);

        // Build projection for selected columns
        Map<String, Object> projection = buildProjection(columns);

        // Query MongoDB
        List<Map<String, Object>> documents = mongoService.find(tableName, mongoFilter, projection);

        // Convert to Salesforce rows
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Map<String, Object> doc : documents) {
            rows.add(convertMongoDocToSalesforceRow(doc));
        }

        return DataSource.TableResult.get(true, null, tableName, rows);
    }

    /**
     * Search method - called for SOSL queries
     * @return Search results
     */
    global override List<DataSource.TableResult> search(DataSource.SearchContext context) {
        List<DataSource.TableResult> results = new List<DataSource.TableResult>();

        // Perform text search on each table
        for (DataSource.TableSelection tableSelection : context.tableSelections) {
            String tableName = tableSelection.tableSelected;

            // MongoDB text search filter
            Map<String, Object> filter = new Map<String, Object>{
                '$text' => new Map<String, Object>{
                    '$search' => context.searchPhrase
                }
            };

            List<Map<String, Object>> documents = mongoService.find(tableName, filter, null);
            List<Map<String, Object>> rows = new List<Map<String, Object>>();

            for (Map<String, Object> doc : documents) {
                rows.add(convertMongoDocToSalesforceRow(doc));
            }

            results.add(DataSource.TableResult.get(true, null, tableName, rows));
        }

        return results;
    }

    /**
     * Sync method to get table metadata
     * @return List of table definitions
     */
    global override List<DataSource.Table> sync() {
        List<DataSource.Table> tables = new List<DataSource.Table>();

        // Define your MongoDB collections as tables
        // Example: Users collection
        List<DataSource.Column> columns = new List<DataSource.Column>();

        columns.add(DataSource.Column.text('ExternalId', 255));
        columns.add(DataSource.Column.text('DisplayUrl', 255));
        columns.add(DataSource.Column.text('name', 255));
        columns.add(DataSource.Column.text('email', 255));
        columns.add(DataSource.Column.text('phone', 50));
        columns.add(DataSource.Column.text('status', 50));

        // Create table for 'users' collection
        tables.add(DataSource.Table.get('users', 'name', columns));

        // Add more tables/collections as needed
        // You can dynamically retrieve collection names from MongoDB if needed

        return tables;
    }

    /**
     * Upsert rows (create or update)
     * @return List of upsert results
     */
    global override List<DataSource.UpsertResult> upsertRows(DataSource.UpsertContext context) {
        List<DataSource.UpsertResult> results = new List<DataSource.UpsertResult>();
        String tableName = context.tableSelected;

        for (Map<String, Object> row : context.rows) {
            try {
                String externalId = (String) row.get('ExternalId');

                if (String.isNotBlank(externalId)) {
                    // Update existing document
                    Map<String, Object> filter = new Map<String, Object>{
                        '_id' => new Map<String, Object>{ '$oid' => externalId }
                    };

                    Map<String, Object> updateDoc = new Map<String, Object>{
                        '$set' => row
                    };

                    mongoService.updateOne(tableName, filter, updateDoc);
                    results.add(DataSource.UpsertResult.success(externalId));
                } else {
                    // Insert new document
                    String newId = mongoService.insertOne(tableName, row);
                    results.add(DataSource.UpsertResult.success(newId));
                }
            } catch (Exception e) {
                results.add(DataSource.UpsertResult.failure(
                    (String) row.get('ExternalId'),
                    'Upsert failed: ' + e.getMessage()
                ));
            }
        }

        return results;
    }

    /**
     * Delete rows
     * @return List of delete results
     */
    global override List<DataSource.DeleteResult> deleteRows(DataSource.DeleteContext context) {
        List<DataSource.DeleteResult> results = new List<DataSource.DeleteResult>();
        String tableName = context.tableSelected;

        for (String externalId : context.externalIds) {
            try {
                Map<String, Object> filter = new Map<String, Object>{
                    '_id' => new Map<String, Object>{ '$oid' => externalId }
                };

                mongoService.deleteOne(tableName, filter);
                results.add(DataSource.DeleteResult.success(externalId));
            } catch (Exception e) {
                results.add(DataSource.DeleteResult.failure(
                    externalId,
                    'Delete failed: ' + e.getMessage()
                ));
            }
        }

        return results;
    }

    /**
     * Build MongoDB filter from Salesforce filter
     * @param filter Salesforce filter
     * @return MongoDB filter map
     */
    private Map<String, Object> buildMongoFilter(DataSource.Filter filter) {
        Map<String, Object> mongoFilter = new Map<String, Object>();

        if (filter == null) {
            return mongoFilter;
        }

        if (filter.type == DataSource.FilterType.EQUALS) {
            mongoFilter.put(filter.columnName, filter.columnValue);
        } else if (filter.type == DataSource.FilterType.NOT_EQUALS) {
            mongoFilter.put(filter.columnName, new Map<String, Object>{
                '$ne' => filter.columnValue
            });
        } else if (filter.type == DataSource.FilterType.LESS_THAN) {
            mongoFilter.put(filter.columnName, new Map<String, Object>{
                '$lt' => filter.columnValue
            });
        } else if (filter.type == DataSource.FilterType.LESS_THAN_OR_EQUAL_TO) {
            mongoFilter.put(filter.columnName, new Map<String, Object>{
                '$lte' => filter.columnValue
            });
        } else if (filter.type == DataSource.FilterType.GREATER_THAN) {
            mongoFilter.put(filter.columnName, new Map<String, Object>{
                '$gt' => filter.columnValue
            });
        } else if (filter.type == DataSource.FilterType.GREATER_THAN_OR_EQUAL_TO) {
            mongoFilter.put(filter.columnName, new Map<String, Object>{
                '$gte' => filter.columnValue
            });
        } else if (filter.type == DataSource.FilterType.STARTS_WITH) {
            mongoFilter.put(filter.columnName, new Map<String, Object>{
                '$regex' => '^' + filter.columnValue,
                '$options' => 'i'
            });
        } else if (filter.type == DataSource.FilterType.ENDS_WITH) {
            mongoFilter.put(filter.columnName, new Map<String, Object>{
                '$regex' => filter.columnValue + '$',
                '$options' => 'i'
            });
        } else if (filter.type == DataSource.FilterType.CONTAINS) {
            mongoFilter.put(filter.columnName, new Map<String, Object>{
                '$regex' => (String) filter.columnValue,
                '$options' => 'i'
            });
        } else if (filter.type == DataSource.FilterType.AND_) {
            List<Map<String, Object>> andFilters = new List<Map<String, Object>>();
            andFilters.add(buildMongoFilter(filter.subfilters.get(0)));
            andFilters.add(buildMongoFilter(filter.subfilters.get(1)));
            mongoFilter.put('$and', andFilters);
        } else if (filter.type == DataSource.FilterType.OR_) {
            List<Map<String, Object>> orFilters = new List<Map<String, Object>>();
            orFilters.add(buildMongoFilter(filter.subfilters.get(0)));
            orFilters.add(buildMongoFilter(filter.subfilters.get(1)));
            mongoFilter.put('$or', orFilters);
        }

        return mongoFilter;
    }

    /**
     * Build MongoDB projection from selected columns
     * @param columns Selected columns
     * @return Projection map
     */
    private Map<String, Object> buildProjection(List<DataSource.ColumnSelection> columns) {
        if (columns == null || columns.isEmpty()) {
            return null;
        }

        Map<String, Object> projection = new Map<String, Object>();
        for (DataSource.ColumnSelection col : columns) {
            projection.put(col.columnName, 1);
        }

        return projection;
    }

    /**
     * Convert MongoDB document to Salesforce row
     * @param doc MongoDB document
     * @return Salesforce row map
     */
    private Map<String, Object> convertMongoDocToSalesforceRow(Map<String, Object> doc) {
        Map<String, Object> row = new Map<String, Object>();

        // Handle MongoDB _id field
        if (doc.containsKey('_id')) {
            Object idObj = doc.get('_id');
            if (idObj instanceof Map<String, Object>) {
                Map<String, Object> idMap = (Map<String, Object>) idObj;
                row.put('ExternalId', (String) idMap.get('$oid'));
            } else {
                row.put('ExternalId', String.valueOf(idObj));
            }
        }

        // Copy other fields
        for (String key : doc.keySet()) {
            if (key != '_id') {
                row.put(key, doc.get(key));
            }
        }

        // Set DisplayUrl for the record
        row.put('DisplayUrl', 'mongodb://document/' + row.get('ExternalId'));

        return row;
    }
}
