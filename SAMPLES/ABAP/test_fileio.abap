REPORT ztest_fileio.
*----------------------------------------------------------------------*
* Lecture et ecriture de fichiers en ABAP/4
*
* Demontre l'utilisation des modules de fonctions standard SAP pour
* manipuler des fichiers cote presentation et cote serveur :
*   - GUI_DOWNLOAD     : ecriture d'une table interne dans un fichier
*   - GUI_UPLOAD       : lecture d'un fichier dans une table interne
*   - DATASET_OPEN     : ouverture d'un fichier serveur
*   - DATASET_WRITE_LINE / DATASET_READ_LINE / DATASET_CLOSE
*
* Tous ces modules font partie de l'environnement standard ABAP.
*----------------------------------------------------------------------*

DATA: gv_file    TYPE C LENGTH 60 VALUE '/tmp/abap_demo.txt',
      gv_line    TYPE C LENGTH 80,
      gv_count   TYPE I VALUE 0,
      gv_total   TYPE I VALUE 0,
      gv_handle  TYPE I,
      gv_eof     TYPE I VALUE 0.

DATA: gt_lines   TYPE TABLE OF C.
DATA: gv_wa      TYPE C LENGTH 80.

START-OF-SELECTION.

  WRITE: 'Demo lecture/ecriture de fichiers ABAP/4'.
  SKIP.

*--- Preparation des donnees a ecrire dans une table interne ---------*
  APPEND 'Premiere ligne du fichier'   TO gt_lines.
  APPEND 'Deuxieme ligne du fichier'   TO gt_lines.
  APPEND 'Troisieme ligne du fichier'  TO gt_lines.
  APPEND 'Quatrieme et derniere ligne' TO gt_lines.

  LOOP AT gt_lines INTO gv_wa.
    ADD 1 TO gv_count.
  ENDLOOP.
  WRITE: 'Lignes a ecrire :', gv_count.
  SKIP.

*--- Ecriture du fichier via GUI_DOWNLOAD (presentation) -------------*
  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING filename = gv_file
              filetype = 'ASC'
    TABLES    data_tab = gt_lines
    EXCEPTIONS file_write_error = 1
               OTHERS           = 2.

  IF SY-SUBRC = 0.
    WRITE: 'GUI_DOWNLOAD : ecriture OK'.
  ELSE.
    WRITE: 'GUI_DOWNLOAD : erreur', SY-SUBRC.
  ENDIF.
  SKIP.

*--- Lecture du fichier via GUI_UPLOAD (presentation) ----------------*
  REFRESH gt_lines.

  CALL FUNCTION 'GUI_UPLOAD'
    EXPORTING filename = gv_file
              filetype = 'ASC'
    TABLES    data_tab = gt_lines
    EXCEPTIONS file_open_error = 1
               file_read_error = 2
               OTHERS          = 3.

  IF SY-SUBRC = 0.
    WRITE: 'GUI_UPLOAD : lecture OK'.
    SKIP.
    gv_count = 0.
    LOOP AT gt_lines INTO gv_wa.
      ADD 1 TO gv_count.
      ADD 1 TO gv_total.
      WRITE: gv_count, gv_wa, /.
    ENDLOOP.
    WRITE: 'Lignes lues :', gv_count.
  ELSE.
    WRITE: 'GUI_UPLOAD : erreur', SY-SUBRC.
  ENDIF.
  SKIP.

*--- Acces fichier serveur via DATASET_OPEN / WRITE / CLOSE ---------*
  CALL FUNCTION 'DATASET_OPEN'
    EXPORTING filename = gv_file
              mode     = 'O'
    IMPORTING handle   = gv_handle
    EXCEPTIONS open_error = 1
               OTHERS     = 2.

  IF SY-SUBRC = 0.
    gv_line = 'Ligne ecrite via DATASET_WRITE_LINE'.
    CALL FUNCTION 'DATASET_WRITE_LINE'
      EXPORTING handle = gv_handle
                line   = gv_line.
    CALL FUNCTION 'DATASET_CLOSE'
      EXPORTING handle = gv_handle.
    WRITE: 'Ecriture serveur OK'.
  ELSE.
    WRITE: 'DATASET_OPEN : erreur', SY-SUBRC.
  ENDIF.
  SKIP.

*--- Lecture serveur ligne par ligne --------------------------------*
  CALL FUNCTION 'DATASET_OPEN'
    EXPORTING filename = gv_file
              mode     = 'I'
    IMPORTING handle   = gv_handle
    EXCEPTIONS open_error = 1
               OTHERS     = 2.

  IF SY-SUBRC = 0.
    gv_count = 0.
    gv_eof   = 0.
    DO 1000 TIMES.
      IF gv_eof = 1.
        EXIT.
      ENDIF.
      CALL FUNCTION 'DATASET_READ_LINE'
        EXPORTING handle = gv_handle
        IMPORTING line   = gv_line
        EXCEPTIONS end_of_file = 1
                   OTHERS      = 2.
      IF SY-SUBRC <> 0.
        gv_eof = 1.
      ELSE.
        ADD 1 TO gv_count.
        ADD 1 TO gv_total.
      ENDIF.
    ENDDO.
    CALL FUNCTION 'DATASET_CLOSE'
      EXPORTING handle = gv_handle.
    WRITE: 'Lignes lues serveur :', gv_count.
  ELSE.
    WRITE: 'DATASET_OPEN (lecture) : erreur', SY-SUBRC.
  ENDIF.
  SKIP.

  WRITE: 'Total lignes traitees =', gv_total.
  WRITE: 'Fin demo fileio.'.
