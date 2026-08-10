/**
 * Lightweight, dependency-free motion primitives for a modern, professional
 * feel. All animation is CSS-driven (see keyframes in styles/global.css) and
 * respects `prefers-reduced-motion` via the `motion-safe:` Tailwind variant.
 */
import {
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from 'react';
import { cn } from '@/lib/utils';

/**
 * Fades + slides its children in once, shortly after mount. `delay` (ms)
 * staggers multiple Reveals; `as` swaps the wrapper element.
 */
export function Reveal({
  children,
  delay = 0,
  className,
  as: Tag = 'div',
}: {
  children: ReactNode;
  delay?: number;
  className?: string;
  as?: 'div' | 'section' | 'li' | 'span';
}) {
  const [shown, setShown] = useState(false);
  useEffect(() => {
    const t = setTimeout(() => setShown(true), delay);
    return () => clearTimeout(t);
  }, [delay]);
  return (
    <Tag
      data-shown={shown}
      className={cn(
        'motion-safe:transition-all motion-safe:duration-500 motion-safe:ease-out',
        shown
          ? 'opacity-100 translate-y-0'
          : 'motion-safe:opacity-0 motion-safe:translate-y-2',
        className
      )}
    >
      {children}
    </Tag>
  );
}

/**
 * Reveals each direct child in sequence. Wrap items in <Stagger> and they fade
 * up one after another using an incrementing delay.
 */
export function Stagger({
  children,
  step = 60,
  className,
}: {
  children: ReactNode[];
  step?: number;
  className?: string;
}) {
  return (
    <div className={className}>
      {children.map((child, i) => (
        <Reveal key={i} delay={i * step}>
          {child}
        </Reveal>
      ))}
    </div>
  );
}

/**
 * Counts up to `value` on mount / when the value changes. Great for KPI tiles.
 * `format` renders the current number (e.g. currency).
 */
export function AnimatedNumber({
  value,
  duration = 700,
  format = v => String(Math.round(v)),
  className,
}: {
  value: number;
  duration?: number;
  format?: (v: number) => string;
  className?: string;
}) {
  const [display, setDisplay] = useState(0);
  const fromRef = useRef(0);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    const prefersReduced =
      typeof window !== 'undefined' &&
      window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    if (prefersReduced) {
      // Jump to the value without animating, deferred out of the effect body.
      rafRef.current = requestAnimationFrame(() => {
        setDisplay(value);
        fromRef.current = value;
      });
      return () => {
        if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
      };
    }
    const from = fromRef.current;
    const start = performance.now();
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / duration);
      // easeOutCubic
      const eased = 1 - Math.pow(1 - t, 3);
      const current = from + (value - from) * eased;
      setDisplay(current);
      if (t < 1) {
        rafRef.current = requestAnimationFrame(tick);
      } else {
        fromRef.current = value;
      }
    };
    rafRef.current = requestAnimationFrame(tick);
    return () => {
      if (rafRef.current != null) cancelAnimationFrame(rafRef.current);
      fromRef.current = value;
    };
  }, [value, duration]);

  return (
    <span className={cn('tabular-nums', className)}>{format(display)}</span>
  );
}

/** A subtle animated gradient/shimmer used behind hero areas and loaders. */
export function Shimmer({
  className,
  style,
}: {
  className?: string;
  style?: CSSProperties;
}) {
  return (
    <span
      aria-hidden
      style={style}
      className={cn(
        'block bg-[linear-gradient(110deg,transparent_20%,var(--color-muted)_40%,transparent_60%)] bg-[length:200%_100%] motion-safe:animate-[fops-shimmer_1.4s_ease-in-out_infinite]',
        className
      )}
    />
  );
}
