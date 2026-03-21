# Agent Memory Index

> This file is the index. Do not write memory content here — write it in dedicated files and link below.
> Lines after 200 are truncated. Keep this concise.

---

## Project Memories

| File | Type | Description |
|------|------|-------------|
| [skills/developer.md](skills/developer.md) | user | Salesforce Developer skill matrix by phase |
| [skills/architect.md](skills/architect.md) | user | Salesforce Architect skill matrix by phase |
| [skills/ba.md](skills/ba.md) | user | Business Analyst skill matrix by phase |
| [skills/product-owner.md](skills/product-owner.md) | user | Product Owner skill matrix by phase |
| [skills/skill-gaps.md](skills/skill-gaps.md) | project | Cross-role skill gap register with risk levels |
| [roles/developer.md](roles/developer.md) | user | Developer responsibilities, ownership, decisions |
| [roles/architect.md](roles/architect.md) | user | Architect responsibilities, ownership, decisions |
| [roles/ba.md](roles/ba.md) | user | BA responsibilities, ownership, decisions |
| [roles/product-owner.md](roles/product-owner.md) | user | PO responsibilities, ownership, decisions |

---

## Key Project Facts

- Phase 1 (Foundation): ✅ Complete — objects, fields, Apex engine, AI adapters, 1 LWC monitor deployed
- Phase 2 (Core Designer): 🔄 In Progress — WorkflowService + designer LWC being built now
- Engine entry point: `AIWorkflowOrchestrator.executeAsync(workflowId, triggerRecordId)`
- Queueable: `AIWorkflowQueueable` chains steps; retry count passed as constructor arg
- AI dispatch: `AIInferenceService.run(request)` → adapter pattern → `AIProviderAdapter` interface
- Adapters built: OpenAI, Anthropic, Google, AzureOpenAI, Cohere, Mistral
- Security util: `AISecurityUtil` — sanitisePrompt, assertReadable, assertUpdatable, assertFieldsWritable
- Objects: AI_Workflow__c → AI_Step__c (master-detail), AI_Execution__c (lookup to workflow), AI_Step_Execution__c (master-detail to execution)
- CMDT: AI_Provider__mdt — queried by DeveloperName, never stores tokens

---

## Feedback Rules

- Keep all Apex `with sharing`; use inner `without sharing` class only for audit writes
- Never store API keys in fields — Named Credentials only
- Always sanitise prompts via `AISecurityUtil.sanitisePrompt()` before dispatch
- SFDX field files: each field = its own `.field-meta.xml`, never inline in object file
- `<required>` tag must be omitted from MasterDetail fields (Salesforce rejects it)
- LWC: no `innerHTML`, no `eval`, all user input validated before Apex call