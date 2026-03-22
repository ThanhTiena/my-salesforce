'use strict';
/**
 * MongoDB REST Proxy — AWS Lambda handler
 *
 * Replaces the deprecated MongoDB Atlas Data API (EOL Sep 30 2025).
 * Accepts the same JSON body shape so Salesforce Apex requires minimal changes.
 *
 * Supported actions (POST /action/<action>):
 *   insertOne   – insert a single document
 *   updateOne   – update a single document
 *   find        – find documents
 *   aggregate   – run an aggregation pipeline
 *
 * Auth: API key passed via X-Api-Key header (configure in API Gateway or check here)
 *
 * Deploy:
 *   1. npm install
 *   2. zip -r proxy.zip . && aws lambda update-function-code --function-name mongo-proxy --zip-file fileb://proxy.zip
 *   OR use Serverless Framework / SAM / CDK (see README)
 *
 * Environment variables:
 *   MONGODB_URI   – MongoDB connection string (e.g. mongodb+srv://user:pass@cluster.mongodb.net)
 *   API_KEY       – Secret key that Salesforce must send in X-Api-Key header
 */

const { MongoClient } = require('mongodb');

let cachedClient = null;

async function getClient(uri) {
    if (!cachedClient) {
        cachedClient = new MongoClient(uri, { serverSelectionTimeoutMS: 10000 });
        await cachedClient.connect();
    }
    return cachedClient;
}

exports.handler = async (event) => {
    // ── Auth check ──────────────────────────────────────────────────────────
    const expectedKey = process.env.API_KEY;
    const receivedKey = (event.headers || {})['x-api-key'] || (event.headers || {})['X-Api-Key'];
    if (expectedKey && receivedKey !== expectedKey) {
        return respond(401, { error: 'Unauthorized' });
    }

    // ── Route: POST /action/<action> ─────────────────────────────────────────
    const action = (event.pathParameters || {}).action;
    if (!action) return respond(400, { error: 'Missing action in path' });

    let body;
    try {
        body = JSON.parse(event.body || '{}');
    } catch (_) {
        return respond(400, { error: 'Invalid JSON body' });
    }

    const { dataSource, database, collection } = body;
    if (!database || !collection) {
        return respond(400, { error: 'database and collection are required' });
    }

    try {
        const client = await getClient(process.env.MONGODB_URI);
        const db     = client.db(database);
        const coll   = db.collection(collection);

        switch (action) {
            case 'insertOne': {
                const result = await coll.insertOne(body.document || {});
                return respond(201, { insertedId: result.insertedId.toString() });
            }
            case 'updateOne': {
                const result = await coll.updateOne(
                    body.filter   || {},
                    body.update   || {},
                    { arrayFilters: body.arrayFilters }
                );
                return respond(200, {
                    matchedCount:  result.matchedCount,
                    modifiedCount: result.modifiedCount,
                });
            }
            case 'find': {
                const cursor = coll
                    .find(body.filter || {}, { projection: body.projection })
                    .sort(body.sort || {})
                    .limit(body.limit || 20);
                const documents = await cursor.toArray();
                return respond(200, { documents });
            }
            case 'aggregate': {
                const documents = await coll.aggregate(body.pipeline || []).toArray();
                return respond(200, { documents });
            }
            default:
                return respond(400, { error: `Unknown action: ${action}` });
        }
    } catch (err) {
        console.error('MongoDB error:', err);
        return respond(500, { error: err.message });
    }
};

function respond(statusCode, body) {
    return {
        statusCode,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    };
}
