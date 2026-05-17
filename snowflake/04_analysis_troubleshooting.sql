 SELECT 'BRONZE.LEADS_RAW' AS object_name, COUNT(*) AS row_count
  FROM INBOUND_LEADS.BRONZE.LEADS_RAW

  UNION ALL

  SELECT 'DBT_DEV_BRONZE.STG_BRONZE__LEADS_RAW', COUNT(*)
  FROM INBOUND_LEADS.DBT_DEV_BRONZE.STG_BRONZE__LEADS_RAW

  UNION ALL

  SELECT 'DBT_DEV_BRONZE.STG_BRONZE__LEAD_ACTIVITIES_RAW', COUNT(*)
  FROM INBOUND_LEADS.DBT_DEV_BRONZE.STG_BRONZE__LEAD_ACTIVITIES_RAW

  UNION ALL

  SELECT 'DBT_DEV_SILVER.SILVER_ACTIVITIES', COUNT(*)
  FROM INBOUND_LEADS.DBT_DEV_SILVER.SILVER_ACTIVITIES

  UNION ALL

  SELECT 'DBT_DEV_SILVER.SILVER_CUSTOM_ACTIVITY_EVENTS', COUNT(*)
  FROM INBOUND_LEADS.DBT_DEV_SILVER.SILVER_CUSTOM_ACTIVITY_EVENTS;

--   Check duplicates in deduped custom events:
  SELECT
      lead_id,
      activity_id,
      COUNT(*) AS duplicate_count
  FROM INBOUND_LEADS.DBT_DEV_SILVER.SILVER_CUSTOM_ACTIVITY_EVENTS
  GROUP BY lead_id, activity_id
  HAVING COUNT(*) > 1
  LIMIT 50;

--   Check activity type distribution:

  SELECT
      activity_type,
      COUNT(*) AS activity_count
  FROM INBOUND_LEADS.DBT_DEV_SILVER.SILVER_ACTIVITIES
  GROUP BY activity_type
  ORDER BY activity_count DESC;

--   Check custom activity type distribution:
  SELECT
      custom_activity_type_id,
      COUNT(*) AS event_count
  FROM INBOUND_LEADS.DBT_DEV_SILVER.SILVER_CUSTOM_ACTIVITY_EVENTS
  GROUP BY custom_activity_type_id
  ORDER BY event_count DESC;

--  Check date range:
  SELECT
      MIN(activity_at) AS min_activity_at,
      MAX(activity_at) AS max_activity_at,
      MIN(activity_updated_at) AS min_activity_updated_at,
      MAX(activity_updated_at) AS max_activity_updated_at
  FROM INBOUND_LEADS.DBT_DEV_SILVER.SILVER_ACTIVITIES;

-- Run validation for DBT_DEV_GOLD
 select
      funnel_source,
      path_category,
      count(*) as path_count,
      count(distinct lead_id) as lead_count,
      count(distinct initial_activity_id) as initial_event_count,
      count(distinct strategy_activity_id) as strategy_event_count,
      count(distinct sale_activity_id) as sale_event_count,
      sum(contract_value) as total_contract_value,
      sum(cash_collected) as total_cash_collected,
      count(*) - count(distinct lead_funnel_id) as duplicate_funnel_id_count
  from INBOUND_LEADS.DBT_DEV_GOLD.FACT_LEAD_FUNNEL
  group by funnel_source, path_category
  order by funnel_source, path_count desc;

-- Validate GOLD dim_user
  select count(*) as user_count
  from INBOUND_LEADS.DBT_DEV_GOLD.DIM_USER;

-- Get sample of the users loaded into DIM_USER table  
  select
      user_id,
      email,
      full_name,
      last_used_timezone,
      user_updated_at
  from INBOUND_LEADS.DBT_DEV_GOLD.DIM_USER
  order by email nulls last, user_id
  limit 50;

--  Check setter/closer coverage:
  with role_user_ids as (
      select 'setter' as role_name, setter_user_id as user_id
      from INBOUND_LEADS.DBT_DEV_GOLD.FACT_LEAD_FUNNEL
      where setter_user_id is not null
        and setter_user_id like 'user_%'

      union all

      select 'closer' as role_name, closer_user_id as user_id
      from INBOUND_LEADS.DBT_DEV_GOLD.FACT_LEAD_FUNNEL
      where closer_user_id is not null
        and closer_user_id like 'user_%'
  )

  select
      role_user_ids.role_name,
      count(*) as populated_user_id_count,
      count(distinct role_user_ids.user_id) as distinct_user_id_count,
      count(*) - count(dim_user.user_id) as unmatched_user_id_count
  from role_user_ids
  left join INBOUND_LEADS.DBT_DEV_GOLD.DIM_USER as dim_user
      on role_user_ids.user_id = dim_user.user_id
  group by role_user_ids.role_name
  order by role_user_ids.role_name;

-- Verify GOLD RPT_INBOUND_SETTER
 select *
  from INBOUND_LEADS.DBT_DEV_GOLD.RPT_INBOUND_SETTER
  order by inbound_booked desc;

-- Inspect OUTBOUND SETTER in GOLD
select *
  from INBOUND_LEADS.DBT_DEV_GOLD.RPT_OUTBOUND_SETTER
  order by total_outbound_calls desc;

-- Inspect RPT_CLOSERs in GOLD
select *
  from INBOUND_LEADS.DBT_DEV_GOLD.RPT_CLOSER
  order by calls_booked desc;

-- Inspect DIM_LEAD in GOLD
select *
  from INBOUND_LEADS.DBT_DEV_GOLD.DIM_LEAD
  limit 50;

-- Inspect RPT_OBJECTIONS_FACED in GOLD
  select *
  from INBOUND_LEADS.DBT_DEV_GOLD.RPT_OBJECTIONS_FACED
  order by objection_count desc;
