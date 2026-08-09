import { useMemo, type ReactNode } from 'react';
import { Link } from 'react-router';
import {
  AlertTriangle,
  ArrowRight,
  BarChart3,
  CalendarDays,
  CheckCircle2,
  Clock,
  FolderKanban,
  FolderOpen,
  Receipt,
  Wallet,
  type LucideIcon,
} from 'lucide-react';

import { useStore, useClientMap, useProjectMap } from '@/lib/store';
import {
  formatCurrency,
  formatDate,
  invoiceTotal,
  effectiveInvoiceStatus,
  monthKey,
  todayISO,
} from '@/lib/format';
import { PageHeader } from '@/components/page-header';
import { StatCard } from '@/components/stat-card';
import { StatusBadge } from '@/components/status-badge';
import {
  Button,
  Card,
  CardHeader,
  CardTitle,
  CardDescription,
  CardContent,
  CardFooter,
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
} from '@/components/ui';

/** Friendly placeholder shown wherever a region has no data yet. */
function EmptyState({
  icon: Icon,
  title,
  message,
  action,
}: {
  icon: LucideIcon;
  title: string;
  message: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 px-4 py-10 text-center">
      <span className="flex size-12 items-center justify-center rounded-full bg-muted text-muted-foreground">
        <Icon className="size-5" />
      </span>
      <div>
        <p className="text-sm font-medium text-foreground">{title}</p>
        <p className="mt-1 text-xs text-muted-foreground">{message}</p>
      </div>
      {action}
    </div>
  );
}

const ACTIVE_PROJECT_STATUSES = new Set(['active', 'planning', 'on-hold']);

export default function Dashboard() {
  const { data } = useStore();
  const clientMap = useClientMap();
  const projectMap = useProjectMap();
  const currency = data.settings.currency;

  // --- KPI figures (all-time so the page is never blank) --------------------
  const kpis = useMemo(() => {
    let outstanding = 0;
    let outstandingCount = 0;
    let overdue = 0;
    let overdueCount = 0;
    let paid = 0;
    let paidCount = 0;

    for (const inv of data.invoices) {
      const status = effectiveInvoiceStatus(inv);
      const total = invoiceTotal(inv);
      if (status === 'sent' || status === 'overdue') {
        outstanding += total;
        outstandingCount += 1;
      }
      if (status === 'overdue') {
        overdue += total;
        overdueCount += 1;
      }
      if (status === 'paid') {
        paid += total;
        paidCount += 1;
      }
    }

    const activeProjects = data.projects.filter(
      p => p.status === 'active'
    ).length;

    let unbilledValue = 0;
    let unbilledHours = 0;
    for (const entry of data.timeEntries) {
      if (entry.billed) continue;
      unbilledHours += entry.hours;
      unbilledValue += entry.hours * (projectMap.get(entry.projectId)?.hourlyRate ?? 0);
    }

    return {
      outstanding,
      outstandingCount,
      overdue,
      overdueCount,
      paid,
      paidCount,
      activeProjects,
      totalProjects: data.projects.length,
      unbilledValue,
      unbilledHours,
    };
  }, [data.invoices, data.projects, data.timeEntries, projectMap]);

  // --- Income for the last 6 months (paid invoices by issue month) ----------
  const income = useMemo(() => {
    const now = new Date();
    const keys: string[] = [];
    for (let i = 5; i >= 0; i -= 1) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      keys.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
    }
    const totals = new Map<string, number>(keys.map(k => [k, 0]));
    for (const inv of data.invoices) {
      if (inv.status !== 'paid') continue;
      const key = monthKey(inv.issueDate);
      if (totals.has(key)) {
        totals.set(key, (totals.get(key) ?? 0) + invoiceTotal(inv));
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
  }, [data.invoices]);

  // --- Recent invoices (newest first) ---------------------------------------
  const recentInvoices = useMemo(
    () =>
      [...data.invoices]
        .sort((a, b) => b.issueDate.localeCompare(a.issueDate))
        .slice(0, 5),
    [data.invoices]
  );

  // --- Active/upcoming projects with tracked hours --------------------------
  const activeProjectRows = useMemo(() => {
    const hoursByProject = new Map<string, number>();
    for (const entry of data.timeEntries) {
      hoursByProject.set(
        entry.projectId,
        (hoursByProject.get(entry.projectId) ?? 0) + entry.hours
      );
    }
    return data.projects
      .filter(p => ACTIVE_PROJECT_STATUSES.has(p.status))
      .sort((a, b) => {
        const ad = a.dueDate ?? '';
        const bd = b.dueDate ?? '';
        if (!ad && !bd) return 0;
        if (!ad) return 1;
        if (!bd) return -1;
        return ad.localeCompare(bd);
      })
      .map(p => {
        const hours = hoursByProject.get(p.id) ?? 0;
        return { project: p, hours, value: hours * (p.hourlyRate ?? 0) };
      });
  }, [data.projects, data.timeEntries]);

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <PageHeader
        title="Dashboard"
        description="Your freelance business at a glance."
        actions={
          <div className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-1.5 text-sm text-muted-foreground">
            <CalendarDays className="size-4" />
            <span className="tabular-nums">{formatDate(todayISO())}</span>
          </div>
        }
      />

      {/* KPI row */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-5">
        <StatCard
          label="Outstanding"
          value={formatCurrency(kpis.outstanding, currency)}
          hint={`${kpis.outstandingCount} open invoice${kpis.outstandingCount === 1 ? '' : 's'}`}
          icon={Wallet}
          accent="text-amber-600"
          iconClassName="bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-300"
        />
        <StatCard
          label="Overdue"
          value={formatCurrency(kpis.overdue, currency)}
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
          value={formatCurrency(kpis.paid, currency)}
          hint={`${kpis.paidCount} invoice${kpis.paidCount === 1 ? '' : 's'}`}
          icon={CheckCircle2}
          accent="text-emerald-600"
          iconClassName="bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300"
        />
        <StatCard
          label="Active projects"
          value={String(kpis.activeProjects)}
          hint={`of ${kpis.totalProjects} total`}
          icon={FolderKanban}
          iconClassName="bg-indigo-100 text-indigo-700 dark:bg-indigo-500/15 dark:text-indigo-300"
        />
        <StatCard
          label="Unbilled"
          value={formatCurrency(kpis.unbilledValue, currency)}
          hint={`${kpis.unbilledHours.toLocaleString('en-US')} hrs to bill`}
          icon={Clock}
          accent="text-sky-600"
          iconClassName="bg-sky-100 text-sky-700 dark:bg-sky-500/15 dark:text-sky-300"
        />
      </div>

      {/* Bento: income chart + recent invoices */}
      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>Income (last 6 months)</CardTitle>
            <CardDescription>
              Paid invoices ·{' '}
              <span className="tabular-nums font-medium text-foreground">
                {formatCurrency(income.total, currency)}
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
                        title={`${bar.label}: ${formatCurrency(bar.value, currency)}`}
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
              <EmptyState
                icon={BarChart3}
                title="No income yet"
                message="Paid invoices from the last six months will appear here."
                action={
                  <Button asChild variant="outline" size="sm">
                    <Link to="/invoices">
                      Record a payment <ArrowRight className="size-3.5" />
                    </Link>
                  </Button>
                }
              />
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Recent invoices</CardTitle>
            <CardDescription>Your latest activity</CardDescription>
          </CardHeader>
          {recentInvoices.length > 0 ? (
            <>
              <CardContent className="px-0">
                <ul className="divide-y divide-border">
                  {recentInvoices.map(inv => {
                    const clientName =
                      clientMap.get(inv.clientId)?.name ?? 'Unknown';
                    return (
                      <li
                        key={inv.id}
                        className="flex items-center justify-between gap-3 px-4 py-3 transition-colors hover:bg-muted/50"
                      >
                        <div className="min-w-0">
                          <p className="truncate text-sm font-medium text-foreground">
                            {inv.number}
                          </p>
                          <p className="truncate text-xs text-muted-foreground">
                            {clientName} · {formatDate(inv.issueDate)}
                          </p>
                        </div>
                        <div className="flex shrink-0 items-center gap-3">
                          <span className="text-sm font-medium tabular-nums text-foreground">
                            {formatCurrency(invoiceTotal(inv), currency)}
                          </span>
                          <StatusBadge status={effectiveInvoiceStatus(inv)} />
                        </div>
                      </li>
                    );
                  })}
                </ul>
              </CardContent>
              <CardFooter className="justify-center">
                <Button asChild variant="ghost" size="sm">
                  <Link to="/invoices">
                    View all <ArrowRight className="size-3.5" />
                  </Link>
                </Button>
              </CardFooter>
            </>
          ) : (
            <CardContent>
              <EmptyState
                icon={Receipt}
                title="No invoices yet"
                message="Create your first invoice to start tracking income."
                action={
                  <Button asChild variant="outline" size="sm">
                    <Link to="/invoices">
                      Create an invoice <ArrowRight className="size-3.5" />
                    </Link>
                  </Button>
                }
              />
            </CardContent>
          )}
        </Card>
      </div>

      {/* Active projects table */}
      <Card className="mt-6">
        <CardHeader>
          <CardTitle>Active &amp; upcoming projects</CardTitle>
          <CardDescription>
            In-flight work (active, planning, and on-hold) sorted by due date.
          </CardDescription>
        </CardHeader>
        <CardContent className="px-0">
          {activeProjectRows.length > 0 ? (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="pl-4">Project</TableHead>
                    <TableHead>Client</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Tracked hrs</TableHead>
                    <TableHead className="pr-4 text-right">Value</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {activeProjectRows.map(({ project, hours, value }) => (
                    <TableRow key={project.id}>
                      <TableCell className="pl-4 font-medium text-foreground">
                        {project.name}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {clientMap.get(project.clientId)?.name ?? 'Unknown'}
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={project.status} />
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        {hours.toLocaleString('en-US')}
                      </TableCell>
                      <TableCell className="pr-4 text-right tabular-nums">
                        {formatCurrency(value, currency)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          ) : (
            <EmptyState
              icon={FolderOpen}
              title="No active projects"
              message="Spin up a project to plan work and track billable time."
              action={
                <Button asChild variant="outline" size="sm">
                  <Link to="/projects">
                    Add a project <ArrowRight className="size-3.5" />
                  </Link>
                </Button>
              }
            />
          )}
        </CardContent>
      </Card>
    </div>
  );
}
