---Шаг 4 Расчет метрик

--Сколько у нас пользователей заходят на сайт?
with lp as (
    select
        date_trunc('week', s.visit_date) as start_week,
        to_char(s.visit_date, 'yyyy-mm-dd') as date,
        count(s.visitor_id) as count_visitor
    from sessions s
    group by 1, 2
)
        
    select
        sum(lp.count_visitor) as count_month,
        round(sum(lp.count_visitor) / 5, 0) as count_week,
        round(avg(lp.count_visitor), 0) as count_day
    from lp
;

--Какие каналы их приводят на сайт? Хочется видеть по дням/неделям/месяцам для по модели атрибуции Last Paid Click

--по дням недели
with LPC as (
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
        row_number() over(partition by s.visitor_id order by s.visit_date desc) as rang
    from sessions s 
    left join leads l on s.visitor_id  = l.visitor_id 
        and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
), unoin_ads as (
SELECT
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as daily_spent
    FROM vk_ads AS vk
    group by 1,2,3,4
    union all
    SELECT
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as daily_spent
    FROM ya_ads as ya 
    group by 1,2,3,4
)
select 
        --LPC.visit_date as start_day,
        --date_trunc('week', LPC.visit_date) as start_week,
        --to_char(LPC.visit_date, 'Month') as start_month,
        to_char(LPC.visit_date, 'Day') as day_week,
        to_char(LPC.visit_date, 'D') as day_week_number,
        LPC.utm_source,
        LPC.utm_medium,
        LPC.utm_campaign,
        count(LPC.visitor_id) as visitors_count
        from LPC
left join unoin_ads as u 
    on u.campaign_date = LPC.visit_date
    and u.utm_source = LPC.utm_source
    and    u.utm_medium = LPC.utm_medium 
    and    u.utm_campaign = LPC.utm_campaign 
where LPC.rang = 1
group by 1,2,3,4,5
order by day_week_number
;

--Сколько лидов к нам приходят?

select
    count(l.lead_id) as count_leads
from leads l 
;

--Какая конверсия из клика в лид? А из лида в оплату?

with lp as (
    select 
        count(distinct s.visitor_id) as count_visitors,
        count(distinct l.lead_id)::numeric as count_leads,
        count(l.lead_id)  filter (
            where l.status_id = 142) as purchases_count
    from sessions s 
    left join leads l on s.visitor_id  = l.visitor_id 
)
select 
    lp.count_visitors,
    lp.count_leads,
    lp.purchases_count,
    round(lp.count_leads / lp.count_visitors * 100, 2) as conversion_lead,
    round((lp.purchases_count / lp.count_leads) * 100, 2) as conversion_amlead
from lp
;

--Сколько мы тратим по разным каналам в динамике? только для вк и яндекс

with LPC as (
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
        row_number() over(partition by s.visitor_id order by s.visit_date desc) as rang
    from sessions s 
    left join leads l on s.visitor_id  = l.visitor_id 
        and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    and s."source" in ('vk', 'yandex')
), unoin_ads as (
SELECT
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as daily_spent
    FROM vk_ads AS vk
    group by 1,2,3,4
    union all
    SELECT
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as daily_spent
    FROM ya_ads as ya 
    group by 1,2,3,4
)
select 
        LPC.visit_date as start_day,
        to_char(LPC.visit_date, 'Day') as day_week,
        extract(isodow from LPC.visit_date) as day_week_number,
        LPC.utm_source,
        LPC.utm_medium,
        LPC.utm_campaign,
        coalesce(sum(u.daily_spent), 0) as total_cost
        from LPC
left join unoin_ads as u 
    on u.campaign_date = LPC.visit_date
    and u.utm_source = LPC.utm_source
    and    u.utm_medium = LPC.utm_medium 
    and    u.utm_campaign = LPC.utm_campaign 
where LPC.rang = 1
group by 1,2,3,4,5,6
order by 1
;


---Окупаются ли каналы? Почему такая разницв между вk и яндекс/Обязательно рассчитать основные метрики;
------Шаг 5 Презентация и выводы
---Есть ли окупаемые каналы? Если да, то какие?
---Какие рекламные каналы стоит отключить, над какими нужно поработать и улучшить

with LPC as (
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
        row_number() over(partition by s.visitor_id order by s.visit_date desc) as rang
    from sessions s 
    left join leads l on s.visitor_id  = l.visitor_id 
        and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    and s."source" in ('vk', 'yandex')
), unoin_ads as (
SELECT
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as daily_spent
    FROM vk_ads AS vk
    group by 1,2,3,4
    union all
    SELECT
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as daily_spent
    FROM ya_ads as ya 
    group by 1,2,3,4
),  metrics as (
select 
        LPC.visit_date,
        count(distinct LPC.visitor_id) as visitors_count,
        LPC.utm_source,
        LPC.utm_medium,
        LPC.utm_campaign,
        coalesce(u.daily_spent, 0) as total_cost,
        count(distinct LPC.lead_id) as leads_count,
        count(LPC.lead_id)  filter (
            where LPC.status_id = 142) as purchases_count,
        coalesce(sum(LPC.amount), 0) as revenue
        from LPC
left join unoin_ads as u 
    on u.campaign_date = LPC.visit_date
    and u.utm_source = LPC.utm_source
    and    u.utm_medium = LPC.utm_medium 
    and    u.utm_campaign = LPC.utm_campaign 
where LPC.rang = 1
group by 1,3,4,5,6
)

select 
    m.utm_source,
    m.utm_medium,
    m.utm_campaign,
    sum(m.visitors_count) as visitors_sum,
    sum(m.leads_count) as leads_sum ,
    sum(m.purchases_count) as purchases_sum,
    sum(m.total_cost) as total_cost_sum,
    sum(m.revenue) as revenue_sum,
    case 
        when sum(m.visitors_count) = 0 then 0
        else round(sum(m.total_cost) / sum(m.visitors_count))
    end as CPU,
    case 
        when sum(m.leads_count) = 0 then 0
        else round(sum(m.total_cost) / sum(m.leads_count))
    end as CPL,
    case 
        when sum(m.purchases_count) = 0 then 0
        else round(sum(m.total_cost) / sum(m.purchases_count))
    end as CPPU,
    case 
        when sum(m.total_cost) = 0 then 0
        else round(((sum(m.revenue) - sum(m.total_cost)) / sum(m.total_cost))*100, 0)
    end as ROI
from metrics as m
group by 1,2,3
order by 12 desc
;

---Через какое время после запуска компании маркетинг может анализировать компанию используя ваш дашборд? 
---Можно посчитать за сколько дней с момента перехода по рекламе закрывается 90% лидов.
with LPC as (
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
        row_number() over(partition by s.visitor_id order by s.visit_date desc) as rang
    from sessions s 
    left join leads l on s.visitor_id  = l.visitor_id 
        and s.visit_date <= l.created_at
)
select 
LPC.utm_source,
LPC.utm_medium,
percentile_disc(0.90) within group (
    order by date_part('day', LPC.created_at - LPC.visit_date)) as _day_leads
from LPC
group by 1,2
order by 3 desc nulls last 

---Есть ли заметная корреляция между запуском рекламной компании и ростом органики?

with LPC as (
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
        row_number() over(partition by s.visitor_id order by s.visit_date desc) as rang
    from sessions s 
    left join leads l on s.visitor_id  = l.visitor_id 
        and s.visit_date <= l.created_at
)
select 
        LPC.visit_date,
        count(LPC.visitor_id) as visitors_count,
        LPC.utm_source,
        LPC.utm_medium,
        LPC.utm_campaign,
        count(distinct LPC.lead_id) as leads_count,
        count(LPC.lead_id)  filter (
            where LPC.status_id = 142) as purchases_count,
        coalesce(sum(LPC.amount), 0) as revenue
        from LPC
where LPC.rang = 1
group by 1,3,4,5
order by revenue desc
;

---Любые другие инсайты, которые вы можете найти в данных

    with LPC as (
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
        row_number() over(partition by s.visitor_id order by s.visit_date desc) as rang
    from sessions s 
    left join leads l on s.visitor_id  = l.visitor_id 
        and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    and s."source" in ('vk', 'yandex')
), unoin_ads as (
SELECT
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        sum(vk.daily_spent) as daily_spent
    FROM vk_ads AS vk
    group by 1,2,3,4
    union all
    SELECT
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        sum(ya.daily_spent) as daily_spent
    FROM ya_ads as ya 
    group by 1,2,3,4
)
select 
        LPC.utm_source,
        coalesce(sum(u.daily_spent), 0) as total_cost,
        coalesce(sum(LPC.amount), 0 ) as revenue,
        coalesce((sum(LPC.amount)-sum(u.daily_spent)), 0) as pribil
        from LPC
left join unoin_ads as u 
    on u.campaign_date = LPC.visit_date
    and u.utm_source = LPC.utm_source
    and    u.utm_medium = LPC.utm_medium 
    and    u.utm_campaign = LPC.utm_campaign 
where LPC.rang = 1
group by 1
;

---
with LPC as (
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
        row_number() over(partition by s.visitor_id order by s.visit_date desc) as rang
    from sessions s 
    left join leads l on s.visitor_id  = l.visitor_id 
        and s.visit_date <= l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
), unoin_ads as (
SELECT
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        coalesce(sum(vk.daily_spent), 0) as daily_spent
    FROM vk_ads AS vk
    group by 1,2,3,4
    union all
    SELECT
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        coalesce(sum(ya.daily_spent), 0) as daily_spent
    FROM ya_ads as ya 
    group by 1,2,3,4
), metrics as (
    select 
        LPC.visit_date as start_day,
            LPC.utm_source,
            LPC.utm_medium,
            LPC.utm_campaign,
            coalesce(u.daily_spent, 0) as total_cost,
            coalesce(sum(LPC.amount), 0 ) as revenue
            from LPC
    left join unoin_ads as u 
        on u.campaign_date = LPC.visit_date
        and u.utm_source = LPC.utm_source
        and    u.utm_medium = LPC.utm_medium 
        and    u.utm_campaign = LPC.utm_campaign 
    where LPC.rang = 1
    and LPC.utm_source in ('vk', 'yandex')
    group by 1,2,3,4,5
    order by revenue desc NULLS last, LPC.utm_source asc, LPC.utm_medium asc, LPC.utm_campaign asc
)
select
  --m.start_day,
    m.utm_source,
    m.utm_medium,
    m.utm_campaign,
    m.total_cost,
    m.revenue,
    (m.revenue - m.total_cost) as pribul,
    round((m.revenue - m.total_cost) / nullif(m.total_cost, 0) * 100.0, 2) as ROI
from metrics as m
group by 1, 2, 3, 4, 5
having (m.revenue - m.total_cost) > 0
order by 5 desc
;

---
with LPC as (
    select 
        s.visitor_id,
        s.visit_date::date,
        s."source" as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.learning_format,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id
    from sessions s 
    left join leads l on s.visitor_id  = l.visitor_id 
        and s.visit_date <= l.created_at
)
select 
        LPC.visit_date,
        count(LPC.visitor_id) as visitors_count,
        LPC.utm_source,
        LPC.utm_medium,
        LPC.utm_campaign,
        LPC.learning_format,
        count(distinct LPC.lead_id) as leads_count,
        count(LPC.lead_id)  filter (
            where LPC.status_id = 142) as purchases_count,
        coalesce(sum(LPC.amount), 0) as revenue
        from LPC
where LPC.status_id is not null
group by 1,3,4,5,6
order by revenue desc
;
