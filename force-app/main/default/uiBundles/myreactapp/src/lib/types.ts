/**
 * Domain model for FreelanceHub — an all-in-one freelance management app.
 *
 * All records carry a string `id` and ISO-8601 timestamps. Monetary values
 * are stored as plain numbers in the workspace currency (see store settings).
 */

export type ClientStatus = 'active' | 'lead' | 'archived';

export interface Client {
  id: string;
  name: string;
  company?: string;
  email?: string;
  phone?: string;
  status: ClientStatus;
  notes?: string;
  createdAt: string;
}

export type ProjectStatus =
  | 'planning'
  | 'active'
  | 'on-hold'
  | 'completed'
  | 'cancelled';

export interface Project {
  id: string;
  name: string;
  clientId: string;
  status: ProjectStatus;
  /** Fixed budget for the whole project, if billed as a fixed price. */
  budget?: number;
  /** Hourly rate used to value tracked time and fee estimates. */
  hourlyRate?: number;
  startDate?: string;
  dueDate?: string;
  description?: string;
  createdAt: string;
}

export type InvoiceStatus = 'draft' | 'sent' | 'paid' | 'overdue';

export interface InvoiceLineItem {
  id: string;
  description: string;
  quantity: number;
  unitPrice: number;
}

export interface Invoice {
  id: string;
  number: string;
  clientId: string;
  projectId?: string;
  status: InvoiceStatus;
  issueDate: string;
  dueDate: string;
  lineItems: InvoiceLineItem[];
  notes?: string;
  createdAt: string;
}

export interface TimeEntry {
  id: string;
  projectId: string;
  /** Calendar day the work happened, YYYY-MM-DD. */
  date: string;
  hours: number;
  description?: string;
  /** Whether the entry has been rolled into an invoice already. */
  billed: boolean;
  createdAt: string;
}

export interface WorkspaceData {
  clients: Client[];
  projects: Project[];
  invoices: Invoice[];
  timeEntries: TimeEntry[];
  settings: {
    currency: string;
    businessName: string;
  };
}
