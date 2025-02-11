/**************************************************************************************************
Title: Attainment of qualification
Author: Simon Anastasiadis
Reviewer: Joel Bancolita

Inputs & Dependencies:
- [IDI_Clean].[cen_clean].[census_individual]
- [IDI_Clean].[moe_clean].[student_qualification]
- [IDI_Clean].[moe_clean].[completion]
- [IDI_Clean].[moe_clean].[tec_it_learner]
Outputs:
- [IDI_UserCode].[DL-MAA2023-20].[defn_qualification_awards]
- [IDI_Sandpit].[DL-MAA2023-20].[defn_highest_qual]
- [IDI_UserCode].[DL-MAA2023-20].[defn_qualification_spell_quarters]

Description:
[defn_qualification_awards] is attainment of qualification (or our best approximation of).

[defn_highest_qual] is a persons highest qualification (or approximation of) in a spell-based format. This may be convenient when using the assembly tool and needing to preserve 

[defn_qualification_spell_quarters] is a spell-based format with start and end dates aligned with quarters. 
This may be convenient if reporting quarterly as it only attributes a person one qualificaiton (their highest) during a quarter

Intended purpose:
Identifying people's highest qualification at a point in time ([IDI_Sandpit].[project schema].[defn_highest_qual])
Identifying when people have been awared qualifications (requires removal of Census data) ([IDI_UserCode].[project schema].[qualification_awarded])
 
Notes:
1) Where only year is available assumed qualification awarded 1st December (approx, end of calendar year).
2) Code guided by Population Explorer Highest Qualification code in SNZ Population Explorer by Peter Elis
   github.com/StatisticsNZ/population-explorer/blob/master/build-db/01-int-tables/18-qualificiations.sql
3) Qualifications reported from Census 2013 have been added, as without only qualifications earned recently
   are reported which results in an under count. As Census does not report date of award/qualification
   we use December in 18th year of life as proxy for award date of secondary school degrees, and 
   date of Census 2013 as proxy for aware of post-secondary school degrees.
   The same process has been followed for Census 2018.
4) Numeric values are NZQA levels:
	1 = Certificate or NCEA level 1
	2 = Certificate or NCEA level 2
	3 = Certificate or NCEA level 3
	4 = Certificate level 4
	5 = Certificate of diploma level 5
	6 = Certificate or diploma level 6
	7 = Bachelors degree, graduate diploma or certificate level 7
	8 = Bachelors honours degree or postgraduate diploma or certificate level 8
	9 = Masters degree
	10 = Doctoral degree
	-1 = International qualification (recoded from 11. This means that any New Zealand qualification earned will supercede this, on the assumption that a person is unlikely to subsequently obtain a signficiantly lower qual)


Parameters & Present values:
  Current refresh = 202210
  Prefix = defn_
  Project schema = [DL-MAA2023-20]
 
Issues:
 
History (reverse order):
2023-05-16 DY updated to produce a second table in spell based format and a view of the highest qual during a quarter
2023-05-11 DY updated with secondary via school leavers to match Github coverage.
2022-05-20 JG updated with provider code for entity count
2022-04-05 JG Updated project and refresh for Data for Communities
2020-07-22 JB QA
2020-03-02 SA v1
**************************************************************************************************/
/* 
Takes about 7 minutes for 9 quarters and then about 5 minutes to update the master table. If this is too long, could potentially get speed improvement by either applying filters to when quals were awarded (less useful if using recent dates) 
 or by turning into spells with higher quals replacing lower level ones 
*/

/* Establish database for writing views */
USE IDI_UserCode
GO

/* Clear view */
IF OBJECT_ID('[DL-MAA2023-20].[defn_qualification_awards]','V') IS NOT NULL
DROP VIEW [DL-MAA2023-20].[defn_qualification_awards];
GO

CREATE VIEW [DL-MAA2023-20].[defn_qualification_awards] AS

-- Census 2018 highest qualification
SELECT [snz_uid]
	  ,NULL AS provider_code
	  ,'2018-03-06' AS [event_date]
      ,CASE WHEN [cen_ind_standard_hst_qual_code] = '11' THEN -1 ELSE [cen_ind_standard_hst_qual_code] END AS [qualification_level]
	  ,'cen2018' AS [source]
FROM [IDI_Clean_202210].[cen_clean].[census_individual_2018]
WHERE [cen_ind_standard_hst_qual_code] IN ('01', '02', '03', '04', '05', '06', '07', '08', '09', '10','11')
--AND [cen_ind_standard_hst_qual_code] <> [cen_ind_scdry_scl_qual_code]

UNION ALL

-- Census 2013 highest qualification
SELECT [snz_uid]
	,NULL AS provider_code
	,'2013-03-05' AS [event_date]
	,CASE WHEN cen_ind_std_highest_qual_code = '11' THEN -1 ELSE cen_ind_std_highest_qual_code END AS [qualification_level]
	,'cen2013' AS [source]
FROM [IDI_Clean_202210].[cen_clean].[census_individual_2013]
WHERE cen_ind_std_highest_qual_code IN ('01', '02', '03', '04', '05', '06', '07', '08', '09', '10','11')
--AND cen_ind_std_highest_qual_code <> cen_ind_sndry_scl_qual_code

UNION ALL

-- Primary and secondary
SELECT snz_uid
		,CAST([moe_sql_iss_provider_code] AS int) AS provider_code
		,DATEFROMPARTS(moe_sql_attained_year_nbr,12,1) AS [event_date]
		,moe_sql_nqf_level_code AS [qualification_level]
		,'second' AS [source]
FROM [IDI_Clean_202210].[moe_clean].[student_qualification]
WHERE moe_sql_nqf_level_code IS NOT NULL
AND moe_sql_nqf_level_code IN (1,2,3,4,5,6,7,8,9,10) -- limit to 10 levels of NZQF

UNION ALL

---- Secondary via school leavers 
SELECT [snz_uid]
		,CAST(moe_sl_provider_code AS int) AS provider_code
		,DATEFROMPARTS([moe_sl_leaver_year],12,1) AS [event_date]
		--,[moe_sl_leaver_year]
		--,[moe_sl_leaving_yr_lvl]
		--,[moe_sl_leaving_reason_code]
		--,[moe_sl_highest_attain_code]
		,CASE
			WHEN [moe_sl_highest_attain_code] IN (13,14,15,16,17
													--,20,55
													,60,70,80,90) THEN 1 -- 20 and 55 record 1-13 credits and 30+ at level 2 or above
			WHEN [moe_sl_highest_attain_code] IN (4,24,25,26,27
													--,30,56
													,61,71,81,91) THEN 2 -- 30 and 56 record 1-13 credits and 30+ at level 3 or above
			WHEN [moe_sl_highest_attain_code] IN (33,34,35,36,37,40
													--,43
													,62,72,82,92) THEN 3 -- 43 records national certificate at level 4
			WHEN [moe_sl_highest_attain_code] IN (43) THEN 4
			ELSE NULL END AS [qualification_level]
		,'leavers' AS [source]
FROM [IDI_Clean_202210].[moe_clean].[student_leavers]
WHERE [moe_sl_eligibility_code] = 'DOMESTIC'
AND [moe_sl_leaving_yr_lvl] BETWEEN 12 AND 16
AND (
		[moe_sl_highest_attain_code] IN (13,14,15,16,17
										--,20,55
										,60,70,80,90)
		OR [moe_sl_highest_attain_code] IN (4,24,25,26,27
										--,30,56
										,61,71,81,91)
		OR [moe_sl_highest_attain_code] IN (33,34,35,36,37,40,43,62,72,82,92)
)

UNION ALL

-- Tertiary qualification
SELECT snz_uid
		,CAST([moe_com_provider_code] AS int) AS provider_code
		,DATEFROMPARTS(moe_com_year_nbr,12,1) AS [event_date]
		,moe_com_qual_level_code AS [qualification_level]
		,'tertiary' AS [source]
FROM [IDI_Clean_202210].[moe_clean].[completion]
WHERE moe_com_qual_level_code IS NOT NULL
AND moe_com_qual_level_code IN (1,2,3,4,5,6,7,8,9,10) -- limit to 10 levels of NZQF

UNION ALL

-- Industry training qualifications
SELECT snz_uid
		,CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
		,moe_itl_end_date AS [event_date]
		,1 AS [qualification_level]
		,'industry' AS [source]
FROM [IDI_Clean_202210].moe_clean.tec_it_learner
WHERE moe_itl_end_date IS NOT NULL
AND moe_itl_level1_qual_awarded_nbr > 0

UNION ALL

SELECT snz_uid
		,CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
		,moe_itl_end_date AS [event_date]
		,2 AS [qualification_level]
		,'industry' AS [source]
FROM [IDI_Clean_202210].moe_clean.tec_it_learner
WHERE moe_itl_end_date IS NOT NULL
AND moe_itl_level2_qual_awarded_nbr > 0

UNION ALL

SELECT snz_uid
		,CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
		,moe_itl_end_date AS [event_date]
		,3 AS [qualification_level]
		,'industry' AS [source]
FROM [IDI_Clean_202210].moe_clean.tec_it_learner
WHERE moe_itl_end_date IS NOT NULL
AND moe_itl_level3_qual_awarded_nbr > 0

UNION ALL

SELECT snz_uid
		,CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
		,moe_itl_end_date AS [event_date]
		,4 AS [qualification_level]
		,'industry' AS [source]
FROM [IDI_Clean_202210].moe_clean.tec_it_learner
WHERE moe_itl_end_date IS NOT NULL
AND moe_itl_level4_qual_awarded_nbr > 0

UNION ALL

SELECT snz_uid
		,CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
		,moe_itl_end_date AS [event_date]
		,5 AS [qualification_level]
		,'industry' AS [source]
FROM [IDI_Clean_202210].moe_clean.tec_it_learner
WHERE moe_itl_end_date IS NOT NULL
AND moe_itl_level5_qual_awarded_nbr > 0

UNION ALL

SELECT snz_uid
		,CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
		,moe_itl_end_date AS [event_date]
		,6 AS [qualification_level]
		,'industry' AS [source]
FROM [IDI_Clean_202210].moe_clean.tec_it_learner
WHERE moe_itl_end_date IS NOT NULL
AND moe_itl_level6_qual_awarded_nbr > 0

UNION ALL

SELECT snz_uid
		,CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
		,moe_itl_end_date AS [event_date]
		,7 AS [qualification_level]
		,'industry' AS [source]
FROM [IDI_Clean_202210].moe_clean.tec_it_learner
WHERE moe_itl_end_date IS NOT NULL
AND moe_itl_level7_qual_awarded_nbr > 0

UNION ALL

SELECT snz_uid
		,CAST([moe_itl_ito_edumis_id_code] AS int) AS provider_code
		,moe_itl_end_date AS [event_date]
		,8 AS [qualification_level]
		,'industry' AS [source]
FROM [IDI_Clean_202210].moe_clean.tec_it_learner
WHERE moe_itl_end_date IS NOT NULL
AND moe_itl_level8_qual_awarded_nbr > 0;
GO



/*****************************************************************************************************************************************************************/

/* Produce entity table - may not be required as multisource */


DROP TABLE IF EXISTS [IDI_Sandpit].[DL-MAA2023-20].qual_level_ENT

SELECT DISTINCT snz_uid
		,[provider_code] AS entity_1
		,[quarter]
INTO [IDI_Sandpit].[DL-MAA2023-20].qual_level_ENT
FROM #quals
/* Add index */
CREATE CLUSTERED INDEX my_index_name ON [IDI_Sandpit].[DL-MAA2023-20].qual_level_ENT (snz_uid);
GO
/* Compress final table to save space */
ALTER TABLE [IDI_Sandpit].[DL-MAA2023-20].qual_level_ENT REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE);
GO


/* Update our master table - drop any existing columns to be overwritten, append on new columns, and insert values*/

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-20].[master_table] DROP COLUMN IF EXISTS [qual_level__1_3],
															COLUMN IF EXISTS [qual_level__4_6], 
															COLUMN IF EXISTS [qual_level__7_10];

ALTER TABLE [IDI_Sandpit].[DL-MAA2023-20].[master_table] ADD [qual_level__1_3] smallint,
															[qual_level__4_6] smallint,
															[qual_level__7_10] smallint;

UPDATE
	[IDI_Sandpit].[DL-MAA2023-20].[master_table]
SET
	[qual_level__1_3] = qual.[qual_level__1_3],
	[qual_level__4_6] = qual.[qual_level__4_6],
	[qual_level__7_10] = qual.[qual_level__7_10]

FROM 
	#quals qual
	WHERE [IDI_Sandpit].[DL-MAA2023-20].[master_table].snz_uid = qual.snz_uid
	AND [IDI_Sandpit].[DL-MAA2023-20].[master_table].[quarter] = qual.[quarter];


-- Clean up 
IF OBJECT_ID('[DL-MAA2023-20].[defn_qualification_awards]','V') IS NOT NULL
DROP VIEW [DL-MAA2023-20].[defn_qualification_awards];
GO
DROP TABLE IF EXISTS #quals
