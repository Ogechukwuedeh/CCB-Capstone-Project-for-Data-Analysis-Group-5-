-- CAPSTONE PROJECT
-- DS JOB HR ANALYTICS
DROP DATABASE ds_job_hr;
CREATE DATABASE ds_job_hr;
USE ds_job_hr;

DROP TABLE ds_jobs;
CREATE TABLE ds_jobs (
	id INT PRIMARY KEY,
    job_title VARCHAR(100),
    salary_estimate VARCHAR(100),
    job_description LONGTEXT,
    rating FLOAT,
    company_name VARCHAR(100),
	location VARCHAR(100),
	headquarters VARCHAR(100),
 	size VARCHAR(50),
	founded INT,
	type_of_ownership VARCHAR(100),
	industry VARCHAR(150),
	sector VARCHAR(100),
	revenue	VARCHAR(100),
    competitors VARCHAR(150)
);

SELECT COUNT(*) FROM ds_jobs;
SELECT * FROM ds_jobs;


-- FIXING DATA IMPORT
LOAD DATA INFILE 'C:/Users/hp/Downloads/DS/DS_jobs'
INTO TABLE ds_jobs
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- FIXING ERROR GOTTEN FROM THE ABOVE CODE
SHOW VARIABLES LIKE 'secure_file_priv';

-- FINAL FIXING OF DATA IMPORT AFTER CORRECTING THE ERROR
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/DS_jobs.csv'
INTO TABLE ds_jobs
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

-- DATA CLEANING 
UPDATE ds_jobs
SET job_title = TRIM(job_title),
    salary_estimate = TRIM(salary_estimate),
    job_description = TRIM(job_description),
    company_name = TRIM(company_name),
	location = TRIM(location),
	headquarters = TRIM(headquarters),
 	size = TRIM(size),
	type_of_ownership = TRIM(type_of_ownership),
	industry = TRIM(industry),
	sector = TRIM(sector),
	revenue	= TRIM(revenue),
    competitors = TRIM(competitors);

-- REPLACING MISSING VALUES
UPDATE ds_jobs
SET founded = null
WHERE founded = -1;

SELECT 
	AVG(rating) AS median_rating
FROM (
	SELECT 
		rating, 
		ROW_NUMBER() OVER (ORDER BY rating) AS row_num, 
		COUNT(*) OVER() AS total_rows
    FROM ds_jobs
    WHERE rating IS NOT NULL
) ranked
WHERE
	row_num IN (FLOOR((total_rows + 1) / 2), CEIL((total_rows + 1) / 2));

UPDATE ds_jobs
SET rating = (SELECT AVG(rating) 
	FROM (SELECT rating, 
			ROW_NUMBER() OVER (ORDER BY rating) AS row_num, 
			COUNT(*) OVER() AS total_rows
		FROM ds_jobs
		WHERE rating IS NOT NULL AND rating != -1
	) ranked
	WHERE row_num 
    IN (FLOOR((total_rows + 1) / 2), CEIL((total_rows + 1) / 2)))
WHERE rating IS NULL OR rating = -1;

UPDATE ds_jobs
SET founded = null
WHERE founded = -1;

UPDATE ds_jobs
SET headquarters = 'Unknown'
WHERE headquarters = '-1';

UPDATE ds_jobs
SET size = 'Unknown'
WHERE size = '-1';	

UPDATE ds_jobs
SET type_of_ownership = 'Unknown'
WHERE type_of_ownership = '-1'; 

UPDATE ds_jobs
SET industry = 'Unknown'
WHERE industry = '-1';

UPDATE ds_jobs
SET sector = 'Unknown'
WHERE sector = '-1';

UPDATE ds_jobs
SET revenue = 'Unknown'
WHERE revenue = '-1';

UPDATE ds_jobs
SET competitors = 'Unknown'
WHERE competitors = '-1';	

SELECT * FROM ds_jobs;

-- Problem 1: Salary insights across roles
-- Business Question: Which job titles have the highest average salary estimates?

-- Task 1: Clean and extract the minimum and maximum salary values from the Salary Estimate column.
-- a. Remove (Glassdoor est) and (Employee est) from salary estimate column.
UPDATE ds_jobs
SET salary_estimate = TRIM(SUBSTRING_INDEX(salary_estimate, '(', 1))
WHERE salary_estimate IS NOT NULL;

-- b. Add minimum and maximum salary columns.
ALTER TABLE ds_jobs
ADD COLUMN min_salary INT,
ADD COLUMN max_salary INT;

-- c. Remove $, - and K from the columns added and multiply them with 1000 due to K.
UPDATE ds_jobs
SET
	min_salary = REPLACE(SUBSTRING_INDEX(SUBSTRING_INDEX(salary_estimate, '-', 1), '$', -1), 'K', '') * 1000,
    max_salary = REPLACE(SUBSTRING_INDEX(SUBSTRING_INDEX(salary_estimate, '-', -1), '$', -1), 'K', '') * 1000
WHERE salary_estimate LIKE '%-%K%';

-- Task 2: Compute the average salary for each Job Title.
-- a. Add average salary column
ALTER TABLE ds_jobs
ADD COLUMN avg_salary INT;

-- b. Calculate the average salary for each job title.
UPDATE ds_jobs
SET avg_salary = (min_salary + max_salary) / 2
WHERE min_salary IS NOT NULL AND max_salary IS NOT NULL;

-- Task 3: Sort job roles by average salary.
-- a. Find the average salary of each job title in descending order. 
SELECT
	job_title,
    ROUND(AVG(avg_salary), 0) AS average_salary
FROM ds_jobs
GROUP BY job_title
ORDER BY average_salary DESC;

-- Task 4: Identify top 5 highest-paying roles.
-- a. Calculate the 5 job titles that pays the most.
SELECT
	job_title,
    ROUND(AVG(avg_salary), 0) AS average_salary
FROM ds_jobs
GROUP BY job_title
ORDER BY average_salary DESC
LIMIT 5;

-- Problem 2: Company Ratings and Size
-- Business Question: Do larger companies tend to have higher Glassdoor ratings?
-- Task 1: Categorize companies into size groups (e.g., Small: <500, Medium: 500–5000, Large: >5000).
-- a. Add size category column to the table
ALTER TABLE ds_jobs
ADD COLUMN size_category VARCHAR(20);

UPDATE ds_jobs
SET size_category = CASE
	WHEN size LIKE '1 to%' OR size LIKE '51 to%' OR size LIKE '201 to%' THEN 'Small'
    WHEN size LIKE '501 to%' OR size LIKE '1001 to%' OR size LIKE '2001 to%' OR size LIKE '3001 to%' OR size LIKE '4001 to%' THEN 'Medium'
    WHEN size LIKE '5001 to%' OR size LIKE '10000+%' THEN 'Large'
	ELSE 'Unknown'
END;

-- b. Find the companies categorized into size groups.
SELECT 
	company_name, 
    size,
    size_category
FROM ds_jobs;

-- Task 2: Calculate the average rating by company size group.
SELECT 
	size_category, 
    ROUND(AVG(rating), 2) AS avg_rating 
FROM ds_jobs
WHERE rating IS NOT NULL AND size_category != 'Unknown'
GROUP BY size_category
ORDER BY avg_rating DESC;

-- Task 3: Identify companies with the highest and lowest ratings within each size group.
SELECT company_name, 
	size_category, 
    rating,
    'Highest' AS rating_type
FROM ds_jobs
WHERE (size_category, rating) IN (
		SELECT size_category, MAX(rating)
		FROM ds_jobs
        WHERE rating IS NOT NULL 
		GROUP BY size_category)
UNION ALL
SELECT company_name, 
	size_category, 
    rating,
    'Lowest' AS rating_type
FROM ds_jobs
WHERE (size_category, rating) IN (
		SELECT size_category, MIN(rating)
		FROM ds_jobs
        WHERE rating IS NOT NULL
		GROUP BY size_category)
ORDER BY size_category, rating_type DESC, rating DESC;

-- Problem 3: Industry & Sector Analysis
-- Business Question: Which industries and sectors offer the best combination of high salaries and strong ratings?

-- Task 1: Group data by Industry and Sector.
SELECT DISTINCT industry, sector
FROM ds_jobs
WHERE industry IS NOT NULL AND sector IS NOT NULL
ORDER BY sector, industry;
SELECT * FROM ds_jobs;
-- Task 2: Compute average salary and average rating for each group.
SELECT industry, sector, 
	ROUND(AVG(avg_salary), 2) AS average_salary, 
    ROUND(AVG(rating), 2) AS avg_rating
FROM ds_jobs
WHERE industry IS NOT NULL AND sector IS NOT NULL
GROUP BY industry, sector
ORDER BY average_salary DESC;

-- Rank the top 5 industries by salary and by rating.
-- a. Top 5 industries by salary
SELECT industry,
	ROUND(AVG(avg_salary), 0) AS average_salary
FROM ds_jobs
WHERE avg_salary IS NOT NULL 
GROUP BY industry
ORDER BY average_salary DESC
LIMIT 5;

-- b. Top 5 industries by rating
SELECT industry,
	ROUND(AVG(rating), 2) AS avg_rating
FROM ds_jobs
WHERE rating IS NOT NULL
GROUP BY industry
ORDER BY avg_rating DESC
LIMIT 5;

-- Identify industries with both above-average salaries and above-average ratings.
SELECT industry,
	ROUND(AVG(avg_salary), 2) AS average_salary,
    ROUND(AVG(rating), 2) AS avg_rating
FROM ds_jobs
WHERE avg_salary IS NOT NULL AND rating IS NOT NULL
GROUP BY industry
HAVING 
	AVG(avg_salary) > (SELECT AVG(avg_salary) FROM ds_jobs WHERE avg_salary IS NOT NULL)
    AND AVG(rating) > (SELECT AVG(rating) FROM ds_jobs WHERE rating IS NOT NULL)
ORDER BY average_salary, avg_rating DESC;

-- Problem 4: Location & Market Opportunities
-- Business Question: Which U.S. cities offer the most Data Science job opportunities and best pay?

-- Task 1: Extract city names from the Location field.
-- a. Add city column
ALTER TABLE ds_jobs
ADD COLUMN city VARCHAR(50);

-- b. Update the table
UPDATE ds_jobs
SET city = TRIM(SUBSTRING_INDEX(location, ',', 1))
WHERE location IS NOT NULL;

-- Task 2: Count the number of job postings per city.
SELECT city, 
	COUNT(*) AS job_postings
FROM ds_jobs
WHERE city IS NOT NULL 
GROUP BY city
ORDER BY job_postings DESC;

-- Task 3: Calculate average salary per city.
SELECT city, 
	ROUND(AVG(avg_salary), 2) AS average_salary
FROM ds_jobs
WHERE avg_salary IS NOT NULL AND city IS NOT NULL
GROUP BY city
ORDER BY average_salary DESC;

-- Task 4: Identify top 5 cities by both job count and salary
SELECT city, 
	COUNT(*) AS job_count,
    ROUND(AVG(avg_salary), 2) AS average_salary
FROM ds_jobs
WHERE city IS NOT NULL and avg_salary IS NOT NULL
GROUP BY city
ORDER BY job_count DESC, average_salary DESC
LIMIT 5;

-- Problem 5: Company Age and Salary Relation
-- Business Question: Do older, more established companies offer higher salaries?

-- Task 1: Create a calculated column for Company Age = 2025 - Founded.
-- a. Add company age column
ALTER TABLE ds_jobs
ADD COLUMN company_age INT;

-- b. Update the table
UPDATE ds_jobs
SET company_age = 2025 - founded
WHERE founded IS NOT NULL;

-- Task 2: Group companies into categories (e.g., Startups, Mid-age, Established).
-- a. Add company age category column
ALTER TABLE ds_jobs
ADD COLUMN age_category VARCHAR(15);

-- b. Update the table with the grouped companies
UPDATE ds_jobs
SET age_category = CASE
	WHEN company_age < 10 THEN 'Startup'
    WHEN company_age BETWEEN 10 AND 30 THEN 'Mid_age'
    WHEN company_age > 30 THEN 'Established'
	ELSE 'Unknown'
END;

-- Task 3: Calculate average salary and rating for each age group.
SELECT age_category,
	ROUND(AVG(avg_salary), 2) AS average_salary,
    ROUND(AVG(rating), 2) AS avg_rating
FROM ds_jobs
WHERE age_category IS NOT NULL 
	AND age_category <> 'Unknown'
GROUP BY age_category
ORDER BY average_salary DESC;

-- Task 4: Identify patterns between company maturity and salary levels.
SELECT age_category,
	COUNT(*) AS total_companies,
	ROUND(AVG(avg_salary), 2) AS average_salary,
    ROUND(AVG(rating), 2) AS avg_rating
FROM ds_jobs
WHERE founded IS NOT NULL 
	AND age_category <> 'Unknown'
GROUP BY age_category
ORDER BY average_salary DESC;