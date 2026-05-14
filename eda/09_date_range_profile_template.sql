/*
Purpose:
  Identify activity date ranges for incremental load planning and dashboard filters.

Important:
  This is a template. Update JSON paths and column names after identifying activity_at.
*/

/*
WITH parsed_activities AS (
    SELECT
        (activity ->> 'activity_at')::timestamptz AS activity_at
    FROM raw.lead_activites_raw lar
    CROSS JOIN LATERAL jsonb_array_elements(
        lar.<json_column>::jsonb -> 'masked_activities'
    ) AS activity
)
SELECT
    MIN(activity_at) AS min_activity_at,
    MAX(activity_at) AS max_activity_at,
    COUNT(*) AS activity_count
FROM parsed_activities;
*/

