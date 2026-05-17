-- Create Role needed to run BI dashboard using Snowsight
 CREATE ROLE IF NOT EXISTS BI_REPORTER;

  GRANT USAGE ON DATABASE INBOUND_LEADS TO ROLE BI_REPORTER;
  GRANT USAGE ON SCHEMA INBOUND_LEADS.DBT_DEV_GOLD TO ROLE BI_REPORTER;

  GRANT SELECT ON ALL TABLES IN SCHEMA INBOUND_LEADS.DBT_DEV_GOLD TO ROLE BI_REPORTER;
  GRANT SELECT ON FUTURE TABLES IN SCHEMA INBOUND_LEADS.DBT_DEV_GOLD TO ROLE BI_REPORTER;

  CREATE WAREHOUSE IF NOT EXISTS BI_WH
    WAREHOUSE_SIZE = XSMALL
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

  GRANT USAGE ON WAREHOUSE BI_WH TO ROLE BI_REPORTER;

--   For your own user:
USE ROLE ACCOUNTADMIN;
GRANT ROLE BI_REPORTER TO USER MBECCARIA; -- Make sure to type user in all CAPS or it wont work

-- Tile 1: KPI Scorecards
SELECT
  SUM(inbound_booked) AS inbound_booked,
  SUM(triage_set) AS inbound_strategy_calls_set,
  SUM(total_sales) AS inbound_sales,
  SUM(total_cash_collected) AS inbound_cash_collected
FROM INBOUND_LEADS.DBT_DEV_GOLD.RPT_INBOUND_SETTER;

-- Tile 2: Inbound Setter Performance

SELECT
  COALESCE(setter_name, setter_user_id) AS setter,
  inbound_booked,
  inbound_taken,
  triage_set,
  strategy_calls_taken,
  total_sales,
  sale_rate,
  total_cash_collected
FROM INBOUND_LEADS.DBT_DEV_GOLD.RPT_INBOUND_SETTER
ORDER BY inbound_booked DESC;

-- Tile 3: Outbound Setter Performance

SELECT
  COALESCE(setter_name, setter_user_id) AS setter,
  total_outbound_calls,
  unique_leads_touched,
  outbound_set,
  total_closer_show,
  total_sales,
  dial_to_set_rate,
  show_to_sale_rate
FROM INBOUND_LEADS.DBT_DEV_GOLD.RPT_OUTBOUND_SETTER
ORDER BY total_outbound_calls DESC;

-- Tile 4: Closer Performance

SELECT
  COALESCE(closer_name, closer_user_id) AS closer,
  calls_booked,
  shows,
  no_shows,
  lost_deals,
  sales,
  show_rate,
  show_to_sale_rate,
  total_cash_collected
FROM INBOUND_LEADS.DBT_DEV_GOLD.RPT_CLOSER
ORDER BY calls_booked DESC;

-- Tile 5: Objections Faced

SELECT
  objection_category,
  objection_count,
  distinct_strategy_call_count,
  strategy_call_percentage
FROM INBOUND_LEADS.DBT_DEV_GOLD.RPT_OBJECTIONS_FACED
ORDER BY objection_count DESC;

-- Tile 6: Funnel Path Summary

SELECT
  funnel_source,
  path_category,
  COUNT(*) AS path_count,
  COUNT(DISTINCT lead_id) AS lead_count,
  SUM(contract_value) AS total_contract_value,
  SUM(cash_collected) AS total_cash_collected
FROM INBOUND_LEADS.DBT_DEV_GOLD.FACT_LEAD_FUNNEL
GROUP BY funnel_source, path_category
ORDER BY funnel_source, path_count DESC;
