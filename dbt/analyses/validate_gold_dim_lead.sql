select
    count(*) as dim_lead_row_count,
    count(distinct lead_id) as distinct_lead_count,
    count(*) - count(distinct lead_id) as duplicate_lead_id_count,
    count_if(lead_name is null and display_name is null) as missing_name_count,
    count_if(status_label is null) as missing_status_label_count,
    min(lead_created_at) as min_lead_created_at,
    max(lead_created_at) as max_lead_created_at,
    min(lead_updated_at) as min_lead_updated_at,
    max(lead_updated_at) as max_lead_updated_at
from {{ ref('dim_lead') }}
