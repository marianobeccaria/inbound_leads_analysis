/*
Purpose:
  Map custom.cf_* field IDs to readable field names and show where each field
  is populated by CustomActivity type.

Questions:
  - What does each custom field ID mean?
  - Which fields belong to triage, prospecting, strategy, sale, users,
    objections, and revenue?
*/

WITH metadata_rows AS (
    SELECT raw_data ->> 'JSON_OBJECT' AS metadata_text
    FROM raw.custom_activites_raw
),
field_metadata AS (
    SELECT DISTINCT
        match[1] AS custom_field_id,
        match[2] AS custom_field_name,
        match[3] AS custom_field_type
    FROM metadata_rows
    CROSS JOIN LATERAL regexp_matches(
        metadata_text,
        '''id'': ''(cf_[^'']+)''[^}]*?''name'': ''([^'']*)''[^}]*?''type'': ''([^'']*)''',
        'g'
    ) AS match
),
custom_activities AS (
    SELECT
        activity ->> 'id' AS activity_id,
        activity ->> 'lead_id' AS lead_id,
        activity ->> 'custom_activity_type_id' AS custom_activity_type_id,
        NULLIF(activity ->> 'activity_at', '')::timestamptz AS activity_at,
        NULLIF(activity ->> 'date_updated', '')::timestamptz AS date_updated,
        activity
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
custom_fields AS (
    SELECT
        activity ->> 'custom_activity_type_id' AS custom_activity_type_id,
        replace(activity_kv.key, 'custom.', '') AS custom_field_id,
        activity_kv.value AS custom_field_value
    FROM deduped_custom_activities
    CROSS JOIN LATERAL jsonb_each_text(activity) AS activity_kv(key, value)
    WHERE activity_kv.key LIKE 'custom.cf_%'
      AND activity_kv.value IS NOT NULL
      AND activity_kv.value <> ''
)
SELECT
    cf.custom_activity_type_id,
    cf.custom_field_id,
    fm.custom_field_name,
    fm.custom_field_type,
    COUNT(*) AS populated_count,
    COUNT(DISTINCT cf.custom_field_value) AS distinct_value_count
FROM custom_fields cf
LEFT JOIN field_metadata fm
    ON cf.custom_field_id = fm.custom_field_id
GROUP BY
    cf.custom_activity_type_id,
    cf.custom_field_id,
    fm.custom_field_name,
    fm.custom_field_type
ORDER BY
    cf.custom_activity_type_id,
    populated_count DESC;

