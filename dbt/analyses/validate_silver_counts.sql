select 'stg_bronze__leads_raw' as model_name, count(*) as row_count
from {{ ref('stg_bronze__leads_raw') }}

union all

select 'stg_bronze__lead_activities_raw' as model_name, count(*) as row_count
from {{ ref('stg_bronze__lead_activities_raw') }}

union all

select 'silver_activities' as model_name, count(*) as row_count
from {{ ref('silver_activities') }}

union all

select 'silver_custom_activity_events' as model_name, count(*) as row_count
from {{ ref('silver_custom_activity_events') }};
