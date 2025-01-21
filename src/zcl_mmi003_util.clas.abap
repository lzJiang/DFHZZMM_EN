CLASS zcl_mmi003_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS check_0001
      IMPORTING ls_req TYPE zzs_mmi003_in
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg.
    METHODS deal_0001
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi003_in.
    METHODS save_zztmm_0001
      IMPORTING lv_purchaseorder  TYPE ebeln
      CHANGING  lt_zzt_mmi003_out TYPE zzt_mmi003_out.
    METHODS check_0002
      IMPORTING lt_req TYPE zzt_mmi003_0002_in
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg.
    METHODS deal_0002
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  lt_req TYPE zzt_mmi003_0002_in.
    METHODS deal_0002_one
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi003_0002_in.
PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_MMI003_UTIL IMPLEMENTATION.


  METHOD check_0001.
    IF ls_req IS INITIAL.
      flag = 'E'.
      msg = |'传入项目为空'| .
      RETURN.
    ENDIF.

    "1.检查抬头
    IF ls_req-outbillno IS INITIAL.
      flag = 'E'.
      msg = '【外部采购订单号】不能为空'.
      RETURN.
    ELSE.
      SELECT SINGLE *
               FROM i_purchaseorderapi01 WITH PRIVILEGED ACCESS
              WHERE supplierrespsalespersonname = @ls_req-outbillno
              INTO @DATA(ls_purchaseorder).
      IF sy-subrc = 0.
        flag = 'E'.
        msg = |'外部系统单号'{ ls_req-outbillno }'已存在对应SAP采购订单'{ ls_purchaseorder-purchaseorder }',请勿重复创建' |.
        RETURN.
      ENDIF.
    ENDIF.
    IF ls_req-companycode IS INITIAL.
      flag = 'E'.
      msg = '【公司代码】不能为空'.
      RETURN.
    ENDIF.
    IF ls_req-purchaseordertype IS INITIAL.
      flag = 'E'.
      msg = '【采购订单类型】不能为空'.
      RETURN.
    ENDIF.
    IF ls_req-supplier IS INITIAL.
      flag = 'E'.
      msg = '【供应商编码】不能为空'.
      RETURN.
    ENDIF.
    "2.检查行项目
    IF ls_req-topurchaseorderitem IS INITIAL.
      flag = 'E'.
      msg = '行项目不能为空'.
      RETURN.
    ENDIF.
    LOOP AT ls_req-topurchaseorderitem[] INTO DATA(ls_item).
      IF ls_item-outbillitemno IS INITIAL.
        flag = 'E'.
        msg = '【外部系统订单行】不能为空'.
        RETURN.
      ENDIF.
      IF ls_item-plant IS INITIAL.
        flag = 'E'.
        msg =  |'行'{ ls_item-outbillitemno }'【收货工厂】不能为空'| .
        RETURN.
      ENDIF.
      IF ls_item-netpriceamount IS INITIAL.
        flag = 'E'.
        msg = |'行'{ ls_item-outbillitemno }'【含税单价】不能为空'| .
        RETURN.
      ENDIF.
      IF ls_item-orderquantity IS INITIAL.
        flag = 'E'.
        msg = |'行'{ ls_item-outbillitemno }'【订单数量】不能为空'| .
        RETURN.
      ENDIF.
      IF ls_item-material IS INITIAL and ls_req-purchaseordertype NE 'ZT4'.
        flag = 'E'.
        msg = |'行' { ls_item-outbillitemno } '【物料】不能为空'|.
        RETURN.
      ENDIF.
      IF ls_item-purchaseorderquantityunit IS INITIAL.
        flag = 'E'.
        msg = |'行'{ ls_item-outbillitemno }'【订单单位】不能为空'| .
        RETURN.
      ENDIF.
      IF ls_item-taxcode IS INITIAL.
        flag = 'E'.
        msg = |'行'{ ls_item-outbillitemno }'【税码】不能为空'| .
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_0002.
    LOOP AT lt_req INTO DATA(ls_item).
      IF ls_item-purchaseorder IS INITIAL.
        flag = 'E'.
        msg = |行{ sy-tabix }【SAP采购单号】不能为空|.
        RETURN.
      ENDIF.
      IF ls_item-purchaseorderitem IS INITIAL.
        flag = 'E'.
        msg =  |'行'{ sy-tabix }'【SAP采购单行号】不能为空'| .
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD deal_0001.
    TYPES:BEGIN OF ty_tosubcontractingcomponent,
            material            TYPE string,
            requirementdate     TYPE string,
            quantityinentryunit TYPE string,
            plant               TYPE string,
            entryunit           TYPE string,
          END OF ty_tosubcontractingcomponent,
          BEGIN OF ty_toscheduleline,
            schedulelineorderquantity  TYPE string,
            schedulelinedeliverydate   TYPE string,
            to_subcontractingcomponent TYPE TABLE OF ty_tosubcontractingcomponent WITH DEFAULT KEY,
          END OF ty_toscheduleline,
          BEGIN OF ty_topurorderpricingelement,
            conditiontype           TYPE string,
            conditionrateamount     TYPE string,
            conditionquantity       TYPE string,
            pricingprocedurecounter TYPE string,
            pricingdocumentitem     TYPE string,
            pricingprocedurestep    TYPE string,
          END OF ty_topurorderpricingelement,
          BEGIN OF ty_toaccountassignment,
            masterfixedasset        TYPE string,
            quantity                TYPE string,
            accountassignmentnumber TYPE string,
          END OF ty_toaccountassignment,
          BEGIN OF ty_topurchaseorderitem,
            suppliermaterialnumber         TYPE string,
            purchaseorderitemtext          TYPE string,
            plant                          TYPE string,
            netpriceamount                 TYPE string,
            netpricequantity               TYPE string,
            purchaseorderitemcategory      TYPE string,
            accountassignmentcategory      TYPE string,
            orderquantity                  TYPE string,
            purchaseorderquantityunit      TYPE string,
            material                       TYPE string,
            materialgroup                  TYPE string,
            taxcode                        TYPE string,
            isreturnsitem                  TYPE abap_bool,
            subcontractor                  TYPE string,
            supplierissubcontractor        TYPE abap_bool,
            unlimitedoverdeliveryisallowed TYPE abap_bool,
            to_scheduleline                TYPE TABLE OF  ty_toscheduleline WITH DEFAULT KEY,
            to_purorderpricingelement      TYPE TABLE OF  ty_topurorderpricingelement WITH DEFAULT KEY,
            to_accountassignment           TYPE TABLE OF  ty_toaccountassignment WITH DEFAULT KEY,
          END OF ty_topurchaseorderitem,
          BEGIN OF ty_topurchaseorder,
            supplierrespsalespersonname TYPE string,
            purchaseorder               TYPE string,
            purchaseordertype           TYPE string,
            purchaseorderdate           TYPE string,
            purchasingorganization      TYPE string,
            companycode                 TYPE string,
            purchasinggroup             TYPE string,
            supplier                    TYPE string,
            paymentterms                TYPE string,
            to_purchaseorderitem        TYPE TABLE OF  ty_topurchaseorderitem WITH DEFAULT KEY,
          END OF ty_topurchaseorder.
    DATA:ls_send        TYPE ty_topurchaseorder,
         ls_bomlink     TYPE i_materialbomlink,
         lv_menge       TYPE menge_d,
         lv_pricequalen TYPE i,
         lv_price_6     TYPE p DECIMALS 6,
         lv_price_2     TYPE p DECIMALS 2,
         lv_bs          TYPE i.
    DATA:lv_json TYPE string.
    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.
    TYPES:BEGIN OF ty_heads,
            purchaseorder TYPE string,
          END OF ty_heads,
          BEGIN OF ty_ress,
            d TYPE ty_heads,
          END OF  ty_ress.
    DATA:ls_ress TYPE ty_ress.
    DATA:lv_flag_0                     TYPE char1,
         lv_purchase_order_by_customer TYPE i_salesdocument-purchaseorderbycustomer.
    DATA:lv_supplier               TYPE i_supplierpurchasingorg-supplier,
         lv_purchasingorganization TYPE i_supplierpurchasingorg-purchasingorganization.

    TRY.
        DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).
      CATCH cx_http_dest_provider_error INTO DATA(lx_http_dest_provider_error).
        EXIT.
    ENDTRY.

    "转换采购订单值
    "填充抬头
    ls_send-supplierrespsalespersonname = ls_req-outbillno.
    ls_send-companycode = ls_req-companycode.
    ls_send-purchaseordertype = ls_req-purchaseordertype.
    ls_send-supplier = ls_req-supplier.
    ls_send-purchasingorganization = ls_req-purchasingorganization.
    ls_send-purchasinggroup = ls_req-purchasinggroup.
    lv_supplier = ls_req-supplier.
    lv_supplier = |{ lv_supplier ALPHA = IN }|.
    lv_purchasingorganization = ls_req-purchasingorganization.
    SELECT SINGLE *
             FROM i_supplierpurchasingorg WITH PRIVILEGED ACCESS
            WHERE supplier = @lv_supplier
              AND purchasingorganization = @lv_purchasingorganization
             INTO @DATA(ls_supplierpurchasingorg).
    LOOP AT ls_req-topurchaseorderitem INTO DATA(ls_req_item).
      CLEAR:ls_bomlink.
      APPEND INITIAL LINE TO ls_send-to_purchaseorderitem ASSIGNING FIELD-SYMBOL(<fs_item>).
      IF ls_send-purchaseordertype = 'ZT7'.
        <fs_item>-isreturnsitem = 'X'.
      ENDIF.
      <fs_item>-suppliermaterialnumber = ls_req_item-outbillitemno.
      <fs_item>-plant = ls_req_item-plant.
*      <fs_item>-netpriceamount = ls_req_item-netpriceamount.
*      <fs_item>-netpricequantity = '1'.
      <fs_item>-purchaseorderitemcategory = ls_req_item-purchaseorderitemcategory.
      <fs_item>-accountassignmentcategory = ls_req_item-accountassignmentcategory.
      <fs_item>-orderquantity = ls_req_item-orderquantity.
      <fs_item>-purchaseorderquantityunit = ls_req_item-purchaseorderquantityunit.
      <fs_item>-material = ls_req_item-material.
      <fs_item>-subcontractor = ls_req_item-subcontractor.
      <fs_item>-supplierissubcontractor = ls_req_item-supplierissubcontractor.
      <fs_item>-unlimitedoverdeliveryisallowed = 'X'.
      zcl_com_util=>matnr_zero_in( EXPORTING input  = <fs_item>-material
                                   IMPORTING output = <fs_item>-material ).
      IF ls_req_item-purchaseorderitemtext IS INITIAL.
        SELECT SINGLE productname
                 FROM i_producttext WITH PRIVILEGED ACCESS
                WHERE product = @<fs_item>-material
                  AND language = '1'
                  INTO @ls_req_item-purchaseorderitemtext.
      ELSE.
        <fs_item>-purchaseorderitemtext = ls_req_item-purchaseorderitemtext.
      ENDIF.
      IF ls_req-purchaseordertype = 'ZT4'.
        CLEAR:<fs_item>-material.
        ls_req_item-accountassignmentcategory = 'A'.
        <fs_item>-accountassignmentcategory = ls_req_item-accountassignmentcategory.
      ENDIF.
      IF ls_req_item-accountassignmentcategory = 'A'.
        <fs_item>-materialgroup = '8001'.
        APPEND INITIAL LINE TO <fs_item>-to_accountassignment ASSIGNING FIELD-SYMBOL(<fs_accountassignment>).
        <fs_accountassignment>-masterfixedasset = ls_req_item-masterfixedasset.
        <fs_accountassignment>-quantity = '1'.
*        <fs_accountassignment>-accountassignmentnumber = '1'.
      ENDIF.
      APPEND INITIAL LINE TO <fs_item>-to_purorderpricingelement ASSIGNING FIELD-SYMBOL(<fs_price>).
      <fs_price>-conditiontype = 'PMP0'.
      CONDENSE ls_req_item-netpriceamount NO-GAPS.
      <fs_price>-conditionrateamount = ls_req_item-netpriceamount.
      SPLIT <fs_price>-conditionrateamount AT '.' INTO TABLE DATA(lt_conditionrateamount).
      lv_pricequalen = 1.
      lv_bs          = 1.
      READ TABLE lt_conditionrateamount INTO DATA(ls_conditionrateamount) INDEX 2.
      IF sy-subrc = 0.
        IF strlen( ls_conditionrateamount ) > 2.
          DATA(lv_len) = strlen( ls_conditionrateamount ).
          lv_pricequalen = ( lv_len - 2 ).
          DO lv_pricequalen TIMES.
            lv_bs = lv_bs * 10.
          ENDDO.
        ENDIF.
      ENDIF.
      lv_price_6 = <fs_price>-conditionrateamount.
      lv_price_6 = lv_price_6 * lv_bs.
      lv_price_2 = lv_price_6.
      <fs_price>-conditionrateamount = lv_price_2.
      CONDENSE <fs_price>-conditionrateamount NO-GAPS.
      <fs_price>-conditionquantity = lv_bs.
      CONDENSE <fs_price>-conditionquantity NO-GAPS.
      IF ls_supplierpurchasingorg-calculationschemagroupcode = '01'.
        <fs_price>-pricingprocedurestep = '080'.
      ELSE.
        <fs_price>-pricingprocedurestep = '060'.
      ENDIF.
      <fs_price>-pricingprocedurecounter = '001'.
      APPEND INITIAL LINE TO <fs_item>-to_purorderpricingelement ASSIGNING <fs_price>.
      <fs_price>-conditiontype = 'ZP01'.
      <fs_item>-taxcode = ls_req_item-taxcode.
      <fs_price>-conditionrateamount = zcl_com_util=>get_taxrate_by_code( ls_req_item-taxcode ).
      <fs_price>-pricingprocedurestep = '820'.
      <fs_price>-pricingprocedurecounter = '001'.

      APPEND INITIAL LINE TO <fs_item>-to_scheduleline ASSIGNING FIELD-SYMBOL(<fs_scheduleline>).
      <fs_scheduleline>-schedulelinedeliverydate = ls_req_item-schedulelinedeliverydate.
      IF ls_req_item-purchaseorderitemcategory = '3'.
        SELECT SINGLE   b~unitofmeasure,
                        b~unitofmeasure_e AS unittext
                 FROM i_product WITH PRIVILEGED ACCESS AS a
                 INNER JOIN i_unitofmeasure WITH PRIVILEGED ACCESS AS b
                 ON a~baseunit = b~unitofmeasure
                WHERE product = @<fs_item>-material
                 INTO @DATA(ls_baseunit).
        SELECT SINGLE   b~unitofmeasure,
                        b~unitofmeasure_e AS unittext
                 FROM i_unitofmeasure WITH PRIVILEGED ACCESS AS b
                 INNER JOIN i_productunitsofmeasure WITH PRIVILEGED ACCESS AS a
                   ON b~unitofmeasure = a~alternativeunit
                WHERE unitofmeasure_e = @<fs_item>-purchaseorderquantityunit
                  AND product = @<fs_item>-material
                 INTO @DATA(ls_requnit).
        IF sy-subrc = 0.
*          IF ls_baseunit-unitofmeasure = ls_requnit-unitofmeasure.
*
*          ELSE.
*            CLEAR:lv_menge.
*            lv_menge = ls_req_item-orderquantity.
*            DATA(lo_unit) = cl_uom_conversion=>create( ).
*            lo_unit->unit_conversion_simple( EXPORTING  input                = lv_menge
*                                                        round_sign           = 'X'
*                                                        unit_in              = ls_requnit-unitofmeasure
*                                                        unit_out             = ls_baseunit-unitofmeasure
*                                             IMPORTING  output               = lv_menge
*                                             EXCEPTIONS conversion_not_found = 01
*                                                        division_by_zero     = 02
*                                                        input_invalid        = 03
*                                                        output_invalid       = 04
*                                                        overflow             = 05
*                                                        units_missing        = 06
*                                                        unit_in_not_found    = 07
*                                                        unit_out_not_found   = 08 ).
*            <fs_item>-orderquantity = lv_menge.
*            CONDENSE <fs_item>-orderquantity NO-GAPS.
*          ENDIF.
        ELSE.
          flag = 'E'.
          msg = |物料{ <fs_item>-material }单位{ <fs_item>-purchaseorderquantityunit }不存在|.
          RETURN.
        ENDIF.
        <fs_scheduleline>-schedulelineorderquantity = <fs_item>-orderquantity.
*        CLEAR:<fs_item>-purchaseorderquantityunit.
      ENDIF.
      ls_bomlink-material = <fs_item>-material.
      ls_bomlink-plant = <fs_item>-plant.
      DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
      SELECT b~*
        FROM i_materialbomlink WITH PRIVILEGED ACCESS AS a
        INNER JOIN i_bomcomponentwithkeydate WITH PRIVILEGED ACCESS AS b
          ON a~billofmaterial = b~billofmaterial AND a~billofmaterialcategory = b~billofmaterialcategory
          AND a~billofmaterialvariant = b~billofmaterialvariant
       WHERE a~billofmaterialvariantusage = '1'
         AND a~material = @ls_bomlink-material
         AND a~plant = @ls_bomlink-plant
         AND b~validityenddate >= @lv_date
         AND b~validitystartdate <= @lv_date
         INTO TABLE @DATA(lt_comp).
      SORT lt_comp BY billofmaterial DESCENDING.
      READ TABLE lt_comp INTO DATA(ls_comp_1) INDEX 1.
      IF sy-subrc = 0.
        DELETE lt_comp WHERE billofmaterial NE ls_comp_1-billofmaterial.
      ENDIF.

*      LOOP AT lt_comp[] INTO DATA(ls_req_subcomponent).
*        APPEND INITIAL LINE TO <fs_scheduleline>-to_subcontractingcomponent ASSIGNING FIELD-SYMBOL(<fs_subcomponent>).
*        <fs_subcomponent>-material =  ls_req_subcomponent-billofmaterialcomponent.
*        <fs_subcomponent>-plant =  ls_req_item-plant.
*        <fs_subcomponent>-quantityinentryunit =  ls_req_subcomponent-billofmaterialitemquantity.
**        <fs_subcomponent>-entryunit =  ls_req_subcomponent-billofmaterialitemunit.
**        <fs_subcomponent>-requirementdate = ls_req_item-schedulelinedeliverydate.
*      ENDLOOP.

    ENDLOOP.

    lt_mapping = VALUE #(
           ( abap = 'SupplierRespSalesPersonName'           json = 'SupplierRespSalesPersonName'       )
           ( abap = 'CompanyCode'                           json = 'CompanyCode'                       )
           ( abap = 'PurchaseOrderType'                     json = 'PurchaseOrderType'                 )
           ( abap = 'Supplier'                              json = 'Supplier'                          )
           ( abap = 'PurchasingOrganization'                json = 'PurchasingOrganization'            )
           ( abap = 'PurchasingGroup'                       json = 'PurchasingGroup'                   )

           ( abap = 'to_PurchaseOrderItem'                  json = 'to_PurchaseOrderItem'              )
           ( abap = 'SupplierMaterialNumber'                json = 'SupplierMaterialNumber'            )
           ( abap = 'PurchaseOrderItemText'                 json = 'PurchaseOrderItemText'             )
           ( abap = 'Plant'                                 json = 'Plant'                             )
           ( abap = 'NetPriceAmount'                        json = 'NetPriceAmount'                    )
           ( abap = 'NetPriceQuantity'                      json = 'NetPriceQuantity'                  )
           ( abap = 'PurchaseOrderItemCategory'             json = 'PurchaseOrderItemCategory'         )
           ( abap = 'AccountAssignmentCategory'             json = 'AccountAssignmentCategory'         )
           ( abap = 'OrderQuantity'                         json = 'OrderQuantity'                     )
           ( abap = 'PurchaseOrderQuantityUnit'             json = 'PurchaseOrderQuantityUnit'         )
           ( abap = 'Material'                              json = 'Material'                          )
           ( abap = 'MaterialGroup'                         json = 'MaterialGroup'                     )
           ( abap = 'TaxCode'                               json = 'TaxCode'                           )
           ( abap = 'IsReturnsItem'                         json = 'IsReturnsItem'                     )
           ( abap = 'Subcontractor'                         json = 'Subcontractor'                     )
           ( abap = 'SupplierIsSubcontractor'               json = 'SupplierIsSubcontractor'           )
           ( abap = 'UnlimitedOverdeliveryIsAllowed'        json = 'UnlimitedOverdeliveryIsAllowed'    )

           ( abap = 'to_ScheduleLine'                       json = 'to_ScheduleLine'                   )
           ( abap = 'ScheduleLineOrderQuantity'             json = 'ScheduleLineOrderQuantity'         )
           ( abap = 'ScheduleLineDeliveryDate'              json = 'ScheduleLineDeliveryDate'          )

           ( abap = 'to_SubcontractingComponent'            json = 'to_SubcontractingComponent'        )
           ( abap = 'RequirementDate'                       json = 'RequirementDate'                   )
           ( abap = 'QuantityInEntryUnit'                   json = 'QuantityInEntryUnit'               )
           ( abap = 'EntryUnit'                             json = 'EntryUnit'                         )

           ( abap = 'to_purorderpricingelement'             json = 'to_PurchaseOrderPricingElement'    )
           ( abap = 'ConditionType'                         json = 'ConditionType'                     )
           ( abap = 'ConditionQuantity'                     json = 'ConditionQuantity'                 )
           ( abap = 'ConditionRateAmount'                   json = 'ConditionRateValue'                )
           ( abap = 'PricingProcedureStep'                  json = 'PricingProcedureStep'              )
           ( abap = 'PricingProcedureCounter'               json = 'PricingProcedureCounter'           )

           ( abap = 'to_AccountAssignment'                  json = 'to_AccountAssignment'              )
           ( abap = 'MasterFixedAsset'                      json = 'MasterFixedAsset'                  )
           ( abap = 'AccountAssignmentNumber'               json = 'AccountAssignmentNumber'           )
           ( abap = 'Quantity'                              json = 'Quantity'                          )
           ).

    "传入数据转JSON
    lv_json = /ui2/cl_json=>serialize(
          data          = ls_send
          compress      = abap_true
          pretty_name   = /ui2/cl_json=>pretty_mode-camel_case
          name_mappings = lt_mapping ).

*&---接口HTTP 链接调用
    TRY.
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_request) = lo_http_client->get_http_request(   ).
        lo_http_client->enable_path_prefix( ).

        DATA(lv_uri_path) = |/API_PURCHASEORDER_PROCESS_SRV/A_PurchaseOrder?sap-language=zh|.

        lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        "lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
        lo_http_client->set_csrf_token(  ).

        lo_request->set_content_type( 'application/json' ).

        lo_request->set_text( lv_json ).

*&---执行http post 方法
        DATA(lo_response) = lo_http_client->execute( if_web_http_client=>post ).
*&---获取http reponse 数据
        DATA(lv_res) = lo_response->get_text(  ).
*&---确定http 状态
        DATA(status) = lo_response->get_status( ).
        IF status-code = '201'.

          /ui2/cl_json=>deserialize( EXPORTING json  = lv_res
                                      CHANGING data  = ls_ress ).
          flag  = 'S'.
          msg  = ls_ress-d-purchaseorder.
        ELSE.
          DATA:ls_rese TYPE zzs_odata_fail.
          /ui2/cl_json=>deserialize( EXPORTING json  = lv_res
                                      CHANGING data  = ls_rese ).
          flag = 'E'.
          msg = ls_rese-error-message-value .
          IF ls_rese-error-innererror-errordetails[] IS NOT INITIAL.
            LOOP AT ls_rese-error-innererror-errordetails[] ASSIGNING FIELD-SYMBOL(<fs_error_detail>) WHERE severity = 'error'.
              msg = |{ msg }/{ <fs_error_detail>-message }|.
            ENDLOOP.
          ENDIF.

        ENDIF.
      CATCH cx_http_dest_provider_error INTO DATA(lo_error).
        flag = 'E'.
        msg = '接口调用异常1:' && lo_error->get_longtext( ) .
        RETURN.
      CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
        flag = 'E'.
        msg = '接口调用异常2:' && lx_web_http_client_error->get_longtext( ) .
        RETURN.
    ENDTRY.
    "关闭HTTP链接
    IF lo_http_client IS NOT INITIAL.
      TRY.
          lo_http_client->close( ).
        CATCH cx_web_http_client_error.
          "handle exception
      ENDTRY.
    ENDIF.

  ENDMETHOD.


  METHOD deal_0002.
    LOOP AT lt_req ASSIGNING FIELD-SYMBOL(<fs_req>).
      me->deal_0002_one( IMPORTING flag = flag
                                   msg  = msg
                         CHANGING ls_req = <fs_req> ).
      IF flag = 'E'.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF flag = 'E'.
      ROLLBACK ENTITIES.
    ELSE.
      flag = 'S'.
      msg  = <fs_req>-purchaseorder.
      COMMIT ENTITIES.
    ENDIF.
  ENDMETHOD.


  METHOD deal_0002_one.
    DATA:ls_purchaseorder TYPE i_purchaseorderitemtp_2,
         lv_taxcode       TYPE string,
         lv_taxrate       TYPE i_purchaseorderitemtp_2-netpriceamount.
    ls_purchaseorder-purchaseorder = ls_req-purchaseorder.
    ls_purchaseorder-purchaseorder = |{ ls_purchaseorder-purchaseorder ALPHA = IN }|.
    ls_purchaseorder-purchaseorderitem = ls_req-purchaseorderitem.
    CONDENSE ls_req-orderquantity NO-GAPS.
    ls_purchaseorder-orderquantity = ls_req-orderquantity.
    CONDENSE ls_req-netpriceamount NO-GAPS.
    ls_purchaseorder-netpriceamount = ls_req-netpriceamount.
    ls_purchaseorder-iscompletelydelivered = ls_req-iscompletelydelivered.
    ls_purchaseorder-taxcode = ls_req-taxcode.

    SELECT SINGLE *
             FROM i_purchaseorderitemtp_2 WITH PRIVILEGED ACCESS
            WHERE purchaseorder = @ls_purchaseorder-purchaseorder
              AND purchaseorderitem = @ls_purchaseorder-purchaseorderitem
             INTO @DATA(ls_purchaseorderitemtp_2).
    IF ls_purchaseorder-orderquantity IS INITIAL.
      ls_purchaseorder-orderquantity = ls_purchaseorderitemtp_2-orderquantity.
    ENDIF.
    IF ls_purchaseorder-iscompletelydelivered IS INITIAL.
      ls_purchaseorder-iscompletelydelivered = ls_purchaseorderitemtp_2-iscompletelydelivered.
    ENDIF.
    IF ls_purchaseorder-taxcode IS INITIAL.
      ls_purchaseorder-taxcode = ls_purchaseorderitemtp_2-taxcode.
    ENDIF.

    MODIFY ENTITIES OF i_purchaseordertp_2 PRIVILEGED
     ENTITY purchaseorderitem
     UPDATE
     FIELDS ( orderquantity iscompletelydelivered taxcode )
     WITH VALUE #( ( orderquantity = ls_purchaseorder-orderquantity
                     iscompletelydelivered = ls_purchaseorder-iscompletelydelivered
                     taxcode = ls_purchaseorder-taxcode
     %key-purchaseorder = ls_purchaseorder-purchaseorder
     %key-purchaseorderitem = ls_purchaseorder-purchaseorderitem ) )
     FAILED DATA(failed)
     REPORTED DATA(reported).

    IF failed IS INITIAL.

    ELSE.
      MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno  WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO FINAL(mtext).
      flag = 'E'.
      zcl_com_util=>get_eml_msg( EXPORTING  ls_failed = failed
                                  ls_reported = reported
                                  lv_component = 'PURCHASEORDER'
                IMPORTING msg = msg     ).
      IF msg IS INITIAL.
        zcl_com_util=>get_eml_msg( EXPORTING  ls_failed = failed
                                               ls_reported = reported
                                               lv_component = 'PURCHASEORDERITEM'
                                   IMPORTING msg = msg     ).
      ENDIF.
      msg = |{ msg }'/'{ mtext }|.
      msg = |行{ ls_purchaseorder-purchaseorder }-{ ls_purchaseorder-purchaseorderitem }修改失败:{ msg }|.
      RETURN.
    ENDIF.

    lv_taxcode = ls_purchaseorder-taxcode.
    DATA(lv_taxrate_str) = zcl_com_util=>get_taxrate_by_code( lv_taxcode ).
    lv_taxrate = lv_taxrate_str.
    "税率修改
    SELECT SINGLE *
         FROM i_purordpricingelementtp_2 WITH PRIVILEGED ACCESS
        WHERE purchaseorder = @ls_purchaseorder-purchaseorder
          AND purchaseorderitem = @ls_purchaseorder-purchaseorderitem
          AND conditiontype = 'ZP01'
          INTO @DATA(ls_price).
    IF sy-subrc = 0 AND ls_price-conditionrateamount NE lv_taxrate.
      MODIFY ENTITIES OF i_purchaseordertp_2 PRIVILEGED
           ENTITY purorderitempricingelement
           UPDATE
           FIELDS ( conditionrateamount  )
           WITH VALUE #( ( conditionrateamount = lv_taxrate
             %key-purchaseorder = ls_purchaseorder-purchaseorder
             %key-purchaseorderitem = ls_purchaseorder-purchaseorderitem
             %key-pricingprocedurecounter = ls_price-pricingprocedurecounter
             %key-pricingprocedurestep = ls_price-pricingprocedurestep
             %key-pricingdocument = ls_price-pricingdocument
             %key-pricingdocumentitem = ls_price-pricingdocumentitem  ) )
           FAILED DATA(ls_failed_price)
           REPORTED DATA(ls_reported_price).
      IF ls_failed_price IS NOT INITIAL.
        MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno  WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO FINAL(mtext1).
        flag = 'E'.
        zcl_com_util=>get_eml_msg( EXPORTING  ls_failed = ls_failed_price
                                    ls_reported = ls_reported_price
                                    lv_component = 'PURCHASEORDER'
                  IMPORTING msg = msg     ).
        IF msg IS INITIAL.
          zcl_com_util=>get_eml_msg( EXPORTING  ls_failed = ls_failed_price
                                                 ls_reported = ls_reported_price
                                                 lv_component = 'PURCHASEORDERITEM'
                                     IMPORTING msg = msg     ).
        ENDIF.
        IF msg IS INITIAL.
          zcl_com_util=>get_eml_msg( EXPORTING  ls_failed = ls_failed_price
                                                 ls_reported = ls_reported_price
                                                 lv_component = 'PURORDERITEMPRICINGELEMENT'
                                     IMPORTING msg = msg     ).
        ENDIF.
        msg = |{ msg }'/'{ mtext1 }|.
        msg = |行{ ls_purchaseorder-purchaseorder }-{ ls_purchaseorder-purchaseorderitem }含税单价修改失败:{ msg }|.
        RETURN.
      ENDIF.

    ENDIF.

    "含税单价修改
    SELECT SINGLE *
         FROM i_purordpricingelementtp_2 WITH PRIVILEGED ACCESS
        WHERE purchaseorder = @ls_purchaseorder-purchaseorder
          AND purchaseorderitem = @ls_purchaseorder-purchaseorderitem
          AND conditiontype = 'PMP0'
          INTO @ls_price.
    IF sy-subrc = 0 AND ls_price-conditionrateamount NE ls_purchaseorder-netpriceamount.
      MODIFY ENTITIES OF i_purchaseordertp_2 PRIVILEGED
           ENTITY purorderitempricingelement
           UPDATE
           FIELDS ( conditionrateamount  )
           WITH VALUE #( ( conditionrateamount = ls_purchaseorder-netpriceamount
             %key-purchaseorder = ls_purchaseorder-purchaseorder
             %key-purchaseorderitem = ls_purchaseorder-purchaseorderitem
             %key-pricingprocedurecounter = ls_price-pricingprocedurecounter
             %key-pricingprocedurestep = ls_price-pricingprocedurestep
             %key-pricingdocument = ls_price-pricingdocument
             %key-pricingdocumentitem = ls_price-pricingdocumentitem  ) )
           FAILED DATA(ls_failed_price_1)
           REPORTED DATA(ls_reported_price_1).
      IF ls_failed_price IS NOT INITIAL.
        MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno  WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4 INTO FINAL(mtext2).
        flag = 'E'.
        zcl_com_util=>get_eml_msg( EXPORTING  ls_failed = ls_failed_price_1
                                    ls_reported = ls_reported_price_1
                                    lv_component = 'PURCHASEORDER'
                  IMPORTING msg = msg     ).
        IF msg IS INITIAL.
          zcl_com_util=>get_eml_msg( EXPORTING  ls_failed = ls_failed_price_1
                                                 ls_reported = ls_reported_price_1
                                                 lv_component = 'PURCHASEORDERITEM'
                                     IMPORTING msg = msg     ).
        ENDIF.
        IF msg IS INITIAL.
          zcl_com_util=>get_eml_msg( EXPORTING  ls_failed = ls_failed_price
                                                 ls_reported = ls_reported_price
                                                 lv_component = 'PURORDERITEMPRICINGELEMENT'
                                     IMPORTING msg = msg     ).
        ENDIF.
        msg = |{ msg }'/'{ mtext2 }|.
        msg = |行{ ls_purchaseorder-purchaseorder }-{ ls_purchaseorder-purchaseorderitem }含税单价修改失败:{ msg }|.
        RETURN.
      ENDIF.

    ENDIF.


  ENDMETHOD.


 METHOD  save_zztmm_0001.
   DATA:lt_zztmm_0001 TYPE TABLE OF zztmm_0001.
   SELECT a~purchaseorder,
          b~purchaseorderitem,
          a~supplierrespsalespersonname AS outbillno,
          b~suppliermaterialnumber AS outbillitemno
     FROM i_purchaseorderapi01 WITH PRIVILEGED ACCESS AS a
     INNER JOIN i_purchaseorderitemapi01  WITH PRIVILEGED ACCESS AS b
       ON a~purchaseorder = b~purchaseorder
    WHERE a~purchaseorder = @lv_purchaseorder
      AND b~purchasingdocumentdeletioncode = ''
     INTO TABLE @DATA(lt_data).
   lt_zzt_mmi003_out = CORRESPONDING #( DEEP lt_data ).
   lt_zztmm_0001 = CORRESPONDING #( DEEP lt_data ).
   LOOP AT lt_zztmm_0001 ASSIGNING FIELD-SYMBOL(<fs_zztmm_0001>).
     <fs_zztmm_0001>-zdate = cl_abap_context_info=>get_system_date( ).
     <fs_zztmm_0001>-ztime = cl_abap_context_info=>get_system_time( ).
     <fs_zztmm_0001>-zuser = cl_abap_context_info=>get_user_technical_name( ).
   ENDLOOP.
   MODIFY zztmm_0001 FROM TABLE @lt_zztmm_0001.
 ENDMETHOD.
ENDCLASS.
