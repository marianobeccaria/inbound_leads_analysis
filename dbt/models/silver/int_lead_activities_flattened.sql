with source as (
    select *
    from {{ ref('stg_bronze__lead_activities_raw') }}
),

flattened as (
    select
        activity.value as activity,
        activity.index as activity_array_index,
        source.source_file_name,
        source.source_row_number,
        source.load_date,
        source.insert_date,
        source.bronze_loaded_at
    from source,
    lateral flatten(input => source.activity_data) activity
)

select
    activity:id::string as activity_id,
    activity:lead_id::string as lead_id,
    activity:_type::string as activity_type,
    activity:custom_activity_type_id::string as custom_activity_type_id,
    try_to_timestamp_ntz(activity:activity_at::string) as activity_at,
    try_to_timestamp_ntz(activity:date_created::string) as activity_created_at,
    try_to_timestamp_ntz(activity:date_updated::string) as activity_updated_at,
    activity:user_id::string as user_id,
    activity,
    activity_array_index,
    source_file_name,
    source_row_number,
    load_date,
    insert_date,
    bronze_loaded_at
from flattened
