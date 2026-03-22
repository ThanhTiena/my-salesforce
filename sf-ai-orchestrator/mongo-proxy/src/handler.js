'use strict';
const { isAuthorized } = require('./auth');
const { executeAction } = require('./actions');

const respond = (statusCode, body) => ({
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
});

/**
 * AWS Lambda entry point.
 * Route: POST /action/{action}
 */
exports.handler = async (event) => {
    if (!isAuthorized(event.headers)) {
        return respond(401, { error: 'Unauthorized' });
    }

    const action = (event.pathParameters ?? {}).action;
    if (!action) return respond(400, { error: 'Missing action in path' });

    let body;
    try {
        body = JSON.parse(event.body ?? '{}');
    } catch {
        return respond(400, { error: 'Invalid JSON body' });
    }

    try {
        const { statusCode, body: result } = await executeAction(action, body);
        return respond(statusCode, result);
    } catch (err) {
        console.error(`[mongo-proxy] ${action} error:`, err.message);
        return respond(err.statusCode ?? 500, { error: err.message });
    }
};
