-- =====================================================================
-- PROJECT 2 : WORLD LAYOFFS  |  EXPLORATORY DATA ANALYSIS (MySQL)
-- Table used : world_layoffs.layoffs_staging2  (already cleaned)
-- Columns    : company, location, industry, total_laid_off,
--              percentage_laid_off, `date` (DATE), stage, country,
--              funds_raised_millions
-- =====================================================================
USE world_layoffs;

-- 0. QUICK LOOK ---------------------------------------------------------
SELECT * FROM layoffs_staging2 LIMIT 20;
SELECT COUNT(*) AS total_rows FROM layoffs_staging2;

-- 1. OVERALL NUMBERS ----------------------------------------------------
SELECT MAX(total_laid_off)              AS max_laid_off,
       MAX(percentage_laid_off)         AS max_pct,
       SUM(total_laid_off)              AS total_laid_off,
       ROUND(AVG(total_laid_off),0)     AS avg_per_event,
       MIN(`date`)                      AS first_date,
       MAX(`date`)                      AS last_date
FROM layoffs_staging2
WHERE total_laid_off IS NOT NULL;

-- 2. COMPANIES THAT SHUT DOWN (100% laid off), biggest funding first ----
SELECT company, industry, country, total_laid_off, funds_raised_millions
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY funds_raised_millions DESC
LIMIT 15;

-- 3. TOP 10 COMPANIES BY TOTAL LAYOFFS ---------------------------------
SELECT company, SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
GROUP BY company
HAVING SUM(total_laid_off) IS NOT NULL
ORDER BY total_laid_off DESC
LIMIT 10;

-- 4. BY INDUSTRY --------------------------------------------------------
SELECT industry, SUM(total_laid_off) AS total_laid_off,
       COUNT(*) AS events,
       ROUND(100 * SUM(total_laid_off) / SUM(SUM(total_laid_off)) OVER (), 1) AS pct_of_total
FROM layoffs_staging2
GROUP BY industry
HAVING SUM(total_laid_off) IS NOT NULL
ORDER BY total_laid_off DESC;

-- 5. BY COUNTRY (top 10) ------------------------------------------------
SELECT country, SUM(total_laid_off) AS total_laid_off, COUNT(*) AS events
FROM layoffs_staging2
GROUP BY country
HAVING SUM(total_laid_off) IS NOT NULL
ORDER BY total_laid_off DESC
LIMIT 10;

-- 6. BY FUNDING STAGE ---------------------------------------------------
SELECT stage, SUM(total_laid_off) AS total_laid_off, COUNT(*) AS events
FROM layoffs_staging2
GROUP BY stage
HAVING SUM(total_laid_off) IS NOT NULL
ORDER BY total_laid_off DESC;

-- 7. BY YEAR ------------------------------------------------------------
SELECT YEAR(`date`) AS yr, SUM(total_laid_off) AS total_laid_off, COUNT(*) AS events
FROM layoffs_staging2
WHERE `date` IS NOT NULL
GROUP BY YEAR(`date`)
ORDER BY yr;

-- 8. MONTHLY TREND + ROLLING TOTAL -------------------------------------
WITH monthly AS (
  SELECT SUBSTRING(`date`,1,7) AS `month`, SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY `month`
)
SELECT `month`, total_laid_off,
       SUM(total_laid_off) OVER (ORDER BY `month`) AS rolling_total
FROM monthly
ORDER BY `month`;

-- 9. TOP 3 COMPANIES PER YEAR (ranking with window function) -----------
WITH company_year AS (
  SELECT company, YEAR(`date`) AS yr, SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY company, YEAR(`date`)
  HAVING SUM(total_laid_off) IS NOT NULL
),
ranked AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY yr ORDER BY total_laid_off DESC) AS ranking
  FROM company_year
)
SELECT * FROM ranked WHERE ranking <= 3 ORDER BY yr, ranking;

-- 10. TOP 3 INDUSTRIES PER YEAR ----------------------------------------
WITH industry_year AS (
  SELECT industry, YEAR(`date`) AS yr, SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY industry, YEAR(`date`)
  HAVING SUM(total_laid_off) IS NOT NULL
),
ranked AS (
  SELECT *, DENSE_RANK() OVER (PARTITION BY yr ORDER BY total_laid_off DESC) AS ranking
  FROM industry_year
)
SELECT * FROM ranked WHERE ranking <= 3 ORDER BY yr, ranking;

-- 11. QUARTER-WISE TREND -----------------------------------------------
SELECT YEAR(`date`) AS yr, QUARTER(`date`) AS qtr, SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE `date` IS NOT NULL
GROUP BY yr, qtr
ORDER BY yr, qtr;

-- 12. MONTH-ON-MONTH % CHANGE (LAG) ------------------------------------
WITH monthly AS (
  SELECT SUBSTRING(`date`,1,7) AS `month`, SUM(total_laid_off) AS total_laid_off
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY `month`
)
SELECT `month`, total_laid_off,
       LAG(total_laid_off) OVER (ORDER BY `month`) AS prev_month,
       ROUND(100 * (total_laid_off - LAG(total_laid_off) OVER (ORDER BY `month`))
             / LAG(total_laid_off) OVER (ORDER BY `month`), 1) AS mom_pct_change
FROM monthly
ORDER BY `month`;

-- 13. INDIA FOCUS (top cities & companies) -----------------------------
SELECT location AS city, SUM(total_laid_off) AS total_laid_off, COUNT(*) AS events
FROM layoffs_staging2
WHERE country = 'India'
GROUP BY location
HAVING SUM(total_laid_off) IS NOT NULL
ORDER BY total_laid_off DESC;

SELECT company, industry, SUM(total_laid_off) AS total_laid_off
FROM layoffs_staging2
WHERE country = 'India'
GROUP BY company, industry
HAVING SUM(total_laid_off) IS NOT NULL
ORDER BY total_laid_off DESC
LIMIT 10;

-- 14. FUNDING vs LAYOFFS : did heavily-funded companies also cut? ------
SELECT CASE
         WHEN funds_raised_millions IS NULL THEN 'Unknown'
         WHEN funds_raised_millions < 50    THEN '1. Under 50M'
         WHEN funds_raised_millions < 500   THEN '2. 50M - 500M'
         WHEN funds_raised_millions < 2000  THEN '3. 500M - 2B'
         ELSE '4. 2B+'
       END AS funding_bucket,
       COUNT(*) AS events,
       SUM(total_laid_off) AS total_laid_off,
       ROUND(AVG(percentage_laid_off) * 100, 1) AS avg_pct_laid_off
FROM layoffs_staging2
GROUP BY funding_bucket
ORDER BY funding_bucket;

-- 15. REPEAT LAYOFFS : companies that laid off more than once ----------
SELECT company, COUNT(*) AS rounds, SUM(total_laid_off) AS total_laid_off,
       MIN(`date`) AS first_round, MAX(`date`) AS last_round
FROM layoffs_staging2
GROUP BY company
HAVING COUNT(*) >= 3
ORDER BY rounds DESC, total_laid_off DESC
LIMIT 15;

-- 16. DATA QUALITY CHECK : how many rows have no headcount? ------------
SELECT SUM(total_laid_off IS NULL)          AS missing_headcount,
       SUM(percentage_laid_off IS NULL)     AS missing_pct,
       SUM(funds_raised_millions IS NULL)   AS missing_funds
FROM layoffs_staging2;
