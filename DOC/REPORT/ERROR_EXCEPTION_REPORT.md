# TODO 23 : GESTION DES ERREURS ET EXCEPTIONS - Rapport d'implémentation

## Résumé

La TODO 23 implémente le système complet de gestion des erreurs et exceptions VAX Pascal dans le compilateur VAXPAS86.

**Avant :** 15 576 lignes | **Après :** 16 231 lignes (+655 lignes)
**Compilation :** 0 erreurs, 2 notes (variables existantes non utilisées)

---

## Fonctionnalités implémentées

### 1. Infrastructure d'erreurs de compilation
- **`Expect(ExpKind, ExpVal)`** : vérifie et consomme un token attendu, émet erreur si absent
- **`SkipTo(StopVal)`** : synchronisation après erreur de syntaxe (skip jusqu'au token stop)
- **`CheckEnabled`** : option booléenne dans `TOptions` pour activer/désactiver les vérifications runtime

### 2. Routines runtime de panique (EmitFooter)
| Routine | Description |
|---------|-------------|
| `_VXPRT_PANIC` | Affiche message ASCIIZ sur stderr, exit code 1 |
| `_VXPRT_PANIC_DIV0` | Division par zéro → EXCCODE=3, route vers handler ou PANIC |
| `_VXPRT_PANIC_OVF` | Overflow entier → EXCCODE=2 |
| `_VXPRT_PANIC_RNG` | Erreur de range → EXCCODE=6 |
| `_VXPRT_PANIC_NIL` | Déréférencement nil → EXCCODE=1 |
| `_VXPRT_SIGNAL` | Signal générique → stocke AX dans EXCCODE, route vers handler |
| `_VXPRT_EXCMSG` | Retourne pointeur message d'exception dans SI selon EXCCODE |

### 3. Segment de données d'exception (EmitDataSeg)
```asm
_VXPRT_EXCHDL  DW  0     ; adresse du handler actif
_VXPRT_EXCSP   DW  0     ; SP sauvegardé
_VXPRT_EXCBP   DW  0     ; BP sauvegardé
_VXPRT_EXCCODE DW  0     ; code de la condition
_VXPRT_EXCVAL  DW  0     ; valeur associée
_VXPRT_EXCPHDL DW  0     ; chaîne parent (handler)
_VXPRT_EXCPSP  DW  0     ; chaîne parent (SP)
_VXPRT_EXCPBP  DW  0     ; chaîne parent (BP)
```
Plus les chaînes de messages d'erreur (DIV0MSG, OVFMSG, RNGMSG, NILMSG, SIGMSG).

### 4. Déclaration CONDITION
```pascal
CONDITION user_error VALUE 200;    { code explicite }
CONDITION file_not_found;           { code auto 100+idx }
```
- Parsing au niveau global (Run) et local (ParseFuncOrProc)
- Symboles enregistrés en SC_CONDITION avec Offset = code

### 5. Conditions prédéfinies VMS (SymInit)
| Symbole | Code | Description |
|---------|------|-------------|
| `ss$_accvio` | 1 | Access violation |
| `ss$_intovf` | 2 | Integer overflow |
| `ss$_intdiv` | 3 | Integer divide by zero |
| `ss$_fltovf` | 4 | Floating overflow |
| `ss$_fltdiv` | 5 | Floating divide by zero |
| `ss$_roprand` | 6 | Reserved operand |
| `ss$_hparith` | 7 | High perf arithmetic trap |

### 6. Bloc BEGIN...EXCEPTION...END (ParseBlock)
Architecture complète avec sauvegarde/restauration de handler par pile :
```
          PUSH [EXCHDL]     ; sauver handler parent
          PUSH [EXCSP]
          PUSH [EXCBP]
          MOV [EXCHDL], handler_label
          MOV [EXCSP], SP
          MOV [EXCBP], BP
          ; ... code protégé ...
          POP [EXCBP]       ; restaurer parent (normal)
          POP [EXCSP]
          POP [EXCHDL]
          JMP end_label
  handler_label:
          POP [EXCBP]       ; restaurer parent (exception)
          POP [EXCSP]
          POP [EXCHDL]
          ; ON cond DO stmt / ANYOTHER / ALLCONDITIONS
          ; RESIGNAL implicite si aucun handler ne matche
  end_label:
```

### 7. SIGNAL / SIGNAL_STOP / RESIGNAL (ParseStatement)
- **`SIGNAL(condition)`** : charge le code condition dans AX, appelle `_VXPRT_SIGNAL`
- **`SIGNAL_STOP(condition)`** : même comportement (non-continuable traité identiquement sur 8086)
- **`RESIGNAL`** : repropage vers handler parent via EXCHDL/EXCSP/EXCBP

### 8. Vérifications runtime
- **Division par zéro** : `TEST BX, BX / JZ _VXPRT_PANIC_DIV0` avant chaque IDIV (div et mod)
- **Déréférencement nil** : `TEST BX, BX / JZ _VXPRT_PANIC_NIL` conditionnel (Opts.CheckEnabled) aux points :
  - Expression p^ (simple déréférencement)
  - Assignment p^.field := expr
  - Assignment p^[i] := expr
  - Assignment p^ := expr

### 9. Fonctions d'exception (ParsePrimary)
- **`exception_message`** : appelle `_VXPRT_EXCMSG`, retourne pointeur string dans AX
- **`exception_value`** : retourne `WORD PTR [_VXPRT_EXCVAL]` dans AX
- Acceptent optionnellement les parenthèses vides ()

### 10. Correction ParseStatement
- Ajout du dispatch d'affectation variable dans ParseStatement pour les identifiants génériques
- Gère : `:=`, `[`, `^`, `.`, `(` après consommation de l'identifiant
- Résout la boucle infinie dans ParseBlock

---

## Fichiers de test

| Fichier | Résultat |
|---------|----------|
| `t_simple.pas` | ✅ EXIT:0 - Compilation simple avec cadre d'exception |
| `t_test_except2.pas` | ✅ EXIT:0 - 1580 lignes ASM, div/0 + signal + nested blocks |
| `test_todo21.pas` | ✅ EXIT:0 - 1826 lignes ASM, régression OK |

---

## Mots-clés ajoutés
- `signal_stop` dans le lexeur (IsKeyword)

## Variables globales ajoutées
- `ExcNestLevel : Integer` — niveau d'imbrication des blocs exception
- `ExcHandlerLabel : TString` — label du handler courant
- `ExcEndLabel : TString` — label de fin de bloc courant
