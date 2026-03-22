'use strict';

/**
 * Validates the X-Api-Key header against the API_KEY env variable.
 * Returns true if auth passes, false otherwise.
 */
function isAuthorized(headers = {}) {
    const expected = process.env.API_KEY;
    if (!expected) return true; // no key configured → open (dev only)
    const received = headers['x-api-key'] ?? headers['X-Api-Key'];
    return received === expected;
}

module.exports = { isAuthorized };
