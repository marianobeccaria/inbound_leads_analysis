/*
Purpose:
  Validate revenue fields used by sales, closer, and revenue reporting.

Questions:
  - How many revenue events have populated numeric values?
  - Are there missing, zero, invalid, or negative values?
  - Which revenue event types should be modeled separately?
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
revenue_events AS (
    SELECT
        activity_id,
        lead_id,
        custom_activity_type_id,
        activity_at,
        activity ->> 'custom.cf_vIanPjPEit6ssajmWkcprF2V1nO1itfes8hOSnjmhfT' AS contract_value_raw,
        activity ->> 'custom.cf_eyLbGJm9DYY7cuJk2otnCxhUEzK9ayEARiE81xPG5uY' AS cash_collected_raw,
        activity ->> 'custom.cf_KTd6MrsBY2TiQPmD2eTT9Qf8OmIS1UZZkNOOseWTENf' AS additional_cash_collected_raw,
        NULLIF(regexp_replace(activity ->> 'custom.cf_vIanPjPEit6ssajmWkcprF2V1nO1itfes8hOSnjmhfT', '[^0-9.-]', '', 'g'), '')::numeric AS contract_value,
        NULLIF(regexp_replace(activity ->> 'custom.cf_eyLbGJm9DYY7cuJk2otnCxhUEzK9ayEARiE81xPG5uY', '[^0-9.-]', '', 'g'), '')::numeric AS cash_collected,
        NULLIF(regexp_replace(activity ->> 'custom.cf_KTd6MrsBY2TiQPmD2eTT9Qf8OmIS1UZZkNOOseWTENf', '[^0-9.-]', '', 'g'), '')::numeric AS additional_cash_collected
    FROM deduped_custom_activities
    WHERE custom_activity_type_id IN (
        'actitype_3E85vFq3a06LlEzXT2N1kS',
        'actitype_0FNk72Q8eSYX2MVd4A2UFx',
        'actitype_0UClFQWNpy8T71EXBNHKYG',
        'actitype_3bvm3ENPUG8NT0owMJ6XDH'
    )
)
SELECT
    custom_activity_type_id,
    COUNT(*) AS revenue_event_count,
    COUNT(contract_value_raw) AS populated_contract_value_raw_count,
    COUNT(cash_collected_raw) AS populated_cash_collected_raw_count,
    COUNT(additional_cash_collected_raw) AS populated_additional_cash_raw_count,
    COUNT(contract_value) AS numeric_contract_value_count,
    COUNT(cash_collected) AS numeric_cash_collected_count,
    COUNT(additional_cash_collected) AS numeric_additional_cash_count,
    COUNT(*) FILTER (WHERE contract_value IS NULL AND contract_value_raw IS NOT NULL) AS invalid_contract_value_count,
    COUNT(*) FILTER (WHERE cash_collected IS NULL AND cash_collected_raw IS NOT NULL) AS invalid_cash_collected_count,
    COUNT(*) FILTER (WHERE contract_value = 0) AS zero_contract_value_count,
    COUNT(*) FILTER (WHERE cash_collected = 0) AS zero_cash_collected_count,
    COUNT(*) FILTER (WHERE contract_value < 0) AS negative_contract_value_count,
    COUNT(*) FILTER (WHERE cash_collected < 0) AS negative_cash_collected_count,
    SUM(contract_value) AS total_contract_value,
    SUM(cash_collected) AS total_cash_collected,
    SUM(additional_cash_collected) AS total_additional_cash_collected,
    AVG(contract_value) AS avg_contract_value,
    MIN(contract_value) AS min_contract_value,
    MAX(contract_value) AS max_contract_value,
    MIN(cash_collected) AS min_cash_collected,
    MAX(cash_collected) AS max_cash_collected
FROM revenue_events
GROUP BY custom_activity_type_id
ORDER BY revenue_event_count DESC;

