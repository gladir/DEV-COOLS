* test_if.prg - Test IF/ELSEIF/ELSE/ENDIF et DO CASE (TODO 13)
* Compilation : CLIPPER86 test_if.prg

* ---- Test 1 : IF simple (vrai) ----
LOCAL x
x := 10
IF x = 10
  ? "Test 1: x is 10"
ENDIF

* ---- Test 2 : IF simple (faux) ----
IF x = 99
  ? "ERREUR: ne devrait pas s afficher"
ENDIF
? "Test 2: IF faux passe"

* ---- Test 3 : IF / ELSE ----
LOCAL y
y := 5
IF y = 10
  ? "ERREUR"
ELSE
  ? "Test 3: y n est pas 10"
ENDIF

* ---- Test 4 : IF / ELSEIF / ELSE ----
LOCAL z
z := 20
IF z = 10
  ? "ERREUR"
ELSEIF z = 20
  ? "Test 4: z is 20"
ELSEIF z = 30
  ? "ERREUR"
ELSE
  ? "ERREUR"
ENDIF

* ---- Test 5 : IF / ELSEIF sans ELSE (derniere branche) ----
IF z = 10
  ? "ERREUR"
ELSEIF z = 20
  ? "Test 5: ELSEIF branch"
ENDIF

* ---- Test 6 : IF imbrique ----
LOCAL a, b
a := 1
b := 2
IF a = 1
  IF b = 2
    ? "Test 6: imbrique OK"
  ENDIF
ENDIF

* ---- Test 7 : DO CASE simple ----
LOCAL code
code := 2
DO CASE
  CASE code = 1
    ? "ERREUR"
  CASE code = 2
    ? "Test 7: case 2"
  CASE code = 3
    ? "ERREUR"
ENDCASE

* ---- Test 8 : DO CASE avec OTHERWISE ----
LOCAL val
val := 99
DO CASE
  CASE val = 1
    ? "ERREUR"
  CASE val = 2
    ? "ERREUR"
  OTHERWISE
    ? "Test 8: otherwise"
ENDCASE

* ---- Test 9 : DO CASE premier match ----
DO CASE
  CASE .T.
    ? "Test 9: premier case vrai"
  CASE .T.
    ? "ERREUR: ne devrait pas s afficher"
ENDCASE

* ---- Test 10 : IF avec comparaison > ----
LOCAL n
n := 15
IF n > 20
  ? "grand"
ELSEIF n > 10
  ? "Test 10: moyen"
ELSE
  ? "petit"
ENDIF

? "Fin des tests IF/CASE"
