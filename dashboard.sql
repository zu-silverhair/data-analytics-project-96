---Шаг 4 Расчет метрик

--Сколько у нас пользователей заходят на сайт?
with lp as (
    select
        date_trunc('week', s.visit_date) as start_week,
        to_char(s.visit_date, 'yyyy-mm-dd') as dates,
        count(s.visitor_id) as count_visitor
    from sessions as s
    group by 1, 2
)

select
    sum(lp.count_visitor) as count_month,
    round(sum(lp.count_visitor) / 5, 0) as count_week,
    round(avg(lp.count_visitor), 0) as count_day
from lp;

--Какие каналы их приводят на сайт? 
--Хочется видеть по дням/неделям/месяцам для по модели атрибуции LastPaidClick
--по дням недели
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
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
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
)

select
    --lpc.visit_date as start_day,
    --date_trunc('week', lpc.visit_date) as start_week,
    --to_char(lpc.visit_date, 'Month') as start_month,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    count(lpc.visitor_id) as visitors_count,
    to_char(lpc.visit_date, 'Day') as day_week,
    to_char(lpc.visit_date, 'D') as day_week_number
from lpc
left join unoin_ads as u
    on
        u.campaign_date = lpc.visit_date
        and u.utm_source = lpc.utm_source
        and u.utm_medium = lpc.utm_medium
        and u.utm_campaign = lpc.utm_campaign
where lpc.rang = 1
group by 1, 2, 3, 5, 6
order by 6 asc;

--Сколько лидов к нам приходят?

select count(l.lead_id) as count_leads
from leads as l;

--Какая конверсия из клика в лид? А из лида в оплату?

/*with lp as (
    select
        count(distinct s.visitor_id) as count_visitors,
        count(distinct l.lead_id)::numeric as count_leads,
        count(l.lead_id) filter (
            where l.status_id = 142
        ) as purchases_count
    from sessions as s
    left join leads as l
        on s.visitor_id = l.visitor_id
)
select
    lp.count_visitors,
    lp.count_leads,
    lp.purchases_count,
    round(lp.count_leads / lp.count_visitors * 100, 2) as conversion_lead,
    round((lp.purchases_count / lp.count_leads) * 100, 2) as conversion_amlead
from lp;*/

select
    count(distinct s.visitor_id) as count_visitors,
    count(distinct l.lead_id)::numeric as count_leads,
    count(l.lead_id) filter (
        where l.status_id = 142
    ) as purchases_count,
    round((count(distinct l.lead_id)::numeric) / (count(distinct s.visitor_id)) * 100, 2) as conversion_lead,
    round((count(l.lead_id) filter (
        where l.status_id = 142
    )) / (count(distinct l.lead_id)::numeric) * 100, 2) as conversion_amlead
from sessions as s
left join leads as l
    on s.visitor_id = l.visitor_id;
    
--Сколько мы тратим по разным каналам в динамике? только для вк и яндекс

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
    where
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
        and s."source" in ('vk', 'yandex')
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
)

select
    lpc.visit_date as start_day,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    coalesce(sum(u.daily_spent), 0) as total_cost,
    to_char(lpc.visit_date, 'Day') as day_week,
    extract(isodow from lpc.visit_date) as day_week_number
from lpc
left join unoin_ads as u
    on
        u.campaign_date = lpc.visit_date
        and u.utm_source = lpc.utm_source
        and u.utm_medium = lpc.utm_medium
        and u.utm_campaign = lpc.utm_campaign
where lpc.rang = 1
group by 1, 2, 3, 4, 6
order by 1;

---Окупаются ли каналы? Почему такая разницв между вk и яндекс/
---Обязательно рассчитать основные метрики;
------Шаг 5 Презентация и выводы
---Есть ли окупаемые каналы? Если да, то какие?
---Какие рекламные каналы стоит отключить,над какими нужно поработать/улучшить

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
    where
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
        and s."source" in ('vk', 'yandex')
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
        count(distinct lpc.visitor_id) as visitors_count,
        coalesce(u.daily_spent, 0) as total_cost,
        count(distinct lpc.lead_id) as leads_count,
        count(lpc.lead_id) filter (
            where lpc.status_id = 142
        ) as purchases_count,
        coalesce(sum(lpc.amount), 0) as revenue
    from lpc
    left join unoin_ads as u
        on
            u.campaign_date = lpc.visit_date
            and u.utm_source = lpc.utm_source
            and u.utm_medium = lpc.utm_medium
            and u.utm_campaign = lpc.utm_campaign
    where lpc.rang = 1
    group by 1, 2, 3, 4, 6
)

select
    m.utm_source,
    m.utm_medium,
    m.utm_campaign,
    sum(m.visitors_count) as visitors_sum,
    sum(m.leads_count) as leads_sum,
    sum(m.purchases_count) as purchases_sum,
    sum(m.total_cost) as total_cost_sum,
    sum(m.revenue) as revenue_sum,
    case
        when sum(m.visitors_count) = 0 then 0
        else round(sum(m.total_cost) / sum(m.visitors_count))
    end as cpu,
    case
        when sum(m.leads_count) = 0 then 0
        else round(sum(m.total_cost) / sum(m.leads_count))
    end as cpl,
    case
        when sum(m.purchases_count) = 0 then 0
        else round(sum(m.total_cost) / sum(m.purchases_count))
    end as cppu,
    case
        when sum(m.total_cost) = 0 then 0
        else
            round(
                ((sum(m.revenue) - sum(m.total_cost)) / sum(m.total_cost)
                ) * 100, 0
            )
    end as roi
from metrics as m
group by 1, 2, 3
order by 12 desc;

---Через какое время после запуска компании 
---маркетинг может анализировать компанию используя ваш дашборд? 
---Можно посчитать за сколько дней с момента перехода по рекламе
---закрывается 90% лидов
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
)

select
    lpc.utm_source,
    lpc.utm_medium,
    percentile_disc(0.90) within group (
        order by date_part('day', lpc.created_at - lpc.visit_date)
    ) as _day_leads
from lpc
group by 1, 2
order by 3 desc nulls last;

--Есть ли заметная корреляция между запуском рекламной компании/ростом органики

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
)

select
    lpc.visit_date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    count(lpc.visitor_id) as visitors_count,
    count(distinct lpc.lead_id) as leads_count,
    count(lpc.lead_id) filter (
        where lpc.status_id = 142
    ) as purchases_count,
    coalesce(sum(lpc.amount), 0) as revenue
from lpc
where lpc.rang = 1
group by 1, 2, 3, 4
order by 8 desc;

---Любые другие инсайты, которые вы можете найти в данных

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
    where
        s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
        and s."source" in ('vk', 'yandex')
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
)

select
    lpc.utm_source,
    coalesce(sum(u.daily_spent), 0) as total_cost,
    coalesce(sum(lpc.amount), 0) as revenue,
    coalesce((sum(lpc.amount) - sum(u.daily_spent)), 0) as pribil
from lpc
left join unoin_ads as u
    on
        u.campaign_date = lpc.visit_date
        and u.utm_source = lpc.utm_source
        and u.utm_medium = lpc.utm_medium
        and u.utm_campaign = lpc.utm_campaign
where lpc.rang = 1
group by 1;

---ANY
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
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
),

unoin_ads as (
    select
        vk.campaign_date::date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        coalesce(sum(vk.daily_spent), 0) as daily_spent
    from vk_ads as vk
    group by 1, 2, 3, 4
    union all
    select
        ya.campaign_date::date,
        ya.utm_source,
        ya.utm_medium,
        ya.utm_campaign,
        coalesce(sum(ya.daily_spent), 0) as daily_spent
    from ya_ads as ya
    group by 1, 2, 3, 4
),

metrics as (
    select
        lpc.visit_date as start_day,
        lpc.utm_source,
        lpc.utm_medium,
        lpc.utm_campaign,
        coalesce(u.daily_spent, 0) as total_cost,
        coalesce(sum(lpc.amount), 0) as revenue
    from lpc
    left join unoin_ads as u
        on
            u.campaign_date = lpc.visit_date
            and u.utm_source = lpc.utm_source
            and u.utm_medium = lpc.utm_medium
            and u.utm_campaign = lpc.utm_campaign
    where
        lpc.rang = 1
        and lpc.utm_source in ('vk', 'yandex')
    group by 1, 2, 3, 4, 5
    order by 6 desc nulls last
)

select
    --m.start_day,
    utm_source,
    utm_medium,
    utm_campaign,
    total_cost,
    revenue,
    (revenue - total_cost) as pribul,
    round((revenue - total_cost) / nullif(total_cost, 0) * 100.0, 2) as roi
from metrics
group by 1, 2, 3, 4, 5
having (revenue - total_cost) > 0
order by 5 desc;

---any learning_format
with lpc as (
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
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
)

select
    lpc.visit_date,
    lpc.utm_source,
    lpc.utm_medium,
    lpc.utm_campaign,
    lpc.learning_format,
    count(lpc.visitor_id) as visitors_count,
    count(distinct lpc.lead_id) as leads_count,
    count(lpc.lead_id) filter (
        where lpc.status_id = 142
    ) as purchases_count,
    coalesce(sum(lpc.amount), 0) as revenue
from lpc
where lpc.status_id is not null
group by 1, 2, 3, 4, 5
order by 9 desc;
