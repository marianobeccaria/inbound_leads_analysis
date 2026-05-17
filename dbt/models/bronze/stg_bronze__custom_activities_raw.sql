/*
    Bronze staging model for Close CRM custom activity metadata.

    Source:
      INBOUND_LEADS.BRONZE.CUSTOM_ACTIVITIES_RAW, loaded from S3 JSONL files.

    Purpose:
      Preserve the raw metadata payload used later to map custom activity type
      IDs to business labels such as Triage Call, Strategy Call, and New Sale.
*/

select
    raw_data,
    raw_data:JSON_OBJECT::string as json_object_text,
    source_file_name,
    source_row_number,
    load_date,
    insert_date,
    bronze_loaded_at
from {{ source('bronze', 'CUSTOM_ACTIVITIES_RAW') }}
