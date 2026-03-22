'use strict';
const { MongoClient } = require('mongodb');

let cachedClient = null;

async function getClient() {
    if (!cachedClient) {
        cachedClient = new MongoClient(process.env.MONGODB_URI, {
            serverSelectionTimeoutMS: 10000,
        });
        await cachedClient.connect();
    }
    return cachedClient;
}

module.exports = { getClient };
