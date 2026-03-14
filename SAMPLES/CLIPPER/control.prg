* control.prg - Exemple Clipper : IF/ELSEIF, DO CASE, DO WHILE, FOR, FOR EACH
* Compilation : CLIPPER86 control.prg

* --- IF / ELSEIF / ELSE / ENDIF ---
LOCAL nNote
nNote := 75

? "Note =", nNote
IF nNote >= 90
  ? "  Mention : Excellent"
ELSEIF nNote >= 80
  ? "  Mention : Tres bien"
ELSEIF nNote >= 70
  ? "  Mention : Bien"
ELSEIF nNote >= 60
  ? "  Mention : Assez bien"
ELSE
  ? "  Mention : Insuffisant"
ENDIF

* --- DO CASE ---
LOCAL cJour
cJour := 3
? "Jour =", cJour
DO CASE
  CASE cJour = 1
    ? "  Lundi"
  CASE cJour = 2
    ? "  Mardi"
  CASE cJour = 3
    ? "  Mercredi"
  CASE cJour = 4
    ? "  Jeudi"
  CASE cJour = 5
    ? "  Vendredi"
  OTHERWISE
    ? "  Week-end"
ENDCASE

* --- DO WHILE : compteur simple ---
LOCAL i
i := 1
? "DO WHILE 1..5 :"
DO WHILE i <= 5
  ?? " "
  ?? i
  i := i + 1
ENDDO
?

* --- DO WHILE avec EXIT ---
? "DO WHILE avec EXIT a 3 :"
i := 0
DO WHILE .T.
  i := i + 1
  IF i > 3
    EXIT
  ENDIF
  ?? " "
  ?? i
ENDDO
?

* --- DO WHILE avec LOOP (skip pair) ---
? "DO WHILE LOOP (impairs 1..10) :"
i := 0
DO WHILE i < 10
  i := i + 1
  IF i % 2 = 0
    LOOP
  ENDIF
  ?? " "
  ?? i
ENDDO
?

* --- FOR / NEXT ---
LOCAL n, sum
sum := 0
FOR n := 1 TO 10
  sum := sum + n
NEXT
? "Somme 1..10 =", sum

* --- FOR avec STEP ---
? "FOR STEP 3 (1..15) :"
FOR n := 1 TO 15 STEP 3
  ?? " "
  ?? n
NEXT
?

* --- FOR descendant ---
? "FOR 5 TO 1 STEP -1 :"
FOR n := 5 TO 1 STEP -1
  ?? " "
  ?? n
NEXT
?

* --- FOR EACH sur un tableau ---
LOCAL aListe, elem
aListe := {10, 20, 30, 40, 50}
? "FOR EACH :"
FOR EACH elem IN aListe
  ?? " "
  ?? elem
NEXT
?

* --- Boucles imbriquees ---
LOCAL r, c, count
count := 0
FOR r := 1 TO 3
  FOR c := 1 TO 4
    count := count + 1
  NEXT
NEXT
? "3x4 iterations =", count

? "Fin de control.prg"
