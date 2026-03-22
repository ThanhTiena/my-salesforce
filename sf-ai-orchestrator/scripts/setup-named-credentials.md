# Named Credential Setup Guide

After deploying the package, configure each Named Credential with the provider's API key
using **External Credentials** (Salesforce API version 57.0+).
API keys are stored in the Salesforce credential store — **never in Apex, custom fields, or CMDT**.

---

## Step-by-step (per provider)

### 1. Create External Credential

Navigate to: **Setup → Named Credentials → External Credentials → New**

| Field                  | Value                              |
|------------------------|------------------------------------|
| Label                  | e.g. `OpenAI External`             |
| Name                   | e.g. `OpenAI_External`             |
| Authentication Protocol| `Custom`                           |

Under **Principals**, add a principal:
| Field          | Value           |
|----------------|-----------------|
| Parameter Name | `Authorization` |
| Sequence Number| `1`             |

Then add an **Authentication Parameter**:
| Field | Value                         |
|-------|-------------------------------|
| Name  | `Authorization`               |
| Value | `Bearer sk-xxxx...` (your key)|

### 2. Link Named Credential to External Credential

Navigate to: **Setup → Named Credentials → Named Credentials → AI OpenAI → Edit**

| Field               | Value                       |
|---------------------|-----------------------------|
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

| Provider     | Header Name       | Value format                              |
|--------------|-------------------|-------------------------------------------|
| OpenAI       | `Authorization`   | `Bearer sk-...`                           |
| Anthropic    | `x-api-key`       | `sk-ant-...`                              |
| Google Gemini| URL param `key`   | Add as query parameter in path            |
| Azure OpenAI | `api-key`         | Your Azure key                            |
| Cohere       | `Authorization`   | `Bearer ...`                              |
| Mistral      | `Authorization`   | `Bearer ...`                              |

---

---

## Vercel / MongoDB Proxy (`AI_MongoDB_Atlas`)

This Named Credential connects Salesforce to the Vercel-hosted REST API that proxies writes
and reads to MongoDB. Authentication uses a shared `x-api-key` header — the key must match
the `SALESFORCE_API_KEY` environment variable set in Vercel.

### 1. Deploy the Vercel app

Set the following environment variables in your Vercel project (**Settings → Environment Variables**):

| Variable             | Description                                                   |
|----------------------|---------------------------------------------------------------|
| `MONGODB_URI`        | MongoDB Atlas connection string (from Atlas → Connect)        |
| `MONGODB_DB_NAME`    | Database name — must match `Database_Name__c` in the CMDT (`salesforce`) |
| `SALESFORCE_API_KEY` | A strong random secret shared with Salesforce                 |

### 2. Add your Vercel domain to Remote Site Settings

1. **Setup → Security → Remote Site Settings → New Remote Site**
2. Name: `VercelProxy`
3. URL: `https://<your-vercel-domain>.vercel.app`
4. Save.

> Named Credentials handle the HTTPS call — this step is only needed if you test callouts
> outside of a Named Credential context.

### 3. Create the External Credential

Navigate to: **Setup → Named Credentials → External Credentials → New**

| Field                   | Value                          |
|-------------------------|--------------------------------|
| Label                   | `MongoDB Vercel Proxy External`|
| Name                    | `MongoDB_Vercel_Proxy_External`|
| Authentication Protocol | `Custom`                       |

Under **Principals**, add a principal:

| Field           | Value      |
|-----------------|------------|
| Parameter Name  | `x-api-key`|
| Sequence Number | `1`        |

Then add an **Authentication Parameter**:

| Field | Value                                         |
|-------|-----------------------------------------------|
| Name  | `x-api-key`                                   |
| Value | The same secret as `SALESFORCE_API_KEY` in Vercel |

### 4. Configure the Named Credential

Navigate to: **Setup → Named Credentials → Named Credentials → AI MongoDB Vercel Proxy → Edit**

| Field               | Value                                              |
|---------------------|----------------------------------------------------|
| URL                 | `https://<your-vercel-domain>.vercel.app`          |
| External Credential | `MongoDB_Vercel_Proxy_External`                    |

### 5. Activate in Custom Metadata

In **Setup → Custom Metadata Types → AI MongoDB Config → Manage Records → Default → Edit**:

| Field               | Value                     | Notes                                          |
|---------------------|---------------------------|------------------------------------------------|
| Named Credential    | `AI_MongoDB_Atlas`        | Must match API Name of the Named Credential    |
| App Id (Base Path)  | `api/salesforce/data`     | Vercel route prefix — do not add a leading `/` |
| Data Source         | `Cluster0`                | Your Atlas cluster name                        |
| Database Name       | `salesforce`              | Must match `MONGODB_DB_NAME` in Vercel         |
| Executions Collection | `ai_executions`         | Collection where execution logs are stored     |
| Org Id              | `<your 18-char org ID>`   | From Setup → Company Information               |
| Is Active           | `true`                    | Flip to `true` only after steps 1–4 are done   |
| Timeout Seconds     | `30`                      |                                                |
| Write Mode          | `ASYNC_BEST_EFFORT`       | Use `SYNC_REQUIRED` only for debugging         |

### 6. Verify the callout

In the Developer Console (Anonymous Apex):

```apex
// Should return HTTP 200 and a JSON body with "success": true
MongoDBLogService.ExecutionDocument doc = new MongoDBLogService.ExecutionDocument();
doc.sfExecutionId   = 'test-' + Datetime.now().getTime();
doc.sfWorkflowId    = 'test-workflow';
doc.workflowName    = 'Verify Connection';
doc.workflowVersion = 1;
doc.sfOrgId         = UserInfo.getOrganizationId();
doc.status          = 'PENDING';
doc.startedAtEpochMs = Datetime.now().getTime();
doc.schemaVersion   = 1;
MongoDBLogService.insertExecution(doc);
System.debug('Insert dispatched — check Vercel logs for confirmation');
```

---

## Security checklist

- [ ] No API keys stored in CMDT, custom fields, or Apex code
- [ ] Named Credentials restricted to specific Permission Set users only
- [ ] External Credential Principals scoped to `NamedUser` (not org-wide)
- [ ] `SALESFORCE_API_KEY` is a high-entropy random string (min 32 chars)
- [ ] Vercel environment variable `SALESFORCE_API_KEY` is set to Production scope only
- [ ] Shield Platform Encryption enabled on `AI_Step_Execution__c.Prompt_Sent__c`
- [ ] Shield Platform Encryption enabled on `AI_Step_Execution__c.Raw_Response__c`
- [ ] Remote Site Settings entry added for the Vercel domain
