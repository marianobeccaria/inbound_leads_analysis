/*
Purpose:
  Profile activity types such as CustomActivity, SMS, Call, Meeting, and Note.

Important:
  This is a template. Update the JSON column name after running:
    eda/03_table_schema_profile.sql
    eda/05_json_column_discovery.sql

Assumption:
  Replace <json_column> with the column that contains activity JSON.
*/

/*
Example for json/jsonb data:

SELECT
    activity ->> 'type' AS activity_type,
    COUNT(*) AS activity_count
FROM raw.lead_activites_raw lar
CROSS JOIN LATERAL jsonb_array_elements(
    lar.<json_column>::jsonb -> 'masked_activities'
) AS activity
GROUP BY activity ->> 'type'
ORDER BY activity_count DESC;
*/

/*
If the activity payload is stored as text and contains malformed JSON,
sample the raw value first before casting:

SELECT
    <json_column>
FROM raw.lead_activites_raw
WHERE <json_column> IS NOT NULL
LIMIT 10;
*/

