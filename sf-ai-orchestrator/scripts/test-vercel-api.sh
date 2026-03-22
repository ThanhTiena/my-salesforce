#!/usr/bin/env bash
# test-vercel-api.sh
#
# End-to-end tests for the Salesforce → Vercel → MongoDB REST API.
#
# Usage:
#   export VERCEL_URL="https://your-app.vercel.app"
#   export SALESFORCE_API_KEY="your-key"
#   bash scripts/test-vercel-api.sh
#
# Or pass inline:
#   VERCEL_URL=https://your-app.vercel.app SALESFORCE_API_KEY=abc123 bash scripts/test-vercel-api.sh

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

BASE_URL="${VERCEL_URL:?Set VERCEL_URL, e.g. https://your-app.vercel.app}"
API_KEY="${SALESFORCE_API_KEY:?Set SALESFORCE_API_KEY}"

# A stable test record ID used across tests
TEST_RECORD_ID="TEST_SF_$(date +%s)"

# ── Helpers ───────────────────────────────────────────────────────────────────

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ PASS${NC} $1"; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; FAILURES=$((FAILURES + 1)); }
info() { echo -e "${YELLOW}──${NC} $1"; }

FAILURES=0

# Execute a curl call and capture status + body separately
call() {
  local method="$1" path="$2"
  shift 2
  # remaining args forwarded to curl (e.g. -d '...')
  HTTP_RESPONSE=$(curl -s -w "\n__STATUS__%{http_code}" \
    -X "$method" \
    -H "x-api-key: $API_KEY" \
    -H "Content-Type: application/json" \
    "$BASE_URL$path" "$@")
  HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1 | sed 's/__STATUS__//')
  HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d' | sed 's/__STATUS__.*//')
}

assert_status() {
  local expected="$1" label="$2"
  if [ "$HTTP_STATUS" -eq "$expected" ]; then
    pass "$label (HTTP $HTTP_STATUS)"
  else
    fail "$label — expected HTTP $expected, got HTTP $HTTP_STATUS"
    echo "     Body: $HTTP_BODY"
  fi
}

assert_body_contains() {
  local key="$1" label="$2"
  if echo "$HTTP_BODY" | grep -q "\"$key\""; then
    pass "$label (found \"$key\" in response)"
  else
    fail "$label — \"$key\" not found in body"
    echo "     Body: $HTTP_BODY"
  fi
}

# ── Tests ─────────────────────────────────────────────────────────────────────

echo ""
echo "============================================"
echo "  Vercel API End-to-End Tests"
echo "  $BASE_URL"
echo "============================================"
echo ""

# ── 1. Auth checks ────────────────────────────────────────────────────────────

info "1. Authentication"

# Missing key → 401
HTTP_RESPONSE=$(curl -s -w "\n__STATUS__%{http_code}" \
  -X POST -H "Content-Type: application/json" \
  "$BASE_URL/api/salesforce/logs" \
  -d '{"action":"test","level":"info","message":"no key"}')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1 | sed 's/__STATUS__//')
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d' | sed 's/__STATUS__.*//')
assert_status 401 "Missing x-api-key returns 401"

# Wrong key → 401
HTTP_RESPONSE=$(curl -s -w "\n__STATUS__%{http_code}" \
  -X POST -H "Content-Type: application/json" -H "x-api-key: wrong-key" \
  "$BASE_URL/api/salesforce/logs" \
  -d '{"action":"test","level":"info","message":"wrong key"}')
HTTP_STATUS=$(echo "$HTTP_RESPONSE" | tail -n1 | sed 's/__STATUS__//')
HTTP_BODY=$(echo "$HTTP_RESPONSE" | sed '$d' | sed 's/__STATUS__.*//')
assert_status 401 "Wrong x-api-key returns 401"

# ── 2. POST /api/salesforce/logs ─────────────────────────────────────────────

info "2. POST /api/salesforce/logs"

# Valid log entry
call POST /api/salesforce/logs \
  -d "{
    \"action\":       \"sync\",
    \"level\":        \"info\",
    \"message\":      \"Test log from CI\",
    \"sfOrgId\":      \"00Dxx0000001TEST\",
    \"sfUserId\":     \"005xx000001SvTEST\",
    \"sfObjectType\": \"Account\",
    \"sfRecordId\":   \"$TEST_RECORD_ID\",
    \"sfRecordName\": \"Test Corp\",
    \"payload\":      {\"source\": \"test-script\"}
  }"
assert_status 201 "Write log entry returns 201"
assert_body_contains "logId" "Response contains logId"
LOG_ID=$(echo "$HTTP_BODY" | grep -o '"logId":"[^"]*"' | cut -d'"' -f4)
info "  logId: $LOG_ID"

# Missing required field: action
call POST /api/salesforce/logs \
  -d '{"level":"info","message":"missing action"}'
assert_status 400 "Missing 'action' returns 400"

# Invalid level value
call POST /api/salesforce/logs \
  -d '{"action":"sync","level":"verbose","message":"bad level"}'
assert_status 400 "Invalid 'level' value returns 400"

# Error level log
call POST /api/salesforce/logs \
  -d "{
    \"action\":  \"callout\",
    \"level\":   \"error\",
    \"message\": \"Callout failed: connection timeout\",
    \"sfOrgId\": \"00Dxx0000001TEST\",
    \"payload\": {\"httpStatus\": 504, \"provider\": \"OpenAI\"}
  }"
assert_status 201 "Write error-level log returns 201"

# ── 3. POST /api/salesforce/records ──────────────────────────────────────────

info "3. POST /api/salesforce/records (upsert)"

# Insert new record
call POST /api/salesforce/records \
  -d "{
    \"sfRecordId\":   \"$TEST_RECORD_ID\",
    \"sfObjectType\": \"Account\",
    \"sfOrgId\":      \"00Dxx0000001TEST\",
    \"name\":         \"Test Corp\",
    \"data\": {
      \"industry\":      \"Technology\",
      \"annualRevenue\": 5000000,
      \"tier\":          \"Enterprise\"
    }
  }"
assert_status 201 "Insert new record returns 201"
assert_body_contains "created" "Response contains operation=created"

# Update same record (upsert)
call POST /api/salesforce/records \
  -d "{
    \"sfRecordId\":   \"$TEST_RECORD_ID\",
    \"sfObjectType\": \"Account\",
    \"name\":         \"Test Corp (Updated)\",
    \"data\": {\"tier\": \"Strategic\"}
  }"
assert_status 200 "Update existing record returns 200"
assert_body_contains "updated" "Response contains operation=updated"

# Missing sfRecordId → 400
call POST /api/salesforce/records \
  -d '{"sfObjectType":"Account","name":"No ID"}'
assert_status 400 "Missing sfRecordId returns 400"

# Missing sfObjectType → 400
call POST /api/salesforce/records \
  -d '{"sfRecordId":"TEST_NOTYPE_001","name":"No Type"}'
assert_status 400 "Missing sfObjectType returns 400"

# ── 4. GET /api/salesforce/records ───────────────────────────────────────────

info "4. GET /api/salesforce/records (query)"

# Fetch single record by sfRecordId
call GET "/api/salesforce/records?sfRecordId=$TEST_RECORD_ID"
assert_status 200 "Fetch record by sfRecordId returns 200"
assert_body_contains "sfRecordId" "Response contains sfRecordId"
assert_body_contains "Test Corp" "Response contains record name"

# Query by sfObjectType
call GET "/api/salesforce/records?sfObjectType=Account&limit=5"
assert_status 200 "Query by sfObjectType returns 200"
assert_body_contains "records" "Response contains records array"
assert_body_contains "total" "Response contains total count"

# Pagination: skip + limit
call GET "/api/salesforce/records?sfObjectType=Account&limit=2&skip=0"
assert_status 200 "Pagination (limit=2, skip=0) returns 200"

# Search by name
call GET "/api/salesforce/records?search=Test"
assert_status 200 "Search by name returns 200"

# 404 for unknown sfRecordId
call GET "/api/salesforce/records?sfRecordId=DOES_NOT_EXIST_XYZ_99999"
assert_status 404 "Unknown sfRecordId returns 404"

# ── 5. Multiple log levels ────────────────────────────────────────────────────

info "5. Log levels"

for level in info warn error; do
  call POST /api/salesforce/logs \
    -d "{\"action\":\"test\",\"level\":\"$level\",\"message\":\"Testing level $level\"}"
  assert_status 201 "Log level '$level' accepted"
done

# ── 6. Large payload ─────────────────────────────────────────────────────────

info "6. Edge cases"

# Log with no optional fields (minimal)
call POST /api/salesforce/logs \
  -d '{"action":"create","level":"info","message":"minimal log"}'
assert_status 201 "Minimal log (no optional fields) returns 201"

# Record with no data field
call POST /api/salesforce/records \
  -d '{"sfRecordId":"TEST_NODATA_001","sfObjectType":"Contact"}'
assert_status 201 "Record upsert without data field returns 201"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "============================================"
if [ "$FAILURES" -eq 0 ]; then
  echo -e "  ${GREEN}All tests passed${NC}"
else
  echo -e "  ${RED}$FAILURES test(s) failed${NC}"
fi
echo "============================================"
echo ""

exit "$FAILURES"
