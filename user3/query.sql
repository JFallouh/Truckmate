/* -----------------------------------------------------------
   Adds vendor ID (V.VENDOR_ID) alongside USER3-based IDVEND
   ----------------------------------------------------------- */
WITH X_HEADER AS (
  SELECT
    VARCHAR_FORMAT(CURRENT DATE, 'YYMMDD')                                     AS CNTBTCH,

    ROW_NUMBER() OVER (
      PARTITION BY VARCHAR_FORMAT(CURRENT DATE, 'YYMMDD')
      ORDER BY
        VARCHAR_FORMAT(CURRENT DATE, 'YYMMDD'),
        V.USER3,
        V.VENDOR_ID,
        COALESCE(T.BILL_NUMBER, T2.BILL_NUMBER)
    )                                                                           AS CNTITEM,

    V.USER3                                                                     AS IDVEND,     -- “alternate” vendor code
    V.VENDOR_ID                                                                 AS VENDID,     -- numeric vendor ID  ← NEW
    '1'                                                                         AS TEXTTRX,
    COALESCE(T.BILL_NUMBER, T2.BILL_NUMBER)                                     AS IDINVC,
    V.NAME                                                                      AS DESCRIPTION,
    VARCHAR_FORMAT(OI.SRC_APPROVAL_DATE, 'YYYY-MM-DD')                          AS DATEINVC,
    OI.PROBILL                                                                  AS ORDRNBR,
    '1'                                                                         AS SWTAXBL,
    '0'                                                                         AS SWCALCTX,
    '0'                                                                         AS AMTTAX1,
    '0'                                                                         AS AMTTAX2,

    /* only 01-4000-00 hits gross total */
    SUM(
      CASE
        WHEN IP.ACCT_CODE = '01-4000-00'
          THEN IP.DEBIT_AMT - IP.CREDIT_AMT
        ELSE 0
      END
    )                                                                           AS AMTGROSTOT,

    '1'                                                                         AS SWMANTX,
    OI.ORDER_INTERLINER_ID                                                      AS IDKEY
  FROM ORDER_INTERLINER                   OI
  JOIN ORDER_INTERLINER_USERFIELDS        OIU ON OIU.ORDER_INTERLINER_ID = OI.ORDER_INTERLINER_ID

  /* vendor lookup */
  LEFT JOIN VENDOR                        V   ON V.VENDOR_ID = OI.INTERLINER_ID

  /* GL details (accrual register stage only) */
  LEFT JOIN IP_GL                         IP  ON IP.ORDER_INTERLINER_ID = OI.ORDER_INTERLINER_ID
                                             AND IP.SOURCE_TYPE       = 'IP Source Register'

  /* single-segment legs */
  LEFT JOIN TLORDER                       T   ON (OI.CHILD_DETAIL_LINE_ID = 0 OR OI.CHILD_TYPE = 'S')
                                             AND T.DETAIL_LINE_ID       = OI.DETAIL_LINE_ID

  /* multi-segment legs */
  LEFT JOIN TLORDER                       T2  ON (OI.CHILD_DETAIL_LINE_ID > 0 AND OI.CHILD_TYPE <> 'S')
                                             AND T2.DETAIL_LINE_ID      = OI.CHILD_DETAIL_LINE_ID

  WHERE OI.INTERFACE_STATUS = 'S'                                       -- “approved” interliners

  GROUP BY
    VARCHAR_FORMAT(CURRENT DATE, 'YYMMDD'),
    V.USER3,
    V.VENDOR_ID,
    V.NAME,
    COALESCE(T.BILL_NUMBER, T2.BILL_NUMBER),
    VARCHAR_FORMAT(OI.SRC_APPROVAL_DATE, 'YYYY-MM-DD'),
    OI.PROBILL,
    OI.ORDER_INTERLINER_ID

  HAVING
    SUM(
      CASE
        WHEN IP.ACCT_CODE = '01-4000-00'
          THEN IP.DEBIT_AMT - IP.CREDIT_AMT
        ELSE 0
      END
    ) <> 0
)

/* ---------- final extract ---------- */
SELECT
  CNTBTCH,
  CNTITEM,
  IDVEND,       -- USER3
  VENDID,       -- VENDOR_ID (new column in output)
  TEXTTRX,
  IDINVC,
  DESCRIPTION,  -- vendor name
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
