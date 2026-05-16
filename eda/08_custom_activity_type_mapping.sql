/*
Purpose:
  Map CustomActivity type IDs to business activity names and usage counts.

Questions:
  - Which custom_activity_type_id values exist in activity records?
  - What business activity name does each ID represent?
  - Which activity types are relevant to the sales funnel?

Why regex:
  custom_activites_raw.JSON_OBJECT is malformed stringified JSON, so this script
  extracts IDs and names with regex instead of casting to jsonb.
*/

WITH custom_activities AS (
    SELECT
        activity ->> 'id' AS activity_id,
        activity ->> 'lead_id' AS lead_id,
        activity ->> 'custom_activity_type_id' AS custom_activity_type_id,
        NULLIF(activity ->> 'activity_at', '')::timestamptz AS activity_at,
        NULLIF(activity ->> 'date_updated', '')::timestamptz AS date_updated
    FROM raw.lead_activites_raw lar
    CROSS JOIN LATERAL jsonb_array_elements(lar.raw_data -> 'data') AS activity
    WHERE activity ->> '_type' = 'CustomActivity'
),
deduped_custom_activities AS (
    SELECT *
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY lead_id, activity_id
                ORDER BY date_updated DESC NULLS LAST, activity_at DESC NULLS LAST
            ) AS rn
        FROM custom_activities
    ) x
    WHERE rn = 1
),
custom_activity_counts AS (
    SELECT
        custom_activity_type_id,
        COUNT(*) AS activity_count,
        COUNT(DISTINCT lead_id) AS distinct_lead_count,
        MIN(activity_at) AS first_activity_at,
        MAX(activity_at) AS latest_activity_at
    FROM deduped_custom_activities
    GROUP BY custom_activity_type_id
),
metadata_rows AS (
    SELECT raw_data ->> 'JSON_OBJECT' AS metadata_text
    FROM raw.custom_activites_raw
),
activity_type_matches AS (
    SELECT DISTINCT
        match[1] AS custom_activity_type_id,
        match[2] AS custom_activity_type_name
    FROM metadata_rows
    CROSS JOIN LATERAL regexp_matches(
        metadata_text,
        '''id'': ''(actitype_[^'']+)''[^}]*?''name'': ''([^'']*)''',
        'g'
    ) AS match
)
SELECT
    c.custom_activity_type_id,
    m.custom_activity_type_name,
    c.activity_count,
    c.distinct_lead_count,
    c.first_activity_at,
    c.latest_activity_at
FROM custom_activity_counts c
LEFT JOIN activity_type_matches m
    ON c.custom_activity_type_id = m.custom_activity_type_id
ORDER BY c.activity_count DESC;

