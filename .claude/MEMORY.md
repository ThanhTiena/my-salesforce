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
| [skills/devops.md](skills/devops.md) | user | Senior DevOps skill matrix — GitHub Actions, SF CI/CD, caching, secrets, Webpack |
| [skills/skill-gaps.md](skills/skill-gaps.md) | project | Cross-role skill gap register with risk levels |
| [roles/developer.md](roles/developer.md) | user | Developer responsibilities, ownership, decisions |
| [roles/architect.md](roles/architect.md) | user | Architect responsibilities, ownership, decisions |
| [roles/ba.md](roles/ba.md) | user | BA responsibilities, ownership, decisions |
| [roles/product-owner.md](roles/product-owner.md) | user | PO responsibilities, ownership, decisions |
| [roles/devops.md](roles/devops.md) | user | DevOps responsibilities, pipeline rules, decisions |

---

## Key Project Facts

- Phase 1 (Foundation): ✅ Complete — objects, fields, Apex engine, AI adapters, 1 LWC monitor deployed
- Phase 2 (Core Designer): 🔄 In Progress — WorkflowService + designer LWC built; pipeline rebuilt
- Engine entry point: `AIWorkflowOrchestrator.executeAsync(workflowId, triggerRecordId)`
- Queueable: `AIWorkflowQueueable` chains steps; retry count passed as constructor arg
- AI dispatch: `AIInferenceService.run(request)` → adapter pattern → `AIProviderAdapter` interface
- Adapters built: OpenAI, Anthropic, Google, AzureOpenAI, Cohere, Mistral
- Security util: `AISecurityUtil` — sanitisePrompt, assertReadable, assertUpdatable, assertFieldsWritable
- Objects: AI_Workflow__c → AI_Step__c (master-detail), AI_Execution__c (lookup to workflow), AI_Step_Execution__c (master-detail to execution)
- CMDT: AI_Provider__mdt — queried by DeveloperName, never stores tokens
- SF API version: 62.0 (must match sfdx-project.json and pipeline env var SF_API_VERSION)

---

## Pipeline Architecture (GitHub Actions)

- `validate-pr.yml` — PR gate; cancels stale runs; `dorny/paths-filter` for change detection
- `deploy-sandbox.yml` — triggers on merge to main; queues (no cancel-in-progress)
- `deploy-production.yml` — manual only; requires "production" environment approval
- `.github/actions/setup-salesforce/` — composite action; Node.js + SF CLI with 2-layer cache
- `.github/actions/build-static-resource/` — Webpack build + zip → .resource file
- Static resource (orchestrationEngine) MUST be built before deploying LWC that imports it
- Old `cicd.yml` archived — do not edit; replaced by the split workflow files above

---

## Feedback Rules

- Keep all Apex `with sharing`; use inner `without sharing` class only for audit writes
- Never store API keys in fields — Named Credentials only
- Always sanitise prompts via `AISecurityUtil.sanitisePrompt()` before dispatch
- SFDX field files: each field = its own `.field-meta.xml`, never inline in object file
- `<required>` tag must be omitted from MasterDetail fields (Salesforce rejects it)
- LWC: no `innerHTML`, no `eval`, all user input validated before Apex call
- Pipeline: never log secrets; JWT key written to file then `rm -f` in same step
- Pipeline: `SF_API_VERSION` must stay `62.0` — do not bump to 64.0