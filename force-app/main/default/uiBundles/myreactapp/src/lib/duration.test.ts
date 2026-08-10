import { describe, it, expect } from 'vitest';
import { parseDuration, formatDuration, formatClock } from './duration';

describe('parseDuration', () => {
  it('parses plain decimal hours', () => {
    expect(parseDuration('1.5')).toBe(1.5);
    expect(parseDuration('2')).toBe(2);
    expect(parseDuration('0.25')).toBe(0.25);
  });

  it('parses clock form h:mm', () => {
    expect(parseDuration('1:30')).toBe(1.5);
    expect(parseDuration('0:15')).toBe(0.25);
    expect(parseDuration('2:00')).toBe(2);
    expect(parseDuration('1:30:00')).toBe(1.5);
  });

  it('parses h/m/s unit forms', () => {
    expect(parseDuration('90m')).toBe(1.5);
    expect(parseDuration('30m')).toBe(0.5);
    expect(parseDuration('1h')).toBe(1);
    expect(parseDuration('1.5h')).toBe(1.5);
    expect(parseDuration('45s')).toBe(0.01); // 0.0125 rounded to 2dp
  });

  it('parses combined 1h30 / 1h 30m / 2h15m', () => {
    expect(parseDuration('1h30')).toBe(1.5);
    expect(parseDuration('1h 30m')).toBe(1.5);
    expect(parseDuration('2h15m')).toBe(2.25);
  });

  it('rejects invalid / non-positive input', () => {
    expect(parseDuration('')).toBeNull();
    expect(parseDuration('abc')).toBeNull();
    expect(parseDuration('0')).toBeNull();
    expect(parseDuration('-1')).toBeNull();
    expect(parseDuration('1:99')).toBeNull(); // minutes >= 60
    expect(parseDuration('1h75')).toBeNull();
  });
});

describe('formatDuration', () => {
  it('renders compact labels', () => {
    expect(formatDuration(1.5)).toBe('1h 30m');
    expect(formatDuration(2)).toBe('2h');
    expect(formatDuration(0.5)).toBe('30m');
    expect(formatDuration(0)).toBe('0h');
  });
});

describe('formatClock', () => {
  it('renders hh:mm:ss', () => {
    expect(formatClock(0)).toBe('00:00:00');
    expect(formatClock(5_400_000)).toBe('01:30:00');
    expect(formatClock(65_000)).toBe('00:01:05');
  });
});
