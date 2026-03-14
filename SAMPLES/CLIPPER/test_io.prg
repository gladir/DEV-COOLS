* test_io.prg - Test des entrees/sorties ecran (TODO 12)
* Compilation : CLIPPER86 test_io.prg

* ---- Test ? et ?? (affichage) ----
? "Hello, World!"
? 42
? "Resultat:", 10 + 5
?? "Suite "
?? "sur la meme ligne"
?

* ---- Test CLEAR SCREEN ----
CLEAR SCREEN

* ---- Test @ row,col SAY ----
@ 0,0 SAY "Coin haut-gauche"
@ 5,10 SAY "Position 5,10"
@ 10,20 SAY "Valeur:" 
?? 123

* ---- Test @ row,col TO (cadre) ----
@ 2,5 TO 8,40
@ 3,6 TO 7,39 DOUBLE

* ---- Test SET COLOR TO ----
SET COLOR TO 14

* ---- Test ROW() / COL() / MAXROW() / MAXCOL() ----
LOCAL nRow, nCol
nRow := ROW()
nCol := COL()
? "Curseur a:", nRow, nCol
? "Max:", MAXROW(), MAXCOL()

* ---- Test INKEY() et LASTKEY() ----
LOCAL nKey
nKey := INKEY()
? "Touche:", nKey
? "Derniere touche:", LASTKEY()

* ---- Test @ GET / READ ----
LOCAL cNom
cNom := "Test"
@ 12,0 SAY "Nom:" GET cNom
READ

? "Fin du test I/O"
