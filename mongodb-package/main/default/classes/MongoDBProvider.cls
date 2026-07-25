/**
 * Salesforce Connect DataSource.Provider implementation for MongoDB
 * This class registers the MongoDB data source with Salesforce Connect
 */
global class MongoDBProvider extends DataSource.Provider {

    /**
     * Return the list of capabilities supported by this data source
     * @return List of capabilities
     */
    global override List<DataSource.Capability> getCapabilities() {
        List<DataSource.Capability> capabilities = new List<DataSource.Capability>();

        // Basic query capabilities
        capabilities.add(DataSource.Capability.ROW_QUERY);
        capabilities.add(DataSource.Capability.SEARCH);

        // Write capabilities
        capabilities.add(DataSource.Capability.ROW_CREATE);
        capabilities.add(DataSource.Capability.ROW_UPDATE);
        capabilities.add(DataSource.Capability.ROW_DELETE);

        return capabilities;
    }

    /**
     * Return the authentication capabilities for this data source
     * @return List of authentication types
     */
    global override List<DataSource.AuthenticationCapability> getAuthenticationCapabilities() {
        List<DataSource.AuthenticationCapability> authCapabilities =
            new List<DataSource.AuthenticationCapability>();

        // Support for Anonymous authentication
        authCapabilities.add(DataSource.AuthenticationCapability.ANONYMOUS);

        return authCapabilities;
    }

    /**
     * Create a connection to MongoDB
     * @param params Connection parameters
     * @return MongoDB connection instance
     */
    global override DataSource.Connection getConnection(DataSource.ConnectionParams params) {
        return new MongoDBConnection(params);
    }
}
