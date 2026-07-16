# Business Strategy and Market Share Performance Dashboard

A consulting style, end to end analytics engagement built entirely with SQL and Power BI. This project analyzes a global consumer products company's competitive position across ten regions and fifteen categories, and builds a Bain style BCG growth share matrix directly in SQL to answer where the company should invest, defend, or exit.

## Project Overview

This repository contains a complete analytics build, from raw data to executive dashboard, structured the way a Bain, ZS Associates, or Fractal Analytics team would hand off a client strategy deliverable. It uses only SQL and Power BI. No Python, no R, no Tableau, and no machine learning libraries anywhere in the codebase.

## Business Problem

Every business unit reports market share differently, and the strategy team cannot say with confidence where the company is winning, losing, or leaving whitespace on the table. Full context is in [`Documentation/Business_Problem.md`](Documentation/Business_Problem.md).

## Architecture

```
Raw CSV extract (Dataset/)
        |
        v
Staging tables  ---->  Data_Cleaning.sql   (sign errors, dedup, casing standardization, logic validation)
        |
        v
Data_Transformation.sql  ---->  Star schema (dim_region, dim_category, dim_competitor, dim_date,
                                              fact_market_performance, fact_competitor_sales)
        |
        v
KPI_Queries.sql  +  Advanced_Analysis.sql  (market share, BCG matrix, whitespace funnel, leadership retention)
        |
        v
Power BI  (star schema model, DAX measures, BCG matrix dashboard)
```

See the full entity relationship diagram at [`Documentation/ER_Diagram.png`](Documentation/ER_Diagram.png).

## Dataset

The dataset is synthetic, generated with pure SQL (see [`SQL/Data_Generation.sql`](SQL/Data_Generation.sql) for full transparency on how it was built), covering 5 years and 20 fiscal quarters, because real company and competitor sales data is confidential. It is deliberately seeded with realistic data quality issues, negative market size sign errors, missing sales values, duplicate rows, and inconsistent region name casing, so that `Data_Cleaning.sql` has real problems to solve.

| Table | Rows | Description |
|---|---|---|
| regions_raw.csv | 10 | Regions across North America, Europe, APAC, LATAM, and MEA |
| categories_raw.csv | 15 | Product categories across 5 category groups |
| competitors_raw.csv | 5 | Tracked competitors across 3 tiers |
| date_dim_raw.csv | 20 | Fiscal quarters, 2021 through 2025 |
| company_market_performance_raw.csv | 3,003 | Company sales and total market size by quarter, region, category |
| competitor_sales_raw.csv | 11,985 | Competitor sales by quarter, region, category, competitor |

Full column level detail is in [`Documentation/Data_Dictionary.md`](Documentation/Data_Dictionary.md).

## SQL Concepts Used

Complex multi table joins, CTEs, window functions (RANK, NTILE, LAG, rolling averages), a stored procedure for parameterized market attractiveness scoring, views for reusable reporting layers, a temp table for staged strategic priority scoring, a BCG style growth share matrix classification, a whitespace opportunity funnel, competitive leadership retention analysis, and quarter over quarter time series trending.

## Power BI Features Used

Star schema data modeling, DAX measures and calculated columns, drill through pages, bookmarks with toggle buttons, a What If parameter simulating investment reallocation between BCG quadrants, built in forecasting on market size, row level security by region, custom tooltip pages, and dynamic titles. Full build steps, with every DAX formula included, are in [`PowerBI/Dashboard_Build_Guide.md`](PowerBI/Dashboard_Build_Guide.md).

A note on the `.pbix` file: this repository was built in an environment without Power BI Desktop installed, so the binary `.pbix` is not included. Everything needed to build it, the data model, every DAX measure, and the page by page layout, is fully specified in the build guide.

## Key Insights

A small number of categories qualify as Stars, high growth and high relative share, and are currently under-invested relative to their potential. Several Cash Cow categories are stable and defensible. A cluster of Question Mark categories sit in large, fast growing markets with low current share, the clearest whitespace opportunity in the portfolio. Competitive leadership churns more than expected in several region and category combinations, meaning current market position is less defensible than it looks. Full findings are in [`Documentation/Recommendations.md`](Documentation/Recommendations.md).

## Dashboard Pages

Executive Summary, KPI Dashboard, Portfolio Analytics (BCG Matrix), Geographic Analysis, Trend Analysis with forecasting, Deep Dive: Whitespace Opportunities, Deep Dive: Competitive Position, and a Recommendation Dashboard with a live investment reallocation simulator. Layout wireframe: [`PowerBI/Dashboard_Screenshots/BCG_Matrix_Page_Wireframe.png`](PowerBI/Dashboard_Screenshots/BCG_Matrix_Page_Wireframe.png).

## Business Recommendations

See [`Documentation/Recommendations.md`](Documentation/Recommendations.md) for the full memo, including key findings, revenue opportunities, cost reduction areas, risk factors, and a four point action plan.

## Installation Steps

1. Clone this repository.
2. Load the CSV files in `/Dataset` into a SQL Server, Azure SQL, or PostgreSQL database (adjust minor T-SQL syntax for PostgreSQL, mainly `TOP` to `LIMIT`).
3. Run `SQL/Schema.sql`, then `SQL/Data_Cleaning.sql`, then `SQL/Data_Transformation.sql`, in that order.
4. Run `SQL/KPI_Queries.sql` and `SQL/Advanced_Analysis.sql` to validate the numbers.
5. Open Power BI Desktop, connect to the database, and follow `PowerBI/Dashboard_Build_Guide.md` to build the model and every page.

## Future Improvements

Add a pricing index dimension so share shifts can be decomposed into volume versus price effects. Extend the whitespace funnel with a market entry cost proxy, so the ranked opportunity list balances market size against ease of entry, not size alone. Add a scenario comparison page that stores multiple What If reallocation snapshots side by side using bookmarks.

## Repository Structure

```
Business_Strategy_Market_Share_Dashboard/
├── Dataset/                         Raw CSV extracts (with intentional data quality issues)
├── SQL/
│   ├── Schema.sql                   Staging and star schema DDL
│   ├── Data_Generation.sql          How the synthetic dataset was built (SQLite dialect)
│   ├── Data_Cleaning.sql            Sign errors, dedup, casing standardization, validation
│   ├── Data_Transformation.sql      Star schema load logic and reusable views
│   ├── KPI_Queries.sql              Ten core business KPI queries
│   └── Advanced_Analysis.sql        Window functions, BCG matrix, whitespace funnel, stored procedure
├── PowerBI/
│   ├── Dashboard_Build_Guide.md     Full model, DAX, and page build instructions
│   └── Dashboard_Screenshots/       Layout wireframe
├── Documentation/
│   ├── Business_Problem.md
│   ├── Recommendations.md
│   ├── Data_Dictionary.md
│   └── ER_Diagram.png
├── Presentation/
│   └── Executive_Summary_Deck.md
└── README.md
```

## Resume Bullet Points

* Designed a star schema SQL data model across 6 tables and 15,000+ synthetic market performance records, building a BCG style growth share matrix classification entirely in SQL to categorize 15 product categories into Star, Cash Cow, Question Mark, and Dog strategic postures.
* Built a whitespace opportunity funnel and competitive leadership retention analysis using CTEs, window functions, and a parameterized stored procedure, surfacing 10 priority market expansion targets from over 150 region and category combinations.
* Designed an 8 page Power BI strategy dashboard with a live What If investment reallocation simulator, forecasting, row level security, and drill through, translating raw sales data into a board ready portfolio prioritization tool.

ATS friendly one line description: Built an end to end SQL and Power BI analytics solution for market share and portfolio strategy, including a BCG growth share matrix, whitespace opportunity analysis, and executive dashboard design.
