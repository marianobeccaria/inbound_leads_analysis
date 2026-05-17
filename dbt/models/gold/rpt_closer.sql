/*
    Gold report model for closer performance.

    Sources:
      fact_lead_funnel and dim_user.

    Purpose:
      Summarize strategy call outcomes by closer. This report evaluates the
      closer stage of the funnel, including cancellations, shows, lost deals,
      sales, contract value, and cash collected.
*/

with strategy_funnels as (
    select *
    from {{ ref('fact_lead_funnel') }}
    where strategy_activity_id is not null
),

closer_rollup as (
    select
        closer_user_id,
        count(*) as calls_booked,
        count_if(strategy_outcome = '2. Admin Cancel') as admin_cancellations,
        count_if(strategy_outcome = '8. Cancel- Nurture') as nurture_cancellations,
        count_if(strategy_outcome = '3. Cancel- Not Interested') as not_interested_cancellations,
        count_if(strategy_outcome = '4. No Show') as no_shows,

        -- Shows exclude canceled, no-show, rescheduled, and blank strategy outcomes.
        count_if(
            strategy_outcome is not null
            and strategy_outcome not in (
                '2. Admin Cancel',
                '3. Cancel- Not Interested',
                '4. No Show',
                '5. Reschedule',
                '8. Cancel- Nurture',
                '8. Cancel',
                ''
            )
        ) as shows,

        count_if(strategy_outcome = '7. Lost') as lost_deals,

        -- Final sales and revenue use linked New Sale activities, not only strategy outcome.
        count(sale_activity_id) as sales,
        sum(contract_value) as total_contract_value,
        sum(cash_collected) as total_cash_collected
    from strategy_funnels
    group by closer_user_id
),

final as (
    select
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
