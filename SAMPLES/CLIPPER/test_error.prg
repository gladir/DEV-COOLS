* test_error.prg - Test de la gestion des erreurs (TODO 21)
* BEGIN SEQUENCE / RECOVER / BREAK / ERRORBLOCK

* --- Test 1 : BEGIN SEQUENCE simple sans BREAK ---
? "Test 1: BEGIN SEQUENCE sans BREAK"
BEGIN SEQUENCE
  ? "  Dans le bloc SEQUENCE"
  ? "  Pas de BREAK"
END SEQUENCE
? "  Apres END SEQUENCE"

* --- Test 2 : BEGIN SEQUENCE avec BREAK ---
? "Test 2: BEGIN SEQUENCE avec BREAK"
BEGIN SEQUENCE
  ? "  Avant BREAK"
  BREAK
  ? "  Apres BREAK (ne devrait pas s afficher)"
RECOVER
  ? "  Dans RECOVER"
END SEQUENCE
? "  Apres END SEQUENCE"

* --- Test 3 : BEGIN SEQUENCE avec BREAK valeur ---
? "Test 3: BREAK avec valeur"
LOCAL oErr
BEGIN SEQUENCE
  ? "  Avant BREAK 42"
  BREAK 42
  ? "  Apres BREAK (ne devrait pas s afficher)"
RECOVER USING oErr
  ? "  Dans RECOVER, erreur =", oErr
END SEQUENCE
? "  Apres END SEQUENCE"

* --- Test 4 : SEQUENCE imbriquees ---
? "Test 4: SEQUENCE imbriquees"
BEGIN SEQUENCE
  ? "  Sequence externe"
  BEGIN SEQUENCE
    ? "  Sequence interne"
    BREAK 99
    ? "  (pas affiche)"
  RECOVER USING oErr
    ? "  Recover interne, err =", oErr
  END SEQUENCE
  ? "  Suite sequence externe"
END SEQUENCE
? "  Fin test 4"

* --- Test 5 : ERRORBLOCK ---
? "Test 5: ERRORBLOCK"
LOCAL bOld
bOld := ERRORBLOCK()
? "  Ancien bloc erreur =", bOld

* --- Fin ---
? "Tous les tests passes!"
RETURN
