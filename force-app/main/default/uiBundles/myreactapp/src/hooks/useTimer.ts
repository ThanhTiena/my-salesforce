import { useCallback, useEffect, useState } from 'react';

const STORAGE_KEY = 'freelancehub:timer';

function readStart(): number | null {
  try {
    const raw =
      typeof localStorage !== 'undefined'
        ? localStorage.getItem(STORAGE_KEY)
        : null;
    const n = raw ? Number(raw) : NaN;
    return Number.isFinite(n) ? n : null;
  } catch {
    return null;
  }
}

/**
 * A single, reload-proof stopwatch (Clockify pattern). The start timestamp is
 * persisted to localStorage and elapsed time is derived from the wall clock, so
 * closing the tab or reloading never loses the running timer. Only one timer
 * runs at a time by construction.
 */
export function useTimer() {
  const [startedAt, setStartedAt] = useState<number | null>(readStart);
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    if (startedAt == null) return;
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, [startedAt]);

  const running = startedAt != null;
  const elapsedMs = running ? Math.max(0, now - startedAt) : 0;
  const elapsedHours = elapsedMs / 3_600_000;

  const start = useCallback(() => {
    const t = Date.now();
    try {
      localStorage.setItem(STORAGE_KEY, String(t));
    } catch {
      /* ignore quota/availability */
    }
    setStartedAt(t);
    setNow(t);
  }, []);

  /** Stop the timer and return the elapsed decimal hours. */
  const stop = useCallback((): number => {
    const el = startedAt != null ? Math.max(0, Date.now() - startedAt) : 0;
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      /* ignore */
    }
    setStartedAt(null);
    return el / 3_600_000;
  }, [startedAt]);

  return { running, elapsedMs, elapsedHours, start, stop };
}
