/*
    Audit model for custom.cf_* fields found in CustomActivity payloads but not
    present in the custom_field_map seed.

    Expected result:
    zero rows for fields needed by reporting.

    Some low-value fields may appear here initially. If they are not needed,
    either add them to the seed as inactive/reference-only or document why they
    are intentionally ignored.
*/

with custom_activity_events as (
    select *
    from {{ ref('silver_custom_activity_events') }}
),

activity_custom_fields as (
    select
        replace(activity_key.value::string, 'custom.', '') as custom_field_id,
        activity_key.value::string as raw_activity_key,
        custom_activity_events.custom_activity_type_id,
        custom_activity_events.lead_id,
        custom_activity_events.activity_id,
        custom_activity_events.activity_at
    from custom_activity_events,
    lateral flatten(input => object_keys(custom_activity_events.activity)) as activity_key
    where activity_key.value::string like 'custom.cf_%'
),

custom_field_map as (
    select custom_field_id
    from {{ ref('custom_field_map') }}
    where lower(is_active::string) = 'true'
)

select
    activity_custom_fields.custom_field_id,
    activity_custom_fields.raw_activity_key,
    count(*) as field_occurrence_count,
    count(distinct activity_custom_fields.activity_id) as distinct_activity_count,
    count(distinct activity_custom_fields.lead_id) as distinct_lead_count,
    min(activity_custom_fields.activity_at) as first_seen_at,
    max(activity_custom_fields.activity_at) as latest_seen_at
from activity_custom_fields
left join custom_field_map
    on activity_custom_fields.custom_field_id = custom_field_map.custom_field_id
where custom_field_map.custom_field_id is null
group by
    activity_custom_fields.custom_field_id,
    activity_custom_fields.raw_activity_key
