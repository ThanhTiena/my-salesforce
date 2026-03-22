'use strict';
const { isAuthorized } = require('../src/auth');

test('passes when no API_KEY configured', () => {
    delete process.env.API_KEY;
    expect(isAuthorized({})).toBe(true);
});

test('passes with correct key (lowercase header)', () => {
    process.env.API_KEY = 'secret';
    expect(isAuthorized({ 'x-api-key': 'secret' })).toBe(true);
});

test('passes with correct key (mixed-case header)', () => {
    process.env.API_KEY = 'secret';
    expect(isAuthorized({ 'X-Api-Key': 'secret' })).toBe(true);
});

test('fails with wrong key', () => {
    process.env.API_KEY = 'secret';
    expect(isAuthorized({ 'x-api-key': 'wrong' })).toBe(false);
});

test('fails with missing key', () => {
    process.env.API_KEY = 'secret';
    expect(isAuthorized({})).toBe(false);
});
