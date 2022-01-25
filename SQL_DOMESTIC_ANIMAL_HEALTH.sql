---EXPLORING ANIMAL HEALTH DATA FOR *DOMESTIC* ANIMALS SINCE 2005
---DATA RETRIEVED FROM OIE-WAHIS (WORLD ANIMAL HEALTH INFORMATION SYSTEM)
---ON 01/12/2022

---SKILLS USED: AGGREGATE FUNCTIONS, WINDOW FUNCTIONS, CTE, SUBQUERIES, CASE STATEMENT
		
---A. SETTING THINGS UP

--I. IN THIS DATA SET:
	--i. THERE ARE INSTANCES WHERE NUMBER OF DEATHS(KILLED, SLAUGHTERED AND DICEASED COMBINED)
	-- FAR EXCEEDS NUMBER OF CASES
--II. FOR THAT, WE HAVE:
	--1. ADDED A NEW COLUMN CALLED NEW_CASES BASED ON THE
	-- ASSUMPTION THAT THE TRUE CASE NUMBERS SHOULD BE AT LEAST >= 
	-- NUMBERS OF DEATHS(KILLED, SLAUGHTERED AND DICEASED COMBINED)

--III. ADDING COLUMN NEW_CASES, THEN INSERT THE TRUE CASES VALUES INTO IT

	ALTER TABLE ANIMAL_HEALTH_REPORT
	ADD NEW_CASES FLOAT;
			
	UPDATE ANIMAL_HEALTH_REPORT
	SET NEW_CASES =
		CASE
			WHEN CASES < KILLED_AND_DISPOSED_OF + SLAUGHTERED + DEATHS 
			THEN KILLED_AND_DISPOSED_OF + SLAUGHTERED + DEATHS
			ELSE CASES
		END;

---B. PARTIAL DATA EXPLORATION FOR REPORTED DISEASES AMONG DOMESTIC ANIMALS AROUND THE WORLD

--I. NUMBER OF DOMESTIC ANIMALS THAT HAVE LOST THEIR LIVES BY YEAR
			
	SELECT YEAR, 
	FORMAT(SUM(KILLED_AND_DISPOSED_OF), '###,###,###') AS KILLED_AND_DISPOSED_OF,
	FORMAT(SUM(SLAUGHTERED), '###,###,###') AS SLAUGHTERED, 
	FORMAT(SUM(DEATHS), '###,###,###') AS DEATHS,
	FORMAT(SUM(KILLED_AND_DISPOSED_OF + SLAUGHTERED + DEATHS), '###,###,###') AS TOTAL_LIVES_LOST
	FROM ANIMAL_HEALTH_REPORT
	GROUP BY YEAR
	ORDER BY 1 DESC;

	-- TOTAL LIVES LOST WITH PERCENT INCREASE/DECREASE

	WITH CTE1 AS
		( SELECT YEAR, 
		SUM(KILLED_AND_DISPOSED_OF + SLAUGHTERED + DEATHS) 
		AS TOTAL_LIVES_LOST
		FROM ANIMAL_HEALTH_REPORT
		GROUP BY YEAR ),
	CTE2 AS
		( SELECT *, LEAD(TOTAL_LIVES_LOST, 1) OVER (ORDER BY YEAR DESC) 
		AS PREVIOUS_NUMB
		FROM CTE1 )
	SELECT YEAR, TOTAL_LIVES_LOST,
	CAST(((TOTAL_LIVES_LOST - PREVIOUS_NUMB)/PREVIOUS_NUMB)*100 AS DEC(3,1))
	AS [PERCT_INCREASE/DECREASE]
	FROM CTE2;

--II. TOTAL CASES BY SPECIES OVER THE LAST 10 YEARS

	SELECT SPECIES, 
	SUM(NEW_CASES) TOTAL_CASES,
	SUM(KILLED_AND_DISPOSED_OF) AS KILLED_AND_DISPOSED_OF, 
	SUM(SLAUGHTERED) AS SLAUGHTERED, 
	SUM(DEATHS) AS DEATHS
	FROM ANIMAL_HEALTH_REPORT
	WHERE YEAR >= 2011
	GROUP BY SPECIES
	ORDER BY 2 DESC;

--III. LIST OF REPORTED DISEASES BY TOTAL CASES, TOTAL DEATHS,
--AND CASE FATALITY RATE (CFR) OVER THE LAST 10 YEARS
			
	SELECT DISEASE,
	SUM(NEW_CASES) TOTAL_CASES,
	SUM(DEATHS) TOTAL_DEATHS,
	CAST(SUM(DEATHS)/SUM(NEW_CASES)*100 AS DEC(3,1)) AS CFR
	FROM ANIMAL_HEALTH_REPORT
	WHERE YEAR >= 2011
	GROUP BY DISEASE
	ORDER BY 2 DESC;

					--- OR ---

	WITH CTE_SUMS AS (
		SELECT DISEASE,
		SUM(NEW_CASES) AS TOTAL_CASES,
		SUM(DEATHS) AS TOTAL_DEATHS
		FROM ANIMAL_HEALTH_REPORT WHERE YEAR >= 2011
		GROUP BY DISEASE
			 )
	SELECT *, CAST((TOTAL_DEATHS/TOTAL_CASES)*100 AS DEC(3,1)) AS CFR
	FROM CTE_SUMS
	ORDER BY TOTAL_CASES DESC

	--A LOOK AT THE LIST OF REPORTED DISEASES IN 2020-2021 ALONE

	SELECT DISTINCT(DISEASE),
	SUM(NEW_CASES) OVER (PARTITION BY DISEASE) AS TOTAL_CASES,
	SUM(DEATHS) OVER (PARTITION BY DISEASE) AS TOTAL_DEATHS
	FROM ANIMAL_HEALTH_REPORT
	WHERE YEAR IN (2020, 2021)
	ORDER BY 2 DESC;

--IV. TOTAL NUMBER OF DOMESTIC ANIMALS KILLED AND DISPOSED OF, SLAUGHTERED,
-- AND DIED DUE TO DISEASES, BY REGION, SINCE 2005

	SELECT WORLD_REGION, 
	SUM(KILLED_AND_DISPOSED_OF) AS KILLED_AND_DISPOSED_OF, 
	SUM(SLAUGHTERED) AS SLAUGHTERED, SUM(DEATHS) AS DIED
	FROM ANIMAL_HEALTH_REPORT
	GROUP BY WORLD_REGION
	ORDER BY 2 DESC;

	-- A LOOK AT THESE NUMBERS BY YEAR

	SELECT YEAR, WORLD_REGION, 
	SUM(KILLED_AND_DISPOSED_OF) KILLED_AND_DISPOSED_OF, 
	SUM(SLAUGHTERED) SLAUGHTERED, SUM(DEATHS) DIED
	FROM ANIMAL_HEALTH_REPORT
	GROUP BY YEAR, WORLD_REGION
	ORDER BY 1 DESC;

	-- CREATE A BETTER VIEW OF THE PREVIOUS QUERY FOR VIEWING PURPOSES ONLY
			
	CREATE VIEW ANIMAL_DEATHS_BY_REGION AS
	WITH CTE AS (SELECT YEAR,
	WORLD_REGION, SUM(KILLED_AND_DISPOSED_OF) KILLED_AND_DISPOSED_OF, 
	SUM(SLAUGHTERED) SLAUGHTERED, SUM(DEATHS) DIED,
		CASE
			WHEN LAG(YEAR, 1) OVER (PARTITION BY YEAR ORDER BY YEAR DESC ) =   -- WILL SKIP THE NEXT YEAR
			LAG(YEAR, 1) OVER (PARTITION BY YEAR ORDER BY YEAR DESC ) THEN ' ' -- WHEN THE PREVIOUS YEAR 
			ELSE YEAR														   -- IS THE SAME
		END AS YEAR_IN
	FROM ANIMAL_HEALTH_REPORT
	GROUP BY YEAR, WORLD_REGION)
	SELECT YEAR_IN AS YEAR, WORLD_REGION, KILLED_AND_DISPOSED_OF, SLAUGHTERED, DIED
	FROM CTE;

	SELECT * FROM ANIMAL_DEATHS_BY_REGION;

--V. LIST OF DOMESTIC ANIMALS AFFECTED BY SARS-COV-2

	SELECT SPECIES, SUM(NEW_CASES) AS TOTAL_CASES, 
	SUM(NEW_OUTBREAKS) AS NEW_OUTBREAKS
	FROM ANIMAL_HEALTH_REPORT
	WHERE DISEASE LIKE '%SARS-CoV-2%'
	GROUP BY SPECIES
	ORDER BY 2 DESC

	-- DOMESTIC ANIMAL MOST SUSCEPITBLE TO SARS-COV-2

	SELECT TOP 1 SPECIES, 
	SUM(SUSCEPTIBLE) AS TOTAL_SUSCEPTIBLE 
	FROM ANIMAL_HEALTH_REPORT
	WHERE DISEASE LIKE '%SARS-CoV-2%'
	GROUP BY SPECIES
	ORDER BY 2 DESC

--VI. SARS-COV-2 GLOBAL NUMBERS AMONG DOMESTIC ANIMALS BY YEAR

	SELECT YEAR, SUM(NEW_CASES) CASES, SUM(NEW_OUTBREAKS) NEW_OUTBREAKS, 
	SUM(KILLED_AND_DISPOSED_OF) KILLED_AND_DISPOSED_OF, 
	SUM(SLAUGHTERED) SLAUGHTERED, SUM(DEATHS) DIED
	FROM ANIMAL_HEALTH_REPORT
	WHERE DISEASE LIKE '%SARS-COV-2%'
	GROUP BY YEAR
	ORDER BY YEAR DESC

	-- SARS-COV-2 GLOBAL NUMBERS AMONG DOMESTIC ANIMALS BY REGION
			
	SELECT WORLD_REGION, SUM(NEW_CASES) TOTAL_CASES,
	SUM(KILLED_AND_DISPOSED_OF) KILLED_AND_DISPOSED_OF, 
	SUM(SLAUGHTERED) SLAUGHTERED, SUM(DEATHS) DIED,
	CAST(SUM(DEATHS)/SUM(NEW_CASES)*100 AS DEC(3,1)) AS CFR
	FROM ANIMAL_HEALTH_REPORT
	WHERE DISEASE LIKE '%SARS-COV-2%'
	GROUP BY WORLD_REGION
	ORDER BY 2 DESC
	
---C. PARTIAL DATA EXPLORATION FOR REPORTED DISEASES AMONG DOGS

--I. TOTAL NUMBER OF DOGS KILLED AND DISPOSED OF, SLAUGHTERED,
-- OR DIED DUE TO DISEASES BY YEAR

	SELECT YEAR, 
	SUM(KILLED_AND_DISPOSED_OF) KILLED_AND_DISPOSED_OF, 
	SUM(SLAUGHTERED) SLAUGHTERED, SUM(DEATHS) DEATHS
	FROM ANIMAL_HEALTH_REPORT
	WHERE SPECIES LIKE '%DOGS%'
	GROUP BY YEAR
	ORDER BY 1 DESC

	-- TOTAL NUMBER OF DOGS THAT LOST THEIR LIVES DUE TO DISEASE BY REGION

	SELECT WORLD_REGION, 
	SUM(KILLED_AND_DISPOSED_OF + SLAUGHTERED + DEATHS) AS TOTAL_LIVES_LOST
	FROM ANIMAL_HEALTH_REPORT
	WHERE SPECIES LIKE '%DOGS%'
	GROUP BY WORLD_REGION
	ORDER BY TOTAL_LIVES_LOST DESC

--II. MOST FREQUENT DISEASE AMONG DOGS BASED ON
--   NUMBER OF REPORTED CASES OVER THE LAST 10 YEARS

	SELECT TOP 1 DISEASE, SUM(NEW_CASES) TOTAL_CASES
	FROM ANIMAL_HEALTH_REPORT
	WHERE SPECIES LIKE '%DOGS%' AND YEAR >= 2011
	GROUP BY DISEASE
	ORDER BY TOTAL_CASES DESC
							
					--- OR ---
			
	WITH CTE AS (
		SELECT DISEASE, SUM(NEW_CASES) TOTAL_CASES
		FROM ANIMAL_HEALTH_REPORT
		WHERE SPECIES LIKE '%DOGS%' AND YEAR >= 2011
		GROUP BY DISEASE
				)
	SELECT DISEASE, TOTAL_CASES FROM CTE
	WHERE TOTAL_CASES = (SELECT MAX(TOTAL_CASES) FROM CTE)

--III. LIST OF REPORTED DISEASES AMONG DOGS IN 2020-2021
			
	SELECT DISTINCT(DISEASE), 
	SUM(NEW_CASES) OVER (PARTITION BY DISEASE) TOTAL_CASES,
	SUM(NEW_OUTBREAKS) OVER (PARTITION BY DISEASE) NEW_OUTBREAKS
	FROM ANIMAL_HEALTH_REPORT
	WHERE SPECIES LIKE '%DOGS%' AND YEAR IN (2020, 2021)
	ORDER BY TOTAL_CASES DESC

--IV. COMPARE SARS-COV-2 WITH RABIES VIRUS AMONG DOGS IN 2020-2021

	SELECT DISEASE,
	SUM(NEW_CASES) AS TOTAL_CASES,
	SUM(NEW_OUTBREAKS) AS NEW_OUTBREAKS,
	SUM(DEATHS) AS TOTAL_DEATHS,
	CAST(SUM(DEATHS)/SUM(NEW_CASES)*100 AS DEC(3,1)) AS CFR
	FROM ANIMAL_HEALTH_REPORT
	WHERE (YEAR IN (2020, 2021) AND SPECIES LIKE '%DOGS%') AND
	(DISEASE LIKE '%Rabies virus%' OR DISEASE LIKE '%SARS-CoV-2%') AND
	(NEW_CASES <> 0)
	GROUP BY DISEASE			

--V. SARS-COV-2 OVERVIEW AMONG DOGS BY YEAR
			
	SELECT YEAR,
	SUM(NEW_CASES) AS TOTAL_CASES,
	SUM(DEATHS) AS TOTAL_DEATHS,
	CAST(SUM(DEATHS)/SUM(NEW_CASES)*100 AS DEC(3,1)) AS CFR
	FROM ANIMAL_HEALTH_REPORT
	WHERE SPECIES LIKE '%DOGS%' AND DISEASE LIKE '%SARS-COV-2%'
	GROUP BY YEAR
	ORDER BY CFR DESC

--E. CASE FATALITY RATE FOR SARS-COV-2 AMONG DOGS BY COUNTRY
			
	SELECT COUNTRY,
	SUM(NEW_CASES) AS TOTAL_CASES,
	SUM(DEATHS) AS TOTAL_DEATHS,
	CAST(SUM(DEATHS)/SUM(NEW_CASES)*100 AS DEC(3,1)) AS CFR
	FROM ANIMAL_HEALTH_REPORT
	WHERE SPECIES LIKE '%DOGS%' AND DISEASE LIKE '%SARS-COV-2%'
	GROUP BY COUNTRY
	ORDER BY CFR DESC

	-- COUNTRY WITH THE GREATEST CFR FOR SARS-COV-2 AMONG DOGS

	SELECT TOP 1 COUNTRY,
	SUM(NEW_CASES) AS TOTAL_CASES,
	SUM(DEATHS) AS TOTAL_DEATHS,
	CAST(SUM(DEATHS)/SUM(NEW_CASES)*100 AS DEC(3,1)) AS CFR
	FROM ANIMAL_HEALTH_REPORT
	WHERE SPECIES LIKE '%DOGS%' AND DISEASE LIKE '%SARS-COV-2%'
	GROUP BY COUNTRY
	ORDER BY CFR DESC


											--- END ---
