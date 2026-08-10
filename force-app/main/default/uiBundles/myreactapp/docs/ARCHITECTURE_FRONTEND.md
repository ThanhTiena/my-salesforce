# FreelanceHub — Frontend Architecture (High-Performance React)

**Status:** Blueprint / design intent (not yet implemented)
**Owner:** Fullstack Developer
**Peer doc:** Salesforce Solution Architect owns the GraphQL data model, object/field API names, and the query/mutation _contracts_. This doc consumes those contracts; it does **not** redesign them.
**Stack (as-is):** React 19, react-router 7, Vite 7, TypeScript (strict), Tailwind v4, shadcn/ui, `@salesforce/platform-sdk` GraphQL (uiapi). Build: `tsc -b && vite build`. Bundle ≈ 200 KB gzip and growing.
**Hard constraint:** **No CDNs.** The UI Bundle must be fully self-contained, so every dependency is bundled and counts against our size budget. This shapes every "add a library?" decision below.

---

## 0. Design principles

1. **Server state ≠ UI state.** Salesforce/local records live in a cache keyed by query; component state (dialog open, filter text) stays local. No global store for server data. (See §5.)
2. **One data seam.** The app never imports `executeGraphQL` or `localStorage` from a page. It talks to a `DataSource` interface; the environment picks the implementation. (See §3.)
3. **Every KB is bought, not free.** Because we can't lazy-load from a CDN, we lazy-load from our _own_ chunks (route splitting) and we prefer ~1–2 KB in-house utilities over 10 KB+ libraries unless the library earns its weight. (See §2, §4, §7.)
4. **Low-churn migration.** We evolve the current `src/pages` app in place. No big-bang rewrite; each phase leaves `tsc -b && vite build` green. (See §8.)

---

## 1. Target folder structure (feature-first)

Today everything is grouped by _technical type_ (`pages/`, `components/`, `hooks/`, `data/`). That scales poorly: a change to "Invoices" touches five directories. We move to **feature-first** — each domain owns its routes, components, hooks, and API mapping — while keeping genuinely shared things (design-system UI, the data-fetching core, the data source) central.

```
src/
├── app/                          # composition root — wiring only, no domain logic
│   ├── main.tsx                  # (today: app.tsx) createRoot + providers
│   ├── providers.tsx             # <DataSourceProvider><QueryProvider><StoreProvider>…
│   ├── router.tsx                # createBrowserRouter(routes, { basename })
│   ├── routes.tsx                # route table — lazy() element per feature
│   └── AppLayout.tsx             # (today: appLayout.tsx) sidebar/shell + <Outlet/>
│
├── features/
│   ├── dashboard/
│   │   ├── routes/DashboardPage.tsx
│   │   ├── components/…          # KPI tiles, charts specific to dashboard
│   │   └── hooks/useDashboardMetrics.ts
│   ├── clients/
│   │   ├── api/
│   │   │   ├── clients.queries.ts     # gql operation strings (Account…)
│   │   │   ├── clients.mappers.ts     # uiapi { value } → SfAccount view models
│   │   │   ├── clients.keys.ts        # query-key factory (see §2)
│   │   │   └── useClients.ts          # useQuery/useMutation wrappers for this domain
│   │   ├── components/ClientTable.tsx, ClientDialog.tsx …
│   │   └── routes/ClientsPage.tsx
│   ├── projects/   { api, components, routes }
│   ├── invoices/   { api, components, routes }
│   ├── time/       { api, components, routes }        # TimeTracking
│   └── salesforce/ routes/SalesforcePage.tsx          # the live-data explorer
│
├── data/
│   ├── DataSource.ts             # the interface (§3) — the app's only data contract
│   ├── salesforce/               # KEEP as-is, becomes one DataSource impl
│   │   ├── client.ts             #   executeGraphQL + isSalesforceEnv (unchanged)
│   │   ├── queries.ts            #   thin re-exports of feature queries, or shared ops
│   │   ├── mappers.ts            #   shared uiapi helpers (val, nodes, pageInfo)
│   │   └── salesforceDataSource.ts
│   └── local/                    # standalone-mode impl
│       ├── store.tsx             # (today: lib/store.tsx) localStorage workspace
│       ├── seed.ts
│       └── localDataSource.ts    # adapts the store to the DataSource interface
│
├── lib/
│   ├── query/                    # the data-fetching CORE (framework-agnostic)
│   │   ├── cache.ts              # tiny SWR cache: TTL + dedup + subscribe (§2)
│   │   ├── useQuery.ts           # read hook (§2)
│   │   ├── useMutation.ts        # write hook + optimistic/rollback (§2)
│   │   └── QueryProvider.tsx     # holds one cache instance in context
│   ├── perf/
│   │   ├── reportWebVitals.ts    # onLCP/onINP/onCLS wiring (§7)
│   │   └── useDeferredFilter.ts  # shared search/filter helper (§4)
│   ├── format.ts, utils.ts       # KEEP
│   └── types.ts                  # KEEP (domain model)
│
├── components/
│   ├── ui/                       # shadcn/ui primitives — KEEP untouched
│   ├── common/                   # PageHeader, StatCard, StatusBadge, DataState…
│   ├── motion/                   # Reveal, Stagger, AnimatedNumber — KEEP
│   └── table/VirtualTable.tsx    # virtualization wrapper (§4)
│
├── styles/global.css             # KEEP
└── api/
    ├── graphqlClient.ts          # KEEP (executeGraphQL) — re-homed conceptually under data/
    └── graphql-operations-types.ts   # generated by codegen (§6) — do not edit
```

**Migration mapping (what moves, what stays) — deliberately low-churn:**

| Today | Target | Action |
|---|---|---|
| `src/pages/*.tsx` | `src/features/<domain>/routes/*Page.tsx` | **Move** (git mv), one per phase |
| `src/appLayout.tsx`, `app.tsx`, `routes.tsx`, `router-utils.tsx` | `src/app/*` | **Move** |
| `src/data/salesforce/*` | same path | **Keep**; add `salesforceDataSource.ts` + extract `mappers.ts` from `repository.ts` |
| `src/lib/store.tsx`, `seed.ts` | `src/data/local/*` | **Move**; add `localDataSource.ts` |
| `src/hooks/useAsyncData.ts` | — | **Keep during migration**, deprecate once `useQuery` lands (§8) |
| `src/components/{ui,motion}` | same | **Keep** |
| `src/components/{page-header,stat-card,status-badge}.tsx` | `src/components/common/` | **Move** (flat → folder) |
| `src/api/graphqlClient.ts` | same | **Keep** |

Path aliases already exist (`@`, `@api`, `@components`, …) — add `@features`, `@data`, `@lib` in both `vite.config.ts` `resolve.alias` and `tsconfig.json` `paths` so imports read `@features/invoices/api/useInvoices`. (Note: `@utils` currently points at `src/utils` but code uses `@/lib`; fix the alias to `src/lib` during Phase 0 to remove the dead mapping.)

---

## 2. Data-fetching & caching layer

### Recommendation: a ~1–2 KB in-house SWR cache, **not** TanStack Query — for now

| | Custom cache (recommended) | TanStack Query v5 |
|---|---|---|
| Gzipped cost | **~1–2 KB** (we write it) | **~13.6 KB** ([bundle measurements](https://www.pkgpulse.com/guides/tanstack-query-vs-swr-2026)) |
| Fit for uiapi | Perfect — wraps our existing `executeGraphQL` | Needs a `queryFn` wrapper anyway |
| Features we need | dedup, SWR, keys, optimistic, pagination — all small to build | All built-in + devtools, retries, infinite queries |
| When it wins | ≤ ~15 query types, tight bundle budget | Many queries, complex invalidation graphs, a team that already knows it |

**Why custom wins here:** the app has ~5 read shapes today, a `no-CDN` bundle budget under active pressure, and an `executeGraphQL` wrapper that already centralizes transport + error handling. TanStack Query's 13.6 KB would be ~7% of our current gzip budget to replace a cache we can express in a couple hundred lines. A custom hook is the right call for "small projects with basic-to-moderate fetching," and the accepted upgrade trigger is when caching/retry/invalidation complexity outgrows hand-rolled code ([Custom hooks vs TanStack Query](https://medium.com/@tanveer.singh926/custom-react-hooks-vs-tanstack-query-for-fetching-073954af54f4), [Refine 2025 comparison](https://refine.dev/blog/react-query-vs-tanstack-query-vs-swr-2025/)).

**We keep the escape hatch open:** `useQuery`/`useMutation` mirror TanStack's API surface (`queryKey`, `queryFn`, `onMutate/onError/onSettled`). If the app grows past ~15 queries or needs devtools/retry policies, we swap the implementation behind the same hook signatures with near-zero page churn.

The cache implements the classic **stale-while-revalidate** contract: return cached data instantly (stale), fire the request (revalidate), then swap in fresh data — never blocking the UI ([SWR / RFC 5861](https://github.com/vercel/swr), [Toptal SWR hooks guide](https://www.toptal.com/react-hooks/stale-while-revalidate)).

### Query keys

A serializable key identifies a cache entry and drives dedup + invalidation. Use a per-feature factory (the pattern TanStack popularized) so keys are typo-proof and hierarchical:

```ts
// features/invoices/api/invoices.keys.ts
export const invoiceKeys = {
  all:   ['invoices'] as const,
  list:  (f: InvoiceFilter) => ['invoices', 'list', f] as const,
  page:  (cursor: string | null) => ['invoices', 'list', { cursor }] as const,
  detail:(id: string) => ['invoices', 'detail', id] as const,
};
// The cache stringifies the key (stable JSON) into its Map id.
```

### The core cache (sketch)

```ts
// lib/query/cache.ts
type Entry<T> = {
  data?: T; error?: Error;
  status: 'idle' | 'loading' | 'success' | 'error';
  updatedAt: number;
  promise?: Promise<T>;          // in-flight — single-flight dedup
  listeners: Set<() => void>;
};

export class QueryCache {
  private map = new Map<string, Entry<unknown>>();

  // stale-while-revalidate + request dedup in one method
  fetch<T>(key: string, fn: () => Promise<T>, staleMs = 30_000): Entry<T> {
    const e = (this.map.get(key) as Entry<T>) ?? this.init<T>(key);
    const fresh = Date.now() - e.updatedAt < staleMs;
    if (e.promise) return e;                    // dedup: reuse in-flight
    if (e.status === 'success' && fresh) return e; // fresh cache hit, no refetch
    e.status = e.data ? 'success' : 'loading';  // keep showing stale data
    e.promise = fn().then(
      d => { e.data = d; e.status = 'success'; e.updatedAt = Date.now(); e.promise = undefined; this.emit(key); return d; },
      err => { e.error = err; e.status = 'error'; e.promise = undefined; this.emit(key); throw err; },
    );
    this.emit(key);
    return e;
  }
  getEntry<T>(key: string) { return this.map.get(key) as Entry<T> | undefined; }
  setData<T>(key: string, updater: (prev?: T) => T) { /* optimistic writes */ }
  invalidate(prefix: string) { /* mark matching keys stale, re-emit */ }
  subscribe(key: string, cb: () => void) { /* add to listeners, return unsub */ }
  private emit(key: string) { this.map.get(key)?.listeners.forEach(l => l()); }
}
```

Components subscribe via `useSyncExternalStore`, so a cache write re-renders exactly the components reading that key — no context-wide re-render.

### Hook contracts (the public API pages use)

```ts
// lib/query/useQuery.ts
interface QueryOptions<T> {
  queryKey: readonly unknown[];
  queryFn: () => Promise<T>;
  enabled?: boolean;      // gate on env / prerequisites (replaces the IN_SF ? … : [] dance)
  staleMs?: number;       // default 30s
}
interface QueryResult<T> {
  data: T | undefined;
  error: Error | undefined;
  isLoading: boolean;     // no data yet
  isFetching: boolean;    // revalidating with stale data shown
  refetch: () => void;
}
export function useQuery<T>(opts: QueryOptions<T>): QueryResult<T>;

// lib/query/useMutation.ts
interface MutationOptions<TVars, TData, TCtx> {
  mutationFn: (vars: TVars) => Promise<TData>;
  onMutate?: (vars: TVars) => TCtx | Promise<TCtx>;      // snapshot + optimistic write
  onError?: (err: Error, vars: TVars, ctx?: TCtx) => void; // rollback using ctx
  onSettled?: (data: TData | undefined, err: Error | undefined, vars: TVars) => void; // invalidate
}
interface MutationResult<TVars, TData> {
  mutate: (vars: TVars) => Promise<TData>;
  isPending: boolean;
  error: Error | undefined;
}
export function useMutation<TVars, TData, TCtx>(o: MutationOptions<TVars, TData, TCtx>): MutationResult<TVars, TData>;
```

### Pagination (cursor/edges from uiapi)

Salesforce uiapi is Relay-style: request `first` + `after`, read `pageInfo { hasNextPage endCursor }`, and feed `endCursor` back as `after` for the next page. Backward pagination (`last`/`before`) is **not supported** ([Salesforce: Paginate with Record Connections](https://developer.salesforce.com/docs/platform/graphql/guide/paginate-use.html)).

```graphql
query FopsInvoices($first: Int = 50, $after: String) {
  uiapi { query { Order(first: $first, after: $after, orderBy: { EffectiveDate: { order: DESC } }) {
    edges { cursor node { Id OrderNumber @optional { value } … } }
    pageInfo { hasNextPage endCursor }
  } } }
}
```

`useInfiniteQuery` (thin wrapper over the cache) accumulates pages keyed by `endCursor` and exposes `fetchNextPage()` + `hasNextPage`. **Add `pageInfo`/`cursor` to the mapper contract with the Solution Architect** — today's queries omit them.

### Optimistic mutations + rollback

Standard snapshot → optimistic write → rollback-on-error → invalidate-on-settle, exactly the TanStack pattern but on our cache ([TanStack optimistic-updates guide](https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates)):

```ts
// features/clients/api/useClients.ts
const updateHealth = useMutation({
  mutationFn: ({ id, health }) => dataSource.updateClientHealth(id, health),
  onMutate: ({ id, health }) => {
    const key = JSON.stringify(clientKeys.all);
    const prev = cache.getEntry<SfAccount[]>(key)?.data;              // 1. snapshot
    cache.setData<SfAccount[]>(key, rows => rows?.map(r => r.id === id ? { ...r, health } : r) ?? []); // 2. optimistic
    return { prev, key };                                             // context → onError
  },
  onError: (_e, _vars, ctx) => ctx && cache.setData(ctx.key, () => ctx.prev), // 3. rollback
  onSettled: () => cache.invalidate('["clients"'),                    // 4. resync
});
```

---

## 3. Data-source abstraction

One interface; two implementations; auto-selected by `isSalesforceEnv()`. This is what lets the app run in `vite dev`/tests (localStorage) **and** live in an org (uiapi) with identical page code. It also removes the `IN_SF ? fetchX() : Promise.resolve([])` conditionals now scattered through `Salesforce.tsx`.

```ts
// data/DataSource.ts
export interface Page<T> { items: T[]; nextCursor: string | null; hasNextPage: boolean; }

export interface DataSource {
  // Reads return already-mapped view models (SfAccount, SfInvoice, …) — uiapi shape never leaks up.
  listClients(opts?: { first?: number; after?: string | null }): Promise<Page<SfAccount>>;
  listProjects(opts?: { first?: number; after?: string | null }): Promise<Page<SfAssignment>>;
  listInvoices(opts?: { first?: number; after?: string | null }): Promise<Page<SfInvoice>>;
  listTimeEntries(opts?: { first?: number; after?: string | null }): Promise<Page<SfTimeEntry>>;
  // Writes
  updateClientHealth(id: string, health: string): Promise<void>;
  // …CRUD per the Solution Architect's mutation contracts…
  readonly kind: 'salesforce' | 'local';
}
```

```ts
// data/salesforce/salesforceDataSource.ts   → wraps existing repository.ts + executeGraphQL
export const salesforceDataSource: DataSource = {
  kind: 'salesforce',
  listInvoices: (o) => fetchInvoicesPage(o?.first, o?.after),   // adds pageInfo to today's fetchInvoices
  updateClientHealth: (id, h) => updateAccountHealth(id, h),
  /* … */
};

// data/local/localDataSource.ts   → adapts the localStorage workspace, paginates in-memory
export function createLocalDataSource(store: WorkspaceStore): DataSource { /* … */ }
```

```tsx
// app/providers.tsx — auto-select once, provide via context
const dataSource = isSalesforceEnv() ? salesforceDataSource : createLocalDataSource(store);
export const DataSourceContext = createContext<DataSource>(dataSource);
export const useDataSource = () => useContext(DataSourceContext);
```

Pages call `useDataSource()` inside their feature hooks; they never branch on environment. Standalone mode "just works," and Vitest can inject a fake `DataSource` for deterministic tests.

---

## 4. Rendering performance

### 4.1 Route-level code splitting (biggest single win)

Today `routes.tsx` **eagerly imports all six pages** — every page's code (tables, dialogs, charts) is in the initial bundle. Convert each route element to `React.lazy` behind a `<Suspense>` boundary in `AppLayout`. Each page becomes its own chunk fetched on navigation.

```tsx
// app/routes.tsx
const ClientsPage = lazy(() => import('@features/clients/routes/ClientsPage'));
// … element: <ClientsPage /> wrapped by AppLayout's <Suspense fallback={<PageSkeleton/>}>
```

```tsx
// app/AppLayout.tsx — one boundary around the outlet
<main className="md:pl-60">
  <Suspense fallback={<PageSkeleton />}>
    <Outlet />
  </Suspense>
</main>
```

Route splitting is the canonical Vite pattern — dynamic `import()` makes Rollup emit a separate chunk automatically ([Vite build guide](https://v3.vitejs.dev/guide/build)). Expect the initial JS to drop meaningfully as Invoices/Time (the heaviest pages) leave the entry chunk.

### 4.2 Vite `manualChunks` — split vendor & platform SDK

Currently there's no `build.rollupOptions.manualChunks`, so vendor code rides in whatever chunk imports it first. Carve out long-lived, rarely-changing vendors so they cache across app deploys, and isolate the heavyweight Salesforce SDK ([Vite/Rollup manualChunks](https://blog.kowalczyk.info/til-vite-rollup-manualchunks.html), [Vite code-splitting that works](https://sambitsahoo.com/blog/vite-code-splitting-that-works.html)):

```ts
// vite.config.ts → build.rollupOptions.output.manualChunks
manualChunks(id) {
  if (!id.includes('node_modules')) return;
  if (id.includes('react') || id.includes('react-dom') || id.includes('react-router'))
    return 'vendor-react';                     // boot deps — one stable chunk
  if (id.includes('@salesforce')) return 'platform-sdk'; // heavy, org-only
  if (id.includes('radix-ui') || id.includes('lucide-react')) return 'vendor-ui';
  if (id.includes('date-fns')) return 'vendor-date';
  return 'vendor';
}
```

Guidance: group **boot dependencies** (React, router) into one chunk and split heavyweight libs individually so they're fetched only when needed ([Vite discussion #17730](https://github.com/vitejs/vite/discussions/17730)). Keep chunk count sane — over-splitting adds request overhead. Verify with `vite build` output and a bundle visualizer in CI (§7).

### 4.3 Table virtualization

Current tables render **every** row (`rows.map`). Fine for 50; janky at 1k+ time entries/invoices. Add a `VirtualTable` that renders only visible rows. Both **TanStack Virtual** and **react-window** handle 1M cells with low memory; TanStack is more responsive on rapid scroll and better for dynamic/variable rows, react-window is the smaller, stable pick for fixed-height grids ([Virtualization showdown](https://mashuktamim.medium.com/react-virtualization-showdown-tanstack-virtualizer-vs-react-window-for-sticky-table-grids-69b738b36a83), [PkgPulse 2026](https://www.pkgpulse.com/guides/tanstack-virtual-vs-react-window-vs-react-virtuoso-2026)).

**Recommendation:** `@tanstack/react-virtual` (headless, ~a few KB, no DOM opinions so it composes with our shadcn `<Table>`). Apply it **only** to lists that can exceed ~100 rows (Invoices, Time, Salesforce explorer); leave small tables plain. Gate behind a threshold: `rows.length > 100 ? <VirtualTable/> : <PlainTable/>` so the common case pays nothing.

### 4.4 Search/filter with `useDeferredValue` + memo

Filtering keeps the input responsive while the (potentially large) filtered list renders at lower priority. React 19's scheduler defers the heavy render until the browser is idle — smarter than a fixed debounce. **Critical:** the deferred value only helps if the consuming list is memoized (`React.memo` + `useMemo`), otherwise React re-renders everything synchronously anyway ([useDeferredValue best practices](https://medium.com/@ignatovich.dm/understanding-usedeferredvalue-in-react-enhancing-performance-with-deferred-rendering-ec8eb28aa997), [React 19 transitions guide](https://stacknotice.com/blog/react-19-transitions-guide-2026)).

```tsx
const [query, setQuery] = useState('');
const deferred = useDeferredValue(query);                 // input stays snappy
const rows = useMemo(() => filter(all, deferred), [all, deferred]); // memoized compute
const isStale = query !== deferred;                        // dim list while catching up
// <MemoTable rows={rows} className={isStale ? 'opacity-70 transition-opacity' : ''} />
```

Use `useTransition` for the coarser case — tab switches / route-level view swaps that update multiple components at once; use `useDeferredValue` for the single filtered value.

### 4.5 Skeletons & data states

Consolidate the `loading / error / empty / not-connected` ladder (currently re-implemented inside `Salesforce.tsx`) into one `<DataState>` in `components/common`, driven by the `useQuery` result flags. Suspense fallbacks (§4.1) reuse the same skeletons for perceived-instant navigation.

### 4.6 Animations without layout thrash

The motion primitives are already well-built: CSS-driven, `motion-safe:` gated, and `AnimatedNumber` bails out on `prefers-reduced-motion`. Rules to hold the line:

- **Animate only `transform` and `opacity`** (GPU-compositable, no reflow) — never `top/left/width/height`. Current `Reveal` uses `translate-y` + `opacity` ✅.
- Keep respecting `prefers-reduced-motion` everywhere (already done via `motion-safe:` and the matchMedia check in `AnimatedNumber`).
- Don't stagger long lists — `Stagger` on 500 rows creates 500 timers and delays content. Cap stagger to hero/above-the-fold counts; virtualized rows must not animate per-row.
- Watch CLS: reserve space for async content with skeletons of matching height so revealed data doesn't shift layout (§7 budget: CLS ≤ 0.1).

---

## 5. State management

**Two buckets, kept apart:**

| Kind | Examples | Home |
|---|---|---|
| **Server state** (async, cached, shared, can go stale) | clients, projects, invoices, time entries, dashboard metrics | **QueryCache** via `useQuery` (§2). Keyed, SWR, deduped. |
| **UI state** (synchronous, local, ephemeral) | dialog open, active tab, filter text, form fields, sidebar drawer | `useState`/`useReducer` in the component; `useContext` only for genuinely cross-cutting UI (theme, current business name) |

**Explicit anti-pattern to avoid:** putting server data in a global store. The current `StoreProvider` context is fine for **local standalone mode** (it _is_ the local data source), but it must not become the home for Salesforce records — that couples every consumer to one giant object and re-renders the tree on any change. Server data belongs in the cache, addressed by key, so writes notify only subscribers. This server/client split is the single most important state decision ([TanStack Query vs Redux](https://www.alexisdata.com/2025/12/30/tanstack-query-vs-redux-complete-comparison-guide-for-state-management/)).

Net: no Redux/Zustand needed. Server state → cache. UI state → local. Local-mode workspace → the `local` DataSource (which happens to be backed by the existing context store).

---

## 6. Type-safety & codegen

The pipeline **already exists** — lean on it instead of hand-typing operations:

- `npm run graphql:schema` → fetches the org schema to `schema.graphql` (repo root, five levels up).
- `codegen.yml` → generates `src/api/graphql-operations-types.ts` via `typescript-operations` (scalar map already handles uiapi's `Currency`/`Date`/`Picklist` → `number`/`string`). `onlyOperationTypes: true` keeps output lean.
- `vite-plugin-graphql-codegen` runs codegen on dev start & build **only when the schema file exists** (guarded in `vite.config.ts`), so CI without a schema still builds.

**Target usage:**

1. Keep GraphQL operation strings in `features/<domain>/api/*.queries.ts` (codegen's `documents` glob already covers `src/**/*.{graphql,ts,tsx}`).
2. Type each `executeGraphQL<TData, TVars>` call with the **generated** `…Query`/`…QueryVariables` types — kills the `any`/`Record<string, Scalar<unknown>>` casts currently in `repository.ts`.
3. **Mappers stay hand-written on purpose.** Codegen types the raw uiapi response (`{ value }` wrappers, edges/nodes); the mapper's job is to flatten that into the app's view models (`SfInvoice`, …). That boundary is deliberate: generated type at the wire, hand-written mapper to the domain, so a schema change surfaces as a compile error in exactly one file per object.

```ts
// After codegen — no more casts:
import type { FopsInvoicesQuery, FopsInvoicesQueryVariables } from '@api/graphql-operations-types';
const data = await executeGraphQL<FopsInvoicesQuery, FopsInvoicesQueryVariables>(INVOICES_QUERY, { first, after });
return mapInvoices(data);   // mapper input is now fully typed
```

**Contract with the Solution Architect:** they define/version the operation shapes (fields, filters, mutation inputs); we regenerate types and adjust mappers. We don't invent fields or redesign objects.

---

## 7. Performance budget & metrics

### Budgets (fail the build if exceeded)

| Metric | Budget | Rationale |
|---|---|---|
| Initial JS (entry + boot vendor), gzip | **≤ 150 KB** | Below today's ~200 KB; route-splitting funds it |
| Any single route chunk, gzip | **≤ 60 KB** | Keeps navigation snappy |
| `platform-sdk` chunk | isolated, lazy | Org-only weight off the standalone/initial path |
| Total transferred JS, gzip | **≤ 350 KB** | Ceiling as features grow |
| LCP | **≤ 2.5 s** | Core Web Vital "good" |
| INP | **≤ 200 ms** | Core Web Vital "good" |
| CLS | **≤ 0.1** | Core Web Vital "good" |

Thresholds per [web.dev Vitals](https://web.dev/articles/vitals). Every KB of JS delays both LCP (render) and INP (main-thread blocking), so the bundle budget and the CWV budget are the same fight ([web-vitals in React](https://dev.to/munna_thakur_2019444f0351/web-vitals-in-react-the-complete-guide-to-measuring-and-optimizing-performance-2026-5aj3)).

### How we measure

- **Field/real-user:** `web-vitals` (~2 KB) wired in `lib/perf/reportWebVitals.ts` using `onLCP/onINP/onCLS`; in-org, forward to Salesforce logging. This is one of the few deps worth its weight.
- **Lab:** `vite build` prints per-chunk gzip sizes; add `rollup-plugin-visualizer` (devDependency only, not shipped) for a treemap.
- **CI gate:** a `bundlesize`-style check on `dist/assets/*.js` gzip totals; block PRs that regress the entry budget — the recommended "block deploys that regress CWV/bundle" discipline ([performance budgets](https://reactperf.dev/)).

### Checklist (PR-level)

- [ ] New route uses `lazy()` + Suspense skeleton
- [ ] New heavy dep justified against budget; is there a lighter option / can we hand-roll < 2 KB?
- [ ] Lists that can exceed ~100 rows use `VirtualTable`
- [ ] Filter/search uses `useDeferredValue` **and** the list is memoized
- [ ] Animations touch only `transform`/`opacity`; `prefers-reduced-motion` respected
- [ ] Async regions reserve height (no CLS); skeleton matches final layout
- [ ] `executeGraphQL` calls typed with generated operation types (no `any`)
- [ ] Entry-chunk gzip still ≤ 150 KB (check CI output)

---

## 8. Migration plan (phased, build stays green)

Each phase is independently shippable and ends with `tsc -b && vite build` passing. Order maximizes ROI-per-churn.

**Phase 0 — Scaffolding (no behavior change).**
Add `@features`, `@data`, `@lib` aliases (vite + tsconfig); fix the stale `@utils` alias. Create empty `app/`, `features/*`, `lib/query/`, `lib/perf/`, `components/common/` dirs. Move `page-header/stat-card/status-badge` into `components/common` with re-export shims so existing imports keep working. **Risk: none.**

**Phase 1 — Route code-splitting + manualChunks (highest ROI).**
Convert `routes.tsx` elements to `React.lazy`, add the `<Suspense>` boundary + `PageSkeleton`, add `manualChunks`. Measure before/after entry gzip. **No file moves — pure win.** This is the change to ship first.

**Phase 2 — Query core.**
Add `lib/query/{cache,useQuery,useMutation,QueryProvider}.ts` and wrap the app in `QueryProvider`. Migrate `Salesforce.tsx` tabs from `useAsyncData` → `useQuery` (dedup + SWR + the `enabled` flag replacing the `IN_SF ? … : []` pattern). Keep `useAsyncData` until all callers move, then delete.

**Phase 3 — DataSource seam.**
Add `data/DataSource.ts`, `salesforceDataSource.ts`, `localDataSource.ts`, and `DataSourceContext`. Extract `mappers.ts` out of `repository.ts`. Point feature hooks at `useDataSource()`. Removes env branching from pages.

**Phase 4 — Feature-first moves.**
`git mv` one page at a time into `features/<domain>/routes/` and colocate its api/components/hooks. One PR per domain (dashboard → clients → projects → invoices → time → salesforce). Small, reviewable, reversible.

**Phase 5 — Codegen tightening.**
Run `npm run graphql:schema`, replace `any`/`Scalar<unknown>` casts in mappers with generated operation types. Turn on stricter mapper typing.

**Phase 6 — Virtualization + perf polish.**
Add `VirtualTable` (threshold-gated) to Invoices/Time/Salesforce; add `useDeferredValue` to filters with memoized rows; wire `web-vitals` and the CI bundle-size gate.

---

## Sources

- [React Query vs TanStack Query vs SWR — Refine, 2025](https://refine.dev/blog/react-query-vs-tanstack-query-vs-swr-2025/)
- [TanStack Query vs SWR bundle sizes — PkgPulse, 2026](https://www.pkgpulse.com/guides/tanstack-query-vs-swr-2026)
- [Custom React Hooks vs TanStack Query for Fetching](https://medium.com/@tanveer.singh926/custom-react-hooks-vs-tanstack-query-for-fetching-073954af54f4)
- [SWR (vercel/swr) — stale-while-revalidate](https://github.com/vercel/swr) · [Toptal SWR-with-hooks guide](https://www.toptal.com/react-hooks/stale-while-revalidate)
- [useDeferredValue deep dive](https://medium.com/@ignatovich.dm/understanding-usedeferredvalue-in-react-enhancing-performance-with-deferred-rendering-ec8eb28aa997) · [React 19 transitions guide, 2026](https://stacknotice.com/blog/react-19-transitions-guide-2026)
- [Vite/Rollup manualChunks](https://blog.kowalczyk.info/til-vite-rollup-manualchunks.html) · [Vite code splitting that works](https://sambitsahoo.com/blog/vite-code-splitting-that-works.html) · [Vite discussion #17730](https://github.com/vitejs/vite/discussions/17730) · [Vite build guide](https://v3.vitejs.dev/guide/build)
- [TanStack Virtual vs react-window showdown](https://mashuktamim.medium.com/react-virtualization-showdown-tanstack-virtualizer-vs-react-window-for-sticky-table-grids-69b738b36a83) · [PkgPulse virtualization 2026](https://www.pkgpulse.com/guides/tanstack-virtual-vs-react-window-vs-react-virtuoso-2026)
- [TanStack Query — Optimistic Updates](https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates)
- [Salesforce — Paginate with Record Connections](https://developer.salesforce.com/docs/platform/graphql/guide/paginate-use.html) · [Salesforce — Paginate results (LWC)](https://developer.salesforce.com/docs/platform/graphql/guide/graphql-wire-lwc-paginate.html)
- [web.dev — Web Vitals](https://web.dev/articles/vitals) · [Web Vitals in React, 2026](https://dev.to/munna_thakur_2019444f0351/web-vitals-in-react-the-complete-guide-to-measuring-and-optimizing-performance-2026-5aj3) · [React Performance Field Guide](https://reactperf.dev/)
- [TanStack Query vs Redux — server vs client state](https://www.alexisdata.com/2025/12/30/tanstack-query-vs-redux-complete-comparison-guide-for-state-management/)
