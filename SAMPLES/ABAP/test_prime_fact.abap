REPORT ztest_prime_fact.
*----------------------------------------------------------------------*
* Nombres premiers et factorielles en ABAP/4
*
* - Test de primalite par division d'essai jusqu'a sqrt(N)
* - Liste des nombres premiers jusqu'a 50
* - Calcul de N! par boucle WHILE
* - Calcul de N! par appel recursif d'une FORM
*----------------------------------------------------------------------*

DATA: gv_n        TYPE I,
      gv_d        TYPE I,
      gv_limit    TYPE I,
      gv_is_prime TYPE I,
      gv_count    TYPE I,
      gv_max      TYPE I VALUE 50,
      gv_fact     TYPE I,
      gv_i        TYPE I,
      gv_rec_res  TYPE I.

START-OF-SELECTION.

  WRITE: 'Demo nombres premiers et factorielles'.
  SKIP.

*--- Liste des premiers <= 50 ----------------------------------------*
  WRITE: 'Premiers <= 50 :'.
  gv_count = 0.
  gv_n     = 2.
  WHILE gv_n <= gv_max.
    PERFORM is_prime USING gv_n CHANGING gv_is_prime.
    IF gv_is_prime = 1.
      WRITE gv_n.
      ADD 1 TO gv_count.
    ENDIF.
    ADD 1 TO gv_n.
  ENDWHILE.
  SKIP.
  WRITE: 'Total premiers trouves :', gv_count.
  SKIP.

*--- Factorielle iterative -------------------------------------------*
  gv_n    = 10.
  gv_fact = 1.
  gv_i    = 1.
  WHILE gv_i <= gv_n.
    COMPUTE gv_fact = gv_fact * gv_i.
    ADD 1 TO gv_i.
  ENDWHILE.
  WRITE: '10! (iteratif)  =', gv_fact, /.

*--- Factorielle recursive (FORM appelant FORM) ----------------------*
  PERFORM factorial USING 10 CHANGING gv_rec_res.
  WRITE: '10! (recursif)  =', gv_rec_res, /.

  PERFORM factorial USING 7 CHANGING gv_rec_res.
  WRITE: ' 7! (recursif)  =', gv_rec_res, /.

  WRITE: 'Fin demo premiers/factorielles.'.

*======================================================================*
* FORMs
*======================================================================*

*----------------------------------------------------------------------*
* IS_PRIME : 1 si p_n est premier, 0 sinon (division d'essai)
*----------------------------------------------------------------------*
FORM is_prime USING p_n TYPE I CHANGING p_res TYPE I.
  DATA: lv_d     TYPE I,
        lv_lim   TYPE I,
        lv_q     TYPE I,
        lv_r     TYPE I.

  IF p_n < 2.
    p_res = 0.
    EXIT.
  ENDIF.
  IF p_n = 2.
    p_res = 1.
    EXIT.
  ENDIF.
  COMPUTE lv_r = p_n MOD 2.
  IF lv_r = 0.
    p_res = 0.
    EXIT.
  ENDIF.

  lv_d = 3.
  WHILE lv_d * lv_d <= p_n.
    COMPUTE lv_r = p_n MOD lv_d.
    IF lv_r = 0.
      p_res = 0.
      EXIT.
    ENDIF.
    ADD 2 TO lv_d.
  ENDWHILE.
  p_res = 1.
ENDFORM.

*----------------------------------------------------------------------*
* FACTORIAL : factorielle recursive de p_n
*----------------------------------------------------------------------*
FORM factorial USING p_n TYPE I CHANGING p_res TYPE I.
  DATA: lv_sub TYPE I.

  IF p_n <= 1.
    p_res = 1.
    EXIT.
  ENDIF.
  COMPUTE lv_sub = p_n - 1.
  PERFORM factorial USING lv_sub CHANGING p_res.
  COMPUTE p_res = p_res * p_n.
ENDFORM.
