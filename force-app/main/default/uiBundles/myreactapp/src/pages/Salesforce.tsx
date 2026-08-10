import { useMemo, useState } from 'react';
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
  Button,
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
import { AlertTriangle, Database, Inbox, RefreshCw, Plug } from 'lucide-react';

/**
 * Fetches a Salesforce list. Env is evaluated by the caller at RENDER time
 * (never module load) so it can't run before the platform injects SFDC_ENV.
 * `reload()` re-runs; any GraphQL error is captured verbatim so it's visible.
 */
function useSfList<T>(fetcher: () => Promise<T[]>, enabled: boolean) {
  const [gen, setGen] = useState(0);
  const { data, loading, error } = useAsyncData<T[]>(
    () => (enabled ? fetcher() : Promise.resolve([])),
    [enabled, gen]
  );
  return {
    rows: data ?? [],
    loading: enabled && loading,
    error,
    reload: () => setGen(g => g + 1),
  };
}

function StateCard({
  icon: Icon,
  title,
  message,
  tone = 'muted',
  action,
}: {
  icon: typeof Inbox;
  title: string;
  message: string;
  tone?: 'muted' | 'danger';
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 px-6 py-14 text-center">
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
        <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
          {message}
        </p>
      </div>
      {action}
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

/** Handles enabled / loading / error / empty and renders the table otherwise. */
function DataTab({
  enabled,
  loading,
  error,
  count,
  cols,
  onConnect,
  onReload,
  children,
}: {
  enabled: boolean;
  loading: boolean;
  error: string | null;
  count: number;
  cols: number;
  onConnect: () => void;
  onReload: () => void;
  children: React.ReactNode;
}) {
  if (!enabled) {
    return (
      <StateCard
        icon={Database}
        title="Not connected to Salesforce"
        message="This tab queries your FreelanceOps objects with GraphQL. It runs automatically inside the FreelanceHub Lightning app — or load it now to test the connection and see any error."
        action={
          <Button size="sm" onClick={onConnect}>
            <Plug className="size-4" /> Load from Salesforce
          </Button>
        }
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
        action={
          <Button size="sm" variant="outline" onClick={onReload}>
            <RefreshCw className="size-4" /> Retry
          </Button>
        }
      />
    );
  if (count === 0)
    return (
      <StateCard
        icon={Inbox}
        title="No records yet"
        message="Connected, but this object has no records. Load the sample data (scripts/apex/fops-sample-data.apex) or create records in Salesforce — they'll appear here instantly."
        action={
          <Button size="sm" variant="outline" onClick={onReload}>
            <RefreshCw className="size-4" /> Refresh
          </Button>
        }
      />
    );
  return <Reveal className="overflow-x-auto">{children}</Reveal>;
}

function AccountsTab({ enabled, onConnect }: { enabled: boolean; onConnect: () => void }) {
  const { rows, loading, error, reload } = useSfList<SfAccount>(
    fetchAccounts,
    enabled
  );
  return (
    <DataTab
      enabled={enabled}
      loading={loading}
      error={error}
      count={rows.length}
      cols={4}
      onConnect={onConnect}
      onReload={reload}
    >
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

function AssignmentsTab({ enabled, onConnect }: { enabled: boolean; onConnect: () => void }) {
  const { rows, loading, error, reload } = useSfList<SfAssignment>(
    fetchAssignments,
    enabled
  );
  return (
    <DataTab
      enabled={enabled}
      loading={loading}
      error={error}
      count={rows.length}
      cols={5}
      onConnect={onConnect}
      onReload={reload}
    >
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

function InvoicesTab({ enabled, onConnect }: { enabled: boolean; onConnect: () => void }) {
  const { rows, loading, error, reload } = useSfList<SfInvoice>(
    fetchInvoices,
    enabled
  );
  return (
    <DataTab
      enabled={enabled}
      loading={loading}
      error={error}
      count={rows.length}
      cols={5}
      onConnect={onConnect}
      onReload={reload}
    >
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
  // Evaluate the environment at render time, not at module load.
  const detected = useMemo(() => isSalesforceEnv(), []);
  const [forced, setForced] = useState(false);
  const enabled = detected || forced;

  return (
    <div>
      <PageHeader
        title="Salesforce Data"
        description="Live FreelanceOps records queried with the Salesforce GraphQL (uiapi) API."
        actions={
          !detected ? (
            <Button variant="outline" size="sm" onClick={() => setForced(true)}>
              <Plug className="size-4" /> Connect
            </Button>
          ) : undefined
        }
      />

      {!detected && (
        <Reveal>
          <Card className="mb-6 border-dashed">
            <CardContent className="flex items-start gap-3 py-4">
              <Database className="mt-0.5 size-5 shrink-0 text-muted-foreground" />
              <p className="text-sm text-muted-foreground">
                Salesforce wasn't detected in this environment (you're likely
                viewing FreelanceHub standalone). Inside the{' '}
                <strong>FreelanceHub</strong> Lightning app this reads your
                Accounts, Assignments, and Invoices live. Use{' '}
                <strong>Connect</strong> to attempt the query anyway and surface
                any error.
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
                <AccountsTab enabled={enabled} onConnect={() => setForced(true)} />
              </TabsContent>
              <TabsContent value="assignments">
                <AssignmentsTab enabled={enabled} onConnect={() => setForced(true)} />
              </TabsContent>
              <TabsContent value="invoices">
                <InvoicesTab enabled={enabled} onConnect={() => setForced(true)} />
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>
      </Reveal>
    </div>
  );
}
