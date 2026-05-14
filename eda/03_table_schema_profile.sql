/*
Purpose:
  Inspect column names, data types, and nullability for the raw source tables.

Notes:
  Use this to determine whether JSON is stored as text, json, jsonb, or another type.
*/

SELECT
    table_schema,
    table_name,
    ordinal_position,
    column_name,
    data_type,
    udt_name,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'raw'
  AND table_name IN (
      'leads_raw',
      'lead_activites_raw',
      'close_crm_users_raw',
      'custom_activites_raw'
  )
ORDER BY
    table_name,
    ordinal_position;

