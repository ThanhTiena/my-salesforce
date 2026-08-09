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
  `config/project-scratch-def.json` already enables the `MultiCurrency`
  feature, which the frozen-rate design depends on.

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

### 4.1 Assign record types to layouts and profiles
The 13 record types (Account ×3, Contact ×2, Product2 ×1, Event ×4, Case ×3)
must be enabled on the relevant profiles and mapped to page layouts.

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
3. **Bill rate and margin are invisible to sub-contractors.** Ten fields are
   `readable=false` in `FOPS_Consultant.permissionset-meta.xml`. **Any new
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
