REPORT test_select.

* Test SELECT SINGLE (stub sans BD)
DATA: lv_name TYPE C LENGTH 20.
SELECT SINGLE * FROM ztable INTO lv_name WHERE id = 1.

* Test SY-SUBRC apres SELECT
IF SY-SUBRC <> 0.
  WRITE: 'Non trouve'.
ENDIF.

* Test SELECT avec ENDSELECT (boucle vide)
DATA: lv_val TYPE I.
SELECT * FROM ztable INTO lv_val.
  ADD 1 TO lv_val.
ENDSELECT.

* Test SELECT avec ORDER BY et UP TO n ROWS
SELECT * FROM ztable INTO lv_val
  WHERE status = 1
  ORDER BY name
  UP TO 10 ROWS.
  WRITE: lv_val.
ENDSELECT.

* Test SELECT INTO TABLE
DATA: lt_result TYPE TABLE OF I.
SELECT * FROM ztable INTO TABLE lt_result
  WHERE active = 1.

* Test SELECT CORRESPONDING FIELDS
DATA: ls_data TYPE I.
SELECT SINGLE * FROM ztable
  INTO CORRESPONDING FIELDS OF ls_data
  WHERE id = 5.
