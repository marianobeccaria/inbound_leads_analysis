/*
    Gold report model for inbound setter performance.

    Sources:
      fact_lead_funnel and dim_user.

    Purpose:
      Summarize inbound triage performance by setter. This model uses the
      ordered funnel paths from fact_lead_funnel, so strategy calls and sales are
      only counted when they happen after the inbound initial contact.
*/

with inbound_funnels as (
    select *
    from {{ ref('fact_lead_funnel') }}
    where funnel_source = 'inbound'
),

setter_rollup as (
    select
        initial_at::date as report_date,
        setter_user_id,
        count(*) as inbound_booked,

        -- Triage taken excludes no-shows, reschedules, cancels, and blank outcomes.
        count_if(
            initial_outcome is not null
            and initial_outcome not in (
                '6. No Show',
                '7. Reschedule',
                '8. Cancel',
                ''
            )
        ) as inbound_taken,

        -- EDA defined inbound set as triage outcome = Strategy Call Scheduled.
        count_if(initial_outcome = '1. Strategy Call Scheduled') as triage_set,

        count(strategy_activity_id) as strategy_calls_booked,

        -- Strategy taken excludes admin cancels, not-interested cancels, no-shows,
        -- reschedules, nurture cancels, general cancels, and blank outcomes.
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
        ) as strategy_calls_taken,

        count_if(offer_presented is not null and offer_presented <> '') as offers_presented,
        count(sale_activity_id) as total_sales,
        sum(contract_value) as total_contract_value,
        sum(cash_collected) as total_cash_collected
    from inbound_funnels
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
