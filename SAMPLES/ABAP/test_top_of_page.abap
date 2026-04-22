REPORT ztest_top_of_page.
*----------------------------------------------------------------------*
* Demontre les evenements TOP-OF-PAGE et END-OF-PAGE.
* TOP-OF-PAGE est appele avant START-OF-SELECTION (entete).
* END-OF-PAGE est appele apres END-OF-SELECTION (pied de page).
*----------------------------------------------------------------------*
DATA: gv_i TYPE I.

TOP-OF-PAGE.
  WRITE '=== EN-TETE DE PAGE ==='.
  SKIP.
  WRITE 'Rapport demonstration TOP-OF-PAGE'.
  SKIP.

END-OF-PAGE.
  SKIP.
  WRITE '=== PIED DE PAGE ==='.
  SKIP.

START-OF-SELECTION.
  WRITE 'Corps du rapport :'.
  SKIP.
  DO 3 TIMES.
    gv_i = SY-INDEX.
    WRITE 'Ligne'. WRITE gv_i. SKIP.
  ENDDO.

END-OF-SELECTION.
  WRITE 'Fin du traitement.'.
  SKIP.
