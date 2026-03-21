# Role: Product Owner

---

## What You Own

- Product vision and roadmap
- Backlog prioritisation (what gets built, in what order)
- Definition of Done (DoD) for each phase
- Stakeholder relationships and communication
- Go/no-go decisions for each phase release
- AI cost governance (token caps, budget thresholds)
- AI risk and compliance framing

---

## What You Do in Each Phase

| Phase | PO Actions |
|-------|------------|
| Pre-project ✅ | Define vision, identify stakeholders, approve provider list, apply MoSCoW to FR-01–FR-44 |
| Phase 1 ✅ | Approve object model + field names, approve 6 AI providers in scope |
| Phase 2 🔄 | Review designer wireframes, approve 11 node types, set DoD: "admin can draw + save + reload a workflow" |
| Phase 3 ⏳ | Approve retry policy (3 retries, configurable delay), set DoD: "workflow runs end-to-end from trigger to completion log" |
| Phase 4 ⏳ | Approve 4 prompt templates, set token cost caps per provider, set DoD: "AI step executes and logs token usage" |
| Phase 5 ⏳ | Approve dashboard KPIs, approve template library scope, set DoD: "monitoring shows live execution data" |
| Phase 6 ⏳ | Review UAT results, approve permission set design, sign off production readiness |

---

## Definition of Done — Per Phase

| Phase | DoD (must ALL be true before phase is "done") |
|-------|----------------------------------------------|
| 1 ✅ | All 5 objects deployed, all Apex classes compile, Named Credentials configured, Static Resource uploaded |
| 2 | Workflow can be drawn on canvas, saved to `AI_Workflow__c`, reloaded, and activated; validation catches orphan nodes |
| 3 | Multi-step workflow runs async (Queueable), all steps logged, retry triggers on failure, instance marked FAILED after max retries |
| 4 | AI Inference step executes via at least 2 providers, token usage logged, prompt interpolation works |
| 5 | Dashboard shows live execution data, at least 1 template importable from UI, sub-workflow links to parent |
| 6 | 90%+ test coverage, clean deploy to fresh scratch org, all FR-01–FR-44 UAT passing, permission sets deployed |

---

## Non-Negotiable Product Principles

1. **Security is non-negotiable** — any feature that would require storing API keys in fields is rejected
2. **AI cost transparency** — every AI call must log token usage; daily cap alerts are not optional
3. **Scope protection** — new node types or providers mid-phase require a scope change approval, not just verbal agreement
4. **Phase gates** — next phase does not start until current phase DoD is fully met
5. **No hardcoded credentials** — ever, in any environment

---

## Backlog Prioritisation Rules

| Priority | Applies To |
|----------|-----------|
| **Must** (build now) | All FR tagged Must in spec §3; security requirements; governor limit guards |
| **Should** (build if time) | FR-09 (view-only), FR-25 (pause/resume), FR-35 (fallback provider), FR-38 (streaming) |
| **Could** (future) | FR-10 (undo/redo), FR-28 (parallel branches), FR-39 (prompt versioning) |
| **Won't** (not in scope) | Non-Salesforce deployments, mobile-native app, real-time collaboration on canvas |

---

## Decisions You Make

- Priority order of backlog items
- Which "Should" items get pulled into a phase vs deferred
- Go/no-go for each phase release
- AI cost caps and budget thresholds
- Whether a stakeholder request is in scope

---

## Decisions You Escalate

- Security architecture concerns → **Architect**
- Technical feasibility of a requested feature → **Developer + Architect**
- Compliance / legal concerns about AI and PII → **Legal / Compliance team**