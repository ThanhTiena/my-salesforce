import { PageHeader } from '@/components/page-header';
import { useAsyncData } from '@/hooks/useAsyncData';
import { Reveal } from '@/components/motion';
import {
  isSalesforceEnv,
  fetchAccounts,
  fetchAssignments,
  fetchInvoices,
  type SfAccount,
  type SfAssignment,
  type SfInvoice,
} from '@/data/salesforce';
import { StatusBadge } from '@/components/status-badge';
import { formatCurrency, formatDate } from '@/lib/format';
import {
  Card,
  CardContent,
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
  Skeleton,
} from '@/components/ui';
import { AlertTriangle, Database, Inbox } from 'lucide-react';

const IN_SF = isSalesforceEnv();

function StateCard({
  icon: Icon,
  title,
  message,
  tone = 'muted',
}: {
  icon: typeof Inbox;
  title: string;
  message: string;
  tone?: 'muted' | 'danger';
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-14 text-center">
      <span
        className={
          tone === 'danger'
            ? 'flex size-12 items-center justify-center rounded-full bg-rose-100 text-rose-600 dark:bg-rose-500/15 dark:text-rose-300'
            : 'flex size-12 items-center justify-center rounded-full bg-muted text-muted-foreground'
        }
      >
        <Icon className="size-6" />
      </span>
      <div>
        <p className="font-medium text-foreground">{title}</p>
        <p className="mt-1 max-w-md text-sm text-muted-foreground">{message}</p>
      </div>
    </div>
  );
}

function LoadingRows({ cols }: { cols: number }) {
  return (
    <div className="space-y-2 p-4">
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="flex gap-3">
          {Array.from({ length: cols }).map((_, j) => (
            <Skeleton key={j} className="h-6 flex-1" />
          ))}
        </div>
      ))}
    </div>
  );
}

/** Shared shell that handles the not-connected / loading / error / empty states. */
function DataTab<T>({
  loading,
  error,
  rows,
  cols,
  children,
}: {
  loading: boolean;
  error: string | null;
  rows: T[];
  cols: number;
  children: React.ReactNode;
}) {
  if (!IN_SF) {
    return (
      <StateCard
        icon={Database}
        title="Connect to Salesforce to see live data"
        message="This tab queries your FreelanceOps objects with GraphQL. It fills in automatically when the app runs inside Salesforce as the FreelanceHub Lightning app."
      />
    );
  }
  if (loading) return <LoadingRows cols={cols} />;
  if (error)
    return (
      <StateCard
        icon={AlertTriangle}
        tone="danger"
        title="Couldn't load records"
        message={error}
      />
    );
  if (rows.length === 0)
    return (
      <StateCard
        icon={Inbox}
        title="No records yet"
        message="Once you create records in Salesforce, they'll appear here in real time."
      />
    );
  return <div className="overflow-x-auto">{children}</div>;
}

function AccountsTab() {
  const { data, loading, error } = useAsyncData<SfAccount[]>(
    () => (IN_SF ? fetchAccounts() : Promise.resolve([])),
    []
  );
  const rows = data ?? [];
  return (
    <DataTab loading={loading} error={error} rows={rows} cols={4}>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Account</TableHead>
            <TableHead>Role</TableHead>
            <TableHead>Health</TableHead>
            <TableHead>Phone</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map(a => (
            <TableRow key={a.id}>
              <TableCell className="font-medium">{a.name}</TableCell>
              <TableCell className="text-muted-foreground">
                {a.role ?? '—'}
              </TableCell>
              <TableCell>
                {a.health ? <StatusBadge status={a.health} /> : '—'}
              </TableCell>
              <TableCell className="text-muted-foreground">
                {a.phone ?? '—'}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </DataTab>
  );
}

function AssignmentsTab() {
  const { data, loading, error } = useAsyncData<SfAssignment[]>(
    () => (IN_SF ? fetchAssignments() : Promise.resolve([])),
    []
  );
  const rows = data ?? [];
  return (
    <DataTab loading={loading} error={error} rows={rows} cols={5}>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Assignment</TableHead>
            <TableHead>Consultant</TableHead>
            <TableHead>End Client</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Hrs/wk</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map(a => (
            <TableRow key={a.id}>
              <TableCell className="font-medium">{a.name}</TableCell>
              <TableCell className="text-muted-foreground">
                {a.consultant ?? '—'}
              </TableCell>
              <TableCell className="text-muted-foreground">
                {a.endClient ?? '—'}
              </TableCell>
              <TableCell>
                {a.status ? <StatusBadge status={a.status} /> : '—'}
              </TableCell>
              <TableCell className="text-right tabular-nums">
                {a.hoursPerWeek ?? '—'}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </DataTab>
  );
}

function InvoicesTab() {
  const { data, loading, error } = useAsyncData<SfInvoice[]>(
    () => (IN_SF ? fetchInvoices() : Promise.resolve([])),
    []
  );
  const rows = data ?? [];
  return (
    <DataTab loading={loading} error={error} rows={rows} cols={5}>
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead>Invoice</TableHead>
            <TableHead>Account</TableHead>
            <TableHead>Due</TableHead>
            <TableHead>Status</TableHead>
            <TableHead className="text-right">Total</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {rows.map(inv => (
            <TableRow key={inv.id}>
              <TableCell className="font-medium">{inv.number ?? '—'}</TableCell>
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
    </DataTab>
  );
}

export default function Salesforce() {
  return (
    <div>
      <PageHeader
        title="Salesforce Data"
        description="Live FreelanceOps records queried with the Salesforce GraphQL (uiapi) API."
      />

      {!IN_SF && (
        <Reveal>
          <Card className="mb-6 border-dashed">
            <CardContent className="flex items-start gap-3 py-4">
              <Database className="mt-0.5 size-5 shrink-0 text-muted-foreground" />
              <p className="text-sm text-muted-foreground">
                You're viewing FreelanceHub outside Salesforce, so these tabs are
                empty. Deployed as the <strong>FreelanceHub</strong> Lightning app,
                they read your Accounts, Assignments, and Invoices in real time
                through GraphQL — no page reloads.
              </p>
            </CardContent>
          </Card>
        </Reveal>
      )}

      <Reveal delay={60}>
        <Card className="py-0">
          <CardContent className="p-0">
            <Tabs defaultValue="accounts" className="w-full">
              <TabsList className="m-3">
                <TabsTrigger value="accounts">Accounts</TabsTrigger>
                <TabsTrigger value="assignments">Assignments</TabsTrigger>
                <TabsTrigger value="invoices">Invoices</TabsTrigger>
              </TabsList>
              <TabsContent value="accounts">
                <AccountsTab />
              </TabsContent>
              <TabsContent value="assignments">
                <AssignmentsTab />
              </TabsContent>
              <TabsContent value="invoices">
                <InvoicesTab />
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </Reveal>
    </div>
  );
}
