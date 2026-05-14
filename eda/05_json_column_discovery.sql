/*
Purpose:
  Identify likely JSON-bearing columns in the raw tables.

Notes:
  This helps decide which columns need JSON parsing, JSON repair, or direct extraction.
*/

SELECT
    table_name,
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_schema = 'raw'
  AND table_name IN (
      'leads_raw',
      'lead_activites_raw',
      'close_crm_users_raw',
      'custom_activites_raw'
  )
  AND (
      data_type IN ('json', 'jsonb')
      OR udt_name IN ('json', 'jsonb')
      OR column_name ILIKE '%json%'
      OR column_name ILIKE '%data%'
      OR column_name ILIKE '%raw%'
      OR column_name ILIKE '%activity%'
  )
ORDER BY
    table_name,
    column_name;

