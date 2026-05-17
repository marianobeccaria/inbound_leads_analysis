/*
    Silver model for deduplicated Close CRM CustomActivity events.

    Source:
      silver_activities.

    Purpose:
      Keep only activity_type = 'CustomActivity' because these records drive the
      business funnel. Daily loads can repeat the same activity, so this model
      keeps the latest version by lead_id + activity_id.
*/

with custom_activities as (
    select *
    from {{ ref('silver_activities') }}
    where activity_type = 'CustomActivity'
),

ranked as (
    select
        *,
        -- Keep the newest version of each repeated activity across daily loads.
        row_number() over (
            partition by lead_id, activity_id
            order by activity_updated_at desc nulls last, activity_at desc nulls last
        ) as row_number_latest
    from custom_activities
)

select *
from ranked
where row_number_latest = 1
