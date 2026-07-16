/* ============================================================================
   PROJECT      : Business Strategy and Market Share Performance Dashboard
   FILE         : Data_Transformation.sql
   PURPOSE      : Builds the clean star schema (dim_region, dim_category,
                  dim_competitor, dim_date, fact_market_performance,
                  fact_competitor_sales) from the cleaned staging tables.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   1. Dimension tables : direct load from cleaned staging tables
   ---------------------------------------------------------------------------- */

INSERT INTO dim_region (region_id, region_name, country, sub_region)
SELECT region_id, region_name, country, sub_region FROM stg_region;

INSERT INTO dim_category (category_id, category_name, category_group)
SELECT category_id, category_name, category_group FROM stg_category;

INSERT INTO dim_competitor (competitor_id, competitor_name, competitor_tier)
SELECT competitor_id, competitor_name, competitor_tier FROM stg_competitor;

INSERT INTO dim_date (date_key, year, quarter, quarter_label)
SELECT date_key, year, quarter, quarter_label FROM stg_date;

/* ----------------------------------------------------------------------------
   2. fact_market_performance and fact_competitor_sales : load, keyed on
      the same fact_id as the cleaned staging layer, joined to confirm
      referential integrity against the dimensions before insert
   ---------------------------------------------------------------------------- */

INSERT INTO fact_market_performance (fact_id, date_key, region_id, category_id, company_sales, total_market_size)
SELECT
    mp.fact_id, mp.date_key, mp.region_id, mp.category_id, mp.company_sales, mp.total_market_size
FROM stg_market_performance mp
JOIN dim_date d      ON d.date_key = mp.date_key
JOIN dim_region r     ON r.region_id = mp.region_id
JOIN dim_category c      ON c.category_id = mp.category_id;

INSERT INTO fact_competitor_sales (fact_id, date_key, region_id, category_id, competitor_id, competitor_sales)
SELECT
    cs.fact_id, cs.date_key, cs.region_id, cs.category_id, cs.competitor_id, cs.competitor_sales
FROM stg_competitor_sales cs
JOIN dim_date d          ON d.date_key = cs.date_key
JOIN dim_region r         ON r.region_id = cs.region_id
JOIN dim_category c          ON c.category_id = cs.category_id
JOIN dim_competitor comp        ON comp.competitor_id = cs.competitor_id;

/* ----------------------------------------------------------------------------
   3. VIEW: market share by period, region and category, combining company
      sales with the sum of tracked competitor sales, used as the base
      layer for every market share KPI and Power BI visual
   ---------------------------------------------------------------------------- */

CREATE OR ALTER VIEW vw_market_share AS
SELECT
    mp.fact_id,
    d.date_key,
    d.year,
    d.quarter,
    d.quarter_label,
    r.region_id,
    r.region_name,
    r.sub_region,
    cat.category_id,
    cat.category_name,
    cat.category_group,
    mp.company_sales,
    mp.total_market_size,
    ROUND(mp.company_sales / NULLIF(mp.total_market_size, 0) * 100, 2)                        AS company_market_share_pct,
    (SELECT SUM(cs.competitor_sales)
       FROM fact_competitor_sales cs
      WHERE cs.date_key = mp.date_key AND cs.region_id = mp.region_id AND cs.category_id = mp.category_id) AS total_tracked_competitor_sales
FROM fact_market_performance mp
JOIN dim_date d      ON d.date_key = mp.date_key
JOIN dim_region r     ON r.region_id = mp.region_id
JOIN dim_category cat    ON cat.category_id = mp.category_id;

/* ----------------------------------------------------------------------------
   4. VIEW: top competitor by period, region and category, for use in
      relative market share calculations
   ---------------------------------------------------------------------------- */

CREATE OR ALTER VIEW vw_top_competitor AS
SELECT
    cs.date_key,
    cs.region_id,
    cs.category_id,
    comp.competitor_id,
    comp.competitor_name,
    cs.competitor_sales,
    RANK() OVER (
        PARTITION BY cs.date_key, cs.region_id, cs.category_id
        ORDER BY cs.competitor_sales DESC
    ) AS sales_rank
FROM fact_competitor_sales cs
JOIN dim_competitor comp ON comp.competitor_id = cs.competitor_id;
