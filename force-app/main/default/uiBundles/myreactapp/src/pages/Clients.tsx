import { useMemo, useState } from 'react';
import {
  Building2,
  Mail,
  Pencil,
  Phone,
  Plug,
  Plus,
  RefreshCw,
  Search,
  Trash2,
  Users,
} from 'lucide-react';

import { useStore } from '@/lib/store';
import type { Client } from '@/lib/types';
import { formatDate } from '@/lib/format';
import {
  useResource,
  salesforceDataSource,
  isSalesforceEnv,
  type ResourceResult,
  type SfAccount,
} from '@/data';
import { LiveBadge, LiveStates } from '@/data/live-view';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import {
  Button,
  Card,
  CardContent,
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  Input,
  Label,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  Tabs,
  TabsList,
  TabsTrigger,
} from '@/components/ui';
import { toast } from '@/components/ui/sonner';

type StatusFilter = 'all' | Client['status'];

interface ClientForm {
  name: string;
  company: string;
  email: string;
  phone: string;
  status: Client['status'];
  notes: string;
}

const EMPTY_FORM: ClientForm = {
  name: '',
  company: '',
  email: '',
  phone: '',
  status: 'lead',
  notes: '',
};

const TEXTAREA_CLASS =
  'dark:bg-input/30 border-input focus-visible:border-ring focus-visible:ring-ring/50 min-h-20 w-full rounded-lg border bg-transparent px-2.5 py-1.5 text-sm transition-colors outline-none placeholder:text-muted-foreground/70 placeholder:italic focus-visible:ring-3';

const FILTERS: { value: StatusFilter; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'active', label: 'Active' },
  { value: 'lead', label: 'Lead' },
  { value: 'archived', label: 'Archived' },
];

export default function Clients() {
  const { data, addClient, updateClient, deleteClient } = useStore();

  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<ClientForm>(EMPTY_FORM);

  // Live-Salesforce seam. `detected` is evaluated at render (never module load);
  // `forced` lets a standalone user attempt the live query via "Connect".
  const detected = useMemo(() => isSalesforceEnv(), []);
  const [forced, setForced] = useState(false);
  const live = detected || forced;
  const sf = useResource<SfAccount>({
    salesforce: () => salesforceDataSource.listClients(),
    enabled: live,
  });

  const projectCounts = useMemo(() => {
    const counts = new Map<string, number>();
    for (const project of data.projects) {
      counts.set(project.clientId, (counts.get(project.clientId) ?? 0) + 1);
    }
    return counts;
  }, [data.projects]);

  const filtered = useMemo(() => {
    const query = search.trim().toLowerCase();
    return data.clients
      .filter(c => statusFilter === 'all' || c.status === statusFilter)
      .filter(c => {
        if (!query) return true;
        return (
          c.name.toLowerCase().includes(query) ||
          (c.company ?? '').toLowerCase().includes(query) ||
          (c.email ?? '').toLowerCase().includes(query)
        );
      })
      .sort((a, b) => a.name.localeCompare(b.name));
  }, [data.clients, search, statusFilter]);

  function openCreate() {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setDialogOpen(true);
  }

  function openEdit(client: Client) {
    setEditingId(client.id);
    setForm({
      name: client.name,
      company: client.company ?? '',
      email: client.email ?? '',
      phone: client.phone ?? '',
      status: client.status,
      notes: client.notes ?? '',
    });
    setDialogOpen(true);
  }

  function handleOpenChange(next: boolean) {
    setDialogOpen(next);
    if (!next) setEditingId(null);
  }

  function save() {
    const name = form.name.trim();
    if (!name) {
      toast.error('Name is required');
      return;
    }
    const payload = {
      name,
      company: form.company.trim() || undefined,
      email: form.email.trim() || undefined,
      phone: form.phone.trim() || undefined,
      status: form.status,
      notes: form.notes.trim() || undefined,
    };
    if (editingId) {
      updateClient(editingId, payload);
      toast.success('Client updated');
    } else {
      addClient(payload);
      toast.success('Client added');
    }
    handleOpenChange(false);
  }

  function handleDelete(client: Client) {
    const confirmed = window.confirm(
      `Delete ${client.name}? This also removes their projects, invoices, and tracked time. This can't be undone.`
    );
    if (!confirmed) return;
    deleteClient(client.id);
    toast.success(`Deleted ${client.name}`);
  }

  // Live Salesforce mode is read-first: show Accounts, keep local CRUD gated to
  // standalone mode below.
  if (live) {
    return (
      <ClientsLive sf={sf} detected={detected} onExit={() => setForced(false)} />
    );
  }

  return (
    <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
      <PageHeader
        title="Clients"
        description="Everyone you work with, in one place."
        actions={
          <>
            <LiveBadge live={false} className="self-center" />
            <Button variant="outline" size="sm" onClick={() => setForced(true)}>
              <Plug className="size-4" />
              Connect
            </Button>
            <Button onClick={openCreate}>
              <Plus className="size-4" />
              Add client
            </Button>
          </>
        }
      />

      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full sm:max-w-xs">
          <Search className="text-muted-foreground pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2" />
          <Input
            value={search}
            onChange={e => setSearch(e.target.value)}
            placeholder="Search name, company, or email"
            aria-label="Search clients"
            className="pl-8"
          />
        </div>
        <Tabs
          value={statusFilter}
          onValueChange={v => setStatusFilter(v as StatusFilter)}
        >
          <TabsList>
            {FILTERS.map(f => (
              <TabsTrigger key={f.value} value={f.value}>
                {f.label}
              </TabsTrigger>
            ))}
          </TabsList>
        </Tabs>
      </div>

      <Card>
        <CardContent className="px-0">
          {filtered.length === 0 ? (
            <div className="flex flex-col items-center gap-3 px-6 py-16 text-center">
              <div className="bg-muted flex size-12 items-center justify-center rounded-full">
                <Users className="text-muted-foreground size-6" />
              </div>
              <div className="space-y-1">
                <p className="text-foreground font-medium">No clients found</p>
                <p className="text-muted-foreground text-sm">
                  {data.clients.length === 0
                    ? 'Add your first client to start tracking projects and invoices.'
                    : 'Try adjusting your search or status filter.'}
                </p>
              </div>
              <Button onClick={openCreate} className="mt-1">
                <Plus className="size-4" />
                Add client
              </Button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Client</TableHead>
                    <TableHead>Contact</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Projects</TableHead>
                    <TableHead>Added</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filtered.map(client => (
                    <TableRow key={client.id}>
                      <TableCell>
                        <div className="font-medium text-foreground">
                          {client.name}
                        </div>
                        {client.company && (
                          <div className="text-muted-foreground mt-0.5 flex items-center gap-1 text-xs">
                            <Building2 className="size-3" />
                            {client.company}
                          </div>
                        )}
                      </TableCell>
                      <TableCell>
                        <div className="text-muted-foreground space-y-0.5 text-xs">
                          {client.email && (
                            <div className="flex items-center gap-1.5">
                              <Mail className="size-3 shrink-0" />
                              <span>{client.email}</span>
                            </div>
                          )}
                          {client.phone && (
                            <div className="flex items-center gap-1.5">
                              <Phone className="size-3 shrink-0" />
                              <span>{client.phone}</span>
                            </div>
                          )}
                          {!client.email && !client.phone && (
                            <span aria-hidden>—</span>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        <StatusBadge status={client.status} />
                      </TableCell>
                      <TableCell className="text-right tabular-nums">
                        {projectCounts.get(client.id) ?? 0}
                      </TableCell>
                      <TableCell className="text-muted-foreground">
                        {formatDate(client.createdAt)}
                      </TableCell>
                      <TableCell>
                        <div className="flex justify-end gap-1">
                          <Button
                            variant="ghost"
                            size="icon-sm"
                            aria-label={`Edit ${client.name}`}
                            onClick={() => openEdit(client)}
                          >
                            <Pencil className="size-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="icon-sm"
                            aria-label={`Delete ${client.name}`}
                            onClick={() => handleDelete(client)}
                          >
                            <Trash2 className="size-4" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      <Dialog open={dialogOpen} onOpenChange={handleOpenChange}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>
              {editingId ? 'Edit client' : 'Add client'}
            </DialogTitle>
            <DialogDescription>
              {editingId
                ? 'Update the details for this client.'
                : 'Add someone new to your client list.'}
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-4">
            <div className="grid gap-2">
              <Label htmlFor="client-name">Name</Label>
              <Input
                id="client-name"
                value={form.name}
                onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                placeholder="Jane Doe"
                autoFocus
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="client-company">Company</Label>
              <Input
                id="client-company"
                value={form.company}
                onChange={e =>
                  setForm(f => ({ ...f, company: e.target.value }))
                }
                placeholder="Acme Inc."
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="grid gap-2">
                <Label htmlFor="client-email">Email</Label>
                <Input
                  id="client-email"
                  type="email"
                  value={form.email}
                  onChange={e =>
                    setForm(f => ({ ...f, email: e.target.value }))
                  }
                  placeholder="jane@acme.com"
                />
              </div>
              <div className="grid gap-2">
                <Label htmlFor="client-phone">Phone</Label>
                <Input
                  id="client-phone"
                  value={form.phone}
                  onChange={e =>
                    setForm(f => ({ ...f, phone: e.target.value }))
                  }
                  placeholder="(555) 123-4567"
                />
              </div>
            </div>
            <div className="grid gap-2">
              <Label htmlFor="client-status">Status</Label>
              <Select
                value={form.status}
                onValueChange={v =>
                  setForm(f => ({ ...f, status: v as Client['status'] }))
                }
              >
                <SelectTrigger id="client-status" className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="active">Active</SelectItem>
                  <SelectItem value="lead">Lead</SelectItem>
                  <SelectItem value="archived">Archived</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-2">
              <Label htmlFor="client-notes">Notes</Label>
              <textarea
                id="client-notes"
                value={form.notes}
                onChange={e =>
                  setForm(f => ({ ...f, notes: e.target.value }))
                }
                placeholder="Anything worth remembering about this client."
                className={TEXTAREA_CLASS}
              />
            </div>
          </div>

          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline">Cancel</Button>
            </DialogClose>
            <Button onClick={save}>
              {editingId ? 'Save changes' : 'Add client'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

/**
 * Read-only Accounts view shown when running live in Salesforce (or after a
 * standalone "Connect"). Mirrors the state handling in src/pages/Salesforce.tsx.
 */
function ClientsLive({
  sf,
  detected,
  onExit,
}: {
  sf: ResourceResult<SfAccount>;
  detected: boolean;
  onExit: () => void;
}) {
  return (
    <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
      <PageHeader
        title="Clients"
        description="Accounts from your live Salesforce org."
        actions={
          <>
            <LiveBadge live className="self-center" />
            <Button variant="outline" size="sm" onClick={sf.reload}>
              <RefreshCw className="size-4" />
              Refresh
            </Button>
          </>
        }
      />

      <Card>
        <CardContent className="px-0">
          <LiveStates
            result={sf}
            cols={4}
            onExit={detected ? undefined : onExit}
            emptyMessage="Connected, but no Accounts were returned. Add Accounts in Salesforce and they'll appear here instantly."
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
                {sf.rows.map(a => (
                  <TableRow key={a.id}>
                    <TableCell className="font-medium text-foreground">
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
          </LiveStates>
        </CardContent>
      </Card>

      {/* TODO(salesforce-writes): creating / editing Accounts in SF mode needs
          uiapi mutations (see salesforceDataSource.updateClientHealth for the
          pattern). Full CRUD stays available in standalone/local mode; SF mode
          is read-first for now. */}
    </div>
  );
}
