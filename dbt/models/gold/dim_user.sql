/*
    Gold dimension for Close CRM users.

    Source:
      stg_bronze__close_crm_users_raw.

    Purpose:
      Parse user metadata from the raw JSON_OBJECT text so funnel reports can
      display setter and closer details instead of only Close CRM user IDs.

    Important source behavior:
      JSON_OBJECT is a single-quoted JSON-like string, not clean JSON. Regex is
      used here because direct JSON parsing is unreliable for this source.
*/

with source as (
    select *
    from {{ ref('stg_bronze__close_crm_users_raw') }}
),

user_objects as (
    select
        source.insert_date,
        source.source_file_name,
        source.source_row_number,
        source.bronze_loaded_at,
        user_object.value::string as user_object_text
    from source,
    lateral flatten(
        input => regexp_substr_all(
            source.json_object_text,
            $$\{[^{}]*'id': 'user_[^']+'[^{}]*\}$$
        )
    ) as user_object
),

parsed_users as (
    select
        regexp_substr(user_object_text, $$'id': '([^']+)'$$, 1, 1, 'e', 1) as user_id,
        regexp_substr(user_object_text, $$'email': '([^']*)'$$, 1, 1, 'e', 1) as email,
        regexp_substr(user_object_text, $$'first_name': '([^']*)'$$, 1, 1, 'e', 1) as first_name,
        regexp_substr(user_object_text, $$'last_name': '([^']*)'$$, 1, 1, 'e', 1) as last_name,
        regexp_substr(user_object_text, $$'last_used_timezone': '([^']*)'$$, 1, 1, 'e', 1) as last_used_timezone,
        try_to_timestamp_ntz(
            regexp_substr(user_object_text, $$'date_created': '([^']*)'$$, 1, 1, 'e', 1)
        ) as user_created_at,
        try_to_timestamp_ntz(
            regexp_substr(user_object_text, $$'date_updated': '([^']*)'$$, 1, 1, 'e', 1)
        ) as user_updated_at,
        user_object_text,
        insert_date,
        source_file_name,
        source_row_number,
        bronze_loaded_at
    from user_objects
),

ranked_users as (
    select
        *,
        -- Keep the latest user metadata version when the same user appears in multiple loads.
        row_number() over (
            partition by user_id
            order by user_updated_at desc nulls last, insert_date desc nulls last
        ) as row_number_latest
    from parsed_users
    where user_id is not null
),

deduped_users as (
    select *
    from ranked_users
    where row_number_latest = 1
)

select
    user_id,
    email,
    first_name,
    last_name,
    trim(concat(coalesce(first_name, ''), ' ', coalesce(last_name, ''))) as full_name,
    last_used_timezone,
    user_created_at,
    user_updated_at,
    user_object_text,
    source_file_name,
    source_row_number,
    insert_date,
    bronze_loaded_at
from deduped_users
