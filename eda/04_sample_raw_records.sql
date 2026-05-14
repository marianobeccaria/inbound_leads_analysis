/*
Purpose:
  Review small samples from each raw source table.

Notes:
  Start with a small LIMIT because raw JSON fields can be large.
*/

SELECT *
FROM raw.leads_raw
LIMIT 5;

SELECT *
FROM raw.lead_activites_raw
LIMIT 5;

SELECT *
FROM raw.close_crm_users_raw
LIMIT 5;

SELECT *
FROM raw.custom_activites_raw
LIMIT 5;

