/*
    Gold report model for closer performance.

    Sources:
    fact_lead_funnel, dim_user, and funnel_outcome_map.

    Purpose:
    Summarize strategy call outcomes by closer using normalized outcome
    categories and flags from reference seeds.
*/

with strategy_funnels as (
    select *
    from {{ ref('fact_lead_funnel') }}
    where strategy_activity_id is not null
),

outcome_map as (
    select *
    from {{ ref('funnel_outcome_map') }}
    where field_name = 'Strategy Call Outcome'
),

mapped_funnels as (
    select
        strategy_funnels.*,
        outcome_map.normalized_value as normalized_strategy_outcome,
        outcome_map.outcome_category as strategy_outcome_category,
        outcome_map.is_taken as strategy_is_taken
    from strategy_funnels
    left join outcome_map
        on strategy_funnels.strategy_outcome = outcome_map.raw_value
),

closer_rollup as (
    select
        strategy_at::date as report_date,
        closer_user_id,
        count(*) as calls_booked,
        count_if(normalized_strategy_outcome = 'Admin Cancel') as admin_cancellations,
        count_if(normalized_strategy_outcome = 'Cancel - Nurture') as nurture_cancellations,
        count_if(normalized_strategy_outcome = 'Cancel - Not Interested') as not_interested_cancellations,
        count_if(strategy_outcome_category = 'no_show') as no_shows,

        count_if(lower(coalesce(strategy_is_taken::string, 'false')) = 'true') as shows,

        count_if(strategy_outcome_category = 'lost') as lost_deals,

        -- Final sales and revenue use linked New Sale activities, not only strategy outcome.
        count(sale_activity_id) as sales,
        sum(contract_value) as total_contract_value,
        sum(cash_collected) as total_cash_collected
    from mapped_funnels
    group by strategy_at::date, closer_user_id
),

final as (
    select
        closer_rollup.report_date,
        closer_rollup.closer_user_id,
        dim_user.full_name as closer_name,
        dim_user.email as closer_email,
        closer_rollup.calls_booked,
        closer_rollup.admin_cancellations,
        closer_rollup.nurture_cancellations,
        closer_rollup.not_interested_cancellations,
        closer_rollup.no_shows,
        closer_rollup.shows,
        closer_rollup.lost_deals,
        closer_rollup.sales,
        closer_rollup.total_contract_value,
        closer_rollup.total_cash_collected,
        round(closer_rollup.shows / nullif(closer_rollup.calls_booked, 0), 4) as show_rate,
        round(closer_rollup.sales / nullif(closer_rollup.shows, 0), 4) as show_to_sale_rate,
        round(closer_rollup.total_contract_value / nullif(closer_rollup.sales, 0), 2) as average_contract_value
    from closer_rollup
    left join {{ ref('dim_user') }} as dim_user
        on closer_rollup.closer_user_id = dim_user.user_id
)

select *
from final
