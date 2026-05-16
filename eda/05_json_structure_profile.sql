/*
Purpose:
  Summarize the JSON structure that drives downstream flattening and parsing.

Questions:
  - Which table stores direct objects?
  - Which table stores arrays?
  - Which table stores malformed stringified JSON?

Finding expected from prior EDA:
  - leads_raw.raw_data is a direct lead object.
  - lead_activites_raw.raw_data -> 'data' is an activity array.
  - custom_activites_raw and close_crm_users_raw store JSON_OBJECT as a string.
*/

SELECT
    'leads_raw' AS table_name,
    jsonb_typeof(raw_data) AS raw_data_type,
    NULL AS nested_key,
    NULL AS nested_key_type,
    COUNT(*) AS row_count
FROM raw.leads_raw
GROUP BY jsonb_typeof(raw_data)

UNION ALL

SELECT
    'lead_activites_raw' AS table_name,
    jsonb_typeof(raw_data) AS raw_data_type,
    'data' AS nested_key,
    jsonb_typeof(raw_data -> 'data') AS nested_key_type,
    COUNT(*) AS row_count
FROM raw.lead_activites_raw
GROUP BY jsonb_typeof(raw_data), jsonb_typeof(raw_data -> 'data')

UNION ALL

SELECT
    'custom_activites_raw' AS table_name,
    jsonb_typeof(raw_data) AS raw_data_type,
    'JSON_OBJECT' AS nested_key,
    jsonb_typeof(raw_data -> 'JSON_OBJECT') AS nested_key_type,
    COUNT(*) AS row_count
FROM raw.custom_activites_raw
GROUP BY jsonb_typeof(raw_data), jsonb_typeof(raw_data -> 'JSON_OBJECT')

UNION ALL

SELECT
    'close_crm_users_raw' AS table_name,
    jsonb_typeof(raw_data) AS raw_data_type,
    'JSON_OBJECT' AS nested_key,
    jsonb_typeof(raw_data -> 'JSON_OBJECT') AS nested_key_type,
    COUNT(*) AS row_count
FROM raw.close_crm_users_raw
GROUP BY jsonb_typeof(raw_data), jsonb_typeof(raw_data -> 'JSON_OBJECT')
ORDER BY table_name;

SELECT
    insert_date::date AS load_date,
    COUNT(*) AS lead_activity_raw_rows,
    SUM(jsonb_array_length(raw_data -> 'data')) AS flattened_activity_count
FROM raw.lead_activites_raw
GROUP BY insert_date::date
ORDER BY load_date;

