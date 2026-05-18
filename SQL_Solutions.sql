-- (1) Find total eligible customers, qualified customers, and qualification rate for each promotion
SELECT p.promotion_name,
count(case
when pp.eligible_flag = 1
then 1 end) as eligible_customers
FROM promotions p
JOIN promotion_participants pp
ON p.promotion_id = pp.promotion_id
GROUP BY p.promotion_name;

-- Total qualified customers
SELECT p.promotion_name,
count(case
when pp.qualified_flag = 1
then 1 end) as qualified_customers
FROM promotions p
JOIN promotion_participants pp
ON p.promotion_id = pp.promotion_id
GROUP BY p.promotion_name;

-- Find qualification rate for each promotion
select p.promotion_name,
COUNT(case
when pp.qualified_flag = 1 
then 1 end) * 100.0 
/
count(case 
when pp.eligible_flag = 1 
then 1 end)
as qualification_rate
from promotions p
join promotion_participants pp
on p.promotion_id = pp.promotion_id
group by p.promotion_name;

-- (2) For each promotion, calculate total sales generated during the promotion period by eligible participants only
select p.promotion_name, SUM(o.order_value) AS total_sales
from promotions p
join promotion_participants pp
on p.promotion_id = pp.promotion_id
join orders o
on pp.customer_id = o.customer_id
where pp.eligible_flag = 1
and o.order_date between p.start_date and p.end_date
group by p.promotion_name;

-- (3) Compare customer sales during the promotion period vs the same number of days before the promotion started
select p.promotion_name, pp.customer_id,
sum(case
when o.order_date between p.start_date and p.end_date
then o.order_value
else 0
end) as sales_during_promotion,
sum(case
when o.order_date between
date_sub(p.start_date,interval datediff(p.end_date,p.start_date) day)
and date_sub(p.start_date,interval 1 day)
then o.order_value
else 0
end) as sales_before_promotion,
(
sum(case
when o.order_date between p.start_date and p.end_date
then o.order_value
else 0
end)
-
sum(case
when o.order_date between 
date_sub(p.start_date,interval datediff(p.end_date,p.start_date) day)
and date_sub(p.start_date,interval 1 day)
then o.order_value
else 0
end)
)*100
/
nullif(
sum(case
when o.order_date between 
date_sub(p.start_date,interval datediff(p.end_date,p.start_date) day)
and date_sub(p.start_date,interval 1 day)
then o.order_value
else 0
end),
0) as sales_lift_percent
from promotions p
join promotion_participants pp
on p.promotion_id=pp.promotion_id
left join orders o
on pp.customer_id=o.customer_id
group by p.promotion_name,pp.customer_id;

-- (4)Identify customers who qualified for a promotion but had zero orders during the promotion period
select c.customer_id, c.customer_name
from promotions p
join promotion_participants pp
on p.promotion_id = pp.promotion_id
join customers c
on pp.customer_id = c.customer_id
left join orders o
on pp.customer_id = o.customer_id
and o.order_date 
between p.start_date and p.end_date
where pp.qualified_flag = 1
and o.order_id is null;

/* (5) Rank promotions by effectiveness using

(a) qualification rate  = (Eligible Customers / Qualified Customers​)* 100 */
select p.promotion_name, p.promotion_id, p.market,
count(case
when pp.qualified_flag = 1 then 1
end) * 100.0 
/ 
count(case
when pp.eligible_flag = 1 then 1
end) as qualification_rate
from promotions p
join promotion_participants pp 
on p.promotion_id = pp.promotion_id
group by p.promotion_name , p.promotion_id , p.market
order by qualification_rate desc
limit 5;

-- (b) sales lift % 
select p.promotion_name, (sum(case
when o.order_date 
between p.start_date and p.end_date
then o.order_value
else 0
end)
-
sum(case
when o.order_date between date_sub(p.start_date, interval datediff(p.end_date, p.start_date) +1 day)
and date_sub(p.start_date, interval 1 day)
then o.order_value
else 0
end))*100
/
nullif (sum (case
when o.order_date 
between date_sub( p.start_date, interval datediff(p.end_date, p.start_date)+1 day)
and date_sub(p.start_date, interval 1 day)
then o.order_value
else 0
end), 0) as sales_lift_percent
from promotions p
join promotion_participants pp
on p.promotion_id = pp.promotion_id
left join orders o
on pp.customer_id = o.customer_id
group by p.promotion_name;


-- (c) Reward cost
select p.promotion_name, sum(pp.reward_amount) as total_reward_cost
from promotions p
join promotion_participants pp
on p.promotion_id = pp.promotion_id
group by p.promotion_name;

-- (d) Net value
select p.promotion_name, sum(case
when o.order_date 
between p.start_date and p.end_date
then o.commission_value
else 0 end) as commission_value,
sum(pp.reward_amount) as reward_cost,
(sum(case
when o.order_date 
between p.start_date and p.end_date
then o.commission_value
else 0 end)
-
sum(pp.reward_amount)
) as net_value
from promotions p
join promotion_participants pp
on p.promotion_id = pp.promotion_id
left join orders o
on pp.customer_id = o.customer_id
group by p.promotion_name
order by net_value desc
limit 5;