/**
 * Shared presentational primitives for the live-Salesforce read views on the
 * Clients / Projects / Invoices pages.
 *
 * These live under `src/data` (the data seam's owner) so the three live pages
 * stay DRY without duplicating the loading / error / empty scaffolding, and
 * without editing shared components another engineer may be touching. They only
 * *consume* shared read-only UI (`@/components/ui`, motion) — nothing here
 * mutates global styles or components.
 *
 * The states mirror src/pages/Salesforce.tsx: loading skeletons, a verbatim
 * error, an empty state, and a source badge. The "not connected" affordance is
 * surfaced by the pages themselves (a Connect button + "Local demo" badge in
 * the header) so standalone mode keeps its full local UX.
 */
import { AlertTriangle, Inbox, RefreshCw, Undo2, Zap, HardDrive } from 'lucide-react';
import { Reveal } from '@/components/motion';
import { Button, Skeleton } from '@/components/ui';
import { cn } from '@/lib/utils';
import type { ResourceResult } from './useResource';

/** Subtle "Live Salesforce" vs "Local demo" source indicator. */
export function LiveBadge({
  live,
  className,
}: {
  live: boolean;
  className?: string;
}) {
  if (live) {
    return (
      <span
        className={cn(
          'inline-flex w-fit shrink-0 items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium',
          'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300',
          className
        )}
      >
        <span className="relative flex size-1.5">
          <span className="absolute inline-flex size-full rounded-full bg-emerald-500 opacity-75 motion-safe:animate-ping" />
          <span className="relative inline-flex size-1.5 rounded-full bg-emerald-500" />
        </span>
        <Zap className="size-3" aria-hidden />
        Live Salesforce
      </span>
    );
  }
  return (
    <span
      className={cn(
        'inline-flex w-fit shrink-0 items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium',
        'bg-muted text-muted-foreground',
        className
      )}
    >
      <HardDrive className="size-3" aria-hidden />
      Local demo
    </span>
  );
}

/** Centered icon + message card used for the error and empty states. */
export function SfStateCard({
  icon: Icon,
  title,
  message,
  tone = 'muted',
  action,
}: {
  icon: typeof Inbox;
  title: string;
  message: string;
  tone?: 'muted' | 'danger';
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 px-6 py-14 text-center">
      <span
        className={
          tone === 'danger'
            ? 'flex size-12 items-center justify-center rounded-full bg-rose-100 text-rose-600 dark:bg-rose-500/15 dark:text-rose-300'
            : 'flex size-12 items-center justify-center rounded-full bg-muted text-muted-foreground'
        }
      >
        <Icon className="size-6" />
      </span>
      <div>
        <p className="font-medium text-foreground">{title}</p>
        <p className="mx-auto mt-1 max-w-md text-sm text-muted-foreground">
          {message}
        </p>
      </div>
      {action}
    </div>
  );
}

/** Skeleton rows shown while a live fetch is in flight. */
export function LoadingTable({ cols }: { cols: number }) {
  return (
    <div className="space-y-2 p-4">
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="flex gap-3">
          {Array.from({ length: cols }).map((_, j) => (
            <Skeleton key={j} className="h-6 flex-1" />
          ))}
        </div>
      ))}
    </div>
  );
}

/**
 * Renders the loading / error / empty scaffolding around a live table and shows
 * the table (via `children`) only when there are rows. `onExit`, when provided
 * (standalone "Connect" mode), offers a way back to the local data.
 */
export function LiveStates({
  result,
  cols,
  emptyMessage = 'Connected, but this object has no records yet. Create records in Salesforce and they will appear here.',
  onExit,
  children,
}: {
  result: ResourceResult<unknown>;
  cols: number;
  emptyMessage?: string;
  onExit?: () => void;
  children: React.ReactNode;
}) {
  const exitButton = onExit ? (
    <Button size="sm" variant="ghost" onClick={onExit}>
      <Undo2 className="size-4" /> Use local data
    </Button>
  ) : null;

  if (result.loading) return <LoadingTable cols={cols} />;

  if (result.error) {
    return (
      <SfStateCard
        icon={AlertTriangle}
        tone="danger"
        title="Couldn't load records"
        message={result.error}
        action={
          <div className="flex items-center gap-2">
            <Button size="sm" variant="outline" onClick={result.reload}>
              <RefreshCw className="size-4" /> Retry
            </Button>
            {exitButton}
          </div>
        }
      />
    );
  }

  if (result.rows.length === 0) {
    return (
      <SfStateCard
        icon={Inbox}
        title="No records yet"
        message={emptyMessage}
        action={
          <div className="flex items-center gap-2">
            <Button size="sm" variant="outline" onClick={result.reload}>
              <RefreshCw className="size-4" /> Refresh
            </Button>
            {exitButton}
          </div>
        }
      />
    );
  }

  return <Reveal className="overflow-x-auto">{children}</Reveal>;
}
