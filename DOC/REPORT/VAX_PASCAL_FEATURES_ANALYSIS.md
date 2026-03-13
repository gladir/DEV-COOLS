# Analyse complète des fonctionnalités VAX Pascal

Analyse basée sur ~40 fichiers .pas du répertoire `SAMPLES/VAXPASCAL/`.

> Note : Les échantillons couvrent deux « dialectes » VAX Pascal :
> - Le **Pascal TOPS-10/20** (DEC-10) — fichiers test*.pas, stat.pas, bldrw.pas, etc.
> - Le **VAX/VMS Pascal** — Windows.pas et fichiers référencés par `[Inherit]`/`[Environment]`.
>
> Les deux partagent beaucoup d'extensions, mais le VMS Pascal ajoute des attributs entre crochets `[...]`.

---

## 1. Structure Programme / Module

### 1.1 `PROGRAM` avec `OPTIONS`
```pascal
PROGRAM TEST12 OPTIONS dump, fortran, optimize, nocheck;
PROGRAM test60 OPTIONS dumpst, dumpif;
$OPTIONS SPECIAL, NOCHECK
$OPTIONS MAIN, SPECIAL, NOCHECK, PROGRESS, INFO
$OPTIONS STORAGE=4096
```
Options vues : `DUMP`, `DUMPST`, `DUMPIF`, `FORTRAN`, `OPTIMIZE`, `NOOPTIMIZE`, `CHECK`, `NOCHECK`, `ASSEMBLY`, `SPECIAL(coercions)`, `SPECIAL(word)`, `SPECIAL(ptr)`, `MAIN`, `PROGRESS`, `INFO`, `NODUMP(ifm,dags,shape,optshape)`.

### 1.2 `MODULE` (unité de compilation séparée)
```pascal
MODULE test58 OPTIONS dump;
MODULE test59 OPTIONS dump;
MODULE GAMMA;
MODULE PRIME;
module debbo$ options nocheck, special (word);
module mdlpro options special (coercions);
```
Un `MODULE` n'a **pas** de bloc `BEGIN..END` principal — il se termine par `END.`

### 1.3 `DATAMODULE` (module de données uniquement)
```pascal
DATAMODULE test52 OPTIONS dump;
  const c1 = 3;
  public var a: 1..3;
  var b: 1..c1
END.
```

### 1.4 `[Inherit]` et `[Environment]` (VMS Pascal uniquement)
```pascal
[Inherit ('SYS$LIBRARY:STARLET','LibRtl','Types','SMGRTL')] Module Windows;
```
- `[Inherit(...)]` importe des environnements compilés (équivalent à `USES` en Turbo Pascal).
- `[Environment(...)]` crée un fichier d'environnement exportable.

---

## 2. Visibilité et Liaison

### 2.1 `PUBLIC` — exporte le symbole
```pascal
PUBLIC var c, d: (red, green, blue);
PUBLIC function fun (var x: boolean): char;
PUBLIC procedure f2proc; forward;
PUBLIC type b = 0..4;
PUBLIC const cst = false;
PUBLIC condition pubcond: boolean;
```

### 2.2 `EXTERNAL` — importe un symbole externe
```pascal
EXTERNAL procedure extproc (boolean; char);
EXTERNAL var b: 0..2;
EXTERNAL const d: char;
EXTERNAL condition extcond;
EXTERNAL procedure p1 (t1; var t2; t3);
```
Note : Les paramètres des procédures externes peuvent être des **noms de types non définis** (types forwards implicites).

### 2.3 `STATIC` — stockage statique
```pascal
STATIC var c2: char := 'b';
STATIC const b: boolean := false;
STATIC label 300;
```

### 2.4 Attributs VMS `[External]` et `[Global]`
```pascal
[External] Procedure Ring_Bell (Display_Id: Unsigned; Number_of_Times: Integer := 1); External;
[Global] Procedure Message_Trap;
[Global] Procedure Printing_Message;
[Global] Procedure Closing_Warning (...);
Var Print_Queue: [External] Line;
Var Pasteboard: [External] Unsigned;
```

---

## 3. Types de données

### 3.1 Types entiers et sous-intervalle
```pascal
type t1 = 0..1;
type smallint = -32..31;
type one_byte = 0..2**8-1;
type two_bytes = 0..2**16-1;
type four_bytes = 0..2**32-1;
```
Expressions constantes dans les bornes de sous-intervalles (y compris `**`).

### 3.2 Octal avec suffixe `B`
```pascal
proj: 0..777777B;
```

### 3.3 Packed avec taille explicite `PACKED [n]`
```pascal
type s1 = packed [4] 0..3;
type s2 = packed [4] 0..8;
type color = packed (red, green, blue);
```

### 3.4 Types réels avec `PREC` (précision)
```pascal
type t4 = 1..4 PREC 12;
type t5 = 1..5.0 PREC 17;
var f: 1..100 BY 0.01;   (* réel avec pas *)
var s: -10e4..10e4 PREC 5;
var d: -10e4..10e4 PREC 12;
```

### 3.5 `VARYING OF CHAR` (VMS Pascal — chaînes de longueur variable)
```pascal
Type Long_Line = Varying [390] of Char;
Var Msg: Varying [390] of Char;
```
Accès au champ `.Length` implicite :
```pascal
If Msg.Length > 0 then ...
```

### 3.6 `STRING` (chaînes de longueur variable TOPS-10/20)
```pascal
var s: string;            (* longueur illimitée par défaut *)
var s2: string[4];        (* longueur max 4 *)
string[*]                  (* longueur flexible/conformant *)
```

### 3.7 `PACKED ARRAY [1..*] OF CHAR` (paramètres conformants)
```pascal
type sff = packed array [1..*] of char;
procedure error (msg: packed array [1..*] of char);
```

### 3.8 `Unsigned` (VMS Pascal)
```pascal
Var Pasteboard: [External] Unsigned;
Type Signed_Word = [Word] -32767..32767;
```

### 3.9 `PTR` — pointeur générique non typé
```pascal
var p: ptr;
ip := ptr(5);
ip := ptr(ord(cp^));
ip := iptr(cp);      (* coercition de pointeur *)
```

### 3.10 `MACHINE_WORD` — mot machine
```pascal
int_value1, int_value2: machine_word;
```

### 3.11 Tableaux et records à taille flexible (`*` dans les bornes)
```pascal
type t4 = array [1..*] of boolean;    (* dimension flexible *)
type t7 = array [*] of boolean;       (* totalement flexible *)
type flexrec = packed record
    field1, field2: 0..777777B;
    arr: array [1..*] of smallint      (* dernier champ flexible *)
end;
type PASSEDARRAY = array [1..*] of integer;  (* paramètre conformant *)
```

### 3.12 Types procéduraux
```pascal
var afun: procedure (a: char; var b: boolean): boolean;
var P1: PROCEDURE (BOOLEAN; VAR BOOLEAN);
var F1: FUNCTION (BOOLEAN): CHAR;
```

### 3.13 Enregistrements avec variants `OTHERS`
```pascal
case int of
    1, 12..20: (xyz: string);
    OTHERS: (s: packed array [1..4] of char)
```
Le mot-clé `OTHERS` dans les `case` de variant.

### 3.14 Constructeurs d'enregistrements (record constructors)
```pascal
X := ('A', 'B', 6);
X := ('0', '1', 1, 'MINIMAX', 'ALPHA');
P := (0, 4, TRUE);
input_word := (0, 0, 0, 0);
last^ := (nil, ('*', 1, cursor(help_file)));
```

### 3.15 Constructeurs de tableaux (array constructors)
```pascal
IA := (10, 20, 30, 40);
CA := ('A', 'B', ' ', 'D', ' ', 'H');
BA := (TRUE, FALSE, TRUE);
```

### 3.16 Types prédéfinis
- `IO_STATUS` — type scalaire d'état d'E/S
- `IO_OK`, `IO_NOVF`, `IO_POVF`, etc. — valeurs de `IO_STATUS`
- `FILE_NAME` — type chaîne pour les noms de fichiers
- `FILE_BLOCK` — type structuré pour les blocs fichier
- `TEXT` — fichier texte

---

## 4. Opérateurs

### 4.1 Concaténation `||`
```pascal
STR1 := 'A' || STR2[3:5] || STR3[2];
D := C || 'MIN';
P1 := P2 || P2;
```

### 4.2 Exponentiation `**`
```pascal
B = A ** 2;
i := i ** 4;
s := s ** i;
d := d ** d;
```

### 4.3 Sous-chaîne `[start:length]`
```pascal
S1 := A1[I].FLD4^.FLD2[1:5];
D2 = C1[3:4];
C2 := A2['A', 1, 3:5];
```

### 4.4 Court-circuit `ANDIF` / `ORIF`
```pascal
while (local_index <= maximum(ESDID_range)) ANDIF
      (ESDID_array[local_index].name <> '') do ...
if (text_line = '') ORIF (text_line[1] <> '\') then ...
```

### 4.5 Formatage en base `:o` (octal), `:h` (hex), `:L` (aligné à gauche)
```pascal
write (tty, major:width(major):o);     (* format octal *)
putstring (int_text, int:max_hex_width:h);  (* format hex *)
write (outtab, text: maxsylen: L, '  );');  (* aligné à gauche *)
```

---

## 5. Instructions de contrôle

### 5.1 `LOOP .. EXIT IF .. END`
```pascal
LOOP
  repeat i := i + 1 until a[i] >= v;
  repeat j := j - 1 until a[j] <= v;
EXIT IF j < i;
  t := a[i]; a[i] := a[j]; a[j] := t;
END;
```

### 5.2 `EXIT IF` dans `WHILE..DO BEGIN..END`
```pascal
while not b do begin
  b := b;
EXIT IF b;
  b := b;
end;
```

### 5.3 `RETURN` (retour de procédure sans valeur)
```pascal
procedure proc (...);
begin
  RETURN
end;
```

### 5.4 `STOP` (arrêt du programme)
```pascal
begin
  STOP
end.
```

### 5.5 `BREAK` (flush output / vidage de tampon)
```pascal
write (tty, 'Input: '); BREAK;
BREAK (tty);
```

### 5.6 `CASE .. OF .. OTHERS`
```pascal
case i of
  1..10: stop;
  12: stop;
  OTHERS: writeln
end;
```

### 5.7 `FOR` avec variable de type scalaire
```pascal
for c := lowerbound(a, 1) to upperbound(a, 1) do ...
```

---

## 6. Gestion des conditions (Exceptions)

### 6.1 Déclaration `CONDITION`
```pascal
CONDITION xyz (): real;
CONDITION abc (var c: char);
CONDITION cbb (var a: boolean; b: boolean);
CONDITION cnr: real;
PUBLIC CONDITION pubcond: boolean;
EXTERNAL CONDITION extcond;
```

### 6.2 Levée et gestion `ON .. DO .. :`
```pascal
writeln (tty) ON cn DO stop;

ON cnr DO cnr := 2.0 :
  begin stop end;

ON cbb DO begin a := b end :
  stop;

ON anyother DO writeln (tty, name) :
  stop;
```

### 6.3 `EXCEPTION` (handler dans un bloc)
```pascal
loop begin
  write (tty, '???? '); break; readln (tty);
exit if eoln (tty);
  EXCEPTION allconditions: begin
    writeln (tty, exception_message);
  end;
end end;
```
- `ALLCONDITIONS` — attrape toutes les exceptions
- `EXCEPTION_MESSAGE` — message d'erreur prédéfini

---

## 7. Entrées/Sorties

### 7.1 Fichiers prédéfinis
- `TTY` — terminal (lecture/écriture)
- `TTYOUTPUT` — terminal sortie seulement
- `INPUT` / `OUTPUT` — entrée/sortie standard

### 7.2 `OPEN` / `CLOSE` / `RESET` / `REWRITE`
```pascal
OPEN (tty);
REWRITE (tty);
RESET (input_file, source_file_name);
RESET (input_file, '.RO ' || input_file_name, [retry]);
REWRITE (help_file, 'PASCAL.HLP', [seekok]);
CLOSE;
CLOSE (f);
```
Options de fichier : `[retry]`, `[seekok]`.

### 7.3 `READ` / `WRITE` / `READLN` / `WRITELN` extensions
```pascal
write (tty, i, i:4, i:4:0, i:4:o);   (* format octal *)
write (f, c:12, s:12);
```

### 7.4 `READRN` / `WRITERN` (accès direct par numéro d'enregistrement)
```pascal
readrn (relfile, 7, version);
```

### 7.5 `GET` / `PUT` (accès buffer)
```pascal
GET (f);
PUT (f);
```

### 7.6 `PAGE` / `BREAK`
```pascal
PAGE;
PAGE (t);
BREAK;
BREAK (tty);
```

### 7.7 `CURSOR` (position dans le fichier)
```pascal
k := cursor (input);
c := cursor (help_file);
```

### 7.8 `FILENAME` (nom du fichier associé)
```pascal
test_file_name := filename (test_file);
```

### 7.9 `IOSTATUS`
```pascal
if iostatus <> io_ok then error ('Bad input file.');
if iostatus (input_file) <> io_ok then ...
```

### 7.10 `PUTSTRING` / `GETSTRING` (conversion en mémoire)
```pascal
putstring (convert_decimal, input_number:0);
putstring (int_text, int:0);
putstring (int_text, int:max_octal_width:o);
getstring (id_text, cons_node.scalar_val[1]: charcnt: o);
```

### 7.11 `WRITEV` (VMS Pascal — write to varying string)
```pascal
WriteV (Msg, Minutes_Left: 0);
```

### 7.12 `FIO_*` — bibliothèque d'I/O de fichiers
```pascal
fio_open (output_file, '.LS ' || output_file_name);
fio_line (fb, 'text');
fio_skip (fb);
fio_page (output_file);
fio_reopen (listfb);
fio_write (listfb, cv_hex(label_addr, 8));
```

### 7.13 Paramètre nommé (VMS Pascal)
```pascal
SMG$Put_Line (BroadcastDisplay, Msg, wrap_flag := SMG$M_WRAP_WORD);
```

### 7.14 Valeur par défaut de paramètre (VMS Pascal)
```pascal
Procedure Ring_Bell (Display_Id: Unsigned; Number_of_Times: Integer := 1);
```

---

## 8. Fonctions et procédures prédéfinies

### 8.1 Fonctions standard étendues
| Fonction | Description | Exemple |
|----------|-------------|---------|
| `ABS(x)` | Valeur absolue | `I := ABS(I)` |
| `ODD(x)` | Test d'imparité | `P := ODD(I)` |
| `ORD(x)` | Ordinal | `I := ORD(C)` |
| `CHR(x)` | Caractère | `C := CHR(I)` |
| `SUCC(x)` | Successeur | `C := SUCC(C)` |
| `PRED(x)` | Prédécesseur | `S := PRED(S)` |
| `TRUNC(x)` | Troncature | `I := TRUNC(R)` |
| `ROUND(x)` | Arrondi | `I := ROUND(F)` |
| `ROUND(x, n)` | Arrondi à n décimales | `s := round(s, i)` |
| `EOF(f)` | Fin de fichier | `P := EOF(TTY)` |
| `EOLN(f)` | Fin de ligne | `P := EOLN` |
| `SQR(x)` | Carré | `ta := sqr(max(...))` |
| `SQRT(x)` | Racine carrée | `s := sqrt(s)` |
| `LN(x)` | Logarithme naturel | `s := ln(s)` |
| `ARCTAN(x)` | Arc tangente (1 ou 2 args) | `d := arctan(d, d)` |
| `RANDOM` | Nombre aléatoire | `s := random; s := random(d)` |
| `MAX(a, b, ...)` | Maximum (N-aire) | `ta := max(pm4, dt)` |
| `MIN(a, b, ...)` | Minimum (N-aire) | `d := min(d, d)` |

### 8.2 Fonctions de chaîne
| Fonction | Description | Exemple |
|----------|-------------|---------|
| `LENGTH(s)` | Longueur courante | `I := LENGTH(T)` |
| `INDEX(s, t)` | Recherche de sous-chaîne | `I := INDEX(U, T)` |
| `INDEX(s, t, start)` | Recherche avec position | `I := INDEX(U, T, 0)` |
| `SUBSTR(s, pos)` | Sous-chaîne | `T := SUBSTR(U, I)` |
| `SUBSTR(s, pos, len)` | Sous-chaîne | `T := SUBSTR(T, I, 3)` |
| `VERIFY(s, set)` | Position non dans l'ensemble | `I := VERIFY(T, D)` |
| `SEARCH(s, set)` | Position dans l'ensemble | `I := SEARCH(U, D)` |
| `UPPERCASE(s)` | Conversion majuscule | `C := UPPERCASE(C)` |
| `LOWERCASE(s)` | Conversion minuscule | `C := LOWERCASE('A')` |

### 8.3 Fonctions de type/mémoire
| Fonction | Description | Exemple |
|----------|-------------|---------|
| `SIZE(type)` | Taille d'un type | `i := SIZE(r)` |
| `SIZE(type, variant_tags...)` | Taille avec variants | `i := SIZE(r, 2, 20)` |
| `LOWERBOUND(x)` | Borne inférieure | `n := LOWERBOUND(a)` |
| `LOWERBOUND(x, dim)` | Borne inf. dimension N | `n := LOWERBOUND(a1, 3)` |
| `UPPERBOUND(x)` | Borne supérieure | `n := UPPERBOUND(s)` |
| `UPPERBOUND(x, dim)` | Borne sup. dimension N | `n := UPPERBOUND(a2, 2)` |
| `DIMENSION(x)` | Nombre d'éléments | `n := DIMENSION(a)` |
| `DIMENSION(x, dim)` | Dimension N | `n := DIMENSION(a1, 3)` |
| `MAXIMUM(type)` | Valeur max d'un type | `0..MAXIMUM(integer)` |
| `MINIMUM(type)` | Valeur min d'un type | `MINIMUM(ESDID_range)` |
| `ADDRESS(x)` | Adresse | `i := ord(ADDRESS(i))` |
| `NEW(p)` | Allocation | `NEW(p)` |
| `NEW(p, tag_values...)` | Allocation variant | `NEW(p, true, 1)` |
| `NEW(p, flex_size)` | Allocation flexible | `NEW(p, 27)` |
| `DISPOSE(p)` | Libération | `DISPOSE(tptr)` |

---

## 9. Directives du préprocesseur / compilateur

### 9.1 Directives à `$`
| Directive | Description | Exemple |
|-----------|-------------|---------|
| `$INCLUDE file` | Inclusion de fichier | `$INCLUDE pascal.inc` |
| `$SYSTEM file` | Inclusion système | `$SYSTEM pascal` |
| `$PAGE [name]` | Saut de page listing | `$PAGE declarations` |
| `$TITLE text` | Titre du listing | `$TITLE listing test` |
| `$HEADER text` | En-tête du listing | `$HEADER debbol` |
| `$LENGTH (n)` | Longueur de page | `$LENGTH (15)` |
| `$WIDTH (n)` | Largeur de page | `$WIDTH (80)` |
| `$OPTIONS ...` | Options de compilation | `$OPTIONS SPECIAL, NOCHECK` |
| `$SOURCE` | Début listing source | `$SOURCE` |
| `$IF cond` | Compilation conditionnelle | `$IF foo,bar  a := 3;` |
| `$IF VAX` / `$IF P10` | Ciblage plateforme | `$IF VAX ... $ENDIF` |
| `$IFNOT cond` | Comp. conditionnelle négative | `$IFNOT foo` |
| `$END` | Fin de bloc conditionnel | `$END` |
| `$ENDIF` | Fin de bloc conditionnel (alt.) | `$ENDIF` |

### 9.2 `%INCLUDE` (syntaxe VMS alternative)
```pascal
%INCLUDE 'SYS$LIBRARY:STARLET'
```

---

## 10. Options de procédure/fonction

### 10.1 `OPTIONS` sur les routines
```pascal
external procedure foo OPTIONS fortran, nooptimize;
procedure bar OPTIONS fortran, check, nooptimize;
function f (a: integer): integer OPTIONS nodump (ifm, dags, shape, optshape);
```

### 10.2 `FORWARD`
```pascal
procedure fproc (s, f: char); FORWARD;
public procedure f2proc; FORWARD;
```

---

## 11. Initialisation de variables à la déclaration
```pascal
var a: 0..4 := 2;
var c: char := 'a';
static var c2: char := 'b';
const bad: boolean := 2;          (* typed const *)
static const b: boolean := false;
```

---

## 12. Accès aux champs de fichiers structurés
```pascal
with output_file do begin
  page_header := write_header;   (* affectation proc à champ procédural *)
  width := 120;
  plength := 42;
end;
```

---

## 13. Paramètres typés implicites (sans nom)
```pascal
external procedure extproc (boolean; char);          (* pas de nom de paramètre *)
var afun3: function (char; boolean);                  (* pas de nom *)
external procedure p2 (var 0..3);                     (* type inline *)
```

---

## 14. Coercitions explicites
```pascal
ip := iptr(cp^);    (* coercion pointeur *)
ip := iptr(cp);     (* coercion pointeur *)
ip := ptr(5);       (* entier → pointeur *)
a[color(i+1-4), blue] := 14;  (* entier → enum *)
```

---

## 15. Variables et types « forward » (utilisation avant déclaration)
```pascal
var xx: ftype;           (* type non encore déclaré *)
...
type ftype = 0..6;       (* déclaré plus tard *)

type p = ^ fortype;      (* pointeur vers type non défini *)
...
type fortype = 'A'..'Z'; (* défini plus tard *)
```

---

## 16. Fonctionnalités VMS spécifiques (Windows.pas)

### 16.1 Appels système VMS
```pascal
SMG$Create_Virtual_Display (5, 78, Display_ID, 1);
SMG$Erase_Display (Display_ID);
SMG$Label_Border (Display_ID, Message_Text, SMG$K_TOP);
SMG$Get_Broadcast_Message (Pasteboard, Msg, Len);
SMG$Paste_Virtual_Display (BroadcastDisplay, Pasteboard, 2, 2);
LIB$WAIT (4.0);
```

### 16.2 Attribut `[Word]` sur les types
```pascal
Type Signed_Word = [Word] -32767..32767;
```

### 16.3 Constantes et types système
- `Line` — type chaîne prédéfini
- `Unsigned` — entier non signé
- `SMG$K_TOP`, `SMG$M_WRAP_WORD` — constantes système

---

## 17. Récapitulatif — Liste TODO pour compilateur

### Catégorie A : Structure
- [ ] `PROGRAM .. OPTIONS ..`
- [ ] `MODULE .. OPTIONS ..`
- [ ] `DATAMODULE .. END.`
- [ ] `[Inherit (...)]`
- [ ] `[Environment (...)]`
- [ ] `PUBLIC`, `EXTERNAL`, `STATIC` modificateurs
- [ ] `[External]`, `[Global]` attributs VMS

### Catégorie B : Types
- [ ] Sous-intervalles avec expressions constantes (`0..2**8-1`)
- [ ] Constantes octales (`777777B`)
- [ ] `PACKED [n] type` — taille en bits explicite
- [ ] `PACKED (enum)` — enum packed
- [ ] Réels avec `PREC n`
- [ ] Réels avec `BY step`
- [ ] `VARYING [n] OF CHAR` (VMS)
- [ ] `STRING [n]` / `STRING [*]` / `STRING`
- [ ] `PACKED ARRAY [1..*] OF CHAR` — conformant
- [ ] `ARRAY [1..*]` / `ARRAY [*]` — flexible
- [ ] `PTR` — pointeur générique
- [ ] `MACHINE_WORD`
- [ ] `Unsigned` (VMS)
- [ ] `[Word]` attribut (VMS)
- [ ] Types procéduraux/fonctionnels
- [ ] Variants avec `OTHERS`
- [ ] Records flexibles (dernier champ `array [1..*]`)
- [ ] Constructeurs d'enregistrements et de tableaux

### Catégorie C : Opérateurs
- [ ] `||` — concaténation
- [ ] `**` — exponentiation
- [ ] `[start:length]` — sous-chaîne
- [ ] `ANDIF` / `ORIF` — évaluation court-circuit
- [ ] Format `:o` (octal), `:h` (hex), `:L` (gauche), `:E` (exponentiel)

### Catégorie D : Contrôle
- [ ] `LOOP .. EXIT IF .. END`
- [ ] `EXIT IF` dans `WHILE`
- [ ] `RETURN`
- [ ] `STOP`
- [ ] `BREAK` / `BREAK(f)`
- [ ] `CASE .. OTHERS`
- [ ] `FOR` avec types scalaires énumérés

### Catégorie E : Conditions/Exceptions
- [ ] `CONDITION` déclarations
- [ ] `ON .. DO .. :` gestionnaires
- [ ] `EXCEPTION .. :` gestionnaires dans blocs
- [ ] `ALLCONDITIONS`
- [ ] `EXCEPTION_MESSAGE`
- [ ] `ANYOTHER`

### Catégorie F : E/S
- [ ] `TTY`, `TTYOUTPUT` — fichiers prédéfinis
- [ ] `OPEN`, `CLOSE`, `RESET`, `REWRITE` avec options (`[retry]`, `[seekok]`)
- [ ] `GET`, `PUT`
- [ ] `PAGE`, `BREAK`
- [ ] `CURSOR(f)`, `FILENAME(f)`, `IOSTATUS`, `IOSTATUS(f)`
- [ ] `READRN`, `WRITERN` — accès direct
- [ ] `PUTSTRING`, `GETSTRING` — formatage mémoire
- [ ] `WRITEV` (VMS)
- [ ] `FILE OF *` — fichier non typé
- [ ] `FIO_*` — bibliothèque de fichiers
- [ ] Paramètres nommés (`wrap_flag := ...`)
- [ ] Valeurs par défaut de paramètres (`Number_of_Times: Integer := 1`)

### Catégorie G : Fonctions prédéfinies
- [ ] `ABS`, `ODD`, `ORD`, `CHR`, `SUCC`, `PRED`, `TRUNC`, `ROUND`
- [ ] `SQR`, `SQRT`, `LN`, `ARCTAN` (1-2 args)
- [ ] `LENGTH`, `INDEX`, `SUBSTR`, `VERIFY`, `SEARCH`
- [ ] `UPPERCASE`, `LOWERCASE`
- [ ] `SIZE` (avec tags de variants)
- [ ] `LOWERBOUND`, `UPPERBOUND`, `DIMENSION` (avec dimension)
- [ ] `MAXIMUM`, `MINIMUM` (sur types)
- [ ] `ADDRESS`
- [ ] `NEW` (avec tags/taille flexible), `DISPOSE`
- [ ] `MAX`, `MIN` (N-aire, multi-type)
- [ ] `RANDOM`

### Catégorie H : Préprocesseur
- [ ] `$INCLUDE`, `$SYSTEM`
- [ ] `$PAGE`, `$TITLE`, `$HEADER`
- [ ] `$LENGTH`, `$WIDTH`
- [ ] `$OPTIONS`
- [ ] `$IF` / `$IFNOT` / `$END` / `$ENDIF`
- [ ] `$SOURCE`
- [ ] `%INCLUDE` (VMS)

### Catégorie I : Divers
- [ ] Initialisation à la déclaration (`var x: type := value`)
- [ ] Paramètres sans nom (`procedure p (boolean; char)`)
- [ ] Coercitions de type explicites (`iptr(cp)`, `color(i)`)
- [ ] Types forward implicites
- [ ] Constructeurs litéraux de records et arrays
- [ ] `FORWARD` sur `PUBLIC` procedures
- [ ] Options `FORTRAN` sur routines
- [ ] Const record field references (`C1.F2`)
- [ ] Const array subscripting (`A1[1]`)
- [ ] Const string subscripting/concatenation
