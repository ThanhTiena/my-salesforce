'use strict';
const { getClient } = require('./db');

/**
 * Executes a MongoDB action and returns the response body object.
 * Throws on unknown action or MongoDB error.
 *
 * Supported actions: insertOne | updateOne | find | aggregate
 */
async function executeAction(action, body) {
    const { database, collection } = body;
    if (!database || !collection) {
        const err = new Error('database and collection are required');
        err.statusCode = 400;
        throw err;
    }

    const client = await getClient();
    const coll   = client.db(database).collection(collection);

    switch (action) {
        case 'insertOne': {
            const result = await coll.insertOne(body.document ?? {});
            return { statusCode: 201, body: { insertedId: result.insertedId.toString() } };
        }
        case 'updateOne': {
            const result = await coll.updateOne(
                body.filter  ?? {},
                body.update  ?? {},
                { arrayFilters: body.arrayFilters }
            );
            return {
                statusCode: 200,
                body: { matchedCount: result.matchedCount, modifiedCount: result.modifiedCount },
            };
        }
        case 'find': {
            const docs = await coll
                .find(body.filter ?? {}, { projection: body.projection })
                .sort(body.sort ?? {})
                .limit(body.limit ?? 20)
                .toArray();
            return { statusCode: 200, body: { documents: docs } };
        }
        case 'aggregate': {
            const docs = await coll.aggregate(body.pipeline ?? []).toArray();
            return { statusCode: 200, body: { documents: docs } };
        }
        default: {
            const err = new Error(`Unknown action: ${action}`);
            err.statusCode = 400;
            throw err;
        }
    }
}

module.exports = { executeAction };
