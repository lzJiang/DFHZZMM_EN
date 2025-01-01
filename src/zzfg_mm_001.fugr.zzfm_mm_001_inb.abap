FUNCTION zzfm_mm_001_inb.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_DATA) TYPE  ZZS_MMI001_ITEM_IN OPTIONAL
*"  EXPORTING
*"     REFERENCE(O_RESP) TYPE  ZZS_REST_OUT
*"----------------------------------------------------------------------
  .

  TYPES:BEGIN OF ty_deliveryitem,
          batch                   TYPE string, "批次
          shelflifeexpirationdate TYPE string, "过期日期
        END OF ty_deliveryitem,
        BEGIN OF ty_deliveryitems,
          d TYPE ty_deliveryitem,
        END OF ty_deliveryitems.

  DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.
  DATA:lv_json TYPE string.
  DATA:ls_item TYPE ty_deliveryitems.
  DATA:ls_data TYPE zzs_mmi001_item_in.
  DATA:lv_deliverydocument     TYPE i_deliverydocumentitem-deliverydocument,
       lv_deliverydocumentitem TYPE i_deliverydocumentitem-deliverydocumentitem.

  ls_data = i_data.
*&---=============================使用API 步骤01
*&---=========1.API 类使用变量
*&---定义场景使用变量
  DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

*&---导入结构JSON MAPPING
  lt_mapping = VALUE #(
       ( abap = 'd'                           json = 'd'                          )
       ( abap = 'Batch'                       json = 'Batch'                      )
       ( abap = 'ShelfLifeExpirationDate'     json = 'ShelfLifeExpirationDate'    )
       ).

  lv_deliverydocument = ls_data-delivery.
  lv_deliverydocumentitem = ls_data-deliveryitem.

  ls_item-d-batch = ls_data-batch.
  ls_item-d-shelflifeexpirationdate = zzcl_comm_tool=>date2iso( ls_data-shelflifeexpirationdate ).

*&---接口HTTP 链接调用
  TRY.
      DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
      DATA(lo_request) = lo_http_client->get_http_request(   ).
      lo_http_client->enable_path_prefix( ).

      DATA(lv_uri_path) = |/API_INBOUND_DELIVERY_SRV;v=0002/A_InbDeliveryItem|.
      lv_uri_path = lv_uri_path && |(DeliveryDocument='{ lv_deliverydocument }',| &&
                                   |DeliveryDocumentItem='{ lv_deliverydocumentitem }')|.

      lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
      lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
      lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
      lo_http_client->set_csrf_token(  ).

      lo_request->set_content_type( 'application/json' ).
      "传入数据转JSON
      lv_json = /ui2/cl_json=>serialize(
            data          = ls_item
            compress      = abap_true
            name_mappings = lt_mapping ).

      lo_request->set_text( lv_json ).

*&---执行http post 方法
      DATA(lo_response) = lo_http_client->execute( if_web_http_client=>patch ).
*&---获取http reponse 数据
      DATA(lv_res) = lo_response->get_text(  ).
*&---确定http 状态
      DATA(status) = lo_response->get_status( ).
      IF status-code <> '204'.
        DATA:ls_rese TYPE zzs_odata_fail.
        /ui2/cl_json=>deserialize( EXPORTING json  = lv_res
                                    CHANGING data  = ls_rese ).
        o_resp-msgty = 'E'.
        o_resp-msgtx = ls_rese-error-message-value .
      ENDIF.

      lo_http_client->close( ).
      FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

    CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
      RETURN.
  ENDTRY.

ENDFUNCTION.
