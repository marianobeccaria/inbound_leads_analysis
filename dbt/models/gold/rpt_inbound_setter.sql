/*
    Gold report model for inbound setter performance.

    Sources:
    fact_lead_funnel, silver_activities, dim_user, and funnel_outcome_map.

    Purpose:
    Summarize inbound triage performance by setter using booking evidence for
    booked triage calls and logged triage outcomes for taken triage calls.
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
        initial_outcome_map.is_set as initial_is_set,
        strategy_outcome_map.is_taken as strategy_is_taken
    from inbound_funnels
    left join outcome_map as initial_outcome_map
        on initial_outcome_map.canonical_field_name = 'triage_outcome'
        and inbound_funnels.initial_outcome = initial_outcome_map.raw_value
    left join outcome_map as strategy_outcome_map
        on strategy_outcome_map.canonical_field_name = 'strategy_outcome'
        and inbound_funnels.strategy_outcome = strategy_outcome_map.raw_value
),

deduped_activities as (
    select
        activity_id,
        lead_id,
        activity_type,
        activity_at,
        convert_timezone('UTC', 'America/New_York', activity_at)::date as report_date,
        user_id as setter_user_id,
        activity:status::string as activity_status,
        activity:title::string as activity_title,
        activity:note::string as activity_note,
        activity:sequence_name::string as sequence_name
    from {{ ref('silver_activities') }}
    qualify row_number() over (
        partition by activity_id
        order by activity_updated_at desc nulls last, activity_at desc nulls last
    ) = 1
),

booking_evidence as (
    select
        report_date,
        setter_user_id,
        lead_id,
        max(
            iff(
                activity_type = 'Meeting'
                and (
                    activity_title ilike '%Data Engineer Academy%'
                    or activity_note ilike '%Data Engineer Academy%'
                ),
                1,
                0
            )
        ) as has_calendar_booking,
        max(
            iff(
                activity_type = 'SMS'
                and sequence_name = '001-Triage Booked // Setter Confirmation',
                1,
                0
            )
        ) as has_sms_booking
    from deduped_activities
    group by report_date, setter_user_id, lead_id
),

triage_conclusions as (
    select
        convert_timezone('UTC', 'America/New_York', initial_at)::date as report_date,
        setter_user_id,
        lead_id,
        max(
            iff(
                initial_outcome is not null
                and trim(initial_outcome) <> '',
                1,
                0
            )
        ) as has_triage_conclusion,
        max(
            iff(
                lower(coalesce(initial_is_set::string, 'false')) = 'true',
                1,
                0
            )
        ) as has_triage_set,
        count(strategy_activity_id) as strategy_calls_booked,
        count_if(
            strategy_activity_id is not null
            and lower(coalesce(strategy_is_taken::string, 'false')) = 'true'
        ) as strategy_calls_taken,
        count_if(
            strategy_activity_id is not null
            and lower(coalesce(strategy_is_taken::string, 'false')) = 'true'
            and offer_presented is not null
            and offer_presented <> ''
        ) as offers_presented,

        count(sale_activity_id) as total_sales,
        sum(contract_value) as total_contract_value,
        sum(cash_collected) as total_cash_collected
    from mapped_funnels
    group by
        convert_timezone('UTC', 'America/New_York', initial_at)::date,
        setter_user_id,
        lead_id
),

combined_inbound_leads as (
    select
        coalesce(booking_evidence.report_date, triage_conclusions.report_date) as report_date,
        coalesce(booking_evidence.setter_user_id, triage_conclusions.setter_user_id) as setter_user_id,
        coalesce(booking_evidence.lead_id, triage_conclusions.lead_id) as lead_id,
        coalesce(booking_evidence.has_calendar_booking, 0) as has_calendar_booking,
        coalesce(booking_evidence.has_sms_booking, 0) as has_sms_booking,
        coalesce(triage_conclusions.has_triage_conclusion, 0) as has_triage_conclusion,
        coalesce(triage_conclusions.has_triage_set, 0) as has_triage_set,
        coalesce(triage_conclusions.strategy_calls_booked, 0) as strategy_calls_booked,
        coalesce(triage_conclusions.strategy_calls_taken, 0) as strategy_calls_taken,
        coalesce(triage_conclusions.offers_presented, 0) as offers_presented,
        coalesce(triage_conclusions.total_sales, 0) as total_sales,
        coalesce(triage_conclusions.total_contract_value, 0) as total_contract_value,
        coalesce(triage_conclusions.total_cash_collected, 0) as total_cash_collected
    from booking_evidence
    full outer join triage_conclusions
        on booking_evidence.report_date = triage_conclusions.report_date
        and booking_evidence.setter_user_id = triage_conclusions.setter_user_id
        and booking_evidence.lead_id = triage_conclusions.lead_id
),

setter_rollup as (
    select
        report_date,
        setter_user_id,
        count_if(
            has_calendar_booking = 1
            or has_sms_booking = 1
            or has_triage_conclusion = 1
        ) as inbound_booked,
        count_if(has_triage_conclusion = 1) as inbound_taken,
        count_if(has_triage_set = 1) as triage_set,
        sum(strategy_calls_booked) as strategy_calls_booked,
        sum(strategy_calls_taken) as strategy_calls_taken,
        sum(offers_presented) as offers_presented,
        sum(total_sales) as total_sales,
        sum(total_contract_value) as total_contract_value,
        sum(total_cash_collected) as total_cash_collected
    from combined_inbound_leads
    group by report_date, setter_user_id
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
