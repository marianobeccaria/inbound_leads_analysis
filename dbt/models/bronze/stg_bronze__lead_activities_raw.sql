select
    raw_data,
    raw_data:data as activity_data,
    source_file_name,
    source_row_number,
    load_date,
    insert_date,
    bronze_loaded_at
from {{ source('bronze', 'LEAD_ACTIVITIES_RAW') }}
