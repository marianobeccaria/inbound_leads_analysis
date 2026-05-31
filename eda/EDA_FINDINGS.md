# EDA SQL Scripts

This folder contains the clean, reproducible PostgreSQL EDA flow for the Inbound Leads Analytics project.

The scripts move from broad source discovery to business-rule validation:

```text
source inventory
  -> raw schema and JSON structure
  -> activity flattening and deduplication
  -> custom activity and field mapping
  -> funnel outcomes and sales source validation
  -> ordered funnel path validation
  -> user, objection, and revenue quality checks
```

## Run Order

Run the scripts in this order:

```text
01_source_table_inventory.sql
02_raw_row_counts.sql
03_table_schema_profile.sql
04_compact_raw_samples.sql
05_json_structure_profile.sql
06_activity_type_counts.sql
07_duplicate_and_load_profile.sql
08_custom_activity_type_mapping.sql
09_custom_field_mapping.sql
10_funnel_outcome_distributions.sql
11_sales_revenue_source_check.sql
12_lead_funnel_sequence_path_check.sql
13_user_mapping_coverage.sql
14_objection_category_profile.sql
15_revenue_quality_check.sql
```

## Script Purpose

| Script | Purpose |
|---|---|
| `01_source_table_inventory.sql` | Confirm source tables exist in the `raw` schema |
| `02_raw_row_counts.sql` | Count rows in each raw source table |
| `03_table_schema_profile.sql` | Inspect raw table columns and data types |
| `04_compact_raw_samples.sql` | Inspect compact JSON samples without printing full payloads |
| `05_json_structure_profile.sql` | Identify direct objects, arrays, and stringified JSON wrappers |
| `06_activity_type_counts.sql` | Count flattened activity events by `_type` |
| `07_duplicate_and_load_profile.sql` | Validate duplicate behavior and load-date volume |
| `08_custom_activity_type_mapping.sql` | Map `custom_activity_type_id` values to business activity names |
| `09_custom_field_mapping.sql` | Map `custom.cf_*` fields to business labels and activity types |
| `10_funnel_outcome_distributions.sql` | Profile deduplicated triage, prospecting, and strategy outcomes |
| `11_sales_revenue_source_check.sql` | Compare strategy sale outcomes against New Sale records |
| `12_lead_funnel_sequence_path_check.sql` | Validate ordered `initial -> strategy -> sale` funnel paths |
| `13_user_mapping_coverage.sql` | Confirm setter/closer IDs resolve to Close CRM users |
| `14_objection_category_profile.sql` | Normalize and count objection categories |
| `15_revenue_quality_check.sql` | Validate revenue fields for sales reporting |

## EDA Summary

The EDA moved from broad source discovery to business-rule validation:

```text
Source Inventory
      |
      v
Raw Structure Discovery
      |
      v
JSON Shape Discovery
      |
      v
Activity Flattening
      |
      v
CustomActivity Mapping
      |
      v
Funnel Outcome Profiling
      |
      v
Deduplication + Sequence Logic
      |
      v
User / Objection / Revenue Validation
      |
      v
Ready for Snowflake + dbt Modeling
```

## Visual Flow

```text
01-03: What data exists?
  raw tables, row counts, schemas
        |
        v
04-05: How is raw JSON shaped?
  raw_data jsonb, lead activities under raw_data -> data
        |
        v
06-07: What events exist and how reliable are they?
  500k+ flattened activities, duplicates confirmed
        |
        v
08-09: What do CustomActivity IDs and fields mean?
  activity type IDs + custom.cf_* fields mapped to business labels
        |
        v
10-11: What are the funnel outcomes and sales source of truth?
  outcomes profiled, New Sale chosen as sales/revenue source
        |
        v
12: Can the funnel be sequenced?
  initial -> strategy -> sale paths validated
        |
        v
13-15: Can reports be built?
  users resolve, objections normalize, revenue fields are usable
```

## Findings By Script Group

### `01_source_table_inventory.sql`

Confirmed the expected raw source tables exist:

```text
leads_raw
lead_activites_raw
close_crm_users_raw
custom_activites_raw
```

### `02_raw_row_counts.sql`

Established initial source volume:

```text
leads_raw: 37k+
lead_activites_raw: 31k+
close_crm_users_raw: 1k+
custom_activites_raw: 3
```

### `03_table_schema_profile.sql`

Confirmed all raw tables share:

```text
raw_data jsonb
insert_date timestamp
```

This told us all meaningful analysis should start from `raw_data`.

### `04_compact_raw_samples.sql`

Provides readable samples of each raw payload without printing the entire JSON object. This replaced the original full raw sample script because full JSON output was too wide for repeated use.

### `05_json_structure_profile.sql`

Found the key JSON shapes:

```text
leads_raw.raw_data = direct lead object
lead_activites_raw.raw_data -> 'data' = activity array
custom_activites_raw.raw_data -> 'JSON_OBJECT' = malformed stringified JSON
close_crm_users_raw.raw_data -> 'JSON_OBJECT' = malformed stringified JSON
```

### `06_activity_type_counts.sql`

Confirmed the activity mix:

```text
Call
SMS
Email
CustomActivity
Meeting
Note
Created
LeadMerge
```

`CustomActivity` is the primary funnel data source.

### `07_duplicate_and_load_profile.sql`

Confirmed:

```text
activities span 2026-02-26 onward
daily loads repeat historical activities
duplicates exist by lead_id + activity_id
date_updated changes across duplicate versions
```

Deduplication rule for Silver:

```text
PARTITION BY lead_id, activity_id
ORDER BY date_updated DESC NULLS LAST, activity_at DESC NULLS LAST
```

### `08_custom_activity_type_mapping.sql`

Mapped activity type IDs:

```text
Triage Call              = actitype_38341SWOKRkRHHAqWEqSJu
Strategy Call            = actitype_2VcSfZQX6FeIL8kkxy48C2
Strategy Call Follow Up  = actitype_6IrDujYE2WKg9QCFJdpXJk
New Sale                 = actitype_3E85vFq3a06LlEzXT2N1kS
Prospecting Activity     = actitype_4tEv1xumZEk9vYYs7WxYy7
Prospecting Follow Up    = actitype_6ga7msjJ7kZcH2rGtYETwe
```

### `09_custom_field_mapping.sql`

Mapped custom fields to business fields:

```text
Triage Call Outcome    = cf_h3tYb9J6yPK7J4PMExDGsEqPCf8kBGBrRNIur2Dm5aN
Strategy Call Outcome  = cf_dhJR4N7Rm6czuJthYGJP6KqUcuOzi7fqApGI7puWnMo
Prospecting Outcome    = cf_Q2fsrD8VpPaunZLtyiy7P3vG6qJTv0w1ESmlhdHU2ra
Offer Presented        = cf_LGyzSTMPy37y87rDOUmFXlZA42HPSIpbipeT2OsQNHW
Objections Faced       = cf_aIN5Gtqq33tUCCBxFTW63FY6d3mofnKIfFqfWPkvNla
Contract Value         = cf_vIanPjPEit6ssajmWkcprF2V1nO1itfes8hOSnjmhfT
Cash Collected         = cf_eyLbGJm9DYY7cuJk2otnCxhUEzK9ayEARiE81xPG5uY
Setter                 = cf_v385AJ8HSgepKQ3rvqo4yOA3nn49eGqz39DOqojJG5M
Closer                 = cf_Lv5lSqLOZwLrNhe5M7kWx2mF8Ge2Z23aw5NUNhbXvVS
```

### `10_funnel_outcome_distributions.sql`

Found exact funnel outcomes for triage, strategy, and prospecting.

This enabled KPI logic such as:

```text
Inbound booked = all triage calls
Inbound set = triage outcome = Strategy Call Scheduled
Strategy sale outcome = strategy outcome = Sale
Outbound set = prospecting outcome = Strategy Call Scheduled
```

This script uses deduplicated activities.

### `11_sales_revenue_source_check.sql`

Confirmed `New Sale` activity records are the correct source of truth for final sales and revenue, not only `Strategy Call Outcome = Sale`.

### `12_lead_funnel_sequence_path_check.sql`

Validated the best current funnel path logic:

```text
initial contact -> first strategy after initial -> first sale after strategy
```

This found valid ordered paths for inbound and outbound leads. It also confirmed that Gold models need matched and unmatched funnel categories because not every strategy call or sale can be linked to a prior funnel event.

Detailed exception analysis from archived scripts found:

```text
strategy_without_prior_initial: 488 events / 371 leads
sale_without_prior_strategy:     60 events / 60 leads
```

### `13_user_mapping_coverage.sql`

Confirmed user mapping works:

```text
379 users parsed
all setter/closer user IDs matched to user metadata
```

This means `DIM_USER` can support setter and closer reporting.

### `14_objection_category_profile.sql`

Confirmed objections are array-like text and can be normalized:

```text
["Money"]
["Logistical", "Money"]
```

Top categories include:

```text
No Show
Money
Think About It
No Objections
Logistical
Partner
Time
Fear
```

`No Show` appears in the objection field but is not one of the required objection categories, so it should be modeled explicitly and reviewed for reporting treatment.

### `15_revenue_quality_check.sql`

Validated revenue quality:

```text
New Sale: 157 records, 153 populated revenue rows
Backend Sale: 40 records
Additional Cash Collected: 27 records
No invalid numeric values
Some zero or missing revenue values exist
```

Revenue fields are usable, but Gold models should flag missing and zero values for data quality visibility.

## Key EDA Rules

The source data refresh repeats historical activities. Any metric-facing analysis should deduplicate activities with:

```text
PARTITION BY lead_id, activity_id
ORDER BY date_updated DESC NULLS LAST, activity_at DESC NULLS LAST
```

Lead activity flattening uses:

```text
raw.lead_activites_raw.raw_data -> 'data'
```

Custom activity metadata and users are stored as malformed stringified JSON under:

```text
raw_data -> 'JSON_OBJECT'
```

The clean scripts use regex where needed because simple JSON casting is not reliable for those malformed strings.

## Recommended Next Work & DBT Transformations

  1. Create Snowflake Bronze DDL and stage/COPY scripts.
  2. Define dbt sources.yml for Bronze tables.
  3. Build Silver staging models:
     - stg_leads
     - stg_lead_activities_flattened
     - stg_custom_activity_types
     - stg_custom_activity_fields
     - stg_users
  4. Build Silver intermediate models:
     - int_deduped_activities
     - int_custom_activity_events
     - int_funnel_events
     - int_funnel_paths
  5. Build Gold facts/dimensions:
     - dim_user
     - dim_lead
     - dim_activity_type
     - fact_lead_funnel
     - fact_sale
     - fact_objection
  6. Build reporting views:
     - rpt_inbound_setter
     - rpt_outbound_setter
     - rpt_closer
     - rpt_objections_faced

## Handoff to dbt

The EDA findings were converted into dbt reference seeds and audit models so the production pipeline does not depend only on hardcoded SQL values.

| EDA Finding | dbt Implementation |
|---|---|
| Custom activity type IDs identify funnel stages | `custom_activity_type_map.csv` |
| Custom field IDs identify business fields | `custom_field_map.csv` |
| Raw outcome labels define KPI behavior | `funnel_outcome_map.csv` |
| Objection values require normalization | `objection_category_map.csv` |
| New source values may appear over time | `audit_unmapped_*` models |

This creates an idempotent pattern:

```text
Raw Close CRM data
  -> deterministic Silver deduplication
  -> version-controlled reference mappings
  -> Gold facts and reports
  -> audit models for unmapped source drift
```

If Close CRM introduces a new custom activity type, custom field, or outcome value, the pipeline surfaces it through the Audit layer. The value can then be reviewed, classified in the appropriate seed, and rebuilt without changing core transformation logic.
