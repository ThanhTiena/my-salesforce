/**
 * Salesforce data access for the UI Bundle.
 *
 * Everything Salesforce-specific lives under `src/data/salesforce`:
 *   - client.ts      this file — the GraphQL executor + environment detection
 *   - queries.ts     the uiapi GraphQL operation strings
 *   - mappers.ts     unwrap uiapi `{ value }` nodes into flat domain objects
 *   - repository.ts  typed read/write functions the app calls
 *
 * The GraphQL executor delegates to `@salesforce/platform-sdk`'s
 * `createDataSDK()` (see src/api/graphqlClient.ts). We re-export it here so the
 * whole data layer imports from one place.
 */
export { executeGraphQL } from '@/api/graphqlClient';

/**
 * True when the app is running inside Salesforce (the platform injects
 * `SFDC_ENV`). Outside Salesforce — local `vite dev`, tests, a static preview —
 * this is false and the app falls back to the local data source, so the UI
 * always renders without a live org.
 */
export function isSalesforceEnv(): boolean {
  return typeof (globalThis as { SFDC_ENV?: unknown }).SFDC_ENV !== 'undefined';
}
