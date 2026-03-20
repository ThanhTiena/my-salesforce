#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Deploy AI Orchestration package to a Salesforce org
#
# Usage:
#   ./scripts/deploy.sh [org-alias] [--check-only]
#
# Examples:
#   ./scripts/deploy.sh my-sandbox
#   ./scripts/deploy.sh my-sandbox --check-only   # validate only, no deploy
#
# Prerequisites:
#   - Salesforce CLI (sf) installed
#   - Target org authenticated: sf org login web --alias my-sandbox
# =============================================================================

set -euo pipefail

ORG_ALIAS="${1:-}"
CHECK_ONLY="${2:-}"

if [ -z "$ORG_ALIAS" ]; then
  echo "ERROR: Provide an org alias as the first argument."
  echo "  Usage: ./scripts/deploy.sh <org-alias> [--check-only]"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_DIR="$ROOT_DIR/force-app"

echo "=================================================="
echo "  AI Orchestration Package Deploy"
echo "  Org:        $ORG_ALIAS"
echo "  Source:     $DEPLOY_DIR"
echo "  Check Only: ${CHECK_ONLY:--}"
echo "=================================================="

# ── 1. Pre-flight: verify CLI ─────────────────────────────────────────────────
if ! command -v sf &>/dev/null; then
  echo "ERROR: Salesforce CLI (sf) not found. Install from https://developer.salesforce.com/tools/salesforcecli"
  exit 1
fi

# ── 2. Deploy ─────────────────────────────────────────────────────────────────
DEPLOY_FLAGS="--source-dir $DEPLOY_DIR --target-org $ORG_ALIAS --test-level RunLocalTests"

if [ "$CHECK_ONLY" = "--check-only" ]; then
  DEPLOY_FLAGS="$DEPLOY_FLAGS --dry-run"
fi

echo ""
echo "Running: sf project deploy start $DEPLOY_FLAGS"
sf project deploy start $DEPLOY_FLAGS

echo ""
echo "✓ Deploy completed successfully."

# ── 3. Run tests ──────────────────────────────────────────────────────────────
if [ "$CHECK_ONLY" != "--check-only" ]; then
  echo ""
  echo "Running Apex tests..."
  sf apex run test \
    --target-org "$ORG_ALIAS" \
    --class-names AISecurityUtilTest,AIInferenceServiceTest,AIPromptTemplateServiceTest \
    --result-format human \
    --synchronous
fi
