/*
Purpose:
  Normalize and count objections from strategy activities.

Questions:
  - Are objections stored as array-like text?
  - Can they be split into one row per objection?
  - Which normalized categories are needed for the Objections Faced report?
*/

WITH custom_activities AS (
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
strategy_events AS (
    SELECT
        activity_id,
        lead_id,
        custom_activity_type_id,
        activity ->> 'custom.cf_aIN5Gtqq33tUCCBxFTW63FY6d3mofnKIfFqfWPkvNla' AS objections_faced
    FROM deduped_custom_activities
    WHERE custom_activity_type_id IN (
        'actitype_2VcSfZQX6FeIL8kkxy48C2',
        'actitype_6IrDujYE2WKg9QCFJdpXJk'
    )
),
clean_objections AS (
    SELECT
        activity_id,
        lead_id,
        custom_activity_type_id,
        trim(
            both ' '
            FROM regexp_replace(
                regexp_replace(objections_faced, '^\[|\]$', '', 'g'),
                '"',
                '',
                'g'
            )
        ) AS objections_csv
    FROM strategy_events
    WHERE objections_faced IS NOT NULL
      AND objections_faced <> ''
),
unnested_objections AS (
    SELECT
        activity_id,
        lead_id,
        custom_activity_type_id,
        trim(both ' ' FROM objection_value) AS objection_value
    FROM clean_objections
    CROSS JOIN LATERAL regexp_split_to_table(objections_csv, '\s*,\s*') AS objection_value
)
SELECT
    CASE
        WHEN objection_value ILIKE 'money' OR objection_value ILIKE 'financial' THEN 'Money'
        WHEN objection_value ILIKE 'fear' THEN 'Fear'
        WHEN objection_value ILIKE 'hung up' THEN 'Hung Up'
        WHEN objection_value ILIKE 'logistical' THEN 'Logistical'
        WHEN objection_value ILIKE 'no objections' THEN 'No Objections'
        WHEN objection_value ILIKE 'talking to other coaches' THEN 'Talking to Other Coaches'
        WHEN objection_value ILIKE 'partner' THEN 'Partner'
        WHEN objection_value ILIKE 'think about it' THEN 'Think About It'
        WHEN objection_value ILIKE 'time' THEN 'Time'
        WHEN objection_value ILIKE 'trust' OR objection_value ILIKE 'uncertain about us' THEN 'Trust'
        WHEN objection_value ILIKE 'value' THEN 'Value'
        WHEN objection_value ILIKE 'wasn''t looking for what we offered' THEN 'Wasn''t Looking For What We Offered'
        ELSE objection_value
    END AS normalized_objection_category,
    objection_value AS source_objection_value,
    COUNT(*) AS objection_count,
    COUNT(DISTINCT activity_id) AS distinct_activity_count,
    COUNT(DISTINCT lead_id) AS distinct_lead_count
FROM unnested_objections
WHERE objection_value IS NOT NULL
  AND objection_value <> ''
GROUP BY
    normalized_objection_category,
    source_objection_value
ORDER BY
    objection_count DESC,
    normalized_objection_category,
    source_objection_value;

