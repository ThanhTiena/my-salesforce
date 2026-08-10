import { useMemo, useState, type ReactNode } from 'react';
import {
  AlertTriangle,
  CalendarDays,
  CheckCircle2,
  Clock,
  FolderKanban,
  Inbox,
  RefreshCw,
  Wallet,
} from 'lucide-react';

import {
  fetchInvoices,
  fetchAssignments,
  fetchTimeEntries,
  type SfInvoice,
  type SfAssignment,
  type SfTimeEntry,
} from '@/data/salesforce';
import { useAsyncData } from '@/hooks/useAsyncData';
import { formatCurrency, formatDate } from '@/lib/format';
import { LoadingTable, SfStateCard } from '@/data/live-view';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import { Stagger } from '@/components/motion';
import { StatusBadge } from '@/components/common/status-badge';
import {
  Button,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from '@/components/ui';

/** Statuses (lower-cased) that count an assignment as in-flight. */
const ACTIVE_ASSIGNMENT_STATUSES = new Set([
  'active',
  'in progress',
  'in-progress',
  'ongoing',
  'current',
  'booked',
  'open',
]);

function isActiveAssignment(status: string | null): boolean {
  return ACTIVE_ASSIGNMENT_STATUSES.has((status ?? '').toLowerCase());
}

/** Balance still owed on an invoice (falls back to its total). */
function invoiceOutstanding(inv: SfInvoice): number {
  return inv.balanceDue ?? inv.total ?? 0;
}

/** Small inline placeholder shown when a single section's slice is empty. */
function SectionEmpty({ children }: { children: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 px-4 py-10 text-center">
      <span className="flex size-10 items-center justify-center rounded-full bg-muted text-muted-foreground">
        <Inbox className="size-5" />
      </span>
      <p className="text-xs text-muted-foreground">{children}</p>
    </div>
  );
}

type DashboardData = [SfInvoice[], SfAssignment[], SfTimeEntry[]];

export default function Dashboard() {
  // Reload via a generation counter fed into the fetcher's deps.
  const [gen, setGen] = useState(0);
  const reload = () => setGen(g => g + 1);

  const { data, loading, error } = useAsyncData<DashboardData>(
    () => Promise.all([fetchInvoices(), fetchAssignments(), fetchTimeEntries()]),
    [gen]
  );

  const invoices = useMemo(() => data?.[0] ?? [], [data]);
  const assignments = useMemo(() => data?.[1] ?? [], [data]);
  const timeEntries = useMemo(() => data?.[2] ?? [], [data]);

  // --- KPI figures ----------------------------------------------------------
  const kpis = useMemo(() => {
    let outstanding = 0;
    let outstandingCount = 0;
    let overdue = 0;
    let overdueCount = 0;
    let paid = 0;
    let paidCount = 0;

    for (const inv of invoices) {
      const status = (inv.status ?? '').toLowerCase();
      const owed = invoiceOutstanding(inv);
      if (status === 'sent' || status === 'overdue' || (inv.balanceDue ?? 0) > 0) {
        outstanding += owed;
        outstandingCount += 1;
      }
      if (status === 'overdue') {
        overdue += owed;
        overdueCount += 1;
      }
      if (status === 'paid') {
        paid += inv.total ?? 0;
        paidCount += 1;
      }
    }

    const activeAssignments = assignments.filter(a =>
      isActiveAssignment(a.status)
    ).length;

    const hoursLogged = timeEntries.reduce(
      (sum, entry) => sum + (entry.hours ?? 0),
      0
    );

    return {
      outstanding,
      outstandingCount,
      overdue,
      overdueCount,
      paid,
      paidCount,
      activeAssignments,
      totalAssignments: assignments.length,
      hoursLogged,
    };
  }, [invoices, assignments, timeEntries]);

  // --- Income for the last 6 months (paid invoices by issue month) ----------
  const income = useMemo(() => {
    const now = new Date();
    const keys: string[] = [];
    for (let i = 5; i >= 0; i -= 1) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      keys.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
    }
    const totals = new Map<string, number>(keys.map(k => [k, 0]));
    for (const inv of invoices) {
      if ((inv.status ?? '').toLowerCase() !== 'paid') continue;
      const key = (inv.issueDate ?? '').slice(0, 7);
      if (totals.has(key)) {
        totals.set(key, (totals.get(key) ?? 0) + (inv.total ?? 0));
      }
    }
    const bars = keys.map(key => {
      const [y, m] = key.split('-');
      const label = new Date(Number(y), Number(m) - 1, 1).toLocaleDateString(
        'en-US',
        { month: 'short' }
      );
      return { key, label, value: totals.get(key) ?? 0 };
    });
    const max = Math.max(0, ...bars.map(b => b.value));
    const total = bars.reduce((sum, b) => sum + b.value, 0);
    return { bars, max, total };
  }, [invoices]);

  // --- Recent invoices (newest first by issue date) -------------------------
  const recentInvoices = useMemo(
    () =>
      [...invoices]
        .sort((a, b) => (b.issueDate ?? '').localeCompare(a.issueDate ?? ''))
        .slice(0, 5),
    [invoices]
  );

  // --- Active assignments ---------------------------------------------------
  const activeAssignmentRows = useMemo(
    () => assignments.filter(a => isActiveAssignment(a.status)),
    [assignments]
  );

  const header = (
    <PageHeader
      title="Dashboard"
      description="Your freelance business at a glance."
      actions={
        <div className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-1.5 text-sm text-muted-foreground">
          <CalendarDays className="size-4" />
          <span className="tabular-nums">{formatDate(new Date().toISOString())}</span>
        </div>
      }
    />
  );

  // --- Loading --------------------------------------------------------------
  if (loading) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {header}
        <Card className="mt-6">
          <CardContent className="px-0">
            <LoadingTable cols={4} />
          </CardContent>
        </Card>
      </div>
    );
  }

  // --- Error (verbatim message + Retry) -------------------------------------
  if (error) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {header}
        <Card className="mt-6">
          <SfStateCard
            icon={AlertTriangle}
            tone="danger"
            title="Couldn't load records"
            message={error}
            action={
              <Button size="sm" variant="outline" onClick={reload}>
                <RefreshCw className="size-4" /> Retry
              </Button>
            }
          />
        </Card>
      </div>
    );
  }

  // --- All three slices empty -> "No data" ----------------------------------
  const allEmpty =
    invoices.length === 0 &&
    assignments.length === 0 &&
    timeEntries.length === 0;

  if (allEmpty) {
    return (
      <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {header}
        <Card className="mt-6">
          <SfStateCard
            icon={Inbox}
            title="No data"
            message="No records in Salesforce yet."
            action={
              <Button size="sm" variant="outline" onClick={reload}>
                <RefreshCw className="size-4" /> Refresh
              </Button>
            }
          />
        </Card>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      {header}

      {/* KPI row */}
      <Stagger
        step={70}
        className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-5"
      >
        <StatCard
          label="Outstanding"
          value={formatCurrency(kpis.outstanding)}
          numericValue={kpis.outstanding}
          format={v => formatCurrency(v)}
          hint={`${kpis.outstandingCount} open invoice${kpis.outstandingCount === 1 ? '' : 's'}`}
          icon={Wallet}
          accent="text-amber-600"
          iconClassName="bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-300"
        />
        <StatCard
          label="Overdue"
          value={formatCurrency(kpis.overdue)}
          numericValue={kpis.overdue}
          format={v => formatCurrency(v)}
          hint={`${kpis.overdueCount} past due`}
          icon={AlertTriangle}
          accent={kpis.overdue > 0 ? 'text-rose-600' : 'text-emerald-600'}
          iconClassName={
            kpis.overdue > 0
              ? 'bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-300'
              : 'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300'
          }
        />
        <StatCard
          label="Paid (all time)"
          value={formatCurrency(kpis.paid)}
          numericValue={kpis.paid}
          format={v => formatCurrency(v)}
          hint={`${kpis.paidCount} invoice${kpis.paidCount === 1 ? '' : 's'}`}
          icon={CheckCircle2}
          accent="text-emerald-600"
          iconClassName="bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300"
        />
        <StatCard
          label="Active assignments"
          value={String(kpis.activeAssignments)}
          numericValue={kpis.activeAssignments}
          hint={`of ${kpis.totalAssignments} total`}
          icon={FolderKanban}
          iconClassName="bg-indigo-100 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-300"
        />
        <StatCard
          label="Hours logged"
          value={kpis.hoursLogged.toLocaleString('en-US')}
          numericValue={kpis.hoursLogged}
          format={v => `${Math.round(v).toLocaleString('en-US')} hrs`}
          hint={`${timeEntries.length} time entr${timeEntries.length === 1 ? 'y' : 'ies'}`}
          icon={Clock}
          accent="text-sky-600"
          iconClassName="bg-sky-100 text-sky-700 dark:bg-sky-500/15 dark:text-sky-300"
        />
      </Stagger>

      {/* Bento: income chart + recent invoices */}
      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Income (last 6 months)</CardTitle>
            <CardDescription>
              Paid invoices ·{' '}
              <span className="tabular-nums font-medium text-foreground">
                {formatCurrency(income.total)}
              </span>{' '}
              collected
            </CardDescription>
          </CardHeader>
          <CardContent>
            {income.total > 0 ? (
              <div>
                <div className="flex h-40 items-end gap-2 sm:gap-3">
                  {income.bars.map(bar => {
                    const pct =
                      income.max > 0 && bar.value > 0
                        ? Math.max((bar.value / income.max) * 100, 6)
                        : 0;
                    return (
                      <div
                        key={bar.key}
                        className="flex h-full flex-1 flex-col justify-end"
                        title={`${bar.label}: ${formatCurrency(bar.value)}`}
                      >
                        <div
                          className="w-full rounded-t-md bg-primary transition-[height] duration-300 ease-out hover:bg-primary/90"
                          style={{ height: `${pct}%` }}
                        />
                      </div>
                    );
                  })}
                </div>
                <div className="mt-2 flex gap-2 sm:gap-3">
                  {income.bars.map(bar => (
                    <span
                      key={bar.key}
                      className="flex-1 text-center text-xs text-muted-foreground"
                    >
                      {bar.label}
                    </span>
                  ))}
                </div>
              </div>
            ) : (
              <SectionEmpty>
                No paid invoices in the last six months.
              </SectionEmpty>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Recent invoices</CardTitle>
            <CardDescription>Your latest activity</CardDescription>
          </CardHeader>
          <CardContent className="px-0">
            {recentInvoices.length > 0 ? (
              <ul className="divide-y divide-border">
                {recentInvoices.map(inv => (
                  <li
                    key={inv.id}
                    className="flex items-center justify-between gap-3 px-4 py-3 transition-colors hover:bg-muted/50"
                  >
                    <div className="min-w-0">
                      <p className="truncate text-sm font-medium text-foreground">
                        {inv.number ?? 'Untitled'}
                      </p>
                      <p className="truncate text-xs text-muted-foreground">
                        {inv.account ?? 'Unknown'} · {formatDate(inv.issueDate ?? undefined)}
                      </p>
                    </div>
                    <div className="flex shrink-0 items-center gap-3">
                      <span className="text-sm font-medium tabular-nums text-foreground">
                        {formatCurrency(inv.total ?? 0)}
                      </span>
                      <StatusBadge status={(inv.status ?? 'unknown').toLowerCase()} />
                    </div>
                  </li>
                ))}
              </ul>
            ) : (
              <SectionEmpty>No invoices in Salesforce yet.</SectionEmpty>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Active assignments table */}
      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Active assignments</CardTitle>
          <CardDescription>
            In-flight assignments with consultant, end client, and weekly hours.
          </CardDescription>
        </CardHeader>
        <CardContent className="px-0">
          {activeAssignmentRows.length > 0 ? (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="pl-4">Assignment</TableHead>
                    <TableHead>Consultant</TableHead>
                    <TableHead>End client</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="pr-4 text-right">Hrs / wk</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {activeAssignmentRows.map(a => (
                    <TableRow key={a.id}>
                      <TableCell className="pl-4 font-medium text-foreground">
                        {a.name}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {a.consultant ?? '—'}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {a.endClient ?? '—'}
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={(a.status ?? 'unknown').toLowerCase()} />
                      </TableCell>
                      <TableCell className="pr-4 text-right tabular-nums">
                        {a.hoursPerWeek != null
                          ? a.hoursPerWeek.toLocaleString('en-US')
                          : '—'}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          ) : (
            <div className="px-4 pb-2">
              <SectionEmpty>
                {assignments.length > 0
                  ? 'No active assignments right now.'
                  : 'No assignments in Salesforce yet.'}
              </SectionEmpty>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
