/*
Purpose:
  Count flattened Close CRM activity events by activity type.

Questions:
  - Which activity types exist?
  - How many events are relevant to funnel analytics?

Why this matters:
  The requirements state that core KPIs are driven by CustomActivity records,
  while Call, SMS, Email, Meeting, and Note provide supporting context.
*/

WITH flattened_activities AS (
    SELECT
        activity ->> 'id' AS activity_id,
        activity ->> 'lead_id' AS lead_id,
        activity ->> '_type' AS activity_type,
        NULLIF(activity ->> 'activity_at', '')::timestamptz AS activity_at
    FROM raw.lead_activites_raw lar
    CROSS JOIN LATERAL jsonb_array_elements(lar.raw_data -> 'data') AS activity
)
SELECT
    activity_type,
    COUNT(*) AS raw_event_count,
    COUNT(DISTINCT activity_id) AS distinct_activity_id_count,
    COUNT(DISTINCT lead_id) AS distinct_lead_count,
    MIN(activity_at) AS first_activity_at,
    MAX(activity_at) AS latest_activity_at
FROM flattened_activities
GROUP BY activity_type
ORDER BY raw_event_count DESC;

