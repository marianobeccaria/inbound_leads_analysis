with report_totals as (
    select
        count(*) as setter_count,
        sum(total_outbound_calls) as total_outbound_calls,
        sum(unique_leads_touched) as summed_unique_leads_touched,
        sum(outbound_set) as outbound_set,
        sum(strategy_calls_booked) as strategy_calls_booked,
        sum(total_closer_show) as total_closer_show,
        sum(total_sales) as total_sales,
        sum(total_contract_value) as total_contract_value,
        sum(total_cash_collected) as total_cash_collected
    from {{ ref('rpt_outbound_setter') }}
),

fact_totals as (
    select
        count(*) as total_outbound_calls,
        count(distinct lead_id) as distinct_leads_touched,
        count(strategy_activity_id) as strategy_calls_booked,
        count(sale_activity_id) as total_sales,
        sum(contract_value) as total_contract_value,
        sum(cash_collected) as total_cash_collected
    from {{ ref('fact_lead_funnel') }}
    where funnel_source = 'outbound'
)

select
    report_totals.setter_count,
    report_totals.total_outbound_calls,
    fact_totals.total_outbound_calls as fact_total_outbound_calls,
    report_totals.total_outbound_calls - fact_totals.total_outbound_calls as total_outbound_calls_diff,
    report_totals.summed_unique_leads_touched,
    fact_totals.distinct_leads_touched as fact_distinct_leads_touched,
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
