REPORT ztest_triple_loop.
*----------------------------------------------------------------------*
* Triple boucles imbriquees en ABAP/4
*
* - Triple DO/TIMES : produit cartesien et somme triple
* - Triple WHILE    : recherche d'un triplet pythagoricien
* - Triple LOOP AT  : produit de trois tables internes
*----------------------------------------------------------------------*

DATA: gv_i      TYPE I,
      gv_j      TYPE I,
      gv_k      TYPE I,
      gv_total  TYPE I VALUE 0,
      gv_count  TYPE I VALUE 0,
      gv_a      TYPE I,
      gv_b      TYPE I,
      gv_c      TYPE I,
      gv_aa     TYPE I,
      gv_bb     TYPE I,
      gv_cc     TYPE I,
      gv_found  TYPE I VALUE 0,
      gv_prod   TYPE I VALUE 0.

DATA: gt_x TYPE TABLE OF I,
      gt_y TYPE TABLE OF I,
      gt_z TYPE TABLE OF I,
      gv_x TYPE I,
      gv_y TYPE I,
      gv_z TYPE I.

START-OF-SELECTION.

  WRITE: 'Demo triple boucles ABAP/4'.
  SKIP.

*--- Triple DO : somme i*j*k pour i,j,k dans 1..4 --------------------*
  gv_total = 0.
  gv_count = 0.
  DO 4 TIMES.
    gv_i = SY-INDEX.
    DO 4 TIMES.
      gv_j = SY-INDEX.
      DO 4 TIMES.
        gv_k = SY-INDEX.
        ADD 1 TO gv_count.
        COMPUTE gv_prod = gv_i * gv_j * gv_k.
        ADD gv_prod TO gv_total.
      ENDDO.
    ENDDO.
  ENDDO.
  WRITE: 'Triple DO : iterations =', gv_count, /.
  WRITE: 'Triple DO : somme i*j*k =', gv_total, /.
  SKIP.

*--- Triple WHILE : recherche d'un triplet pythagoricien -------------*
  gv_found = 0.
  gv_a = 1.
  WHILE gv_a <= 20 AND gv_found = 0.
    gv_b = gv_a.
    WHILE gv_b <= 20 AND gv_found = 0.
      gv_c = gv_b.
      WHILE gv_c <= 30 AND gv_found = 0.
        COMPUTE gv_aa = gv_a * gv_a.
        COMPUTE gv_bb = gv_b * gv_b.
        COMPUTE gv_cc = gv_c * gv_c.
        IF gv_aa + gv_bb = gv_cc.
          gv_found = 1.
          WRITE: 'Triplet pythagoricien :',
                 gv_a, '^2 +', gv_b, '^2 =', gv_c, '^2', /.
        ENDIF.
        ADD 1 TO gv_c.
      ENDWHILE.
      ADD 1 TO gv_b.
    ENDWHILE.
    ADD 1 TO gv_a.
  ENDWHILE.
  SKIP.

*--- Triple LOOP AT : produit de trois tables ------------------------*
  APPEND 1 TO gt_x. APPEND 2 TO gt_x.
  APPEND 3 TO gt_y. APPEND 4 TO gt_y.
  APPEND 5 TO gt_z. APPEND 6 TO gt_z.

  gv_total = 0.
  gv_count = 0.
  LOOP AT gt_x INTO gv_x.
    LOOP AT gt_y INTO gv_y.
      LOOP AT gt_z INTO gv_z.
        ADD 1 TO gv_count.
        COMPUTE gv_prod = gv_x * gv_y * gv_z.
        ADD gv_prod TO gv_total.
      ENDLOOP.
    ENDLOOP.
  ENDLOOP.
  WRITE: 'Triple LOOP : iterations =', gv_count, /.
  WRITE: 'Triple LOOP : somme produits =', gv_total, /.

  SKIP.
  WRITE: 'Fin demo triple boucles.'.
