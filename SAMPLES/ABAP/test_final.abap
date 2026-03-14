REPORT ZTEST_FINAL.

* Test TODO 25 : Generation finale, .OBJ, .EXE et exemples
* =========================================================

* Variables globales
DATA gv_count TYPE I VALUE 5.
DATA gv_name TYPE C LENGTH 20.
DATA gv_total TYPE I.

* Boucle WHILE simple
gv_total = 0.
WHILE gv_total < gv_count.
  gv_total = gv_total + 1.
ENDWHILE.

* IF / ELSEIF / ELSE
IF gv_total = 5.
  WRITE 'Total correct'.
ELSEIF gv_total > 5.
  WRITE 'Trop grand'.
ELSE.
  WRITE 'Trop petit'.
ENDIF.

* DO TIMES
DO 3 TIMES.
  WRITE gv_total.
ENDDO.

* FORM / PERFORM
PERFORM afficher USING gv_total.

FORM afficher USING p_val TYPE I.
  WRITE p_val.
ENDFORM.

* MOVE et CLEAR
MOVE 42 TO gv_total.
WRITE gv_total.
CLEAR gv_total.
WRITE gv_total.

* SKIP
SKIP.
WRITE 'Fin du programme'.
