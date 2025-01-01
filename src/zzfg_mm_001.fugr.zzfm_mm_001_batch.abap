FUNCTION zzfm_mm_001_batch.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"----------------------------------------------------------------------


  TYPES:BEGIN OF ty_charc,
          charcvalue            TYPE string, "特征
          material              TYPE string,
          batchidentifyingplant TYPE string,
          batch                 TYPE string,
          charcinternalid       TYPE string,
        END OF ty_charc.


  DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.
  DATA:lv_json TYPE string.
  DATA:ls_charc TYPE ty_charc.
  DATA:lv_mater18(18).
*&---=============================使用API 步骤01
*&---=========1.API 类使用变量
*&---定义场景使用变量
  DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

*&---导入结构JSON MAPPING
  lt_mapping = VALUE #(
       ( abap = 'Material'                   json = 'Material'   )
       ( abap = 'BatchIdentifyingPlant'      json = 'BatchIdentifyingPlant'   )
       ( abap = 'Batch'                      json = 'Batch'   )
       ( abap = 'CharcInternalID'            json = 'CharcInternalID'   )
       ( abap = 'CharcValue'                 json = 'CharcValue'   )
       ).

  SELECT charcinternalid,
         timeintervalnumber,
         characteristic
    FROM i_clfncharacteristic WITH PRIVILEGED ACCESS AS a
   WHERE characteristic LIKE 'Z%'
    INTO TABLE @DATA(lt_chara).
  SORT lt_chara BY characteristic.

  SELECT material,
         batch,
         materialdocumentitemtext
    FROM i_materialdocumentitem_2 WITH PRIVILEGED ACCESS AS a
   WHERE materialdocument = @gv_mblnr
     AND materialdocumentyear = @gv_year
     AND batch IS NOT INITIAL
     INTO TABLE @DATA(lt_documentitem).
  "将生成的批次对应
  LOOP AT gt_item ASSIGNING FIELD-SYMBOL(<fs_item>) WHERE batch IS INITIAL.
    READ TABLE lt_documentitem INTO DATA(ls_documentitem) WITH KEY materialdocumentitemtext = <fs_item>-tabix.
    IF sy-subrc = 0.
      <fs_item>-batch = ls_documentitem-batch.
    ENDIF.
  ENDLOOP.



  LOOP AT gt_item INTO DATA(ls_item) WHERE batch IS NOT INITIAL
                                     AND zzversion IS NOT INITIAL.

    READ TABLE lt_chara INTO DATA(ls_chara) WITH KEY characteristic = 'Z_BANBEN' BINARY SEARCH.
    CLEAR:ls_charc.
    ls_charc-charcvalue = ls_item-zzversion.

    lv_mater18 = ls_item-material.
    lv_mater18 = |{ lv_mater18 ALPHA = IN }|.


    SELECT SINGLE *
      FROM i_batchcharacteristicvaluetp_2 WITH PRIVILEGED ACCESS AS a
     WHERE material = @lv_mater18
       AND batch = @ls_item-batch
       AND charcinternalid = @ls_chara-charcinternalid
      INTO @DATA(ls_valuetp).

    IF sy-subrc = 0.
      "更改
*&---接口HTTP 链接调用
      TRY.
          DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
          DATA(lo_request) = lo_http_client->get_http_request(   ).
          lo_http_client->enable_path_prefix( ).

          DATA(lv_uri_path) = |/API_BATCH_SRV/BatchCharcValue|.
          lv_uri_path = lv_uri_path && |(Material='{ ls_valuetp-material }',| &&
                                       |BatchIdentifyingPlant='{ ls_valuetp-batchidentifyingplant }',| &&
                                       |Batch='{ ls_valuetp-batch }',| &&
                                       |CharcInternalID='{ ls_valuetp-charcinternalid }',| &&
                                       |CharcValuePositionNumber='{ ls_valuetp-clfncharcvaluepositionnumber }')|.

          lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
          lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
          lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
          lo_http_client->set_csrf_token(  ).

          lo_request->set_content_type( 'application/json' ).
          "传入数据转JSON
          lv_json = /ui2/cl_json=>serialize(
                data          = ls_charc
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

          ENDIF.

          lo_http_client->close( ).
          FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

        CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
          RETURN.
      ENDTRY.

    ELSE.

      "创建
      ls_charc-material = lv_mater18.
      ls_charc-batch = ls_item-batch.
      ls_charc-charcinternalid = ls_chara-charcinternalid.
      ls_charc-charcvalue = ls_item-zzversion.
*&---接口HTTP 链接调用
      TRY.
          lo_http_client = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
          lo_request = lo_http_client->get_http_request(   ).
          lo_http_client->enable_path_prefix( ).

          lv_uri_path = |/API_BATCH_SRV/BatchCharcValue|.

          lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
          lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
          lo_http_client->set_csrf_token(  ).

          lo_request->set_content_type( 'application/json' ).
          "传入数据转JSON
          lv_json = /ui2/cl_json=>serialize(
                data          = ls_charc
                compress      = abap_true
                name_mappings = lt_mapping ).

          lo_request->set_text( lv_json ).

*&---执行http post 方法
          lo_response = lo_http_client->execute( if_web_http_client=>post ).
*&---获取http reponse 数据
          lv_res = lo_response->get_text(  ).
*&---确定http 状态
          status = lo_response->get_status( ).
          IF status-code <> '201'.
            /ui2/cl_json=>deserialize( EXPORTING json  = lv_res
                                        CHANGING data  = ls_rese ).

          ENDIF.

          lo_http_client->close( ).
          FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

        CATCH cx_web_http_client_error INTO lx_web_http_client_error.
          RETURN.
      ENDTRY.
    ENDIF.
  ENDLOOP.


  "将WMS批次写入批次特性
  IF gv_wmsflag = abap_true.
    IF lt_documentitem IS NOT INITIAL.
      READ TABLE lt_chara INTO ls_chara WITH KEY characteristic = 'Z_WMSBATCH' BINARY SEARCH.

      LOOP AT lt_documentitem INTO ls_documentitem.
        "创建
        ls_charc-material = ls_documentitem-material.
        ls_charc-batch = ls_documentitem-batch.
        ls_charc-charcinternalid = ls_chara-charcinternalid.
        READ TABLE gt_item INTO ls_item WITH KEY tabix = ls_documentitem-materialdocumentitemtext.
        IF sy-subrc = 0.
          ls_charc-charcvalue = ls_item-zzwmsbatch.
        ENDIF.

*&---接口HTTP 链接调用
        TRY.
            lo_http_client = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
            lo_request = lo_http_client->get_http_request(   ).
            lo_http_client->enable_path_prefix( ).

            lv_uri_path = |/API_BATCH_SRV/BatchCharcValue|.

            lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
            lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
            lo_http_client->set_csrf_token(  ).

            lo_request->set_content_type( 'application/json' ).
            "传入数据转JSON
            lv_json = /ui2/cl_json=>serialize(
                  data          = ls_charc
                  compress      = abap_true
                  name_mappings = lt_mapping ).

            lo_request->set_text( lv_json ).

*&---执行http post 方法
            lo_response = lo_http_client->execute( if_web_http_client=>post ).
*&---获取http reponse 数据
            lv_res = lo_response->get_text(  ).
*&---确定http 状态
            status = lo_response->get_status( ).
            IF status-code <> '201'.
              /ui2/cl_json=>deserialize( EXPORTING json  = lv_res
                                          CHANGING data  = ls_rese ).

            ENDIF.

            lo_http_client->close( ).
            FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

          CATCH cx_web_http_client_error INTO lx_web_http_client_error.
            RETURN.
        ENDTRY.

      ENDLOOP.
    ENDIF.


  ENDIF.



ENDFUNCTION.
