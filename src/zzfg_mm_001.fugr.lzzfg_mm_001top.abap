FUNCTION-POOL zzfg_mm_001.                  "MESSAGE-ID ..

* INCLUDE LZZFG_MM_001D...                   " Local class definition

DATA:gt_item TYPE zzt_mmi001_item_in.
DATA:gv_wmsflag TYPE abap_boolean,
     gv_mblnr   TYPE i_materialdocumentitem_2-materialdocument,
     gv_year    TYPE i_materialdocumentitem_2-materialdocumentyear.
