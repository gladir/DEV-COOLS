REPORT ZTEST01.
* Programme de test ABAP86 - TODO 25
* Calcul de la somme 1+2+...+N et affichage

DATA: GV_N   TYPE I VALUE 10,
      GV_I   TYPE I VALUE 1,
      GV_SUM TYPE I VALUE 0,
      GV_MAX TYPE I VALUE 100.

DATA: GV_MSG TYPE C VALUE 'Debut du programme'.
DATA: GV_SEP TYPE C VALUE '---'.

START-OF-SELECTION.
  GV_SUM = 0.
  GV_I   = 1.

  WRITE: 'Programme ABAP86 - Test complet'.
  SKIP.

* Boucle WHILE : somme de 1 a GV_N
  WHILE GV_I <= GV_N.
    ADD GV_I TO GV_SUM.
    ADD 1 TO GV_I.
  ENDWHILE.

  WRITE: 'Somme 1..N = ', GV_SUM.
  SKIP.

* Test de la structure IF/ELSEIF/ELSE
  IF GV_SUM > GV_MAX.
    WRITE: 'Somme > 100'.
  ELSEIF GV_SUM = 55.
    WRITE: 'Somme = 55 (correct pour N=10)'.
  ELSE.
    WRITE: 'Resultat inattendu'.
  ENDIF.
  SKIP.

* Test DO ... TIMES
  GV_I = 0.
  DO 3 TIMES.
    ADD 1 TO GV_I.
  ENDDO.
  WRITE: 'Compteur apres DO 3 TIMES =', GV_I.
  SKIP.

* Appel FORM
  PERFORM AFFICHER_BILAN.
  SKIP.

* Test MOVE
  MOVE 42 TO GV_SUM.
  WRITE: 'Apres MOVE 42 TO GV_SUM =', GV_SUM.
  SKIP.

* Test CLEAR
  CLEAR GV_SUM.
  WRITE: 'Apres CLEAR GV_SUM =', GV_SUM.
  SKIP.

  WRITE: 'Fin du programme.'.

FORM AFFICHER_BILAN.
  WRITE: '--- Bilan de calcul ---'.
  WRITE: 'N   =', GV_N.
  WRITE: 'Max =', GV_MAX.
ENDFORM.
