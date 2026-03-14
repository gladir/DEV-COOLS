REPORT ZTEST_WRITE.

* Test TODO 14 : WRITE / SKIP / NEW-LINE

DATA: gv_count TYPE I,
      gv_name  TYPE C LENGTH 20,
      gv_total TYPE I.

gv_count = 42.
gv_total = 100.

* WRITE simple avec variable entiere
WRITE gv_count.

* WRITE simple avec chaine litterale
WRITE 'Bonjour le monde'.

* WRITE avec deux-points (forme liste)
WRITE: 'Compteur =', gv_count, /.
WRITE: 'Total =', gv_total.

* WRITE avec / (saut de ligne dans la liste)
WRITE: 'Ligne 1', /, 'Ligne 2', /, 'Ligne 3'.

* WRITE avec nombre litteral
WRITE 12345.

* SKIP sans argument (1 ligne)
SKIP.

* SKIP avec nombre
SKIP 3.

* NEW-LINE
NEW-LINE.

* WRITE avec options de formatage (ignorees pour l instant)
WRITE gv_count LEFT-JUSTIFIED.
WRITE gv_count NO-GAP.

* Test boucle avec WRITE
DO 5 TIMES.
  WRITE: 'iteration', SY-INDEX, /.
ENDDO.
