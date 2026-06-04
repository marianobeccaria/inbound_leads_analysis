/*
    Gold fact model for lead funnel paths.

    Source:
      silver_custom_activity_events.

    Purpose:
      Build one row per ordered funnel path by linking initial contact events to
      the first strategy call after that contact, then to the first sale after
      that strategy call. This prevents reports from matching events out of
      chronological order.

    Mapping strategy:
      Custom activity types and custom fields are resolved through dbt seeds.
*/

with custom_activity_events as (
    select *
    from {{ ref('silver_custom_activity_events') }}
),

custom_activity_type_map as (
    select
        custom_activity_type_id,
        custom_activity_type_name,
        funnel_source,
        funnel_stage
    from {{ ref('custom_activity_type_map') }}
    where lower(is_active::string) = 'true'
    and funnel_stage in (
        'initial_contact',
        'strategy',
        'sale'
    )
),

custom_field_map as (
    select
        custom_field_id,
        canonical_field_name
    from {{ ref('custom_field_map') }}
    where lower(is_active::string) = 'true'
    and canonical_field_name in (
        'triage_outcome',
        'prospecting_outcome',
        'strategy_outcome',
        'offer_presented',
        'objections_faced',
        'contract_value',
        'cash_collected',
        'setter_user_id',
        'closer_user_id'
    )
),

mapped_activity_fields as (
    select
        custom_activity_events.lead_id,
        custom_activity_events.activity_id,
        custom_activity_events.custom_activity_type_id,
        custom_activity_events.activity_at,
        custom_activity_events.activity_updated_at,
        custom_activity_events.user_id,
        custom_activity_type_map.funnel_source,
        custom_activity_type_map.funnel_stage,
        custom_field_map.canonical_field_name,
        get(
            custom_activity_events.activity,
            'custom.' || custom_field_map.custom_field_id
        ) as custom_field_value
    from custom_activity_events
    inner join custom_activity_type_map
        on custom_activity_events.custom_activity_type_id
            = custom_activity_type_map.custom_activity_type_id
    left join custom_field_map
        on get(
            custom_activity_events.activity,
            'custom.' || custom_field_map.custom_field_id
        ) is not null
),

funnel_events as (
    select
        lead_id,
        activity_id,
        custom_activity_type_id,
        activity_at,
        activity_updated_at,
        user_id,
        funnel_source,
        funnel_stage,

        max(
            case
                when canonical_field_name = 'triage_outcome'
                    then custom_field_value::string
            end
        ) as triage_outcome,

        max(
            case
                when canonical_field_name = 'prospecting_outcome'
                    then custom_field_value::string
            end
        ) as prospecting_outcome,

        max(
            case
                when canonical_field_name = 'strategy_outcome'
                    then custom_field_value::string
            end
        ) as strategy_outcome,

        max(
            case
                when canonical_field_name = 'offer_presented'
                    then custom_field_value::string
            end
        ) as offer_presented,

        max(
            case
                when canonical_field_name = 'objections_faced'
                    then custom_field_value
            end
        ) as objections_faced,

        nullif(
            regexp_replace(
                max(
                    case
                        when canonical_field_name = 'contract_value'
                            then custom_field_value::string
                    end
                ),
                '[^0-9.-]',
                ''
            ),
            ''
        )::number(18, 2) as contract_value,

        nullif(
            regexp_replace(
                max(
                    case
                        when canonical_field_name = 'cash_collected'
                            then custom_field_value::string
                    end
                ),
                '[^0-9.-]',
                ''
            ),
            ''
        )::number(18, 2) as cash_collected,

        coalesce(
            max(
                case
                    when canonical_field_name = 'setter_user_id'
                        then custom_field_value::string
                end
            ),
            user_id
        ) as setter_user_id,

        coalesce(
            max(
                case
                    when canonical_field_name = 'closer_user_id'
                        then custom_field_value::string
                end
            ),
            user_id
        ) as closer_user_id
    from mapped_activity_fields
    group by
        lead_id,
        activity_id,
        custom_activity_type_id,
        activity_at,
        activity_updated_at,
        user_id,
        funnel_source,
        funnel_stage
),

initial_events as (
    select *
    from funnel_events
    where funnel_stage = 'initial_contact'
),

strategy_matches as (
    select
        initial_events.lead_id,
        initial_events.funnel_source,
        initial_events.activity_id as initial_activity_id,
        initial_events.activity_at as initial_at,
        initial_events.custom_activity_type_id as initial_activity_type_id,
        initial_events.setter_user_id,
        coalesce(initial_events.triage_outcome, initial_events.prospecting_outcome) as initial_outcome,
        strategy_events.activity_id as strategy_activity_id,
        strategy_events.activity_at as strategy_at,
        strategy_events.custom_activity_type_id as strategy_activity_type_id,
        strategy_events.closer_user_id,
        strategy_events.strategy_outcome,
        strategy_events.offer_presented,
        strategy_events.objections_faced,
        row_number() over (
            partition by initial_events.lead_id, initial_events.activity_id
            order by strategy_events.activity_at, strategy_events.activity_id
        ) as strategy_match_rank
    from initial_events
    left join funnel_events as strategy_events
        on initial_events.lead_id = strategy_events.lead_id
        and strategy_events.funnel_stage = 'strategy'
        and strategy_events.activity_at >= initial_events.activity_at
    qualify strategy_match_rank = 1
),

sale_matches as (
    select
        strategy_matches.*,
        sale_events.activity_id as sale_activity_id,
        sale_events.activity_at as sale_at,
        sale_events.custom_activity_type_id as sale_activity_type_id,
        sale_events.contract_value,
        sale_events.cash_collected,
        row_number() over (
            partition by strategy_matches.lead_id, strategy_matches.initial_activity_id
            order by sale_events.activity_at, sale_events.activity_id
        ) as sale_match_rank
    from strategy_matches
    left join funnel_events as sale_events
        on strategy_matches.lead_id = sale_events.lead_id
        and sale_events.funnel_stage = 'sale'
        and strategy_matches.strategy_at is not null
        and sale_events.activity_at >= strategy_matches.strategy_at
    qualify sale_match_rank = 1
)

select
    md5(
        concat_ws(
            '|',
            lead_id,
            initial_activity_id,
            coalesce(strategy_activity_id, ''),
            coalesce(sale_activity_id, '')
        )
    ) as lead_funnel_id,
    lead_id,
    funnel_source,
    initial_activity_id,
    initial_activity_type_id,
    initial_at,
    setter_user_id,
    initial_outcome,
    strategy_activity_id,
    strategy_activity_type_id,
    strategy_at,
    closer_user_id,
    strategy_outcome,
    offer_presented,
    objections_faced,
    sale_activity_id,
    sale_activity_type_id,
    sale_at,
    contract_value,
    cash_collected,
    case
        when strategy_activity_id is not null
            and sale_activity_id is not null then 'initial_to_strategy_to_sale'
        when strategy_activity_id is not null then 'initial_to_strategy_no_sale'
        else 'initial_no_strategy'
    end as path_category
from sale_matches
