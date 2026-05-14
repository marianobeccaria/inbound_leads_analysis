/*
Purpose:
  Count rows in each expected raw source table.

Notes:
  This validates source availability and gives a first sense of data volume.
*/

SELECT 'raw.leads_raw' AS table_name, COUNT(*) AS row_count
FROM raw.leads_raw

UNION ALL

SELECT 'raw.lead_activites_raw' AS table_name, COUNT(*) AS row_count
FROM raw.lead_activites_raw

UNION ALL

SELECT 'raw.close_crm_users_raw' AS table_name, COUNT(*) AS row_count
FROM raw.close_crm_users_raw

UNION ALL

SELECT 'raw.custom_activites_raw' AS table_name, COUNT(*) AS row_count
FROM raw.custom_activites_raw

ORDER BY table_name;

