import { cn } from '@/lib/utils';

/**
 * A small, self-contained colored status pill used across FreelanceHub.
 * Colors are literal Tailwind classes (with dark-mode variants) so the pill
 * reads the same regardless of the shadcn theme tokens in play.
 */
const STATUS_STYLES: Record<string, string> = {
  // Client
  active:
    'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300',
  lead: 'bg-sky-100 text-sky-700 dark:bg-sky-500/15 dark:text-sky-300',
  archived:
    'bg-gray-100 text-gray-600 dark:bg-white/10 dark:text-gray-300',
  // Project
  planning:
    'bg-violet-100 text-violet-700 dark:bg-violet-500/15 dark:text-violet-300',
  'on-hold':
    'bg-amber-100 text-amber-700 dark:bg-amber-500/15 dark:text-amber-300',
  completed:
    'bg-teal-100 text-teal-700 dark:bg-teal-500/15 dark:text-teal-300',
  cancelled:
    'bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-300',
  // Invoice
  draft: 'bg-gray-100 text-gray-600 dark:bg-white/10 dark:text-gray-300',
  sent: 'bg-sky-100 text-sky-700 dark:bg-sky-500/15 dark:text-sky-300',
  paid: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300',
  overdue: 'bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-300',
};

const LABELS: Record<string, string> = {
  'on-hold': 'On Hold',
};

function labelize(status: string): string {
  if (LABELS[status]) return LABELS[status];
  return status.charAt(0).toUpperCase() + status.slice(1);
}

export function StatusBadge({
  status,
  className,
}: {
  status: string;
  className?: string;
}) {
  return (
    <span
      className={cn(
        'inline-flex w-fit shrink-0 items-center gap-1 rounded-full px-2 py-0.5 text-xs font-medium capitalize',
        STATUS_STYLES[status] ??
          'bg-gray-100 text-gray-600 dark:bg-white/10 dark:text-gray-300',
        className
      )}
    >
      {labelize(status)}
    </span>
  );
}
