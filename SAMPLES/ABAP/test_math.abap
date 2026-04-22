REPORT ztest_math.
*----------------------------------------------------------------------*
* Operations mathematiques en ABAP/4
*
* Couvre : COMPUTE avec les operateurs +, -, *, /, MOD, DIV,
*          ABS (valeur absolue), puissance entiere, racine carree
*          calculee par la methode de Newton, et somme harmonique.
*----------------------------------------------------------------------*

DATA: gv_a       TYPE I VALUE  17,
      gv_b       TYPE I VALUE   5,
      gv_c       TYPE I VALUE -42,
      gv_res     TYPE I,
      gv_quot    TYPE I,
      gv_rem     TYPE I,
      gv_pow     TYPE I,
      gv_base    TYPE I,
      gv_exp     TYPE I,
      gv_i       TYPE I,
      gv_sqrt    TYPE I,
      gv_x       TYPE I,
      gv_prev    TYPE I,
      gv_iter    TYPE I,
      gv_n       TYPE I,
      gv_harm    TYPE I.

START-OF-SELECTION.

  WRITE: 'Demo mathematique ABAP/4'.
  SKIP.

*--- Operations arithmetiques de base --------------------------------*
  COMPUTE gv_res = gv_a + gv_b.
  WRITE: 'a + b =', gv_res, /.

  COMPUTE gv_res = gv_a - gv_b.
  WRITE: 'a - b =', gv_res, /.

  COMPUTE gv_res = gv_a * gv_b.
  WRITE: 'a * b =', gv_res, /.

  COMPUTE gv_quot = gv_a DIV gv_b.
  COMPUTE gv_rem  = gv_a MOD gv_b.
  WRITE: 'a DIV b =', gv_quot, /.
  WRITE: 'a MOD b =', gv_rem, /.

*--- Valeur absolue --------------------------------------------------*
  IF gv_c < 0.
    COMPUTE gv_res = 0 - gv_c.
  ELSE.
    gv_res = gv_c.
  ENDIF.
  WRITE: 'ABS(c) =', gv_res, /.
  SKIP.

*--- Puissance entiere : base ^ exp par boucle -----------------------*
  gv_base = 2.
  gv_exp  = 10.
  gv_pow  = 1.
  gv_i    = 0.
  WHILE gv_i < gv_exp.
    COMPUTE gv_pow = gv_pow * gv_base.
    ADD 1 TO gv_i.
  ENDWHILE.
  WRITE: '2 ^ 10 =', gv_pow, /.

*--- Racine carree entiere par methode de Newton ---------------------*
  gv_n    = 12345.
  gv_x    = gv_n.
  gv_prev = 0.
  gv_iter = 0.
  WHILE gv_x <> gv_prev.
    gv_prev = gv_x.
    COMPUTE gv_x = ( gv_x + gv_n DIV gv_x ) DIV 2.
    ADD 1 TO gv_iter.
    IF gv_iter > 50.
      EXIT.
    ENDIF.
  ENDWHILE.
  gv_sqrt = gv_x.
  WRITE: 'sqrt(12345) ~', gv_sqrt, '(iterations:', gv_iter, ')', /.
  SKIP.

*--- Somme harmonique entiere : sum(1..N) ---------------------------*
  gv_harm = 0.
  gv_i    = 1.
  WHILE gv_i <= 100.
    ADD gv_i TO gv_harm.
    ADD 1 TO gv_i.
  ENDWHILE.
  WRITE: 'Somme 1..100 =', gv_harm, /.

  WRITE: 'Fin demo math.'.
