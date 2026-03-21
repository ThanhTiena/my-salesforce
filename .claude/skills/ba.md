# Business Analyst — Skill Matrix

> Proficiency levels: **Basic** | **Intermediate** | **Advanced** | **Expert**

---

## Requirements & Documentation

| Skill | Phase | Required Level | Applied To |
|-------|-------|----------------|-----------|
| User story writing (As a / I want / So that) | 1–6 | Advanced | All 44 functional requirements (FR-01 to FR-44) |
| Acceptance criteria definition (Given/When/Then) | All | Advanced | Each FR needs testable AC before dev starts |
| Functional vs non-functional requirement separation | 1 | Advanced | FR-01–44 (functional); §4 of spec (non-functional) |
| Gap analysis documentation | 1 | Intermediate | SF Flow limitations vs. this engine — see spec §2 |
| Use case documentation (flows, happy path, edge cases) | 2–4 | Advanced | Designer UX, execution scenarios, AI step configs |
| Process mapping (swim-lane, BPMN-lite) | 2, 5 | Intermediate | Workflow execution lifecycle, approval flows |
| UAT plan creation | 6 | Advanced | Tied directly to FR-01–FR-44 |
| UAT test script writing | 6 | Advanced | One test script per FR, with pass/fail criteria |
| Change request assessment | All | Intermediate | Evaluate scope impact of new node types or providers |

---

## Salesforce Domain Knowledge

| Skill | Phase | Required Level | Applied To |
|-------|-------|----------------|-----------|
| Standard object familiarity (Lead, Case, Opportunity) | 5 | Intermediate | Pre-built templates use these objects as triggers |
| Salesforce Flow builder (declarative) | 1, 2 | Intermediate | Explain engine's advantages over native Flow |
| Custom object & field relationships | 1 | Intermediate | Review FIELDS_TO_CREATE.md for correctness |
| Picklist value governance | 1 | Intermediate | Status values, Step_Type values — define and freeze |
| Permission sets & profiles | 6 | Basic | Validate Designer / Operator / Viewer access |
| Reports & dashboards (SF native) | 5 | Basic | Monitoring dashboard requirements |
| Record types (if needed) | Future | Basic | Not in current scope |

---

## AI & Product Domain

| Skill | Phase | Required Level | Applied To |
|-------|-------|----------------|-----------|
| AI provider capabilities overview | 4 | Basic | OpenAI GPT-4o, Anthropic Claude, Google Gemini, Mistral, Cohere |
| Prompt template design (business language) | 4, 5 | Intermediate | Write the 4 pre-built templates (Lead Qual, Case Escalation, Doc Analysis, Approval) |
| AI guardrails (PII, data sensitivity) | 4, 6 | Intermediate | Define field allowlist rules; document PII masking requirements |
| Token / cost estimation | 4 | Basic | Help stakeholders understand AI cost implications |
| AI output quality assessment | 4, 5 | Basic | Review AI responses in UAT, flag accuracy issues |

---

## Functional Requirements Ownership by Phase

| Phase | FRs Owned by BA | BA Deliverable |
|-------|-----------------|----------------|
| Phase 1 | FR-06, FR-08 (save/version) | Object schema sign-off, picklist value definitions |
| Phase 2 | FR-01–FR-12 (designer) | UX wireframes, node type definitions, validation rules list |
| Phase 3 | FR-20–FR-29 (execution) | Error handling scenarios, retry policy, context variable naming |
| Phase 4 | FR-30–FR-39 (AI) | Provider config guide, prompt templates for 4 use cases, PII rules |
| Phase 5 | FR-40–FR-44 (templates/monitoring) | Template definitions, dashboard KPI list, alert thresholds |
| Phase 6 | All | UAT plan, test scripts, sign-off document |

---

## Phase Readiness Checklist

| Phase | BA Must Deliver Before Dev Starts |
|-------|-----------------------------------|
| 1 ✅ | Object model reviewed, picklist values defined, field naming approved |
| 2 🔄 | Wireframes for designer canvas, node palette, properties panel per node type |
| 3 ⏳ | Execution flow diagrams, error/retry scenarios, context variable glossary |
| 4 ⏳ | Prompt templates for all 4 use cases, PII field allowlist, provider config docs |
| 5 ⏳ | Dashboard KPIs, template definitions, alert thresholds, monitoring requirements |
| 6 ⏳ | UAT plan, test scripts for FR-01–FR-44, sign-off criteria |