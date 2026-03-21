# Salesforce Architect — Skill Matrix

> Proficiency levels: **Basic** | **Intermediate** | **Advanced** | **Expert**

---

## Data Architecture

| Skill | Phase | Required Level | Decision Made |
|-------|-------|----------------|---------------|
| Custom object modelling (relationships, cardinality) | 1 | Advanced | ✅ AI_Workflow → AI_Step (Master-Detail), AI_Execution (Lookup) |
| Master-Detail vs Lookup trade-offs | 1 | Advanced | ✅ Step is MD (cascade delete OK); Execution is Lookup (persist audit on workflow delete) |
| AutoNumber name fields for audit objects | 1 | Advanced | ✅ AI_Execution uses `EXEC-{0000000}`, AI_Step_Execution uses `STEP-{0000000}` |
| CMDT design for pluggable config | 1 | Advanced | ✅ AI_Provider__mdt — DeveloperName as registry key, no tokens in fields |
| Long Text Area size strategy (131K limit) | 1 | Advanced | ✅ Prompt/response truncated to 131072 via `.left()` before DML |
| Field History Tracking design | 1 | Intermediate | ✅ Status__c on AI_Execution__c tracks history |
| Record-level security (OWD, sharing rules) | 1 | Advanced | ✅ AI_Workflow: ReadWrite; AI_Execution: Private; AI_Step_Execution: ControlledByParent |
| Shield Encryption candidates | 1 | Intermediate | Prompt_Sent__c, Raw_Response__c, Context_JSON__c — requires Shield license |

---

## Integration Architecture

| Skill | Phase | Required Level | Decision Made |
|-------|-------|----------------|---------------|
| Named Credentials + External Credentials | 1 | Advanced | ✅ One NC per provider: AI_OpenAI, AI_Anthropic, AI_Google_Gemini, AI_Mistral, AI_Cohere |
| Adapter pattern for multi-provider callouts | 1 | Advanced | ✅ `AIProviderAdapter` interface → 6 adapters registered in `AIInferenceService` |
| Callout security (no raw Http.send) | 1 | Advanced | ✅ All callouts via `AIInferenceService.callout()` only |
| Remote Site Settings / CSP Trusted Sites | 2 | Intermediate | Required for Drawflow CDN if not bundled locally |
| Platform Event design (pause/resume) | 3 | Advanced | Wait handler publishes PE; Trigger resumes Queueable |
| Fallback provider design | 4 | Advanced | Secondary provider on 429/5xx — config via step |

---

## Async Execution Architecture

| Skill | Phase | Required Level | Decision Made |
|-------|-------|----------------|---------------|
| Queueable chaining pattern | 1 | Expert | ✅ `AIWorkflowQueueable` → `AIWorkflowOrchestrator.runWorkflow()` → re-enqueue on retry |
| Retry with configurable count | 1 | Advanced | ✅ retryCount passed as constructor arg; max from `AI_Workflow__c.Max_Retries__c` |
| Governor limit monitoring strategy | 3 | Expert | Check `Limits.getQueries()`, `Limits.getCpuTime()` before each step |
| 250K daily Queueable limit strategy | 3 | Advanced | Sub-workflows + Batch Apex for bulk; alert at 80% consumption |
| Parallel branch execution | 5 | Advanced | Fan-out: enqueue multiple Queueables from one parent; merge via Platform Event |
| Error boundary (fail step, not transaction) | 1 | Expert | ✅ try/catch per step in `runWorkflow()` — workflow continues where possible |

---

## Security Architecture

| Skill | Phase | Required Level | Decision Made |
|-------|-------|----------------|---------------|
| Custom Permission design | 6 | Advanced | `Manage_Orchestration`, `Execute_Orchestration`, `View_Orchestration` |
| Permission Set design | 6 | Advanced | Designer / Operator / Viewer — each gets matching Custom Permission |
| `with sharing` / inner `without sharing` | 1 | Expert | ✅ `SystemWriter` inner class writes audit records in system context |
| SOQL injection prevention | 1 | Advanced | ✅ `AISecurityUtil.sanitiseFieldName/ObjectName` before dynamic SOQL |
| Prompt injection prevention | 1 | Advanced | ✅ `AISecurityUtil.sanitisePrompt()` — strips control chars, limits length |
| PII masking in AI steps | 4 | Advanced | Field allowlist per AI step — only explicitly selected fields sent |
| Apex sharing model review | 6 | Advanced | All classes: `with sharing`; exception is `SystemWriter` (documented intent) |

---

## Front-End Architecture

| Skill | Phase | Required Level | Decision Made |
|-------|-------|----------------|---------------|
| Webpack UMD bundle strategy | 1 | Advanced | ✅ Output: `window.OrchestrationEngine`; loaded via `loadScript()` |
| Lightning Web Security (LWS) constraints | 2 | Advanced | Drawflow is vanilla JS — no framework conflicts; tested in LWS |
| `lwc:dom="manual"` isolation pattern | 2 | Advanced | Drawflow owns its subtree; LWC never queries inside it |
| LWC state management for complex components | 2 | Advanced | Parent shell owns state; child components are display-only |
| Canvas JSON storage size (131K limit) | 3 | Intermediate | Alert user when canvas JSON > 100K; recommend sub-workflows |

---

## Architecture Decision Log

| Decision | Rationale | Phase |
|----------|-----------|-------|
| Drawflow over bpmn-js / React Flow | Zero deps, vanilla JS, LWS-safe, < 30KB | 1 |
| Adapter registry over switch statement | Open/Closed principle — new providers without modifying service | 1 |
| `SystemWriter` inner class | Audit records need system access; intent is documented | 1 |
| AutoNumber on execution objects | Immutable, user-friendly audit IDs | 1 |
| CMDT over Custom Settings | Packageable, deployable, no sharing concern | 1 |
| Lookup (not MD) from AI_Execution to AI_Workflow | Preserve execution audit when workflow is deleted | 1 |