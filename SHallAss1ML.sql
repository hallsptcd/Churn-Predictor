-- !preview conn=DBI::dbConnect(RSQLite::SQLite())

/*DATA9910 WwD -- Assignment 1 -- Simon Hall*/

/*Machine Learning Development Script.*/

/*The correct grain for this phase of the project is monthly data for each
customer. This comes naturally from our research question. Ultimately, we
want to predict the churn probability per customer per month.*/

/*Let's first create a more suitable fact table to serve as the basis
of the Machine Learning phase of this project. We must choose the original
fact table as our source as it has the finest grain. We can simply aggregate
rows in this table to suit our grain for Machine Learning.*/

CREATE TABLE monthly_churn_fact_table
AS SELECT * FROM customer_calls_fact_table;

/*However, we will need to augment this table so that we're in a position
to create a view which aggregates everything correctly.*/

/*Add a month number for each original call.*/
ALTER TABLE monthly_churn_fact_table
ADD month_num NUMBER(2);

/*Add the contract end date to the fact table.*/
ALTER TABLE monthly_churn_fact_table
ADD contract_end_date VARCHAR2(10);

/*Update the contract end date values.*/
UPDATE monthly_churn_fact_table mcft
SET mcft.contract_end_date = (SELECT c.contract_end_date FROM customers c WHERE mcft.phone_number = c.phone_number)
WHERE EXISTS (SELECT 1 FROM customers c WHERE mcft.phone_number = c.phone_number);

UPDATE monthly_churn_fact_table
SET month_num = to_number(to_char(call_time, 'FMMM'));

/*Add a new 'churned' attribute, a binary variable which will be 1 if the
customer who made that call churned that same month, and 0 otherwise.*/

ALTER TABLE monthly_churn_fact_table
ADD churned NUMBER(1);

/*Fill in the churned value for each customer in each month. It's 0
if the contract end date is NULL. It's 1 when both the contract end
date is NOT NULL and the customer ended their contract in the same
month as the call in question.*/

UPDATE monthly_churn_fact_table
SET churned =  
CASE 
  WHEN contract_end_date IS NULL THEN 0
  WHEN contract_end_date IS NOT NULL AND month_num = to_number(SUBSTR(contract_end_date, 6, 2)) - 1 THEN 1
END;

/*It's also 0 if the contract end date is NOT NULL but the customer ended 
their contract in a different month to the call in question.*/

UPDATE monthly_churn_fact_table
SET churned = 0
WHERE churned IS NULL;

/*Add made_international, made_roaming, and made_custserv attributes, 
all binary variables which are 1 if the customer made the relevant call
type in the same month as the call in the fact table, otherwise it's 0.*/

ALTER TABLE monthly_churn_fact_table
ADD made_international NUMBER(1);

ALTER TABLE monthly_churn_fact_table
ADD made_roaming NUMBER(1);

ALTER TABLE monthly_churn_fact_table
ADD made_custserv NUMBER(1);

/*Update the made_custserv attribute.*/

UPDATE monthly_churn_fact_table mcft
SET mcft.made_custserv = 1 WHERE phone_number IN (SELECT phone_number FROM customer_service);

/*Update the made_custserv attribute.*/

CREATE VIEW cs_jan AS
SELECT cs.phone_number 
FROM customer_service cs
WHERE to_number(to_char(call_time, 'FMMM')) = 1;

CREATE VIEW cs_feb AS
SELECT cs.phone_number 
FROM customer_service cs
WHERE to_number(to_char(call_time, 'FMMM')) = 2;

CREATE VIEW cs_mar AS
SELECT cs.phone_number 
FROM customer_service cs
WHERE to_number(to_char(call_time, 'FMMM')) = 3;

CREATE VIEW cs_apr AS
SELECT cs.phone_number 
FROM customer_service cs
WHERE to_number(to_char(call_time, 'FMMM')) = 4;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_custserv = 1 WHERE phone_number IN (SELECT phone_number FROM cs_jan) AND month_num = 1;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_custserv = 1 WHERE phone_number IN (SELECT phone_number FROM cs_feb) AND month_num = 2;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_custserv = 1 WHERE phone_number IN (SELECT phone_number FROM cs_mar) AND month_num = 3;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_custserv = 1 WHERE phone_number IN (SELECT phone_number FROM cs_apr) AND month_num = 4;

UPDATE monthly_churn_fact_table
SET made_custserv = 0
WHERE made_custserv IS NULL;

/*Update the made_roaming attribute.*/

CREATE VIEW ro_jan AS
SELECT ac.phone_number 
FROM all_calls ac
WHERE to_number(to_char(call_time, 'FMMM')) = 1
AND call_type = 4;

CREATE VIEW ro_feb AS
SELECT ac.phone_number 
FROM all_calls ac
WHERE to_number(to_char(call_time, 'FMMM')) = 2
AND call_type = 4;

CREATE VIEW ro_mar AS
SELECT ac.phone_number 
FROM all_calls ac
WHERE to_number(to_char(call_time, 'FMMM')) = 3
AND call_type = 4;

CREATE VIEW ro_apr AS
SELECT ac.phone_number 
FROM all_calls ac
WHERE to_number(to_char(call_time, 'FMMM')) = 4
AND call_type = 4;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_roaming = 1 WHERE mcft.phone_number IN (SELECT phone_number FROM ro_jan) AND mcft.month_num = 1;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_roaming = 1 WHERE mcft.phone_number IN (SELECT phone_number FROM ro_feb) AND mcft.month_num = 2;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_roaming = 1 WHERE mcft.phone_number IN (SELECT phone_number FROM ro_mar) AND mcft.month_num = 3;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_roaming = 1 WHERE mcft.phone_number IN (SELECT phone_number FROM ro_apr) AND mcft.month_num = 4;

UPDATE monthly_churn_fact_table
SET made_roaming = 0
WHERE made_roaming IS NULL;

/*Update made_international attribute.*/

CREATE VIEW in_jan AS
SELECT ac.phone_number 
FROM all_calls ac
WHERE to_number(to_char(call_time, 'FMMM')) = 1
AND call_type = 3;

CREATE VIEW in_feb AS
SELECT ac.phone_number 
FROM all_calls ac
WHERE to_number(to_char(call_time, 'FMMM')) = 2
AND call_type = 3;

CREATE VIEW in_mar AS
SELECT ac.phone_number 
FROM all_calls ac
WHERE to_number(to_char(call_time, 'FMMM')) = 3
AND call_type = 3;

CREATE VIEW in_apr AS
SELECT ac.phone_number 
FROM all_calls ac
WHERE to_number(to_char(call_time, 'FMMM')) = 4
AND call_type = 3;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_international = 1 WHERE mcft.phone_number IN (SELECT phone_number FROM in_jan) AND mcft.month_num = 1;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_international = 1 WHERE mcft.phone_number IN (SELECT phone_number FROM in_feb) AND mcft.month_num = 2;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_international = 1 WHERE mcft.phone_number IN (SELECT phone_number FROM in_mar) AND mcft.month_num = 3;

UPDATE monthly_churn_fact_table mcft
SET mcft.made_international = 1 WHERE mcft.phone_number IN (SELECT phone_number FROM in_apr) AND mcft.month_num = 4;

UPDATE monthly_churn_fact_table
SET made_international = 0
WHERE made_international IS NULL;

/*Re-calculate the years under contract to account for time until contract
end date, where it exists.*/

ALTER TABLE monthly_churn_fact_table
ADD contract_start_date DATE;

ALTER TABLE monthly_churn_fact_table
ADD years_under_contract NUMBER(5,2);

UPDATE monthly_churn_fact_table mcft
SET mcft.contract_start_date = (SELECT c.contract_start_date FROM customers c WHERE mcft.phone_number = c.phone_number)
WHERE EXISTS (SELECT 1 FROM customers c WHERE mcft.phone_number = c.phone_number);

UPDATE monthly_churn_fact_table
SET years_under_contract = 
CASE 
    WHEN contract_end_date IS NOT NULL AND to_number(SUBSTR(contract_end_date, 6, 2)) - 1 = 1 THEN round(MONTHS_BETWEEN(to_date('2021/02/01', 'yyyy/mm/dd'), trunc(contract_start_date))/12,2)
    WHEN contract_end_date IS NOT NULL AND to_number(SUBSTR(contract_end_date, 6, 2)) - 1 = 2 THEN round(MONTHS_BETWEEN(to_date('2021/03/01', 'yyyy/mm/dd'), trunc(contract_start_date))/12,2)
    WHEN contract_end_date IS NOT NULL AND to_number(SUBSTR(contract_end_date, 6, 2)) - 1 = 3 THEN round(MONTHS_BETWEEN(to_date('2021/04/01', 'yyyy/mm/dd'), trunc(contract_start_date))/12,2)
    WHEN contract_end_date IS NOT NULL AND to_number(SUBSTR(contract_end_date, 6, 2)) - 1 = 4 THEN round(MONTHS_BETWEEN(to_date('2021/05/01', 'yyyy/mm/dd'), trunc(contract_start_date))/12,2)
    WHEN contract_end_date IS NULL THEN round(MONTHS_BETWEEN(trunc(sysdate), trunc(contract_start_date))/12,2)
END;

/*Finally, create the desired view for Machine Learning, complete with
a unique column called case_id, built from concatenating the phone number
with the month number in question.*/ 

CREATE OR REPLACE VIEW monthly_churn_case_table AS
SELECT mcft.phone_number||mcft.month_num AS case_id, mcft.phone_number, mcft.month_num, sum(mcft.total_cost) AS cost_per_month, count(mcft.connection_id) AS total_calls, mcft.plan_id, c.nrs, c.age, c.county, mcft.years_under_contract, mcft.made_custserv, mcft.made_roaming, mcft.made_international, mcft.churned
FROM monthly_churn_fact_table mcft
INNER JOIN customers c ON mcft.phone_number = c.phone_number
GROUP BY mcft.phone_number, mcft.month_num, mcft.plan_id, c.nrs, c.age, c.county, mcft.years_under_contract, mcft.made_custserv, mcft.made_roaming, mcft.made_international, mcft.churned
ORDER BY mcft.month_num;

SELECT * FROM monthly_churn_case_table;

/*Prior to the Machine Learning phase, we need to split the data into a training 
set and a testing set. We can do this using the ORA_HASH() function.*/ 

SELECT COUNT(*) FROM monthly_churn_case_table;

--We'll take 20% as our test sample.
CREATE TABLE churn_test_sample
AS (SELECT * FROM monthly_churn_case_table WHERE ORA_HASH(case_id, 99, 0) <= 20);

CREATE TABLE churn_training_sample
AS (SELECT * FROM monthly_churn_case_table);

--We need to delete the records contained in the testing set.
DELETE
FROM churn_training_sample
WHERE case_id IN (SELECT case_id FROM churn_test_sample);

/*Create a view from the churn_test_sample, containing just the case_id
and the churned column.*/
CREATE OR REPLACE VIEW target_view AS
SELECT case_id, churned FROM churn_test_sample;

/*Now, we are in a position to build our models.*/

/*The first model is a Decision Tree.*/

/*We first create a settings table for this model.*/

CREATE TABLE churn_decision_tree_settings (
setting_name varchar2(30),
setting_value varchar2(30)
);

/

/*Next, we populate the settings table.*/

BEGIN 
    INSERT INTO churn_decision_tree_settings (setting_name, setting_value)
    VALUES (dbms_data_mining.algo_name, dbms_data_mining.algo_decision_tree);

    INSERT INTO churn_decision_tree_settings (setting_name, setting_value)
    VALUES (dbms_data_mining.prep_auto, dbms_data_mining.prep_auto_on);
  COMMIT;
END;

/

/*Next, we create the model.*/

BEGIN
  DBMS_DATA_MINING.CREATE_MODEL(
    model_name          => 'customer_churn_decision_tree',
    mining_function     => dbms_data_mining.classification,
    data_table_name     => 'churn_training_sample',
    case_id_column_name => 'CASE_ID',
    target_column_name  => 'CHURNED',
    settings_table_name => 'churn_decision_tree_settings'
    );
END;

/

SELECT * FROM all_mining_models;

SELECT * FROM all_mining_model_settings;

SELECT * FROM user_mining_model_attributes;

/

/*If we need to delete a model, use this:*/
--BEGIN
--DBMS_DATA_MINING.DROP_MODEL (model_name => 'customer_churn_decision_tree');
--END;

/

/*These queries are useful.*/

SELECT setting_name,
   setting_value,
   setting_type
FROM user_mining_model_settings
WHERE model_name in 'CUSTOMER_CHURN_DECISION_TREE';

SELECT attribute_name,
   attribute_type,
   usage_type,
   target
from all_mining_model_attributes
where model_name = 'CUSTOMER_CHURN_DECISION_TREE';

/

/*Next, we can create a view to hold the predictions of the model
when applied to the test set.*/

CREATE OR REPLACE VIEW decision_tree_test_result AS
SELECT case_id, 
PREDICTION(customer_churn_decision_tree using *) "PREDICTION", 
PREDICTION_PROBABILITY(customer_churn_decision_tree using *) "PROBABILITY" 
FROM churn_test_sample;

/

/*Finally, we can generate the confusion matrix.*/

SET SERVEROUTPUT ON;
DECLARE
   v_accuracy NUMBER;
BEGIN
        DBMS_DATA_MINING.COMPUTE_CONFUSION_MATRIX (
                   accuracy                     => v_accuracy,
                   apply_result_table_name      => 'decision_tree_test_result',
                   target_table_name            => 'target_view',
                   case_id_column_name          => 'case_id',
                   target_column_name           => 'churned',
                   confusion_matrix_table_name  => 'churn_model_confusion_matrix',
                   score_column_name            => 'Prediction',
                   score_criterion_column_name  => 'Probability',
                   cost_matrix_table_name       =>  null,
                   apply_result_schema_name     =>  null,
                   target_schema_name           =>  null,
                   cost_matrix_schema_name      =>  null,
                   score_criterion_type         => 'PROBABILITY');
        DBMS_OUTPUT.PUT_LINE('**** MODEL ACCURACY: ****' || ROUND(v_accuracy,4));
END;

/

/*Our next model is a Naive Bayes.*/

BEGIN
  DBMS_DATA_MINING.CREATE_MODEL(
    model_name          => 'customer_churn_naive_bayes',
    mining_function     => dbms_data_mining.classification,
    data_table_name     => 'churn_training_sample',
    case_id_column_name => 'CASE_ID',
    target_column_name  => 'CHURNED',
    settings_table_name => NULL
    );
END;

/

/*Next, we can create a view to hold the predictions of the model
when applied to the test set.*/

CREATE OR REPLACE VIEW naive_bayes_test_result AS
SELECT case_id, 
PREDICTION(customer_churn_naive_bayes using *) "PREDICTION", 
PREDICTION_PROBABILITY(customer_churn_naive_bayes using *) "PROBABILITY" 
FROM churn_test_sample;

/

/*Finally, we generate the confusion matrix.*/

SET SERVEROUTPUT ON;
DECLARE
   v_accuracy NUMBER;
BEGIN
        DBMS_DATA_MINING.COMPUTE_CONFUSION_MATRIX (
                   accuracy                     => v_accuracy,
                   apply_result_table_name      => 'naive_bayes_test_result',
                   target_table_name            => 'target_view',
                   case_id_column_name          => 'case_id',
                   target_column_name           => 'churned',
                   confusion_matrix_table_name  => 'naive_bayes_confusion_matrix',
                   score_column_name            => 'Prediction',
                   score_criterion_column_name  => 'Probability',
                   cost_matrix_table_name       =>  null,
                   apply_result_schema_name     =>  null,
                   target_schema_name           =>  null,
                   cost_matrix_schema_name      =>  null,
                   score_criterion_type         => 'PROBABILITY');
        DBMS_OUTPUT.PUT_LINE('**** MODEL ACCURACY: ****' || ROUND(v_accuracy,4));
END;

/


/*Our final model is a Random Forest.*/

/*First, we create the settings table.*/

CREATE TABLE churn_random_forest_settings (
setting_name varchar2(30),
setting_value varchar2(30)
);

/

/*Next, we insert the requirements.*/

BEGIN 
    INSERT INTO churn_random_forest_settings (setting_name, setting_value)
    VALUES (dbms_data_mining.algo_name, dbms_data_mining.algo_random_forest);

    INSERT INTO churn_random_forest_settings (setting_name, setting_value)
    VALUES (dbms_data_mining.prep_auto, dbms_data_mining.prep_auto_on);
  COMMIT;
END;

/

/*Next, we create the model.*/

BEGIN
  DBMS_DATA_MINING.CREATE_MODEL(
    model_name          => 'customer_churn_random_forest',
    mining_function     => dbms_data_mining.classification,
    data_table_name     => 'churn_training_sample',
    case_id_column_name => 'CASE_ID',
    target_column_name  => 'CHURNED',
    settings_table_name => 'churn_random_forest_settings'
    );
END;

/

/*Next, we can create a view to hold the predictions of the model
when applied to the test set.*/

CREATE OR REPLACE VIEW random_forest_test_result AS
SELECT case_id, 
PREDICTION(customer_churn_random_forest using *) "PREDICTION", 
PREDICTION_PROBABILITY(customer_churn_random_forest using *) "PROBABILITY" 
FROM churn_test_sample;

/

/*Lastly, we generate the confusion matrix.*/

SET SERVEROUTPUT ON;
DECLARE
   v_accuracy NUMBER;
BEGIN
        DBMS_DATA_MINING.COMPUTE_CONFUSION_MATRIX (
                   accuracy                     => v_accuracy,
                   apply_result_table_name      => 'random_forest_test_result',
                   target_table_name            => 'target_view',
                   case_id_column_name          => 'case_id',
                   target_column_name           => 'churned',
                   confusion_matrix_table_name  => 'random_forest_confusion_matrix',
                   score_column_name            => 'Prediction',
                   score_criterion_column_name  => 'Probability',
                   cost_matrix_table_name       =>  null,
                   apply_result_schema_name     =>  null,
                   target_schema_name           =>  null,
                   cost_matrix_schema_name      =>  null,
                   score_criterion_type         => 'PROBABILITY');
        DBMS_OUTPUT.PUT_LINE('**** MODEL ACCURACY: ****' || ROUND(v_accuracy,4));
END;

/

/*Finally, we can write PL/SQL script to output the accuracy of each
of our models.*/

SET SERVEROUTPUT ON;
DECLARE
decision_tree_total NUMBER;
decision_tree_oo NUMBER;
decision_tree_ii NUMBER;
decision_tree_accuracy NUMBER;
naive_bayes_total NUMBER;
naive_bayes_oo NUMBER;
naive_bayes_ii NUMBER;
naive_bayes_accuracy NUMBER;
random_forest_total NUMBER;
random_forest_oo NUMBER;
random_forest_ii NUMBER;
random_forest_accuracy NUMBER;
BEGIN
SELECT sum(cmcm.value) INTO decision_tree_total FROM churn_model_confusion_matrix cmcm;
SELECT cmcm.value INTO decision_tree_oo FROM churn_model_confusion_matrix cmcm WHERE actual_target_value = 0 AND predicted_target_value = 0;
SELECT cmcm.value INTO decision_tree_ii FROM churn_model_confusion_matrix cmcm WHERE actual_target_value = 1 AND predicted_target_value = 1;
decision_tree_accuracy := (decision_tree_oo + decision_tree_ii) / decision_tree_total;
DBMS_OUTPUT.PUT_LINE('********** DECISION TREE MODEL ACCURACY:' || ROUND(decision_tree_accuracy,4));
SELECT sum(nbcm.value) INTO naive_bayes_total FROM naive_bayes_confusion_matrix nbcm;
SELECT nbcm.value INTO naive_bayes_oo FROM naive_bayes_confusion_matrix nbcm WHERE actual_target_value = 0 AND predicted_target_value = 0;
SELECT nbcm.value INTO naive_bayes_ii FROM naive_bayes_confusion_matrix nbcm WHERE actual_target_value = 1 AND predicted_target_value = 1;
naive_bayes_accuracy := (naive_bayes_oo + naive_bayes_ii) / naive_bayes_total;
DBMS_OUTPUT.PUT_LINE('********** NAIVE BAYES MODEL ACCURACY:' || ROUND(naive_bayes_accuracy,4));
SELECT sum(rfcm.value) INTO random_forest_total FROM random_forest_confusion_matrix rfcm;
SELECT rfcm.value INTO random_forest_oo FROM random_forest_confusion_matrix rfcm WHERE actual_target_value = 0 AND predicted_target_value = 0;
SELECT rfcm.value INTO random_forest_ii FROM random_forest_confusion_matrix rfcm WHERE actual_target_value = 1 AND predicted_target_value = 1;
random_forest_accuracy := (random_forest_oo + random_forest_ii) / random_forest_total;
DBMS_OUTPUT.PUT_LINE('********** RANDOM FOREST MODEL ACCURACY:' || ROUND(random_forest_accuracy,4));
END;

/

/*We can try undersampling our data.*/

CREATE TABLE new_test AS
(SELECT * FROM churn_test_sample);

CREATE TABLE new_training AS
(SELECT * FROM churn_training_sample);

/*Delete about 80% of the non-churning customers to even out the data set.*/ 

DELETE
FROM new_training
WHERE ORA_HASH(case_id, 99, 0) <=80 AND churned = 0;

/*Create a 2nd Decision Tree model.*/

CREATE TABLE decision_tree_2_settings (
setting_name varchar2(30),
setting_value varchar2(30)
);

/

BEGIN 
    INSERT INTO decision_tree_2_settings (setting_name, setting_value)
    VALUES (dbms_data_mining.algo_name, dbms_data_mining.algo_decision_tree);

    INSERT INTO decision_tree_2_settings (setting_name, setting_value)
    VALUES (dbms_data_mining.prep_auto, dbms_data_mining.prep_auto_on);
  COMMIT;
END;

/

BEGIN  
DBMS_DATA_MINING.CREATE_MODEL(
    model_name          => 'decision_tree_2',
    mining_function     => dbms_data_mining.classification,
    data_table_name     => 'new_training',
    case_id_column_name => 'CASE_ID',
    target_column_name  => 'CHURNED',
    settings_table_name => 'decision_tree_2_settings'
    );
END;

/

CREATE OR REPLACE VIEW decision_tree_2_test_result AS
SELECT case_id, 
PREDICTION(decision_tree_2 using *) "PREDICTION", 
PREDICTION_PROBABILITY(decision_tree_2 using *) "PROBABILITY" 
FROM new_test;

/

SET SERVEROUTPUT ON;
DECLARE
   v_accuracy NUMBER;
BEGIN
        DBMS_DATA_MINING.COMPUTE_CONFUSION_MATRIX (
                   accuracy                     => v_accuracy,
                   apply_result_table_name      => 'decision_tree_2_test_result',
                   target_table_name            => 'target_view',
                   case_id_column_name          => 'case_id',
                   target_column_name           => 'churned',
                   confusion_matrix_table_name  => 'dt_2_confusion_matrix',
                   score_column_name            => 'Prediction',
                   score_criterion_column_name  => 'Probability',
                   cost_matrix_table_name       =>  null,
                   apply_result_schema_name     =>  null,
                   target_schema_name           =>  null,
                   cost_matrix_schema_name      =>  null,
                   score_criterion_type         => 'PROBABILITY');
        DBMS_OUTPUT.PUT_LINE('**** MODEL ACCURACY: ****' || ROUND(v_accuracy,4));
END;

/

/*Create a second Naive Bayes model.*/

BEGIN
  DBMS_DATA_MINING.CREATE_MODEL(
    model_name          => 'naive_bayes_2',
    mining_function     => dbms_data_mining.classification,
    data_table_name     => 'new_training',
    case_id_column_name => 'CASE_ID',
    target_column_name  => 'CHURNED',
    settings_table_name => NULL
    );
END;

/

CREATE OR REPLACE VIEW naive_bayes_2_test_result AS
SELECT case_id, 
PREDICTION(naive_bayes_2 using *) "PREDICTION", 
PREDICTION_PROBABILITY(naive_bayes_2 using *) "PROBABILITY" 
FROM new_test;

/

SET SERVEROUTPUT ON;
DECLARE
   v_accuracy NUMBER;
BEGIN
        DBMS_DATA_MINING.COMPUTE_CONFUSION_MATRIX (
                   accuracy                     => v_accuracy,
                   apply_result_table_name      => 'naive_bayes_2_test_result',
                   target_table_name            => 'target_view',
                   case_id_column_name          => 'case_id',
                   target_column_name           => 'churned',
                   confusion_matrix_table_name  => 'nb_2_confusion_matrix',
                   score_column_name            => 'Prediction',
                   score_criterion_column_name  => 'Probability',
                   cost_matrix_table_name       =>  null,
                   apply_result_schema_name     =>  null,
                   target_schema_name           =>  null,
                   cost_matrix_schema_name      =>  null,
                   score_criterion_type         => 'PROBABILITY');
        DBMS_OUTPUT.PUT_LINE('**** MODEL ACCURACY: ****' || ROUND(v_accuracy,4));
END;

/

/*Create a second Random Forest model.*/

CREATE TABLE random_forest_2_settings (
setting_name varchar2(30),
setting_value varchar2(30)
);

/

BEGIN 
    INSERT INTO random_forest_2_settings (setting_name, setting_value)
    VALUES (dbms_data_mining.algo_name, dbms_data_mining.algo_random_forest);

    INSERT INTO random_forest_2_settings (setting_name, setting_value)
    VALUES (dbms_data_mining.prep_auto, dbms_data_mining.prep_auto_on);
  COMMIT;
END;

/

BEGIN
  DBMS_DATA_MINING.CREATE_MODEL(
    model_name          => 'random_forest_2',
    mining_function     => dbms_data_mining.classification,
    data_table_name     => 'new_training',
    case_id_column_name => 'CASE_ID',
    target_column_name  => 'CHURNED',
    settings_table_name => 'random_forest_2_settings'
    );
END;

/

CREATE OR REPLACE VIEW random_forest_2_test_result AS
SELECT case_id, 
PREDICTION(random_forest_2 using *) "PREDICTION", 
PREDICTION_PROBABILITY(random_forest_2 using *) "PROBABILITY" 
FROM new_test;

/

SET SERVEROUTPUT ON;
DECLARE
   v_accuracy NUMBER;
BEGIN
        DBMS_DATA_MINING.COMPUTE_CONFUSION_MATRIX (
                   accuracy                     => v_accuracy,
                   apply_result_table_name      => 'random_forest_2_test_result',
                   target_table_name            => 'target_view',
                   case_id_column_name          => 'case_id',
                   target_column_name           => 'churned',
                   confusion_matrix_table_name  => 'rf_2_confusion_matrix',
                   score_column_name            => 'Prediction',
                   score_criterion_column_name  => 'Probability',
                   cost_matrix_table_name       =>  null,
                   apply_result_schema_name     =>  null,
                   target_schema_name           =>  null,
                   cost_matrix_schema_name      =>  null,
                   score_criterion_type         => 'PROBABILITY');
        DBMS_OUTPUT.PUT_LINE('**** MODEL ACCURACY: ****' || ROUND(v_accuracy,4));
END;

/

/*Finally, we can write a new PL/SQL script to output the accuracies of the new model.*/

SET SERVEROUTPUT ON;
DECLARE
decision_tree_2_total NUMBER;
decision_tree_2_oo NUMBER;
decision_tree_2_ii NUMBER;
decision_tree_2_accuracy NUMBER;
naive_bayes_2_total NUMBER;
naive_bayes_2_oo NUMBER;
naive_bayes_2_ii NUMBER;
naive_bayes_2_accuracy NUMBER;
random_forest_2_total NUMBER;
random_forest_2_oo NUMBER;
random_forest_2_ii NUMBER;
random_forest_2_accuracy NUMBER;
BEGIN
SELECT sum(cmcm.value) INTO decision_tree_2_total FROM dt_2_confusion_matrix cmcm;
SELECT cmcm.value INTO decision_tree_2_oo FROM dt_2_confusion_matrix cmcm WHERE actual_target_value = 0 AND predicted_target_value = 0;
SELECT cmcm.value INTO decision_tree_2_ii FROM dt_2_confusion_matrix cmcm WHERE actual_target_value = 1 AND predicted_target_value = 1;
decision_tree_2_accuracy := (decision_tree_2_oo + decision_tree_2_ii) / decision_tree_2_total;
DBMS_OUTPUT.PUT_LINE('********** DECISION TREE 2nd MODEL ACCURACY:' || ROUND(decision_tree_2_accuracy,4));
SELECT sum(nbcm.value) INTO naive_bayes_2_total FROM nb_2_confusion_matrix nbcm;
SELECT nbcm.value INTO naive_bayes_2_oo FROM nb_2_confusion_matrix nbcm WHERE actual_target_value = 0 AND predicted_target_value = 0;
SELECT nbcm.value INTO naive_bayes_2_ii FROM nb_2_confusion_matrix nbcm WHERE actual_target_value = 1 AND predicted_target_value = 1;
naive_bayes_2_accuracy := (naive_bayes_2_oo + naive_bayes_2_ii) / naive_bayes_2_total;
DBMS_OUTPUT.PUT_LINE('********** NAIVE BAYES 2nd MODEL ACCURACY:' || ROUND(naive_bayes_2_accuracy,4));
SELECT sum(rfcm.value) INTO random_forest_2_total FROM rf_2_confusion_matrix rfcm;
SELECT rfcm.value INTO random_forest_2_oo FROM rf_2_confusion_matrix rfcm WHERE actual_target_value = 0 AND predicted_target_value = 0;
SELECT rfcm.value INTO random_forest_2_ii FROM rf_2_confusion_matrix rfcm WHERE actual_target_value = 1 AND predicted_target_value = 1;
random_forest_2_accuracy := (random_forest_2_oo + random_forest_2_ii) / random_forest_2_total;
DBMS_OUTPUT.PUT_LINE('********** RANDOM FOREST 2nd MODEL ACCURACY:' || ROUND(random_forest_2_accuracy,4));
END;

/

/*END*/