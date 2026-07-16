/* ============================================================================
   PROJECT      : Business Strategy and Market Share Performance Dashboard
   FILE         : Data_Generation.sql (SQLite dialect)
   PURPOSE      : This is the actual script used to synthesize the raw
                  dataset shipped in /Dataset. Included for transparency.
                  It is a build utility, not part of the analytics layer.
                  Run it with any SQLite client to reproduce the dataset.
   ============================================================================ */

PRAGMA foreign_keys = OFF;

DROP TABLE IF EXISTS raw_region;
DROP TABLE IF EXISTS raw_category;
DROP TABLE IF EXISTS raw_competitor;
DROP TABLE IF EXISTS raw_date;
DROP TABLE IF EXISTS raw_market_performance;
DROP TABLE IF EXISTS raw_competitor_sales;

CREATE TABLE raw_region (region_id INTEGER, region_name TEXT, country TEXT, sub_region TEXT);
INSERT INTO raw_region VALUES
(1,'North America East','USA','Northeast'),
(2,'North America West','USA','West'),
(3,'North America Central','USA','Midwest'),
(4,'Western Europe','Germany','EU West'),
(5,'Southern Europe','Italy','EU South'),
(6,'United Kingdom','UK','UK'),
(7,'South East Asia','Singapore','APAC'),
(8,'East Asia','Japan','APAC'),
(9,'Latin America','Brazil','LATAM'),
(10,'Middle East','UAE','MEA');

CREATE TABLE raw_category (category_id INTEGER, category_name TEXT, category_group TEXT);
INSERT INTO raw_category VALUES
(1,'Premium Skincare','Personal Care'),
(2,'Mass Skincare','Personal Care'),
(3,'Hair Care','Personal Care'),
(4,'Oral Care','Personal Care'),
(5,'Packaged Snacks','Food and Beverage'),
(6,'Beverages','Food and Beverage'),
(7,'Breakfast Foods','Food and Beverage'),
(8,'Home Cleaning','Household'),
(9,'Laundry Care','Household'),
(10,'Paper Products','Household'),
(11,'Baby Care','Family Care'),
(12,'Adult Nutrition','Family Care'),
(13,'Pet Care','Family Care'),
(14,'Cosmetics','Beauty'),
(15,'Fragrances','Beauty');

CREATE TABLE raw_competitor (competitor_id INTEGER, competitor_name TEXT, competitor_tier TEXT);
INSERT INTO raw_competitor VALUES
(1,'Northbridge Consumer Group','Tier 1'),
(2,'Alderway Global Brands','Tier 1'),
(3,'Solace Household Inc','Tier 2'),
(4,'Marlow and Finch Co','Tier 2'),
(5,'Brightfield Industries','Tier 3');

CREATE TABLE raw_date (date_key INTEGER, year INTEGER, quarter INTEGER, quarter_label TEXT);
WITH RECURSIVE q(n) AS (SELECT 0 UNION ALL SELECT n+1 FROM q WHERE n < 19)
INSERT INTO raw_date
SELECT
  2021000 + n,
  2021 + n/4,
  (n % 4) + 1,
  'Q' || ((n % 4) + 1) || ' ' || (2021 + n/4)
FROM q;

CREATE TABLE raw_market_performance (
  fact_id INTEGER, date_key INTEGER, region_id INTEGER, category_id INTEGER,
  company_sales REAL, total_market_size REAL
);

WITH RECURSIVE tally(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM tally WHERE n < 3000)
INSERT INTO raw_market_performance
SELECT
  n,
  2021000 + ((n-1) % 20),
  1 + ((n-1) / 20) % 10,
  1 + ((n-1) / 200) % 15,
  0,
  0
FROM tally;

UPDATE raw_market_performance
SET total_market_size = ROUND(2000000 + (ABS(RANDOM()) % 48000000) *
  (1.0 + 0.02 * ((date_key % 2021000))), 2);

UPDATE raw_market_performance
SET company_sales = ROUND(total_market_size * (0.04 + (ABS(RANDOM()) % 32) / 100.0), 2);

-- inject a few data quality issues: negative market size typos, null company_sales, duplicate rows
UPDATE raw_market_performance SET total_market_size = -1 * total_market_size WHERE fact_id % 601 = 0;
UPDATE raw_market_performance SET company_sales = NULL WHERE fact_id % 457 = 0;
INSERT INTO raw_market_performance SELECT * FROM raw_market_performance WHERE fact_id % 900 = 0;

CREATE INDEX idx_mp_fact ON raw_market_performance(fact_id);

CREATE TABLE raw_competitor_sales (
  fact_id INTEGER, date_key INTEGER, region_id INTEGER, category_id INTEGER,
  competitor_id INTEGER, competitor_sales REAL
);

WITH RECURSIVE tally(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM tally WHERE n < 3000),
comp(c) AS (SELECT 1 UNION ALL SELECT c+1 FROM comp WHERE c < 4)
INSERT INTO raw_competitor_sales
SELECT
  ((t.n-1) * 4) + c.c,
  m.date_key,
  m.region_id,
  m.category_id,
  1 + ((c.c - 1 + (t.n % 5)) % 5),
  ROUND((m.total_market_size - m.company_sales) * (0.08 + (ABS(RANDOM()) % 20) / 100.0), 2)
FROM tally t
JOIN comp c
JOIN raw_market_performance m ON m.fact_id = t.n
WHERE m.total_market_size > 0 AND m.company_sales IS NOT NULL;

-- inject dirty data: region name casing inconsistency handled at region table level (kept clean here),
-- a few null competitor_sales and duplicate rows for cleaning practice
UPDATE raw_competitor_sales SET competitor_sales = NULL WHERE fact_id % 733 = 0;
INSERT INTO raw_competitor_sales SELECT * FROM raw_competitor_sales WHERE fact_id % 1200 = 0;

-- introduce inconsistent casing / whitespace directly into a copy used for the raw region export
CREATE TABLE raw_region_export AS SELECT * FROM raw_region;
UPDATE raw_region_export SET region_name = UPPER(region_name) WHERE region_id IN (3,7);
UPDATE raw_region_export SET region_name = '  ' || region_name || '  ' WHERE region_id IN (5,9);
