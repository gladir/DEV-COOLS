REPORT test_dispatch.

* Test TODO 23 : dispatcher complet et stubs

* Test PARAMETERS (stub)
PARAMETERS p_count TYPE I DEFAULT 5.

* Test START-OF-SELECTION event (stub)
START-OF-SELECTION.

DATA: lv_x TYPE I VALUE 10.
DATA: lv_y TYPE I VALUE 20.

* Test TRY / CATCH / ENDTRY (stub)
TRY.
  lv_x = 42.
  WRITE: lv_x.
CATCH cx_root.
  WRITE: 'Exception attrapee'.
ENDTRY.

* Test TRY / CATCH / CLEANUP / ENDTRY (stub)
TRY.
  lv_y = 99.
CATCH cx_sy_arithmetic_error.
  WRITE: 'Erreur arithmetique'.
CLEANUP.
  WRITE: 'Cleanup effectue'.
ENDTRY.

* Test RAISE (stub)
RAISE EXCEPTION TYPE cx_root.

* Test END-OF-SELECTION event (stub)
END-OF-SELECTION.

WRITE: 'Fin du programme'.
