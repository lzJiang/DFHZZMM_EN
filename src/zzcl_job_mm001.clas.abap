CLASS zzcl_job_mm001 DEFINITION
 PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_apj_dt_exec_object .
    INTERFACES if_apj_rt_exec_object .
    INTERFACES if_oo_adt_classrun.
    CLASS-METHODS trans541o
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING ls_zztmm_0005  TYPE zztmm_0005.

    DATA:rt_aufnr TYPE RANGE OF aufnr,
         rs_aufnr LIKE LINE OF rt_aufnr.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZZCL_JOB_MM001 IMPLEMENTATION.


  METHOD if_apj_dt_exec_object~get_parameters.

  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.
    DATA:lv_count  TYPE i,
         lv_text   TYPE char200,
         lv_status TYPE string,
         lv_flag   TYPE bapi_mtype,
         lv_msg    TYPE bapi_msg,
         lv_req    TYPE string,
         lv_res    TYPE string,
         lv_aufnr  TYPE aufnr.
    DATA:lt_zztmm_0005 TYPE TABLE OF zztmm_0005.



    TRY.
        DATA(l_log) = cl_bali_log=>create_with_header(
                        header = cl_bali_header_setter=>create( object = 'ZZAL_PP_0001'
                                                                subobject = 'ZZAL_PP_0001_SUB1' ) ).
        "1.获取检验批放行非限制转541O增量处理数据
        SELECT a~*,
               d~insplotqtytofree AS quantityinentryunit541,
               d~inspectionlot
          FROM zztmm_0005 WITH PRIVILEGED ACCESS AS a
          INNER JOIN i_insplotmatldocitem WITH PRIVILEGED ACCESS AS b
            ON a~materialdocument = b~materialdocument
            AND a~materialdocumentyear = b~materialdocumentyear
            AND a~materialdocumentitem = b~materialdocumentitem
          INNER JOIN i_insplotusagedecision WITH PRIVILEGED ACCESS AS c
            ON b~inspectionlot = c~inspectionlot
          INNER JOIN i_inspectionlot WITH PRIVILEGED ACCESS AS d
            ON b~inspectionlot = d~inspectionlot
         WHERE a~flag = ''
           AND a~inventoryusabilitycode = 'X'
           AND a~goodsmovementtype = '101'
           AND b~usagedecisionstocktype = ''
           AND c~insplotusagedecisionvaluation = 'A'
          INTO TABLE @DATA(lt_fx).
        LOOP AT lt_fx INTO DATA(ls_fx).
          APPEND INITIAL LINE TO lt_zztmm_0005 ASSIGNING FIELD-SYMBOL(<fs_zztmm_0005>).
          MOVE-CORRESPONDING ls_fx-a TO <fs_zztmm_0005>.
          MOVE-CORRESPONDING ls_fx TO <fs_zztmm_0005>.
          CONDENSE <fs_zztmm_0005>-quantityinentryunit541 NO-GAPS.
        ENDLOOP.
        "2.获取101入库非限制转541O增量处理数据
        SELECT a~*
          FROM zztmm_0005 WITH PRIVILEGED ACCESS AS a
         WHERE a~flag = ''
           AND a~inventoryusabilitycode NE 'X'
           AND a~goodsmovementtype = '101'
          APPENDING TABLE @lt_zztmm_0005.
        IF lt_zztmm_0005[] IS INITIAL.
          l_log->add_item( item = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_information
                                                          text = '未获取增量数据！' ) ).
          cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection( log = l_log
                                                             assign_to_current_appl_job = abap_true ).
          RETURN.
        ELSE.
          "先更新处理标识为R，避免后续作业交叉处理,更新检验批
          LOOP AT lt_zztmm_0005 ASSIGNING <fs_zztmm_0005>.
            IF <fs_zztmm_0005>-quantityinentryunit541 IS INITIAL.
              <fs_zztmm_0005>-quantityinentryunit541 = <fs_zztmm_0005>-quantityinentryunit.
            ENDIF.
            <fs_zztmm_0005>-flag = 'R'.
          ENDLOOP.
          MODIFY zztmm_0005 FROM TABLE @lt_zztmm_0005.
          COMMIT WORK AND WAIT.
        ENDIF.
        "2.541O
        LOOP AT lt_zztmm_0005 INTO DATA(ls_zztmm_0005).
          CLEAR:lv_text,lv_flag,lv_msg,lv_text,lv_req,lv_res.
          IF ls_zztmm_0005-inspectionlot IS NOT INITIAL.
            SELECT SINGLE *
                     FROM zztmm_0005 WITH PRIVILEGED ACCESS
                    WHERE inspectionlot = @ls_zztmm_0005-inspectionlot
                      AND flag IN ( 'S','E' )
                      INTO @DATA(ls_zztmm_0005_now).
            IF sy-subrc = 0.
            "同检验批的其他物料凭证行已转过541则跳过
              CONTINUE.
            ENDIF.
          ENDIF.
          lv_count = lv_count + 1.
          lv_text = |{ lv_count }.开始转供应商库存:源101物料凭证行{ ls_zztmm_0005-materialdocument }|
          && |-{ ls_zztmm_0005-materialdocumentyear }-{ ls_zztmm_0005-materialdocumentitem }|
          && |物料{ ls_zztmm_0005-material }供应商{ ls_zztmm_0005-supplier }数量{ ls_zztmm_0005-quantityinentryunit541 }|
          && |检验批【{ ls_zztmm_0005-inspectionlot }】|.
          l_log->add_item( item = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_information
                                                text = lv_text ) ).
          trans541o( IMPORTING flag = lv_flag
                               msg  = lv_msg
                     CHANGING  ls_zztmm_0005 = ls_zztmm_0005 ).
          IF lv_flag = 'E'.
            lv_text = |{ lv_count }.转供应商库存失败:【{ lv_msg }】|.
            l_log->add_item( item = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_error
                                                  text = lv_text ) ).
          ELSE.
            lv_text = |{ lv_count }.转供应商库存成功:【{ lv_msg }】|.
            l_log->add_item( item = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_status
                                                  text = lv_text ) ).
          ENDIF.
          lv_text = |{ lv_count }.结束转供应商库存:源101物料凭证行{ ls_zztmm_0005-materialdocument }|
          && |-{ ls_zztmm_0005-materialdocumentyear }-{ ls_zztmm_0005-materialdocumentitem }|
          && |物料{ ls_zztmm_0005-material }供应商{ ls_zztmm_0005-supplier }数量{ ls_zztmm_0005-quantityinentryunit541 }|
          && |检验批【{ ls_zztmm_0005-inspectionlot }】|.
          l_log->add_item( item = cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_information
                                                text = lv_text ) ).
        ENDLOOP.

        cl_bali_log_db=>get_instance( )->save_log_2nd_db_connection( log = l_log
                                                                     assign_to_current_appl_job = abap_true ).
      CATCH cx_bali_runtime INTO DATA(l_runtime_exception).
        " some error handling
    ENDTRY.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.

*    DATA lv_job_text TYPE cl_apj_rt_api=>ty_job_text VALUE '测试采购入库非限制自动转供应商库存后台作业'.
*    DATA lv_template_name TYPE cl_apj_rt_api=>ty_template_name VALUE 'ZZ_JT_MM001'.
*    DATA ls_start_info TYPE cl_apj_rt_api=>ty_start_info.
*    DATA ls_scheduling_info TYPE cl_apj_rt_api=>ty_scheduling_info.
*    DATA ls_end_info TYPE cl_apj_rt_api=>ty_end_info.
*    DATA lv_jobname TYPE cl_apj_rt_api=>ty_jobname.
*    DATA lv_jobcount TYPE cl_apj_rt_api=>ty_jobcount.
*    DATA job_start_info TYPE cl_apj_rt_api=>ty_start_info.
*    DATA job_parameters TYPE cl_apj_rt_api=>tt_job_parameter_value.
*    DATA job_parameter TYPE cl_apj_rt_api=>ty_job_parameter_value.
*    DATA range_value TYPE cl_apj_rt_api=>ty_value_range.
*    DATA job_name TYPE cl_apj_rt_api=>ty_jobname.
*    DATA job_count TYPE cl_apj_rt_api=>ty_jobcount.
*    DATA: saptimestamp  TYPE timestamp,
*          javatimestamp TYPE string,
*          lv_ts         TYPE string.
*********** Set scheduling options *******************
*    GET TIME STAMP FIELD saptimestamp .
*    ls_start_info-start_immediately = ''.
*    ls_start_info-timestamp =  saptimestamp + 60 * 1."1分钟后运行
*    ls_scheduling_info-test_mode = abap_false.
*    ls_scheduling_info-timezone = 'UTC+8'.
*
**    job_parameter-name = 'AUFNR'.
**    range_value-sign = 'I'.
**    range_value-option = 'EQ'.
**    range_value-low = '1000006'.
**    APPEND range_value TO job_parameter-t_value.
**    APPEND job_parameter TO job_parameters.
******************************************************
*
*    TRY.
*        cl_apj_rt_api=>schedule_job(
*          EXPORTING
*            iv_job_template_name = lv_template_name
*            iv_job_text          = lv_job_text
*            is_start_info        = ls_start_info
*            is_scheduling_info   = ls_scheduling_info
*            is_end_info          = ls_end_info
*            it_job_parameter_value = job_parameters
*          IMPORTING
*            ev_jobname           = lv_jobname
*            ev_jobcount          = lv_jobcount
*        ).
*      CATCH cx_apj_rt INTO DATA(exc).
*        DATA(lv_txt) = exc->get_longtext( ).
*        DATA(ls_ret) = exc->get_bapiret2( ).
*    ENDTRY.
    DATA:lv_count  TYPE i,
         lv_text   TYPE char200,
         lv_status TYPE string,
         lv_flag   TYPE bapi_mtype,
         lv_msg    TYPE bapi_msg,
         lv_req    TYPE string,
         lv_res    TYPE string,
         lv_aufnr  TYPE aufnr.
    DATA:lt_zztmm_0005 TYPE TABLE OF zztmm_0005.



    TRY.
        "1.获取检验批放行非限制转541O增量处理数据
        SELECT a~*,
               d~insplotqtytofree AS quantityinentryunit541,
               d~inspectionlot
          FROM zztmm_0005 WITH PRIVILEGED ACCESS AS a
          INNER JOIN i_insplotmatldocitem WITH PRIVILEGED ACCESS AS b
            ON a~materialdocument = b~materialdocument
            AND a~materialdocumentyear = b~materialdocumentyear
            AND a~materialdocumentitem = b~materialdocumentitem
          INNER JOIN i_insplotusagedecision WITH PRIVILEGED ACCESS AS c
            ON b~inspectionlot = c~inspectionlot
          INNER JOIN i_inspectionlot WITH PRIVILEGED ACCESS AS d
            ON b~inspectionlot = d~inspectionlot
         WHERE a~flag = ''
           AND a~inventoryusabilitycode = 'X'
           AND a~goodsmovementtype = '101'
           AND b~usagedecisionstocktype = ''
           AND c~insplotusagedecisionvaluation = 'A'
          INTO TABLE @DATA(lt_fx).
        LOOP AT lt_fx INTO DATA(ls_fx).
          APPEND INITIAL LINE TO lt_zztmm_0005 ASSIGNING FIELD-SYMBOL(<fs_zztmm_0005>).
          MOVE-CORRESPONDING ls_fx-a TO <fs_zztmm_0005>.
          MOVE-CORRESPONDING ls_fx TO <fs_zztmm_0005>.
          CONDENSE <fs_zztmm_0005>-quantityinentryunit541 NO-GAPS.
        ENDLOOP.
        "2.获取101入库非限制转541O增量处理数据
        SELECT a~*
          FROM zztmm_0005 WITH PRIVILEGED ACCESS AS a
         WHERE a~flag = ''
           AND a~inventoryusabilitycode NE 'X'
           AND a~goodsmovementtype = '101'
          APPENDING TABLE @lt_zztmm_0005.
        IF lt_zztmm_0005[] IS INITIAL.
          RETURN.
        ELSE.
          "先更新处理标识为R，避免后续作业交叉处理
          LOOP AT lt_zztmm_0005 ASSIGNING <fs_zztmm_0005>.
            IF <fs_zztmm_0005>-quantityinentryunit541 IS INITIAL.
              <fs_zztmm_0005>-quantityinentryunit541 = <fs_zztmm_0005>-quantityinentryunit.
            ENDIF.
            <fs_zztmm_0005>-flag = 'R'.
          ENDLOOP.
          MODIFY zztmm_0005 FROM TABLE @lt_zztmm_0005.
          COMMIT WORK AND WAIT.
        ENDIF.
        "2.541O
        LOOP AT lt_zztmm_0005 INTO DATA(ls_zztmm_0005).
          CLEAR:lv_text,lv_flag,lv_msg,lv_text,lv_req,lv_res.
          IF ls_zztmm_0005-inspectionlot IS NOT INITIAL.
            SELECT SINGLE *
                     FROM zztmm_0005 WITH PRIVILEGED ACCESS
                    WHERE inspectionlot = @ls_zztmm_0005-inspectionlot
                      AND flag IN ( 'S','E' )
                      INTO @DATA(ls_zztmm_0005_now).
            IF sy-subrc = 0.
              "同检验批的其他物料凭证行已转过541则跳过
              CONTINUE.
            ENDIF.
          ENDIF.
          trans541o( IMPORTING flag = lv_flag
                               msg  = lv_msg
                     CHANGING  ls_zztmm_0005 = ls_zztmm_0005 ).
        ENDLOOP.

      CATCH cx_bali_runtime INTO DATA(l_runtime_exception).
        " some error handling
    ENDTRY.
  ENDMETHOD.


  METHOD trans541o.
    TYPES:BEGIN OF ty_item,
            goodsmovementtype            TYPE string,
            goodsmovementrefdoctype      TYPE string,
            delivery                     TYPE i_deliverydocumentitem-deliverydocument,
            deliveryitem                 TYPE string,
            purchaseorder                TYPE i_materialdocumentitem_2-purchaseorder,
            purchaseorderitem            TYPE string,
            manufacturingorder           TYPE aufnr,
            manufacturingorderitem       TYPE string,
            reservation                  TYPE string,
            reservationitem              TYPE string,
            costcenter                   TYPE string,
            material                     TYPE matnr,
            plant                        TYPE string,
            storagelocation              TYPE string,
            batch                        TYPE string,
            manufacturedate              TYPE string,
            quantityinbaseunit           TYPE string,
            entryunit                    TYPE string,
            quantityinentryunit          TYPE string,
            issgorrcvgmaterial           TYPE string,
            issuingorreceivingplant      TYPE string,
            issuingorreceivingstorageloc TYPE string,
            issgorrcvgbatch              TYPE string,
            shelflifeexpirationdate      TYPE string,
            reversedmaterialdocumentyear TYPE string,
            reversedmaterialdocument     TYPE string,
            reversedmaterialdocumentitem TYPE string,
            invtrymgmtreferencedocument  TYPE string,
            invtrymgmtrefdocumentitem    TYPE string,
            goodsmovementreasoncode      TYPE string,
            supplier                     TYPE string,
            customer                     TYPE string,
            materialdocumentitemtext     TYPE string,
            inventoryspecialstocktype    TYPE string,
            materialdocumentline         TYPE string,
            materialdocumentparentline   TYPE string,
            hierarchynodelevel           TYPE string,
            wbselement                   TYPE string,
            batchbysupplier(15)          TYPE c,
            inventorystocktype           TYPE string,
            inventoryusabilitycode       TYPE string,
          END OF ty_item,
          BEGIN OF tty_item,
            results TYPE TABLE OF ty_item WITH EMPTY KEY,
          END OF tty_item,
          BEGIN OF ty_data,
            documentdate               TYPE string,
            postingdate                TYPE string,
            referencedocument          TYPE string,
            goodsmovementcode          TYPE string,
            materialdocumentheadertext TYPE string,
            to_materialdocumentitem    TYPE tty_item,
          END OF ty_data.

    DATA:lv_date        TYPE string.
    DATA:lv_json TYPE string.
    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.
    DATA:ls_data TYPE ty_data,
         ls_item TYPE ty_item,
         ls_sub  TYPE ty_item,
         lt_item TYPE TABLE OF ty_item.
    DATA:lv_mater18(18).
    DATA:lv_deliveryitem TYPE i_deliverydocumentitem-deliverydocumentitem.
*&---BAPI参数
    DATA:lv_msg  TYPE bapi_msg,
         lv_msg2 TYPE bapi_msg.
    DATA:lv_tabix TYPE i_materialdocumentitem_2-materialdocumentitem.
    DATA:lv_purchaseorderitem   TYPE i_materialdocumentitem_2-purchaseorderitem.
    DATA:lv_line_id    TYPE i_materialdocumentitem_2-materialdocumentline,
         lv_parent_id  TYPE i_materialdocumentitem_2-materialdocumentparentline,
         lv_line_depth TYPE numc2.
    DATA:lv_quantity TYPE i_posubcontractingcompapi01-requiredquantity.
    DATA:lv_remain TYPE i_posubcontractingcompapi01-requiredquantity.
    DATA:lv_materialdocument     TYPE i_materialdocumentheader_2-materialdocument,
         lv_materialdocumentyear TYPE i_materialdocumentheader_2-materialdocumentyear.
    DATA:lt_zztmm_0004 TYPE TABLE OF zztmm_0004,
         ls_zztmm_0003 TYPE zztmm_0003.

*&---=============================使用API 步骤01
    DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

    DATA(lv_date1) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
*&---导入结构JSON MAPPING
    lt_mapping = VALUE #(
         ( abap = 'DocumentDate'                 json = 'DocumentDate'                )
         ( abap = 'PostingDate'                  json = 'PostingDate'                 )
         ( abap = 'ReferenceDocument'            json = 'ReferenceDocument'           )
         ( abap = 'GoodsMovementCode'            json = 'GoodsMovementCode'           )
         ( abap = 'MaterialDocumentHeaderText'   json = 'MaterialDocumentHeaderText'  )
         ( abap = 'to_MaterialDocumentItem'      json = 'to_MaterialDocumentItem'     )
         ( abap = 'results'                      json = 'results'                     )
         ( abap = 'GoodsMovementRefDocType'      json = 'GoodsMovementRefDocType'     )
         ( abap = 'GoodsMovementType'            json = 'GoodsMovementType'           )
         ( abap = 'Delivery'                     json = 'Delivery'                    )
         ( abap = 'DeliveryItem'                 json = 'DeliveryItem'                )
         ( abap = 'PurchaseOrder'                json = 'PurchaseOrder'               )
         ( abap = 'PurchaseOrderItem'            json = 'PurchaseOrderItem'           )
         ( abap = 'ManufacturingOrder'           json = 'ManufacturingOrder'          )
         ( abap = 'ManufacturingOrderItem'       json = 'ManufacturingOrderItem'      )
         ( abap = 'Reservation'                  json = 'Reservation'                 )
         ( abap = 'ReservationItem'              json = 'ReservationItem'             )
         ( abap = 'CostCenter'                   json = 'CostCenter'                  )
         ( abap = 'Material'                     json = 'Material'                    )
         ( abap = 'Plant'                        json = 'Plant'                       )
         ( abap = 'StorageLocation'              json = 'StorageLocation'             )
         ( abap = 'Batch'                        json = 'Batch'                       )
         ( abap = 'ManufactureDate'              json = 'ManufactureDate'             )
         ( abap = 'EntryUnit'                    json = 'EntryUnit'                   )
         ( abap = 'QuantityInEntryUnit'          json = 'QuantityInEntryUnit'         )
         ( abap = 'QuantityInBaseUnit'           json = 'QuantityInBaseUnit'          )
         ( abap = 'IssgOrRcvgMaterial'           json = 'IssgOrRcvgMaterial'          )
         ( abap = 'IssuingOrReceivingPlant'      json = 'IssuingOrReceivingPlant'     )
         ( abap = 'IssuingOrReceivingStorageLoc' json = 'IssuingOrReceivingStorageLoc' )
         ( abap = 'IssgOrRcvgBatch'              json = 'IssgOrRcvgBatch'             )
         ( abap = 'ShelfLifeExpirationDate'      json = 'ShelfLifeExpirationDate'     )
         ( abap = 'ReversedMaterialDocumentYear' json = 'ReversedMaterialDocumentYear' )
         ( abap = 'ReversedMaterialDocument'     json = 'ReversedMaterialDocument'    )
         ( abap = 'ReversedMaterialDocumentItem' json = 'ReversedMaterialDocumentItem' )
         ( abap = 'InvtryMgmtReferenceDocument'  json = 'InvtryMgmtReferenceDocument' )
         ( abap = 'InvtryMgmtRefDocumentItem'    json = 'InvtryMgmtRefDocumentItem'   )
         ( abap = 'GoodsMovementReasonCode'      json = 'GoodsMovementReasonCode'     )
         ( abap = 'BatchBySupplier'              json = 'BatchBySupplier'             )

         ( abap = 'Supplier'                     json = 'Supplier'                    )
         ( abap = 'Customer'                     json = 'Customer'                    )
         ( abap = 'InventorySpecialStockType'    json = 'InventorySpecialStockType'   )
         ( abap = 'InventoryStockType'           json = 'InventoryStockType'          )
         ( abap = 'InventoryUsabilityCode'       json = 'InventoryUsabilityCode'      )
         ( abap = 'MaterialDocumentItemText'     json = 'MaterialDocumentItemText'    )
         ( abap = 'WBSElement'                   json = 'WBSElement'                  )

         ( abap = 'MaterialDocumentLine'         json = 'MaterialDocumentLine'        )
         ( abap = 'MaterialDocumentParentLine'   json = 'MaterialDocumentParentLine'  )
         ( abap = 'HierarchyNodeLevel'           json = 'HierarchyNodeLevel'  )
      ).

    "数据整合
    "凭证日期
    ls_data-documentdate = |{ lv_date1+0(4) }-{ lv_date1+4(2) }-{ lv_date1+6(2) }T00:00:00| .
    "过账日期
    ls_data-postingdate = |{ lv_date1+0(4) }-{ lv_date1+4(2) }-{ lv_date1+6(2) }T00:00:00| .
    "抬头文本
    ls_data-materialdocumentheadertext = |{ ls_zztmm_0005-materialdocument }-{ ls_zztmm_0005-materialdocumentyear }-{ ls_zztmm_0005-materialdocumentitem }|.
    ls_data-goodsmovementcode = '04'.
    CLEAR:ls_item.
    lv_tabix = lv_tabix + 1.
    lv_line_id = lv_line_id + 1.
*    MOVE-CORRESPONDING ls_zztmm_0005 TO ls_item.
*    ls_item-inventoryspecialstocktype = 'O'.
    ls_item-goodsmovementtype = '541'.
    ls_item-supplier = ls_zztmm_0005-supplier.
    lv_mater18 = ls_zztmm_0005-material.
    lv_mater18 = |{ lv_mater18 ALPHA = IN }|.
    ls_item-material = lv_mater18.
    ls_item-plant = ls_zztmm_0005-plant.
    ls_item-batch = ls_zztmm_0005-batch.
    ls_item-storagelocation = ls_zztmm_0005-storagelocation.
    ls_item-entryunit = ls_zztmm_0005-entryunit.
    ls_item-quantityinentryunit = ls_zztmm_0005-quantityinentryunit541.
    ls_item-materialdocumentitemtext = ls_zztmm_0005-materialdocumentitemtext.
    APPEND ls_item TO lt_item.

    ls_data-to_materialdocumentitem-results = lt_item.

*&---接口HTTP 链接调用
    TRY.
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_request) = lo_http_client->get_http_request(   ).
        lo_http_client->enable_path_prefix( ).

        DATA(lv_uri_path) = |/API_MATERIAL_DOCUMENT_SRV/A_MaterialDocumentHeader?sap-language=zh|.
        lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        "lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
        lo_http_client->set_csrf_token(  ).

        lo_request->set_content_type( 'application/json' ).
        "传入数据转JSON
        lv_json = /ui2/cl_json=>serialize(
              data          = ls_data
              compress      = abap_true
              name_mappings = lt_mapping ).

        lo_request->set_text( lv_json ).

*&---执行http post 方法
        DATA(lo_response) = lo_http_client->execute( if_web_http_client=>post ).
*&---获取http reponse 数据
        DATA(lv_res) = lo_response->get_text(  ).
*&---确定http 状态
        DATA(status) = lo_response->get_status( ).
        IF status-code = '201'.
          TYPES:BEGIN OF ty_heads,
                  materialdocument     TYPE string,
                  materialdocumentyear TYPE string,
                END OF ty_heads,
                BEGIN OF ty_ress,
                  d TYPE ty_heads,
                END OF  ty_ress.
          DATA:ls_ress TYPE ty_ress.
          /ui2/cl_json=>deserialize( EXPORTING json  = lv_res
                                      CHANGING data  = ls_ress ).

          flag  = 'S'.
          lv_materialdocument = ls_ress-d-materialdocument.
          lv_materialdocumentyear = ls_ress-d-materialdocumentyear.
          msg  = |541凭证{ lv_materialdocument }-{ lv_materialdocumentyear }|.
        ELSE.
          DATA:ls_rese TYPE zzs_odata_fail.
          /ui2/cl_json=>deserialize( EXPORTING json  = lv_res
                                      CHANGING data  = ls_rese ).
          flag = 'E'.
          msg = ls_rese-error-message-value .
          IF ls_rese-error-innererror-errordetails[] IS NOT INITIAL.
            LOOP AT ls_rese-error-innererror-errordetails ASSIGNING FIELD-SYMBOL(<fs_errordetails>) WHERE severity = 'error'.
              msg = |{ msg }/{ <fs_errordetails>-message }|.
            ENDLOOP.
          ENDIF.
        ENDIF.
      CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
        flag = 'E'.
        msg  = '接口调用异常' && lx_web_http_client_error->get_longtext( ) .
    ENDTRY.

    IF flag = 'S'.
      SELECT a~materialdocumentheadertext,
             b~materialdocument,
             b~materialdocumentyear,
             b~materialdocumentitem,
             b~materialdocumentitemtext,
             b~batch
        FROM i_materialdocumentheader_2 WITH PRIVILEGED ACCESS AS a
       INNER JOIN i_materialdocumentitem_2 WITH PRIVILEGED ACCESS AS b
          ON a~materialdocument = b~materialdocument AND a~materialdocumentyear = b~materialdocumentyear
       WHERE a~materialdocument = @lv_materialdocument
         AND a~materialdocumentyear = @lv_materialdocumentyear
        INTO TABLE @DATA(lt_materialdocumentitem).
      ls_zztmm_0005-updated_date = lv_date1.
      ls_zztmm_0005-updated_time = lv_time.
      ls_zztmm_0005-updated_by   = lv_user.
      READ TABLE lt_materialdocumentitem INTO DATA(ls_materialdocumentitem) WITH KEY materialdocumentitemtext = ls_zztmm_0005-materialdocumentitemtext.
      IF sy-subrc = 0.
        ls_zztmm_0005-materialdocument541 = ls_materialdocumentitem-materialdocument.
        ls_zztmm_0005-materialdocumentyear541 = ls_materialdocumentitem-materialdocumentyear.
        ls_zztmm_0005-materialdocumentitem541 = ls_materialdocumentitem-materialdocumentitem.
        ls_zztmm_0005-flag = 'S'.
      ENDIF.
    ELSE.
      ls_zztmm_0005-updated_date = lv_date1.
      ls_zztmm_0005-updated_time = lv_time.
      ls_zztmm_0005-updated_by   = lv_user.
      ls_zztmm_0005-flag = flag.
      ls_zztmm_0005-msg = msg.
    ENDIF.

    IF ls_zztmm_0005-inspectionlot IS NOT INITIAL.
      UPDATE zztmm_0005 SET updated_date = @ls_zztmm_0005-updated_date,
                            updated_time = @ls_zztmm_0005-updated_time,
                            updated_by = @ls_zztmm_0005-updated_by,
                            materialdocument541 = @ls_zztmm_0005-materialdocument541,
                            materialdocumentyear541 = @ls_zztmm_0005-materialdocumentyear541,
                            materialdocumentitem541 = @ls_zztmm_0005-materialdocumentitem541,
                            flag = @ls_zztmm_0005-flag,
                            msg = @ls_zztmm_0005-msg WHERE inspectionlot = @ls_zztmm_0005-inspectionlot.
    ELSE.
      MODIFY zztmm_0005 FROM @ls_zztmm_0005.
    ENDIF.
    COMMIT WORK AND WAIT.
  ENDMETHOD.
ENDCLASS.
