REPORT ZTEST_EVENTS.

* Test TODO 24 : Evenements ABAP et ecran de selection
* ====================================================

* Ecran de selection : PARAMETERS avec DEFAULT
PARAMETERS p_count TYPE I DEFAULT 10.
PARAMETERS p_name TYPE C.

* Ecran de selection : SELECT-OPTIONS avec FOR
DATA gv_num TYPE I.
SELECT-OPTIONS s_num FOR gv_num.

* TRY / CATCH / CLEANUP / ENDTRY avec labels
DATA gv_val TYPE I.
TRY.
  gv_val = 42.
  WRITE gv_val.
CATCH cx_root.
  WRITE 'Exception attrapee'.
CLEANUP.
  WRITE 'Nettoyage'.
ENDTRY.

* TOP-OF-PAGE et END-OF-PAGE (stubs)
TOP-OF-PAGE.
END-OF-PAGE.

* RAISE stub
DATA gv_flag TYPE I.
gv_flag = 1.
IF gv_flag = 0.
  RAISE EXCEPTION TYPE cx_root.
ENDIF.

* Evenement START-OF-SELECTION avec bloc
START-OF-SELECTION.
  WRITE 'Debut du traitement'.
  DATA lv_i TYPE I.
  lv_i = p_count.
  WRITE lv_i.

* Evenement END-OF-SELECTION avec bloc
END-OF-SELECTION.
  WRITE 'Fin du traitement'.
