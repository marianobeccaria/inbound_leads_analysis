with dim_user as (
    select *
    from {{ ref('dim_user') }}
),

role_user_ids as (
    select
        'setter' as role_name,
        setter_user_id as user_id
    from {{ ref('fact_lead_funnel') }}
    where setter_user_id is not null
      and setter_user_id like 'user_%'

    union all

    select
        'closer' as role_name,
        closer_user_id as user_id
    from {{ ref('fact_lead_funnel') }}
    where closer_user_id is not null
      and closer_user_id like 'user_%'
),

role_coverage as (
    select
        role_user_ids.role_name,
        count(*) as populated_user_id_count,
        count(distinct role_user_ids.user_id) as distinct_user_id_count,
        count(*) - count(dim_user.user_id) as unmatched_user_id_count
    from role_user_ids
    left join dim_user
        on role_user_ids.user_id = dim_user.user_id
    group by role_user_ids.role_name
)

select
    'dim_user_summary' as result_type,
    null as role_name,
    count(*) as populated_user_id_count,
    count(distinct user_id) as distinct_user_id_count,
    0 as unmatched_user_id_count
from dim_user

union all

select
    'fact_lead_funnel_role_coverage' as result_type,
    role_name,
    populated_user_id_count,
    distinct_user_id_count,
    unmatched_user_id_count
from role_coverage
order by result_type, role_name
