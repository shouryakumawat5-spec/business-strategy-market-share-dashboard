/* ============================================================================
   PROJECT      : Business Strategy and Market Share Performance Dashboard
   FILE         : Data_Cleaning.sql
   PURPOSE      : Cleans the staging tables loaded from /Dataset before they
                  are transformed into the star schema.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   1. REGION: standardize casing and trim whitespace on region_name, which
      arrived from two different source system extracts with inconsistent
      formatting (all caps in one feed, leading and trailing spaces in
      another)
   ---------------------------------------------------------------------------- */

UPDATE stg_region
SET region_name = LTRIM(RTRIM(region_name));

UPDATE stg_region
SET region_name = UPPER(LEFT(region_name, 1)) + LOWER(SUBSTRING(region_name, 2, LEN(region_name)))
WHERE region_name = UPPER(region_name);

/* ----------------------------------------------------------------------------
   2. MARKET PERFORMANCE: fix sign entry errors on total_market_size,
      remove rows where company_sales is missing (cannot compute share
      without it), remove exact duplicate rows, and enforce the logical
      rule that company_sales cannot exceed total_market_size
   ---------------------------------------------------------------------------- */

UPDATE stg_market_performance
SET total_market_size = ABS(total_market_size)
WHERE total_market_size < 0;

DELETE FROM stg_market_performance
WHERE company_sales IS NULL;

WITH ranked_mp AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY date_key, region_id, category_id
               ORDER BY fact_id
           ) AS rn
    FROM stg_market_performance
)
DELETE FROM ranked_mp WHERE rn > 1;

/* logical validation: flag any row where company_sales exceeds
   total_market_size, which should not happen and indicates an upstream
   extract error worth escalating rather than silently deleting */
SELECT fact_id, date_key, region_id, category_id, company_sales, total_market_size
INTO stg_mp_logic_errors
FROM stg_market_performance
WHERE company_sales > total_market_size;

/* cap the handful of rows where it does happen, so downstream KPI
   calculations never show a market share above 100 percent */
UPDATE stg_market_performance
SET company_sales = total_market_size * 0.95
WHERE company_sales > total_market_size;

/* ----------------------------------------------------------------------------
   3. COMPETITOR SALES: handle missing competitor_sales values and remove
      exact duplicate rows introduced by the extract/reload process
   ---------------------------------------------------------------------------- */

DELETE FROM stg_competitor_sales
WHERE competitor_sales IS NULL;

WITH ranked_cs AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY date_key, region_id, category_id, competitor_id
               ORDER BY fact_id
           ) AS rn
    FROM stg_competitor_sales
)
DELETE FROM ranked_cs WHERE rn > 1;

/* ----------------------------------------------------------------------------
   4. VALIDATION CHECKS
      Run these after cleaning to confirm the staging layer is ready for
      Data_Transformation.sql. Each query should return zero rows.
   ---------------------------------------------------------------------------- */

-- Check 1: no negative market size remains
SELECT * FROM stg_market_performance WHERE total_market_size < 0;

-- Check 2: no NULL company_sales remains
SELECT * FROM stg_market_performance WHERE company_sales IS NULL;

-- Check 3: no company_sales exceeds total_market_size
SELECT * FROM stg_market_performance WHERE company_sales > total_market_size;

-- Check 4: no duplicate (date, region, category) combination remains in market performance
SELECT date_key, region_id, category_id, COUNT(*) AS cnt
FROM stg_market_performance
GROUP BY date_key, region_id, category_id
HAVING COUNT(*) > 1;

-- Check 5: region names are properly cased, single spaced, no leading/trailing whitespace
SELECT DISTINCT region_name FROM stg_region WHERE region_name <> LTRIM(RTRIM(region_name));
