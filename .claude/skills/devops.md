---
name: Senior DevOps Skill Matrix
description: CI/CD, GitHub Actions, cloud platforms, Salesforce pipeline, infra and secrets management skills by phase
type: user
---

# Senior DevOps — Skill Matrix

## Core Competency Areas

### 1. GitHub Actions (Expert)
| Skill | Proficiency | Notes |
|-------|-------------|-------|
| Workflow triggers (push/PR/schedule/dispatch) | Expert | path filters, event types, concurrency groups |
| Reusable workflows (`workflow_call`) | Expert | `inputs`, `secrets: inherit`, outputs |
| Composite actions | Expert | multi-step, caching patterns, `action.yml` |
| Matrix strategy | Advanced | env matrix, `include/exclude`, `fail-fast: false` |
| Environment protection rules | Advanced | required reviewers, deployment gates |
| Concurrency groups | Expert | cancel-in-progress, per-branch/per-env slots |
| OIDC token auth | Advanced | AWS, GCP, Azure — no long-lived secrets |
| Artifact upload/download | Expert | `actions/upload-artifact@v4`, cross-job sharing |
| Caching strategy | Expert | `actions/cache@v4`, multi-layer, restore-keys |
| Job dependencies (`needs`) | Expert | conditional job skipping, fan-out/fan-in |
| Self-hosted runners | Intermediate | runner groups, labels, network access |
| Workflow visualization | Advanced | job summaries, `$GITHUB_STEP_SUMMARY` |

### 2. Salesforce-Specific CI/CD (Expert)
| Skill | Proficiency | Notes |
|-------|-------------|-------|
| JWT-based org auth (`sf org login jwt`) | Expert | server.key from secret, alias, set-default |
| Delta deployment (`sf project deploy`) | Expert | `sgd` (Salesforce Git Delta), manifest-based |
| Scratch org provisioning | Advanced | `sf org create scratch`, pool strategies |
| Apex test execution & parsing | Expert | `RunLocalTests`, `RunSpecifiedTests`, exit code handling |
| Static resource build pipeline | Expert | Webpack → zip → staticresource deploy |
| SFDX project structure | Expert | `sfdx-project.json`, packageDirectories, sub-projects |
| Named Credential deployment | Advanced | deploy before dependent classes |
| CMDT record deployment | Advanced | `.md-meta.xml`, ordering with `--pre-destructive-changes` |
| Destructive changes | Advanced | `destructiveChanges.xml`, pre vs post |
| Deployment validation (`--dry-run`) | Expert | PR gate, separate from deploy job |

### 3. Caching & Performance (Advanced)
| Skill | Proficiency | Notes |
|-------|-------------|-------|
| npm global cache (`~/.npm`) | Expert | keyed on OS + node-version + lock hash |
| SF CLI config cache | Expert | `~/.config/sf`, restore-keys fallback |
| Node modules cache | Expert | `node_modules` vs `~/.npm` tradeoffs |
| Webpack build cache | Advanced | `cache-loader`, `babel-loader` caching |
| Cache invalidation strategy | Expert | lock file hash in key, date-scoped restore keys |
| Cache size management | Intermediate | max 10GB per repo, eviction awareness |

### 4. Secrets & Security (Expert)
| Skill | Proficiency | Notes |
|-------|-------------|-------|
| GitHub Secrets (repo/env/org level) | Expert | env secrets for deployment gates |
| OIDC vs long-lived secrets | Advanced | prefer OIDC where supported |
| JWT key handling | Expert | write to file, use, rm immediately — never log |
| Secret masking | Expert | `add-mask`, never echo secrets |
| Environment-scoped secrets | Expert | `SF_SANDBOX_*` vs `SF_PROD_*` per env |
| Least-privilege permissions | Expert | minimal `permissions:` block per workflow |

### 5. Pipeline Architecture (Expert)
| Skill | Proficiency | Notes |
|-------|-------------|-------|
| Separation of concerns (validate/build/deploy) | Expert | one job = one responsibility |
| Fan-out parallelism | Advanced | parallel test shards, parallel org targets |
| Fail-fast vs continue-on-error | Expert | per step vs per job strategy |
| Reusable workflow composition | Expert | call-stack: main → reusable → composite action |
| Environment promotion model | Expert | sandbox → staging → production gates |
| Pipeline observability | Advanced | step summaries, Slack webhooks, PR comments |
| Idempotent deployments | Expert | re-run safely, no duplicate side effects |
| Monorepo path filtering | Expert | `paths:` trigger, `dorny/paths-filter` |

### 6. Build Tooling (Advanced)
| Skill | Proficiency | Notes |
|-------|-------------|-------|
| Webpack (UMD bundles) | Advanced | externals, output.library, libraryTarget: 'umd' |
| npm scripts | Expert | `build`, `build:sf`, `ci` scripts in package.json |
| Node.js version management | Expert | `actions/setup-node@v4`, `.nvmrc` |
| zip/archive for Static Resource | Expert | `zip -r staticresource.resource dist/` |
| Asset fingerprinting | Intermediate | content hash in filename |

### 7. Cloud Platform Concepts (Intermediate)
| Skill | Proficiency | Notes |
|-------|-------------|-------|
| AWS IAM / OIDC federation | Intermediate | role assumption for GitHub Actions |
| GCP Workload Identity | Intermediate | OIDC token → service account |
| Azure Service Principals | Intermediate | OIDC or client secret for pipeline auth |
| IaC basics (Terraform) | Intermediate | state, modules, workspace per env |
| Container basics (Docker) | Intermediate | custom runner images, multi-stage builds |

---

## Phase Readiness Checklist

### Phase 1 (Foundation) ✅
- [x] JWT auth workflow for validation org
- [x] Composite action for SF CLI setup with caching
- [x] Basic validate + deploy job sequence

### Phase 2 (Core Designer) 🔄
- [x] Sub-project path filtering (`sf-ai-orchestrator/**`)
- [ ] **Webpack build step for Static Resource (orchestrationEngine)**
- [ ] Static resource must deploy before LWC that imports it
- [ ] Concurrency groups to cancel stale PR runs
- [ ] API version aligned with `sfdx-project.json` (62.0, not 64.0)

### Phase 3 (Execution Engine)
- [ ] Queueable/callout test isolation (separate test class filter)
- [ ] Environment matrix: sandbox + staging
- [ ] Delta deployment to reduce deploy time

### Phase 4 (AI Inference)
- [ ] Named Credential deployment step (must precede class deploy)
- [ ] CMDT record deployment for AI_Provider__mdt
- [ ] Token cost alerting hook (post-deploy smoke test)

### Phase 5 (Monitoring & Templates)
- [ ] Production environment gate (required reviewer)
- [ ] Scratch org regression workflow (nightly)
- [ ] Deployment report to PR comment

### Phase 6 (UAT & Release)
- [ ] Full test suite (`RunAllTestsInOrg`) gate before production
- [ ] Pre-destructive changes for deprecated fields
- [ ] Release tag automation