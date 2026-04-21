REPORT ztest_calendar.
*----------------------------------------------------------------------*
* Calendrier gregorien en ABAP/4
*
* - Calcul des annees bissextiles
* - Nombre de jours de chaque mois
* - Jour de la semaine par la formule de Zeller (calendrier gregorien)
* - Affichage d'un calendrier mensuel
*----------------------------------------------------------------------*

DATA: gv_year   TYPE I VALUE 2026,
      gv_month  TYPE I VALUE 4,
      gv_day    TYPE I,
      gv_leap   TYPE I,
      gv_nbjour TYPE I,
      gv_dow    TYPE I,
      gv_first  TYPE I,
      gv_i      TYPE I,
      gv_col    TYPE I,
      gv_y2     TYPE I,
      gv_m2     TYPE I,
      gv_q      TYPE I,
      gv_k      TYPE I,
      gv_j      TYPE I,
      gv_h      TYPE I,
      gv_tmp    TYPE I.

START-OF-SELECTION.

  WRITE: 'Demo calendrier gregorien ABAP/4'.
  SKIP.
  WRITE: 'Annee :', gv_year, ' Mois :', gv_month.
  SKIP.

*--- Test annee bissextile -------------------------------------------*
  PERFORM is_leap USING gv_year CHANGING gv_leap.
  IF gv_leap = 1.
    WRITE: gv_year, 'est bissextile'.
  ELSE.
    WRITE: gv_year, 'n est pas bissextile'.
  ENDIF.
  SKIP.

*--- Nombre de jours du mois -----------------------------------------*
  PERFORM days_in_month USING gv_year gv_month CHANGING gv_nbjour.
  WRITE: 'Nombre de jours du mois :', gv_nbjour.
  SKIP.

*--- Jour de la semaine du 1er du mois (Zeller) ----------------------*
  gv_day = 1.
  PERFORM zeller USING gv_year gv_month gv_day CHANGING gv_first.
  WRITE: 'Jour de la semaine du 1er (0=Sam,1=Dim,...,6=Ven) :',
         gv_first.
  SKIP.

*--- Affichage du calendrier mensuel ---------------------------------*
  WRITE: 'Di Lu Ma Me Je Ve Sa'.
  SKIP.

* Calcul de la colonne de depart : 0=Dim, 1=Lun, ..., 6=Sam
* Zeller : 0=Sam,1=Dim,2=Lun,...,6=Ven  =>  col = (h + 6) MOD 7
  COMPUTE gv_col = ( gv_first + 6 ) MOD 7.

* Espaces avant le 1er
  gv_i = 0.
  WHILE gv_i < gv_col.
    WRITE '  '.
    ADD 1 TO gv_i.
  ENDWHILE.

* Affichage des jours
  gv_day = 1.
  WHILE gv_day <= gv_nbjour.
    WRITE gv_day.
    ADD 1 TO gv_col.
    IF gv_col = 7.
      gv_col = 0.
      SKIP.
    ENDIF.
    ADD 1 TO gv_day.
  ENDWHILE.
  SKIP.
  SKIP.

  WRITE: 'Fin demo calendrier.'.

*======================================================================*
* FORMs
*======================================================================*

*----------------------------------------------------------------------*
* IS_LEAP : 1 si annee bissextile (regle gregorienne), 0 sinon
*----------------------------------------------------------------------*
FORM is_leap USING p_y TYPE I CHANGING p_res TYPE I.
  DATA: lv_r4   TYPE I,
        lv_r100 TYPE I,
        lv_r400 TYPE I.

  COMPUTE lv_r4   = p_y MOD 4.
  COMPUTE lv_r100 = p_y MOD 100.
  COMPUTE lv_r400 = p_y MOD 400.

  IF lv_r400 = 0.
    p_res = 1.
    EXIT.
  ENDIF.
  IF lv_r100 = 0.
    p_res = 0.
    EXIT.
  ENDIF.
  IF lv_r4 = 0.
    p_res = 1.
  ELSE.
    p_res = 0.
  ENDIF.
ENDFORM.

*----------------------------------------------------------------------*
* DAYS_IN_MONTH : nombre de jours du mois p_m de l annee p_y
*----------------------------------------------------------------------*
FORM days_in_month USING p_y TYPE I p_m TYPE I CHANGING p_res TYPE I.
  DATA: lv_leap TYPE I.

  CASE p_m.
    WHEN 1.  p_res = 31.
    WHEN 2.
      PERFORM is_leap USING p_y CHANGING lv_leap.
      IF lv_leap = 1.
        p_res = 29.
      ELSE.
        p_res = 28.
      ENDIF.
    WHEN 3.  p_res = 31.
    WHEN 4.  p_res = 30.
    WHEN 5.  p_res = 31.
    WHEN 6.  p_res = 30.
    WHEN 7.  p_res = 31.
    WHEN 8.  p_res = 31.
    WHEN 9.  p_res = 30.
    WHEN 10. p_res = 31.
    WHEN 11. p_res = 30.
    WHEN 12. p_res = 31.
    WHEN OTHERS.
      p_res = 0.
  ENDCASE.
ENDFORM.

*----------------------------------------------------------------------*
* ZELLER : jour de la semaine pour la date p_y/p_m/p_d
*          Resultat : 0=Sam, 1=Dim, 2=Lun, 3=Mar, 4=Mer, 5=Jeu, 6=Ven
*          Formule de Zeller pour le calendrier gregorien.
*----------------------------------------------------------------------*
FORM zeller USING p_y TYPE I p_m TYPE I p_d TYPE I CHANGING p_h TYPE I.
  DATA: lv_y    TYPE I,
        lv_m    TYPE I,
        lv_q    TYPE I,
        lv_k    TYPE I,
        lv_j    TYPE I,
        lv_h    TYPE I,
        lv_tmp1 TYPE I,
        lv_tmp2 TYPE I,
        lv_tmp3 TYPE I.

  lv_y = p_y.
  lv_m = p_m.
  IF lv_m < 3.
    ADD 12 TO lv_m.
    SUBTRACT 1 FROM lv_y.
  ENDIF.

  lv_q = p_d.
  COMPUTE lv_k = lv_y MOD 100.
  COMPUTE lv_j = lv_y DIV 100.

  COMPUTE lv_tmp1 = ( 13 * ( lv_m + 1 ) ) DIV 5.
  COMPUTE lv_tmp2 = lv_k DIV 4.
  COMPUTE lv_tmp3 = lv_j DIV 4.

  COMPUTE lv_h = lv_q + lv_tmp1 + lv_k + lv_tmp2 + lv_tmp3 + 5 * lv_j.
  COMPUTE lv_h = lv_h MOD 7.

  p_h = lv_h.
ENDFORM.
