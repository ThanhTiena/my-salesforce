# Quick-Start Guide — How to Use These Documents

## You have 2 files:

### 1. MASTER_BUILD_PROMPT.md (The Prompt)
→ **Copy-paste this into any AI assistant** (Claude, ChatGPT, Gemini, Copilot)
→ It tells the AI exactly what to build, how to build it, and in what order
→ Edit the `[CONFIGURATION]` block at the top with your org details first
→ Then say "start phase 1" and the AI will begin generating deployable code

### 2. PROJECT_SPECIFICATION.md (The Reference)
→ **Keep this open as your reference** while building
→ Contains the full data model, AI provider configs, security model, templates
→ Share with your team for alignment on architecture decisions
→ Use it to answer "why did we do it this way?" questions

---

## Step-by-step workflow:

```
1. Edit MASTER_BUILD_PROMPT.md [CONFIGURATION] section
   ↓
2. Paste the entire prompt into your AI assistant
   ↓
3. Say: "start phase 1"
   ↓
4. AI generates: custom objects, CMDT, Named Credentials, Webpack bundle
   ↓
5. Deploy to scratch org, verify
   ↓
6. Say: "start phase 2"
   ↓
7. AI generates: LWC designer, palette, properties panel, WorkflowService
   ↓
8. Deploy, test the visual designer
   ↓
9. Repeat for phases 3-6
   ↓
10. Production-ready orchestration engine
```

## Key commands you can give the AI:

| Command | What it does |
|---------|-------------|
| `start phase N` | Builds all code for that phase |
| `show me the SFDX structure` | Outputs the full directory tree |
| `generate the bundle` | Creates the Webpack project + zip instructions |
| `create template: Lead Qualification` | Generates a pre-built workflow template |
| `add AI provider: Mistral` | Adds a new AI provider config + code |
| `explain AIInferenceService` | Deep-dive explanation of that component |

## AI provider setup (do this before Phase 4):

1. Get API keys from: OpenAI, Anthropic, Google AI, or your custom provider
2. In Salesforce Setup → Named Credentials → create one per provider
3. The prompt will guide the AI to generate the exact CMDT records needed
