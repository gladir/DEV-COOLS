# Exemples Ada standard : SAMPLES/ADA/T30..T35

Cette serie de fichiers `.ADB` demontre les fonctions built-in de la
bibliotheque standard Ada supportees par le compilateur `ADACW32`.
Chaque programme se termine par le marqueur `=== FIN ===` afin
de permettre aux tests automatises de verifier l.execution complete
sous Wine.

## Contenu

| Fichier             | Module(s) Ada                              | Fonctions / constantes testees |
|---------------------|--------------------------------------------|-------------------------------|
| `T30_LATIN1.ADB`    | `Ada.Characters.Latin_1`                   | ~30 constantes (NUL, LF, CR, Space, LC_a..LC_z, UC_A..UC_Z, ponctuation) |
| `T31_HANDLING.ADB`  | `Ada.Characters.Handling`                  | `Is_Letter`, `Is_Digit`, `Is_Alphanumeric`, `Is_Upper`, `Is_Lower`, `Is_Control`, `Is_Graphic`, `Is_Hexadecimal_Digit`, `To_Upper`, `To_Lower` |
| `T32_NUMERICS.ADB`  | `Ada.Numerics.Elementary_Functions`        | `Sqrt`, `Sin`, `Cos`, `Tan`, `Exp`, `Log`, `Arcsin`, `Arccos`, `Arctan`, `Sinh`, `Cosh`, `Tanh` |
| `T33_STRINGS.ADB`   | `Ada.Strings`, `Ada.Strings.Fixed`, `Ada.Strings.Maps` | `Length`, `Index`, `Count`, `Head`, `Tail`, `Trim`, `Is_In` |
| `T34_TEXTIO.ADB`    | `Ada.Text_IO`                              | `Put` (String/Integer/Boolean/Character), `Put_Line`, `New_Line`, `Set_Col` |
| `T35_ALLMODS.ADB`   | Tous les modules ci-dessus                 | Combinaison multi-modules dans un seul programme |
| `T36_ASMINLINE.ADB` | `System.Machine_Code`                      | `Asm ("...")` : insertion d.assembleur 80386 inline (3 formes d.appel : `Asm`, `Machine_Code.Asm`, `System.Machine_Code.Asm`), multi-instructions separees par `;`. |

## Compilation et execution

Chaque exemple se compile et s.execute ainsi :

```bash
./BINLINUX/ADACW32 SAMPLES/ADA/T30_LATIN1.ADB
WINEDEBUG=-all wine SAMPLES/ADA/T30_LATIN1.exe
```

## Suite de tests automatisee

Le script `BINLINUX/test_ada_builtins.sh` compile et execute tous les
samples T30..T35, puis verifie la sortie pour chacun. Il affiche un tableau
PASS/FAIL et retourne un code non-zero si un test echoue :

```bash
./BINLINUX/test_ada_builtins.sh
```

Sortie attendue :

```
=== Tests Ada built-in sous Wine ===
  [PASS] T30_LATIN1       ( 30 lignes)
  [PASS] T31_HANDLING     ( 24 lignes)
  [PASS] T32_NUMERICS     ( 17 lignes)
  [PASS] T33_STRINGS      ( 20 lignes)
  [PASS] T34_TEXTIO       ( 21 lignes)
  [PASS] T35_ALLMODS      ( 23 lignes)
---
Resultat : 6 PASS, 0 FAIL
```

## Fonctions supportees et non-supportees

Environ 100+ fonctions / constantes du coeur de la bibliotheque standard
Ada sont fonctionnelles : les 55 constantes Latin_1, les 14 fonctions de
`Characters.Handling`, les 12 fonctions elementaires `Numerics`, les 7
fonctions principales de `Strings`, et les primitives de `Text_IO`.

Les fonctions suivantes sont declarees mais retournent des valeurs par
defaut (stubs) et n.effectuent pas de vraie I/O fichier : `Direct_IO`,
`Sequential_IO`, `Stream_IO`, `Storage_IO`, `Text_Streams`, ainsi que les
primitives avancees de `Ada.Command_Line`. Elles compilent mais leur
comportement d.execution sera minimal sous Wine.
