REPORT ZTEST_CASE.
* Test du CASE / WHEN / WHEN OTHERS / ENDCASE (TODO 11)

DATA: lv_code TYPE I VALUE 2.
DATA: lv_res  TYPE I VALUE 0.

CASE lv_code.
  WHEN 1.
    COMPUTE lv_res = 10.
  WHEN 2.
    COMPUTE lv_res = 20.
  WHEN 3 OR 4.
    COMPUTE lv_res = 30.
  WHEN OTHERS.
    COMPUTE lv_res = 99.
ENDCASE.
