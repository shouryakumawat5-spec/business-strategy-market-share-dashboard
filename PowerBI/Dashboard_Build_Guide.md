# Power BI Dashboard Build Guide

## A Note Before You Start

This build environment cannot run Power BI Desktop, so no `.pbix` binary is included in this folder. What is included instead is everything needed to build the exact dashboard: the data model, every DAX measure written and ready to paste, the page by page layout, and the setup steps for every advanced feature requested (drill through, bookmarks, RLS, what if, forecasting, custom tooltips). Point Power BI Desktop at the CSV files in `/Dataset`, or better, at the SQL Server database built from the `/SQL` scripts, and follow this guide top to bottom.

## 1. Data Model (Star Schema)

Import these tables and set the relationships exactly as listed. All relationships are one to many, single direction, from dimension to fact.

* `dim_date` (1) to `fact_market_performance` (many) on `date_key`
* `dim_region` (1) to `fact_market_performance` (many) on `region_id`
* `dim_category` (1) to `fact_market_performance` (many) on `category_id`
* `dim_date` (1) to `fact_competitor_sales` (many) on `date_key`
* `dim_region` (1) to `fact_competitor_sales` (many) on `region_id`
* `dim_category` (1) to `fact_competitor_sales` (many) on `category_id`
* `dim_competitor` (1) to `fact_competitor_sales` (many) on `competitor_id`

Since `dim_date` here represents quarters rather than days, build a `Quarter Start Date` calculated column (see below) and mark that as the date table if you want native time intelligence functions to work, or use `quarter_label` as a sorted category axis if you prefer a simpler build.

## 2. Calculated Columns

```
Quarter Start Date =
DATE(dim_date[year], (dim_date[quarter] - 1) * 3 + 1, 1)

Region Display Label =
dim_region[region_name] & " (" & dim_region[sub_region] & ")"

BCG Quadrant =
VAR MktGrowth = [Market Growth %]
VAR RelShare = [Relative Market Share]
RETURN
SWITCH(
    TRUE(),
    MktGrowth >= 5 && RelShare >= 1, "Star",
    MktGrowth <  5 && RelShare >= 1, "Cash Cow",
    MktGrowth >= 5 && RelShare <  1, "Question Mark",
    "Dog"
)
```
(Note: `BCG Quadrant` as written is intended as a measure using the DAX measures below, not a calculated column, since it depends on filter context; add it under Measures, not Columns.)

## 3. Core DAX Measures

```
Total Company Sales = SUM(fact_market_performance[company_sales])

Total Market Size = SUM(fact_market_performance[total_market_size])

Market Share % = DIVIDE([Total Company Sales], [Total Market Size], 0) * 100

Total Competitor Sales = SUM(fact_competitor_sales[competitor_sales])

Top Competitor Sales =
CALCULATE(
    MAX(fact_competitor_sales[competitor_sales]),
    ALLEXCEPT(fact_competitor_sales, fact_competitor_sales[date_key], fact_competitor_sales[region_id], fact_competitor_sales[category_id])
)

Relative Market Share = DIVIDE([Total Company Sales], [Top Competitor Sales], 0)

Market Size LY = CALCULATE([Total Market Size], SAMEPERIODLASTYEAR(dim_date[Quarter Start Date]))

Market Growth % = DIVIDE([Total Market Size] - [Market Size LY], [Market Size LY], 0) * 100

Share of Wallet % =
DIVIDE([Total Company Sales], CALCULATE([Total Company Sales], ALL(dim_category)), 0) * 100

Share Change YoY =
[Market Share %] - CALCULATE([Market Share %], SAMEPERIODLASTYEAR(dim_date[Quarter Start Date]))

Category Rank by Share =
RANKX(ALL(dim_category[category_name]), CALCULATE([Market Share %]), , DESC)

Region Rank by Growth =
RANKX(ALL(dim_region[region_name]), CALCULATE([Market Growth %]), , DESC)
```

## 4. What If Parameter: Investment Reallocation Simulator

Modeling tab, New Parameter, Numeric range, name it `Reallocation %`, minimum 0, maximum 20, increment 1, default 5. Add this measure:

```
Simulated Company Sales =
[Total Company Sales] *
(1 + ([Reallocation % Value] / 100) * IF([BCG Quadrant Text] = "Question Mark", 1, IF([BCG Quadrant Text] = "Dog", -1, 0)))
```

Use this on the Recommendation Dashboard page so a viewer can drag the reallocation percentage and see simulated revenue impact of shifting investment from Dog categories into Question Mark categories, exactly the decision framed in `Recommendations.md`.

## 5. Forecasting

On the Trend Analysis page, build a line chart of `Total Market Size` by `dim_date[Quarter Start Date]`. Select the visual, open the Analytics pane, add a Forecast, set forecast length to 4 quarters, confidence interval 95 percent.

## 6. Row Level Security (RLS)

Modeling tab, Manage Roles, create a role named `Regional Lead` with this table filter on `dim_region`:

```
[region_name] = LOOKUPVALUE(region_access[region_name], region_access[user_email], USERPRINCIPALNAME())
```

This requires adding a small `region_access` mapping table (user_email, region_name) to the model, not related to any other table by relationship, referenced only inside the RLS filter expression.

## 7. Bookmarks

Create two bookmarks on the Executive Summary page named `View: Market Share` and `View: BCG Matrix`. Wire two buttons to these bookmarks so a presenter can toggle between the share trend story and the portfolio quadrant story without switching pages.

## 8. Drill Through

Create a hidden page named `Category Detail`. Add `dim_category[category_name]` to the Drill through filters well. On the KPI Dashboard page, right click any category and select Drill Through to see that category's full region by region breakdown and quarterly trend.

## 9. Custom Tooltips

Create a tooltip page (Page Information, set as a tooltip, canvas size 300 by 200) showing `Market Growth %` and `Relative Market Share` for the hovered category. Assign it to the BCG matrix scatter chart under Format, Tooltip.

## 10. Dynamic Titles

```
Dynamic Page Title =
"Market Share Performance — " &
SELECTEDVALUE(dim_region[region_name], "All Regions") &
" | " & SELECTEDVALUE(dim_date[quarter_label], "All Periods")
```

## 11. Dashboard Pages

**Page 1, Executive Summary.** KPI cards for Total Company Sales, Market Share %, Market Growth %, Relative Market Share. A world or region map colored by market share. Bookmark toggle buttons.

**Page 2, KPI Dashboard.** Full grid of every KPI in `KPI_Queries.sql`, filterable by year, region, and category.

**Page 3, Portfolio Analytics (BCG Matrix).** A scatter chart plotting Market Growth % (Y axis) against Relative Market Share (X axis), one bubble per category sized by Total Market Size, quadrant lines at growth = 5% and relative share = 1.0, colored by `BCG Quadrant`.

**Page 4, Geographic Analysis.** Filled map of market share and share change by region, with a slicer for category group.

**Page 5, Trend Analysis.** Quarterly market size and share trend with the four quarter forecast described above.

**Page 6, Deep Dive: Whitespace Opportunities.** Table of the top ten whitespace targets from `Advanced_Analysis.sql` section 5, with market size and current share.

**Page 7, Deep Dive: Competitive Position.** Leadership retention table showing which regions and categories have stable versus churning market leaders.

**Page 8, Recommendation Dashboard.** Executive storytelling page summarizing findings and the four point action plan, with the Reallocation % what if slider live on the page.

## 12. Suggested Visual Theme

Use a dark navy and white corporate theme (Format, Themes, Browse for themes, or the built in "Executive" theme) to match a board level strategy presentation.
