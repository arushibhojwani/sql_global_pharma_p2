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


-- 3. Data Cleaning & Exploration

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

-- how many distinct product_id we have?
SELECT DISTINCT product_id FROM batch_production;

-- what is the total number of countries involved in distribution?
SELECT COUNT(DISTINCT country_distributed) FROM batch_production;

-- how many unique therapeutic classes are listed in product registry?
SELECT COUNT(DISTINCT therapeutic_class) FROM product_registry;

-- 4. Core Strategic Problems & Optimized Query Solutions

-- Q.1. Fetch all batches containing Patented products under Regulatory Tier-1

SELECT 
		b.*, p.product_name, p.patent_status 
		FROM batch_production b
		JOIN product_registry p 
		ON b.product_id = p.product_id
WHERE patent_status = 'Patented'AND regulatory_tier = 'Tier-1';


-- Q.2. Audit checking for missing records or logic errors (Expiry date before Manufacturing date)

SELECT * FROM batch_production 
WHERE transaction_id IS NULL
	OR expiry_date <= manufacturing_date
	OR units_produced <= 0;


-- Q.3. Find total production units and average wholesale values grouped by Therapeutic Class

SELECT 
		p.therapeutic_class,
		SUM(b.units_produced) as total_production_units,
		ROUND(AVG(b.wholesale_price),2) AS avg_wholesale_values
	FROM product_registry p
	JOIN batch_production b
	ON p.product_id = b.product_id
GROUP BY 1
ORDER BY 3 DESC;


-- Q.4. Determine overall revenue, total manufacturing costs, and pure net margins

SELECT
		SUM(units_produced * wholesale_price) AS overall_revenue,
		SUM(units_produced * cost_per_unit) AS total_mfg_cost,
		SUM(units_produced *(wholesale_price - cost_per_unit)) AS net_margin
		FROM batch_production
WHERE quality_status = 'Passed';


-- Q.5. Isolate the total batches and total cost broken down by their quality classification.
SELECT 
		quality_status,
		COUNT(*) AS total_batches,
		SUM(units_produced * cost_per_unit) AS total_mfg_cost
FROM batch_production
GROUP BY 1;


-- Q.6. Top 3 distribution countries based on net margin performance

SELECT 
		country_distributed,
		SUM(units_produced * (wholesale_price - cost_per_unit)) AS net_margin
		FROM batch_production
		WHERE quality_status = 'Passed'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3;


-- Q.7. Average shipping delays across distinct distribution pipelines

SELECT 
		DISTINCT distribution_channel,
		COUNT(*) AS load_count,
		ROUND(AVG(shipping_delay_days),1) AS avg_delay
		FROM batch_production 
GROUP BY 1
ORDER BY 2 DESC


-- Q.8. Identify specific products experiencing severe delivery friction (> 4 days lag)

SELECT 
		DISTINCT p.product_name, p.therapeutic_class
		FROM product_registry p
		JOIN batch_production b
		ON p.product_id = b.product_id
WHERE b.shipping_delay_days > 4;


-- Q.9. Categorize batches based on shelf-life remaining relative to a target date

SELECT
		batch_number,
		expiry_date,
		CASE
			WHEN (expiry_date - '2025-06-01'::date) < 365 THEN 'High Risk'
			WHEN (expiry_date - '2025-06-01'::date) BETWEEN 365 AND 730 THEN 'Standard'
			ELSE 'Low Risk'
		END AS shelf_life_tier
		FROM batch_production;


-- Q.10. Track monthly unit yields systematically

SELECT 
		TO_CHAR(manufacturing_date, 'YYYY-MM') AS monthly_cycle,
		SUM(units_produced) AS monthly_yields
		FROM batch_production
GROUP BY 1	
ORDER BY 1;


-- Q.11. Find the highest revenue-generating drug within each country market framework

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

	
-- Q.12. Rank manufacturing runs by unit volume within each dosage form

SELECT 
		p.dosage_form,
		b.batch_number,
		b.units_produced,
		DENSE_RANK() OVER (PARTITION BY p.dosage_form ORDER BY b.units_produced DESC) AS production_rank
		FROM batch_production b
		JOIN product_registry p
		ON b.product_id = p.product_id;


-- Q.13. Calculate a chronologically ordered, running cumulative financial total specifically for the Oncology drug segment distributed inside the USA market

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


-- Q.14. Flag critical anomalies where batches are marked "Failed" but have skipped retesting or carry a high shipping delay

SELECT 
		transaction_id,
		batch_number,
		quality_status,
		shipping_delay_days
FROM batch_production
WHERE quality_status = 'Failed'
AND shipping_delay_days > 0;


-- Q.15. Extract categories accounting for >1,000,000 total units across Tier-1 regions with below-average delays

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

-- END OF PROJECT