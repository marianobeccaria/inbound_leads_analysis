/*
    Gold fact model for lead funnel paths.

    Source:
      silver_custom_activity_events.

    Purpose:
      Build one row per ordered funnel path by linking initial contact events to
      the first strategy call after that contact, then to the first sale after
      that strategy call. This prevents reports from matching events out of
      chronological order.
*/

with custom_activity_events as (
    select *
    from {{ ref('silver_custom_activity_events') }}
),

funnel_events as (
    select
        lead_id,
        activity_id,
        custom_activity_type_id,
        activity_at,
        activity_updated_at,
        user_id,
        -- Inbound starts with triage activity types; outbound starts with prospecting types.
        case
            when custom_activity_type_id in (
                'actitype_38341SWOKRkRHHAqWEqSJu',
                'actitype_1zimBrwAdOLmRLK0Ncg6Lb'
            ) then 'inbound'
            when custom_activity_type_id in (
                'actitype_4tEv1xumZEk9vYYs7WxYy7',
                'actitype_6ga7msjJ7kZcH2rGtYETwe'
            ) then 'outbound'
        end as funnel_source,
        -- Activity type IDs are mapped to the funnel stage they represent.
        case
            when custom_activity_type_id in (
                'actitype_38341SWOKRkRHHAqWEqSJu',
                'actitype_1zimBrwAdOLmRLK0Ncg6Lb',
                'actitype_4tEv1xumZEk9vYYs7WxYy7',
                'actitype_6ga7msjJ7kZcH2rGtYETwe'
            ) then 'initial_contact'
            when custom_activity_type_id in (
                'actitype_2VcSfZQX6FeIL8kkxy48C2',
                'actitype_6IrDujYE2WKg9QCFJdpXJk'
            ) then 'strategy'
            when custom_activity_type_id in (
                'actitype_3E85vFq3a06LlEzXT2N1kS',
                'actitype_0FNk72Q8eSYX2MVd4A2UFx'
            ) then 'sale'
        end as funnel_stage,
        -- Custom field IDs were identified during EDA and map to business attributes.
        activity:"custom.cf_h3tYb9J6yPK7J4PMExDGsEqPCf8kBGBrRNIur2Dm5aN"::string as triage_outcome,
        activity:"custom.cf_Q2fsrD8VpPaunZLtyiy7P3vG6qJTv0w1ESmlhdHU2ra"::string as prospecting_outcome,
        activity:"custom.cf_dhJR4N7Rm6czuJthYGJP6KqUcuOzi7fqApGI7puWnMo"::string as strategy_outcome,
        activity:"custom.cf_LGyzSTMPy37y87rDOUmFXlZA42HPSIpbipeT2OsQNHW"::string as offer_presented,
        activity:"custom.cf_aIN5Gtqq33tUCCBxFTW63FY6d3mofnKIfFqfWPkvNla" as objections_faced,
        nullif(
            regexp_replace(
                activity:"custom.cf_vIanPjPEit6ssajmWkcprF2V1nO1itfes8hOSnjmhfT"::string,
                '[^0-9.-]',
                ''
            ),
            ''
        )::number(18, 2) as contract_value,
        nullif(
            regexp_replace(
                activity:"custom.cf_eyLbGJm9DYY7cuJk2otnCxhUEzK9ayEARiE81xPG5uY"::string,
                '[^0-9.-]',
                ''
            ),
            ''
        )::number(18, 2) as cash_collected,
        coalesce(
            activity:"custom.cf_v385AJ8HSgepKQ3rvqo4yOA3nn49eGqz39DOqojJG5M"::string,
            user_id
        ) as setter_user_id,
        coalesce(
            activity:"custom.cf_Lv5lSqLOZwLrNhe5M7kWx2mF8Ge2Z23aw5NUNhbXvVS"::string,
            user_id
        ) as closer_user_id
    from custom_activity_events
    where custom_activity_type_id in (
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
        -- Match the first strategy event for the same lead after the initial contact.
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
        -- Match the first sale event for the same lead after the matched strategy call.
        on strategy_matches.lead_id = sale_events.lead_id
        and sale_events.funnel_stage = 'sale'
        and strategy_matches.strategy_at is not null
        and sale_events.activity_at >= strategy_matches.strategy_at
    qualify sale_match_rank = 1
)

select
    -- Stable path key based on the event IDs that define this funnel path.
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
