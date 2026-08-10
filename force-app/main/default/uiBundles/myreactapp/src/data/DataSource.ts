/**
 * The app's single data contract (the "data seam" from
 * docs/ARCHITECTURE_FRONTEND.md §3).
 *
 * Pages never import `executeGraphQL` or `localStorage` directly — they talk to
 * a `DataSource`, and the environment decides the implementation:
 *   - `salesforceDataSource` wraps the uiapi repository (live org).
 *   - the LOCAL implementation is the existing `store.tsx` context; feature
 *     pages read it through `useStore()` and render CRUD from it, so there is no
 *     separate object to construct outside React.
 *
 * Reads return already-mapped view models (SfAccount, SfAssignment, SfInvoice) —
 * the uiapi `{ value }` / `edges/node` shape never leaks above this layer.
 *
 * This is intentionally a thin, additive seam: it does not replace the store or
 * touch app providers. It gives the three live pages one typed place to reach
 * Salesforce, and leaves room to grow into the full DataSourceContext described
 * in the blueprint (Phase 3) without changing page code.
 */
import {
  fetchAccounts,
  fetchAssignments,
  fetchInvoices,
  updateAccountHealth,
  type SfAccount,
  type SfAssignment,
  type SfInvoice,
} from './salesforce';

export type DataSourceKind = 'salesforce' | 'local';

export interface DataSource {
  readonly kind: DataSourceKind;
  /** Accounts → the "Clients" view. */
  listClients(first?: number): Promise<SfAccount[]>;
  /** FOPS Assignments → the "Projects" view. */
  listProjects(first?: number): Promise<SfAssignment[]>;
  /** Orders → the "Invoices" view. */
  listInvoices(first?: number): Promise<SfInvoice[]>;
  /** Sample write: update an Account's Client-Health picklist. */
  updateClientHealth(id: string, health: string): Promise<void>;
}

/** Live Salesforce implementation — wraps the typed uiapi repository. */
export const salesforceDataSource: DataSource = {
  kind: 'salesforce',
  listClients: first => fetchAccounts(first),
  listProjects: first => fetchAssignments(first),
  listInvoices: first => fetchInvoices(first),
  updateClientHealth: (id, health) => updateAccountHealth(id, health),
};
