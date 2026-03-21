# Skill Gap Register — Cross-Role Risk Analysis

> Review before each phase starts. Red = block the phase if unresolved.

---

## Phase 2 — Core Designer (CURRENT)

| Gap | Role | Risk Level | Consequence | Resolution |
|-----|------|-----------|-------------|------------|
| `lwc:dom="manual"` + Drawflow canvas init | Developer | 🔴 High | Designer never renders | Spike: create minimal LWC that loads Drawflow via `loadScript` before writing full component |
| Webpack UMD bundle for Static Resource | Developer | 🔴 High | Phase 2 blocked entirely | Run `npm install drawflow && webpack` — bundle before any LWC work |
| LWC event bus design (palette→designer, props→designer) | Developer + Architect | 🟡 Medium | Component communication breaks | Use `CustomEvent` + parent property binding; architect must approve pattern |
| UX wireframes for properties panel per node type | BA | 🟡 Medium | Dev builds wrong UI | BA must deliver wireframes for all 11 node types before properties panel built |

---

## Phase 3 — Execution Engine

| Gap | Role | Risk Level | Consequence | Resolution |
|-----|------|-----------|-------------|------------|
| Queueable governor limit monitoring | Developer | 🔴 High | Instance fails mid-chain in prod | Add `Limits.getQueries() < 90` guard before each step handler |
| Platform Event schema design | Architect | 🟡 Medium | Wait/Resume handler broken | Design PE payload before Phase 3 starts |
| Decision node expression evaluator | Developer | 🟡 Medium | Decision handler incomplete | Evaluate expression string safely — no `eval()`; use Apex formula or condition map |

---

## Phase 4 — AI Integration

| Gap | Role | Risk Level | Consequence | Resolution |
|-----|------|-----------|-------------|------------|
| `HttpCalloutMock` for all 6 providers | Developer | 🟡 Medium | Test coverage fails | Write mock classes for each adapter in Phase 6 — start early |
| PII masking rule definition | BA + Architect | 🔴 High | Compliance risk — PII sent to AI | BA must define field allowlist per use case before Phase 4 builds |
| Rate limit enforcement mechanism | Architect | 🟡 Medium | Provider 429 errors spike | Platform Cache for per-provider RPM counter — architect must approve approach |
| Prompt injection sanitisation completeness | Architect + Developer | 🔴 High | Security vulnerability | `AISecurityUtil.sanitisePrompt()` must be reviewed and hardened in Phase 4 |

---

## Phase 6 — Hardening

| Gap | Role | Risk Level | Consequence | Resolution |
|-----|------|-----------|-------------|------------|
| 90%+ Apex test coverage | Developer | 🔴 High | Cannot deploy to production | All test classes planned from Phase 3 onwards — not left to Phase 6 |
| Custom Permission deployment | Developer | 🟡 Medium | Access control not enforced | Permissions built in Phase 6 — must be in package.xml |
| UAT sign-off by stakeholders | PO + BA | 🟡 Medium | Launch delayed | PO must schedule UAT with stakeholders at Phase 5 completion |
| Shield Encryption policy | Architect | 🟢 Low | Compliance gap (if Shield licensed) | Only applies if org has Shield — verify license before Phase 6 |

---

## Ongoing / All Phases

| Gap | Role | Risk Level | Consequence | Resolution |
|-----|------|-----------|-------------|------------|
| Named Credential token expiry handling | Developer + Architect | 🟡 Medium | AI calls fail silently | Health check method in `AIInferenceService`; dashboard shows last success per provider |
| Canvas JSON size approaching 131K | Architect | 🟢 Low | Cannot save large workflows | Alert user when JSON > 100K chars; recommend sub-workflows |
| Daily Queueable limit (250K) | Architect | 🟡 Medium | Org-wide async limit hit | Monitor usage; Batch Apex for bulk scenarios; alert at 80% |