import type { Invoice, InvoiceStatus } from './types';

/** Format a number as currency in the given ISO currency code. */
export function formatCurrency(value: number, currency = 'USD'): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    maximumFractionDigits: value % 1 === 0 ? 0 : 2,
  }).format(value);
}

/** Format an ISO date/day string as e.g. "Aug 9, 2026". Empty input -> "—". */
export function formatDate(iso?: string): string {
  if (!iso) return '—';
  const d = new Date(iso.length <= 10 ? `${iso}T00:00:00` : iso);
  if (Number.isNaN(d.getTime())) return '—';
  return d.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
}

/** Sum an invoice's line items. */
export function invoiceTotal(invoice: Invoice): number {
  return invoice.lineItems.reduce(
    (sum, li) => sum + li.quantity * li.unitPrice,
    0
  );
}

/**
 * Resolve an invoice's *effective* status. A "sent" invoice whose due date has
 * passed is treated as overdue without mutating the stored record.
 */
export function effectiveInvoiceStatus(invoice: Invoice): InvoiceStatus {
  if (invoice.status === 'sent') {
    const due = new Date(`${invoice.dueDate}T23:59:59`);
    if (!Number.isNaN(due.getTime()) && due.getTime() < Date.now()) {
      return 'overdue';
    }
  }
  return invoice.status;
}

/** The `YYYY-MM` month key for an ISO date string. */
export function monthKey(iso: string): string {
  return iso.slice(0, 7);
}

/** Today's date as YYYY-MM-DD, using the viewer's LOCAL calendar day.
 *  (toISOString() would use UTC and roll a day early/late off-timezone.) */
export function todayISO(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate()
  ).padStart(2, '0')}`;
}
