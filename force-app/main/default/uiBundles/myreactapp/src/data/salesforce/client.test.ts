import { describe, it, expect, afterEach, vi } from 'vitest';

// client.ts re-exports executeGraphQL from '@/api/graphqlClient', which pulls in
// the platform SDK. Mock it so importing the module never touches the real SDK;
// this test only exercises isSalesforceEnv().
vi.mock('@/api/graphqlClient', () => ({ executeGraphQL: vi.fn() }));

import { isSalesforceEnv } from './client';

const g = globalThis as { SFDC_ENV?: unknown };

afterEach(() => {
  delete g.SFDC_ENV;
});

describe('isSalesforceEnv', () => {
  it('returns false when globalThis.SFDC_ENV is undefined', () => {
    delete g.SFDC_ENV;
    expect(isSalesforceEnv()).toBe(false);
  });

  it('returns true when globalThis.SFDC_ENV is set', () => {
    g.SFDC_ENV = { some: 'context' };
    expect(isSalesforceEnv()).toBe(true);
  });

  it('treats even a falsy-but-defined SFDC_ENV as connected', () => {
    // `typeof x !== 'undefined'` is the check, so an empty string still counts.
    g.SFDC_ENV = '';
    expect(isSalesforceEnv()).toBe(true);
  });
});
