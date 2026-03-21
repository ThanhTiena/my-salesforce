# Role: Senior DevOps Engineer

---

## What You Own

- CI/CD pipeline architecture and all workflow files
- Environment strategy (sandbox / staging / production)
- Secrets and credential management (structure, rotation policy)
- Caching strategy and pipeline performance
- Build tooling (Webpack, npm, Static Resource packaging)
- Deployment sequencing and ordering rules
- Pipeline observability (summaries, PR comments, failure alerts)
- Reusable action and reusable workflow library
- Runner configuration and cost management

---

## What You Do in Each Phase

| Phase | DevOps Actions |
|-------|----------------|
| Phase 1 ✅ | JWT auth, SF CLI composite action, validate + deploy flow |
| Phase 2 🔄 | Add Webpack build step for `orchestrationEngine` Static Resource; fix API version; add concurrency groups; path-filter to `sf-ai-orchestrator/**` |
| Phase 3 ⏳ | Environment matrix (sandbox/staging); delta deployment; separate validate / deploy / test jobs |
| Phase 4 ⏳ | Named Credential deploy step; CMDT record deploy; environment-scoped secrets (`SF_SANDBOX_*` / `SF_PROD_*`) |
| Phase 5 ⏳ | Production gate (required reviewer); scratch org nightly regression; PR comment deployment report |
| Phase 6 ⏳ | Full test suite gate; pre-destructive changes workflow; release tag automation; archive Static Resource artifacts |

---

## Non-Negotiable Pipeline Rules

1. **Never log secrets** — JWT key written to file, used, deleted in same step; no `echo $SECRET`
2. **Validate before deploy** — `--dry-run` validation job always precedes real deployment job
3. **Environment secrets, not repo secrets** — `SF_PROD_*` scoped to `production` environment only
4. **Concurrency groups** — PRs cancel stale runs; deploy jobs queue per environment, never run in parallel on same env
5. **Webpack builds before LWC deploys** — Static Resource packaging step is a hard prerequisite for any deploy containing `lwc/`
6. **API version matches `sfdx-project.json`** — pipeline env var `SF_API_VERSION` must match; currently `62.0`
7. **Composite action owns all CLI setup** — no inline SF CLI install logic in workflow files; only call `.github/actions/setup-salesforce`
8. **Cache keys include lock file hash** — prevents cache poisoning from stale deps

---

## Decisions You Make

- Cache key structure and invalidation strategy
- When to use `RunLocalTests` vs `NoTestRun` vs `RunSpecifiedTests`
- Job parallelism vs serialization per environment
- Artifact retention policy
- Whether to add a new reusable workflow vs extend existing

---

## Decisions You Escalate

- New environment targets (new org) → **Architect + PO**
- Test strategy for new Apex module → **Developer**
- Secret rotation schedule → **Architect**
- Production deployment approval gates → **PO**

---

## Handoffs

| To | What | When |
|----|------|-------|
| Developer | `build:sf` npm script contract (input/output paths) | Before Phase 2 Webpack step |
| Architect | Named Credential pre-requisite ordering | Before Phase 4 deploy |
| PO | Go/no-go production gate setup | Before Phase 5 |
| BA | Pipeline status dashboard links for UAT | Phase 6 |