SELECT
    CAST('ME01_HUB_DQC100' AS NVARCHAR2(50))   AS DQ_TYPE,
    CAST(y.dq_category AS NVARCHAR2(100))      AS DQ_CATEGORY,
    CAST(y.check_name  AS NVARCHAR2(500))      AS CHECK_NAME,
    CAST(y.table_name  AS NVARCHAR2(100))      AS TABLE_NAME,
    CAST(y.failed_records AS NUMBER)           AS FAILED_RECORDS,
    CAST(y.total_records AS NUMBER)            AS TOTAL_RECORDS,
    CAST(y.failure_pct AS NUMBER(10,2))        AS FAILURE_PCT,
    CAST(NULL AS NVARCHAR2(20))                AS CHECK_ID,
    CAST(NULL AS NUMBER(20,2))                 AS RESULT_NUM,
    CAST(NULL AS NVARCHAR2(2000))              AS RESULT_TXT,
    CAST(NULL AS NUMBER(20,2))                 AS EXPECTED,
    CAST(
        CASE
            WHEN y.failure_pct = 0 THEN 'PASS'
            WHEN y.failure_pct < 1 THEN 'LOW'
            WHEN y.failure_pct < 5 THEN 'MEDIUM'
            ELSE 'HIGH'
        END AS NVARCHAR2(20)
    ) AS DQ_STATUS
FROM (
    SELECT
        dq_category,
        check_name,
        table_name,
        failed_records,
        total_records,
        ROUND(failed_records * 100.0 / NULLIF(total_records, 0), 2) AS failure_pct
    FROM (

-- 1.1 | Missing Customer Full Name (ZGCSFN)
    SELECT '1. Completeness' AS dq_category,
           'Missing Customer Full Name' AS check_name,
           'SSCUSTP' AS table_name,
           COUNT(CASE WHEN ZGCSFN IS NULL OR TRIM(ZGCSFN) IS NULL THEN 1 END) AS failed_records,
           COUNT(*) AS total_records
    FROM DATACUT3.HUB_MT_SSCUSTP

    UNION ALL

    -- 1.2 | Missing GHO Classification (ZGGHCL)
    SELECT '1. Completeness', 'Missing GHO Classification', 'SSCUSTP',
           COUNT(CASE WHEN ZGGHCL IS NULL OR TRIM(ZGGHCL) IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCUSTP

    UNION ALL

    -- 1.3 | Missing Date of Birth (ZKDTBR = NULL or 0)
    SELECT '1. Completeness', 'Missing Date of Birth', 'SSINCIP',
           COUNT(CASE WHEN ZKDTBR IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSINCIP

    UNION ALL

    -- 1.4 | Missing Sex Code (ZKSEX)
    SELECT '1. Completeness', 'Missing Sex Code', 'SSINCIP',
           COUNT(CASE WHEN ZKSEX IS NULL OR TRIM(ZKSEX) IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSINCIP

    UNION ALL

    -- 1.5 | Missing Account Short Name (DFACSN) — active DD accounts only
    SELECT '1. Completeness', 'Missing Account Short Name', 'DDACMSP',
           COUNT(CASE WHEN DFACSN IS NULL OR TRIM(DFACSN) IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP
    WHERE DFSTUS != '5'

    UNION ALL

    -- 1.6 | Missing Date Account Opened (DFDTAO)
    SELECT '1. Completeness', 'Missing Date Account Opened', 'DDACMSP',
           COUNT(CASE WHEN DFDTAO IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP
    WHERE DFSTUS != '5'

    UNION ALL

    -- 1.7 | Missing Loan Open Date (PODTAO)
    SELECT '1. Completeness', 'Missing Loan Open Date', 'LSACMSP',
           COUNT(CASE WHEN PODTAO IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSACMSP
    WHERE POSTUS != '5'

    UNION ALL

    -- 1.8 | Customers Without Address
    -- FIX-01: SSADDRP has no ZBDCG field. Join on ZBDCB+ZBDCS only.
    SELECT '1. Completeness', 'Customers Without Address', 'SSCUSTP/SSADDRP',
           COUNT(CASE WHEN a.ZBDCB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCUSTP c
    LEFT JOIN DATACUT3.HUB_MT_SSADDRP a
           ON a.ZBDCB = c.ZGDCB
          AND a.ZBDCS = c.ZGDCS
    WHERE c.ZGDROP != 'Y'

    UNION ALL

    -- 1.9 | Missing VAT Number Non-Individual (XUVATR)
    SELECT '1. Completeness', 'Missing VAT Number (Non-Individual)', 'SSNICIP',
           COUNT(CASE WHEN XUVATR IS NULL OR XUVATR = 0 THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSNICIP

    UNION ALL

    -- 1.10 | Missing IBAN Value (IBIBAN)
    SELECT '1. Completeness', 'Missing IBAN Value', 'DDIBANP',
           COUNT(CASE WHEN IBIBAN IS NULL OR TRIM(IBIBAN) IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDIBANP

    UNION ALL

    -- 1.11 | Missing Occupation Code (ZKOCPT)
    SELECT '1. Completeness', 'Missing Occupation Code (Individuals)', 'SSINCIP',
           COUNT(CASE WHEN ZKOCPT IS NULL OR TRIM(ZKOCPT) IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSINCIP

-- =============================================================================
-- CAT-2: VALIDITY (17 checks)
-- =============================================================================

    UNION ALL

    -- 2.1 | Invalid DD Account Status (must be 1–5)
    SELECT '2. Validity', 'Invalid Account Status', 'DDACMSP',
           COUNT(CASE WHEN DFSTUS NOT IN ('1','2','3','4','5') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP

    UNION ALL

    -- 2.2 | Invalid Loan Status
    SELECT '2. Validity', 'Invalid Loan Status', 'LSACMSP',
           COUNT(CASE WHEN POSTUS NOT IN ('1','2','3','4','5') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSACMSP

    UNION ALL

    -- 2.3 | Invalid TD Status
    SELECT '2. Validity', 'Invalid TD Status', 'TDACMSP',
           COUNT(CASE WHEN TDSTUS NOT IN ('1','2','3','4','5') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_TDACMSP

    UNION ALL

    -- 2.4 | Date of Birth in Future
    SELECT '2. Validity', 'Date of Birth in Future', 'SSINCIP',
           COUNT(CASE WHEN ZKDTBR > DATE '2026-06-15' THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSINCIP
    WHERE ZKDTBR IS NOT NULL

    UNION ALL

    -- 2.5 | Customer Age Under 18
    SELECT '2. Validity', 'Customer Age Under 18', 'SSINCIP',
           COUNT(CASE WHEN FLOOR(MONTHS_BETWEEN(DATE '2026-06-15', ZKDTBR) / 12) < 18 THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSINCIP
    WHERE ZKDTBR IS NOT NULL

    UNION ALL

    -- 2.6 | Customer Age Over 120
    SELECT '2. Validity', 'Customer Age Over 120', 'SSINCIP',
           COUNT(CASE WHEN FLOOR(MONTHS_BETWEEN(DATE '2026-06-15', ZKDTBR) / 12) > 120 THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSINCIP
    WHERE ZKDTBR IS NOT NULL

    UNION ALL

    -- 2.7 | Account Open Date in Future
    SELECT '2. Validity', 'Account Open Date in Future', 'DDACMSP',
           COUNT(CASE WHEN DFDTAO > DATE '2026-06-15' THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP
    WHERE DFDTAO IS NOT NULL

    UNION ALL

    -- 2.8 | Negative Loan Outstanding Principal [OI-001 STOPPER]
    SELECT '2. Validity', 'Negative Loan Outstanding Principal', 'LSACMSP',
           COUNT(CASE WHEN POROPR < 0 THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSACMSP
    WHERE POSTUS NOT IN ('4','5')

    UNION ALL

    -- 2.9 | Invalid Sex Code (must be M, F, U, or blank)
    SELECT '2. Validity', 'Invalid Sex Code', 'SSINCIP',
           COUNT(CASE WHEN ZKSEX NOT IN ('M','F','U',' ') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSINCIP
    WHERE ZKSEX IS NOT NULL

    UNION ALL

    -- 2.10 | Invalid Client Indicator (ZGRCBI) for active customers
    SELECT '2. Validity', 'Invalid Client Indicator', 'SSCUSTP',
           COUNT(CASE WHEN ZGRCBI IS NULL
                          OR TRIM(ZGRCBI) NOT IN ('R','C','B','S','N','X','L','I') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCUSTP
    WHERE ZGDROP != 'Y'

    UNION ALL

    -- 2.11 | Invalid IBAN Length (Malta = 31 chars)
    SELECT '2. Validity', 'Invalid IBAN Length (not 31 chars)', 'DDIBANP',
           COUNT(CASE WHEN LENGTH(TRIM(IBIBAN)) != 31 THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDIBANP
    WHERE IBIBAN IS NOT NULL

    UNION ALL

    -- 2.12 | Zero Interest Rate on Active Loan (POTINR)
    SELECT '2. Validity', 'Zero Interest Rate on Active Loan', 'LSACMSP',
           COUNT(CASE WHEN POTINR = 0 OR POTINR IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSACMSP
    WHERE POSTUS = '1'

    UNION ALL

    -- 2.13 | IBAN Invalid Country Prefix (not MT)
    SELECT '2. Validity', 'IBAN Invalid Country Prefix (not MT)', 'DDIBANP',
           COUNT(CASE WHEN IBIBAN IS NOT NULL AND TRIM(IBIBAN) IS NOT NULL
                       AND SUBSTR(TRIM(IBIBAN),1,2) != 'MT' THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDIBANP

    UNION ALL

    -- 2.14 | Interest Accrual End Date Out of Valid Range (EQENDT)
    SELECT '2. Validity', 'Interest Accrual End Date Out of Valid Range', 'LSINACP',
           COUNT(CASE WHEN EQENDT IS NULL
                           OR EQENDT > ADD_MONTHS(DATE '2026-06-15',12) THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSINACP

    UNION ALL

    -- 2.15 | Active SI With Invalid Next Payment Date (FNPPDP) [OI-005 HIGH]
    SELECT '2. Validity', 'Active SI With Invalid Next Payment Date', 'AFSIMSP',
           COUNT(CASE WHEN FNPPDP IS NULL OR FNPPDP = 0
                           OR FNPPDP < TO_NUMBER(TO_CHAR(ADD_MONTHS(DATE '2026-06-15',-24),'YYYYMMDD')) THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_AFSIMSP

    UNION ALL

    -- 2.16 | Credit Application Capture Date After Approval Date (SS@CAJP)
    -- Fields CACPDT, CAAVDT confirmed in DD v1.14
    SELECT '2. Validity', 'Credit Application Capture Date After Approval Date', 'SS@CAJP',
           COUNT(CASE WHEN CACPDT IS NOT NULL AND CAAVDT IS NOT NULL AND CACPDT > CAAVDT THEN 1 END), COUNT(*)
    FROM DATACUT3."HUB_MT_SS@CAJP"
    WHERE CAAVDT IS NOT NULL

    UNION ALL

    -- 2.17 | Active TD With Missing Maturity Date (TDDUDT)
    SELECT '2. Validity', 'Active TD With Missing Maturity Date', 'TDACMSP',
           COUNT(CASE WHEN TDDUDT IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_TDACMSP
    WHERE TDSTUS = '1'

-- =============================================================================
-- CAT-3: REFERENTIAL INTEGRITY (27 checks)
-- =============================================================================

    UNION ALL

    -- 3.1 | DD Accounts Without Customer (Orphan)
    -- DDACMSP customer key: DFDCG, DFDCB, DFDCS
    SELECT '3. Referential', 'DD Accounts Without Customer (Orphan)', 'DDACMSP',
           COUNT(CASE WHEN c.ZGDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP a
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCG = a.DFDCG AND c.ZGDCB = a.DFDCB AND c.ZGDCS = a.DFDCS
    WHERE a.DFSTUS != '5'

    UNION ALL

    -- 3.2 | Loans Without Customer (Orphan)
    -- LSACMSP customer key: PODCG, PODCB, PODCS
    SELECT '3. Referential', 'Loans Without Customer (Orphan)', 'LSACMSP',
           COUNT(CASE WHEN c.ZGDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSACMSP l
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCG = l.PODCG AND c.ZGDCB = l.PODCB AND c.ZGDCS = l.PODCS
    WHERE l.POSTUS != '5'

    UNION ALL

    -- 3.3 | Term Deposits Without Customer (Orphan)
    -- TDACMSP customer key: TDDCG, TDDCB, TDDCS
    SELECT '3. Referential', 'Term Deposits Without Customer (Orphan)', 'TDACMSP',
           COUNT(CASE WHEN c.ZGDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_TDACMSP t
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCG = t.TDDCG AND c.ZGDCB = t.TDDCB AND c.ZGDCS = t.TDDCS
    WHERE t.TDSTUS != '5'

    UNION ALL

    -- 3.4 | IBAN Without DD Account (Orphan)
    -- DDIBANP account key: IBACB, IBACS, IBACX
    SELECT '3. Referential', 'IBAN Without DD Account (Orphan)', 'DDIBANP',
           COUNT(CASE WHEN a.DFACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDIBANP i
    LEFT JOIN DATACUT3.HUB_MT_DDACMSP a
           ON a.DFACB = i.IBACB AND a.DFACS = i.IBACS AND a.DFACX = i.IBACX

    UNION ALL

    -- 3.5 | E-Banking Without Customer (Orphan)
    -- EBCUSTP customer key: PCDCB, PCDCS (no PCDCG in DD — branch+serial only)
    SELECT '3. Referential', 'E-Banking Without Customer (Orphan)', 'EBCUSTP',
           COUNT(CASE WHEN c.ZGDCB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_EBCUSTP e
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c ON c.ZGDCB = e.PCDCB AND c.ZGDCS = e.PCDCS

    UNION ALL

    -- 3.6 | SSINCIP Without SSCUSTP Record
    -- SSINCIP customer key: ZKDCG, ZKDCB, ZKDCS
    SELECT '3. Referential', 'SSINCIP Without SSCUSTP Record', 'SSINCIP',
           COUNT(CASE WHEN c.ZGDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSINCIP i
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCG = i.ZKDCG AND c.ZGDCB = i.ZKDCB AND c.ZGDCS = i.ZKDCS

    UNION ALL

    -- 3.7 | Overdraft Accounts Without Customer
    -- DCACMSP customer key: D1DCG, D1DCB, D1DCS
    SELECT '3. Referential', 'Overdraft Accounts Without Customer', 'DCACMSP',
           COUNT(CASE WHEN c.ZGDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DCACMSP dc
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCG = dc.D1DCG AND c.ZGDCB = dc.D1DCB AND c.ZGDCS = dc.D1DCS

    UNION ALL

    -- 3.8 | PGL Accounts Without Customer (Orphan)
    -- PLACMSP customer key: PFDCG, PFDCB, PFDCS
    SELECT '3. Referential', 'PGL Accounts Without Customer (Orphan)', 'PLACMSP',
           COUNT(CASE WHEN c.ZGDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_PLACMSP p
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCG = p.PFDCG AND c.ZGDCB = p.PFDCB AND c.ZGDCS = p.PFDCS

    UNION ALL

    -- 3.9 | Cheque Book Without DD Account (Orphan)
    -- DDCQBKP account key: DJACB, DJACS, DJACX
    SELECT '3. Referential', 'Cheque Book Without DD Account (Orphan)', 'DDCQBKP',
           COUNT(CASE WHEN a.DFACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDCQBKP cq
    LEFT JOIN DATACUT3.HUB_MT_DDACMSP a
           ON a.DFACB = cq.DJACB AND a.DFACS = cq.DJACS AND a.DFACX = cq.DJACX

    UNION ALL

    -- 3.10 | Stop Cheque Without DD Account (Orphan)
    -- DDSPCQP account key: DKACB, DKACS, DKACX
    SELECT '3. Referential', 'Stop Cheque Without DD Account (Orphan)', 'DDSPCQP',
           COUNT(CASE WHEN a.DFACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDSPCQP sc
    LEFT JOIN DATACUT3.HUB_MT_DDACMSP a
           ON a.DFACB = sc.DKACB AND a.DFACS = sc.DKACS AND a.DFACX = sc.DKACX

    UNION ALL

    -- 3.11 | Interest Accrual Without Loan Account (Orphan)
    -- LSINACP account key: EQACB, EQACS, EQACX
    SELECT '3. Referential', 'Interest Accrual Without Loan Account (Orphan)', 'LSINACP',
           COUNT(CASE WHEN ls.POACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSINACP ia
    LEFT JOIN DATACUT3.HUB_MT_LSACMSP ls
           ON ls.POACB = ia.EQACB AND ls.POACS = ia.EQACS AND ls.POACX = ia.EQACX

    UNION ALL

    -- 3.12 | Repayment History Without Loan Account (Orphan)
    -- LSRHSLP account key: CFACB, CFACS, CFACX
    SELECT '3. Referential', 'Repayment History Without Loan Account (Orphan)', 'LSRHSLP',
           COUNT(CASE WHEN ls.POACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSRHSLP rh
    LEFT JOIN DATACUT3.HUB_MT_LSACMSP ls
           ON ls.POACB = rh.CFACB AND ls.POACS = rh.CFACS AND ls.POACX = rh.CFACX

    UNION ALL

    -- 3.13 | Payment History Without Loan Account (Orphan)
    -- LSPMHSP account key: CNACB, CNACS, CNACX
    SELECT '3. Referential', 'Payment History Without Loan Account (Orphan)', 'LSPMHSP',
           COUNT(CASE WHEN ls.POACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSPMHSP ph
    LEFT JOIN DATACUT3.HUB_MT_LSACMSP ls
           ON ls.POACB = ph.CNACB AND ls.POACS = ph.CNACS AND ls.POACX = ph.CNACX

    UNION ALL

    -- 3.14 | Address Without Customer Record (Orphan)
    -- FIX-02: SSADDRP has no ZBDCG. Join on ZBDCB+ZBDCS only.
    SELECT '3. Referential', 'Address Without Customer Record (Orphan)', 'SSADDRP',
           COUNT(CASE WHEN c.ZGDCB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSADDRP ad
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCB = ad.ZBDCB
          AND c.ZGDCS = ad.ZBDCS

    UNION ALL

    -- 3.15 | Collateral Relationship Without Security Record (Orphan)
    -- SSSCRLP → SSSECHP: VYDCG/VYDCB/VYDCS/VYLGI
    SELECT '3. Referential', 'Collateral Relationship Without Security Record (Orphan)', 'SSSCRLP',
           COUNT(CASE WHEN sec.Y2DCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSSCRLP sr
    LEFT JOIN DATACUT3.HUB_MT_SSSECHP sec
           ON sec.Y2DCG = sr.VYDCG AND sec.Y2DCB = sr.VYDCB
          AND sec.Y2DCS = sr.VYDCS AND sec.Y2LGI = sr.VYLGI

    UNION ALL

    -- 3.16 | SI Transaction Without SI Master Record (Orphan)
    -- AFSITJP → AFSIMSP: F0PPAB/F0PPAS/F0PPAX → FNPPAB/FNPPAS/FNPPAX
    SELECT '3. Referential', 'SI Transaction Without SI Master Record (Orphan)', 'AFSITJP',
           COUNT(CASE WHEN m.FNPPAB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_AFSITJP tj
    LEFT JOIN DATACUT3.HUB_MT_AFSIMSP m
           ON m.FNPPAB = tj.F0PPAB AND m.FNPPAS = tj.F0PPAS AND m.FNPPAX = tj.F0PPAX

    UNION ALL

    -- 3.17 | SI Retention Amount Without SI Master (Orphan)
    -- AFSIRAP → AFSIMSP: FTPPAB/FTPPAS/FTPPAX → FNPPAB/FNPPAS/FNPPAX
    SELECT '3. Referential', 'SI Retention Amount Without SI Master (Orphan)', 'AFSIRAP',
           COUNT(CASE WHEN m.FNPPAB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_AFSIRAP r
    LEFT JOIN DATACUT3.HUB_MT_AFSIMSP m
           ON m.FNPPAB = r.FTPPAB AND m.FNPPAS = r.FTPPAS AND m.FNPPAX = r.FTPPAX

    UNION ALL

    -- 3.18 | CDD Record References Inactive/Missing Customer
    -- SSCDDMP → SSCUSTP: CMDCG/CMDCB/CMDCS
    SELECT '3. Referential', 'CDD Record References Inactive/Missing Customer', 'SSCDDMP',
           COUNT(CASE WHEN c.ZGDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCDDMP d
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCG = d.CMDCG AND c.ZGDCB = d.CMDCB AND c.ZGDCS = d.CMDCS
          AND c.ZGDROP != 'Y'

    UNION ALL

    -- 3.19 | DD Account Without Credit Interest Segment
    -- DDACMSP → DDCRINP: DFACB/DFACS/DFACX → DGACB/DGACS/DGACX
    SELECT '3. Referential', 'DD Account Without Credit Interest Segment', 'DDACMSP',
           COUNT(CASE WHEN ci.DGACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP a
    LEFT JOIN DATACUT3.HUB_MT_DDCRINP ci
           ON ci.DGACB = a.DFACB AND ci.DGACS = a.DFACS AND ci.DGACX = a.DFACX
    WHERE a.DFSTUS != '5'

    UNION ALL

    -- 3.20 | DD Account Without Extension Record
    -- DDACMSP → DDACESP: same DFACB/DFACS/DFACX key
    SELECT '3. Referential', 'DD Account Without Extension Record', 'DDACMSP',
           COUNT(CASE WHEN ext.DFACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP a
    LEFT JOIN DATACUT3.HUB_MT_DDACESP ext
           ON ext.DFACB = a.DFACB AND ext.DFACS = a.DFACS AND ext.DFACX = a.DFACX
    WHERE a.DFSTUS != '5'

    UNION ALL

    -- 3.21 | DD Account Without Statement Segment
    -- DDACMSP → DDSTMTP: DFACB/DFACS/DFACX → DHACB/DHACS/DHACX
    SELECT '3. Referential', 'DD Account Without Statement Segment', 'DDACMSP',
           COUNT(CASE WHEN st.DHACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP a
    LEFT JOIN DATACUT3.HUB_MT_DDSTMTP st
           ON st.DHACB = a.DFACB AND st.DHACS = a.DFACS AND st.DHACX = a.DFACX
    WHERE a.DFSTUS = '1'

    UNION ALL

    -- 3.22 | Active Loan Without Repayment Schedule
    -- LSACMSP → LSRPSLP: POACB/POACS/POACX → RNACB/RNACS/RNACX
    SELECT '3. Referential', 'Active Loan Without Repayment Schedule', 'LSACMSP',
           COUNT(CASE WHEN rs.RNACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSACMSP l
    LEFT JOIN DATACUT3.HUB_MT_LSRPSLP rs
           ON rs.RNACB = l.POACB AND rs.RNACS = l.POACS AND rs.RNACX = l.POACX
    WHERE l.POSTUS = '1'

    UNION ALL

    -- 3.23 | SEPA Direct Debit Without Valid IBAN Reference [OI-002 STOPPER]
    -- EUDTSDDP.SDCRAC → DDIBANP.IBIBAN
    SELECT '3. Referential', 'SEPA Direct Debit Without Valid IBAN Reference', 'EUDTSDDP',
           COUNT(CASE WHEN ib.IBIBAN IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_EUDTSDDP sd
    LEFT JOIN DATACUT3.HUB_MT_DDIBANP ib ON ib.IBIBAN = sd.SDCRAC
    WHERE sd.SDCRAC IS NOT NULL AND TRIM(sd.SDCRAC) IS NOT NULL

    UNION ALL

    -- 3.24 | Collateral Without Facility/Account Link
    -- SSSECHP → SSSCRLP: Y2DCG/Y2DCB/Y2DCS/Y2LGI → VYDCG/VYDCB/VYDCS/VYLGI
    SELECT '3. Referential', 'Collateral Without Facility/Account Link', 'SSSECHP',
           COUNT(CASE WHEN sr.VYDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSSECHP sec
    LEFT JOIN DATACUT3.HUB_MT_SSSCRLP sr
           ON sr.VYDCG = sec.Y2DCG AND sr.VYDCB = sec.Y2DCB
          AND sr.VYDCS = sec.Y2DCS AND sr.VYLGI = sec.Y2LGI

    UNION ALL

    -- 3.25 | Write-off Account Without Customer Record
    -- SSCLACP customer key: ZIDCG, ZIDCB, ZIDCS (confirmed in DD)
    SELECT '3. Referential', 'Write-off Account Without Customer Record', 'SSCLACP',
           COUNT(CASE WHEN c.ZGDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCLACP cl
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCG = cl.ZIDCG AND c.ZGDCB = cl.ZIDCB AND c.ZGDCS = cl.ZIDCS

    UNION ALL

    -- 3.26 | IB Account ID Without DD Account (Orphan)
    -- FIX-04: IBACIDP is an account-reference table, not a customer table.
    -- DD fields: IAACB, IAACS, IAACX → DDACMSP DFACB, DFACS, DFACX
    -- (LBDCB/LBDCS do NOT exist in IBACIDP DD v1.14)
    SELECT '3. Referential', 'IB Account ID Without DD Account (Orphan)', 'IBACIDP',
           COUNT(CASE WHEN a.DFACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_IBACIDP ib
    LEFT JOIN DATACUT3.HUB_MT_DDACMSP a
           ON a.DFACB = ib.IAACB AND a.DFACS = ib.IAACS AND a.DFACX = ib.IAACX

    UNION ALL

    -- 3.27 | TD Account With Product Code Not in TD Product Control
    -- TDACMSP.TDAPTY → TDPDCPP.TAAPTY
    SELECT '3. Referential', 'TD Account With Product Code Not in TD Product Control', 'TDACMSP/TDPDCPP',
           COUNT(CASE WHEN pc.TAAPTY IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_TDACMSP t
    LEFT JOIN DATACUT3.HUB_MT_TDPDCPP pc ON pc.TAAPTY = t.TDAPTY
    WHERE t.TDSTUS != '5'

-- =============================================================================
-- CAT-4: CONSISTENCY (21 checks)
-- =============================================================================

    UNION ALL

    -- 4.1 | Active Customer Flag (ZGCAST='Y') but No Active Account
    SELECT '4. Consistency', 'Active Customer Flag but No Active Account', 'SSCUSTP',
           COUNT(CASE WHEN dd.DFDCG IS NULL AND ls.PODCG IS NULL AND td.TDDCG IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCUSTP c
    LEFT JOIN (SELECT DISTINCT DFDCG, DFDCB, DFDCS FROM DATACUT3.HUB_MT_DDACMSP WHERE DFSTUS = '1') dd
           ON dd.DFDCG = c.ZGDCG AND dd.DFDCB = c.ZGDCB AND dd.DFDCS = c.ZGDCS
    LEFT JOIN (SELECT DISTINCT PODCG, PODCB, PODCS FROM DATACUT3.HUB_MT_LSACMSP WHERE POSTUS = '1') ls
           ON ls.PODCG = c.ZGDCG AND ls.PODCB = c.ZGDCB AND ls.PODCS = c.ZGDCS
    LEFT JOIN (SELECT DISTINCT TDDCG, TDDCB, TDDCS FROM DATACUT3.HUB_MT_TDACMSP WHERE TDSTUS = '1') td
           ON td.TDDCG = c.ZGDCG AND td.TDDCB = c.ZGDCB AND td.TDDCS = c.ZGDCS
    WHERE c.ZGCAST = 'Y'

    UNION ALL

    -- 4.2 | DD Account Currency Mismatch with IBAN (DFCYCD ≠ IBCYCD)
    SELECT '4. Consistency', 'DD Account Currency Mismatch with IBAN', 'DDACMSP/DDIBANP',
           (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDACMSP a
            JOIN DATACUT3.HUB_MT_DDIBANP i
                ON a.DFACB = i.IBACB AND a.DFACS = i.IBACS AND a.DFACX = i.IBACX
            WHERE a.DFCYCD != i.IBCYCD),
           (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDIBANP)
    FROM DUAL

    UNION ALL

    -- 4.3 | Closed DD Account (DFSTUS='5') with Positive Balance (DFRLBL > 0)
    SELECT '4. Consistency', 'Closed DD Account with Positive Balance', 'DDACMSP',
           COUNT(CASE WHEN DFSTUS = '5' AND DFRLBL > 0 THEN 1 END),
           COUNT(CASE WHEN DFSTUS = '5' THEN 1 END)
    FROM DATACUT3.HUB_MT_DDACMSP

    UNION ALL

    -- 4.4 | Past Due Loan with Non-Overdue Maturity Code (POPDUE/POMTCD)
    SELECT '4. Consistency', 'Past Due Loan with Non-Overdue Maturity Code', 'LSACMSP',
           COUNT(CASE WHEN POPDUE = 'Y' AND POMTCD NOT IN ('P','Q','R','S','T') THEN 1 END),
           COUNT(CASE WHEN POPDUE = 'Y' THEN 1 END)
    FROM DATACUT3.HUB_MT_LSACMSP

    UNION ALL

    -- 4.5 | TD Maturity Date Before Open Date (TDDUDT < TDDTAO)
    SELECT '4. Consistency', 'TD Maturity Date Before Open Date', 'TDACMSP',
           COUNT(CASE WHEN TDDUDT < TDDTAO AND TDDUDT IS NOT NULL AND TDDTAO IS NOT NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_TDACMSP

    UNION ALL

    -- 4.6 | Customer in Both Individual and Non-Individual Tables
    -- SSINCIP key: ZKDCG/ZKDCB/ZKDCS — SSNICIP key: XUDCG/XUDCB/XUDCS
    SELECT '4. Consistency', 'Customer in Both Individual and Non-Individual Tables', 'SSINCIP/SSNICIP',
           (SELECT COUNT(*) FROM DATACUT3.HUB_MT_SSINCIP i
            WHERE EXISTS (SELECT 1 FROM DATACUT3.HUB_MT_SSNICIP n
                          WHERE n.XUDCG = i.ZKDCG AND n.XUDCB = i.ZKDCB AND n.XUDCS = i.ZKDCS)),
           (SELECT COUNT(*) FROM DATACUT3.HUB_MT_SSINCIP)
    FROM DUAL

    UNION ALL

    -- 4.7 | E-Banking Customer With No Active DD Account [DC1: 23.31% HIGH]
    -- EBCUSTP key: PCDCB, PCDCS
    SELECT '4. Consistency', 'E-Banking Customer With No Active DD Account', 'EBCUSTP',
           COUNT(CASE WHEN dd.DFDCB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_EBCUSTP e
    LEFT JOIN (SELECT DISTINCT DFDCB, DFDCS FROM DATACUT3.HUB_MT_DDACMSP
               WHERE DFSTUS NOT IN ('4','5')) dd
           ON dd.DFDCB = e.PCDCB AND dd.DFDCS = e.PCDCS

    UNION ALL

    -- 4.8 | Loan Maturity Date Before Open Date
    -- TODO — DD VERIFICATION NEEDED: all_tab_columns confirms POMTCD is VARCHAR2
    -- and, per check 4.4, holds a maturity STATUS CODE ('P','Q','R','S','T'), not
    -- a date. PODTAO is DATE, not numeric — REGEXP_LIKE(PODTAO,...) here would
    -- silently misfire (implicit DATE->VARCHAR2 uses NLS default format, which
    -- won't match '^[0-9]+$', so dtao would evaluate to 0 for nearly every row).
    -- This check as originally written compares the wrong field for "maturity
    -- date" — confirm the actual loan-maturity-date column name in the DD
    -- (likely something parallel to TD's TDDUDT) before re-enabling this check.
    SELECT '4. Consistency', 'Loan Maturity Date Before Open Date [DISABLED - PENDING DD FIELD CONFIRMATION]', 'LSACMSP',
           0, 0
    FROM DUAL

    UNION ALL

    -- 4.9 | Active DD Account Without Exactly One IBAN
    SELECT '4. Consistency', 'Active DD Account Without Exactly One IBAN', 'DDACMSP/DDIBANP',
           COUNT(CASE WHEN iban_cnt != 1 THEN 1 END), COUNT(*)
    FROM (
        SELECT a.DFACB, a.DFACS, a.DFACX,
               COUNT(i.IBACB) AS iban_cnt
        FROM DATACUT3.HUB_MT_DDACMSP a
        LEFT JOIN DATACUT3.HUB_MT_DDIBANP i
               ON i.IBACB = a.DFACB AND i.IBACS = a.DFACS AND i.IBACX = a.DFACX
        WHERE a.DFSTUS = '1'
        GROUP BY a.DFACB, a.DFACS, a.DFACX
    ) iban_check

    UNION ALL

    -- 4.10 | CBAR Open Accounts Exceeding DD Account Master [OI-004 HIGH]
    SELECT '4. Consistency', 'CBAR Open Accounts Exceeding DD Account Master', 'SS@ACPP/DDACMSP',
           ABS(cbar_cnt - dd_cnt), cbar_cnt
    FROM (
        SELECT (SELECT COUNT(*) FROM DATACUT3."HUB_MT_SS@ACPP") AS cbar_cnt,
               (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDACMSP WHERE DFSTUS != '5') AS dd_cnt
        FROM DUAL
    ) cbar_chk

    UNION ALL

    -- 4.11 | Closed Account (SSCLACP) Still Active in DD Master
    -- SSCLACP account key: ZIACB, ZIACS, ZIACX — cast to CHAR for type safety
    SELECT '4. Consistency', 'Closed Account (SSCLACP) Still Active in DD Master', 'SSCLACP/DDACMSP',
           COUNT(CASE WHEN a.DFSTUS IS NOT NULL AND a.DFSTUS NOT IN ('4','5') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCLACP cl
    LEFT JOIN DATACUT3.HUB_MT_DDACMSP a
           ON TO_CHAR(a.DFACB) = TO_CHAR(cl.ZIACB)
          AND TO_CHAR(a.DFACS) = TO_CHAR(cl.ZIACS)
          AND TO_CHAR(a.DFACX) = TO_CHAR(cl.ZIACX)

    UNION ALL

    -- 4.12 | GL Account Count vs Sub-Ledger Count Mismatch [OI-003 HIGH]
    -- GLACMSP balance field: GERLBL (confirmed in DD v1.14)
    SELECT '4. Consistency', 'GL Account Count vs Sub-Ledger Count Mismatch', 'GLACMSP',
           ABS(gl_cnt - sub_cnt), sub_cnt
    FROM (
        SELECT (SELECT COUNT(*) FROM DATACUT3.HUB_MT_GLACMSP) AS gl_cnt,
               (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDACMSP WHERE DFSTUS != '5')
             + (SELECT COUNT(*) FROM DATACUT3.HUB_MT_LSACMSP WHERE POSTUS != '5')
             + (SELECT COUNT(*) FROM DATACUT3.HUB_MT_TDACMSP WHERE TDSTUS != '5')
             + (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DCACMSP) AS sub_cnt
        FROM DUAL
    ) gl_rec

    UNION ALL

    -- 4.13 | GL Balance Sum vs Sub-Ledger Balance Sum
    -- GL: GERLBL | DD: DFRLBL | Loans: POROPR | TD: TDRLBL
    SELECT '4. Consistency', 'GL Balance Sum Vs Sub-Ledger Balance Mismatch', 'GLACMSP/DDACMSP/LSACMSP/TDACMSP',
           ABS(gl_bal - sub_bal), gl_bal
    FROM (
        SELECT (SELECT NVL(SUM(GERLBL),0) FROM DATACUT3.HUB_MT_GLACMSP) AS gl_bal,
               (SELECT NVL(SUM(DFRLBL),0) FROM DATACUT3.HUB_MT_DDACMSP WHERE DFSTUS != '5')
             + (SELECT NVL(SUM(POROPR),0) FROM DATACUT3.HUB_MT_LSACMSP WHERE POSTUS != '5')
             + (SELECT NVL(SUM(TDRLBL),0) FROM DATACUT3.HUB_MT_TDACMSP WHERE TDSTUS != '5') AS sub_bal
        FROM DUAL
    ) bal_rec

    UNION ALL

    -- 4.14 | Active TD Maturity Date Before Start (Value) Date (TDDUDT < TDSTDT)
    SELECT '4. Consistency', 'Active TD Maturity Date Before Start (Value) Date', 'TDACMSP',
           COUNT(CASE WHEN TDDUDT IS NOT NULL AND TDSTDT IS NOT NULL AND TDDUDT < TDSTDT THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_TDACMSP
    WHERE TDSTUS = '1'

    UNION ALL

    -- 4.15 | Closed Account (SSCLACP) Still Active in Loan Master
    SELECT '4. Consistency', 'Closed Account (SSCLACP) Still Active in Loan Master', 'SSCLACP/LSACMSP',
           COUNT(CASE WHEN l.POACB IS NOT NULL AND l.POSTUS NOT IN ('4','5') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCLACP cl
    LEFT JOIN DATACUT3.HUB_MT_LSACMSP l
           ON TO_CHAR(l.POACB) = TO_CHAR(cl.ZIACB)
          AND TO_CHAR(l.POACS) = TO_CHAR(cl.ZIACS)
          AND TO_CHAR(l.POACX) = TO_CHAR(cl.ZIACX)

    UNION ALL

    -- 4.16 | Closed Account (SSCLACP) Still Active in TD Master
    SELECT '4. Consistency', 'Closed Account (SSCLACP) Still Active in TD Master', 'SSCLACP/TDACMSP',
           COUNT(CASE WHEN t.TDACB IS NOT NULL AND t.TDSTUS NOT IN ('4','5') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCLACP cl
    LEFT JOIN DATACUT3.HUB_MT_TDACMSP t
           ON TO_CHAR(t.TDACB) = TO_CHAR(cl.ZIACB)
          AND TO_CHAR(t.TDACS) = TO_CHAR(cl.ZIACS)
          AND TO_CHAR(t.TDACX) = TO_CHAR(cl.ZIACX)

    UNION ALL

    -- 4.17 | Customer Master Count vs Individual + Non-Individual [DC1: 16.10% HIGH]
    -- SSCUSTP vs SSINCIP + SSNICIP totals
    SELECT '4. Consistency', 'Customer Master Count vs Individual + Non-Individual', 'SSCUSTP/SSINCIP/SSNICIP',
           ABS(cust_cnt - (ind_cnt + nind_cnt)), cust_cnt
    FROM (
        SELECT (SELECT COUNT(*) FROM DATACUT3.HUB_MT_SSCUSTP) cust_cnt,
               (SELECT COUNT(*) FROM DATACUT3.HUB_MT_SSINCIP)  ind_cnt,
               (SELECT COUNT(*) FROM DATACUT3.HUB_MT_SSNICIP) nind_cnt
        FROM DUAL
    ) x

    UNION ALL

    -- 4.18 | DD Account Count vs IBAN Count (1:1) — DC2: DIFF=1
    SELECT '4. Consistency', 'DD Account Count vs IBAN Count (1:1 expected)', 'DDACMSP/DDIBANP',
           ABS(dd_cnt - iban_cnt), dd_cnt
    FROM (SELECT (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDACMSP) dd_cnt,
                 (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDIBANP) iban_cnt FROM DUAL) x

    UNION ALL

    -- 4.19 | DD Account Count vs Credit Interest Segment Count (1:1)
    SELECT '4. Consistency', 'DD Account Count vs Credit Interest Segment Count (1:1)', 'DDACMSP/DDCRINP',
           ABS(dd_cnt - crin_cnt), dd_cnt
    FROM (SELECT (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDACMSP) dd_cnt,
                 (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDCRINP) crin_cnt FROM DUAL) x

    UNION ALL

    -- 4.20 | DD Account Count vs Statement Segment Count (tolerance ±5)
    SELECT '4. Consistency', 'DD Account Count vs Statement Segment Count (threshold 5)', 'DDACMSP/DDSTMTP',
           CASE WHEN ABS(dd_cnt - stmt_cnt) > 5 THEN ABS(dd_cnt - stmt_cnt) ELSE 0 END, dd_cnt
    FROM (SELECT (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDACMSP) dd_cnt,
                 (SELECT COUNT(*) FROM DATACUT3.HUB_MT_DDSTMTP) stmt_cnt FROM DUAL) x

    UNION ALL

    -- 4.21 | Loan Core Accrual vs Local Accrual Distinct Accounts
    -- LSINACP: EQACB/EQACS/EQACX | LS@INACP: E1ACB/E1ACS/E1ACX (both confirmed in DD)
    SELECT '4. Consistency', 'Loan Core Accrual Distinct Accounts vs Local Accrual Distinct Accounts', 'LSINACP/LS@INACP',
           ABS(core_cnt - local_cnt), core_cnt
    FROM (
        SELECT (SELECT COUNT(DISTINCT TO_CHAR(EQACB)||'-'||TO_CHAR(EQACS)||'-'||TO_CHAR(EQACX))
                FROM DATACUT3.HUB_MT_LSINACP) core_cnt,
               (SELECT COUNT(DISTINCT TO_CHAR(E1ACB)||'-'||TO_CHAR(E1ACS)||'-'||TO_CHAR(E1ACX))
                FROM DATACUT3."HUB_MT_LS@INACP") local_cnt
        FROM DUAL
    ) x

-- =============================================================================
-- CAT-5: UNIQUENESS (8 checks)
-- =============================================================================

    UNION ALL

    -- 5.1 | Duplicate Customer Keys (ZGDCG + ZGDCB + ZGDCS)
    SELECT '5. Uniqueness', 'Duplicate Customer Keys', 'SSCUSTP',
           COUNT(*) - COUNT(DISTINCT ZGDCG||'|'||TO_CHAR(ZGDCB)||'|'||TO_CHAR(ZGDCS)), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCUSTP

    UNION ALL

    -- 5.2 | Duplicate DD Account Keys (DFACB + DFACS + DFACX)
    SELECT '5. Uniqueness', 'Duplicate Account Keys', 'DDACMSP',
           COUNT(*) - COUNT(DISTINCT TO_CHAR(DFACB)||'|'||TO_CHAR(DFACS)||'|'||TO_CHAR(DFACX)), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP

    UNION ALL

    -- 5.3 | Duplicate IBAN Numbers (IBIBAN)
    SELECT '5. Uniqueness', 'Duplicate IBAN Numbers', 'DDIBANP',
           COUNT(*) - COUNT(DISTINCT IBIBAN), COUNT(*)
    FROM DATACUT3.HUB_MT_DDIBANP

    UNION ALL

    -- 5.4 | Duplicate Loan Account Keys (POACB + POACS + POACX)
    SELECT '5. Uniqueness', 'Duplicate Loan Account Keys', 'LSACMSP',
           NVL(SUM(cnt-1),0), NVL(SUM(cnt),0)
    FROM (SELECT COUNT(*) AS cnt FROM DATACUT3.HUB_MT_LSACMSP
          GROUP BY POACB, POACS, POACX HAVING COUNT(*) > 1)

    UNION ALL

    -- 5.5 | Duplicate Term Deposit Account Keys (TDACB + TDACS + TDACX)
    SELECT '5. Uniqueness', 'Duplicate Term Deposit Account Keys', 'TDACMSP',
           COUNT(*) - COUNT(DISTINCT TO_CHAR(TDACB)||'|'||TO_CHAR(TDACS)||'|'||TO_CHAR(TDACX)), COUNT(*)
    FROM DATACUT3.HUB_MT_TDACMSP

    UNION ALL

    -- 5.6 | Duplicate Customer Address Records (SSADDRP)
    -- FIX-03: SSADDRP has no ZBDCG. Unique key = ZBDCB + ZBDCS + ZBADID
    SELECT '5. Uniqueness', 'Duplicate Customer Address Records', 'SSADDRP',
           COUNT(*) - COUNT(DISTINCT TO_CHAR(ZBDCB)||'|'||TO_CHAR(ZBDCS)||'|'||ZBADID), COUNT(*)
    FROM DATACUT3.HUB_MT_SSADDRP

    UNION ALL

    -- 5.7 | Duplicate Security Held Records (SSSECHP)
    -- Unique key: Y2DCG + Y2DCB + Y2DCS + Y2LGI + Y2SCSR
    SELECT '5. Uniqueness', 'Duplicate Security Held Records', 'SSSECHP',
           COUNT(*) - COUNT(DISTINCT Y2DCG||'|'||TO_CHAR(Y2DCB)||'|'||TO_CHAR(Y2DCS)
                            ||'|'||Y2LGI||'|'||TO_CHAR(Y2SCSR)), COUNT(*)
    FROM DATACUT3.HUB_MT_SSSECHP

    UNION ALL

    -- 5.8 | Duplicate GL Account Records (GLACMSP)
    -- Unique key: GEACB + GEACS + GEACX
    SELECT '5. Uniqueness', 'Duplicate GL Account Records', 'GLACMSP',
           COUNT(*) - COUNT(DISTINCT TO_CHAR(GEACB)||'|'||TO_CHAR(GEACS)||'|'||TO_CHAR(GEACX)), COUNT(*)
    FROM DATACUT3.HUB_MT_GLACMSP

-- =============================================================================
-- CAT-6: TIMELINESS (6 checks)
-- =============================================================================

    UNION ALL

    -- 6.1 | Customer Not Updated > 2 Years (ZGDLUP) [OI-007 HIGH — DC1: 51.39%]
    SELECT '6. Timeliness', 'Customer Not Updated > 2 Years', 'SSCUSTP',
           COUNT(CASE WHEN ZGDLUP < ADD_MONTHS(DATE '2026-06-15',-24) THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCUSTP
    WHERE ZGDROP != 'Y' AND ZGDLUP IS NOT NULL

    UNION ALL

    -- 6.2 | Active DD Account No Transaction > 1 Year (DFDLTN)
    SELECT '6. Timeliness', 'Active DD Account No Transaction > 1 Year', 'DDACMSP',
           COUNT(CASE WHEN DFDLTN < ADD_MONTHS(DATE '2026-06-15',-12) THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP
    WHERE DFSTUS = '1' AND DFDLTN IS NOT NULL

    UNION ALL

    -- 6.3 | Expired Blacklist Records Still Present (V7BLEX < today)
    SELECT '6. Timeliness', 'Expired Blacklist Records Still Present', 'SSBKLSP',
           COUNT(CASE WHEN V7BLEX < DATE '2026-06-15' AND V7BLEX IS NOT NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSBKLSP

    UNION ALL

    -- 6.4 | Matured TD Still with Active Status (TDDUDT < today, TDSTUS='1') [DC1: 22.71% HIGH]
    SELECT '6. Timeliness', 'Matured TD Still with Active Status', 'TDACMSP',
           COUNT(CASE WHEN TDDUDT < DATE '2026-06-15' AND TDDUDT IS NOT NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_TDACMSP
    WHERE TDSTUS = '1'

    UNION ALL

    -- 6.5 | Credit Limit Overdue for Review (ZFFRDT < today)
    -- SSCLMTP filter: ZFDROP confirmed in DD v1.14
    SELECT '6. Timeliness', 'Credit Limit Overdue for Review', 'SSCLMTP',
           COUNT(CASE WHEN ZFFRDT < DATE '2026-06-15' AND ZFFRDT IS NOT NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCLMTP
    WHERE ZFDROP != 'Y'

    UNION ALL

    -- 6.6 | Term Deposit Open Date > 10 Years Still Active [DC1: 58.57% HIGH]
    SELECT '6. Timeliness', 'Term Deposit Open Date Older Than 10 Years Still Active', 'TDACMSP',
           COUNT(CASE WHEN TDDTAO IS NOT NULL
                       AND TDDTAO < ADD_MONTHS(DATE '2026-06-15',-120) THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_TDACMSP
    WHERE TDSTUS = '1'

-- =============================================================================
-- CAT-7: REGULATORY (7 checks)
-- =============================================================================

    UNION ALL

    -- 7.1 | Invalid FATCA (US Person) Indicator (ZKUSPI must be Y, N, or blank)
    -- ZKUSPI confirmed in DD v1.14 for SSINCIP
    SELECT '7. Regulatory', 'Invalid FATCA (US Person) Indicator Value', 'SSINCIP',
           COUNT(CASE WHEN ZKUSPI IS NOT NULL AND TRIM(ZKUSPI) NOT IN ('Y','N',' ','') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSINCIP

    UNION ALL

    -- 7.2 | Missing GHO Customer Classification for Active Customer (ZGGHCL)
    SELECT '7. Regulatory', 'Missing GHO Customer Classification for Active Customer', 'SSCUSTP',
           COUNT(CASE WHEN ZGGHCL IS NULL OR TRIM(ZGGHCL) IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCUSTP
    WHERE ZGDROP != 'Y'

    UNION ALL

    -- 7.3 | Invalid Blacklist Indicator Value (CMBKLI must be Y or N)
    SELECT '7. Regulatory', 'Invalid Blacklist Indicator Value (not Y/N)', 'SSCDDMP',
           COUNT(CASE WHEN CMBKLI IS NOT NULL AND TRIM(CMBKLI) NOT IN ('Y','N') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCDDMP

    UNION ALL

    -- 7.4 | Missing CDD Risk Rating for Active Customer (CMRSKC)
    -- SSCDDMP has no MDFL — join on CMDCG/CMDCB/CMDCS
    SELECT '7. Regulatory', 'Missing CDD Risk Rating for Active Customer', 'SSCDDMP',
           COUNT(CASE WHEN CMRSKC IS NULL OR TRIM(CMRSKC) IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCDDMP d
    JOIN DATACUT3.HUB_MT_SSCUSTP c
      ON c.ZGDCG = d.CMDCG AND c.ZGDCB = d.CMDCB AND c.ZGDCS = d.CMDCS
    WHERE c.ZGDROP != 'Y'

    UNION ALL

    -- 7.5 | Missing KYC Standard Code (CMKYCS) [OI-006 HIGH — DC1: 54.76%]
    SELECT '7. Regulatory', 'Missing KYC Standard Code', 'SSCDDMP',
           COUNT(CASE WHEN CMKYCS IS NULL OR TRIM(CMKYCS) IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCDDMP

    UNION ALL

    -- 7.6 | Missing or Invalid Client Indicator (ZGRCBI must be R/C/B) for Active Customers
    SELECT '7. Regulatory', 'Missing or Invalid Client Indicator (R/C/B) for Active Customer', 'SSCUSTP',
           COUNT(CASE WHEN ZGRCBI IS NULL OR TRIM(ZGRCBI) NOT IN ('R','C','B') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSCUSTP
    WHERE ZGDROP != 'Y'

    UNION ALL

    -- 7.7 | IBAN Check Digits (Positions 3-4) Not Numeric
    -- Malta IBAN: MT + 2 numeric check digits + 27 alphanumeric = 31 chars
    SELECT '7. Regulatory', 'IBAN Check Digits (Positions 3-4) Not Numeric', 'DDIBANP',
           COUNT(CASE WHEN NOT REGEXP_LIKE(SUBSTR(TRIM(IBIBAN),3,2),'^[0-9]{2}$') THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDIBANP
    WHERE IBIBAN IS NOT NULL AND TRIM(IBIBAN) IS NOT NULL

-- =============================================================================
-- CAT-8: BUSINESS RULES (3 checks)
-- =============================================================================

    UNION ALL

    -- 8.1 | Active DD Account Missing Short Name (DFACSN) — active = DFSTUS='1'
    SELECT '8. Business Rules', 'Active DD Account Missing Short Name (DFACSN)', 'DDACMSP',
           COUNT(CASE WHEN DFACSN IS NULL OR TRIM(DFACSN) IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_DDACMSP
    WHERE DFSTUS = '1'

    UNION ALL

    -- 8.2 | Active Loan Interest Rate Out of Range 0-50% (POTINR)
    -- POTINR stored as integer basis points * 100 (e.g. 5.00% = 500)
    SELECT '8. Business Rules', 'Active Loan Interest Rate Out of Range (0-50%)', 'LSACMSP',
           COUNT(CASE WHEN POTINR < 0 OR POTINR > 5000 THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSACMSP
    WHERE POSTUS = '1' AND POTINR IS NOT NULL

    UNION ALL

    -- 8.3 | Repayment Schedule Next Instalment Date in the Past (RNNISD) [OI-008 HIGH — DC1: 48.14%]
    -- LSRPSLP key: RNACB/RNACS/RNACX → LSACMSP POACB/POACS/POACX
    SELECT '8. Business Rules', 'Repayment Schedule Next Instalment Date in the Past', 'LSRPSLP',
           COUNT(CASE WHEN RNNISD < DATE '2026-06-15' THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSRPSLP rs
    JOIN DATACUT3.HUB_MT_LSACMSP l
      ON l.POACB = rs.RNACB AND l.POACS = rs.RNACS AND l.POACX = rs.RNACX
    WHERE l.POSTUS = '1' AND rs.RNNISD IS NOT NULL

-- =============================================================================
-- CAT-9: DC2 NEW TABLES (13 checks — DD-verified fields)
-- =============================================================================

    UNION ALL

    -- 9.1 | LSOIACP Row Count vs DC2 Expected (1,224,997)
    -- FIX-06: LSOIACP fields NOW confirmed in DD v1.14 (EI prefix)
    -- EIMDFL = mode flag | EIACB/EIACS/EIACX = loan account key
    SELECT '9. DC2 New Tables', 'DC2 New Table Row Count — LSOIACP (EI prefix)', 'LSOIACP',
           ABS(COUNT(*) - 1224997), COUNT(*)
    FROM DATACUT3.HUB_MT_LSOIACP

    UNION ALL

    -- 9.2 | LSOIACP Shadow Record Ratio (EIMDFL)
    SELECT '9. DC2 New Tables', 'LSOIACP Shadow Record Ratio (EIMDFL)', 'LSOIACP',
           COUNT(CASE WHEN EIMDFL NOT IN ('P','S','') OR EIMDFL IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSOIACP

    UNION ALL

    -- 9.3 | LSOIACP Orphan: No Matching Loan Account in LSACMSP
    -- LSOIACP loan key: EIACB/EIACS/EIACX → LSACMSP POACB/POACS/POACX
    SELECT '9. DC2 New Tables', 'LSOIACP Without Matching Loan Account (Orphan)', 'LSOIACP/LSACMSP',
           COUNT(CASE WHEN ls.POACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSOIACP oi
    LEFT JOIN DATACUT3.HUB_MT_LSACMSP ls
           ON ls.POACB = oi.EIACB AND ls.POACS = oi.EIACS AND ls.POACX = oi.EIACX
    WHERE oi.EIMDFL <> 'S'

    UNION ALL

    -- 9.4 | SSIFPWP Row Count vs DC2 Expected (134,399)
    -- FIX-07: SSIFPWP fields confirmed in DD v1.14 (WE prefix)
    SELECT '9. DC2 New Tables', 'DC2 New Table Row Count — SSIFPWP (WE prefix)', 'SSIFPWP',
           ABS(COUNT(*) - 134399), COUNT(*)
    FROM DATACUT3.HUB_MT_SSIFPWP

    UNION ALL

    -- 9.5 | SSIFPWP Orphan: No Matching DD Account
    -- SSIFPWP account key: WEACB/WEACS/WEACX → DDACMSP DFACB/DFACS/DFACX
    SELECT '9. DC2 New Tables', 'SSIFPWP Without Matching DD Account (Orphan)', 'SSIFPWP/DDACMSP',
           COUNT(CASE WHEN a.DFACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSIFPWP pw
    LEFT JOIN DATACUT3.HUB_MT_DDACMSP a
           ON a.DFACB = pw.WEACB AND a.DFACS = pw.WEACS AND a.DFACX = pw.WEACX

    UNION ALL

    -- 9.6 | SSIFPWP Missing Currency (WECYCD)
    SELECT '9. DC2 New Tables', 'SSIFPWP Missing Currency (WECYCD)', 'SSIFPWP',
           COUNT(CASE WHEN WECYCD IS NULL OR TRIM(WECYCD) = '' THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSIFPWP

    UNION ALL

    -- 9.7 | SSRCUSP Row Count vs DC2 Expected (1,439)
    -- FIX-08: SSRCUSP fields confirmed in DD v1.14 (JP prefix)
    SELECT '9. DC2 New Tables', 'DC2 New Table Row Count — SSRCUSP (JP prefix)', 'SSRCUSP',
           ABS(COUNT(*) - 1439), COUNT(*)
    FROM DATACUT3.HUB_MT_SSRCUSP

    UNION ALL

    -- 9.8 | SSRCUSP Customer Not in HUB Customer Master
    -- SSRCUSP customer key: JPDCB/JPDCS (and JPDCG for group member)
    SELECT '9. DC2 New Tables', 'SSRCUSP Customer Not in HUB Customer Master', 'SSRCUSP/SSCUSTP',
           COUNT(CASE WHEN c.ZGDCB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_SSRCUSP r
    LEFT JOIN DATACUT3.HUB_MT_SSCUSTP c
           ON c.ZGDCB = r.JPDCB AND c.ZGDCS = r.JPDCS

    UNION ALL

    -- 9.9 | LSRPACP Row Count vs DC2 Expected (31,270)
    -- LSRPACP PQ-prefix fields confirmed in DD v1.14
    SELECT '9. DC2 New Tables', 'Local Repayment Account Row Count — LSRPACP', 'LSRPACP',
           ABS(COUNT(*) - 31270), COUNT(*)
    FROM DATACUT3.HUB_MT_LSRPACP

    UNION ALL

    -- 9.10 | LSRPACP Shadow Record Ratio (PQMDFL)
    SELECT '9. DC2 New Tables', 'LSRPACP Invalid Mode Flag (PQMDFL)', 'LSRPACP',
           COUNT(CASE WHEN PQMDFL NOT IN ('P','S','') OR PQMDFL IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSRPACP

    UNION ALL

    -- 9.11 | LSRPACP Missing Account Branch (PK component PQACB)
    SELECT '9. DC2 New Tables', 'LSRPACP Missing Account Branch (PK: PQACB)', 'LSRPACP',
           COUNT(CASE WHEN PQACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSRPACP
    WHERE PQMDFL <> 'S'

    UNION ALL

    -- 9.12 | LSRPACP Orphan: No Matching Loan Account in LSACMSP
    -- LSRPACP → LSACMSP via PQACB/PQACS/PQACX → POACB/POACS/POACX
    SELECT '9. DC2 New Tables', 'LSRPACP Without Matching Loan Account (Orphan)', 'LSRPACP/LSACMSP',
           COUNT(CASE WHEN ls.POACB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSRPACP rp
    LEFT JOIN DATACUT3.HUB_MT_LSACMSP ls
           ON ls.POACB = rp.PQACB AND ls.POACS = rp.PQACS AND ls.POACX = rp.PQACX
    WHERE rp.PQMDFL <> 'S'

    UNION ALL

    -- 9.13 | LSRPACP Missing Repayment Transfer Account Branch (PQPTAB)
    -- FIX-05: PQPMRT (Repayment %) is NOT in DD v1.14 for LSRPACP — removed.
    -- PQPIRT (Priority) IS in DD v1.14.
    SELECT '9. DC2 New Tables', 'LSRPACP Missing Repayment Transfer Account Branch (PQPTAB)', 'LSRPACP',
           COUNT(CASE WHEN PQPTAB IS NULL THEN 1 END), COUNT(*)
    FROM DATACUT3.HUB_MT_LSRPACP
    WHERE PQMDFL <> 'S'

    ) dq_results
) y
ORDER BY y.dq_category, y.failure_pct DESC NULLS LAST;
