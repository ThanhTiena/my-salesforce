import { useMemo, useState } from 'react';
import {
  Plus,
  Pencil,
  Trash2,
  FileText,
  CheckCircle2,
  CircleDollarSign,
  AlertTriangle,
  X,
} from 'lucide-react';

import { useStore, useClientMap } from '@/lib/store';
import type { Invoice, InvoiceLineItem, InvoiceStatus } from '@/lib/types';
import {
  formatCurrency,
  formatDate,
  invoiceTotal,
  effectiveInvoiceStatus,
  todayISO,
} from '@/lib/format';

import { PageHeader } from '@/components/page-header';
import { StatCard } from '@/components/stat-card';
import { StatusBadge } from '@/components/status-badge';

import {
  Button,
  Input,
  Label,
  Card,
  CardContent,
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
  Tabs,
  TabsList,
  TabsTrigger,
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
  DialogClose,
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
  Separator,
} from '@/components/ui';
import { toast } from '@/components/ui/sonner';

type FilterValue = 'all' | InvoiceStatus;

/** A line item while it is being edited — numbers held as strings for inputs. */
interface DraftLine {
  id: string;
  description: string;
  quantity: string;
  unitPrice: string;
}

const TEXTAREA_CLASS =
  'flex min-h-[72px] w-full rounded-lg border border-input bg-transparent px-2.5 py-1.5 text-sm outline-none transition-colors placeholder:text-muted-foreground/70 focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 dark:bg-input/30';

function newLineId(): string {
  return typeof crypto !== 'undefined' && crypto.randomUUID
    ? crypto.randomUUID()
    : String(Date.now() + Math.random());
}

function blankLine(): DraftLine {
  return { id: newLineId(), description: '', quantity: '1', unitPrice: '0' };
}

function countLabel(n: number): string {
  return `${n} invoice${n === 1 ? '' : 's'}`;
}

export default function Invoices() {
  const { data, addInvoice, updateInvoice, deleteInvoice, nextInvoiceNumber } =
    useStore();
  const clientMap = useClientMap();
  const currency = data.settings.currency;

  const [filter, setFilter] = useState<FilterValue>('all');

  // Dialog + form state.
  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [number, setNumber] = useState('');
  const [clientId, setClientId] = useState('');
  const [projectId, setProjectId] = useState('none');
  const [status, setStatus] = useState<InvoiceStatus>('draft');
  const [issueDate, setIssueDate] = useState(todayISO());
  const [dueDate, setDueDate] = useState('');
  const [notes, setNotes] = useState('');
  const [lines, setLines] = useState<DraftLine[]>([blankLine()]);

  const stats = useMemo(() => {
    let outstanding = 0;
    let outstandingCount = 0;
    let overdue = 0;
    let overdueCount = 0;
    let paid = 0;
    let paidCount = 0;
    for (const inv of data.invoices) {
      const eff = effectiveInvoiceStatus(inv);
      const total = invoiceTotal(inv);
      if (eff === 'sent' || eff === 'overdue') {
        outstanding += total;
        outstandingCount += 1;
      }
      if (eff === 'overdue') {
        overdue += total;
        overdueCount += 1;
      }
      if (eff === 'paid') {
        paid += total;
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
  }, [data.invoices]);

  const rows = useMemo(() => {
    const sorted = [...data.invoices].sort((a, b) =>
      b.issueDate.localeCompare(a.issueDate)
    );
    if (filter === 'all') return sorted;
    return sorted.filter(inv => effectiveInvoiceStatus(inv) === filter);
  }, [data.invoices, filter]);

  // Projects selectable in the dialog — scoped to the chosen client.
  const clientProjects = useMemo(
    () => data.projects.filter(p => !clientId || p.clientId === clientId),
    [data.projects, clientId]
  );

  const draftTotal = lines.reduce(
    (sum, l) => sum + (Number(l.quantity) || 0) * (Number(l.unitPrice) || 0),
    0
  );

  function openCreate() {
    setEditingId(null);
    setNumber(nextInvoiceNumber());
    setClientId('');
    setProjectId('none');
    setStatus('draft');
    setIssueDate(todayISO());
    setDueDate('');
    setNotes('');
    setLines([blankLine()]);
    setOpen(true);
  }

  function openEdit(inv: Invoice) {
    setEditingId(inv.id);
    setNumber(inv.number);
    setClientId(inv.clientId);
    setProjectId(inv.projectId ?? 'none');
    setStatus(inv.status);
    setIssueDate(inv.issueDate);
    setDueDate(inv.dueDate);
    setNotes(inv.notes ?? '');
    setLines(
      inv.lineItems.length
        ? inv.lineItems.map(li => ({
            id: li.id,
            description: li.description,
            quantity: String(li.quantity),
            unitPrice: String(li.unitPrice),
          }))
        : [blankLine()]
    );
    setOpen(true);
  }

  function patchLine(id: string, patch: Partial<DraftLine>) {
    setLines(ls => ls.map(l => (l.id === id ? { ...l, ...patch } : l)));
  }

  function removeLine(id: string) {
    setLines(ls => (ls.length > 1 ? ls.filter(l => l.id !== id) : ls));
  }

  function markPaid(inv: Invoice) {
    updateInvoice(inv.id, { status: 'paid' });
    toast.success(`${inv.number} marked as paid`);
  }

  function handleDelete(inv: Invoice) {
    if (!window.confirm(`Delete invoice ${inv.number}? This cannot be undone.`))
      return;
    deleteInvoice(inv.id);
    toast.success(`${inv.number} deleted`);
  }

  function handleSubmit() {
    if (!clientId) {
      toast.error('Choose a client for this invoice.');
      return;
    }
    const valid = lines.filter(
      l => l.description.trim() && Number(l.quantity) > 0
    );
    if (valid.length === 0) {
      toast.error('Add at least one line item with a description and quantity.');
      return;
    }
    const lineItems: InvoiceLineItem[] = valid.map(l => ({
      id: l.id,
      description: l.description.trim(),
      quantity: Number(l.quantity),
      unitPrice: Number(l.unitPrice) || 0,
    }));
    const payload: Omit<Invoice, 'id' | 'createdAt'> = {
      number: number.trim() || nextInvoiceNumber(),
      clientId,
      projectId: projectId === 'none' ? undefined : projectId,
      status,
      issueDate,
      dueDate,
      lineItems,
      notes: notes.trim() || undefined,
    };
    if (editingId) {
      updateInvoice(editingId, payload);
      toast.success(`${payload.number} updated`);
    } else {
      addInvoice(payload);
      toast.success(`${payload.number} created`);
    }
    setOpen(false);
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <PageHeader
        title="Invoices"
        description="Bill clients and track what you're owed."
        actions={
          <Button className="cursor-pointer" onClick={openCreate}>
            <Plus />
            New invoice
          </Button>
        }
      />

      {/* KPI row */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard
          label="Outstanding"
          value={formatCurrency(stats.outstanding, currency)}
          hint={countLabel(stats.outstandingCount)}
          icon={CircleDollarSign}
          accent="text-amber-600"
          iconClassName="bg-amber-100 text-amber-600 dark:bg-amber-500/15 dark:text-amber-400"
        />
        <StatCard
          label="Overdue"
          value={formatCurrency(stats.overdue, currency)}
          hint={countLabel(stats.overdueCount)}
          icon={AlertTriangle}
          accent="text-rose-600"
          iconClassName="bg-rose-100 text-rose-600 dark:bg-rose-500/15 dark:text-rose-400"
        />
        <StatCard
          label="Paid"
          value={formatCurrency(stats.paid, currency)}
          hint={countLabel(stats.paidCount)}
          icon={CheckCircle2}
          accent="text-emerald-600"
          iconClassName="bg-emerald-100 text-emerald-600 dark:bg-emerald-500/15 dark:text-emerald-400"
        />
      </div>

      {/* Status filter */}
      <div className="mt-6">
        <Tabs value={filter} onValueChange={v => setFilter(v as FilterValue)}>
          <TabsList>
            <TabsTrigger value="all" className="cursor-pointer">
              All
            </TabsTrigger>
            <TabsTrigger value="draft" className="cursor-pointer">
              Draft
            </TabsTrigger>
            <TabsTrigger value="sent" className="cursor-pointer">
              Sent
            </TabsTrigger>
            <TabsTrigger value="paid" className="cursor-pointer">
              Paid
            </TabsTrigger>
            <TabsTrigger value="overdue" className="cursor-pointer">
              Overdue
            </TabsTrigger>
          </TabsList>
        </Tabs>
      </div>

      {/* Invoices table */}
      <Card className="mt-4 shadow-sm">
        <CardContent className="px-0">
          {rows.length === 0 ? (
            <div className="flex flex-col items-center justify-center px-6 py-16 text-center">
              <span className="flex size-12 items-center justify-center rounded-full bg-muted text-muted-foreground">
                <FileText className="size-6" />
              </span>
              <h3 className="mt-4 text-sm font-medium text-foreground">
                {filter === 'all'
                  ? 'No invoices yet'
                  : `No ${filter} invoices`}
              </h3>
              <p className="mt-1 max-w-sm text-sm text-muted-foreground">
                Create your first invoice to start billing clients and
                tracking payments.
              </p>
              <Button className="mt-4 cursor-pointer" onClick={openCreate}>
                <Plus />
                New invoice
              </Button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Number</TableHead>
                    <TableHead>Client</TableHead>
                    <TableHead>Issued</TableHead>
                    <TableHead>Due</TableHead>
                    <TableHead className="text-right">Amount</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map(inv => {
                    const eff = effectiveInvoiceStatus(inv);
                    return (
                      <TableRow key={inv.id}>
                        <TableCell className="font-medium">
                          {inv.number}
                        </TableCell>
                        <TableCell>
                          {clientMap.get(inv.clientId)?.name ?? 'Unknown'}
                        </TableCell>
                        <TableCell>{formatDate(inv.issueDate)}</TableCell>
                        <TableCell>{formatDate(inv.dueDate)}</TableCell>
                        <TableCell className="text-right tabular-nums">
                          {formatCurrency(invoiceTotal(inv), currency)}
                        </TableCell>
                        <TableCell>
                          <StatusBadge status={eff} />
                        </TableCell>
                        <TableCell>
                          <div className="flex items-center justify-end gap-1">
                            {eff !== 'paid' && (
                              <Button
                                size="sm"
                                variant="outline"
                                className="cursor-pointer"
                                onClick={() => markPaid(inv)}
                              >
                                <CheckCircle2 />
                                Mark paid
                              </Button>
                            )}
                            <Button
                              size="icon-sm"
                              variant="ghost"
                              className="cursor-pointer"
                              aria-label={`Edit ${inv.number}`}
                              onClick={() => openEdit(inv)}
                            >
                              <Pencil />
                            </Button>
                            <Button
                              size="icon-sm"
                              variant="ghost"
                              className="cursor-pointer text-muted-foreground hover:text-destructive"
                              aria-label={`Delete ${inv.number}`}
                              onClick={() => handleDelete(inv)}
                            >
                              <Trash2 />
                            </Button>
                          </div>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Create / edit dialog */}
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-2xl">
          <DialogHeader>
            <DialogTitle>
              {editingId ? 'Edit invoice' : 'New invoice'}
            </DialogTitle>
            <DialogDescription>
              {editingId
                ? 'Update the details, line items, and status of this invoice.'
                : 'Add line items and issue a new invoice to a client.'}
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="grid gap-1.5">
              <Label htmlFor="inv-number">Number</Label>
              <Input
                id="inv-number"
                value={number}
                onChange={e => setNumber(e.target.value)}
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="inv-status">Status</Label>
              <Select
                value={status}
                onValueChange={v => setStatus(v as InvoiceStatus)}
              >
                <SelectTrigger id="inv-status" className="w-full">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="draft">Draft</SelectItem>
                  <SelectItem value="sent">Sent</SelectItem>
                  <SelectItem value="paid">Paid</SelectItem>
                  <SelectItem value="overdue">Overdue</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="inv-client">Client</Label>
              <Select
                value={clientId}
                onValueChange={v => {
                  setClientId(v);
                  setProjectId('none');
                }}
              >
                <SelectTrigger id="inv-client" className="w-full">
                  <SelectValue placeholder="Select a client" />
                </SelectTrigger>
                <SelectContent>
                  {data.clients.map(c => (
                    <SelectItem key={c.id} value={c.id}>
                      {c.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="inv-project">Project</Label>
              <Select value={projectId} onValueChange={setProjectId}>
                <SelectTrigger id="inv-project" className="w-full">
                  <SelectValue placeholder="No project" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="none">No project</SelectItem>
                  {clientProjects.map(p => (
                    <SelectItem key={p.id} value={p.id}>
                      {p.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="inv-issue">Issue date</Label>
              <Input
                id="inv-issue"
                type="date"
                value={issueDate}
                onChange={e => setIssueDate(e.target.value)}
              />
            </div>
            <div className="grid gap-1.5">
              <Label htmlFor="inv-due">Due date</Label>
              <Input
                id="inv-due"
                type="date"
                value={dueDate}
                onChange={e => setDueDate(e.target.value)}
              />
            </div>
          </div>

          <Separator />

          {/* Line items editor */}
          <div className="grid gap-2">
            <div className="flex items-center justify-between">
              <Label>Line items</Label>
              <Button
                type="button"
                size="sm"
                variant="ghost"
                className="cursor-pointer"
                onClick={() => setLines(ls => [...ls, blankLine()])}
              >
                <Plus />
                Add line
              </Button>
            </div>

            <div className="grid gap-2">
              {lines.map(line => (
                <div key={line.id} className="flex items-center gap-2">
                  <Input
                    className="flex-1"
                    placeholder="Description"
                    value={line.description}
                    onChange={e =>
                      patchLine(line.id, { description: e.target.value })
                    }
                  />
                  <Input
                    className="w-20"
                    type="number"
                    min="0"
                    step="1"
                    placeholder="Qty"
                    value={line.quantity}
                    onChange={e =>
                      patchLine(line.id, { quantity: e.target.value })
                    }
                  />
                  <Input
                    className="w-28"
                    type="number"
                    min="0"
                    step="0.01"
                    placeholder="Unit price"
                    value={line.unitPrice}
                    onChange={e =>
                      patchLine(line.id, { unitPrice: e.target.value })
                    }
                  />
                  <Button
                    type="button"
                    size="icon-sm"
                    variant="ghost"
                    className="cursor-pointer text-muted-foreground hover:text-destructive"
                    aria-label="Remove line"
                    disabled={lines.length <= 1}
                    onClick={() => removeLine(line.id)}
                  >
                    <X />
                  </Button>
                </div>
              ))}
            </div>

            <div className="flex items-center justify-end gap-3 pt-1 text-sm">
              <span className="text-muted-foreground">Total</span>
              <span className="font-semibold tabular-nums">
                {formatCurrency(draftTotal, currency)}
              </span>
            </div>
          </div>

          <div className="grid gap-1.5">
            <Label htmlFor="inv-notes">Notes</Label>
            <textarea
              id="inv-notes"
              className={TEXTAREA_CLASS}
              rows={3}
              placeholder="Payment terms, thank-you note, etc."
              value={notes}
              onChange={e => setNotes(e.target.value)}
            />
          </div>

          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline" className="cursor-pointer">
                Cancel
              </Button>
            </DialogClose>
            <Button className="cursor-pointer" onClick={handleSubmit}>
              {editingId ? 'Save changes' : 'Create invoice'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
