with report_totals as (
    select
        count(*) as setter_count,
        sum(inbound_booked) as inbound_booked,
        sum(inbound_taken) as inbound_taken,
        sum(triage_set) as triage_set,
        sum(strategy_calls_booked) as strategy_calls_booked,
        sum(strategy_calls_taken) as strategy_calls_taken,
        sum(offers_presented) as offers_presented,
        sum(total_sales) as total_sales,
        sum(total_contract_value) as total_contract_value,
        sum(total_cash_collected) as total_cash_collected
    from {{ ref('rpt_inbound_setter') }}
),

fact_totals as (
    select
        count(*) as inbound_booked,
        count(strategy_activity_id) as strategy_calls_booked,
        count(sale_activity_id) as total_sales,
        sum(contract_value) as total_contract_value,
        sum(cash_collected) as total_cash_collected
    from {{ ref('fact_lead_funnel') }}
    where funnel_source = 'inbound'
)

select
    report_totals.setter_count,
    report_totals.inbound_booked,
    fact_totals.inbound_booked as fact_inbound_booked,
    report_totals.inbound_booked - fact_totals.inbound_booked as inbound_booked_diff,
    report_totals.strategy_calls_booked,
    fact_totals.strategy_calls_booked as fact_strategy_calls_booked,
    report_totals.strategy_calls_booked - fact_totals.strategy_calls_booked as strategy_calls_booked_diff,
    report_totals.total_sales,
    fact_totals.total_sales as fact_total_sales,
    report_totals.total_sales - fact_totals.total_sales as total_sales_diff,
    report_totals.total_contract_value,
    fact_totals.total_contract_value as fact_total_contract_value,
    report_totals.total_cash_collected,
    fact_totals.total_cash_collected as fact_total_cash_collected
from report_totals
cross join fact_totals
