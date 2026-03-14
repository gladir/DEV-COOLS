REPORT ztest_loops.

* ---- Test WHILE / ENDWHILE ----
DATA: lv_count TYPE I VALUE 5.

WHILE lv_count > 0.
  COMPUTE lv_count = lv_count - 1.
ENDWHILE.

* ---- Test DO n TIMES / ENDDO ----
DATA: lv_sum TYPE I VALUE 0.

DO 10 TIMES.
  COMPUTE lv_sum = lv_sum + 1.
ENDDO.

* ---- Test DO infini avec EXIT ----
DATA: lv_iter TYPE I VALUE 0.

DO.
  COMPUTE lv_iter = lv_iter + 1.
  IF lv_iter = 3.
    EXIT.
  ENDIF.
ENDDO.

* ---- Test WHILE avec CONTINUE ----
DATA: lv_val TYPE I VALUE 0.
DATA: lv_idx TYPE I VALUE 0.

WHILE lv_idx < 5.
  COMPUTE lv_idx = lv_idx + 1.
  IF lv_idx = 3.
    CONTINUE.
  ENDIF.
  COMPUTE lv_val = lv_val + lv_idx.
ENDWHILE.
