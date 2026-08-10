import { useState } from 'react';
import { AlertTriangle, Database, Inbox, RefreshCw } from 'lucide-react';

import { useAsyncData } from '@/hooks/useAsyncData';
import { fetchAccounts, type SfAccount } from '@/data/salesforce';
import { SfStateCard, LoadingTable } from '@/data/live-view';
import { PageHeader } from '@/components/common/page-header';
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
 * Reads FreelanceOps Accounts from Salesforce. `reload()` bumps a generation
 * counter so the fetcher re-runs; any GraphQL error is captured verbatim.
 */
function useSfAccounts() {
  const [gen, setGen] = useState(0);
  const { data, loading, error } = useAsyncData<SfAccount[]>(
    () => fetchAccounts(),
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

export default function Clients() {
  const { rows, loading, error, reload } = useSfAccounts();

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
      <PageHeader
        title="Clients"
        description="Accounts from your Salesforce org."
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

      <Card>
        <CardContent className="px-0">
          {loading ? (
            <LoadingTable cols={4} />
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
                    <TableHead>Account</TableHead>
                    <TableHead>Role</TableHead>
                    <TableHead>Health</TableHead>
                    <TableHead>Phone</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map(a => (
                    <TableRow key={a.id}>
                      <TableCell className="text-foreground font-medium">
                        {a.name}
                      </TableCell>
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
            </Reveal>
          )}
        </CardContent>
      </Card>

      {/* TODO(salesforce-writes): create/update/delete via uiapi mutation */}
    </div>
  );
}
