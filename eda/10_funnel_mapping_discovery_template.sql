/*
Purpose:
  Discover the activity names, outcomes, custom fields, and choice values needed
  to build the funnel mapping.

Important:
  This is a template. It should be finalized after reviewing custom activity metadata.

Target mappings:
  - Inbound triage activity
  - Outbound prospecting activity
  - Strategy call activity
  - Strategy call follow-up activity
  - New sale activity
  - Custom payment plan sale activity
  - Outcome fields
  - Objection fields
  - Contracted value fields
  - Cash collected fields
  - Setter fields
  - Closer fields
*/

/*
Suggested manual review query after metadata JSON paths are known:

SELECT
    custom_activity_type_id,
    custom_activity_name,
    field_id,
    field_label,
    field_type,
    choice_id,
    choice_label
FROM <parsed_custom_activity_metadata>
WHERE custom_activity_name ILIKE ANY (
    ARRAY[
        '%triage%',
        '%prospect%',
        '%strategy%',
        '%sale%',
        '%payment%',
        '%objection%'
    ]
)
   OR field_label ILIKE ANY (
    ARRAY[
        '%outcome%',
        '%objection%',
        '%contract%',
        '%cash%',
        '%setter%',
        '%closer%'
    ]
)
ORDER BY
    custom_activity_name,
    field_label,
    choice_label;
*/

