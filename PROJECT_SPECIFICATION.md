# Salesforce Orchestration Engine — Project Specification

**Version:** 1.0
**Status:** Ready for Development
**Last Updated:** March 2026

---

## 1. Executive Summary

This project builds a visual workflow orchestration engine embedded natively into Salesforce. Admins and developers design workflows by dragging and connecting nodes on a visual canvas (powered by Drawflow), and the platform executes those workflows asynchronously with full audit logging. A key differentiator is the built-in AI integration layer — workflow steps can invoke external AI models (OpenAI, Anthropic Claude, Google Gemini, or custom endpoints) using securely stored API tokens, enabling intelligent automation like lead scoring, case summarization, document analysis, and content generation as native workflow steps.

---

## 2. Problem Statement

Salesforce Flow is powerful for declarative automation but has limitations for complex orchestration scenarios:

- No visual orchestration across multiple async systems (external APIs, AI services, approval chains)
- No native way to invoke AI models as part of an automated process
- Limited retry/error handling for multi-step processes involving external services
- No single view to monitor the health of complex multi-step automations
- Flow cannot easily be versioned, templated, or exported/imported as portable definitions

This engine fills that gap by providing a visual designer, a pluggable execution runtime, and first-class AI integration — all within the Salesforce platform.

---

## 3. Functional Requirements

### 3.1 Visual Workflow Designer

| ID | Requirement | Priority |
|----|------------|----------|
| FR-01 | Drag-and-drop node canvas with zoom, pan, and mobile touch support | Must |
| FR-02 | Node palette sidebar with all registered node types | Must |
| FR-03 | Properties panel that changes contextually based on selected node | Must |
| FR-04 | Connect nodes by dragging from output port to input port | Must |
| FR-05 | Support multiple output ports per node (success/failure/conditional paths) | Must |
| FR-06 | Save workflow as JSON to Salesforce custom object | Must |
| FR-07 | Load and render existing workflow from saved JSON | Must |
| FR-08 | Version tracking — auto-increment on each save | Must |
| FR-09 | View-only mode for non-designers | Should |
| FR-10 | Canvas undo/redo | Could |
| FR-11 | Workflow validation before activation (check for orphan nodes, missing connections, required configs) | Must |
| FR-12 | Export/import workflow definitions as JSON files | Should |

### 3.2 Node Types

| Node Type | Inputs | Outputs | Purpose |
|-----------|--------|---------|---------|
| **Start** | 0 | 1 | Entry point — defines trigger criteria |
| **End** | 1 | 0 | Terminates workflow, sets final status |
| **Apex Action** | 1 | 2 (success/fail) | Invokes a configured Apex class implementing IOrchestrationAction |
| **Flow Launch** | 1 | 2 (success/fail) | Launches a Salesforce Flow by API name, passes input variables |
| **HTTP Callout** | 1 | 2 (success/fail) | Makes outbound REST call via Named Credential |
| **AI Inference** | 1 | 2 (success/fail) | Calls configured AI provider with prompt template |
| **Decision** | 1 | 2-4 (conditional) | Evaluates expression, routes to matching output |
| **Wait** | 1 | 1 | Pauses execution for N minutes or until Platform Event |
| **Loop** | 1 | 2 (iterate/done) | Iterates over a collection in context |
| **Subflow** | 1 | 2 (success/fail) | Launches another Workflow__c as a child instance |
| **Notification** | 1 | 1 | Sends email, Chatter post, or custom notification |

### 3.3 Execution Engine

| ID | Requirement | Priority |
|----|------------|----------|
| FR-20 | Execute workflows asynchronously via Queueable chaining | Must |
| FR-21 | Pass context (variables/payload) between steps | Must |
| FR-22 | Retry failed steps with configurable count and delay | Must |
| FR-23 | Timeout handling per step | Must |
| FR-24 | Log every step execution with input/output/status/duration | Must |
| FR-25 | Support pausing and resuming instances | Should |
| FR-26 | Support cancelling running instances | Must |
| FR-27 | Handle governor limits gracefully — fail step, not entire transaction | Must |
| FR-28 | Parallel step execution for independent branches | Could |
| FR-29 | Sub-workflow nesting with parent-child instance linking | Should |

### 3.4 AI Integration

| ID | Requirement | Priority |
|----|------------|----------|
| FR-30 | Configure multiple AI providers via Custom Metadata + Named Credentials | Must |
| FR-31 | Admin UI (LWC) to set up AI provider tokens without code | Must |
| FR-32 | AI step node with configurable provider, model, system prompt, user prompt template | Must |
| FR-33 | Variable interpolation in prompts — {{Object.Field}} replaced with runtime values | Must |
| FR-34 | Parse AI response as JSON or plain text, store in workflow context | Must |
| FR-35 | Fallback provider — if primary AI fails, retry with a secondary provider | Should |
| FR-36 | Token usage tracking per request (prompt tokens, completion tokens, estimated cost) | Must |
| FR-37 | Rate limiting — respect provider RPM limits via CMDT config | Should |
| FR-38 | Support streaming responses for long-running AI calls (via @future callout) | Could |
| FR-39 | Prompt versioning — save prompt templates separately, reference by ID | Could |

### 3.5 Templates & Monitoring

| ID | Requirement | Priority |
|----|------------|----------|
| FR-40 | Pre-built workflow templates stored in Custom Metadata | Should |
| FR-41 | Template library UI — browse, preview, clone to new workflow | Should |
| FR-42 | Monitoring dashboard — running instances, failure rate, avg duration | Must |
| FR-43 | AI usage dashboard — tokens consumed, cost by provider, cost by workflow | Should |
| FR-44 | Alert on repeated failures (3+ consecutive fails on same workflow) | Could |

---

## 4. Non-Functional Requirements

| Category | Requirement |
|----------|------------|
| **Performance** | Step execution must complete within Queueable limits (10 min CPU). AI callouts must timeout at configurable threshold (default 30s). |
| **Scalability** | Engine must handle 500+ concurrent workflow instances without hitting daily async limits (250K Queueable jobs). |
| **Security** | All API tokens stored in Named Credentials (never in custom fields or code). All Apex uses `with sharing`. CRUD/FLS enforced on every query/DML. XSS prevention in LWC. |
| **Reliability** | Failed steps logged with full error detail. Retry with exponential backoff. Instance marked Failed only after all retries exhausted. |
| **Auditability** | Every step execution logged in Step_Log__c. Every AI call logged in AI_Usage_Log__c. Canvas changes tracked via Version__c. |
| **Maintainability** | Handler pattern allows new node types without modifying engine core. Custom Metadata for all config. 90%+ test coverage. |
| **Governor limits** | Engine monitors SOQL (100), DML (150), CPU (10s), heap (6MB) consumption and fails gracefully before hitting limits. |

---

## 5. Technical Architecture

### 5.1 Technology Choices

**Drawflow** was selected as the visual canvas library because:
- Zero dependencies — no framework conflicts with Locker Service / Lightning Web Security
- ~30KB bundled — well within the 5MB static resource limit
- Vanilla JavaScript — works directly with LWC's `loadScript()`
- JSON import/export — maps cleanly to Salesforce Long Text Area storage
- Built-in features: drag-and-drop, zoom, modules, reroute, mobile touch, edit/view modes

**Alternatives evaluated and rejected:**
- bpmn-js: Too heavy (~500KB+), complex dependency tree, BPMN compliance not required
- Rete.js: Requires framework adapters (React/Vue), adds unnecessary coupling
- Flowy.js: Too simple — single connections only, no multiple outputs per node
- React Flow: Requires React, incompatible with LWC shadow DOM

### 5.2 Static Resource Bundling

```
Source (npm)              Build (Webpack)          Deploy (SFDX)
┌──────────────┐         ┌──────────────┐         ┌────────────────────┐
│ drawflow     │  ──→    │ UMD bundle   │  ──→    │ StaticResource     │
│ (npm package)│  webpack│ (.js + .css) │  zip    │ orchestrationEngine│
└──────────────┘         └──────────────┘         └────────────────────┘
```

Webpack config produces a UMD (Universal Module Definition) bundle that exposes `window.OrchestrationEngine` when loaded via `loadScript()`. The CSS is either inlined via style-loader or loaded separately via `loadStyle()`.

### 5.3 Execution Flow

```
Trigger (record change, API call, scheduled, manual)
    │
    ▼
OrchestrationExecutionEngine.startWorkflow(workflowId, triggerRecordId, context)
    │
    ├── Create WF_Instance__c (Status = Running)
    ├── Find Start node from WF_Step__c
    ├── Log Start step
    └── Enqueue OrchestrationQueueable(instanceId, nextNodeId)
            │
            ▼
    OrchestrationQueueable.execute()
        │
        ├── Load WF_Instance__c + WF_Step__c for current nodeId
        ├── StepHandlerFactory.getHandler(stepType)
        ├── handler.execute(step, context)
        │       │
        │       ├── [Apex Action] → dynamically invoke IOrchestrationAction
        │       ├── [Flow Launch] → Flow.Interview.createInterview()
        │       ├── [HTTP Callout] → HttpRequest via Named Credential
        │       ├── [AI Inference] → AIInferenceService.callProvider()
        │       ├── [Decision] → evaluate expression, pick output path
        │       ├── [Wait] → pause instance, subscribe to Platform Event
        │       └── [End] → mark instance Completed
        │
        ├── Update context with step output
        ├── Log Step_Log__c
        │
        ├── On SUCCESS → enqueue next step (Next_Step_Success__c)
        ├── On FAILURE → retry or enqueue failure path (Next_Step_Failure__c)
        └── On NO NEXT → mark instance Completed/Failed
```

### 5.4 AI Callout Architecture

```
AIInferenceHandler.execute(step, context)
    │
    ├── Read Config_JSON__c → get provider, model, prompts
    ├── Interpolate {{variables}} in prompt templates from context
    │
    ▼
AIInferenceService.callProvider(providerName, request)
    │
    ├── Read AI_Provider__mdt → get endpoint, auth type, named credential
    ├── Build HttpRequest:
    │   ├── OpenAI format:    { model, messages: [{role, content}], max_tokens }
    │   ├── Anthropic format: { model, messages: [{role, content}], max_tokens }
    │   └── Google format:    { contents: [{parts: [{text}]}], generationConfig }
    │
    ├── Set auth header via Named Credential (callout:NC_Name)
    ├── Send request (30s timeout)
    │
    ├── Parse response:
    │   ├── Extract content text
    │   ├── Extract token usage (prompt_tokens, completion_tokens)
    │   └── Calculate estimated cost
    │
    ├── Log AI_Usage_Log__c
    │
    └── Return StepResult with AI response in outputData
```

### 5.5 Security Model

| Concern | Mitigation |
|---------|-----------|
| API token storage | Named Credentials with External Credentials (OAuth or custom auth). Tokens never stored in custom fields, code, or Custom Settings. |
| AI prompt injection | Sanitize context variables before interpolation. Strip special characters. Limit prompt length. |
| Data exposure to AI | Configurable field-level allowlist per AI step — only explicitly selected fields are sent. PII masking option. |
| Apex security | `with sharing` on all classes. `WITH SECURITY_ENFORCED` on all SOQL. `Schema.sObjectType` checks before DML. |
| LWC security | No `innerHTML`. No `lwc:dom="manual"` unless strictly necessary. Input validation on all user-entered configs. |
| Access control | Custom Permission: `Manage_Orchestration` (design/edit), `Execute_Orchestration` (run), `View_Orchestration` (read-only). |

---

## 6. AI Provider Configuration Reference

### 6.1 OpenAI

```
AI_Provider__mdt record:
  Provider_Name__c:      "OpenAI"
  API_Endpoint__c:       "https://api.openai.com/v1/chat/completions"
  Default_Model__c:      "gpt-4o"
  Auth_Type__c:          "Bearer_Token"
  Auth_Header_Name__c:   "Authorization"
  Named_Credential__c:   "OpenAI_API"
  Max_Tokens_Default__c: 1024
  Temperature_Default__c: 0.7
  Rate_Limit_RPM__c:     60
  Is_Active__c:          true

Request format:
{
  "model": "gpt-4o",
  "messages": [
    {"role": "system", "content": "...system prompt..."},
    {"role": "user", "content": "...interpolated user prompt..."}
  ],
  "max_tokens": 1024,
  "temperature": 0.7
}

Response parsing:
  content  → response.choices[0].message.content
  tokens   → response.usage.prompt_tokens, response.usage.completion_tokens
```

### 6.2 Anthropic Claude

```
AI_Provider__mdt record:
  Provider_Name__c:      "Anthropic"
  API_Endpoint__c:       "https://api.anthropic.com/v1/messages"
  Default_Model__c:      "claude-sonnet-4-20250514"
  Auth_Type__c:          "API_Key_Header"
  Auth_Header_Name__c:   "x-api-key"
  Named_Credential__c:   "Anthropic_API"
  Max_Tokens_Default__c: 1024
  Temperature_Default__c: 0.7
  Rate_Limit_RPM__c:     60
  Is_Active__c:          true

Request format:
{
  "model": "claude-sonnet-4-20250514",
  "max_tokens": 1024,
  "system": "...system prompt...",
  "messages": [
    {"role": "user", "content": "...interpolated user prompt..."}
  ]
}

Additional required header:
  "anthropic-version": "2023-06-01"

Response parsing:
  content  → response.content[0].text
  tokens   → response.usage.input_tokens, response.usage.output_tokens
```

### 6.3 Google Gemini

```
AI_Provider__mdt record:
  Provider_Name__c:      "Google"
  API_Endpoint__c:       "https://generativelanguage.googleapis.com/v1beta/models"
  Default_Model__c:      "gemini-2.0-flash"
  Auth_Type__c:          "Custom_Header"
  Auth_Header_Name__c:   "x-goog-api-key"
  Named_Credential__c:   "Google_AI_API"
  Max_Tokens_Default__c: 1024
  Temperature_Default__c: 0.7
  Rate_Limit_RPM__c:     60
  Is_Active__c:          true

Request URL pattern:
  {endpoint}/{model}:generateContent

Request format:
{
  "contents": [
    {"parts": [{"text": "...combined system + user prompt..."}]}
  ],
  "generationConfig": {
    "maxOutputTokens": 1024,
    "temperature": 0.7
  }
}

Response parsing:
  content  → response.candidates[0].content.parts[0].text
  tokens   → response.usageMetadata.promptTokenCount, response.usageMetadata.candidatesTokenCount
```

### 6.4 Adding a Custom Provider

To add any other AI provider:

1. Create a new `AI_Provider__mdt` record with the endpoint, auth, and model details
2. Create a Named Credential with the auth token
3. Add a request builder method in `AIInferenceService.cls`:
   ```apex
   private static HttpRequest buildCustomProviderRequest(AI_Provider__mdt config, String systemPrompt, String userPrompt, Map<String, Object> options) {
       // Build provider-specific JSON body
   }
   ```
4. Add a response parser method:
   ```apex
   private static AIResponse parseCustomProviderResponse(String responseBody) {
       // Extract content and token usage
   }
   ```
5. Register in the provider routing switch — or use a generic handler if the API follows OpenAI-compatible format

---

## 7. Pre-Built Workflow Templates

### Template 1: AI Lead Qualification

```
[Start: New Lead Created]
    → [AI Inference: Score lead 1-100 based on company, title, description]
    → [Decision: Score >= 70?]
        → YES → [Apex Action: Convert to Opportunity + assign owner]
            → [Notification: Email sales rep with AI analysis]
            → [End: Qualified]
        → NO → [Apex Action: Add to nurture campaign]
            → [End: Nurture]
```

### Template 2: Intelligent Case Escalation

```
[Start: Case Status = Escalated]
    → [AI Inference: Summarize case history and suggest resolution]
    → [HTTP Callout: Check SLA status from external system]
    → [Decision: SLA breached?]
        → YES → [Notification: Page on-call manager with AI summary]
            → [Apex Action: Set Priority = Critical]
            → [End: Escalated]
        → NO → [Notification: Email assigned agent with AI suggestions]
            → [End: Suggestions Sent]
```

### Template 3: Document Analysis Pipeline

```
[Start: ContentDocument linked to record]
    → [Apex Action: Extract document text (ContentVersion)]
    → [AI Inference: Analyze document, extract key terms, classify type]
    → [AI Inference: Generate executive summary]
    → [Apex Action: Store analysis and summary on parent record]
    → [Decision: Contains compliance risk keywords?]
        → YES → [Notification: Alert compliance team]
        → NO → [End: Analysis Complete]
```

### Template 4: Multi-Step Approval with AI

```
[Start: Opportunity Amount > $100K]
    → [AI Inference: Assess deal risk based on account history, industry, amount]
    → [Decision: Risk score > 70?]
        → HIGH RISK → [Flow Launch: 3-level approval (Manager → Director → VP)]
            → [Wait: Approval completed Platform Event]
            → [Decision: Approved?]
                → YES → [Apex Action: Update stage to Negotiation]
                → NO → [Notification: Rejection email with AI risk analysis]
        → LOW RISK → [Flow Launch: 1-level approval (Manager only)]
            → [Wait: Approval completed]
            → [Apex Action: Update stage]
    → [End]
```

---

## 8. Project Phases & Milestones

| Phase | Deliverables | Estimated Effort | Dependencies |
|-------|-------------|-----------------|--------------|
| **Phase 1: Foundation** | Custom objects, CMDT, Named Credentials, Static Resource bundle | 2-3 days | Salesforce org access, npm/webpack |
| **Phase 2: Core Designer** | Designer LWC, palette, properties panel, WorkflowService | 3-5 days | Phase 1 |
| **Phase 3: Execution Engine** | All handlers, factory, Queueable chaining, step logging | 3-5 days | Phase 2 |
| **Phase 4: AI Integration** | AIInferenceService, AI handler, provider setup UI, usage logging | 3-4 days | Phase 3, AI API keys |
| **Phase 5: Advanced Features** | Viewer, dashboard, templates, retry, sub-workflows | 3-5 days | Phase 4 |
| **Phase 6: Hardening** | Tests, permissions, security review, documentation | 2-3 days | Phase 5 |

**Total estimated effort: 16-25 days**

---

## 9. Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|-----------|------------|
| Drawflow JS conflicts with Locker Service | Canvas fails to render | Low | Drawflow is vanilla JS with no DOM hacks. Tested in LWC shadow DOM. Fallback: use `lwc:dom="manual"` container. |
| AI API latency causes Queueable timeout | Step fails, instance stuck | Medium | Configurable timeout per step. AI steps use `@future(callout=true)` or dedicated Queueable with callout=true. Fallback provider on timeout. |
| Governor limits on complex workflows | Instance fails mid-execution | Medium | Monitor limits in engine. Break long workflows into sub-workflows. Use Batch Apex for bulk data steps. |
| Canvas JSON exceeds Long Text Area limit (131K chars) | Cannot save large workflows | Low | Compress JSON. For very large workflows, split into sub-workflows. Alert user when approaching limit. |
| AI token costs accumulate | Unexpected expense | Medium | Usage logging with cost estimates. Configurable daily/monthly token caps per provider in CMDT. Alert on threshold breach. |
| Named Credential token expiry | AI calls fail silently | Medium | Health check endpoint in AIInferenceService. Dashboard shows last successful call per provider. Alert on auth failures. |

---

## 10. Glossary

| Term | Definition |
|------|-----------|
| **Workflow** | A reusable automation definition — the blueprint, not a running instance |
| **Instance** | A single execution of a workflow, tied to a trigger record |
| **Step** | One node in the workflow — a discrete unit of work |
| **Context** | A JSON map of variables passed between steps during execution |
| **Handler** | An Apex class that knows how to execute a specific step type |
| **Canvas JSON** | The full Drawflow export — node positions, connections, data |
| **Node ID** | Drawflow's internal ID for a node on the canvas — links canvas to WF_Step__c |
| **Named Credential** | Salesforce's secure mechanism for storing external API credentials |
| **CMDT** | Custom Metadata Type — deployable, packageable configuration records |
| **Platform Event** | Salesforce's pub/sub messaging system used to resume paused workflows |

---

## 11. How to Use This Document

1. **Copy the Master Build Prompt** (`MASTER_BUILD_PROMPT.md`) into your AI assistant
2. Update the `[CONFIGURATION]` section with your Salesforce org details and AI provider preferences
3. Say **"start phase 1"** to begin building
4. Use this specification as the reference for requirements, data model, and architecture decisions
5. Each phase produces deployable code — test in your scratch org after each phase
6. After Phase 6, you have a production-ready orchestration engine

For questions about specific components, tell the AI: **"explain [component name]"** and reference the relevant section of this spec.
