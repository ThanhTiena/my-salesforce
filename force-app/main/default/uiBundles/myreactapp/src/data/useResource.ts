/**
 * useResource — the render-time data seam every live page uses.
 *
 * One hook, two paths, picked by `isSalesforceEnv()` at RENDER time (never at
 * module load, so it can't run before the platform injects `SFDC_ENV`):
 *
 *   - Inside Salesforce → run the async `salesforce` fetcher and expose its
 *     loading / error / rows (backed by `useAsyncData`), plus `reload()`.
 *   - Standalone (vite dev, tests, static preview) → return the `local` data
 *     synchronously with `loading: false`, so the app renders without an org.
 *
 * `enabled` overrides detection — pass `detected || forced` to let a standalone
 * page offer a "Connect" button that attempts the live query and surfaces any
 * error (mirrors src/pages/Salesforce.tsx). Hooks are always called in the same
 * order regardless of the branch, so this is safe under the Rules of Hooks.
 *
 * Pages whose local UX is richer than the read view (the CRUD pages) simply
 * omit `local` and render their own local branch when `kind === 'local'`;
 * `useResource` still cleanly owns the Salesforce read path for them.
 */
import { useMemo, useState } from 'react';
import { useAsyncData } from '@/hooks/useAsyncData';
import { isSalesforceEnv } from './salesforce';
import type { DataSourceKind } from './DataSource';

export interface ResourceResult<T> {
  /** The rows to render: live SF rows when live, else the local rows. */
  rows: T[];
  /** True only while a live Salesforce fetch is in flight. */
  loading: boolean;
  /** The verbatim error message from a failed live fetch, else null. */
  error: string | null;
  /** Which source produced `rows`, for a "Live Salesforce" vs "Local demo" badge. */
  kind: DataSourceKind;
  /** Convenience: `kind === 'salesforce'`. */
  live: boolean;
  /** Re-run the live fetch (no-op impact in local mode). */
  reload: () => void;
}

export function useResource<T>({
  salesforce,
  local,
  enabled,
}: {
  /** Async loader used when running live in Salesforce. */
  salesforce: () => Promise<T[]>;
  /** Synchronous local fallback. Defaults to an empty list. */
  local?: () => T[];
  /** Force the live path on/off; defaults to `isSalesforceEnv()`. */
  enabled?: boolean;
}): ResourceResult<T> {
  const detected = useMemo(() => isSalesforceEnv(), []);
  const live = enabled ?? detected;

  const [gen, setGen] = useState(0);
  // Always call the hook; gate the actual fetch on `live` so standalone mode
  // never hits the network and resolves instantly.
  const { data, loading, error } = useAsyncData<T[]>(
    () => (live ? salesforce() : Promise.resolve<T[]>([])),
    [live, gen]
  );

  const reload = () => setGen(g => g + 1);

  if (live) {
    return {
      rows: data ?? [],
      loading,
      error,
      kind: 'salesforce',
      live: true,
      reload,
    };
  }

  return {
    rows: local ? local() : [],
    loading: false,
    error: null,
    kind: 'local',
    live: false,
    reload,
  };
}
