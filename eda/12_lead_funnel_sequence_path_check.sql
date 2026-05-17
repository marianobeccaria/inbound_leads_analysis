/*
Purpose:
  Validate ordered lead funnel paths.

Questions:
  - For each initial contact, can we find the first strategy event after it?
  - For that strategy event, can we find the first sale after it?
  - How many valid inbound and outbound paths exist?

Gold modeling implication:
  FACT_LEAD_FUNNEL should be built with ordered path matching, not simple
  MIN timestamp logic, because many leads have multiple events per stage.
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
funnel_events AS (
    SELECT
        lead_id,
        activity_id,
        custom_activity_type_id,
        activity_at,
        CASE
            WHEN custom_activity_type_id IN (
                'actitype_38341SWOKRkRHHAqWEqSJu',
                'actitype_1zimBrwAdOLmRLK0Ncg6Lb'
            ) THEN 'inbound'
            WHEN custom_activity_type_id IN (
                'actitype_4tEv1xumZEk9vYYs7WxYy7',
                'actitype_6ga7msjJ7kZcH2rGtYETwe'
            ) THEN 'outbound'
            ELSE NULL
        END AS funnel_source,
        CASE
            WHEN custom_activity_type_id IN (
                'actitype_38341SWOKRkRHHAqWEqSJu',
                'actitype_1zimBrwAdOLmRLK0Ncg6Lb',
                'actitype_4tEv1xumZEk9vYYs7WxYy7',
                'actitype_6ga7msjJ7kZcH2rGtYETwe'
            ) THEN 'initial_contact'
            WHEN custom_activity_type_id IN (
                'actitype_2VcSfZQX6FeIL8kkxy48C2',
                'actitype_6IrDujYE2WKg9QCFJdpXJk'
            ) THEN 'strategy'
            WHEN custom_activity_type_id IN (
                'actitype_3E85vFq3a06LlEzXT2N1kS',
                'actitype_0FNk72Q8eSYX2MVd4A2UFx'
            ) THEN 'sale'
            ELSE NULL
        END AS funnel_stage,
        activity ->> 'custom.cf_h3tYb9J6yPK7J4PMExDGsEqPCf8kBGBrRNIur2Dm5aN' AS triage_outcome,
        activity ->> 'custom.cf_Q2fsrD8VpPaunZLtyiy7P3vG6qJTv0w1ESmlhdHU2ra' AS prospecting_outcome,
        activity ->> 'custom.cf_dhJR4N7Rm6czuJthYGJP6KqUcuOzi7fqApGI7puWnMo' AS strategy_outcome,
        NULLIF(regexp_replace(activity ->> 'custom.cf_vIanPjPEit6ssajmWkcprF2V1nO1itfes8hOSnjmhfT', '[^0-9.-]', '', 'g'), '')::numeric AS contract_value,
        NULLIF(regexp_replace(activity ->> 'custom.cf_eyLbGJm9DYY7cuJk2otnCxhUEzK9ayEARiE81xPG5uY', '[^0-9.-]', '', 'g'), '')::numeric AS cash_collected
    FROM deduped_custom_activities
    WHERE custom_activity_type_id IN (
        'actitype_38341SWOKRkRHHAqWEqSJu',
        'actitype_1zimBrwAdOLmRLK0Ncg6Lb',
        'actitype_4tEv1xumZEk9vYYs7WxYy7',
        'actitype_6ga7msjJ7kZcH2rGtYETwe',
        'actitype_2VcSfZQX6FeIL8kkxy48C2',
        'actitype_6IrDujYE2WKg9QCFJdpXJk',
        'actitype_3E85vFq3a06LlEzXT2N1kS',
        'actitype_0FNk72Q8eSYX2MVd4A2UFx'
    )
),
initial_events AS (
    SELECT *
    FROM funnel_events
    WHERE funnel_stage = 'initial_contact'
),
matched_paths AS (
    SELECT
        i.lead_id,
        i.funnel_source,
        i.activity_id AS initial_activity_id,
        i.activity_at AS initial_at,
        COALESCE(i.triage_outcome, i.prospecting_outcome) AS initial_outcome,
        s.strategy_activity_id,
        s.strategy_at,
        s.strategy_outcome,
        ns.sale_activity_id,
        ns.sale_at,
        ns.contract_value,
        ns.cash_collected
    FROM initial_events i
    LEFT JOIN LATERAL (
        SELECT
            e.activity_id AS strategy_activity_id,
            e.activity_at AS strategy_at,
            e.strategy_outcome
        FROM funnel_events e
        WHERE e.lead_id = i.lead_id
          AND e.funnel_stage = 'strategy'
          AND e.activity_at >= i.activity_at
        ORDER BY e.activity_at, e.activity_id
        LIMIT 1
    ) s ON TRUE
    LEFT JOIN LATERAL (
        SELECT
            e.activity_id AS sale_activity_id,
            e.activity_at AS sale_at,
            e.contract_value,
            e.cash_collected
        FROM funnel_events e
        WHERE e.lead_id = i.lead_id
          AND e.funnel_stage = 'sale'
          AND s.strategy_at IS NOT NULL
          AND e.activity_at >= s.strategy_at
        ORDER BY e.activity_at, e.activity_id
        LIMIT 1
    ) ns ON TRUE
),
classified_paths AS (
    SELECT
        *,
        CASE
            WHEN strategy_activity_id IS NOT NULL
             AND sale_activity_id IS NOT NULL THEN 'initial_to_strategy_to_sale'
            WHEN strategy_activity_id IS NOT NULL THEN 'initial_to_strategy_no_sale'
            ELSE 'initial_no_strategy'
        END AS path_category
    FROM matched_paths
)
SELECT
    funnel_source,
    path_category,
    COUNT(*) AS path_count,
    COUNT(DISTINCT lead_id) AS lead_count,
    COUNT(DISTINCT initial_activity_id) AS initial_event_count,
    COUNT(DISTINCT strategy_activity_id) AS strategy_event_count,
    COUNT(DISTINCT sale_activity_id) AS sale_event_count,
    SUM(contract_value) AS total_contract_value,
    SUM(cash_collected) AS total_cash_collected
FROM classified_paths
GROUP BY funnel_source, path_category
ORDER BY funnel_source, path_count DESC;

