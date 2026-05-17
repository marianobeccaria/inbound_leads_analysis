/*
Purpose:
  Inspect compact raw samples without printing entire JSON payloads.

Questions:
  - What are the top-level JSON keys in each raw table?
  - Are payloads direct objects, arrays, or wrapped stringified JSON?

Why this matters:
  Raw JSON can be very wide. Compact samples make the first inspection
  reproducible without flooding the terminal.
*/

SELECT
    'leads_raw' AS table_name,
    insert_date,
    jsonb_typeof(raw_data) AS raw_data_type,
    array_agg(key ORDER BY key) AS top_level_keys
-- FROM raw.leads_raw
-- CROSS JOIN LATERAL jsonb_object_keys(raw_data) AS key
-- GROUP BY insert_date, raw_data
-- LIMIT 5;
FROM (
    SELECT insert_date, raw_data
    FROM raw.leads_raw
    LIMIT 5
) sample
CROSS JOIN LATERAL jsonb_object_keys(sample.raw_data) AS key
GROUP BY insert_date, raw_data;

SELECT
    'lead_activites_raw' AS table_name,
    insert_date,
    jsonb_typeof(raw_data) AS raw_data_type,
    array_agg(key ORDER BY key) AS top_level_keys,
    jsonb_typeof(raw_data -> 'data') AS data_key_type,
    jsonb_array_length(raw_data -> 'data') AS activity_count_in_row
-- FROM raw.lead_activites_raw
-- CROSS JOIN LATERAL jsonb_object_keys(raw_data) AS key
-- GROUP BY insert_date, raw_data
-- LIMIT 5;
FROM (
    SELECT insert_date, raw_data
    FROM raw.lead_activites_raw
    LIMIT 5
) sample
CROSS JOIN LATERAL jsonb_object_keys(sample.raw_data) AS key
GROUP BY insert_date, raw_data;

SELECT
    'custom_activites_raw' AS table_name,
    insert_date,
    jsonb_typeof(raw_data) AS raw_data_type,
    array_agg(key ORDER BY key) AS top_level_keys,
    left(raw_data ->> 'JSON_OBJECT', 500) AS json_object_sample
-- FROM raw.custom_activites_raw
-- CROSS JOIN LATERAL jsonb_object_keys(raw_data) AS key
-- GROUP BY insert_date, raw_data
-- LIMIT 5;
FROM (
    SELECT insert_date, raw_data
    FROM raw.custom_activites_raw
    LIMIT 5
) sample
CROSS JOIN LATERAL jsonb_object_keys(sample.raw_data) AS key
GROUP BY insert_date, raw_data;

SELECT
    'close_crm_users_raw' AS table_name,
    insert_date,
    jsonb_typeof(raw_data) AS raw_data_type,
    array_agg(key ORDER BY key) AS top_level_keys,
    left(raw_data ->> 'JSON_OBJECT', 500) AS json_object_sample
-- FROM raw.close_crm_users_raw
-- CROSS JOIN LATERAL jsonb_object_keys(raw_data) AS key
-- GROUP BY insert_date, raw_data
-- LIMIT 5;
FROM (
    SELECT insert_date, raw_data
    FROM raw.close_crm_users_raw
    LIMIT 5
) sample
CROSS JOIN LATERAL jsonb_object_keys(sample.raw_data) AS key
GROUP BY insert_date, raw_data;
