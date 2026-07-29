-- =============================================================================
-- CM_NCIS_Customers_vs_HUB_ME01_Validation_v1.sql
-- HSBC Malta Core Banking Migration · Deloitte IQA · EIM ID 240825
-- MODULE: ME01_HUB — Column Match (CM) checks: NCIS_Customers (PROFITS-side
-- extract, per 01_CUSTOMER.sql) vs. HUB_MT_SSCUSTP / SSGHCLP / SSINCIP / SSNICIP
-- source fields, per Data Dictionary 21_606_240825_ME01_HUB_v1_0_DDAMO_v1.17
-- =============================================================================
--
-- *** ASSUMPTIONS / OPEN ITEMS — CONFIRM WITH NC/CREDIA BEFORE EXECUTION ***
--
-- A1. BRIDGE JOIN KEY — NOW CONFIRMED by 01_CUSTOMER.sql:
--       MG_CUSTOMER_INTER.PRFT_CUST_ID = NCIS_Customers.Customer_Code (= CUST_ID)
--     This resolves the previously open assumption on the NCIS_Customers
--     completeness script.
--
-- A2. SCHEMA / OBJECT RESOLUTION FOR HUB_MT_SSCUSTP / SSGHCLP / SSINCIP —
--     NOT CONFIRMED. 01_CUSTOMER.sql references these tables unqualified
--     (no DATACUT35 prefix) and joins via a column literally named
--     "CUSTOMER_CODE" on SSCUSTP/SSINCIP. That column is NOT a native DD field
--     of SSCUSTP (native fields are ZGDCB [branch] + ZGDCS [serial]) — it may be
--     a derived/concatenated staging column, or these objects may be synonyms/
--     views distinct from the raw HUB_MT_SSCUSTP landing table used
--     by the DQC scripts. This script mirrors 01_CUSTOMER.sql's join pattern
--     exactly (same unqualified names + CUSTOMER_CODE key) on the assumption it
--     runs in the same environment/schema context. Update the schema prefix
--     DATACUT35 below and confirm the join key with NC/Credia before
--     live execution.
--
-- A3. FIELD MAPPING CONFIDENCE — see accompanying mapping table (chat). Checks
--     below are grouped:
--       CAT-1 CONFIRMED  — direct 1:1 DD field match (Date_of_Birth, Sex,
--                           Nationality, Communication_Language, Number_of_Children,
--                           Education_Level, Branch_Code)
--       CAT-2 PROBABLE   — plausible match by description, not DD-certain
--                           (Identification_ID_Type/No, Tax_ID, Family_Status,
--                           Activity_Code, Profession, Corporation_Registry_Number,
--                           Legal_Form, Customer_Type)
--       CAT-3 NOT FOUND  — no corresponding HUB_MT field identified in DD subset;
--                           COUNT(*)-only INFO placeholders, no fabricated fields.
--
-- A4. PII / MASKING DISCIPLINE — fields flagged "Is field masked = Yes" in the DD
--     (ZGIDNO, ZGTXNO, ZKKID, ZGINDY, ZKOCPT, XUINCN, ZGDCS, ZGNATY) are used
--     ONLY in COUNT(*)/mismatch predicates below — never surfaced as raw values
--     in RESULT_TXT or GROUP BY.
--
-- A5. Two apparent issues carried over from 01_CUSTOMER.sql (source system query,
--     not this script) — flagged for NC clarification, not corrected here:
--       - Identification_ID_Issue_Country is sourced from O.FKGD_HAS_TYPE,
--         identical to Identification_ID_Type (col #11/#15) — likely a bug in
--         the source query, not this validation script.
--       - Activity_Code is sourced from C4.FK_CATEGORYCATEGOR (the category
--         code itself) rather than GD4.FK_GENERIC_DETASER as its sibling
--         category joins do — inconsistent with the pattern used elsewhere.
--
-- Schema/platform: Oracle · Target landing schema placeholder: DATACUT35
-- Status logic: PASS (0 mismatches) / REVIEW (>0, CAT-1/2) / INFO (CAT-3, no
-- confirmed field to compare)
-- =============================================================================

SELECT
       C.CHECK_ID, C.CHECK_NAME, C.CATEGORY, C.RESULT_NUM, C.RESULT_TXT,
       CASE WHEN C.CATEGORY = 'NOT_FOUND' THEN 'INFO'
            WHEN C.RESULT_NUM = 0            THEN 'PASS'
            ELSE 'REVIEW' END AS STATUS
  FROM (

-- =============================================================================
-- CAT-1 — CONFIRMED FIELD MATCHES
-- =============================================================================

-- CM-001 | Branch_Code vs SSCUSTP.ZGDCB
SELECT 'CM-001' AS CHECK_ID, 'Branch_Code mismatch vs SSCUSTP.ZGDCB' AS CHECK_NAME,
       'CONFIRMED' AS CATEGORY, COUNT(*) AS RESULT_NUM,
       CAST(NULL AS VARCHAR2(200)) AS RESULT_TXT
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN v_reconciliation_customer_recordsv2 s ON TRIM(s.CUSTOMER_CODE) = TRIM(n.CUSTOMER_CODE)
 WHERE TRIM(TO_CHAR(n.Branch_Code)) <> TRIM(TO_CHAR(s.ZGDCB_Customer_Branch))
    OR (n.Branch_Code IS NULL AND s.ZGDCB_Customer_Branch IS NOT NULL)
    OR (n.Branch_Code IS NOT NULL AND s.ZGDCB_Customer_Branch IS NULL)

UNION ALL

  SELECT 'CM-002' AS CHECK_ID, 
       'Date_of_Birth mismatch vs SSINCIP.ZKDTBR' AS CHECK_NAME,
       'CONFIRMED' AS CATEGORY, 
       COUNT(*) AS RESULT_NUM, 
       CAST(NULL AS VARCHAR2(200)) AS RESULT_TXT
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN v_reconciliation_customer_recordsv2 i ON TRIM(i.CUSTOMER_CODE) = TRIM(mci.PRFT_CUST_ID)
 WHERE NVL(TO_CHAR(n.Date_of_Birth,'YYYYMMDD'),'19010101') <>
       CASE 
         WHEN TRIM(i.ZGDTBR_Date_of_Birth) = '99999999' THEN '19010101' 
         WHEN TRIM(i.ZGDTBR_Date_of_Birth) = '0' THEN '19010101'
         ELSE NVL(TRIM(i.ZGDTBR_Date_of_Birth),'19010101')
       END


UNION ALL

--DC3 issues: 1. even corporate has sex, 2.Customers exists in HUB_MT_SSINCIP does not exists in hub_mt_sscustp 7011656,33669900
SELECT 'CM-003' AS CHECK_ID, 'Sex mismatch vs SSINCIP.ZKSEX' AS CHECK_NAME,
       'CONFIRMED' AS CATEGORY, COUNT(*) AS RESULT_NUM, 'Sext ype even for corporate' AS RESULT_TXT
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN HUB_MT_SSINCIP i ON TRIM(i.CUSTOMER_CODE) = TRIM(mci.CUSTOMER_CODE)
 WHERE CASE 
         -- Κανόνας 1: Αν Customer_Type = 1 και ZKSEX είναι NULL/κενό, και το Sex είναι M -> Θεώρησέ το Match
         WHEN n.Customer_Type = 1 AND (i.ZKSEX IS NULL OR TRIM(i.ZKSEX) = '') AND TRIM(n.Sex) = 'M' 
           THEN 'MATCH_FOUND'
         -- Κανόνας 2: Αν το ZKSEX είναι 'X' και το Sex είναι 'M' -> Θεώρησέ το Match
         WHEN TRIM(i.ZKSEX) = 'X' AND TRIM(n.Sex) = 'M' 
           THEN 'MATCH_FOUND'
         -- Σε κάθε άλλη περίπτωση, κράτα την κανονική τιμή του Sex για τη σύγκριση
         ELSE NVL(TRIM(n.Sex), 'X')
       END
       <>
       CASE 
         WHEN n.Customer_Type = 1 AND (i.ZKSEX IS NULL OR TRIM(i.ZKSEX) = '') AND TRIM(n.Sex) = 'M' 
           THEN 'MATCH_FOUND'
         WHEN TRIM(i.ZKSEX) = 'X' AND TRIM(n.Sex) = 'M' 
           THEN 'MATCH_FOUND'
         ELSE NVL(TRIM(i.ZKSEX), 'X')
       END
UNION ALL
-- CM-004 | Nationality vs SSCUSTP.ZGNATY (masked field — count only)
--Observations
SELECT 'CM-004', 'Nationality mismatch vs SSCUSTP.ZGNATY',
       'CONFIRMED', COUNT(*), CAST(NULL AS VARCHAR2(200))AS RESULT_TXT
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN v_reconciliation_customer_recordsv2 s ON TRIM(s.CUSTOMER_CODE) = TRIM(mci.PRFT_CUST_ID)
 WHERE NVL(TRIM(n.Nationality),'X') = NVL(TRIM(s.ZGNATY_Nationality),'X')


UNION ALL    
-- CM-005 | Communication_Language vs SSCUSTP.ZGLANG
--Language Code
--It is a code to specify in which language text will be displayed on customer/staff terminals or ATM machine.
--e.g.  P - Primary Language (English)
--S - Secondary Language
--(According to the 2nd Language Code defined in the 2nd Language Control) When used in HCC card master file, it signifies the ATM --language displayed, ie,
--'1' - English
--'2' - Local language
--'3' - local language
SELECT 'CM-005', 'Communication_Language mismatch vs SSCUSTP.ZGLANG',
       'CONFIRMED', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN v_reconciliation_customer_recordsv2 s ON TRIM(s.CUSTOMER_CODE) = TRIM(mci.PRFT_CUST_ID)
 WHERE NVL(TRIM(n.Communication_Language),'X') <> 
 NVL(TRIM((SELECT mpp1.NEW_VALUE FROM MG_PARAM_PARAMETER mpp1 WHERE mpp1.PARAMETER_TYPE = 'COMLA' AND mpp1.OLD_VALUE=s.ZGLANG_Language)),'X')
 --NVL(TRIM(s.ZGLANG),'X')

UNION ALL
-- CM-006 | Number_of_Children vs SSINCIP.ZKKID (masked field — count only)
--	92533470	56490245            
--    91931014	74925718     
-- mismatches
SELECT 'CM-006', 'Number_of_Children mismatch vs SSINCIP.ZKKID',
       'CONFIRMED', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN v_reconciliation_customer_recordsv2 i ON TRIM(i.CUSTOMER_CODE) = TRIM(mci.PRFT_CUST_ID)
 WHERE NVL(TO_NUMBER(n.Number_of_Children),0) <> 
 CASE WHEN 
 			NVL(TO_NUMBER(i.ZKKID_No_Kids),0)>99 THEN 99
 	  ELSE
 	  		NVL(TO_NUMBER(i.ZKKID_No_Kids),0)
 	  END 

UNION ALL
-- CM-007 | Education_Level vs SSINCIP.ZKEDUC
-- all profits values are 10 or null,waiting for malta to provide parameter mappings
SELECT 'CM-007', 'Education_Level mismatch vs SSINCIP.ZKEDUC',
       'CONFIRMED', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN v_reconciliation_customer_recordsv2 i ON TRIM(i.CUSTOMER_CODE) = TRIM(mci.PRFT_CUST_ID)
 WHERE NVL(TRIM(n.Education_Level),'X') <> NVL(TRIM(i.ZKEDUC_Educ_Level),'X')

-- =============================================================================
-- CAT-2 — PROBABLE FIELD MATCHES (plausible by description, not DD-certain —
-- treat REVIEW results as candidates for confirmation, not hard failures)
-- =============================================================================

UNION ALL
-- CM-008 | Identification_ID_Type vs SSCUSTP.ZGIDTY
SELECT 'CM-008', 'Identification_ID_Type mismatch vs SSCUSTP.ZGIDTY (PROBABLE — confirm mapping)',
       'PROBABLE', COUNT(*), 'Parameter mapping from HSBC missing'
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN v_reconciliation_customer_recordsv2 s ON TRIM(s.CUSTOMER_CODE) = TRIM(mci.PRFT_CUST_ID)
 WHERE NVL(TRIM(TO_CHAR(n.Identification_ID_Type)),'X') <> NVL(TRIM(s.ZGIDTY_ID_Doc_Type),'X')

UNION ALL
-- CM-009 | Identification_ID vs SSCUSTP.ZGIDNO (masked PII — count only, no values exposed)
SELECT 'CM-009', 'Identification_ID mismatch vs SSCUSTP.ZGIDNO (PROBABLE — confirm mapping)',
       'PROBABLE', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN v_reconciliation_customer_recordsv2 s ON TRIM(s.CUSTOMER_CODE) = TRIM(mci.PRFT_CUST_ID)
 WHERE NVL(TRIM(n.Identification_ID),'X') = NVL(TRIM(s.ZGIDNO_ID_Doc_Number),'X')

UNION ALL
-- CM-010 | Tax_ID vs SSCUSTP.ZGTXNO (masked PII — count only)
SELECT 'CM-010', 'Tax_ID mismatch vs SSCUSTP.ZGTXNO (PROBABLE — confirm mapping)',
       'PROBABLE', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN v_reconciliation_customer_recordsv2 s ON TRIM(s.CUSTOMER_CODE) = TRIM(mci.PRFT_CUST_ID)
 WHERE NVL(TRIM(n.Tax_ID),'X') = NVL(TRIM(s.ZGTXNO_Tax_ID_Num),'X')

UNION ALL
-- CM-011 | Family_Status vs SSINCIP.ZKMST
SELECT 'CM-011', 'Family_Status mismatch vs SSINCIP.ZKMST (PROBABLE — confirm mapping)',
       'PROBABLE', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN HUB_MT_SSINCIP i ON TRIM(i.CUSTOMER_CODE) = TRIM(mci.CUSTOMER_CODE)
 WHERE NVL(TRIM(n.Family_Status),'X') <> NVL(TRIM(i.ZKMST),'X')

UNION ALL
-- CM-012 | Activity_Code vs SSCUSTP.ZGINDY (masked — count only). Note source-side
-- inconsistency in 01_CUSTOMER.sql (A5) — expect elevated mismatch rate.
SELECT 'CM-012', 'Activity_Code mismatch vs SSCUSTP.ZGINDY (PROBABLE — confirm mapping; see A5)',
       'PROBABLE', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN HUB_MT_SSCUSTP s ON TRIM(s.CUSTOMER_CODE) = TRIM(mci.CUSTOMER_CODE)
 WHERE NVL(TRIM(TO_CHAR(n.Activity_Code)),'X') <> NVL(TRIM(TO_CHAR(s.ZGINDY)),'X')

UNION ALL
-- CM-013 | Profession vs SSINCIP.ZKOCPT (masked — count only)
SELECT 'CM-013', 'Profession mismatch vs SSINCIP.ZKOCPT (PROBABLE — confirm mapping)',
       'PROBABLE', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN HUB_MT_SSINCIP i ON TRIM(i.CUSTOMER_CODE) = TRIM(mci.CUSTOMER_CODE)
 WHERE NVL(TRIM(n.Profession),'X') <> NVL(TRIM(i.ZKOCPT),'X')

UNION ALL
-- CM-014 | Corporation_Registry_Number vs SSNICIP.XUINCN (masked — count only;
-- applies to non-individual customers only — Customer_Type filter TODO once
-- CM-015 confirms CUST_TYPE <-> VQCSTY mapping)
SELECT 'CM-014', 'Corporation_Registry_Number mismatch vs SSNICIP.XUINCN (PROBABLE — non-individual only)',
       'PROBABLE', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN HUB_MT_SSNICIP ni ON TRIM(ni.CUSTOMER_CODE) = TRIM(mci.CUSTOMER_CODE)
 WHERE n.Corporation_Registry_Number IS NOT NULL
   AND NVL(TRIM(n.Corporation_Registry_Number),'X') <> NVL(TRIM(ni.XUINCN),'X')

UNION ALL
-- CM-015 | Legal_Form vs SSCUSTP.ZGLGTP
SELECT 'CM-015', 'Legal_Form mismatch vs SSCUSTP.ZGLGTP (PROBABLE — confirm mapping)',
       'PROBABLE', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN HUB_MT_SSCUSTP s ON TRIM(s.CUSTOMER_CODE) = TRIM(mci.CUSTOMER_CODE)
 WHERE NVL(TRIM(TO_CHAR(n.Legal_Form)),'X') <> NVL(TRIM(s.ZGLGTP),'X')

UNION ALL
-- CM-016 | Customer_Type vs SSGHCLP.VQCSTY (least confident PROBABLE mapping — INFO-weight)
SELECT 'CM-016', 'Customer_Type distribution vs SSGHCLP.VQCSTY (LOW CONFIDENCE — for review only)',
       'PROBABLE', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers n
  JOIN MG_CUSTOMER_INTER mci ON mci.PRFT_CUST_ID = n.Customer_Code
  JOIN HUB_MT_SSCUSTP s ON TRIM(s.CUSTOMER_CODE) = TRIM(mci.CUSTOMER_CODE)
  JOIN HUB_MT_SSGHCLP g ON TRIM(s.ZGGHCL) = TRIM(g.VQGHCL)
 WHERE NVL(TRIM(TO_CHAR(n.Customer_Type)),'X') <> NVL(TRIM(g.VQCSTY),'X')

-- =============================================================================
-- CAT-3 — NOT FOUND: no confirmed HUB_MT field identified in DD subset.
-- COUNT(*)-only INFO placeholders per project no-fabrication rule. Row count
-- = total NCIS_Customers population with a non-null source value, for volume
-- reference only — NOT a mismatch count (INFO, no comparison performed).
-- =============================================================================

UNION ALL
-- CM-017 | Customer_Check_Digit — TODO: confirm if embedded in ZGDCS last digit
SELECT 'CM-017', 'Customer_Check_Digit — TODO: no confirmed HUB field (see A3)',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Customer_Check_Digit IS NOT NULL

UNION ALL
-- CM-018 | First_Name — TODO: derivable via SSCUSTP.ZGFNSP/ZGFNLN substring of ZGCSFN
SELECT 'CM-018', 'First_Name — TODO: derived field only (ZGFNSP/ZGFNLN substring), not directly comparable',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE First_Name IS NOT NULL

UNION ALL
-- CM-019 | Surname — TODO: derivable via SSCUSTP.ZGLNSP/ZGLNLN substring of ZGCSFN
SELECT 'CM-019', 'Surname — TODO: derived field only (ZGLNSP/ZGLNLN substring), not directly comparable',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Surname IS NOT NULL

UNION ALL
-- CM-020 | Father_name — TODO: no field found in SSCUSTP/SSINCIP DD
SELECT 'CM-020', 'Father_name — TODO: no confirmed HUB field',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Father_name IS NOT NULL

UNION ALL
-- CM-021 | Country_of_Birth — TODO: no field found in SSCUSTP/SSINCIP/SSNICIP DD
SELECT 'CM-021', 'Country_of_Birth — TODO: no confirmed HUB field',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Country_of_Birth IS NOT NULL

UNION ALL
-- CM-022 | Identification_ID_Issue_Date — TODO: no field found in DD subset
SELECT 'CM-022', 'Identification_ID_Issue_Date — TODO: no confirmed HUB field',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Identification_ID_Issue_Date IS NOT NULL

UNION ALL
-- CM-023 | Identification_ID_Issue_Authority — TODO: no field found in DD subset
SELECT 'CM-023', 'Identification_ID_Issue_Authority — TODO: no confirmed HUB field',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Identification_ID_Issue_Authority IS NOT NULL

UNION ALL
-- CM-024 | Identification_ID_Issue_Country — TODO: see A5, source-side duplicate field
SELECT 'CM-024', 'Identification_ID_Issue_Country — TODO: no confirmed HUB field (see A5)',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Identification_ID_Issue_Country IS NOT NULL

UNION ALL
-- CM-025 | Tax_ID_Office — TODO: no field found in DD subset
SELECT 'CM-025', 'Tax_ID_Office — TODO: no confirmed HUB field',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Tax_ID_Office IS NOT NULL

UNION ALL
-- CM-026 | Mobile_Telephone — TODO: not in SSCUSTP/SSINCIP subset; check SSADDRP or similar
SELECT 'CM-026', 'Mobile_Telephone — TODO: no confirmed HUB field in this DD subset',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Mobile_Telephone IS NOT NULL

UNION ALL
-- CM-027 | email — TODO: not in SSCUSTP/SSINCIP subset
SELECT 'CM-027', 'email — TODO: no confirmed HUB field in this DD subset',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE email IS NOT NULL

UNION ALL
-- CM-028 | Citizenship — TODO: possible overlap with Nationality/ZGCTRS, needs NC clarification
SELECT 'CM-028', 'Citizenship — TODO: no confirmed distinct HUB field (possible overlap with Nationality)',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Citizenship IS NOT NULL

UNION ALL
-- CM-029 | Financial_Sector — TODO: candidate ZGMKS1/2/3 but slot unconfirmed
SELECT 'CM-029', 'Financial_Sector — TODO: candidate SSCUSTP.ZGMKS1/2/3, slot not confirmed',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Financial_Sector IS NOT NULL

UNION ALL
-- CM-030 | Professional_Status — TODO: no field found in DD subset
SELECT 'CM-030', 'Professional_Status — TODO: no confirmed HUB field',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Professional_Status IS NOT NULL

UNION ALL
-- CM-031 | Insurance_Clearance_Expiration_Date — TODO: no HUB source, likely PROFITS-only
SELECT 'CM-031', 'Insurance_Clearance_Expiration_Date — TODO: likely no HUB source (PROFITS-only enrichment)',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Insurance_Clearance_Expiration_Date IS NOT NULL

UNION ALL
-- CM-032 | Corporation_Registry_Number_Issue_Country — TODO: candidate SSNICIP.XUCTHQ, not confirmed
SELECT 'CM-032', 'Corp_Registry_Number_Issue_Country — TODO: candidate SSNICIP.XUCTHQ, not confirmed',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Corporation_Registry_Number_Issue_Country IS NOT NULL

UNION ALL
-- CM-033 | Risk_Classification — TODO: likely SSCDDMP.CMRSKC (different table, outside this join)
SELECT 'CM-033', 'Risk_Classification — TODO: likely SSCDDMP.CMRSKC, outside SSCUSTP/SSINCIP join scope',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Risk_Classification IS NOT NULL

UNION ALL
-- CM-034 | Special_Agreements — TODO: no field found in DD subset
SELECT 'CM-034', 'Special_Agreements — TODO: no confirmed HUB field',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Special_Agreements IS NOT NULL

UNION ALL
-- CM-035 | Tax_ID_Issue_Country — TODO: no field found in DD subset
SELECT 'CM-035', 'Tax_ID_Issue_Country — TODO: no confirmed HUB field',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Tax_ID_Issue_Country IS NOT NULL

UNION ALL
-- CM-036 | Customer_Creation_Date — TODO: candidate SSCUSTP.ZGDTAD ("Date Request Added"), not confirmed
SELECT 'CM-036', 'Customer_Creation_Date — TODO: candidate SSCUSTP.ZGDTAD, not confirmed',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE Customer_Creation_Date IS NOT NULL

UNION ALL
-- CM-037 | AMLRICAT — TODO: possibly related to SSCDDMP.CMRSKC, not confirmed
SELECT 'CM-037', 'AMLRICAT — TODO: no confirmed HUB field (possibly related to SSCDDMP.CMRSKC)',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE AMLRICAT IS NOT NULL

UNION ALL
-- CM-038 | CUSTOMER_ENTRY_COMMENTS — TODO: no HUB source, likely PROFITS-only free text
SELECT 'CM-038', 'CUSTOMER_ENTRY_COMMENTS — TODO: likely no HUB source (PROFITS-only free text)',
       'NOT_FOUND', COUNT(*), CAST(NULL AS VARCHAR2(200))
  FROM NCIS_Customers WHERE CUSTOMER_ENTRY_COMMENTS IS NOT NULL

) C
--ORDER BY C.CATEGORY--, C.CHECK_ID
-- =============================================================================
