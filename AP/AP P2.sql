WITH X_HEADER AS (
  /* same CTE as above */
  SELECT
    OI.SRC_SOURCE_AUDIT                                             AS CNTBTCH,
    ROW_NUMBER() OVER (
      PARTITION BY OI.SRC_SOURCE_AUDIT
      ORDER BY
        OI.SRC_SOURCE_AUDIT,
        OIU.USER3,
        COALESCE(T.BILL_NUMBER, T2.BILL_NUMBER)
    )                                                               AS CNTITEM,
    OIU.USER3                                                        AS IDCUST,
    '1'                                                              AS TEXTTRX,
    COALESCE(T.BILL_NUMBER, T2.BILL_NUMBER)                          AS IDINVC,
    VARCHAR_FORMAT(
      COALESCE(T.BILL_DATE, T2.BILL_DATE),
      'YYYY-MM-DD'
    )                                                               AS DATEINVC,
    OI.PROBILL                                                       AS ORDRNBR,
    '1'                                                              AS SWTAXBL,
    '0'                                                              AS SWCALCTX,
    '0'                                                              AS AMTTAX1,
    '0'                                                              AS AMTTAX2,
    SUM(IP.DEBIT_AMT) - SUM(IP.CREDIT_AMT)                            AS AMTGROSTOT,
    '1'                                                              AS SWMANTX,
    OI.ORDER_INTERLINER_ID                                           AS IDKEY
  FROM ORDER_INTERLINER OI
  JOIN ORDER_INTERLINER_USERFIELDS OIU
    ON OIU.ORDER_INTERLINER_ID = OI.ORDER_INTERLINER_ID
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
  --  AND COALESCE(T.BILL_DATE, T2.BILL_DATE)
       -- BETWEEN DATE('2025-06-20') AND DATE('2025-06-20')
  GROUP BY
    OI.SRC_SOURCE_AUDIT,
    OIU.USER3,
    COALESCE(T.BILL_NUMBER, T2.BILL_NUMBER),
    VARCHAR_FORMAT(COALESCE(T.BILL_DATE, T2.BILL_DATE), 'YYYY-MM-DD'),
    OI.PROBILL,
    OI.ORDER_INTERLINER_ID
)
SELECT
  H.CNTBTCH,
  H.CNTITEM,
  CASE 
    WHEN IP.ACCT_CODE LIKE '%-2200-%' 
      THEN '40' 
    ELSE '20' 
  END                                                               AS CNTLINE,
  '0'                                                                 AS AMTTAX1,
  '0'                                                                 AS AMTTAX2,
  IP.ACCT_CODE                                                       AS IDGLACCT,
  CASE 
    WHEN IP.DEBIT_AMT > IP.CREDIT_AMT 
      THEN IP.DEBIT_AMT - IP.CREDIT_AMT 
    ELSE IP.CREDIT_AMT - IP.DEBIT_AMT 
  END                                                               AS AMTDIST
FROM X_HEADER H
JOIN IP_GL IP
  ON IP.ORDER_INTERLINER_ID = H.IDKEY
 AND IP.SOURCE_TYPE         = 'IP Source Register'
ORDER BY
  H.CNTBTCH,
  H.CNTITEM,
  CNTLINE,
  IDGLACCT;
