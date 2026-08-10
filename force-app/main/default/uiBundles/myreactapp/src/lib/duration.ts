/**
 * Flexible duration grammar shared by every time-logging mode (manual entry,
 * timer, range, week grid). Accepts the forms people actually type:
 *   "1.5"      -> 1.5 h        "90m"   -> 1.5 h
 *   "1:30"     -> 1.5 h        "45s"   -> 0.0125 h
 *   "1h30"     -> 1.5 h        "1h"    -> 1 h
 *   "1h 30m"   -> 1.5 h        "2h15m" -> 2.25 h
 * Returns decimal hours rounded to 2dp, or null when unparseable / <= 0.
 */
export function parseDuration(input: string): number | null {
  const s = input.trim().toLowerCase().replace(/\s+/g, '');
  if (!s) return null;

  let hours: number | null = null;
  let m: RegExpExecArray | null;

  if ((m = /^(\d+):(\d{1,2})(?::(\d{1,2}))?$/.exec(s))) {
    // clock form 1:30 or 1:30:00
    const min = Number(m[2]);
    if (min >= 60) return null;
    hours = Number(m[1]) + min / 60 + (m[3] ? Number(m[3]) / 3600 : 0);
  } else if ((m = /^(\d+)h(\d+)m?$/.exec(s))) {
    // 1h30 / 1h30m
    const min = Number(m[2]);
    if (min >= 60) return null;
    hours = Number(m[1]) + min / 60;
  } else if ((m = /^(\d+(?:\.\d+)?)h$/.exec(s))) {
    hours = Number(m[1]); // 1h / 1.5h
  } else if ((m = /^(\d+(?:\.\d+)?)m$/.exec(s))) {
    hours = Number(m[1]) / 60; // 90m / 30m
  } else if ((m = /^(\d+(?:\.\d+)?)s$/.exec(s))) {
    hours = Number(m[1]) / 3600; // 45s
  } else if (/^\d+(?:\.\d+)?$/.test(s)) {
    hours = Number(s); // plain decimal hours
  }

  if (hours == null || !(hours > 0)) return null;
  return Math.round(hours * 100) / 100;
}

/** Render decimal hours as a compact human label: 1.5 -> "1h 30m". */
export function formatDuration(hours: number): string {
  if (!(hours > 0)) return '0h';
  const totalMin = Math.round(hours * 60);
  const h = Math.floor(totalMin / 60);
  const m = totalMin % 60;
  if (h && m) return `${h}h ${m}m`;
  if (h) return `${h}h`;
  return `${m}m`;
}

/** Render elapsed milliseconds as a running clock: 5_400_000 -> "01:30:00". */
export function formatClock(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}
