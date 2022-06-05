-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

/*DATA9910 WwD -- Assignment 1 -- Simon Hall*/

/*Schema Querying Script.*/

/*We are now in a position to query our data warehouse using the schema 
created in the previous file.*/

/*First, we can discover range of dates in this time period. The data runs
from 1st January, 2021, to 29th April, 2021. This represents the entirety of
the first quarter, and the beginning of the second.*/

SELECT MIN(call_time) AS "Earliest Date"
FROM customer_calls_fact_table;

SELECT MAX(call_time) AS "Latest Date"
FROM customer_calls_fact_table;

SELECT ROUND(MONTHS_BETWEEN(MAX(call_time), MIN(call_time)),2) AS "Months"
FROM customer_calls_fact_table;

/*Next, we can discover the total revenue generated in this time period.
This amounts to €502,322.64*/

SELECT sum(total_cost) AS "Total Revenue" FROM customer_calls_fact_table;

/*Next, we can discover the total revenue generated per quarter. As we
expect, since the data doesn't include all of Q2, Q1 generated more revenue. 
Q1: €401,337.25. Q2: €100,985.39. Also, customer churn takes its toll.*/

SELECT dd.quarter AS "Quarter", sum(ccft.total_cost) AS "Total Revenue"
FROM customer_calls_fact_table ccft
JOIN date_dim dd on ccft.call_time = dd.date_long 
GROUP BY dd.quarter
ORDER BY sum(ccft.total_cost) DESC;

/*We can also discover the total revenue generated per month.*/

SELECT dd.month_name AS "Month", sum(ccft.total_cost) AS "Total Revenue"
FROM customer_calls_fact_table ccft
JOIN date_dim dd on ccft.call_time = dd.date_long 
GROUP BY dd.month_name
ORDER BY sum(ccft.total_cost) DESC;

/*Next, we can discover the total revenue generated per customer. The top
spender is 065 692 1249, who spent €538.86.*/

SELECT phone_number AS "Customer", sum(total_cost) AS "Total Revenue"
FROM customer_calls_fact_table
GROUP BY phone_number
ORDER BY sum(total_cost) DESC;

/*We can generate a ranking of customers in this period by using the 
rank function.*/

SELECT phone_number AS "Customer", sum(total_cost) "Total Revenue",
RANK() OVER (ORDER BY sum(total_cost) DESC) AS "Ranking"
FROM customer_calls_fact_table
GROUP BY phone_number;

/*We can also generate a ranking of customers per month, taking January
as an example.*/

SELECT phone_number AS "Customer", sum(total_cost) "Total Revenue",
RANK() OVER (ORDER BY sum(total_cost) DESC) AS "Ranking"
FROM customer_calls_fact_table
WHERE to_char(call_time, 'FMMonth') = 'January'
GROUP BY phone_number;

/*We can also determine the average cost per call per customer.*/

SELECT phone_number AS "Phone Number", round(avg(total_cost),2) AS "Average Cost"
FROM customer_calls_fact_table
GROUP BY phone_number
ORDER BY round(avg(total_cost),2) DESC;

/*From a customer's perspective, we can also calculate the monthly bill
per customer, and list it according the month number.*/

SELECT phone_number AS "Customer", dd.month_name AS "Month", dd.month_num AS "Month Number", sum(total_cost) AS "Total Revenue"
FROM customer_calls_fact_table ccft
JOIN date_dim dd ON ccft.call_time = dd.date_long
GROUP BY phone_number, dd.month_name, dd.month_num
ORDER BY dd.month_num;

/*Or order according to total cost.*/

SELECT phone_number AS "Customer", dd.month_name AS "Month", dd.month_num AS "Month Number", sum(total_cost) AS "Total Revenue"
FROM customer_calls_fact_table ccft
JOIN date_dim dd ON ccft.call_time = dd.date_long
GROUP BY phone_number, dd.month_name, dd.month_num
ORDER BY sum(total_cost) DESC;

/*We can also display the total cost per call type per month, in an aggregated 
bill per customer using the rollup function.*/
SELECT phone_number AS "Customer", call_type AS "Call Type", sum(total_cost) AS "Total"
FROM customer_calls_fact_table
WHERE phone_number = '01 205 8305' AND to_char(call_time, 'FMMonth') = 'January'
GROUP BY ROLLUP (phone_number, call_type)
ORDER BY call_type;

/*Next, we can discover the total revenue generated per plan. Plan 2,
the off-peak plan, is the biggest earner at	€183,846.4. Plan 1, the standard
plan, comes next at €178,732.73. Plan 3, cosmopolitan, is the lowest earner
at €139,743.51.*/

SELECT ccft.plan_id AS "Plan ID", cp.contract_name AS "Plan Name", sum(ccft.total_cost) AS "Total Revenue"
FROM customer_calls_fact_table ccft
JOIN contract_plans cp on ccft.plan_id = cp.contract_id 
GROUP BY ccft.plan_id, cp.contract_name
ORDER BY sum(ccft.total_cost) DESC;

/*Next, we can discover the total revenue generated per plan per call type. 
Predictably, the top three are all roaming calls, Call Type 4, with the
biggest earner coming from Plan 2 (off-peak) Call Type 4 (roaming) at	
€86,089.58. Plan 1 (standard) Call Type 4 (roaming) comes next, at €83,872.88.
Plan 3 Call Type 4 (roaming) brings in €51,639.96.*/

SELECT ccft.plan_id AS "Plan ID", cp.contract_name AS "Plan Name", ccft.call_type AS "Call Type ID", rt.rate_name AS "Type Name", sum(ccft.total_cost) AS "Total Revenue"
FROM customer_calls_fact_table ccft
JOIN contract_plans cp on ccft.plan_id = cp.contract_id 
JOIN rate_types rt on ccft.call_type = rt.rate_type_id
GROUP BY ccft.plan_id, cp.contract_name, ccft.call_type, rt.rate_name
ORDER BY sum(ccft.total_cost) DESC;

/*Next, we can calculate the average cost per call, €2.49.*/

SELECT round(avg(total_cost),2) AS "Average Revenue" FROM customer_calls_fact_table;

/*We can also discover the average cost per call partitioned according
to call type. Expectedly, roaming and international calls have the highest
average cost per call, at €7.68 and €3.29 respectively. Roaming calls
are much more costly.*/

SELECT ccft.call_type AS "Call Type", rt.rate_name, round(avg(total_cost),2) AS "Average Revenue"
FROM customer_calls_fact_table ccft
JOIN rate_types rt on ccft.call_type = rt.rate_type_id
GROUP BY ccft.call_type, rt.rate_name
ORDER BY round(avg(total_cost),2) DESC;

/*Next, we can build up a profile of our customers. We can examine their
ages, occupations, locations, and the number of years they've been under
contract, a proxy for customer retention. Age is calculated from their dates of birth.
Occupation information is included in the Natinal Readership Survey (NRS) 
social grade maintained by the Market Research Society. Locations can be
determined from the prefixes attached to customers' phone numbers, although
their precise address is undoubtedly already known by the company.*/ 

/*First, we can examine the ages of most customers. The ages vary considerably,
so this information is of little use. People in their 60s occupy five of
the top ten positions, but this is not surprising. These are home phone
numbers, and older people represent a disproportionate number of home-owners.*/

SELECT floor(age) AS "Age", count(*) AS "Frequency" FROM customers
GROUP BY floor(age)
ORDER BY count(*) DESC;

/*A more valuable and more insightful measure is the average age of customers,
which is 47 years old.*/

SELECT round(avg(age),2) AS "Average Age" FROM customers;

/*We can attempt to understand our customers' occupations via their NRS social 
grade. The most frequent are the Lower Middle Class at 1,418, followed by the
Middle Middle Class at 1,188, then the Skilled Working Class at 960, the 
Working Class at 759, the Non-Working at 474, and the Upper Middle Class at 200.*/

SELECT c.nrs AS "NRS Grade", nrsd.nrs_label AS "Label", count(*) AS "Frequency" FROM customers c
JOIN nrs_descriptor nrsd ON c.nrs = nrsd.nrs
GROUP BY c.nrs, nrsd.nrs_label
ORDER BY count(*) DESC;

--We can include a more detailed description of these social grades.
SELECT c.nrs AS "NRS Grade", nrsd.nrs_label AS "Label", count(*) AS "Frequency", nrsd.nrs_description AS "Description" FROM customers c
JOIN nrs_descriptor nrsd ON c.nrs = nrsd.nrs
GROUP BY c.nrs, nrsd.nrs_label, nrsd.nrs_description
ORDER BY count(*) DESC;

/*Using Irish phone prefixes, we can pinpoint a phone location at the county 
level, and often also at the townland level. We can plot customer frequency on
a chloropleth map of Ireland. Predictably, the county with the highest number 
of customers is Dublin, numbering some 2,535. Cork is second, at 505. 
Mayo is third, at 257.*/

SELECT county AS "County", count(*) AS "Total Customers" FROM customers
GROUP BY county
ORDER BY count(*) DESC;

SELECT location AS "Location", count(*) AS "Total Customers" FROM customers
GROUP BY location
ORDER BY count(*) DESC;

/*We can determine the average duration under contract, a measure of 
customer retention. The average is 2.95 years.*/

SELECT round(avg(years_under_contract),2) AS "Average Duration of Contract" 
FROM customers;

/*We can rank the customers in terms of years spent under contract. 
The customer with the company longest is 051 672 6919, at 5.82 years.*/

SELECT phone_number AS "Customer", years_under_contract AS "Years under Contract"
FROM customers
ORDER BY years_under_contract DESC;

/*There are three customers with negative durations. This might be some type
of error made during data input.*/

SELECT min(years_under_contract) AS "Year under Contract" FROM customers;
SELECT * FROM customers WHERE years_under_contract = -0.24;

/*We can find the number of calls made by each customer in the given
time period.*/

SELECT phone_number AS "Customer", count(connection_id) AS "Total Calls"
FROM customer_calls_fact_table
GROUP BY phone_number
ORDER BY count(connection_id) DESC;

/*We can do the same by month.*/
SELECT phone_number AS "Customer", count(connection_id) AS "Total Calls"
FROM customer_calls_fact_table ccft
WHERE to_char(call_time, 'FMMonth') = 'January'
GROUP BY phone_number
ORDER BY count(connection_id) DESC;

/*We can find out when customers are making calls by aggregating
according to Time of Day, an attribute of the date dimension.
We can see that most calls are made in the morning, a total of 63,263.
Evening calls amount to 55,303. Night calls number 53,263. Afternoon calls
come in at 30,164.*/

SELECT dd.time_of_day AS "Time of Day", count(connection_id) AS "Total Calls" 
FROM customer_calls_fact_table ccft
JOIN date_dim dd ON ccft.call_time = dd.date_long
GROUP BY dd.time_of_day
ORDER BY count(connection_id) DESC;

/*We can find build a better temporal picture by aggregating according
to the day of the week. Sunday is the busiest, with 32,455 calls, followed
by Saturday with 32,451 calls.*/

SELECT dd.day_name AS "Day of Week", count(connection_id) AS "Total Calls" 
FROM customer_calls_fact_table ccft
JOIN date_dim dd ON ccft.call_time = dd.date_long
GROUP BY dd.day_name
ORDER BY count(connection_id) DESC;

/*Finally, we can investigate the pattern of behaviour of the customers 
over the course of time. We can see a pattern of declining call numbers,
broadly correlated with the passage of time. January has the most
number of calls, April has the fewest. However, January having the 
New Year holidays might be an outlier. Although many of the busiest days
are in late January. In general, however, there is a decline. This is due
to customer churn.
*/

SELECT trunc(call_time), count(connection_id) 
FROM customer_calls_fact_table
GROUP BY trunc(call_time)
ORDER BY count(connection_id) DESC;

SELECT dd.month_num AS "Month Number", dd.month_name AS "Month", count(connection_id) AS "Total Calls" 
FROM customer_calls_fact_table ccft
JOIN date_dim dd ON ccft.call_time = dd.date_long
GROUP BY dd.month_num, dd.month_name
ORDER BY count(connection_id) DESC;

/*We can determine who from our customers have not made any calls at all
in this period of time. There are 4,952 customers making calls in this
period, from a total of 4,999 customers listed. There are 47 customers
who have not made a call in this period. They have already ceased using
the service.*/

SELECT count(DISTINCT phone_number) FROM customer_calls_fact_table;

/*We can determine their phone numbers.*/

SELECT phone_number AS "Phone Number" FROM customers c
WHERE NOT EXISTS (SELECT phone_number FROM customer_calls_fact_table ccft WHERE c.phone_number = ccft.phone_number)
ORDER BY phone_number;

/*We can examine the individual customers to check the date of their
last call. This will give us a crude measure of the drop-off rate.*/

SELECT phone_number AS "Customer", max(call_time) AS "Last Call" 
FROM customer_calls_fact_table
GROUP BY phone_number
ORDER BY max(call_time);

/*We can start to put some numbers on customer churn by reference
to the contract end date. This is NULL for customers who have not cancelled
their subscription. It is NOT NULL for those that have cancelled. We can
see how many are cancelling. 458 ended their contract in January (ceasing on 
01/02), 443 ended it in February (ceasing on 01/03), 396 ended it in March 
(ceasing on 01/04), and 316 ended it in April (ceasing on 01/05). This 
represents a churn rate of 9.16% in January, 9.75% in February, 9.55% in 
March, and 8.25% in April.*/

SELECT c.contract_end_date AS "Contract End Date", count(contract_end_date) AS "Numbers Cancelling"
FROM customers c
GROUP BY contract_end_date
ORDER By count(contract_end_date) DESC;

/*END*/