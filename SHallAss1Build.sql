-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

/*DATA9910 WwD -- Assignment 1 -- Simon Hall*/

/*Data Warehouse Development or Build Script.*/

/*The data has already been imported into Oracle SQL Developer from the 
CSV files provided, and the table names have been unchanged. This SQL script 
will take the tables as privided, and transform them into the structure 
required by my chosen schema.*/ 

/*I have chosen to merge the calls, voicemails, and customer_service tables
into a single table called all_calls. This is because these three tables contain
the same sorts of information. There is little point in keeping them separate
when we can include the call_type as a column. In addition, we will want to
have all the records in the same fact table for ease of aggregate analysis.*/

/*The schema is as follows: customer_calls_fact_table (which extracts and
aggregates data from all_calls), date_dim (a date/time dimension),
customers (which has been expanded to include data on age, years since 
contract began, location, and county) and which is linked to nrs_descriptor 
(which contains more information relating to the NRS code), contract_plans 
(which is unchanged except the headers have been renamed contract_id
and contract_name, and contains information about the contract plan),
rate_types (which is unchanged except the headers have been renamed 
rate_type_id and rate_name, and contains information related to call type),
and call_rates (which is unchanged and contains information about the cost per
minute depending on both contract and call type).*/

/*It's necessary to remove one entry from the customers table, as there
are two contracts associated with one phone number. Inspection shows that
the newest contract began at a time prior to the calls data, so it's
not an issue to delete the previous record.*/ 

DELETE 
FROM customers
WHERE phone_number = '01 495 7529' AND dob = TO_DATE('24/MAR/1998','dd/mon/yyyy');

/*Add the Primary Keys*/
ALTER TABLE calls
ADD CONSTRAINT PK_calls PRIMARY KEY (connection_id);

ALTER TABLE voicemails
ADD CONSTRAINT PK_voicemails PRIMARY KEY (connection_id);

ALTER TABLE customer_service
ADD CONSTRAINT PK_cust_serv PRIMARY KEY (connection_id);

ALTER TABLE customers
ADD CONSTRAINT PK_customers PRIMARY KEY (phone_number);

ALTER TABLE contract_plans
ADD CONSTRAINT PK_contract PRIMARY KEY (contract_id);

ALTER TABLE rate_types
ADD CONSTRAINT PK_rates PRIMARY KEY (rate_type_id);

/*A composite or compound PK is required for call_rates.*/
ALTER TABLE call_rates
ADD CONSTRAINT PK_call_rates PRIMARY KEY (plan_id, call_type_id);

/*Next, we'll add call_type (also called call_type_id and rate_type_id) to 
the calls table, in preparation for merging calls, voicemails, and customer_service tables
into a single table called all_calls.*/

ALTER TABLE calls
ADD call_type INTEGER;

/*Update international call_type (3) first. This affects 24,511 rows.*/

UPDATE calls
SET call_type = 3 WHERE calls.is_international = 'TRUE';    

/*Update roaming call_type (4) next. This affects 28,859 rows.*/
  
UPDATE calls
SET call_type = 4 WHERE calls.is_roaming = 'TRUE';    

/*Update off-peak call_type (2), where the 24 hour clock is greater than
or equal to 17, or less than 9. This affects 40,715 rows.*/

UPDATE calls
SET call_type = 2 
WHERE calls.is_international = 'FALSE' 
AND calls.is_roaming = 'FALSE'
AND (to_number(to_char(call_time, 'HH24')) >= 17 OR to_number(to_char(call_time, 'HH24')) < 9);

/*Finally, update the remaining call_types as peak (1). This affects 67,499 rows.*/

UPDATE calls
SET call_type = 1 WHERE call_type IS NULL; 

/*Now, we can delete the is_international and is_roaming binary columns,
as the information is now stored in the call_type column. We also need to
have the number of columns equal in all of the tables we wish to merge.*/

ALTER TABLE calls DROP (is_international, is_roaming);

/*We can create the table all_calls by merging calls, voicemails, and 
customer_service. We can count the entries in each to ensure that
the merger is complete. There are 161,584 entries in calls, 30,046 
entries in voicemails, and 10,363 in customer service. This comes to
201,993 althogether.*/

SELECT count(*) FROM calls;
SELECT count(*) FROM voicemails;
SELECT count(*) FROM customer_service;

CREATE TABLE all_calls 
AS
SELECT connection_id, phone_number, call_time, duration, call_type 
FROM (
  SELECT connection_id, phone_number, call_time, duration, call_type FROM calls
  UNION
  SELECT connection_id, phone_number, call_time, duration, call_type_id FROM customer_service
  UNION
  SELECT connection_id, phone_number, call_time, duration, call_type_id FROM voicemails
  );

/*We can count the entries in all_calls: 201,993.*/
SELECT count(*) FROM all_calls;

/*Next, we must create a plan_id column inside all_calls in preparation for
loading the cost per minute per call.*/

ALTER TABLE all_calls
ADD plan_id INTEGER;  

/*We can populate this column using an UPDATE.*/
  
UPDATE all_calls ac
SET ac.plan_id = (SELECT c.plan_id FROM customers c WHERE ac.phone_number = c.phone_number)
WHERE EXISTS (SELECT 1 FROM customers c WHERE ac.phone_number = c.phone_number);

/*Now that all_calls contains a plan_id column and a call_type column, we
can use our call_rates table to calculate the cost per minute per call.*/

ALTER TABLE all_calls
ADD cost_per_minute NUMBER(38,2);  

UPDATE all_calls ac
SET ac.cost_per_minute = (SELECT cr.cost_per_minute FROM call_rates cr WHERE ac.plan_id = cr.plan_id AND ac.call_type = cr.call_type_id)
WHERE EXISTS (SELECT 1 FROM call_rates cr WHERE ac.plan_id = cr.plan_id AND ac.call_type = cr.call_type_id);

/*We next create the customer_calls_fact_table, using the all_calls table,
and calculating the total cost per call, rounded to two decimal places. We
must account also for the fact that the duration, as recorded in all_calls, is
in seconds.*/

CREATE TABLE customer_calls_fact_table AS
SELECT ac.connection_id, ac.phone_number, ac.call_time, ac.duration, ac.call_type, ac.plan_id, ac.cost_per_minute, ROUND(ac.duration / 60 * ac.cost_per_minute, 2) AS total_cost
FROM all_calls ac;

/*Now that the fact table has been created, we can turn our attention to
the customers table. I want to extend the table to include more detailed
information relating to each customer, including age, years since contract
began, as well as the location and county based on the phone number prefixes.*/

/*Age:*/

ALTER TABLE customers
ADD age NUMBER(5,2);

UPDATE customers
SET age = floor(MONTHS_BETWEEN(trunc(sysdate), trunc(dob))/12);

/*Years under contract:*/

ALTER TABLE customers
ADD years_under_contract NUMBER(5,2);

--Those customers with NULL contract_end_date are still active.
UPDATE customers
SET years_under_contract =  
    CASE 
        WHEN contract_end_date IS NULL THEN round(MONTHS_BETWEEN(trunc(sysdate), trunc(contract_start_date))/12,2)
        WHEN contract_end_date IS NOT NULL THEN round(MONTHS_BETWEEN(to_date(contract_end_date, 'YYYY-MM-DD'), trunc(contract_start_date))/12,2)
    END;
                          
/*Location:*/

ALTER TABLE customers
ADD location VARCHAR2(16); 

--Locations with single digit prefix (Dublin). Affects 2,535 rows:
UPDATE customers c
SET c.location = (SELECT ipc.location FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 1) = to_char(ipc.prefix))
WHERE EXISTS (SELECT 1 FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 1) = to_char(ipc.prefix));

--Locations with double digit prefixes. Affects 2,265 rows:
UPDATE customers c
SET c.location = (SELECT ipc.location FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 2) = to_char(ipc.prefix))
WHERE EXISTS (SELECT 1 FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 2) = to_char(ipc.prefix));

--Locations with triple digit prefixes. Affects the remaining 199 rows:
UPDATE customers c
SET c.location = (SELECT ipc.location FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 3) = to_char(ipc.prefix))
WHERE EXISTS (SELECT 1 FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 3) = to_char(ipc.prefix));

/*County:*/

ALTER TABLE customers
ADD county VARCHAR2(16); 

--County with single digit prefix (Dublin):
UPDATE customers c
SET c.county = (SELECT ipc.county FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 1) = to_char(ipc.prefix))
WHERE EXISTS (SELECT 1 FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 1) = to_char(ipc.prefix));

--Counties with double digit prefixes:
UPDATE customers c
SET c.county = (SELECT ipc.county FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 2) = to_char(ipc.prefix))
WHERE EXISTS (SELECT 1 FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 2) = to_char(ipc.prefix));

--Counties with triple digit prefixes:
UPDATE customers c
SET c.county = (SELECT ipc.county FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 3) = to_char(ipc.prefix))
WHERE EXISTS (SELECT 1 FROM irish_phone_codes ipc WHERE SUBSTR(c.phone_number, 2, 3) = to_char(ipc.prefix));

/*We are now in a position to add the foreign keys to our tables.*/

ALTER TABLE customer_calls_fact_table
ADD CONSTRAINT FK_call_time
FOREIGN KEY (call_time) REFERENCES date_dim(date_long);

ALTER TABLE customer_calls_fact_table
ADD CONSTRAINT FK_customers
FOREIGN KEY (phone_number) REFERENCES customers(phone_number);

ALTER TABLE customer_calls_fact_table
ADD CONSTRAINT FK_contract_plans
FOREIGN KEY (plan_id) REFERENCES contract_plans(contract_id);

ALTER TABLE customer_calls_fact_table
ADD CONSTRAINT FK_rate_types
FOREIGN KEY (call_type) REFERENCES rate_types(rate_type_id);
  
ALTER TABLE customer_calls_fact_table
ADD CONSTRAINT FK_call_rates
FOREIGN KEY(plan_id, call_type) REFERENCES call_rates(plan_id, call_type_id);  

--Add foreign key also to customers table, linking to nrs_descriptor
ALTER TABLE customers
ADD CONSTRAINT FK_nrs
FOREIGN KEY (nrs) REFERENCES nrs_descriptor(nrs);

/*END*/