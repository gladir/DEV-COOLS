REPORT test_control.

* Test CLEAR sur entier
DATA: lv_num TYPE I VALUE 42.
CLEAR lv_num.

* Test CLEAR sur chaine
DATA: lv_str TYPE C LENGTH 20 VALUE 'hello'.
CLEAR lv_str.

* Test REFRESH sur table interne
DATA: lt_tab TYPE TABLE OF I.
APPEND 10 TO lt_tab.
APPEND 20 TO lt_tab.
REFRESH lt_tab.

* Test FREE (stub = REFRESH)
APPEND 30 TO lt_tab.
FREE lt_tab.

* Test CHECK dans une boucle DO
DATA: lv_cnt TYPE I.
DO 5 TIMES.
  ADD 1 TO lv_cnt.
  CHECK lv_cnt < 3.
ENDDO.

* Test STOP
DATA: lv_flag TYPE I VALUE 0.
IF lv_flag = 1.
  STOP.
ENDIF.

* Test RETURN dans une FORM
PERFORM my_form USING 10.

FORM my_form USING p_val TYPE I.
  IF p_val > 5.
    RETURN.
  ENDIF.
  WRITE: p_val.
ENDFORM.
