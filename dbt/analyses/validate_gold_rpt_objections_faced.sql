with source_objections as (
    select
        lead_funnel_id,
        strategy_activity_id,
        objections_faced
    from {{ ref('fact_lead_funnel') }}
    where strategy_activity_id is not null
      and objections_faced is not null
),

flattened as (
    select
        lead_funnel_id,
        strategy_activity_id,
        trim(objection.value::string) as source_objection_value
    from source_objections,
    lateral flatten(input => source_objections.objections_faced) as objection
    where trim(objection.value::string) <> ''
),

report_totals as (
    select
        sum(objection_count) as report_objection_count,
        sum(distinct_strategy_call_count) as summed_distinct_strategy_call_count,
        max(strategy_calls_evaluated) as strategy_calls_evaluated
    from {{ ref('rpt_objections_faced') }}
)

select
    count(*) as flattened_objection_count,
    count(distinct strategy_activity_id) as distinct_strategy_calls_with_objections,
    report_totals.report_objection_count,
    report_totals.strategy_calls_evaluated,
    report_totals.report_objection_count - count(*) as objection_count_diff,
    report_totals.strategy_calls_evaluated - count(distinct strategy_activity_id) as strategy_calls_evaluated_diff
from flattened
cross join report_totals
group by
    report_totals.report_objection_count,
    report_totals.strategy_calls_evaluated
