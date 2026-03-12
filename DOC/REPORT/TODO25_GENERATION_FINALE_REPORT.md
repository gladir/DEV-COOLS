# TODO 25 — GENERATION FINALE ET FICHIERS EXEMPLES

## Résumé

TODO 25 complété avec succès. Le pipeline de compilation est vérifié, 30 fichiers exemples créés, et tous passent le smoke test (30/30 OK, 0 FAIL, 0 HANG).

## Pipeline de compilation (8 étapes)

La procédure `Run` orchestre les 8 étapes suivantes (déjà implémentées avant TODO 25) :

| # | Étape | Description |
|---|-------|-------------|
| 1 | `LexInit` | Initialisation du lexer |
| 2 | `SymInitBuiltins` | Enregistrement des types et fonctions intégrées |
| 3 | `PreprocessFile` | Préprocesseur (%INCLUDE, %IF, %DEFINE, etc.) |
| 4 | `EmitHeader` | En-tête assembleur (.MODEL SMALL, DGROUP, _TEXT SEGMENT) |
| 5 | `ParseProgram` | Analyse syntaxique + génération de code |
| 6 | `EmitFooter` | Clôture du segment de code (_TEXT ENDS) |
| 7 | `EmitDataSeg` | Segment de données (_DATA SEGMENT / ENDS) |
| 8 | `EmitClose` | END _VXPF_main |

## Fichiers exemples (30 fichiers dans `SAMPLES\VAXPASCAL\`)

### Batch 1 (1-15)
| # | Fichier | Description |
|---|---------|-------------|
| 1 | hello.pas | Programme minimal Hello World |
| 2 | test_var.pas | Variables de différents types |
| 3 | test_const.pas | Constantes et constantes typées |
| 4 | test_expr.pas | Expressions arithmétiques et logiques |
| 5 | test_types.pas | Déclarations de types (alias, sous-types) |
| 6 | test_string.pas | Opérations sur les chaînes |
| 7 | test_func.pas | Fonctions et procédures |
| 8 | test_if.pas | Structures IF/THEN/ELSE et CASE |
| 9 | test_loop.pas | Boucles FOR, WHILE, REPEAT |
| 10 | test_array.pas | Tableaux et accès indexé |
| 11 | test_record.pas | Records avec champs |
| 12 | test_io.pas | Entrées/sorties (WRITELN, READLN, fichiers) |
| 13 | test_pointer.pas | Pointeurs et allocation dynamique |
| 14 | test_set.pas | Ensembles (SET OF) |
| 15 | test_module.pas | Module VAX Pascal |

### Batch 2 (16-30)
| # | Fichier | Description |
|---|---------|-------------|
| 16 | test_include.pas | Directive %INCLUDE |
| 17 | test_except.pas | Gestion d'exceptions (TRY/EXCEPT) |
| 18 | test_static.pas | Variables statiques ([STATIC]) |
| 19 | test_varying.pas | Types VARYING OF CHAR |
| 20 | test_preproc.pas | Préprocesseur (%DEFINE, %IF, %ELSE) |
| 21 | test_label.pas | Labels et GOTO |
| 22 | test_value.pas | Paramètres VALUE/VAR |
| 23 | test_named.pas | Fonctions et procédures nommées |
| 24 | test_fileorg.pas | Organisation de fichiers |
| 25 | test_coerce.pas | Coercitions de types |
| 26 | test_datetime.pas | Fonctions date/heure |
| 27 | test_assert.pas | Assertions |
| 28 | test_procvar.pas | Procédures comme variables |
| 29 | test_smg.pas | Interface SMG (Screen Management) |
| 30 | test_converge.pas | Test de convergence complet |

## Bugs corrigés pendant les smoke tests

### Bug 1 — ParseParamList : boucle infinie sur `varying [N] of char`

**Symptôme** : Le compilateur bloquait indéfiniment sur les paramètres de type `varying [80] of char` ou `array [1..10] of integer`.

**Cause** : Après avoir lu `varying` ou `array` comme nom de type, les tokens `[N] of char` / `[lo..hi] of type` n'étaient jamais consommés.

**Fix** : Ajout de la consommation de `[...] of <type>` dans `ParseParamList` (~ligne 13946).

### Bug 2 — ParseStatement SC_PROC : boucle infinie sur les appels de procédures

**Symptôme** : Tout appel de procédure utilisateur (ex: `show_val(result)`, même `donothing;`) provoquait une boucle infinie.

**Cause** : Dans le bloc SC_PROC de ParseStatement, le token identifiant de la procédure n'était jamais consommé par `LexNextToken`. Le token restait sur l'identifiant, `ParseBlock` rappelait `ParseStatement` sur le même token indéfiniment.

**Fix** : Ajout de `LexNextToken;` après l'entrée dans le bloc SC_PROC (~ligne 16092) pour consommer l'identifiant avant de vérifier la présence de `(`.

## Résultats des smoke tests

```
Batch 1 (1-15):  OK=15  FAIL=0  HANG=0
Batch 2 (16-30): OK=15  FAIL=0  HANG=0
Total:           OK=30  FAIL=0  HANG=0
```

## Statistiques du compilateur

- **Lignes** : 16 729
- **Erreurs de compilation** : 0
- **Notes** : 2 (variables locales non utilisées)

## Commande de vérification

```
fpc VAXPAS86.PAS
.\VAXPAS86.exe -v SAMPLES\VAXPASCAL\hello.pas
.\VAXPAS86.exe -v SAMPLES\VAXPASCAL\test_func.pas
```
