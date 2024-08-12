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
		row_number() over(partition by s.visitor_id order by s.visit_date) as rang
	from sessions s 
	left join leads l on s.visitor_id  = l.visitor_id 
		and s.visit_date < l.created_at
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
		LPC.visit_date,
		count(LPC.visitor_id) as visitors_count,
		LPC.utm_source,
		LPC.utm_medium,
		LPC.utm_campaign,
		u.daily_spent as total_cost,
		count(distinct LPC.lead_id) as leads_count,
		(select count(LPC.lead_id) 
		from LPC
		where LPC.status_id = 142) as purchases_count,
		sum(LPC.amount) as revenue
		from LPC
left join unoin_ads as u 
	on u.campaign_date = LPC.visit_date
	and u.utm_source = LPC.utm_source
	and	u.utm_medium = LPC.utm_medium 
	and	u.utm_campaign = LPC.utm_campaign 
where LPC.rang = 1
group by 1,3,4,5,6
order by revenue desc NULLS last, LPC.visit_date asc, visitors_count desc, LPC.utm_source asc, LPC.utm_medium asc, LPC.utm_campaign asc
limit 15
;