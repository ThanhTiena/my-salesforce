---
name: create-pr
description: Stages changes, commits, pushes a feature branch, and opens a GitHub PR that triggers the validate-pr and deploy-sandbox CI pipelines. Use when the user says /pr, "create a PR", "open a pull request", or wants to commit and submit changes for review.
allowed-tools: Bash(git:*), Bash(gh:*), Read, Grep, Glob
---

# Create Pull Request — Salesforce AI Orchestrator

Commits staged/unstaged changes, pushes a feature branch, opens a PR against `main`, and lets the CI pipeline (validate-pr → deploy-sandbox) do the rest.

## PR Title Format

```
<type>(<scope>): <summary>
```

### Types

| Type       | When to use                                      |
|------------|--------------------------------------------------|
| `feat`     | New feature (LWC, Apex class, CMDT, object)      |
| `fix`      | Bug fix                                          |
| `perf`     | Performance improvement                          |
| `test`     | Adding/correcting Apex test classes              |
| `docs`     | Documentation only                               |
| `refactor` | Code restructure — no behaviour change           |
| `build`    | Webpack, npm, static resource                    |
| `ci`       | GitHub Actions workflow changes                  |
| `chore`    | Routine tasks, metadata cleanup                  |

### Scopes (optional but recommended)

| Scope        | When to use                                     |
|--------------|-------------------------------------------------|
| `apex`       | Apex classes, triggers, test classes            |
| `lwc`        | Lightning Web Components                        |
| `cmdt`       | Custom Metadata Type records                    |
| `objects`    | sObject fields, picklists, validation rules     |
| `pipeline`   | GitHub Actions workflows, composite actions     |
| `static`     | Static resources / Webpack bundle               |
| `perms`      | Permission sets                                 |
| `credentials`| Named credentials                               |

### Summary Rules

- Imperative present tense: "Add" not "Added"
- Capital first letter
- No period at the end
- Keep it under 72 characters total

### Examples

```
feat(lwc): Add AI workflow builder canvas with Drawflow
fix(apex): Handle missing config in AIStepHandlerHttp
feat(cmdt): Add OpenAI and Anthropic provider records
build(static): Bundle Drawflow UMD via Webpack
ci(pipeline): Split validate-pr and deploy-sandbox workflows
test(apex): Add AIExecutionMonitorControllerTest
chore(objects): Update Step_Type__c picklist to handler keys
```

---

## Steps

### 1. Understand what the user wants to commit

- If the user described specific files or a scope, use only those.
- Otherwise, inspect full diff: `git status` + `git diff --stat`.

### 2. Determine branch name

- If already on a feature branch (not `main`), stay on it.
- If on `main`, derive a branch name from the changes:
  - Format: `<type>/<short-description>` e.g. `feat/ai-workflow-phase-5`
  - Create it: `git checkout -b <branch-name>`

### 3. Stage and commit

Stage relevant files (prefer explicit paths over `git add .`):
```bash
git add <files...>
```

Commit with a message that matches the PR title format:
```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <summary>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

### 4. Push branch

```bash
git push -u origin HEAD
```

### 5. Create PR

```bash
gh pr create \
  --base main \
  --title "<type>(<scope>): <summary>" \
  --body "$(cat <<'EOF'
## Summary

<!-- What does this PR do? How should reviewers test it? -->

## Changes

<!-- Bullet list of what changed -->

## Salesforce Deployment

- **Validate PR** job runs `sf project deploy --dry-run` against sandbox on open/push
- **Deploy to Sandbox** job deploys automatically on merge to `main`
- **Deploy to Production** is manual — trigger from Actions tab after sandbox is verified

## Checklist

- [ ] Apex test classes included or existing tests still pass
- [ ] No hardcoded credentials or org-specific IDs
- [ ] Static resource rebuilt if LWC or Webpack source changed
- [ ] Named credentials / CMDT records documented if added
EOF
)"
```

---

## CI Pipeline Behaviour After PR Opens

| Event | Workflow | What happens |
|-------|----------|--------------|
| PR opened / push to PR branch | `validate-pr.yml` | Detects changes, builds assets if needed, runs `sf project deploy --dry-run`, posts result comment to PR |
| Merge to `main` | `deploy-sandbox.yml` | Builds assets if needed, deploys to sandbox org with `RunLocalTests` (if Apex changed) |
| Manual trigger | `deploy-production.yml` | Requires `production` environment approval, runs `RunAllTestsInOrg` |

The validate-pr workflow uses `dorny/paths-filter` scoped to `sf-ai-orchestrator/**` — changes outside that path do not trigger a Salesforce validation.

---

## Full Execution (what to actually run)

```bash
# 1. See what's changed
git status
git diff --stat

# 2. Create branch (if on main)
git checkout -b feat/my-feature

# 3. Stage files
git add sf-ai-orchestrator/force-app/...

# 4. Commit
git commit -m "feat(apex): Add AIStepHandlerWait with governor limit guard

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

# 5. Push
git push -u origin HEAD

# 6. Open PR
gh pr create --base main --title "feat(apex): Add AIStepHandlerWait with governor limit guard" --body "..."

# 7. Watch CI
gh pr checks --watch
```