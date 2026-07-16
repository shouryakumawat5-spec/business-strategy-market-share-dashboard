# Business Problem

## Client Context

A global consumer products company, competing across Personal Care, Food and Beverage, Household, Family Care, and Beauty categories in ten regions worldwide, is preparing its annual strategy offsite. The CEO and the corporate strategy team have one core complaint about the current state of reporting.

Every business unit presents its own view of performance, in its own format, using its own definition of market share. Nobody in the room can answer a simple question with confidence: where exactly is this company winning share, where is it losing share, and where should the next dollar of investment go.

## The Ask

Build one consistent, company wide view of competitive position that answers three questions the strategy team is expected to walk into the offsite with an answer to.

Which categories and regions are we winning in, and which are we losing in, relative to the market and relative to named competitors.

Where is there real whitespace, meaning large and growing markets where our current share is low, worth actively pursuing.

Which parts of the portfolio are Stars worth continued investment, which are Cash Cows to protect margin on, and which are Question Marks or Dogs that need a hard strategic decision.

## Why This Matters Financially

This company's portfolio spans multiple billion dollar categories. A one point market share swing in even a single major category, at this revenue scale, represents a material shift in enterprise value. Getting the portfolio prioritization right, rather than spreading investment evenly across fifteen categories and ten regions, is the single highest leverage decision the strategy team makes each year.

## Scope Of This Engagement

This project covers the full analytics lifecycle end to end. Company sales, competitor sales, and total market size data across five years and twenty quarters is extracted, cleaned, and modeled into a star schema in SQL. Market share, relative market share, growth, and a full BCG style growth share matrix are calculated directly in SQL, and a Power BI dashboard is built on top to give the strategy team a self service view they can slice by region, category, and time period, styled the way a board level strategy presentation would look.

## Out Of Scope

This project does not forecast future market share using statistical or machine learning models. Power BI's native forecasting visual, which uses exponential smoothing, is used for trend projection, and all classification (Star, Cash Cow, Question Mark, Dog) is done with transparent, auditable SQL logic rather than a black box model. No Python, R, or machine learning libraries are used anywhere in this project, by design, to keep the deliverable fully reproducible with only SQL and Power BI.
