REPORT ZTEST_TABLES.

* Test TODO 16 : LOOP AT / ENDLOOP + tables internes

DATA: lt_nums TYPE TABLE OF I.
DATA: lv_wa   TYPE I.
DATA: lv_sum  TYPE I VALUE 0.

* APPEND : ajouter des elements a la table interne
APPEND 10 TO lt_nums.
APPEND 20 TO lt_nums.
APPEND 30 TO lt_nums.

* LOOP AT ... INTO wa ... ENDLOOP
LOOP AT lt_nums INTO lv_wa.
  ADD lv_wa TO lv_sum.
ENDLOOP.

WRITE: 'Somme:', lv_sum.
SKIP.

* READ TABLE avec INDEX
READ TABLE lt_nums INTO lv_wa INDEX 2.
WRITE: 'Element 2:', lv_wa.
SKIP.

* DELETE par INDEX
DELETE lt_nums INDEX 1.

* SORT (stub)
SORT lt_nums.

WRITE 'Fin test tables.'.
