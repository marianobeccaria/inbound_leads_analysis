select
    funnel_source,
    path_category,
    count(*) as path_count,
    count(distinct lead_id) as lead_count,
    count(distinct initial_activity_id) as initial_event_count,
    count(distinct strategy_activity_id) as strategy_event_count,
    count(distinct sale_activity_id) as sale_event_count,
    sum(contract_value) as total_contract_value,
    sum(cash_collected) as total_cash_collected,
    count(*) - count(distinct lead_funnel_id) as duplicate_funnel_id_count
from {{ ref('fact_lead_funnel') }}
group by funnel_source, path_category
order by funnel_source, path_count desc
