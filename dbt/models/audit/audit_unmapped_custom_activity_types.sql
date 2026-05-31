/*
    Audit model for Close CRM CustomActivity type IDs not present in the
    custom_activity_type_map seed.

    Expected result:
    zero rows.

    If rows appear, Close CRM introduced a custom activity type that has not
    been classified into a funnel stage or business category yet.
*/

with custom_activity_events as (
    select *
    from {{ ref('silver_custom_activity_events') }}
),

activity_type_map as (
    select custom_activity_type_id
    from {{ ref('custom_activity_type_map') }}
    where lower(is_active::string) = 'true'
)

select
    custom_activity_events.custom_activity_type_id,
    count(*) as event_count,
    count(distinct custom_activity_events.lead_id) as distinct_lead_count,
    min(custom_activity_events.activity_at) as first_seen_at,
    max(custom_activity_events.activity_at) as latest_seen_at
from custom_activity_events
left join activity_type_map
    on custom_activity_events.custom_activity_type_id
        = activity_type_map.custom_activity_type_id
where activity_type_map.custom_activity_type_id is null
group by custom_activity_events.custom_activity_type_id
