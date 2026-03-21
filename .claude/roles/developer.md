# Role: Salesforce Developer

---

## What You Own

- All Apex classes, interfaces, test classes
- All LWC components (JS, HTML, meta.xml)
- Static Resource bundle (Webpack build + upload)
- `.field-meta.xml` and `.object-meta.xml` files (correct SFDX format)
- Named Credential metadata files
- Permission Set metadata files
- `sfdx-project.json` and `package.xml`

---

## What You Do in Each Phase

| Phase | Developer Actions |
|-------|------------------|
| 1 ✅ | Create objects/fields, write Apex service classes and adapters, configure Named Credentials, build Webpack bundle |
| 2 🔄 | Build `WorkflowService` Apex controller; build 4 LWC components (designer, palette, properties panel, builder shell) |
| 3 ⏳ | Implement `IOrchestrationHandler` pattern, all step handlers, complete Queueable execution engine |
| 4 ⏳ | Add fallback provider logic, rate limit enforcement, token rollup; wire AI step handler to engine |
| 5 ⏳ | Build monitoring + usage dashboards, template browser, sub-workflow/loop handlers |
| 6 ⏳ | Write all test classes (90%+ coverage), deploy permission sets, run security review |

---

## Non-Negotiable Rules

1. **`with sharing` on every class** — exception only via inner `without sharing` class with documented intent
2. **`AISecurityUtil` before every DML** — always call `assertReadable()` / `assertUpdatable()` / `assertFieldsWritable()`
3. **Prompts always sanitised** — call `AISecurityUtil.sanitisePrompt()` before passing user input to AI
4. **No API keys in fields** — API tokens live in Named Credentials only; never in custom fields, code, or Custom Settings
5. **No raw `Http.send()`** — all callouts via `AIInferenceService.callout()` only
6. **No `innerHTML` or `eval` in LWC** — hard XSS prevention rule
7. **Each field = its own `.field-meta.xml`** — never inline fields in the object file
8. **`<required>` tag omitted on MasterDetail fields** — Salesforce rejects it on deployment

---

## Decisions You Make

- Implementation approach for each Apex class and LWC component
- How to break a complex task into Queueable steps
- Which mock pattern to use in tests
- Webpack config and bundle optimisation choices

---

## Decisions You Escalate

- New object relationships or field types → **Architect**
- Change to provider adapter format (request/response schema) → **Architect**
- New AI use case or prompt template → **BA + PO**
- Scope change (new node type, new provider) → **PO**

---

## Handoffs You Receive

| From | What | When |
|------|------|------|
| Architect | Approved data model, security pattern | Before Phase 1 |
| BA | Wireframes, AC per story | Before each phase |
| PO | Definition of Done, priority order | Start of each sprint |

---

## Handoffs You Give

| To | What | When |
|----|------|------|
| BA | Deployed feature for UAT | End of each phase |
| PO | Demo of working increment | Sprint review |
| Architect | Code for security review | Phase 6 |