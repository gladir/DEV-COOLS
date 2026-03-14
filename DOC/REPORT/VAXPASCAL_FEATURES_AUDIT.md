# Audit exhaustif des fonctionnalités VMS Pascal (DEC/VAX Pascal)

## Répertoire analysé : `SAMPLES\VAXPASCAL\`

> **217 fichiers `.pas`** examinés, plus `.typ`, `.inc`, `.env`. Certains fichiers test (test1-3, test10, test14, test15, test20, testa, testb, gshell) sont binaires (format DEC ancien) et n'ont pas pu être lus.

---

## 1. Directives de préprocesseur

| Directive | Description | Fichiers |
|-----------|-------------|----------|
| `$TITLE text` | Titre du module (listing) | debug.pas, m68cgu.pas, m68mac.pas, debdmp.pas, debref.pas, debprt.pas, deblex.pas |
| `$HEADER text` | En-tête de page (listing) | debug.pas |
| `$PAGE text` | Saut de page / section (listing) | Quasi-totalité des fichiers sources |
| `$INCLUDE file` | Inclusion de fichier | debug.pas, mdlpro.pas, anal.pas, m68imd.pas |
| `$SYSTEM file` | Inclusion fichier système (résolu dans SYS$LIBRARY) | m68mac.pas, pasdmp.pas, m68imd.pas, pascfm.pas, mdlpro.pas |
| `$SOURCE` | Indicateur de source | cursor.pas |
| `$IF condition` | Compilation conditionnelle | debug.typ (`$IF P10`, `$IF VAX`, `$IF STATS`) |
| `$ENDIF` | Fin de bloc conditionnel | debug.typ |
| `$ELSE` | Branche alternative | debug.typ |

### Exemples :
```pascal
$IF P10
  machine_word = integer;
$ENDIF
$IF VAX
  machine_word = [Long] integer;
$ENDIF
$SYSTEM pascal.inc
$INCLUDE MMTCOR.INC
```

---

## 2. Système de modules

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `MODULE name` | Déclaration de module (pas de programme principal) | debug.pas, m68cgu.pas, m68mac.pas, m68imd.pas, mdlpro.pas, debbol.pas, debbrk.pas, debdmp.pas, debref.pas, debprt.pas, deblex.pas, m68dmp.pas, m68exp.pas, m68gen.pas, m68set.pas, m68str.pas |
| `PROGRAM name` | Programme principal | cursor.pas, heat2d.pas |
| `OPTIONS nocheck` | Désactive les vérifications de limites | debug.pas, debbol.pas, debbrk.pas, debref.pas |
| `OPTIONS check` | Active les vérifications | m68cgu.pas, m68mac.pas, m68imd.pas |
| `OPTIONS dump` | Dump interne | test30.pas |
| `OPTIONS dumpst, dumpif` | Dump de la table de symboles / forme intermédiaire | test60.pas |
| `OPTIONS assembly` | Listing assembleur | cursor.pas |
| `OPTIONS special(coercions)` | Autorise les coercitions de type | mdlpro.pas |
| `OPTIONS special(word)` | Coercitions mot | debbol.pas |
| `OPTIONS special(coercions, word, ptr)` | Multiples coercitions | debug.pas, debbrk.pas, debref.pas |
| Procedure-level `options` | `procedure foo options special(coercions)` | m68imd.pas |

### Exemples :
```pascal
module debug$ options nocheck, special (coercions, word, ptr);
module m68mac options check, special (word);
procedure init_tal_tables options special(coercions);
program cursor_bug options assembly;
```

---

## 3. Visibilité et liaison

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `PUBLIC procedure` | Procédure exportée | debug.pas, m68cgu.pas, m68imd.pas, m68mac.pas, m68str.pas, anal.pas |
| `PUBLIC function` | Fonction exportée | test5.pas, m68str.pas |
| `PUBLIC var` | Variable exportée | mdlpro.pas, m68imd.pas |
| `PUBLIC const` | Constante exportée | m68imd.pas |
| `PUBLIC type` | Type exporté | (implicite dans les modules) |
| `EXTERNAL procedure` | Procédure externe (définie ailleurs) | test5.pas, mdlpro.pas, debsym.inc, m68imd.pas |
| `EXTERNAL function` | Fonction externe | debsym.inc, m68imd.pas |
| `EXTERNAL var` | Variable externe | test5.pas, mdlpro.pas, m68imd.pas |
| `[External]` | Attribut VMS EXTERNAL (style crochet) | Windows.pas |
| `[Global]` | Attribut VMS GLOBAL (symbole global linker) | Windows.pas |
| `[Inherit ('lib1','lib2')]` | Héritage d'environnement compilé | Windows.pas |
| `FORWARD` | Déclaration forward | test5.pas, p10sel.pas |

### Exemples :
```pascal
[Inherit ('SYS$LIBRARY:STARLET','LibRtl','Types','SMGRTL')]Module Windows;
public procedure gen_pc_assert (area: rel_sections; offset: integer);
external var lastsym: symptr;
[External]Procedure Ring_Bell (Display_Id: Unsigned; Number_of_Times: Integer:=1);External;
[Global]Procedure Message_Trap;
```

---

## 4. Types — Extensions DEC

### 4.1 Types prédéfinis

| Type | Description | Fichiers |
|------|-------------|----------|
| `VARYING [n] OF CHAR` | Chaîne de longueur variable (avec champ `.Length`) | Windows.pas |
| `STRING [n]` | Chaîne fixe de longueur n | debug.pas, m68mac.pas, m68dmp.pas, cursor.pas, mdlpro.pas |
| `STRING [*]` | Chaîne conformante (paramètre) | m68dmp.pas, debio.pas |
| `STRING` (sans taille) | Type chaîne (paramètre) | cursor.pas, mdlpro.pas |
| `MACHINE_WORD` | Entier de la taille d'un mot machine | debug.typ, debref.pas, debprt.pas, m68str.pas |
| `UNSIGNED` | Entier non signé | Windows.pas |
| `REAL_TYPE` | Type réel DEC (alias) | m68cgu.pas, debref.pas, m68imd.pas, debprt.pas |
| `FILE_NAME` | Type prédéfini pour noms de fichiers | m68dmp.pas, cursor.pas, mdlpro.pas, debsym.inc |
| `FILE_NAME_STRING` | Variante string du nom de fichier | debsym.inc |
| `IO_STATUS` | Énumération prédéfinie des statuts I/O | cursor.pas |
| `HALF_WORD` | Demi-mot machine | debug.typ |
| `PTR` | Pointeur générique/non typé | debsym.inc |
| `EXTNAME` | Type pour nom externe | m68imd.pas |
| `CONDNAMES` | Type pour noms de conditions | m68imd.pas |
| `SAVE_POINTER` | Pointeur de sauvegarde d'état | m68imd.pas |
| `PARM_RANGE` | Plage de paramètres | pasbod.pas |
| `TEXT` | Fichier texte (standard mais important) | cursor.pas, mdlpro.pas, heat2d.pas |

### 4.2 Qualificateurs et attributs de types

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `[Word]` | Attribut de taille mot | Windows.pas (`Signed_Word = [Word]-32767..32767`) |
| `[Long]` | Attribut de taille long mot | debug.typ (conditionnel VAX) |
| `PREC precision` | Précision des réels | debref.pas, debprt.pas, tst106.pas |
| `PACKED RECORD` | Record empaqueté (champs sur bits) | debug.typ, test4.pas |
| `PACKED ARRAY` | Tableau empaqueté | debug.pas, m68cgu.pas, debprt.pas |

### Exemples :
```pascal
Signed_Word = [Word]-32767..32767;
Long_Line = Varying [390] of Char;
single_real_ptr = ^minimum(real_type)..maximum(real_type) prec single_real_prec;
condnamextern: condnames = ( 'E.CMATH', 'E.CIO', 'E.CPROG', 'E.CATTN',
                             'E.CHEAP', 'E.CSTACK', 'E.CSPEC' );
```

---

## 5. Littéraux numériques — Extensions

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `nnnB` (octal) | Suffixe B pour octal : `777777B` | tst100.pas, test4.pas |
| `#Onnnn` (octal) | Notation # + O : `#O177777`, `#O400012` | debug.typ, debref.pas, m68imd.pas, mdlpro.pas |
| `chr(#O15)` | Caractère via octal | debio.pas |
| Format `:width:h` | Sortie hexadécimale dans PUTSTRING | m68dmp.pas, m68mac.pas, debprt.pas |
| Format `:width:o` | Sortie octale dans PUTSTRING | debio.pas, debprt.pas |

### Exemples :
```pascal
resptr := #o400012;
if c > chr(#O15) then ...
putstring (cv_hex, input_number:input_length:h)
putstring (octal_text, value:max_octal_width:o);
```

---

## 6. Tableaux conformants et flexibles

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `PACKED ARRAY [1..*] OF CHAR` | Tableau conformant empaqueté | debug.pas, m68cgu.pas, debprt.pas, m68gen.pas |
| `ARRAY [1..*]` | Tableau flexible (upper bound en runtime) | tst100.pas |
| `ARRAY [*]` | Tableau conformant (bounds en runtime) | tst100.pas |
| `ARRAY [red..*]` | Lower bound fixe, upper bound conformant | tst100.pas |
| `NEW(p, size)` | Allocation avec borne supérieure pour flex | tst100.pas, m68cgu.pas |
| `NEW(p, tag1, tag2)` | Allocation avec tags de variants | tst101.pas, test60.pas |

### Exemples :
```pascal
procedure fatal_error (message: packed array [1..*] of char);
procedure write_string (input_string: string[*]);
new (cr, set_code, upperbound (set_const));
new (op_descs, upperbound (operand));
```

---

## 7. Fonctions et procédures prédéfinies étendues

### 7.1 Fonctions sur tableaux/chaînes

| Fonction | Description | Fichiers |
|----------|-------------|----------|
| `DIMENSION(array)` | Nombre d'éléments (taille) | debug.pas, m68cgu.pas, m68mac.pas |
| `LOWERBOUND(array)` | Borne inférieure | deblex.pas, m68set.pas, p10sel.pas |
| `UPPERBOUND(array)` | Borne supérieure | deblex.pas, m68cgu.pas, m68str.pas, debprt.pas, m68set.pas, p10exp.pas, p10sel.pas, m68gen.pas |
| `SUBSTR(str, start, len)` | Extraction de sous-chaîne | mdlpro.pas, m68mac.pas, m68dmp.pas, debref.pas |
| `INDEX(str, char, default)` | Recherche dans une chaîne | mdlpro.pas |
| `LENGTH(str)` | Longueur de chaîne | m68mac.pas, m68cgu.pas, m68str.pas, mdlpro.pas, m68gen.pas |
| `VERIFY(str, charset, default)` | Vérification de caractères | m68mac.pas, debio.pas, m68str.pas |
| `SEARCH(str, charset)` | Recherche de caractères d'un ensemble | m68str.pas (commentaires) |
| `PUTSTRING(target, items...)` | Formatage dans un string | m68mac.pas, m68dmp.pas, debprt.pas, debio.pas |
| `WRITEV` / `WRITEV` | Écriture formatée vers un string | Windows.pas |
| `UPPERCASE(str)` | Conversion en majuscules | mdlpro.pas, tst106.pas, debref.pas |
| `LOWERCASE(str)` | Conversion en minuscules | tst106.pas |

### 7.2 Fonctions mathématiques et de type

| Fonction | Description | Fichiers |
|----------|-------------|----------|
| `MAXIMUM(type)` | Valeur maximale d'un type | debug.typ, m68imd.pas, debprt.pas, debref.pas |
| `MINIMUM(type)` | Valeur minimale d'un type | debug.typ, debref.pas, debprt.pas |
| `MAX(a, b, ...)` | Maximum avec args multiples | tst106.pas, heat2d.pas |
| `MIN(a, b, ...)` | Minimum avec args multiples | tst106.pas, m68mac.pas |
| `SIZE(type)` | Taille d'un type en octets/mots | test65.pas |
| `SIZE(type, tag_values...)` | Taille d'un variant spécifique | test65.pas |
| `ADDRESS(var)` | Adresse d'une variable | tst100.pas |
| `ORD(ADDRESS(var))` | Adresse comme entier | tst100.pas |
| `RANDOM` / `RANDOM(d)` | Nombre aléatoire | tst106.pas |
| `ABS()`, `SQR()`, `SQRT()` | Fonctions mathématiques standard | tst106.pas, heat2d.pas |
| `LN()`, `ARCTAN(x, y)` | Log, arctangente (2 args !) | tst106.pas |
| `TRUNC()`, `ROUND(x, mode)` | Troncature, arrondi avec mode | tst106.pas |
| `ASSERT(condition)` | Assertion (si checks activés) | m68cgu.pas, pasbod.pas |
| `ALLOCATE(ptr, size)` | Allocation par taille | pasbod.pas |

### 7.3 Fonctions I/O

| Fonction | Description | Fichiers |
|----------|-------------|----------|
| `CURSOR(file)` | Position du curseur dans un fichier texte | cursor.pas |
| `FILENAME(file)` | Nom du fichier ouvert | cursor.pas, m68dmp.pas, pascfm.pas |
| `IOSTATUS` / `IOSTATUS(file)` | État de la dernière opération I/O | m68dmp.pas, deblex.pas |
| `EOF(file)` / `EOLN(file)` | Fin de fichier / fin de ligne | pascfm.pas, m68mac.pas |

### Exemples :
```pascal
assert ((dimension (set_const) mod 16) = 0);
for i := lowerbound (rw_table) to upperbound (rw_table) do ...
cv_hex := substr (cv_hex, min (9-input_length, verify (cv_hex, ['0'], 8)));
semi := index (rtline, ';', length (rtline) + 1);
rtline := uppercase (substr (rtline, 1, semi - 1));
putstring (convert_four_bytes, input_four_bytes:8:h);
WriteV (Msg, Minutes_Left: 0);
single_real_ptr = ^minimum(real_type)..maximum(real_type) prec single_real_prec;
```

---

## 8. Opérateurs — Extensions DEC

| Opérateur | Description | Fichiers |
|-----------|-------------|----------|
| `ANDIF` | ET court-circuit (lazy evaluation) | m68cgu.pas, debref.pas, pasbod.pas, m68dmp.pas, m68exp.pas, deblex.pas |
| `ORIF` | OU court-circuit (lazy evaluation) | debref.pas, deblex.pas, m68gen.pas, p10exp.pas |
| `**` | Exponentiation | tst100.pas, tst106.pas |
| `\|\|` | Concaténation de chaînes | debdmp.pas, debio.pas, m68mac.pas, m68dmp.pas, mdlpro.pas, pasbod.pas |
| `.Length` | Accès à la longueur d'un VARYING string | Windows.pas |

### Exemples :
```pascal
while (local_index <= maximum(ESDID_range)) andif (...)  do ...
comp$types := (left.dkind = right.dkind) orif (...)
fname := list_file || '.SYM';
If Msg.Length > 0 then ...
result := base ** exponent;
```

---

## 9. Contrôle de flux — Extensions DEC

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `LOOP` ... `EXIT IF cond` ... | Boucle infinie avec sortie conditionnelle | debref.pas, debio.pas, m68cgu.pas |
| `EXIT IF cond DO stmt` | Sortie avec action | debref.pas |
| `RETURN` | Retour anticipé de procédure/fonction | debref.pas, m68cgu.pas, pasbod.pas, mdlpro.pas |
| `STOP` | Arrêt du programme | test4.pas, pasbod.pas |
| `LABEL` | Déclarations d'étiquettes numériques | pasbod.pas (gestion du compilateur) |
| `GOTO label` | Saut à une étiquette | pasbod.pas (gestion du compilateur) |

### Exemples :
```pascal
loop
  ... instructions ...
  exit if (level = 0) or (id_intsym <> ord(nil));
  ... instructions ...
end;

exit if field_number > upperbound(elem_vals);

if left.type_ptr = right.type_ptr then return;
```

---

## 10. Gestion d'exceptions (Condition Handling)

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `EXCEPTION` clause | Bloc exception dans un compound statement | pasbod.pas (ligne 960+) |
| Handlers avec identifiants | Labels de handler par nom de condition | pasbod.pas |
| `OTHERS` handler | Handler par défaut | pasbod.pas, test81.pas |
| `ALLCONDITIONS` handler | Handler pour toutes conditions | pasbod.pas |
| `SIGNAL(condition)` | Signaler une condition/exception | pasbod.pas (ligne 682) |
| `RESIGNAL` | Re-signaler au handler parent | pasbod.pas (ligne 693) |
| `MASK(condition)` | Masquer une condition | pasbod.pas (ligne 728) |
| `UNMASK(condition)` | Démasquer une condition | pasbod.pas (ligne 728) |
| Condition names prédéfinies | `E.CMATH`, `E.CIO`, `E.CPROG`, `E.CATTN`, `E.CHEAP`, `E.CSTACK`, `E.CSPEC` | m68imd.pas |

### Exemples (reconstitués depuis le compilateur) :
```pascal
begin
  ... code ...
exception
  [math_error]: writeln('Erreur math');
  [io_error]:   writeln('Erreur I/O');
  [others]:     resignal;
end;

signal(my_condition);
mask(math_error);
unmask(math_error);
```

---

## 11. Système d'entrées/sorties — Extensions DEC

### 11.1 Opérations de fichier

| Opération | Description | Fichiers |
|-----------|-------------|----------|
| `OPEN(file)` | Ouvrir un fichier | m68dmp.pas, pasbod.pas |
| `OPEN(file, name)` | Ouvrir avec nom | m68dmp.pas |
| `OPEN(file, name, [options])` | Ouvrir avec options | pasbod.pas |
| `RESET(file)` / `RESET(file, name)` | Réinitialiser en lecture | cursor.pas, m68dmp.pas |
| `RESET(file, name, [retry])` | Reset avec option retry | m68dmp.pas |
| `REWRITE(file)` / `REWRITE(file, name)` | Ouvrir en écriture | cursor.pas |
| `UPDATE(file)` | Ouvrir en mise à jour | pasbod.pas |
| `CLOSE(file)` | Fermer un fichier | m68dmp.pas, m68mac.pas |
| `CLOSE` (sans param) | Fermer tous les fichiers | pasbod.pas |
| `SEEK(file, index)` | Accès aléatoire | pasbod.pas |
| `SCRATCH(file)` | Supprimer fichier temporaire | pasbod.pas |
| `GET(file)` | Lire le buffer courant | pasbod.pas |
| `PUT(file)` | Écrire le buffer courant | pasbod.pas |
| `PAGE(file)` | Saut de page | pasbod.pas |
| `CLEAR(file)` | Effacer fichier | pasbod.pas |
| `BREAK(file)` | Forcer vidage du buffer | pasbod.pas |
| `EMPTY(file)` | Vider le buffer | pasbod.pas |

### 11.2 Fichiers prédéfinis

| Fichier | Description | Fichiers |
|---------|-------------|----------|
| `TTY` | Terminal (entrée/sortie) | m68dmp.pas, cursor.pas, m68mac.pas, pasglb.pas |
| `TTYOUTPUT` | Terminal (sortie seule) | cursor.pas, pasbod.pas |
| `INPUT` / `OUTPUT` | Fichiers standard (standard Pascal) | heat2d.pas |

### 11.3 Statuts I/O prédéfinis

| Constante | Description | Fichiers |
|-----------|-------------|----------|
| `IO_OK` | Opération réussie | m68dmp.pas, m68imd.pas |
| `IO_NOVF` | Overflow numérique | deblex.pas, m68imd.pas |
| `IO_POVF` | Page overflow | cursor.pas |
| `IO_DGIT` | Mauvais chiffre | deblex.pas, m68imd.pas |
| `IO_GOVF` | Overflow général | cursor.pas |
| `IO_INTR` | Interruption | cursor.pas |
| `IO_REWR` | Rewrite | cursor.pas |
| `IO_EOF` | Fin de fichier | m68imd.pas |
| `IO_OUTF` | Output | cursor.pas |
| `IO_INPF` | Input | cursor.pas |
| `IO_SEEK` | Seek error | cursor.pas |
| `IO_ILLC` | Illegal character | cursor.pas |
| `IO_NEPF` | Not existing | cursor.pas |
| `IO_OPNF` | Open failure | cursor.pas |

### 11.4 PUTSTRING — Formatage

| Format | Description | Fichiers |
|--------|-------------|----------|
| `:width` | Largeur minimale | m68dmp.pas |
| `:width:h` | Sortie hexadécimale | m68dmp.pas, m68mac.pas |
| `:width:o` | Sortie octale | debio.pas, debprt.pas |
| `:0` | Largeur minimale (pas de padding) | debio.pas |

### 11.5 FIO (Formatted I/O Library)

| Routine | Description | Fichiers |
|---------|-------------|----------|
| `fio_open(fb, name)` | Ouvrir via FIO | m68mac.pas, pasdmp.pas, m68dmp.pas |
| `fio_close(fb)` | Fermer via FIO | pasdmp.pas, m68mac.pas |
| `fio_reopen(fb)` | Rouvrir via FIO | m68mac.pas, pasdmp.pas |
| `fio_write(fb, text)` | Écrire texte | m68mac.pas, pasdmp.pas |
| `fio_line(fb, text)` | Écrire ligne | m68mac.pas, pasdmp.pas |
| `fio_tab(fb, col)` | Tabuler | m68mac.pas, pasdmp.pas |
| `fio_eject` | Saut de page | m68mac.pas, pasdmp.pas |
| `fio_nop` | Opération nulle | m68mac.pas, pasdmp.pas |

---

## 12. Déclarations — Extensions DEC

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `STATIC VAR` | Variable statique (persistante entre appels) | test5.pas, m68imd.pas |
| Initialisation de variable : `var c: char := 'a'` | Valeur initiale dans la déclaration | test5.pas |
| Initialisation de constante typée : `const x: type := value` | Constante typée avec `:=` | debug.pas, m68imd.pas |
| Initialisation de tableau constant | `array [type] of string := ('val1', 'val2', ...)` | cursor.pas, m68mac.pas |
| Record constructors (tuple) | `X := ('A', 'B', 6)` | test81.pas |
| `STATIC VAR` avec init | `static var x: type := value` | m68imd.pas |
| Types procéduraux | `var P1: PROCEDURE(BOOLEAN; VAR BOOLEAN)` | test30.pas |
| Types fonctionnels | `type semantic_function = function(parse_node): expr` | pasbod.pas |
| Paramètres nommés | `Ring_Bell(Display_Id, Number_of_Times:=3)` | Windows.pas |
| Paramètres par défaut | `Number_of_Times: Integer := 1` | Windows.pas |

### Exemples :
```pascal
static var
    r_8_8_8: rule_node := ( nil, 8, 8, 8 );
    x_efw: bit_range := 32;

const
    status_text: array [io_status] of string
       := ('IO_OK', 'IO_NOVF', 'IO_POVF', ...);

type semantic_function = function ( parse_node ): expr;

var P1: PROCEDURE(BOOLEAN; VAR BOOLEAN);
```

---

## 13. Chaînes de caractères — Fonctionnalités avancées

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `VARYING [n] OF CHAR` | String de longueur variable | Windows.pas |
| `.Length` accès direct | Longueur courante d'un VARYING | Windows.pas |
| `STRING [n]` type | Chaîne fixe type DEC | m68mac.pas, m68dmp.pas, debug.typ, mdlpro.pas |
| `STRING [*]` conformant | Paramètre chaîne de taille quelconque | m68dmp.pas, debio.pas |
| `\|\|` concaténation | Opérateur de concaténation | m68mac.pas, mdlpro.pas, m68dmp.pas, debio.pas |
| `str[i]` indexation | Accès caractère par index | mdlpro.pas |
| Slice assignment | `str_val [1:length(name)] := name` | pasbod.pas |
| `SUBSTR`, `INDEX`, `LENGTH`, `VERIFY` | Opérations sur chaînes | Voir section 7.1 |
| Comparaison avec `''` | Chaîne vide | mdlpro.pas, m68mac.pas |

### Exemples :
```pascal
Long_Line = Varying [390] of Char;
If Msg.Length > 0 then ...
Msg[X] := ' ';
fname := list_file || '.SYM';
rtline := uppercase (substr (rtline, 1, semi - 1));
while rtline [length(rtline)] = ' ' do
    rtline := substr (rtline, 1, length(rtline) - 1);
```

---

## 14. Identifiants — Extensions DEC

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `$` dans les identifiants | Dollar comme caractère valide | debug.pas (`a$$ert`, `writ$str`), debref.pas (`comp$types`, `ext$scalar`, `deref$ptr`), debprt.pas, debdmp.pas (`R50$ASC`) |
| `_` (underscore) | Underscore dans identifiants | Quasi-totalité des fichiers |
| Identifiants système `SMG$*`, `LIB$*` | Appels services VMS | Windows.pas |

### Exemples :
```pascal
a$$ert (desc.dkind in [string_dt, substr_dt]);
comp$types := (left.dkind = right.dkind);
SMG$Create_Virtual_Display (5, 78, Display_ID, 1);
LIB$Get_Input (Input, '> ');
```

---

## 15. Variants et records — Extensions

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `OTHERS` dans variants CASE | Variante par défaut | test81.pas |
| Record constructors (tuples) | Initialisation par valeurs positionnelles | test81.pas |
| `NEW(ptr, tag1, tag2, ...)` | Allocation avec tags de variant | tst101.pas, test60.pas, pasbod.pas |
| `SIZE(type, tag_values)` | Taille d'un variant spécifique | test65.pas |
| `DISPOSE(ptr)` | Libération (standard, supporté) | pascfm.pas, pasbod.pas |
| Variant record avec flex array | Flexible array dans un variant | test60.pas, tst100.pas |

### Exemples :
```pascal
type rec = record
    case tag: char of
      'A': (x: integer);
      'B': (y: real);
      others: (z: boolean)
end;

X := ('A', 'B', 6);  { record constructor }
new (p, tag_value1, tag_value2);
s := size(rec, 'A');
```

---

## 16. Divers

| Fonctionnalité | Description | Fichiers |
|----------------|-------------|----------|
| `R50$ASC()` | Conversion Radix-50 vers ASCII | debdmp.pas |
| `WITH` statement | Raccourci pour accès record | debug.typ (with_table), pasbod.pas |
| `{ }` commentaires | Style Turbo Pascal / VMS Pascal | Windows.pas |
| `(* *)` commentaires | Style standard Pascal | Tous les fichiers |
| `IN` opérateur sur ensembles | Appartenance à un ensemble | Omniprésent |
| `SET OF range` | Ensembles | test4.pas, debug.typ |
| `SQR()` | Carré | heat2d.pas |
| `#CN` | Nom terminal prédéfini | m68imd.pas (`ttyiname := '#CN'`) |

---

## 17. Résumé des procédures standard étendues

Liste complète trouvée dans `pasbod.pas` (lignes 700-730) :

```
OPEN, RESET, REWRITE, UPDATE,
GET, PUT, PAGE, CLEAR, BREAK, EMPTY,
CLOSE, SCRATCH,
READ8, WRITE8, SEEK,
NEW, ALLOCATE, DISPOSE,
ASSERT,
SIGNAL, MASK, UNMASK
```

---

## 18. Fichiers clés par catégorie

### Fichiers de test
- **tst100.pas** : Conformant arrays, DIMENSION, LOWERBOUND, UPPERBOUND, flex arrays, NEW+size, **, ADDRESS
- **tst101.pas** : Flex arrays, NEW avec tags
- **tst106.pas** : PREC, RANDOM, LOWERCASE, UPPERCASE, ARCTAN(x,y), ROUND(x,mode), **
- **tst200.pas** : Pointeurs, variant records
- **test4.pas** : Packed records, octal, STOP
- **test5.pas** : EXTERNAL, FORWARD, PUBLIC, STATIC VAR, initialisation `:=`
- **test30.pas** : Types procéduraux/fonctionnels
- **test60.pas** : NEW avec multiples tags, flex arrays dans variants
- **test64.pas** : EXTERNAL avec types forward/non définis
- **test65.pas** : SIZE avec tags de variants
- **test81.pas** : Record constructors, OTHERS dans variants
- **cursor.pas** : CURSOR(), FILENAME(), OPEN, RESET, REWRITE, TTY, TTYOUTPUT, IO_STATUS, file_name

### Fichiers compilateur (sources du compilateur DEC Pascal lui-même)
- **debug.pas** : MODULE, OPTIONS, PUBLIC, $INCLUDE, $TITLE/$HEADER/$PAGE, machine_word, string, packed array[1..*]
- **debug.typ** : $IF/$ENDIF, machine_word, MAXIMUM, MINIMUM, packed records, types complexes
- **pasbod.pas** : TOUTES les procédures standard, exception handling, I/O calls, NEW/DISPOSE/ALLOCATE
- **m68cgu.pas** : ASSERT massif, ANDIF, RETURN, upperbound/dimension, packed array[1..*]
- **m68mac.pas** : PUTSTRING, SUBSTR, VERIFY, LENGTH, string[n], FIO library, ||
- **m68dmp.pas** : OPEN, RESET, CLOSE, IOSTATUS, FILENAME, ||, PUTSTRING
- **m68imd.pas** : PUBLIC CONST, STATIC VAR, condnames, machine constants, MAXIMUM
- **m68str.pas** : SEARCH, VERIFY, upperbound, LENGTH, substring operations
- **mdlpro.pas** : EXTERNAL VAR, PUBLIC VAR, INDEX, SUBSTR, UPPERCASE, LENGTH, RETURN, #o octaux
- **debref.pas** : ANDIF/ORIF massif, RETURN, LOOP/EXIT IF, machine_word, PREC
- **debprt.pas** : PUTSTRING:o, machine_word, MAXIMUM, PREC, packed array[1..*]
- **deblex.pas** : ORIF, LOWERBOUND, UPPERBOUND, IOSTATUS
- **debio.pas** : LOOP/EXIT IF, chr(#O15), string[*], ||, PUTSTRING:h:o, VERIFY

### Programme applicatif
- **Windows.pas** : [Inherit], [Global], [External], Module, VARYING, Unsigned, .Length, SubStr, WriteV, paramètres nommés/défaut, SMG$/LIB$
- **heat2d.pas** : Programme numérique, MAX, SQR, SQRT
- **anal.pas** : EXTERNAL function/procedure, PUBLIC procedure, $INCLUDE, GOTO/LABEL

---

## 19. Fonctionnalités NON trouvées dans les échantillons

Les fonctionnalités suivantes de VAX Pascal **ne sont pas attestées** dans les fichiers examinés (mais pourraient exister dans les fichiers binaires non lisibles) :

- `VOLATILE` / `READONLY` / `ALIGNED` / `POS()` / `OVERLAID` / `COMMON` — attributs supplémentaires
- `VALUE` section (section d'initialisation VAX Pascal v4+)
- `DOUBLE` type (flottant double précision DEC)
- Schema types (types paramétrés VAX Pascal v4+)
- `FORTRAN` / `C` calling conventions dans les attributs
- `QUADRUPLE` type
- `TIMESTAMP` / `DATE` / `TIME` functions
- `BIT` / `BIT_ARRAY` types
- `%INCLUDE` (forme alternative de $INCLUDE)
