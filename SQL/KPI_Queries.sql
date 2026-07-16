/* ============================================================================
   PROJECT      : Business Strategy and Market Share Performance Dashboard
   FILE         : KPI_Queries.sql
   PURPOSE      : Business KPI queries used to power the Power BI dashboard.
   ============================================================================ */

/* 1. Market share percentage, latest year, by region and category */
SELECT
    region_name, category_name, year,
    ROUND(SUM(company_sales) / NULLIF(SUM(total_market_size), 0) * 100, 2) AS market_share_pct
FROM vw_market_share
WHERE year = (SELECT MAX(year) FROM vw_market_share)
GROUP BY region_name, category_name, year
ORDER BY market_share_pct DESC;

/* 2. Relative market share = company share / largest competitor's share */
WITH company_share AS (
    SELECT date_key, region_id, category_id, company_sales, total_market_size
    FROM fact_market_performance
),
top_comp AS (
    SELECT date_key, region_id, category_id, competitor_sales AS top_competitor_sales
    FROM vw_top_competitor
    WHERE sales_rank = 1
)
SELECT
    r.region_name, c.category_name, d.year,
    ROUND(AVG(cs.company_sales * 1.0 / NULLIF(tc.top_competitor_sales, 0)), 3) AS relative_market_share
FROM company_share cs
JOIN top_comp tc ON tc.date_key = cs.date_key AND tc.region_id = cs.region_id AND tc.category_id = cs.category_id
JOIN dim_region r    ON r.region_id = cs.region_id
JOIN dim_category c     ON c.category_id = cs.category_id
JOIN dim_date d            ON d.date_key = cs.date_key
GROUP BY r.region_name, c.category_name, d.year
ORDER BY relative_market_share DESC;

/* 3. Market growth rate, year over year, by category */
WITH yearly AS (
    SELECT category_name, year, SUM(total_market_size) AS market_size
    FROM vw_market_share
    GROUP BY category_name, year
)
SELECT
    category_name, year, market_size,
    LAG(market_size) OVER (PARTITION BY category_name ORDER BY year) AS prior_year_market_size,
    ROUND(
        (market_size - LAG(market_size) OVER (PARTITION BY category_name ORDER BY year)) * 100.0
        / NULLIF(LAG(market_size) OVER (PARTITION BY category_name ORDER BY year), 0), 2
    ) AS market_growth_pct
FROM yearly
ORDER BY category_name, year;

/* 4. Category share of wallet = company sales in category / total company sales */
SELECT
    category_name,
    SUM(company_sales)                                                              AS category_sales,
    ROUND(SUM(company_sales) * 100.0 / SUM(SUM(company_sales)) OVER (), 2)             AS share_of_wallet_pct
FROM vw_market_share
GROUP BY category_name
ORDER BY share_of_wallet_pct DESC;

/* 5. Regional share gain or loss, comparing first year to latest year */
WITH bounds AS (
    SELECT MIN(year) AS min_year, MAX(year) AS max_year FROM vw_market_share
),
share_by_region_year AS (
    SELECT region_name, year,
           SUM(company_sales) / NULLIF(SUM(total_market_size), 0) * 100 AS share_pct
    FROM vw_market_share
    GROUP BY region_name, year
)
SELECT
    a.region_name,
    a.share_pct AS share_pct_start,
    b.share_pct AS share_pct_latest,
    ROUND(b.share_pct - a.share_pct, 2) AS share_change_pct_points
FROM share_by_region_year a
JOIN share_by_region_year b ON b.region_name = a.region_name
JOIN bounds bd ON a.year = bd.min_year AND b.year = bd.max_year
ORDER BY share_change_pct_points DESC;

/* 6. Revenue growth versus market growth, by category (are we growing faster or slower than the market) */
WITH company_growth AS (
    SELECT category_name, year, SUM(company_sales) AS company_sales
    FROM vw_market_share GROUP BY category_name, year
),
market_growth AS (
    SELECT category_name, year, SUM(total_market_size) AS market_size
    FROM vw_market_share GROUP BY category_name, year
)
SELECT
    cg.category_name, cg.year,
    ROUND((cg.company_sales - LAG(cg.company_sales) OVER (PARTITION BY cg.category_name ORDER BY cg.year)) * 100.0
        / NULLIF(LAG(cg.company_sales) OVER (PARTITION BY cg.category_name ORDER BY cg.year), 0), 2) AS company_growth_pct,
    ROUND((mg.market_size - LAG(mg.market_size) OVER (PARTITION BY mg.category_name ORDER BY mg.year)) * 100.0
        / NULLIF(LAG(mg.market_size) OVER (PARTITION BY mg.category_name ORDER BY mg.year), 0), 2)   AS market_growth_pct
FROM company_growth cg
JOIN market_growth mg ON mg.category_name = cg.category_name AND mg.year = cg.year
ORDER BY cg.category_name, cg.year;

/* 7. Portfolio balance across categories, by category_group */
SELECT
    category_group,
    SUM(company_sales)                                                    AS group_sales,
    ROUND(SUM(company_sales) * 100.0 / SUM(SUM(company_sales)) OVER (), 2)   AS pct_of_total_portfolio
FROM vw_market_share
GROUP BY category_group
ORDER BY pct_of_total_portfolio DESC;

/* 8. Market attractiveness index = normalized market size rank + normalized growth rank, by category */
WITH cat_metrics AS (
    SELECT
        category_name,
        SUM(total_market_size)                                                                       AS latest_market_size,
        AVG(company_market_share_pct)                                                                    AS avg_share
    FROM vw_market_share
    WHERE year = (SELECT MAX(year) FROM vw_market_share)
    GROUP BY category_name
)
SELECT
    category_name,
    latest_market_size,
    avg_share,
    RANK() OVER (ORDER BY latest_market_size DESC) AS size_rank,
    RANK() OVER (ORDER BY avg_share ASC)             AS whitespace_rank,
    RANK() OVER (ORDER BY latest_market_size DESC) + RANK() OVER (ORDER BY avg_share ASC) AS attractiveness_score
FROM cat_metrics
ORDER BY attractiveness_score ASC;

/* 9. Top 5 regions by absolute company sales, most recent year */
SELECT TOP 5
    region_name, SUM(company_sales) AS company_sales
FROM vw_market_share
WHERE year = (SELECT MAX(year) FROM vw_market_share)
GROUP BY region_name
ORDER BY company_sales DESC;

/* 10. Competitive tier mix, share of tracked competitor sales by tier */
SELECT
    comp.competitor_tier,
    SUM(cs.competitor_sales)                                                    AS tier_sales,
    ROUND(SUM(cs.competitor_sales) * 100.0 / SUM(SUM(cs.competitor_sales)) OVER (), 2) AS pct_of_competitor_market
FROM fact_competitor_sales cs
JOIN dim_competitor comp ON comp.competitor_id = cs.competitor_id
GROUP BY comp.competitor_tier
ORDER BY tier_sales DESC;
