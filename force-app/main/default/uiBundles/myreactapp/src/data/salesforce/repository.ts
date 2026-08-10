/**
 * Typed Salesforce read/write functions. Pages call these (via the
 * `useSalesforceQuery` hook) rather than touching GraphQL directly, so the
 * uiapi response shape never leaks into the UI.
 */
import { executeGraphQL } from './client';
import {
  ACCOUNTS_QUERY,
  ASSIGNMENTS_QUERY,
  INVOICES_QUERY,
  TIME_ENTRIES_QUERY,
  ACCOUNT_UPDATE_MUTATION,
} from './queries';

/** uiapi wraps every scalar as `{ value }`; this reads it back safely. */
type Scalar<T> = { value: T | null } | null | undefined;
function val<T>(field: Scalar<T>): T | null {
  return field ? (field.value ?? null) : null;
}

interface Connection<TNode> {
  uiapi?: { query?: Record<string, { edges?: Array<{ node?: TNode }> } | undefined> };
}

/** Flatten a uiapi connection for `objectName` into an array of nodes. */
function nodes<TNode>(data: Connection<TNode>, objectName: string): TNode[] {
  const conn = data.uiapi?.query?.[objectName];
  return (conn?.edges ?? [])
    .map(e => e?.node)
    .filter((n): n is TNode => Boolean(n));
}

// ---- View models the UI consumes ----------------------------------------
export interface SfAccount {
  id: string;
  name: string;
  phone: string | null;
  role: string | null;
  health: string | null;
  currency: string | null;
}

export interface SfAssignment {
  id: string;
  name: string;
  status: string | null;
  startDate: string | null;
  endDate: string | null;
  hoursPerWeek: number | null;
  consultant: string | null;
  endClient: string | null;
}

export interface SfInvoice {
  id: string;
  number: string | null;
  status: string | null;
  issueDate: string | null;
  dueDate: string | null;
  total: number | null;
  balanceDue: number | null;
  account: string | null;
}

export interface SfTimeEntry {
  id: string;
  date: string | null;
  hours: number | null;
  billable: boolean | null;
  description: string | null;
}

// ---- Reads ---------------------------------------------------------------
export async function fetchAccounts(first = 50): Promise<SfAccount[]> {
  const data = await executeGraphQL<Connection<Record<string, Scalar<unknown>>>, { first: number }>(
    ACCOUNTS_QUERY,
    { first }
  );
  return nodes<Record<string, Scalar<unknown>>>(data, 'Account').map(n => ({
    id: (val(n.Id as Scalar<string>) ?? (n.Id as unknown as string)) as string,
    name: (val(n.Name as Scalar<string>) as string) ?? 'Untitled',
    phone: val(n.Phone as Scalar<string>),
    role: val(n.FOPS_Account_Role__c as Scalar<string>),
    health: val(n.FOPS_Client_Health__c as Scalar<string>),
    currency: val(n.FOPS_Default_Invoice_Currency__c as Scalar<string>),
  }));
}

export async function fetchAssignments(first = 50): Promise<SfAssignment[]> {
  const data = await executeGraphQL<Connection<any>, { first: number }>(
    ASSIGNMENTS_QUERY,
    { first }
  );
  return nodes<any>(data, 'FOPS_Assignment__c').map(n => ({
    id: n.Id?.value ?? n.Id,
    name: val<string>(n.Name) ?? 'Assignment',
    status: val<string>(n.FOPS_Status__c),
    startDate: val<string>(n.FOPS_Start_Date__c),
    endDate: val<string>(n.FOPS_End_Date__c),
    hoursPerWeek: val<number>(n.FOPS_Hours_Per_Week__c),
    consultant: n.FOPS_Consultant__r?.Name?.value ?? null,
    endClient: n.FOPS_End_Client__r?.Name?.value ?? null,
  }));
}

export async function fetchInvoices(first = 50): Promise<SfInvoice[]> {
  const data = await executeGraphQL<Connection<any>, { first: number }>(
    INVOICES_QUERY,
    { first }
  );
  return nodes<any>(data, 'Order').map(n => ({
    id: n.Id?.value ?? n.Id,
    number: val<string>(n.FOPS_Invoice_Number__c) ?? val<string>(n.OrderNumber),
    status: val<string>(n.FOPS_Invoice_Status__c) ?? val<string>(n.Status),
    issueDate: val<string>(n.EffectiveDate),
    dueDate: val<string>(n.FOPS_Due_Date__c),
    total: val<number>(n.FOPS_Total_Amount_Base__c),
    balanceDue: val<number>(n.FOPS_Balance_Due__c),
    account: n.Account?.Name?.value ?? null,
  }));
}

export async function fetchTimeEntries(first = 100): Promise<SfTimeEntry[]> {
  const data = await executeGraphQL<Connection<any>, { first: number }>(
    TIME_ENTRIES_QUERY,
    { first }
  );
  return nodes<any>(data, 'FOPS_Time_Entry__c').map(n => ({
    id: n.Id?.value ?? n.Id,
    date: val<string>(n.FOPS_Work_Date__c),
    hours: val<number>(n.FOPS_Hours__c),
    billable: val<boolean>(n.FOPS_Is_Billable__c),
    description: val<string>(n.FOPS_Description__c),
  }));
}

// ---- Writes --------------------------------------------------------------
/** Update the FreelanceOps "Client Health" picklist on an Account. */
export async function updateAccountHealth(
  accountId: string,
  health: string
): Promise<void> {
  await executeGraphQL(ACCOUNT_UPDATE_MUTATION, {
    input: { Id: accountId, Account: { FOPS_Client_Health__c: health } },
  });
}
