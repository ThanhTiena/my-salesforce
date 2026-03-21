# Product Owner — Skill Matrix

> Proficiency levels: **Basic** | **Intermediate** | **Advanced** | **Expert**

---

## Product Strategy & Vision

| Skill | Phase | Required Level | Applied To |
|-------|-------|----------------|-----------|
| Product vision articulation | Pre-project | Advanced | "Visual AI workflow engine embedded natively in Salesforce" |
| Value proposition definition | Pre-project | Advanced | Fills SF Flow gap for async multi-step + AI workflows |
| Competitive landscape awareness | Pre-project | Basic | vs. MuleSoft, Make (Integromat), n8n, AWS Step Functions |
| Roadmap planning (now/next/later) | All | Advanced | 6-phase roadmap already defined — PO maintains it |
| Backlog prioritisation (MoSCoW) | All | Advanced | Must/Should/Could applied to all 44 FRs |
| Release planning per phase | All | Advanced | Each phase = a shippable increment |
| Success metric definition | Pre-project | Advanced | e.g. # workflows live, # AI calls/day, error rate < 2% |

---

## Stakeholder Management

| Skill | Phase | Required Level | Applied To |
|-------|-------|----------------|-----------|
| Stakeholder identification & RACI | Pre-project | Advanced | IT, Sales Ops, Customer Success, Compliance, Finance |
| Sprint review facilitation | Each phase | Advanced | Demo each phase increment to stakeholders |
| Feedback capture & triage | Each phase | Advanced | Distinguish "must fix" from "nice to have" during demos |
| Executive communication | Pre-project, 6 | Advanced | ROI framing: AI automation cost savings vs. implementation cost |
| Conflict resolution (scope vs. timeline) | All | Advanced | Protect MVP scope when stakeholders request extras |

---

## Backlog & Story Management

| Skill | Phase | Required Level | Applied To |
|-------|-------|----------------|-----------|
| Backlog grooming | All | Advanced | Each FR decomposed into actionable stories with AC |
| Story sizing facilitation (story points) | All | Intermediate | Work with dev to estimate each phase task |
| Definition of Done (DoD) ownership | All | Advanced | DoD = deployed to scratch org + AC met + tests passing |
| Definition of Ready (DoR) ownership | All | Intermediate | Story = ready when BA has wireframes/AC, Architect has signed off design |
| Acceptance criteria review | All | Advanced | PO signs off AC before dev starts; validates after dev ships |
| Sprint goal setting | All | Advanced | Each sprint has one clear goal aligned to a phase deliverable |

---

## Salesforce Product Knowledge

| Skill | Phase | Required Level | Applied To |
|-------|-------|----------------|-----------|
| Salesforce editions & feature availability | Pre-project | Intermediate | Shield Encryption (requires add-on), Platform Events (available in Enterprise+) |
| AppExchange packaging concepts | Future | Basic | Future: packaging this as a managed package |
| Salesforce release schedule (3x/year) | All | Basic | Plan around Spring/Summer/Winter release windows |
| Governor limits as product constraints | All | Basic | Understand 250K Queueable limit affects scalability story |
| Named Credentials as security requirement | Pre-project | Basic | PO must communicate: "no API keys in fields — ever" to stakeholders |
| Custom Metadata (deployable config) | 1 | Basic | PO approves CMDT as the config mechanism (vs. Custom Settings) |

---

## AI Product Governance

| Skill | Phase | Required Level | Applied To |
|-------|-------|----------------|-----------|
| AI use case prioritisation | 4, 5 | Advanced | Which 4 templates ship first; how to measure quality |
| AI cost governance | 4 | Intermediate | Token budget per workflow, daily caps, cost alert thresholds |
| AI risk & compliance framing | 4, 6 | Intermediate | PII exposure, bias, hallucination — must be in product governance docs |
| Provider SLA awareness | 4 | Basic | OpenAI 99.9% uptime; Anthropic; Gemini — what happens on provider outage |
| AI content policy alignment | 4, 6 | Basic | Ensure prompts don't violate provider acceptable use policies |

---

## Phase Responsibilities

| Phase | PO Must Do |
|-------|------------|
| Pre-project | Define vision, stakeholders, success metrics, approve MoSCoW on 44 FRs |
| Phase 1 ✅ | Approve object model, approve provider list (OpenAI/Anthropic/Google/Azure/Cohere/Mistral) |
| Phase 2 🔄 | Review designer wireframes, approve node types, set DoD for designer increment |
| Phase 3 ⏳ | Approve execution error/retry policy, set DoD for engine increment |
| Phase 4 ⏳ | Approve 4 prompt templates, set AI cost caps, approve provider config UI |
| Phase 5 ⏳ | Approve dashboard KPIs, template library scope, alert thresholds |
| Phase 6 ⏳ | Review UAT results, sign off production readiness, approve go-live date |