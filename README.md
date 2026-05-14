# Inbound Leads Analytics

## Project Overview

This project designs and implements an end-to-end data engineering pipeline for sales analytics. The goal is to provide a unified analytical view of inbound and outbound sales performance using Close CRM source data.

The pipeline tracks the full sales funnel:

```text
Initial Contact
  -> Triage Call for inbound leads
  -> Prospecting activity for outbound leads

Strategy Call
  -> booked, attended, no-show, canceled, follow-up, lost, sale

Sales Outcome
  -> sale status, contracted value, cash collected
```

The final solution should support BI dashboards for sales stakeholders, helping them measure conversion rates, sales team performance, funnel drop-offs, objections, and revenue outcomes.

## Source Data

The source system is PostgreSQL. Raw source tables are provided under the `raw` schema.

Important source tables:

```text
leads_raw
lead_activites_raw
close_crm_users_raw
custom_activites_raw
```

The source data is refreshed daily by `07:30 AM EST`.

## Key Data Characteristics

- Lead activity records are delivered as nested JSON.
- Activity types include `CustomActivity`, `SMS`, `Call`, `Meeting`, and `Note`.
- Core funnel KPIs are driven primarily by `CustomActivity` records.
- Daily refreshes include historical activity records for leads updated that day.
- The same activity can appear in multiple daily loads.
- Deduplication is required using `lead_id + activity_id`.
- The latest version of an activity should be retained using `activity_at`.
- Some inner JSON strings are malformed because they use single quotes instead of standard JSON double quotes.
- The pipeline must repair malformed JSON before parsing.
- Change data capture should be implemented using an `MD5_HASH`.
- Warehouse loads should use upserts with `MERGE INTO`.
- Audit fields such as `INSERT_DATE` and `UPDATE_DATE` should be included.

## Business Funnel

The main business hierarchy is:

```text
Initial Contact -> Strategy Call -> Sales Outcome
```

Inbound leads begin with a triage call. Outbound leads begin with prospecting activity. If the initial contact is successful, the lead moves to a strategy call. If the strategy call converts, a sale is recorded.

Example successful inbound journey:

```text
Triage Call
  Outcome: Strategy Call Booked

Strategy Call
  Outcome: Sale

Sale Recorded
  Contracted Value and Cash Collected captured
```

This hierarchy is important because all KPI logic depends on linking activities in the correct sequence. Without sequence-aware funnel modeling, the pipeline may double-count activities or misclassify leads.

## Required KPI Reports

### Inbound Setter Report

Tracks the performance of setters handling inbound triage calls.

Metrics:

- Inbound booked
- Inbound taken
- Show rate
- Triage set rate
- Strategy calls booked
- Strategy calls taken
- Offer rate
- Total sales
- Sale rate
- Average order value

### Outbound Setter Report

Tracks the performance of setters handling outbound prospecting activity.

Metrics:

- Total outbound calls
- Unique leads touched
- Outbound set
- Total closer show
- Dial-to-set rate
- Set-to-show rate
- Show-to-sale rate

### Closer Report

Tracks the performance of closers handling strategy calls.

Metrics:

- Calls booked
- Admin cancellations
- Nurture cancellations
- Not-interested cancellations
- No-shows
- Shows
- Lost deals
- Sales
- Average contract value
- Total cash collected

### Objections Faced Report

Analyzes the reasons prospects do not buy during strategy calls.

Objection categories:

- Money
- Fear
- Hung up
- Logistical
- No objections
- Talking to other coaches
- Partner
- Think about it
- Time
- Trust
- Value
- Wasn't looking for what was offered

Metrics:

- Total strategy calls evaluated
- Count by objection category
- Percentage by objection category

## Architecture

The project should use a Snowflake medallion architecture:

```text
PostgreSQL / S3 Raw Files
        |
        v
Bronze Layer
Raw loaded JSON / variant tables
        |
        v
Silver Layer
Parsed, flattened, deduplicated, normalized activity data
        |
        v
Gold Layer
Business facts, dimensions, funnel models, KPI views
        |
        v
BI Dashboard
```

## Bronze Layer

The Bronze layer preserves raw source data with minimal transformation.

Suggested Bronze tables:

```text
BRONZE.CLOSE_CRM_USERS_RAW
BRONZE.CUSTOM_ACTIVITIES_RAW
BRONZE.LEAD_ACTIVITIES_RAW
BRONZE.LEADS_RAW
```

Recommended common columns:

```text
RAW_DATA VARIANT
SOURCE_FILE_NAME
LOAD_DATE
INSERT_DATE
```

Bronze ingestion should use Snowflake stages and `COPY INTO` commands. The raw data should remain replayable so that Silver parsing logic can be corrected without extracting from the source again.

## Silver Layer

The Silver layer cleans, repairs, flattens, deduplicates, and normalizes the source data.

Suggested Silver tables:

```text
SILVER.USERS
SILVER.CUSTOM_ACTIVITY_TYPES
SILVER.CUSTOM_ACTIVITY_FIELDS
SILVER.CUSTOM_ACTIVITY_CHOICES
SILVER.LEADS
SILVER.ACTIVITIES
SILVER.CUSTOM_ACTIVITY_EVENTS
SILVER.CALL_EVENTS
SILVER.SMS_EVENTS
SILVER.MEETING_EVENTS
SILVER.NOTE_EVENTS
```

Key Silver responsibilities:

- Flatten nested arrays such as `masked_activities`, `raw_data`, and `data`.
- Repair malformed JSON before parsing.
- Extract base activity objects dynamically.
- Normalize Close CRM users.
- Normalize custom activity metadata.
- Map custom field IDs to business labels.
- Map choice IDs to readable outcomes.
- Identify funnel-relevant activities.
- Generate `MD5_HASH` values for CDC.
- Deduplicate using `lead_id + activity_id`.
- Keep the latest activity record using `activity_at`.
- Load data through `MERGE INTO` upserts.

## Gold Layer

The Gold layer exposes business-ready tables and views for reporting.

Suggested dimensions:

```text
GOLD.DIM_DATE
GOLD.DIM_USER
GOLD.DIM_LEAD
GOLD.DIM_ACTIVITY_TYPE
GOLD.DIM_OUTCOME
```

Suggested facts:

```text
GOLD.FACT_TRIAGE_CALL
GOLD.FACT_OUTBOUND_PROSPECTING
GOLD.FACT_STRATEGY_CALL
GOLD.FACT_SALE
GOLD.FACT_LEAD_FUNNEL
GOLD.FACT_OBJECTION
```

Suggested report views:

```text
GOLD.RPT_INBOUND_SETTER
GOLD.RPT_OUTBOUND_SETTER
GOLD.RPT_CLOSER
GOLD.RPT_OBJECTIONS_FACED
```

The most important Gold model is `GOLD.FACT_LEAD_FUNNEL`, which should link events in timestamp order:

```text
lead_id
triage_activity_id
triage_at
setter_user_id
triage_outcome
strategy_activity_id
strategy_at
closer_user_id
strategy_outcome
sale_activity_id
sale_at
contracted_value
cash_collected
objection_category
funnel_source
```

## Processing Plan

1. Confirm business definitions and funnel mapping with the SME.
2. Create Snowflake database, schemas, stages, and file formats.
3. Create Bronze raw tables.
4. Build `COPY INTO` ingestion scripts.
5. Build malformed JSON repair logic.
6. Flatten and normalize activity data into Silver tables.
7. Normalize custom activity metadata.
8. Map custom fields and choice values to business outcomes.
9. Implement deduplication and CDC using `MD5_HASH`.
10. Implement `MERGE INTO` upsert logic.
11. Build funnel sequencing logic.
12. Create Gold dimension and fact tables.
13. Create the four required Gold reporting views.
14. Validate KPI output against source samples.
15. Schedule daily orchestration after the source refresh.
16. Run the pipeline for 7 daily loads to simulate production.
17. Connect the Gold layer to a BI dashboard.
18. Document the architecture, ERD, assumptions, and known edge cases.

## Orchestration Plan

The pipeline should run daily after the source refresh window.

Recommended sequence:

```text
1. Land source extracts in S3.
2. Load files into Bronze using Snowflake COPY INTO.
3. Parse, clean, flatten, and deduplicate into Silver.
4. Build or refresh Gold facts and dimensions.
5. Refresh report views.
6. Track processed files.
7. Archive or purge processed staged files using date-based patterns.
```

## Implementation Risks

The highest-risk area is custom activity mapping. Close CRM custom activity structures are dynamic, and KPI accuracy depends on correctly translating field IDs and choice values into business funnel outcomes.

Before final implementation, validate these mappings with the SME:

- Triage activity type IDs
- Prospecting activity type IDs
- Strategy call activity type IDs
- Sale activity type IDs
- Outcome choice values
- Objection field values
- Revenue fields
- Setter and closer assignment fields
