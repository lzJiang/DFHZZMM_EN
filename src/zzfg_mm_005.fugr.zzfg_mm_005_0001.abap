FUNCTION zzfg_mm_005_0001.
*"----------------------------------------------------------------------
*"*"本地接口：
*"  IMPORTING
*"     REFERENCE(I_REQ) TYPE  ZZS_MMI005_REQ OPTIONAL
*"  EXPORTING
*"     REFERENCE(O_RESP) TYPE  ZZS_MMI005_RES
*"----------------------------------------------------------------------
  .
  DATA: ls_req   TYPE zzs_mmi005_in,
        lv_tabix TYPE i,
        lv_div   TYPE i,
        lv_mod   TYPE i,
        lv_where TYPE string.

  ls_req = i_req-req.
  lv_where = | product ne '' and Language = '1'|.

*1.检查数据
  IF ls_req-currpage <= 0.
    o_resp-msgty = 'E'.
    o_resp-msgtx = |【当前页】字段需大于0| .
    RETURN.
  ENDIF.
  IF ls_req-pagesize <= 0.
    o_resp-msgty = 'E'.
    o_resp-msgtx = |【每页条数】字段需大于0| .
    RETURN.
  ENDIF.

  IF ls_req-product IS NOT INITIAL.
    lv_where = | { lv_where } and ( product like '%{ ls_req-product }%' or productname like '%{ ls_req-product }%' )|.
  ENDIF.

  SELECT product,
         productname
    FROM i_producttext WITH PRIVILEGED ACCESS
    WHERE (lv_where)
    INTO CORRESPONDING FIELDS OF TABLE @o_resp-res.

  SORT o_resp-res BY product.
  IF o_resp-res[] IS NOT INITIAL.
    DATA(lv_totalsize) = lines( o_resp-res ).
    DATA(lv_totalpage) = lv_totalsize DIV ls_req-pagesize.
    lv_mod = lv_totalsize MOD ls_req-pagesize.
    IF lv_mod NE 0.
      lv_totalpage = lv_totalpage + 1.
    ENDIF.
    IF ls_req-currpage > lv_totalpage.
      o_resp-msgty = 'E'.
      o_resp-msgtx = |查询当前页{ ls_req-currpage }超过总页数{ lv_totalpage }| .
      CLEAR:o_resp-res[].
      RETURN.
    ENDIF.
    LOOP AT o_resp-res ASSIGNING FIELD-SYMBOL(<fs_res>).
      lv_tabix = sy-tabix.
      lv_div = lv_tabix DIV ls_req-pagesize.
      <fs_res>-currpage = lv_div + 1.
      <fs_res>-pagesize = ls_req-pagesize.
      <fs_res>-totalsize = lv_totalsize.
      <fs_res>-totalpage = lv_totalpage.
      <fs_res>-product = |{ <fs_res>-product ALPHA = OUT }|.
      CONDENSE <fs_res>-product NO-GAPS.
    ENDLOOP.
    DELETE o_resp-res WHERE currpage NE ls_req-currpage.
    IF o_resp-res[] IS NOT INITIAL.
      o_resp-msgty = 'S'.
    ELSE.
      o_resp-msgty = 'E'.
      o_resp-msgtx = '未查询到有效数据' .
    ENDIF.
  ELSE.
    o_resp-msgty = 'E'.
    o_resp-msgtx = '未查询到有效数据' .
  ENDIF.

ENDFUNCTION.
