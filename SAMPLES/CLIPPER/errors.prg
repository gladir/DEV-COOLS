* errors.prg - Exemple Clipper : BEGIN SEQUENCE, RECOVER, BREAK, ERRORBLOCK
* Compilation : CLIPPER86 errors.prg

* --- Sequence simple sans erreur ---
? "Test 1 : Sequence sans BREAK"
BEGIN SEQUENCE
  ? "  Execution normale"
  ? "  Pas d erreur"
END SEQUENCE
? "  Suite apres sequence"

* --- Sequence avec BREAK ---
? "Test 2 : Sequence avec BREAK"
BEGIN SEQUENCE
  ? "  Avant le BREAK"
  BREAK
  ? "  (ne s affiche pas)"
RECOVER
  ? "  Dans le RECOVER"
END SEQUENCE
? "  Suite apres recover"

* --- BREAK avec valeur ---
? "Test 3 : BREAK avec valeur"
LOCAL oErr
BEGIN SEQUENCE
  ? "  Envoi de BREAK 42"
  BREAK 42
  ? "  (ne s affiche pas)"
RECOVER USING oErr
  ? "  Erreur recue :", oErr
END SEQUENCE

* --- Sequences imbriquees ---
? "Test 4 : Sequences imbriquees"
BEGIN SEQUENCE
  ? "  Sequence externe"
  BEGIN SEQUENCE
    ? "  Sequence interne"
    BREAK 99
    ? "  (pas affiche)"
  RECOVER USING oErr
    ? "  Recover interne :", oErr
  END SEQUENCE
  ? "  Suite sequence externe"
END SEQUENCE
? "  Fin test 4"

* --- ERRORBLOCK ---
? "Test 5 : ERRORBLOCK"
LOCAL bOld
bOld := ERRORBLOCK()
? "  Bloc erreur actuel :", bOld

* --- Sequence sans RECOVER ---
? "Test 6 : Sequence sans RECOVER"
BEGIN SEQUENCE
  ? "  Code normal"
END SEQUENCE
? "  Fin normale"

? "Tous les tests erreurs passes!"
RETURN
