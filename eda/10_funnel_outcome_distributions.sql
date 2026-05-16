/*
Purpose:
  Count deduplicated funnel outcome values for triage, prospecting, and strategy
  calls.

Questions:
  - What exact outcome values drive KPI definitions?
  - Which outcomes represent booked, taken, canceled, no-show, sale, and lost?
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
)
SELECT
    'Triage Call Outcome' AS field_name,
    COALESCE(NULLIF(activity ->> 'custom.cf_h3tYb9J6yPK7J4PMExDGsEqPCf8kBGBrRNIur2Dm5aN', ''), '[blank]') AS field_value,
    COUNT(*) AS record_count
FROM deduped_custom_activities
WHERE custom_activity_type_id = 'actitype_38341SWOKRkRHHAqWEqSJu'
GROUP BY field_value

UNION ALL

SELECT
    'Strategy Call Outcome' AS field_name,
    COALESCE(NULLIF(activity ->> 'custom.cf_dhJR4N7Rm6czuJthYGJP6KqUcuOzi7fqApGI7puWnMo', ''), '[blank]') AS field_value,
    COUNT(*) AS record_count
FROM deduped_custom_activities
WHERE custom_activity_type_id = 'actitype_2VcSfZQX6FeIL8kkxy48C2'
GROUP BY field_value

UNION ALL

SELECT
    'Prospecting Call Outcome' AS field_name,
    COALESCE(NULLIF(activity ->> 'custom.cf_Q2fsrD8VpPaunZLtyiy7P3vG6qJTv0w1ESmlhdHU2ra', ''), '[blank]') AS field_value,
    COUNT(*) AS record_count
FROM deduped_custom_activities
WHERE custom_activity_type_id = 'actitype_4tEv1xumZEk9vYYs7WxYy7'
GROUP BY field_value

ORDER BY field_name, record_count DESC;

