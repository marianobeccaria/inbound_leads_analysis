# EDA SQL Scripts

These scripts support early source data exploration for the Inbound Leads Analytics project.

The first scripts are executable PostgreSQL queries for source inventory, row counts, schemas, samples, and JSON column discovery. Later scripts are templates because the exact JSON column names and paths must be confirmed from the source data first.

Recommended order:

```text
01_source_table_inventory.sql
02_raw_row_counts.sql
03_table_schema_profile.sql
04_sample_raw_records.sql
05_json_column_discovery.sql
06_activity_type_profile_template.sql
07_custom_activity_metadata_profile_template.sql
08_duplicate_activity_check_template.sql
09_date_range_profile_template.sql
10_funnel_mapping_discovery_template.sql
```

These scripts are designed to run first against PostgreSQL, because that is the source system. After the raw data is landed in Snowflake Bronze tables, equivalent Snowflake profiling queries can be created for the Bronze layer.

