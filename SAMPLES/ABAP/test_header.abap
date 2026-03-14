REPORT ZTEST_HEADER.
* Test TODO 18 - EN-TETE ASSEMBLEUR ET SEGMENT .DATA
* Verifie la generation de l'en-tete ASM 80386 et du segment .DATA

DATA: lv_count TYPE I VALUE 42,
      lv_name  TYPE C LENGTH 20,
      lv_total TYPE I.

COMPUTE lv_total = lv_count + 8.

WRITE: 'Compteur:', lv_count.
WRITE: / 'Nom:', lv_name.
WRITE: / 'Total:', lv_total.
