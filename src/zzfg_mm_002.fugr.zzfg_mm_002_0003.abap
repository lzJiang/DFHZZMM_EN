FUNCTION zzfg_mm_002_0003.
*"----------------------------------------------------------------------
*"*"本地接口：
*"  IMPORTING
*"     REFERENCE(I_REQ) TYPE  ZZS_MMI002_REQ OPTIONAL
*"  EXPORTING
*"     REFERENCE(O_RESP) TYPE  ZZS_REST_OUT
*"----------------------------------------------------------------------
  .
  DATA: ls_req         TYPE zzs_mmi002_head_in,
        lo_util        TYPE REF TO zcl_mmi002_util,
        lv_sales_order TYPE vbeln.
  CLEAR:gv_flag,gv_msg.
  ls_req = i_req-req.

*1.检查数据
  CREATE OBJECT lo_util.
  lo_util->check_0002( EXPORTING ls_req = ls_req
                       IMPORTING flag = gv_flag
                                 msg  = gv_msg ).
  IF gv_flag = 'E'.
    o_resp-msgty = 'E'.
    o_resp-msgtx = gv_msg .
    RETURN.
  ENDIF.
*2.处理数据
  lo_util->deal_0002( IMPORTING flag = gv_flag
                                 msg  = gv_msg
                       CHANGING ls_req = ls_req ).
  IF gv_flag = 'S'.
    o_resp-msgty = 'S'.
    o_resp-msgtx = '处理成功' .
    o_resp-sapnum = gv_msg .

    COMMIT WORK.
  ELSE.
    o_resp-msgty = 'E'.
    o_resp-msgtx = gv_msg .
  ENDIF.


ENDFUNCTION.
