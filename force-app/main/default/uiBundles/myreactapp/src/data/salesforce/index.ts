/** Public surface of the Salesforce data layer. */
export { isSalesforceEnv, executeGraphQL } from './client';
export {
  fetchAccounts,
  fetchAssignments,
  fetchInvoices,
  fetchTimeEntries,
  updateAccountHealth,
} from './repository';
export type {
  SfAccount,
  SfAssignment,
  SfInvoice,
  SfTimeEntry,
} from './repository';
