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
| Phase 2 | Core Designer | 🔄 In Progress | 70% | — |
| Phase 3 | Execution Engine | ⏳ Not Started | 0% | — |
| Phase 4 | AI Integration | ⏳ Not Started | 0% | — |
| Phase 5 | Advanced Features | ⏳ Not Started | 0% | — |
| Phase 6 | Hardening | ⏳ Not Started | 0% | — |

---

## Phase 1 — Foundation
**Goal:** Deploy all custom objects, fields, CMDT, Named Credentials, and static resource bundle to scratch org.
**Dependencies:** Salesforce scratch org access, npm/webpack installed.
**Estimated Effort:** 2–3 days

### 1.1 Custom Objects & Fields

| Task | Status | Income (What you need) | Outcome (What you produce) | Next Action |
|------|--------|------------------------|---------------------------|-------------|
| Create `AI_Workflow__c` object | ✅ Done | Salesforce Setup or SFDX | Object + 10 fields deployed | — |
| Create `AI_Step__c` object | ✅ Done | `AI_Workflow__c` must exist first | Object + 14 fields deployed | — |
| Create `AI_Execution__c` object | ✅ Done | `AI_Workflow__c` must exist | Object with AutoNumber name + 12 fields | — |
| Create `AI_Step_Execution__c` object | ✅ Done | `AI_Execution__c` + `AI_Step__c` must exist | Object with AutoNumber name + 16 fields | — |
| Create `AI_Provider__mdt` CMDT | ✅ Done | Salesforce Setup | CMDT with 14 fields | — |
| Verify all `.field-meta.xml` files pass `sf deploy` | ⏳ Not Started | All objects/fields created | Zero deploy errors | Run `sf project deploy start --dry-run` from `sf-ai-orchestrator/` |

### 1.2 Named Credentials

| Task | Status | Income | Outcome | Next Action |
|------|--------|--------|---------|-------------|
| Create Named Credential: `AI_OpenAI` | ✅ Done | OpenAI API key | NC metadata file deployed | `namedCredentials/AI_OpenAI.namedCredential-meta.xml` |
| Create Named Credential: `AI_Anthropic` | ✅ Done | Anthropic API key | NC metadata file deployed | `namedCredentials/AI_Anthropic.namedCredential-meta.xml` |
| Create Named Credential: `AI_Google_Gemini` | ✅ Done | Google AI API key | NC metadata file deployed | `namedCredentials/AI_Google_Gemini.namedCredential-meta.xml` |
| Create Named Credential: `AI_Cohere` | ✅ Done | Cohere API key | NC metadata file deployed | — |
| Create Named Credential: `AI_Mistral` | ✅ Done | Mistral API key | NC metadata file deployed | — |
| Add AI providers to Remote Site Settings | ⏳ Not Started | Endpoint URLs from spec §6 | Callouts allowed | Setup → Remote Site Settings → New for each API base URL |

### 1.3 Static Resource (Drawflow Bundle)

| Task | Status | Income | Outcome | Next Action |
|------|--------|--------|---------|-------------|
| `npm install drawflow` | ⏳ Not Started | Node.js + npm installed | `node_modules/drawflow` present | Run `npm install drawflow` in `sf-ai-orchestrator/` |
| Configure Webpack (`webpack.config.js`) | ⏳ Not Started | Drawflow npm package | UMD bundle: `orchestrationEngine.js` + `.css` | Output format: UMD, library name: `Drawflow`, expose `window.Drawflow`. Entry: `node_modules/drawflow/dist/drawflow.js` |
| Build bundle: `npm run build` | ⏳ Not Started | `webpack.config.js` ready | `dist/orchestrationEngine.js` + `dist/orchestrationEngine.css` | Run `npm run build` — verify file sizes are < 5MB |
| Zip and upload as Static Resource `orchestrationEngine` | ⏳ Not Started | Built bundle files | Static Resource deployed | Zip `dist/` contents → upload in Setup → Static Resources. Name must match `@salesforce/resourceUrl/orchestrationEngine` |

**Phase 1 Checkpoint:** ✅ All objects deployed + ✅ NCs created + ✅ Static resource uploaded = Phase 2 can begin.

---

## Phase 2 — Core Designer
**Goal:** Build the drag-and-drop workflow designer LWC with node palette and properties panel.
**Dependencies:** Phase 1 complete. Static resource `orchestrationEngine` deployed.
**Estimated Effort:** 3–5 days

| Task | Status | Income | Outcome | Next Action |
|------|--------|--------|---------|-------------|
| `WorkflowService` Apex controller | ✅ Done | Phase 1 done | `@AuraEnabled` methods: getWorkflow, getWorkflows, createWorkflow, saveWorkflow, saveSteps, setWorkflowActive, deleteWorkflow, runWorkflow, getActiveProviders | — |
| `aiWorkflowDesigner` LWC — canvas + Drawflow | ✅ Done | Static Resource deployed | LWC renders Drawflow canvas, handles node selection events, exposes `addNode()` and `updateNodeData()` @api | Located at `lwc/aiWorkflowDesigner/` |
| `aiNodePalette` LWC — sidebar | ✅ Done | — | All 11 node types as draggable palette items with search, category colour coding, drag+click events | Located at `lwc/aiNodePalette/` |
| `aiPropertiesPanel` LWC — contextual config form | ✅ Done | — | Per-type forms: AI Inference, Decision, HTTP Callout, Apex Action, Flow Launch, Wait, Notification, Sub-Workflow | Located at `lwc/aiPropertiesPanel/` |
| `aiWorkflowBuilder` LWC — parent shell | ✅ Done | All 3 children built | Three-column layout. Wires palette → canvas → properties. New Workflow modal. Drag-and-drop + click-to-add. | Located at `lwc/aiWorkflowBuilder/` — exposed to AppPage + Tab |
| Webpack bundle + Static Resource upload | ⏳ Not Started | npm/webpack installed | `orchestrationEngine` Static Resource deployed | See Phase 1 Static Resource tasks above — must be done before designer renders |
| Deploy Phase 2 to scratch org + smoke test | ⏳ Not Started | Static resource + all above | Designer loads in App Page, nodes can be added, saved, reloaded | Run `sf project deploy start` then open AI Workflow Builder tab |

**Phase 2 Checkpoint:** ✅ Can draw a workflow, save it, reload it, activate it = Phase 3 can begin.

---

## Phase 3 — Execution Engine
**Goal:** Build the Queueable-based execution runtime with all step handlers and step logging.
**Dependencies:** Phase 2 complete. At least one workflow definition saved.
**Estimated Effort:** 3–5 days

| Task | Status | Income | Outcome | Next Action |
|------|--------|--------|---------|-------------|
| `IOrchestrationHandler` interface | ⏳ Not Started | Phase 2 done | Interface: `StepResult execute(StepContext ctx)` | All handlers implement this |
| `StepHandlerFactory` class | ⏳ Not Started | Interface defined | Returns correct handler by `Step_Type__c` | Use `Type.forName()` or switch statement |
| `ApexActionHandler` | ⏳ Not Started | Factory ready | Dynamically invokes custom Apex class | Invoke via `Type.forName()` + cast to `IOrchestrationAction` |
| `FlowLaunchHandler` | ⏳ Not Started | Factory ready | Launches Salesforce Flow by API name | `Flow.Interview.createInterview(flowApiName, inputs)` |
| `HttpCalloutHandler` | ⏳ Not Started | Factory ready | Makes outbound REST call via Named Credential | `HttpRequest` + Named Credential URL, 30s timeout |
| `DecisionHandler` | ⏳ Not Started | Factory ready | Evaluates expression, picks output path | Parse condition string from `Config_JSON__c`, evaluate against context |
| `WaitHandler` | ⏳ Not Started | Factory ready | Pauses instance, subscribes to Platform Event | Mark instance `WAITING`, resume on Platform Event |
| `NotificationHandler` | ⏳ Not Started | Factory ready | Sends email or Chatter post | `Messaging.SingleEmailMessage` or `ConnectApi.ChatterFeeds` |
| `EndHandler` | ⏳ Not Started | Factory ready | Marks `AI_Execution__c` Status = Completed | Simple DML update |
| `OrchestrationQueueable` | ⏳ Not Started | All handlers ready | Chains step execution asynchronously | `System.enqueueJob(new OrchestrationQueueable(execId, nextStepId))` |
| `OrchestrationExecutionEngine` entry point | ⏳ Not Started | Queueable ready | `startExecution(workflowId, triggerRecordId, contextJson)` public method | Creates `AI_Execution__c`, enqueues first step |
| Retry logic (configurable count + delay) | ⏳ Not Started | Engine working | Failed step retries N times before marking FAILED | Read `Max_Retries__c` from `AI_Workflow__c`, store `Retry_Count__c` |
| Governor limit monitoring | ⏳ Not Started | Engine working | Step fails gracefully before hitting limits | Check `Limits.getQueries() < 90` etc. before each step |
| Step logging to `AI_Step_Execution__c` | ⏳ Not Started | Engine working | Every step has a log record with input/output/status/duration | Set `Started_At__c` + `Completed_At__c` + `Duration_Ms__c` per step |

**Phase 3 Checkpoint:** ✅ Can run a multi-step workflow end-to-end + ✅ Every step logged = Phase 4 can begin.

---

## Phase 4 — AI Integration
**Goal:** Build the AI inference service, wire it into the execution engine, and create the provider setup UI.
**Dependencies:** Phase 3 complete. AI API keys available. Named Credentials created (Phase 1.2).
**Estimated Effort:** 3–4 days

| Task | Status | Income | Outcome | Next Action |
|------|--------|--------|---------|-------------|
| `AIInferenceService` core class | ⏳ Not Started | Phase 3 + NCs ready | `AIResponse callProvider(String providerName, AIRequest req)` | Routes to correct builder/parser per `Provider_Type__c` |
| OpenAI request builder + response parser | ⏳ Not Started | Service scaffolded | `buildOpenAIRequest()` + `parseOpenAIResponse()` | JSON format from spec §6.1 |
| Anthropic request builder + response parser | ⏳ Not Started | Service scaffolded | `buildAnthropicRequest()` + `parseAnthropicResponse()` | JSON format from spec §6.2. Add `anthropic-version` header. |
| Google Gemini request builder + response parser | ⏳ Not Started | Service scaffolded | `buildGoogleRequest()` + `parseGoogleResponse()` | JSON format from spec §6.3. URL pattern: `{endpoint}/{model}:generateContent` |
| Variable interpolation engine | ⏳ Not Started | Service scaffolded | `{{Object.Field}}` replaced with runtime context values | Regex replace against execution context map |
| `AIInferenceHandler` (step handler) | ⏳ Not Started | Service + Factory ready | AI step executes in workflow chain | Reads `Config_JSON__c` → builds `AIRequest` → calls service → returns `StepResult` |
| Token usage logging to `AI_Step_Execution__c` | ⏳ Not Started | Handler working | `Prompt_Tokens__c`, `Completion_Tokens__c`, `Tokens_Used__c` populated | Parse from provider response |
| AI usage rollup to `AI_Execution__c.Total_Tokens_Used__c` | ⏳ Not Started | Token logging done | Parent record shows total tokens | Roll-up summary field or Apex trigger |
| Provider setup admin LWC | ⏳ Not Started | CMDT fields created | Admin can view/add/edit `AI_Provider__mdt` records | LWC reads CMDT records, links to Setup for edits. No tokens ever in fields. |
| Rate limit enforcement | ⏳ Not Started | Service working | Requests per minute throttled to `Rate_Limit_RPM__c` | Cache request count per provider per minute in Platform Cache |
| Fallback provider on failure | ⏳ Not Started | Service working | If primary provider 429/5xx, retry with secondary | Add `Fallback_Provider__c` lookup field to `AI_Step__c` config |

**Phase 4 Checkpoint:** ✅ AI Inference step runs in a workflow + ✅ Token usage logged = Phase 5 can begin.

---

## Phase 5 — Advanced Features
**Goal:** Build monitoring dashboard, template library, viewer mode, sub-workflow support, and retry dashboard.
**Dependencies:** Phase 4 complete.
**Estimated Effort:** 3–5 days

| Task | Status | Income | Outcome | Next Action |
|------|--------|--------|---------|-------------|
| Monitoring dashboard LWC | ⏳ Not Started | Phase 4 done | Running instances, failure rate, avg duration widgets | Wire to `AI_Execution__c` SOQL aggregates |
| AI usage dashboard LWC | ⏳ Not Started | Token logging done | Tokens by provider, cost by workflow, daily totals | Wire to `AI_Step_Execution__c` token fields |
| Alert on repeated failures | ⏳ Not Started | Monitoring working | Email/Chatter alert after 3 consecutive fails | Apex trigger on `AI_Execution__c.Status = FAILED` — count consecutive |
| Template library — Lead Qualification | ⏳ Not Started | Phase 4 done | Pre-built workflow importable from UI | Store as CMDT record with `Canvas_JSON__c` |
| Template library — Case Escalation | ⏳ Not Started | Phase 4 done | Pre-built workflow importable | Store as CMDT record |
| Template library — Document Analysis | ⏳ Not Started | Phase 4 done | Pre-built workflow importable | Store as CMDT record |
| Template library — Multi-Step Approval | ⏳ Not Started | Phase 4 done | Pre-built workflow importable | Store as CMDT record |
| Template library browser UI | ⏳ Not Started | Templates in CMDT | Admin can browse + clone to new workflow | LWC reads CMDT templates, clones to `AI_Workflow__c` |
| Sub-workflow / parent-child execution | ⏳ Not Started | Engine working | `SubflowHandler` spawns child `AI_Execution__c` linked to parent | Add `Parent_Execution__c` lookup to `AI_Execution__c` |
| Loop handler | ⏳ Not Started | Engine working | Iterates collection in context, one Queueable per iteration | Track iteration index in context |
| Export/import workflow JSON | ⏳ Not Started | Designer working | Download Canvas JSON as `.json` file, upload to create new workflow | LWC file download + `InputFile` for import |
| Instance pause / resume | ⏳ Not Started | Wait handler done | Admin can manually pause/resume a running instance | Status = PAUSED, Platform Event to resume |
| Instance cancel | ⏳ Not Started | Engine working | Admin can cancel a running instance | Status = CANCELLED, abort current Queueable |

**Phase 5 Checkpoint:** ✅ Dashboard shows live data + ✅ At least 1 template importable = Phase 6 can begin.

---

## Phase 6 — Hardening
**Goal:** Full test coverage, security review, Custom Permission gates, documentation.
**Dependencies:** Phase 5 complete.
**Estimated Effort:** 2–3 days

| Task | Status | Income | Outcome | Next Action |
|------|--------|--------|---------|-------------|
| Apex test class: `AIInferenceServiceTest` | ⏳ Not Started | Phase 4 done | 90%+ coverage, all providers mocked | Use `HttpCalloutMock` for provider responses |
| Apex test class: `OrchestrationQueueableTest` | ⏳ Not Started | Phase 3 done | Queueable chain tested end-to-end | Test success path, failure path, retry path |
| Apex test class: all handlers | ⏳ Not Started | Phase 3–4 done | Each handler has isolated test | Mock `StepContext` with test data |
| Apex test class: `OrchestrationExecutionEngineTest` | ⏳ Not Started | Engine done | Entry point tested | Test trigger scenarios |
| Custom Permission: `Manage_Orchestration` | ⏳ Not Started | Phase 5 done | Permission created | Setup → Custom Permissions → New |
| Custom Permission: `Execute_Orchestration` | ⏳ Not Started | Phase 5 done | Permission created | — |
| Custom Permission: `View_Orchestration` | ⏳ Not Started | Phase 5 done | Permission created | — |
| Permission Set: Designer | ⏳ Not Started | Custom Permissions created | Has `Manage_Orchestration` + object CRUD | — |
| Permission Set: Operator | ⏳ Not Started | Custom Permissions created | Has `Execute_Orchestration` + read/create on execution objects | — |
| Permission Set: Viewer | ⏳ Not Started | Custom Permissions created | Has `View_Orchestration` + read-only on all objects | — |
| Security review: SOQL injection | ⏳ Not Started | All Apex done | No dynamic SOQL with unsanitised input | Code review checklist |
| Security review: Prompt injection | ⏳ Not Started | Phase 4 done | Context variables sanitised before interpolation | Strip/escape special chars, enforce max length |
| Shield Encryption: `Prompt_Sent__c`, `Raw_Response__c`, `Context_JSON__c` | ⏳ Not Started | Shield license | Sensitive fields encrypted at rest | Setup → Platform Encryption → Encryption Policy |
| `sf org beta:create` scratch org full deploy test | ⏳ Not Started | All code done | Zero-error deploy to fresh scratch org | `sf project deploy start -x manifest/package.xml` |
| UAT sign-off | ⏳ Not Started | Deploy test passed | Stakeholder acceptance | Run test scripts from `FIELDS_TO_CREATE.md` |

**Phase 6 Checkpoint:** ✅ 90%+ test coverage + ✅ Clean deploy to scratch org + ✅ UAT signed off = **Production Ready** 🎉

---

## Blockers & Decisions Log

| Date | Phase | Blocker / Decision | Resolution | Owner |
|------|-------|-------------------|------------|-------|
| — | — | — | — | — |

> Add a row here whenever something is blocked or an architectural decision is made.

---

## Agent Instructions

> An AI agent resuming this project should:
>
> 1. Read this file top to bottom.
> 2. Find the **first task** with status `⏳ Not Started` or `🚫 Blocked`.
> 3. Check its **Income** column — verify all prerequisites are satisfied.
> 4. Execute the task using the **Next Action** column as the instruction.
> 5. On completion: set Status = `✅ Done`, fill in the **Outcome**, update the Phase summary progress %.
> 6. Check if the phase checkpoint is now satisfied — if yes, update the Phase row in the Overall Summary.
> 7. Move to the next task.
>
> If a task is `🚫 Blocked`, add a row to the **Blockers & Decisions Log** and skip to the next unblocked task.