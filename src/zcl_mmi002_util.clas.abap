CLASS zcl_mmi002_util DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    METHODS check_0002
      IMPORTING ls_req TYPE zzs_mmi002_head_in
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg.
    METHODS deal_0002
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi002_head_in.
    METHODS deal_0002_modify
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi002_head_in.
    METHODS deal_0002_delete
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi002_head_in.
    METHODS deal_0002_delete_one
      EXPORTING flag                   TYPE bapi_mtype
                msg                    TYPE bapi_msg
      CHANGING  businesspartner        TYPE i_businesspartner-businesspartner
                supplier               TYPE i_supplierpurchasingorg-supplier
                purchasingorganization TYPE i_supplierpurchasingorg-purchasingorganization.
    METHODS deal_0002_modify_basis
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi002_head_in.
    METHODS deal_0002_modify_address
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi002_head_in.
    METHODS deal_0002_modify_bank
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi002_head_in.
    METHODS deal_0002_modify_tax
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi002_head_in.
    METHODS deal_0002_modify_purorg
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi002_head_in.
    METHODS deal_0002_modify_purorg_one
      EXPORTING flag                   TYPE bapi_mtype
                msg                    TYPE bapi_msg
      CHANGING  ls_req                 TYPE zzs_mmi002_head_in
                businesspartner        TYPE i_businesspartner-businesspartner
                supplier               TYPE i_supplierpurchasingorg-supplier
                purchasingorganization TYPE i_supplierpurchasingorg-purchasingorganization.
    METHODS deal_0002_modify_scompany
      EXPORTING flag   TYPE bapi_mtype
                msg    TYPE bapi_msg
      CHANGING  ls_req TYPE zzs_mmi002_head_in.
    METHODS deal_0002_modify_scompany_one
      EXPORTING flag            TYPE bapi_mtype
                msg             TYPE bapi_msg
      CHANGING  ls_req          TYPE zzs_mmi002_head_in
                businesspartner TYPE i_businesspartner-businesspartner
                supplier               TYPE i_supplierpurchasingorg-supplier
                companycode     TYPE i_suppliercompany-companycode.

PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_MMI002_UTIL IMPLEMENTATION.


  METHOD check_0002.
    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    IF ls_req IS INITIAL.
      flag = 'E'.
      msg = |'传入项目为空'| .
      RETURN.
    ENDIF.

    "1.检查抬头
    IF ls_req-actioncode NE '01' AND ls_req-actioncode NE '02'.
      flag = 'E'.
      msg = '【操作类型】传入值不存在，请检查'.
      RETURN.
    ENDIF.
    IF ls_req-businesspartner IS INITIAL.
      flag = 'E'.
      msg = '【SAP供应商编码】不能为空'.
      RETURN.
    ELSE.
      lv_businesspartner = ls_req-businesspartner.
      lv_businesspartner = |{ lv_businesspartner ALPHA = IN }|.
      SELECT SINGLE *
               FROM i_businesspartner WITH PRIVILEGED ACCESS
              WHERE businesspartner = @lv_businesspartner
              INTO @DATA(ls_purchaseorder).
      IF sy-subrc NE 0.
        flag = 'E'.
        msg = |SAP供应商编码{ ls_req-businesspartner }不存在,请检查' |.
        RETURN.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD deal_0002.
    CASE ls_req-actioncode.
      WHEN '01'.
        me->deal_0002_modify( IMPORTING flag = flag
                                        msg  = msg
                              CHANGING  ls_req = ls_req ).
      WHEN '02'.
        me->deal_0002_delete( IMPORTING flag = flag
                                        msg  = msg
                              CHANGING  ls_req = ls_req ).
    ENDCASE.
  ENDMETHOD.


  METHOD deal_0002_delete.
    "删除操作则把供应商所有采购组织视图打删除标记
    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = ls_req-businesspartner.
    lv_businesspartner = |{ lv_businesspartner ALPHA = IN }|.
    SELECT c~*
      FROM i_businesspartner WITH PRIVILEGED ACCESS AS a
      INNER JOIN i_suppliertobusinesspartner WITH PRIVILEGED ACCESS AS b
        ON a~BusinessPartnerUUID = b~BusinessPartnerUUID
      INNER JOIN i_supplierpurchasingorg WITH PRIVILEGED ACCESS AS c
        ON b~supplier = c~supplier
      WHERE a~BusinessPartner = @lv_businesspartner
        AND deletionindicator IS INITIAL
       INTO TABLE @DATA(lt_supplierpurchasingorg).
    LOOP AT lt_supplierpurchasingorg INTO DATA(ls_supplierpurchasingorg).
      me->deal_0002_delete_one( IMPORTING flag = flag
                                          msg  = msg
                            CHANGING  businesspartner = lv_businesspartner
                                      supplier = ls_supplierpurchasingorg-supplier
                                      purchasingorganization =  ls_supplierpurchasingorg-purchasingorganization ).
      IF flag = 'E'.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF flag NE 'E'.
      flag = 'S'.
      msg  = lv_businesspartner.
    ENDIF.
  ENDMETHOD.


  METHOD deal_0002_delete_one.
    TYPES:BEGIN OF ty_supplierpurchasingorg,
            deletionindicator TYPE abap_bool,
          END OF ty_supplierpurchasingorg,
          BEGIN OF ty_udata,
            d TYPE ty_supplierpurchasingorg,
          END OF ty_udata.
    DATA:lv_json TYPE string.
    DATA:ls_udata TYPE ty_udata.


    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.

    DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

    lt_mapping = VALUE #(
         ( abap = 'd'                            json = 'd'                    )
         ( abap = 'DeletionIndicator'          json = 'DeletionIndicator'  )
       ).
    ls_udata-d-deletionindicator = 'X'.
*&---接口HTTP 链接调用
    TRY.
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_request) = lo_http_client->get_http_request(   ).
        lo_http_client->enable_path_prefix( ).

        DATA(lv_uri_path) = |/API_BUSINESS_PARTNER/A_SupplierPurchasingOrg|
        && |(Supplier='{ businesspartner }',PurchasingOrganization='{ purchasingorganization }')|.

        lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
        lo_http_client->set_csrf_token(  ).

        lo_request->set_content_type( 'application/json' ).
        "传入数据转JSON
        lv_json = /ui2/cl_json=>serialize(
              data          = ls_udata
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
          flag = 'E'.
          msg = |采购组织{ purchasingorganization }下供应商删除失败:{ ls_rese-error-message-value }| .
        ENDIF.

        FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

      CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
        DATA(lv_msg) = lx_web_http_client_error->get_longtext( ).
        flag = 'E'.
        msg = |采购组织{ purchasingorganization }下供应商删除失败:{ lv_msg }| .
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


  METHOD deal_0002_modify.
    "修改操作根据传入的字段修改相应的视图
    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = ls_req-businesspartner.
    lv_businesspartner = |{ lv_businesspartner ALPHA = IN }|.
    "基本视图
    IF ls_req-organizationbpname1 IS NOT INITIAL OR ls_req-searchterm1 IS NOT INITIAL.
      me->deal_0002_modify_basis( IMPORTING flag = flag
                                            msg  = msg
                                  CHANGING  ls_req = ls_req ).
      IF flag = 'E'.
        RETURN.
      ENDIF.
    ENDIF.
    "地址视图
    IF ls_req-streetname IS NOT INITIAL.
      me->deal_0002_modify_address( IMPORTING flag = flag
                                            msg  = msg
                                  CHANGING  ls_req = ls_req ).
      IF flag = 'E'.
        RETURN.
      ENDIF.
    ENDIF.
    "银行视图
    IF ls_req-bankname IS NOT INITIAL OR ls_req-bankaccount IS NOT INITIAL.
      me->deal_0002_modify_bank( IMPORTING flag = flag
                                            msg  = msg
                                  CHANGING  ls_req = ls_req ).
      IF flag = 'E'.
        RETURN.
      ENDIF.
    ENDIF.
    "税号视图
    IF ls_req-bptaxlongnumber IS NOT INITIAL.
      me->deal_0002_modify_tax( IMPORTING flag = flag
                                            msg  = msg
                                  CHANGING  ls_req = ls_req ).
      IF flag = 'E'.
        RETURN.
      ENDIF.
    ENDIF.
    "供应商采购视图
    IF ls_req-organizationbpname1 IS NOT INITIAL or ls_req-currency IS NOT INITIAL .
      me->deal_0002_modify_purorg( IMPORTING flag = flag
                                            msg  = msg
                                  CHANGING  ls_req = ls_req ).
      IF flag = 'E'.
        RETURN.
      ENDIF.
    ENDIF.
    "供应商公司视图
    IF ls_req-reconciliationaccount IS NOT INITIAL.
      me->deal_0002_modify_scompany( IMPORTING flag = flag
                                            msg  = msg
                                  CHANGING  ls_req = ls_req ).
      IF flag = 'E'.
        RETURN.
      ENDIF.
    ENDIF.

    IF flag NE 'E'.
      flag = 'S'.
      msg  = ls_req-businesspartner.
    ENDIF.
  ENDMETHOD.


  METHOD deal_0002_modify_address.
    TYPES:BEGIN OF ty_data,
            streetname TYPE string,
          END OF ty_data,
          BEGIN OF ty_udata,
            d TYPE ty_data,
          END OF ty_udata.
    DATA:lv_json TYPE string.
    DATA:ls_udata TYPE ty_udata.


    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.
    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = ls_req-businesspartner.
    lv_businesspartner = |{ lv_businesspartner ALPHA = IN }|.

    DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

      SELECT SINGLE a~*
        FROM i_buspartaddress WITH PRIVILEGED ACCESS AS a
       WHERE a~businesspartner = @lv_businesspartner
        INTO @data(ls_buspartaddress).

    lt_mapping = VALUE #(
         ( abap = 'd'                            json = 'd'                    )
         ( abap = 'streetname'                   json = 'StreetName'  )
       ).
    ls_udata-d-streetname = ls_req-streetname.
*&---接口HTTP 链接调用
    TRY.
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_request) = lo_http_client->get_http_request(   ).
        lo_http_client->enable_path_prefix( ).

        DATA(lv_uri_path) = |/API_BUSINESS_PARTNER/A_BusinessPartnerAddress|
        && |(BusinessPartner='{ lv_businesspartner }',AddressID='{ ls_buspartaddress-AddressID }')|.

        lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
        lo_http_client->set_csrf_token(  ).

        lo_request->set_content_type( 'application/json' ).
        "传入数据转JSON
        lv_json = /ui2/cl_json=>serialize(
              data          = ls_udata
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
          flag = 'E'.
          msg = |供应商地址视图修改失败:{ ls_rese-error-message-value }| .
        ENDIF.

        FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

      CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
        DATA(lv_msg) = lx_web_http_client_error->get_longtext( ).
        flag = 'E'.
        msg = |供应商地址视图修改失败:{ lv_msg }| .
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


  METHOD deal_0002_modify_bank.
    TYPES:BEGIN OF ty_data,
            bankname                 TYPE string,
            bankaccount              TYPE string,
            bankaccountreferencetext TYPE string,
          END OF ty_data,
          BEGIN OF ty_udata,
            d TYPE ty_data,
          END OF ty_udata.
    DATA:lv_json TYPE string.
    DATA:ls_udata TYPE ty_udata.


    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.
    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = ls_req-businesspartner.
    lv_businesspartner = |{ lv_businesspartner ALPHA = IN }|.

    DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

    SELECT SINGLE a~*
      FROM i_businesspartnerbank WITH PRIVILEGED ACCESS AS a
     WHERE a~businesspartner = @lv_businesspartner
      INTO @DATA(ls_businesspartnerbank).

    lt_mapping = VALUE #(
         ( abap = 'd'                            json = 'd'            )
         ( abap = 'bankname'                     json = 'BankAccountHolderName'     )
         ( abap = 'bankaccount'                  json = 'BankAccount'  )
         ( abap = 'bankaccountreferencetext'     json = 'BankAccountReferenceText'  )
       ).

    IF ls_req-bankname IS NOT INITIAL.
      ls_udata-d-bankname = ls_req-bankname.
    ELSE.
      ls_udata-d-bankname = ls_businesspartnerbank-bankname.
    ENDIF.

    IF ls_req-bankaccount IS NOT INITIAL.
      ls_udata-d-bankaccount = ls_req-bankaccount.
      IF strlen( ls_req-bankaccount ) > 18.
        ls_udata-d-bankaccountreferencetext = ls_req-bankaccount+18.
        ls_udata-d-bankaccount = ls_req-bankaccount+0(18).
      ENDIF.
    ELSE.
      ls_udata-d-bankaccount = ls_businesspartnerbank-bankaccount.
    ENDIF.

*&---接口HTTP 链接调用
    TRY.
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_request) = lo_http_client->get_http_request(   ).
        lo_http_client->enable_path_prefix( ).

        DATA(lv_uri_path) = |/API_BUSINESS_PARTNER/A_BusinessPartnerBank|
        && |(BusinessPartner='{ lv_businesspartner }',BankIdentification='{ ls_businesspartnerbank-bankidentification }')|.

        lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
        lo_http_client->set_csrf_token(  ).

        lo_request->set_content_type( 'application/json' ).
        "传入数据转JSON
        lv_json = /ui2/cl_json=>serialize(
              data          = ls_udata
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
          flag = 'E'.
          msg = |供应商银行视图修改失败:{ ls_rese-error-message-value }| .
        ENDIF.

        FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

      CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
        DATA(lv_msg) = lx_web_http_client_error->get_longtext( ).
        flag = 'E'.
        msg = |供应商银行视图修改失败:{ lv_msg }| .
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


  METHOD deal_0002_modify_basis.
    TYPES:BEGIN OF ty_data,
            organizationbpname1 TYPE string,
            searchterm1         TYPE string,
          END OF ty_data,
          BEGIN OF ty_udata,
            d TYPE ty_data,
          END OF ty_udata.
    DATA:lv_json TYPE string.
    DATA:ls_udata TYPE ty_udata.


    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.
    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = ls_req-businesspartner.
    lv_businesspartner = |{ lv_businesspartner ALPHA = IN }|.

    DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

    SELECT SINGLE *
             FROM i_businesspartner
            WHERE businesspartner = @lv_businesspartner
              INTO @DATA(ls_businesspartner).

    lt_mapping = VALUE #(
         ( abap = 'd'                            json = 'd'                    )
         ( abap = 'OrganizationBPName1'          json = 'OrganizationBPName1'  )
         ( abap = 'SearchTerm1'                  json = 'SearchTerm1'  )
       ).
    IF ls_req-organizationbpname1 IS NOT INITIAL.
      ls_udata-d-organizationbpname1 = ls_req-organizationbpname1.
    ELSE.
      ls_udata-d-organizationbpname1 = ls_businesspartner-organizationbpname1.
    ENDIF.

    IF ls_req-searchterm1 IS NOT INITIAL.
      ls_udata-d-searchterm1 = ls_req-searchterm1.
    ELSE.
      ls_udata-d-searchterm1 = ls_businesspartner-searchterm1.
    ENDIF.
*&---接口HTTP 链接调用
    TRY.
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_request) = lo_http_client->get_http_request(   ).
        lo_http_client->enable_path_prefix( ).

        DATA(lv_uri_path) = |/API_BUSINESS_PARTNER/A_BusinessPartner|
        && |('{ lv_businesspartner }')|.

        lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
        lo_http_client->set_csrf_token(  ).

        lo_request->set_content_type( 'application/json' ).
        "传入数据转JSON
        lv_json = /ui2/cl_json=>serialize(
              data          = ls_udata
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
          flag = 'E'.
          msg = |供应商基本视图修改失败:{ ls_rese-error-message-value }| .
        ENDIF.

        FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

      CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
        DATA(lv_msg) = lx_web_http_client_error->get_longtext( ).
        flag = 'E'.
        msg = |供应商基本视图修改失败:{ lv_msg }| .
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


  METHOD deal_0002_modify_purorg.
    "修改操作则把供应商所有采购组织视图相应字段做修改
    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = ls_req-businesspartner.
    lv_businesspartner = |{ lv_businesspartner ALPHA = IN }|.
    SELECT c~*
      FROM i_businesspartner WITH PRIVILEGED ACCESS AS a
      INNER JOIN i_suppliertobusinesspartner WITH PRIVILEGED ACCESS AS b
        ON a~BusinessPartnerUUID = b~BusinessPartnerUUID
      INNER JOIN i_supplierpurchasingorg WITH PRIVILEGED ACCESS AS c
        ON b~supplier = c~supplier
      WHERE a~BusinessPartner = @lv_businesspartner
        AND deletionindicator IS INITIAL
       INTO TABLE @DATA(lt_supplierpurchasingorg).
    LOOP AT lt_supplierpurchasingorg INTO DATA(ls_supplierpurchasingorg).
      me->deal_0002_modify_purorg_one( IMPORTING flag = flag
                                                 msg  = msg
                            CHANGING  ls_req = ls_req
                                      businesspartner = lv_businesspartner
                                      supplier = ls_supplierpurchasingorg-supplier
                                      purchasingorganization =  ls_supplierpurchasingorg-purchasingorganization ).
      IF flag = 'E'.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF flag NE 'E'.
      flag = 'S'.
    ENDIF.
  ENDMETHOD.


  METHOD deal_0002_modify_purorg_one.
    TYPES:BEGIN OF ty_data,
            purchaseordercurrency TYPE string,
            incotermslocation1    TYPE string,
          END OF ty_data,
          BEGIN OF ty_udata,
            d TYPE ty_data,
          END OF ty_udata.
    DATA:lv_json TYPE string.
    DATA:ls_udata TYPE ty_udata.


    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.

    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = businesspartner.

    DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

    SELECT SINGLE a~*
      FROM i_supplierpurchasingorg WITH PRIVILEGED ACCESS AS a
     WHERE a~supplier = @supplier
       and a~PurchasingOrganization = @purchasingorganization
      INTO @DATA(ls_supplierpurchasingorg).

    lt_mapping = VALUE #(
         ( abap = 'd'                            json = 'd'            )
         ( abap = 'purchaseordercurrency'        json = 'PurchaseOrderCurrency'     )
         ( abap = 'IncotermsLocation1'           json = 'IncotermsLocation1'  )
       ).

    IF ls_req-currency IS NOT INITIAL.
      ls_udata-d-purchaseordercurrency = ls_req-currency.
    ELSE.
      ls_udata-d-purchaseordercurrency = ls_supplierpurchasingorg-purchaseordercurrency.
    ENDIF.

    IF ls_req-organizationbpname1 IS NOT INITIAL.
      ls_udata-d-incotermslocation1 = ls_req-organizationbpname1.
    ELSE.
      ls_udata-d-incotermslocation1 = ls_supplierpurchasingorg-incotermslocation1.
    ENDIF.
*&---接口HTTP 链接调用
    TRY.
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_request) = lo_http_client->get_http_request(   ).
        lo_http_client->enable_path_prefix( ).

        DATA(lv_uri_path) = |/API_BUSINESS_PARTNER/A_SupplierPurchasingOrg|
        && |(Supplier='{ supplier }',PurchasingOrganization='{ purchasingorganization }')|.

        lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
        lo_http_client->set_csrf_token(  ).

        lo_request->set_content_type( 'application/json' ).
        "传入数据转JSON
        lv_json = /ui2/cl_json=>serialize(
              data          = ls_udata
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
          flag = 'E'.
          msg = |采购组织{ purchasingorganization }下供应商修改失败:{ ls_rese-error-message-value }| .
        ENDIF.

        FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

      CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
        DATA(lv_msg) = lx_web_http_client_error->get_longtext( ).
        flag = 'E'.
        msg = |采购组织{ purchasingorganization }下供应商修改失败:{ lv_msg }| .
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


  METHOD deal_0002_modify_scompany.
    "修改操作则把供应商所有公司视图相应字段做修改
    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = ls_req-businesspartner.
    lv_businesspartner = |{ lv_businesspartner ALPHA = IN }|.
    SELECT c~*
      FROM i_businesspartner WITH PRIVILEGED ACCESS AS a
      INNER JOIN i_suppliertobusinesspartner WITH PRIVILEGED ACCESS AS b
        ON a~businesspartneruuid = b~businesspartneruuid
      INNER JOIN i_suppliercompany WITH PRIVILEGED ACCESS AS c
        ON b~supplier = c~supplier
      WHERE a~businesspartner = @lv_businesspartner
       INTO TABLE @DATA(lt_suppliercompany).
    LOOP AT lt_suppliercompany INTO DATA(ls_suppliercompany).
      me->deal_0002_modify_scompany_one( IMPORTING flag = flag
                                                 msg  = msg
                            CHANGING  ls_req = ls_req
                                      businesspartner = lv_businesspartner
                                      supplier = ls_suppliercompany-supplier
                                      companycode =  ls_suppliercompany-companycode ).
      IF flag = 'E'.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF flag NE 'E'.
      flag = 'S'.
    ENDIF.
  ENDMETHOD.


  METHOD deal_0002_modify_scompany_one.
    TYPES:BEGIN OF ty_data,
            reconciliationaccount TYPE string,
          END OF ty_data,
          BEGIN OF ty_udata,
            d TYPE ty_data,
          END OF ty_udata.
    DATA:lv_json TYPE string.
    DATA:ls_udata TYPE ty_udata.


    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.

    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = businesspartner.

    DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

    SELECT SINGLE a~*
      FROM i_suppliercompany WITH PRIVILEGED ACCESS AS a
     WHERE a~supplier = @supplier
       AND a~companycode = @companycode
      INTO @DATA(ls_suppliercompany).

    lt_mapping = VALUE #(
         ( abap = 'd'                            json = 'd'            )
         ( abap = 'reconciliationaccount'        json = 'ReconciliationAccount'     )
       ).

    IF ls_req-reconciliationaccount IS NOT INITIAL.
      ls_udata-d-reconciliationaccount = ls_req-reconciliationaccount.
    ELSE.
      ls_udata-d-reconciliationaccount = ls_suppliercompany-reconciliationaccount.
    ENDIF.

*&---接口HTTP 链接调用
    TRY.
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_request) = lo_http_client->get_http_request(   ).
        lo_http_client->enable_path_prefix( ).

        DATA(lv_uri_path) = |/API_BUSINESS_PARTNER/A_SupplierCompany|
        && |(Supplier='{ supplier }',CompanyCode='{ companycode }')|.

        lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
        lo_http_client->set_csrf_token(  ).

        lo_request->set_content_type( 'application/json' ).
        "传入数据转JSON
        lv_json = /ui2/cl_json=>serialize(
              data          = ls_udata
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
          flag = 'E'.
          msg = |公司{ companycode }下供应商修改失败:{ ls_rese-error-message-value }| .
        ENDIF.

        FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

      CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
        DATA(lv_msg) = lx_web_http_client_error->get_longtext( ).
        flag = 'E'.
        msg = |公司{ companycode }下供应商修改失败:{ lv_msg }| .
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


METHOD deal_0002_modify_tax.
    TYPES:BEGIN OF ty_data,
            bptaxlongnumber TYPE string,
          END OF ty_data,
          BEGIN OF ty_udata,
            d TYPE ty_data,
          END OF ty_udata.
    DATA:lv_json TYPE string.
    DATA:ls_udata TYPE ty_udata.


    DATA:lt_mapping TYPE /ui2/cl_json=>name_mappings.
    DATA:lv_businesspartner TYPE i_businesspartner-businesspartner.
    lv_businesspartner = ls_req-businesspartner.
    lv_businesspartner = |{ lv_businesspartner ALPHA = IN }|.

    DATA(lo_dest) = zzcl_comm_tool=>get_dest( ).

    SELECT SINGLE a~*
      FROM i_businesspartnertaxnumber WITH PRIVILEGED ACCESS AS a
     WHERE a~businesspartner = @lv_businesspartner
      INTO @DATA(ls_businesspartnertaxnumber).

    lt_mapping = VALUE #(
         ( abap = 'd'                            json = 'd'            )
         ( abap = 'BPTaxLongNumber'                     json = 'BPTaxLongNumber'     )
       ).

    IF ls_req-bptaxlongnumber IS NOT INITIAL.
      ls_udata-d-bptaxlongnumber = ls_req-bptaxlongnumber.
    ELSE.
      ls_udata-d-bptaxlongnumber = ls_businesspartnertaxnumber-bptaxlongnumber.
    ENDIF.

*&---接口HTTP 链接调用
    TRY.
        DATA(lo_http_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).
        DATA(lo_request) = lo_http_client->get_http_request(   ).
        lo_http_client->enable_path_prefix( ).

        DATA(lv_uri_path) = |/API_BUSINESS_PARTNER/A_BusinessPartnerTaxNumber|
        && |(BusinessPartner='{ lv_businesspartner }',BPTaxType='{ ls_businesspartnertaxnumber-bptaxtype }')|.

        lo_request->set_uri_path( EXPORTING i_uri_path = lv_uri_path ).
        lo_request->set_header_field( i_name = 'Accept' i_value = 'application/json' ).
        lo_request->set_header_field( i_name = 'If-Match' i_value = '*' ).
        lo_http_client->set_csrf_token(  ).

        lo_request->set_content_type( 'application/json' ).
        "传入数据转JSON
        lv_json = /ui2/cl_json=>serialize(
              data          = ls_udata
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
          flag = 'E'.
          msg = |供应商税号视图修改失败:{ ls_rese-error-message-value }| .
        ENDIF.

        FREE:lo_http_client,lo_request,lv_uri_path,lo_request.

      CATCH cx_web_http_client_error INTO DATA(lx_web_http_client_error).
        DATA(lv_msg) = lx_web_http_client_error->get_longtext( ).
        flag = 'E'.
        msg = |供应商税号视图修改失败:{ lv_msg }| .
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
ENDCLASS.
