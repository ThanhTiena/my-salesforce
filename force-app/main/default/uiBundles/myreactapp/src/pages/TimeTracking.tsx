import { useMemo, useState } from 'react';
import {
  Plus,
  Trash2,
  Clock,
  CircleDollarSign,
  CheckCircle2,
  CalendarDays,
  Play,
  Square,
} from 'lucide-react';
import { useStore, useProjectMap, useClientMap } from '@/lib/store';
import type { TimeEntry } from '@/lib/types';
import { formatCurrency, formatDate, todayISO } from '@/lib/format';
import { parseDuration, formatDuration, formatClock } from '@/lib/duration';
import { useTimer } from '@/hooks/useTimer';
import { PageHeader } from '@/components/page-header';
import { StatCard } from '@/components/stat-card';
import {
  Button,
  Input,
  Label,
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  Table,
  TableHeader,
  TableBody,
  TableRow,
  TableHead,
  TableCell,
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
import { Badge } from '@/components/ui/badge';
import { toast } from '@/components/ui/sonner';
import { cn } from '@/lib/utils';

/** Billable value of one entry: hours × the project's hourly rate. */
function entryValue(hours: number, rate: number | undefined): number {
  return hours * (rate ?? 0);
}

export default function TimeTracking() {
  const { data, addTimeEntry, updateTimeEntry, deleteTimeEntry } = useStore();
  const projectMap = useProjectMap();
  const clientMap = useClientMap();
  const currency = data.settings.currency;
  const { projects, timeEntries } = data;

  const [filterProject, setFilterProject] = useState<string>('all');

  // Create dialog + form state.
  const [open, setOpen] = useState(false);
  const [projectId, setProjectId] = useState('');
  const [date, setDate] = useState(todayISO());
  const [hours, setHours] = useState('');
  const [description, setDescription] = useState('');
  const [billed, setBilled] = useState(false);

  const kpis = useMemo(() => {
    // Local YYYY-MM so it matches how entry dates (local calendar days) render.
    const now = new Date();
    const monthPrefix = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
    let hoursThisMonth = 0;
    let entriesThisMonth = 0;
    let totalHours = 0;
    let unbilledHours = 0;
    let unbilledValue = 0;
    let unbilledEntries = 0;
    for (const e of timeEntries) {
      totalHours += e.hours;
      if (e.date.startsWith(monthPrefix)) {
        hoursThisMonth += e.hours;
        entriesThisMonth += 1;
      }
      if (!e.billed) {
        unbilledHours += e.hours;
        unbilledValue += entryValue(e.hours, projectMap.get(e.projectId)?.hourlyRate);
        unbilledEntries += 1;
      }
    }
    return {
      hoursThisMonth,
      entriesThisMonth,
      totalHours,
      unbilledHours,
      unbilledValue,
      unbilledEntries,
    };
  }, [timeEntries, projectMap]);

  const rows = useMemo(() => {
    return timeEntries
      .filter(e => filterProject === 'all' || e.projectId === filterProject)
      .slice()
      .sort((a, b) => b.date.localeCompare(a.date));
  }, [timeEntries, filterProject]);

  const totals = useMemo(() => {
    let h = 0;
    let v = 0;
    for (const e of rows) {
      h += e.hours;
      v += entryValue(e.hours, projectMap.get(e.projectId)?.hourlyRate);
    }
    return { hours: h, value: v };
  }, [rows, projectMap]);

  function openCreate(prefillHours?: string) {
    setProjectId(projects[0]?.id ?? '');
    setDate(todayISO());
    setHours(prefillHours ?? '');
    setDescription('');
    setBilled(false);
    setOpen(true);
  }

  function handleSave() {
    if (!projectId) {
      toast.error('Pick a project first.');
      return;
    }
    const h = parseDuration(hours);
    if (h == null) {
      toast.error('Enter a valid duration, e.g. 1.5, 1:30, 1h30, or 90m.');
      return;
    }
    addTimeEntry({
      projectId,
      date: date || todayISO(),
      hours: h,
      description: description.trim() || undefined,
      billed,
    });
    toast.success(`Logged ${formatDuration(h)}.`);
    setOpen(false);
  }

  // Live, reload-proof stopwatch. Stopping it opens the dialog prefilled with
  // the elapsed duration so the user just confirms project + notes.
  const timer = useTimer();
  function stopTimerAndLog() {
    const elapsed = timer.stop();
    openCreate(elapsed > 0 ? formatDuration(elapsed) : '');
  }

  function toggleBilled(e: TimeEntry) {
    updateTimeEntry(e.id, { billed: !e.billed });
    toast.success(e.billed ? 'Marked as unbilled.' : 'Marked as billed.');
  }

  function handleDelete(e: TimeEntry) {
    if (!window.confirm('Delete this time entry? This cannot be undone.')) return;
    deleteTimeEntry(e.id);
    toast.success('Time entry deleted.');
  }

  const hasProjects = projects.length > 0;

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
      <PageHeader
        title="Time Tracking"
        description="Log billable hours against your projects."
        actions={
          <div className="flex items-center gap-2">
            {timer.running ? (
              <Button
                variant="destructive"
                onClick={stopTimerAndLog}
                className="cursor-pointer"
              >
                <Square className="fill-current" />
                <span className="tabular-nums">
                  {formatClock(timer.elapsedMs)}
                </span>
              </Button>
            ) : (
              <Button
                variant="outline"
                onClick={timer.start}
                className="cursor-pointer"
                aria-label="Start timer"
              >
                <Play />
                Start timer
              </Button>
            )}
            <Button onClick={() => openCreate()} className="cursor-pointer">
              <Plus />
              Log time
            </Button>
          </div>
        }
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <StatCard
          label="Hours this month"
          value={`${kpis.hoursThisMonth.toFixed(1)}h`}
          hint={`${kpis.entriesThisMonth} entries · ${kpis.totalHours.toFixed(1)}h all-time`}
          icon={Clock}
          iconClassName="bg-primary/10 text-primary"
        />
        <StatCard
          label="Unbilled hours"
          value={`${kpis.unbilledHours.toFixed(1)}h`}
          hint={`${kpis.unbilledEntries} entries`}
          icon={CalendarDays}
          accent="text-amber-600"
          iconClassName="bg-amber-500/10 text-amber-600"
        />
        <StatCard
          label="Unbilled value"
          value={formatCurrency(kpis.unbilledValue, currency)}
          hint="Not yet invoiced"
          icon={CircleDollarSign}
          accent="text-amber-600"
          iconClassName="bg-amber-500/10 text-amber-600"
        />
      </div>

      <Card className="mt-6 rounded-xl shadow-sm">
        <CardHeader className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <CardTitle>Entries</CardTitle>
          <div className="flex items-center gap-2">
            <Label
              htmlFor="project-filter"
              className="text-xs text-muted-foreground"
            >
              Project
            </Label>
            <Select value={filterProject} onValueChange={setFilterProject}>
              <SelectTrigger id="project-filter" className="w-48">
                <SelectValue placeholder="All projects" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All projects</SelectItem>
                {projects.map(p => (
                  <SelectItem key={p.id} value={p.id}>
                    {p.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>
        </CardHeader>
        <CardContent>
          {rows.length === 0 ? (
            <div className="flex flex-col items-center justify-center gap-3 py-14 text-center">
              <span className="flex size-12 items-center justify-center rounded-full bg-muted text-muted-foreground">
                <Clock className="size-6" />
              </span>
              <div>
                <p className="font-medium text-foreground">
                  {timeEntries.length === 0
                    ? 'No time logged yet'
                    : 'No entries for this project'}
                </p>
                <p className="mt-1 text-sm text-muted-foreground">
                  Track billable hours to see them totalled here.
                </p>
              </div>
              <Button
                variant="outline"
                onClick={() => openCreate()}
                className="cursor-pointer"
              >
                <Plus />
                Log time
              </Button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Date</TableHead>
                    <TableHead>Project</TableHead>
                    <TableHead>Description</TableHead>
                    <TableHead className="text-right">Hours</TableHead>
                    <TableHead className="text-right">Value</TableHead>
                    <TableHead>Billed</TableHead>
                    <TableHead className="text-right">
                      <span className="sr-only">Actions</span>
                    </TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {rows.map(e => {
                    const project = projectMap.get(e.projectId);
                    const client = project
                      ? clientMap.get(project.clientId)
                      : undefined;
                    const value = entryValue(e.hours, project?.hourlyRate);
                    return (
                      <TableRow key={e.id}>
                        <TableCell className="whitespace-nowrap">
                          {formatDate(e.date)}
                        </TableCell>
                        <TableCell>
                          <div className="font-medium text-foreground">
                            {project?.name ?? 'Unknown project'}
                          </div>
                          {client && (
                            <div className="text-xs text-muted-foreground">
                              {client.name}
                            </div>
                          )}
                        </TableCell>
                        <TableCell className="max-w-[16rem] truncate text-muted-foreground">
                          {e.description || '—'}
                        </TableCell>
                        <TableCell className="text-right tabular-nums">
                          {e.hours.toFixed(1)}h
                        </TableCell>
                        <TableCell className="text-right tabular-nums">
                          {formatCurrency(value, currency)}
                        </TableCell>
                        <TableCell>
                          <Badge
                            asChild
                            variant="outline"
                            className={cn(
                              'cursor-pointer gap-1 transition-colors duration-200',
                              e.billed
                                ? 'border-transparent bg-emerald-500/15 text-emerald-600 hover:bg-emerald-500/25'
                                : 'text-muted-foreground hover:bg-muted'
                            )}
                          >
                            <button
                              type="button"
                              onClick={() => toggleBilled(e)}
                            >
                              {e.billed && <CheckCircle2 />}
                              {e.billed ? 'Billed' : 'Unbilled'}
                            </button>
                          </Badge>
                        </TableCell>
                        <TableCell className="text-right">
                          <Button
                            variant="ghost"
                            size="icon-sm"
                            onClick={() => handleDelete(e)}
                            className="cursor-pointer text-muted-foreground hover:text-destructive"
                            aria-label="Delete entry"
                          >
                            <Trash2 />
                          </Button>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                  <TableRow className="border-t-2">
                    <TableCell colSpan={3} className="font-medium">
                      Total
                    </TableCell>
                    <TableCell className="text-right font-medium tabular-nums">
                      {totals.hours.toFixed(1)}h
                    </TableCell>
                    <TableCell className="text-right font-medium tabular-nums">
                      {formatCurrency(totals.value, currency)}
                    </TableCell>
                    <TableCell colSpan={2} />
                  </TableRow>
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Log time</DialogTitle>
            <DialogDescription>
              Record billable hours against a project.
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-4">
            <div className="grid gap-1.5">
              <Label htmlFor="entry-project">Project</Label>
              {hasProjects ? (
                <Select value={projectId} onValueChange={setProjectId}>
                  <SelectTrigger id="entry-project" className="w-full">
                    <SelectValue placeholder="Select a project" />
                  </SelectTrigger>
                  <SelectContent>
                    {projects.map(p => (
                      <SelectItem key={p.id} value={p.id}>
                        {p.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              ) : (
                <p className="text-sm text-muted-foreground">
                  Create a project first to log time against it.
                </p>
              )}
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="grid gap-1.5">
                <Label htmlFor="entry-date">Date</Label>
                <Input
                  id="entry-date"
                  type="date"
                  value={date}
                  onChange={ev => setDate(ev.target.value)}
                />
              </div>
              <div className="grid gap-1.5">
                <Label htmlFor="entry-hours">Duration</Label>
                <Input
                  id="entry-hours"
                  type="text"
                  inputMode="decimal"
                  placeholder="1.5, 1:30, 1h30, 90m…"
                  value={hours}
                  onChange={ev => setHours(ev.target.value)}
                  className="tabular-nums"
                />
                {parseDuration(hours) != null && (
                  <p className="text-xs text-muted-foreground">
                    = {formatDuration(parseDuration(hours) as number)}
                  </p>
                )}
              </div>
            </div>

            <div className="grid gap-1.5">
              <Label htmlFor="entry-desc">Description</Label>
              <Input
                id="entry-desc"
                placeholder="What did you work on?"
                value={description}
                onChange={ev => setDescription(ev.target.value)}
              />
            </div>

            <label className="flex cursor-pointer items-center gap-2 text-sm text-foreground">
              <input
                type="checkbox"
                checked={billed}
                onChange={ev => setBilled(ev.target.checked)}
                className="size-4 cursor-pointer rounded border-input accent-primary"
              />
              Already billed
            </label>
          </div>

          <DialogFooter>
            <DialogClose asChild>
              <Button variant="outline" className="cursor-pointer">
                Cancel
              </Button>
            </DialogClose>
            <Button
              onClick={handleSave}
              disabled={!hasProjects}
              className="cursor-pointer"
            >
              Save entry
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
