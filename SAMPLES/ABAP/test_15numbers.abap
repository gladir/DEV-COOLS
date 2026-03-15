REPORT ZTEST_15NUM.
* Test: Afficher les nombres de 1 a 15 dans une boucle
* Chaque nombre doit apparaitre sur une ligne separee

DATA: GV_I TYPE I VALUE 0.

WRITE 'Les 15 nombres:'.
SKIP.

DO 15 TIMES.
  ADD 1 TO GV_I.
  WRITE GV_I.
  SKIP.
ENDDO.

WRITE 'Fin.'.
