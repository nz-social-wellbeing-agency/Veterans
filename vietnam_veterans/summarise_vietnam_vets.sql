/****** Summarise Vietnam Veterans

Script prepared by: Dan Young 31-01-2024

This script takes our cleaned the Vietnam Veterans dataset and joins to our veterans definition. We then produce summaries
for the purpose of understanding how we performed in identifying these people in our main analysis of veterans.

In particular, we produce the following summaries:
(i) Count of Vietnam veterans by inclusion within our (general) population defintion
(ii) Count of Vietnam veterans by source found in (ie, if we identified them as veteran, the kind of data (occupation, 
		industry, pension or employment) we used to identify them)
(iii) Count of Vietnam veterans by age
(iv) Count of Vietnam veterans by sex/gender
(v) Count of Vietnam veterans by ethnicity


Output tables:
 - containing snz_uids associated with the Vietnam veterans

Input tables used:
[IDI_Sandpit].[DL-MAA2023-20].[Vietnam_snz_uids_clean] - see Tidy Vietnam Veterans Population.sql
[IDI_Clean_202210].[msd_clean].[msd_swn]
[IDI_Clean_202210].[security].[concordance]


******/

/*** 1) Summary of data ***/

-- Join onto population definition to create our res_pop indicator, and onto personal_details to pick up the spine indicator

DROP TABLE IF EXISTS #pop21_prec_1;
SELECT vet.snz_uid
		,CASE WHEN res_pop_2021 = 1 THEN 1 ELSE 0 END as res_pop_2021
		,pd.snz_spine_ind
INTO #pop21_prec_1
FROM [IDI_Sandpit].[DL-MAA2023-20].[Vietnam_snz_uids_clean] vet
LEFT JOIN (SELECT snz_uid, 1 AS res_pop_2021 FROM [IDI_Sandpit].[DL-MAA2023-20].cw_202210_res_pop WHERE YEAR([start_date]) <= 2021 AND YEAR([end_date]) >= 2021 GROUP BY snz_uid) pop
ON vet.snz_uid = pop.snz_uid
LEFT JOIN [IDI_Clean_202210].[data].[personal_detail] pd
ON pd.snz_uid = vet.snz_uid;

-- note that this is identifying everyone in our table. We cut later by resident_population and identified
-- however, what we don't use is the 'veteran_1_year_2021 indicator' - so if any are still employed in the military, they would be included
-- in the summary as 'identified by our indicator', but our business rules would mean they were not identified as a veteran in our other output.
DROP TABLE IF EXISTS #pop21
SELECT pop.* 
		,CASE WHEN vet.ided IS NULL THEN 0 ELSE vet.ided END AS identified
		,CASE WHEN vet.veteran_1_year_2021 IS NULL THEN 0 ELSE vet.veteran_1_year_2021 END as veteran_1_year_2021
INTO #pop21
FROM #pop21_prec_1 pop
LEFT JOIN (SELECT snz_uid, 1 AS ided, veteran_1_year_2021 FROM [IDI_Sandpit].[DL-MAA2023-20].[veterans_all] GROUP BY snz_uid,veteran_1_year_2021) vet
ON vet.snz_uid = pop.snz_uid;

DROP TABLE IF EXISTS #pop21_prec_1;

-- summarise the sources we identified veterans by 
DROP TABLE IF EXISTS #sources;
WITH reconciled AS (
			SELECT [snz_uid]
					  ,[occ_cen13]
					  ,[occ_cen18]
					  ,[occ_hlfs]
					  ,[occ_gss]
					  ,[occ_acc]
					  ,[occ_immig]
					  ,[occ_journey]
					  ,[occ_birth]
					  ,[occ_marriage]
					  ,[occ_civil]
					  ,[occ_death]
					  ,[occ_hospital]
					  ,[ind_cen13]
					  ,[ind_cen18]
					  ,[ind_hlfs]
					  ,[msd_pension]
					  ,[first_t1]
					  ,[msd_supplementary]
					  ,[first_t2]
					  ,[msd_lumpsum]
					  ,[first_t3]
					  ,[msd_anypayment]
					  ,[ir_prevemployee]
					  ,[ir_currentemployee]
					,CASE WHEN occ_any IS NULL THEN 0 ELSE 1 END AS occ_any
					,CASE WHEN ind_cen13 is NULL AND ind_cen18 IS NULL AND ind_hlfs IS NULL THEN 0 ELSE 1 END AS ind_any
					,CASE WHEN msd_anypayment IS NULL THEN 0 ELSE 1 END AS pen_any
					,CASE WHEN ir_prevemployee IS NULL AND ir_currentemployee IS NULL THEN 0 ELSE 1 END AS emp_any
			FROM [IDI_Sandpit].[DL-MAA2023-20].[veterans_all]
			)
SELECT snz_uid
		,CASE WHEN occ_any+ind_any+pen_any+emp_any >=3 THEN 'Three or more sources'
				WHEN occ_any + ind_any = 2 THEN  'Occupation and industry'
				WHEN occ_any + pen_any = 2 THEN 'Occupation and Pensions'
				WHEN occ_any + emp_any = 2 THEN 'Occupation and employees'
				WHEN ind_any+pen_any = 2 THEN 'Industry and pensions'
				WHEN ind_any+emp_any = 2 THEN 'Industry and employee'
				WHEN pen_any+emp_any = 2 THEN 'Employee and pensions'
				WHEN occ_any = 1 THEN 'Only occupation'
				WHEN ind_any = 1 THEN 'Only industry'
				WHEN pen_any = 1 THEN 'Only pensions'
				WHEN emp_any = 1 THEN 'Only employees'
				ELSE 'Not found' END AS sources
INTO #sources
FROM reconciled


/*** 2) Start of summary ***/

-- identify where there were people not included in our group due to the population defintiion
-- NB population definition requires spine = 1
SELECT vet.res_pop_2021
		,'population definition' AS col1
		,CASE WHEN res_pop_2021 = 1 THEN 'In population' 
				WHEN res_pop_2021 = 0 AND snz_spine_ind = 0 THEN 'Not on spine'
				WHEN res_pop_2021 = 0 THEN 'Not in population' 
				ELSE 'Error' END AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
GROUP BY res_pop_2021,
			CASE WHEN res_pop_2021 = 1 THEN 'In population' 
				WHEN res_pop_2021 = 0 AND snz_spine_ind = 0 THEN 'Not on spine'
				WHEN res_pop_2021 = 0 THEN 'Not in population' 
				ELSE 'Error' END 

UNION

-- produce a summary that is aligned with our previous output
SELECT vet.res_pop_2021
		,'identified and veteran_1_year_2021' AS col1
		,CONCAT(cast(identified AS varchar),'-',cast(veteran_1_year_2021 AS varchar)) AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
GROUP BY res_pop_2021,CONCAT(cast(identified AS varchar),'-',cast(veteran_1_year_2021 AS varchar))

UNION


-- identify the source that identified Vietnam Veterans
SELECT vet.res_pop_2021
		,'Source' AS col1
		,sour.sources val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
LEFT JOIN #sources sour
ON vet.snz_uid = sour.snz_uid
WHERE vet.res_pop_2021 = 1
GROUP BY res_pop_2021,sour.sources

UNION

-- Age (5 year bands)

SELECT vet.res_pop_2021
		,'Age' AS col1
		,CASE WHEN 2021 - snz_birth_year_nbr >= 90 THEN '90+' ELSE CAST (2021 - snz_birth_year_nbr AS varchar) END AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
LEFT JOIN IDI_Clean_202210.data.personal_detail pd
ON vet.snz_uid = pd.snz_uid
WHERE vet.res_pop_2021 = 1
GROUP BY res_pop_2021, CASE WHEN 2021 - snz_birth_year_nbr >= 90 THEN '90+' ELSE CAST (2021 - snz_birth_year_nbr AS varchar) END

UNION


-- Sex/gender 

SELECT res_pop_2021
		,'Sex' AS col1
		,CAST(snz_sex_gender_code AS varchar) AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
LEFT JOIN IDI_Clean_202210.data.personal_detail pd
ON vet.snz_uid = pd.snz_uid
WHERE vet.res_pop_2021 = 1
GROUP BY res_pop_2021,snz_sex_gender_code

UNION

-- Ethnicity
SELECT res_pop_2021
		,'European' AS col1
		,CAST(snz_ethnicity_grp1_nbr AS varchar) AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
LEFT JOIN IDI_Clean_202210.data.personal_detail pd
ON vet.snz_uid = pd.snz_uid
WHERE vet.res_pop_2021 = 1
GROUP BY res_pop_2021,snz_ethnicity_grp1_nbr

UNION

SELECT res_pop_2021
		,'Maori' AS col1
		,CAST(snz_ethnicity_grp2_nbr AS varchar) AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
LEFT JOIN IDI_Clean_202210.data.personal_detail pd
ON vet.snz_uid = pd.snz_uid
WHERE vet.res_pop_2021 = 1
GROUP BY res_pop_2021,snz_ethnicity_grp2_nbr

UNION

SELECT res_pop_2021
		,'Pacific' AS col1
		,CAST(snz_ethnicity_grp3_nbr AS varchar) AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
LEFT JOIN IDI_Clean_202210.data.personal_detail pd
ON vet.snz_uid = pd.snz_uid
WHERE vet.res_pop_2021 = 1
GROUP BY res_pop_2021,snz_ethnicity_grp3_nbr

UNION

SELECT res_pop_2021
		,'Asian' AS col1
		,CAST(snz_ethnicity_grp4_nbr AS varchar) AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
LEFT JOIN IDI_Clean_202210.data.personal_detail pd
ON vet.snz_uid = pd.snz_uid
WHERE vet.res_pop_2021 = 1
GROUP BY res_pop_2021,snz_ethnicity_grp4_nbr

UNION

SELECT res_pop_2021
		,'MELAA' AS col1
		,CAST(snz_ethnicity_grp5_nbr AS varchar) AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
LEFT JOIN IDI_Clean_202210.data.personal_detail pd
ON vet.snz_uid = pd.snz_uid
WHERE vet.res_pop_2021 = 1
GROUP BY res_pop_2021,snz_ethnicity_grp5_nbr

UNION

SELECT res_pop_2021
		,'Other' AS col1
		,CAST(snz_ethnicity_grp6_nbr AS varchar) AS val1
		,COUNT(DISTINCT vet.snz_uid) n
FROM #pop21 vet
LEFT JOIN IDI_Clean_202210.data.personal_detail pd
ON vet.snz_uid = pd.snz_uid
WHERE vet.res_pop_2021 = 1
GROUP BY res_pop_2021,snz_ethnicity_grp6_nbr


