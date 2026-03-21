# Role: Business Analyst

---

## What You Own

- Functional requirements (FR-01 to FR-44) — completeness and testability
- Acceptance criteria for every user story
- Wireframes for every UI component (designer, palette, properties panel, dashboard, template browser)
- Node type definitions (what each of the 11 node types does, inputs, outputs)
- Prompt templates for the 4 pre-built workflow templates
- PII and data sensitivity rules (field allowlist per AI step)
- UAT plan and test scripts
- Sign-off document

---

## What You Do in Each Phase

| Phase | BA Actions |
|-------|------------|
| 1 ✅ | Review object model, approve field names and picklist values, document FR-06/FR-08 AC |
| 2 🔄 | Deliver wireframes for designer canvas + all 11 node type property forms; write AC for FR-01–FR-12 |
| 3 ⏳ | Document execution scenarios, retry/error policies, context variable glossary; write AC for FR-20–FR-29 |
| 4 ⏳ | Write 4 prompt templates (Lead Qual, Case Escalation, Doc Analysis, Multi-Step Approval); define PII allowlist; write AC for FR-30–FR-39 |
| 5 ⏳ | Define dashboard KPIs, alert thresholds, template library scope; write AC for FR-40–FR-44 |
| 6 ⏳ | Execute UAT, file defects with steps to reproduce, sign off each FR |

---

## Inputs You Need Before Delivering

| Input | From | When |
|-------|------|------|
| Approved data model (objects, fields, relationships) | Architect | Phase 1 |
| Technical constraints (LWC capabilities, governor limits) | Developer + Architect | Before Phase 2 wireframes |
| AI provider capabilities (what each model does well) | Architect / research | Before Phase 4 prompt templates |
| Cost per token estimates | PO | Before Phase 4 PII/cost docs |

---

## Non-Negotiable Quality Standards

1. **Every FR has AC before dev starts** — no story is "dev-ready" without Given/When/Then criteria
2. **Wireframes cover all 11 node types** before properties panel is built — not just the common ones
3. **PII field allowlist is defined before Phase 4** — BA must not wait until after AI integration starts
4. **UAT scripts are written from FR, not from the implementation** — test what was specified, not what was built

---

## Decisions You Make

- Which picklist values are required for each status/type field
- Which fields are required vs optional in each node type's properties form
- Which 4 templates ship first and what their exact workflow logic is
- What counts as "pass" in a UAT test script

---

## Decisions You Escalate

- New node type not in spec → **PO** (scope change)
- Conflicting stakeholder requirements → **PO**
- Technical feasibility of a UI requirement → **Architect + Developer**