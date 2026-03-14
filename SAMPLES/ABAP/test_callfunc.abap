REPORT test_callfunc.

* Test CALL FUNCTION avec EXPORTING (stub)
DATA: lv_result TYPE I.
CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
  EXPORTING input = 42
  IMPORTING output = lv_result.

* Test SY-SUBRC apres CALL FUNCTION
IF SY-SUBRC = 0.
  WRITE: 'Appel OK'.
ENDIF.

* Test CALL FUNCTION avec TABLES et EXCEPTIONS
DATA: lt_data TYPE TABLE OF I.
CALL FUNCTION 'RFC_READ_TABLE'
  EXPORTING query_table = 1
  TABLES data = lt_data
  EXCEPTIONS table_not_available = 1
             OTHERS = 2.

* Test CALL FUNCTION simple sans clauses
CALL FUNCTION 'POPUP_TO_CONFIRM'.

* Test FUNCTION / ENDFUNCTION
FUNCTION my_func.
  DATA: lv_x TYPE I.
  lv_x = 10.
  WRITE: lv_x.
ENDFUNCTION.
