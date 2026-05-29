/*
    Gold report model for outbound setter performance.

    Sources:
      fact_lead_funnel and dim_user.

    Purpose:
      Summarize outbound prospecting performance by setter. This model uses
      ordered funnel paths so strategy calls and sales are only counted when
      they happen after the outbound initial contact.
*/

with outbound_funnels as (
    select *
    from {{ ref('fact_lead_funnel') }}
    where funnel_source = 'outbound'
),

setter_rollup as (
    select
        initial_at::date as report_date,
        setter_user_id,
        count(*) as total_outbound_calls,
        count(distinct lead_id) as unique_leads_touched,

        -- EDA defined outbound set as prospecting outcome = Strategy Call Scheduled.
        count_if(initial_outcome = '2. Strategy Call Scheduled') as outbound_set,

        count(strategy_activity_id) as strategy_calls_booked,

        -- A closer show is a strategy call that was not canceled, no-showed, rescheduled, or blank.
        count_if(
            strategy_activity_id is not null
            and strategy_outcome is not null
            and strategy_outcome not in (
                '2. Admin Cancel',
                '3. Cancel- Not Interested',
                '4. No Show',
                '5. Reschedule',
                '8. Cancel- Nurture',
                '8. Cancel',
                ''
            )
        ) as total_closer_show,

        count(sale_activity_id) as total_sales,
        sum(contract_value) as total_contract_value,
        sum(cash_collected) as total_cash_collected
    from outbound_funnels
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
