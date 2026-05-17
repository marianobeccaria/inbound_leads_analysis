select
    lead_id,
    activity_id,
    count(*) as duplicate_count
from {{ ref('silver_custom_activity_events') }}
group by lead_id, activity_id
having count(*) > 1
limit 50;
