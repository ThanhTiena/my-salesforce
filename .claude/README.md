# .claude/ — Project Intelligence Hub

This folder is read by the Claude Code agent at the start of every session.
It contains project memory, role skill matrices, progress tracking, and agent instructions.

---

## Folder Structure

```
.claude/
├── README.md                  ← You are here — start here
├── MEMORY.md                  ← Agent memory index (auto-updated)
├── settings.local.json        ← Claude Code permission settings
│
├── skills/                    ← Skill matrices by role
│   ├── developer.md           ← Salesforce Developer skills by phase
│   ├── architect.md           ← Salesforce Architect skills by phase
│   ├── ba.md                  ← Business Analyst skills by phase
│   ├── product-owner.md       ← Product Owner skills by phase
│   └── skill-gaps.md          ← Cross-role gap analysis & risk register
│
└── roles/                     ← Role definitions & responsibilities
    ├── developer.md           ← What the developer owns, does, and decides
    ├── architect.md           ← What the architect owns, does, and decides
    ├── ba.md                  ← What the BA owns, does, and decides
    └── product-owner.md       ← What the PO owns, does, and decides
```

---

## Agent Quick-Start

When Claude Code starts a new session on this project:

1. Read `MEMORY.md` — loads project context and feedback rules
2. Read `roles/<your-role>.md` — understand ownership boundaries
3. Check `../PROGRESS.md` — find the first `⏳ Not Started` task
4. Verify the task's **Income** prerequisites are met
5. Execute using the **Next Action** column
6. Mark done, update progress %, move to next task

---

## Project At-a-Glance

| Item | Value |
|------|-------|
| **Product** | Salesforce AI Orchestration Engine |
| **Stack** | Apex · LWC · Queueable · CMDT · Named Credentials |
| **AI Providers** | OpenAI · Anthropic · Google Gemini · Azure OpenAI · Cohere · Mistral |
| **Canvas** | Drawflow (vanilla JS, UMD bundle via Webpack) |
| **Current Phase** | Phase 2 — Core Designer LWC |
| **Progress Tracker** | `../PROGRESS.md` |
| **Field Checklist** | `../sf-ai-orchestrator/FIELDS_TO_CREATE.md` |
| **Spec** | `../project-design/PROJECT_SPECIFICATION.md` |