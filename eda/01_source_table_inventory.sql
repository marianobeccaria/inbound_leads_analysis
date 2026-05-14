/*
Purpose:
  Confirm which raw source tables exist in PostgreSQL.

Notes:
  Run this against the source PostgreSQL database before building ingestion logic.
*/

SELECT
    table_schema,
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'raw'
ORDER BY
    table_schema,
    table_name;

