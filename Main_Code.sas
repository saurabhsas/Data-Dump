* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

 Program        : AOPP-M-PHPHEQ.sas

 Purpose        : Create tableau input for PHP Health Equity dashboard

 Developer      : Supriya Khatri

 Date           : 11/08/2022

 Run Book       : AOPP-M-PHPHEQ

 Est Run Time   : 60 Minutes depending on DW speed

 Folder         : [SAS DEV Server] /data/php/code/
                  [SAS PRD Server] /data/php/code/DSNP_ClinOps/

 Output/Result  : TableauShareFP:
                  /data/php/PRDTLAPP02_PHP/PHP_HEQ_ROLLING3YEARS.txt

 Change Log     : 10/03/2022 - Initial Code

* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *;
/*%let SysCC = 0; ** reset to start return code processing **;*/
/*%put NOTE: SysJobID: &SYSJOBID..;*/
/**/
/*option nosymbolgen compress=yes DLCREATEDIR varinitchk=ERROR;*/


** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **; 
**                                                                         **;
**                        SAS Metadata Connection                          **;
**                                                                         **;
** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **; 
** connect to meta server from root/OS sas                                                         **;
** this is required to setup connections and permissions when running from SAS outside of EG       **;
** include this section for prod setup but leave commented out, will not run for non scheduled job **;

/*%include "/data/ts_share/schedule/connection/SchedulerIncludeParms.sas";*/
/*%put &TestInclude.;*/


** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **; 
**                                                                         **;
**                                parameters                               **;
**                                                                         **;
** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **;
/*FILENAME IN0 "/data/ts_share/code/";*/
/*%INCLUDE IN0 ("SASRDL.sas")/SOURCE2;*/
/**/
/*%SASRDL(RptId='AOPP-M-PHPHEQ');*/
/*%SASRDL(RptId='ROBBYTEST');*/

%put &frmlist.;

** ** ** ** ** ** **   Development - Begin   ** ** ** ** ** ** ** **;
%let path            = data;
%let DataSubFolder   = php;
%let ProdShare       = share_prodapp01; 
%let SubFolder       = TableauDashboard;
%let SASFOLDER       = PHP_TST;
%let ProjectName     = DSNP_ClinOps;
%let TableauShare    = TSTTBLOAPP01_PHP;
%let TableauShareFP  = /&path./&DataSubFolder./&TableauShare.;
%let BOShare         = PHP_TST;
%let BOShareFP       = /&path./&DataSubFolder./&BOShare./&ProjectName.;
** ** ** ** ** ** **   Development - End     ** ** ** ** ** ** ** **;
/*

** ** ** ** ** ** **   Production - Begin   ** ** ** ** ** ** ** **;
%let path            = data;
%let DataSubFolder   = php;
%let ProdShare       = share_testapp01; 
%let ProjectName     = DSNP_ClinOps;
%let TableauShare    = PRDTLAPP02_PHP;
%let TableauShareFP  = /&path./&DataSubFolder./&TableauShare.;
%let BOShare         = PHP_PRD;
%let BOShareFP       = /&path./&DataSubFolder./&BOSHARE./&ProjectName.;
** ** ** ** ** ** **   Production - End     ** ** ** ** ** ** ** **;*/

%put &BOShareFP.;
%put &TableauShareFP.;

** the resulting folder path will be like: *;
%put   /&path./&DataSubFolder./stage/&ProjectName. ;

%let _sdtm=%sysfunc(datetime());


** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **; 
**                                                                         **;
**                                libraries                                **;
**                                                                         **;
** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **; 
libname HEDIS    "/&path./&DataSubFolder./&ProdShare./HEDIS";
/*libname IRADWER    "/data/php/share_special/SAS_IRADWDW_PROD/Enrollment/" access=readonly;*/
libname PHP_SDOH "/&path./&DataSubFolder./&ProdShare./SDOH" access=readonly;
libname PHPSDOH  "/&path./&DataSubFolder./final/SDOH" compress=yes access=readonly;
libname HEQ  "/&path./&DataSubFolder./final/HealthEquity" compress=yes;
/*libname ADI "/&path./rdt/&path./ADI" compress=yes access=readonly;*/


/*%if (&SysCC.=0) %then %do;*/


/*--------------------------------------------------------------------------------------------------------------------
-- SECTION 1.1: %Bring_in_HEDIS
-- DESCRIPTION: Pulls in and transforms Inovalon HEDIS data.

-- INPUT/OUTPUT:
-- Input data: Summary[year] --> Table of 46 columns. 

-- Output data: HEDIS_Summary_[year]_dup --> Table of 17 columns. This datset contains measure (e.g. CIS, BCS), and includes mapped date and line of business (LOB) values.
--------------------------------------------------------------------------------------------------------------------*/

/*Begins Macro %Bring_in_HEDIS.*/
%MACRO Bring_in_HEDIS;
	/*Bring in IRADW data*/
	/*Bring in iradw data*/

	PROC SQL ;  
		CONNECT TO odbc 
		(DATASRC=IRADW_SAWESCPDSAPP00_UAT_IND user="&cdisql_id." pw="&cdisql_pw." );         
		CREATE TABLE IRADW_ELIG AS SELECT * FROM connection to odbc 
			(SELECT DISTINCT MEMBERUCI as MEMBER_UCI
					, MEMBERID as MEMBER_ID
					, AGE
					, MEMBERDOB AS DOB
					, ELIGIBILITYYEARANDMONTH AS ELIGIBILITY_YM
					, GENDER
					, COUNTY AS Member_County
					, RATEAREACODE AS RATE_AREA
					, RATEAREADESCR AS RATE_AREA_DESCRIPTION
					FROM IRADW_UAT.DM_M360.CUDA_MM 
					WHERE MEMBERUCI IS NOT NULL
					ORDER BY MEMBER_UCI ,	ELIGIBILITY_YM;
			 );         
			DISCONNECT FROM odbc; 
	QUIT;

	DATA IRADWELIG;
		SET IRADW_ELIG;
		BY MEMBER_UCI;
		IF LAST.MEMBER_UCI THEN OUTPUT;
	RUN;

	/*Brings in 5 years of data*/
	proc sql;
		create table HEDIS_Summary (compress=yes) as
		SELECT DISTINCT b.member_id ,
			b.member_uci ,
			a.Year,
			a.Claim_Month AS MONTH ,
			CASE
				WHEN a.Claim_Month = 1 THEN 'JAN'
				WHEN a.Claim_Month = 2 THEN 'FEB'
				WHEN a.Claim_Month = 3 THEN 'MAR'
				WHEN a.Claim_Month = 4 THEN 'APR'
				WHEN a.Claim_Month = 5 THEN 'MAY'
				WHEN a.Claim_Month = 6 THEN 'JUN'
				WHEN a.Claim_Month = 7 THEN 'JUL'
				WHEN a.Claim_Month = 8 THEN 'AUG'
				WHEN a.Claim_Month = 9 THEN 'SEP'
				WHEN a.Claim_Month = 10 THEN 'OCT'
				WHEN a.Claim_Month = 11 THEN 'NOV'
				WHEN a.Claim_Month = 12 THEN 'DEC'
				WHEN a.Claim_Month = 13 THEN 'YEAR-END'
				ELSE " "
			END AS Month_Name ,
			a.Payer_Code ,
			a.Product_Code ,
			CASE
				WHEN a.Payer_Code IN('K') AND a.Product_Code IN('H') THEN 'COMMERCIAL'
				WHEN a.Payer_Code IN('K') AND a.Product_Code IN('P') THEN 'COMMERCIAL'
				WHEN a.Payer_Code IN('C') AND a.Product_Code IN('H') THEN 'COMMERCIAL'
				WHEN a.Payer_Code IN('C') AND a.Product_Code IN('S') THEN 'COMMERCIAL'
				WHEN a.Payer_Code IN('C') AND a.Product_Code IN('P') THEN 'COMMERCIAL'
				WHEN a.Payer_Code IN('S') AND a.Product_Code IN('H') THEN 'COMMERCIAL'
				WHEN a.Payer_Code IN('S') AND a.Product_Code IN('P') THEN 'COMMERCIAL'
				WHEN a.Payer_Code IN('S') AND a.Product_Code IN('S') THEN 'COMMERCIAL'
				WHEN a.Payer_Code IN('RR') AND a.Product_Code IN('H') THEN 'MEDICARE'
				WHEN a.Payer_Code IN('RR') AND a.Product_Code IN('S') THEN 'MEDICARE'
				WHEN a.Payer_Code IN('RC') AND a.Product_Code IN('P') THEN 'MEDICARE'
/*				WHEN a.Payer_Code IN('ND') AND a.Product_Code IN('H') THEN 'DSNP' Comes under Medicare, Medicaid, and DSNP.*/
/*				WHEN a.Payer_Code IN('NR') AND a.Product_Code IN('H') THEN 'DSNP' Comes under Medicare and DSNP.*/
				WHEN a.Payer_Code IN('ND') AND a.Product_Code IN('H') THEN 'MEDICAID' /*Comes under Medicare, Medicaid, and DSNP.*/
				WHEN a.Payer_Code IN('NR') AND a.Product_Code IN('H') THEN 'MEDICAID' /*Comes under Medicare and DSNP.*/
				WHEN a.Payer_Code IN('D') AND a.Product_Code IN('H') THEN 'MEDICAID'
				WHEN a.Payer_Code IN('M') AND a.Product_Code IN('H') THEN 'MEDICAID'
				WHEN a.Payer_Code IN('MD') AND a.Product_Code IN('H') THEN 'MEDICAID'
				WHEN a.Payer_Code IN('ML') AND a.Product_Code IN('H') THEN 'MEDICAID'
				WHEN a.Payer_Code IN('ND') AND a.Product_Code IN('H') THEN 'MEDICAID'
				WHEN a.Payer_Code IN('MR') AND a.Product_Code IN('H') THEN 'MEDICAID'
				ELSE 'error'
			END AS LOB ,
			a.measure ,
			a.rpt_submeasure /*Maps 'measure' and 'rpt_submeasure' values to 'meas_sub_map' values.*/ ,
			CASE
				WHEN a.measure IN('BCSE') AND a.rpt_submeasure IN('TOTAL') THEN 'BCS'
/*				WHEN a.measure IN('CDC') AND a.rpt_submeasure IN('A1C<8','A1C<=9','A1C>9') THEN 'CDC'*/
				WHEN a.measure IN('EED', 'KED', 'HBD') THEN 'CDC'
				WHEN a.measure IN('CIS') AND a.rpt_submeasure IN('COMBO 7') THEN 'CIS'
				WHEN a.measure IN('COLE') AND a.rpt_submeasure IN('TOTAL') THEN 'COL'
				WHEN a.measure IN('PPC') AND a.rpt_submeasure IN('POSTPARTUM') THEN 'POSTPARTUM'
				WHEN a.measure IN('PPC') AND a.rpt_submeasure IN('PRENATAL') THEN 'PRENATAL'
				WHEN a.measure IN('CBP') AND a.rpt_submeasure IN('TOTAL') THEN 'CBP'
/*				WHEN a.measure IN('CDC') AND a.rpt_submeasure IN('A1C<8') THEN 'HBD'*/
				WHEN a.measure IN('GSD') AND a.rpt_submeasure IN('A1C<8') THEN 'HBD'
/*				WHEN a.measure IN('HBD') AND a.rpt_submeasure IN('A1C<8') THEN 'HBD'*/
				WHEN a.measure IN('WCV') AND a.rpt_submeasure IN('TOTAL') THEN 'WCV'
				WHEN a.measure IN('W30') AND a.rpt_submeasure IN('WELL CHILD VISITS IN THE FIRST 15 MONTHS') THEN 'W30'
				WHEN a.measure IN('WCC') AND a.rpt_submeasure IN('PHYS ACT TOTAL') THEN 'WCC'
				WHEN a.measure IN('AMM') AND a.rpt_submeasure IN('CONTINUATION PHASE') THEN 'AMM'
				WHEN a.measure IN('IET') AND a.rpt_submeasure IN('EGMT TOTAL','INIT TOTAL') THEN 'IET'
				WHEN a.measure IN('FUH') AND a.rpt_submeasure IN('TOTAL 30 DAYS') THEN 'FUH'
				WHEN a.measure IN('FUM') AND a.rpt_submeasure IN('30 DAY TOTAL AGES') THEN 'FUM'
				WHEN a.measure IN('SSD') AND a.rpt_submeasure IN('DIABETES SCREENING') THEN 'SSD'
				ELSE ' '
			END AS meas_sub_map ,
			b.gender ,
			b.age ,
			b.member_county ,
			a.numercnt ,
			a.denomcnt ,
			b.RATE_AREA ,
			b.RATE_AREA_DESCRIPTION ,
			(b.RATE_AREA||" : "||b.RATE_AREA_DESCRIPTION) AS cohort
		FROM hedis.summary_5yr AS a
		LEFT JOIN IRADWELIG AS b ON a.mbr_nbr = b.member_id
		WHERE a.denomcnt > 0 and year=2024
			AND a.Claim_Month = 13
/*			AND a.measure IN('BCS','CDC','CIS','COL','COL','PPC','CBP','WCV','W30','WCC','AMM','IET','FUH','FUM','SSD','HBD')*/
            AND a.measure IN('BCSE', 'CDC',	'EED', 'KED', 'GSD', 'HBD',	'CIS',	'COLE',	'PPC',	'PPC',	'CBP',	'CDC',	'WCV',	'W30',	'WCC',	'AMM',	'IET',	'FUH',	'FUM',	'SSD')
			AND a.rpt_submeasure IN('TOTAL', 'COMBO 7','POSTPARTUM','PRENATAL', 'A1C<=9','A1C<8','WELL CHILD VISITS IN THE FIRST 15 MONTHS','PHYS ACT TOTAL' ,'CONTINUATION PHASE','EGMT TOTAL','INIT TOTAL' ,'TOTAL 30 DAYS','30 DAY TOTAL AGES','DIABETES SCREENING',
									'EYE EXAM', '' )
		ORDER BY a.rpt_submeasure ,
				a.Year ,
				a.Claim_Month;
	quit;

	/*Ends Macro %Bring_in_HEDIS.*/
%MEND Bring_in_HEDIS;

%Bring_in_HEDIS;

Proc SQL;
Create Table test12345 as
Select measure,rpt_submeasure, meas_sub_map,count(*) as cnt
From HEDIS_Summary
Group by measure, rpt_submeasure, meas_sub_map;
Quit;

Data HEDIS_Summary ;
set HEDIS_Summary ;
If upcase(strip(member_county)) = 'DE BACA' then  member_county = 'DEBACA';
Else if (strip(member_county)) = 'DONA ANA' then  member_county = 'DONAANA';
Else if (strip(member_county)) = 'RIO ARRIBA' then  member_county = 'RIOARRIBA';
Else if (strip(member_county)) = 'SAN JUAN' then  member_county = 'SANJUAN';
Else if (strip(member_county)) = 'SAN MIGUEL' then  member_county = 'SANMIGUEL';
Else if (strip(member_county)) = 'SANTA FE' then  member_county = 'SANTAFE';
Else member_county = member_county;
run;

Data HEDIS_Summary ;
set HEDIS_Summary ;
If upcase(strip(member_county)) not in ('BERNALILLO',	'CATRON',	'CHAVES',	'CIBOLA',	'COLFAX',	'CURRY',	'DEBACA',	
										'DONAANA',	'EDDY',	'GRANT',	'GUADALUPE',	'HARDING',	'HIDALGO',	'LEA',	'LINCOLN',	
										'LOSALAMOS',	'LUNA',	'MCKINLEY',	'MORA',	'OTERO',	'QUAY',	'RIOARRIBA',	'ROOSEVELT',
										'SANDOVAL',	'SANJUAN',	'SANMIGUEL',	'SANTAFE',	'SIERRA',	'SOCORRO',	'TAOS',	
										'TORRANCE',	'UNION',	'VALENCIA') then member_county = 'NON-NM';
Else member_county = upcase(strip(member_county));
run;

/**/
/*/****pull out unique members from HEDIS data mart*******/
proc sql;
	create table work.IDENTITY_ID_LIST as 
	select distinct
			strip(Member_UCI) as IDENTITY_ID
	from work.HEDIS_Summary 
	where Member_UCI ^= " "
	order by IDENTITY_ID;
quit;
/**/
/*/*--------------------------------------------------------------------------------------------------------------------*/
/*-- SECTION 1.2: Macro for pulling demographics information from clarity*/
/*-- DESCRIPTION: Pulls in demographics like age group gender, Race from clarity.*/
/**/
/*-- INPUT/OUTPUT:*/
/*--- Input data: Summary[year] --> Multiple tables from clarity are joined to extract the information. */
/**/
/*--- Output data: HEDIS_Summary_[year]_dup --> Table of 16 columns. This datset contains patient ID's MRN, age_group,gender,ethnicity etc.*/
/*--------------------------------------------------------------------------------------------------------------------*/*/
/**/
			/*Connects to Epic Clarity via a SAS Pass-Through. Creates datasets containing demographic data for 1000 patients. */
			/*Demographic variable values are mapped per directions from stakeholders.*/;
%MACRO Pull_Demographics(ALIAS,id_name);
	/*Deletes work.DEMOGRAPHICS_&ID_NAME. in preparation for data appending.*/
	proc datasets lib=work memtype=data noprint;
		delete DEMOGRAPHICS_&ID_NAME.;
	run;

	/*Creates local macro variables that contain (1) [cc_obs]: number of observations in input dataset and (2) [cc_lists]: */
	/*number of lists containing 1000 observations.*/
	* EMPTY MACROS;
	%let cc_obs=;
	%let cc_lists=;

	/*Populating the macros created above.*/
	DATA _null_;
		SET work.&ID_NAME._list NOBS=SIZE;
		CALL symput("cc_obs",SIZE);
		CALL symput("cc_lists",ceil(SIZE/1000));
		STOP;
	run;

	/*Outputs contents of macro variables to SAS log.*/
	%put &=cc_obs;
	%put &=cc_lists;

	/*Creates datasets containing a list of 1000 patient IDs.*/
	%DO i=1 %TO &cc_lists.;

		DATA work.ID_LIST_&i.;
			SET work.&ID_NAME._list (keep=&ID_NAME.);

			IF &i.=1 THEN
				DO;
					IF _n_ LE 1000 THEN OUTPUT ID_LIST_&i.;
				END;
			ELSE
				DO;
					IF (&i.-1)*1000 LT _n_ LE &i.*1000 THEN OUTPUT work.ID_LIST_&i.;
				END;

			/*Creates macro variables containing a list of 1000 patient IDs.*/
			%IF &ID_NAME. = HSP_ACCOUNT_ID %THEN
				%DO;

			proc SQL noprint;
				SELECT DISTINCT &ID_NAME. INTO :&ID_NAME._list separated BY ','
					FROM work.ID_LIST_&i.;
			quit;

				%END;
			%ELSE
				%DO;

					proc SQL noprint;
						SELECT DISTINCT quote(strip(&ID_NAME.),"'") INTO :&ID_NAME._list separated BY ','
							FROM work.ID_LIST_&i.;
					quit;

				%END;

			/*Deletes datasets containing a list of 1000 patient IDs.*/
			proc datasets lib=work memtype=data noprint;
				delete ID_LIST_&i.;
			run;

			/*Connects to Epic Clarity via a SAS Pass-Through. Creates datasets containing demographic data for 1000 patients. */
			/*Demographic variable values are mapped per directions from stakeholders.*/
			Proc SQL;
				CONNECT TO ODBC AS CLARITY (DATASRC=CLARPROD_EDWETL AUTHDOMAIN=EDW_SAS_Login);
				CREATE TABLE work.DEMOGRAPHICS_&ID_NAME._&i. (COMPRESS=yes) AS
					SELECT DISTINCT *
					FROM CONNECTION TO CLARITY (
						SELECT DISTINCT
							%IF &ID_NAME. = HSP_ACCOUNT_ID %THEN
							%DO;
								E.PAT_ID ,
								P.PAT_MRN_ID ,
								H.HSP_ACCOUNT_ID ,
								ID.IDENTITY_ID
							%END;
							%ELSE %IF &ID_NAME. = IDENTITY_ID %THEN
								%DO;
									E.PAT_ID ,
									P.PAT_MRN_ID ,
									ID.IDENTITY_ID
								%END;
							%ELSE %IF &ID_NAME. = PAT_ID %THEN
							%DO;
								E.PAT_ID,
								P.PAT_MRN_ID,
								ID.IDENTITY_ID
							%END;
							,P.BIRTH_DATE,
							P.ZIP,
							(CASE
								WHEN UPPER(TRIM(CT.NAME)) IS NULL
								OR UPPER(TRIM(CT.NAME))IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'
								ELSE UPPER(TRIM(CT.NAME))
							END)
							COUNTY,
							(CASE
								WHEN UPPER(TRIM(S.NAME)) IS NULL
								OR UPPER(TRIM(S.NAME)) IN('NEED TO OBTAIN', 'UNKNOWN', 'DECLINED', 'NONE GIVEN', 'UNABLE TO ASK', 'REFUSED', 'CHOOSE NOT TO DISCLOSE', 'DON''T KNOW') THEN 'UNKNOWN'
								ELSE UPPER(TRIM(S.NAME))
							END)
							SEX,
							(CASE
								WHEN UPPER(TRIM(M.NAME)) IS NULL
								OR UPPER(TRIM(M.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'
								ELSE UPPER(TRIM(M.NAME))
							END)
							MARITAL_STATUS,
							(CASE
								WHEN UPPER(TRIM(RE.NAME)) IS NULL
								OR UPPER(TRIM(RE.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'
								ELSE UPPER(TRIM(RE.NAME))
							END)
							RELIGION,
/*							(CASE*/
/*								WHEN UPPER(TRIM(L.NAME)) IS NULL*/
/*								OR UPPER(TRIM(L.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'*/
/*								ELSE UPPER(TRIM(L.NAME))*/
/*							END)*/
/*							LANGUAGE,*/
							(CASE
								WHEN UPPER(TRIM(EG.NAME)) IS NULL
								OR UPPER(TRIM(EG.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW','MEXICAN','SPANISH','PUERTO RICAN','MEXICAN AMERICAN') THEN 'UNKNOWN'
								ELSE UPPER(TRIM(EG.NAME))
							END)
							ETHNICITY,
							(CASE
								WHEN UPPER(TRIM(EB.NAME)) IS NULL
								OR UPPER(TRIM(EB.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'
								ELSE UPPER(TRIM(EB.NAME))
							END)
							ETHNIC_BACKGROUND,
							(CASE
								WHEN UPPER(TRIM(PR.NAME)) IS NULL
								OR UPPER(TRIM(PR.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'
								WHEN UPPER(TRIM(PR.NAME)) IN('AMERICAN INDIAN OR ALASKA NATIVE') THEN 'NATIVE AMERICAN'
								WHEN UPPER(TRIM(PR.NAME)) IN('NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER') THEN 'PACIFIC ISLANDER'
								WHEN UPPER(TRIM(PR.NAME)) IN('AFRICAN AMERICAN OR BLACK') THEN 'BLACK'
								ELSE UPPER(TRIM(PR.NAME))
							END)
							RACE,
							(CASE
								WHEN UPPER(TRIM(GI.NAME)) IS NULL
								OR UPPER(TRIM(GI.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'
								WHEN UPPER(TRIM(GI.NAME)) IN('TRANSGENDER FEMALE / MALE-TO-FEMALE') THEN 'TRANS FEMALE'
								WHEN UPPER(TRIM(GI.NAME)) IN('TRANSGENDER MALE / FEMALE-TO-MALE') THEN 'TRANS MALE'
								ELSE UPPER(TRIM(GI.NAME))
							END)
							GENDER_IDENTITY,
							(CASE
								WHEN UPPER(TRIM(SX.NAME)) IS NULL
								OR UPPER(TRIM(SX.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'
								WHEN UPPER(TRIM(SX.NAME)) IN('SOMETHING ELSE') THEN 'OTHER'
								WHEN UPPER(TRIM(SX.NAME)) IN('STRAIGHT (NOT LESBIAN OR GAY)') THEN 'STRAIGHT'
								WHEN UPPER(TRIM(S.NAME)) IN('MALE','TRANSGENDER MALE / FEMALE-TO-MALE')
								AND UPPER(TRIM(SX.NAME)) IN('LESBIAN OR GAY') THEN 'GAY'
								WHEN UPPER(TRIM(S.NAME)) IN('FEMALE','TRANSGENDER FEMALE / MALE-TO-FEMALE')
								AND UPPER(TRIM(SX.NAME)) IN('LESBIAN OR GAY') THEN 'LESBIAN'
								ELSE UPPER(TRIM(SX.NAME))
							END)
							SEXUAL_ORIENTATION
						FROM PATIENT P 
							%IF &ID_NAME. = IDENTITY_ID OR &ID_NAME. = PAT_ID 
							%THEN
							%DO;
								/* BASICALLY ONLY BRING IN PATIENT INFORMATION*/
							%END;
						%ELSE
							%DO;
								LEFT JOIN HSP_ACCOUNT H ON P.PAT_ID = H.PAT_ID
							%END;
						LEFT JOIN IDENTITY_ID ID ON P.PAT_ID = ID.PAT_ID
						LEFT JOIN PATIENT_4 PT ON P.PAT_ID = PT.PAT_ID
						LEFT JOIN PAT_ENC E ON P.PAT_ID = E.PAT_ID
						LEFT JOIN CLARITY_DEP C ON E.DEPARTMENT_ID = C.DEPARTMENT_ID
						LEFT JOIN ZC_DISP_ENC_TYPE T ON E.ENC_TYPE_C = T.DISP_ENC_TYPE_C
						LEFT JOIN ETHNIC_BACKGROUND B ON P.PAT_ID = B.PAT_ID and B.LINE = 1
						LEFT JOIN PATIENT_RACE R ON P.PAT_ID = R.PAT_ID and R.LINE = 1
						LEFT JOIN PAT_SEXUAL_ORIENTATION SO ON P.PAT_ID = SO.PAT_ID and SO.LINE = 1
						LEFT JOIN ZC_COUNTY CT ON P.COUNTY_C=CT.COUNTY_C
						LEFT JOIN ZC_SEX S ON P.SEX_C = S.RCPT_MEM_SEX_C
						LEFT JOIN ZC_MARITAL_STATUS M ON P.MARITAL_STATUS_C = M.MARITAL_STATUS_C
						LEFT JOIN ZC_RELIGION RE ON P.RELIGION_C = RE.RELIGION_C
/*						LEFT JOIN ZC_LANGUAGE L ON P.LANGUAGE_C = L.LANGUAGE_C*/
						LEFT JOIN ZC_ETHNIC_GROUP EG ON P.ETHNIC_GROUP_C = EG.ETHNIC_GROUP_C
						LEFT JOIN ZC_ETHNIC_BKGRND EB ON B.ETHNIC_BKGRND_C = EB.ETHNIC_BKGRND_C
						LEFT JOIN ZC_PATIENT_RACE PR ON R.PATIENT_RACE_C = PR.PATIENT_RACE_C
						LEFT JOIN ZC_GENDER_IDENTITY GI ON PT.GENDER_IDENTITY_C = GI.GENDER_IDENTITY_C
						LEFT JOIN ZC_SEXUAL_ORIENTATION SX ON SO.SEXUAL_ORIENTATN_C = SX.SEXUAL_ORIENTATION_C
						WHERE &Alias..&ID_Name. IN(&&&ID_Name._list.)
							AND ID.IDENTITY_TYPE_ID = 333 );
				DISCONNECT FROM CLARITY;
			quit;

			/*Appends datasets containing demographics data for 1000 patient to a base 'Demographics' dataset.*/
			proc append base=work.DEMOGRAPHICS_&ID_NAME. DATA=work.DEMOGRAPHICS_&ID_NAME._&i. FORCE;
			run;

			/*Deletes datasets containing demographics data for 1000 patients.*/
			proc datasets lib=work memtype=data noprint;
				delete DEMOGRAPHICS_&ID_NAME._&i.;
			run;

	%END;
	run;

	/*Ends Macro %Pull_Demographics.*/
%MEND Pull_Demographics;

%Pull_Demographics(ID,IDENTITY_ID);

proc sql ;
connect to odbc
(DATASRC = IRADW_SAWESCPDSAPP00_UAT_IND  user="&cdisql_id." pw="&cdisql_pw.");

    create table WORK.SDOH_MBR_FINAL as
    select * from connection to odbc
    ( select distinct uci_id, DERIVEDLANGUAGE as LANGUAGE 
		from DM_M360.SDOH_SEF_SCORE 
		where DERIVEDLANGUAGESOURCE = 'PHP' and UCI_ID IS NOT NULL
);disconnect from odbc;
quit;

/*------------------------------------------------------------------------*/
/*DEMOGRAPHICS_IDENTITY_ID: 344,904 observations and 14 variables*/
/*SDOH_MBR_FINAL: 927,026 rows and 2 columns*/
/*------------------------------------------------------------------------*/
/*344,904 rows and 15 columns*/
Proc SQL;
Create Table DEMOGRAPHICS_IDENTITY_ID_NEW as
Select DEMO.*, SDOH.LANGUAGE
From DEMOGRAPHICS_IDENTITY_ID  as DEMO left join SDOH_MBR_FINAL as SDOH
on trim(DEMO.IDENTITY_ID) = trim(SDOH.uci_id);
Quit;
proc sql;
Create Table t1 as
Select LANGUAGE, Count(*) as cnt
From DEMOGRAPHICS_IDENTITY_ID_NEW
Group by LANGUAGE;
Quit;

/*		Proc SQL;*/
/*				CONNECT TO ODBC AS CLARITY (DATASRC=CLARPROD_EDWETL AUTHDOMAIN=EDW_SAS_Login);*/
/*				CREATE TABLE work.DEMOGRAPHICS (COMPRESS=yes) AS*/
/*					SELECT DISTINCT **/
/*					FROM CONNECTION TO CLARITY (*/
/*						SELECT DISTINCT*/
/*								p.PAT_ID ,*/
/*								P.PAT_MRN_ID ,*/
/*								ID.IDENTITY_ID,											*/
/*							(CASE*/
/*								WHEN UPPER(TRIM(GI.NAME)) IS NULL*/
/*								OR UPPER(TRIM(GI.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'*/
/*								WHEN UPPER(TRIM(GI.NAME)) IN('TRANSGENDER FEMALE / MALE-TO-FEMALE') THEN 'TRANS FEMALE'*/
/*								WHEN UPPER(TRIM(GI.NAME)) IN('TRANSGENDER MALE / FEMALE-TO-MALE') THEN 'TRANS MALE'*/
/*								ELSE UPPER(TRIM(GI.NAME))*/
/*							END)*/
/*							GENDER_IDENTITY,*/
/*							(CASE*/
/*								WHEN UPPER(TRIM(SX.NAME)) IS NULL*/
/*								OR UPPER(TRIM(SX.NAME)) IN('NEED TO OBTAIN','UNKNOWN','DECLINED','NONE GIVEN','UNABLE TO ASK','REFUSED','CHOOSE NOT TO DISCLOSE','DON''T KNOW') THEN 'UNKNOWN'*/
/*								WHEN UPPER(TRIM(SX.NAME)) IN('SOMETHING ELSE') THEN 'OTHER'*/
/*								WHEN UPPER(TRIM(SX.NAME)) IN('STRAIGHT (NOT LESBIAN OR GAY)') THEN 'STRAIGHT'*/
/*								WHEN UPPER(TRIM(S.NAME)) IN('MALE','TRANSGENDER MALE / FEMALE-TO-MALE')*/
/*								AND UPPER(TRIM(SX.NAME)) IN('LESBIAN OR GAY') THEN 'GAY'*/
/*								WHEN UPPER(TRIM(S.NAME)) IN('FEMALE','TRANSGENDER FEMALE / MALE-TO-FEMALE')*/
/*								AND UPPER(TRIM(SX.NAME)) IN('LESBIAN OR GAY') THEN 'LESBIAN'*/
/*								ELSE UPPER(TRIM(SX.NAME))*/
/*							END)*/
/*							SEXUAL_ORIENTATION*/
/*						FROM PATIENT P */
/*						LEFT JOIN IDENTITY_ID ID ON P.PAT_ID = ID.PAT_ID*/
/*						LEFT JOIN PATIENT_4 PT ON P.PAT_ID = PT.PAT_ID*/
/*						LEFT JOIN ZC_SEX S ON P.SEX_C = S.RCPT_MEM_SEX_C*/
/*						LEFT JOIN PAT_SEXUAL_ORIENTATION SO ON P.PAT_ID = SO.PAT_ID and SO.LINE = 1*/
/*						LEFT JOIN ZC_LANGUAGE L ON P.LANGUAGE_C = L.LANGUAGE_C*/
/*						LEFT JOIN ZC_GENDER_IDENTITY GI ON PT.GENDER_IDENTITY_C = GI.GENDER_IDENTITY_C*/
/*						LEFT JOIN ZC_SEXUAL_ORIENTATION SX ON SO.SEXUAL_ORIENTATN_C = SX.SEXUAL_ORIENTATION_C*/
/*						WHERE (IDENTITY_TYPE_ID = 333 and ID.IDENTITY_ID >0 )*/
/*);*/
/*				DISCONNECT FROM CLARITY;*/
/*			quit;*/


/*--------------------------------------------------------------------------------------------------------------------
-- SECTION 1.3: Pull out data from SDOH data mart
-- DESCRIPTION: Pulls in information for SDOH measures from SDOH dat amart in production and in developement.
--------------------------------------------------------------------------------------------------------------------*/
/*data sdoh_mbr_final;*/
/*	set PHP_SDOH.sdoh_mbr_final;*/
/*run;*/
/*/**/*/
/*/*PROC SORT DATA=PHPSDOH.HEALTHY_LIFESTYLE_SCORE_RANK OUT=PHP_LIFE NODUPKEY;*/*/
/*/*	BY L1_UCI;*/*/
/*/*RUN;*/*/
/**/;
/*DATA RACE_ETH;*/
/*	SET PHP_SDOH.sdoh_mbr_final;*/
/*RACE_FINAL2= DerivedRace;*/
/*ethnicity_final2=DerivedEthnicity;*/
/*Source=DerivedRaceSource;*/
/*KEEP   UCI RACE_FINAL2 ethnicity_final2  SOURCE ;*/
/*RUN;*/
proc sql;
connect to odbc
(DATASRC = IRADW_SAWESCPDSAPP00_UAT_IND  user="&cdisql_id." pw="&cdisql_pw.");

    create table work.SDOH_MBR_FINAL as
    select * from connection to odbc
    ( select * from DM_M360.SDOH_SEF_SCORE  
);disconnect from odbc;
quit;

DATA SDOH_MBR_FINAL;
SET SDOH_MBR_FINAL;
RENAME UCI_ID = UCI ;
RPLTHEME1_New = input(RPLTHEME1, best8.);
RPLTHEME2_New = input(RPLTHEME2, best8.);
RPLTHEME3_New = input(RPLTHEME2, best8.);
RPLTHEME4_New = input(RPLTHEME4, best8.);
drop RPLTHEME1 RPLTHEME2 RPLTHEME3 RPLTHEME4;
rename RPLTHEME1_New=RPLTHEME1 RPLTHEME2_New=RPLTHEME2 RPLTHEME3_New=RPLTHEME3 RPLTHEME4_New=RPLTHEME4; 
RUN;
DATA RACE_ETH;
	SET SDOH_MBR_FINAL;
RACE_FINAL2= DerivedRace;
ethnicity_final2=DerivedEthnicity;
Source=DerivedRaceSource;
KEEP   UCI RACE_FINAL2 ethnicity_final2  SOURCE ;
RUN;

/*--------------------------------------------------------------------------------------------------------------------
-- SECTION 2.1: Macro %Model_Data_Prep
-- DESCRIPTION: This macro runs for each HEDIS measure individually. It filters out the data for the year for \
	which statistics are required and prepares the data for the model. For e.g.removes missing values
	and defines thresholds for variable for grouping of categories into others. 
--------------------------------------------------------------------------------------------------------------------*/
%MACRO Model_Data_Prep(Source,Measure,Cutoff,Cutoff2,RangeYR,RangeMO);
	/*Creates local macros for use in %Do loops.*/
	%Let Factor=FACTOR;
	%Let Factor1=AGE_GROUP;
	%Let Factor2=Gender;
	%Let Factor3=ETHNICITY;
	%Let Factor4=RACE;
	%Let Factor5=COUNTY;
	%Let Factor6=ADI;
	%Let Factor7=FOOD_FLAG;
	%Let Factor8=HOUSE_FLAG;
	%Let Factor9=SOCIAL_SUPP_FLAG;
	%Let Factor10=LIFE_FLAG;
	%Let Factor11=EDU_FLAG;
	%Let Factor12=SOCIOECO;
	%Let Factor13=COMPDIS;
	%Let Factor14=MINORLANG;
	%Let Factor15=HOUSETRNS;
	%Let Factor16=TRANSPORT_FLAG;
	%Let Factor17=LANGUAGE;
	%Let Factor18=SEXUAL_ORIENTATION;
	%Let Factor19=GENDER_IDENTITY;
	%Let FactorN =19;

	/*Creates a dataset from [Source]_Joins with a set number of columns and a date range set determined by "Range" macro */
	/*parameter(s). This dataset is used for frequencies only.*/
	proc sql;
		CREATE TABLE work.&Source._&Measure._freq AS
		SELECT DISTINCT 
			UCI_ID_REF    AS MEMBER_UCI,
			Measure_Code,
			Measure_Description,
			Record_Count,
			Ref_Year,
			Ref_Month,
			Ref_Month_Name,
			Ref_Month_Limit,
			Numerator,
			Denominator,
			Value,
			Outcome_Linear,
			Outcome_Logistic,
			Age_Group,
			Race,
			Sou_Race,
			Ethnicity,
			Sou_Eth,
			Gender,
			County,
			ADI,
			FOOD_FLAG,
			HOUSE_FLAG,
			SOCIAL_SUPP_FLAG,
			LIFE_FLAG,
			EDU_FLAG,
			SOCIOECO,
			COMPDIS,
			MINORLANG,
			HOUSETRNS,
			TRANSPORT_FLAG,
			LOB,
			Language,
			Sexual_Orientation,
			GENDER_IDENTITY
		FROM work.&Source._Joins
		%IF &Source. = HEDIS %THEN %DO;
			WHERE Measure_Code IN("&Measure.")
				AND (Ref_Year IN(&RangeYR.)
				AND Ref_Month IN(&RangeMO.));
			%END;
		%ELSE %DO;
			WHERE Measure_Code IN("&Measure.")
				AND Ref_Year IN(&RangeYR.);
		%END; 
		;
	quit;

	proc sql;
		CREATE TABLE work.&Source._&Measure._other AS
		SELECT DISTINCT 
			UCI_ID_REF    AS MEMBER_UCI,
			Measure_Code,
			Measure_Description,
			Record_Count,
			Ref_Year,
			Ref_Month,
			Ref_Month_Name,
			Ref_Month_Limit,
			Numerator,
			Denominator,
			Value,
			Outcome_Linear,
			Outcome_Logistic,
			Age_Group,
			Race,
			Sou_Race,
			Ethnicity,
			Sou_Eth,
			Gender,
			County,
			ADI,
			FOOD_FLAG,
			HOUSE_FLAG,
			SOCIAL_SUPP_FLAG,
			LIFE_FLAG,
			EDU_FLAG,
			SOCIOECO,
			COMPDIS,
			MINORLANG,
			HOUSETRNS,
			TRANSPORT_FLAG,
			LOB,
			Language,
			Sexual_Orientation,
			GENDER_IDENTITY
		FROM work.&Source._Joins
		%IF &Source. = HEDIS %THEN %DO;
			WHERE Measure_Code IN("&Measure.")
				AND NOT (Ref_Year IN(&RangeYR.)
				AND Ref_Month IN(&RangeMO.));
		%END;
		%ELSE %DO;
			WHERE Measure_Code IN("&Measure.")
				AND NOT Ref_Year IN(&RangeYR.);
		%END;
		;
	quit;

	/*Initates a %Do loop that itterates through demographic/SDOH variables.*/
	%Do i=1 %To &FactorN;

		/*Runs frequencies on a demographic/SDOH variable and outputs to "_h" dataset.*/
		proc freq data=work.&Source._&Measure._freq ORDER=FREQ;
			tables &&Factor&i. /norow nocol nopercent missing out=work.&&Measure._&&Factor&i.._h;
		run;

		/*Takes category names from "_h" datasets and inserts them into an "_h" macro variable.*/
		/*The "_j" macro variable is created to suppress warning messages and is not used.*/
		proc sql noprint;
			SELECT DISTINCT quote(strip(&&Factor&i.),"'"), COUNT
				INTO :&&Measure._&&Factor&i.._h separated BY ',',
					 :&&Measure._&&Factor&i.._j
			FROM work.&&Measure._&&Factor&i.._h 
			%IF &&Factor&i. = COUNTY %THEN %DO;
				WHERE COUNT >= &Cutoff2.
				/*                  AND &&Factor&i. NOT IN('UNKNOWN')*/
				ORDER BY COUNT DESC;
			%END;
			%ELSE %DO;
				WHERE COUNT >= &Cutoff.
				/*                  AND &&Factor&i. NOT IN('UNKNOWN')*/
			ORDER BY COUNT DESC;
			%END;
		quit;

		/********** removing unknown as reference*******************/
		proc sql noprint;
			SELECT DISTINCT quote(strip(&&Factor&i.),"'"), COUNT
				INTO :&&Measure._&&Factor&i.._x separated BY ',',
					 :&&Measure._&&Factor&i.._y
			FROM work.&&Measure._&&Factor&i.._h 
			%IF &&Factor&i. = COUNTY %THEN %DO;
				WHERE COUNT >= &Cutoff2.
					AND &&Factor&i. NOT IN('UNKNOWN','Unknown','unknown')
				ORDER BY COUNT DESC;
			%END;
			%ELSE %DO;
			WHERE COUNT >= &Cutoff.
				AND &&Factor&i. NOT IN('UNKNOWN','Unknown','unknown')
			ORDER BY COUNT DESC;
			%END;
		quit;

	%End;

	/*Creates a dataset from [Source]_Joins with a set number of columns and a date range set determined by "Range" macro */
	/*parameter(s). Demographic/SDOH variable categories not found in the "_h" macro variable are mapped to "UNKNOWN" category.*/
	proc sql;
		CREATE TABLE work.&Source._&Measure._map AS
			SELECT DISTINCT 
				UCI_ID_REF    AS MEMBER_UCI,
				Measure_Code,
				Measure_Description,
				Record_Count,
				Ref_Year,
				Ref_Month,
				Ref_Month_Name,
				Ref_Month_Limit,
				Numerator,
				Denominator,
				Value,
				Outcome_Linear,
				Outcome_Logistic,
				CASE
					WHEN AGE_GROUP IN(&&&Measure._AGE_GROUP_h.) THEN AGE_GROUP
					ELSE 'OTHER'
				END AS AGE_GROUP,
				CASE
					WHEN RACE IN(&&&Measure._RACE_h.) THEN RACE
					ELSE 'OTHER'
				END AS RACE,
				Sou_Race,
				CASE
					WHEN ETHNICITY IN(&&&Measure._ETHNICITY_h.) THEN ETHNICITY
					ELSE 'OTHER'
				END AS ETHNICITY,
				Sou_Eth,
				CASE
					WHEN Gender IN(&&&Measure._Gender_h.) THEN Gender
					ELSE 'OTHER'
				END AS Gender,
				CASE
					WHEN COUNTY IN(&&&Measure._COUNTY_h.) THEN COUNTY
					ELSE 'OTHER'
				END AS COUNTY,
				CASE
					WHEN ADI IN(&&&Measure._ADI_h.) THEN ADI
					ELSE 'OTHER'
				END AS ADI,
				CASE
					WHEN FOOD_FLAG IN(&&&Measure._FOOD_FLAG_h.) THEN FOOD_FLAG
					ELSE 'OTHER'
				END AS FOOD_FLAG,
				CASE
					WHEN HOUSE_FLAG IN(&&&Measure._HOUSE_FLAG_h.) THEN HOUSE_FLAG
					ELSE 'OTHER'
				END AS HOUSE_FLAG,
				CASE
					WHEN SOCIAL_SUPP_FLAG IN(&&&Measure._SOCIAL_SUPP_FLAG_h.) THEN SOCIAL_SUPP_FLAG
					ELSE 'OTHER'
				END AS SOCIAL_SUPP_FLAG,
				CASE
					WHEN LIFE_FLAG IN(&&&Measure._LIFE_FLAG_h.) THEN LIFE_FLAG
					ELSE 'OTHER'
				END AS LIFE_FLAG,
				CASE
					WHEN EDU_FLAG IN(&&&Measure._EDU_FLAG_h.) THEN EDU_FLAG
					ELSE 'OTHER'
				END AS EDU_FLAG,
				CASE
					WHEN SOCIOECO IN(&&&Measure._SOCIOECO_h.) THEN SOCIOECO
					ELSE 'OTHER'
				END AS SOCIOECO,
				CASE
					WHEN COMPDIS IN(&&&Measure._COMPDIS_h.) THEN COMPDIS
					ELSE 'OTHER'
				END AS COMPDIS,
				CASE
					WHEN MINORLANG IN(&&&Measure._MINORLANG_h.) THEN MINORLANG
					ELSE 'OTHER'
				END AS MINORLANG,
				CASE
					WHEN HOUSETRNS IN(&&&Measure._HOUSETRNS_h.) THEN HOUSETRNS
					ELSE 'OTHER'
				END AS HOUSETRNS,
				CASE
					WHEN TRANSPORT_FLAG IN(&&&Measure._TRANSPORT_FLAG_h.) THEN TRANSPORT_FLAG
					ELSE 'OTHER'
				END AS TRANSPORT_FLAG,
				LOB,
					CASE
					WHEN LANGUAGE IN(&&&Measure._LANGUAGE_h.) THEN LANGUAGE
					ELSE 'OTHER'
				END AS LANGUAGE,
				CASE
					WHEN SEXUAL_ORIENTATION IN(&&&Measure._SEXUAL_ORIENTATION_h.) THEN SEXUAL_ORIENTATION
					ELSE 'OTHER'
				END AS SEXUAL_ORIENTATION,
				CASE
					WHEN GENDER_IDENTITY IN(&&&Measure._GENDER_IDENTITY_h.) THEN GENDER_IDENTITY
					ELSE 'OTHER'
				END AS GENDER_IDENTITY
			FROM work.&Source._Joins
		%IF &Source. = HEDIS %THEN %DO;
			WHERE Measure_Code IN("&Measure.")
				AND Ref_Year IN(&RangeYR.)
				AND Ref_Month IN(&RangeMO.)
			%END;
		%ELSE %DO;
			WHERE Measure_Code IN("&Measure.")
			AND Ref_Year IN(&RangeYR.)
		%END;
			ORDER BY UCI_ID_REF;
	quit;

	/*Initates a %Do loop that cycles through demographic and SDOH variables.*/
	%Do i=1 %To &FactorN;

		/*Initializes a local macro variable "_l" and gives it an value of PLACEHOLDER. Unlike the "_h" */
		/*macro variable, "_l" wont necessarily receive a value from the proc sql step below.*/
		%let &&Measure._&&Factor&i.._l = 'PLACEHOLDER';

		/*Initializes a global macro variable "_r" and "_s". */
		%global 
			&&Measure._&&Factor&i.._r
			&&Measure._&&Factor&i.._z
			&&Measure._&&Factor&i.._s
		;

		/*Macro variable "_r" contains the first value in the comma-delimited string held by macro variable "_h" (i.e. the variable category */
		/*with the highest count) and will be used later in the proc sql step below and in %Model_Logistic to assign a reference category.*/
		%let &&Measure._&&Factor&i.._r = %scan(%bquote(&&&&&Measure._&&Factor&i.._h.),1,',');

		/***macro variable for removing unknown as reference****/
		%let &&Measure._&&Factor&i.._z = %scan(%bquote(&&&&&Measure._&&Factor&i.._x.),1,',');

		/*Macro variable "_s" contains the name of a demographic/SDOH variable next to its corresponding value held in the */
		/*macro variable "_r" and will be used later in %Macro_Linear to assign a reference category.*/
		/*The value from macro variable "_r" embedded in other text and will be used later in %Macro_Linear.*/
		%let &&Measure._&&Factor&i.._s = %sysfunc(strip(%bquote(%str(%'&&Factor&i. )&&&&&Measure._&&Factor&i.._r.%str(%'n))));

		/*Runs frequencies on a demographic/SDOH variable and outputs to "_l" dataset.*/
		proc freq data=work.&Source._&Measure._map ORDER=FREQ;
			tables &&Factor&i. /norow nocol nopercent missing out=work.&&Measure._&&Factor&i.._l;
		run;

		/*Takes category names from "_l" datasets and inserts them into an "_l" macro variable. The "_k" macro variable is created to */
		/*suppress warning messages and is not used.*/
		proc sql noprint;
			SELECT DISTINCT quote(strip(&&Factor&i.),"'"),
				COUNT INTO :&&Measure._&&Factor&i.._l separated BY ',',:&&Measure._&&Factor&i.._k
			FROM work.&&Measure._&&Factor&i.._l
			WHERE COUNT < &Cutoff.
			ORDER BY COUNT DESC;
		quit;

	%End;

	/*Creates an analytical dataset from [Source]_[Measure]. Demographic/SDOH variable categories in the "_l" */
	/*macro variable are mapped to value in the "_r" macro variable.*/
	proc sql;
		CREATE TABLE work.&Source._&Measure. AS
			SELECT DISTINCT 
				MEMBER_UCI,
				Measure_Code,
				Measure_Description,
				Record_Count,
				Ref_Year,
				Ref_Month,
				Ref_Month_Name,
				Ref_Month_Limit,
				Numerator,
				Denominator,
				Value,
				Outcome_Linear,
				Outcome_Logistic,
				CASE
					WHEN AGE_GROUP IN(&&&Measure._AGE_GROUP_l.) THEN %sysfunc(quote(&&&Measure._AGE_GROUP_r,"'"))
					ELSE AGE_GROUP
				END AS AGE_GROUP,
				CASE
					WHEN RACE IN(&&&Measure._RACE_l.) THEN %sysfunc(quote(&&&Measure._RACE_r,"'"))
					ELSE RACE
				END AS RACE,
				Sou_Race,
				CASE
					WHEN ETHNICITY IN(&&&Measure._ETHNICITY_l.) THEN %sysfunc(quote(&&&Measure._ETHNICITY_r,"'"))
					ELSE ETHNICITY
				END AS ETHNICITY,
				Sou_Eth,
				CASE
					WHEN Gender IN(&&&Measure._Gender_l.) THEN %sysfunc(quote(&&&Measure._Gender_r,"'"))
					ELSE Gender
				END AS Gender,
				CASE
					WHEN COUNTY IN(&&&Measure._COUNTY_l.) THEN %sysfunc(quote(&&&Measure._COUNTY_r,"'"))
					ELSE COUNTY
				END AS COUNTY,
				CASE
					WHEN ADI IN(&&&Measure._ADI_l.) THEN %sysfunc(quote(&&&Measure._ADI_r,"'"))
					ELSE ADI
				END AS ADI,
				CASE
					WHEN FOOD_FLAG IN(&&&Measure._FOOD_FLAG_l.) THEN %sysfunc(quote(&&&Measure._FOOD_FLAG_r,"'"))
					ELSE FOOD_FLAG
				END AS FOOD_FLAG,
				CASE
					WHEN HOUSE_FLAG IN(&&&Measure._HOUSE_FLAG_l.) THEN %sysfunc(quote(&&&Measure._HOUSE_FLAG_r,"'"))
					ELSE HOUSE_FLAG
				END AS HOUSE_FLAG,
				CASE
					WHEN SOCIAL_SUPP_FLAG IN(&&&Measure._SOCIAL_SUPP_FLAG_l.) THEN %sysfunc(quote(&&&Measure._SOCIAL_SUPP_FLAG_r,"'"))
					ELSE SOCIAL_SUPP_FLAG
				END AS SOCIAL_SUPP_FLAG,
				CASE
					WHEN LIFE_FLAG IN(&&&Measure._LIFE_FLAG_l.) THEN %sysfunc(quote(&&&Measure._LIFE_FLAG_r,"'"))
					ELSE LIFE_FLAG
				END AS LIFE_FLAG,
				CASE
					WHEN EDU_FLAG IN(&&&Measure._EDU_FLAG_l.) THEN %sysfunc(quote(&&&Measure._EDU_FLAG_r,"'"))
					ELSE EDU_FLAG
				END AS EDU_FLAG,
				CASE
					WHEN SOCIOECO IN(&&&Measure._SOCIOECO_l.) THEN %sysfunc(quote(&&&Measure._SOCIOECO_r,"'"))
					ELSE SOCIOECO
				END AS SOCIOECO,
				CASE
					WHEN COMPDIS IN(&&&Measure._COMPDIS_l.) THEN %sysfunc(quote(&&&Measure._COMPDIS_r,"'"))
					ELSE COMPDIS
				END AS COMPDIS,
				CASE
					WHEN MINORLANG IN(&&&Measure._MINORLANG_l.) THEN %sysfunc(quote(&&&Measure._MINORLANG_r,"'"))
					ELSE MINORLANG
				END AS MINORLANG,
				CASE
					WHEN HOUSETRNS IN(&&&Measure._HOUSETRNS_l.) THEN %sysfunc(quote(&&&Measure._HOUSETRNS_r,"'"))
					ELSE HOUSETRNS
				END AS HOUSETRNS,
				CASE
					WHEN TRANSPORT_FLAG IN(&&&Measure._TRANSPORT_FLAG_l.) THEN %sysfunc(quote(&&&Measure._TRANSPORT_FLAG_r,"'"))
					ELSE TRANSPORT_FLAG
				END AS TRANSPORT_FLAG,
				LOB,
								CASE
					WHEN LANGUAGE IN(&&&Measure._LANGUAGE_l.) THEN %sysfunc(quote(&&&Measure._LANGUAGE_r,"'"))
					ELSE LANGUAGE
				END AS LANGUAGE,
				CASE
					WHEN SEXUAL_ORIENTATION IN(&&&Measure._SEXUAL_ORIENTATION_l.) THEN %sysfunc(quote(&&&Measure._SEXUAL_ORIENTATION_r,"'"))
					ELSE SEXUAL_ORIENTATION
				END AS SEXUAL_ORIENTATION,
				CASE
					WHEN GENDER_IDENTITY IN(&&&Measure._GENDER_IDENTITY_l.) THEN %sysfunc(quote(&&&Measure._GENDER_IDENTITY_r,"'"))
					ELSE GENDER_IDENTITY
				END AS GENDER_IDENTITY
			FROM work.&Source._&Measure._map
			ORDER BY MEMBER_UCI;
	quit;

	/*Runs frequencies for QC.*/
	proc freq data=work.&Source._&Measure. order=freq;
		tables Age_Group Gender Ethnicity Race County ADI 
			/*BMI_Group*/
		FOOD_FLAG HOUSE_FLAG SOCIAL_SUPP_FLAG LIFE_FLAG EDU_FLAG LOB LANGUAGE SEXUAL_ORIENTATION GENDER_IDENTITY;
	run;

	**Append split work.[Source]_[Measure] datasets **;
	Proc sql;
		create table work.&Source._&Measure._Join as 
			select distinct *
			from work.&Source._&Measure._Other
			UNION ALL 
			select distinct *
			from work.&Source._&Measure.
		;
	quit;

	/*Deletes intermediate datasets.*/

	%_eg_conditional_dropds(work.&Measure._AGE_GROUP_H,
	work.&Measure._COUNTY_H,
	work.&Measure._ADI_H,
	work.&Measure._ETHNICITY_H,
	work.&Measure._RACE_H,
	work.&Measure._Gender_H,
	work.&Measure._FOOD_FLAG_H,
	work.&Measure._HOUSE_FLAG_H,
	work.&Measure._SOCIAL_SUPP_FLAG_H,
	work.&Measure._LIFE_FLAG_H,
	work.&Measure._EDU_FLAG_H,
	work.&Measure._SOCIOECO_H,
	work.&Measure._COMPDIS_H,
	work.&Measure._MINORLANG_H,
	work.&Measure._HOUSETRNS_H,
	work.&Measure._TRANSPORT_FLAG_H,
	work.&Measure._AGE_GROUP_L,
	work.&Measure._COUNTY_L,
	work.&Measure._ADI_L,
	work.&Measure._ETHNICITY_L,
	work.&Measure._RACE_L,
	work.&Measure._Gender_L,
	work.&Measure._FOOD_FLAG_L,
	work.&Measure._HOUSE_FLAG_L,
	work.&Measure._SOCIAL_SUPP_FLAG_L,
	work.&Measure._LIFE_FLAG_L,
	work.&Measure._EDU_FLAG_L,
	work.&Measure._SOCIOECO_L,
	work.&Measure._COMPDIS_L,
	work.&Measure._MINORLANG_L,
	work.&Measure._HOUSETRNS_L,
	work.&Measure._TRANSPORT_FLAG_L,
	work.&Source._&Measure._Freq,
	work.&Source._&Measure._Other,
	work.&Measure._LANGUAGE_L,
	work.&Measure._SEXUAL_ORIENTATION_L,
	work.&Measure._GENDER_IDENTITY_L,
	work.&Source._&Measure._Map);

	/*Ends Macro %Model_Data_Prep.*/
%MEND Model_Data_Prep;

/*--------------------------------------------------------------------------------------------------------------------
- SECTION 2.2 (%Model_Logistic)
-- DESCRIPTION: Runs a logistic regression model.

-- INPUT/OUTPUT:
--- Input data: [Source]_[Measure] --> Table of 34 columns. This is an analytical dataset. 

--- Output data: [Source]_[Measure]_EST --> Table of 8 columns. This datset contains parameter estimates from a 
	 logistic regression model (e.g. ProbChiSq). 

-- PARAMETERS:
--- source: name of "source" dataset - HEDIS
--- measure: name of "measure" - e.g. from HEDIS source is "BCS"
--------------------------------------------------------------------------------------------------------------------*/

/*Begins Macro %Model_Logistic.*/
%MACRO Model_Logistic(Source,Measure);
	/*Runs frequencies for QC.*/
	proc freq data=work.&Source._&Measure. order=freq;
		tables
			Age_Group
			Gender
			Ethnicity
			Language
			Sexual_Orientation
			GENDER_IDENTITY
			Race
			County 
			FOOD_FLAG
			HOUSE_FLAG
			SOCIAL_SUPP_FLAG
			LIFE_FLAG
			EDU_FLAG
			ADI
			SOCIOECO
			COMPDIS
			MINORLANG
			HOUSETRNS
			TRANSPORT_FLAG
			LOB
		;
	run;

	/*Runs a logisitic regression model and outputs parameter estimate values. Reference values for variables */
	/*in the CLASS statement are set to the value in the "_r" global macro variable.*/
	ods output ParameterEstimates = work.&Source._&Measure._PE;
	ods output CLParmPL = work.&Source._&Measure._CL;

	proc logistic data = work.&Source._&Measure. descending;
		class 
			Age_Group (REF=%sysfunc(quote(&&&Measure._AGE_GROUP_z,"'"))) 
			Race (REF=%sysfunc(quote(&&&Measure._RACE_z,"'"))) 
			Ethnicity (REF=%sysfunc(quote(&&&Measure._ETHNICITY_z,"'"))) 
			Gender (REF=%sysfunc(quote(&&&Measure._Gender_z,"'")))
			County (REF=%sysfunc(quote(&&&Measure._COUNTY_z,"'"))) 
			ADI (REF='1')
			FOOD_FLAG (REF=%sysfunc(quote(&&&Measure._FOOD_FLAG_z,"'"))) 
			HOUSE_FLAG (REF=%sysfunc(quote(&&&Measure._HOUSE_FLAG_z,"'"))) 
			SOCIAL_SUPP_FLAG (REF=%sysfunc(quote(&&&Measure._SOCIAL_SUPP_FLAG_z,"'"))) 
			LIFE_FLAG (REF=%sysfunc(quote(&&&Measure._LIFE_FLAG_z,"'"))) 
			EDU_FLAG (REF=%sysfunc(quote(&&&Measure._EDU_FLAG_z,"'"))) 
			SOCIOECO (REF=%sysfunc(quote(&&&Measure._SOCIOECO_z,"'"))) 
			COMPDIS (REF=%sysfunc(quote(&&&Measure._COMPDIS_z,"'"))) 
			MINORLANG (REF=%sysfunc(quote(&&&Measure._MINORLANG_z,"'"))) 
			HOUSETRNS (REF=%sysfunc(quote(&&&Measure._HOUSETRNS_z,"'"))) 
			TRANSPORT_FLAG (REF=%sysfunc(quote(&&&Measure._TRANSPORT_FLAG_z,"'")))
			Sexual_Orientation (REF=%sysfunc(quote(&&&Measure._SEXUAL_ORIENTATION_z,"'")))
			Language (REF=%sysfunc(quote(&&&Measure._LANGUAGE_z,"'")))
			GENDER_IDENTITY (REF=%sysfunc(quote(&&&Measure._GENDER_IDENTITY_z,"'")))
			/param = ref;
		model Outcome_Logistic = 
			Age_Group 
			Race 
			Ethnicity 
			Language
			Sexual_Orientation
			GENDER_IDENTITY
			Gender 
			County
			ADI 
			FOOD_FLAG
			HOUSE_FLAG
			SOCIAL_SUPP_FLAG
			LIFE_FLAG
			EDU_FLAG
			SOCIOECO
			COMPDIS
			MINORLANG
			HOUSETRNS
			TRANSPORT_FLAG

			/FIRTH CLPARM=PL;
	run;

	/*  ods _all_ close;*/
	/*Joins "_PE" and "_CL" datasets and cleans up output.*/
	proc sql;
		CREATE TABLE work.&Source._&Measure._EST AS
			SELECT a.Variable,
				a.ClassVal0,
				a.ProbChiSq,
				round(a.Estimate,
				0.01) AS Estimate,
				catx(',',
				round(LowerCL,0.01),
				round(UpperCL,0.01)) AS CI
			FROM work.&Source._&Measure._PE AS a
			LEFT JOIN work.&Source._&Measure._CL AS b ON a.Variable = b.Parameter
				AND a.ClassVal0 = b.ClassVal0
			WHERE VARIABLE NOT IN('Intercept')
				ORDER BY VARIABLE,
					ClassVal0;
	quit;

	/*Deletes intermediate datasets.*/

	%_eg_conditional_dropds(work.&Source._&Measure._CL,
		work.&Source._&Measure._PE);

	/*Ends Macro %Model_Logistic.*/
%MEND Model_Logistic;

/*Model mmacro to run regression without sexual orieentaion data mainly for kids measures when sexual orienataion data is unknown*/
%MACRO Model_Logistic_se(Source,Measure);
	/*Runs frequencies for QC.*/
	proc freq data=work.&Source._&Measure. order=freq;
		tables
			Age_Group
			Gender
			Ethnicity
			Language
			Sexual_Orientation
			GENDER_IDENTITY
			Race
			County 
			FOOD_FLAG
			HOUSE_FLAG
			SOCIAL_SUPP_FLAG
			LIFE_FLAG
			EDU_FLAG
			ADI
			SOCIOECO
			COMPDIS
			MINORLANG
			HOUSETRNS
			TRANSPORT_FLAG
			LOB
		;
	run;

	/*Runs a logisitic regression model and outputs parameter estimate values. Reference values for variables */
	/*in the CLASS statement are set to the value in the "_r" global macro variable.*/
	ods output ParameterEstimates = work.&Source._&Measure._PE;
	ods output CLParmPL = work.&Source._&Measure._CL;

	proc logistic data = work.&Source._&Measure. descending;
		class 
			Age_Group (REF=%sysfunc(quote(&&&Measure._AGE_GROUP_z,"'"))) 
			Race (REF=%sysfunc(quote(&&&Measure._RACE_z,"'"))) 
			Ethnicity (REF=%sysfunc(quote(&&&Measure._ETHNICITY_z,"'"))) 
			Gender (REF=%sysfunc(quote(&&&Measure._Gender_z,"'")))
			County (REF=%sysfunc(quote(&&&Measure._COUNTY_z,"'"))) 
			ADI (REF='1')
			FOOD_FLAG (REF=%sysfunc(quote(&&&Measure._FOOD_FLAG_z,"'"))) 
			HOUSE_FLAG (REF=%sysfunc(quote(&&&Measure._HOUSE_FLAG_z,"'"))) 
			SOCIAL_SUPP_FLAG (REF=%sysfunc(quote(&&&Measure._SOCIAL_SUPP_FLAG_z,"'"))) 
			LIFE_FLAG (REF=%sysfunc(quote(&&&Measure._LIFE_FLAG_z,"'"))) 
			EDU_FLAG (REF=%sysfunc(quote(&&&Measure._EDU_FLAG_z,"'"))) 
			SOCIOECO (REF=%sysfunc(quote(&&&Measure._SOCIOECO_z,"'"))) 
			COMPDIS (REF=%sysfunc(quote(&&&Measure._COMPDIS_z,"'"))) 
			MINORLANG (REF=%sysfunc(quote(&&&Measure._MINORLANG_z,"'"))) 
			HOUSETRNS (REF=%sysfunc(quote(&&&Measure._HOUSETRNS_z,"'"))) 
			TRANSPORT_FLAG (REF=%sysfunc(quote(&&&Measure._TRANSPORT_FLAG_z,"'")))
/*			Sexual_Orientation (REF=%sysfunc(quote(&&&Measure._SEXUAL_ORIENTATION_z,"'")))*/
			Language (REF=%sysfunc(quote(&&&Measure._LANGUAGE_z,"'")))
			GENDER_IDENTITY (REF=%sysfunc(quote(&&&Measure._GENDER_IDENTITY_z,"'")))
			/param = ref;
		model Outcome_Logistic = 
			Age_Group 
			Race 
			Ethnicity 
			Language
/*			Sexual_Orientation*/
			GENDER_IDENTITY
			Gender 
			County
			ADI 
			FOOD_FLAG
			HOUSE_FLAG
			SOCIAL_SUPP_FLAG
			LIFE_FLAG
			EDU_FLAG
			SOCIOECO
			COMPDIS
			MINORLANG
			HOUSETRNS
			TRANSPORT_FLAG

			/FIRTH CLPARM=PL;
	run;

	/*  ods _all_ close;*/
	/*Joins "_PE" and "_CL" datasets and cleans up output.*/
	proc sql;
		CREATE TABLE work.&Source._&Measure._EST AS
			SELECT a.Variable,
				a.ClassVal0,
				a.ProbChiSq,
				round(a.Estimate,
				0.01) AS Estimate,
				catx(',',
				round(LowerCL,0.01),
				round(UpperCL,0.01)) AS CI
			FROM work.&Source._&Measure._PE AS a
			LEFT JOIN work.&Source._&Measure._CL AS b ON a.Variable = b.Parameter
				AND a.ClassVal0 = b.ClassVal0
			WHERE VARIABLE NOT IN('Intercept')
				ORDER BY VARIABLE,
					ClassVal0;
	quit;

	/*Deletes intermediate datasets.*/

	%_eg_conditional_dropds(work.&Source._&Measure._CL,
		work.&Source._&Measure._PE);

	/*Ends Macro %Model_Logistic.*/
%MEND Model_Logistic_se;

/*,                         */
/*                          work.&Source._&Measure._MAP,*/
/*                          work.&Source._&Measure._FREQ,*/
/*                          work.&Source._&Measure._OTHER*/

/*--------------------------------------------------------------------------------------------------------------------
- SECTION 2.3: Macro %Model_Post_Processing
-- DESCRIPTION: This macro processes the output of logistic regression model and creates significant values
based on Prob chi sq values
------------------------------------------------------------------------------------------*/

/*Begins Macro %Model_Post_Processing.*/
%MACRO Model_Post_Processing(Source,Measure,Year);
	/*Deletes '_OUT' in preparation for appending near the end of this macro.*/
	%_eg_conditional_dropds(work.&Source._&Measure._OUT);

	/*Creates local macros for use in %Do loops.*/
	%Let Factor=FACTOR;
	%Let Factor1=AGE_GROUP;
	%Let Factor2=Gender;
	%Let Factor3=ETHNICITY;
	%Let Factor4=RACE;
	%Let Factor5=COUNTY;
	%Let Factor6=ADI;
	%Let Factor7=FOOD_FLAG;
	%Let Factor8=HOUSE_FLAG;
	%Let Factor9=SOCIAL_SUPP_FLAG;
	%Let Factor10=LIFE_FLAG;
	%Let Factor11=EDU_FLAG;
	%Let Factor12=SOCIOECO;
	%Let Factor13=COMPDIS;
	%Let Factor14=MINORLANG;
	%Let Factor15=HOUSETRNS;
	%Let Factor16=TRANSPORT_FLAG;
	%Let Factor17=LANGUAGE;
	%Let Factor18=SEXUAL_ORIENTATION;
	%Let Factor19=GENDER_IDENTITY;
	%Let FactorN =19;

	%Do i=1 %To &FactorN;

		/*Subsets [Source]_[Measure]_EST by demographic/SDOH factor.*/
		proc sort data=work.&Source._&Measure._EST (where=(Variable=%sysfunc(quote(&&Factor&i.,"'")))) out=work.&&Measure._&&Factor&i.._I;
			by Variable ClassVal0 ProbChiSq;
		run;

		/*Creates a 'Cutoff' and 'Significance' variable.*/
		proc sql;
			CREATE TABLE work.&&Measure._&&Factor&i.._O AS
				SELECT %sysfunc(quote(&Measure.,"'")) AS Measure ,
					VARIABLE AS Variable ,
					ClassVal0 AS ClassVal ,
					ProbChiSq AS Probability ,
				CASE
					WHEN ProbChiSq ^= . AND ProbChiSq < 0.05 THEN '<0.05'
					WHEN ProbChiSq ^= . AND ProbChiSq >= 0.05 THEN '>=0.05'
					ELSE 'Not Calculated'
				END 
			AS Cutoff,
				CASE
					WHEN ProbChiSq ^= . AND ProbChiSq < 0.05 THEN 'Significant'
					WHEN ProbChiSq ^= . AND ProbChiSq >= 0.05 THEN 'Nonsignificant'
					ELSE 'Not Calculated'
				END 
			AS Significance ,
				CASE 
					WHEN ProbChiSq ^= . AND ProbChiSq < 0.05 AND Estimate >= 0.00 AND %sysfunc(quote(&Measure.,"'")) in ('Duration','MME','CDBR_1532','CDBR_919','CDBR_993','CDBR_996') THEN 'Orange'
					WHEN ProbChiSq ^= . AND ProbChiSq < 0.05 AND Estimate < 0.00 AND %sysfunc(quote(&Measure.,"'")) in ('Duration','MME','CDBR_1532','CDBR_919','CDBR_993','CDBR_996') THEN 'Green'
					WHEN ProbChiSq ^= . AND ProbChiSq < 0.05 AND Estimate >= 0.00 AND %sysfunc(quote(&Measure.,"'")) in ('Naloxone','BCS','CDC','CIS','COLE','POSTPARTUM','PRENATAL','CBP','HBD','WCV','W30','WCC','IET','AMM','FUH','FUM','SSD') THEN 'Green'
					WHEN ProbChiSq ^= . AND ProbChiSq < 0.05 AND Estimate < 0.00 AND %sysfunc(quote(&Measure.,"'")) in ('Naloxone','BCS','CDC','CIS','COLE','POSTPARTUM','PRENATAL','CBP','HBD','WCV','W30','WCC','IET','AMM','FUH','FUM','SSD') THEN 'Orange'
					WHEN ProbChiSq ^= . AND ProbChiSq >= 0.05 THEN 'Gray'
					ELSE 'White'
				END 
			AS Significance_Color length = 6 ,
				"Est. "||strip(put(Estimate,8.2))||"; C.I. "||CI AS Estimate_CI ,
				&Year. as Ref_Year
			FROM work.&&Measure._&&Factor&i.._I;
		quit;

		%if &&Factor&i. ^= ADI %then
			%do;
				/*Inserts line into "_O" dataset containing values for Measure, Variable, ClassVal, and Significance.*/
				proc sql;
					insert into work.&&Measure._&&Factor&i.._O(Measure,Variable,ClassVal,Significance,Significance_Color,Ref_Year)
						Values (%sysfunc(quote(&Measure.,"'")),%sysfunc(quote(&&Factor&i.,"'")),%sysfunc(quote(&&&&&Measure._&&Factor&i.._z,"'")),'Reference','Blue',&Year.);
				quit;

			%end;
		%else
			%do;
				/*Inserts line into "_O" dataset containing values for Measure, Variable, ClassVal, and Significance.*/
				proc sql;
					insert into work.&&Measure._&&Factor&i.._O(Measure,Variable,ClassVal,Significance,Significance_Color,Ref_Year)
						Values (%sysfunc(quote(&Measure.,"'")),%sysfunc(quote(&&Factor&i.,"'")),'1','Reference','Blue',&Year.);
				quit;

			%end;

		/*Appends "_O" datasets to base "_OUT" dataset.*/
		proc append base=work.&Source._&Measure._OUT data=work.&&Measure._&&Factor&i.._O;
		run;

		/*Deletes intermediate datasets.*/

		%_eg_conditional_dropds(work.&&Measure._&&Factor&i.._I,
			work.&&Measure._&&Factor&i.._O);
	%End;

	/*Ends Macro %Model_Post_Processing.*/
%MEND Model_Post_Processing;

/*--------------------------------------------------------------------------------------------------------------------
- SECTION 2.4: %Build_Output
-- DESCRIPTION: Creates a dataset for dashboard use. 

-- INPUT/OUTPUT:
--- Input data: (1) [Source]_Statistics -->  This dataset consists of appended 
 [Source]_[Measure]_OUT datasets. 

(2) [Source]_Summarize -->  This is a summarized version of the [Source]_Joins dataset
and contains summarized values (e.g. pat_count, numerator, denominator, and value). 

--- Output data: [Source]_Output -->  This dataset contains, [Source], all data needed to build 
 a Tableau dashboard.

-- PARAMETERS:
--- source: name of "source" dataset - HEDIS
--------------------------------------------------------------------------------------------------------------------*/

**Begins Macro %Build_Output**;
%MACRO Build_Output(Source);
	/*Joins [Source]_Summarize table with [Source]_Statistics tables.*/
	proc sql;
		CREATE TABLE work.&Source._Output AS
		SELECT CASE
					WHEN a.Measure_Code = 'PRENATAL' THEN 'PPC_Prenatal'
					WHEN a.Measure_Code = 'POSTPARTUM' THEN 'PPC_Postpartum'
					ELSE a.Measure_Code
				END AS Measure,
				a.Measure_Description,
				put(md5(upper(strip(a.MEMBER_UCI))),$hex32.) AS PAT_ID,
				a.Ref_Year,
				a.Ref_Month,
				a.Ref_Month_Name,
				a.Numerator,
				a.Denominator,
				a.Record_Count,
				a.Outcome_Linear AS Value,
				CASE
					WHEN a.Age_Group = ' ' THEN 'UNKNOWN'
					ELSE a.Age_Group
				END AS Age_Group,
				b.Probability AS Age_Group_Prob,
				b.Cutoff AS Age_Group_Cutoff,
				b.Significance AS Age_Group_Sig,
				b.Significance_Color AS Age_Group_Sig_Color,
				b.Estimate_CI AS Age_Group_Est_CI,
				CASE
					WHEN a.Race = ' ' THEN 'UNKNOWN'
					ELSE a.Race
				END AS Race,
				a.Sou_Race AS SOURCE_RACE,
				d.Probability AS Race_Prob,
				d.Cutoff AS Race_Cutoff,
				d.Significance AS Race_Sig,
				d.Significance_Color AS Race_Sig_Color,
				d.Estimate_CI AS Race_Est_CI,
				CASE
					WHEN a.Ethnicity = ' ' THEN 'Unknown'
					ELSE a.Ethnicity
				END AS Ethnicity,
				a.Sou_Eth AS SOURCE_ETHNICITY,
				e.Probability AS Ethnicity_Prob,
				e.Cutoff AS Ethnicity_Cutoff,
				e.Significance AS Ethnicity_Sig,
				e.Significance_Color AS Ethnicity_Sig_Color,
				e.Estimate_CI AS Ethnicity_Est_CI,
				CASE
					WHEN a.Gender = ' ' THEN 'UNKNOWN'
					ELSE a.Gender
				END AS Gender,
				g.Probability AS Gender_Prob,
				g.Cutoff AS Gender_Cutoff,
				g.Significance AS Gender_Sig,
				g.Significance_Color AS Gender_Sig_Color,
				g.Estimate_CI AS Gender_Est_CI,
				CASE
			   		WHEN a.Sexual_Orientation = ' ' THEN 'UNKNOWN'
			   		ELSE a.Sexual_Orientation
		   		END AS Sexual_Orientation ,
	   			v.Probability AS Sexual_Orientation_Prob ,
	   			v.Cutoff AS Sexual_Orientation_Cutoff ,
	   			v.Significance AS Sexual_Orientation_Sig ,
	   			v.Significance_Color AS Sexual_Orientation_Sig_Color ,
	   			v.Estimate_CI AS Sexual_Orientation_Est_CI ,
				CASE
					WHEN a.Gender_Identity = ' ' THEN 'UNKNOWN'
					ELSE a.Gender_Identity
				END AS Gender_Identity,
				x.Probability AS Gender_Identity_Prob,
				x.Cutoff AS Gender_Identity_Cutoff,
				x.Significance AS Gender_Identity_Sig,
				x.Significance_Color AS Gender_Identity_Sig_Color,
				x.Estimate_CI AS Gender_Identity_Est_CI,
				CASE
		   			WHEN a.Language = ' ' THEN 'UNKNOWN'
		   			ELSE a.Language
		   		END AS Language ,
		   		w.Probability AS Language_Prob ,
		   		w.Cutoff AS Language_Cutoff ,
		   		w.Significance AS Language_Sig ,
		   		w.Significance_Color AS Language_Sig_Color ,
		   		w.Estimate_CI AS Language_Est_CI ,
				CASE
					WHEN a.County = ' ' THEN 'UNKNOWN'
					ELSE a.County
				END AS County,
				i.Probability AS County_Prob,
				i.Cutoff AS County_Cutoff,
				i.Significance AS County_Sig,
				i.Significance_Color AS County_Sig_Color,
				i.Estimate_CI AS County_Est_CI,
				CASE
					WHEN a.FOOD_FLAG = ' ' THEN 'UNKNOWN'
					ELSE a.FOOD_FLAG
				END AS FOOD_FLAG,
				l.Probability AS FOOD_FLAG_Prob,
				l.Cutoff AS FOOD_FLAG_Cutoff,
				l.Significance AS FOOD_FLAG_Sig,
				l.Significance_Color AS FOOD_FLAG_Sig_Color,
				l.Estimate_CI AS FOOD_FLAG_Est_CI,
				CASE
					WHEN a.HOUSE_FLAG = ' ' THEN 'UNKNOWN'
					ELSE a.HOUSE_FLAG
				END AS HOUSE_FLAG,
				m.Probability AS HOUSE_FLAG_Prob,
				m.Cutoff AS HOUSE_FLAG_Cutoff,
				m.Significance AS HOUSE_FLAG_Sig,
				m.Significance_Color AS HOUSE_FLAG_Sig_Color,
				m.Estimate_CI AS HOUSE_FLAG_Est_CI,
				CASE
					WHEN a.SOCIAL_SUPP_FLAG = ' ' THEN 'UNKNOWN'
					ELSE a.SOCIAL_SUPP_FLAG
				END AS SOCIAL_SUPP_FLAG,
				n.Probability AS SOCIAL_SUPP_FLAG_Prob,
				n.Cutoff AS SOCIAL_SUPP_FLAG_Cutoff,
				n.Significance AS SOCIAL_SUPP_FLAG_Sig,
				n.Significance_Color AS SOCIAL_SUPP_FLAG_Sig_Color,
				n.Estimate_CI AS SOCIAL_SUPP_FLAG_Est_CI,
				CASE
					WHEN a.LIFE_FLAG = ' ' THEN 'UNKNOWN'
					ELSE a.LIFE_FLAG
				END AS LIFE_FLAG,
				o.Probability AS LIFE_FLAG_Prob,
				o.Cutoff AS LIFE_FLAG_Cutoff,
				o.Significance AS LIFE_FLAG_Sig,
				o.Significance_Color AS LIFE_FLAG_Sig_Color,
				o.Estimate_CI AS LIFE_FLAG_Est_CI,
				CASE
					WHEN a.EDU_FLAG = ' ' THEN 'UNKNOWN'
					ELSE a.EDU_FLAG
				END AS EDU_FLAG,
				p.Probability AS EDU_FLAG_Prob,
				p.Cutoff AS EDU_FLAG_Cutoff,
				p.Significance AS EDU_FLAG_Sig,
				p.Significance_Color AS EDU_FLAG_Sig_Color,
				p.Estimate_CI AS EDU_FLAG_Est_CI,
				CASE
					WHEN a.SOCIOECO = ' ' THEN 'UNKNOWN'
					ELSE a.SOCIOECO
				END AS SOCIOECO,
				q.Probability AS SOCIOECO_Prob,
				q.Cutoff AS SOCIOECO_Cutoff,
				q.Significance AS SOCIOECO_Sig,
				q.Significance_Color AS SOCIOECO_Sig_Color,
				q.Estimate_CI AS SOCIOECO_Est_CI,
				CASE
					WHEN a.COMPDIS = ' ' THEN 'UNKNOWN'
					ELSE a.COMPDIS
				END AS COMPDIS,
				r.Probability AS COMPDIS_Prob,
				r.Cutoff AS COMPDIS_Cutoff,
				r.Significance AS COMPDIS_Sig,
				r.Significance_Color AS COMPDIS_Sig_Color,
				r.Estimate_CI AS COMPDIS_Est_CI,
				CASE
					WHEN a.MINORLANG = ' ' THEN 'UNKNOWN'
					ELSE a.MINORLANG
				END AS MINORLANG,
				s.Probability AS MINORLANG_Prob,
				s.Cutoff AS MINORLANG_Cutoff,
				s.Significance AS MINORLANG_Sig,
				s.Significance_Color AS MINORLANG_Sig_Color,
				s.Estimate_CI AS MINORLANG_Est_CI,
				CASE
					WHEN a.HOUSETRNS = ' ' THEN 'UNKNOWN'
					ELSE a.HOUSETRNS
				END AS HOUSETRNS,
				t.Probability AS HOUSETRNS_Prob,
				t.Cutoff AS HOUSETRNS_Cutoff,
				t.Significance AS HOUSETRNS_Sig,
				t.Significance_Color AS HOUSETRNS_Sig_Color,
				t.Estimate_CI AS HOUSETRNS_Est_CI,
				a.ADI AS ADI,
				k.Probability AS ADI_Prob,
				k.Cutoff AS ADI_Cutoff,
				k.Significance AS ADI_Sig,
				k.Significance_Color AS ADI_Sig_Color,
				k.Estimate_CI AS ADI_Est_CI,
				CASE
					WHEN a.TRANSPORT_FLAG = ' ' THEN 'UNKNOWN'
					ELSE a.TRANSPORT_FLAG
				END AS TRANSPORT_FLAG,
				u.Probability AS TRANSPORT_FLAG_Prob,
				u.Cutoff AS TRANSPORT_FLAG_Cutoff,
				u.Significance AS TRANSPORT_FLAG_Sig,
				u.Significance_Color AS TRANSPORT_FLAG_Sig_Color,
				u.Estimate_CI AS TRANSPORT_FLAG_Est_CI,
				a.LOB,
				a.member_uci
		FROM work.&Source._Summarize AS a
		LEFT JOIN work.&Source._Statistics AS b ON a.Measure_Code = b.Measure AND a.Ref_Year = b.Ref_Year AND a.Age_Group = b.ClassVal AND b.Variable = 'AGE_GROUP'
		LEFT JOIN work.&Source._Statistics AS d ON a.Measure_Code = d.Measure AND a.Ref_Year = d.Ref_Year AND a.Race = d.ClassVal AND d.Variable = 'RACE'
		LEFT JOIN work.&Source._Statistics AS e ON a.Measure_Code = e.Measure AND a.Ref_Year = e.Ref_Year AND a.Ethnicity = e.ClassVal AND e.Variable = 'ETHNICITY'
		LEFT JOIN work.&Source._Statistics AS g ON a.Measure_Code = g.Measure AND a.Ref_Year = g.Ref_Year AND a.Gender = g.ClassVal AND g.Variable = 'Gender'
		LEFT JOIN work.&Source._Statistics AS i ON a.Measure_Code = i.Measure AND a.Ref_Year = i.Ref_Year AND a.County = i.ClassVal AND i.Variable = 'COUNTY'
		LEFT JOIN work.&Source._Statistics AS k ON a.Measure_Code = k.Measure AND a.Ref_Year = k.Ref_Year AND a.ADI = k.Classval AND k.Variable = 'ADI'
		LEFT JOIN work.&Source._Statistics AS l ON a.Measure_Code = l.Measure AND a.Ref_Year = l.Ref_Year AND a.FOOD_FLAG = l.ClassVal AND l.Variable = 'FOOD_FLAG'
		LEFT JOIN work.&Source._Statistics AS m ON a.Measure_Code = m.Measure AND a.Ref_Year = m.Ref_Year AND a.HOUSE_FLAG = m.ClassVal AND m.Variable = 'HOUSE_FLAG'
		LEFT JOIN work.&Source._Statistics AS n ON a.Measure_Code = n.Measure AND a.Ref_Year = n.Ref_Year AND a.SOCIAL_SUPP_FLAG = n.ClassVal AND n.Variable = 'SOCIAL_SUPP_FLAG'
		LEFT JOIN work.&Source._Statistics AS o ON a.Measure_Code = o.Measure AND a.Ref_Year = o.Ref_Year AND a.LIFE_FLAG = o.ClassVal AND o.Variable = 'LIFE_FLAG'
		LEFT JOIN work.&Source._Statistics AS p ON a.Measure_Code = p.Measure AND a.Ref_Year = p.Ref_Year AND a.EDU_FLAG = p.ClassVal AND p.Variable = 'EDU_FLAG'
		LEFT JOIN work.&Source._Statistics AS q ON a.Measure_Code = q.Measure AND a.Ref_Year = q.Ref_Year AND a.SOCIOECO = q.ClassVal AND q.Variable = 'SOCIOECO'
		LEFT JOIN work.&Source._Statistics AS r ON a.Measure_Code = r.Measure AND a.Ref_Year = r.Ref_Year AND a.COMPDIS = r.ClassVal AND r.Variable = 'COMPDIS'
		LEFT JOIN work.&Source._Statistics AS s ON a.Measure_Code = s.Measure AND a.Ref_Year = s.Ref_Year AND a.MINORLANG = s.ClassVal AND s.Variable = 'MINORLANG'
		LEFT JOIN work.&Source._Statistics AS t ON a.Measure_Code = t.Measure AND a.Ref_Year = t.Ref_Year AND a.HOUSETRNS = t.ClassVal AND t.Variable = 'HOUSETRNS'
		LEFT JOIN work.&Source._Statistics AS u ON a.Measure_Code = u.Measure AND a.Ref_Year = u.Ref_Year AND a.TRANSPORT_FLAG = u.ClassVal AND u.Variable = 'TRANSPORT_FLAG'
		LEFT JOIN work.&Source._Statistics AS v ON a.Measure_Code = v.Measure AND a.Ref_Year = v.Ref_Year AND a.SEXUAL_ORIENTATION = v.ClassVal AND v.Variable = 'SEXUAL_ORIENTATION'
		LEFT JOIN work.&Source._Statistics AS w ON a.Measure_Code = w.Measure AND a.Ref_Year = w.Ref_Year AND a.Language = w.ClassVal AND W.Variable = 'LANGUAGE'
		LEFT JOIN work.&Source._Statistics AS x ON a.Measure_Code = x.Measure AND a.Ref_Year = x.Ref_Year AND a.GENDER_IDENTITY = x.ClassVal AND x.Variable = 'GENDER_IDENTITY'
		ORDER BY a.MEMBER_UCI,
				MEASURE,
				Ref_Year,
				Ref_Month,
				Age_Group,
				Race,
				Ethnicity,
				Gender,
				LANGUAGE,
		 		Sexual_Orientation,
				GENDER_IDENTITY,
				County,
				ADI,
				FOOD_FLAG,
				HOUSE_FLAG,
				SOCIAL_SUPP_FLAG,
				LIFE_FLAG,
				EDU_FLAG,
				SOCIOECO,
				COMPDIS,
				MINORLANG,
				HOUSETRNS,
				TRANSPORT_FLAG
		;
	quit;

	/*Ends Macro %Build_Output.*/
%MEND Build_Output;

/*--------------------------------------------------------------------------------------------------------------------
- SECTION 3.1: Add SDOH measure with HEDIS Population
-- DESCRIPTION: Merge SDOH measures with HEDIS population

-- PARAMETERS:
--- source: name of "source" dataset - HEDIS
--------------------------------------------------------------------------------------------------------------------*/
proc sort data= sdoh_mbr_final out= sdoh_mbr_final2 nodupkey;
	by uci   ;
run;

data sdoh_mbr_final3;
	set sdoh_mbr_final2;
	uci_1= uci*1;
	rename UCI= L1_UCI;
run;

/****collate information from multiple SDOH sources in one table****/
PROC SQL;
	CREATE TABLE ADI_PHP AS 
		SELECT DISTINCT POP.L1_UCI ,
				CASE
					WHEN POP.DerivedFoodInsecure ='1' THEN 'Yes'
					WHEN POP.DerivedFoodInsecure ='0' THEN 'No'
					ELSE 'Unknown'
				END AS FOOD_FLAG ,
				CASE
					WHEN POP.DerivedHouseInsecure ='1' THEN 'Yes'
					WHEN POP.DerivedHouseInsecure ='0' THEN 'No'
					ELSE 'Unknown'
				END AS HOUSE_FLAG ,
				CASE
					WHEN POP.DerivedSocialInsecure ='1' THEN 'Yes'
					WHEN POP.DerivedSocialInsecure ='0' THEN 'No'
					ELSE 'Unknown'
				END AS SOCIAL_SUPP_FLAG,
				CASE
					WHEN POP.DerivedTransportInsecure ='1' THEN 'Yes'
					WHEN POP.DerivedTransportInsecure ='0' THEN 'No'
					ELSE 'Unknown'
				END AS TRANSPORT_FLAG,
				POP.DerivedFoodSource AS SOURCE_FI,
				POP.DerivedHouseSource AS SOURCE_HI,
				POP.DerivedSocialSource AS SOURCE_SI,
				POP.DerivedTransportSource AS SOURCE_TI,
				UPPER(POP.DerivedEthnicitySource) as SOU_ETH,
				UPPER(POP.DerivedRaceSource) as SOU_RACE,
				CASE
					WHEN POP.HealthyLifestyle = '1' THEN 'LIFESTYLE' 
					ELSE '' 
				END AS LIFE_FLAG,
				CASE
					WHEN POP.EducationLevel IN ('College',
												'Graduate School') THEN 'Educated'
					WHEN POP.EducationLevel IN ('High School',
												'Vocational') THEN 'Not Educated'
					ELSE 'UNKNOWN'
				END AS EDU_FLAG,
				POP.ADISTATERNK,
				CASE
					WHEN (POP.RPLTHEME1 > 0.7) THEN 'High'
					WHEN (POP.RPLTHEME1 BETWEEN 0.4 AND 0.7) THEN 'Mid'
					WHEN (POP.RPLTHEME1 BETWEEN 0.0 AND 0.3) THEN 'Low'
					ELSE ''
				END AS SOCIOECO,
				CASE
					WHEN (POP.RPLTHEME2 > 0.7) THEN 'High'
					WHEN (POP.RPLTHEME2 BETWEEN 0.4 AND 0.7) THEN 'Mid'
					WHEN (POP.RPLTHEME2 BETWEEN 0.0 AND 0.3) THEN 'Low'
					ELSE ''
				END AS COMPDIS,
				CASE
					WHEN (POP.RPLTHEME3 > 0.7) THEN 'High'
					WHEN (POP.RPLTHEME3 BETWEEN 0.4 AND 0.7) THEN 'Mid'
					WHEN (POP.RPLTHEME3 BETWEEN 0.0 AND 0.3) THEN 'Low'
					ELSE ''
				END AS MINORLANG,
				CASE
					WHEN (POP.RPLTHEME4 > 0.7) THEN 'High'
					WHEN (POP.RPLTHEME4 BETWEEN 0.4 AND 0.7) THEN 'Mid'
					WHEN (POP.RPLTHEME4 BETWEEN 0.0 AND 0.3) THEN 'Low'
					ELSE ''
				END AS HOUSETRNS,
				DerivedLanguage as LANGUAGE
		FROM sdoh_mbr_final3 POP
/*		LEFT JOIN PHP_LIFE B ON B.L1_UCI = POP.UCI_1*/
		ORDER BY POP.L1_UCI;
QUIT;


/******Merge SDOH measures with base HEDIS population ******************/
proc sql;
	create table HEDIS_Join as 
		SELECT DISTINCT 
CASE
					WHEN b.PAT_ID = " " THEN a.MEMBER_UCI
					ELSE b.PAT_ID
				END AS PAT_ID ,
				CASE
					WHEN b.PAT_MRN_ID = " " THEN a.MEMBER_UCI
					ELSE b.PAT_MRN_ID
				END AS PAT_MRN_ID ,
				a.MEMBER_UCI AS UCI_ID,
				b.IDENTITY_ID AS UCI_ID ,
				. AS Record_Count ,
				a.Year AS Ref_Year ,
				a.Month AS Ref_Month ,
				a.Month_Name AS Ref_Month_Name ,
				CASE
					WHEN a.Month IN(13) THEN 12
					ELSE a.Month
				END AS Ref_Month_Limit ,
				a.meas_sub_map AS Measure ,
				a.meas_sub_map AS Measure_Code ,
				" " AS Measure_Description ,
				a.numercnt AS Numerator ,
				a.denomcnt AS Denominator ,
				. AS Outcome_Linear ,
				a.numercnt AS Outcome_Logistic ,
				. AS Value,
				CASE
					WHEN A.Age>0
						 AND A.Age<=18 THEN "0-18"
					WHEN A.Age>18
						 AND A.Age<=24 THEN "19-24"
					WHEN A.Age>24
						 AND A.Age<=34 THEN "25-34"
					WHEN A.Age>34
						 AND A.Age<=44 THEN "35-44"
					WHEN A.Age>44
						 AND A.Age<=54 THEN "45-54"
					WHEN A.Age>54
						 AND A.Age<=64 THEN "55-64"
					WHEN A.Age>64
						 AND A.Age<=74 THEN "65-74"
					WHEN A.Age>74 THEN "75+"
					ELSE 'UNKNOWN'
				END AS AGE_GROUP,
				CASE
					WHEN A.Gender IN('F') THEN 'Female'
					WHEN A.Gender IN('M') THEN 'Male'
					ELSE 'UNKNOWN'
				END AS Gender,
				CASE
					WHEN UPPER(TRIM(C.Derivedethnicity)) IN('HISPANIC OR LATINO',
															'HISPANIC',
															'HISPANIC/LATINO') THEN 'HISPANIC OR LATINO'
					WHEN UPPER(TRIM(C.Derivedethnicity)) IN('NOT HISPANIC/LATINO',
															'NOT HISPANIC OR LATINO',
															'NOT OF HISPANIC OR LATINO OR SPANISH ORIGIN',
															'NOT OF HISPANIC, LATINO OR SPANISH ORIGIN',
															'NOT OF HISPANIC OR LATINO OR SPANISH ORIGIN') THEN 'NOT HISPANIC OR LATINO'
					ELSE C.Derivedethnicity
				END AS ETHNICITY,
/*				CASE*/
/*					WHEN UPPER(TRIM(B.ETHNICITY)) IN('HISPANIC OR LATINO',*/
/*													 'HISPANIC') THEN 'HISPANIC OR LATINO'*/
/*					WHEN UPPER(TRIM(B.ETHNICITY)) IN('NOT HISPANIC OR LATINO',*/
/*													 'NOT OF HISPANIC OR LATINO OR SPANISH ORIGIN',*/
/*													 'NOT OF HISPANIC, LATINO OR SPANISH ORIGIN',*/
/*													 'NOT OF HISPANIC OR LATINO OR SPANISH ORIGIN') THEN 'NOT HISPANIC OR LATINO'*/
/*					ELSE B.ETHNICITY*/
/*				END AS CLARITY_ETH,*/
				CASE
					WHEN UPPER(TRIM(C.DerivedRace)) IN('AFRICAN AMERICAN AND WHITE',
													   'ASIAN AND WHITE',
													   'ASIAN/PACIFIC ISLANDER',
													   'MULTIRACIAL') THEN 'Two or More Races'
					WHEN UPPER(TRIM(C.DerivedRace)) IN('ASIAN') THEN 'ASIAN'
					WHEN UPPER(TRIM(C.DerivedRace)) IN('AMERICAN INDIAN',
													   'NATIVE AMERICAN',
													   'NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER',
													   'PACIFIC ISLANDER') THEN 'PACIFIC ISLANDER'
					WHEN UPPER(TRIM(C.DerivedRace)) IN('AMERICAN INDIAN OR ALASKA NATIVE AND AFRICAN AMERICAN',
													   'AMERICAN INDIAN OR ALASKA NATIVE AND WHITE') THEN 'NATIVE AMERICAN'
					WHEN UPPER(TRIM(C.DerivedRace)) IN('BLACK',
													   'BLACK/AFRICAN AMERICAN') THEN 'BLACK'
					WHEN UPPER(TRIM(C.DerivedRace)) IN('CAUCASIAN',
													   'WHITE') THEN 'WHITE'
					WHEN UPPER(TRIM(C.DerivedRace)) IN("OTHER") THEN 'OTHER'
					ELSE C.DerivedRace
				END AS RACE,
/*				CASE*/
/*					WHEN UPPER(TRIM(B.RACE)) IN('AFRICAN AMERICAN AND WHITE',*/
/*												'ASIAN AND WHITE',*/
/*												'ASIAN/PACIFIC ISLANDER',*/
/*												'MULTIRACIAL') THEN 'Two or More Races'*/
/*					WHEN UPPER(TRIM(B.RACE)) IN('ASIAN') THEN 'ASIAN'*/
/*					WHEN UPPER(TRIM(B.RACE)) IN('AMERICAN INDIAN',*/
/*												'NATIVE AMERICAN',*/
/*												'NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER',*/
/*												'PACIFIC ISLANDER') THEN 'PACIFIC ISLANDER'*/
/*					WHEN UPPER(TRIM(B.RACE)) IN('AMERICAN INDIAN OR ALASKA NATIVE AND AFRICAN AMERICAN',*/
/*												'AMERICAN INDIAN OR ALASKA NATIVE AND WHITE') THEN 'NATIVE AMERICAN'*/
/*					WHEN UPPER(TRIM(B.RACE)) IN('BLACK',*/
/*												'BLACK/AFRICAN AMERICAN') THEN 'BLACK'*/
/*					WHEN UPPER(TRIM(B.RACE)) IN('CAUCASIAN',*/
/*												'WHITE') THEN 'WHITE'*/
/*					WHEN UPPER(TRIM(B.RACE)) IN("OTHER") THEN 'OTHER'*/
/*					ELSE B.RACE*/
/*				END AS CLARITY_RACE,*/
/*				F.SOURCE,*/
				A.Member_County AS COUNTY,
				CASE
					WHEN C.adistaternk IN('10') THEN '10'
					WHEN C.adistaternk IN('9') THEN '9'
					WHEN C.adistaternk IN('8') THEN '8'
					WHEN C.adistaternk IN('7') THEN '7'
					WHEN C.adistaternk IN('6') THEN '6'
					WHEN C.adistaternk IN('5') THEN '5'
					WHEN C.adistaternk IN('4') THEN '4'
					WHEN C.adistaternk IN('3') THEN '3'
					WHEN C.adistaternk IN('2') THEN '2'
					WHEN C.adistaternk IN('1') THEN '1'
					ELSE 'Unknown'
				END AS ADI,
				CASE
					WHEN d.FOOD_FLAG IN(' ') THEN 'Unknown'
					ELSE d.FOOD_FLAG
				END AS FOOD_FLAG,
				CASE
					WHEN d.HOUSE_FLAG IN(' ') THEN 'Unknown'
					ELSE d.HOUSE_FLAG
				END AS HOUSE_FLAG,
				CASE
					WHEN d.SOCIAL_SUPP_FLAG IN(' ') THEN 'Unknown'
					ELSE d.SOCIAL_SUPP_FLAG
				END AS SOCIAL_SUPP_FLAG,
				CASE
					WHEN d.TRANSPORT_FLAG IN(' ') THEN 'Unknown'
					ELSE d.TRANSPORT_FLAG
				END AS TRANSPORT_FLAG,
				d.source_HI,
				d.source_FI,
				d.source_SI,
				d.source_TI,
				SOU_RACE,
				SOU_ETH,
				CASE
					WHEN d.LIFE_FLAG IN(' ') THEN 'UNKNOWN'
					ELSE d.LIFE_FLAG
				END AS LIFE_FLAG,
				CASE
					WHEN d.EDU_FLAG IN(' ') THEN 'UNKNOWN'
					ELSE d.EDU_FLAG
				END AS EDU_FLAG,
				CASE
					WHEN D.SOCIOECO IN(' ') THEN 'UNKNOWN'
					ELSE D.SOCIOECO
				END AS SOCIOECO,
				CASE
					WHEN D.COMPDIS IN(' ') THEN 'UNKNOWN'
					ELSE D.COMPDIS
				END AS COMPDIS,
				CASE
					WHEN D.MINORLANG IN(' ') THEN 'UNKNOWN'
					ELSE D.MINORLANG
				END AS MINORLANG,
				CASE
					WHEN D.HOUSETRNS IN(' ') THEN 'UNKNOWN'
					ELSE D.HOUSETRNS
				END AS HOUSETRNS,
				UPPER(A.LOB) AS LOB,
				case 
				 when D.LANGUAGE in(' ') then 'UNKNOWN'
				 else D.LANGUAGE 
				 end                          as LANGUAGE
				,case 
				 when b.SEXUAL_ORIENTATION in(' ') then 'UNKNOWN'
				 else b.SEXUAL_ORIENTATION 
				 end                          as SEXUAL_ORIENTATION
				 ,case 
				 when b.GENDER_IDENTITY in(' ') then 'UNKNOWN'
				 else b.GENDER_IDENTITY 
				 end                          as GENDER_IDENTITY
		FROM HEDIS_SUMMARY AS A
		LEFT JOIN DEMOGRAPHICS_IDENTITY_ID_NEW AS B ON A.MEMBER_UCI = b.IDENTITY_ID /***output of pull_demographics macro convert this to IRADW****/
		LEFT JOIN sdoh_mbr_final3 AS C ON A.MEMBER_UCI = C.L1_UCI
/*		LEFT JOIN RACE_ETH F ON A.MEMBER_UCI = STRIP((F.UCI))*/
		LEFT JOIN ADI_PHP AS D ON A.MEMBER_UCI = D.L1_UCI
		WHERE A.MEMBER_UCI ^= " "
			AND A.MEAS_SUB_MAP ^= " ";
QUIT;
PROC SQL;
SELECT DISTINCT  GENDER, GENDER_IDENTITY
FROM HEDIS_JOIN;
QUIT;


data HEDIS_JOINS_2;
	set HEDIS_JOIN;
		if LANGUAGE in("UNKNOWN","","*UNSPECIFIED") then
		LANGUAGE= 'Unknown';
	else if race in ('OTHER','Other Race') then
		race = 'Other';
	if race in("UNKNOWN","","Unknown(Missing)") then
		race= 'Unknown';
	else if race in ('OTHER','Other Race') then
		race = 'Other';
	else if race in ('BLACK','Black or African American') then
		race= 'Black or African American';

	if sou_race in ('','MISSING') then
		sou_race= 'No Source';

	if SOU_ETH in ('','MISSING') then
		SOU_ETH = 'No Source';

	if sou_race in ('HSD') then
		sou_race= 'PHP';

	if SOU_ETH in ('HSD') then
		SOU_ETH = 'PHP';

	if ethnicity in ('','UNKNOWN') then
		ethnicity= 'Unknown';

	if lob= 'ERROR' then
		lob= 'UNKNOWN';
run;

data HEDIS_JOINS;
	set HEDIS_JOINS_2;
UCI_ID_REF=UCI_ID;
	if sou_eth= 'No Source' then
		ethnicity= 'Unknown';
	if sou_race= 'No Source' then
		race= 'Unknown';
run;

proc contents data=HEDIS_JOINS varnum;
run;

/*--------------------------------------------------------------------------------------------------------------------
- SECTION 3.2: Create statistical output for HEDIS measures
-- DESCRIPTION: Run macros for data prearation, logistic regression, output processing for each of the HEDIS
	measures seperately

-- PARAMETERS:
--- source: name of "source" dataset - HEDIS
--------------------------------------------------------------------------------------------------------------------*/
%Model_Data_Prep(HEDIS,BCS,20,80,2024,13);
%Model_Data_Prep(HEDIS,CDC,20,80,2024,13);
%Model_Data_Prep(HEDIS,CIS,20,80,2024,13);
%Model_Data_Prep(HEDIS,COL,20,80,2024,13);
%Model_Data_Prep(HEDIS,POSTPARTUM,20,80,2024,13);
%Model_Data_Prep(HEDIS,PRENATAL,20,80,2024,13);
%Model_Data_Prep(HEDIS,CBP,20,80,2024,13);
%Model_Data_Prep(HEDIS,HBD,20,80,2024,13);
%Model_Data_Prep(HEDIS,WCV,20,80,2024,13);
%Model_Data_Prep(HEDIS,W30,20,80,2024,13);
%Model_Data_Prep(HEDIS,WCC,20,80,2024,13);
%Model_Data_Prep(HEDIS,AMM,20,80,2024,13);
%Model_Data_Prep(HEDIS,IET,20,80,2024,13);
%Model_Data_Prep(HEDIS,FUH,20,80,2024,13);
%Model_Data_Prep(HEDIS,FUM,20,80,2024,13);
%Model_Data_Prep(HEDIS,SSD,20,80,2024,13);

**Append work.&Source._&Measure._Join datasets**;
Proc sql;
	create table work.HEDIS_Append_Joins as 
		select distinct *
		from work.HEDIS_BCS_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_CDC_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_CIS_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_COL_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_POSTPARTUM_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_PRENATAL_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_CBP_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_HBD_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_WCV_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_W30_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_WCC_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_AMM_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_IET_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_FUH_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_FUM_Join
		UNION ALL 
		select distinct *
		from work.HEDIS_SSD_Join
	;
quit;

**Summarize HEDIS data.**;
proc SQL;
	CREATE TABLE work.HEDIS_Summarize AS
		SELECT DISTINCT Measure_Code,
			Measure_Description,
			MEMBER_UCI,
			Ref_Year,
			Ref_Month,
			Ref_Month_Name,
			Ref_Month_Limit,
			sum(Numerator)        AS Numerator,
			sum(Denominator)      AS Denominator,
			sum(Record_Count)     AS Record_Count,
			sum(Outcome_Linear)   AS Outcome_Linear,
			sum(Outcome_Logistic) AS Outcome_Logisitic,
			Age_Group,
			Race,
			Sou_Race,
			Ethnicity,
			Sou_Eth,
			Gender,
			Language,
			Sexual_Orientation,
			GENDER_IDENTITY,
			County,
			FOOD_FLAG,
			HOUSE_FLAG,
			SOCIAL_SUPP_FLAG,
			LIFE_FLAG,
			EDU_FLAG,
			ADI,
			SOCIOECO,
			COMPDIS,
			MINORLANG,
			HOUSETRNS,
			TRANSPORT_FLAG,
			LOB

		FROM work.HEDIS_Append_Joins
			WHERE mdy(Ref_Month_Limit, 1, Ref_Year) >= intnx('month',today(),-38)
				GROUP BY Measure_Code,
					MEMBER_UCI,
					Ref_year,
					Ref_month,
					Age_Group,
					Race,
					Sou_Race,
					Ethnicity,
					Sou_Eth,
					Gender,
					Language,
					Sexual_Orientation,
					GENDER_IDENTITY,
					County,
					FOOD_FLAG,
					HOUSE_FLAG,
					SOCIAL_SUPP_FLAG,
					LIFE_FLAG,
					EDU_FLAG,
					ADI,
					SOCIOECO,
					COMPDIS,
					MINORLANG,
					HOUSETRNS,
					TRANSPORT_FLAG,
					LOB
				ORDER BY Measure_Code,
					MEMBER_UCI,
					Ref_year,
					Ref_month,
					Age_Group,
					Race,
					Sou_Race,
					Ethnicity,
					Sou_Eth,
					Gender,
					Language,
					Sexual_Orientation,
					GENDER_IDENTITY,
					County,
					FOOD_FLAG,
					HOUSE_FLAG,
					SOCIAL_SUPP_FLAG,
					LIFE_FLAG,
					EDU_FLAG,
					ADI,
					SOCIOECO,
					COMPDIS,
					MINORLANG,
					HOUSETRNS,
					LOB;
quit;

proc sql;
	drop table HEDIS_Append_Joins;
quit;

%Model_Logistic(HEDIS,BCS);
%Model_Logistic(HEDIS,CDC);
%Model_Logistic(HEDIS,CIS);
%Model_Logistic(HEDIS,COL);
%Model_Logistic(HEDIS,POSTPARTUM);
%Model_Logistic(HEDIS,PRENATAL);
%Model_Logistic(HEDIS,CBP);
%Model_Logistic(HEDIS,HBD);
%Model_Logistic(HEDIS,WCV);
/*%Model_Logistic(HEDIS,W30);*/
%Model_Logistic(HEDIS,WCC);
%Model_Logistic(HEDIS,AMM);
%Model_Logistic(HEDIS,IET);
%Model_Logistic(HEDIS,FUH);
%Model_Logistic(HEDIS,FUM);
%Model_Logistic(HEDIS,SSD);

%Model_Post_Processing(HEDIS,BCS,2024);
%Model_Post_Processing(HEDIS,CDC,2024);
%Model_Post_Processing(HEDIS,CIS,2024);
%Model_Post_Processing(HEDIS,COL,2024);
%Model_Post_Processing(HEDIS,POSTPARTUM,2024);
%Model_Post_Processing(HEDIS,PRENATAL,2024);
%Model_Post_Processing(HEDIS,CBP,2024);
%Model_Post_Processing(HEDIS,HBD,2024);
%Model_Post_Processing(HEDIS,WCV,2024);
/*%Model_Post_Processing(HEDIS,W30,2024);*/
%Model_Post_Processing(HEDIS,WCC,2024);
%Model_Post_Processing(HEDIS,AMM,2024);
%Model_Post_Processing(HEDIS,IET,2024);
%Model_Post_Processing(HEDIS,FUH,2024);
%Model_Post_Processing(HEDIS,FUM,2024);
%Model_Post_Processing(HEDIS,SSD,2024);

/*********Bring in statistics of all the HEDIS meaures in one table**************/
Proc sql;
	create table work.HEDIS_Statistics as 
		SELECT *
		FROM work.HEDIS_BCS_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_CDC_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_CIS_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_COL_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_Postpartum_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_Prenatal_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_CBP_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_HBD_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_WCV_OUT
		UNION ALL
/*		SELECT **/
/*		FROM work.HEDIS_W30_OUT*/
/*		UNION ALL*/
		SELECT *
		FROM work.HEDIS_WCC_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_AMM_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_IET_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_FUH_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_FUM_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_SSD_OUT
	;
quit;

%Build_Output(HEDIS);

/*607,671 rows and 134 columns*/
proc sql;
	create table all_output3 as
		select a.*,b.DerivedFoodSource as SOURCE_FI
			,b.DerivedHouseSource as SOURCE_HI
			,b.DerivedSocialSource as SOURCE_SI
			,b.DerivedFinanceSource as Source_Finance
			,b.DerivedSafetySource as Source_Safety
			,b.DerivedTransportSource as source_TI
		from HEDIS_output a
			left join SDOH_MBR_FINAL3 b
				on a.member_uci= b.l1_uci;
quit;

/*********added cohorts from enrollment table**********/
/*607,671 rows and 135 columns*/
proc sql;
	create table all_output4 as
		select a.*,
			(b.rate_area||" : "||b.rate_area_description) as cohort
		from all_output3 a left join IRADWELIG b
			on a.member_uci= b.member_uci;
quit;
/*607,671 observations and 135 variables*/
data all_output5;
	set all_output4;

	if lob = 'UNKNOWN' then
		delete;
run;

/*--------------------------------------------------------------------------------------------------------------------
- SECTION 4.1: calculate statistics for medicaid Population
--------------------------------------------------------------------------------------------------------------------*/

/**********adding official statistics for medicaid*************/
/********filter the data only for medicaid***************/
/*409,780 observations and 43 variables*/
data HEDIS_medicaid_Joins;
	set HEDIS_JOINS;

	if lob= 'MEDICAID';
run;

%Model_Data_Prep(HEDIS_medicaid,BCS,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,CDC,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,CIS,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,COL,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,POSTPARTUM,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,PRENATAL,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,CBP,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,HBD,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,WCV,20,80,2024,13);
/*%Model_Data_Prep(HEDIS_medicaid,W30,20,80,2024,13);*/
%Model_Data_Prep(HEDIS_medicaid,WCC,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,AMM,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,IET,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,FUH,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,FUM,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicaid,SSD,20,80,2024,13);

%Model_Logistic(HEDIS_medicaid,BCS);
%Model_Logistic(HEDIS_medicaid,CDC);
/*%Model_Logistic(HEDIS_medicaid,CIS);*/
%Model_Logistic(HEDIS_medicaid,COL);
%Model_Logistic(HEDIS_medicaid,POSTPARTUM);
%Model_Logistic(HEDIS_medicaid,PRENATAL);
%Model_Logistic(HEDIS_medicaid,CBP);
%Model_Logistic(HEDIS_medicaid,HBD);
%Model_Logistic(HEDIS_medicaid,WCV);
/*%Model_Logistic(HEDIS_medicaid,W30);*/
%Model_Logistic(HEDIS_medicaid,WCC);
%Model_Logistic(HEDIS_medicaid,AMM);
%Model_Logistic(HEDIS_medicaid,IET);
%Model_Logistic(HEDIS_medicaid,FUH);
%Model_Logistic(HEDIS_medicaid,FUM);
%Model_Logistic(HEDIS_medicaid,SSD);

%Model_Post_Processing(HEDIS_medicaid,BCS,2024);
%Model_Post_Processing(HEDIS_medicaid,CDC,2024);
/*%Model_Post_Processing(HEDIS_medicaid,CIS,2024);*/
%Model_Post_Processing(HEDIS_medicaid,COL,2024);
%Model_Post_Processing(HEDIS_medicaid,POSTPARTUM,2024);
%Model_Post_Processing(HEDIS_medicaid,PRENATAL,2024);
%Model_Post_Processing(HEDIS_medicaid,CBP,2024);
%Model_Post_Processing(HEDIS_medicaid,HBD,2024);
%Model_Post_Processing(HEDIS_medicaid,WCV,2024);
/*%Model_Post_Processing(HEDIS_medicaid,W30,2023);*/
%Model_Post_Processing(HEDIS_medicaid,WCC,2024);
%Model_Post_Processing(HEDIS_medicaid,AMM,2024);
%Model_Post_Processing(HEDIS_medicaid,IET,2024);
%Model_Post_Processing(HEDIS_medicaid,FUH,2024);
%Model_Post_Processing(HEDIS_medicaid,FUM,2024);
%Model_Post_Processing(HEDIS_medicaid,SSD,2024);

Proc sql;
	create table work.HEDIS_medicaid_Statistics as 
		SELECT *
		FROM work.HEDIS_medicaid_BCS_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_CDC_OUT
/*		UNION ALL*/
/*		SELECT **/
/*		FROM work.HEDIS_medicaid_CIS_OUT*/
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_COL_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_Postpartum_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_Prenatal_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_CBP_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_HBD_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_WCV_OUT
		UNION ALL
/*		SELECT **/
/*		FROM work.HEDIS_medicaid_W30_OUT*/
/*		UNION ALL*/
		SELECT *
		FROM work.HEDIS_medicaid_WCC_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_AMM_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_IET_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_FUH_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_FUM_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicaid_SSD_OUT
	;
quit;

data HEDIS_medicaid_Statistics2;
	length measure $32.;
	set HEDIS_medicaid_Statistics;

	if Measure = 'PRENATAL' then
		Measure= 'PPC_Prenatal';
	else if Measure = 'POSTPARTUM' then
		Measure= 'PPC_Postpartum';
	lob= 'MEDICAID';
run;

/**********Merge Medicaid statistics with the final output************/
proc sql;
	create table all_output6 as
		select a.*,
			b.Probability AS Age_Group_Prob_mdcd ,
			b.Cutoff AS Age_Group_Cutoff_mdcd ,
			b.Significance AS Age_Group_Sig_mdcd ,
			b.Significance_Color AS Age_Group_Sig_Color_mdcd ,
			b.Estimate_CI AS Age_Group_Est_CI_mdcd ,
			d.Probability AS Race_Prob_mdcd ,
			d.Cutoff AS Race_Cutoff_mdcd ,
			d.Significance AS Race_Sig_mdcd ,
			d.Significance_Color AS Race_Sig_Color_mdcd ,
			d.Estimate_CI AS Race_Est_CI_mdcd ,
			e.Probability AS Ethnicity_Prob_mdcd ,
			e.Cutoff AS Ethnicity_Cutoff_mdcd ,
			e.Significance AS Ethnicity_Sig_mdcd ,
			e.Significance_Color AS Ethnicity_Sig_Color_mdcd ,
			e.Estimate_CI AS Ethnicity_Est_CI_mdcd ,
			g.Probability AS Gender_Prob_mdcd ,
			g.Cutoff AS Gender_Cutoff_mdcd ,
			g.Significance AS Gender_Sig_mdcd ,
			g.Significance_Color AS Gender_Sig_Color_mdcd ,
			g.Estimate_CI AS Gender_Est_CI_mdcd ,
			i.Probability AS County_Prob_mdcd ,
			i.Cutoff AS County_Cutoff_mdcd ,
			i.Significance AS County_Sig_mdcd ,
			i.Significance_Color AS County_Sig_Color_mdcd ,
			i.Estimate_CI AS County_Est_CI_mdcd ,
			l.Probability AS FOOD_FLAG_Prob_mdcd ,
			l.Cutoff AS FOOD_FLAG_Cutoff_mdcd ,
			l.Significance AS FOOD_FLAG_Sig_mdcd ,
			l.Significance_Color AS FOOD_FLAG_Sig_Color_mdcd ,
			l.Estimate_CI AS FOOD_FLAG_Est_CI_mdcd ,
			m.Probability AS HOUSE_FLAG_Prob_mdcd ,
			m.Cutoff AS HOUSE_FLAG_Cutoff_mdcd ,
			m.Significance AS HOUSE_FLAG_Sig_mdcd ,
			m.Significance_Color AS HOUSE_FLAG_Sig_Color_mdcd ,
			m.Estimate_CI AS HOUSE_FLAG_Est_CI_mdcd ,
			n.Probability AS SOCIAL_SUPP_FLAG_Prob_mdcd ,
			n.Cutoff AS SOCIAL_SUPP_FLAG_Cutoff_mdcd ,
			n.Significance AS SOCIAL_SUPP_FLAG_Sig_mdcd ,
			n.Significance_Color AS SOCIAL_SUPP_FLAG_Sig_Color_mdcd ,
			n.Estimate_CI AS SOCIAL_SUPP_FLAG_Est_CI_mdcd ,
			o.Probability AS LIFE_FLAG_Prob_mdcd ,
			o.Cutoff AS LIFE_FLAG_Cutoff_mdcd ,
			o.Significance AS LIFE_FLAG_Sig_mdcd ,
			o.Significance_Color AS LIFE_FLAG_Sig_Color_mdcd ,
			o.Estimate_CI AS LIFE_FLAG_Est_CI_mdcd ,
			p.Probability AS EDU_FLAG_Prob_mdcd ,
			p.Cutoff AS EDU_FLAG_Cutoff_mdcd ,
			p.Significance AS EDU_FLAG_Sig_mdcd ,
			p.Significance_Color AS EDU_FLAG_Sig_Color_mdcd ,
			p.Estimate_CI AS EDU_FLAG_Est_CI_mdcd ,
			q.Probability        AS SOCIOECO_Prob_mdcd ,
			q.Cutoff             AS SOCIOECO_Cutoff_mdcd ,
			q.Significance       AS SOCIOECO_Sig_mdcd ,
			q.Significance_Color AS SOCIOECO_Sig_Color_mdcd ,
			q.Estimate_CI        AS SOCIOECO_Est_CI_mdcd ,
			r.Probability        AS COMPDIS_Prob_mdcd ,
			r.Cutoff             AS COMPDIS_Cutoff_mdcd ,
			r.Significance       AS COMPDIS_Sig_mdcd ,
			r.Significance_Color AS COMPDIS_Sig_Color_mdcd ,
			r.Estimate_CI        AS COMPDIS_Est_CI_mdcd ,
			s.Probability        AS MINORLANG_Prob_mdcd ,
			s.Cutoff             AS MINORLANG_Cutoff_mdcd ,
			s.Significance       AS MINORLANG_Sig_mdcd ,
			s.Significance_Color AS MINORLANG_Sig_Color_mdcd ,
			s.Estimate_CI        AS MINORLANG_Est_CI_mdcd ,
			t.Probability        AS HOUSETRNS_Prob_mdcd ,
			t.Cutoff             AS HOUSETRNS_Cutoff_mdcd ,
			t.Significance       AS HOUSETRNS_Sig_mdcd ,
			t.Significance_Color AS HOUSETRNS_Sig_Color_mdcd ,
			t.Estimate_CI        AS HOUSETRNS_Est_CI_mdcd ,
			k.Probability AS ADI_Prob_mdcd ,
			k.Cutoff AS ADI_Cutoff_mdcd ,
			k.Significance AS ADI_Sig_mdcd ,
			k.Significance_Color AS ADI_Sig_Color_mdcd ,
			k.Estimate_CI AS ADI_Est_CI_mdcd ,
			u.Probability AS TI_Prob_mdcd ,
			u.Cutoff AS TI_Cutoff_mdcd ,
			u.Significance AS TI_Sig_mdcd ,
			u.Significance_Color AS TI_Sig_Color_mdcd ,
			u.Estimate_CI AS TI_Est_CI_mdcd ,
	   		v.Probability AS Sexual_Orientation_Prob_mdcd ,
	   		v.Cutoff AS Sexual_Orientation_Cutoff_mdcd ,
	   		v.Significance AS Sexual_Orientation_Sig_mdcd ,
	   		v.Significance_Color AS Sexual_Orient_Sig_Color_mdcd ,
	   		v.Estimate_CI AS Sexual_Orientation_Est_CI_mdcd ,
	   		w.Probability AS Language_Prob_mdcd ,
	   		w.Cutoff AS Language_Cutoff_mdcd ,
	   		w.Significance AS Language_Sig_mdcd ,
	   		w.Significance_Color AS Language_Sig_Color_mdcd ,
	   		w.Estimate_CI AS Language_Est_CI_mdcd,
			x.Probability AS Gender_Identity_Prob_mdcd ,
			x.Cutoff AS Gender_Identity_Cutoff_mdcd ,
			x.Significance AS Gender_Identity_Sig_mdcd ,
			x.Significance_Color AS Gender_Identity_Sig_Color_mdcd ,
			x.Estimate_CI AS Gender_Identity_Est_CI_mdcd 
		FROM all_output5 AS a
		LEFT JOIN HEDIS_medicaid_Statistics2 AS b ON a.Measure = b.Measure AND a.lob= b.lob AND a.Ref_Year = b.Ref_Year AND a.Age_Group = b.ClassVal AND b.Variable = 'AGE_GROUP'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS d ON a.Measure = d.Measure AND a.lob= d.lob AND a.Ref_Year = d.Ref_Year AND a.Race = d.ClassVal AND d.Variable = 'RACE'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS e ON a.Measure = e.Measure AND a.lob= e.lob AND a.Ref_Year = e.Ref_Year AND a.Ethnicity = e.ClassVal AND e.Variable = 'ETHNICITY'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS g ON a.Measure = g.Measure AND a.lob= g.lob AND a.Ref_Year = g.Ref_Year AND a.Gender = g.ClassVal AND g.Variable = 'Gender'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS i ON a.Measure = i.Measure AND a.lob= i.lob AND a.Ref_Year = i.Ref_Year AND a.County = i.ClassVal AND i.Variable = 'COUNTY'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS k ON a.Measure = k.Measure AND a.lob= k.lob AND a.Ref_Year = k.Ref_Year AND a.ADI       = k.Classval and k.Variable = 'ADI'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS l ON a.Measure = l.Measure AND a.lob= l.lob AND a.Ref_Year = l.Ref_Year AND a.FOOD_FLAG = l.ClassVal AND l.Variable = 'FOOD_FLAG'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS m ON a.Measure = m.Measure AND a.lob= m.lob AND a.Ref_Year = m.Ref_Year AND a.HOUSE_FLAG = m.ClassVal AND m.Variable = 'HOUSE_FLAG'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS n ON a.Measure = n.Measure AND a.lob= n.lob AND a.Ref_Year = n.Ref_Year AND a.SOCIAL_SUPP_FLAG = n.ClassVal AND n.Variable = 'SOCIAL_SUPP_FLAG'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS o ON a.Measure = o.Measure AND a.lob= o.lob AND a.Ref_Year = o.Ref_Year AND a.LIFE_FLAG = o.ClassVal AND o.Variable = 'LIFE_FLAG'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS p ON a.Measure = p.Measure AND a.lob= p.lob AND a.Ref_Year = p.Ref_Year AND a.EDU_FLAG = p.ClassVal AND p.Variable = 'EDU_FLAG'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS q ON a.Measure = q.Measure AND a.lob= q.lob AND a.Ref_Year = q.Ref_Year AND a.SOCIOECO = q.ClassVal AND q.Variable = 'SOCIOECO'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS r ON a.Measure = r.Measure AND a.lob= r.lob AND a.Ref_Year = r.Ref_Year AND a.COMPDIS = r.ClassVal AND r.Variable = 'COMPDIS'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS s ON a.Measure = s.Measure AND a.lob= s.lob AND a.Ref_Year = s.Ref_Year AND a.MINORLANG = s.ClassVal AND s.Variable = 'MINORLANG'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS t ON a.Measure = t.Measure AND a.lob= t.lob AND a.Ref_Year = t.Ref_Year AND a.HOUSETRNS = t.ClassVal AND t.Variable = 'HOUSETRNS'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS u ON a.Measure = u.Measure AND a.lob= u.lob AND a.Ref_Year = u.Ref_Year AND a.TRANSPORT_FLAG = u.ClassVal AND u.Variable = 'TRANSPORT_FLAG'
/*		LEFT JOIN HEDIS_medicaid_Statistics2 AS v ON a.Measure = v.Measure AND a.lob= v.lob AND a.Ref_Year = v.Ref_Year AND a.Sexual_Orientation = u.ClassVal AND u.Variable = 'SEXUAL_ORIENTATION'*/
/*		LEFT JOIN HEDIS_medicaid_Statistics2 AS w ON a.Measure = w.Measure AND a.lob= w.lob AND a.Ref_Year = w.Ref_Year AND a.LANGUAGE = u.ClassVal AND w.Variable = 'LANGUAGE'*/
/*		LEFT JOIN HEDIS_medicaid_Statistics2 AS x ON a.Measure = x.Measure AND a.lob= x.lob AND a.Ref_Year = x.Ref_Year AND a.Gender_identity = g.ClassVal AND x.Variable = 'GENDER_IDENTITY'*/
		LEFT JOIN HEDIS_medicaid_Statistics2 AS v ON a.Measure = v.Measure AND a.lob= v.lob AND a.Ref_Year = v.Ref_Year AND a.Sexual_Orientation = v.ClassVal AND v.Variable = 'SEXUAL_ORIENTATION'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS w ON a.Measure = w.Measure AND a.lob= w.lob AND a.Ref_Year = w.Ref_Year AND a.LANGUAGE = w.ClassVal AND w.Variable = 'LANGUAGE'
		LEFT JOIN HEDIS_medicaid_Statistics2 AS x ON a.Measure = x.Measure AND a.lob= x.lob AND a.Ref_Year = x.Ref_Year AND a.Gender_identity = x.ClassVal AND x.Variable = 'GENDER_IDENTITY'
		ORDER BY a.MEMBER_UCI ,
			MEASURE,
			Ref_Year,
			Ref_Month,
			Age_Group,
			Race,
			Ethnicity,
			Gender,
			Gender_identity,
			County,
			ADI,
			FOOD_FLAG,
			HOUSE_FLAG,
			SOCIAL_SUPP_FLAG,
			LIFE_FLAG,
			EDU_FLAG,
			SOCIOECO,
			COMPDIS,
			MINORLANG,
			HOUSETRNS;
quit;

/*--------------------------------------------------------------------------------------------------------------------
- SECTION 4.2: calculate statistics for medicare Population
--------------------------------------------------------------------------------------------------------------------*/

/********** adding official statistics for medicare *************/
/******** filter the data only for medicare ***************/
data HEDIS_medicare_Joins;
	set HEDIS_JOINS;

	if lob= 'MEDICARE';
run;
Proc SQL;
Select Measure_Code,count(*) as cnt
From HEDIS_medicare_Joins
Group by Measure_Code;
Quit;
%Model_Data_Prep(HEDIS_medicare,BCS,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicare,CDC,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicare,COL,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicare,CBP,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicare,HBD,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicare,AMM,20,80,2024,13);
%Model_Data_Prep(HEDIS_medicare,IET,20,80,2024,13);

%Model_Logistic(HEDIS_medicare,BCS);
%Model_Logistic(HEDIS_medicare,CDC);
%Model_Logistic(HEDIS_medicare,COL);
%Model_Logistic(HEDIS_medicare,CBP);
%Model_Logistic(HEDIS_medicare,HBD);
%Model_Logistic(HEDIS_medicare,AMM);
%Model_Logistic(HEDIS_medicare,IET);

%Model_Post_Processing(HEDIS_medicare,BCS,2024);
%Model_Post_Processing(HEDIS_medicare,CDC,2024);
%Model_Post_Processing(HEDIS_medicare,COL,2024);
%Model_Post_Processing(HEDIS_medicare,CBP,2024);
%Model_Post_Processing(HEDIS_medicare,HBD,2024);
%Model_Post_Processing(HEDIS_medicare,AMM,2024);
%Model_Post_Processing(HEDIS_medicare,IET,2024);

Proc sql;
	create table work.HEDIS_medicare_Statistics as 
		SELECT *
		FROM work.HEDIS_medicare_BCS_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicare_CDC_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicare_COL_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicare_CBP_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicare_HBD_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicare_AMM_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_medicare_IET_OUT
	;
quit;

data HEDIS_medicare_Statistics2;
	length measure $32.;
	set HEDIS_medicare_Statistics;

	if Measure = 'PRENATAL' then
		Measure= 'PPC_Prenatal';
	else if Measure = 'POSTPARTUM' then
		Measure= 'PPC_Postpartum';
	lob= 'MEDICARE';
run;

/**********Merge Medicare statistics with th efinal output************/
proc sql;
	create table all_output7 as
		select a.*,
			b.Probability AS Age_Group_Prob_mcr ,
			b.Cutoff AS Age_Group_Cutoff_mcr ,
			b.Significance AS Age_Group_Sig_mcr ,
			b.Significance_Color AS Age_Group_Sig_Color_mcr ,
			b.Estimate_CI AS Age_Group_Est_CI_mcr ,
			d.Probability AS Race_Prob_mcr ,
			d.Cutoff AS Race_Cutoff_mcr ,
			d.Significance AS Race_Sig_mcr ,
			d.Significance_Color AS Race_Sig_Color_mcr ,
			d.Estimate_CI AS Race_Est_CI_mcr ,
			e.Probability AS Ethnicity_Prob_mcr ,
			e.Cutoff AS Ethnicity_Cutoff_mcr ,
			e.Significance AS Ethnicity_Sig_mcr ,
			e.Significance_Color AS Ethnicity_Sig_Color_mcr ,
			e.Estimate_CI AS Ethnicity_Est_CI_mcr ,
			g.Probability AS Gender_Prob_mcr ,
			g.Cutoff AS Gender_Cutoff_mcr ,
			g.Significance AS Gender_Sig_mcr ,
			g.Significance_Color AS Gender_Sig_Color_mcr ,
			g.Estimate_CI AS Gender_Est_CI_mcr ,
			i.Probability AS County_Prob_mcr ,
			i.Cutoff AS County_Cutoff_mcr ,
			i.Significance AS County_Sig_mcr ,
			i.Significance_Color AS County_Sig_Color_mcr ,
			i.Estimate_CI AS County_Est_CI_mcr ,
			l.Probability AS FOOD_FLAG_Prob_mcr ,
			l.Cutoff AS FOOD_FLAG_Cutoff_mcr ,
			l.Significance AS FOOD_FLAG_Sig_mcr ,
			l.Significance_Color AS FOOD_FLAG_Sig_Color_mcr ,
			l.Estimate_CI AS FOOD_FLAG_Est_CI_mcr ,
			m.Probability AS HOUSE_FLAG_Prob_mcr ,
			m.Cutoff AS HOUSE_FLAG_Cutoff_mcr ,
			m.Significance AS HOUSE_FLAG_Sig_mcr ,
			m.Significance_Color AS HOUSE_FLAG_Sig_Color_mcr ,
			m.Estimate_CI AS HOUSE_FLAG_Est_CI_mcr ,
			n.Probability AS SOCIAL_SUPP_FLAG_Prob_mcr ,
			n.Cutoff AS SOCIAL_SUPP_FLAG_Cutoff_mcr ,
			n.Significance AS SOCIAL_SUPP_FLAG_Sig_mcr ,
			n.Significance_Color AS SOCIAL_SUPP_FLAG_Sig_Color_mcr ,
			n.Estimate_CI AS SOCIAL_SUPP_FLAG_Est_CI_mcr ,
			o.Probability AS LIFE_FLAG_Prob_mcr ,
			o.Cutoff AS LIFE_FLAG_Cutoff_mcr ,
			o.Significance AS LIFE_FLAG_Sig_mcr ,
			o.Significance_Color AS LIFE_FLAG_Sig_Color_mcr ,
			o.Estimate_CI AS LIFE_FLAG_Est_CI_mcr ,
			p.Probability AS EDU_FLAG_Prob_mcr ,
			p.Cutoff AS EDU_FLAG_Cutoff_mcr ,
			p.Significance AS EDU_FLAG_Sig_mcr ,
			p.Significance_Color AS EDU_FLAG_Sig_Color_mcr ,
			p.Estimate_CI AS EDU_FLAG_Est_CI_mcr ,
			q.Probability        AS SOCIOECO_Prob_mcr ,
			q.Cutoff             AS SOCIOECO_Cutoff_mcr ,
			q.Significance       AS SOCIOECO_Sig_mcr ,
			q.Significance_Color AS SOCIOECO_Sig_Color_mcr ,
			q.Estimate_CI        AS SOCIOECO_Est_CI_mcr ,
			r.Probability        AS COMPDIS_Prob_mcr ,
			r.Cutoff             AS COMPDIS_Cutoff_mcr ,
			r.Significance       AS COMPDIS_Sig_mcr ,
			r.Significance_Color AS COMPDIS_Sig_Color_mcr ,
			r.Estimate_CI        AS COMPDIS_Est_CI_mcr ,
			s.Probability        AS MINORLANG_Prob_mcr ,
			s.Cutoff             AS MINORLANG_Cutoff_mcr ,
			s.Significance       AS MINORLANG_Sig_mcr ,
			s.Significance_Color AS MINORLANG_Sig_Color_mcr ,
			s.Estimate_CI        AS MINORLANG_Est_CI_mcr ,
			t.Probability        AS HOUSETRNS_Prob_mcr ,
			t.Cutoff             AS HOUSETRNS_Cutoff_mcr ,
			t.Significance       AS HOUSETRNS_Sig_mcr ,
			t.Significance_Color AS HOUSETRNS_Sig_Color_mcr ,
			t.Estimate_CI        AS HOUSETRNS_Est_CI_mcr ,
			k.Probability AS ADI_Prob_mcr ,
			k.Cutoff AS ADI_Cutoff_mcr ,
			k.Significance AS ADI_Sig_mcr ,
			k.Significance_Color AS ADI_Sig_Color_mcr ,
			k.Estimate_CI AS ADI_Est_CI_mcr, 
			u.Probability AS TI_Prob_mcr ,
			u.Cutoff AS TI_Cutoff_mcr ,
			u.Significance AS TI_Sig_mcr ,
			u.Significance_Color AS TI_Sig_Color_mcr ,
			u.Estimate_CI AS TI_Est_CI_mcr,
			v.Probability AS Sexual_Orientation_Prob_mcr ,
	   		v.Cutoff AS Sexual_Orientation_Cutoff_mcr ,
	   		v.Significance AS Sexual_Orientation_Sig_mcr ,
	   		v.Significance_Color AS Sexual_Orientation_Sig_Color_mcr ,
	   		v.Estimate_CI AS Sexual_Orientation_Est_CI_mcr ,
	   		w.Probability AS Language_Prob_mcr ,
	   		w.Cutoff AS Language_Cutoff_mcr ,
	   		w.Significance AS Language_Sig_mcr ,
	   		w.Significance_Color AS Language_Sig_Color_mcr ,
	   		w.Estimate_CI AS Language_Est_CI_mcr,
			g.Probability AS Gender_Identity_Prob_mcr ,
			x.Cutoff AS Gender_Identity_Cutoff_mcr ,
			x.Significance AS Gender_Identity_Sig_mcr ,
			x.Significance_Color AS Gender_Identity_Sig_Color_mcr ,
			x.Estimate_CI AS Gender_Identity_Est_CI_mcr
		FROM all_output6 AS a
		LEFT JOIN HEDIS_medicare_Statistics2 AS b ON a.Measure = b.Measure AND a.lob= b.lob AND a.Ref_Year = b.Ref_Year AND a.Age_Group = b.ClassVal AND b.Variable = 'AGE_GROUP'
		LEFT JOIN HEDIS_medicare_Statistics2 AS d ON a.Measure = d.Measure AND a.lob= d.lob AND a.Ref_Year = d.Ref_Year AND a.Race = d.ClassVal AND d.Variable = 'RACE'
		LEFT JOIN HEDIS_medicare_Statistics2 AS e ON a.Measure = e.Measure AND a.lob= e.lob AND a.Ref_Year = e.Ref_Year AND a.Ethnicity = e.ClassVal AND e.Variable = 'ETHNICITY'
		LEFT JOIN HEDIS_medicare_Statistics2 AS g ON a.Measure = g.Measure AND a.lob= g.lob AND a.Ref_Year = g.Ref_Year AND a.Gender = g.ClassVal AND g.Variable = 'Gender'
		LEFT JOIN HEDIS_medicare_Statistics2 AS i ON a.Measure = i.Measure AND a.lob= i.lob AND a.Ref_Year = i.Ref_Year AND a.County = i.ClassVal AND i.Variable = 'COUNTY'
		LEFT JOIN HEDIS_medicare_Statistics2 AS k ON a.Measure = k.Measure AND a.lob= k.lob AND a.Ref_Year = k.Ref_Year AND a.ADI       = k.Classval and k.Variable = 'ADI'
		LEFT JOIN HEDIS_medicare_Statistics2 AS l ON a.Measure = l.Measure AND a.lob= l.lob AND a.Ref_Year = l.Ref_Year AND a.FOOD_FLAG = l.ClassVal AND l.Variable = 'FOOD_FLAG'
		LEFT JOIN HEDIS_medicare_Statistics2 AS m ON a.Measure = m.Measure AND a.lob= m.lob AND a.Ref_Year = m.Ref_Year AND a.HOUSE_FLAG = m.ClassVal AND m.Variable = 'HOUSE_FLAG'
		LEFT JOIN HEDIS_medicare_Statistics2 AS n ON a.Measure = n.Measure AND a.lob= n.lob AND a.Ref_Year = n.Ref_Year AND a.SOCIAL_SUPP_FLAG = n.ClassVal AND n.Variable = 'SOCIAL_SUPP_FLAG'
		LEFT JOIN HEDIS_medicare_Statistics2 AS o ON a.Measure = o.Measure AND a.lob= o.lob AND a.Ref_Year = o.Ref_Year AND a.LIFE_FLAG = o.ClassVal AND o.Variable = 'LIFE_FLAG'
		LEFT JOIN HEDIS_medicare_Statistics2 AS p ON a.Measure = p.Measure AND a.lob= p.lob AND a.Ref_Year = p.Ref_Year AND a.EDU_FLAG = p.ClassVal AND p.Variable = 'EDU_FLAG'
		LEFT JOIN HEDIS_medicare_Statistics2 AS q ON a.Measure = q.Measure AND a.lob= q.lob AND a.Ref_Year = q.Ref_Year AND a.SOCIOECO = q.ClassVal AND q.Variable = 'SOCIOECO'
		LEFT JOIN HEDIS_medicare_Statistics2 AS r ON a.Measure = r.Measure AND a.lob= r.lob AND a.Ref_Year = r.Ref_Year AND a.COMPDIS = r.ClassVal AND r.Variable = 'COMPDIS'
		LEFT JOIN HEDIS_medicare_Statistics2 AS s ON a.Measure = s.Measure AND a.lob= s.lob AND a.Ref_Year = s.Ref_Year AND a.MINORLANG = s.ClassVal AND s.Variable = 'MINORLANG'
		LEFT JOIN HEDIS_medicare_Statistics2 AS t ON a.Measure = t.Measure AND a.lob= t.lob AND a.Ref_Year = t.Ref_Year AND a.HOUSETRNS = t.ClassVal AND t.Variable = 'HOUSETRNS'
		LEFT JOIN HEDIS_medicare_Statistics2 AS u ON a.Measure = u.Measure AND a.lob= u.lob AND a.Ref_Year = u.Ref_Year AND a.TRANSPORT_FLAG = u.ClassVal AND u.Variable = 'TRANSPORT_FLAG'
		LEFT JOIN HEDIS_medicare_Statistics2 AS v ON a.Measure = v.Measure AND a.lob= v.lob AND a.Ref_Year = v.Ref_Year AND a.LANGUAGE = u.ClassVal AND u.Variable = 'LANGUAGE'
		LEFT JOIN HEDIS_medicare_Statistics2 AS w ON a.Measure = w.Measure AND a.lob= w.lob AND a.Ref_Year = w.Ref_Year AND a.SEXUAL_ORIENTATION = u.ClassVal AND u.Variable = 'SEXUAL_ORIENTATION'
		LEFT JOIN HEDIS_medicare_Statistics2 AS x ON a.Measure = x.Measure AND a.lob= x.lob AND a.Ref_Year = x.Ref_Year AND a.Gender_identity = x.ClassVal AND x.Variable = 'GENDER_IDENTITY'
ORDER BY a.MEMBER_UCI ,
			MEASURE,
			Ref_Year,
			Ref_Month,
			Age_Group,
			Race,
			Ethnicity,
			GENDER,
			Gender_identity,
			County,
			ADI,
			FOOD_FLAG,
			HOUSE_FLAG,
			SOCIAL_SUPP_FLAG,
			LIFE_FLAG,
			EDU_FLAG,
			SOCIOECO,
			COMPDIS,
			MINORLANG,
			HOUSETRNS;
quit;

/*--------------------------------------------------------------------------------------------------------------------
- SECTION 4.3: calculate statistics for commercial Population
--------------------------------------------------------------------------------------------------------------------*/

/**********adding official statistics for commercial*************/
/********filter the data only for commercial***************/
data HEDIS_comm_Joins;
	set HEDIS_JOINS;

	if lob= 'COMMERCIAL';
run;
Proc SQL;
Select Measure_Code,count(*) as cnt
From HEDIS_comm_Joins
Group by Measure_Code;
Quit;

%Model_Data_Prep(HEDIS_comm,BCS,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,CDC,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,CIS,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,COL,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,POSTPARTUM,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,PRENATAL,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,CBP,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,HBD,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,WCV,20,80,2024,13);
/*%Model_Data_Prep(HEDIS_comm,W30,20,80,2023,13);*/
%Model_Data_Prep(HEDIS_comm,WCC,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,AMM,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,IET,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,FUH,20,80,2024,13);
%Model_Data_Prep(HEDIS_comm,FUM,20,80,2024,13);

%Model_Logistic(HEDIS_comm,BCS);
%Model_Logistic(HEDIS_comm,CDC);
/*%Model_Logistic_se(HEDIS_comm,CIS);*/
%Model_Logistic(HEDIS_comm,COL);
%Model_Logistic(HEDIS_comm,POSTPARTUM);
%Model_Logistic(HEDIS_comm,PRENATAL);
%Model_Logistic(HEDIS_comm,CBP);
%Model_Logistic(HEDIS_comm,HBD);
%Model_Logistic(HEDIS_comm,WCV);
/*%Model_Logistic_se(HEDIS_comm,W30);*/
%Model_Logistic(HEDIS_comm,WCC);
%Model_Logistic(HEDIS_comm,AMM);
%Model_Logistic(HEDIS_comm,IET);
%Model_Logistic(HEDIS_comm,FUH);
/*%Model_Logistic(HEDIS_comm,FUM); /*ERROR: Invalid reference value for ADI.*/

%Model_Post_Processing(HEDIS_comm,BCS,2024);
%Model_Post_Processing(HEDIS_comm,CDC,2024);
/*%Model_Post_Processing(HEDIS_comm,CIS,2024);*/
%Model_Post_Processing(HEDIS_comm,COL,2024);
%Model_Post_Processing(HEDIS_comm,POSTPARTUM,2024);
%Model_Post_Processing(HEDIS_comm,PRENATAL,2024);
%Model_Post_Processing(HEDIS_comm,CBP,2024);
%Model_Post_Processing(HEDIS_comm,HBD,2024);
%Model_Post_Processing(HEDIS_comm,WCV,2024);
/*%Model_Post_Processing(HEDIS_comm,W30,2023);*/
%Model_Post_Processing(HEDIS_comm,WCC,2024);
%Model_Post_Processing(HEDIS_comm,AMM,2024);
%Model_Post_Processing(HEDIS_comm,IET,2024);
%Model_Post_Processing(HEDIS_comm,FUH,2024);
/*%Model_Post_Processing(HEDIS_comm,FUM,2024);*/

Proc sql;
	create table work.HEDIS_commercial_Statistics as 
		SELECT *
		FROM work.HEDIS_comm_BCS_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_CDC_OUT
/*		UNION ALL*/
/*		SELECT **/
/*		FROM work.HEDIS_comm_CIS_OUT*/
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_COL_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_Postpartum_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_Prenatal_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_CBP_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_HBD_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_WCV_OUT
/*		UNION ALL*/
/*		SELECT **/
/*		FROM work.HEDIS_comm_W30_OUT*/
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_WCC_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_AMM_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_IET_OUT
		UNION ALL
		SELECT *
		FROM work.HEDIS_comm_FUH_OUT
/*		UNION ALL*/
/*		SELECT **/
/*		FROM work.HEDIS_comm_FUM_OUT*/

	;
quit;

data HEDIS_commercial_Statistics2;
	length measure $32.;
	set HEDIS_commercial_Statistics;

	if Measure = 'PRENATAL' then
		Measure= 'PPC_Prenatal';
	else if Measure = 'POSTPARTUM' then
		Measure= 'PPC_Postpartum';
	lob= 'COMMERCIAL';
	if classval IN('&CIS_SEXUAL_ORIENTATIO','&W30_SEXUAL_ORIENTATIO') then classval='UNKNOWN';
run;

/**********Merge commercial statistics with the final output************/
proc sql;
	create table all_output8 as
		select a.*,
			b.Probability AS Age_Group_Prob_cmr ,
			b.Cutoff AS Age_Group_Cutoff_cmr ,
			b.Significance AS Age_Group_Sig_cmr ,
			b.Significance_Color AS Age_Group_Sig_Color_cmr ,
			b.Estimate_CI AS Age_Group_Est_CI_cmr ,
			d.Probability AS Race_Prob_cmr ,
			d.Cutoff AS Race_Cutoff_cmr ,
			d.Significance AS Race_Sig_cmr ,
			d.Significance_Color AS Race_Sig_Color_cmr ,
			d.Estimate_CI AS Race_Est_CI_cmr ,
			e.Probability AS Ethnicity_Prob_cmr ,
			e.Cutoff AS Ethnicity_Cutoff_cmr ,
			e.Significance AS Ethnicity_Sig_cmr ,
			e.Significance_Color AS Ethnicity_Sig_Color_cmr ,
			e.Estimate_CI AS Ethnicity_Est_CI_cmr ,
			g.Probability AS Gender_Prob_cmr ,
			g.Cutoff AS Gender_Cutoff_cmr ,
			g.Significance AS Gender_Sig_cmr ,
			g.Significance_Color AS Gender_Sig_Color_cmr ,
			g.Estimate_CI AS Gender_Est_CI_cmr ,
			i.Probability AS County_Prob_cmr ,
			i.Cutoff AS County_Cutoff_cmr ,
			i.Significance AS County_Sig_cmr ,
			i.Significance_Color AS County_Sig_Color_cmr ,
			i.Estimate_CI AS County_Est_CI_cmr ,
			l.Probability AS FOOD_FLAG_Prob_cmr ,
			l.Cutoff AS FOOD_FLAG_Cutoff_cmr ,
			l.Significance AS FOOD_FLAG_Sig_cmr ,
			l.Significance_Color AS FOOD_FLAG_Sig_Color_cmr ,
			l.Estimate_CI AS FOOD_FLAG_Est_CI_cmr ,
			m.Probability AS HOUSE_FLAG_Prob_cmr ,
			m.Cutoff AS HOUSE_FLAG_Cutoff_cmr ,
			m.Significance AS HOUSE_FLAG_Sig_cmr ,
			m.Significance_Color AS HOUSE_FLAG_Sig_Color_cmr ,
			m.Estimate_CI AS HOUSE_FLAG_Est_CI_cmr ,
			n.Probability AS SOCIAL_SUPP_FLAG_Prob_cmr ,
			n.Cutoff AS SOCIAL_SUPP_FLAG_Cutoff_cmr ,
			n.Significance AS SOCIAL_SUPP_FLAG_Sig_cmr ,
			n.Significance_Color AS SOCIAL_SUPP_FLAG_Sig_Color_cmr ,
			n.Estimate_CI AS SOCIAL_SUPP_FLAG_Est_CI_cmr ,
			o.Probability AS LIFE_FLAG_Prob_cmr ,
			o.Cutoff AS LIFE_FLAG_Cutoff_cmr ,
			o.Significance AS LIFE_FLAG_Sig_cmr ,
			o.Significance_Color AS LIFE_FLAG_Sig_Color_cmr ,
			o.Estimate_CI AS LIFE_FLAG_Est_CI_cmr ,
			p.Probability AS EDU_FLAG_Prob_cmr ,
			p.Cutoff AS EDU_FLAG_Cutoff_cmr ,
			p.Significance AS EDU_FLAG_Sig_cmr ,
			p.Significance_Color AS EDU_FLAG_Sig_Color_cmr ,
			p.Estimate_CI AS EDU_FLAG_Est_CI_cmr ,
			q.Probability        AS SOCIOECO_Prob_cmr ,
			q.Cutoff             AS SOCIOECO_Cutoff_cmr ,
			q.Significance       AS SOCIOECO_Sig_cmr ,
			q.Significance_Color AS SOCIOECO_Sig_Color_cmr ,
			q.Estimate_CI        AS SOCIOECO_Est_CI_cmr ,
			r.Probability        AS COMPDIS_Prob_cmr ,
			r.Cutoff             AS COMPDIS_Cutoff_cmr ,
			r.Significance       AS COMPDIS_Sig_cmr ,
			r.Significance_Color AS COMPDIS_Sig_Color_cmr ,
			r.Estimate_CI        AS COMPDIS_Est_CI_cmr ,
			s.Probability        AS MINORLANG_Prob_cmr ,
			s.Cutoff             AS MINORLANG_Cutoff_cmr ,
			s.Significance       AS MINORLANG_Sig_cmr ,
			s.Significance_Color AS MINORLANG_Sig_Color_cmr ,
			s.Estimate_CI        AS MINORLANG_Est_CI_cmr ,
			t.Probability        AS HOUSETRNS_Prob_cmr ,
			t.Cutoff             AS HOUSETRNS_Cutoff_cmr ,
			t.Significance       AS HOUSETRNS_Sig_cmr ,
			t.Significance_Color AS HOUSETRNS_Sig_Color_cmr ,
			t.Estimate_CI        AS HOUSETRNS_Est_CI_cmr ,
			k.Probability AS ADI_Prob_cmr ,
			k.Cutoff AS ADI_Cutoff_cmr ,
			k.Significance AS ADI_Sig_cmr ,
			k.Significance_Color AS ADI_Sig_Color_cmr ,
			k.Estimate_CI AS ADI_Est_CI_cmr ,
			u.Probability AS TI_Prob_cmr ,
			u.Cutoff AS TI_Cutoff_cmr ,
			u.Significance AS TI_Sig_cmr ,
			u.Significance_Color AS TI_Sig_Color_cmr ,
			u.Estimate_CI AS TI_Est_CI_cmr ,
			v.Probability AS Sexual_Orientation_Prob_cmr ,
	   		v.Cutoff AS Sexual_Orientation_Cutoff_cmr ,
	   		v.Significance AS Sexual_Orientation_Sig_cmr ,
	   		v.Significance_Color AS Sexual_Orientation_Sig_Color_cmr ,
	   		v.Estimate_CI AS Sexual_Orientation_Est_CI_cmr ,
	   		w.Probability AS Language_Prob_cmr ,
	   		w.Cutoff AS Language_Cutoff_cmr ,
	   		w.Significance AS Language_Sig_cmr ,
	   		w.Significance_Color AS Language_Sig_Color_cmr ,
	   		w.Estimate_CI AS Language_Est_CI_cmr,
			x.Probability AS Gender_Identity_Prob_cmr ,
			x.Cutoff AS Gender_Identity_Cutoff_cmr ,
			x.Significance AS Gender_Identity_Sig_cmr ,
			x.Significance_Color AS Gender_Identity_Sig_Color_cmr ,
			x.Estimate_CI AS Gender_Identity_Est_CI_cmr
		FROM all_output7 AS a
		LEFT JOIN HEDIS_commercial_Statistics2 AS b ON a.Measure = b.Measure AND a.lob= b.lob AND a.Ref_Year = b.Ref_Year AND a.Age_Group = b.ClassVal AND b.Variable = 'AGE_GROUP'
		LEFT JOIN HEDIS_commercial_Statistics2 AS d ON a.Measure = d.Measure AND a.lob= d.lob AND a.Ref_Year = d.Ref_Year AND a.Race = d.ClassVal AND d.Variable = 'RACE'
		LEFT JOIN HEDIS_commercial_Statistics2 AS e ON a.Measure = e.Measure AND a.lob= e.lob AND a.Ref_Year = e.Ref_Year AND a.Ethnicity = e.ClassVal AND e.Variable = 'ETHNICITY'
		LEFT JOIN HEDIS_commercial_Statistics2 AS g ON a.Measure = g.Measure AND a.lob= g.lob AND a.Ref_Year = g.Ref_Year AND a.Gender = g.ClassVal AND g.Variable = 'Gender'
		LEFT JOIN HEDIS_commercial_Statistics2 AS i ON a.Measure = i.Measure AND a.lob= i.lob AND a.Ref_Year = i.Ref_Year AND a.County = i.ClassVal AND i.Variable = 'COUNTY'
		LEFT JOIN HEDIS_commercial_Statistics2 AS k ON a.Measure = k.Measure AND a.lob= k.lob AND a.Ref_Year = k.Ref_Year AND a.ADI       = k.Classval and k.Variable = 'ADI'
		LEFT JOIN HEDIS_commercial_Statistics2 AS l ON a.Measure = l.Measure AND a.lob= l.lob AND a.Ref_Year = l.Ref_Year AND a.FOOD_FLAG = l.ClassVal AND l.Variable = 'FOOD_FLAG'
		LEFT JOIN HEDIS_commercial_Statistics2 AS m ON a.Measure = m.Measure AND a.lob= m.lob AND a.Ref_Year = m.Ref_Year AND a.HOUSE_FLAG = m.ClassVal AND m.Variable = 'HOUSE_FLAG'
		LEFT JOIN HEDIS_commercial_Statistics2 AS n ON a.Measure = n.Measure AND a.lob= n.lob AND a.Ref_Year = n.Ref_Year AND a.SOCIAL_SUPP_FLAG = n.ClassVal AND n.Variable = 'SOCIAL_SUPP_FLAG'
		LEFT JOIN HEDIS_commercial_Statistics2 AS o ON a.Measure = o.Measure AND a.lob= o.lob AND a.Ref_Year = o.Ref_Year AND a.LIFE_FLAG = o.ClassVal AND o.Variable = 'LIFE_FLAG'
		LEFT JOIN HEDIS_commercial_Statistics2 AS p ON a.Measure = p.Measure AND a.lob= p.lob AND a.Ref_Year = p.Ref_Year AND a.EDU_FLAG = p.ClassVal AND p.Variable = 'EDU_FLAG'
		LEFT JOIN HEDIS_commercial_Statistics2 AS q ON a.Measure = q.Measure AND a.lob= q.lob AND a.Ref_Year = q.Ref_Year AND a.SOCIOECO = q.ClassVal AND q.Variable = 'SOCIOECO'
		LEFT JOIN HEDIS_commercial_Statistics2 AS r ON a.Measure = r.Measure AND a.lob= r.lob AND a.Ref_Year = r.Ref_Year AND a.COMPDIS = r.ClassVal AND r.Variable = 'COMPDIS'
		LEFT JOIN HEDIS_commercial_Statistics2 AS s ON a.Measure = s.Measure AND a.lob= s.lob AND a.Ref_Year = s.Ref_Year AND a.MINORLANG = s.ClassVal AND s.Variable = 'MINORLANG'
		LEFT JOIN HEDIS_commercial_Statistics2 AS t ON a.Measure = t.Measure AND a.lob= t.lob AND a.Ref_Year = t.Ref_Year AND a.HOUSETRNS = t.ClassVal AND t.Variable = 'HOUSETRNS'
		LEFT JOIN HEDIS_commercial_Statistics2 AS u ON a.Measure = u.Measure AND a.lob= u.lob AND a.Ref_Year = u.Ref_Year AND a.TRANSPORT_FLAG = u.ClassVal AND u.Variable = 'TRANSPORT_FLAG'
		LEFT JOIN HEDIS_commercial_Statistics2 AS v ON a.Measure = v.Measure AND a.lob= v.lob AND a.Ref_Year = v.Ref_Year AND a.SEXUAL_ORIENTATION = v.ClassVal AND v.Variable = 'SEXUAL_ORIENTATION'
		LEFT JOIN HEDIS_commercial_Statistics2 AS w ON a.Measure = w.Measure AND a.lob= w.lob AND a.Ref_Year = w.Ref_Year AND a.LANGUAGE = w.ClassVal AND w.Variable = 'LANGUAGE'
		LEFT JOIN HEDIS_commercial_Statistics2 AS x ON a.Measure = x.Measure AND a.lob= x.lob AND a.Ref_Year = x.Ref_Year AND a.Gender_identity = x.ClassVal AND x.Variable = 'GENDER_IDENTITY'
	ORDER BY a.MEMBER_UCI ,
			MEASURE,
			Ref_Year,
			Ref_Month,
			Age_Group,
			Race,
			Ethnicity,
			Gender,
			Gender_identity,
			County,
			ADI,
			FOOD_FLAG,
			HOUSE_FLAG,
			SOCIAL_SUPP_FLAG,
			LIFE_FLAG,
			EDU_FLAG,
			SOCIOECO,
			COMPDIS,
			MINORLANG,
			HOUSETRNS;
quit;
/*To Match with the Tableau Extract, renaming Gender columns to Gender_Identity and Gender_Identity to Gender_Identity_New*/
Data all_output9;
Set all_output8;
rename Gender_identity = Gender_identity_N
Gender_identity_Prob	 = Gender_identity_Prob_N
Gender_identity_Cutoff = Gender_identity_Cutoff_N
Gender_identity_Sig = Gender_identity_Sig_N	
Gender_identity_Sig_Color =	Gender_identity_Sig_Color_N
Gender_identity_Est_CI = Gender_identity_Est_CI_N

Gender_identity_Prob_MDCD = Gender_identity_Prob_MDCD_N
Gender_identity_Cutoff_MDCD = Gender_identity_Cutoff_MDCD_N
Gender_identity_Sig_MDCD = Gender_identity_Sig_MDCD_N
Gender_identity_Sig_Color_MDCD = Gender_identity_Sig_Color_MDCD_N
Gender_identity_Est_CI_MDCD = Gender_identity_Est_CI_MDCD_N

Gender_identity_Prob_MCR = Gender_identity_Prob_MCR_N
Gender_identity_Cutoff_MCR = Gender_identity_Cutoff_MCR_N
Gender_identity_Sig_MCR = Gender_identity_Sig_MCR_N
Gender_identity_Sig_Color_MCR = Gender_identity_Sig_Color_MCR_N
Gender_identity_Est_CI_MCR = Gender_identity_Est_CI_MCR_N

Gender_identity_Prob_cmr = Gender_identity_Prob_cmr_N
Gender_identity_Cutoff_cmr = Gender_identity_Cutoff_cmr_N
Gender_identity_Sig_cmr = Gender_identity_Sig_cmr_N
Gender_identity_Sig_Color_cmr = Gender_identity_Sig_Color_cmr_N
Gender_identity_Est_CI_cmr = Gender_identity_Est_CI_cmr_N;
run;

Data all_output9;
Set all_output9;
rename Gender = Gender_identity 
Gender_Prob	= Gender_identity_Prob
Gender_Cutoff =	Gender_identity_Cutoff
Gender_Sig	= Gender_identity_Sig
Gender_Sig_Color = Gender_identity_Sig_Color	
Gender_Est_CI = Gender_identity_Est_CI

Gender_Prob_MDCD = Gender_identity_Prob_MDCD
Gender_Cutoff_MDCD = Gender_identity_Cutoff_MDCD
Gender_Sig_MDCD = Gender_identity_Sig_MDCD
Gender_Sig_Color_MDCD = Gender_identity_Sig_Color_MDCD
Gender_Est_CI_MDCD = Gender_identity_Est_CI_MDCD

Gender_Prob_MCR = Gender_identity_Prob_MCR
Gender_Cutoff_MCR = Gender_identity_Cutoff_MCR
Gender_Sig_MCR = Gender_identity_Sig_MCR
Gender_Sig_Color_MCR = Gender_identity_Sig_Color_MCR
Gender_Est_CI_MCR = Gender_identity_Est_CI_MCR

Gender_Prob_cmr = Gender_identity_Prob_cmr
Gender_Cutoff_cmr = Gender_identity_Cutoff_cmr
Gender_Sig_cmr = Gender_identity_Sig_cmr
Gender_Sig_Color_cmr = Gender_identity_Sig_Color_cmr
Gender_Est_CI_cmr = Gender_identity_Est_CI_cmr;
run;

Data all_output10;
Set all_output9;
Age_Group_Prob1 =  PUT(Age_Group_Prob, PVALUE6.4);
Race_Prob1 =  PUT(Race_Prob, PVALUE6.4);
Ethnicity_Prob1 =  PUT(Ethnicity_Prob, PVALUE6.4);
Gender_Identity_Prob1 =  PUT(Gender_Identity_Prob, PVALUE6.4);
Sexual_Orientation_Prob1 =  PUT(Sexual_Orientation_Prob, PVALUE6.4);
Language_Prob1 =  PUT(Language_Prob, PVALUE6.4);
County_Prob1 =  PUT(County_Prob, PVALUE6.4);
FOOD_FLAG_Prob1 =  PUT(FOOD_FLAG_Prob, PVALUE6.4);
HOUSE_FLAG_Prob1 =  PUT(HOUSE_FLAG_Prob, PVALUE6.4);
SOCIAL_SUPP_FLAG_Prob1 =  PUT(SOCIAL_SUPP_FLAG_Prob, PVALUE6.4);
LIFE_FLAG_Prob1 =  PUT(LIFE_FLAG_Prob, PVALUE6.4);
EDU_FLAG_Prob1 =  PUT(EDU_FLAG_Prob, PVALUE6.4);
COMPDIS_Prob1 =  PUT(COMPDIS_Prob, PVALUE6.4);
ADI_Prob1 =  PUT(ADI_Prob, PVALUE6.4);
TRANSPORT_FLAG_Prob1 =  PUT(TRANSPORT_FLAG_Prob, PVALUE6.4);
Age_Group_Prob_mdcd1 =  PUT(Age_Group_Prob_mdcd, PVALUE6.4);
Race_Prob_mdcd1 =  PUT(Race_Prob_mdcd, PVALUE6.4);
Ethnicity_Prob_mdcd1 =  PUT(Ethnicity_Prob_mdcd, PVALUE6.4);
Gender_Identity_Prob_mdcd1 =  PUT(Gender_Identity_Prob_mdcd, PVALUE6.4);
County_Prob_mdcd1 =  PUT(County_Prob_mdcd, PVALUE6.4);
HOUSE_FLAG_Prob_mdcd1 =  PUT(HOUSE_FLAG_Prob_mdcd, PVALUE6.4);
SOCIAL_SUPP_FLAG_Prob_mdcd1 =  PUT(SOCIAL_SUPP_FLAG_Prob_mdcd, PVALUE6.4);
EDU_FLAG_Prob_mdcd1 =  PUT(EDU_FLAG_Prob_mdcd, PVALUE6.4);
COMPDIS_Prob_mdcd1 =  PUT(COMPDIS_Prob_mdcd, PVALUE6.4);
ADI_Prob_mdcd1 =  PUT(ADI_Prob_mdcd, PVALUE6.4);
TI_Prob_mdcd1 =  PUT(TI_Prob_mdcd, PVALUE6.4);
Sexual_Orientation_Prob_mdcd1 =  PUT(Sexual_Orientation_Prob_mdcd, PVALUE6.4);
Language_Prob_mdcd1 =  PUT(Language_Prob_mdcd, PVALUE6.4);
Age_Group_Prob_mcr1 =  PUT(Age_Group_Prob_mcr, PVALUE6.4);
Race_Prob_mcr1 =  PUT(Race_Prob_mcr, PVALUE6.4);
County_Prob_mcr1 =  PUT(County_Prob_mcr, PVALUE6.4);
ADI_Prob_mcr1 =  PUT(ADI_Prob_mcr, PVALUE6.4);
Sexual_Orientation_Prob_mcr1 =  PUT(Sexual_Orientation_Prob_mcr, PVALUE6.4);
Language_Prob_mcr1 =  PUT(Language_Prob_mcr, PVALUE6.4);
Age_Group_Prob_cmr1 =  PUT(Age_Group_Prob_cmr, PVALUE6.4);
Race_Prob_cmr1 =  PUT(Race_Prob_cmr, PVALUE6.4);
Ethnicity_Prob_cmr1 =  PUT(Ethnicity_Prob_cmr, PVALUE6.4);
Gender_Identity_Prob_cmr1 =  PUT(Gender_Identity_Prob_cmr, PVALUE6.4);
County_Prob_cmr1 =  PUT(County_Prob_cmr, PVALUE6.4);
HOUSE_FLAG_Prob_cmr1 =  PUT(HOUSE_FLAG_Prob_cmr, PVALUE6.4);
EDU_FLAG_Prob_cmr1 =  PUT(EDU_FLAG_Prob_cmr, PVALUE6.4);
ADI_Prob_cmr1 =  PUT(ADI_Prob_cmr, PVALUE6.4);
TI_Prob_cmr1 =  PUT(TI_Prob_cmr, PVALUE6.4);
Sexual_Orientation_Prob_cmr1 =  PUT(Sexual_Orientation_Prob_cmr, PVALUE6.4);
Language_Prob_cmr1 =  PUT(Language_Prob_cmr, PVALUE6.4);
Gender_Identity_Prob_N1 =  PUT(Gender_Identity_Prob_N, PVALUE6.4);
Gender_Identity_Prob_MDCD_N1 =  PUT(Gender_Identity_Prob_MDCD_N, PVALUE6.4);
Gender_Identity_Prob_cmr_N1 =  PUT(Gender_Identity_Prob_cmr_N, PVALUE6.4);
MEMBER_UCI1 = INPUT(STRIP(MEMBER_UCI), BEST32.);
DROP Age_Group_Prob	Race_Prob	Ethnicity_Prob	Gender_Identity_Prob	Sexual_Orientation_Prob	
Language_Prob	County_Prob	FOOD_FLAG_Prob	HOUSE_FLAG_Prob	SOCIAL_SUPP_FLAG_Prob	LIFE_FLAG_Prob	
EDU_FLAG_Prob	COMPDIS_Prob	ADI_Prob	TRANSPORT_FLAG_Prob	Age_Group_Prob_mdcd	Race_Prob_mdcd	
Ethnicity_Prob_mdcd	Gender_Identity_Prob_mdcd	County_Prob_mdcd	HOUSE_FLAG_Prob_mdcd	
SOCIAL_SUPP_FLAG_Prob_mdcd	EDU_FLAG_Prob_mdcd	COMPDIS_Prob_mdcd	ADI_Prob_mdcd	TI_Prob_mdcd	
Sexual_Orientation_Prob_mdcd	Language_Prob_mdcd	Age_Group_Prob_mcr	Race_Prob_mcr	County_Prob_mcr	
ADI_Prob_mcr	Sexual_Orientation_Prob_mcr	Language_Prob_mcr	Age_Group_Prob_cmr	Race_Prob_cmr	
Ethnicity_Prob_cmr	Gender_Identity_Prob_cmr	County_Prob_cmr	HOUSE_FLAG_Prob_cmr	EDU_FLAG_Prob_cmr	
ADI_Prob_cmr	TI_Prob_cmr	Sexual_Orientation_Prob_cmr	Language_Prob_cmr	Gender_Identity_Prob_N	
Gender_Identity_Prob_MDCD_N	Gender_Identity_Prob_cmr_N MEMBER_UCI;
run;

Data all_output10;
Set all_output10;
Rename Age_Group_Prob1 = Age_Group_Prob
Race_Prob1 = Race_Prob
Ethnicity_Prob1 = Ethnicity_Prob
Gender_Identity_Prob1 = Gender_Identity_Prob
Sexual_Orientation_Prob1 = Sexual_Orientation_Prob
Language_Prob1 = Language_Prob
County_Prob1 = County_Prob
FOOD_FLAG_Prob1 = FOOD_FLAG_Prob
HOUSE_FLAG_Prob1 = HOUSE_FLAG_Prob
SOCIAL_SUPP_FLAG_Prob1 = SOCIAL_SUPP_FLAG_Prob
LIFE_FLAG_Prob1 = LIFE_FLAG_Prob
EDU_FLAG_Prob1 = EDU_FLAG_Prob
COMPDIS_Prob1 = COMPDIS_Prob
ADI_Prob1 = ADI_Prob
TRANSPORT_FLAG_Prob1 = TRANSPORT_FLAG_Prob
Age_Group_Prob_mdcd1 = Age_Group_Prob_mdcd
Race_Prob_mdcd1 = Race_Prob_mdcd
Ethnicity_Prob_mdcd1 = Ethnicity_Prob_mdcd
Gender_Identity_Prob_mdcd1 = Gender_Identity_Prob_mdcd
County_Prob_mdcd1 = County_Prob_mdcd
HOUSE_FLAG_Prob_mdcd1 = HOUSE_FLAG_Prob_mdcd
SOCIAL_SUPP_FLAG_Prob_mdcd1 = SOCIAL_SUPP_FLAG_Prob_mdcd
EDU_FLAG_Prob_mdcd1 = EDU_FLAG_Prob_mdcd
COMPDIS_Prob_mdcd1 = COMPDIS_Prob_mdcd
ADI_Prob_mdcd1 = ADI_Prob_mdcd
TI_Prob_mdcd1 = TI_Prob_mdcd
Sexual_Orientation_Prob_mdcd1 = Sexual_Orientation_Prob_mdcd
Language_Prob_mdcd1 = Language_Prob_mdcd
Age_Group_Prob_mcr1 = Age_Group_Prob_mcr
Race_Prob_mcr1 = Race_Prob_mcr
County_Prob_mcr1 = County_Prob_mcr
ADI_Prob_mcr1 = ADI_Prob_mcr
Sexual_Orientation_Prob_mcr1 = Sexual_Orientation_Prob_mcr
Language_Prob_mcr1 = Language_Prob_mcr
Age_Group_Prob_cmr1 = Age_Group_Prob_cmr
Race_Prob_cmr1 = Race_Prob_cmr
Ethnicity_Prob_cmr1 = Ethnicity_Prob_cmr
Gender_Identity_Prob_cmr1 = Gender_Identity_Prob_cmr
County_Prob_cmr1 = County_Prob_cmr
HOUSE_FLAG_Prob_cmr1 = HOUSE_FLAG_Prob_cmr
EDU_FLAG_Prob_cmr1 = EDU_FLAG_Prob_cmr
ADI_Prob_cmr1 = ADI_Prob_cmr
TI_Prob_cmr1 = TI_Prob_cmr
Sexual_Orientation_Prob_cmr1 = Sexual_Orientation_Prob_cmr
Language_Prob_cmr1 = Language_Prob_cmr
Gender_Identity_Prob_N1 = Gender_Identity_Prob_N
Gender_Identity_Prob_MDCD_N1 = Gender_Identity_Prob_MDCD_N
Gender_Identity_Prob_cmr_N1 = Gender_Identity_Prob_cmr_N
MEMBER_UCI1 = MEMBER_UCI;
run;

Data all_output10;
Retain 	Measure	Measure_Description	PAT_ID	Ref_Year	Ref_Month	Ref_Month_Name	Numerator	Denominator	Record_Count	Value	
Age_Group	Age_Group_Prob	Age_Group_Cutoff	Age_Group_Sig	Age_Group_Sig_Color	Age_Group_Est_CI	
Race	SOURCE_RACE	Race_Prob	Race_Cutoff	Race_Sig	Race_Sig_Color	Race_Est_CI	
Ethnicity	SOURCE_ETHNICITY	Ethnicity_Prob	Ethnicity_Cutoff	Ethnicity_Sig	Ethnicity_Sig_Color	Ethnicity_Est_CI	

Gender_Identity	Gender_Identity_Prob	Gender_Identity_Cutoff	Gender_Identity_Sig	Gender_Identity_Sig_Color	Gender_Identity_Est_CI	
Sexual_Orientation	Sexual_Orientation_Prob	Sexual_Orientation_Cutoff	Sexual_Orientation_Sig	Sexual_Orientation_Sig_Color	Sexual_Orientation_Est_CI	
Language	Language_Prob	Language_Cutoff	Language_Sig	Language_Sig_Color	Language_Est_CI	County	
County_Prob	County_Cutoff	County_Sig	County_Sig_Color	County_Est_CI	
FOOD_FLAG	FOOD_FLAG_Prob	FOOD_FLAG_Cutoff	FOOD_FLAG_Sig	FOOD_FLAG_Sig_Color	FOOD_FLAG_Est_CI	
HOUSE_FLAG	HOUSE_FLAG_Prob	HOUSE_FLAG_Cutoff	HOUSE_FLAG_Sig	HOUSE_FLAG_Sig_Color	HOUSE_FLAG_Est_CI	
SOCIAL_SUPP_FLAG	SOCIAL_SUPP_FLAG_Prob	SOCIAL_SUPP_FLAG_Cutoff	SOCIAL_SUPP_FLAG_Sig	SOCIAL_SUPP_FLAG_Sig_Color	SOCIAL_SUPP_FLAG_Est_CI	
LIFE_FLAG	LIFE_FLAG_Prob	LIFE_FLAG_Cutoff	LIFE_FLAG_Sig	LIFE_FLAG_Sig_Color	LIFE_FLAG_Est_CI	
EDU_FLAG	EDU_FLAG_Prob	EDU_FLAG_Cutoff	EDU_FLAG_Sig	EDU_FLAG_Sig_Color	EDU_FLAG_Est_CI	
SOCIOECO	SOCIOECO_Prob	SOCIOECO_Cutoff	SOCIOECO_Sig	SOCIOECO_Sig_Color	SOCIOECO_Est_CI	
COMPDIS	COMPDIS_Prob	COMPDIS_Cutoff	COMPDIS_Sig	COMPDIS_Sig_Color	COMPDIS_Est_CI	
MINORLANG	MINORLANG_Prob	MINORLANG_Cutoff	MINORLANG_Sig	MINORLANG_Sig_Color	MINORLANG_Est_CI	
HOUSETRNS	HOUSETRNS_Prob	HOUSETRNS_Cutoff	HOUSETRNS_Sig	HOUSETRNS_Sig_Color	HOUSETRNS_Est_CI	
ADI	ADI_Prob	ADI_Cutoff	ADI_Sig	ADI_Sig_Color	ADI_Est_CI	
TRANSPORT_FLAG	TRANSPORT_FLAG_Prob	TRANSPORT_FLAG_Cutoff	TRANSPORT_FLAG_Sig	TRANSPORT_FLAG_Sig_Color	TRANSPORT_FLAG_Est_CI	
LOB	MEMBER_UCI	SOURCE_FI	SOURCE_HI	SOURCE_SI	Source_Finance	Source_Safety	source_TI	cohort	
Age_Group_Prob_mdcd	Age_Group_Cutoff_mdcd	Age_Group_Sig_mdcd	Age_Group_Sig_Color_mdcd	Age_Group_Est_CI_mdcd	
Race_Prob_mdcd	Race_Cutoff_mdcd	Race_Sig_mdcd	Race_Sig_Color_mdcd	Race_Est_CI_mdcd	
Ethnicity_Prob_mdcd	Ethnicity_Cutoff_mdcd	Ethnicity_Sig_mdcd	Ethnicity_Sig_Color_mdcd	Ethnicity_Est_CI_mdcd	

Gender_Identity_Prob_mdcd	Gender_Identity_Cutoff_mdcd	Gender_Identity_Sig_mdcd	Gender_Identity_Sig_Color_mdcd	Gender_Identity_Est_CI_mdcd	
County_Prob_mdcd	County_Cutoff_mdcd	County_Sig_mdcd	County_Sig_Color_mdcd	County_Est_CI_mdcd	
FOOD_FLAG_Prob_mdcd	FOOD_FLAG_Cutoff_mdcd	FOOD_FLAG_Sig_mdcd	FOOD_FLAG_Sig_Color_mdcd	FOOD_FLAG_Est_CI_mdcd	
HOUSE_FLAG_Prob_mdcd	HOUSE_FLAG_Cutoff_mdcd	HOUSE_FLAG_Sig_mdcd	HOUSE_FLAG_Sig_Color_mdcd	HOUSE_FLAG_Est_CI_mdcd	
SOCIAL_SUPP_FLAG_Prob_mdcd	SOCIAL_SUPP_FLAG_Cutoff_mdcd	SOCIAL_SUPP_FLAG_Sig_mdcd	SOCIAL_SUPP_FLAG_Sig_Color_mdcd	SOCIAL_SUPP_FLAG_Est_CI_mdcd	
LIFE_FLAG_Prob_mdcd	LIFE_FLAG_Cutoff_mdcd	LIFE_FLAG_Sig_mdcd	LIFE_FLAG_Sig_Color_mdcd	LIFE_FLAG_Est_CI_mdcd	
EDU_FLAG_Prob_mdcd	EDU_FLAG_Cutoff_mdcd	EDU_FLAG_Sig_mdcd	EDU_FLAG_Sig_Color_mdcd	EDU_FLAG_Est_CI_mdcd	
SOCIOECO_Prob_mdcd	SOCIOECO_Cutoff_mdcd	SOCIOECO_Sig_mdcd	SOCIOECO_Sig_Color_mdcd	SOCIOECO_Est_CI_mdcd	
COMPDIS_Prob_mdcd	COMPDIS_Cutoff_mdcd	COMPDIS_Sig_mdcd	COMPDIS_Sig_Color_mdcd	COMPDIS_Est_CI_mdcd	
MINORLANG_Prob_mdcd	MINORLANG_Cutoff_mdcd	MINORLANG_Sig_mdcd	MINORLANG_Sig_Color_mdcd	MINORLANG_Est_CI_mdcd	
HOUSETRNS_Prob_mdcd	HOUSETRNS_Cutoff_mdcd	HOUSETRNS_Sig_mdcd	HOUSETRNS_Sig_Color_mdcd	HOUSETRNS_Est_CI_mdcd	
ADI_Prob_mdcd	ADI_Cutoff_mdcd	ADI_Sig_mdcd	ADI_Sig_Color_mdcd	ADI_Est_CI_mdcd	
TI_Prob_mdcd	TI_Cutoff_mdcd	TI_Sig_mdcd	TI_Sig_Color_mdcd	TI_Est_CI_mdcd	
Sexual_Orientation_Prob_mdcd	Sexual_Orientation_Cutoff_mdcd	Sexual_Orientation_Sig_mdcd	Sexual_Orient_Sig_Color_mdcd	Sexual_Orientation_Est_CI_mdcd	
Language_Prob_mdcd	Language_Cutoff_mdcd	Language_Sig_mdcd	Language_Sig_Color_mdcd	Language_Est_CI_mdcd	
Age_Group_Prob_mcr	Age_Group_Cutoff_mcr	Age_Group_Sig_mcr	Age_Group_Sig_Color_mcr	Age_Group_Est_CI_mcr	
Race_Prob_mcr	Race_Cutoff_mcr	Race_Sig_mcr	Race_Sig_Color_mcr	Race_Est_CI_mcr	
Ethnicity_Prob_mcr	Ethnicity_Cutoff_mcr	Ethnicity_Sig_mcr	Ethnicity_Sig_Color_mcr	Ethnicity_Est_CI_mcr	

Gender_Identity_Prob_mcr	Gender_Identity_Cutoff_mcr	Gender_Identity_Sig_mcr	Gender_Identity_Sig_Color_mcr	Gender_Identity_Est_CI_mcr	
County_Prob_mcr	County_Cutoff_mcr	County_Sig_mcr	County_Sig_Color_mcr	County_Est_CI_mcr	
FOOD_FLAG_Prob_mcr	FOOD_FLAG_Cutoff_mcr	FOOD_FLAG_Sig_mcr	FOOD_FLAG_Sig_Color_mcr	FOOD_FLAG_Est_CI_mcr	
HOUSE_FLAG_Prob_mcr	HOUSE_FLAG_Cutoff_mcr	HOUSE_FLAG_Sig_mcr	HOUSE_FLAG_Sig_Color_mcr	HOUSE_FLAG_Est_CI_mcr	
SOCIAL_SUPP_FLAG_Prob_mcr	SOCIAL_SUPP_FLAG_Cutoff_mcr	SOCIAL_SUPP_FLAG_Sig_mcr	SOCIAL_SUPP_FLAG_Sig_Color_mcr	SOCIAL_SUPP_FLAG_Est_CI_mcr	
LIFE_FLAG_Prob_mcr	LIFE_FLAG_Cutoff_mcr	LIFE_FLAG_Sig_mcr	LIFE_FLAG_Sig_Color_mcr	LIFE_FLAG_Est_CI_mcr	
EDU_FLAG_Prob_mcr	EDU_FLAG_Cutoff_mcr	EDU_FLAG_Sig_mcr	EDU_FLAG_Sig_Color_mcr	EDU_FLAG_Est_CI_mcr	SOCIOECO_Prob_mcr	
SOCIOECO_Cutoff_mcr	SOCIOECO_Sig_mcr	SOCIOECO_Sig_Color_mcr	SOCIOECO_Est_CI_mcr	
COMPDIS_Prob_mcr	COMPDIS_Cutoff_mcr	COMPDIS_Sig_mcr	COMPDIS_Sig_Color_mcr	COMPDIS_Est_CI_mcr	
MINORLANG_Prob_mcr	MINORLANG_Cutoff_mcr	MINORLANG_Sig_mcr	MINORLANG_Sig_Color_mcr	MINORLANG_Est_CI_mcr	
HOUSETRNS_Prob_mcr	HOUSETRNS_Cutoff_mcr	HOUSETRNS_Sig_mcr	HOUSETRNS_Sig_Color_mcr	HOUSETRNS_Est_CI_mcr	
ADI_Prob_mcr	ADI_Cutoff_mcr	ADI_Sig_mcr	ADI_Sig_Color_mcr	ADI_Est_CI_mcr	
TI_Prob_mcr	TI_Cutoff_mcr	TI_Sig_mcr	TI_Sig_Color_mcr	TI_Est_CI_mcr	
Sexual_Orientation_Prob_mcr	Sexual_Orientation_Cutoff_mcr	Sexual_Orientation_Sig_mcr	Sexual_Orientation_Sig_Color_mcr	Sexual_Orientation_Est_CI_mcr	
Language_Prob_mcr	Language_Cutoff_mcr	Language_Sig_mcr	Language_Sig_Color_mcr	Language_Est_CI_mcr	
Age_Group_Prob_cmr	Age_Group_Cutoff_cmr	Age_Group_Sig_cmr	Age_Group_Sig_Color_cmr	Age_Group_Est_CI_cmr	
Race_Prob_cmr	Race_Cutoff_cmr	Race_Sig_cmr	Race_Sig_Color_cmr	Race_Est_CI_cmr	Ethnicity_Prob_cmr	
Ethnicity_Cutoff_cmr	Ethnicity_Sig_cmr	Ethnicity_Sig_Color_cmr	Ethnicity_Est_CI_cmr	

Gender_Identity_Prob_cmr	Gender_Identity_Cutoff_cmr	Gender_Identity_Sig_cmr	Gender_Identity_Sig_Color_cmr	Gender_Identity_Est_CI_cmr	
County_Prob_cmr	County_Cutoff_cmr	County_Sig_cmr	County_Sig_Color_cmr	County_Est_CI_cmr	
FOOD_FLAG_Prob_cmr	FOOD_FLAG_Cutoff_cmr	FOOD_FLAG_Sig_cmr	FOOD_FLAG_Sig_Color_cmr	FOOD_FLAG_Est_CI_cmr	
HOUSE_FLAG_Prob_cmr	HOUSE_FLAG_Cutoff_cmr	HOUSE_FLAG_Sig_cmr	HOUSE_FLAG_Sig_Color_cmr	HOUSE_FLAG_Est_CI_cmr	
SOCIAL_SUPP_FLAG_Prob_cmr	SOCIAL_SUPP_FLAG_Cutoff_cmr	SOCIAL_SUPP_FLAG_Sig_cmr	SOCIAL_SUPP_FLAG_Sig_Color_cmr	SOCIAL_SUPP_FLAG_Est_CI_cmr	
LIFE_FLAG_Prob_cmr	LIFE_FLAG_Cutoff_cmr	LIFE_FLAG_Sig_cmr	LIFE_FLAG_Sig_Color_cmr	LIFE_FLAG_Est_CI_cmr
EDU_FLAG_Prob_cmr	EDU_FLAG_Cutoff_cmr	EDU_FLAG_Sig_cmr	EDU_FLAG_Sig_Color_cmr	EDU_FLAG_Est_CI_cmr	
SOCIOECO_Prob_cmr	SOCIOECO_Cutoff_cmr	SOCIOECO_Sig_cmr	SOCIOECO_Sig_Color_cmr	SOCIOECO_Est_CI_cmr	
COMPDIS_Prob_cmr	COMPDIS_Cutoff_cmr	COMPDIS_Sig_cmr	COMPDIS_Sig_Color_cmr	COMPDIS_Est_CI_cmr	
MINORLANG_Prob_cmr	MINORLANG_Cutoff_cmr	MINORLANG_Sig_cmr	MINORLANG_Sig_Color_cmr	MINORLANG_Est_CI_cmr	
HOUSETRNS_Prob_cmr	HOUSETRNS_Cutoff_cmr	HOUSETRNS_Sig_cmr	HOUSETRNS_Sig_Color_cmr	HOUSETRNS_Est_CI_cmr	
ADI_Prob_cmr	ADI_Cutoff_cmr	ADI_Sig_cmr	ADI_Sig_Color_cmr	ADI_Est_CI_cmr	
TI_Prob_cmr	TI_Cutoff_cmr	TI_Sig_cmr	TI_Sig_Color_cmr	TI_Est_CI_cmr	
Sexual_Orientation_Prob_cmr	Sexual_Orientation_Cutoff_cmr	Sexual_Orientation_Sig_cmr	Sexual_Orientation_Sig_Color_cmr	Sexual_Orientation_Est_CI_cmr	
Language_Prob_cmr	Language_Cutoff_cmr	Language_Sig_cmr	Language_Sig_Color_cmr	Language_Est_CI_cmr	

Gender_Identity_N
	
Gender_Identity_Prob_N		Gender_Identity_Cutoff_N		Gender_Identity_Sig_N		Gender_Identity_Sig_Color_N			Gender_Identity_Est_CI_N	
Gender_Identity_Prob_MDCD_N	Gender_Identity_Cutoff_mdcd_N	Gender_Identity_Sig_mdcd_N	Gender_Identity_Sig_Color_MDCD_N	Gender_Identity_Est_CI_mdcd_N
Gender_Identity_Prob_MCR_N	Gender_Identity_Cutoff_mcr_N	Gender_Identity_Sig_mcr_N	Gender_Identity_Sig_Color_MCR_N		Gender_Identity_Est_CI_mcr_N	
Gender_Identity_Prob_cmr_N	Gender_Identity_Cutoff_cmr_N	Gender_Identity_Sig_cmr_N	Gender_Identity_Sig_Color_cmr_N	    Gender_Identity_Est_CI_cmr_N
;
Set all_output10;
run;



/*--------------------------------------------------------------*/
/*Append data of 2021, 2022 to the current run of 2023*/
/*--------------------------------------------------------------*/
/*PROC IMPORT DATAFILE="/data/rdt/rkoralkar/HEQ/QLTY_PSE_HEQ_Rolling3Years_2023.txt"*/
/*out=HEQ2*/
/*DBMS=DLM */
/*REPLACE;*/
/*DELIMITER='|';*/
/*guessingrows=max;*/
/*getnames= yes;*/
/*run;*/
/*      data WORK.HEQ2  ;  */
/*      %let _EFIERR_ = 0 /* set the ERROR detection macro variable */;*/
/*/*      infile '/data/rdt/rkoralkar/HEQ/QLTY_PSE_HEQ_Rolling3Years_2022.csv' DSD delimiter = ',' firstobs=2 MISSOVER;*/*/
/*	  infile '/data/rdt/rkoralkar/HEQ/QLTY_PSE_HEQ_Rolling3Years_2023.txt' DSD delimiter = ',' firstobs=2 MISSOVER;*/
/*	  INPUT*/
/*          ADI :$7. */
/*          ADI_Cutoff :$6. */
/*          ADI_Cutoff_cmr :$6. */
/*          ADI_Cutoff_mcr :$6. */
/*          ADI_Cutoff_mdcd :$6. */
/*          ADI_Est_CI :$30. */
/*                                                               */
/*          ADI_Est_CI_cmr :$30. */
/*          ADI_Est_CI_mcr :$30. */
/*          ADI_Est_CI_mdcd :$30. */
/*          ADI_Prob :Best32. */
/*          ADI_Prob_cmr :Best32. */
/*          ADI_Sig :$14. */
/*          ADI_Sig_cmr :$14. */
/*          ADI_Sig_Color :$6. */
/*          ADI_Sig_Color_cmr :$6. */
/*          ADI_Sig_Color_mcr :$6. */
/*          ADI_Sig_Color_mdcd :$6. */
/*          ADI_Sig_mcr :$14. */
/*          ADI_Sig_mdcd :$14. */
/*          Age_Group :$5. */
/*          Age_Group_Cutoff :$6. */
/*          Age_Group_Cutoff_cmr :$6. */
/*          Age_Group_Cutoff_mcr :$6. */
/*          Age_Group_Cutoff_mdcd :$6. */
/*          Age_Group_Est_CI :$30. */
/*          Age_Group_Est_CI_cmr :$30. */
/*          Age_Group_Est_CI_mcr :$30. */
/*          Age_Group_Est_CI_mdcd :$30. */
/*          Age_Group_Prob :Best32. */
/*          Age_Group_Prob_mdcd :Best32. */
/*          Age_Group_Sig :$14. */
/*          Age_Group_Sig_cmr :$14. */
/*          Age_Group_Sig_Color :$6. */
/*          Age_Group_Sig_Color_cmr :$6. */
/*          Age_Group_Sig_Color_mcr :$6. */
/*          Age_Group_Sig_Color_mdcd :$6. */
/*          Age_Group_Sig_mcr :$14. */
/*          Age_Group_Sig_mdcd :$14. */
/*          Cohort :$53. */
/*          Compdis :$7. */
/*          COMPDIS_Cutoff :$6. */
/*          COMPDIS_Cutoff_cmr :$6. */
/*          COMPDIS_Cutoff_mcr :$6. */
/*          COMPDIS_Cutoff_mdcd :$6. */
/*          COMPDIS_Est_CI :$29. */
/*          COMPDIS_Est_CI_cmr :$30. */
/*          COMPDIS_Est_CI_mcr :$29. */
/*          COMPDIS_Est_CI_mdcd :$30. */
/*          COMPDIS_Sig :$14. */
/*          COMPDIS_Sig_cmr :$14. */
/*          COMPDIS_Sig_Color :$5. */
/*          COMPDIS_Sig_Color_cmr :$6. */
/*          COMPDIS_Sig_Color_mcr :$4. */
/*          COMPDIS_Sig_Color_mdcd :$6. */
/*          COMPDIS_Sig_mcr :$14. */
/*          COMPDIS_Sig_mdcd :$14. */
/*          County :$10. */
/*          County_Cutoff :$6. */
/*          County_Cutoff_cmr :$6. */
/*          County_Cutoff_mcr :$6. */
/*          County_Cutoff_mdcd :$6. */
/*          County_Est_CI :$30. */
/*          County_Est_CI_cmr :$30. */
/*          County_Est_CI_mcr :$30. */
/*          County_Est_CI_mdcd :$30. */
/*          County_Prob :Best32. */
/*          County_Sig :$14. */
/*          County_Sig_cmr :$14. */
/*          County_Sig_Color :$6. */
/*          County_Sig_Color_cmr :$6. */
/*          County_Sig_Color_mcr :$6. */
/*          County_Sig_Color_mdcd :$6. */
/*          County_Sig_mcr :$14. */
/*          County_Sig_mdcd :$14. */
/*          Edu_Flag :$12. */
/*          EDU_FLAG_Cutoff :$6. */
/*          EDU_FLAG_Cutoff_cmr :$6. */
/*          EDU_FLAG_Cutoff_mcr :$6. */
/*          EDU_FLAG_Cutoff_mdcd :$6. */
/*          EDU_FLAG_Est_CI :$30. */
/*          EDU_FLAG_Est_CI_cmr :$30. */
/*          EDU_FLAG_Est_CI_mcr :$29. */
/*          EDU_FLAG_Est_CI_mdcd :$30. */
/*          EDU_FLAG_Prob :Best32. */
/*          EDU_FLAG_Sig :$14. */
/*          EDU_FLAG_Sig_cmr :$14. */
/*          EDU_FLAG_Sig_Color :$6. */
/*          EDU_FLAG_Sig_Color_cmr :$6. */
/*          EDU_FLAG_Sig_Color_mcr :$4. */
/*          EDU_FLAG_Sig_Color_mdcd :$6. */
/*          EDU_FLAG_Sig_mcr :$14. */
/*          EDU_FLAG_Sig_mdcd :$14. */
/*          Ethnicity :$22. */
/*          Ethnicity_Cutoff :$6. */
/*          Ethnicity_Cutoff_cmr :$6. */
/*          Ethnicity_Cutoff_mcr :$6. */
/*          Ethnicity_Cutoff_mdcd :$6. */
/*          Ethnicity_Est_CI :$30. */
/*          Ethnicity_Est_CI_cmr :$30. */
/*          Ethnicity_Est_CI_mcr :$30. */
/*          Ethnicity_Est_CI_mdcd :$30. */
/*          Ethnicity_Prob :Best32. */
/*          Ethnicity_Sig :$14. */
/*          Ethnicity_Sig_cmr :$14. */
/*          Ethnicity_Sig_Color :$6. */
/*          Ethnicity_Sig_Color_cmr :$6. */
/*          Ethnicity_Sig_Color_mcr :$6. */
/*          Ethnicity_Sig_Color_mdcd :$6. */
/*          Ethnicity_Sig_mcr :$14. */
/*          Ethnicity_Sig_mdcd :$14. */
/*          Food_Flag :$7. */
/*          FOOD_FLAG_Cutoff :$6. */
/*          FOOD_FLAG_Cutoff_cmr :$6. */
/*          FOOD_FLAG_Cutoff_mcr :$6. */
/*          FOOD_FLAG_Cutoff_mdcd :$6. */
/*          FOOD_FLAG_Est_CI :$30. */
/*          FOOD_FLAG_Est_CI_cmr :$30. */
/*          FOOD_FLAG_Est_CI_mcr :$29. */
/*          FOOD_FLAG_Est_CI_mdcd :$30. */
/*          FOOD_FLAG_Sig :$14. */
/*          FOOD_FLAG_Sig_cmr :$14. */
/*          FOOD_FLAG_Sig_Color :$6. */
/*          FOOD_FLAG_Sig_Color_cmr :$6. */
/*          FOOD_FLAG_Sig_Color_mcr :$4. */
/*          FOOD_FLAG_Sig_Color_mdcd :$6. */
/*          FOOD_FLAG_Sig_mcr :$14. */
/*          FOOD_FLAG_Sig_mdcd :$14. */
/*          Gender_Identity :$7. */
/*          Gender_Identity_Cutoff :$6. */
/*          Gender_Identity_Cutoff_cmr :$6. */
/*          Gender_Identity_Cutoff_mcr :$6. */
/*          Gender_Identity_Cutoff_mdcd :$6. */
/*          Gender_Identity_Est_CI :$30. */
/*          Gender_Identity_Est_CI_cmr :$29. */
/*          Gender_Identity_Est_CI_mcr :$29. */
/*          Gender_Identity_Est_CI_mdcd :$30. */
/*          Gender_Identity_Prob :Best32.*/
/*          Gender_Identity_Sig :$14. */
/*          Gender_Identity_Sig_cmr :$14. */
/*          Gender_Identity_Sig_Color :$6. */
/*          Gender_Identity_Sig_Color_cmr :$6. */
/*          Gender_Identity_Sig_Color_mcr :$6. */
/*          Gender_Identity_Sig_Color_mdcd :$6. */
/*          Gender_Identity_Sig_mcr :$14. */
/*          Gender_Identity_Sig_mdcd :$14. */
/*          House_Flag :$7. */
/*          HOUSE_FLAG_Cutoff :$6. */
/*          HOUSE_FLAG_Cutoff_cmr :$6. */
/*          HOUSE_FLAG_Cutoff_mcr :$6. */
/*          HOUSE_FLAG_Cutoff_mdcd :$6. */
/*          HOUSE_FLAG_Est_CI :$30. */
/*          HOUSE_FLAG_Est_CI_cmr :$30. */
/*          HOUSE_FLAG_Est_CI_mcr :$30. */
/*          HOUSE_FLAG_Est_CI_mdcd :$30. */
/*          HOUSE_FLAG_Prob :Best32. */
/*          HOUSE_FLAG_Prob_cmr :Best32. */
/*          HOUSE_FLAG_Sig :$14. */
/*          HOUSE_FLAG_Sig_cmr :$14. */
/*          HOUSE_FLAG_Sig_Color :$6. */
/*          HOUSE_FLAG_Sig_Color_cmr :$6. */
/*          HOUSE_FLAG_Sig_Color_mcr :$6. */
/*          HOUSE_FLAG_Sig_Color_mdcd :$6. */
/*          HOUSE_FLAG_Sig_mcr :$14. */
/*          HOUSE_FLAG_Sig_mdcd :$14. */
/*          Housetrns :$7. */
/*          HOUSETRNS_Cutoff :$6. */
/*          HOUSETRNS_Cutoff_cmr :$6. */
/*          HOUSETRNS_Cutoff_mcr :$6. */
/*          HOUSETRNS_Cutoff_mdcd :$6. */
/*          HOUSETRNS_Est_CI :$29. */
/*          HOUSETRNS_Est_CI_cmr :$30. */
/*          HOUSETRNS_Est_CI_mcr :$29. */
/*          HOUSETRNS_Est_CI_mdcd :$29. */
/*          HOUSETRNS_Sig :$14. */
/*          HOUSETRNS_Sig_cmr :$14. */
/*          HOUSETRNS_Sig_Color :$6. */
/*          HOUSETRNS_Sig_Color_cmr :$6. */
/*          HOUSETRNS_Sig_Color_mcr :$4. */
/*          HOUSETRNS_Sig_Color_mdcd :$5. */
/*          HOUSETRNS_Sig_mcr :$14.                       */
/*          HOUSETRNS_Sig_mdcd :$14. */
/*          Language :$13. */
/*          Language_Cutoff :$6. */
/*          Language_Cutoff_cmr :$6. */
/*          Language_Cutoff_mcr :$1. */
/*          Language_Cutoff_mdcd :$1. */
/*          Language_Est_CI :$30. */
/*          Language_Est_CI_cmr :$28. */
/*          Language_Est_CI_mcr :$1. */
/*          Language_Est_CI_mdcd :$1. */
/*          Language_Prob :Best32. */
/*          Language_Prob_cmr :Best32. */
/*          Language_Prob_mcr :Best32. */
/*          Language_Prob_mdcd :Best32. */
/*          Language_Sig :$14. */
/*          Language_Sig_cmr :$14. */
/*          Language_Sig_Color :$6. */
/*          Language_Sig_Color_cmr :$5. */
/*          Language_Sig_Color_mcr :$1. */
/*          Language_Sig_Color_mdcd :$1. */
/*          Language_Sig_mcr :$1. */
/*          Language_Sig_mdcd :$1. */
/*          Life_Flag :$7. */
/*          LIFE_FLAG_Cutoff :$6. */
/*          LIFE_FLAG_Cutoff_cmr :$6. */
/*          LIFE_FLAG_Cutoff_mcr :$6. */
/*          LIFE_FLAG_Cutoff_mdcd :$6. */
/*          LIFE_FLAG_Est_CI :$30. */
/*          LIFE_FLAG_Est_CI_cmr :$30. */
/*          LIFE_FLAG_Est_CI_mcr :$30. */
/*          LIFE_FLAG_Est_CI_mdcd :$30. */
/*          LIFE_FLAG_Sig :$14. */
/*          LIFE_FLAG_Sig_cmr :$14. */
/*          LIFE_FLAG_Sig_Color :$6. */
/*          LIFE_FLAG_Sig_Color_cmr :$6. */
/*          LIFE_FLAG_Sig_Color_mcr :$6. */
/*          LIFE_FLAG_Sig_Color_mdcd :$6. */
/*          LIFE_FLAG_Sig_mcr :$14. */
/*          LIFE_FLAG_Sig_mdcd :$14. */
/*          LOB :$10. */
/*          Measure :$14. */
/*          Measure_Description :$1. */
/*          Minorlang :$7. */
/*          MINORLANG_Cutoff :$6. */
/*          MINORLANG_Cutoff_cmr :$6. */
/*          MINORLANG_Cutoff_mcr :$6. */
/*          MINORLANG_Cutoff_mdcd :$6. */
/*          MINORLANG_Est_CI :$30. */
/*          MINORLANG_Est_CI_cmr :$29. */
/*          MINORLANG_Est_CI_mcr :$29. */
/*          MINORLANG_Est_CI_mdcd :$30. */
/*          MINORLANG_Sig :$14. */
/*          MINORLANG_Sig_cmr :$14. */
/*          MINORLANG_Sig_Color :$6. */
/*          MINORLANG_Sig_Color_cmr :$6. */
/*          MINORLANG_Sig_Color_mcr :$4. */
/*          MINORLANG_Sig_Color_mdcd :$6. */
/*          MINORLANG_Sig_mcr :$14. */
/*          MINORLANG_Sig_mdcd :$14. */
/*          Pat_Id :$32. */
/*          Race :$32. */
/*          Race_Cutoff :$6. */
/*          Race_Cutoff_cmr :$6. */
/*          Race_Cutoff_mcr :$6. */
/*          Race_Cutoff_mdcd :$6. */
/*          Race_Est_CI :$30. */
/*          Race_Est_CI_cmr :$30. */
/*          Race_Est_CI_mcr :$30. */
/*          Race_Est_CI_mdcd :$30. */
/*          Race_Sig :$14. */
/*          Race_Sig_cmr :$14. */
/*          Race_Sig_Color :$6. */
/*          Race_Sig_Color_cmr :$6. */
/*          Race_Sig_Color_mcr :$6. */
/*          Race_Sig_Color_mdcd :$6. */
/*          Race_Sig_mcr :$14. */
/*          Race_Sig_mdcd :$14. */
/*          Record_Count :Best32. */
/*          Ref_Month :best32. */
/*          Ref_Month_Name :$8. */
/*          Ref_Year :best32. */
/*          Sexual_Orient_Sig_Color_mdcd :$1. */
/*          Sexual_Orientation :$8. */
/*          Sexual_Orientation_Cutoff :$6. */
/*          Sexual_Orientation_Cutoff_cmr :$6. */
/*          Sexual_Orientation_Cutoff_mcr :$1. */
/*          Sexual_Orientation_Cutoff_mdcd :$1. */
/*          Sexual_Orientation_Est_CI :$30. */
/*          Sexual_Orientation_Est_CI_cmr :$30. */
/*          Sexual_Orientation_Est_CI_mcr :$1. */
/*          Sexual_Orientation_Est_CI_mdcd :$1. */
/*          Sexual_Orientation_Prob :Best32. */
/*          Sexual_Orientation_Prob_cmr :Best32. */
/*          Sexual_Orientation_Prob_mcr :Best32. */
/*          Sexual_Orientation_Prob_mdcd :Best32. */
/*          Sexual_Orientation_Sig :$14. */
/*          Sexual_Orientation_Sig_cmr :$14. */
/*          Sexual_Orientation_Sig_Color :$6. */
/*          Sexual_Orientation_Sig_Color_cmr :$6. */
/*          Sexual_Orientation_Sig_Color_mcr :$1. */
/*          Sexual_Orientation_Sig_mcr :$1. */
/*          Sexual_Orientation_Sig_mdcd :$1. */
/*          Social_Supp_Flag :$7. */
/*          SOCIAL_SUPP_FLAG_Cutoff :$6. */
/*          SOCIAL_SUPP_FLAG_Cutoff_cmr :$6. */
/*          SOCIAL_SUPP_FLAG_Cutoff_mcr :$6. */
/*          SOCIAL_SUPP_FLAG_Cutoff_mdcd :$6. */
/*          SOCIAL_SUPP_FLAG_Est_CI :$29. */
/*          SOCIAL_SUPP_FLAG_Est_CI_cmr :$29. */
/*          SOCIAL_SUPP_FLAG_Est_CI_mcr :$29. */
/*          SOCIAL_SUPP_FLAG_Est_CI_mdcd :$29. */
/*          SOCIAL_SUPP_FLAG_Prob :best32. */
/*          SOCIAL_SUPP_FLAG_Sig :$14. */
/*          SOCIAL_SUPP_FLAG_Sig_cmr :$14. */
/*          SOCIAL_SUPP_FLAG_Sig_Color :$5. */
/*          SOCIAL_SUPP_FLAG_Sig_Color_cmr :$5. */
/*          SOCIAL_SUPP_FLAG_Sig_Color_mcr :$5. */
/*          SOCIAL_SUPP_FLAG_Sig_Color_mdcd :$5. */
/*          SOCIAL_SUPP_FLAG_Sig_mcr :$14. */
/*          SOCIAL_SUPP_FLAG_Sig_mdcd :$14. */
/*          Socioeco :$7. */
/*          SOCIOECO_Cutoff :$6. */
/*          SOCIOECO_Cutoff_cmr :$6. */
/*          SOCIOECO_Cutoff_mcr :$6. */
/*          SOCIOECO_Cutoff_mdcd :$6. */
/*          SOCIOECO_Est_CI :$29. */
/*          SOCIOECO_Est_CI_cmr :$30. */
/*          SOCIOECO_Est_CI_mcr :$29. */
/*          SOCIOECO_Est_CI_mdcd :$29. */
/*          SOCIOECO_Sig :$14. */
/*          SOCIOECO_Sig_cmr :$14. */
/*          SOCIOECO_Sig_Color :$6. */
/*          SOCIOECO_Sig_Color_cmr :$6. */
/*          SOCIOECO_Sig_Color_mcr :$4. */
/*          SOCIOECO_Sig_Color_mdcd :$4. */
/*          SOCIOECO_Sig_mcr :$14. */
/*          SOCIOECO_Sig_mdcd :$14. */
/*          Source_Ethnicity :$4. */
/*          Source_Fi :$6. */
/*          Source_Finance :$4. */
/*          Source_Hi :$6. */
/*          Source_Race :$4. */
/*          Source_Safety :$4. */
/*          Source_Si :$6. */
/*          source_TI :$8. */
/*          TI_Cutoff_cmr :$6. */
/*          TI_Cutoff_mcr :$6. */
/*          TI_Cutoff_mdcd :$6. */
/*          TI_Est_CI_cmr :$30. */
/*          TI_Est_CI_mcr :$30. */
/*          TI_Est_CI_mdcd :$29. */
/*          TI_Sig_cmr :$14. */
/*          TI_Sig_Color_cmr :$6. */
/*          TI_Sig_Color_mcr :$6. */
/*          TI_Sig_Color_mdcd :$6. */
/*          TI_Sig_mcr :$14. */
/*          TI_Sig_mdcd :$14. */
/*          Transport_Flag :$7. */
/*          TRANSPORT_FLAG_Cutoff :$6. */
/*          TRANSPORT_FLAG_Est_CI :$30. */
/*          TRANSPORT_FLAG_Prob :Best32. */
/*          TRANSPORT_FLAG_Sig :$14. */
/*          TRANSPORT_FLAG_Sig_Color :$6. */
/*          Value :Best32. */
/*          ADI_Prob_mcr :best32. */
/*          ADI_Prob_mdcd :best32. */
/*          Age_Group_Prob_cmr :best32. */
/*          Age_Group_Prob_mcr :best32. */
/*          COMPDIS_Prob :best32. */
/*          COMPDIS_Prob_cmr :best32. */
/*          COMPDIS_Prob_mcr :best32. */
/*          COMPDIS_Prob_mdcd :best32. */
/*          County_Prob_cmr :best32. */
/*          County_Prob_mcr :best32. */
/*             */
/*          County_Prob_mdcd :best32. */
/*          Denominator :best32. */
/*          EDU_FLAG_Prob_cmr :best32. */
/*          EDU_FLAG_Prob_mcr :best32. */
/*          EDU_FLAG_Prob_mdcd :best32. */
/*          Ethnicity_Prob_cmr :best32. */
/*          Ethnicity_Prob_mcr :best32. */
/*          Ethnicity_Prob_mdcd :best32. */
/*          FOOD_FLAG_Prob :best32. */
/*          FOOD_FLAG_Prob_cmr :best32. */
/*          FOOD_FLAG_Prob_mcr :best32. */
/*          FOOD_FLAG_Prob_mdcd :best32. */
/*          Gender_Identity_Prob_cmr :best32. */
/*          Gender_Identity_Prob_mcr :best32. */
/*          Gender_Identity_Prob_mdcd :best32. */
/*          HOUSE_FLAG_Prob_mcr :best32. */
/*          HOUSE_FLAG_Prob_mdcd :best32. */
/*          HOUSETRNS_Prob :best32. */
/*          HOUSETRNS_Prob_cmr :best32. */
/*          HOUSETRNS_Prob_mcr :best32. */
/*          HOUSETRNS_Prob_mdcd :best32. */
/*          LIFE_FLAG_Prob :best32. */
/*          LIFE_FLAG_Prob_cmr :best32. */
/*          LIFE_FLAG_Prob_mcr :best32. */
/*          LIFE_FLAG_Prob_mdcd :best32. */
/*          Member_Uci :$50. */
/*          MINORLANG_Prob :best32. */
/*          MINORLANG_Prob_cmr :best32. */
/*          MINORLANG_Prob_mcr :best32. */
/*          MINORLANG_Prob_mdcd :best32. */
/*          Numerator :best32. */
/*          Race_Prob :best32. */
/*          Race_Prob_cmr :best32. */
/*          Race_Prob_mcr :best32. */
/*          Race_Prob_mdcd :best32. */
/*          SOCIAL_SUPP_FLAG_Prob_cmr :best32. */
/*          SOCIAL_SUPP_FLAG_Prob_mcr :best32. */
/*          SOCIAL_SUPP_FLAG_Prob_mdcd :best32. */
/*          SOCIOECO_Prob :best32. */
/*          SOCIOECO_Prob_cmr :best32. */
/*          SOCIOECO_Prob_mcr :best32. */
/*          SOCIOECO_Prob_mdcd :best32. */
/*          TI_Prob_cmr :best32. */
/*          TI_Prob_mcr :best32. */
/*          TI_Prob_mdcd :best32. ;*/
/**/
/*      if _ERROR_ then call symputx('_EFIERR_',1)  /* set ERROR detection macro variable */;*/
/*	  RUN;*/;


LIBNAME ssingh  "/data/php/stage/SSingh";

Data ssingh.PHP_HEQ_ROLLING3YEARS_22_23_24_N;
Set   all_output10 ssingh.PHP_HEQ_ROLLING3YEARS_21_22_23;
Format Race $50.;
IF ref_year in (2022, 2023, 2024);
run;
Proc SQL;
Select ref_year, count(*) as cnt
From ssingh.PHP_HEQ_ROLLING3YEARS_22_23_24_N
Group by ref_year;
Run;

Proc export 
DATA = ssingh.PHP_HEQ_ROLLING3YEARS_22_23_24_N
OUTFILE="/data/php/TSTTBLOAPP01_PHP/PHP_HEQ_ROLLING3YEARS.txt"
DBMS=DLM 
REPLACE;
DELIMITER='|';
PUTNAMES=YES;
RUN;

