/*
Purpose:
  Validate that setter and closer IDs resolve to Close CRM users.

Questions:
  - Can user metadata be extracted from close_crm_users_raw?
  - Do setter and closer IDs in activity custom fields match parsed users?

Gold modeling implication:
  DIM_USER can support setter and closer reporting if assignment coverage is high.
*/

WITH user_metadata_rows AS (
    SELECT
        insert_date,
        raw_data ->> 'JSON_OBJECT' AS metadata_text
    FROM raw.close_crm_users_raw
),
user_objects AS (
    SELECT
        insert_date,
        user_match[1] AS user_object_text
    FROM user_metadata_rows
    CROSS JOIN LATERAL regexp_matches(
        metadata_text,
        '(\{[^{}]*''id'': ''user_[^'']+''[^{}]*\})',
        'g'
    ) AS user_match
),
parsed_users AS (
    SELECT
        substring(user_object_text FROM '''id'': ''([^'']+)''') AS user_id,
        substring(user_object_text FROM '''email'': ''([^'']*)''') AS email,
        substring(user_object_text FROM '''first_name'': ''([^'']*)''') AS first_name,
        substring(user_object_text FROM '''last_name'': ''([^'']*)''') AS last_name,
        substring(user_object_text FROM '''last_used_timezone'': ''([^'']*)''') AS last_used_timezone,
        substring(user_object_text FROM '''date_updated'': ''([^'']*)''') AS date_updated,
        insert_date
    FROM user_objects
),
deduped_users AS (
    SELECT *
    FROM (
        SELECT
            *,
            ROW_NUMBER() OVER (
                PARTITION BY user_id
                ORDER BY date_updated DESC NULLS LAST, insert_date DESC NULLS LAST
            ) AS rn
        FROM parsed_users
        WHERE user_id IS NOT NULL
    ) x
    WHERE rn = 1
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
role_assignments AS (
    SELECT
        'setter' AS role_name,
        'primary_setter' AS role_field_name,
        custom_activity_type_id,
        activity ->> 'custom.cf_v385AJ8HSgepKQ3rvqo4yOA3nn49eGqz39DOqojJG5M' AS user_id
    FROM deduped_custom_activities

    UNION ALL

    SELECT
        'closer' AS role_name,
        'primary_closer' AS role_field_name,
        custom_activity_type_id,
        activity ->> 'custom.cf_Lv5lSqLOZwLrNhe5M7kWx2mF8Ge2Z23aw5NUNhbXvVS' AS user_id
    FROM deduped_custom_activities
),
clean_role_assignments AS (
    SELECT *
    FROM role_assignments
    WHERE user_id IS NOT NULL
      AND user_id <> ''
      AND user_id LIKE 'user_%'
)
SELECT
    'parsed_user_summary' AS result_type,
    NULL AS role_name,
    NULL AS role_field_name,
    NULL AS custom_activity_type_id,
    COUNT(*) AS populated_assignment_count,
    COUNT(DISTINCT user_id) AS distinct_user_id_count,
    COUNT(email) AS matched_assignment_count,
    NULL::bigint AS unmatched_assignment_count
FROM deduped_users

UNION ALL

SELECT
    'role_coverage' AS result_type,
    ra.role_name,
    ra.role_field_name,
    ra.custom_activity_type_id,
    COUNT(*) AS populated_assignment_count,
    COUNT(DISTINCT ra.user_id) AS distinct_user_id_count,
    COUNT(*) FILTER (WHERE u.user_id IS NOT NULL) AS matched_assignment_count,
    COUNT(*) FILTER (WHERE u.user_id IS NULL) AS unmatched_assignment_count
FROM clean_role_assignments ra
LEFT JOIN deduped_users u
    ON ra.user_id = u.user_id
GROUP BY
    ra.role_name,
    ra.role_field_name,
    ra.custom_activity_type_id
ORDER BY result_type, role_name, role_field_name, populated_assignment_count DESC;

