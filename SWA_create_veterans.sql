/* 
Creation of veterans population

This code is used to identify potential veterans in the IDI data, in order to explore various social outcomes for this target group.
The intention is to analyse veterans in both 2019 and 2021.
This will be subsequently joined to various indicators, and summarised.


This includes potential identification through several mechanisms:
1. Occupation data:
	1a. Census 2013
	1b. Census 2018
	1c. HLFS 2009-2022
	1d. GSS 2014, 2016, 2018, 2021
	1e. ACC claims
	1f. Customs journey data
	1g. MBIE immigration data
	1h. DIA (births, deaths, marriages, civil unions)
	1i. Hospital admissions
2. IR data (receiving income from NZDF)
3. Veterans Pension payments from MSD
4. Border crossing data (having border crossings that are consistent with active service deployment) 

This produces the table [IDI_Sandpit].[Proj_schema].[veterans_population] with the following columns. There are other tables also produced for temporary/checking purposes:
	snz_uid
-- Occupation identification
	occ_cen13 - identified as veteran due to stated occupation in census 2013
	occ_cen18 - identified as veteran due to stated occupation in census 2018
	occ_hlfs - identified as veteran due to stated occupation in hlfs survey
	occ_gss - identified as veteran due to stated occupation in gss survey
	occ_acc - identified as veteran due to stated occupation in acc claim data
	occ_immig  - identified as veteran due to stated occupation in visa application (not expecting huge numbers)
	occ_journey - identified as veteran due to stated occupation in border crossing data
	occ_birth - identified as veteran due to stated occupation as parent of child in birth records
	occ_marriage - identified as veteran due to stated occupation in marriage records
	occ_civil - identified as veteran due to stated occupation in civil union records
	occ_death - identified as veteran due to stated occupation in death records (note: can use timing/absence of IRD payments data to help determine timing - eg, when last payment made, before data series began, etc)
	occ_hospital - identified as veteran due to stated occupation in hospitalisation data
	occ_any - identified as veteran due to stated occupation in any of the occupation datasets
-- Industry identification
	ind_cen13 - identified as veteran due to stated industry of employment in census 2013
	ind_cen18 - identified as veteran due to stated industry of employment in census 2018
	ind_hlfs - identified as veteran due to stated industry of employment in HLFS
-- Pension identification
	msd_pension - recipient of veterans pension
	first_t1 - date of first receipt of veteran's pension
	msd_supplementary - reciept of supplementary benefits coded as related to Vietnam, Gallantry Award, Pension Under Section 55, 1939/45 War, War Medical Treatment - UK Pensioner
	first_t2 - date of first receipt of supplementary payment
	msd_lumpsum - reciept of lump sum payment coded as War Travel Concessions, War Surgical Appliances, War 11 Assessment, War Medical Treatment - NZ Pensioner, War Medical Treatment - UK Pensioner, War Medical Treatment - AUS Pensioner
	first_t3 - date of first receipt of supplementary payment
	msd_anypayment - flag for recipet of any pension/supplementary/lump sum
-- Employment ('IRD data') identification
	ir_prevemployee - identifies persons who had not received a payment from Defence within the last year of the data (1 = last payment before May 2021, 0 = last payment after, null = no data)
	ir_currentemployee - persons who received a payment from Defence within the last year of the data (from May 2021 onwards) (1 = yes, 0 = last payment was before then, null = no data)
-- Categorisation
	veteran_2019 -- persons who did not receive a payment from Defence (as recorded in IR data) from 1 Jan 2019 onwards
	veteran_1_year_2019 -- persons who did not receive a payment from Defence (as recorded in IR data) from 1 Jan 2018 onwards - ie, had left service for at least a year in 2019
	veteran_2021 -- persons who did not receive a payment from Defence (as recorded in IR data) from 1 Jan 2021 onwards
	veteran_1_year_2021 -- persons who did not receive a payment from Defence (as recorded in IR data) from 1 Jan 2020 onwards - ie, had left service for at least a year in 2021


Inputs (we used the October 2022 refresh):
	[hlfs_clean].[data]
	[gss_clean].[gss_person]
	[gss_clean].[gss_person_2021]
	[acc_clean].[claims]
	[cus_clean].[journey]
	[dol_clean].[occupations]
	[dol_clean].[decisions]
	[dia_clean].[births]
	[dia_clean].[civil_unions]
	[dia_clean].[marriages]
	[dia_clean].[deaths]
	[moh_clean].[pub_fund_hosp_discharges_event]
	[ir_clean].[ird_ems]
	[msd_clean].[msd_first_tier_expenditure]
	[msd_clean].[msd_second_tier_expenditure]
	[msd_clean].[msd_third_tier_expenditure]

Inputs from elsewhere: 
	We used the following inputs, which were freetext occupation descriptions from dia and moh datasets. We identified the occupations that we considered were indicative of veteran status.
	[IDI_Sandpit].[Proj_schema].[dy_dia] 
	[IDI_Sandpit].[Proj_schema].[dy_moh] 

Nb. The project schema reference when saving tables has been replaced with proj_schema - find and replace before running.


Changelog:

2022-12-08	CW	Initial creation
2022-01-13	AW	Tidy and re-format; add in occupation from other stats surveys
2023-05-19 DY combined into single table with first instance of identification. Saved as v4
2023-07-01-> DY updated list of pensions, constructed new output table to focus on 2019 and 2021 veteran population, and on source of information for various indicators (pensions mainly)

*/


/*
1. Occupation data 
*/

/* 1a Census 2013 
This codes occupation to ANZSCO 2006 classifications. These codes are equivalent to ANZSCO 2013/v1.2 classifications, at least as far as the armed forces are concerned. 
The 2013 Census stores occupation only at the 6 digit level, so the codes we are interested in are: 
--111212	Defence Force Senior Officer
--139111	Commissioned Defence Force Officer
--139211	Senior Non-commissioned Defence Force Member
--441111	Defence Force Member - Other Ranks

The 2013 Census also stores the industry of the respondent, coded to ANZSIC 2006. There is only one industry relevant to defence: code 'O760000'
*/
drop table if exists #cen13 

SELECT [snz_uid]
        ,'CEN13' as source
      ,[cen_ind_occupation2006_code] as occ_code
      ,cen_ind_industry06_code as ind_code
	  ,datefromparts(2013,3,5) as start_date
	  ,datefromparts(2013,3,5) as end_date
	  ,'ANZSCO 2006 6-digit' as occ_standard
	  ,'ANZSIC 2006' as ind_standard
	  , case when cen_ind_occupation2006_code in ('441111','139211','139111','111212') then 1 else 0 end as occ_veteran
	  , case when cen_ind_industry06_code='O760000' then 1 else 0 end as ind_defence
	  ,null AS ex_service
into #cen13
FROM [IDI_Clean_202210].[cen_clean].[census_individual_2013]
where [cen_ind_occupation2006_code] in ('441111','139211','139111','111212') or cen_ind_industry06_code='O760000'

/* 1b Census 2018 
This codes occupation to ANZSCO 2013/v1.2 classifications. These codes are equivalent to ANZSCO 2006 classifications, at least as far as the armed forces are concerned. 
The 2018 Census stores occupation only at the 6 digit level, so the codes we are interested in are: 
--111212	Defence Force Senior Officer
--139111	Commissioned Defence Force Officer
--139211	Senior Non-commissioned Defence Force Member
--441111	Defence Force Member - Other Ranks

The 2018 Census also stores the industry of the respondent, coded to ANZSIC 2006. There is only one industry relevant to defence: code 'O760000'
*/
drop table if exists #cen18

SELECT [snz_uid]
      ,'CEN18' as source
      ,cen_ind_occupation_code as occ_code
      ,cen_ind_industry_code as ind_code
	  ,datefromparts(2018,3,6) as start_date
	  ,datefromparts(2018,3,6) as end_date
	  ,'ANZSCO 2013 6-digit' as occ_standard
	  ,'ANZSIC 2006' as ind_standard
	  , case when cen_ind_occupation_code in ('441111','139211','139111','111212') then 1 else 0 end as occ_veteran
	  , case when cen_ind_industry_code='O760000' then 1 else 0 end as ind_defence
	  ,null AS ex_service
into #cen18
from [IDI_Clean_202210].[cen_clean].[census_individual_2018]
where cen_ind_occupation_code in ('441111','139211','139111','111212') or cen_ind_industry_code='O760000'

/* 1c HLFS 2006-2022
This has only a subset of the population, but across a decade, might contribute substantially to coverage. 
This asks about occupation, which is coded differently depending on wave:
	Dec 2006 to Dec 2008: Uses NZSCO 1990, captured in the variable [hlfs_urd_nzsco90_code]
		Armed Forces are categorised under this classification with the code 011
	Mar 2009 to Mar 2016: Uses ANZSCO 2006, but is coded only to a 3-digit level, captured in the variable [hlfs_urd_occ_main_code]
		Unfortunately, ANZSCO 2006 when reported at the 3-digit level is not sufficient to split armed forces from other occupations (like police/firefighters)
	Jun 2016 to present: Uses ANZSCO 2006, coded to a 6-digit level, captured in the variable [hlfs_urd_occ_main_code]
		This uses the same four codes used in the above Census extracts
	(Source: Stats NZ correspondence on IDI Commons)
Industry is also split into multiple classifications, depending on wave:
	Dec 2006 to Dec 2008: Uses ANZSIC 1993 (4-digit), captured in the variable [hlfs_urd_anzsic96_code]
		Defence is coded as M820 in this classification
	Mar 2009 to present: Uses ANZSIC 2006 (7-digit), captured in the variable [hlfs_urd_ind_main_code]
		Defence is coded as O760000 in this classification
*/
drop table if exists #hlfs

SELECT [snz_uid]
      ,'HLFS' as source
      ,case when year([hlfs_urd_quarter_date])<2009 then [hlfs_urd_nzsco90_code] else [hlfs_urd_occ_main_code] end as occ_code
      ,case when year([hlfs_urd_quarter_date])<2009 then [hlfs_urd_anzsic96_code] else [hlfs_urd_ind_main_code] end as ind_code
	  ,[hlfs_urd_quarter_date] as start_date
	  ,[hlfs_urd_quarter_date] as end_date
	  ,case when year([hlfs_urd_quarter_date])<2009 then 'NZSCO 1999 3-digit'
		when year([hlfs_urd_quarter_date])>=2009 and [hlfs_urd_quarter_date]<datefromparts(2016,4,1) then 'ANZSCO 2006 3-digit'
		else 'ANZSCO 2006 6-digit' end as occ_standard
	  , case when year([hlfs_urd_quarter_date])<2009 then 'ANZSIC 1996' else 'ANZSIC 2006' end as ind_standard
	  , case when (year([hlfs_urd_quarter_date])<2009 and [hlfs_urd_nzsco90_code]='011') 
		or ([hlfs_urd_quarter_date]>datefromparts(2016,4,1) and [hlfs_urd_occ_main_code] in ('441111','139211','139111','111212')) then 1 else 0 end as occ_veteran
	  , case when (year([hlfs_urd_quarter_date])<2009 and [hlfs_urd_anzsic96_code]='M820')
		or (year([hlfs_urd_quarter_date])>=2009 and [hlfs_urd_ind_main_code]='O760000') then 1 else 0 end as ind_defence
		,null AS ex_service
into #hlfs
from [IDI_Clean_202210].[hlfs_clean].[data]
where (year([hlfs_urd_quarter_date])<2009 and [hlfs_urd_nzsco90_code]='011')
	or ([hlfs_urd_quarter_date]>datefromparts(2016,4,1) and [hlfs_urd_occ_main_code] in ('441111','139211','139111','111212'))
	or (year([hlfs_urd_quarter_date])<2009 and [hlfs_urd_anzsic96_code]='M820')
	or (year([hlfs_urd_quarter_date])>=2009 and [hlfs_urd_ind_main_code]='O760000')

/* 1d GSS 2014, 2016, 2018
Uses ANZSCO 2006, coded to a 6-digit level. Uses the same four codes as the census extraction above.
GSS does not ask about industry of job.
*/
drop table if exists #gss2018

SELECT [snz_uid]
      ,'GSS18' as source
      ,[gss_pq_occupation_code] as occ_code
      ,null as ind_code
	  ,[gss_pq_PQinterview_date] as start_date
	  ,[gss_pq_PQinterview_date] as end_date
	  ,'ANZSCO 2013 6-digit' as occ_standard
	  ,'N/A' as ind_standard
	  , case when [gss_pq_occupation_code] in ('441111','139211','139111','111212') then 1 else 0 end as occ_veteran
	  , null as ind_defence
	  ,null AS ex_service
into #gss2018
from [IDI_Clean_202210].[gss_clean].[gss_person]
where [gss_pq_occupation_code] in ('441111','139211','139111','111212') 

/* GSS 2021 uses the same coding as earlier waves but is stored in a different table */
drop table if exists #gss2021

SELECT [snz_uid]
      ,'GSS18' as source
      ,[gss_pq_lfs_qoccupation] as occ_code
      ,null as ind_code
	  ,[gss_pq_fpqinterviewdate] as start_date
	  ,[gss_pq_fpqinterviewdate] as end_date
	  ,'ANZSCO 2013 6-digit' as occ_standard
	  ,'N/A' as ind_standard
	  , case when [gss_pq_lfs_qoccupation] in ('441111','139211','139111','111212') then 1 else 0 end as occ_veteran
	  , null as ind_defence
	  ,null AS ex_service
into #gss2021
from [IDI_Clean_202210].[gss_clean].[gss_person_2021]
where [gss_pq_lfs_qoccupation] in ('441111','139211','139111','111212') 

/* 1e ACC claims
ACC collects occupation using the NZSCO 1999 classification, and collects to the 5 digit level. 
However, it stores this information as text (ie as "ARMED FORCES", rather than "51551").
ACC also collects industry of employer (ANZSIC06), but only in cases where there is a workplace-related claim and only at the 1-digit level. 
This means that ACC data cannot separate defence from related industries (police etc) via industry data.
*/
drop table if exists #acc

SELECT [snz_uid]
      ,'ACC' as source
      ,51551 as occ_code
      ,null as ind_code
	  ,[acc_cla_lodgement_date] as start_date
	  ,[acc_cla_lodgement_date] as end_date
	  ,'NZSCO 1999 5-digit' as occ_standard
	  ,'N/A' as ind_standard
	  , 1 as occ_veteran
	  , null as ind_defence
	  ,null AS ex_service
into #acc
from [IDI_Clean_202210].[acc_clean].[claims]
where [acc_cla_occupation_level_5_text] ='ARMED FORCES'

/* 1f Customs journey data
All border crossings forms (entry/departure to NZ) ask for occupation. This is coded is one of three ways, depending on the date:
	1997-2009: NZSCO 1999 3-digit
		At this level of detail, Armed Forces are combined with other related occupations eg police, firefighters. We therefore cannot use this data.
		AW NOTE: I'm not certain that it uses NZSCO 1999 - it could use NZSCO 1990 (the data dictionary is not explicit). The most relevant difference between these classifications is that in NZSCO 1990,
			Armed Forces are included under a separate level 1 classification: code 0 (the relevant 3-digit code for Armed Forces is '011'). 
			As there are no 3 digit codes beginning with 0 in the table, I infer this must be NZSCO 1999.
			Alternatively, it could be the case that this DID use NZSCO 1990 and it's just the case that no one reported having an Armed Force occupation (over 12 years??).
	2009-2018: ANZSCO 2013/v1.2 4-digit
		There are two codes at this level that identify Defence Forces: 1392 (Senior Non-commissioned Defence Force Members) and 4411 (Defence Force Members - Other Ranks).
		There are two other codes where some Defence Force members are included, but also includes staff from police, fire fighters etc: 1112 and 1392
	2018-present: ANZSCO 2013/v1.2 6-digit
		This uses the same four codes used in the Census extracts
Customs does not collect industry data.
*/

drop table if exists #journeys

SELECT [snz_uid]
      ,'Cust' as source
      ,[cus_jou_occupation_code] as occ_code
      ,null as ind_code
	  ,[cus_jou_actual_date] as start_date
	  ,[cus_jou_actual_date] as end_date
	  ,case when len([cus_jou_occupation_code])=3 then 'NZSCO 1999 3-digit'
		when len([cus_jou_occupation_code])=4 then 'ANZSCO 2013 4-digit'
		when len([cus_jou_occupation_code])=6 then 'ANZSCO 2013 6-digit'
		else 'N/A' end as occ_standard
	  , 'N/A' as ind_standard
	  , 1 as occ_veteran
	  , null as ind_defence
	  ,null AS ex_service
into #journeys
from [IDI_Clean_202210].[cus_clean].[journey]
where [cus_jou_occupation_code] in ('1392','4411','441111','139211','139111','111212')

/* 1g MBIE immigration data
MBIE records the occupation of the principal applicant for certain visas. This is unlikely to be hugely relevant for people in defense forces but is included here for completeness.
The information is recorded to 5-digit NZSCO 1999 from 7 December 2002, and 6-digit ANZSCO 2006 from 2 February 2008.
MBIE does not collect industry of employment.
*/
drop table if exists #immig
  
SELECT distinct a.[snz_uid]
      ,'IMMIG' as source
      ,[dol_occ_occ_code] as occ_code
      ,null as ind_code
	  ,b.[dol_dec_decision_date] as start_date
	  ,b.[dol_dec_decision_date] as end_date
	  ,case when [dol_occ_occ_standard_code]=0 then 'ANZSCO 1999 5-digit' 
		when [dol_occ_occ_standard_code]=1 then 'ANZSCO 2006 6-digit' 
		else null end as occ_standard
	  ,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,null AS ex_service
into #immig
FROM [IDI_Clean_202210].[dol_clean].[occupations] as a
inner join [IDI_Clean_202210].[dol_clean].[decisions] as b
on a.snz_uid=b.snz_uid and a.[snz_application_uid]=b.[snz_application_uid]
where ([dol_occ_occ_standard_code]=0 and [dol_occ_occ_code] = '51551')
	or ([dol_occ_occ_standard_code]=1 and [dol_occ_occ_code] in ('441111','139211','139111','111212'))
	
/* 1h DIA data
This includes self-reported occupation that is on birth, death and marriage registrations. This information is stored as free text. 
We have gone through and manually identified all occupations that might signal an occupation associated with being a veteran.
This was based on guidance from Veterans Affairs.
This coding information is stored as an excel spreadsheet that needs to be uploaded to a temp table or the sandpit.
*/

/* Birth records */
drop table if exists #bir

select * 
into #bir
from (
(SELECT [parent1_snz_uid] as snz_uid
	,'BIR' as source
    ,a.[dia_bir_parent1_occupation_text] as occ_code
    ,null as ind_code
    ,DATEFROMPARTS([dia_bir_birth_year_nbr],[dia_bir_birth_month_nbr],1) as start_date
	,eomonth(DATEFROMPARTS([dia_bir_birth_year_nbr],[dia_bir_birth_month_nbr],1)) as end_date
	,'Free text' as occ_standard
	,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,b.ex_service
  FROM [IDI_Clean_202210].[dia_clean].[births] a
  inner join [IDI_Sandpit].[Proj_schema].[dy_dia] b
  on a.[dia_bir_parent1_occupation_text]=b.occ_text_raw
  where a.[dia_bir_parent1_occupation_text] is not null and a.[parent1_snz_uid] is not null and b.veteran_related=1 )
UNION ALL
	(SELECT [parent2_snz_uid] as snz_uid
	,'BIR' as source
    ,a.[dia_bir_parent2_occupation_text] as occ_code
    ,null as ind_code
    ,DATEFROMPARTS([dia_bir_birth_year_nbr],[dia_bir_birth_month_nbr],1) as start_date
	,eomonth(DATEFROMPARTS([dia_bir_birth_year_nbr],[dia_bir_birth_month_nbr],1)) as end_date
	,'Free text' as occ_standard
	,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,b.ex_service
  FROM [IDI_Clean_202210].[dia_clean].[births] a
  inner join [IDI_Sandpit].[Proj_schema].[dy_dia] b
  on a.[dia_bir_parent2_occupation_text]=b.occ_text_raw
  where a.[dia_bir_parent2_occupation_text] is not null and a.[parent2_snz_uid] is not null and b.veteran_related=1)
) as a

/* Civil union records */
drop table if exists #civ

select * 
into #civ
from (
(SELECT [partnr1_snz_uid] as snz_uid
	,'CIV' as source
    ,a.[dia_civ_partnr1_occupation_text] as occ_code
	,null as ind_code
	,[dia_civ_civil_union_date] as start_date
	,[dia_civ_civil_union_date] as end_date
	,'Free text' as occ_standard
	,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,b.ex_service
  FROM [IDI_Clean_202210].[dia_clean].[civil_unions] a
  inner join [IDI_Sandpit].[Proj_schema].[dy_dia] b
  on a.[dia_civ_partnr1_occupation_text]=b.occ_text_raw
  where a.[dia_civ_partnr1_occupation_text] is not null and a.[partnr1_snz_uid] is not null and b.veteran_related=1  )
UNION ALL
(SELECT [partnr2_snz_uid] as snz_uid
	,'CIV' as source
    ,a.[dia_civ_partnr2_occupation_text] as occ_code
	,null as ind_code
	,[dia_civ_civil_union_date] as start_date
	,[dia_civ_civil_union_date] as end_date
	,'Free text' as occ_standard
	,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,b.ex_service
  FROM [IDI_Clean_202210].[dia_clean].[civil_unions] a
  inner join [IDI_Sandpit].[Proj_schema].[dy_dia] b
  on a.[dia_civ_partnr2_occupation_text]=b.occ_text_raw
  where a.[dia_civ_partnr2_occupation_text] is not null and a.[partnr2_snz_uid] is not null and b.veteran_related=1  )
  ) as a

/* Marriage records */
drop table if exists #mar
  
select * 
into #mar
from (
(SELECT [partnr1_snz_uid] as snz_uid
	,'MAR' as source
    ,a.[dia_mar_partnr1_occupation_text] as occ_code
	,null as ind_code
	,[dia_mar_marriage_date] as start_date
	,[dia_mar_marriage_date] as end_date
	,'Free text' as occ_standard
	,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,b.ex_service
  FROM [IDI_Clean_202210].[dia_clean].[marriages] a
  inner join [IDI_Sandpit].[Proj_schema].[dy_dia] b
  on a.[dia_mar_partnr1_occupation_text]=b.occ_text_raw
  where a.[dia_mar_partnr1_occupation_text] is not null and [partnr1_snz_uid] is not null and b.veteran_related=1  )
UNION ALL
(SELECT [partnr2_snz_uid] as snz_uid
	,'MAR' as source
    ,a.[dia_mar_partnr2_occupation_text] as occ_code
	,null as ind_code
	,[dia_mar_marriage_date] as start_date
	,[dia_mar_marriage_date] as end_date
	,'Free text' as occ_standard
	,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,b.ex_service
  FROM [IDI_Clean_202210].[dia_clean].[marriages] a
  inner join [IDI_Sandpit].[Proj_schema].[dy_dia] b
  on a.[dia_mar_partnr2_occupation_text]=b.occ_text_raw
  where a.[dia_mar_partnr2_occupation_text] is not null and [partnr2_snz_uid] is not null and b.veteran_related=1  )
  ) as a

/* Death records */
drop table if exists #dea

select * 
into #dea
from (
  (SELECT [snz_uid]
	,'DEA' as source
    ,a.[dia_dth_occupation_text] as occ_code
	,null as ind_code
    ,datefromparts([dia_dth_death_year_nbr],[dia_dth_death_month_nbr],1) as start_date
    ,eomonth(datefromparts([dia_dth_death_year_nbr],[dia_dth_death_month_nbr],1)) as end_date
	,'Free text' as occ_standard
	,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,b.ex_service
  FROM [IDI_Clean_202210].[dia_clean].[deaths] a
  inner join [IDI_Sandpit].[Proj_schema].[dy_dia] b
  on a.[dia_dth_occupation_text]=b.occ_text_raw
  where a.[dia_dth_occupation_text] is not null and [snz_uid] is not null and b.veteran_related=1  )
UNION ALL
(SELECT [parent1_snz_uid] as snz_uid
	,'DEA' as source
    ,a.[dia_dth_parent1_occupation_text] as occ_code
	,null as ind_code
    ,datefromparts([dia_dth_death_year_nbr],[dia_dth_death_month_nbr],1) as start_date
    ,eomonth(datefromparts([dia_dth_death_year_nbr],[dia_dth_death_month_nbr],1)) as end_date
	,'Free text' as occ_standard
	,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,b.ex_service
  FROM [IDI_Clean_202210].[dia_clean].[deaths] a
  inner join [IDI_Sandpit].[Proj_schema].[dy_dia] b
  on a.[dia_dth_parent1_occupation_text]=b.occ_text_raw
  where a.[dia_dth_parent1_occupation_text] is not null and [parent1_snz_uid] is not null and b.veteran_related=1  )
UNION ALL
(SELECT [parent2_snz_uid] as snz_uid
	,'DEA' as source
    ,a.[dia_dth_parent2_occupation_text] as occ_code
	,null as ind_code
    ,datefromparts([dia_dth_death_year_nbr],[dia_dth_death_month_nbr],1) as start_date
    ,eomonth(datefromparts([dia_dth_death_year_nbr],[dia_dth_death_month_nbr],1)) as end_date
	,'Free text' as occ_standard
	,'N/A' as ind_standard
	, 1 as occ_veteran
	, null as ind_defence
	,b.ex_service
  FROM [IDI_Clean_202210].[dia_clean].[deaths] a
  inner join [IDI_Sandpit].[Proj_schema].[dy_dia] b
  on a.[dia_dth_parent2_occupation_text]=b.occ_text_raw
  where a.[dia_dth_parent2_occupation_text] is not null and [parent2_snz_uid] is not null and b.veteran_related=1  )) as a

/* 1i Hospital data 
MoH also collects free-text occupation as part of public (but not private) hospital discharge records. This has been coded to a couple of different standard occupation classifications in the 
[moh_evt_occupation_code] variable. However, the dataset also includes the free-text occupation that was entered by the patient. 
A comparison of the coded fields to the free-text occupation indicates many cases where a patient has entered an occupation likely to identify them as a veteran, but it has not been allocated an occupation code.
In addition, there are many instances where someone has identified themselves as being retired with a history in the armed forces, which would be correctly coded as no (current) occupation, but a loss of information for us.
See the below query for a demonstration of this:

  select [moh_evt_occupation_code],[moh_evt_occupation_text], count(distinct snz_uid) as n
  from [IDI_Clean_202210].[moh_clean].[pub_fund_hosp_discharges_event]
  where [moh_evt_occupation_text] like '%ARMY%'
  group by [moh_evt_occupation_code],[moh_evt_occupation_text]
  
Compared to DIA free-text occupation data, there are many more unique values in the MoH occupation collection, implying the MoH data is much lower quality.
As with the DIA occupations, we have manually coded the occupations likely to be related to veterans (using guidance from Veterans Affairs), and import this as a lookup table.
We then look at the combination of occupation codes and free text occupations to identify veteran-relevant occupations.

There is one unresolved issue in the occupation clasification. The MoH data dictionary indicates that occupations have been coded to two classifications:
	NZSCO 1990 (4-digit) up until 30 June 2015
	ANZSCO v1.2 (6-digit) from 1 July onwards
However, there are some occupations coded to code '5155'. This code does not appear in the NZSCO90 or ANZSCOv1.2 schemas, but does appear in NZSCO99 (and the free-text occupations related to this code
appear to indicate that they correctly identify people in the Armed Forces). There are also some occupations coded to code '0111', which appears only in NZSCO90, but not the other two schemas (and also
appears to correctly identify people in the Armed Forces). Therefore, it appears that some combination of the three classification systems are being used. The time periods in which they are used also appear to overlap.
Since the codes that identify potential veterans are not used for other purposes in other classification schemas, we are safe to just look for any indication of codes 
('0111','5155','441111','139211','139111','111212').
However, if this code is used for other occupation types, be aware that you may end up combining codes that mean different things in different classification schemas.
*/
drop table if exists #hospital

SELECT [snz_uid]
      ,'HOSP' as source
	  ,case when [moh_evt_occupation_code] in ('0111','5155','441111','139211','139111','111212') then [moh_evt_occupation_code] 
			else a.[moh_evt_occupation_text] end as occ_code
	  ,null as ind_code
      ,case when [moh_evt_occupation_code]='0111' then 'NZSCO 1990 4-digit' 
			when [moh_evt_occupation_code]='5155' then 'NZSCO 1999 4-digit'
			when [moh_evt_occupation_code] in ('441111','139211','139111','111212') then 'ANZSCO 2013 6-digit'
			else 'Free Text' end as occ_standard
      ,[moh_evt_evst_date] as start_date
      ,[moh_evt_even_date] as end_date
	  ,'N/A' as ind_standard
	  , 1 as occ_veteran
	  , null as ind_defence
	  ,b.ex_service
	  into #hospital
  FROM [IDI_Clean_202210].[moh_clean].[pub_fund_hosp_discharges_event] a
  left join [IDI_Sandpit].[Proj_schema].[dy_moh] b
  on a.[moh_evt_occupation_text]=b.occ_text_raw
  where [moh_evt_occupation_code] in ('0111','5155','441111','139211','139111','111212')
	or b.veteran_related=1

/* Create all occupation spells 
This table is created by appending all spells from each of the 13 different sources of occupation into one table */
drop table if exists #occupation_all

select * 
into #occupation_all
from (
select snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #cen13
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #cen18
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #hlfs
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #gss2018
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #gss2021
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #acc
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #journeys
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #immig
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #bir
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #mar
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #civ
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #dea
union all
select  snz_uid, source
	, cast(occ_code as varchar(max)) as occ_code, cast(ind_code as varchar(max)) as ind_code
	, start_date, end_date, occ_standard, ind_standard, occ_veteran, ind_defence, ex_service
from #hospital) a


/* 2 IR data
This identifies anyone who has received wage and salary income for the employer entity associated with NZDF.
We identified the employer ID by observing the modal IR employer (in March 2018) for the people who reported an occupation associated with Defence Forces in the 2018 Census.
*/

--Isolate all payments by NZDF
drop table if exists #ir_allpayments
select snz_uid
	, [snz_employer_ird_uid]
	, [ir_ems_return_period_date]
	, [ir_ems_gross_earnings_amt]
into #ir_allpayments
from [IDI_Clean_202210].[ir_clean].[ird_ems]
where [snz_employer_ird_uid] [suppressed] and [ir_ems_gross_earnings_amt]>5

--Group by employee to find the first and last payments from NZDF
drop table if exists #ir_byemployee
select snz_uid
	, min([ir_ems_return_period_date]) as firstpayment
	, max([ir_ems_return_period_date]) as lastpayment
into #ir_byemployee
from #ir_allpayments
group by snz_uid

/* Summarise the employment spells and payments over the last 12 months of employment by employee.
Separately flag employees who have been paid by NZDF in the last 12 months of the data (which ends on 05/2022 at time of writing) in order to exclude current employees later in the code. 
DY: This table is only used for analysing the source of signals (including of current employees), not to build the main table
*/
drop table if exists #ir_lastpayment
select a.snz_uid, a.firstpayment, a.lastpayment
	, sum(b.[ir_ems_gross_earnings_amt]) as earnings_last12months
	, max(case when a.lastpayment<'2021-05-01' then 1 else 0 end) as ir_veteran
	, max(case when a.lastpayment>='2021-05-01' then 1 else 0 end) as ir_currentemployee
into #ir_lastpayment
from #ir_byemployee a
left join #ir_allpayments b
on a.snz_uid=b.snz_uid and dateadd(year,-1,a.lastpayment)<=b.ir_ems_return_period_date
group by a.snz_uid, a.firstpayment, a.lastpayment

/* AW NOTE
[suppressed]
*/

/* Identify persons who are employed in 2019 and in 2021 */
drop table if exists #ir_current_employee
select snz_uid
		,MAX(CASE WHEN [ir_ems_return_period_date] >='2019-01-01' AND [ir_ems_return_period_date] <= '2019-12-31' THEN 1 ELSE null END) as employee2019
		,MAX(CASE WHEN [ir_ems_return_period_date] >='2021-01-01' AND [ir_ems_return_period_date] <= '2021-12-31' THEN 1 ELSE null END) as employee2021
into #ir_current_employee
from #ir_allpayments
group by snz_uid


/* 3 Veterans payments from MSD 
There are several payments administered by MSD that might signal a recipient is a veteran. 
The most common is the Veteran's Pension - a first tier benefit (a substitution for NZ Super). But there are also several different supplementary and lump-sum payments that relate to veterans.
These payments are stored across multiple tables so we have to extract tier 1/2/3 payments separately.
The relevant serv codes for each payment related to veterans has been verified with MSD (via CW's correspondence).
There are some other payments related to veterans that are not stored in the IDI.
The following codes are conceptually related to pensioners, but do not show up in any of the tables, so have not been included:
--179	Veterans Pension						1/01/1990	31/12/9999
--201	1914/18 War								1/01/1990	31/12/9999
--203	Peace Time Armed Forces					1/01/1990	31/12/9999
--205	UN Armed Forces							1/01/1990	31/12/9999
--211	J-Force									1/01/1990	31/12/9999
*/

/* Tier 1
--181	Veterans Pension						1/01/1990	22/05/2004
--181	Veterans Pension						23/05/2004	31/12/9999
*/
drop table if exists #msd_t1

SELECT snz_uid
	,1 as tier_payment
	,[msd_fte_serv_code] as serv_code
    ,[msd_fte_start_date] as start_date
	,[msd_fte_end_date] as end_date
	,[msd_fte_period_nbr] as length
	,([msd_fte_period_nbr]*[msd_fte_daily_gross_amt]) as total_payment
into #msd_t1
FROM [IDI_Clean_202210].[msd_clean].[msd_first_tier_expenditure]
where [msd_fte_serv_code] in ('181') 

/* Tier 2 supplementary benefits
AW NOTE: The last serv code (271) shows up both in tier 2 and tier 3 tables, so we include in both sections
--202	Vietnam									1/01/1990	31/12/9999
--208	Gallantry Award							1/01/1990	31/12/9999
--209	Pension Under Section 55				1/01/1990	31/12/9999 -- DY: This appears to be a reference to s55 of the War Pensions Act 1954, which provides for a pension to Govt employees who served overseas in connection with a war/emergency, who were disabled or killed, and who were not members of the armed forces
--210	1939/45 War								1/01/1990	31/12/9999
--213	War Servicemens Dependants Allowance	1/01/1990	31/12/9999 -- DY: this appears to be for children and dependents of war servicement. It is not included (commented out) below.
--271	War Medical Treatment - UK Pensioner	1/01/1990	31/12/9999
*/
drop table if exists #msd_t2

SELECT [snz_uid]
	  ,2 as tier_payment
	  ,[msd_ste_supp_serv_code] as serv_code
      ,[msd_ste_start_date] as start_date
      ,[msd_ste_end_date] as end_date
	  ,[msd_ste_period_nbr] as length
	  ,([msd_ste_period_nbr]*[msd_ste_daily_gross_amt]) as total_payment
into #msd_t2
FROM [IDI_Clean_202210].[msd_clean].[msd_second_tier_expenditure]
where [msd_ste_supp_serv_code]  in ('202','208',
									'209',
									'210',
									--'213',
									'271')
  
/* Tier 3 lump-sum payments:
AW NOTE: One serv code (271) shows up both in tier 2 and tier 3 tables, so we include in both sections
DY: did some analysis of benefits available and what these might describe
--193	War Funeral Grant						1/01/1990	31/12/9999 -- DY: this appears to be reimbursement or payment of funeral costs, which would not be paid to the veteran who is deceased (excluded from below)
--250	War Travel Concessions					1/01/1990	31/12/9999 -- DY: this appears to be paid to a veteran who has a severe impairment, to support travel within NZ
--255	War Bursaries							1/01/1990	31/12/9999 -- DY: think this is the Children's Bursary, which is for children of veterans (or recipients of children's pension)
--260	War Surgical Appliances					1/01/1990	31/12/9999
--263	War 11 Assessment						1/01/1990	31/12/9999
--270	War Medical Treatment - NZ Pensioner	1/01/1990	31/12/9999
--271	War Medical Treatment - UK Pensioner	1/01/1990	31/12/9999
--272	War Medical Treatment - AUS Pensioner	1/01/1990	31/12/9999
--850	Veterans Pension Lump Sum				1/01/1990	31/12/9999 -- This is coded as Veterans Pension Lump Sum Pymt on Death in metadata - which looks to potentially be the Survivors Grant, paid to survivors.

*/
drop table if exists #msd_t3

SELECT [snz_uid]
	  ,3 as tier_payment
	  ,[msd_tte_lump_sum_svc_code] as serv_code
      ,[msd_tte_app_date] as start_date
      ,[msd_tte_decision_date] as end_date
      ,datediff(day,[msd_tte_app_date],[msd_tte_decision_date]) as length
      ,[msd_tte_pmt_amt] as total_payment
into #msd_t3
FROM [IDI_Clean_202210].[msd_clean].[msd_third_tier_expenditure]
where [msd_tte_lump_sum_svc_code] in (--'193',
									'250', --'255',
									'260','263','270','271','272'
									--,'850'
									)

/* Append all payments together in the same table */
drop table if exists #msd_allpayments

select * 
into #msd_allpayments
from (
select * from #msd_t1
union all
select * from #msd_t2
union all
select * from #msd_t3) a

/* Summarise into binary variables per person */
drop table if exists #msd_summary

select snz_uid
	, max(case when tier_payment=1 then 1 else 0 end) as msd_pension
	, max(case when tier_payment=2 then 1 else 0 end) as msd_supplementary
	, max(case when tier_payment=3 then 1 else 0 end) as msd_lumpsum
	, 1 as msd_anypayment
into #msd_summary
from #msd_allpayments
group by snz_uid

/* 4 Border crossings */
/* 
The intention here was to try to identify border crossings of groups of people coded as veterans, to potentially associate others crossing with them. This was explored but did not produce useful results. */

/* Table for analysis and business rules */

/* Combining all signals of veterans 
This combines all previous data together in a table that provides, per person, a time-invariant binary indicator of whether they showed up as a potential veteran in each data source.
This is intended to use as a basis to develop business rules to identify likely veterans */
drop table if exists #pop
select distinct snz_uid 
into #pop
from (
select snz_uid from #occupation_all
union
select snz_uid from #ir_byemployee
union
select snz_uid from #msd_summary) a



/*******    Check for first date for recipients of veterans pension and other pensions     *******/

/* Summarise into binary variables per person */
drop table if exists #msd_summary_dates

select snz_uid
	, max(case when tier_payment=1 then 1 else 0 end) as msd_pension
	, min(case when tier_payment = 1 THEN start_date else null END) first_t1
	, max(case when tier_payment=2 then 1 else 0 end) as msd_supplementary
	, min(case when tier_payment = 2 THEN start_date else null END) first_t2
	, max(case when tier_payment=3 then 1 else 0 end) as msd_lumpsum
	, min(case when tier_payment = 3 THEN start_date else null END) first_t3
	, 1 as msd_anypayment
into #msd_summary_dates
from #msd_allpayments
group by snz_uid

-- Create a combined table.

drop table if exists #veterans_summary
select a.snz_uid
	, max(b.occ_veteran) as occ_cen13
	, max(c.occ_veteran) as occ_cen18
	, max(d.occ_veteran) as occ_hlfs
	, max(e.occ_veteran) as occ_gss
	, max(f.occ_veteran) as occ_acc
	, max(g.occ_veteran) as occ_immig
	, max(h.occ_veteran) as occ_journey
	, max(i.occ_veteran) as occ_birth
	, max(j.occ_veteran) as occ_marriage
	, max(k.occ_veteran) as occ_civil
	, max(l.occ_veteran) as occ_death
	, max(m.occ_veteran) as occ_hospital
	, max(n.occ_veteran) as occ_any
	, max(b.ind_defence) as ind_cen13
	, max(c.ind_defence) as ind_cen18
	, max(d.ind_defence) as ind_hlfs
	, max(o.msd_pension) as msd_pension
	, max(q.first_t1) first_t1
	, max(o.msd_supplementary) as msd_supplementary
	, max(q.first_t2) first_t2
	, max(o.msd_lumpsum) as msd_lumpsum
	, max(q.first_t3) first_t3
	, max(o.msd_anypayment) as msd_anypayment
	, max(p.ir_veteran) as ir_prevemployee
	, max(p.ir_currentemployee) as ir_currentemployee
	, CASE WHEN max(p.lastpayment) >= '2019-01-01' THEN 0 ELSE 1 END AS veteran_2019 -- people who still receive wages and salary in 2019 or later are not veterans in 2019
	, CASE WHEN max(p.lastpayment) >= '2018-01-01' THEN 0 ELSE 1 END AS veteran_1_year_2019 -- people who still receive wages and salary in 2018 or later had not been veterans for 1 year in 2019
	, CASE WHEN max(p.lastpayment) >= '2021-01-01' THEN 0 ELSE 1 END AS veteran_2021 -- people who still receive wages and salary in 2021 or later are not veterans in 2021 
	, CASE WHEN max(p.lastpayment) >= '2020-01-01' THEN 0 ELSE 1 END AS veteran_1_year_2021 -- people who still receive wages and salary in 2020 or later had not been veterans for 1 year in 2021
	, max(r.employee2019) as employee2019
	, max(r.employee2021) employee2021
into #veterans_summary
from #pop a
left join #cen13 b
on a.snz_uid=b.snz_uid
left join #cen18 c
on a.snz_uid=c.snz_uid
left join #hlfs d
on a.snz_uid=d.snz_uid
left join (select * from #gss2018 union all select * from #gss2021) e
on a.snz_uid=e.snz_uid
left join #acc f
on a.snz_uid=f.snz_uid
left join #immig g
on a.snz_uid=g.snz_uid
left join #journeys h
on a.snz_uid=h.snz_uid
left join #bir i
on a.snz_uid=i.snz_uid
left join #mar j
on a.snz_uid=j.snz_uid
left join #civ k
on a.snz_uid=k.snz_uid
left join #dea l
on a.snz_uid=l.snz_uid
left join #hospital m
on a.snz_uid=m.snz_uid
left join #occupation_all n
on a.snz_uid=n.snz_uid
left join #msd_summary o
on a.snz_uid=o.snz_uid
left join #ir_lastpayment p
on a.snz_uid=p.snz_uid
left join #msd_summary_dates q
on a.snz_uid = q.snz_uid
left join #ir_current_employee r
on a.snz_uid = r.snz_uid
group by a.snz_uid


DROP TABLE IF EXISTS [IDI_Sandpit].[Proj_schema].[veterans_population];
SELECT * 
INTO [IDI_Sandpit].[Proj_schema].[veterans_population]
FROM #veterans_summary


/* 2019 table for temporary analysis purposes*/


DROP TABLE IF EXISTS [IDI_Sandpit].[Proj_schema].[veterans2019];
SELECT * 
INTO [IDI_Sandpit].[Proj_schema].[veterans2019]
FROM #veterans_summary
WHERE veteran_2019 = 1;



/* Pension type table reference */

--181	Veterans Pension
--202	Vietnam							1/01/1990	31/12/9999
--208	Gallantry Award						1/01/1990	31/12/9999
--209	Pension Under Section 55				1/01/1990	31/12/9999
--210	1939/45 War						1/01/1990	31/12/9999
--271	War Medical Treatment - UK Pensioner			1/01/1990	31/12/9999
--250	War Travel Concessions					1/01/1990	31/12/9999 
--260	War Surgical Appliances					1/01/1990	31/12/9999
--263	War 11 Assessment					1/01/1990	31/12/9999
--270	War Medical Treatment - NZ Pensioner			1/01/1990	31/12/9999
--271	War Medical Treatment - UK Pensioner			1/01/1990	31/12/9999
--272	War Medical Treatment - AUS Pensioner			1/01/1990	31/12/9999

DROP TABLE IF EXISTS [IDI_Sandpit].[Proj_schema].[pensions_by_snz_uid];
select snz_uid, serv_code, min(start_date) as earliest_receipt, max(end_date) as latest_receipt
INTO [IDI_Sandpit].[Proj_schema].[pensions_by_snz_uid]
FROM #msd_allpayments
GROUP BY snz_uid, serv_code




