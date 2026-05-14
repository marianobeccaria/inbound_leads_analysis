/*
Purpose:
  Explore custom activity metadata and identify business mappings.

Important:
  This is a template. Update JSON paths and column names after inspecting the raw schema.

Use this script to discover:
  - Custom activity type IDs
  - Custom activity names
  - Field IDs
  - Field labels
  - Field data types
  - Choice IDs and labels
*/

/*
Step 1: Sample metadata rows.
*/

SELECT *
FROM raw.custom_activites_raw
LIMIT 20;

/*
Step 2: After identifying the metadata JSON column, extract high-level keys.

Replace <json_column> with the correct column name.
*/

/*
SELECT
    jsonb_object_keys(<json_column>::jsonb) AS top_level_key,
    COUNT(*) AS occurrence_count
FROM raw.custom_activites_raw
GROUP BY top_level_key
ORDER BY occurrence_count DESC, top_level_key;
*/

/*
Step 3: Once paths are known, extract activity fields and choice values.
*/

