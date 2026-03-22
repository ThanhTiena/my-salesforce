# Project Progress — Salesforce AI Orchestration Engine

> **How to use this file:**
> - Update `Status` and `Progress` after completing each task
> - Fill in `Outcome` when a task is done
> - The `Next Action` column tells you exactly what to do next
> - An AI agent reading this file should be able to pick up from any point

**Legend:** `✅ Done` | `🔄 In Progress` | `⏳ Not Started` | `🚫 Blocked`

---

## Overall Summary

| Phase | Name | Status | Progress | Owner |
|-------|------|--------|----------|-------|
| Phase 1 | Foundation | ✅ Done | 100% | — |
| Phase 2 | Core Designer | ✅ Done | 100% | — |
| Phase 3 | Execution Engine | ✅ Done | 100% | — |
| Phase 4 | AI Integration | ✅ Done | 100% | — |
| Phase 5 | Advanced Features | 🔄 In Progress | 15% | — |
| Phase 6 | Hardening | ⏳ Not Started | 0% | — |

---

## Phase 1 — Foundation
**Goal:** Deploy all custom objects, fields, CMDT, Named Credentials, and static resource bundle.
**Status: ✅ Done**

### 1.1 Custom Objects & Fields

| Task | Status | Outcome |
|------|--------|---------|
| Create `AI_Workflow__c` object | ✅ Done | Deployed with all fields |
| Create `AI_Step__c` object | ✅ Done | Deployed — `Step_Type__c` picklist updated to handler keys (AI_INFERENCE, DECISION, HTTP_CALLOUT, etc.) |
| Create `AI_Execution__c` object | ✅ Done | Deployed |
| Create `AI_Step_Execution__c` object | ✅ Done | Deployed |
| Create `AI_Provider__mdt` CMDT | ✅ Done | Deployed with 14 fields |
| Create `AI_Prompt_Template__c` object | ✅ Done | Object exists in codebase |
| Create `AI_Rate_Limit__c` object | ✅ Done | Object exists in codebase |
| Verify all field metadata passes deploy | ✅ Done | Deployed to `my-dev` — Status: Succeeded |

### 1.2 Named Credentials

| Task | Status | Outcome |
|------|--------|---------|
| `AI_OpenAI` | ✅ Done | Deployed |
| `AI_Anthropic` | ✅ Done | Deployed |
| `AI_Google_Gemini` | ✅ Done | Deployed |
| `AI_Cohere` | ✅ Done | Deployed |
| `AI_Mistral` | ✅ Done | Deployed |
| Remote Site Settings | ⚠️ Skipped | Must be configured manually per org — cannot deploy via metadata |

### 1.3 Static Resource (Drawflow Bundle)

| Task | Status | Outcome |
|------|--------|---------|
| `npm install drawflow` | ✅ Done | `node_modules/drawflow` present |
| Configure Webpack (`webpack.config.js`) | ✅ Done | UMD bundle, `library.name: 'Drawflow'`, exposes `window.Drawflow` |
| Build bundle: `npm run build` | ✅ Done | `dist/orchestrationEngine.js` + `dist/orchestrationEngine.css` |
| Upload as Static Resource `orchestrationEngine` | ✅ Done | Zipped to `.resource`, deployed to `my-dev` |

---

## Phase 2 — Core Designer
**Goal:** Drag-and-drop workflow designer with node palette and properties panel.
**Status: ✅ Done**

| Task | Status | Outcome |
|------|--------|---------|
| `WorkflowService` Apex controller | ✅ Done | `getWorkflow`, `saveWorkflow`, `saveSteps`, `runWorkflow`, `getActiveProviders`, etc. |
| `aiWorkflowDesigner` LWC | ✅ Done | Drawflow canvas, node select/add/update events |
| `aiNodePalette` LWC | ✅ Done | 11 node types, drag+click, category colours |
| `aiPropertiesPanel` LWC | ✅ Done | Per-type config forms for all 11 node types |
| `aiWorkflowBuilder` LWC | ✅ Done | Three-column shell, wired to palette + canvas + properties |
| Deploy to `my-dev` + smoke test | ✅ Done | Deployed. App Page configured manually in Setup |
| CMDT provider records | ✅ Done | OpenAI GPT-4o, Anthropic Claude, Google Gemini, Azure (inactive), Cohere, Mistral |

---

## Phase 3 — Execution Engine
**Goal:** Queueable execution runtime with all step handlers and step logging.
**Status: ✅ Done**

| Task | Status | Outcome |
|------|--------|---------|
| `AIStepHandler` interface | ✅ Done | `execute(AI_Step__c, Map<String,Object>, Id): AIStepResult` |
| `AIStepResult` DTO | ✅ Done | `ok()` / `fail()` factories, `nextBranch`, `durationMs` |
| `AIStepHandlerRegistry` | ✅ Done | Static map: DECISION, HTTP_CALLOUT, APEX_ACTION, FLOW_LAUNCH, WAIT, NOTIFICATION, START, END |
| `AIStepHandlerDecision` | ✅ Done | Evaluates `CONTEXT_KEY==value` and `LAST_OUTPUT_CONTAINS:keyword` |
| `AIStepHandlerHttp` | ✅ Done | Named Credential callout, context interpolation, sanitised NC name |
| `AIStepHandlerApex` | ✅ Done | `Type.forName()`, validates `implements AIStepHandler` |
| `AIStepHandlerFlow` | ✅ Done | `Flow.Interview.createInterview(flowApiName, inputs)` |
| `AIStepHandlerWait` | ✅ Done | Records wait metadata in context, pass-through |
| `AIStepHandlerNotification` | ✅ Done | `Messaging.sendEmail`, context interpolation |
| `AIStepHandlerPassthrough` | ✅ Done | START/END — returns `ok(step.Step_Type__c)` |
| `AIWorkflowOrchestrator` updated | ✅ Done | Routes through registry; AI_INFERENCE falls to `AIInferenceService`; `checkLimits()` guard |
| `AIWorkflowQueueable` | ✅ Done | Queueable class exists |
| Step logging to `AI_Step_Execution__c` | ✅ Done | `completeHandlerStepExecution()` in SystemWriter inner class |
| Governor limit monitoring | ✅ Done | `checkLimits()` — aborts at SOQL ≥90, DML ≥140, CPU ≥9000ms |
| **Test classes (25/25 passing)** | ✅ Done | Decision, Http, Notification, Passthrough, Registry, Wait, StepResult |

---

## Phase 4 — AI Integration
**Goal:** AI inference service, provider adapters, prompt templating, security util.
**Status: ✅ Done**

| Task | Status | Outcome |
|------|--------|---------|
| `AIProviderAdapter` interface | ✅ Done | Interface exists |
| `AIAdapterOpenAI` | ✅ Done | OpenAI request builder + response parser |
| `AIAdapterAnthropic` | ✅ Done | Anthropic builder + parser, `anthropic-version` header |
| `AIAdapterGoogle` | ✅ Done | Gemini builder + parser |
| `AIAdapterAzureOpenAI` | ✅ Done | Azure OpenAI adapter |
| `AIAdapterCohere` | ✅ Done | Cohere Command-R+ adapter |
| `AIAdapterMistral` | ✅ Done | Mistral Large adapter |
| `AIInferenceService` | ✅ Done | Routes to correct adapter by `Provider_Type__c` |
| `AIPromptTemplateService` | ✅ Done | Variable interpolation engine |
| `AISecurityUtil` | ✅ Done | Input sanitisation / security helpers |
| `AIInferenceServiceTest` | ✅ Done | Test class exists |
| `AIPromptTemplateServiceTest` | ✅ Done | Test class exists |
| `AISecurityUtilTest` | ✅ Done | Test class exists |
| Token usage logging | 🔄 In Progress | Token fields on `AI_Step_Execution__c` exist — wiring to adapter responses needs verification |
| Rate limit enforcement | ⏳ Not Started | `AI_Rate_Limit__c` object exists but `AIRateLimitService` not yet built |
| Fallback provider on failure | ⏳ Not Started | No `Fallback_Provider__c` field or fallback logic yet |
| `aiProviderSetup` LWC | ✅ Done | Admin view deployed — reads `getActiveProviders()` |
| `aiProviderConfig` LWC | ✅ Done | Component exists |

---

## Phase 5 — Advanced Features
**Goal:** Monitoring dashboard, template library, sub-workflow, loop, export/import.
**Status: 🔄 In Progress (65%)**

| Task | Status | Outcome / Next Action |
|------|--------|----------------------|
| `aiExecutionMonitor` LWC — execution dashboard | ✅ Done | 6 metric tiles, executions table, step drill-down modal, token-by-provider grid |
| `AIExecutionMonitorController` | ✅ Done | `getDashboardMetrics`, `getRecentExecutions`, `getTokenUsageByProvider`, `getStepExecutions` — 7/7 tests passing |
| `aiOrchestrationDashboard` LWC | ✅ Done | Shell with lightning-tabset: "Executions" → aiExecutionMonitor, "Providers" → aiProviderSetup |
| `aiPromptBuilder` LWC | ✅ Done | Token pill insertion, Object+Field combobox, clipboard copy, `promptchange` event |
| `aiStepBuilder` LWC | ✅ Done | Wizard panel: AI_INFERENCE gets Model + Prompt tabs with embedded aiPromptBuilder; delegates other types |
| Rate limit enforcement | ✅ Done | `AIRateLimitService` — transaction-scoped static map, `checkAndIncrement()` called in `AIInferenceService.run()` — 4/4 tests passing |
| Fallback provider on failure | ✅ Done | `AIInferenceRequest.fallbackProviderDeveloperName` — recursive retry with null-guard; 13/13 AIInferenceServiceTest passing |
| Template library — `Is_Template__c` field | ✅ Done | Checkbox field on `AI_Workflow__c` |
| Template library — `Canvas_JSON__c` field | ✅ Done | LongTextArea(131072) on `AI_Workflow__c` |
| `WorkflowTemplateService` Apex | ✅ Done | `getTemplates()` + `cloneTemplate()` with full step cloning — 3/3 tests passing |
| `aiTemplateBrowser` LWC | ✅ Done | Card grid, clone modal with name input, `workflowcreated` event dispatch |
| Alert on repeated failures | ⏳ Not Started | Apex trigger on `AI_Execution__c.Status = FAILED` — count consecutive, fire notification |
| Template data — 4 sample templates | ⏳ Not Started | Insert 4 `AI_Workflow__c` records with `Is_Template__c=true` + pre-built steps (Lead Qualification, Case Escalation, Document Analysis, Multi-Step Approval) |
| Sub-workflow / parent-child execution | ⏳ Not Started | `Parent_Execution__c` lookup on `AI_Execution__c` + SubflowHandler spawns child execution |
| Loop handler | ⏳ Not Started | `AIStepHandlerLoop` — iterate collection in context, track index |
| Export/import workflow JSON | ⏳ Not Started | LWC file download (Canvas JSON) + `InputFile` upload to create new workflow |
| Instance pause / resume | ⏳ Not Started | Status = PAUSED, Platform Event to resume |
| Instance cancel | ⏳ Not Started | Status = CANCELLED, abort Queueable |

**Phase 5 Checkpoint:** ✅ Dashboard live ✅ Rate limiting ✅ Fallback provider ✅ Template browser — remaining: sample templates, sub-workflow, loop, export/import, instance control

---

## Phase 6 — Hardening
**Goal:** Full test coverage, security review, Custom Permissions, scratch org deploy test.
**Status: ⏳ Not Started**

| Task | Status | Next Action |
|------|--------|-------------|
| Verify all Phase 4 test classes pass in org | ✅ Done | AIInferenceServiceTest 13/13, AIPromptTemplateServiceTest 9/9, AISecurityUtilTest 19/19 — all passing |
| Review `aiOrchestrationDashboard`, `aiPromptBuilder`, `aiStepBuilder` LWCs | ✅ Done | Built from scratch, deployed — all 3 green |
| Custom Permission: `Manage_Orchestration` | ⏳ Not Started | Setup → Custom Permissions → New |
| Custom Permission: `Execute_Orchestration` | ⏳ Not Started | — |
| Custom Permission: `View_Orchestration` | ⏳ Not Started | — |
| Upgrade Permission Sets with Custom Permissions | ⏳ Not Started | Add to `AI_Orchestration_Admin` + `AI_Orchestration_User` perm sets |
| Security review: SOQL injection | ⏳ Not Started | Audit all dynamic SOQL in Apex |
| Security review: Prompt injection | ⏳ Not Started | Verify `AISecurityUtil` covers context variable sanitisation |
| Shield Encryption: `Prompt_Sent__c`, `Raw_Response__c` | ⏳ Not Started | Requires Shield license — document as prerequisite |
| `sf project deploy start` to fresh scratch org | ⏳ Not Started | Zero-error full deploy validates all metadata |
| UAT sign-off | ⏳ Not Started | Run end-to-end workflow with real API keys |

---

## Blockers & Decisions Log

| Date | Phase | Blocker / Decision | Resolution |
|------|-------|-------------------|------------|
| 2026-03 | Phase 2 | FlexiPage schema too restrictive for automated deploy | User added App Page manually in Setup UI |
| 2026-03 | Phase 3 | `AI_Step__c.Step_Type__c` picklist had wrong values (`INFERENCE` instead of `AI_INFERENCE`) | Updated picklist to match handler keys; old values deactivated as legacy |
| 2026-03 | Phase 4 | `Flow.Interview.InputVariable` type does not exist in Apex | Replaced with `Map<String,Object>` passed directly to `createInterview()` |
| 2026-03 | Phase 2 | npm cache EACCES — no sudo | Used `npm install --cache /tmp/npm-cache` |

---

## Agent Instructions

> An AI agent resuming this project should:
>
> 1. Read this file top to bottom.
> 2. Find the **first task** with status `⏳ Not Started` in the current in-progress phase.
> 3. Check its prerequisites are satisfied.
> 4. Build it, deploy it, run tests.
> 5. On completion: set Status = `✅ Done`, fill in Outcome, update phase progress %.
> 6. If the phase checkpoint is satisfied, mark phase `✅ Done` in the Overall Summary.
> 7. Move to the next task.
