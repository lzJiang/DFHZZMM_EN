FUNCTION zzfm_mm_001.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(I_REQ) TYPE  ZZS_MMI001_REQ OPTIONAL
*"  EXPORTING
*"     REFERENCE(O_RESP) TYPE  ZZS_REST_OUT
*"----------------------------------------------------------------------
  .

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
          batchbysupplier              TYPE string,
          inventorystocktype           TYPE string,
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
  DATA:ls_tmp TYPE zzs_mmi001_req.
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

  ls_tmp = i_req.
*&---=============================使用API 步骤01
  DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).


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
       ( abap = 'MaterialDocumentItemText'     json = 'MaterialDocumentItemText'    )
       ( abap = 'WBSElement'                   json = 'WBSElement'                  )

       ( abap = 'MaterialDocumentLine'         json = 'MaterialDocumentLine'        )
       ( abap = 'MaterialDocumentParentLine'   json = 'MaterialDocumentParentLine'  )
       ( abap = 'HierarchyNodeLevel'           json = 'HierarchyNodeLevel'  )
    ).

  "数据整合
  "凭证日期
  ls_data-documentdate = zzcl_comm_tool=>date2iso( ls_tmp-req-head-documentdate ).
  "过账日期
  ls_data-postingdate = zzcl_comm_tool=>date2iso( ls_tmp-req-head-postingdate ).
  "库存业务类型
  ls_data-goodsmovementcode = ls_tmp-req-head-goodsmovementcode.
  "抬头文本
  ls_data-materialdocumentheadertext = ls_tmp-req-head-materialdocumentheadertext.
  LOOP AT ls_tmp-req-item INTO DATA(ls_tmp_item).
    CLEAR:ls_item.
    lv_tabix = lv_tabix + 1.
    lv_line_id = lv_line_id + 1.
    MOVE-CORRESPONDING ls_tmp_item TO ls_item.

    ls_item-manufacturingorder = |{ ls_item-manufacturingorder ALPHA = IN }|.
    ls_item-purchaseorder = |{ ls_item-purchaseorder ALPHA = IN }|.
    ls_item-delivery = |{ ls_item-delivery ALPHA = IN }|.
    lv_mater18 = ls_tmp_item-material.
    lv_mater18 = |{ lv_mater18 ALPHA = IN }|.
    ls_tmp_item-material = lv_mater18.
    lv_deliveryitem = ls_item-deliveryitem.


    "匹配批次
    IF ls_item-batch IS NOT INITIAL.
      SELECT SINGLE a~material,
                a~batch
        FROM i_batchcharacteristicvaluetp_2 WITH PRIVILEGED ACCESS AS a
        JOIN i_clfncharacteristic WITH PRIVILEGED ACCESS AS b ON a~charcinternalid = b~charcinternalid
       WHERE material = @lv_mater18
         AND b~characteristic = 'Z_WMSBATCH'
         AND a~charcvalue = @ls_item-batch
        INTO @DATA(ls_valuetp).
      IF sy-subrc = 0.
        ls_item-batch = ls_valuetp-batch.
        ls_tmp_item-batch = ls_item-batch.
      ENDIF.
    ENDIF.

    IF ls_item-issgorrcvgbatch IS NOT INITIAL.
      SELECT SINGLE a~material,
                a~batch
        FROM i_batchcharacteristicvaluetp_2 WITH PRIVILEGED ACCESS AS a
        JOIN i_clfncharacteristic WITH PRIVILEGED ACCESS AS b ON a~charcinternalid = b~charcinternalid
       WHERE material = @lv_mater18
         AND b~characteristic = 'Z_WMSBATCH'
         AND a~charcvalue = @ls_item-issgorrcvgbatch
        INTO @ls_valuetp.
      IF sy-subrc = 0.
        ls_item-issgorrcvgbatch = ls_valuetp-batch.
        ls_tmp_item-issgorrcvgbatch = ls_item-issgorrcvgbatch.
      ENDIF.
    ENDIF.

    "移动类型确认 code
    CASE ls_item-goodsmovementtype.
      WHEN '101' OR '102' OR  '161'."采购入库 生产入库 采购退货
        IF ls_item-delivery IS NOT INITIAL.
          ls_data-goodsmovementcode = '01'.
          ls_item-goodsmovementrefdoctype = 'B'.

          "行项目
          SELECT SINGLE
                 a~purchaseorder,
                 a~purchaseorderitem,
                 a~sddocumentcategory,
                 a~actualdeliveryquantity
            FROM i_deliverydocumentitem WITH PRIVILEGED ACCESS AS a
           WHERE deliverydocument = @ls_item-delivery
             AND deliverydocumentitem = @lv_deliveryitem
            INTO @DATA(ls_deliverydocumentitem).

          "汇总已交货行。
          SELECT SINGLE SUM( CASE a~debitcreditcode
                             WHEN 'S' THEN  a~quantityinentryunit
                             ELSE 0 - a~quantityinentryunit END )  AS menge
            FROM i_materialdocumentitem_2 WITH PRIVILEGED ACCESS AS a
           WHERE a~deliverydocument = @ls_item-delivery
             AND a~deliverydocumentitem = @lv_deliveryitem
             AND a~goodsmovementtype IN ('101','102')
            INTO @DATA(lv_menge).

          IF ls_item-quantityinentryunit + lv_menge > ls_deliverydocumentitem-actualdeliveryquantity.
            o_resp-msgty  = 'E'.
            o_resp-msgtx  = '收货数量不允许大于交货单数量'.
            RETURN.
          ENDIF.

          IF ls_deliverydocumentitem-sddocumentcategory = '7'.
            IF ls_tmp_item-batch IS NOT INITIAL OR ls_tmp_item-shelflifeexpirationdate IS NOT INITIAL.
              CALL FUNCTION 'ZZFM_MM_001_INB'
                EXPORTING
                  i_data = ls_tmp_item
                IMPORTING
                  o_resp = o_resp.
              IF o_resp-msgty   = 'E'.
                RETURN.
              ENDIF.
            ENDIF.
          ENDIF.

          "采购订单写入
          IF ls_item-purchaseorder IS INITIAL.
            ls_item-purchaseorder = ls_deliverydocumentitem-purchaseorder.
            ls_item-purchaseorderitem = ls_deliverydocumentitem-purchaseorderitem.
          ENDIF.
        ENDIF.

        IF ls_item-manufacturingorder IS NOT INITIAL.
          ls_data-goodsmovementcode = '02'.
          ls_item-goodsmovementrefdoctype = 'F'.
        ENDIF.

        IF ls_item-purchaseorder IS NOT INITIAL.
          ls_data-goodsmovementcode = '01'.
          ls_item-goodsmovementrefdoctype = 'B'.
        ENDIF.

        "WMS批次特性
        IF ls_item-goodsmovementtype = '101'.
          IF ls_tmp_item-zzwmsbatch IS NOT INITIAL.
            SELECT SINGLE a~material,
                          a~batch
              FROM i_batchcharacteristicvaluetp_2 WITH PRIVILEGED ACCESS AS a
              JOIN i_clfncharacteristic WITH PRIVILEGED ACCESS AS b ON a~charcinternalid = b~charcinternalid
             WHERE material = @lv_mater18
               AND b~characteristic = 'Z_WMSBATCH'
               AND a~charcvalue = @ls_tmp_item-zzwmsbatch
              INTO @ls_valuetp.
            IF sy-subrc = 0.
              ls_item-batch = ls_valuetp-batch.
              ls_tmp_item-batch = ls_item-batch.
            ELSE.
              gv_wmsflag = abap_true.
              ls_item-materialdocumentitemtext = lv_tabix.
              ls_tmp_item-tabix = lv_tabix.
            ENDIF.
            ls_item-batchbysupplier = ls_tmp_item-zzwmsbatch.
          ENDIF.
          IF ls_tmp_item-batch IS NOT INITIAL..
            ls_item-batchbysupplier = ls_tmp_item-batch.
          ENDIF.

          "当 是否最后一次收货 = X 时 ， 543 需要加增强计算扣减数量 = 总需要扣减数量 - 已提货数量
          "针对委外订单
          IF ls_tmp_item-zzlast = 'X'.
            lv_purchaseorderitem = ls_item-purchaseorderitem.
            lv_parent_id = lv_tabix.
            ls_item-materialdocumentline = lv_parent_id.

            "组件
            SELECT a~purchaseorder,
                   a~purchaseorderitem,
                   a~material,
                   a~requiredquantity,
                   a~withdrawnquantity,
                   a~batch,
                   a~plant,
                   b~supplier
              FROM i_posubcontractingcompapi01 WITH PRIVILEGED ACCESS AS a
              LEFT JOIN i_purchaseorderapi01 WITH PRIVILEGED ACCESS AS b ON a~purchaseorder = b~purchaseorder
             WHERE a~purchaseorder = @ls_item-purchaseorder
               AND a~purchaseorderitem = @lv_purchaseorderitem
              INTO TABLE @DATA(lt_posub).
            "库存
            SELECT a~plant,
                   a~product,
                   c~lastgoodsreceiptdate,
                   a~batch,
                   a~matlwrhsstkqtyinmatlbaseunit
              FROM i_stockquantitycurrentvalue_2( p_displaycurrency = 'CNY' ) WITH PRIVILEGED ACCESS AS a
              JOIN @lt_posub AS b ON a~plant   = b~plant
                                 AND a~product = b~material
                                 AND a~supplier = b~supplier
              JOIN i_batchdistinct WITH PRIVILEGED ACCESS AS c ON a~product = c~material
                                                              AND a~batch = c~batch
             WHERE a~inventoryspecialstocktype = 'O'
               AND a~valuationareatype = '1'

              INTO TABLE @DATA(lt_stock).
            SORT lt_stock BY plant product lastgoodsreceiptdate ASCENDING.

            LOOP AT lt_posub INTO DATA(ls_posub).
              CLEAR:ls_sub.
              ls_sub-purchaseorder  =   ls_item-purchaseorder.
              ls_sub-purchaseorderitem  = ls_item-purchaseorderitem.
              ls_sub-goodsmovementtype = '543'.  " 移动类型
              ls_sub-material = ls_posub-material. " 物料号
              ls_sub-inventoryspecialstocktype = 'O'. " 特殊库存
              ls_sub-supplier = ls_posub-supplier.
              ls_sub-plant = ls_posub-plant.
              "ls_sub-batch = '20241130AA'.
              lv_quantity = ls_posub-requiredquantity - ls_posub-withdrawnquantity.
              ls_sub-quantityinentryunit = ls_posub-requiredquantity - ls_posub-withdrawnquantity.
              READ TABLE lt_stock TRANSPORTING NO FIELDS WITH KEY plant = ls_posub-plant
                                                                  product = ls_posub-material BINARY SEARCH.
              IF sy-subrc = 0.
                LOOP AT lt_stock INTO DATA(ls_stock) FROM sy-tabix.
                  IF ls_stock-plant = ls_posub-plant AND ls_stock-product = ls_posub-material.
                    lv_remain = lv_quantity - ls_stock-matlwrhsstkqtyinmatlbaseunit.
                    IF lv_remain >= 0.
                      ls_sub-batch = ls_stock-batch.
                      ls_sub-quantityinentryunit = ls_stock-matlwrhsstkqtyinmatlbaseunit.
                      CONDENSE  ls_sub-quantityinentryunit NO-GAPS.
                      ls_sub-materialdocumentparentline = lv_parent_id. " 父项目编码
                      lv_line_id = lv_line_id + 1. " 子项目编号
                      ls_sub-materialdocumentline = lv_line_id.
                      APPEND ls_sub TO lt_item.
                      lv_quantity = lv_remain .
                    ELSE.
                      ls_sub-batch = ls_stock-batch.
                      ls_sub-quantityinentryunit = lv_quantity.
                      CONDENSE  ls_sub-quantityinentryunit NO-GAPS.
                      ls_sub-materialdocumentparentline = lv_parent_id. " 父项目编码
                      lv_line_id = lv_line_id + 1. " 子项目编号
                      ls_sub-materialdocumentline = lv_line_id.
                      APPEND ls_sub TO lt_item.
                      EXIT.
                    ENDIF.

                  ELSE.
                    EXIT.
                  ENDIF.
                ENDLOOP.
              ENDIF.
*              ls_sub-quantityinentryunit = ls_posub-requiredquantity - ls_posub-withdrawnquantity.
*              CONDENSE ls_sub-quantityinentryunit NO-GAPS.
*
*              ls_sub-materialdocumentparentline = lv_parent_id. " 父项目编码
*              lv_line_id = lv_line_id + 1. " 子项目编号
*              ls_sub-materialdocumentline = lv_line_id.
*              APPEND ls_sub TO lt_item.

            ENDLOOP.
          ENDIF.

        ENDIF.

      WHEN '201' OR '202' OR 'Z01' OR 'Z02' ."成本中心领料/冲销,会议领用
        ls_data-goodsmovementcode = '03'.
      WHEN '711'  OR '712' ."盘盈/盘亏
        ls_data-goodsmovementcode = '03'.
      WHEN '551' ."报废
        ls_data-goodsmovementcode = '03'.
      WHEN '261' OR '531'."副产品收货."生产订单投料
        ls_data-goodsmovementcode = '03'.
        "获取预留
        IF ls_item-reservation  IS INITIAL.
          SELECT SINGLE
                 b~reservation,
                 b~reservationitem
            FROM i_reservationdocumentheader WITH PRIVILEGED ACCESS AS a
            JOIN i_reservationdocumentitem WITH PRIVILEGED ACCESS AS b ON a~reservation = b~reservation
           WHERE a~orderid = @ls_item-manufacturingorder
             AND b~product = @ls_tmp_item-material
            INTO (@ls_item-reservation, @ls_item-reservationitem ).
        ENDIF.
      WHEN '262' OR '532'.
        ls_data-goodsmovementcode = '03'.
      WHEN '311' ."库存调拨
        ls_data-goodsmovementcode = '04'.
      WHEN '309' ."物料转物料
        ls_data-goodsmovementcode = '04'.
      WHEN '122'."原采购退货
        IF ls_item-delivery IS NOT INITIAL .
          ls_data-goodsmovementcode = '01'.
          ls_item-goodsmovementrefdoctype = 'B'.
        ENDIF.

      WHEN '221' OR '222'."研发项目领料
        ls_data-goodsmovementcode = '03'.

      WHEN '501'."无采购订单收货
        ls_data-goodsmovementcode = '01'.
      WHEN '541'."发货到转包库存（供应商库存）
        ls_data-goodsmovementcode = '06'.

    ENDCASE.
    "订单单位
    IF ls_item-entryunit IS  INITIAL.
      SELECT SINGLE baseunit
        FROM i_product WITH PRIVILEGED ACCESS
       WHERE product = @ls_tmp_item-material
        INTO @ls_item-entryunit.
    ENDIF.

    ls_item-manufacturedate = zzcl_comm_tool=>date2iso( ls_tmp_item-manufacturedate ).
    ls_item-shelflifeexpirationdate = zzcl_comm_tool=>date2iso( ls_tmp_item-shelflifeexpirationdate ).
    APPEND ls_item TO lt_item.

    APPEND ls_tmp_item TO gt_item.
  ENDLOOP.

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

        o_resp-msgty  = 'S'.
        o_resp-msgtx  = 'success'.
        o_resp-sapnum = ls_ress-d-materialdocument.
        gv_mblnr = ls_ress-d-materialdocument.
        gv_year = ls_ress-d-materialdocumentyear.
        "更改批次
        CALL FUNCTION 'ZZFM_MM_001_BATCH'.
      ELSE.
        DATA:ls_rese TYPE zzs_odata_fail.
        /ui2/cl_json=>deserialize( EXPORTING json  = lv_res
                                    CHANGING data  = ls_rese ).
        o_resp-msgty = 'E'.
        o_resp-msgtx = ls_rese-error-message-value .

      ENDIF.
    CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
      RETURN.
  ENDTRY.




ENDFUNCTION.
