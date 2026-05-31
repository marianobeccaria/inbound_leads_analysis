/*
    Gold report model for strategy-call objections.

    Sources:
    fact_lead_funnel and objection_category_map.

    Purpose:
    Normalize the Objections Faced custom field into one row per objection
    category for BI reporting. Objections can contain multiple array values
    such as ["Logistical", "Money"], so this model flattens them.
*/

with strategy_funnels as (
    select
        lead_funnel_id,
        lead_id,
        strategy_activity_id,
        strategy_at::date as report_date,
        strategy_at,
        closer_user_id,
        objections_faced
    from {{ ref('fact_lead_funnel') }}
    where strategy_activity_id is not null
    and objections_faced is not null
),

flattened_objections as (
    select
        strategy_funnels.lead_funnel_id,
        strategy_funnels.lead_id,
        strategy_funnels.strategy_activity_id,
        strategy_funnels.report_date,
        strategy_funnels.strategy_at,
        strategy_funnels.closer_user_id,
        trim(objection.value::string) as source_objection_value
    from strategy_funnels,
    lateral flatten(input => strategy_funnels.objections_faced) as objection
),

objection_category_map as (
    select
        source_objection_value,
        normalized_objection_category
    from {{ ref('objection_category_map') }}
    where lower(is_active::string) = 'true'
),

normalized_objections as (
    select
        flattened_objections.lead_funnel_id,
        flattened_objections.lead_id,
        flattened_objections.strategy_activity_id,
        flattened_objections.report_date,
        flattened_objections.strategy_at,
        flattened_objections.closer_user_id,
        flattened_objections.source_objection_value,
        coalesce(
            objection_category_map.normalized_objection_category,
            flattened_objections.source_objection_value
        ) as objection_category
    from flattened_objections
    left join objection_category_map
        on lower(flattened_objections.source_objection_value)
            = lower(objection_category_map.source_objection_value)
    where flattened_objections.source_objection_value is not null
    and flattened_objections.source_objection_value <> ''
),

total_strategy_calls as (
    select
        report_date,
        count(distinct strategy_activity_id) as strategy_calls_evaluated
    from strategy_funnels
    group by report_date
),

category_rollup as (
    select
        report_date,
        objection_category,
        count(*) as objection_count,
        count(distinct strategy_activity_id) as distinct_strategy_call_count,
        count(distinct lead_id) as distinct_lead_count
    from normalized_objections
    group by report_date, objection_category
)

select
    category_rollup.report_date,
    category_rollup.objection_category,
    category_rollup.objection_count,
    category_rollup.distinct_strategy_call_count,
    category_rollup.distinct_lead_count,
    total_strategy_calls.strategy_calls_evaluated,
    round(
        category_rollup.distinct_strategy_call_count
        / nullif(total_strategy_calls.strategy_calls_evaluated, 0),
        4
    ) as strategy_call_percentage
from category_rollup
left join total_strategy_calls
    on category_rollup.report_date = total_strategy_calls.report_date
