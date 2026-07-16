/* ============================================================================
   PROJECT      : Business Strategy and Market Share Performance Dashboard
   FILE         : Schema.sql
   PURPOSE      : Creates the staging layer used to load the CSV files in
                  /Dataset, and the clean star schema layer that the rest of
                  the SQL scripts and the Power BI model are built on.
   DIALECT      : T-SQL (Microsoft SQL Server / Azure SQL Database).
                  Minor syntax changes are needed for PostgreSQL, noted inline.
   ============================================================================ */

/* ----------------------------------------------------------------------------
   1. STAGING LAYER (raw, as-extracted data, loaded directly from /Dataset)
   ---------------------------------------------------------------------------- */

DROP TABLE IF EXISTS stg_region;
CREATE TABLE stg_region (
    region_id      INT,
    region_name      VARCHAR(50),
    country            VARCHAR(50),
    sub_region           VARCHAR(30)
);

DROP TABLE IF EXISTS stg_category;
CREATE TABLE stg_category (
    category_id      INT,
    category_name      VARCHAR(50),
    category_group        VARCHAR(50)
);

DROP TABLE IF EXISTS stg_competitor;
CREATE TABLE stg_competitor (
    competitor_id      INT,
    competitor_name      VARCHAR(100),
    competitor_tier         VARCHAR(10)
);

DROP TABLE IF EXISTS stg_date;
CREATE TABLE stg_date (
    date_key       INT,
    year             INT,
    quarter            INT,
    quarter_label        VARCHAR(10)
);

DROP TABLE IF EXISTS stg_market_performance;
CREATE TABLE stg_market_performance (
    fact_id            INT,
    date_key             INT,
    region_id              INT,
    category_id               INT,
    company_sales                DECIMAL(15,2),
    total_market_size               DECIMAL(15,2)
);

DROP TABLE IF EXISTS stg_competitor_sales;
CREATE TABLE stg_competitor_sales (
    fact_id             INT,
    date_key              INT,
    region_id               INT,
    category_id                INT,
    competitor_id                 INT,
    competitor_sales                 DECIMAL(15,2)
);

/* Load with BULK INSERT / bcp / Import Wizard, for example:
   BULK INSERT stg_market_performance FROM 'Dataset\company_market_performance_raw.csv'
   WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '\n', TABLOCK);
   Repeat for the other five staging tables. */

/* ----------------------------------------------------------------------------
   2. CLEAN STAR SCHEMA LAYER (populated by Data_Cleaning.sql and
      Data_Transformation.sql, this is the layer Power BI connects to)
   ---------------------------------------------------------------------------- */

DROP TABLE IF EXISTS fact_competitor_sales;
DROP TABLE IF EXISTS fact_market_performance;
DROP TABLE IF EXISTS dim_region;
DROP TABLE IF EXISTS dim_category;
DROP TABLE IF EXISTS dim_competitor;
DROP TABLE IF EXISTS dim_date;

CREATE TABLE dim_region (
    region_id      INT           NOT NULL,
    region_name      VARCHAR(50)   NOT NULL,
    country            VARCHAR(50)   NOT NULL,
    sub_region           VARCHAR(30)   NOT NULL,
    CONSTRAINT pk_dim_region PRIMARY KEY (region_id)
);

CREATE TABLE dim_category (
    category_id      INT           NOT NULL,
    category_name      VARCHAR(50)   NOT NULL,
    category_group        VARCHAR(50)   NOT NULL,
    CONSTRAINT pk_dim_category PRIMARY KEY (category_id)
);

CREATE TABLE dim_competitor (
    competitor_id      INT           NOT NULL,
    competitor_name      VARCHAR(100)  NOT NULL,
    competitor_tier         VARCHAR(10)   NOT NULL,
    CONSTRAINT pk_dim_competitor PRIMARY KEY (competitor_id)
);

CREATE TABLE dim_date (
    date_key         INT           NOT NULL,
    year               INT           NOT NULL,
    quarter               INT           NOT NULL,
    quarter_label            VARCHAR(10)   NOT NULL,
    CONSTRAINT pk_dim_date PRIMARY KEY (date_key)
);

CREATE TABLE fact_market_performance (
    fact_id             INT             NOT NULL,
    date_key              INT             NOT NULL,
    region_id                INT             NOT NULL,
    category_id                  INT             NOT NULL,
    company_sales                    DECIMAL(15,2)   NOT NULL CHECK (company_sales >= 0),
    total_market_size                    DECIMAL(15,2)   NOT NULL CHECK (total_market_size > 0),
    CONSTRAINT pk_fact_market_performance PRIMARY KEY (fact_id),
    CONSTRAINT fk_mp_date     FOREIGN KEY (date_key)    REFERENCES dim_date(date_key),
    CONSTRAINT fk_mp_region   FOREIGN KEY (region_id)   REFERENCES dim_region(region_id),
    CONSTRAINT fk_mp_category FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
    CONSTRAINT chk_mp_share   CHECK (company_sales <= total_market_size)
);

CREATE TABLE fact_competitor_sales (
    fact_id             INT             NOT NULL,
    date_key              INT             NOT NULL,
    region_id                INT             NOT NULL,
    category_id                  INT             NOT NULL,
    competitor_id                    INT             NOT NULL,
    competitor_sales                     DECIMAL(15,2)   NOT NULL CHECK (competitor_sales >= 0),
    CONSTRAINT pk_fact_competitor_sales PRIMARY KEY (fact_id),
    CONSTRAINT fk_cs_date       FOREIGN KEY (date_key)      REFERENCES dim_date(date_key),
    CONSTRAINT fk_cs_region     FOREIGN KEY (region_id)     REFERENCES dim_region(region_id),
    CONSTRAINT fk_cs_category   FOREIGN KEY (category_id)   REFERENCES dim_category(category_id),
    CONSTRAINT fk_cs_competitor FOREIGN KEY (competitor_id) REFERENCES dim_competitor(competitor_id)
);

CREATE INDEX ix_mp_region_category ON fact_market_performance(region_id, category_id);
CREATE INDEX ix_mp_date            ON fact_market_performance(date_key);
CREATE INDEX ix_cs_region_category ON fact_competitor_sales(region_id, category_id);
CREATE INDEX ix_cs_date            ON fact_competitor_sales(date_key);
