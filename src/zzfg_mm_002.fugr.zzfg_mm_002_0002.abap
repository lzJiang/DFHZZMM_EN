FUNCTION zzfg_mm_002_0002.
*"----------------------------------------------------------------------
*"*"本地接口：
*"  IMPORTING
*"     REFERENCE(I_REQ) TYPE  ZZS_MMI002_0002_REQ OPTIONAL
*"  EXPORTING
*"     REFERENCE(O_RESP) TYPE  ZZS_MMI002_0002_RES
*"----------------------------------------------------------------------
  " You can use the template 'functionModuleParameter' to add here the signature!
  .
  DATA:ls_req             TYPE zzs_mmi002_0002_in,
       ls_businesspartner TYPE i_businesspartner.
  ls_req = i_req-req.
  ls_businesspartner-businesspartner =  ls_req-businesspartner.
  ls_businesspartner-businesspartner = |{ ls_businesspartner-businesspartner ALPHA = IN }|.

  SELECT SINGLE a~businesspartner,
                a~organizationbpname1,
                b~bptaxlongnumber
           FROM i_businesspartner WITH PRIVILEGED ACCESS AS a
           INNER JOIN i_businesspartnertaxnumber WITH PRIVILEGED ACCESS AS b
             ON a~businesspartner = b~businesspartner AND b~bptaxlongnumber IS NOT INITIAL
          WHERE a~businesspartner = @ls_businesspartner-businesspartner
            OR a~organizationbpname1 = @ls_req-organizationbpname1
            OR b~bptaxlongnumber = @ls_req-bptaxlongnumber
           INTO @DATA(ls_data).
  IF sy-subrc = 0.
    o_resp-msgty = 'E'.
    o_resp-msgtx = '已存在对应供应商'.
    o_resp-businesspartner = |{ ls_data-businesspartner ALPHA = OUT }|.
    o_resp-organizationbpname1 = ls_data-organizationbpname1.
    o_resp-bptaxlongnumber = ls_data-bptaxlongnumber.
  ELSE.
    o_resp-msgty = 'S'.
  ENDIF.

ENDFUNCTION.
