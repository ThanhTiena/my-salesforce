/**
 * Public surface of the app's data layer.
 *
 * Pages import the data seam from here (`useResource`, `salesforceDataSource`)
 * rather than reaching into `salesforce/*` or the store directly.
 */
export { useResource } from './useResource';
export type { ResourceResult } from './useResource';
export { salesforceDataSource } from './DataSource';
export type { DataSource, DataSourceKind } from './DataSource';

// Re-export the Salesforce view models so pages have one import site.
export type { SfAccount, SfAssignment, SfInvoice } from './salesforce';
export { isSalesforceEnv } from './salesforce';
