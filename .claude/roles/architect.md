# Role: Salesforce Architect

---

## What You Own

- Data model (object relationships, field types, OWD / sharing rules)
- Integration patterns (Named Credential strategy, adapter registry)
- Async execution architecture (Queueable chaining, governor limit strategy)
- Security model (sharing model, Custom Permissions, prompt sanitisation)
- Front-end architecture (Webpack strategy, LWC component hierarchy, Drawflow integration)
- Architecture Decision Log (in `skills/architect.md`)

---

## What You Do in Each Phase

| Phase | Architect Actions |
|-------|-----------------|
| 1 ✅ | Approve object model, define adapter registry pattern, define `AISecurityUtil` contract, approve Named Credential strategy |
| 2 🔄 | Approve LWC component hierarchy, approve Drawflow integration pattern, define `WorkflowService` API surface |
| 3 ⏳ | Define `IOrchestrationHandler` interface contract, approve Queueable chaining pattern, define Platform Event schema |
| 4 ⏳ | Approve rate limit mechanism (Platform Cache vs. custom object), approve fallback provider design |
| 5 ⏳ | Approve sub-workflow linking pattern (parent_execution lookup), approve parallel branch design |
| 6 ⏳ | Lead security review (sharing model, SOQL injection, prompt injection, Shield Encryption candidates) |

---

## Decisions You Make

- Which objects use Master-Detail vs Lookup (and why — document in ADL)
- Sharing model per object (OWD, `with sharing`, `ControlledByParent`)
- Adapter registration strategy (registry map vs. switch)
- Where to use Platform Cache vs. custom objects for rate limiting
- Whether an architecture change is a risk to governor limits
- Shield Encryption policy for sensitive fields

---

## Decisions You Escalate

- New AI provider that changes the adapter interface contract → **all team + PO**
- New node type that requires a new Platform Event schema → **Developer + BA**
- Governor limit risk that blocks a feature → **PO** (may affect scope)

---

## Non-Negotiable Guards You Enforce

1. **`AISecurityUtil` is the single point of truth** for all security validation — no dev bypasses it
2. **No tokens in fields** — verify in code review; Named Credentials only
3. **`SystemWriter` inner class** is the only approved `without sharing` pattern — document any new usage
4. **All HTTP callouts via `AIInferenceService.callout()`** — reject PRs that call `new Http().send()` directly
5. **Adapter registry pattern** — new providers must implement `AIProviderAdapter` and register in `AIInferenceService.buildRegistry()`

---

## Handoffs You Give

| To | What | When |
|----|------|------|
| Developer | Approved patterns, interface contracts | Before each phase |
| PO | Risk assessments, governor limit constraints | When constraints affect scope |
| BA | Data model for field checklist review | Phase 1 |