REPORT ZTEST_MOVE.

* Test TODO 15 : MOVE / COMPUTE / FORMES VERBALES ARITHMETIQUES

DATA: gv_a TYPE I VALUE 10,
      gv_b TYPE I VALUE 3,
      gv_c TYPE I VALUE 0,
      gv_r TYPE I VALUE 0.

* Test MOVE source TO destination
MOVE 42 TO gv_a.
WRITE: 'MOVE 42 TO gv_a =', gv_a.

* Test COMPUTE var = expr
COMPUTE gv_b = gv_a + 8.
WRITE: 'COMPUTE gv_b = gv_a + 8 =', gv_b.

* Test assignation directe (style ABAP Objet)
gv_c = gv_a * 2.
WRITE: 'gv_c = gv_a * 2 =', gv_c.

* Test ADD val TO var
gv_r = 0.
ADD 10 TO gv_r.
WRITE: 'ADD 10 TO gv_r =', gv_r.

* Test ADD val1 TO val2 GIVING var
ADD gv_a TO gv_b GIVING gv_c.
WRITE: 'ADD gv_a TO gv_b GIVING gv_c =', gv_c.

* Test SUBTRACT val FROM var
gv_r = 100.
SUBTRACT 30 FROM gv_r.
WRITE: 'SUBTRACT 30 FROM gv_r =', gv_r.

* Test MULTIPLY var BY val
gv_r = 7.
MULTIPLY gv_r BY 6.
WRITE: 'MULTIPLY gv_r BY 6 =', gv_r.

* Test DIVIDE var BY val
gv_r = 84.
DIVIDE gv_r BY 4.
WRITE: 'DIVIDE gv_r BY 4 =', gv_r.

* Test CLEAR variable
CLEAR gv_r.
WRITE: 'CLEAR gv_r =', gv_r.

WRITE: 'Fin test TODO 15.'.
