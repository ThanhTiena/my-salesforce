import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

// Mock the whole Salesforce data layer so the page never touches GraphQL/the SDK.
// isSalesforceEnv drives the connected/not-connected branch; the fetchers drive
// loading/error/empty/data.
vi.mock('@/data/salesforce', () => ({
  isSalesforceEnv: vi.fn(),
  fetchAccounts: vi.fn(),
  fetchAssignments: vi.fn(),
  fetchInvoices: vi.fn(),
}));

import Salesforce from './Salesforce';
import {
  isSalesforceEnv,
  fetchAccounts,
  fetchAssignments,
  fetchInvoices,
} from '@/data/salesforce';

const mockIsEnv = vi.mocked(isSalesforceEnv);
const mockAccounts = vi.mocked(fetchAccounts);
const mockAssignments = vi.mocked(fetchAssignments);
const mockInvoices = vi.mocked(fetchInvoices);

const SAMPLE_ACCOUNTS = [
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
];

beforeEach(() => {
  mockIsEnv.mockReset();
  mockAccounts.mockReset();
  mockAssignments.mockReset();
  mockInvoices.mockReset();
  // Default the non-active tabs so they never reject if ever rendered.
  mockAssignments.mockResolvedValue([]);
  mockInvoices.mockResolvedValue([]);
});

describe('Salesforce page — not connected', () => {
  beforeEach(() => mockIsEnv.mockReturnValue(false));

  it('shows the "Not connected" state and does NOT call the fetcher', async () => {
    render(<Salesforce />);

    expect(
      await screen.findByText(/not connected to salesforce/i)
    ).toBeInTheDocument();
    // Both affordances are present: header Connect + in-card Load.
    expect(
      screen.getByRole('button', { name: /^connect$/i })
    ).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: /load from salesforce/i })
    ).toBeInTheDocument();

    expect(mockAccounts).not.toHaveBeenCalled();
  });
});

describe('Salesforce page — enabling fetch', () => {
  it('clicking Connect enables fetching and renders the rows', async () => {
    mockIsEnv.mockReturnValue(false);
    mockAccounts.mockResolvedValue(SAMPLE_ACCOUNTS);

    const user = userEvent.setup();
    render(<Salesforce />);

    expect(mockAccounts).not.toHaveBeenCalled();
    await user.click(screen.getByRole('button', { name: /^connect$/i }));

    expect(await screen.findByText('Acme Corp')).toBeInTheDocument();
    expect(screen.getByText('Beta LLC')).toBeInTheDocument();
    expect(mockAccounts).toHaveBeenCalled();
  });

  it('fetches automatically when running inside Salesforce (detected env)', async () => {
    mockIsEnv.mockReturnValue(true);
    mockAccounts.mockResolvedValue(SAMPLE_ACCOUNTS);

    render(<Salesforce />);

    expect(await screen.findByText('Acme Corp')).toBeInTheDocument();
    expect(mockAccounts).toHaveBeenCalled();
    // No "Connect" button when already inside Salesforce.
    expect(
      screen.queryByRole('button', { name: /^connect$/i })
    ).not.toBeInTheDocument();
  });
});

describe('Salesforce page — data states (detected env)', () => {
  beforeEach(() => mockIsEnv.mockReturnValue(true));

  it('renders the error state with the verbatim error message on rejection', async () => {
    // useAsyncData logs the error to console.error; keep test output clean.
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});
    mockAccounts.mockRejectedValue(new Error('GraphQL Error: insufficient access'));

    render(<Salesforce />);

    expect(
      await screen.findByText(/couldn't load records/i)
    ).toBeInTheDocument();
    expect(
      screen.getByText('GraphQL Error: insufficient access')
    ).toBeInTheDocument();
    expect(
      screen.getByRole('button', { name: /retry/i })
    ).toBeInTheDocument();

    spy.mockRestore();
  });

  it('renders "No records yet" when the fetch resolves empty', async () => {
    mockAccounts.mockResolvedValue([]);

    render(<Salesforce />);

    expect(await screen.findByText(/no records yet/i)).toBeInTheDocument();
  });

  it('renders a table row per record when the fetch resolves with data', async () => {
    mockAccounts.mockResolvedValue(SAMPLE_ACCOUNTS);

    render(<Salesforce />);

    expect(await screen.findByText('Acme Corp')).toBeInTheDocument();
    // Column headers present -> the table (not a state card) is rendered.
    expect(screen.getByText('Account')).toBeInTheDocument();
    expect(screen.getByText('Health')).toBeInTheDocument();
    // Nulls fall back to the em-dash placeholder.
    expect(screen.getAllByText('—').length).toBeGreaterThan(0);
  });
});

describe('Salesforce page — in-card "Load from Salesforce" affordance', () => {
  // The in-card button flips `forced` (onConnect), which enables the fetch —
  // same effect as the header "Connect".
  it('clicking "Load from Salesforce" enables the fetch and renders rows', async () => {
    mockIsEnv.mockReturnValue(false);
    mockAccounts.mockResolvedValue(SAMPLE_ACCOUNTS);

    const user = userEvent.setup();
    render(<Salesforce />);

    await user.click(
      screen.getByRole('button', { name: /load from salesforce/i })
    );

    // Now connected: the fetcher runs and the account rows render.
    await waitFor(() => expect(mockAccounts).toHaveBeenCalled());
    expect(
      await screen.findByText(SAMPLE_ACCOUNTS[0].name)
    ).toBeInTheDocument();
  });
});

afterEach(() => {
  vi.clearAllMocks();
});
