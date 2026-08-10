import { useCallback, useMemo, useState } from 'react';
import { parseDuration } from '@/lib/duration';
import { todayISO } from '@/lib/format';

/** The three ways a duration can be captured. All resolve to decimal hours. */
export type LogTimeMode = 'manual' | 'timer' | 'range';

/** Parse a "HH:MM" clock string into minutes-since-midnight, or null. */
function clockToMinutes(value: string): number | null {
  const m = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  if (!m) return null;
  const h = Number(m[1]);
  const min = Number(m[2]);
  if (h > 23 || min > 59) return null;
  return h * 60 + min;
}

export interface RangeResult {
  /** Decimal hours for a valid span, else null. */
  hours: number | null;
  /** A human-friendly problem to surface, else null (incomplete is not an error). */
  error: string | null;
}

/** Compute decimal hours for a start/end range, rejecting end <= start. */
export function computeRange(start: string, end: string): RangeResult {
  if (!start || !end) return { hours: null, error: null };
  const s = clockToMinutes(start);
  const e = clockToMinutes(end);
  if (s == null || e == null) {
    return { hours: null, error: 'Enter valid start and end times.' };
  }
  if (e === s) return { hours: null, error: 'Start and end are the same time.' };
  if (e < s) {
    return { hours: null, error: 'End time must be after the start time.' };
  }
  return { hours: Math.round(((e - s) / 60) * 100) / 100, error: null };
}

export interface LogTimeForm {
  mode: LogTimeMode;
  setMode: (mode: LogTimeMode) => void;

  // Shared fields (kept below the mode tabs so switching never loses them).
  projectId: string;
  setProjectId: (id: string) => void;
  date: string;
  setDate: (date: string) => void;
  description: string;
  setDescription: (value: string) => void;
  billed: boolean;
  setBilled: (value: boolean) => void;

  // Manual mode.
  durationText: string;
  setDurationText: (value: string) => void;
  /** Live-parsed decimal hours for the manual field, or null. */
  manualHours: number | null;

  // Range mode.
  startTime: string;
  setStartTime: (value: string) => void;
  endTime: string;
  setEndTime: (value: string) => void;
  range: RangeResult;

  /** Reset every field for a fresh dialog session. */
  reset: (opts?: { projectId?: string; durationText?: string }) => void;
}

/**
 * Owns all shared + per-mode form state for the Log-Time dialog. Extracted so
 * the page stays lean and the dialog can be a thin, presentational shell. The
 * running timer itself lives in `useTimer` (persistent, header-shared) and is
 * wired into the dialog separately.
 */
export function useLogTimeForm(): LogTimeForm {
  const [mode, setMode] = useState<LogTimeMode>('manual');
  const [projectId, setProjectId] = useState('');
  const [date, setDate] = useState(todayISO());
  const [description, setDescription] = useState('');
  const [billed, setBilled] = useState(false);
  const [durationText, setDurationText] = useState('');
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');

  const manualHours = useMemo(() => parseDuration(durationText), [durationText]);
  const range = useMemo(
    () => computeRange(startTime, endTime),
    [startTime, endTime]
  );

  const reset = useCallback(
    (opts?: { projectId?: string; durationText?: string }) => {
      setMode('manual');
      setProjectId(opts?.projectId ?? '');
      setDate(todayISO());
      setDescription('');
      setBilled(false);
      setDurationText(opts?.durationText ?? '');
      setStartTime('');
      setEndTime('');
    },
    []
  );

  return {
    mode,
    setMode,
    projectId,
    setProjectId,
    date,
    setDate,
    description,
    setDescription,
    billed,
    setBilled,
    durationText,
    setDurationText,
    manualHours,
    startTime,
    setStartTime,
    endTime,
    setEndTime,
    range,
    reset,
  };
}
