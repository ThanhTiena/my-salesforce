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

## Security checklist

- [ ] No API keys stored in CMDT, custom fields, or Apex code
- [ ] Named Credentials restricted to specific Permission Set users only
- [ ] External Credential Principals scoped to `NamedUser` (not org-wide)
- [ ] Shield Platform Encryption enabled on `AI_Step_Execution__c.Prompt_Sent__c`
- [ ] Shield Platform Encryption enabled on `AI_Step_Execution__c.Raw_Response__c`
- [ ] Remote Site Settings / CSP Trusted Sites not required (Named Creds handle this)
