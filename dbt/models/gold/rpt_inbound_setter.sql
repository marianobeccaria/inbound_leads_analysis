/*
    Gold report model for inbound setter performance.

    Sources:
    fact_lead_funnel, dim_user, and funnel_outcome_map.

    Purpose:
    Summarize inbound triage performance by setter using normalized outcome
    flags from reference seeds instead of hardcoded raw outcome values.
*/

with inbound_funnels as (
    select *
    from {{ ref('fact_lead_funnel') }}
    where funnel_source = 'inbound'
),

outcome_map as (
    select *
    from {{ ref('funnel_outcome_map') }}
),

mapped_funnels as (
    select
        inbound_funnels.*,
        initial_outcome_map.is_taken as initial_is_taken,
        initial_outcome_map.is_set as initial_is_set,
        strategy_outcome_map.is_taken as strategy_is_taken
    from inbound_funnels
    left join outcome_map as initial_outcome_map
        on initial_outcome_map.field_name = 'Triage Call Outcome'
        and inbound_funnels.initial_outcome = initial_outcome_map.raw_value
    left join outcome_map as strategy_outcome_map
        on strategy_outcome_map.field_name = 'Strategy Call Outcome'
        and inbound_funnels.strategy_outcome = strategy_outcome_map.raw_value
),

setter_rollup as (
    select
        initial_at::date as report_date,
        setter_user_id,
        count(*) as inbound_booked,

        count_if(lower(coalesce(initial_is_taken::string, 'false')) = 'true') as inbound_taken,
        count_if(lower(coalesce(initial_is_set::string, 'false')) = 'true') as triage_set,

        count(strategy_activity_id) as strategy_calls_booked,

        count_if(
            strategy_activity_id is not null
            and lower(coalesce(strategy_is_taken::string, 'false')) = 'true'
        ) as strategy_calls_taken,

        count_if(offer_presented is not null and offer_presented <> '') as offers_presented,
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
        setter_rollup.inbound_booked,
        setter_rollup.inbound_taken,
        setter_rollup.triage_set,
        setter_rollup.strategy_calls_booked,
        setter_rollup.strategy_calls_taken,
        setter_rollup.offers_presented,
        setter_rollup.total_sales,
        setter_rollup.total_contract_value,
        setter_rollup.total_cash_collected,
        round(setter_rollup.inbound_taken / nullif(setter_rollup.inbound_booked, 0), 4) as show_rate,
        round(setter_rollup.triage_set / nullif(setter_rollup.inbound_taken, 0), 4) as triage_set_rate,
        round(setter_rollup.offers_presented / nullif(setter_rollup.strategy_calls_taken, 0), 4) as offer_rate,
        round(setter_rollup.total_sales / nullif(setter_rollup.strategy_calls_taken, 0), 4) as sale_rate,
        round(setter_rollup.total_contract_value / nullif(setter_rollup.total_sales, 0), 2) as average_order_value
    from setter_rollup
    left join {{ ref('dim_user') }} as dim_user
        on setter_rollup.setter_user_id = dim_user.user_id
)

select *
from final
