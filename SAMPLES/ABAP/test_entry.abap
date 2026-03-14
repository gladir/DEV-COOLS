REPORT ZTEST_ENTRY.
* Test TODO 19 : Point d entree Win32 et helpers runtime
* Verifie la generation du point d entree _ABF_main
* et des routines runtime (PRINTCHR, READINT, READSTR, etc.)

DATA: lv_x TYPE I VALUE 10,
      lv_y TYPE I VALUE 20,
      lv_r TYPE I,
      lv_msg TYPE C LENGTH 30.

* Test COMPUTE (utilise PRINTINT -> NUMTOSTR + PRINT)
COMPUTE lv_r = lv_x + lv_y.

* Test WRITE (utilise PRINT, PRINTINT, CRLF, STRLEN)
WRITE: 'Somme:', lv_r.
WRITE: /.
WRITE: 'Fin du test TODO 19'.
