with report_totals as (
    select
        count(*) as closer_count,
        sum(calls_booked) as calls_booked,
        sum(shows) as shows,
        sum(sales) as sales,
        sum(total_contract_value) as total_contract_value,
        sum(total_cash_collected) as total_cash_collected
    from {{ ref('rpt_closer') }}
),

fact_totals as (
    select
        count(*) as calls_booked,
        count(sale_activity_id) as sales,
        sum(contract_value) as total_contract_value,
        sum(cash_collected) as total_cash_collected
    from {{ ref('fact_lead_funnel') }}
    where strategy_activity_id is not null
)

select
    report_totals.closer_count,
    report_totals.calls_booked,
    fact_totals.calls_booked as fact_calls_booked,
    report_totals.calls_booked - fact_totals.calls_booked as calls_booked_diff,
    report_totals.sales,
    fact_totals.sales as fact_sales,
    report_totals.sales - fact_totals.sales as sales_diff,
    report_totals.total_contract_value,
    fact_totals.total_contract_value as fact_total_contract_value,
    report_totals.total_cash_collected,
    fact_totals.total_cash_collected as fact_total_cash_collected
from report_totals
cross join fact_totals
