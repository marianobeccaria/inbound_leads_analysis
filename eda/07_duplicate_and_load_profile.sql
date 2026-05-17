/*
Purpose:
  Validate duplicate behavior and daily load volume.

Questions:
  - Does the same lead_id + activity_id appear multiple times?
  - Which timestamp should be used for deduplication?
  - How much data arrives per insert/load date?

Dedup rule for Silver:
  PARTITION BY lead_id, activity_id
  ORDER BY date_updated DESC NULLS LAST, activity_at DESC NULLS LAST
*/

WITH flattened_activities AS (
    SELECT
        activity ->> 'id' AS activity_id,
        activity ->> 'lead_id' AS lead_id,
        activity ->> '_type' AS activity_type,
        NULLIF(activity ->> 'activity_at', '')::timestamptz AS activity_at,
        NULLIF(activity ->> 'date_updated', '')::timestamptz AS date_updated
    FROM raw.lead_activites_raw lar
    CROSS JOIN LATERAL jsonb_array_elements(lar.raw_data -> 'data') AS activity
)
SELECT
    COUNT(*) AS flattened_activity_rows,
    COUNT(DISTINCT activity_id) AS distinct_activity_ids,
    COUNT(DISTINCT lead_id || '|' || activity_id) AS distinct_lead_activity_keys,
    COUNT(*) - COUNT(DISTINCT lead_id || '|' || activity_id) AS duplicate_rows
FROM flattened_activities;

WITH flattened_activities AS (
    SELECT
        activity ->> 'id' AS activity_id,
        activity ->> 'lead_id' AS lead_id,
        NULLIF(activity ->> 'activity_at', '')::timestamptz AS activity_at,
        NULLIF(activity ->> 'date_updated', '')::timestamptz AS date_updated
    FROM raw.lead_activites_raw lar
    CROSS JOIN LATERAL jsonb_array_elements(lar.raw_data -> 'data') AS activity
)
SELECT
    lead_id,
    activity_id,
    COUNT(*) AS duplicate_count,
    MIN(activity_at) AS first_activity_at,
    MAX(activity_at) AS latest_activity_at,
    MIN(date_updated) AS first_date_updated,
    MAX(date_updated) AS latest_date_updated
FROM flattened_activities
GROUP BY lead_id, activity_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, latest_date_updated DESC NULLS LAST
LIMIT 50;

SELECT
    insert_date::date AS load_date,
    COUNT(*) AS raw_batch_rows,
    SUM(jsonb_array_length(raw_data -> 'data')) AS flattened_activity_count
FROM raw.lead_activites_raw
GROUP BY insert_date::date
ORDER BY load_date;

