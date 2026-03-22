'use strict';
const { executeAction } = require('../src/actions');

jest.mock('../src/db', () => ({
    getClient: jest.fn(),
}));
const { getClient } = require('../src/db');

function makeCollection(overrides = {}) {
    return {
        insertOne:  jest.fn().mockResolvedValue({ insertedId: 'abc123' }),
        updateOne:  jest.fn().mockResolvedValue({ matchedCount: 1, modifiedCount: 1 }),
        find:       jest.fn().mockReturnValue({
            sort:  jest.fn().mockReturnThis(),
            limit: jest.fn().mockReturnThis(),
            toArray: jest.fn().mockResolvedValue([{ _id: '1' }]),
        }),
        aggregate:  jest.fn().mockReturnValue({
            toArray: jest.fn().mockResolvedValue([{ total: 5 }]),
        }),
        ...overrides,
    };
}

beforeEach(() => {
    const coll = makeCollection();
    getClient.mockResolvedValue({
        db: jest.fn().mockReturnValue({ collection: jest.fn().mockReturnValue(coll) }),
    });
});

const base = { database: 'db', collection: 'col' };

test('insertOne returns 201 with insertedId', async () => {
    const r = await executeAction('insertOne', { ...base, document: { x: 1 } });
    expect(r.statusCode).toBe(201);
    expect(r.body.insertedId).toBe('abc123');
});

test('updateOne returns 200 with counts', async () => {
    const r = await executeAction('updateOne', { ...base, filter: {}, update: { $set: { x: 1 } } });
    expect(r.statusCode).toBe(200);
    expect(r.body.matchedCount).toBe(1);
});

test('find returns 200 with documents array', async () => {
    const r = await executeAction('find', { ...base });
    expect(r.statusCode).toBe(200);
    expect(Array.isArray(r.body.documents)).toBe(true);
});

test('aggregate returns 200 with documents array', async () => {
    const r = await executeAction('aggregate', { ...base, pipeline: [] });
    expect(r.statusCode).toBe(200);
    expect(r.body.documents[0].total).toBe(5);
});

test('unknown action throws 400', async () => {
    await expect(executeAction('deleteAll', base)).rejects.toMatchObject({ statusCode: 400 });
});

test('missing collection throws 400', async () => {
    await expect(executeAction('find', { database: 'db' })).rejects.toMatchObject({ statusCode: 400 });
});
