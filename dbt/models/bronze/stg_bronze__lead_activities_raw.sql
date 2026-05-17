/*
    Bronze staging model for raw Close CRM activity wrapper rows.

    Source:
      INBOUND_LEADS.BRONZE.LEAD_ACTIVITIES_RAW, loaded from S3 JSONL files.

    Purpose:
      Keep each raw source row intact and expose RAW_DATA:data as ACTIVITY_DATA.
      ACTIVITY_DATA is a JSON array that is flattened in the Silver layer.
*/

select
    raw_data,
    raw_data:data as activity_data,
    source_file_name,
    source_row_number,
    load_date,
    insert_date,
    bronze_loaded_at
from {{ source('bronze', 'LEAD_ACTIVITIES_RAW') }}
