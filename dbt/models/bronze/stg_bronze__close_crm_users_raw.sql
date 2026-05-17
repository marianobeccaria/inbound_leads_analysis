/*
    Bronze staging model for raw Close CRM user metadata.

    Source:
      INBOUND_LEADS.BRONZE.CLOSE_CRM_USERS_RAW, loaded from S3 JSONL files.

    Purpose:
      Preserve the raw user payload used later to resolve setter and closer
      user IDs into readable user names for Gold reports.
*/

select
    raw_data,
    raw_data:JSON_OBJECT::string as json_object_text,
    source_file_name,
    source_row_number,
    load_date,
    insert_date,
    bronze_loaded_at
from {{ source('bronze', 'CLOSE_CRM_USERS_RAW') }}
