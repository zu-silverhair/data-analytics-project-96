---Напишите запрос для атрибуции лидов по модели Last Paid Click топ-10 записей

with tab as (
    select
        s.visitor_id,
        s.visit_date,
        s."source" as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        l.lead_id,
        l.created_at,
        l.amount,
        l.closing_reason,
        l.status_id,
        row_number() over (partition by s.visitor_id order by s.visit_date desc) as rang
    from sessions as s
    left join 
        leads as l on s.visitor_id = l.visitor_id
        and s.visit_date < l.created_at
    where s.medium in ('cpc', 'cpm', 'cpa', 'youtube', 'cpp', 'tg', 'social')
    order by s.visit_date desc
)

select
    visitor_id,
    visit_date,
    utm_source,
    utm_medium,
    utm_campaign,
    lead_id,
    created_at,
    amount,
    closing_reason,
    status_id
from tab
where rang = 1
order by amount desc nulls last, visit_date, utm_source, utm_medium,
    utm_campaign, lead_id, created_at, closing_reason, status_id
limit 10;
