# Data Dictionary

## dim_region

| Column | Type | Description |
|---|---|---|
| region_id | INT, PK | Unique identifier for the region |
| region_name | VARCHAR(50) | Name of the region, standardized during cleaning |
| country | VARCHAR(50) | Primary country associated with the region |
| sub_region | VARCHAR(30) | Sub region grouping, for example West, APAC, EU South |

## dim_category

| Column | Type | Description |
|---|---|---|
| category_id | INT, PK | Unique identifier for the product category |
| category_name | VARCHAR(50) | Name of the category, for example Premium Skincare |
| category_group | VARCHAR(50) | Higher level grouping, for example Personal Care |

## dim_competitor

| Column | Type | Description |
|---|---|---|
| competitor_id | INT, PK | Unique identifier for the tracked competitor |
| competitor_name | VARCHAR(100) | Name of the competitor |
| competitor_tier | VARCHAR(10) | Tier 1, Tier 2, or Tier 3, by relative competitor size |

## dim_date

| Column | Type | Description |
|---|---|---|
| date_key | INT, PK | Unique key for each fiscal quarter |
| year | INT | Calendar year |
| quarter | INT | Quarter number, 1 to 4 |
| quarter_label | VARCHAR(10) | Display label, for example Q1 2021 |

## fact_market_performance

| Column | Type | Description |
|---|---|---|
| fact_id | INT, PK | Unique identifier for the fact row |
| date_key | INT, FK | References dim_date |
| region_id | INT, FK | References dim_region |
| category_id | INT, FK | References dim_category |
| company_sales | DECIMAL(15,2) | The company's own sales in that region, category, and quarter |
| total_market_size | DECIMAL(15,2) | Total addressable market size in that region, category, and quarter |

## fact_competitor_sales

| Column | Type | Description |
|---|---|---|
| fact_id | INT, PK | Unique identifier for the fact row |
| date_key | INT, FK | References dim_date |
| region_id | INT, FK | References dim_region |
| category_id | INT, FK | References dim_category |
| competitor_id | INT, FK | References dim_competitor |
| competitor_sales | DECIMAL(15,2) | Estimated competitor sales in that region, category, quarter, and competitor |

## Derived Objects

`vw_market_share` joins fact_market_performance to every dimension and calculates company_market_share_pct plus total tracked competitor sales for the same period, region, and category. This is the base layer for nearly every KPI query.

`vw_top_competitor` ranks competitors by sales within each date, region, and category combination, used to identify the market leader and to calculate relative market share.

`vw_regional_scorecard` summarizes total company sales, total market size, and market share percentage by region, used directly by the Geographic Analysis page in Power BI.

`usp_MarketAttractivenessByYear` is a stored procedure that returns the market attractiveness ranking (market size rank plus whitespace rank) for any caller supplied year.
