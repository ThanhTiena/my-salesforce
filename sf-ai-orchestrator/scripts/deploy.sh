#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Deploy AI Orchestration package to a Salesforce org
#
# Usage:
#   ./scripts/deploy.sh <org-alias> [options]
#
# Options:
#   --check-only          Validate only (no deploy). Always runs tests.
#   --no-tests            Skip Apex tests during deploy AND post-deploy run.
#   --run-tests           Run Apex tests during deploy (default).
#
# Examples:
#   ./scripts/deploy.sh my-dev                         # deploy + run tests
#   ./scripts/deploy.sh my-dev --no-tests              # deploy, skip tests
#   ./scripts/deploy.sh my-dev --check-only            # validate + run tests
#   ./scripts/deploy.sh my-dev --check-only --no-tests # validate, skip tests
#
# Prerequisites:
#   - Salesforce CLI (sf) installed
#   - Target org authenticated: sf org login web --alias <org-alias>
# =============================================================================

set -euo pipefail

# ── All test classes in the package ──────────────────────────────────────────
ALL_TEST_CLASSES=(
  AIExecutionAlertHandlerTest
  AIExecutionMonitorControllerTest
  AIInferenceServiceTest
  AIPromptTemplateServiceTest
  AIRateLimitServiceTest
  AISecurityUtilTest
  AIStepHandlerDecisionTest
  AIStepHandlerHttpTest
  AIStepHandlerLoopTest
  AIStepHandlerNotificationTest
  AIStepHandlerPassthroughTest
  AIStepHandlerRegistryTest
  AIStepHandlerSubflowTest
  AIStepHandlerWaitTest
  AIStepResultTest
  MongoDBLogServiceTest
  WorkflowTemplateServiceTest
)

# ── Argument parsing ──────────────────────────────────────────────────────────
ORG_ALIAS=""
CHECK_ONLY=false
RUN_TESTS=true

for arg in "$@"; do
  case "$arg" in
    --check-only) CHECK_ONLY=true ;;
    --no-tests)   RUN_TESTS=false ;;
    --run-tests)  RUN_TESTS=true  ;;
    --*)
      echo "ERROR: Unknown option: $arg"
      echo "  Valid options: --check-only  --no-tests  --run-tests"
      exit 1
      ;;
    *) ORG_ALIAS="$arg" ;;
  esac
done

if [ -z "$ORG_ALIAS" ]; then
  echo "ERROR: Org alias is required as the first argument."
  echo "  Usage: ./scripts/deploy.sh <org-alias> [--check-only] [--no-tests]"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEPLOY_DIR="$ROOT_DIR/force-app"
TEST_CLASSES_CSV=$(IFS=,; echo "${ALL_TEST_CLASSES[*]}")

# ── Banner ────────────────────────────────────────────────────────────────────
echo "=================================================="
echo "  AI Orchestration Package Deploy"
echo "  Org:        $ORG_ALIAS"
echo "  Source:     $DEPLOY_DIR"
echo "  Check Only: $CHECK_ONLY"
echo "  Run Tests:  $RUN_TESTS"
echo "=================================================="

# ── Pre-flight: verify CLI ────────────────────────────────────────────────────
if ! command -v sf &>/dev/null; then
  echo "ERROR: Salesforce CLI (sf) not found."
  echo "  Install from https://developer.salesforce.com/tools/salesforcecli"
  exit 1
fi

# ── Build deploy command ──────────────────────────────────────────────────────
DEPLOY_CMD="sf project deploy start \
  --source-dir \"$DEPLOY_DIR\" \
  --target-org \"$ORG_ALIAS\""

if [ "$CHECK_ONLY" = true ]; then
  DEPLOY_CMD="$DEPLOY_CMD --dry-run"
fi

if [ "$RUN_TESTS" = true ]; then
  DEPLOY_CMD="$DEPLOY_CMD \
  --test-level RunSpecifiedTests \
  --tests $TEST_CLASSES_CSV"
else
  DEPLOY_CMD="$DEPLOY_CMD --test-level NoTestRun"
fi

# ── Deploy ────────────────────────────────────────────────────────────────────
echo ""
echo "Running: $DEPLOY_CMD"
eval "$DEPLOY_CMD"

echo ""
echo "✓ Deploy completed successfully."

# ── Post-deploy test run (skipped for --check-only or --no-tests) ─────────────
if [ "$CHECK_ONLY" = false ] && [ "$RUN_TESTS" = true ]; then
  echo ""
  echo "Running post-deploy Apex test suite..."
  sf apex run test \
    --target-org "$ORG_ALIAS" \
    --class-names "$TEST_CLASSES_CSV" \
    --result-format human \
    --synchronous
  echo ""
  echo "✓ All tests passed."
fi
