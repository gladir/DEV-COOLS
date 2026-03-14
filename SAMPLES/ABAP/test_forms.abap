* test_forms.abap - Test PERFORM / FORM / ENDFORM (TODO 13)
REPORT ztest_forms.

DATA: lv_a TYPE I VALUE 10,
      lv_b TYPE I VALUE 20,
      lv_result TYPE I.

* Appel simple sans parametres
PERFORM afficher.

* Appel avec parametres USING (par valeur)
PERFORM add_values USING lv_a lv_b.

* Appel avec USING et CHANGING (par reference)
PERFORM compute_sum USING lv_a lv_b CHANGING lv_result.

*----------------------------------------------------------------------*
* Definitions des FORMs
*----------------------------------------------------------------------*

FORM afficher.
  DATA: lv_msg TYPE I VALUE 42.
ENDFORM.

FORM add_values USING p_a TYPE I p_b TYPE I.
  DATA: lv_sum TYPE I.
  COMPUTE lv_sum = p_a + p_b.
ENDFORM.

FORM compute_sum USING p_x TYPE I p_y TYPE I CHANGING p_res TYPE I.
  COMPUTE p_res = p_x + p_y.
ENDFORM.
