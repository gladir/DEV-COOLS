* screen.prg - Exemple Clipper : @ SAY, @ GET, READ, @ TO, CLEAR, couleurs
* Compilation : CLIPPER86 screen.prg

* --- CLEAR SCREEN ---
CLEAR SCREEN

* --- @ row,col SAY ---
@ 0,0 SAY "=== Ecran de saisie Clipper ==="
@ 2,0 SAY "Nom    :"
@ 3,0 SAY "Prenom :"
@ 4,0 SAY "Age    :"
@ 5,0 SAY "Ville  :"

* --- Variables pour GET ---
LOCAL cNom, cPrenom, nAge, cVille
cNom    := SPACE(20)
cPrenom := SPACE(20)
nAge    := 0
cVille  := SPACE(20)

* --- @ GET / READ ---
@ 2,10 SAY "Nom    :" GET cNom
@ 3,10 SAY "Prenom :" GET cPrenom
@ 4,10 SAY "Age    :" GET nAge
@ 5,10 SAY "Ville  :" GET cVille
READ

* --- @ TO : cadre simple ---
@ 7,0 TO 12,40
@ 8,1 SAY "Informations saisies :"
@ 9,1 SAY "Nom    : "
?? TRIM(cNom)
@ 10,1 SAY "Prenom : "
?? TRIM(cPrenom)
@ 11,1 SAY "Age    : "
?? nAge

* --- @ TO DOUBLE : cadre double ---
@ 14,0 TO 18,40 DOUBLE
@ 15,1 SAY "Cadre double"
@ 16,1 SAY "Position curseur :"
@ 17,1 SAY "ROW() ="
?? ROW()
?? " COL() ="
?? COL()

* --- SET COLOR TO ---
SET COLOR TO 14
@ 20,0 SAY "Texte en couleur 14"
SET COLOR TO 7

* --- Dimensions ecran ---
@ 22,0 SAY "MAXROW() ="
?? MAXROW()
?? " MAXCOL() ="
?? MAXCOL()

* --- INKEY et LASTKEY ---
LOCAL nKey
@ 23,0 SAY "Appuyez sur une touche..."
nKey := INKEY()
@ 23,0 SAY "Touche     :"
?? nKey
? "LASTKEY() :", LASTKEY()

? "Fin de screen.prg"
