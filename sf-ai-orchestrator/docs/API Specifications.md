# API Specifications

This document describes the REST API endpoints hosted on Vercel (Next.js) that Salesforce can call out to for writing audit logs, reading/writing records, and syncing AI workflow execution telemetry stored in MongoDB.

---

## Base URL

```
https://<your-vercel-domain>.vercel.app
```

Interactive docs and live testing: `https://<your-vercel-domain>.vercel.app/api-docs`

---

## Authentication

All endpoints require an API key passed as a request header.

| Header      | Value                  |
|-------------|------------------------|
| `x-api-key` | `<SALESFORCE_API_KEY>` |

The API key must match the `SALESFORCE_API_KEY` environment variable configured in Vercel. Requests without a valid key receive a `401 Unauthorized` response.

**Generate a key:**
```bash
openssl rand -hex 32
```

---

## Endpoints

### Salesforce General Endpoints

| # | Method | Path | Purpose |
|---|--------|------|---------|
| 1 | POST   | `/api/salesforce/logs`    | Write an audit log entry |
| 2 | POST   | `/api/salesforce/records` | Upsert a Salesforce record |
| 3 | GET    | `/api/salesforce/records` | Query Salesforce records |

### AI Execution Sync Endpoints

| # | Method | Path | Purpose |
|---|--------|------|---------|
| 4 | POST   | `/api/executions`                              | Create execution document (workflow start) |
| 5 | PATCH  | `/api/executions/:id/status`                   | Update execution status |
| 6 | PATCH  | `/api/executions/:id/steps`                    | Push a new step sub-document |
| 7 | PATCH  | `/api/executions/:id/steps/:stepExecId`        | Update an existing step (complete/fail) |
| 8 | PATCH  | `/api/executions/:id/finalise`                 | Finalise execution (set duration, tokens) |
| 9 | POST   | `/api/executions/query`                        | Query executions with filter/sort/pagination |
| 10| POST   | `/api/executions/aggregate`                    | Run aggregation pipeline (dashboard metrics) |

---

### 1. Write a Log Entry

**`POST /api/salesforce/logs`**

Appends an immutable audit log entry from Salesforce into MongoDB. Call this after every significant action (create, update, sync, error, etc.). Logs are **write-only** — no update or delete.

#### Request

- **Headers:**
  ```
  Content-Type: application/json
  x-api-key: <SALESFORCE_API_KEY>
  ```
- **Body:**

  | Field          | Type   | Required | Description |
  |----------------|--------|----------|-------------|
  | `action`       | string | Yes      | What happened: `create` / `update` / `delete` / `sync` / `query` / `callout` / any custom string |
  | `level`        | string | Yes      | Severity: `info` / `warn` / `error` |
  | `message`      | string | Yes      | Human-readable description |
  | `sfOrgId`      | string | No       | Salesforce Org ID (e.g. `00Dxx0000001gEREAY`) |
  | `sfUserId`     | string | No       | Salesforce User ID who triggered the action |
  | `sfObjectType` | string | No       | Salesforce object API name (e.g. `Account`) |
  | `sfRecordId`   | string | No       | 18-char Salesforce record ID |
  | `sfRecordName` | string | No       | Human-readable record name |
  | `payload`      | object | No       | Any extra data snapshot to attach |

- **Example body:**
  ```json
  {
    "sfOrgId":      "00Dxx0000001gEREAY",
    "sfUserId":     "005xx000001SvqjAAC",
    "sfObjectType": "Account",
    "sfRecordId":   "0015g00000XyzAbcAAF",
    "sfRecordName": "Acme Corp",
    "action":       "sync",
    "level":        "info",
    "message":      "Account synced to MongoDB successfully",
    "payload":      { "previousStatus": "Prospect", "newStatus": "Customer" }
  }
  ```

#### Response

**201 Created** — Log entry saved.
```json
{
  "success": true,
  "logId": "64f1a2b3c4d5e6f7a8b9c0d1"
}
```

**400 Bad Request** — Missing or invalid required fields.
```json
{
  "error": "Missing or invalid required fields: level (info | warn | error)"
}
```

**401 Unauthorized**
```json
{ "error": "Unauthorized" }
```

**500 Internal Server Error**
```json
{ "error": "Database error" }
```

#### curl example
```bash
curl -X POST https://<your-vercel-domain>.vercel.app/api/salesforce/logs \
  -H "Content-Type: application/json" \
  -H "x-api-key: <SALESFORCE_API_KEY>" \
  -d '{
    "sfObjectType": "Account",
    "sfRecordId":   "0015g00000XyzAbcAAF",
    "action":       "sync",
    "level":        "info",
    "message":      "Account synced successfully"
  }'
```

---

### 2. Upsert a Record

**`POST /api/salesforce/records`**

Creates or updates a record in MongoDB keyed by `sfRecordId`. If the record already exists it is updated; otherwise a new document is inserted. Returns `operation: "created"` (201) or `operation: "updated"` (200).

#### Request

- **Headers:**
  ```
  Content-Type: application/json
  x-api-key: <SALESFORCE_API_KEY>
  ```
- **Body:**

  | Field          | Type   | Required | Description |
  |----------------|--------|----------|-------------|
  | `sfRecordId`   | string | Yes      | 18-char Salesforce record ID — used as the upsert key |
  | `sfObjectType` | string | Yes      | Salesforce object API name (e.g. `Account`) |
  | `sfOrgId`      | string | No       | Salesforce Org ID |
  | `name`         | string | No       | Human-readable record name |
  | `data`         | object | No       | Any additional fields to store |

- **Example body:**
  ```json
  {
    "sfRecordId":   "0015g00000XyzAbcAAF",
    "sfObjectType": "Account",
    "sfOrgId":      "00Dxx0000001gEREAY",
    "name":         "Acme Corp",
    "data": {
      "industry":      "Technology",
      "annualRevenue": 5000000,
      "tier":          "Enterprise"
    }
  }
  ```

#### Response

**201 Created** — Record inserted.
```json
{
  "success":    true,
  "sfRecordId": "0015g00000XyzAbcAAF",
  "operation":  "created"
}
```

**200 OK** — Record updated.
```json
{
  "success":    true,
  "sfRecordId": "0015g00000XyzAbcAAF",
  "operation":  "updated"
}
```

**400 Bad Request** — Missing required fields.
```json
{
  "error": "Missing or invalid required fields: sfRecordId"
}
```

**401 Unauthorized**
```json
{ "error": "Unauthorized" }
```

**500 Internal Server Error**
```json
{ "error": "Database error" }
```

#### curl example
```bash
curl -X POST https://<your-vercel-domain>.vercel.app/api/salesforce/records \
  -H "Content-Type: application/json" \
  -H "x-api-key: <SALESFORCE_API_KEY>" \
  -d '{
    "sfRecordId":   "0015g00000XyzAbcAAF",
    "sfObjectType": "Account",
    "name":         "Acme Corp",
    "data":         { "tier": "Enterprise" }
  }'
```

---

### 3. Query Records

**`GET /api/salesforce/records`**

Retrieves records from MongoDB to return back to Salesforce. Use `sfRecordId` for a single record lookup, or combine other filters for a list.

#### Request

- **Headers:**
  ```
  x-api-key: <SALESFORCE_API_KEY>
  ```
- **Query Parameters:**

  | Parameter      | Type   | Required | Default | Description |
  |----------------|--------|----------|---------|-------------|
  | `sfRecordId`   | string | No       | —       | Fetch a single record (returns `404` if not found) |
  | `sfObjectType` | string | No       | —       | Filter by Salesforce object type |
  | `sfOrgId`      | string | No       | —       | Filter by Salesforce org |
  | `search`       | string | No       | —       | Case-insensitive substring match on `name` |
  | `limit`        | number | No       | `50`    | Max records to return (capped at `200`) |
  | `skip`         | number | No       | `0`     | Records to skip for pagination |

#### Response

**200 OK** — List of records.
```json
{
  "success": true,
  "total":   3,
  "limit":   50,
  "skip":    0,
  "records": [
    {
      "_id":          "64f1a2b3c4d5e6f7a8b9c0d1",
      "sfRecordId":   "0015g00000XyzAbcAAF",
      "sfObjectType": "Account",
      "sfOrgId":      "00Dxx0000001gEREAY",
      "name":         "Acme Corp",
      "data":         { "tier": "Enterprise" },
      "createdAt":    "2024-09-01T10:00:00.000Z",
      "updatedAt":    "2024-09-01T10:00:00.000Z"
    }
  ]
}
```

**200 OK** — Single record (when `sfRecordId` is provided).
```json
{
  "success": true,
  "record": {
    "_id":          "64f1a2b3c4d5e6f7a8b9c0d1",
    "sfRecordId":   "0015g00000XyzAbcAAF",
    "sfObjectType": "Account",
    "name":         "Acme Corp",
    "createdAt":    "2024-09-01T10:00:00.000Z",
    "updatedAt":    "2024-09-01T10:00:00.000Z"
  }
}
```

**401 Unauthorized**
```json
{ "error": "Unauthorized" }
```

**404 Not Found** — Only when `sfRecordId` filter is used.
```json
{ "error": "Record not found" }
```

**500 Internal Server Error**
```json
{ "error": "Database error" }
```

#### curl examples
```bash
# Fetch a single record by sfRecordId
curl "https://<your-vercel-domain>.vercel.app/api/salesforce/records?sfRecordId=0015g00000XyzAbcAAF" \
  -H "x-api-key: <SALESFORCE_API_KEY>"

# List all Account records
curl "https://<your-vercel-domain>.vercel.app/api/salesforce/records?sfObjectType=Account&limit=10" \
  -H "x-api-key: <SALESFORCE_API_KEY>"

# Search by name
curl "https://<your-vercel-domain>.vercel.app/api/salesforce/records?search=Acme&limit=5" \
  -H "x-api-key: <SALESFORCE_API_KEY>"
```

---

## Salesforce Setup Guide

### Step 1 — Disable Vercel Authentication (for API access)

1. Go to your Vercel project → **Settings → Deployment Protection**.
2. Set **Vercel Authentication** to **Off** for Production.
3. Your `x-api-key` header is the authentication mechanism — no Vercel SSO needed.

### Step 2 — Add the Vercel domain to Remote Site Settings

1. In Salesforce, go to **Setup → Security → Remote Site Settings**.
2. Click **New Remote Site**.
3. Enter a name (e.g. `VercelAPI`) and the URL `https://<your-vercel-domain>.vercel.app`.
4. Save.

### Step 3 — Store the API Key securely in Salesforce

- **Option A (Named Credential):** Create a Named Credential with the base URL and add `x-api-key` as a custom header.
- **Option B (Custom Setting / Custom Metadata):** Store the key in a Protected Custom Setting and reference it in Apex.

### Step 4 — Apex Callout Examples

#### Write a log entry

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('https://<your-vercel-domain>.vercel.app/api/salesforce/logs');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('x-api-key', '<SALESFORCE_API_KEY>');

Map<String, Object> payload = new Map<String, Object>{
    'sfObjectType' => 'Account',
    'sfRecordId'   => '0015g00000XyzAbcAAF',
    'sfRecordName' => 'Acme Corp',
    'action'       => 'sync',
    'level'        => 'info',
    'message'      => 'Account synced to MongoDB'
};
req.setBody(JSON.serialize(payload));

Http http = new Http();
HttpResponse res = http.send(req);

if (res.getStatusCode() == 201) {
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    System.debug('Log ID: ' + result.get('logId'));
} else {
    System.debug('Error: ' + res.getBody());
}
```

#### Upsert a record

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('https://<your-vercel-domain>.vercel.app/api/salesforce/records');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('x-api-key', '<SALESFORCE_API_KEY>');

Map<String, Object> data = new Map<String, Object>{
    'industry' => 'Technology',
    'tier'     => 'Enterprise'
};
Map<String, Object> payload = new Map<String, Object>{
    'sfRecordId'   => '0015g00000XyzAbcAAF',
    'sfObjectType' => 'Account',
    'name'         => 'Acme Corp',
    'data'         => data
};
req.setBody(JSON.serialize(payload));

Http http = new Http();
HttpResponse res = http.send(req);

if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    System.debug('Operation: ' + result.get('operation'));
} else {
    System.debug('Error: ' + res.getBody());
}
```

#### Query records

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('https://<your-vercel-domain>.vercel.app/api/salesforce/records?sfRecordId=0015g00000XyzAbcAAF');
req.setMethod('GET');
req.setHeader('x-api-key', '<SALESFORCE_API_KEY>');

Http http = new Http();
HttpResponse res = http.send(req);

if (res.getStatusCode() == 200) {
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    System.debug('Record: ' + result.get('record'));
} else if (res.getStatusCode() == 404) {
    System.debug('Record not found');
} else {
    System.debug('Error: ' + res.getBody());
}
```

---

---

## AI Execution Sync Endpoints

These endpoints are called automatically by `MongoDBLogService.cls` during every AI workflow execution. They persist the full execution lifecycle — including every step start, completion, and failure — into MongoDB so the Execution Monitor dashboard has live data.

All endpoints share the same `x-api-key` authentication.

---

### 4. Start Execution

**`POST /api/executions`**

Creates a new execution document in MongoDB when a workflow is triggered. Called once per execution at the PENDING stage.

#### Request Body

| Field             | Type    | Required | Description |
|-------------------|---------|----------|-------------|
| `sf_execution_id` | string  | Yes      | 24-char hex correlation ID stored on `AI_Execution__c.Mongo_Execution_Id__c` |
| `sf_workflow_id`  | string  | No       | Salesforce `AI_Workflow__c` record ID |
| `workflow_name`   | string  | No       | Workflow name |
| `workflow_version`| integer | No       | Workflow version number |
| `sf_org_id`       | string  | No       | Salesforce org ID |
| `status`          | string  | No       | Initial status (default: `PENDING`) |
| `initiated_by`    | string  | No       | Salesforce user ID |
| `trigger_record_id`| string | No       | ID of the record that triggered the workflow |
| `trigger_object`  | string  | No       | API name of the trigger object |
| `retry_count`     | integer | No       | Retry attempt number (default: `0`) |
| `schema_version`  | integer | No       | Document schema version (default: `1`) |
| `started_at`      | object  | No       | MongoDB Extended JSON date: `{"$date":{"$numberLong":"<ms>"}}` |

#### Response

**201 Created**
```json
{ "success": true }
```

**400 Bad Request**
```json
{ "error": "Missing required field: sf_execution_id" }
```

---

### 5. Update Execution Status

**`PATCH /api/executions/:id/status`**

Updates the status of an execution. Called at every status transition:
`PENDING → RUNNING → COMPLETED / FAILED / RETRYING`

`:id` is the `sf_execution_id` (24-char hex).

#### Request Body

| Field          | Type   | Required | Description |
|----------------|--------|----------|-------------|
| `status`       | string | Yes      | One of: `PENDING`, `RUNNING`, `COMPLETED`, `FAILED`, `RETRYING` |
| `errorMessage` | string | No       | Error details (set on FAILED or RETRYING) |

#### Response

**200 OK**
```json
{ "success": true }
```

**404 Not Found**
```json
{ "error": "Execution not found" }
```

---

### 6. Push Step (Start)

**`PATCH /api/executions/:id/steps`**

Appends a new step sub-document to the execution's `steps` array. Called when each step begins (status = `RUNNING`).

#### Request Body

```json
{
  "step": {
    "sfStepExecutionId": "AI_Step_Execution__c record ID",
    "sfStepId":          "AI_Step__c record ID",
    "stepName":          "Step label",
    "stepType":          "AI_INFERENCE | DECISION | HTTP_CALLOUT | ...",
    "stepOrder":         1,
    "status":            "RUNNING",
    "retryAttempt":      0
  }
}
```

| Field               | Type    | Required | Description |
|---------------------|---------|----------|-------------|
| `step`              | object  | Yes      | Step sub-document |
| `step.sfStepExecutionId` | string | Yes | Used as the update key in subsequent calls |
| `step.stepType`     | string  | No       | Step type enum value |
| `step.stepOrder`    | integer | No       | Execution order (1-based) |

#### Response

**200 OK**
```json
{ "success": true }
```

---

### 7. Update Step (Complete or Fail)

**`PATCH /api/executions/:id/steps/:stepExecId`**

Updates an existing step sub-document (matched by `sf_step_execution_id`). Called when a step finishes — success or failure — with all result fields populated.

`:stepExecId` is the `sfStepExecutionId` passed when the step was pushed.

#### Request Body

All fields are optional — only non-null fields are applied.

| Field              | Type    | Description |
|--------------------|---------|-------------|
| `status`           | string  | `COMPLETED` or `FAILED` |
| `providerUsed`     | string  | AI provider name |
| `modelUsed`        | string  | Model identifier |
| `promptSent`       | string  | Resolved prompt text |
| `rawResponse`      | string  | Raw API response body |
| `parsedOutput`     | string  | Extracted/parsed content |
| `tokensUsed`       | integer | Total tokens consumed |
| `promptTokens`     | integer | Prompt token count |
| `completionTokens` | integer | Completion token count |
| `httpStatusCode`   | integer | HTTP status from AI provider |
| `durationMs`       | integer | Step duration in milliseconds |
| `errorMessage`     | string  | Error detail on failure |
| `retryAttempt`     | integer | Retry attempt number |

#### Response

**200 OK**
```json
{ "success": true }
```

**404 Not Found**
```json
{ "error": "Execution or step not found" }
```

---

### 8. Finalise Execution

**`PATCH /api/executions/:id/finalise`**

Sets the terminal state of a completed or failed execution: `completed_at`, `duration_seconds`, `total_tokens_used`, final status, and optional context snapshot. Called once after all steps finish.

#### Request Body

| Field                | Type    | Required | Description |
|----------------------|---------|----------|-------------|
| `status`             | string  | No       | Final status (`COMPLETED` or `FAILED`) |
| `durationSeconds`    | decimal | No       | Total wall-clock duration |
| `totalTokensUsed`    | integer | No       | Sum of all step token usage |
| `completedAtEpochMs` | number  | No       | Epoch milliseconds for `completed_at` |
| `contextJson`        | string  | No       | Serialised execution context map |
| `errorMessage`       | string  | No       | Final error message on failure |

#### Response

**200 OK**
```json
{ "success": true }
```

---

### 9. Query Executions

**`POST /api/executions/query`**

Queries execution documents with filtering, sorting, and pagination. Used by the Execution Monitor dashboard to display the log table.

#### Request Body

| Field        | Type    | Required | Default       | Description |
|--------------|---------|----------|---------------|-------------|
| `filter`     | object  | No       | `{}`          | MongoDB filter expression (snake_case field names) |
| `sort`       | object  | No       | `{"started_at":-1}` | Sort fields and direction (`1` = ASC, `-1` = DESC) |
| `skip`       | integer | No       | `0`           | Documents to skip |
| `limit`      | integer | No       | `20`          | Max documents to return (capped at `200`) |
| `projection` | object  | No       | —             | MongoDB projection (field inclusion/exclusion) |

#### Supported Filter Fields

| Field              | Example value |
|--------------------|---------------|
| `status`           | `"COMPLETED"` |
| `workflow_name`    | `{"$regex":"Case","$options":"i"}` |
| `started_at`       | `{"$gte":{"$date":{"$numberLong":"<ms>"}}}` |
| `sf_execution_id`  | `"abc123..."` |

#### Response

**200 OK**
```json
{
  "documents":  [ { ... } ],
  "totalCount": 142
}
```

---

### 10. Aggregate Executions

**`POST /api/executions/aggregate`**

Runs a MongoDB aggregation pipeline on the executions collection. Used for dashboard metrics (counts, average duration, token usage by provider).

Date values in the pipeline can be passed as MongoDB Extended JSON: `{"$date":{"$numberLong":"<epochMs>"}}` — the API resolves them to native `Date` objects before executing.

#### Request Body

| Field      | Type  | Required | Description |
|------------|-------|----------|-------------|
| `pipeline` | array | Yes      | MongoDB aggregation pipeline stages |

#### Example — Count by status

```json
{
  "pipeline": [
    { "$match": { "started_at": { "$gte": { "$date": { "$numberLong": "1700000000000" } } } } },
    { "$group": { "_id": "$status", "count": { "$sum": 1 } } }
  ]
}
```

#### Response

**200 OK**
```json
{
  "documents": [
    { "_id": "COMPLETED", "count": 87 },
    { "_id": "FAILED",    "count": 12 }
  ]
}
```

---

## MongoDB Collections

| Collection      | Purpose |
|-----------------|---------|
| `logs`          | Append-only audit trail from `POST /api/salesforce/logs` |
| `records`       | Upserted Salesforce records keyed by `sfRecordId` |
| `ai_executions` | AI workflow execution documents with embedded step sub-documents |

---

## Environment Variables (Vercel)

Configure these in your Vercel project under **Settings → Environment Variables**:

| Variable                          | Description |
|-----------------------------------|-------------|
| `MONGODB_URI`                     | MongoDB connection string (from MongoDB Atlas) |
| `MONGODB_DB_NAME`                 | MongoDB database name (default: `salesforce`) |
| `MONGODB_EXECUTIONS_COLLECTION`   | AI executions collection name (default: `ai_executions`) |
| `SALESFORCE_API_KEY`              | Shared secret — generate with `openssl rand -hex 32` |
