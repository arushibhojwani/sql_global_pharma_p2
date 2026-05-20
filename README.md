# Global Pharmaceutical Supply Chain & Analytics Audit SQL Project

## Project Overview

**Project Title**: Global Pharmaceutical Supply Chain & Analytics Audit 
**Level**: Beginner  
**Database**: `global_pharma_db`
**Data Domain**: Industrial Manufacturing, Corporate Quality Operations, & Logistics Analysis

This SQL project focuses on pharmaceutical manufacturing, product tracking, logistics monitoring, and operational analytics using relational databases. The project demonstrates how SQL can be used to manage pharmaceutical production workflows, perform data quality checks, monitor regulatory compliance, and generate strategic business insights.

## Objectives

1. **Database Schema Design**: Establish a secure, structured relational model consisting of a product master table and an operational logistics tracking table using appropriate constraints and data types.
2. **Data Integrity & Cleansing**: Implement exploratory workflows to flag data quality issues, handle lifecycle variables, and maintain structured audit trails.
3. **Operational Optimization**: Write complex multi-table joins, subqueries, and conditional branching algorithms to identify bottleneck patterns in quality operations.
4. **Advanced Financial & Trend Analytics**: Utilize advanced SQL window functions, chronological aggregations, and dynamic filtering matrices to generate actionable insights on revenue run-rates and regulatory tier risks.

## Project Structure

### 1. Database Setup

- **Database Creation**: The project initializes an enterprise environment by establishing the core database named `global_pharma_db`.
- **Table Implementations**: The database is engineered around a star-schema-style structure featuring two relational tables:
  - `product_registry`: A dimension master table containing product formulations, therapeutic classes, and global regulatory tiers.
  - `batch_production`: An operational fact table logging batch quantities, cost metrics, distribution pathways, and shipping delays.

```sql
CREATE DATABASE global_pharma_db;

-- 1. Create Product Master Registry (Dimension Table)

DROP TABLE IF EXISTS product_registry CASCADE;
CREATE TABLE product_registry
	(
	product_id VARCHAR(10) PRIMARY KEY,
	product_name VARCHAR(50) NOT NULL,
	therapeutic_class VARCHAR(50),
	dosage_form VARCHAR(20),
	patent_status VARCHAR(15),
	regulatory_tier VARCHAR(10)
	-- Tier 1: FDA/EMA, Tier 2: Regional, Tier 3: Local Genders
	);

-- 2. Create Global Batch Production & Logistics Tracker (Fact Table)
DROP TABLE IF EXISTS batch_production CASCADE;
CREATE TABLE batch_production
	(
	transaction_id VARCHAR(10) PRIMARY KEY,
	batch_number VARCHAR(20) UNIQUE NOT NULL,
	product_id VARCHAR(10) REFERENCES product_registry(product_id),
	manufacturing_date DATE NOT NULL,
	expiry_date	DATE NOT NULL,
	units_produced INT CHECK (units_produced > 0),
	cost_per_unit NUMERIC(10,2),
	wholesale_price	NUMERIC(10,2),
	country_distributed	VARCHAR(50),
	distribution_channel VARCHAR(30),
	quality_status VARCHAR(15), -- Passed, Failed, Retesting
	shipping_delay_days INT DEFAULT 0
	);
```

### 2. Exploratory Data Analysis (EDA) & Data Cleaning

-- Checking Null Values & Cleaning

```sql
SELECT * FROM product_registry
WHERE product_id IS NULL
	OR product_name IS NULL
	OR therapeutic_class IS NULL
	OR dosage_form IS NULL	
	OR patent_status IS NULL
	OR regulatory_tier IS NULL;

SELECT * FROM batch_production
WHERE transaction_id IS NULL
	OR batch_number	IS NULL
	OR product_id IS NULL
	OR manufacturing_date IS NULL
	OR expiry_date IS NULL
	OR units_produced IS NULL
	OR cost_per_unit IS NULL
	OR wholesale_price IS NULL
	OR country_distributed IS NULL
	OR distribution_channel IS NULL
	OR quality_status IS NULL
	OR shipping_delay_days IS NULL;
```
-- Data Exploration

```sql
-- how many distinct product_id we have?
SELECT DISTINCT product_id FROM batch_production;

-- what is the total number of countries involved in distribution?
SELECT COUNT(DISTINCT country_distributed) FROM batch_production;

-- how many unique therapeutic classes are listed in product registry?
SELECT COUNT(DISTINCT therapeutic_class) FROM product_registry;
```

### 3. Business Logic & Query Implementations

The core analytical section of the repository addresses enterprise-level business scenarios. Key solutions highlight specific database mechanisms below:

1. **Fetch all batches containing Patented products under Regulatory Tier-1**:
```sql
SELECT 
		b.*, p.product_name, p.patent_status 
		FROM batch_production b
		JOIN product_registry p 
		ON b.product_id = p.product_id
WHERE patent_status = 'Patented'AND regulatory_tier = 'Tier-1';
```

2. **Audit checking for missing records or logic errors (Expiry date before Manufacturing date)**:
```sql
SELECT * FROM batch_production 
WHERE transaction_id IS NULL
	OR expiry_date <= manufacturing_date
	OR units_produced <= 0;
```

3. **Find total production units and average wholesale values grouped by Therapeutic Class**:
```sql
SELECT 
		p.therapeutic_class,
		SUM(b.units_produced) as total_production_units,
		ROUND(AVG(b.wholesale_price),2) AS avg_wholesale_values
	FROM product_registry p
	JOIN batch_production b
	ON p.product_id = b.product_id
GROUP BY 1
ORDER BY 3 DESC;
```

4. **Determine overall revenue, total manufacturing costs, and pure net margins**:
```sql
SELECT
		SUM(units_produced * wholesale_price) AS overall_revenue,
		SUM(units_produced * cost_per_unit) AS total_mfg_cost,
		SUM(units_produced *(wholesale_price - cost_per_unit)) AS net_margin
		FROM batch_production
WHERE quality_status = 'Passed';
```

5. **Isolate the total batches and total cost broken down by their quality classification**:
```sql
SELECT 
		quality_status,
		COUNT(*) AS total_batches,
		SUM(units_produced * cost_per_unit) AS total_mfg_cost
FROM batch_production
GROUP BY 1;
```

6. **Top 3 distribution countries based on net margin performance**:
```sql
SELECT 
		country_distributed,
		SUM(units_produced * (wholesale_price - cost_per_unit)) AS net_margin
		FROM batch_production
		WHERE quality_status = 'Passed'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;
```

7. **Average shipping delays across distinct distribution pipelines**:
```sql
SELECT 
		DISTINCT distribution_channel,
		COUNT(*) AS load_count,
		ROUND(AVG(shipping_delay_days),1) AS avg_delay
		FROM batch_production 
GROUP BY 1
ORDER BY 2 DESC;
```

8. **Identify specific products experiencing severe delivery friction (> 4 days lag)**:
```sql
SELECT 
		DISTINCT p.product_name, p.therapeutic_class
		FROM product_registry p
		JOIN batch_production b
		ON p.product_id = b.product_id
WHERE b.shipping_delay_days > 4;
```

9. **Categorize batches based on shelf-life remaining relative to a target date**:
```sql
SELECT
		batch_number,
		expiry_date,
		CASE
			WHEN (expiry_date - '2025-06-01'::date) < 365 THEN 'High Risk'
			WHEN (expiry_date - '2025-06-01'::date) BETWEEN 365 AND 730 THEN 'Standard'
			ELSE 'Low Risk'
		END AS shelf_life_tier
		FROM batch_production;
```

10. **Track monthly unit yields systematically**:
```sql
SELECT 
		TO_CHAR(manufacturing_date, 'YYYY-MM') AS monthly_cycle,
		SUM(units_produced) AS monthly_yields
		FROM batch_production
GROUP BY 1	
ORDER BY 1;
```

11. **Find the highest revenue-generating drug within each country market framework**:
```sql
WITH regional_ledger AS
(
SELECT b.country_distributed,
		p.product_name,
		SUM(b.units_produced * b.wholesale_price) AS total_sales,
		RANK() OVER (PARTITION BY b.country_distributed ORDER BY SUM(b.units_produced * b.wholesale_price) DESC) AS rank
	FROM batch_production b
	JOIN product_registry p
	ON b.product_id = p.product_id
	WHERE b.quality_status = 'Passed'
	GROUP BY 1,2
)
SELECT * FROM regional_ledger
WHERE rank = 1;
```

12. **Rank manufacturing runs by unit volume within each dosage form**:
```sql
SELECT 
		p.dosage_form,
		b.batch_number,
		b.units_produced,
		DENSE_RANK() OVER (PARTITION BY p.dosage_form ORDER BY b.units_produced DESC) AS production_rank
		FROM batch_production b
		JOIN product_registry p
		ON b.product_id = p.product_id;
```

13. **Calculate a chronologically ordered, running cumulative financial total specifically for the Oncology drug segment distributed inside the USA market**:
```sql
SELECT 
		b.transaction_id,
		b.manufacturing_date,
		p.therapeutic_class,
		b.country_distributed,
		(b.units_produced * b.wholesale_price) AS batch_revenue,
		SUM(b.units_produced * b.wholesale_price) OVER (ORDER BY b.manufacturing_date) AS running_cumulative_revenue
	FROM batch_production b
	JOIN product_registry p
	ON b.product_id = p.product_id
WHERE p.therapeutic_class = 'Oncology'
AND b.country_distributed = 'USA';
```

14. **Flag critical anomalies where batches are marked "Failed" but have skipped retesting or carry a high shipping delay**:
```sql
SELECT 
		transaction_id,
		batch_number,
		quality_status,
		shipping_delay_days
FROM batch_production
WHERE quality_status = 'Failed'
AND shipping_delay_days > 0;
```

15. **Extract categories accounting for >1,000,000 total units across Tier-1 regions with below-average delays**:
```sql
SELECT 
		p.therapeutic_class,
		SUM(b.units_produced) AS total_units
		FROM batch_production b
		JOIN product_registry p
		ON b.product_id = p.product_id
		WHERE regulatory_tier = 'Tier-1'
		AND shipping_delay_days <
							(SELECT AVG(shipping_delay_days) 
							FROM batch_production)
GROUP BY 1
HAVING SUM(b.units_produced) > 1000000
ORDER BY 2;
```

## Findings

- **Production Scale**: The database tracks over **16,026,450 pharmaceutical units** manufactured and distributed across **8 countries** and **50 registered pharmaceutical products**.
- **Quality Monitoring**: Out of all production batches, **179 batches passed quality checks**, while **14 batches failed** and **7 batches required retesting**, highlighting the importance of pharmaceutical compliance monitoring.
- **Revenue & Profitability**: The manufacturing operations generated an estimated **$223.5 million in wholesale revenue** with a calculated **net margin is $170.05 million** after production costs.
- **Distribution Performance**: Average shipping delays remained low at **1.54 days**, indicating relatively efficient global logistics operations.
- **Top Markets**: Countries such as **France ($53.1M)**, **USA ($39.8M)**, and **Germany ($36.9M)** contributed the highest wholesale distribution revenue.


## Reports
- **Manufacturing Summary**: A consolidated operational report tracking 16M+ production units, batch-level manufacturing activity, and overall production efficiency.
- **Revenue & Margin Analysis**: Financial reporting displaying approximately $223.5M in total revenue, $53.48M in production costs, and strong profitability across pharmaceutical products.
- **Quality Assurance Report**: A compliance-focused report analyzing batch approval rates, failed inspections, and retesting requirements within pharmaceutical production operations.
- **Distribution & Logistics Report**: A logistics intelligence report monitoring shipment activity, country-wise distribution performance, and shipping delays across global pharmaceutical markets.

## Conclusion

This project demonstrates the practical application of SQL in pharmaceutical manufacturing and distribution analytics. Using relational database structures, production tracking systems, and business-driven SQL queries, the project transforms raw pharmaceutical operational data into actionable manufacturing, logistics, compliance, and profitability insights. The workflow showcases real-world SQL practices commonly used in enterprise healthcare, supply chain analytics, and pharmaceutical business intelligence systems.

## Tools & Technologies Used

- **Database Management System (DBMS)**: PostgreSQL 18
- **Database Administration Interface**: Tool: pgAdmin 4
- **SQL Mechanics utilized**:
  - **Data Definition Language (DDL)**: `CREATE TABLE`, `DROP TABLE IF EXISTS` and cascade options to deploy clean, reproducible star-schema environments.
  - **Relational Constraints**: Incorporating `PRIMARY KEY`, `REFERENCES` foreign keys, and validation bounds like `CHECK (units_produced > 0)` to maintain strict database integrity.
  - **Data Aggregation**: `SUM()`, `COUNT()`, `ROUND()`, and mathematical expressions running over `GROUP BY`, `HAVING` and `ORDER BY` frameworks to calculate multi-table metric dimensions.
  - **Analytical & Window Functions**: `SUM(...) OVER (ORDER BY ...)` syntax to compute continuous time-series cumulative run-rates without collapsing core transactional rows.
  - **Conditional Expressions**: `CASE WHEN ... THEN ... ELSE END` blocks to dynamically bucket raw numeric fields into categorical business groups.
  - **Explicit Type Casting**: Using system-level parsing operators `(::date)` to transform absolute string literals securely into data-arithmetic variables.

## How to Use

1. **Clone the Repository**: Clone this project repository from GitHub to your local environment.
2. **Set Up the Database**: Execute the relational schema code provided in the `global_pharma_db.sql` file using your SQL editor (DBeaver/pgAdmin) to generate the tables.
3. **Populate Source Data**: Load the raw transactional records from `product_registry.csv` and `batch_production.csv` into their matching relational structures.
4. **Run Analytics Queries**: Run the structured script queries sequentially to extract quality audits, portfolio margin timelines, and running cumulative market balances.

## Author - Arushi Bhojwani

This project forms a core component of my data analytics portfolio, showcasing the clean SQL syntax, structural execution, and database logic essential for professional Data Analyst roles. If you have any technical questions, optimization feedback, or would like to explore collaborative data projects, please feel free to reach out!

- **LinkedIn**: [Connect with me professionally](https://www.linkedin.com/in/arushi-bhojwani-46a392358 )


Thank you for your support, and I look forward to connecting with you!
