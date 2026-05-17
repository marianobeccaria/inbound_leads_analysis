with custom_activities as (
    select *
    from {{ ref('int_lead_activities_flattened') }}
    where activity_type = 'CustomActivity'
),

ranked as (
    select
        *,
        row_number() over (
            partition by lead_id, activity_id
            order by activity_updated_at desc nulls last, activity_at desc nulls last
        ) as row_number_latest
    from custom_activities
)

select *
from ranked
where row_number_latest = 1
