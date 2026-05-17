/*
    Gold dimension for Close CRM leads.

    Source:
      stg_bronze__leads_raw.

    Purpose:
      Provide one row per lead for BI drilldowns and future joins from funnel
      facts to lead names, statuses, and source-system audit metadata.
*/

with source as (
    select *
    from {{ ref('stg_bronze__leads_raw') }}
),

ranked_leads as (
    select
        *,
        -- Leads can appear in repeated daily extracts; keep the latest version.
        row_number() over (
            partition by lead_id
            order by lead_updated_at desc nulls last, insert_date desc nulls last
        ) as row_number_latest
    from source
    where lead_id is not null
),

deduped_leads as (
    select *
    from ranked_leads
    where row_number_latest = 1
)

select
    lead_id,
    lead_name,
    display_name,
    status_id,
    status_label,
    lead_created_at,
    lead_updated_at,
    created_by_user_id,
    updated_by_user_id,
    raw_data,
    source_file_name,
    source_row_number,
    load_date,
    insert_date,
    bronze_loaded_at
from deduped_leads
