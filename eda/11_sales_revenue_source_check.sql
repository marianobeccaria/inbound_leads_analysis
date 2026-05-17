/*
Purpose:
  Determine whether sales should be counted from Strategy Call Outcome = Sale,
  New Sale activity records, or both.

Conclusion from EDA:
  New Sale activity records should be the source of truth for final sales and
  revenue. Strategy Call Outcome = Sale is a call outcome signal, not the final
  sales fact.
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
strategy_sales AS (
    SELECT
        lead_id,
        activity_id AS strategy_activity_id,
        activity_at AS strategy_activity_at
    FROM deduped_custom_activities
    WHERE custom_activity_type_id = 'actitype_2VcSfZQX6FeIL8kkxy48C2'
      AND activity ->> 'custom.cf_dhJR4N7Rm6czuJthYGJP6KqUcuOzi7fqApGI7puWnMo' = '6. Sale'
),
new_sales AS (
    SELECT
        lead_id,
        activity_id AS sale_activity_id,
        activity_at AS sale_activity_at,
        NULLIF(regexp_replace(activity ->> 'custom.cf_vIanPjPEit6ssajmWkcprF2V1nO1itfes8hOSnjmhfT', '[^0-9.-]', '', 'g'), '')::numeric AS contract_value,
        NULLIF(regexp_replace(activity ->> 'custom.cf_eyLbGJm9DYY7cuJk2otnCxhUEzK9ayEARiE81xPG5uY', '[^0-9.-]', '', 'g'), '')::numeric AS cash_collected
    FROM deduped_custom_activities
    WHERE custom_activity_type_id IN (
        'actitype_3E85vFq3a06LlEzXT2N1kS',
        'actitype_0FNk72Q8eSYX2MVd4A2UFx'
    )
),
lead_level_comparison AS (
    SELECT
        COALESCE(ss.lead_id, ns.lead_id) AS lead_id,
        COUNT(DISTINCT ss.strategy_activity_id) AS strategy_sale_count,
        COUNT(DISTINCT ns.sale_activity_id) AS new_sale_count,
        SUM(ns.contract_value) AS total_contract_value,
        SUM(ns.cash_collected) AS total_cash_collected
    FROM strategy_sales ss
    FULL OUTER JOIN new_sales ns
        ON ss.lead_id = ns.lead_id
    GROUP BY COALESCE(ss.lead_id, ns.lead_id)
)
SELECT
    CASE
        WHEN strategy_sale_count > 0 AND new_sale_count > 0 THEN 'strategy_sale_and_new_sale'
        WHEN strategy_sale_count > 0 AND new_sale_count = 0 THEN 'strategy_sale_only'
        WHEN strategy_sale_count = 0 AND new_sale_count > 0 THEN 'new_sale_only'
        ELSE 'neither'
    END AS sale_match_category,
    COUNT(*) AS lead_count,
    SUM(strategy_sale_count) AS strategy_sale_activity_count,
    SUM(new_sale_count) AS new_sale_activity_count,
    SUM(total_contract_value) AS total_contract_value,
    SUM(total_cash_collected) AS total_cash_collected
FROM lead_level_comparison
GROUP BY sale_match_category
ORDER BY lead_count DESC;

