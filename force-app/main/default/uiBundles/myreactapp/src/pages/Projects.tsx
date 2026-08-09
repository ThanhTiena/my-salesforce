import { useMemo, useState } from 'react';
import {
  Plus,
  Pencil,
  Trash2,
  FolderKanban,
  Calendar,
  Clock,
  CircleDollarSign,
} from 'lucide-react';

import { useStore, useClientMap } from '@/lib/store';
import type { Project } from '@/lib/types';
import { formatCurrency, formatDate } from '@/lib/format';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import {
  Button,
  Input,
  Label,
  Card,
  CardHeader,
  CardContent,
  CardFooter,
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
} from '@/components/ui';
import { toast } from '@/components/ui/sonner';

type ProjectStatus = Project['status'];

const STATUS_OPTIONS: { value: ProjectStatus; label: string }[] = [
  { value: 'planning', label: 'Planning' },
  { value: 'active', label: 'Active' },
  { value: 'on-hold', label: 'On Hold' },
  { value: 'completed', label: 'Completed' },
  { value: 'cancelled', label: 'Cancelled' },
];

const FILTERS: { value: string; label: string }[] = [
  { value: 'all', label: 'All' },
  { value: 'active', label: 'Active' },
  { value: 'planning', label: 'Planning' },
  { value: 'on-hold', label: 'On Hold' },
  { value: 'completed', label: 'Completed' },
  { value: 'cancelled', label: 'Cancelled' },
];

const STATUS_PROGRESS: Record<ProjectStatus, number> = {
  planning: 10,
  active: 55,
  'on-hold': 40,
  completed: 100,
  cancelled: 0,
};

interface FormState {
  name: string;
  clientId: string;
  status: ProjectStatus;
  hourlyRate: string;
  budget: string;
  startDate: string;
  dueDate: string;
  description: string;
}

const EMPTY_FORM: FormState = {
  name: '',
  clientId: '',
  status: 'planning',
  hourlyRate: '',
  budget: '',
  startDate: '',
  dueDate: '',
  description: '',
};

function toNumber(value: string): number | undefined {
  const trimmed = value.trim();
  if (trimmed === '') return undefined;
  const n = Number(trimmed);
  return Number.isFinite(n) ? n : undefined;
}

export default function Projects() {
  const { data, addProject, updateProject, deleteProject } = useStore();
  const clientMap = useClientMap();
  const currency = data.settings.currency;

  const [filter, setFilter] = useState<string>('all');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(EMPTY_FORM);
  const [deleting, setDeleting] = useState<Project | null>(null);

  const noClients = data.clients.length === 0;

  // Tracked hours per project, derived from time entries.
  const hoursByProject = useMemo(() => {
    const map = new Map<string, number>();
    for (const entry of data.timeEntries) {
      map.set(entry.projectId, (map.get(entry.projectId) ?? 0) + entry.hours);
    }
    return map;
  }, [data.timeEntries]);

  const visible = useMemo(() => {
    const rows = data.projects.filter(
      p => filter === 'all' || p.status === filter
    );
    return rows.sort((a, b) => {
      const aActive = a.status === 'active' ? 0 : 1;
      const bActive = b.status === 'active' ? 0 : 1;
      if (aActive !== bActive) return aActive - bActive;
      const ad = a.dueDate ?? '￿';
      const bd = b.dueDate ?? '￿';
      return ad.localeCompare(bd);
    });
  }, [data.projects, filter]);

  function openCreate() {
    setEditingId(null);
    setForm(EMPTY_FORM);
    setDialogOpen(true);
  }

  function openEdit(p: Project) {
    setEditingId(p.id);
    setForm({
      name: p.name,
      clientId: p.clientId,
      status: p.status,
      hourlyRate: p.hourlyRate?.toString() ?? '',
      budget: p.budget?.toString() ?? '',
      startDate: p.startDate ?? '',
      dueDate: p.dueDate ?? '',
      description: p.description ?? '',
    });
    setDialogOpen(true);
  }

  function handleSave() {
    const name = form.name.trim();
    if (!name) {
      toast.error('Project name is required');
      return;
    }
    if (!form.clientId) {
      toast.error('Please select a client');
      return;
    }
    const patch = {
      name,
      clientId: form.clientId,
      status: form.status,
      hourlyRate: toNumber(form.hourlyRate),
      budget: toNumber(form.budget),
      startDate: form.startDate || undefined,
      dueDate: form.dueDate || undefined,
      description: form.description.trim() || undefined,
    };
    if (editingId) {
      updateProject(editingId, patch);
      toast.success('Project updated');
    } else {
      addProject(patch);
      toast.success('Project created');
    }
    setDialogOpen(false);
  }

  function confirmDelete() {
    if (!deleting) return;
    deleteProject(deleting.id);
    toast.success(`Deleted ${deleting.name}`);
    setDeleting(null);
  }

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <PageHeader
        title="Projects"
        description="Track every engagement from kickoff to delivery."
        actions={
          <Button onClick={openCreate}>
            <Plus />
            New project
          </Button>
        }
      />

      <Tabs value={filter} onValueChange={setFilter} className="mb-6">
        <TabsList>
          {FILTERS.map(f => (
            <TabsTrigger key={f.value} value={f.value}>
              {f.label}
            </TabsTrigger>
          ))}
        </TabsList>
      </Tabs>

      {visible.length === 0 ? (
        <div className="flex flex-col items-center justify-center rounded-xl border border-dashed py-16 text-center">
          <div className="mb-4 flex size-14 items-center justify-center rounded-full bg-muted">
            <FolderKanban className="size-6 text-muted-foreground" />
          </div>
          <h3 className="text-base font-semibold text-foreground">
            No projects yet
          </h3>
          <p className="mt-1 max-w-sm text-sm text-muted-foreground">
            {filter === 'all'
              ? 'Spin up your first engagement to start tracking time, budget, and delivery.'
              : 'No projects match this filter. Try a different status.'}
          </p>
          {filter === 'all' && (
            <Button className="mt-4" onClick={openCreate}>
              <Plus />
              New project
            </Button>
          )}
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 md:gap-6 xl:grid-cols-3">
          {visible.map(p => {
            const client = clientMap.get(p.clientId);
            const clientName = client?.name ?? 'Unknown client';
            const trackedHours = hoursByProject.get(p.id) ?? 0;
            const trackedValue = trackedHours * (p.hourlyRate ?? 0);
            const progress = p.budget
              ? Math.min(100, Math.round((trackedValue / p.budget) * 100))
              : STATUS_PROGRESS[p.status];
            return (
              <Card
                key={p.id}
                size="sm"
                className="shadow-sm transition-shadow hover:shadow"
              >
                <CardHeader>
                  <div className="flex items-start justify-between gap-2">
                    <div className="min-w-0">
                      <div className="truncate font-semibold text-foreground">
                        {p.name}
                      </div>
                      <div className="truncate text-sm text-muted-foreground">
                        {clientName}
                      </div>
                    </div>
                    <StatusBadge status={p.status} />
                  </div>
                </CardHeader>
                <CardContent>
                  <dl className="grid grid-cols-2 gap-3 text-sm">
                    <Meta icon={CircleDollarSign} label="Rate">
                      {p.hourlyRate != null
                        ? `${formatCurrency(p.hourlyRate, currency)}/hr`
                        : '—'}
                    </Meta>
                    <Meta icon={CircleDollarSign} label="Budget">
                      {p.budget != null
                        ? formatCurrency(p.budget, currency)
                        : '—'}
                    </Meta>
                    <Meta icon={Calendar} label="Due">
                      {formatDate(p.dueDate)}
                    </Meta>
                    <Meta icon={Clock} label="Tracked">
                      <span className="tabular-nums">{trackedHours}h</span>
                    </Meta>
                  </dl>

                  <div className="mt-4">
                    <div className="mb-1 flex items-center justify-between text-xs">
                      <span className="text-muted-foreground tabular-nums">
                        {formatCurrency(trackedValue, currency)} tracked
                      </span>
                      <span className="font-medium tabular-nums">
                        {progress}%
                      </span>
                    </div>
                    <div className="h-2 w-full overflow-hidden rounded-full bg-muted">
                      <div
                        className="h-full rounded-full bg-primary transition-all"
                        style={{ width: `${progress}%` }}
                      />
                    </div>
                  </div>
                </CardContent>
                <CardFooter className="justify-end gap-1 pt-2">
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    aria-label="Edit project"
                    className="cursor-pointer"
                    onClick={() => openEdit(p)}
                  >
                    <Pencil />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon-sm"
                    aria-label="Delete project"
                    className="cursor-pointer text-muted-foreground hover:text-destructive"
                    onClick={() => setDeleting(p)}
                  >
                    <Trash2 />
                  </Button>
                </CardFooter>
              </Card>
            );
          })}
        </div>
      )}

      {/* Create / edit dialog */}
      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>
              {editingId ? 'Edit project' : 'New project'}
            </DialogTitle>
            <DialogDescription>
              {editingId
                ? 'Update the details for this engagement.'
                : 'Set up a new engagement to track time and budget.'}
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-4">
            <div className="grid gap-1.5">
              <Label htmlFor="project-name">Name</Label>
              <Input
                id="project-name"
                value={form.name}
                placeholder="Website redesign"
                onChange={e => setForm({ ...form, name: e.target.value })}
              />
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="project-client">Client</Label>
              {noClients ? (
                <p className="text-sm text-muted-foreground">
                  Add a client first before creating a project.
                </p>
              ) : (
                <Select
                  value={form.clientId}
                  onValueChange={v => setForm({ ...form, clientId: v })}
                >
                  <SelectTrigger id="project-client" className="w-full">
                    <SelectValue placeholder="Select a client" />
                  </SelectTrigger>
                  <SelectContent>
                    {data.clients.map(c => (
                      <SelectItem key={c.id} value={c.id}>
                        {c.company ? `${c.name} · ${c.company}` : c.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-1.5">
                <Label htmlFor="project-status">Status</Label>
                <Select
                  value={form.status}
                  onValueChange={v =>
                    setForm({ ...form, status: v as ProjectStatus })
                  }
                >
                  <SelectTrigger id="project-status" className="w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {STATUS_OPTIONS.map(s => (
                      <SelectItem key={s.value} value={s.value}>
                        {s.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="project-rate">Hourly rate</Label>
                <Input
                  id="project-rate"
                  type="number"
                  min="0"
                  step="1"
                  value={form.hourlyRate}
                  placeholder="0"
                  onChange={e =>
                    setForm({ ...form, hourlyRate: e.target.value })
                  }
                />
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-1.5">
                <Label htmlFor="project-budget">Budget</Label>
                <Input
                  id="project-budget"
                  type="number"
                  min="0"
                  step="100"
                  value={form.budget}
                  placeholder="0"
                  onChange={e => setForm({ ...form, budget: e.target.value })}
                />
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="project-start">Start date</Label>
                <Input
                  id="project-start"
                  type="date"
                  value={form.startDate}
                  onChange={e =>
                    setForm({ ...form, startDate: e.target.value })
                  }
                />
              </div>
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="project-due">Due date</Label>
              <Input
                id="project-due"
                type="date"
                value={form.dueDate}
                onChange={e => setForm({ ...form, dueDate: e.target.value })}
              />
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="project-desc">Description</Label>
              <textarea
                id="project-desc"
                rows={3}
                value={form.description}
                placeholder="Scope, deliverables, notes…"
                onChange={e =>
                  setForm({ ...form, description: e.target.value })
                }
                className="border-input focus-visible:border-ring focus-visible:ring-ring/50 dark:bg-input/30 w-full resize-y rounded-lg border bg-transparent px-2.5 py-1.5 text-sm outline-none transition-colors focus-visible:ring-3 placeholder:text-muted-foreground/70 placeholder:italic"
              />
            </div>
          </div>

          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline">Cancel</Button>
            </DialogClose>
            <Button onClick={handleSave} disabled={noClients}>
              {editingId ? 'Save changes' : 'Create project'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete confirmation */}
      <Dialog
        open={deleting != null}
        onOpenChange={open => !open && setDeleting(null)}
      >
        <DialogContent className="sm:max-w-sm">
          <DialogHeader>
            <DialogTitle>Delete project?</DialogTitle>
            <DialogDescription>
              This permanently deletes{' '}
              <span className="font-medium text-foreground">
                {deleting?.name}
              </span>
              , removes its tracked time entries, and unlinks it from any
              invoices. This cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline">Cancel</Button>
            </DialogClose>
            <Button variant="destructive" onClick={confirmDelete}>
              <Trash2 />
              Delete
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

function Meta({
  icon: Icon,
  label,
  children,
}: {
  icon: React.ComponentType<{ className?: string }>;
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-start gap-2">
      <Icon className="mt-0.5 size-4 shrink-0 text-muted-foreground" />
      <div className="min-w-0">
        <dt className="text-xs text-muted-foreground">{label}</dt>
        <dd className="truncate font-medium text-foreground">{children}</dd>
      </div>
    </div>
  );
}
