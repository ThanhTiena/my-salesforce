import { useCallback, useMemo, useState } from 'react';
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
import { formatCurrency, formatDate } from '@/lib/format';
import { formatDuration, formatClock } from '@/lib/duration';
import { useTimer } from '@/hooks/useTimer';
import { PageHeader } from '@/components/common/page-header';
import { StatCard } from '@/components/common/stat-card';
import {
  Button,
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
  Select,
  SelectTrigger,
  SelectValue,
  SelectContent,
  SelectItem,
} from '@/components/ui';
import { Badge } from '@/components/ui/badge';
import { toast } from '@/components/ui/sonner';
import { cn } from '@/lib/utils';
import { LogTimeDialog } from '@/features/timelog/LogTimeDialog';
import { useLogTimeForm } from '@/features/timelog/useLogTimeForm';

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

  // Create dialog + shared, multi-mode form state (Manual / Timer / Range).
  const [open, setOpen] = useState(false);
  const form = useLogTimeForm();

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

  // The Assignment-anchored pattern, adapted to the local model: the project is
  // the anchor, and its client name renders as read-only context in the dialog.
  const clientNameFor = useCallback(
    (projectId: string): string | undefined => {
      const project = projectMap.get(projectId);
      return project ? clientMap.get(project.clientId)?.name : undefined;
    },
    [projectMap, clientMap]
  );

  function openCreate() {
    form.reset({ projectId: projects[0]?.id ?? '' });
    setOpen(true);
  }

  // Live, reload-proof stopwatch shared with the dialog's Timer tab, so a timer
  // started here in the header is reflected inside the dialog and vice-versa.
  const timer = useTimer();
  function stopTimerAndLog() {
    const elapsed = timer.stop();
    form.reset({
      projectId: projects[0]?.id ?? '',
      durationText: elapsed > 0 ? formatDuration(elapsed) : '',
    });
    setOpen(true);
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
            <Button onClick={openCreate} className="cursor-pointer">
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
                onClick={openCreate}
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

      <LogTimeDialog
        open={open}
        onOpenChange={setOpen}
        projects={projects}
        clientNameFor={clientNameFor}
        timer={timer}
        form={form}
        onCreate={addTimeEntry}
      />
    </div>
  );
}
