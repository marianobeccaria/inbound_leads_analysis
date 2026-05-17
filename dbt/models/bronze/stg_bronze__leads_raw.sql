select
    raw_data:id::string as lead_id,
    raw_data:name::string as lead_name,
    raw_data:display_name::string as display_name,
    raw_data:status_id::string as status_id,
    raw_data:status_label::string as status_label,
    try_to_timestamp_ntz(raw_data:date_created::string) as lead_created_at,
    try_to_timestamp_ntz(raw_data:date_updated::string) as lead_updated_at,
    raw_data:created_by::string as created_by_user_id,
    raw_data:updated_by::string as updated_by_user_id,
    raw_data as raw_data,
    source_file_name,
    source_row_number,
    load_date,
    insert_date,
    bronze_loaded_at
from {{ source('bronze', 'LEADS_RAW') }}
