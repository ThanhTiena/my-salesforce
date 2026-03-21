# Salesforce Developer — Skill Matrix

> Proficiency levels: **Basic** | **Intermediate** | **Advanced** | **Expert**
> Phase column = first phase the skill is actively needed.

---

## Apex — Core

| Skill | Phase | Required Level | Notes |
|-------|-------|----------------|-------|
| Classes, interfaces, abstract classes | 1 | Advanced | `AIProviderAdapter` interface pattern already in use |
| `with sharing` / `without sharing` | 1 | Advanced | Inner `SystemWriter` pattern established — follow it |
| CRUD / FLS enforcement (`assertReadable`, `assertUpdatable`) | 1 | Advanced | All in `AISecurityUtil` — always call before DML/SOQL |
| `WITH SECURITY_ENFORCED` on SOQL | 1 | Advanced | Required on all dynamic queries |
| Custom exceptions (`extends Exception`) | 1 | Intermediate | Each service defines its own typed exceptions |
| `JSON.serialize` / `JSON.deserializeUntyped` | 1 | Advanced | All AI request/response bodies, context maps |
| HTTP callouts (`HttpRequest`, `HttpResponse`) | 1 | Advanced | Only via `AIInferenceService.callout()` — never raw `Http.send()` |
| CMDT queries (no sharing/FLS concern) | 1 | Intermediate | `AI_Provider__mdt` loaded by DeveloperName |
| Queueable Apex + `Database.AllowsCallouts` | 2 | Advanced | `AIWorkflowQueueable` pattern — study before extending |
| Queueable chaining (`System.enqueueJob`) | 2 | Advanced | Retry pattern: pass retryCount as constructor arg |
| `@future(callout=true)` | 4 | Intermediate | Fallback for non-Queueable trigger contexts |
| Platform Events (publish/subscribe) | 3 | Intermediate | Wait/Resume handler in Phase 3 |
| Batch Apex | 5 | Intermediate | Bulk execution of workflows on large datasets |
| `Schema.getGlobalDescribe()` / `SObjectType` | 1 | Intermediate | `writeOutputToRecord` pattern in Orchestrator |
| Governor limit introspection (`Limits.*`) | 3 | Advanced | Check before each step in Queueable |

---

## Apex — Testing

| Skill | Phase | Required Level | Notes |
|-------|-------|----------------|-------|
| `@IsTest` + `Test.startTest/stopTest` | 6 | Advanced | 90%+ coverage required |
| `HttpCalloutMock` + `StaticResourceCalloutMock` | 6 | Advanced | Mock all 6 AI provider responses |
| `Test.enqueueJob` behaviour | 6 | Intermediate | Queueable doesn't run in test without `Test.startTest` |
| `System.assert` / `Assert.areEqual` | 6 | Intermediate | — |

---

## LWC

| Skill | Phase | Required Level | Notes |
|-------|-------|----------------|-------|
| Component lifecycle (`connectedCallback`, `disconnectedCallback`, `renderedCallback`) | 2 | Advanced | `renderedCallback` needed to init Drawflow after DOM ready |
| `@wire` with Apex (`@wire(getRecord)`) | 2 | Intermediate | Load workflow data |
| `@api` / `@track` / reactive properties | 2 | Advanced | — |
| `@salesforce/apex` imperative calls | 2 | Advanced | Save/load workflow JSON |
| `loadScript()` / `loadStyle()` from Static Resource | 2 | Advanced | Bootstrap Drawflow canvas |
| `lwc:dom="manual"` | 2 | Advanced | Required for Drawflow to control its DOM subtree |
| `CustomEvent` + `dispatchEvent` | 2 | Advanced | Palette → Designer, Properties → Designer communication |
| `ShowToastEvent` | 2 | Basic | User feedback on save/error |
| No `innerHTML`, no `eval` | 2 | Advanced | Hard rule — XSS prevention |
| `lightning-datatable` | 2 | Intermediate | Already used in `aiExecutionMonitor` |
| `lightning-combobox`, `lightning-input`, `lightning-textarea` | 2 | Basic | Properties panel fields |
| `lightning-modal` (or custom modal) | 2 | Intermediate | Step config dialog |

---

## SFDX / Tooling

| Skill | Phase | Required Level | Notes |
|-------|-------|----------------|-------|
| SFDX project structure (`force-app/main/default/`) | 1 | Advanced | Sub-project at `sf-ai-orchestrator/` |
| `.field-meta.xml` correct format | 1 | Advanced | See `FIELDS_TO_CREATE.md` for all field specs |
| `.object-meta.xml` (no inline fields) | 1 | Advanced | Object file = object settings only |
| `sf project deploy start` | 1 | Intermediate | Use `--dry-run` first |
| Scratch org creation + push | 1 | Intermediate | `project-scratch-def.json` at root |
| npm + Webpack (UMD bundle) | 1 | Intermediate | Bundle Drawflow for Static Resource |
| `.cls-meta.xml` (API version 62.0) | 1 | Basic | Match `sfdx-project.json` sourceApiVersion |

---

## Phase Readiness Checklist

| Phase | Key Skills Developer Must Have Before Starting |
|-------|-----------------------------------------------|
| 1 ✅ | Apex classes, HTTP callouts, CMDT, Named Credentials, SFDX deploy |
| 2 🔄 | LWC lifecycle, `loadScript`, `lwc:dom="manual"`, Drawflow JS API, Apex wire |
| 3 ⏳ | Queueable chaining, governor limits, Platform Events, all step handler patterns |
| 4 ⏳ | AI adapter pattern, JSON parsing, `HttpCalloutMock` for tests |
| 5 ⏳ | Aggregate SOQL, sub-workflow linking, Batch Apex |
| 6 ⏳ | Full test suite, `HttpCalloutMock`, permission set deployment |