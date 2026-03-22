# Named Credential Setup Guide

After deploying the package, configure each Named Credential with the provider's API key
using **External Credentials** (Salesforce API version 57.0+).
API keys are stored in the Salesforce credential store — **never in Apex, custom fields, or CMDT**.

---

## AI Provider Credentials (OpenAI, Anthropic, etc.)

### 1. Create External Credential

Navigate to: **Setup → Named Credentials → External Credentials → New**

| Field                   | Value                  |
|-------------------------|------------------------|
| Label                   | e.g. `OpenAI External` |
| Name                    | e.g. `OpenAI_External` |
| Authentication Protocol | `Custom`               |

Under **Principals**, add a principal:

| Field           | Value           |
|-----------------|-----------------|
| Parameter Name  | `Authorization` |
| Sequence Number | `1`             |

Then add an **Authentication Parameter**:

| Field | Value                          |
|-------|--------------------------------|
| Name  | `Authorization`                |
| Value | `Bearer sk-xxxx...` (your key) |

### 2. Link Named Credential to External Credential

Navigate to: **Setup → Named Credentials → Named Credentials → AI OpenAI → Edit**

| Field               | Value                          |
|---------------------|--------------------------------|
| External Credential | `OpenAI_External` (from above) |

### 3. Verify callout works

In the Developer Console:
```apex
HttpResponse resp = AIInferenceService.callout(
    'AI_OpenAI',
    '/v1/models',
    'GET',
    null,
    null,
    30
);
System.debug(resp.getStatusCode()); // expect 200
```

---

## Provider-specific auth header

| Provider      | Header Name     | Value format            |
|---------------|-----------------|-------------------------|
| OpenAI        | `Authorization` | `Bearer sk-...`         |
| Anthropic     | `x-api-key`     | `sk-ant-...`            |
| Google Gemini | URL param `key` | Add as query param      |
| Azure OpenAI  | `api-key`       | Your Azure key          |
| Cohere        | `Authorization` | `Bearer ...`            |
| Mistral       | `Authorization` | `Bearer ...`            |

---

## Vercel / MongoDB Proxy (`AI_MongoDB_Atlas`)

This Named Credential connects Salesforce to the Vercel-hosted REST API that proxies
writes and reads to MongoDB. Auth uses a shared `x-api-key` header — the key must match
the `SALESFORCE_API_KEY` environment variable set in Vercel.

### Vercel API endpoints used

| Method | Path                        | Purpose                        |
|--------|-----------------------------|--------------------------------|
| POST   | `/api/salesforce/logs`      | Append an audit log entry      |
| POST   | `/api/salesforce/records`   | Upsert a Salesforce record     |
| GET    | `/api/salesforce/records`   | Query records                  |

### Step 1 — Deploy the Vercel app

Set these environment variables in your Vercel project (**Settings → Environment Variables**):

| Variable             | Description                                                       |
|----------------------|-------------------------------------------------------------------|
| `MONGODB_URI`        | MongoDB Atlas connection string                                   |
| `MONGODB_DB_NAME`    | Database name (e.g. `salesforce`)                                 |
| `SALESFORCE_API_KEY` | Random secret — generate with `openssl rand -hex 32`              |

Also disable Vercel Authentication for Production:
**Vercel project → Settings → Deployment Protection → Vercel Authentication → Off**

### Step 2 — Create the External Credential

Navigate to: **Setup → Named Credentials → External Credentials → New**

| Field                   | Value                            |
|-------------------------|----------------------------------|
| Label                   | `MongoDB Vercel Proxy External`  |
| Name                    | `MongoDB_Vercel_Proxy_External`  |
| Authentication Protocol | `Custom`                         |

Under **Principals → New**:

| Field           | Value       |
|-----------------|-------------|
| Parameter Name  | `x-api-key` |
| Sequence Number | `1`         |

Under that Principal → **Authentication Parameters → New**:

| Field | Value                                              |
|-------|----------------------------------------------------|
| Name  | `x-api-key`                                        |
| Value | The value of `SALESFORCE_API_KEY` from Vercel      |

### Step 3 — Configure the Named Credential

Navigate to: **Setup → Named Credentials → Named Credentials → AI MongoDB Vercel Proxy → Edit**

| Field               | Value                                         |
|---------------------|-----------------------------------------------|
| URL                 | `https://<your-vercel-domain>.vercel.app`     |
| External Credential | `MongoDB_Vercel_Proxy_External`               |

### Step 4 — Grant Permission Set access

**Setup → Permission Sets → (your permission set) → External Credential Principal Access → Edit**

Add: `MongoDB_Vercel_Proxy_External - x-api-key`

Without this step the callout will receive a `401 Unauthorized`.

### Step 5 — Activate in Custom Metadata

**Setup → Custom Metadata Types → AI MongoDB Config → Manage Records → Default → Edit**

| Field                  | Value                                | Notes                                          |
|------------------------|--------------------------------------|------------------------------------------------|
| Named Credential Name  | `AI_MongoDB_Atlas`                   | Must match NC API Name exactly                 |
| Org Id                 | your 18-char org ID                  | Setup → Company Information                    |
| Is Active              | `true`                               | While `false` all methods silently no-op       |
| Timeout Seconds        | `30`                                 |                                                |
| Write Mode             | `SYNC_REQUIRED` (testing)            | Switch to `ASYNC_BEST_EFFORT` for production   |

> All other fields (`App_Id__c`, `Data_Source__c`, `Database_Name__c`, `Executions_Collection__c`)
> are not used by the Vercel proxy — leave them blank.

### Step 6 — Verify with Anonymous Apex

Open **Developer Console → Debug → Open Execute Anonymous Window**:

```apex
// Test 1: write a log entry
MongoDBLogService.LogEntry entry = new MongoDBLogService.LogEntry();
entry.action       = 'sync';
entry.level        = 'info';
entry.message      = 'Connection test from Salesforce';
entry.sfOrgId      = UserInfo.getOrganizationId();
entry.sfUserId     = UserInfo.getUserId();
entry.sfObjectType = 'Account';
entry.sfRecordId   = '0015g00000XyzAbcAAF';
String logId = MongoDBLogService.writeLog(entry);
System.debug('Log ID: ' + logId); // expect a MongoDB ObjectId string

// Test 2: upsert a record
MongoDBLogService.SalesforceRecord rec = new MongoDBLogService.SalesforceRecord();
rec.sfRecordId   = '0015g00000XyzAbcAAF';
rec.sfObjectType = 'Account';
rec.sfOrgId      = UserInfo.getOrganizationId();
rec.name         = 'Acme Corp';
rec.data         = new Map<String, Object>{ 'tier' => 'Enterprise' };
String op = MongoDBLogService.upsertRecord(rec);
System.debug('Operation: ' + op); // expect "created" or "updated"

// Test 3: fetch the record back
Map<String, Object> fetched = MongoDBLogService.getRecord('0015g00000XyzAbcAAF');
System.debug('Fetched: ' + fetched); // expect the document map
```

---

## Security checklist

- [ ] No API keys stored in CMDT, custom fields, or Apex code
- [ ] Named Credentials restricted to specific Permission Set users only
- [ ] External Credential Principals scoped to `NamedUser` (not org-wide)
- [ ] `SALESFORCE_API_KEY` is a high-entropy random string (min 32 chars)
- [ ] Vercel `SALESFORCE_API_KEY` env var is set to Production scope only
- [ ] Vercel Authentication disabled for Production (use `x-api-key` instead)
- [ ] Shield Platform Encryption enabled on `AI_Step_Execution__c.Prompt_Sent__c`
- [ ] Shield Platform Encryption enabled on `AI_Step_Execution__c.Raw_Response__c`
