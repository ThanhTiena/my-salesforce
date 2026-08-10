# FreelanceOps — Setup & Deployment Guide

FreelanceOps is a Salesforce Lightning application that runs the full lifecycle
of independent Salesforce consulting work:

> Sourcing Channel → Lead → Pursuit (Opportunity + JD) → Interview Pipeline →
> Closed Won → Contract → Assignment → Timesheet → Invoice → Payment →
> Margin & Cash Insight

This guide covers the metadata that ships in this repository and the manual
Setup steps that Salesforce does **not** let you deploy from source. It is the
operational companion to the design blueprint.

---

## 1. What is in the repo

All FreelanceOps schema now lives under
`force-app/main/default/` and is source-controlled:

| Area | Path | Contents |
|---|---|---|
| Custom objects (6) | `objects/FOPS_*` | Object + all custom fields |
| Standard-object fields | `objects/{Account,Contact,Contract,Lead,Opportunity,Order,OrderItem,Product2,Campaign,Case,Event}/fields` | Custom `FOPS_*` fields added to standard objects |
| Custom tabs (6) | `tabs/FOPS_*.tab-meta.xml` | One tab per custom object |
| Lightning app | `applications/FreelanceOps.app-meta.xml` | The FreelanceOps app navigation |
| Permission sets (2) | `permissionsets/FOPS_Consultant`, `permissionsets/FOPS_Manager` | Role-based access |

**Data model — standard-first.** 13 candidate custom objects were reduced to 6.
The rest reuse standard objects:

| Concept | Object |
|---|---|
| Sourcing channel | Campaign |
| Job signal | Lead |
| Company | Account (record types: Direct Client · Recruiting Agency · End Client) |
| People | Contact (record types: Client Contact · Consultant) |
| Pursuit + Job Description | Opportunity (11 custom stages — see §4) |
| Interview rounds | Event (record types: Recruiter Screen · HR · Technical · Client/Final) |
| Skill catalogue | Product2 (record type: Skill) |
| Signed engagement | Contract |
| Invoice | Order |
| Invoice line | OrderItem |
| Support | Case (record types: Engagement Issue · Invoice Dispute · Recruiter Correspondence) |

The 6 custom objects (each justified because no standard object fits):
`FOPS_Assignment__c`, `FOPS_Timesheet__c`, `FOPS_Time_Entry__c`,
`FOPS_Skill_Requirement__c`, `FOPS_Consultant_Skill__c`, `FOPS_Payment__c`.

**The commercial core:** every `FOPS_Assignment__c` carries a **bill rate**
(client pays) and a **cost rate** (you pay the sub-contractor). Margin is the
difference. Utilisation, gross margin and cash forecast all derive from these.

---

## 2. Prerequisites

- Salesforce CLI (`sf`) v2+
- A Dev Hub org (the "ABC" Developer Edition org is Dev Hub **only** — never
  deploy FreelanceOps metadata to it by hand)
- All development happens in **scratch orgs**. This project's
  `config/project-scratch-def.json` already enables the features the package
  depends on:
  - **`MultiCurrency`** — the frozen-rate design and every `*_Base__c` field.
  - **`orderSettings.enableOrders`** — the package adds 17 custom fields to
    `Order` and 6 to `OrderItem` (the Invoice / Invoice Line model). Without
    Orders enabled the target org has no `Order` object and the deploy fails
    with *"Order is not enabled"* / an unknown-object error on those fields.

  > The target org must have **both** features on. This is the most common
  > reason the package "won't deploy" even though the metadata is valid — see
  > §7 Troubleshooting.

> ⚠️ **Never enable Multiple Currencies in a persistent org** without an
> explicit, recorded decision — it is irreversible.

---

## 3. Deploy to a scratch org

From the SFDX project root (the directory containing `force-app/`):

```bash
# 1. Create a scratch org (MultiCurrency is enabled by the scratch def)
sf org create scratch -f config/project-scratch-def.json -a fops-dev -d -y 30

# 2. Activate the trading currencies (USD is corporate by default).
#    FX rates below are PLACEHOLDERS — correct them before any real billing.
sf data create record -s CurrencyType -v "IsoCode=AUD ConversionRate=1.52 DecimalPlaces=2 IsActive=true" -o fops-dev
sf data create record -s CurrencyType -v "IsoCode=SGD ConversionRate=1.35 DecimalPlaces=2 IsActive=true" -o fops-dev
sf data create record -s CurrencyType -v "IsoCode=VND ConversionRate=25400 DecimalPlaces=0 IsActive=true" -o fops-dev
sf data create record -s CurrencyType -v "IsoCode=EUR ConversionRate=0.92 DecimalPlaces=2 IsActive=true" -o fops-dev
sf data create record -s CurrencyType -v "IsoCode=GBP ConversionRate=0.79 DecimalPlaces=2 IsActive=true" -o fops-dev

# 3. Deploy the FreelanceOps metadata (validate first)
sf project deploy start --dry-run -d force-app/main/default -o fops-dev
sf project deploy start -d force-app/main/default -o fops-dev

# 4. Assign a permission set to yourself
sf org assign permset -n FOPS_Manager -o fops-dev

# 5. Open the app
sf org open -o fops-dev -p /lightning/app/FreelanceOps
```

To deploy **only** the FreelanceOps schema (excluding the UI bundle and the
MongoDB package), target the specific folders:

```bash
sf project deploy start -o fops-dev \
  -d force-app/main/default/objects \
  -d force-app/main/default/tabs \
  -d force-app/main/default/permissionsets \
  -d force-app/main/default/applications
```

---

## 4. Setup-only steps (cannot be deployed from source)

These must be done by hand in **Setup** after the metadata deploys. Nothing in
the app behaves correctly until steps 1 and 2 are complete.

### 4.1 Assign record types to profiles and layouts
The 13 record types are now **source-controlled** and deploy with the package
(`objects/<Object>/recordTypes/`):

- Account ×3 — Direct Client, Recruiting Agency, End Client
- Contact ×2 — Client Contact, Consultant
- Product2 ×1 — Skill
- Event ×4 — Recruiter Screen, HR, Technical, Client/Final
- Case ×3 — Engagement Issue, Invoice Dispute, Recruiter Correspondence
  (backed by the `FOPS_Case_Process` business process, also in source)

The record types deploy against the **default page layout**. Two Setup steps
remain (they cannot be reliably deployed without also managing full Profile and
Layout metadata): grant each record type to the relevant **profiles /
permission sets** (System Administrator sees them automatically), and, if you
want the `FOPS_*` fields to appear on screen, add them to the page layouts (or
deploy custom Layouts — ask if you want those generated).

### 4.2 Create the 11 Opportunity stages, then deactivate the 10 stock stages
Opportunity stages cannot be inserted as records or reliably deployed — create
them in **Setup → Opportunity → Stages**:

| Stage | Probability | Forecast Category |
|---|---|---|
| JD Received | 5% | Pipeline |
| Profile Submitted | 15% | Pipeline |
| Recruiter Screen | 25% | Pipeline |
| HR Interview | 40% | Pipeline |
| Technical Assessment | 55% | Best Case |
| Client/Final Interview | 70% | Best Case |
| Offer & Rate Negotiation | 85% | Commit |
| Contracting | 95% | Commit |
| Closed Won — Engaged | 100% | Closed |
| Closed Lost | 0% | Omitted |
| Closed — Withdrawn | 0% | Omitted |

> Keep **Closed Lost** and **Closed — Withdrawn** separate: failing an
> interview and declining a bad rate are opposite signals.

### 4.3 Correct the FX rates and enable Advanced Currency Management
The conversion rates seeded in §3 are placeholders. Correct them, then enable
Advanced Currency Management for dated rates on Opportunity.

### 4.4 Pricebook (for invoicing)
Create one `PricebookEntry` per Skill product **per currency** — six active
currencies means six entries per product.

---

## 5. Non-negotiable design rules (do not "helpfully" break these)

1. **Do not adopt standard `TimeSheet`/`TimeSheetEntry`.** They require a
   ServiceResource → User → licence (only one spare full licence exists) and
   store clock times, not an hours decimal. `FOPS_Timesheet__c` /
   `FOPS_Time_Entry__c` exist for this reason.
2. **Frozen-rate pattern.** Every financial record stores
   `FOPS_Exchange_Rate_Used__c`, `FOPS_Exchange_Rate_Date__c`, and a stored
   `*_Base__c` currency amount (never a formula). Correcting an FX rate later
   must not silently change historical invoices.
3. **Bill rate and margin are invisible to sub-contractors.** Rate/cost/margin
   fields are `readable=false` in `FOPS_Consultant.permissionset-meta.xml`
   (including the Time Entry snapshots: `FOPS_Bill_Rate_Snapshot__c`,
   `FOPS_Cost_Rate_Snapshot__c`, `FOPS_Billable_Amount__c`). **Any new
   rate/cost/margin field must be added to that list in the same commit** —
   `FOPS_FieldSecurityTest` asserts it.
4. **Invoice numbering must be gapless.** Use `FOPS_Invoice_Number__c`
   (populated by `SequenceService`), not `OrderNumber` or Auto Number, which
   burn numbers on failed inserts.
5. **Invoices generate as Draft.** A human issues them — never auto-issue to a
   client.

---

## 6. What is not yet built

Apex service layer (`CurrencyService`, `SequenceService`,
`RateNormalisationService`, `Logger`, `FOPS_FieldSecurityTest`), Flows, the
`timeLogger` LWC, invoice generation/PDF, reports and dashboards, and
Email-to-Case. See the handoff prompt and blueprint docs for the full backlog
and dependency order.

---

## 7. Troubleshooting a failed deploy

The metadata is internally validated: every XML file is well-formed, every
permission-set / app / tab reference resolves, every `referenceTo`, formula
reference, and roll-up summary (`summarizedField` / `summaryForeignKey` /
filter) points at a field that exists in the package, and every picklist
carries an inline value set. So a deploy failure is almost always an **org
feature or target** problem, not missing metadata. Check these in order:

| Symptom | Cause | Fix |
|---|---|---|
| `Order is not enabled` / unknown object on `Order`/`OrderItem` fields | Orders feature off in the target org | Enable Orders. Scratch: already set via `orderSettings.enableOrders` in the scratch def — recreate the org. Persistent org: **Setup → Order Settings → Enable Orders**. |
| Errors on `*_Base__c` / currency fields, or `convertCurrency` | Multi-Currency off | Scratch: `MultiCurrency` is in the scratch def — recreate the org. Persistent org: enabling Multiple Currencies is **irreversible** — do it only with a recorded decision (see §2). |
| `INVALID_CROSS_REFERENCE` on a record-type field, or record types don't appear | The 13 record types are **not** in this package (they were created directly in the org) | Assign them in Setup (§4.1). They are not required for the schema deploy itself. |
| A field/object "already exists" or "insufficient access" on the **DE org** | Deploying FreelanceOps to the "ABC" Dev-Hub org by hand | Don't. It is a Dev Hub only — deploy to a **scratch org** (§3). |
| Deploy seems to hang or only some folders go | Deploying a partial source set | Deploy the four folders together: `objects`, `tabs`, `permissionsets`, `applications` (see §3), so cross-references resolve in one transaction. |
| `bad value for restricted picklist field: Event` on every Event field | Custom fields for Tasks/Events must live on the **Activity** object, not `Event` | Interview-round fields are under `objects/Activity/fields/` (they apply to Events). Don't move them back to `Event`. |
| `must specify either cascade delete or restrict delete for required lookup foreign key` | A **required** lookup used `SetNull` | Required lookups use `<deleteConstraint>Restrict</deleteConstraint>` (or `Cascade`). `SetNull` is only valid for optional lookups. |
| `Invalid summary filter: Use "True" or "False"` | A roll-up filter on a checkbox used `1`/`0` | Use `<value>True</value>` / `<value>False</value>`. |
| `<object> does not have history tracking enabled` | A field sets `trackHistory` but the object's history is off | Set `<enableHistory>true</enableHistory>` on the object (already done for Opportunity), or remove `trackHistory` from the field. |

Validate without deploying first — it reports the exact blocking component:

```bash
sf project deploy start --dry-run \
  -d force-app/main/default/objects \
  -d force-app/main/default/tabs \
  -d force-app/main/default/permissionsets \
  -d force-app/main/default/applications \
  -o <org>
```
