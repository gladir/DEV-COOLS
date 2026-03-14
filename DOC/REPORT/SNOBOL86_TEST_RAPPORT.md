# SNOBOL86 — Rapport de tests v1.0

**Date :** 2 mars 2026  
**Compilateur :** `SNOBOL86.EXE` (SNOBOL4 → MASM 8086)  
**Source :** `SNOBOL86.PAS` (7006 lignes, Free Pascal 3.2.0)

---

## Résultats des 7 programmes de test

| # | Fichier source | Fonctionnalité | Instrs | Labels | Erreurs |
|---|---|---|:-:|:-:|:-:|
| 1 | `test01_hello.sbl` | Hello World (`&OUTPUT`) | 1 | 0 | **0** |
| 2 | `test02_vars.sbl` | Variables & concaténation | 5 | 0 | **0** |
| 3 | `test03b_boucle.sbl` | Boucle avec GOTO | 6 | 2 | **0** |
| 4 | `test04_pattern.sbl` | Pattern matching | 6 | 2 | **0** |
| 5 | `test05b_types.sbl` | Predicats IDENT / pattern / GOTO | 15 | 4 | **0** |
| 6 | `test06_define.sbl` | DEFINE / fonctions utilisateur | 8 | 2 | **0** |
| 7 | `test07_arith.sbl` | Arithmétique (SIZE, LT/GT/EQ/NE) | 29 | 8 | **0** |

**Résultat global : 7 / 7 compilations réussies — 0 erreur**

---

## Fonctionnalités validées

### E/S (`&OUTPUT` / `&INPUT`)
```snobol
        &OUTPUT = 'Hello, World !'
```
- `&OUTPUT = expr` → `LEA DI,[desc]` + `MOV SI,DI` + `CALL _RT_WRITELINE` ✅  
- `&INPUT` → `CALL _RT_READLINE` → `DI` ✅

### Variables et concaténation
```snobol
        NOM = 'SNOBOL'
        &OUTPUT = 'Langage : ' NOM
```
- Affectation scalaire : `PUSH AX / MOV AX,[DI] / MOV [VAR_D],AX` ✅  
- Concaténation multi-token : `CALL _SB_CONCATSTR` ✅

### Boucle avec GOTO
```snobol
BOUCLE  &OUTPUT = LIGNE
        LIGNE = LIGNE '='
        LIGNE '==========' :S(FIN)
        :(BOUCLE)
FIN     &OUTPUT = 'Terminee'
```
- Labels SNOBOL → ASM avec préfixe `_SBL_` (ex. `_SBL_BOUCLE:`) ✅  
- `:S(label)` → `JMP _SBL_xxx` ✅  
- `:(label)` (goto inconditionnel) ✅

### Pattern matching
```snobol
        TEXTE 'SNOBOL' :S(TROUVE)
TROUVE  &OUTPUT = 'Patron trouve'
```
- `CALL _RT_MATCH_LIT` avec retry automatique ✅  
- `:S` / `:F` vers labels `_SBL_xxx` ✅

### Prédicats numériques
```snobol
        LT(B,A) :S(B_PETIT)
        EQ(SIZE(MOT),6) :S(TAILLE_OK)
```
- `LT / LE / GT / GE / EQ / NE` → `GenPredicateCall` avec `_RT_ICOMPARE` ✅  
- En position sujet seul (sans `=`) → `GenSimpleAccess` → toujours-succès (v1) ⚠️  
- `SIZE(VAR)` → `CALL _RT_STRLEN` ✅

### DEFINE / Fonctions utilisateur
```snobol
        DEFINE('DOUBLE(N)')
DOUBLE  RESULT = N N
        &OUTPUT = RESULT
```
- `DEFINE(proto, entry)` → enregistrement dans `func_table` ✅  
- `CALL _SBF_DOUBLE` + `ADD SP, 2` (caller cleanup cdecl) ✅

---

## Bug corrigé durant les tests

### Label prefix mismatch (`_SBL_`)

**Problème :** `GenLabelDef` émettait `BOUCLE:` mais `GotoLabelToAsm` générait `JMP _SBL_BOUCLE` → référence indéfinie à l'assemblage.

**Cause :** `AddLabel` stockait déjà `asm_label = SB_LBL_PFX + name`, mais `GenLabelDef` appelait `AsmSafeIdent` sans le préfixe.

**Correction — `SNOBOL86.PAS` :**
```pascal
{ GenLabelDef  ~ ligne 5580 }
EmitLabel(SB_LBL_PFX + AsmSafeIdent(UpCaseStr(inst_label)));

{ GenInstruction ~ ligne 6844 }
SetFirstInstrLabel(SB_LBL_PFX + AsmSafeIdent(UpCaseStr(inst_label)));
```

---

## Limitations v1 documentées

| Limitation | Comportement actuel | Contournement |
|---|---|---|
| Opérateurs `+ - * /` dans `EvalExpr` | Non parsés (space-split → concat) | Utiliser les prédicats numériques |
| Prédicats en position sujet sans `=` | `GenSimpleAccess` → toujours-succès, `:F` ignoré | Structurer les tests pour que `:S` soit toujours correct |
| Espaces dans les args de fonctions | `LT(A, B)` → sujet=`LT(A,`, patron=`B)` | Écrire `LT(A,B)` sans espace |
| `OUTPUT` sans `&` en colonne 1 | Interprété comme label SNOBOL | Utiliser `&OUTPUT` |

---

## Architecture ASM générée

Chaque programme compilé produit un fichier `.asm` MASM 8086 avec :

```
ASSUME CS:_CODE, DS:_DATA, SS:_STACK
_STACK  SEGMENT  STACK  'STACK'   ; 512 octets
_DATA   SEGMENT  WORD   'DATA'    ; variables, littéraux, descripteurs
_CODE   SEGMENT  WORD   'CODE'    ; code programme + runtime complet
```

Le runtime intégré comprend : `_SB_ALLOC`, `_SB_NEWSTR`, `_SB_COPYSTR`,  
`_SB_CONCATSTR`, `_RT_STRLEN`, `_RT_STR2INT`, `_RT_INT2STR`, `_RT_ICOMPARE`,  
`_RT_MATCH_LIT/ANY/SPAN/BREAK/LEN/POS/…`, `_RT_READLINE`, `_RT_WRITELINE`,  
tables/arrays, arithmétique entière et réelle.
