import { useMemo, useState } from 'react';
import {
  Clock,
  CheckCircle2,
  ListChecks,
  CircleDollarSign,
  RefreshCw,
  Inbox,
  AlertTriangle,
} from 'lucide-react';
import { useAsyncData } from '@/hooks/useAsyncData';
import { fetchTimeEntries, type SfTimeEntry } from '@/data/salesforce';
import { formatDate } from '@/lib/format';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from '@/components/ui';
import { SfStateCard, LoadingTable } from '@/data/live-view';
import { Reveal, AnimatedNumber } from '@/components/motion';
import { cn } from '@/lib/utils';

// TODO(salesforce-writes): create Time Entry via uiapi mutation (needs Timesheet/Assignment)

/** A small pill distinguishing billable from non-billable entries. */
function BillableBadge({ billable }: { billable: boolean }) {
  return (
    <span
      className={cn(
        'inline-flex w-fit shrink-0 items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium',
        billable
          ? 'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300'
          : 'bg-muted text-muted-foreground'
      )}
    >
      {billable && <CheckCircle2 className="size-3" aria-hidden />}
      {billable ? 'Billable' : 'Non-billable'}
    </span>
  );
}

export default function TimeTracking() {
  // `gen` is a manual retry counter: bumping it re-runs the Salesforce fetch.
  const [gen, setGen] = useState(0);
  const reload = () => setGen(g => g + 1);
  const { data, loading, error } = useAsyncData<SfTimeEntry[]>(
    () => fetchTimeEntries(),
    [gen]
  );

  const entries = useMemo(() => data ?? [], [data]);

  const kpis = useMemo(() => {
    let totalHours = 0;
    let billableHours = 0;
    for (const e of entries) {
      const h = e.hours ?? 0;
      totalHours += h;
      if (e.billable) billableHours += h;
    }
    return { totalHours, billableHours, entries: entries.length };
  }, [entries]);

  // Newest first; null dates sort to the bottom.
  const rows = useMemo(() => {
    return entries
      .slice()
      .sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''));
  }, [entries]);

  const totalHours = useMemo(
    () => rows.reduce((sum, e) => sum + (e.hours ?? 0), 0),
    [rows]
  );

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <PageHeader
        title="Time Tracking"
        description="Billable hours logged in Salesforce."
        actions={
          <Button
            variant="outline"
            onClick={reload}
            disabled={loading}
            className="cursor-pointer"
          >
            <RefreshCw className={cn('size-4', loading && 'animate-spin')} />
            Refresh
          </Button>
        }
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard
          label="Total hours"
          value={`${kpis.totalHours.toFixed(1)}h`}
          numericValue={kpis.totalHours}
          format={v => `${v.toFixed(1)}h`}
          hint="Across all entries"
          icon={Clock}
          iconClassName="bg-primary/10 text-primary"
        />
        <StatCard
          label="Billable hours"
          value={`${kpis.billableHours.toFixed(1)}h`}
          numericValue={kpis.billableHours}
          format={v => `${v.toFixed(1)}h`}
          hint="Marked billable"
          icon={CircleDollarSign}
          accent="text-emerald-600"
          iconClassName="bg-emerald-500/10 text-emerald-600"
        />
        <StatCard
          label="Entries"
          value={String(kpis.entries)}
          numericValue={kpis.entries}
          hint="Time entries in Salesforce"
          icon={ListChecks}
          iconClassName="bg-muted text-foreground"
        />
      </div>

      <Card className="mt-6 rounded-xl shadow-sm">
        <CardHeader>
          <CardTitle>Entries</CardTitle>
        </CardHeader>
        <CardContent>
          {loading ? (
            <LoadingTable cols={4} />
          ) : error ? (
            <SfStateCard
              icon={AlertTriangle}
              tone="danger"
              title="Couldn't load time entries"
              message={error}
              action={
                <Button
                  size="sm"
                  variant="outline"
                  onClick={reload}
                  className="cursor-pointer"
                >
                  <RefreshCw className="size-4" /> Retry
                </Button>
              }
            />
          ) : rows.length === 0 ? (
            <SfStateCard
              icon={Inbox}
              title="No data"
              message="No time entries in Salesforce yet."
              action={
                <Button
                  size="sm"
                  variant="outline"
                  onClick={reload}
                  className="cursor-pointer"
                >
                  <RefreshCw className="size-4" /> Refresh
                </Button>
              }
            />
          ) : (
            <Reveal className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Date</TableHead>
                    <TableHead className="text-right">Hours</TableHead>
                    <TableHead>Billable</TableHead>
                    <TableHead>Description</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map(e => (
                    <TableRow key={e.id}>
                      <TableCell className="whitespace-nowrap">
                        {formatDate(e.date ?? undefined)}
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        {(e.hours ?? 0).toFixed(1)}h
                      </TableCell>
                      <TableCell>
                        <BillableBadge billable={!!e.billable} />
                      </TableCell>
                      <TableCell className="max-w-[24rem] truncate text-muted-foreground">
                        {e.description || '—'}
                      </TableCell>
                    </TableRow>
                  ))}
                  <TableRow className="border-t-2">
                    <TableCell className="font-medium">Total</TableCell>
                    <TableCell className="text-right font-medium tabular-nums">
                      <AnimatedNumber
                        value={totalHours}
                        format={v => `${v.toFixed(1)}h`}
                      />
                    </TableCell>
                    <TableCell colSpan={2} />
                  </TableRow>
                </TableBody>
              </Table>
            </Reveal>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
