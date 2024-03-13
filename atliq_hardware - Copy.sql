show tables
select * from dim_customer
select * from dim_product
select * from fact_gross_price
select * from fact_manufacturing_cost
select * from fact_pre_invoice_deductions
select * from fact_sales_monthly


SELECT
    DISTINCT market FROM  dim_customer
WHERE region = 'APAC' AND customer = "Atliq Exclusive";


SELECT X.A AS unique_product_2020, Y.B AS unique_products_2021, ROUND((B-A)*100/A, 2) AS percentage_chg
FROM
     (
      (SELECT COUNT(DISTINCT(product_code)) AS A FROM fact_sales_monthly
      WHERE fiscal_year = 2020) X,
      (SELECT COUNT(DISTINCT(product_code)) AS B FROM fact_sales_monthly
      WHERE fiscal_year = 2021) Y 
	 )

/*What is the percentage of unique product increase in 2021 vs. 2020?
The final output contains these fields,unique_products_2020,unique_products_2021, percentage_chg*/
  
with unique_products as 
(
select fiscal_year,
count(distinct product_code) as unique_products 
from fact_sales_monthly
group by fiscal_year
)
select
up_2020.unique_products as unique_products_2020,
up_2021.unique_products as unique_products_2021,
round((up_2021.unique_products - up_2020.unique_products)/up_2020.unique_products *100,2) as per_change
from unique_products up_2020
join unique_products up_2021
where up_2020.fiscal_year = 2020
and up_2021.fiscal_year = 2021


/*Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
The final output contains 2 fields,segment,product_coun*/

select count(distinct product_code) as product_count, segment
from dim_product
group by segment
order by product_count desc

/*Which segment had the most increase in unique products in 2021 vs 2020? 
The final output contains these fields- segment,product_count_2020,product_count_2021,difference*/

with seg_table as 
(
select
p.segment,
f.fiscal_year,
count(distinct p.product_code) as product_count 
from dim_product p
join fact_sales_monthly as f
on p.product_code = f.product_code
group by segment, fiscal_year
)
select 
pc_2020.segment,
pc_2020.product_count as product_count_2020,
pc_2021.product_count as product_count_2021,
(pc_2021.product_count - pc_2020.product_count) as difference
from
seg_table pc_2020
join seg_table pc_2021
on pc_2020.segment = pc_2021.segment
where pc_2020.fiscal_year = 2020
and pc_2021.fiscal_year = 2021
group by pc_2020.segment
order by difference desc

/*Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields-  product_code, product, manufacturing_cost*/

select  m.product_code, d.product, m.manufacturing_cost
from fact_manufacturing_cost m
join  dim_product as d 
on m.product_code = d.product_code
where m.manufacturing_cost=
(SELECT min(manufacturing_cost) FROM fact_manufacturing_cost)
or 
m.manufacturing_cost = 
(SELECT max(manufacturing_cost) FROM fact_manufacturing_cost) 
order by manufacturing_cost desc

--OR

SELECT m.product_code, concat(product," (",variant,")") AS product, cost_year,manufacturing_cost
FROM fact_manufacturing_cost m
JOIN dim_product p ON m.product_code = p.product_code
WHERE manufacturing_cost= 
(SELECT min(manufacturing_cost) FROM fact_manufacturing_cost)
or 
manufacturing_cost = 
(SELECT max(manufacturing_cost) FROM fact_manufacturing_cost) 
ORDER BY manufacturing_cost DESC;


/*Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields -  customer_code, customer, average_discount_percentage*/

select d.customer_code, d.customer, round(avg(pre_invoice_discount_pct),4) as avg_discount_pct
from dim_customer as d 
join fact_pre_invoice_deductions as fp
on d.customer_code = fp.customer_code
where  fp.fiscal_year = 2021 and d.market = "India"
group by d.customer_code, d.customer
order by avg_discount_pct desc
limit 5

/*Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions. The final report contains these columns: Month Year Gross sales Amount*/

select
year(m.date) as Year,
monthname(m.date) as month,
concat(round(sum(m.sold_quantity * gp.gross_price)/1000000,2),' m') as gross_sales_amount 
from dim_customer as dm
join fact_sales_monthly as m 
on dm.customer_code = m.customer_code
join fact_gross_price as gp 
on m.product_code = gp.product_code 
where dm.customer = "Atliq Exclusive"
group by month, Year
order by year 

--OR

SELECT CONCAT(MONTHNAME(FS.date), ' (', YEAR(FS.date), ')') AS 'Month', FS.fiscal_year,
       ROUND(SUM(G.gross_price*FS.sold_quantity), 2) AS Gross_sales_Amount
FROM fact_sales_monthly FS JOIN dim_customer C ON FS.customer_code = C.customer_code
						   JOIN fact_gross_price G ON FS.product_code = G.product_code
WHERE C.customer = 'Atliq Exclusive'
GROUP BY  Month, FS.fiscal_year 
ORDER BY FS.fiscal_year ;

/*In which quarter of 2020, got the maximum total_sold_quantity? The final output contains these fields sorted by the total_sold_quantity,
Quarter total_sold_quantity*/

select 
CASE
		WHEN MONTH(date) BETWEEN 9 AND 11 THEN 'FIRST QUARTER'
        WHEN MONTH(date) BETWEEN 12 AND 2 THEN 'SECOND QUARTER'
        WHEN MONTH(date) BETWEEN 3 AND 5 THEN 'THIRD QUARTER'
        WHEN MONTH(date) BETWEEN 6 AND 8 THEN 'FOURTH QUARTER'
END AS QUARTER ,
SUM(sold_quantity) AS total_sold_quantity
from fact_sales_monthly
where fiscal_year = 2020
group by quarter


WITH temp_table AS (
  SELECT date,month(date_add(date,interval 4 month)) AS period, fiscal_year,sold_quantity 
FROM fact_sales_monthly
)
SELECT CASE 
   when period/3 <= 1 then "Q1"
   when period/3 <= 2 and period/3 > 1 then "Q2"
   when period/3 <=3 and period/3 > 2 then "Q3"
   when period/3 <=4 and period/3 > 3 then "Q4" END quarter,
 round(sum(sold_quantity)/1000000,2) as total_sold_quanity_in_millions FROM temp_table
WHERE fiscal_year = 2020
GROUP BY quarter
ORDER BY total_sold_quanity_in_millions DESC ;

/**Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? The final output contains these fields,
channel gross_sales_mln percentage*/

with temp_table as(
select c.channel, sum(m.sold_quantity * g.gross_price)  as total_sales
from fact_gross_price as g
join fact_sales_monthly as m
on g.product_code = m.product_code
join dim_customer as c
on c.customer_code = m.customer_code
where m.fiscal_year = 2021
group by c.channel
)
select channel,
round(total_sales/1000000,2) as gross_sales_in_millions,
round(total_sales/(sum(total_sales)over())*100,2) as per
from temp_table
order by per


WITH temp_table AS (
      SELECT c.channel,sum(s.sold_quantity * g.gross_price) AS total_sales
  FROM
  fact_sales_monthly s 
  JOIN fact_gross_price g ON s.product_code = g.product_code
  JOIN dim_customer c ON s.customer_code = c.customer_code
  WHERE s.fiscal_year= 2021
  GROUP BY c.channel
  ORDER BY total_sales DESC
)
SELECT 
  channel,
  round(total_sales/1000000,2) AS gross_sales_in_millions,
  round(total_sales/(sum(total_sales) OVER())*100,2) AS percentage 
FROM temp_table; 

/*Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these
fields, division, product_code,product, total_sold_quantity, rank_order*/

WITH temp_table AS (
    select p.division, s.product_code, sum(sold_quantity) AS total_sold_quantity,
    rank() OVER (partition by division order by sum(sold_quantity) desc) AS rank_order
 FROM
 fact_sales_monthly s
 JOIN dim_product p
 ON s.product_code = p.product_code
 WHERE fiscal_year = 2021
 GROUP BY  p.division, s.product_code
)
SELECT * FROM temp_table
WHERE rank_order IN (1,2,3);




