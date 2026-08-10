import type { LucideIcon } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import { AnimatedNumber } from '@/components/motion';

/**
 * A KPI tile: label, large value, an icon chip, and an optional hint line.
 * Used on the dashboard and at the top of list pages.
 */
export function StatCard({
  label,
  value,
  hint,
  icon: Icon,
  accent = 'text-foreground',
  iconClassName = 'bg-muted text-foreground',
  numericValue,
  format,
}: {
  label: string;
  value: string;
  hint?: string;
  icon?: LucideIcon;
  accent?: string;
  iconClassName?: string;
  /** When set, the value counts up on mount using `format` to render it. */
  numericValue?: number;
  format?: (v: number) => string;
}) {
  return (
    <Card className="gap-0 py-4">
      <CardContent className="px-4">
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0">
            <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">
              {label}
            </p>
            <p className={cn('mt-1.5 text-2xl font-semibold truncate', accent)}>
              {numericValue != null ? (
                <AnimatedNumber
                  value={numericValue}
                  format={format ?? (v => String(Math.round(v)))}
                />
              ) : (
                value
              )}
            </p>
            {hint && (
              <p className="mt-1 text-xs text-muted-foreground">{hint}</p>
            )}
          </div>
          {Icon && (
            <span
              className={cn(
                'flex size-9 shrink-0 items-center justify-center rounded-lg',
                iconClassName
              )}
            >
              <Icon className="size-4.5" />
            </span>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
