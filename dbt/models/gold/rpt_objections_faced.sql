/*
    Gold report model for strategy-call objections.

    Source:
      fact_lead_funnel.

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
        strategy_funnels.strategy_at,
        strategy_funnels.closer_user_id,
        trim(objection.value::string) as source_objection_value
    from strategy_funnels,
    lateral flatten(input => strategy_funnels.objections_faced) as objection
),

normalized_objections as (
    select
        lead_funnel_id,
        lead_id,
        strategy_activity_id,
        strategy_at,
        closer_user_id,
        source_objection_value,
        case
            when source_objection_value ilike 'money'
                or source_objection_value ilike 'financial' then 'Money'
            when source_objection_value ilike 'fear' then 'Fear'
            when source_objection_value ilike 'hung up' then 'Hung Up'
            when source_objection_value ilike 'logistical' then 'Logistical'
            when source_objection_value ilike 'no objections' then 'No Objections'
            when source_objection_value ilike 'talking to other coaches' then 'Talking to Other Coaches'
            when source_objection_value ilike 'partner' then 'Partner'
            when source_objection_value ilike 'think about it' then 'Think About It'
            when source_objection_value ilike 'time' then 'Time'
            when source_objection_value ilike 'trust'
                or source_objection_value ilike 'uncertain about us' then 'Trust'
            when source_objection_value ilike 'value' then 'Value'
            when source_objection_value ilike 'wasn''t looking for what we offered'
                then 'Wasn''t Looking For What We Offered'
            when source_objection_value ilike 'no show' then 'No Show'
            else source_objection_value
        end as objection_category
    from flattened_objections
    where source_objection_value is not null
      and source_objection_value <> ''
),

total_strategy_calls as (
    select count(distinct strategy_activity_id) as strategy_calls_evaluated
    from normalized_objections
),

category_rollup as (
    select
        objection_category,
        count(*) as objection_count,
        count(distinct strategy_activity_id) as distinct_strategy_call_count,
        count(distinct lead_id) as distinct_lead_count
    from normalized_objections
    group by objection_category
)

select
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
cross join total_strategy_calls
