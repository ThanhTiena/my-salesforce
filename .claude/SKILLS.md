# Team Skills Reference — Salesforce AI Orchestration Engine

> Use this document to map team members to phases, identify skill gaps, and assign work.

---

## 1. Salesforce Developer Skills

### Core Platform
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| Apex Classes, Interfaces, Abstract Classes | All phases | Advanced |
| Queueable Apex + chaining | Phase 3 | Advanced |
| `@future(callout=true)` | Phase 4 | Intermediate |
| Batch Apex | Phase 5 | Intermediate |
| `with sharing` / CRUD / FLS enforcement | All phases | Advanced |
| `WITH SECURITY_ENFORCED` SOQL | All phases | Intermediate |
| Platform Events (pub/sub) | Phase 3, 5 | Intermediate |
| Custom Metadata Types (CMDT) | Phase 1, 4 | Intermediate |
| Named Credentials + External Credentials | Phase 1, 4 | Intermediate |
| Static Resources (JS/CSS bundles) | Phase 1 | Intermediate |
| Custom Objects + Field-Level Security | Phase 1 | Intermediate |
| Custom Permissions | Phase 6 | Intermediate |
| HTTP Callouts (`HttpRequest`, `HttpResponse`) | Phase 3, 4 | Advanced |
| JSON serialization / `JSON.deserializeUntyped` | Phase 3, 4 | Advanced |
| Apex Test Classes (90%+ coverage) | Phase 6 | Advanced |
| `Schema.sObjectType` DML guards | All phases | Intermediate |

### LWC (Lightning Web Components)
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| LWC component lifecycle (`connectedCallback`, etc.) | Phase 2, 5 | Advanced |
| `@wire` adapter, `getRecord`, `getFieldValue` | Phase 2, 5 | Intermediate |
| `@api` / `@track` / reactive properties | Phase 2, 5 | Intermediate |
| `lightning/platformShowToastEvent` | Phase 2, 5 | Basic |
| `loadScript()` / `loadStyle()` from Static Resource | Phase 2 | Intermediate |
| Event-driven communication (`CustomEvent`, `dispatchEvent`) | Phase 2, 5 | Advanced |
| Slots + composition patterns | Phase 2 | Intermediate |
| NO `innerHTML` / XSS-safe patterns | Phase 2, 6 | Advanced |
| `lwc:dom="manual"` (for Drawflow canvas) | Phase 2 | Advanced |

### Tooling & Deployment
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| SFDX CLI (`sf deploy`, `sf push`) | All phases | Intermediate |
| Scratch orgs | All phases | Intermediate |
| SFDX project structure (`force-app/main/default`) | All phases | Advanced |
| `.field-meta.xml`, `.object-meta.xml` correct format | Phase 1 | Advanced |
| Package.xml / manifest deploys | Phase 6 | Intermediate |
| npm + Webpack (bundle Drawflow) | Phase 1 | Intermediate |

---

## 2. Business Analyst (BA) Skills

### Requirements & Design
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| User story writing (As a / I want / So that) | Phase 1–6 | Advanced |
| Functional requirement documentation | Phase 1 | Advanced |
| Acceptance criteria definition | All phases | Advanced |
| Process mapping (workflow diagrams, swim lanes) | Phase 2, 5 | Intermediate |
| Gap analysis (Salesforce Flow limitations vs. this engine) | Phase 1 | Intermediate |
| Stakeholder interview facilitation | Phase 1 | Advanced |
| Use case documentation for AI step types | Phase 4, 5 | Intermediate |

### Salesforce Business Context
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| Understanding Salesforce standard objects (Lead, Case, Opportunity, Contact) | Phase 5 | Intermediate |
| Salesforce Flow builder familiarity (to explain limitations to stakeholders) | Phase 1, 2 | Intermediate |
| Data model review (object relationships, picklist values) | Phase 1 | Intermediate |
| Permission sets / profiles understanding | Phase 6 | Basic |
| UAT planning and execution | Phase 6 | Advanced |
| Writing test scripts aligned to functional requirements (FR-01 to FR-44) | Phase 6 | Advanced |

### AI / Product
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| Understanding of AI provider capabilities (OpenAI, Anthropic, Gemini) | Phase 4 | Basic |
| Prompt template design (writing effective prompts for business use cases) | Phase 4, 5 | Intermediate |
| Defining AI guardrails (PII, data sensitivity, field allowlists) | Phase 4, 6 | Intermediate |
| Cost/token estimation for AI usage planning | Phase 4 | Basic |
| Template use case documentation (Lead Qualification, Case Escalation, etc.) | Phase 5 | Intermediate |

---

## 3. Salesforce Architect Skills

### Data Architecture
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| Custom object modelling (relationships, cardinality) | Phase 1 | Advanced |
| Master-Detail vs Lookup trade-off decisions | Phase 1 | Advanced |
| Custom Metadata Type (CMDT) design for config | Phase 1, 4 | Advanced |
| Long Text Area storage strategy (JSON in fields, size limits) | Phase 1, 3 | Advanced |
| Record-level security (OWD, sharing rules, ControlledByParent) | Phase 1, 6 | Advanced |
| Field History Tracking design | Phase 1 | Intermediate |
| AutoNumber name fields for audit objects | Phase 1 | Intermediate |

### Integration Architecture
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| Named Credentials + External Credentials (OAuth 2.0, custom auth) | Phase 1, 4 | Advanced |
| Outbound callout design (timeout, retry, error handling) | Phase 3, 4 | Advanced |
| AI provider API formats (OpenAI, Anthropic, Gemini request/response) | Phase 4 | Intermediate |
| Platform Event design (publish/subscribe, resume patterns) | Phase 3, 5 | Advanced |
| Remote Site Settings + CSP Trusted Sites | Phase 2, 4 | Intermediate |

### Execution & Governor Limit Architecture
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| Queueable Apex chaining patterns | Phase 3 | Expert |
| Governor limit monitoring (SOQL 100, DML 150, CPU 10s, Heap 6MB) | Phase 3, 6 | Expert |
| Async Apex daily limits (250K Queueable jobs) | Phase 3 | Advanced |
| Fan-out / parallel execution design | Phase 5 | Advanced |
| Sub-workflow / parent-child instance architecture | Phase 5 | Advanced |
| Batch Apex for bulk-trigger scenarios | Phase 5 | Intermediate |
| Error boundary design (fail step, not transaction) | Phase 3, 6 | Advanced |

### Security Architecture
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| Custom Permission design (`Manage_Orchestration`, `Execute_Orchestration`, `View_Orchestration`) | Phase 6 | Advanced |
| Shield Platform Encryption (for prompt/response fields) | Phase 1, 6 | Intermediate |
| SOQL injection prevention | Phase 3 | Advanced |
| Prompt injection prevention (AI input sanitisation) | Phase 4, 6 | Advanced |
| PII masking in AI steps | Phase 4, 6 | Advanced |
| Apex sharing model review | Phase 6 | Advanced |

### Front-End Architecture
| Skill | Needed In | Proficiency Required |
|-------|-----------|---------------------|
| Static Resource bundling strategy (Webpack + UMD) | Phase 1 | Advanced |
| Lightning Web Security (LWS) / Locker Service constraints | Phase 2 | Advanced |
| Drawflow integration pattern inside LWC shadow DOM | Phase 2 | Advanced |
| LWC state management for complex components | Phase 2 | Advanced |
| Canvas JSON storage size strategy (131K limit) | Phase 3 | Intermediate |

---

## Skill Gap Checklist

Use this when onboarding a new team member or reviewing readiness before a phase.

| Gap Area | Risk if Unaddressed | Who Should Own |
|----------|--------------------|--------------------|
| Queueable chaining + governor limits | Execution engine broken in prod | Senior SF Developer / Architect |
| Named Credentials + AI callout setup | Phase 4 blocked entirely | SF Developer + Admin |
| Webpack / Static Resource bundling | Designer LWC cannot load | SF Developer |
| `lwc:dom="manual"` + Drawflow integration | Canvas never renders | SF Developer |
| CMDT design for AI providers | Hard to add new providers later | Architect |
| Prompt injection sanitisation | Security vulnerability | Architect + Developer |
| Shield Encryption on prompt fields | Compliance risk | Architect + Admin |
| Custom Permission design | Access control broken | Architect |