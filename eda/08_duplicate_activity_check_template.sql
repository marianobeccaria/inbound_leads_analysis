/*
Purpose:
  Check whether the same activity appears multiple times across daily refreshes.

Important:
  This is a template. Update JSON paths and column names after identifying:
    - lead_id
    - activity_id
    - activity_at

Expected deduplication rule from the requirements:
  - Duplicate key: lead_id + activity_id
  - Keep latest record by activity_at
*/

/*
WITH parsed_activities AS (
    SELECT
        activity ->> 'lead_id' AS lead_id,
        activity ->> 'id' AS activity_id,
        (activity ->> 'activity_at')::timestamptz AS activity_at
    FROM raw.lead_activites_raw lar
    CROSS JOIN LATERAL jsonb_array_elements(
        lar.<json_column>::jsonb -> 'masked_activities'
    ) AS activity
)
SELECT
    lead_id,
    activity_id,
    COUNT(*) AS duplicate_count,
    MIN(activity_at) AS first_activity_at,
    MAX(activity_at) AS latest_activity_at
FROM parsed_activities
GROUP BY
    lead_id,
    activity_id
HAVING COUNT(*) > 1
ORDER BY
    duplicate_count DESC,
    latest_activity_at DESC;
*/

