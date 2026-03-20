# Fields To Create Manually in Salesforce Setup

Use **Setup → Object Manager → [Object] → Fields & Relationships → New** for each field below.

Mark each field ✅ when done.

---

## Object 1: `AI_Workflow__c` — AI Workflow
> Object settings: Enable Reports, Enable History, Sharing = ReadWrite

| # | Field Label | API Name | Type | Required | Notes |
|---|-------------|----------|------|----------|-------|
| ☐ | Workflow Name | *(Name field)* | Text | — | Auto-created. Edit label to "Workflow Name". |
| ☐ | Description | `Description__c` | Text Area | No | — |
| ☐ | Trigger Object API Name | `Trigger_Object__c` | Text (255) | No | e.g. `Lead`, `Case` |
| ☐ | Trigger Condition (SOQL WHERE) | `Trigger_Condition__c` | Long Text Area (32768) | No | Visible lines: 3 |
| ☐ | Is Active | `Is_Active__c` | Checkbox | — | Default: `false`. Track History: ✓ |
| ☐ | Max Retries | `Max_Retries__c` | Number (3,0) | No | Default: `3` |
| ☐ | Retry Delay (Seconds) | `Retry_Delay_Seconds__c` | Number (5,0) | No | Default: `60` |
| ☐ | Notification Email | `Notification_Email__c` | Email | No | Notify on failure |
| ☐ | Version | `Version__c` | Number (5,0) | No | Default: `1`. Track History: ✓ |
| ☐ | Total Executions | `Total_Executions__c` | Number (18,0) | No | Default: `0` |
| ☐ | Last Executed | `Last_Executed__c` | Date/Time | No | — |

---

## Object 2: `AI_Step__c` — AI Step
> Object settings: Enable Reports, Sharing = ControlledByParent, Master-Detail to AI_Workflow__c

| # | Field Label | API Name | Type | Required | Notes |
|---|-------------|----------|------|----------|-------|
| ☐ | Step Name | *(Name field)* | Text | — | Auto-created. |
| ☐ | AI Workflow | `AI_Workflow__c` | **Master-Detail** → `AI_Workflow__c` | Yes | Relationship Name: `AI_Steps` |
| ☐ | Order | `Order__c` | Number (5,0) | Yes | Execution order; 1 = first |
| ☐ | Step Type | `Step_Type__c` | Picklist | Yes | Values: `AI Inference` (default), `Classification`, `Summarization`, `Sentiment Analysis`, `Data Extraction`, `Translation`, `Embedding`, `Custom`. Restrict to list. |
| ☐ | AI Provider (Developer Name) | `AI_Provider_Developer_Name__c` | Text (255) | Yes | DeveloperName of `AI_Provider__mdt` |
| ☐ | Model Override | `Model_Override__c` | Text (255) | No | Overrides provider default |
| ☐ | Prompt Template | `Prompt_Template__c` | Long Text Area (131072) | Yes | Use `{{Object.Field}}` syntax. Visible lines: 10 |
| ☐ | System Prompt | `System_Prompt__c` | Long Text Area (32768) | No | Visible lines: 5 |
| ☐ | Output Field API Name | `Output_Field__c` | Text (255) | No | Field on trigger record to write response |
| ☐ | Response Format | `Response_Format__c` | Picklist | No | Values: `Plain Text` (default), `JSON`. Restrict to list. |
| ☐ | Temperature Override | `Temperature_Override__c` | Number (3,2) | No | e.g. `0.70` |
| ☐ | Max Tokens Override | `Max_Tokens_Override__c` | Number (10,0) | No | — |
| ☐ | Condition (Apex Boolean Expression) | `Condition__c` | Text Area | No | Evaluated to skip step |
| ☐ | Is Active | `Is_Active__c` | Checkbox | — | Default: `true` |

---

## Object 3: `AI_Execution__c` — AI Execution
> Object settings: Enable Reports, Sharing = ReadWrite, Name field = **Auto Number** (`EXEC-{0000000}`)

| # | Field Label | API Name | Type | Required | Notes |
|---|-------------|----------|------|----------|-------|
| ☐ | Execution Name | *(Name field)* | **Auto Number** | — | Format: `EXEC-{0000000}` |
| ☐ | AI Workflow | `AI_Workflow__c` | **Lookup** → `AI_Workflow__c` | Yes | Delete: Set Null. Rel label: `AI Executions` |
| ☐ | Status | `Status__c` | Picklist | Yes | Values: `Pending` (default), `Running`, `Completed`, `Failed`, `Cancelled`, `Retrying`. Restrict to list. Track History: ✓ |
| ☐ | Trigger Record ID | `Trigger_Record_Id__c` | Text (18) | No | 18-char SF record ID |
| ☐ | Trigger Object | `Trigger_Object__c` | Text (255) | No | e.g. `Lead` |
| ☐ | Initiated By | `Initiated_By__c` | **Lookup** → `User` | No | Delete: Set Null. Rel label: `Initiated AI Executions` |
| ☐ | Started At | `Started_At__c` | Date/Time | No | — |
| ☐ | Completed At | `Completed_At__c` | Date/Time | No | — |
| ☐ | Duration (Seconds) | `Duration_Seconds__c` | Number (10,2) | No | — |
| ☐ | Error Message | `Error_Message__c` | Long Text Area (32768) | No | Visible lines: 5 |
| ☐ | Retry Count | `Retry_Count__c` | Number (3,0) | No | Default: `0` |
| ☐ | Total Tokens Used | `Total_Tokens_Used__c` | Number (18,0) | No | — |
| ☐ | Context JSON | `Context_JSON__c` | Long Text Area (131072) | No | Encrypted at rest. Visible lines: 5 |

---

## Object 4: `AI_Step_Execution__c` — AI Step Execution
> Object settings: Enable Reports, Sharing = ControlledByParent, Name field = **Auto Number** (`STEP-{0000000}`)

| # | Field Label | API Name | Type | Required | Notes |
|---|-------------|----------|------|----------|-------|
| ☐ | Step Execution Name | *(Name field)* | **Auto Number** | — | Format: `STEP-{0000000}` |
| ☐ | AI Execution | `AI_Execution__c` | **Master-Detail** → `AI_Execution__c` | Yes | Relationship Name: `AI_Step_Executions` |
| ☐ | AI Step | `AI_Step__c` | **Lookup** → `AI_Step__c` | Yes | Delete: Set Null. Rel label: `Step Executions` |
| ☐ | Status | `Status__c` | Picklist | Yes | Values: `Pending` (default), `Running`, `Completed`, `Failed`, `Skipped`. Restrict to list. |
| ☐ | Provider Used | `Provider_Used__c` | Text (255) | No | — |
| ☐ | Model Used | `Model_Used__c` | Text (255) | No | — |
| ☐ | Prompt Sent | `Prompt_Sent__c` | Long Text Area (131072) | No | Resolved prompt. Consider Shield Encryption. Visible lines: 8 |
| ☐ | Raw Response | `Raw_Response__c` | Long Text Area (131072) | No | Full provider response. Consider Shield Encryption. Visible lines: 8 |
| ☐ | Parsed Output | `Parsed_Output__c` | Long Text Area (32768) | No | Visible lines: 5 |
| ☐ | Tokens Used | `Tokens_Used__c` | Number (18,0) | No | Total tokens |
| ☐ | Prompt Tokens | `Prompt_Tokens__c` | Number (18,0) | No | Input tokens |
| ☐ | Completion Tokens | `Completion_Tokens__c` | Number (18,0) | No | Output tokens |
| ☐ | HTTP Status Code | `HTTP_Status_Code__c` | Number (5,0) | No | e.g. `200`, `429`, `500` |
| ☐ | Duration (ms) | `Duration_Ms__c` | Number (10,0) | No | Round-trip latency |
| ☐ | Error Message | `Error_Message__c` | Long Text Area (32768) | No | Visible lines: 3 |
| ☐ | Retry Attempt | `Retry_Attempt__c` | Number (3,0) | No | Default: `0` |

---

## Object 5: `AI_Provider__mdt` — AI Provider (Custom Metadata Type)
> Go to: Setup → Custom Metadata Types → New (if not yet created)

| # | Field Label | API Name | Type | Required | Notes |
|---|-------------|----------|------|----------|-------|
| ☐ | Label | *(built-in)* | Text | — | Auto-created on CMT. |
| ☐ | Provider Type | `Provider_Type__c` | Text (50) | Yes | `OPENAI`, `ANTHROPIC`, `GOOGLE`, `AZURE_OPENAI`, `COHERE`, `MISTRAL`, `CUSTOM` |
| ☐ | Endpoint URL | `Endpoint_URL__c` | URL | Yes | e.g. `https://api.openai.com/v1` |
| ☐ | Named Credential API Name | `Named_Credential_API_Name__c` | Text (255) | Yes | Auth token stored in Named Credential only |
| ☐ | Default Model | `Default_Model__c` | Text (255) | Yes | e.g. `gpt-4o`, `claude-sonnet-4-6` |
| ☐ | Max Tokens | `Max_Tokens__c` | Number (10,0) | No | Default: `4096` |
| ☐ | Temperature | `Temperature__c` | Number (3,2) | No | Default: `0.70` |
| ☐ | Rate Limit (Requests/Min) | `Rate_Limit_RPM__c` | Number (10,0) | No | Default: `60` |
| ☐ | Rate Limit (Tokens/Min) | `Rate_Limit_TPM__c` | Number (18,0) | No | — |
| ☐ | Timeout (Seconds) | `Timeout_Seconds__c` | Number (5,0) | No | Default: `120` |
| ☐ | API Version | `API_Version__c` | Text (50) | No | Azure only: e.g. `2024-02-01` |
| ☐ | Is Active | `Is_Active__c` | Checkbox | — | Default: `true` |
| ☐ | Supports Streaming | `Supports_Streaming__c` | Checkbox | — | Default: `false` |
| ☐ | Custom Headers (JSON) | `Custom_Headers_JSON__c` | Text Area | No | Extra HTTP headers as JSON. No auth here. |

---

## Creation Order (to avoid lookup dependency errors)

Create objects and fields in this sequence:

```
1. AI_Provider__mdt     (no dependencies)
2. AI_Workflow__c       (no dependencies)
3. AI_Step__c           (depends on: AI_Workflow__c)
4. AI_Execution__c      (depends on: AI_Workflow__c)
5. AI_Step_Execution__c (depends on: AI_Execution__c, AI_Step__c)
```

---

## Quick Tips

- **Auto Number name field**: When creating the object, set Name Field Type = **Auto Number** and enter the display format (`EXEC-{0000000}` or `STEP-{0000000}`).
- **Master-Detail**: The parent object must exist before you can create a Master-Detail field on the child.
- **Picklist values**: Use exactly the API names shown in the `Notes` column — they are what the Apex code references.
- **Shield Encryption**: `Prompt_Sent__c`, `Raw_Response__c`, and `Context_JSON__c` should have Platform Encryption enabled if your org has Shield.
- **Track History**: Enable field history tracking on the object first (Object Manager → [Object] → Edit → Enable Field History), then set Track History on individual fields.