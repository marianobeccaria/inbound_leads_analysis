/*
    Audit model for raw funnel outcome values not present in funnel_outcome_map.

    Expected result:
    zero rows.

    If rows appear, Close CRM has introduced or renamed an outcome option. Add
    the new value to funnel_outcome_map.csv with the correct business flags.
*/

with custom_activity_events as (
    select *
    from {{ ref('silver_custom_activity_events') }}
),

outcome_fields as (
    select
        custom_field_id,
        custom_field_name
    from {{ ref('custom_field_map') }}
    where lower(is_active::string) = 'true'
    and field_role = 'outcome'
),

observed_outcomes as (
    select
        outcome_fields.custom_field_name as field_name,
        get(
            custom_activity_events.activity,
            'custom.' || outcome_fields.custom_field_id
        )::string as raw_value,
        custom_activity_events.custom_activity_type_id,
        custom_activity_events.lead_id,
        custom_activity_events.activity_id,
        custom_activity_events.activity_at
    from custom_activity_events
    cross join outcome_fields
    where get(
        custom_activity_events.activity,
        'custom.' || outcome_fields.custom_field_id
    )::string is not null
    and get(
        custom_activity_events.activity,
        'custom.' || outcome_fields.custom_field_id
    )::string <> ''
),

funnel_outcome_map as (
    select
        field_name,
        raw_value
    from {{ ref('funnel_outcome_map') }}
)

select
    observed_outcomes.field_name,
    observed_outcomes.raw_value,
    count(*) as outcome_occurrence_count,
    count(distinct observed_outcomes.activity_id) as distinct_activity_count,
    count(distinct observed_outcomes.lead_id) as distinct_lead_count,
    min(observed_outcomes.activity_at) as first_seen_at,
    max(observed_outcomes.activity_at) as latest_seen_at
from observed_outcomes
left join funnel_outcome_map
    on observed_outcomes.field_name = funnel_outcome_map.field_name
    and observed_outcomes.raw_value = funnel_outcome_map.raw_value
where funnel_outcome_map.raw_value is null
group by
    observed_outcomes.field_name,
    observed_outcomes.raw_value

