REPORT ztest_shell.
*----------------------------------------------------------------------*
* Tri Shell-Metzner en ABAP/4
*
* Implementation du tri Shell (Donald L. Shell, 1959) avec la suite
* d'increments originale h = N/2, N/4, ..., 1 (variante dite
* "Shell-Metzner") sur une table interne d'entiers.
*
* L'algorithme effectue, pour chaque ecart h, un tri par insertion
* sur les sous-suites espacees de h elements.
*----------------------------------------------------------------------*

DATA: gt_data TYPE TABLE OF I,
      gv_wa   TYPE I,
      gv_n    TYPE I VALUE 0,
      gv_h    TYPE I,
      gv_i    TYPE I,
      gv_j    TYPE I,
      gv_idx1 TYPE I,
      gv_idx2 TYPE I,
      gv_v1   TYPE I,
      gv_v2   TYPE I,
      gv_temp TYPE I,
      gv_done TYPE I.

START-OF-SELECTION.

  WRITE: 'Demo tri Shell-Metzner ABAP/4'.
  SKIP.

*--- Donnees initiales (volontairement desordonnees) -----------------*
  APPEND 23 TO gt_data.
  APPEND  5 TO gt_data.
  APPEND 89 TO gt_data.
  APPEND 11 TO gt_data.
  APPEND 47 TO gt_data.
  APPEND  3 TO gt_data.
  APPEND 72 TO gt_data.
  APPEND 18 TO gt_data.
  APPEND 56 TO gt_data.
  APPEND 31 TO gt_data.
  APPEND  9 TO gt_data.
  APPEND 64 TO gt_data.
  APPEND  1 TO gt_data.
  APPEND 99 TO gt_data.
  APPEND 42 TO gt_data.
  APPEND 17 TO gt_data.

*--- Comptage des elements ------------------------------------------*
  LOOP AT gt_data INTO gv_wa.
    ADD 1 TO gv_n.
  ENDLOOP.

  WRITE: 'Avant tri (N =', gv_n, ') :'.
  LOOP AT gt_data INTO gv_wa.
    WRITE gv_wa.
  ENDLOOP.
  SKIP.

*--- Tri Shell-Metzner ----------------------------------------------*
* Suite des increments : h = N/2, h = h/2, ..., 1
  COMPUTE gv_h = gv_n DIV 2.

  WHILE gv_h > 0.

*   Tri par insertion sur chaque sous-suite espacee de gv_h
    gv_i = gv_h.
    WHILE gv_i < gv_n.

*     Lecture de l'element a inserer (1-based : index = i+1)
      COMPUTE gv_idx1 = gv_i + 1.
      READ TABLE gt_data INTO gv_temp INDEX gv_idx1.

      gv_j    = gv_i.
      gv_done = 0.

      WHILE gv_j >= gv_h AND gv_done = 0.
        COMPUTE gv_idx2 = gv_j - gv_h + 1.
        READ TABLE gt_data INTO gv_v1 INDEX gv_idx2.
        IF gv_v1 > gv_temp.
          COMPUTE gv_idx1 = gv_j + 1.
          MODIFY gt_data FROM gv_v1 INDEX gv_idx1.
          COMPUTE gv_j = gv_j - gv_h.
        ELSE.
          gv_done = 1.
        ENDIF.
      ENDWHILE.

      COMPUTE gv_idx1 = gv_j + 1.
      MODIFY gt_data FROM gv_temp INDEX gv_idx1.

      ADD 1 TO gv_i.
    ENDWHILE.

*   Reduction de l'ecart
    COMPUTE gv_h = gv_h DIV 2.
  ENDWHILE.

*--- Affichage du resultat ------------------------------------------*
  WRITE: 'Apres tri Shell-Metzner :'.
  LOOP AT gt_data INTO gv_wa.
    WRITE gv_wa.
  ENDLOOP.
  SKIP.

  WRITE: 'Fin demo tri Shell-Metzner.'.
