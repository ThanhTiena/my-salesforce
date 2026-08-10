import { describe, it, expect, vi, beforeEach } from 'vitest';

// The repository calls executeGraphQL, which client.ts re-exports from
// '@/api/graphqlClient'. Mocking that module intercepts every repository call
// without touching the platform SDK or a live org.
vi.mock('@/api/graphqlClient', () => ({ executeGraphQL: vi.fn() }));

import { executeGraphQL } from '@/api/graphqlClient';
import {
  fetchAccounts,
  fetchAssignments,
  fetchInvoices,
  fetchTimeEntries,
  updateAccountHealth,
} from './repository';
import {
  ACCOUNTS_QUERY,
  ASSIGNMENTS_QUERY,
  INVOICES_QUERY,
  ACCOUNT_UPDATE_MUTATION,
} from './queries';

const mockExec = vi.mocked(executeGraphQL);

/** Wrap a set of nodes into the uiapi connection shape for `objectName`. */
function conn(objectName: string, nodes: unknown[]) {
  return {
    uiapi: { query: { [objectName]: { edges: nodes.map(node => ({ node })) } } },
  };
}

beforeEach(() => {
  mockExec.mockReset();
});

describe('the mock actually intercepts the executor', () => {
  it('surfaces an error thrown by the mocked executeGraphQL', async () => {
    mockExec.mockRejectedValueOnce(new Error('boom from mock'));
    await expect(fetchAccounts()).rejects.toThrow('boom from mock');
  });
});

describe('fetchAccounts', () => {
  it('flattens a uiapi Account response, unwrapping { value } and null fields', async () => {
    mockExec.mockResolvedValueOnce(
      conn('Account', [
        {
          Id: 'a1',
          Name: { value: 'Acme Corp' },
          Phone: { value: '555-1000' },
          FOPS_Account_Role__c: { value: 'Client' },
          FOPS_Client_Health__c: { value: 'active' },
          FOPS_Default_Invoice_Currency__c: { value: 'USD' },
        },
        {
          // realistic partial record: nulls / missing fields collapse to null
          Id: 'a2',
          Name: { value: 'Beta LLC' },
          Phone: { value: null },
          FOPS_Account_Role__c: null,
          FOPS_Client_Health__c: { value: null },
          // FOPS_Default_Invoice_Currency__c omitted entirely
        },
      ]) as never
    );

    const rows = await fetchAccounts();

    expect(rows).toEqual([
      {
        id: 'a1',
        name: 'Acme Corp',
        phone: '555-1000',
        role: 'Client',
        health: 'active',
        currency: 'USD',
      },
      {
        id: 'a2',
        name: 'Beta LLC',
        phone: null,
        role: null,
        health: null,
        currency: null,
      },
    ]);
  });

  it('sends the ACCOUNTS_QUERY with the { first } variable', async () => {
    mockExec.mockResolvedValueOnce(conn('Account', []) as never);
    await fetchAccounts(25);
    expect(mockExec).toHaveBeenCalledWith(ACCOUNTS_QUERY, { first: 25 });
  });

  it('defaults `name` to "Untitled" when Name is missing', async () => {
    mockExec.mockResolvedValueOnce(
      conn('Account', [{ Id: 'a3', Name: null }]) as never
    );
    const [row] = await fetchAccounts();
    expect(row.name).toBe('Untitled');
  });
});

describe('fetchAssignments', () => {
  it('reads nested relationship names via __r.Name.value', async () => {
    mockExec.mockResolvedValueOnce(
      conn('FOPS_Assignment__c', [
        {
          Id: { value: 'asg1' },
          Name: { value: 'Q3 Platform Build' },
          FOPS_Status__c: { value: 'active' },
          FOPS_Start_Date__c: { value: '2026-07-01' },
          FOPS_End_Date__c: { value: '2026-09-30' },
          FOPS_Hours_Per_Week__c: { value: 40 },
          FOPS_Consultant__r: { Name: { value: 'Jane Dev' } },
          FOPS_End_Client__r: { Name: { value: 'Globex' } },
        },
      ]) as never
    );

    const rows = await fetchAssignments();
    expect(rows).toEqual([
      {
        id: 'asg1',
        name: 'Q3 Platform Build',
        status: 'active',
        startDate: '2026-07-01',
        endDate: '2026-09-30',
        hoursPerWeek: 40,
        consultant: 'Jane Dev',
        endClient: 'Globex',
      },
    ]);
    expect(mockExec).toHaveBeenCalledWith(ASSIGNMENTS_QUERY, { first: 50 });
  });

  it('nulls a relationship when the __r object is absent', async () => {
    mockExec.mockResolvedValueOnce(
      conn('FOPS_Assignment__c', [
        { Id: { value: 'asg2' }, Name: { value: 'Solo gig' } },
      ]) as never
    );
    const [row] = await fetchAssignments();
    expect(row.consultant).toBeNull();
    expect(row.endClient).toBeNull();
    expect(row.name).toBe('Solo gig');
  });
});

describe('fetchInvoices', () => {
  it('prefers FOPS_Invoice_Number__c over OrderNumber and FOPS_Invoice_Status__c over Status', async () => {
    mockExec.mockResolvedValueOnce(
      conn('Order', [
        {
          Id: { value: 'ord1' },
          OrderNumber: { value: '00000123' },
          Status: { value: 'Activated' },
          EffectiveDate: { value: '2026-08-01' },
          FOPS_Invoice_Number__c: { value: 'INV-2026-001' },
          FOPS_Invoice_Status__c: { value: 'sent' },
          FOPS_Due_Date__c: { value: '2026-08-31' },
          FOPS_Total_Amount_Base__c: { value: 12000 },
          FOPS_Balance_Due__c: { value: 12000 },
          Account: { Name: { value: 'Acme Corp' } },
        },
      ]) as never
    );

    const [row] = await fetchInvoices();
    expect(row).toEqual({
      id: 'ord1',
      number: 'INV-2026-001',
      status: 'sent',
      issueDate: '2026-08-01',
      dueDate: '2026-08-31',
      total: 12000,
      balanceDue: 12000,
      account: 'Acme Corp',
    });
    expect(mockExec).toHaveBeenCalledWith(INVOICES_QUERY, { first: 50 });
  });

  it('falls back to OrderNumber / Status when the FOPS fields are absent', async () => {
    mockExec.mockResolvedValueOnce(
      conn('Order', [
        {
          Id: { value: 'ord2' },
          OrderNumber: { value: '00000456' },
          Status: { value: 'Draft' },
          FOPS_Invoice_Number__c: { value: null },
          FOPS_Invoice_Status__c: null,
        },
      ]) as never
    );
    const [row] = await fetchInvoices();
    expect(row.number).toBe('00000456');
    expect(row.status).toBe('Draft');
    expect(row.account).toBeNull();
  });
});

describe('fetchTimeEntries', () => {
  it('maps time-entry fields and requests first=100 by default', async () => {
    mockExec.mockResolvedValueOnce(
      conn('FOPS_Time_Entry__c', [
        {
          Id: { value: 'te1' },
          FOPS_Work_Date__c: { value: '2026-08-05' },
          FOPS_Hours__c: { value: 7.5 },
          FOPS_Is_Billable__c: { value: true },
          FOPS_Description__c: { value: 'Design review' },
        },
      ]) as never
    );
    const [row] = await fetchTimeEntries();
    expect(row).toEqual({
      id: 'te1',
      date: '2026-08-05',
      hours: 7.5,
      billable: true,
      description: 'Design review',
    });
    expect(mockExec).toHaveBeenCalledWith(expect.any(String), { first: 100 });
  });
});

describe('empty / missing edges', () => {
  it('returns [] for an empty edges array', async () => {
    mockExec.mockResolvedValueOnce(conn('Account', []) as never);
    await expect(fetchAccounts()).resolves.toEqual([]);
  });

  it('returns [] when the object/edges key is missing entirely', async () => {
    mockExec.mockResolvedValueOnce({ uiapi: { query: {} } } as never);
    await expect(fetchAssignments()).resolves.toEqual([]);
  });

  it('returns [] when uiapi is missing', async () => {
    mockExec.mockResolvedValueOnce({} as never);
    await expect(fetchInvoices()).resolves.toEqual([]);
  });
});

describe('updateAccountHealth', () => {
  it('sends the mutation with input { Id, Account: { FOPS_Client_Health__c } }', async () => {
    mockExec.mockResolvedValueOnce({} as never);
    await updateAccountHealth('a1', 'at-risk');
    expect(mockExec).toHaveBeenCalledWith(ACCOUNT_UPDATE_MUTATION, {
      input: { Id: 'a1', Account: { FOPS_Client_Health__c: 'at-risk' } },
    });
  });
});
