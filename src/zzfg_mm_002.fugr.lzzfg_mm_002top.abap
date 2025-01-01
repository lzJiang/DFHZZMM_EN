FUNCTION-POOL ZZFG_MM_002.                  "MESSAGE-ID ..

* INCLUDE LZZFG_MM_002D...                   " Local class definition
DATA:gv_BusinessPartner TYPE I_BusinessPartner-BusinessPartner,
     gv_AddressID       TYPE I_BusPartAddress-AddressID,
     gv_flag type bapi_mtype,
     gv_msg  type bapi_msg.
