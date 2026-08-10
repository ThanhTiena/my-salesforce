import { useMemo, useState } from 'react';
import {
  AlertTriangle,
  CheckCircle2,
  CircleDollarSign,
  Database,
  Inbox,
  RefreshCw,
} from 'lucide-react';

import { useAsyncData } from '@/hooks/useAsyncData';
import { fetchInvoices, type SfInvoice } from '@/data/salesforce';
import { SfStateCard, LoadingTable } from '@/data/live-view';
import { formatCurrency, formatDate, todayISO } from '@/lib/format';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import { StatusBadge } from '@/components/common/status-badge';
import { Reveal } from '@/components/motion';
import {
  Button,
  Card,
  CardContent,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui';

/**
 * Reads FreelanceOps Orders (invoices) from Salesforce. `reload()` bumps a
 * generation counter so the fetcher re-runs; any GraphQL error is verbatim.
 */
function useSfInvoices() {
  const [gen, setGen] = useState(0);
  const { data, loading, error } = useAsyncData<SfInvoice[]>(
    () => fetchInvoices(),
    [gen]
  );
  return {
    rows: data ?? [],
    loading,
    error,
    reload: () => setGen(g => g + 1),
  };
}

/** Small static source indicator shown in the page header. */
function SalesforceIndicator() {
  return (
    <span className="bg-muted text-muted-foreground inline-flex w-fit shrink-0 items-center gap-1.5 self-center rounded-full px-2.5 py-0.5 text-xs font-medium">
      <Database className="size-3" aria-hidden />
      Salesforce
    </span>
  );
}

function countLabel(n: number): string {
  return `${n} invoice${n === 1 ? '' : 's'}`;
}

export default function Invoices() {
  const { rows, loading, error, reload } = useSfInvoices();

  const stats = useMemo(() => {
    const today = todayISO();
    let outstanding = 0;
    let outstandingCount = 0;
    let overdue = 0;
    let overdueCount = 0;
    let paid = 0;
    let paidCount = 0;
    for (const inv of rows) {
      const total = inv.total ?? 0;
      const balance = inv.balanceDue ?? 0;
      if (balance > 0) {
        outstanding += balance;
        outstandingCount += 1;
        if (inv.dueDate && inv.dueDate < today) {
          overdue += balance;
          overdueCount += 1;
        }
      }
      const collected = total - balance;
      if (collected > 0) {
        paid += collected;
        paidCount += 1;
      }
    }
    return {
      outstanding,
      outstandingCount,
      overdue,
      overdueCount,
      paid,
      paidCount,
    };
  }, [rows]);

  const resolved = !loading && !error;

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <PageHeader
        title="Invoices"
        description="Orders from your Salesforce org."
        actions={
          <>
            <SalesforceIndicator />
            <Button variant="outline" size="sm" onClick={reload}>
              <RefreshCw className="size-4" />
              Refresh
            </Button>
          </>
        }
      />

      {/* KPI row (count-up), populated from the loaded Salesforce records. */}
      {resolved && (
        <div className="mb-6 grid grid-cols-1 gap-4 sm:grid-cols-3">
          <StatCard
            label="Outstanding"
            value={formatCurrency(stats.outstanding)}
            numericValue={stats.outstanding}
            format={v => formatCurrency(v)}
            hint={countLabel(stats.outstandingCount)}
            icon={CircleDollarSign}
            accent="text-amber-600"
            iconClassName="bg-amber-100 text-amber-600 dark:bg-amber-500/15 dark:text-amber-400"
          />
          <StatCard
            label="Overdue"
            value={formatCurrency(stats.overdue)}
            numericValue={stats.overdue}
            format={v => formatCurrency(v)}
            hint={countLabel(stats.overdueCount)}
            icon={AlertTriangle}
            accent="text-rose-600"
            iconClassName="bg-rose-100 text-rose-600 dark:bg-rose-500/15 dark:text-rose-400"
          />
          <StatCard
            label="Paid"
            value={formatCurrency(stats.paid)}
            numericValue={stats.paid}
            format={v => formatCurrency(v)}
            hint={countLabel(stats.paidCount)}
            icon={CheckCircle2}
            accent="text-emerald-600"
            iconClassName="bg-emerald-100 text-emerald-600 dark:bg-emerald-500/15 dark:text-emerald-400"
          />
        </div>
      )}

      <Card className="shadow-sm">
        <CardContent className="px-0">
          {loading ? (
            <LoadingTable cols={5} />
          ) : error ? (
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
          ) : rows.length === 0 ? (
            <SfStateCard
              icon={Inbox}
              title="No data"
              message="No records in Salesforce yet."
              action={
                <Button size="sm" variant="outline" onClick={reload}>
                  <RefreshCw className="size-4" /> Retry
                </Button>
              }
            />
          ) : (
            <Reveal className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Number</TableHead>
                    <TableHead>Account</TableHead>
                    <TableHead>Due</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Total</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map(inv => (
                    <TableRow key={inv.id}>
                      <TableCell className="text-foreground font-medium">
                        {inv.number ?? '—'}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {inv.account ?? '—'}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {formatDate(inv.dueDate ?? undefined)}
                      </TableCell>
                      <TableCell>
                        {inv.status ? <StatusBadge status={inv.status} /> : '—'}
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        {inv.total != null ? formatCurrency(inv.total) : '—'}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </Reveal>
          )}
        </CardContent>
      </Card>

      {/* TODO(salesforce-writes): create/update/delete via uiapi mutation */}
    </div>
  );
}
