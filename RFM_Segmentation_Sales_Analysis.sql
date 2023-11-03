---inspecting  Data
Select * from [PortfolioDB].[dbo].[sales_data_sample]

--Checking unique values
select distinct status from [PortfolioDB].[dbo].[sales_data_sample]
select distinct year_id from [PortfolioDB].[dbo].[sales_data_sample]
select distinct productline from [PortfolioDB].[dbo].[sales_data_sample]
select distinct country from [PortfolioDB].[dbo].[sales_data_sample]
select distinct [CITY] from [PortfolioDB].[dbo].[sales_data_sample]
select distinct [TERRITORY] from [PortfolioDB].[dbo].[sales_data_sample] 
select distinct [DEALSIZE] from [PortfolioDB].[dbo].[sales_data_sample]


select distinct [MONTH_ID] from [PortfolioDB].[dbo].[sales_data_sample]
where [YEAR_ID] = 2005 --We can change the year to see the months we have data for in each year from 2004 to 2005
-- Based on the data the company operated for a full year in 2003 and 2004 but only operated until month 5(May) in 2005.

--ANALYSIS

--GROUPING SALES BY PRODUCTLINE.
select [PRODUCTLINE], SUM([SALES]) Revenue
	from [PortfolioDB].[dbo].[sales_data_sample]
	group by [PRODUCTLINE]
	order by Revenue desc

--GROUPING SALES BY STATUS.
select [STATUS], SUM([SALES]) Revenue
	from [PortfolioDB].[dbo].[sales_data_sample]
	group by [STATUS]
	order by Revenue desc


-- GROUPING SALES BY DEAL SIZES.
select [DEALSIZE], sum([SALES]) Revenue
	from [PortfolioDB].[dbo].[sales_data_sample]
	group by [DEALSIZE]
	order by Revenue desc

-- GROUPING SALES BY COUNTRY
select [COUNTRY], sum([SALES]) Revenue
	from [PortfolioDB].[dbo].[sales_data_sample]
	group by [COUNTRY]
	order by Revenue desc

-- GROUPING SALES BY YEAR.
select [YEAR_ID], sum([SALES]) Revenue
	from [PortfolioDB].[dbo].[sales_data_sample]
	group by [YEAR_ID]
	order by Revenue desc	

-- WHAT WAS THE BEST MONTH IN EACH YEAT AND HOW MUCH WAS MADE?
select [MONTH_ID], SUM([SALES]) Revenue, COUNT([ORDERNUMBER]) Frequency
	from [PortfolioDB].[dbo].[sales_data_sample]
	where [YEAR_ID] = 2003 -- change year to see for other years
	group by [MONTH_ID]
	order by Revenue desc

--NOVEMBER IS THE MOST SELLING MONTH OF THE YEAR,NOW WHICH PRODUCT IS THE MOST SOLD DURING NOVEMBER(Month number 11)?
select [MONTH_ID], [PRODUCTLINE], sum([SALES]) Revenue, COUNT([ORDERNUMBER]) frequency
	from [PortfolioDB].[dbo].[sales_data_sample]
	where [YEAR_ID]= 2004 and [MONTH_ID] = 11 -- change year to see which product was most sold during november for each year
	group by [PRODUCTLINE],  [MONTH_ID]
	order by Revenue desc;

--WHICH PRODUCTS ARE MOSTLY SOLD TOGETHER, 2 ITEMS AND 3 ITEMS SOLD TOGETHER 
--A Data mining technique called "Market bustcket analysis" should answer the above question for us.
select distinct [ORDERNUMBER], STUFF(
		(select ',' + ' ' + [PRODUCTCODE]
		from [PortfolioDB].[dbo].[sales_data_sample] A
		where [ORDERNUMBER] in 
			(
				select  [ORDERNUMBER]
				from
					(
						select [ORDERNUMBER], count(*) shipped_orders
						from [PortfolioDB].[dbo].[sales_data_sample]
						where [STATUS] = 'Shipped'
						group by ORDERNUMBER
					)O
				where shipped_orders = 2
			) and  A.[ORDERNUMBER] = B.[ORDERNUMBER]
			for xml path(''))
			,1, 1, '') productcodes
		from [PortfolioDB].[dbo].[sales_data_sample] B
		order by 2 desc


-- who is our best customer(RMF can answer that)
DROP TABLE IF EXISTS #Base
;with Base as
(
	select	[CUSTOMERNAME] Customer_name,
			MAX([ORDERDATE]) most_recent_purchase_data,
			(select MAX([ORDERDATE]) from [PortfolioDB].[dbo].[sales_data_sample] ) max_order_date,
			DATEDIFF(Day, MAX(ORDERDATE),(select MAX([ORDERDATE]) from [PortfolioDB].[dbo].[sales_data_sample] )) Recency_score,
			COUNT([ORDERNUMBER]) Frequency_score,
			cast(Sum([SALES]) as decimal(16,2)) MonetaryValue_score
	from [PortfolioDB].[dbo].[sales_data_sample]
	group by [CUSTOMERNAME]
),
rfm_calc as
(
	select r.*,
			NTILE(4) OVER (order by Recency_score desc) rfm_Recency,
			NTILE(4) OVER (order by Frequency_score asc) rfm_frequency,
			NTILE(4) OVER (order by MonetaryValue_score asc) rfm_monetary
	
	from Base r
)
select	c.*, rfm_Recency  + rfm_frequency + rfm_monetary as rfm_cell,
		cast(rfm_Recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary  as varchar) rfm_cell_string
INTO #Base
from rfm_calc c

SELECT  Customer_name, rfm_Recency, rfm_frequency,  rfm_monetary,
			case 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144, 243, 232) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away
		when rfm_cell_string in (311, 411, 421, 331, 412) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322, 234) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
		
	end rfm_segment
FROM #Base

