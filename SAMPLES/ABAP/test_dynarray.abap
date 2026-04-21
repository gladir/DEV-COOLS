REPORT ztest_dynarray.
*----------------------------------------------------------------------*
* Tableaux dynamiques (tables internes) en ABAP/4
*
* Demontre les operations classiques sur une table interne :
*   APPEND, INSERT INDEX, MODIFY INDEX, DELETE INDEX, READ TABLE,
*   SORT, LOOP AT et boucles de calculs (somme, min, max, moyenne).
*----------------------------------------------------------------------*

DATA: gt_data TYPE TABLE OF I,
      gv_wa   TYPE I,
      gv_idx  TYPE I,
      gv_n    TYPE I,
      gv_sum  TYPE I VALUE 0,
      gv_min  TYPE I VALUE 999999,
      gv_max  TYPE I VALUE 0,
      gv_avg  TYPE I,
      gv_cnt  TYPE I VALUE 0.

START-OF-SELECTION.

  WRITE: 'Demo tableau dynamique ABAP/4'.
  SKIP.

*--- Remplissage initial : suite 5, 10, 15, ..., 50 ------------------*
  gv_n = 5.
  DO 10 TIMES.
    APPEND gv_n TO gt_data.
    ADD 5 TO gv_n.
  ENDDO.

*--- Insertion en tete -----------------------------------------------*
  gv_wa = 1.
  INSERT gv_wa INTO gt_data INDEX 1.

*--- Modification de l'element a l'index 5 ---------------------------*
  gv_wa = 99.
  MODIFY gt_data FROM gv_wa INDEX 5.

*--- Suppression de l'element a l'index 3 ----------------------------*
  DELETE gt_data INDEX 3.

*--- Lecture par index -----------------------------------------------*
  READ TABLE gt_data INTO gv_wa INDEX 1.
  IF SY-SUBRC = 0.
    WRITE: 'Premier element :', gv_wa, /.
  ENDIF.

  READ TABLE gt_data INTO gv_wa INDEX 7.
  IF SY-SUBRC = 0.
    WRITE: 'Septieme element :', gv_wa, /.
  ENDIF.
  SKIP.

*--- Tri ascendant ---------------------------------------------------*
  SORT gt_data ASCENDING.

*--- Parcours complet et calcul des statistiques --------------------*
  WRITE: 'Contenu trie :'.
  LOOP AT gt_data INTO gv_wa.
    gv_idx = SY-TABIX.
    WRITE: gv_idx, gv_wa, /.
    ADD 1     TO gv_cnt.
    ADD gv_wa TO gv_sum.
    IF gv_wa > gv_max.
      gv_max = gv_wa.
    ENDIF.
    IF gv_wa < gv_min.
      gv_min = gv_wa.
    ENDIF.
  ENDLOOP.
  SKIP.

  WRITE: 'Nombre elements :', gv_cnt, /.
  WRITE: 'Somme           :', gv_sum, /.
  WRITE: 'Minimum         :', gv_min, /.
  WRITE: 'Maximum         :', gv_max, /.

  IF gv_cnt > 0.
    COMPUTE gv_avg = gv_sum DIV gv_cnt.
    WRITE: 'Moyenne (DIV)   :', gv_avg, /.
  ENDIF.

  SKIP.
  WRITE: 'Fin demo tableau dynamique.'.
