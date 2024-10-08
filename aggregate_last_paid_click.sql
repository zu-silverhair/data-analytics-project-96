---Посчитайте расходы на рекламу по модели атрибуции Last Paid Click
with lpc as (
    select
        s.visitor_id,
        s.visit_date::date,
        s."source" as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number() over (
            partition by s.visitor_id order by s.visit_date desc
        ) as rang
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
),

unoin_ads as (
    select
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as daily_spent
    from vk_ads as vk
    group by 1, 2, 3, 4
    union all
    select
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as daily_spent
    from ya_ads as ya
    group by 1, 2, 3, 4
),

metrics as (
    select
        lpc.visit_date,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        u.daily_spent as total_cost,
        count(lpc.visitor_id) as visitors_count,
        count(distinct lpc.lead_id) as leads_count,
        count(lpc.lead_id) filter (
            where lpc.status_id = 142
        ) as purchases_count,
        sum(lpc.amount) as revenue
    from lpc
    left join unoin_ads as u
        on
            u.campaign_date = lpc.visit_date
            and u.utm_source = lpc.utm_source
            and u.utm_medium = lpc.utm_medium
            and u.utm_campaign = lpc.utm_campaign
    where lpc.rang = 1
    group by 1, 2, 3, 4, 5
)

select
    visit_date,
    visitors_count,
    utm_source,
    utm_medium,
    utm_campaign,
    total_cost,
    leads_count,
    purchases_count,
    revenue
from metrics
order by 9 desc nulls last, 1 asc, 2 desc, 3 asc, 4 asc, 5 asc
limit 15;
