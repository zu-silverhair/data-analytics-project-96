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
        row_number() over (
            partition by s.visitor_id order by s.visit_date desc
        ) as rang
    from sessions as s
    left join leads as l
        on
            s.visitor_id = l.visitor_id
            and s.visit_date <= l.created_at
    where s.medium != 'organic'
    order by s.visit_date desc
)

select
    tab.visitor_id,
    tab.visit_date,
    tab.utm_source,
    tab.utm_medium,
    tab.utm_campaign,
    tab.lead_id,
    tab.created_at,
    tab.amount,
    tab.closing_reason,
    tab.status_id
from tab
where rang = 1
order by tab.visit_date asc, tab.utm_source asc, tab.utm_medium asc,
    tab.utm_campaign asc, tab.amount desc nulls last
limit 10;
