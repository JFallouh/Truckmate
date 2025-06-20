WITH X_HEADER AS (
  SELECT
    VARCHAR_FORMAT(CURRENT DATE, 'YYMMDD')                                                       AS CNTBTCH,
    ROW_NUMBER() OVER (
      PARTITION BY VARCHAR_FORMAT(CURRENT DATE, 'YYMMDD')
      ORDER BY
        VARCHAR_FORMAT(CURRENT DATE, 'YYMMDD'),
        V.USER3,
        COALESCE(T.BILL_NUMBER, T2.BILL_NUMBER)
    )                                                                                             AS CNTITEM,
    V.USER3                                                                                       AS IDVEND,         -- vendor code
    '1'                                                                                           AS TEXTTRX,
    COALESCE(T.BILL_NUMBER, T2.BILL_NUMBER)                                                       AS IDINVC,
    V.NAME                                                                                        AS DESCRIPTION,    -- vendor name
    VARCHAR_FORMAT(OI.SRC_APPROVAL_DATE, 'YYYY-MM-DD')                                            AS DATEINVC,
    OI.PROBILL                                                                                    AS ORDRNBR,
    '1'                                                                                           AS SWTAXBL,
    '0'                                                                                           AS SWCALCTX,
    '0'                                                                                           AS AMTTAX1,
    '0'                                                                                           AS AMTTAX2,
    SUM(
      CASE 
        WHEN IP.ACCT_CODE = '01-4000-00'
          THEN CASE 
                 WHEN IP.DEBIT_AMT  > IP.CREDIT_AMT 
                   THEN IP.DEBIT_AMT  - IP.CREDIT_AMT 
                 ELSE IP.CREDIT_AMT - IP.DEBIT_AMT 
               END
        ELSE 0
      END
    )                                                                                             AS AMTGROSTOT,
    '1'                                                                                           AS SWMANTX,
    OI.ORDER_INTERLINER_ID                                                                        AS IDKEY
  FROM ORDER_INTERLINER OI
  JOIN ORDER_INTERLINER_USERFIELDS OIU
    ON OIU.ORDER_INTERLINER_ID = OI.ORDER_INTERLINER_ID

  -- bring in vendor for IDVEND + DESCRIPTION
  LEFT JOIN VENDOR V
    ON V.VENDOR_ID = OI.INTERLINER_ID

  LEFT JOIN IP_GL IP
    ON IP.ORDER_INTERLINER_ID = OI.ORDER_INTERLINER_ID
   AND IP.SOURCE_TYPE       = 'IP Source Register'

  LEFT JOIN TLORDER T
    ON (OI.CHILD_DETAIL_LINE_ID = 0 OR OI.CHILD_TYPE = 'S')
   AND T.DETAIL_LINE_ID       = OI.DETAIL_LINE_ID

  LEFT JOIN TLORDER T2
    ON (OI.CHILD_DETAIL_LINE_ID > 0 AND OI.CHILD_TYPE <> 'S')
   AND T2.DETAIL_LINE_ID      = OI.CHILD_DETAIL_LINE_ID

  WHERE
    OI.INTERFACE_STATUS = 'S'

  GROUP BY
    VARCHAR_FORMAT(CURRENT DATE, 'YYMMDD'),
    V.USER3,
    V.NAME,
    COALESCE(T.BILL_NUMBER, T2.BILL_NUMBER),
    VARCHAR_FORMAT(OI.SRC_APPROVAL_DATE, 'YYYY-MM-DD'),
    OI.PROBILL,
    OI.ORDER_INTERLINER_ID

  HAVING
    SUM(
      CASE 
        WHEN IP.ACCT_CODE = '01-4000-00'
          THEN CASE 
                 WHEN IP.DEBIT_AMT  > IP.CREDIT_AMT 
                   THEN IP.DEBIT_AMT  - IP.CREDIT_AMT 
                 ELSE IP.CREDIT_AMT - IP.DEBIT_AMT 
               END
        ELSE 0
      END
    ) <> 0
)
SELECT
  CNTBTCH,
  CNTITEM,
  IDVEND,
  TEXTTRX,
  IDINVC,
  DESCRIPTION,
  DATEINVC,
  ORDRNBR,
  SWTAXBL,
  SWCALCTX,
  AMTTAX1,
  AMTTAX2,
  AMTGROSTOT,
  SWMANTX
FROM X_HEADER
ORDER BY CNTBTCH, CNTITEM;
