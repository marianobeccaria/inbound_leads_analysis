/*
    Gold report model for outbound setter performance.

    Sources:
    fact_lead_funnel, dim_user, and funnel_outcome_map.

    Purpose:
    Summarize outbound prospecting performance by setter using normalized
    outcome mappings instead of raw hardcoded outcome values.
*/

with outbound_funnels as (
    select *
    from {{ ref('fact_lead_funnel') }}
    where funnel_source = 'outbound'
),

outcome_map as (
    select *
    from {{ ref('funnel_outcome_map') }}
),

mapped_funnels as (
    select
        outbound_funnels.*,
        initial_outcome_map.normalized_value as initial_normalized_outcome,
        strategy_outcome_map.is_taken as strategy_is_taken
    from outbound_funnels
    left join outcome_map as initial_outcome_map
        on initial_outcome_map.field_name = 'Prospecting Call Outcome'
        and outbound_funnels.initial_outcome = initial_outcome_map.raw_value
    left join outcome_map as strategy_outcome_map
        on strategy_outcome_map.field_name = 'Strategy Call Outcome'
        and outbound_funnels.strategy_outcome = strategy_outcome_map.raw_value
),

setter_rollup as (
    select
        initial_at::date as report_date,
        setter_user_id,
        count(*) as total_outbound_calls,
        count(distinct lead_id) as unique_leads_touched,

        -- This preserves the current KPI definition: outbound set means
        -- prospecting outcome scheduled a strategy call.
        count_if(initial_normalized_outcome = 'Strategy Call Scheduled') as outbound_set,

        count(strategy_activity_id) as strategy_calls_booked,

        count_if(
            strategy_activity_id is not null
            and lower(coalesce(strategy_is_taken::string, 'false')) = 'true'
        ) as total_closer_show,

        count(sale_activity_id) as total_sales,
        sum(contract_value) as total_contract_value,
        sum(cash_collected) as total_cash_collected
    from mapped_funnels
    group by initial_at::date, setter_user_id
),

final as (
    select
        setter_rollup.report_date,
        setter_rollup.setter_user_id,
        dim_user.full_name as setter_name,
        dim_user.email as setter_email,
        setter_rollup.total_outbound_calls,
        setter_rollup.unique_leads_touched,
        setter_rollup.outbound_set,
        setter_rollup.strategy_calls_booked,
        setter_rollup.total_closer_show,
        setter_rollup.total_sales,
        setter_rollup.total_contract_value,
        setter_rollup.total_cash_collected,
        round(setter_rollup.outbound_set / nullif(setter_rollup.total_outbound_calls, 0), 4) as dial_to_set_rate,
        round(setter_rollup.total_closer_show / nullif(setter_rollup.outbound_set, 0), 4) as set_to_show_rate,
        round(setter_rollup.total_sales / nullif(setter_rollup.total_closer_show, 0), 4) as show_to_sale_rate,
        round(setter_rollup.total_contract_value / nullif(setter_rollup.total_sales, 0), 2) as average_order_value
    from setter_rollup
    left join {{ ref('dim_user') }} as dim_user
        on setter_rollup.setter_user_id = dim_user.user_id
)

select *
from final
