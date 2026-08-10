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
 * True when the app is running inside Salesforce. Detected from several
 * signals so it's robust across runtimes:
 *   1. the platform-injected `SFDC_ENV` global, or
 *   2. a Salesforce host (`*.force.com` / `*.salesforce.com`), or
 *   3. an LWR bundle path (`/lwr/`).
 * Outside Salesforce — local `vite dev`, tests, a static preview — all three
 * are false and the app falls back to the local data source, so the UI always
 * renders without a live org. Users can still force a live query with the
 * "Connect" button, which surfaces any GraphQL error verbatim.
 */
export function isSalesforceEnv(): boolean {
  if (typeof (globalThis as { SFDC_ENV?: unknown }).SFDC_ENV !== 'undefined') {
    return true;
  }
  try {
    const loc = (globalThis as { location?: { hostname?: string; pathname?: string } })
      .location;
    const host = loc?.hostname ?? '';
    const path = loc?.pathname ?? '';
    return (
      host.includes('force.com') ||
      host.includes('salesforce.com') ||
      path.includes('/lwr/')
    );
  } catch {
    return false;
  }
}
