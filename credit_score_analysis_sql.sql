-- CREDIT SCORE DATA ANALYST PROJECT (PostgreSQL)

-- TABLE SETUP
----------------------------------------------------------------
-- Create the table (run this before importing the CSV)
CREATE TABLE IF NOT EXISTS credit_score_data (
  customer_id BIGSERIAL PRIMARY KEY,
  age INT,
  gender TEXT,
  income INT,
  education TEXT,
  marital_status TEXT,
  num_children INT,
  home_ownership TEXT,
  credit_score TEXT
);

-- Quick test
SELECT * FROM credit_score_data LIMIT 10;



-- DATA CLEANING 
----------------------------------------------------------------
-- Standardize text columns (trim spaces, consistent capitalization) and replace empty values with NULL
UPDATE credit_score_data
SET
  gender         = NULLIF(INITCAP(TRIM(gender)), ''),
  education      = NULLIF(INITCAP(TRIM(education)), ''),
  marital_status = NULLIF(INITCAP(TRIM(marital_status)), ''),
  home_ownership = NULLIF(INITCAP(TRIM(home_ownership)), ''),
  credit_score   = NULLIF(INITCAP(TRIM(credit_score)), '');



-- DATA QUALITY CHECKS
----------------------------------------------------------------
-- Row count
SELECT COUNT(*) AS total_rows
FROM credit_score_data;

-- Null checks (how much missing data?)
SELECT
  SUM(CASE WHEN age IS NULL THEN 1 ELSE 0 END) AS null_age,
  SUM(CASE WHEN gender IS NULL THEN 1 ELSE 0 END) AS null_gender,
  SUM(CASE WHEN income IS NULL THEN 1 ELSE 0 END) AS null_income,
  SUM(CASE WHEN education IS NULL THEN 1 ELSE 0 END) AS null_education,
  SUM(CASE WHEN marital_status IS NULL THEN 1 ELSE 0 END) AS null_marital_status,
  SUM(CASE WHEN num_children IS NULL THEN 1 ELSE 0 END) AS null_num_children,
  SUM(CASE WHEN home_ownership IS NULL THEN 1 ELSE 0 END) AS null_home_ownership,
  SUM(CASE WHEN credit_score IS NULL THEN 1 ELSE 0 END) AS null_credit_score
FROM credit_score_data;

-- Range checks (catch impossible values)
SELECT *
FROM credit_score_data
WHERE age <= 0 OR age > 100
   OR income <= 0 OR income > 1000000
   OR num_children < 0 OR num_children > 20;

-- Confirm expected categories for credit_score
SELECT DISTINCT credit_score
FROM credit_score_data
ORDER BY 1;

-- Quick check of min/max values for numeric columns
SELECT
  MIN(age) AS min_age, MAX(age) AS max_age,
  MIN(income) AS min_income, MAX(income) AS max_income,
  MIN(num_children) AS min_children, MAX(num_children) AS max_children
FROM credit_score_data;



-- DATA EXPLORATION
----------------------------------------------------------------
-- Distribution of credit score categories (counts)
SELECT credit_score, COUNT(*) AS customers
FROM credit_score_data
GROUP BY credit_score
ORDER BY customers DESC;

-- Distribution of credit score categories (percentages)
SELECT
  credit_score,
  COUNT(*) AS customers,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM credit_score_data
GROUP BY credit_score
ORDER BY customers DESC;



-- FEATURE ENGINEERING (VIEW)
----------------------------------------------------------------
-- Create income and age groups to make analysis easier.
CREATE OR REPLACE VIEW v_credit_features AS
SELECT
  customer_id,
  age,
  gender,
  income,
  education,
  marital_status,
  num_children,
  home_ownership,
  credit_score,

  CASE
    WHEN income IS NULL THEN 'Unknown'
    WHEN income < 40000 THEN '<40k'
    WHEN income < 70000 THEN '40k-69k'
    WHEN income < 100000 THEN '70k-99k'
    ELSE '100k+'
  END AS income_band,

  CASE
    WHEN age IS NULL THEN 'Unknown'
    WHEN age < 25 THEN '<25'
    WHEN age < 35 THEN '25-34'
    WHEN age < 45 THEN '35-44'
    WHEN age < 55 THEN '45-54'
    ELSE '55+'
  END AS age_band

FROM credit_score_data;

-- Quick view check
SELECT * FROM v_credit_features LIMIT 10;



-- ANALYSIS: ANSWERING QUESTIONS
----------------------------------------------------------------
-- Q1) Which income bands have the highest % of “High” credit score?
SELECT
  income_band,
  COUNT(*) AS customers,
  ROUND(
    100.0 * SUM(CASE WHEN credit_score = 'High' THEN 1 ELSE 0 END) / COUNT(*),
    1
  ) AS pct_high
FROM v_credit_features
GROUP BY income_band
ORDER BY pct_high DESC, customers DESC;

-- Q2) Which education levels have the highest % of “High”?
SELECT
  education,
  COUNT(*) AS customers,
  ROUND(
    100.0 * SUM(CASE WHEN credit_score = 'High' THEN 1 ELSE 0 END) / COUNT(*),
    1
  ) AS pct_high
FROM v_credit_features
GROUP BY education
ORDER BY pct_high DESC, customers DESC;

-- Q3) Does credit score improve with age?
SELECT
  age_band,
  COUNT(*) AS customers,
  ROUND(100.0 * SUM(CASE WHEN credit_score='High' THEN 1 ELSE 0 END)/COUNT(*), 1) AS pct_high,
  ROUND(100.0 * SUM(CASE WHEN credit_score='Low'  THEN 1 ELSE 0 END)/COUNT(*), 1) AS pct_low
FROM v_credit_features
GROUP BY age_band
ORDER BY
  CASE age_band
    WHEN '<25' THEN 1
    WHEN '25-34' THEN 2
    WHEN '35-44' THEN 3
    WHEN '45-54' THEN 4
    WHEN '55+' THEN 5
    ELSE 6
  END;

-- Q4) Home ownership: which group has the highest % of “High”?
SELECT
  home_ownership,
  COUNT(*) AS customers,
  ROUND(
    100.0 * SUM(CASE WHEN credit_score='High' THEN 1 ELSE 0 END) / COUNT(*),
    1
  ) AS pct_high
FROM v_credit_features
GROUP BY home_ownership
ORDER BY pct_high DESC, customers DESC;

-- Q5) “Risk” view: which marital groups have the highest % of “Low”?
SELECT
  marital_status,
  COUNT(*) AS customers,
  ROUND(
    100.0 * SUM(CASE WHEN credit_score='Low' THEN 1 ELSE 0 END) / COUNT(*),
    1
  ) AS pct_low
FROM v_credit_features
GROUP BY marital_status
ORDER BY pct_low DESC, customers DESC;

-- Q6) Are there specific combinations of factors that perform better?
-- Exclude very small groups to avoid misleading results.
SELECT
  income_band,
  home_ownership,
  education,
  COUNT(*) AS customers,
  ROUND(
    100.0 * SUM(CASE WHEN credit_score='High' THEN 1 ELSE 0 END) / COUNT(*),
    1
  ) AS pct_high
FROM v_credit_features
GROUP BY income_band, home_ownership, education
HAVING COUNT(*) >= 10
ORDER BY pct_high DESC, customers DESC;

-- Q7) Does number of children relate to credit score?
SELECT
  num_children,
  COUNT(*) AS customers,
  ROUND(100.0 * SUM(CASE WHEN credit_score='High' THEN 1 ELSE 0 END)/COUNT(*), 1) AS pct_high,
  ROUND(100.0 * SUM(CASE WHEN credit_score='Low'  THEN 1 ELSE 0 END)/COUNT(*), 1) AS pct_low
FROM v_credit_features
GROUP BY num_children
ORDER BY num_children;



-- SUMMARY VIEWS (for Power BI later)
----------------------------------------------------------------

-- Summary by income_band
CREATE OR REPLACE VIEW v_summary_income AS
SELECT
  income_band,
  COUNT(*) AS customers,
  ROUND(100.0 * SUM(CASE WHEN credit_score='High' THEN 1 ELSE 0 END)/COUNT(*), 1) AS pct_high,
  ROUND(100.0 * SUM(CASE WHEN credit_score='Low'  THEN 1 ELSE 0 END)/COUNT(*), 1) AS pct_low
FROM v_credit_features
GROUP BY income_band
ORDER BY
  CASE income_band
    WHEN '<40k' THEN 1
    WHEN '40k-69k' THEN 2
    WHEN '70k-99k' THEN 3
    WHEN '100k+' THEN 4
    WHEN 'Unknown' THEN 5
    ELSE 6
  END;

-- Summary by age_band
CREATE OR REPLACE VIEW v_summary_age AS
SELECT
  age_band,
  COUNT(*) AS customers,
  ROUND(100.0 * SUM(CASE WHEN credit_score='High' THEN 1 ELSE 0 END)/COUNT(*), 1) AS pct_high,
  ROUND(100.0 * SUM(CASE WHEN credit_score='Low'  THEN 1 ELSE 0 END)/COUNT(*), 1) AS pct_low
FROM v_credit_features
GROUP BY age_band
ORDER BY
  CASE age_band
    WHEN '<25' THEN 1
    WHEN '25-34' THEN 2
    WHEN '35-44' THEN 3
    WHEN '45-54' THEN 4
    WHEN '55+' THEN 5
    WHEN 'Unknown' THEN 6
    ELSE 7
  END;
