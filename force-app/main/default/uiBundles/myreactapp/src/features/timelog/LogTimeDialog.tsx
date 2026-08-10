import { useState } from 'react';
import {
  Pencil,
  Timer as TimerIcon,
  CalendarClock,
  Play,
  Pause,
  Square,
  Building2,
} from 'lucide-react';
import type { Project, TimeEntry } from '@/lib/types';
import type { useTimer } from '@/hooks/useTimer';
import { formatDuration, formatClock } from '@/lib/duration';
import { todayISO } from '@/lib/format';
import {
  Button,
  Input,
  Label,
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
  Tabs,
  TabsList,
  TabsTrigger,
  TabsContent,
} from '@/components/ui';
import { toast } from '@/components/ui/sonner';
import { Reveal } from '@/components/motion';
import { cn } from '@/lib/utils';
import type { LogTimeForm, LogTimeMode } from './useLogTimeForm';

const MS_PER_HOUR = 3_600_000;
const round2 = (n: number) => Math.round(n * 100) / 100;

type TimerApi = ReturnType<typeof useTimer>;

interface LogTimeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  projects: Project[];
  /** Resolve a project's client name for read-only anchor context. */
  clientNameFor: (projectId: string) => string | undefined;
  /** The single, header-shared persistent stopwatch. */
  timer: TimerApi;
  form: LogTimeForm;
  onCreate: (input: Omit<TimeEntry, 'id' | 'createdAt'>) => void;
}

/**
 * The enhanced Log-Time surface: a mode switcher (Manual / Timer / Range) over
 * a shared set of fields (Project, Date, Description, Billable). Every mode
 * resolves to the same decimal-hours `TimeEntry`.
 */
export function LogTimeDialog({
  open,
  onOpenChange,
  projects,
  clientNameFor,
  timer,
  form,
  onCreate,
}: LogTimeDialogProps) {
  const hasProjects = projects.length > 0;

  // Timer-session accounting. `bankedMs` holds time from finished run segments
  // (across Pause/Resume); the underlying `useTimer` measures the live segment.
  const [bankedMs, setBankedMs] = useState(0);

  // Reset the banked time whenever the dialog closes (any path) so the next
  // session starts clean, without a render-triggering effect.
  function handleOpenChange(next: boolean) {
    if (!next) setBankedMs(0);
    onOpenChange(next);
  }

  const liveMs = timer.running ? timer.elapsedMs : 0;
  const totalMs = bankedMs + liveMs;
  const paused = !timer.running && bankedMs > 0;

  function startTimer() {
    timer.start();
  }
  function pauseTimer() {
    // Bank the live segment, then stop the persistent clock.
    const segmentMs = timer.stop() * MS_PER_HOUR;
    setBankedMs(b => b + segmentMs);
  }
  function resumeTimer() {
    timer.start();
  }
  /** Stop, resolve the elapsed time into the Manual field, and switch to it. */
  function stopTimer() {
    const segmentMs = timer.running ? timer.stop() * MS_PER_HOUR : 0;
    const hours = round2((bankedMs + segmentMs) / MS_PER_HOUR);
    setBankedMs(0);
    if (hours > 0) {
      form.setDurationText(formatDuration(hours));
      form.setMode('manual');
      toast.success(`Stopped at ${formatDuration(hours)}.`);
    } else {
      form.setMode('manual');
    }
  }

  /** Decimal hours for the active mode, or null if not yet valid. */
  function resolveHours(): number | null {
    if (form.mode === 'manual') return form.manualHours;
    if (form.mode === 'range') return form.range.hours;
    // timer
    const total = round2(totalMs / MS_PER_HOUR);
    return total > 0 ? total : null;
  }

  function handleSave() {
    if (!form.projectId) {
      toast.error('Pick a project first.');
      return;
    }
    if (form.mode === 'range' && form.range.error) {
      toast.error(form.range.error);
      return;
    }
    const hours = resolveHours();
    if (hours == null) {
      if (form.mode === 'timer') {
        toast.error('Start the timer before saving.');
      } else if (form.mode === 'range') {
        toast.error('Enter a start and end time.');
      } else {
        toast.error('Enter a valid duration, e.g. 1.5, 1:30, 1h30, or 90m.');
      }
      return;
    }
    // If saving straight from a running timer, close it out cleanly.
    if (form.mode === 'timer' && timer.running) {
      timer.stop();
      setBankedMs(0);
    }
    onCreate({
      projectId: form.projectId,
      date: form.date || todayISO(),
      hours,
      description: form.description.trim() || undefined,
      billed: form.billed,
    });
    toast.success(`Logged ${formatDuration(hours)}.`);
    handleOpenChange(false);
  }

  const clientName = form.projectId ? clientNameFor(form.projectId) : undefined;

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="sm:max-w-lg">
        <Reveal>
          <DialogHeader>
            <DialogTitle>Log time</DialogTitle>
            <DialogDescription>
              Capture a block by typing a duration, running a timer, or entering
              a start and end time.
            </DialogDescription>
          </DialogHeader>

          <form
            onSubmit={e => {
              e.preventDefault();
              handleSave();
            }}
          >
            <Tabs
              value={form.mode}
              onValueChange={v => form.setMode(v as LogTimeMode)}
              className="mt-2"
            >
              <TabsList className="grid w-full grid-cols-3">
                <TabsTrigger value="manual">
                  <Pencil />
                  Manual
                </TabsTrigger>
                <TabsTrigger value="timer">
                  <TimerIcon />
                  Timer
                  {(timer.running || paused) && (
                    <span
                      aria-hidden
                      className={cn(
                        'ml-1 size-1.5 rounded-full',
                        timer.running
                          ? 'bg-emerald-500 motion-safe:animate-pulse'
                          : 'bg-amber-500'
                      )}
                    />
                  )}
                </TabsTrigger>
                <TabsTrigger value="range">
                  <CalendarClock />
                  Range
                </TabsTrigger>
              </TabsList>

              {/* Manual */}
              <TabsContent
                value="manual"
                className="mt-4 motion-safe:animate-[fops-page-in_0.25s_ease-out]"
              >
                <div className="grid gap-1.5">
                  <Label htmlFor="entry-hours">Duration</Label>
                  <Input
                    id="entry-hours"
                    type="text"
                    inputMode="decimal"
                    autoFocus
                    placeholder="1.5, 1:30, 1h30, 90m…"
                    value={form.durationText}
                    onChange={e => form.setDurationText(e.target.value)}
                    className="tabular-nums"
                  />
                  <p className="min-h-4 text-xs text-muted-foreground tabular-nums">
                    {form.durationText.trim() === '' ? (
                      'Type a duration in any common form.'
                    ) : form.manualHours != null ? (
                      <span className="text-foreground">
                        = {formatDuration(form.manualHours)}
                      </span>
                    ) : (
                      <span className="text-destructive">
                        Not a valid duration.
                      </span>
                    )}
                  </p>
                </div>
              </TabsContent>

              {/* Timer */}
              <TabsContent
                value="timer"
                className="mt-4 motion-safe:animate-[fops-page-in_0.25s_ease-out]"
              >
                <div className="flex flex-col items-center gap-4 rounded-lg border bg-muted/30 py-6">
                  <div className="flex items-center gap-2">
                    <span
                      aria-hidden
                      className={cn(
                        'size-2.5 rounded-full',
                        timer.running
                          ? 'bg-emerald-500 motion-safe:animate-pulse'
                          : paused
                            ? 'bg-amber-500'
                            : 'bg-muted-foreground/40'
                      )}
                    />
                    <span
                      className="text-4xl font-semibold tabular-nums"
                      role="timer"
                      aria-live="off"
                    >
                      {formatClock(totalMs)}
                    </span>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {timer.running
                      ? 'Timer running'
                      : paused
                        ? 'Paused'
                        : 'Stopped'}
                  </p>
                  <div className="flex items-center gap-2">
                    {!timer.running ? (
                      <Button
                        type="button"
                        variant="outline"
                        onClick={paused ? resumeTimer : startTimer}
                        className="cursor-pointer"
                      >
                        <Play />
                        {paused ? 'Resume' : 'Start'}
                      </Button>
                    ) : (
                      <Button
                        type="button"
                        variant="outline"
                        onClick={pauseTimer}
                        className="cursor-pointer"
                      >
                        <Pause />
                        Pause
                      </Button>
                    )}
                    <Button
                      type="button"
                      variant="destructive"
                      onClick={stopTimer}
                      disabled={totalMs <= 0}
                      className="cursor-pointer"
                    >
                      <Square className="fill-current" />
                      Stop
                    </Button>
                  </div>
                </div>
              </TabsContent>

              {/* Range */}
              <TabsContent
                value="range"
                className="mt-4 motion-safe:animate-[fops-page-in_0.25s_ease-out]"
              >
                <div className="grid grid-cols-2 gap-4">
                  <div className="grid gap-1.5">
                    <Label htmlFor="entry-start">Start</Label>
                    <Input
                      id="entry-start"
                      type="time"
                      value={form.startTime}
                      onChange={e => form.setStartTime(e.target.value)}
                      className="tabular-nums"
                    />
                  </div>
                  <div className="grid gap-1.5">
                    <Label htmlFor="entry-end">End</Label>
                    <Input
                      id="entry-end"
                      type="time"
                      value={form.endTime}
                      onChange={e => form.setEndTime(e.target.value)}
                      className="tabular-nums"
                    />
                  </div>
                </div>
                <p className="mt-1.5 min-h-4 text-xs tabular-nums">
                  {form.range.error ? (
                    <span className="text-destructive">{form.range.error}</span>
                  ) : form.range.hours != null ? (
                    <span className="text-foreground">
                      = {formatDuration(form.range.hours)}
                    </span>
                  ) : (
                    <span className="text-muted-foreground">
                      Pick a start and end time.
                    </span>
                  )}
                </p>
              </TabsContent>
            </Tabs>

            {/* Shared fields — below the tabs so switching modes keeps them. */}
            <div className="mt-5 grid gap-4 border-t pt-5">
              <div className="grid gap-1.5">
                <Label htmlFor="entry-project">Project</Label>
                {hasProjects ? (
                  <Select
                    value={form.projectId}
                    onValueChange={form.setProjectId}
                  >
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
                {clientName && (
                  <p className="flex items-center gap-1.5 text-xs text-muted-foreground motion-safe:animate-[fops-page-in_0.25s_ease-out]">
                    <Building2 className="size-3.5" />
                    {clientName}
                  </p>
                )}
              </div>

              <div className="grid gap-1.5">
                <Label htmlFor="entry-date">Date</Label>
                <Input
                  id="entry-date"
                  type="date"
                  value={form.date}
                  onChange={e => form.setDate(e.target.value)}
                />
              </div>

              <div className="grid gap-1.5">
                <Label htmlFor="entry-desc">Description</Label>
                <Input
                  id="entry-desc"
                  placeholder="What did you work on?"
                  value={form.description}
                  onChange={e => form.setDescription(e.target.value)}
                />
              </div>

              <label className="flex cursor-pointer items-center gap-2 text-sm text-foreground">
                <input
                  type="checkbox"
                  checked={form.billed}
                  onChange={e => form.setBilled(e.target.checked)}
                  className="size-4 cursor-pointer rounded border-input accent-primary"
                />
                Already billed
              </label>
            </div>

            <DialogFooter className="mt-6">
              <DialogClose asChild>
                <Button
                  type="button"
                  variant="outline"
                  className="cursor-pointer"
                >
                  Cancel
                </Button>
              </DialogClose>
              <Button
                type="submit"
                disabled={!hasProjects}
                className="cursor-pointer"
              >
                Save entry
              </Button>
            </DialogFooter>
          </form>
        </Reveal>
      </DialogContent>
    </Dialog>
  );
}
