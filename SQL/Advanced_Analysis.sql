/* ============================================================================
   PROJECT      : Business Strategy and Market Share Performance Dashboard
   FILE         : Advanced_Analysis.sql
   PURPOSE      : Demonstrates advanced SQL: window functions, ranking, a
                  BCG style growth share matrix, competitor rank retention
                  over time, a whitespace opportunity funnel, a stored
                  procedure, a reusable view, and temp table staging.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   1. WINDOW FUNCTIONS: rank regions by market share within each category,
      and compute each region's percentile position
   ---------------------------------------------------------------------------- */

WITH region_share AS (
    SELECT
        category_name,
        region_name,
        AVG(company_market_share_pct) AS avg_share
    FROM vw_market_share
    WHERE year = (SELECT MAX(year) FROM vw_market_share)
    GROUP BY category_name, region_name
)
SELECT
    category_name,
    region_name,
    avg_share,
    RANK() OVER (PARTITION BY category_name ORDER BY avg_share DESC)   AS share_rank,
    NTILE(4) OVER (PARTITION BY category_name ORDER BY avg_share DESC) AS share_quartile
FROM region_share
ORDER BY category_name, share_rank;

/* ----------------------------------------------------------------------------
   2. TIME SERIES: quarter over quarter market share change with a rolling
      four quarter moving average, using window functions
   ---------------------------------------------------------------------------- */

WITH quarterly AS (
    SELECT
        category_name,
        year,
        quarter,
        quarter_label,
        SUM(company_sales) / NULLIF(SUM(total_market_size), 0) * 100 AS share_pct
    FROM vw_market_share
    GROUP BY category_name, year, quarter, quarter_label
)
SELECT
    category_name,
    quarter_label,
    ROUND(share_pct, 2) AS share_pct,
    ROUND(share_pct - LAG(share_pct) OVER (PARTITION BY category_name ORDER BY year, quarter), 2) AS qoq_change_pct_points,
    ROUND(AVG(share_pct) OVER (
        PARTITION BY category_name ORDER BY year, quarter ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_4q_avg_share_pct
FROM quarterly
ORDER BY category_name, year, quarter;

/* ----------------------------------------------------------------------------
   3. BCG STYLE GROWTH SHARE MATRIX (a Bain signature framework):
      classify each category into Star, Cash Cow, Question Mark, or Dog
      based on relative market share and market growth rate
   ---------------------------------------------------------------------------- */

WITH cat_growth AS (
    SELECT
        category_name,
        year,
        SUM(total_market_size) AS market_size
    FROM vw_market_share
    GROUP BY category_name, year
),
growth_calc AS (
    SELECT
        category_name,
        year,
        market_size,
        (market_size - LAG(market_size) OVER (PARTITION BY category_name ORDER BY year)) * 100.0
            / NULLIF(LAG(market_size) OVER (PARTITION BY category_name ORDER BY year), 0) AS growth_pct
    FROM cat_growth
),
latest_growth AS (
    SELECT category_name, growth_pct
    FROM growth_calc
    WHERE year = (SELECT MAX(year) FROM cat_growth)
),
latest_rel_share AS (
    SELECT
        cs.category_name,
        AVG(cs.company_sales * 1.0 / NULLIF(tc.competitor_sales, 0)) AS relative_share
    FROM fact_market_performance mp
    JOIN dim_category cs ON cs.category_id = mp.category_id
    JOIN vw_top_competitor tc ON tc.date_key = mp.date_key AND tc.region_id = mp.region_id
                              AND tc.category_id = mp.category_id AND tc.sales_rank = 1
    JOIN dim_date d ON d.date_key = mp.date_key
    WHERE d.year = (SELECT MAX(year) FROM dim_date)
    GROUP BY cs.category_name
)
SELECT
    g.category_name,
    ROUND(g.growth_pct, 2)          AS market_growth_pct,
    ROUND(r.relative_share, 2)         AS relative_market_share,
    CASE
        WHEN g.growth_pct >= 5  AND r.relative_share >= 1.0 THEN 'Star'
        WHEN g.growth_pct <  5  AND r.relative_share >= 1.0 THEN 'Cash Cow'
        WHEN g.growth_pct >= 5  AND r.relative_share <  1.0 THEN 'Question Mark'
        ELSE 'Dog'
    END AS bcg_quadrant
FROM latest_growth g
JOIN latest_rel_share r ON r.category_name = g.category_name
ORDER BY bcg_quadrant, market_growth_pct DESC;

/* ----------------------------------------------------------------------------
   4. COMPETITOR RANK RETENTION: does the current market leader in a
      region and category stay the leader quarter after quarter, or does
      leadership churn (a retention style analysis applied to competitive
      position rather than customers)
   ---------------------------------------------------------------------------- */

WITH leader_by_quarter AS (
    SELECT
        region_id, category_id, date_key, competitor_id,
        ROW_NUMBER() OVER (PARTITION BY region_id, category_id, date_key ORDER BY competitor_sales DESC) AS rn
    FROM fact_competitor_sales
),
leaders_only AS (
    SELECT region_id, category_id, date_key, competitor_id
    FROM leader_by_quarter WHERE rn = 1
)
SELECT
    region_id,
    category_id,
    competitor_id AS current_leader,
    LAG(competitor_id) OVER (PARTITION BY region_id, category_id ORDER BY date_key) AS previous_leader,
    CASE WHEN competitor_id = LAG(competitor_id) OVER (PARTITION BY region_id, category_id ORDER BY date_key)
         THEN 1 ELSE 0 END AS leadership_retained
FROM leaders_only
ORDER BY region_id, category_id, current_leader;

/* ----------------------------------------------------------------------------
   5. WHITESPACE OPPORTUNITY FUNNEL: from all region-category combinations,
      narrow down to those with large market size, low company share, and
      positive growth, the classic "where should we expand" funnel
   ---------------------------------------------------------------------------- */

WITH all_combos AS (
    SELECT region_name, category_name, AVG(total_market_size) AS avg_market_size,
           AVG(company_market_share_pct) AS avg_share
    FROM vw_market_share
    WHERE year = (SELECT MAX(year) FROM vw_market_share)
    GROUP BY region_name, category_name
),
stage1_large_market AS (
    SELECT * FROM all_combos WHERE avg_market_size > (SELECT AVG(avg_market_size) FROM all_combos)
),
stage2_low_share AS (
    SELECT * FROM stage1_large_market WHERE avg_share < 15
),
stage3_ranked AS (
    SELECT *, RANK() OVER (ORDER BY avg_market_size DESC) AS opportunity_rank
    FROM stage2_low_share
)
SELECT
    (SELECT COUNT(*) FROM all_combos)         AS total_combinations,
    (SELECT COUNT(*) FROM stage1_large_market) AS above_avg_market_size,
    (SELECT COUNT(*) FROM stage2_low_share)      AS above_avg_size_and_low_share,
    (SELECT COUNT(*) FROM stage3_ranked WHERE opportunity_rank <= 10) AS top_10_whitespace_targets;

-- the actual top 10 whitespace targets to expand into
SELECT TOP 10 region_name, category_name, avg_market_size, avg_share
FROM (
    SELECT *, RANK() OVER (ORDER BY avg_market_size DESC) AS opportunity_rank
    FROM (
        SELECT region_name, category_name, AVG(total_market_size) AS avg_market_size, AVG(company_market_share_pct) AS avg_share
        FROM vw_market_share
        WHERE year = (SELECT MAX(year) FROM vw_market_share)
        GROUP BY region_name, category_name
        HAVING AVG(company_market_share_pct) < 15
    ) low_share
) ranked
ORDER BY opportunity_rank;

/* ----------------------------------------------------------------------------
   6. TEMP TABLE: stage a strategic priority score combining size, growth
      and share gap, then query it twice without recomputing
   ---------------------------------------------------------------------------- */

DROP TABLE IF EXISTS #strategic_priority;

WITH base AS (
    SELECT
        category_name,
        AVG(total_market_size)         AS market_size,
        AVG(company_market_share_pct)     AS current_share
    FROM vw_market_share
    WHERE year = (SELECT MAX(year) FROM vw_market_share)
    GROUP BY category_name
)
SELECT
    category_name,
    market_size,
    current_share,
    RANK() OVER (ORDER BY market_size DESC)        AS size_rank,
    RANK() OVER (ORDER BY current_share ASC)          AS gap_rank,
    RANK() OVER (ORDER BY market_size DESC) + RANK() OVER (ORDER BY current_share ASC) AS priority_score
INTO #strategic_priority
FROM base;

SELECT * FROM #strategic_priority ORDER BY priority_score ASC;
SELECT TOP 3 * FROM #strategic_priority ORDER BY priority_score ASC;

DROP TABLE IF EXISTS #strategic_priority;

/* ----------------------------------------------------------------------------
   7. STORED PROCEDURE: returns the market attractiveness ranking for a
      caller supplied year, parameterized so the same logic can be reused
      for any historical period without editing the query
   ---------------------------------------------------------------------------- */

CREATE OR ALTER PROCEDURE usp_MarketAttractivenessByYear
    @TargetYear INT
AS
BEGIN
    SET NOCOUNT ON;

    WITH cat_metrics AS (
        SELECT
            category_name,
            SUM(total_market_size)   AS market_size,
            AVG(company_market_share_pct) AS avg_share
        FROM vw_market_share
        WHERE year = @TargetYear
        GROUP BY category_name
    )
    SELECT
        category_name,
        market_size,
        avg_share,
        RANK() OVER (ORDER BY market_size DESC) AS size_rank,
        RANK() OVER (ORDER BY avg_share ASC)       AS whitespace_rank,
        RANK() OVER (ORDER BY market_size DESC) + RANK() OVER (ORDER BY avg_share ASC) AS attractiveness_score
    FROM cat_metrics
    ORDER BY attractiveness_score ASC;
END;
GO

-- Example call:
-- EXEC usp_MarketAttractivenessByYear @TargetYear = 2025;

/* ----------------------------------------------------------------------------
   8. VIEW: regional strategic scorecard, combining share, growth, and
      leadership retention into one reusable reporting object
   ---------------------------------------------------------------------------- */

CREATE OR ALTER VIEW vw_regional_scorecard AS
SELECT
    r.region_name,
    r.sub_region,
    SUM(mp.company_sales)                                                    AS total_company_sales,
    SUM(mp.total_market_size)                                                   AS total_market_size,
    ROUND(SUM(mp.company_sales) / NULLIF(SUM(mp.total_market_size), 0) * 100, 2) AS market_share_pct
FROM fact_market_performance mp
JOIN dim_region r ON r.region_id = mp.region_id
GROUP BY r.region_name, r.sub_region;
