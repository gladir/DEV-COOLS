{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur JavaScript vers assembleur 80386, 32 bits, pour Windows 32 bits.

  TODO - feuille de route JSCW32.PAS
  01. [IMPLEMENTE] Definir le pipeline canonique .JS -> tokens -> AST -> analyse semantique -> IR -> ASM 80386 -> OBJ COFF -> EXE PE32, avec .EXE Windows produit par defaut ; l'ASM n'est qu'une etape intermediaire optionnelle (jamais ecrite sur disque sans demande explicite).
  02. [IMPLEMENTE] Ajouter le parsing des options de ligne de commande : mode EXE par defaut, parametre pour produire uniquement un .OBJ (sans edition de liens), parametre explicite pour emettre aussi le .ASM, noms de sortie (-o), mode verbose, aide/version, et regles de nommage par defaut (HELLO.JS -> HELLO.EXE / HELLO.OBJ / HELLO.ASM).
  03. [IMPLEMENTE] Implementer le chargeur source et le lexer JavaScript complet : normalisation CR/LF, suivi ligne/colonne, diagnostics avec caret, identifiants, mots-cles (var/let/const/function/class/extends/super/new/this/typeof/void/instanceof/in/of/try/catch/finally/throw...), nombres (decimal, flottant, exposant 1.5e3, hexa 0xFF, binaire 0b1010, octal, separateurs 1_000_000), chaines '...' et "..." avec echappements, template literals avec interpolation (dollar-accolade), litteraux RegExp /re/flags (desambiguises de la division), commentaires // et /* */, tous les operateurs (=== !== ** ?? ?. => ... >>> et affectations composees) et NaN/Infinity/null/undefined/true/false.
  04. [IMPLEMENTE] Parser les instructions : var/let/const (avec destructuration simple), blocs, if/else if/else, switch/case/default, while, do-while, for, for-in, for-of, break/continue (avec etiquettes), return, throw, try/catch/finally, declarations function et class, instructions vides/expressions, insertion automatique des points-virgules (ASI) et hoisting des declarations.
  05. [IMPLEMENTE] Parser les expressions avec precedences et associativites exactes : virgule, affectations (= += -= *= /= %= **= <<= >>= >>>= &= |= ^= &&= ||= ??=), ternaire, ?? || &&, bit a bit, ==/!=/===/!==, relationnels (instanceof, in), decalages, + -, * / %, **, unaires (typeof void delete ! ~ + - ++ --), postfixes, appels/membres/new, optional chaining, spread/rest, fonctions anonymes, fonctions fleches (x => x*2, (a,b) => corps de bloc), litteraux de tableaux et d'objets (raccourcis, cles calculees, methodes, getters/setters), parametres par defaut.
  06. [IMPLEMENTE] Construire l'AST et l'analyse semantique : table des symboles et des scopes (global, fonction, bloc), hoisting de var/function, zone morte temporelle (TDZ) de let/const, erreur sur reaffectation d'une const, detection des variables capturees par des fonctions imbriquees (necessaire aux closures), resolution de this (global, methode, constructeur, fleche) et diagnostics de redeclaration/variable non declaree.
  07. [IMPLEMENTE] Definir le modele de valeurs runtime 32 bits et le gestionnaire memoire : valeurs etiquetees (undefined, null, booleen, nombre, chaine, objet, tableau, fonction/closure, RegExp), nombres IEEE 754 via FPU x87 avec chemin rapide entier, allocation sur le tas Windows (HeapAlloc/VirtualAlloc), tampons de chaines, pile d'appels, et ramasse-miettes simple (mark & sweep) ou strategie documentee de non-liberation.
  08. [IMPLEMENTE] Implementer le pool de constantes et de donnees : chaines litterales internees, constantes flottantes, atomes de noms de proprietes, descripteurs de fonctions/classes, sections .data/.rdata, alignement et noms de symboles stables prefixes (variables, fonctions, chaines, runtime, labels).
  09. [IMPLEMENTE] Generer le code 80386 pour les variables et leur portee : globales, locales sur cadre EBP, parametres, cellules heap pour les variables capturees, initialisation a undefined, TDZ de let/const, affectation, declarations multiples et destructuration, compatibilite avec hello.js, test03/test03b, test04/test04b et test09.
  10. [IMPLEMENTE] Generer les expressions et les conversions de types JavaScript : arithmetique (+ - * / % **), division par zero (Infinity/NaN), comparaisons, == (coercition) vs === (strict), ToNumber/ToString/ToBoolean/ToPrimitive, truthy/falsy, court-circuit && || ??, ternaire, operateurs bit a bit et decalages, ++/-- pre/post, affectations composees, typeof/void/delete/in/instanceof, compatibilite avec test10/test10adv, test11/test11adv, t04_12, t09_15 et t09full.
  11. [IMPLEMENTE] Generer les structures de controle : if/else if/else, switch/case (egalite stricte, fall-through, default), while, do-while, for, for-in, for-of (tableaux et chaines), break/continue simples et etiquetes, labels internes uniques et sauts 80386 fiables, avec control.js, test13 et test14.
  12. [IMPLEMENTE] Implementer les fonctions : declarations (hoistees), expressions, fonctions fleches (corps expression ou bloc), convention d'appel interne (arguments, this, environnement de closure, nombre d'arguments), recursion (factorial/fib de math.js), return sans valeur -> undefined, parametres par defaut/rest/spread, objet arguments, fonctions de premier ordre (callbacks, apply(f, v)), operateur de reference &fn supporte par test22.js, avec test17 et test18.
  13. [IMPLEMENTE] Implementer les closures et le this lexical : environnements captures (cellules partagees entre fonctions), duree de vie apres le retour de la fonction englobante, fonctions imbriquees, fleches capturant this, makeCounter/makeAdder/makeMultiplier, variable modifiee apres creation de la closure (test22.js) et profondeur d'imbrication (test18.js).
  14. [IMPLEMENTE] Implementer les chaines : allocation et concatenation (+), template literals avec interpolation de nombres/chaines/expressions, length, indexation, comparaison, echappements, conversion nombre -> chaine et methodes String (indexOf, lastIndexOf, includes, startsWith, endsWith, charAt, charCodeAt, toUpperCase, toLowerCase, trim, slice, substring, repeat, padStart, split, String.fromCharCode), avec test20.js.
  15. [IMPLEMENTE] Implementer les tableaux : litteraux (imbriques, vides), new Array(n), acces et affectation par index, length, push/pop/shift/unshift, indexOf, reverse, sort (par defaut lexicographique + comparateur), forEach, slice/splice/concat/join/includes/map/filter/reduce, Array.isArray, iteration for-of, avec arrays.js, test10adv, test15 et control.js.
  16. [IMPLEMENTE] Implementer les objets et prototypes : litteraux, acces par point et par crochets, ajout/modification/suppression dynamique de proprietes (table de hachage avec ordre d'insertion), in, hasOwnProperty, chaine de prototypes, getters/setters, Object.keys/values/entries/assign/create/freeze/getPrototypeOf, avec objects.js et test16.
  17. [IMPLEMENTE] Implementer les classes : declaration et expression de classe, constructor, methodes d'instance, methodes statiques, extends, super(...) et super.methode(), new, instanceof, getters/setters, champs, ordre d'initialisation, heritage multi-niveaux (Dog/Cat extends Animal), avec classes.js et test21.js.
  18. [A FAIRE] Implementer les exceptions : try/catch/finally, throw de n'importe quelle valeur, classes Error/TypeError/RangeError/SyntaxError avec message, deroulement de pile via pile de gestionnaires (ou SEH Windows), finally execute meme avec return/break/continue, exception non rattrapee (message sur stderr + code de sortie non nul), erreurs runtime (appel d'un non-fonction, propriete d'undefined), avec test23.js.
  19. [A FAIRE] Implementer les objets globaux et built-ins numeriques : Math (abs, max, min, pow, sqrt, floor, ceil, round, trunc, sign, random, PI, E...), Number (isInteger, isNaN, isFinite, parseFloat, MAX_VALUE...), Number()/parseInt (avec base)/parseFloat/isNaN/isFinite, JSON.stringify et JSON.parse reels (pas des stubs), NaN/Infinity/undefined/globalThis, avec math.js, test20.js et test24.js.
  20. [A FAIRE] Implementer les expressions regulieres : litteraux /re/flags (g, i, m, ainsi que les flags non standards rencontres dans test03.js), new RegExp(pattern, flags), moteur a backtracking (classes, quantificateurs, groupes, ancres, alternatives), RegExp.test/exec, String.match/matchAll/search/replace/split, lastIndex, avec test19.js.
  21. [A FAIRE] Implementer l'interface console, processus et systeme hote Windows : console.log (plusieurs arguments, nombres entiers/flottants/negatifs, booleens, null, undefined, objets et tableaux), console.error/warn vers stderr, process.stdout.write (sans saut de ligne), process.exit(code), process.argv, alert (comme console.log), prompt (lecture de stdin), imports kernel32 (GetStdHandle, WriteFile, ReadFile, GetCommandLineA, HeapAlloc, ExitProcess), avec hello.js, test12.js et test24.js.
  22. [A FAIRE] Construire le generateur ASM 80386 optionnel : syntaxe assembleur Windows 32 bits (.386, .MODEL FLAT, sections .text/.data/.rdata, EXTERN/PUBLIC), labels stables, commentaires reprenant les lignes JavaScript d'origine, routines runtime appelees par noms stables, emission du .ASM uniquement sur demande explicite de l'utilisateur.
  23. [A FAIRE] Construire le generateur OBJ COFF i386 : en-tete, sections .text/.data/.rdata/.bss, table de symboles, relocations (REL32/DIR32), symboles externes importes de kernel32, production d'un .OBJ seul quand le parametre le demande, et validation du format avec les outils DUMPBIN.PAS / OBJDUMP.PAS / NM.PAS du depot.
  24. [A FAIRE] Construire le linker PE32 interne : en-tetes MZ/PE, sections alignees, table d'imports kernel32 (et runtime propre), resolution des relocations, point d'entree, sous-systeme console, ecriture du .EXE final par defaut, suppression des anciens .EXE perimes et verification avec DISEXE.PAS.
  25. [A FAIRE] Ajouter le harnais de validation et stabiliser : option -test compilant tous les SAMPLES\JS\* (arrays, classes, control, hello, math, objects, t04_12, t09_15, t09full, test03, test03b, test04, test04b, test09, test10, test10adv, test11, test11adv, test12 a test24), execution des .EXE et comparaison avec les valeurs « attendu » des commentaires, modes EXE / OBJ / ASM+OBJ, nettoyage des artefacts, compatibilite Free Pascal/Turbo Pascal (types bornes, buffers, aucune dependance moderne), diagnostics finaux et documentation d'utilisation.
}
Program JSCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}
{$IFNDEF FPC}
  {$N+}
{$ENDIF}

{ ============================================================
  TODO 1 - PIPELINE CANONIQUE

  .JS -> tokens -> AST -> analyse semantique -> IR
      -> ASM 80386 -> OBJ COFF -> EXE PE32

  Regles de production des fichiers :
    - Par defaut, seul le .EXE Windows est ecrit sur disque.
    - Avec le mode OBJ, la chaine s'arrete a l'OBJ COFF, qui est
      alors le seul fichier ecrit (pas d'edition de liens).
    - L'ASM est toujours produit en memoire (l'OBJ en derive), mais
      n'est ecrit sur disque que si l'utilisateur le demande
      explicitement (emit_asm).
    - L'OBJ intermediaire d'un build EXE n'est pas conserve.
  ============================================================ }

Const
  JSCW32_VERSION = '1.0';
  JSCW32_DATE    = '2026';
  MAX_PATH_LEN   = 255;
  EXIT_OK        = 0;
  EXIT_ERROR     = 1;
  EXIT_USAGE     = 2;
  EXT_JS         = '.js';
  EXT_ASM        = '.asm';
  EXT_OBJ        = '.obj';
  EXT_EXE        = '.exe';
  MAX_ERRORS         = 30;
  MAX_SOURCE_CHARS   = {$IFDEF FPC}262144{$ELSE}30000{$ENDIF};
  MAX_SOURCE_LINES   = {$IFDEF FPC}16384{$ELSE}1500{$ENDIF};
  MAX_TOKENS         = {$IFDEF FPC}32768{$ELSE}1000{$ENDIF};
  MAX_STRING_POOL    = {$IFDEF FPC}262144{$ELSE}12000{$ENDIF};
  MAX_TEMPLATE_DEPTH = 16;
  MAX_TOKEN_TEXT     = 80;
  MAX_DIAG_LINE      = 160;
  MAX_NODES          = {$IFDEF FPC}65536{$ELSE}1500{$ENDIF};
  MAX_DECLS          = {$IFDEF FPC}16384{$ELSE}500{$ENDIF};
  MAX_LABELS         = 32;
  { Genre de declaration (flags de VAR_DECL) }
  DF_VAR = 1;
  DF_LET = 2;
  DF_CONST = 3;
  { Fonctions, parametres, membres de classe, motifs }
  FN_GENERATOR = 1;
  FN_ASYNC = 2;
  PF_REST = 1;
  PP_SHORTHAND = 1;
  PP_COMPUTED = 2;
  PP_REST = 4;
  MF_STATIC = 1;
  MF_GETTER = 2;
  MF_SETTER = 4;
  MF_COMPUTED = 8;
  MF_CONSTRUCTOR = 16;
  MF_GENERATOR = 32;
  MF_ASYNC = 64;
  FN_ARROW = 4;
  FN_EXPR_BODY = 8;
  FN_METHOD = 16;
  { Proprietes d'objet litteral }
  PR_SHORTHAND = 1;
  PR_COMPUTED = 2;
  PR_SPREAD = 4;
  PR_METHOD = 8;
  PR_GETTER = 16;
  PR_SETTER = 32;
  PR_DEFAULT = 64;
  { Expressions : maillon optionnel (?.) et ++/-- prefixe }
  EF_OPTIONAL = 1;
  UF_PREFIX = 1;
  MAX_SCOPES         = {$IFDEF FPC}16384{$ELSE}300{$ENDIF};
  MAX_SYMS           = {$IFDEF FPC}16384{$ELSE}500{$ENDIF};
  MAX_CAPS           = {$IFDEF FPC}8192{$ELSE}300{$ENDIF};
  { Drapeaux des symboles }
  SF_CAPTURED     = 1;      { reference depuis une fonction imbriquee }
  SF_CELL         = 2;      { doit vivre dans une cellule partagee }
  SF_REASSIGNED   = 4;      { ecrit apres son initialisation }
  SF_TDZ_CHECK    = 8;      { test de zone morte a l'execution }
  SF_PER_ITER     = 16;     { une copie par iteration de boucle }
  SF_STATIC       = 32;     { stockage statique (portee globale) }
  SF_HOISTED      = 64;     { var ou fonction : initialise a l'entree }
  SF_IMPLICIT     = 128;    { globale implicite }
  SF_INITIALIZING = 256;    { en cours d'initialisation }
  { Mode d'acces a un identifiant }
  RM_READ = 1;
  RM_WRITE = 2;
  RM_READWRITE = 3;
  { Resolution d'une reference (champ aux d'un noeud IDENT) }
  RK_LOCAL = 1;
  RK_OUTER = 2;
  RK_BUILTIN = 3;
  RK_GLOBAL_IMPLICIT = 4;
  RK_ARGUMENTS = 5;
  RK_UNDECLARED_OK = 6;
  RK_UNRESOLVED = 7;
  { Liaison de this (champ aux d'un noeud THIS) }
  TB_GLOBAL = 1;
  TB_FUNCTION = 2;
  TB_METHOD = 3;
  TB_CTOR = 4;
  TB_DERIVED_CTOR = 5;
  TB_STATIC = 6;
  TB_FIELD = 7;
  { ---- Modele de valeurs runtime (TODO 7) ---- }
  RT_VALUE_SIZE = 8;
  RT_VAL_LO = 0;
  RT_VAL_HI = 4;
  RT_TAG_PREFIX = 'FFF9';         { hi = FFF9xxxxh pour les valeurs etiquetees }
  RT_T_INT32 = 0;
  RT_T_UNDEFINED = 1;
  RT_T_NULL = 2;
  RT_T_BOOLEAN = 3;
  RT_T_STRING = 4;
  RT_T_OBJECT = 5;
  RT_T_ARRAY = 6;
  RT_T_FUNCTION = 7;
  RT_T_REGEXP = 8;
  RT_T_TDZ = 9;                   { variable lexicale pas encore initialisee }
  RT_T_DONE = 10;                 { fin d'iteration (interne) }
  RT_TAG_BASE = $FFF90000;
  RT_FPU_CW = '027F';
  { cellule du tas }
  RT_HDR_SIZE = 8;
  RT_HDR_KIND = 0;
  RT_HDR_GC = 1;
  RT_HDR_FLAGS = 2;
  RT_HDR_NEXT = 4;
  RT_ALIGN = 8;
  RT_OK_STRING = 1;
  RT_OK_ARRAY = 2;
  RT_OK_OBJECT = 3;
  RT_OK_FUNCTION = 4;
  RT_OK_CELL = 5;
  RT_OK_REGEXP = 6;
  RT_OK_ENV = 7;
  RT_STR_LEN = 8;
  RT_STR_HASH = 12;
  RT_STR_DATA = 16;
  RT_ARR_LEN = 8;
  RT_ARR_CAP = 12;
  RT_ARR_ELEMS = 16;
  RT_ARR_SIZE = 24;
  RT_OBJ_PROTO = 8;
  RT_OBJ_PROPS = 12;
  RT_OBJ_COUNT = 16;
  RT_OBJ_CAP = 20;
  RT_OBJ_CLASS = 24;
  RT_OBJ_SIZE = 32;
  RT_OBJ_INDEX = 28;
  RT_PROP_KEY = 0;
  RT_PROP_FLAGS = 4;
  RT_PROP_VALUE = 8;
  RT_PROP_SIZE = 16;
  RT_FN_CODE = 8;
  RT_FN_ENV = 12;
  RT_FN_DESC = 16;
  RT_FN_PROPS = 20;
  RT_FN_THIS = 24;
  RT_FN_SIZE = 32;
  RT_FD_NAME = 0;
  RT_FD_NPARAMS = 4;
  RT_FD_FLAGS = 8;
  RT_FD_NCELLS = 12;
  RT_FD_SIZE = 16;
  RT_CELL_VALUE = 8;
  RT_CELL_SIZE = 16;
  RT_ENV_COUNT = 8;
  RT_ENV_CELLS = 12;
  RT_RX_SOURCE = 8;
  RT_RX_FLAGS = 12;
  RT_RX_PROG = 16;
  RT_RX_LASTINDEX = 20;
  RT_RX_SIZE = 24;
  { tas et pile }
  RT_ARENA_SIZE = 1048576;
  RT_BIG_ALLOC = 262144;
  RT_STACK_RESERVE = 4194304;
  RT_STACK_GUARD = 65536;
  { convention d'appel : decalages depuis EBP }
  RT_FRAME_CLOSURE = 8;
  RT_FRAME_ARGC = 12;
  RT_FRAME_THIS = 16;
  RT_FRAME_ARGS = 24;
  RT_EH_PREV = 0;
  RT_EH_ESP = 4;
  RT_EH_EBP = 8;
  RT_EH_CATCH = 12;
  RT_EH_SIZE = 16;
  { composants du runtime a lier (masque de bits) }
  RC_HEAP = 1;
  RC_FPU = 2;
  RC_STRING = 4;
  RC_NUMTOSTR = 8;
  RC_ARRAY = 16;
  RC_OBJECT = 32;
  RC_FUNCTION = 64;
  RC_CELL = 128;
  RC_CLASS = 256;
  RC_EXCEPTION = 512;
  RC_REGEXP = 1024;
  RC_CONSOLE = 2048;
  RC_PROCESS = 4096;
  RC_MATH = 8192;
  RC_JSON = 16384;
  RC_STRING_METHODS = 32768;
  RC_ARRAY_METHODS = 65536;
  RC_OBJECT_STATICS = 131072;
  RC_NUMBER_FUNCS = 262144;
  RC_CONVERT = 524288;
  RC_STDIN = 1048576;
  RC_TYPEOF = 2097152;
  RC_INSTANCEOF = 4194304;
  RC_ARGUMENTS = 8388608;
  RC_LAST = 8388608;
  { ---- Pool de donnees (TODO 8) ---- }
  SEC_RDATA = 1;
  SEC_DATA = 2;
  MAX_RDATA = {$IFDEF FPC}524288{$ELSE}8000{$ENDIF};
  MAX_DATA_IMG = {$IFDEF FPC}131072{$ELSE}4000{$ENDIF};
  MAX_DPOOL = {$IFDEF FPC}262144{$ELSE}8000{$ENDIF};
  MAX_STRS = {$IFDEF FPC}16384{$ELSE}500{$ENDIF};
  HASH_SIZE = {$IFDEF FPC}32768{$ELSE}1024{$ENDIF};
  MAX_DBLS = {$IFDEF FPC}4096{$ELSE}100{$ENDIF};
  MAX_FDESCS = {$IFDEF FPC}8192{$ELSE}300{$ENDIF};
  MAX_CDESCS = {$IFDEF FPC}1024{$ELSE}50{$ENDIF};
  MAX_CMEMBERS = {$IFDEF FPC}8192{$ELSE}300{$ENDIF};
  MAX_DSYMS = {$IFDEF FPC}32768{$ELSE}1000{$ENDIF};
  MAX_RELOCS = {$IFDEF FPC}32768{$ELSE}1000{$ENDIF};
  { genres de symboles de donnees }
  DS_STRING = 1;
  DS_DOUBLE = 2;
  DS_FDESC = 3;
  DS_CLASSDESC = 4;
  DS_ATOMS = 5;
  DS_RTVAR = 6;
  DS_GLOBAL = 7;
  OF_FROZEN = 2;                  { objet gele }
  OF_ROPROPS = 4;                 { tableau de proprietes en lecture seule }
  OF_STATIC = 1;                  { drapeau d'en-tete : cellule statique }
  { drapeaux d'un descripteur de fonction }
  FDF_ARROW = 1;
  FDF_ASYNC = 2;
  FDF_GENERATOR = 4;
  FDF_METHOD = 8;
  FDF_CTOR = 16;
  FDF_DERIVED = 32;
  FDF_STATIC = 64;
  FDF_GETTER = 128;
  FDF_SETTER = 256;
  FDF_USES_THIS = 512;
  FDF_USES_ARGS = 1024;
  FDF_THIS_CAPTURED = 2048;
  FDF_EXPR_BODY = 4096;
  FDF_FIELD_INIT = 8192;
  FDF_STATIC_BLOCK = 16384;
  FDF_NATIVE = 32768;
  { descripteur de classe : nom, constructeur, drapeaux, membres }
  RT_CD_NAME = 0;
  RT_CD_CTOR = 4;
  RT_CD_FLAGS = 8;
  RT_CD_NMEMBERS = 12;
  RT_CD_MEMBERS = 16;
  RT_CM_KEY = 0;
  RT_CM_FLAGS = 4;
  RT_CM_DESC = 8;
  RT_CM_SIZE = 16;
  CDF_DERIVED = 1;
  CM_STATIC = 1;
  CM_GETTER = 2;
  CM_SETTER = 4;
  CM_COMPUTED = 8;
  CM_FIELD = 16;
  CM_METHOD = 32;
  CM_CTOR = 64;
  CM_STATIC_BLOCK = 128;
  STD_STR_COUNT = 21;
  STD_ATOM_FIRST = 15;
  STD_DBL_NEGZERO = 3;
  STD_DBL_NAN = 4;
  STD_DBL_INF = 5;
  StdStrings: Array[1..STD_STR_COUNT] Of String[20] = (
    '', 'undefined', 'null', 'true', 'false', 'NaN', 'Infinity', '-Infinity',
    'object', 'boolean', 'number', 'string', 'function', '[object Object]',
    'length', 'prototype', 'constructor', 'name', 'message', 'toString',
    'valueOf'
  );
  RT_DATA_VAR_COUNT = 12;
  { ---- Code genere (TODO 9) ---- }
  SYMK_D = 1;                     { symbole du pool de donnees }
  SYMK_X = 2;                     { symbole de code ou externe }
  MAX_INSTR = {$IFDEF FPC}131072{$ELSE}2000{$ENDIF};
  MAX_XSYMS = {$IFDEF FPC}4096{$ELSE}200{$ENDIF};
  MAX_COMMENTS = {$IFDEF FPC}20000{$ELSE}500{$ENDIF};
  MAX_PENDING = 200;
  CK_NONE = 0;
  CK_NUM = 1;
  CK_BOOL = 2;
  CK_NULL = 3;
  CK_UNDEF = 4;
  { cibles de break et continue }
  MAX_JT = 32;
  JT_LOOP = 1;
  JT_SWITCH = 2;
  JT_BLOCK = 3;
  RtDataVars: Array[1..RT_DATA_VAR_COUNT] Of String[16] = (
    'heap_cur', 'heap_end', 'stack_limit', 'handler_top', 'stdin', 'stdout',
    'stderr', 'process_heap', 'argc', 'argv', 'exit_code', 'fpu_cw'
  );
  BUILTIN_COUNT = 47;
  Builtins: Array[1..BUILTIN_COUNT] Of String[20] = (
    'Array', 'BigInt', 'Boolean', 'Date', 'Error', 'EvalError', 'Function',
    'Infinity', 'JSON', 'Map', 'Math', 'NaN', 'Number', 'Object', 'Promise',
    'Proxy', 'RangeError', 'ReferenceError', 'Reflect', 'RegExp', 'Set',
    'String', 'Symbol', 'SyntaxError', 'TypeError', 'URIError', 'WeakMap',
    'WeakSet', 'alert', 'clearInterval', 'clearTimeout', 'console',
    'decodeURIComponent', 'encodeURIComponent', 'exports', 'globalThis',
    'isFinite', 'isNaN', 'module', 'parseFloat', 'parseInt', 'process',
    'prompt', 'require', 'setInterval', 'setTimeout', 'undefined'
  );

Type
  TString = String[MAX_PATH_LEN];
  TTokenText = String[MAX_TOKEN_TEXT];

  TCompileStage = (
    CS_LOAD_SOURCE,
    CS_LEX_TOKENS,
    CS_PARSE_AST,
    CS_ANALYZE,
    CS_BUILD_IR,
    CS_EMIT_ASM386,
    CS_BUILD_OBJ,
    CS_LINK_EXE
  );

  TArtifactKind = (
    AK_NONE,
    AK_SOURCE_JS,
    AK_TOKEN_STREAM,
    AK_AST,
    AK_AST_ANALYZED,
    AK_IR,
    AK_ASM_386,
    AK_OBJ_COFF,
    AK_EXE_PE32
  );

  TOutputMode = (
    OM_EXE,
    OM_OBJ
  );

  TPipelineOptions = Record
    output_mode : TOutputMode;
    emit_asm    : Boolean;
    verbose     : Boolean;
    show_help   : Boolean;
    show_version: Boolean;
    dump_tokens : Boolean;
    dump_ast    : Boolean;
    dump_scopes : Boolean;
    dump_runtime: Boolean;
    dump_data   : Boolean;
    dump_ir     : Boolean;
    dump_rt     : Boolean;
    run         : Boolean;
    output_name : TString;
  End;

  TTokenKind = (
    TK_EOF,
    TK_IDENT,
    TK_KEYWORD,
    TK_NUMBER,
    TK_STRING,
    TK_TEMPLATE,
    TK_REGEX,
    TK_OPERATOR,
    TK_PUNCT
  );

  { Segments d'un gabarit : sans interpolation, debut, milieu, fin. }
  TTemplatePart = (
    TP_NONE,
    TP_NOSUB,
    TP_HEAD,
    TP_MIDDLE,
    TP_TAIL
  );

  TToken = Record
    kind     : TTokenKind;
    tpl      : TTemplatePart;
    text     : TTokenText;     { texte brut, tronque a 80 octets }
    line     : LongInt;
    col      : LongInt;
    pos      : LongInt;        { etendue brute dans le source }
    len      : LongInt;
    sval_off : LongInt;        { valeur decodee dans le pool }
    sval_len : LongInt;
    flag_len : LongInt;        { RegExp : drapeaux apres le corps }
    num_val  : Double;
    nl_before: Boolean;        { fin de ligne avant ce jeton (ASI) }
  End;

  TSourceInfo = Record
    loaded      : Boolean;
    line_count  : LongInt;
    char_count  : LongInt;
    max_line_len: LongInt;
    line_start  : Array[1..MAX_SOURCE_LINES + 1] Of LongInt;
    buf         : Array[0..MAX_SOURCE_CHARS] Of Char;
  End;

  TLexInfo = Record
    pos, line, line_pos: LongInt;
    nl_pending   : Boolean;
    stop         : Boolean;
    brace_depth  : LongInt;
    tpl_top      : LongInt;
    tpl_stack    : Array[1..MAX_TEMPLATE_DEPTH] Of LongInt;
    token_count  : LongInt;
    ident_count, keyword_count, number_count, string_count,
    template_count, regex_count, operator_count, punct_count,
    comment_count: LongInt;
    pool_len     : LongInt;
    tokens       : Array[1..MAX_TOKENS] Of TToken;
    pool         : Array[0..MAX_STRING_POOL] Of Char;
  End;

  TNodeKind = (
    N_NONE, N_PROGRAM, N_BLOCK, N_EMPTY, N_EXPR_STMT,
    N_VAR_DECL, N_DECLARATOR, N_BIND_IDENT, N_ARRAY_PATTERN,
    N_OBJECT_PATTERN, N_PATTERN_ELEM, N_PATTERN_PROP,
    N_IF, N_SWITCH, N_CASE, N_WHILE, N_DO_WHILE, N_FOR, N_FOR_IN, N_FOR_OF,
    N_BREAK, N_CONTINUE, N_RETURN, N_THROW, N_TRY, N_CATCH, N_LABELED,
    N_DEBUGGER, N_FUNC_DECL, N_PARAM, N_CLASS_DECL, N_METHOD, N_FIELD,
    N_STATIC_BLOCK,
    { expressions }
    N_NUMBER, N_STRING, N_REGEX, N_TEMPLATE, N_TEMPLATE_STR, N_IDENT,
    N_THIS, N_SUPER, N_NULL, N_BOOL, N_ARRAY_LIT, N_ELISION, N_SPREAD,
    N_OBJECT_LIT, N_PROP, N_FUNC_EXPR, N_CLASS_EXPR, N_UNARY, N_UPDATE,
    N_BINARY, N_LOGICAL, N_ASSIGN, N_COND, N_CALL, N_NEW, N_MEMBER,
    N_INDEX, N_SEQUENCE, N_TAGGED
  );

  TDeclKind = (DK_VAR, DK_LET, DK_CONST, DK_FUNC, DK_CLASS, DK_PARAM, DK_CATCH,
                 DK_FNAME, DK_ARGS);

  { Noeud d'AST : tok est le jeton principal (position, nom) ; e1..e4 sont
    des noeuds enfants (ou des indices de jeton pour break/continue et
    EXPR_RAW) ; next chaine les freres d'une liste. }
  TNode = Record
    kind : TNodeKind;
    tok  : LongInt;
    e1, e2, e3, e4: LongInt;
    next : LongInt;
    flags: LongInt;
    paren: Boolean;            { expression entre parentheses }
    scope: LongInt;            { portee ouverte par ce noeud (semantique) }
    decl_head: LongInt;        { premiere declaration de cette portee }
    sym  : LongInt;            { symbole lie ou portee fournissant this }
    aux  : LongInt;            { genre de resolution }
    ds   : LongInt;            { chaine, double ou descripteur associe (donnees) }
  End;

  { Etat sauvegarde a l'entree d'une fonction }
  TFuncSave = Record
    scope, func, loop, switch, labels: LongInt;
  End;

  { Table de hoisting : scope est la portee ou le nom vit (fonction pour
    var), origin la portee ou il est ecrit dans le source. }
  TDecl = Record
    kind    : TDeclKind;
    name_tok: LongInt;
    node    : LongInt;
    scope   : LongInt;
    origin  : LongInt;
    next    : LongInt;
  End;

  TLabelRec = Record
    tok    : LongInt;
    is_loop: Boolean;
  End;

  TAstInfo = Record
    pt          : LongInt;     { jeton courant du parseur }
    stop        : Boolean;
    last_err_tok: LongInt;
    root        : LongInt;
    cur_scope   : LongInt;
    cur_func    : LongInt;
    loop_depth, switch_depth, func_depth: LongInt;
    label_count : LongInt;
    labels      : Array[1..MAX_LABELS] Of TLabelRec;
    node_count  : LongInt;
    decl_count  : LongInt;
    analyzed    : Boolean;
    nodes       : Array[1..MAX_NODES] Of TNode;
    decls       : Array[1..MAX_DECLS] Of TDecl;
  End;

  TScopeKind = (SK_GLOBAL, SK_FUNCTION, SK_BLOCK, SK_CLASS, SK_CATCH);

  TFuncKind = (FK_NONE, FK_GLOBAL, FK_FUNCTION, FK_ARROW, FK_METHOD, FK_CTOR,
               FK_DERIVED_CTOR, FK_STATIC_METHOD, FK_STATIC_BLOCK,
               FK_FIELD_INIT, FK_STATIC_FIELD_INIT);

  TScope = Record
    node, parent, func, first_sym, last_sym, cap_count: LongInt;
    nslots, args_slot, frame_size: LongInt;     { disposition de la trame }
    kind  : TScopeKind;
    fkind : TFuncKind;
    in_loop, uses_this, this_captured, uses_arguments, has_nested: Boolean;
  End;

  TSymbol = Record
    name_tok, scope, node, next, flags, refs, writes: LongInt;
    slot, name_str: LongInt;   { emplacement de trame ; chaine du nom (TDZ) }
    kind: TDeclKind;
    ds  : LongInt;             { symbole de donnees (variable statique) }
  End;

  { Variable libre d'une fonction : fscope capture sym. }
  TCapture = Record
    fscope, sym: LongInt;
  End;

  TSemInfo = Record
    scope_count, sym_count, cap_count: LongInt;
    cur_scope, loop_depth, cur_class: LongInt;
    in_typeof, stop, next_in_loop: Boolean;
    scopes: Array[1..MAX_SCOPES] Of TScope;
    syms  : Array[1..MAX_SYMS] Of TSymbol;
    caps  : Array[1..MAX_CAPS] Of TCapture;
  End;

  { Inventaire du programme et composants du runtime requis }
  TRtModel = Record
    built: Boolean;
    comps: LongInt;
    int_literals, double_literals, string_literals, template_literals,
    regex_literals, array_literals, object_literals, functions, closures,
    classes, cells, try_blocks, throws, calls, news: LongInt;
  End;

  TStrEntry = Record
    off, len: LongInt;
    hash    : Int64;
    atom_id : LongInt;
    sym     : LongInt;
  End;

  TDblEntry = Record
    lo, hi: Int64;
    sym   : LongInt;
  End;

  TFuncDesc = Record
    node, name_str, nparams, flags, ncells, sym: LongInt;
    code_sym: String[100];
  End;

  TClassDesc = Record
    node, name_str, ctor_fd, flags, first_member, member_count, sym: LongInt;
  End;

  TCMember = Record
    key_str, flags, fd: LongInt;
  End;

  TDataSym = Record
    name: String[100];
    sec : Integer;
    ofs, size: LongInt;
    kind: Integer;
  End;

  TReloc = Record
    sec: Integer;
    tkind: Integer;            { SYMK_D : donnee, SYMK_X : code ou externe }
    ofs, target: LongInt;
  End;

  { Pool de constantes et de donnees : images des sections .rdata et
    .data, symboles et relocations. }
  TDataInfo = Record
    built, failed: Boolean;
    str_count, dpool_len, atom_count, atom_table_sym, dbl_count, fd_count,
    cd_count, cm_count, sym_count, reloc_count, rd_size, dt_size,
    global_count: LongInt;
    hash  : Array[0..HASH_SIZE - 1] Of LongInt;
    strs  : Array[1..MAX_STRS] Of TStrEntry;
    atoms : Array[1..MAX_STRS] Of LongInt;
    dpool : Array[0..MAX_DPOOL] Of Char;
    dbls  : Array[1..MAX_DBLS] Of TDblEntry;
    fdescs: Array[1..MAX_FDESCS] Of TFuncDesc;
    cdescs: Array[1..MAX_CDESCS] Of TClassDesc;
    cmembers: Array[1..MAX_CMEMBERS] Of TCMember;
    syms  : Array[1..MAX_DSYMS] Of TDataSym;
    relocs: Array[1..MAX_RELOCS] Of TReloc;
    dhash : Array[0..65535] Of LongInt;      { noms des symboles de donnees }
    rd    : Array[0..MAX_RDATA - 1] Of Byte;
    dt    : Array[0..MAX_DATA_IMG - 1] Of Byte;
  End;

  { Valeur constante evaluee a la compilation }
  TConst = Record
    k: Integer;
    n: Double;
    b: Boolean;
  End;

  TReg = (R_NONE, R_EAX, R_ECX, R_EDX, R_EBX, R_ESP, R_EBP, R_ESI, R_EDI,
          R_CL, R_AL, R_DL, R_BL);

  TOpdKind = (OD_NONE, OD_REG, OD_IMM, OD_MEM, OD_ADDR, OD_LABEL);

  { Instructions de l'IR ; les TODO suivants ajoutent les leurs. }
  TOpc = (OP_NONE, OP_LABEL, OP_COMMENT, OP_PROC, OP_ENDP,
          OP_MOV, OP_LEA, OP_PUSH, OP_POP, OP_ADD, OP_SUB, OP_CMP, OP_TEST,
          OP_XOR, OP_AND, OP_JMP, OP_JE, OP_JNE, OP_JB, OP_JAE, OP_CALL,
          OP_RET, OP_LEAVE, OP_NOP,
          OP_IMUL, OP_OR, OP_NOT, OP_NEG, OP_SHL, OP_SHR, OP_SAR, OP_CDQ,
          OP_IDIV, OP_JL, OP_JLE, OP_JG, OP_JGE, OP_JA, OP_JBE, OP_JO,
          OP_JNO, OP_JS, OP_JNS,
          OP_MOVZX, OP_INC, OP_DEC, OP_DIV, OP_REP_MOVSB);

  { Operande : registre, immediat (disp), memoire [base+disp] ou
    [symbole+disp], adresse d'un symbole, etiquette locale (disp). }
  TOperand = Record
    kind   : TOpdKind;
    reg    : TReg;
    base   : TReg;
    index  : TReg;             { registre d'index (echelle 1) }
    size   : Byte;             { 1 = octet, sinon DWORD }
    symkind: LongInt;          { SYMK_D ou SYMK_X }
    disp   : LongInt;
    sym    : LongInt;
  End;

  TInstr = Record
    op  : TOpc;
    a, b: TOperand;
    line: LongInt;
  End;

  TXSym = Record
    name   : String[100];
    defined: Boolean;
    runtime: Boolean;          { procedure du runtime }
  End;

  TPendingRec = Record
    line: LongInt;
    what: String[60];
  End;

  TJumpTarget = Record
    kind, brk, cont, nlabels: LongInt;
    labels: Array[1..4] Of LongInt;      { jetons des noms d'etiquettes }
  End;

  TIrInfo = Record
    built, failed: Boolean;
    count, xsym_count, comment_count, label_count, proc_count,
    pending_count, cg_fs, frame_patch, cur_line, user_count: LongInt;
    tmp_free: Array[1..64] Of LongInt;      { temporaires de trame libres }
    tmp_free_count: LongInt;
    jt: Array[1..MAX_JT] Of TJumpTarget;
    jt_count, plabel_count, chain_end: LongInt;
    in_chain, chain_used: Boolean;
    plabels: Array[1..4] Of LongInt;
    instrs  : Array[1..MAX_INSTR] Of TInstr;
    xsyms   : Array[1..MAX_XSYMS] Of TXSym;
    comments: Array[1..MAX_COMMENTS] Of String[120];
    pendings: Array[1..MAX_PENDING] Of TPendingRec;
  End;

  TCompilerContext = Record
    options    : TPipelineOptions;
    source_name: TString;
    asm_name   : TString;
    obj_name   : TString;
    exe_name   : TString;
    stage      : TCompileStage;
    last_art   : TArtifactKind;
    errors     : Integer;
    warnings   : Integer;
    source     : TSourceInfo;
    lex        : TLexInfo;
    ast        : TAstInfo;
    sem        : TSemInfo;
    rt         : TRtModel;
    data       : TDataInfo;
    ir         : TIrInfo;
  End;

Const
  KEYWORD_COUNT = 38;
  Keywords: Array[1..KEYWORD_COUNT] Of String[10] = (
    'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger',
    'default', 'delete', 'do', 'else', 'enum', 'export', 'extends', 'false',
    'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof', 'let',
    'new', 'null', 'return', 'static', 'super', 'switch', 'this', 'throw',
    'true', 'try', 'typeof', 'var', 'void', 'while', 'with'
  );

  { Operateurs et ponctuation, du plus long au plus court. }
  OP_COUNT = 57;
  Ops: Array[1..OP_COUNT] Of String[4] = (
    '>>>=',
    '===', '!==', '**=', '<<=', '>>=', '>>>', '...', '&&=', '||=', '??=',
    '=>', '==', '!=', '<=', '>=', '&&', '||', '??', '?.', '++', '--', '+=',
    '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<', '>>', '**',
    '+', '-', '*', '/', '%', '=', '<', '>', '!', '~', '&', '|', '^', '?',
    ':', ',', '.', ';', '(', ')', '[', ']', '{', '}'
  );

Function StageName(stage: TCompileStage): TString;
Begin
  Case stage Of
    CS_LOAD_SOURCE: StageName := 'source';
    CS_LEX_TOKENS:  StageName := 'tokens';
    CS_PARSE_AST:   StageName := 'ast';
    CS_ANALYZE:     StageName := 'semantique';
    CS_BUILD_IR:    StageName := 'ir';
    CS_EMIT_ASM386: StageName := 'asm-80386';
    CS_BUILD_OBJ:   StageName := 'obj-coff';
    CS_LINK_EXE:    StageName := 'exe-pe32';
  Else
    StageName := 'unknown';
  End;
End;

Function ArtifactName(artifact: TArtifactKind): TString;
Begin
  Case artifact Of
    AK_NONE:         ArtifactName := 'none';
    AK_SOURCE_JS:    ArtifactName := 'source-js';
    AK_TOKEN_STREAM: ArtifactName := 'token-stream';
    AK_AST:          ArtifactName := 'ast';
    AK_AST_ANALYZED: ArtifactName := 'ast-analysee';
    AK_IR:           ArtifactName := 'ir';
    AK_ASM_386:      ArtifactName := 'asm-80386';
    AK_OBJ_COFF:     ArtifactName := 'obj-coff';
    AK_EXE_PE32:     ArtifactName := 'exe-pe32';
  Else
    ArtifactName := 'unknown';
  End;
End;

Function OutputModeName(mode: TOutputMode): TString;
Begin
  Case mode Of
    OM_EXE: OutputModeName := 'EXE Win32';
    OM_OBJ: OutputModeName := 'OBJ COFF';
  Else
    OutputModeName := 'inconnu';
  End;
End;

Function BoolText(value: Boolean): TString;
Begin
  If value Then
    BoolText := 'oui'
  Else
    BoolText := 'non';
End;

Function BaseNameNoExt(path: TString): TString;
Var
  i, cut: Integer;
Begin
  cut := 0;
  For i := Length(path) Downto 1 Do
    Begin
      If path[i] = '.' Then
        Begin
          cut := i;
          Break;
        End;
      If (path[i] = '\') Or (path[i] = '/') Or (path[i] = ':') Then
        Break;
    End;
  If cut > 0 Then
    BaseNameNoExt := Copy(path, 1, cut - 1)
  Else
    BaseNameNoExt := path;
End;

Function WithExt(path, ext: TString): TString;
Begin
  WithExt := BaseNameNoExt(path) + ext;
End;

Function StageOutputArtifact(stage: TCompileStage): TArtifactKind;
Begin
  Case stage Of
    CS_LOAD_SOURCE: StageOutputArtifact := AK_SOURCE_JS;
    CS_LEX_TOKENS:  StageOutputArtifact := AK_TOKEN_STREAM;
    CS_PARSE_AST:   StageOutputArtifact := AK_AST;
    CS_ANALYZE:     StageOutputArtifact := AK_AST_ANALYZED;
    CS_BUILD_IR:    StageOutputArtifact := AK_IR;
    CS_EMIT_ASM386: StageOutputArtifact := AK_ASM_386;
    CS_BUILD_OBJ:   StageOutputArtifact := AK_OBJ_COFF;
    CS_LINK_EXE:    StageOutputArtifact := AK_EXE_PE32;
  Else
    StageOutputArtifact := AK_NONE;
  End;
End;

{ Dernier artefact a produire selon le mode : EXE par defaut, OBJ sur demande. }
Function PipelineTargetArtifact(Var ctx: TCompilerContext): TArtifactKind;
Begin
  If ctx.options.run Then
    PipelineTargetArtifact := AK_IR
  Else If ctx.options.output_mode = OM_OBJ Then
    PipelineTargetArtifact := AK_OBJ_COFF
  Else
    PipelineTargetArtifact := AK_EXE_PE32;
End;

{ Indique si un artefact doit etre ecrit sur disque. L'ASM n'est jamais
  ecrit sans demande explicite ; l'OBJ n'est conserve qu'en mode OBJ. }
Function ArtifactIsPersisted(Var ctx: TCompilerContext;
                             artifact: TArtifactKind): Boolean;
Begin
  Case artifact Of
    AK_ASM_386:  ArtifactIsPersisted := ctx.options.emit_asm;
    AK_OBJ_COFF: ArtifactIsPersisted := ctx.options.output_mode = OM_OBJ;
    AK_EXE_PE32: ArtifactIsPersisted := ctx.options.output_mode = OM_EXE;
  Else
    ArtifactIsPersisted := False;
  End;
End;

Procedure InitPipelineDefaults(Var ctx: TCompilerContext);
Begin
  FillChar(ctx, SizeOf(ctx), 0);
  ctx.options.output_mode := OM_EXE;
  ctx.options.emit_asm := False;
  ctx.options.verbose := False;
  ctx.options.show_help := False;
  ctx.options.show_version := False;
  ctx.options.dump_tokens := False;
  ctx.options.dump_ast := False;
  ctx.options.dump_scopes := False;
  ctx.options.dump_runtime := False;
  ctx.options.dump_data := False;
  ctx.options.dump_ir := False;
  ctx.options.dump_rt := False;
  ctx.options.run := False;
  ctx.options.output_name := '';
  ctx.stage := CS_LOAD_SOURCE;
  ctx.last_art := AK_NONE;
  ctx.errors := 0;
  ctx.warnings := 0;
End;

Function UpperStr(str: TString): TString;
Var
  i: Integer;
Begin
  For i := 1 To Length(str) Do
    str[i] := UpCase(str[i]);
  UpperStr := str;
End;

Function HasExt(path, ext: TString): Boolean;
Begin
  HasExt := (Length(path) > Length(ext)) And
            (UpperStr(Copy(path, Length(path) - Length(ext) + 1,
                          Length(ext))) = UpperStr(ext));
End;

{ Les chemins Windows (SAMPLES\JS\x.js) sont acceptes aussi sous Unix. }
Function NormalizePath(path: TString): TString;
{$IFDEF UNIX}
Var
  i: Integer;
{$ENDIF}
Begin
{$IFDEF UNIX}
  For i := 1 To Length(path) Do
    If path[i] = '\' Then
      path[i] := '/';
{$ENDIF}
  NormalizePath := path;
End;

{ Noms de sortie : sans -o, ils derivent du fichier source (HELLO.JS ->
  HELLO.EXE / HELLO.OBJ / HELLO.ASM). Avec -o, le nom fourni est la base
  commune ; une extension .exe/.obj/.asm est retiree, puisque l'extension
  reelle depend du fichier produit. }
Procedure SetDefaultOutputNames(Var ctx: TCompilerContext);
Var
  base: TString;
Begin
  If ctx.options.output_name <> '' Then
    Begin
      base := ctx.options.output_name;
      If HasExt(base, EXT_EXE) Or HasExt(base, EXT_OBJ) Or
         HasExt(base, EXT_ASM) Then
        base := BaseNameNoExt(base);
    End
  Else
    base := BaseNameNoExt(ctx.source_name);
  ctx.asm_name := base + EXT_ASM;
  ctx.obj_name := base + EXT_OBJ;
  ctx.exe_name := base + EXT_EXE;
End;

Procedure PipelineError(Var ctx: TCompilerContext; msg: TString);
Begin
  Inc(ctx.errors);
  Writeln('JSCW32: ', msg);
End;

Procedure PrintPipeline;
Var
  s: TCompileStage;
Begin
  Writeln('JSCW32 ', JSCW32_VERSION, ' - pipeline canonique');
  Write('  ', EXT_JS);
  For s := CS_LOAD_SOURCE To CS_LINK_EXE Do
    If s <> CS_LOAD_SOURCE Then
      Write(' -> ', ArtifactName(StageOutputArtifact(s)));
  Writeln;
  Writeln('  cible par defaut: ', ArtifactName(AK_EXE_PE32),
          ' (fichier ', EXT_EXE, ' Windows 32 bits)');
  Writeln('  ', EXT_OBJ, ' seul: mode OBJ (aucune edition de liens)');
  Writeln('  ', EXT_ASM, ': ecrit seulement sur demande explicite');
End;

Procedure PrintUsage;
Begin
  Writeln('JSCW32 - Compilateur JavaScript vers executable Windows 32 bits (80386).');
  Writeln;
  Writeln('Syntaxe: jscw32 [options] fichier.js');
  Writeln;
  Writeln('Options:');
  Writeln('  -obj          produit seulement le fichier ', EXT_OBJ,
          ' (pas d''edition de liens)');
  Writeln('  -asm          ecrit aussi le fichier ', EXT_ASM);
  Writeln('  -o nom        nom de base des fichiers de sortie');
  Writeln('  -v            mode verbose');
  Writeln('  -tokens       affiche les jetons du lexer');
  Writeln('  -ast          affiche l''arbre syntaxique et les declarations');
  Writeln('  -scopes       affiche les portees, symboles et captures');
  Writeln('  -runtime      affiche le modele runtime (valeurs, tas, pile)');
  Writeln('  -data         affiche le pool de donnees (.rdata, .data)');
  Writeln('  -ir           affiche le code 80386 genere');
  Writeln('  -rt           avec -ir : inclut aussi le code du runtime');
  Writeln('  -run          execute le programme dans l''emulateur 80386 integre');
  Writeln('  -version      affiche la version');
  Writeln('  -h, -?        affiche cette aide');
  Writeln;
  Writeln('Les options peuvent aussi commencer par / ou --.');
  Writeln('Par defaut, la cible est un executable Windows ', EXT_EXE, '.');
  Writeln('Le fichier ', EXT_ASM, ' est produit seulement avec -asm.');
  Writeln;
  Writeln('Exemples:');
  Writeln('  jscw32 SAMPLES\JS\hello.js');
  Writeln('  jscw32 -obj SAMPLES\JS\hello.js');
  Writeln('  jscw32 -asm -obj SAMPLES\JS\hello.js');
  Writeln('  jscw32 -o prog SAMPLES\JS\hello.js');
  Writeln;
  PrintPipeline;
End;

{ Reconnait -x, /x et --x (sans tenir compte de la casse). }
Function IsOption(arg, name: TString): Boolean;
Var
  u: TString;
Begin
  u := UpperStr(arg);
  name := UpperStr(name);
  IsOption := (u = '-' + name) Or (u = '/' + name) Or (u = '--' + name);
End;

Function ParseArgs(Var ctx: TCompilerContext): Integer;
Var
  i: Integer;
  arg: TString;
Begin
  ParseArgs := EXIT_OK;
  i := 1;
  While i <= ParamCount Do
    Begin
      arg := ParamStr(i);
      If IsOption(arg, 'h') Or IsOption(arg, '?') Or IsOption(arg, 'help') Then
        ctx.options.show_help := True
      Else If IsOption(arg, 'version') Then
        ctx.options.show_version := True
      Else If IsOption(arg, 'v') Or IsOption(arg, 'verbose') Then
        ctx.options.verbose := True
      Else If IsOption(arg, 'rt') Then
        ctx.options.dump_rt := True
      Else If IsOption(arg, 'run') Then
        ctx.options.run := True
      Else If IsOption(arg, 'ir') Then
        ctx.options.dump_ir := True
      Else If IsOption(arg, 'data') Then
        ctx.options.dump_data := True
      Else If IsOption(arg, 'runtime') Then
        ctx.options.dump_runtime := True
      Else If IsOption(arg, 'scopes') Then
        ctx.options.dump_scopes := True
      Else If IsOption(arg, 'ast') Then
        ctx.options.dump_ast := True
      Else If IsOption(arg, 'tokens') Then
        ctx.options.dump_tokens := True
      Else If IsOption(arg, 'obj') Then
        ctx.options.output_mode := OM_OBJ
      Else If IsOption(arg, 'asm') Then
        ctx.options.emit_asm := True
      Else If IsOption(arg, 'o') Then
        Begin
          Inc(i);
          If (i > ParamCount) Or (ParamStr(i) = '') Then
            Begin
              Writeln('JSCW32: nom de sortie attendu apres ', arg);
              ParseArgs := EXIT_USAGE;
              Exit;
            End;
          ctx.options.output_name := NormalizePath(ParamStr(i));
        End
      Else If (Length(arg) > 0) And ((arg[1] = '-') Or (arg[1] = '/')) Then
        Begin
          Writeln('JSCW32: option inconnue: ', arg);
          ParseArgs := EXIT_USAGE;
          Exit;
        End
      Else If ctx.source_name = '' Then
        ctx.source_name := NormalizePath(arg)
      Else
        Begin
          Writeln('JSCW32: un seul fichier source est accepte: ', arg);
          ParseArgs := EXIT_USAGE;
          Exit;
        End;
      Inc(i);
    End;

  If ctx.options.show_help Or ctx.options.show_version Then
    Exit;
  If ctx.options.dump_runtime And (ctx.source_name = '') Then
    Exit;
  If ctx.source_name = '' Then
    Begin
      Writeln('JSCW32: fichier source ', EXT_JS, ' manquant');
      ParseArgs := EXIT_USAGE;
      Exit;
    End;
  If BaseNameNoExt(ctx.source_name) = ctx.source_name Then
    ctx.source_name := ctx.source_name + EXT_JS;
  SetDefaultOutputNames(ctx);
End;

Procedure PrintOptions(Var ctx: TCompilerContext);
Begin
  Writeln('Source : ', ctx.source_name);
  Writeln('Mode   : ', OutputModeName(ctx.options.output_mode));
  Writeln('ASM    : ', BoolText(ctx.options.emit_asm));
  Writeln('ASM out: ', ctx.asm_name);
  Writeln('OBJ out: ', ctx.obj_name);
  Writeln('EXE out: ', ctx.exe_name);
  Writeln('Cible  : ', ArtifactName(PipelineTargetArtifact(ctx)));
End;

{ ============================================================
  TODO 3 - CHARGEUR SOURCE ET LEXER

  Le source est lu en octets (UTF-8 attendu). Les fins de ligne CR,
  LF et CR/LF sont normalisees en LF et un BOM UTF-8 est ignore.
  Les colonnes sont comptees en octets. Le lexer produit des jetons
  qui gardent leur etendue brute dans le source ; les valeurs decodees
  (chaines, gabarits, corps de RegExp) sont rangees dans un pool.

  Choix de lexique :
    - null, true et false sont des mots-cles ; undefined, NaN et
      Infinity restent des identifiants (constantes globales).
    - of, get, set, async, await et yield sont des identifiants
      contextuels, laisses au parseur.
    - Un gabarit est decoupe en jetons TEMPLATE : NOSUB, HEAD, MIDDLE
      et TAIL, avec les expressions interpolees entre les segments.
    - Un / est une RegExp apres un debut d'expression, une division
      apres un identifiant, un nombre, une chaine, une parenthese, un crochet ou une accolade fermants, ++ et --.
  ============================================================ }

Function IsDigit(c: Char): Boolean;
Begin
  IsDigit := (c >= '0') And (c <= '9');
End;

Function IsHexDigit(c: Char): Boolean;
Begin
  IsHexDigit := IsDigit(c) Or ((c >= 'A') And (c <= 'F')) Or
                ((c >= 'a') And (c <= 'f'));
End;

Function HexVal(c: Char): LongInt;
Begin
  If IsDigit(c) Then
    HexVal := Ord(c) - Ord('0')
  Else If (c >= 'a') And (c <= 'f') Then
    HexVal := Ord(c) - Ord('a') + 10
  Else
    HexVal := Ord(c) - Ord('A') + 10;
End;

Function IsIdentStart(c: Char): Boolean;
Begin
  IsIdentStart := ((c >= 'A') And (c <= 'Z')) Or ((c >= 'a') And (c <= 'z')) Or
                  (c = '_') Or (c = '$') Or (c >= #128);
End;

Function IsIdentPart(c: Char): Boolean;
Begin
  IsIdentPart := IsIdentStart(c) Or IsDigit(c);
End;

Function IsKeyword(Const name: TTokenText): Boolean;
Var
  i: Integer;
Begin
  IsKeyword := False;
  For i := 1 To KEYWORD_COUNT Do
    If Keywords[i] = name Then
      IsKeyword := True;
End;

{ ---- Diagnostics avec ligne source et caret ---- }

Procedure PrintDiagLine(Var ctx: TCompilerContext; line_no, col_no: LongInt);
Var
  a, b, n, i: LongInt;
Begin
  If (line_no < 1) Or (line_no > ctx.source.line_count) Then
    Exit;
  a := ctx.source.line_start[line_no];
  b := ctx.source.line_start[line_no + 1] - 1;
  If b <= a Then
    Exit;
  n := b - a;
  If n > MAX_DIAG_LINE Then
    n := MAX_DIAG_LINE;
  Write(' ');
  For i := 0 To n - 1 Do
    Write(ctx.source.buf[a + i]);
  Writeln;
  If (col_no >= 1) And (col_no <= n + 1) Then
    Begin
      Write(' ');
      For i := 1 To col_no - 1 Do
        If ctx.source.buf[a + i - 1] = #9 Then
          Write(#9)
        Else
          Write(' ');
      Writeln('^');
    End;
End;

Procedure SourceErrorAt(Var ctx: TCompilerContext; line_no, col_no: LongInt;
                        msg: TString);
Begin
  Inc(ctx.errors);
  Writeln(ctx.source_name, '(', line_no, ',', col_no, '): error: ', msg);
  PrintDiagLine(ctx, line_no, col_no);
End;

Procedure SourceWarnAt(Var ctx: TCompilerContext; line_no, col_no: LongInt;
                       msg: TString);
Begin
  Inc(ctx.warnings);
  Writeln(ctx.source_name, '(', line_no, ',', col_no, '): warning: ', msg);
  PrintDiagLine(ctx, line_no, col_no);
End;

{ ---- Chargement du source ---- }

Function LoadSource(Var ctx: TCompilerContext): Boolean;
Var
  f: File;
  chunk: Array[0..4095] Of Char;
  got: Word;
  i, first_i, io: Integer;
  c: Char;
  first, prev_cr, skip, failed: Boolean;
  line_len: LongInt;
Begin
  LoadSource := False;
  ctx.source.loaded := False;
  ctx.source.char_count := 0;
  ctx.source.line_count := 1;
  ctx.source.line_start[1] := 0;
  ctx.source.max_line_len := 0;

  Assign(f, NormalizePath(ctx.source_name));
  FileMode := 0;
  Reset(f, 1);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible d''ouvrir le fichier source: ' +
                         ctx.source_name);
      Exit;
    End;

  first := True;
  prev_cr := False;
  failed := False;
  Repeat
    BlockRead(f, chunk, SizeOf(chunk), got);
    io := IOResult;
    If io <> 0 Then
      Begin
        PipelineError(ctx, 'erreur de lecture du fichier source');
        failed := True;
      End
    Else If got > 0 Then
      Begin
        first_i := 0;
        If first Then
          Begin
            first := False;
            If (got >= 3) And (chunk[0] = #$EF) And (chunk[1] = #$BB) And
               (chunk[2] = #$BF) Then
              first_i := 3
            Else If (got >= 2) And (((chunk[0] = #$FF) And (chunk[1] = #$FE)) Or
                    ((chunk[0] = #$FE) And (chunk[1] = #$FF))) Then
              Begin
                PipelineError(ctx, 'encodage UTF-16 non supporte (UTF-8 attendu): ' +
                                   ctx.source_name);
                failed := True;
              End;
          End;
        i := first_i;
        While (i < got) And Not failed Do
          Begin
            c := chunk[i];
            skip := False;
            If c = #13 Then
              Begin
                c := #10;
                prev_cr := True;
              End
            Else
              Begin
                If (c = #10) And prev_cr Then
                  skip := True;
                prev_cr := False;
              End;
            If Not skip Then
              Begin
                If ctx.source.char_count >= MAX_SOURCE_CHARS Then
                  Begin
                    PipelineError(ctx, 'source trop volumineux (limite interne atteinte)');
                    failed := True;
                  End
                Else
                  Begin
                    ctx.source.buf[ctx.source.char_count] := c;
                    Inc(ctx.source.char_count);
                    If c = #10 Then
                      Begin
                        line_len := ctx.source.char_count - 1 -
                                    ctx.source.line_start[ctx.source.line_count];
                        If line_len > ctx.source.max_line_len Then
                          ctx.source.max_line_len := line_len;
                        If ctx.source.line_count >= MAX_SOURCE_LINES Then
                          Begin
                            PipelineError(ctx, 'trop de lignes dans le source');
                            failed := True;
                          End
                        Else
                          Begin
                            Inc(ctx.source.line_count);
                            ctx.source.line_start[ctx.source.line_count] :=
                              ctx.source.char_count;
                          End;
                      End;
                  End;
              End;
            Inc(i);
          End;
      End;
  Until (got = 0) Or failed;

  Close(f);
  io := IOResult;
  If failed Then
    Exit;

  line_len := ctx.source.char_count -
              ctx.source.line_start[ctx.source.line_count];
  If line_len > ctx.source.max_line_len Then
    ctx.source.max_line_len := line_len;
  ctx.source.line_start[ctx.source.line_count + 1] := ctx.source.char_count + 1;
  ctx.source.loaded := True;
  If ctx.options.verbose Then
    Writeln('Source chargee: ', ctx.source.line_count, ' lignes, ',
            ctx.source.char_count, ' octets, ligne max ',
            ctx.source.max_line_len);
  LoadSource := True;
End;

{ ---- Primitives du lexer ---- }

Function LxCur(Var ctx: TCompilerContext): Char;
Begin
  If ctx.lex.pos < ctx.source.char_count Then
    LxCur := ctx.source.buf[ctx.lex.pos]
  Else
    LxCur := #0;
End;

Function LxPeek(Var ctx: TCompilerContext; n: LongInt): Char;
Begin
  If ctx.lex.pos + n < ctx.source.char_count Then
    LxPeek := ctx.source.buf[ctx.lex.pos + n]
  Else
    LxPeek := #0;
End;

Function LxAtEnd(Var ctx: TCompilerContext): Boolean;
Begin
  LxAtEnd := ctx.lex.pos >= ctx.source.char_count;
End;

Function LxCol(Var ctx: TCompilerContext): LongInt;
Begin
  LxCol := ctx.lex.pos - ctx.lex.line_pos + 1;
End;

Procedure LxAdvance(Var ctx: TCompilerContext);
Begin
  If ctx.lex.pos < ctx.source.char_count Then
    Begin
      If ctx.source.buf[ctx.lex.pos] = #10 Then
        Begin
          Inc(ctx.lex.line);
          ctx.lex.line_pos := ctx.lex.pos + 1;
        End;
      Inc(ctx.lex.pos);
    End;
End;

Procedure LxAdvanceN(Var ctx: TCompilerContext; n: LongInt);
Var
  i: LongInt;
Begin
  For i := 1 To n Do
    LxAdvance(ctx);
End;

Function RawText(Var ctx: TCompilerContext; tp, rl: LongInt): TTokenText;
Var
  t: TTokenText;
  k, i: LongInt;
Begin
  k := rl;
  If k > MAX_TOKEN_TEXT Then
    k := MAX_TOKEN_TEXT;
  t[0] := Chr(k);
  For i := 1 To k Do
    t[i] := ctx.source.buf[tp + i - 1];
  RawText := t;
End;

{ Cree un jeton couvrant le source de tp jusqu'a la position courante. }
Function AddToken(Var ctx: TCompilerContext; kind: TTokenKind;
                  tl, tc, tp: LongInt): LongInt;
Var
  n: LongInt;
Begin
  If ctx.lex.token_count >= MAX_TOKENS Then
    Begin
      If Not ctx.lex.stop Then
        SourceErrorAt(ctx, tl, tc, 'trop de jetons dans le source');
      ctx.lex.stop := True;
      AddToken := MAX_TOKENS;
      Exit;
    End;
  Inc(ctx.lex.token_count);
  n := ctx.lex.token_count;
  ctx.lex.tokens[n].kind := kind;
  ctx.lex.tokens[n].tpl := TP_NONE;
  ctx.lex.tokens[n].text := RawText(ctx, tp, ctx.lex.pos - tp);
  ctx.lex.tokens[n].line := tl;
  ctx.lex.tokens[n].col := tc;
  ctx.lex.tokens[n].pos := tp;
  ctx.lex.tokens[n].len := ctx.lex.pos - tp;
  ctx.lex.tokens[n].sval_off := 0;
  ctx.lex.tokens[n].sval_len := 0;
  ctx.lex.tokens[n].flag_len := 0;
  ctx.lex.tokens[n].num_val := 0;
  ctx.lex.tokens[n].nl_before := ctx.lex.nl_pending;
  ctx.lex.nl_pending := False;
  Case kind Of
    TK_IDENT:    Inc(ctx.lex.ident_count);
    TK_KEYWORD:  Inc(ctx.lex.keyword_count);
    TK_NUMBER:   Inc(ctx.lex.number_count);
    TK_STRING:   Inc(ctx.lex.string_count);
    TK_TEMPLATE: Inc(ctx.lex.template_count);
    TK_REGEX:    Inc(ctx.lex.regex_count);
    TK_OPERATOR: Inc(ctx.lex.operator_count);
    TK_PUNCT:    Inc(ctx.lex.punct_count);
  End;
  AddToken := n;
End;

Procedure PoolAppend(Var ctx: TCompilerContext; c: Char);
Begin
  If ctx.lex.pool_len >= MAX_STRING_POOL Then
    Begin
      If Not ctx.lex.stop Then
        SourceErrorAt(ctx, ctx.lex.line, LxCol(ctx),
                      'pool de chaines plein');
      ctx.lex.stop := True;
      Exit;
    End;
  ctx.lex.pool[ctx.lex.pool_len] := c;
  Inc(ctx.lex.pool_len);
End;

{ Ajoute un point de code Unicode encode en UTF-8. }
Procedure PoolAppendCP(Var ctx: TCompilerContext; cp: LongInt);
Begin
  If cp < $80 Then
    PoolAppend(ctx, Chr(cp))
  Else If cp < $800 Then
    Begin
      PoolAppend(ctx, Chr($C0 Or (cp Shr 6)));
      PoolAppend(ctx, Chr($80 Or (cp And $3F)));
    End
  Else If cp < $10000 Then
    Begin
      PoolAppend(ctx, Chr($E0 Or (cp Shr 12)));
      PoolAppend(ctx, Chr($80 Or ((cp Shr 6) And $3F)));
      PoolAppend(ctx, Chr($80 Or (cp And $3F)));
    End
  Else
    Begin
      PoolAppend(ctx, Chr($F0 Or (cp Shr 18)));
      PoolAppend(ctx, Chr($80 Or ((cp Shr 12) And $3F)));
      PoolAppend(ctx, Chr($80 Or ((cp Shr 6) And $3F)));
      PoolAppend(ctx, Chr($80 Or (cp And $3F)));
    End;
End;

{ Valeur de n chiffres hexadecimaux situes a pos+ofs, ou -1. }
Function LxHexAt(Var ctx: TCompilerContext; ofs, n: LongInt): LongInt;
Var
  i, v: LongInt;
Begin
  v := 0;
  For i := 0 To n - 1 Do
    Begin
      If Not IsHexDigit(LxPeek(ctx, ofs + i)) Then
        Begin
          LxHexAt := -1;
          Exit;
        End;
      v := v * 16 + HexVal(LxPeek(ctx, ofs + i));
    End;
  LxHexAt := v;
End;

{ ---- Echappements des chaines et des gabarits ---- }

Procedure LxEscape(Var ctx: TCompilerContext; in_template: Boolean);
Var
  tl, tc, v, hv, lo, p, n, maxd: LongInt;
  c: Char;
  bad: Boolean;
Begin
  tl := ctx.lex.line;
  tc := LxCol(ctx);
  LxAdvance(ctx);
  If LxAtEnd(ctx) Then
    Begin
      SourceErrorAt(ctx, tl, tc, 'sequence d''echappement incomplete');
      Exit;
    End;
  c := LxCur(ctx);
  Case c Of
    'n': Begin PoolAppend(ctx, #10); LxAdvance(ctx); End;
    't': Begin PoolAppend(ctx, #9);  LxAdvance(ctx); End;
    'r': Begin PoolAppend(ctx, #13); LxAdvance(ctx); End;
    'b': Begin PoolAppend(ctx, #8);  LxAdvance(ctx); End;
    'f': Begin PoolAppend(ctx, #12); LxAdvance(ctx); End;
    'v': Begin PoolAppend(ctx, #11); LxAdvance(ctx); End;
    #10: LxAdvance(ctx);
    '0'..'7':
      Begin
        If (c = '0') And Not IsDigit(LxPeek(ctx, 1)) Then
          Begin
            PoolAppend(ctx, #0);
            LxAdvance(ctx);
          End
        Else If in_template Then
          Begin
            SourceErrorAt(ctx, tl, tc,
              'sequence octale interdite dans un gabarit');
            LxAdvance(ctx);
          End
        Else
          Begin
            maxd := 2;
            If c <= '3' Then
              maxd := 3;
            n := 0;
            v := 0;
            While (n < maxd) And (LxCur(ctx) >= '0') And (LxCur(ctx) <= '7') Do
              Begin
                v := v * 8 + (Ord(LxCur(ctx)) - Ord('0'));
                LxAdvance(ctx);
                Inc(n);
              End;
            PoolAppendCP(ctx, v);
          End;
      End;
    'x':
      Begin
        hv := LxHexAt(ctx, 1, 2);
        If hv < 0 Then
          Begin
            SourceErrorAt(ctx, tl, tc, 'sequence \x invalide (2 chiffres hexa)');
            LxAdvance(ctx);
          End
        Else
          Begin
            LxAdvanceN(ctx, 3);
            PoolAppendCP(ctx, hv);
          End;
      End;
    'u':
      Begin
        If LxPeek(ctx, 1) = '{' Then
          Begin
            p := 2;
            n := 0;
            v := 0;
            bad := False;
            While IsHexDigit(LxPeek(ctx, p)) Do
              Begin
                If v > $10FFFF Then
                  bad := True
                Else
                  v := v * 16 + HexVal(LxPeek(ctx, p));
                Inc(n);
                Inc(p);
              End;
            If (n = 0) Or (LxPeek(ctx, p) <> '}') Or bad Or (v > $10FFFF) Then
              Begin
                SourceErrorAt(ctx, tl, tc, 'sequence \u{...} invalide');
                LxAdvance(ctx);
              End
            Else
              Begin
                LxAdvanceN(ctx, p + 1);
                PoolAppendCP(ctx, v);
              End;
          End
        Else
          Begin
            hv := LxHexAt(ctx, 1, 4);
            If hv < 0 Then
              Begin
                SourceErrorAt(ctx, tl, tc,
                  'sequence \u invalide (4 chiffres hexa)');
                LxAdvance(ctx);
              End
            Else
              Begin
                LxAdvanceN(ctx, 5);
                If (hv >= $D800) And (hv <= $DBFF) And (LxCur(ctx) = '\') And
                   (LxPeek(ctx, 1) = 'u') Then
                  Begin
                    lo := LxHexAt(ctx, 2, 4);
                    If (lo >= $DC00) And (lo <= $DFFF) Then
                      Begin
                        LxAdvanceN(ctx, 6);
                        hv := $10000 + ((hv - $D800) Shl 10) + (lo - $DC00);
                      End;
                  End;
                PoolAppendCP(ctx, hv);
              End;
          End;
      End;
  Else
    Begin
      PoolAppend(ctx, c);
      LxAdvance(ctx);
    End;
  End;
End;

{ ---- Identifiants et mots-cles ---- }

Procedure LxIdent(Var ctx: TCompilerContext);
Var
  tl, tc, tp, idx: LongInt;
  kind: TTokenKind;
Begin
  tl := ctx.lex.line;
  tc := LxCol(ctx);
  tp := ctx.lex.pos;
  { #nom : membre prive, traite comme un nom de propriete cache }
  If LxCur(ctx) = '#' Then
    LxAdvance(ctx);
  While IsIdentPart(LxCur(ctx)) Do
    LxAdvance(ctx);
  If ctx.lex.pos - tp > MAX_TOKEN_TEXT Then
    SourceErrorAt(ctx, tl, tc, 'identifiant trop long (80 octets maximum)');
  If IsKeyword(RawText(ctx, tp, ctx.lex.pos - tp)) Then
    kind := TK_KEYWORD
  Else
    kind := TK_IDENT;
  idx := AddToken(ctx, kind, tl, tc, tp);
End;

{ ---- Nombres ---- }

Procedure LxNumber(Var ctx: TCompilerContext);
Var
  tl, tc, tp, idx, digits, base: LongInt;
  c, c2: Char;
  v: Double;
  ip, fp, ep: TString;
  esign: Char;
  txt: TString;
  code: Integer;
  has_dot, has_exp, bad_sep, last_us, octal_ok: Boolean;
  i: Integer;

  { Lit des chiffres decimaux avec separateurs _ ; s recoit les chiffres. }
  Procedure ReadDigits(Var s: TString);
  Begin
    While IsDigit(LxCur(ctx)) Or (LxCur(ctx) = '_') Do
      Begin
        If LxCur(ctx) = '_' Then
          Begin
            If (Length(s) = 0) Or Not IsDigit(LxPeek(ctx, 1)) Then
              bad_sep := True;
          End
        Else If Length(s) < 250 Then
          s := s + LxCur(ctx);
        LxAdvance(ctx);
      End;
  End;

Begin
  tl := ctx.lex.line;
  tc := LxCol(ctx);
  tp := ctx.lex.pos;
  c := LxCur(ctx);
  c2 := UpCase(LxPeek(ctx, 1));
  v := 0;
  bad_sep := False;
  If (c = '0') And ((c2 = 'X') Or (c2 = 'B') Or (c2 = 'O')) Then
    Begin
      If c2 = 'X' Then
        base := 16
      Else If c2 = 'B' Then
        base := 2
      Else
        base := 8;
      LxAdvanceN(ctx, 2);
      digits := 0;
      last_us := False;
      While True Do
        Begin
          c := LxCur(ctx);
          If c = '_' Then
            Begin
              If (digits = 0) Or last_us Then
                bad_sep := True;
              last_us := True;
              LxAdvance(ctx);
            End
          Else If IsHexDigit(c) And (HexVal(c) < base) Then
            Begin
              v := v * base + HexVal(c);
              Inc(digits);
              last_us := False;
              LxAdvance(ctx);
            End
          Else
            Break;
        End;
      If digits = 0 Then
        SourceErrorAt(ctx, tl, tc, 'chiffres attendus apres le prefixe numerique')
      Else If IsDigit(LxCur(ctx)) Then
        Begin
          SourceErrorAt(ctx, tl, LxCol(ctx), 'chiffre invalide pour cette base');
          While IsDigit(LxCur(ctx)) Do
            LxAdvance(ctx);
        End
      Else If bad_sep Or last_us Then
        SourceErrorAt(ctx, tl, tc, 'separateur numerique "_" mal place');
    End
  Else
    Begin
      ip := '';
      fp := '';
      ep := '';
      esign := '+';
      has_dot := False;
      has_exp := False;
      If c <> '.' Then
        ReadDigits(ip);
      If LxCur(ctx) = '.' Then
        Begin
          has_dot := True;
          LxAdvance(ctx);
          ReadDigits(fp);
        End;
      If UpCase(LxCur(ctx)) = 'E' Then
        If IsDigit(LxPeek(ctx, 1)) Or
           (((LxPeek(ctx, 1) = '+') Or (LxPeek(ctx, 1) = '-')) And
            IsDigit(LxPeek(ctx, 2))) Then
          Begin
            has_exp := True;
            LxAdvance(ctx);
            If (LxCur(ctx) = '+') Or (LxCur(ctx) = '-') Then
              Begin
                esign := LxCur(ctx);
                LxAdvance(ctx);
              End;
            ReadDigits(ep);
          End;
      If bad_sep Then
        SourceErrorAt(ctx, tl, tc, 'separateur numerique "_" mal place');
      { Ancien octal : 0 suivi uniquement de chiffres 0 a 7. }
      octal_ok := (Not has_dot) And (Not has_exp) And (Length(ip) > 1) And
                  (ip[1] = '0');
      If octal_ok Then
        For i := 2 To Length(ip) Do
          If ip[i] > '7' Then
            octal_ok := False;
      If octal_ok Then
        Begin
          For i := 2 To Length(ip) Do
            v := v * 8 + (Ord(ip[i]) - Ord('0'));
        End
      Else
        Begin
          If ip = '' Then
            ip := '0';
          If fp = '' Then
            fp := '0';
          txt := ip + '.' + fp;
          If has_exp Then
            txt := txt + 'e' + esign + ep;
          Val(txt, v, code);
          If code <> 0 Then
            Begin
              SourceErrorAt(ctx, tl, tc, 'nombre invalide');
              v := 0;
            End;
        End;
    End;
  If IsIdentStart(LxCur(ctx)) Or IsDigit(LxCur(ctx)) Then
    Begin
      If LxCur(ctx) = 'n' Then
        SourceErrorAt(ctx, tl, LxCol(ctx), 'les BigInt (suffixe n) ne sont pas supportes')
      Else
        SourceErrorAt(ctx, tl, LxCol(ctx), 'caractere invalide apres un nombre');
      While IsIdentPart(LxCur(ctx)) Do
        LxAdvance(ctx);
    End;
  idx := AddToken(ctx, TK_NUMBER, tl, tc, tp);
  ctx.lex.tokens[idx].num_val := v;
End;

{ ---- Chaines ---- }

Procedure LxString(Var ctx: TCompilerContext; quote: Char);
Var
  tl, tc, tp, idx, off: LongInt;
  c: Char;
  closed: Boolean;
Begin
  tl := ctx.lex.line;
  tc := LxCol(ctx);
  tp := ctx.lex.pos;
  LxAdvance(ctx);
  off := ctx.lex.pool_len;
  closed := False;
  While Not closed Do
    Begin
      If LxAtEnd(ctx) Or (LxCur(ctx) = #10) Then
        Begin
          SourceErrorAt(ctx, tl, tc, 'chaine non terminee');
          Break;
        End;
      c := LxCur(ctx);
      If c = quote Then
        Begin
          LxAdvance(ctx);
          closed := True;
        End
      Else If c = '\' Then
        LxEscape(ctx, False)
      Else
        Begin
          PoolAppend(ctx, c);
          LxAdvance(ctx);
        End;
    End;
  idx := AddToken(ctx, TK_STRING, tl, tc, tp);
  ctx.lex.tokens[idx].sval_off := off;
  ctx.lex.tokens[idx].sval_len := ctx.lex.pool_len - off;
End;

{ ---- Gabarits `...` ---- }

Procedure LxTemplate(Var ctx: TCompilerContext; resume: Boolean);
Var
  tl, tc, tp, idx, off: LongInt;
  part: TTemplatePart;
  done: Boolean;
Begin
  tl := ctx.lex.line;
  tc := LxCol(ctx);
  tp := ctx.lex.pos;
  If resume Then
    Dec(ctx.lex.tpl_top);
  LxAdvance(ctx);
  off := ctx.lex.pool_len;
  done := False;
  If resume Then
    part := TP_TAIL
  Else
    part := TP_NOSUB;
  While Not done Do
    Begin
      If LxAtEnd(ctx) Then
        Begin
          SourceErrorAt(ctx, tl, tc, 'gabarit non termine');
          Break;
        End;
      If LxCur(ctx) = '`' Then
        Begin
          LxAdvance(ctx);
          done := True;
        End
      Else If (LxCur(ctx) = '$') And (LxPeek(ctx, 1) = '{') Then
        Begin
          LxAdvanceN(ctx, 2);
          If resume Then
            part := TP_MIDDLE
          Else
            part := TP_HEAD;
          If ctx.lex.tpl_top >= MAX_TEMPLATE_DEPTH Then
            SourceErrorAt(ctx, tl, tc, 'gabarits imbriques trop profonds')
          Else
            Begin
              Inc(ctx.lex.tpl_top);
              ctx.lex.tpl_stack[ctx.lex.tpl_top] := ctx.lex.brace_depth;
            End;
          done := True;
        End
      Else If LxCur(ctx) = '\' Then
        LxEscape(ctx, True)
      Else
        Begin
          PoolAppend(ctx, LxCur(ctx));
          LxAdvance(ctx);
        End;
    End;
  idx := AddToken(ctx, TK_TEMPLATE, tl, tc, tp);
  ctx.lex.tokens[idx].tpl := part;
  ctx.lex.tokens[idx].sval_off := off;
  ctx.lex.tokens[idx].sval_len := ctx.lex.pool_len - off;
End;

{ ---- Expressions regulieres ---- }

{ Vrai si un / a cette position commence une RegExp (sinon division). }
Function RegexAllowed(Var ctx: TCompilerContext): Boolean;
Var
  t: TToken;
Begin
  If ctx.lex.token_count = 0 Then
    Begin
      RegexAllowed := True;
      Exit;
    End;
  t := ctx.lex.tokens[ctx.lex.token_count];
  Case t.kind Of
    TK_NUMBER, TK_STRING, TK_REGEX, TK_IDENT:
      RegexAllowed := False;
    TK_TEMPLATE:
      RegexAllowed := (t.tpl = TP_HEAD) Or (t.tpl = TP_MIDDLE);
    TK_KEYWORD:
      RegexAllowed := Not ((t.text = 'this') Or (t.text = 'super') Or
                           (t.text = 'null') Or (t.text = 'true') Or
                           (t.text = 'false'));
    TK_OPERATOR, TK_PUNCT:
      RegexAllowed := Not ((t.text = ')') Or (t.text = ']') Or
                           (t.text = '}') Or (t.text = '++') Or
                           (t.text = '--'));
  Else
    RegexAllowed := True;
  End;
End;

Procedure LxRegex(Var ctx: TCompilerContext);
Var
  tl, tc, tp, idx, off, nflags: LongInt;
  c: Char;
  in_class, closed: Boolean;
  flags: String[16];
Begin
  tl := ctx.lex.line;
  tc := LxCol(ctx);
  tp := ctx.lex.pos;
  LxAdvance(ctx);
  off := ctx.lex.pool_len;
  in_class := False;
  closed := False;
  While Not closed Do
    Begin
      If LxAtEnd(ctx) Or (LxCur(ctx) = #10) Then
        Begin
          SourceErrorAt(ctx, tl, tc, 'expression reguliere non terminee');
          Break;
        End;
      c := LxCur(ctx);
      If c = '\' Then
        Begin
          PoolAppend(ctx, c);
          LxAdvance(ctx);
          If Not LxAtEnd(ctx) And (LxCur(ctx) <> #10) Then
            Begin
              PoolAppend(ctx, LxCur(ctx));
              LxAdvance(ctx);
            End;
        End
      Else
        Begin
          If c = '[' Then
            in_class := True
          Else If c = ']' Then
            in_class := False;
          If (c = '/') And Not in_class Then
            closed := True
          Else
            PoolAppend(ctx, c);
          LxAdvance(ctx);
        End;
    End;
  idx := AddToken(ctx, TK_REGEX, tl, tc, tp);
  ctx.lex.tokens[idx].sval_off := off;
  ctx.lex.tokens[idx].sval_len := ctx.lex.pool_len - off;
  { Drapeaux : stockes dans le pool juste apres le corps. }
  flags := '';
  nflags := 0;
  While IsIdentPart(LxCur(ctx)) Do
    Begin
      c := LxCur(ctx);
      If Pos(c, flags) > 0 Then
        SourceErrorAt(ctx, ctx.lex.line, LxCol(ctx),
                      'drapeau de RegExp en double: ' + c)
      Else If Pos(c, 'dgimsuvy') = 0 Then
        SourceWarnAt(ctx, ctx.lex.line, LxCol(ctx),
                     'drapeau de RegExp non standard: ' + c);
      If Length(flags) < 16 Then
        flags := flags + c;
      PoolAppend(ctx, c);
      Inc(nflags);
      LxAdvance(ctx);
    End;
  ctx.lex.tokens[idx].flag_len := nflags;
  { L'etendue brute inclut les drapeaux. }
  ctx.lex.tokens[idx].len := ctx.lex.pos - tp;
  ctx.lex.tokens[idx].text := RawText(ctx, tp, ctx.lex.pos - tp);
End;

{ ---- Commentaires ---- }

Procedure LxLineComment(Var ctx: TCompilerContext);
Begin
  While Not LxAtEnd(ctx) And (LxCur(ctx) <> #10) Do
    LxAdvance(ctx);
  Inc(ctx.lex.comment_count);
End;

Procedure LxBlockComment(Var ctx: TCompilerContext);
Var
  tl, tc: LongInt;
  closed: Boolean;
Begin
  tl := ctx.lex.line;
  tc := LxCol(ctx);
  LxAdvanceN(ctx, 2);
  closed := False;
  While Not closed Do
    Begin
      If LxAtEnd(ctx) Then
        Begin
          SourceErrorAt(ctx, tl, tc, 'commentaire /* non termine');
          Break;
        End;
      If (LxCur(ctx) = '*') And (LxPeek(ctx, 1) = '/') Then
        Begin
          LxAdvanceN(ctx, 2);
          closed := True;
        End
      Else
        Begin
          If LxCur(ctx) = #10 Then
            ctx.lex.nl_pending := True;
          LxAdvance(ctx);
        End;
    End;
  Inc(ctx.lex.comment_count);
End;

{ ---- Operateurs et ponctuation ---- }

Procedure LxOperator(Var ctx: TCompilerContext);
Var
  tl, tc, tp, idx, i, j, sel: LongInt;
  op: String[4];
  ok: Boolean;
  c: Char;
  num: String[12];
  kind: TTokenKind;
Begin
  tl := ctx.lex.line;
  tc := LxCol(ctx);
  tp := ctx.lex.pos;
  sel := 0;
  i := 1;
  While (sel = 0) And (i <= OP_COUNT) Do
    Begin
      op := Ops[i];
      ok := True;
      For j := 1 To Length(op) Do
        If LxPeek(ctx, j - 1) <> op[j] Then
          ok := False;
      { a?.5:1 est un ternaire, pas un acces optionnel. }
      If ok And (op = '?.') And IsDigit(LxPeek(ctx, 2)) Then
        ok := False;
      If ok Then
        sel := i;
      Inc(i);
    End;
  If sel = 0 Then
    Begin
      c := LxCur(ctx);
      If (c < ' ') Or (c > '~') Then
        Begin
          Str(Ord(c), num);
          SourceErrorAt(ctx, tl, tc, 'caractere inattendu (code ' + num + ')');
        End
      Else
        SourceErrorAt(ctx, tl, tc, 'caractere inattendu: ' + c);
      LxAdvance(ctx);
      Exit;
    End;
  op := Ops[sel];
  LxAdvanceN(ctx, Length(op));
  kind := TK_OPERATOR;
  If (op = '(') Or (op = ')') Or (op = '[') Or (op = ']') Or (op = '{') Or
     (op = '}') Or (op = ';') Or (op = ',') Or (op = ':') Or (op = '.') Or
     (op = '...') Or (op = '=>') Then
    kind := TK_PUNCT;
  If op = '{' Then
    Inc(ctx.lex.brace_depth)
  Else If (op = '}') And (ctx.lex.brace_depth > 0) Then
    Dec(ctx.lex.brace_depth);
  idx := AddToken(ctx, kind, tl, tc, tp);
End;

{ ---- Boucle principale du lexer ---- }

Function LexSource(Var ctx: TCompilerContext): Boolean;
Var
  c: Char;
  tl, tc, idx: LongInt;
Begin
  LexSource := False;
  If Not ctx.source.loaded Then
    Begin
      PipelineError(ctx, 'source non charge avant lexing');
      Exit;
    End;
  ctx.lex.ident_count := 0;
  ctx.lex.keyword_count := 0;
  ctx.lex.number_count := 0;
  ctx.lex.string_count := 0;
  ctx.lex.template_count := 0;
  ctx.lex.regex_count := 0;
  ctx.lex.operator_count := 0;
  ctx.lex.punct_count := 0;
  ctx.lex.pos := 0;
  ctx.lex.line := 1;
  ctx.lex.line_pos := 0;
  ctx.lex.nl_pending := False;
  ctx.lex.brace_depth := 0;
  ctx.lex.tpl_top := 0;
  ctx.lex.token_count := 0;
  ctx.lex.pool_len := 0;
  ctx.lex.stop := False;
  ctx.lex.comment_count := 0;

  { Ligne hashbang (#!) acceptee en tete de fichier. }
  If (LxCur(ctx) = '#') And (LxPeek(ctx, 1) = '!') Then
    LxLineComment(ctx);

  While Not LxAtEnd(ctx) And Not ctx.lex.stop Do
    Begin
      c := LxCur(ctx);
      If c = #10 Then
        Begin
          ctx.lex.nl_pending := True;
          LxAdvance(ctx);
        End
      Else If (c = ' ') Or (c = #9) Or (c = #11) Or (c = #12) Or (c = #13) Then
        LxAdvance(ctx)
      Else If (c = #$C2) And (LxPeek(ctx, 1) = #$A0) Then
        LxAdvanceN(ctx, 2)
      Else If (c = '/') And (LxPeek(ctx, 1) = '/') Then
        LxLineComment(ctx)
      Else If (c = '/') And (LxPeek(ctx, 1) = '*') Then
        LxBlockComment(ctx)
      Else If IsIdentStart(c) Or ((c = '#') And IsIdentStart(LxPeek(ctx, 1))) Then
        LxIdent(ctx)
      Else If IsDigit(c) Or ((c = '.') And IsDigit(LxPeek(ctx, 1))) Then
        LxNumber(ctx)
      Else If (c = '"') Or (c = '''') Then
        LxString(ctx, c)
      Else If c = '`' Then
        LxTemplate(ctx, False)
      Else If (c = '}') And (ctx.lex.tpl_top > 0) And
              (ctx.lex.tpl_stack[ctx.lex.tpl_top] = ctx.lex.brace_depth) Then
        LxTemplate(ctx, True)
      Else If (c = '/') And RegexAllowed(ctx) Then
        LxRegex(ctx)
      Else
        LxOperator(ctx);
      If ctx.errors >= MAX_ERRORS Then
        Begin
          PipelineError(ctx, 'trop d''erreurs, arret du lexer');
          Break;
        End;
    End;

  If ctx.lex.tpl_top > 0 Then
    SourceErrorAt(ctx, ctx.lex.line, LxCol(ctx), 'gabarit non termine');
  tl := ctx.lex.line;
  tc := LxCol(ctx);
  idx := AddToken(ctx, TK_EOF, tl, tc, ctx.lex.pos);
  If ctx.options.verbose Then
    Writeln('Tokens : ', ctx.lex.token_count,
            ' (mots-cles=', ctx.lex.keyword_count,
            ', ident=', ctx.lex.ident_count,
            ', nombres=', ctx.lex.number_count,
            ', chaines=', ctx.lex.string_count,
            ', gabarits=', ctx.lex.template_count,
            ', regexp=', ctx.lex.regex_count,
            ', ops=', ctx.lex.operator_count,
            ', ponct=', ctx.lex.punct_count,
            ', commentaires=', ctx.lex.comment_count, ')');
  LexSource := ctx.errors = 0;
End;

{ ---- Affichage des jetons (option -tokens) ---- }

Function TokenKindName(kind: TTokenKind): TString;
Begin
  Case kind Of
    TK_EOF:      TokenKindName := 'EOF';
    TK_IDENT:    TokenKindName := 'IDENT';
    TK_KEYWORD:  TokenKindName := 'KEYWORD';
    TK_NUMBER:   TokenKindName := 'NUMBER';
    TK_STRING:   TokenKindName := 'STRING';
    TK_TEMPLATE: TokenKindName := 'TEMPLATE';
    TK_REGEX:    TokenKindName := 'REGEX';
    TK_OPERATOR: TokenKindName := 'OPERATOR';
    TK_PUNCT:    TokenKindName := 'PUNCT';
  Else
    TokenKindName := 'UNKNOWN';
  End;
End;

Function TemplatePartName(part: TTemplatePart): TString;
Begin
  Case part Of
    TP_NOSUB:  TemplatePartName := 'nosub';
    TP_HEAD:   TemplatePartName := 'head';
    TP_MIDDLE: TemplatePartName := 'middle';
    TP_TAIL:   TemplatePartName := 'tail';
  Else
    TemplatePartName := '';
  End;
End;

Procedure PrintPoolText(Var ctx: TCompilerContext; off, len: LongInt);
Var
  i: LongInt;
  c: Char;
Const
  HEX_CHARS = '0123456789ABCDEF';
Begin
  For i := 0 To len - 1 Do
    Begin
      c := ctx.lex.pool[off + i];
      If c = #10 Then
        Write('\n')
      Else If c = #9 Then
        Write('\t')
      Else If c = #13 Then
        Write('\r')
      Else If c < ' ' Then
        Write('\x', HEX_CHARS[Ord(c) Div 16 + 1], HEX_CHARS[Ord(c) Mod 16 + 1])
      Else
        Write(c);
    End;
End;

Procedure DumpTokens(Var ctx: TCompilerContext);
Var
  i: LongInt;
  t: TToken;
Begin
  Writeln('Jetons (', ctx.lex.token_count, ') :');
  For i := 1 To ctx.lex.token_count Do
    Begin
      t := ctx.lex.tokens[i];
      Write('  ', t.line:4, ':', t.col, ' ');
      Write(TokenKindName(t.kind));
      If t.nl_before Then
        Write(' [nl]');
      Write(' ');
      Case t.kind Of
        TK_STRING:
          Begin
            Write('"');
            PrintPoolText(ctx, t.sval_off, t.sval_len);
            Write('"');
          End;
        TK_TEMPLATE:
          Begin
            Write('(', TemplatePartName(t.tpl), ') "');
            PrintPoolText(ctx, t.sval_off, t.sval_len);
            Write('"');
          End;
        TK_REGEX:
          Begin
            Write('/');
            PrintPoolText(ctx, t.sval_off, t.sval_len);
            Write('/');
            PrintPoolText(ctx, t.sval_off + t.sval_len, t.flag_len);
          End;
        TK_NUMBER:
          Write(t.text, ' = ', t.num_val);
      Else
        Write(t.text);
      End;
      Writeln;
    End;
End;

{ ============================================================
  TODO 4 - PARSEUR D'INSTRUCTIONS

  Les instructions sont analysees completement : declarations
  var/let/const avec destructuration, blocs, if, switch, boucles,
  break/continue (avec etiquettes), return, throw, try, fonctions et
  classes. L'AST est un tableau de noeuds relies par des indices
  (e1..e4 pour les enfants, next pour la liste de freres).

  Les expressions (TODO 5) sont de vrais arbres : precedences,
  associativite, appels, new, acces optionnels, fonctions fleches,
  litteraux, gabarits et affectations avec destructuration.

  Hoisting : chaque declaration est enregistree dans la table des
  declarations avec sa portee. var va a la fonction englobante,
  let/const/class au bloc, une fonction au bloc qui la contient.
  ============================================================ }

{ ---- Acces aux jetons ---- }

Function TkIsP(Var ctx: TCompilerContext; i: LongInt; Const s: TTokenText): Boolean;
Begin
  TkIsP := ((ctx.lex.tokens[i].kind = TK_PUNCT) Or
            (ctx.lex.tokens[i].kind = TK_OPERATOR)) And
           (ctx.lex.tokens[i].text = s);
End;

Function TkIsKw(Var ctx: TCompilerContext; i: LongInt; Const s: TTokenText): Boolean;
Begin
  TkIsKw := (ctx.lex.tokens[i].kind = TK_KEYWORD) And
            (ctx.lex.tokens[i].text = s);
End;

Function TkIsId(Var ctx: TCompilerContext; i: LongInt; Const s: TTokenText): Boolean;
Begin
  TkIsId := (ctx.lex.tokens[i].kind = TK_IDENT) And
            (ctx.lex.tokens[i].text = s);
End;

Function CurIsP(Var ctx: TCompilerContext; Const s: TTokenText): Boolean;
Begin
  CurIsP := TkIsP(ctx, ctx.ast.pt, s);
End;

Function CurIsKw(Var ctx: TCompilerContext; Const s: TTokenText): Boolean;
Begin
  CurIsKw := TkIsKw(ctx, ctx.ast.pt, s);
End;

Function CurIsEof(Var ctx: TCompilerContext): Boolean;
Begin
  CurIsEof := ctx.lex.tokens[ctx.ast.pt].kind = TK_EOF;
End;

{ Indice du jeton situe n positions apres le courant (borne par EOF). }
Function PeekIdx(Var ctx: TCompilerContext; n: LongInt): LongInt;
Begin
  If ctx.ast.pt + n > ctx.lex.token_count Then
    PeekIdx := ctx.lex.token_count
  Else
    PeekIdx := ctx.ast.pt + n;
End;

Procedure PAdvance(Var ctx: TCompilerContext);
Begin
  If ctx.ast.pt < ctx.lex.token_count Then
    Inc(ctx.ast.pt);
End;

Function TokenDesc(Var ctx: TCompilerContext; i: LongInt): TString;
Begin
  If ctx.lex.tokens[i].kind = TK_EOF Then
    TokenDesc := 'fin de fichier'
  Else
    TokenDesc := '"' + ctx.lex.tokens[i].text + '"';
End;

{ Une seule erreur par jeton, pour eviter les cascades. }
Procedure ParseError(Var ctx: TCompilerContext; i: LongInt; msg: TString);
Begin
  If i = ctx.ast.last_err_tok Then
    Exit;
  ctx.ast.last_err_tok := i;
  SourceErrorAt(ctx, ctx.lex.tokens[i].line, ctx.lex.tokens[i].col, msg);
End;

Function Expect(Var ctx: TCompilerContext; Const s: TTokenText): Boolean;
Begin
  If CurIsP(ctx, s) Then
    Begin
      PAdvance(ctx);
      Expect := True;
    End
  Else
    Begin
      ParseError(ctx, ctx.ast.pt, '"' + s + '" attendu, trouve ' +
                 TokenDesc(ctx, ctx.ast.pt));
      Expect := False;
    End;
End;

{ Point-virgule explicite ou insertion automatique (ASI). }
Procedure ConsumeSemi(Var ctx: TCompilerContext);
Begin
  If CurIsP(ctx, ';') Then
    PAdvance(ctx)
  Else If CurIsP(ctx, '}') Or CurIsEof(ctx) Or
          ctx.lex.tokens[ctx.ast.pt].nl_before Then
    { ASI }
  Else
    ParseError(ctx, ctx.ast.pt, '";" attendu avant ' +
               TokenDesc(ctx, ctx.ast.pt));
End;

Function IsStmtStartKw(Var ctx: TCompilerContext; i: LongInt): Boolean;
Var
  s: TTokenText;
Begin
  s := ctx.lex.tokens[i].text;
  IsStmtStartKw := (ctx.lex.tokens[i].kind = TK_KEYWORD) And
    ((s = 'var') Or (s = 'let') Or (s = 'const') Or (s = 'function') Or
     (s = 'class') Or (s = 'if') Or (s = 'for') Or (s = 'while') Or
     (s = 'do') Or (s = 'return') Or (s = 'switch') Or (s = 'try') Or
     (s = 'throw') Or (s = 'break') Or (s = 'continue'));
End;

{ Reprise apres erreur : saute jusqu'a la fin de l'instruction. }
Procedure Synchronize(Var ctx: TCompilerContext);
Var
  first: Boolean;
Begin
  first := True;
  While Not CurIsEof(ctx) Do
    Begin
      If CurIsP(ctx, ';') Then
        Begin
          PAdvance(ctx);
          Exit;
        End;
      If CurIsP(ctx, '}') Then
        Exit;
      If Not first And ctx.lex.tokens[ctx.ast.pt].nl_before And
         IsStmtStartKw(ctx, ctx.ast.pt) Then
        Exit;
      first := False;
      PAdvance(ctx);
    End;
End;

{ ---- Noeuds et declarations ---- }

Function NewNode(Var ctx: TCompilerContext; kind: TNodeKind; tok: LongInt): LongInt;
Var
  n: LongInt;
Begin
  If ctx.ast.node_count >= MAX_NODES Then
    Begin
      If Not ctx.ast.stop Then
        ParseError(ctx, ctx.ast.pt, 'trop de noeuds dans l''AST');
      ctx.ast.stop := True;
      NewNode := MAX_NODES;
      Exit;
    End;
  Inc(ctx.ast.node_count);
  n := ctx.ast.node_count;
  ctx.ast.nodes[n].kind := kind;
  ctx.ast.nodes[n].tok := tok;
  ctx.ast.nodes[n].e1 := 0;
  ctx.ast.nodes[n].e2 := 0;
  ctx.ast.nodes[n].e3 := 0;
  ctx.ast.nodes[n].e4 := 0;
  ctx.ast.nodes[n].next := 0;
  ctx.ast.nodes[n].flags := 0;
  ctx.ast.nodes[n].paren := False;
  ctx.ast.nodes[n].scope := 0;
  ctx.ast.nodes[n].decl_head := 0;
  ctx.ast.nodes[n].sym := 0;
  ctx.ast.nodes[n].aux := 0;
  ctx.ast.nodes[n].ds := 0;
  NewNode := n;
End;

{ Ajoute node a la liste (first, last). }
Procedure ListAdd(Var ctx: TCompilerContext; Var first, last: LongInt;
                  node: LongInt);
Begin
  If node = 0 Then
    Exit;
  If first = 0 Then
    first := node
  Else
    ctx.ast.nodes[last].next := node;
  last := node;
End;

Procedure DeclareName(Var ctx: TCompilerContext; kind: TDeclKind;
                      name_tok, node: LongInt);
Var
  n: LongInt;
Begin
  If ctx.ast.decl_count >= MAX_DECLS Then
    Begin
      ParseError(ctx, name_tok, 'trop de declarations');
      Exit;
    End;
  Inc(ctx.ast.decl_count);
  n := ctx.ast.decl_count;
  ctx.ast.decls[n].kind := kind;
  ctx.ast.decls[n].name_tok := name_tok;
  ctx.ast.decls[n].node := node;
  ctx.ast.decls[n].origin := ctx.ast.cur_scope;
  If kind = DK_VAR Then
    ctx.ast.decls[n].scope := ctx.ast.cur_func
  Else
    ctx.ast.decls[n].scope := ctx.ast.cur_scope;
End;

{ ---- Declarations anticipees et contexte de fonction ---- }

Function ParseAssign(Var ctx: TCompilerContext; no_in: Boolean): LongInt; Forward;
Function ParseExpr(Var ctx: TCompilerContext; no_in: Boolean): LongInt; Forward;
Function ParseLHS(Var ctx: TCompilerContext): LongInt; Forward;
Function ParseClass(Var ctx: TCompilerContext; is_decl: Boolean): LongInt; Forward;
Procedure ParseParamList(Var ctx: TCompilerContext; node: LongInt); Forward;
Function ParseFuncBlock(Var ctx: TCompilerContext): LongInt; Forward;
Procedure ParseFuncRest(Var ctx: TCompilerContext; node: LongInt); Forward;

{ Entre dans la portee d'une fonction : memorise le contexte courant. }
Procedure EnterFunc(Var ctx: TCompilerContext; node: LongInt; Var sv: TFuncSave);
Begin
  sv.scope := ctx.ast.cur_scope;
  sv.func := ctx.ast.cur_func;
  sv.loop := ctx.ast.loop_depth;
  sv.switch := ctx.ast.switch_depth;
  sv.labels := ctx.ast.label_count;
  ctx.ast.cur_scope := node;
  ctx.ast.cur_func := node;
  ctx.ast.loop_depth := 0;
  ctx.ast.switch_depth := 0;
  Inc(ctx.ast.func_depth);
End;

Procedure LeaveFunc(Var ctx: TCompilerContext; Var sv: TFuncSave);
Begin
  Dec(ctx.ast.func_depth);
  ctx.ast.label_count := sv.labels;
  ctx.ast.switch_depth := sv.switch;
  ctx.ast.loop_depth := sv.loop;
  ctx.ast.cur_func := sv.func;
  ctx.ast.cur_scope := sv.scope;
End;

{ ---- Liaisons : identifiants et motifs de destructuration ---- }

Function ParseBindingTarget(Var ctx: TCompilerContext; dk: TDeclKind): LongInt; Forward;

Function ParseBindingDefault(Var ctx: TCompilerContext): LongInt;
Begin
  ParseBindingDefault := 0;
  If CurIsP(ctx, '=') Then
    Begin
      PAdvance(ctx);
      ParseBindingDefault := ParseAssign(ctx, False);
    End;
End;

Function IsPropertyNameTok(Var ctx: TCompilerContext; i: LongInt): Boolean;
Begin
  IsPropertyNameTok := (ctx.lex.tokens[i].kind = TK_IDENT) Or
                       (ctx.lex.tokens[i].kind = TK_KEYWORD) Or
                       (ctx.lex.tokens[i].kind = TK_STRING) Or
                       (ctx.lex.tokens[i].kind = TK_NUMBER);
End;

Function ParseArrayPattern(Var ctx: TCompilerContext; dk: TDeclKind): LongInt;
Var
  node, el, first, last: LongInt;
  rest: Boolean;
Begin
  node := NewNode(ctx, N_ARRAY_PATTERN, ctx.ast.pt);
  PAdvance(ctx);
  first := 0;
  last := 0;
  While Not CurIsP(ctx, ']') And Not CurIsEof(ctx) Do
    Begin
      el := NewNode(ctx, N_PATTERN_ELEM, ctx.ast.pt);
      If CurIsP(ctx, ',') Then
        { trou : element omis }
      Else
        Begin
          rest := CurIsP(ctx, '...');
          If rest Then
            Begin
              PAdvance(ctx);
              ctx.ast.nodes[el].flags := PF_REST;
            End;
          ctx.ast.nodes[el].e1 := ParseBindingTarget(ctx, dk);
          If Not rest Then
            ctx.ast.nodes[el].e2 := ParseBindingDefault(ctx);
        End;
      ListAdd(ctx, first, last, el);
      If CurIsP(ctx, ',') Then
        PAdvance(ctx)
      Else
        Break;
    End;
  Expect(ctx, ']');
  ctx.ast.nodes[node].e1 := first;
  ParseArrayPattern := node;
End;

Function ParseObjectPattern(Var ctx: TCompilerContext; dk: TDeclKind): LongInt;
Var
  node, prop, first, last, key_tok, tgt: LongInt;
Begin
  node := NewNode(ctx, N_OBJECT_PATTERN, ctx.ast.pt);
  PAdvance(ctx);
  first := 0;
  last := 0;
  While Not CurIsP(ctx, '}') And Not CurIsEof(ctx) Do
    Begin
      prop := NewNode(ctx, N_PATTERN_PROP, ctx.ast.pt);
      If CurIsP(ctx, '...') Then
        Begin
          PAdvance(ctx);
          ctx.ast.nodes[prop].flags := PP_REST;
          ctx.ast.nodes[prop].e1 := ParseBindingTarget(ctx, dk);
        End
      Else
        Begin
          If CurIsP(ctx, '[') Then
            Begin
              PAdvance(ctx);
              ctx.ast.nodes[prop].flags := PP_COMPUTED;
              ctx.ast.nodes[prop].e3 := ParseAssign(ctx, False);
              Expect(ctx, ']');
              key_tok := ctx.ast.nodes[prop].tok;
            End
          Else If IsPropertyNameTok(ctx, ctx.ast.pt) Then
            Begin
              key_tok := ctx.ast.pt;
              ctx.ast.nodes[prop].tok := key_tok;
              PAdvance(ctx);
            End
          Else
            Begin
              ParseError(ctx, ctx.ast.pt, 'nom de propriete attendu, trouve ' +
                         TokenDesc(ctx, ctx.ast.pt));
              Break;
            End;
          If CurIsP(ctx, ':') Then
            Begin
              PAdvance(ctx);
              ctx.ast.nodes[prop].e1 := ParseBindingTarget(ctx, dk);
            End
          Else If (ctx.lex.tokens[key_tok].kind = TK_IDENT) And
                  (ctx.ast.nodes[prop].flags And PP_COMPUTED = 0) Then
            Begin
              { raccourci : a ou a = 1 dans les accolades }
              ctx.ast.nodes[prop].flags := ctx.ast.nodes[prop].flags Or
                                           PP_SHORTHAND;
              tgt := NewNode(ctx, N_BIND_IDENT, key_tok);
              DeclareName(ctx, dk, key_tok, tgt);
              ctx.ast.nodes[prop].e1 := tgt;
            End
          Else
            Begin
              ParseError(ctx, ctx.ast.pt, '":" attendu dans le motif, trouve ' +
                         TokenDesc(ctx, ctx.ast.pt));
              Break;
            End;
          ctx.ast.nodes[prop].e2 := ParseBindingDefault(ctx);
        End;
      ListAdd(ctx, first, last, prop);
      If CurIsP(ctx, ',') Then
        PAdvance(ctx)
      Else
        Break;
    End;
  Expect(ctx, '}');
  ctx.ast.nodes[node].e1 := first;
  ParseObjectPattern := node;
End;

Function ParseBindingTarget(Var ctx: TCompilerContext; dk: TDeclKind): LongInt;
Var
  node: LongInt;
Begin
  ParseBindingTarget := 0;
  If ctx.lex.tokens[ctx.ast.pt].kind = TK_IDENT Then
    Begin
      node := NewNode(ctx, N_BIND_IDENT, ctx.ast.pt);
      DeclareName(ctx, dk, ctx.ast.pt, node);
      PAdvance(ctx);
      ParseBindingTarget := node;
    End
  Else If CurIsP(ctx, '[') Then
    ParseBindingTarget := ParseArrayPattern(ctx, dk)
  Else If CurIsP(ctx, '{') Then
    ParseBindingTarget := ParseObjectPattern(ctx, dk)
  Else
    ParseError(ctx, ctx.ast.pt, 'identifiant attendu, trouve ' +
               TokenDesc(ctx, ctx.ast.pt));
End;

{ ---- Declarations var / let / const ---- }

{ Le mot-cle de declaration est le jeton courant. in_for : acces depuis
  un en-tete de for (initialiseur facultatif pour for-in et for-of). }
Function ParseVarDecl(Var ctx: TCompilerContext; in_for: Boolean): LongInt;
Var
  node, decl, target, init, first, last, kw_tok: LongInt;
  dk: TDeclKind;
  is_pattern: Boolean;
Begin
  kw_tok := ctx.ast.pt;
  node := NewNode(ctx, N_VAR_DECL, kw_tok);
  If CurIsKw(ctx, 'var') Then
    Begin
      dk := DK_VAR;
      ctx.ast.nodes[node].flags := DF_VAR;
    End
  Else If CurIsKw(ctx, 'let') Then
    Begin
      dk := DK_LET;
      ctx.ast.nodes[node].flags := DF_LET;
    End
  Else
    Begin
      dk := DK_CONST;
      ctx.ast.nodes[node].flags := DF_CONST;
    End;
  PAdvance(ctx);
  first := 0;
  last := 0;
  Repeat
    decl := NewNode(ctx, N_DECLARATOR, ctx.ast.pt);
    is_pattern := CurIsP(ctx, '[') Or CurIsP(ctx, '{');
    target := ParseBindingTarget(ctx, dk);
    If target = 0 Then
      Begin
        Synchronize(ctx);
        Break;
      End;
    ctx.ast.nodes[decl].e1 := target;
    init := 0;
    If CurIsP(ctx, '=') Then
      Begin
        PAdvance(ctx);
        init := ParseAssign(ctx, in_for);
      End
    Else If Not in_for Then
      Begin
        If dk = DK_CONST Then
          ParseError(ctx, ctx.ast.nodes[decl].tok,
                     'une constante doit etre initialisee')
        Else If is_pattern Then
          ParseError(ctx, ctx.ast.nodes[decl].tok,
                     'la destructuration doit etre initialisee');
      End;
    ctx.ast.nodes[decl].e2 := init;
    ListAdd(ctx, first, last, decl);
    If CurIsP(ctx, ',') Then
      PAdvance(ctx)
    Else
      Break;
  Until False;
  ctx.ast.nodes[node].e1 := first;
  ParseVarDecl := node;
End;

{ ---- Expressions (TODO 5) ---- }

{ Precedence d'un operateur binaire, 0 si ce n'en est pas un. }
Function BinPrec(Const s: TTokenText): LongInt;
Begin
  BinPrec := 0;
  If s = '??' Then
    BinPrec := 1
  Else If s = '||' Then
    BinPrec := 2
  Else If s = '&&' Then
    BinPrec := 3
  Else If s = '|' Then
    BinPrec := 4
  Else If s = '^' Then
    BinPrec := 5
  Else If s = '&' Then
    BinPrec := 6
  Else If (s = '==') Or (s = '!=') Or (s = '===') Or (s = '!==') Then
    BinPrec := 7
  Else If (s = '<') Or (s = '>') Or (s = '<=') Or (s = '>=') Then
    BinPrec := 8
  Else If (s = '<<') Or (s = '>>') Or (s = '>>>') Then
    BinPrec := 9
  Else If (s = '+') Or (s = '-') Then
    BinPrec := 10
  Else If (s = '*') Or (s = '/') Or (s = '%') Then
    BinPrec := 11
  Else If s = '**' Then
    BinPrec := 12;
End;

Function IsAssignOp(Const s: TTokenText): Boolean;
Begin
  IsAssignOp := (s = '=') Or (s = '+=') Or (s = '-=') Or (s = '*=') Or
                (s = '/=') Or (s = '%=') Or (s = '**=') Or (s = '<<=') Or
                (s = '>>=') Or (s = '>>>=') Or (s = '&=') Or (s = '|=') Or
                (s = '^=') Or (s = '&&=') Or (s = '||=') Or (s = '??=');
End;

{ Cible d'une affectation simple : identifiant ou membre. }
Function IsSimpleTarget(Var ctx: TCompilerContext; n: LongInt): Boolean;
Begin
  IsSimpleTarget := (n <> 0) And
    ((ctx.ast.nodes[n].kind = N_IDENT) Or (ctx.ast.nodes[n].kind = N_MEMBER) Or
     (ctx.ast.nodes[n].kind = N_INDEX));
End;

{ Avec = : un tableau ou un objet litteral est aussi une cible
  (destructuration). }
Function IsPatternTarget(Var ctx: TCompilerContext; n: LongInt): Boolean;
Begin
  IsPatternTarget := IsSimpleTarget(ctx, n) Or
    ((n <> 0) And ((ctx.ast.nodes[n].kind = N_ARRAY_LIT) Or
                   (ctx.ast.nodes[n].kind = N_OBJECT_LIT)));
End;

{ Index de la parenthese fermante qui correspond a la parenthese
  ouvrante du jeton i, ou 0. }
Function MatchClose(Var ctx: TCompilerContext; i: LongInt): LongInt;
Var
  depth: LongInt;
  s: TTokenText;
Begin
  MatchClose := 0;
  depth := 0;
  While ctx.lex.tokens[i].kind <> TK_EOF Do
    Begin
      s := ctx.lex.tokens[i].text;
      Case ctx.lex.tokens[i].kind Of
        TK_PUNCT, TK_OPERATOR:
          Begin
            If (s = '(') Or (s = '[') Or (s = '{') Then
              Inc(depth)
            Else If (s = ')') Or (s = ']') Or (s = '}') Then
              Begin
                Dec(depth);
                If depth = 0 Then
                  Begin
                    MatchClose := i;
                    Exit;
                  End;
              End;
          End;
        TK_TEMPLATE:
          Begin
            If ctx.lex.tokens[i].tpl = TP_HEAD Then
              Inc(depth)
            Else If ctx.lex.tokens[i].tpl = TP_TAIL Then
              Dec(depth);
          End;
      End;
      Inc(i);
    End;
End;

{ Le jeton courant commence-t-il une fonction fleche ? }
Function IsArrowAhead(Var ctx: TCompilerContext; Var is_async: Boolean): Boolean;
Var
  i, nx, j: LongInt;
Begin
  IsArrowAhead := False;
  is_async := False;
  i := ctx.ast.pt;
  nx := PeekIdx(ctx, 1);
  If TkIsId(ctx, i, 'async') And Not ctx.lex.tokens[nx].nl_before And
     Not TkIsP(ctx, nx, '=>') Then
    Begin
      If (ctx.lex.tokens[nx].kind = TK_IDENT) And
         TkIsP(ctx, PeekIdx(ctx, 2), '=>') Then
        Begin
          is_async := True;
          IsArrowAhead := True;
          Exit;
        End;
      If TkIsP(ctx, nx, '(') Then
        Begin
          j := MatchClose(ctx, nx);
          If (j > 0) And TkIsP(ctx, j + 1, '=>') And
             Not ctx.lex.tokens[j + 1].nl_before Then
            Begin
              is_async := True;
              IsArrowAhead := True;
              Exit;
            End;
        End;
    End;
  If (ctx.lex.tokens[i].kind = TK_IDENT) And TkIsP(ctx, nx, '=>') And
     Not ctx.lex.tokens[nx].nl_before Then
    IsArrowAhead := True
  Else If TkIsP(ctx, i, '(') Then
    Begin
      j := MatchClose(ctx, i);
      If (j > 0) And TkIsP(ctx, j + 1, '=>') And
         Not ctx.lex.tokens[j + 1].nl_before Then
        IsArrowAhead := True;
    End;
End;

{ Nom de propriete (ou crochet de nom calcule) au jeton i ? }
Function IsPropNameStart(Var ctx: TCompilerContext; i: LongInt): Boolean;
Begin
  IsPropNameStart := IsPropertyNameTok(ctx, i) Or TkIsP(ctx, i, '[');
End;

{ Arguments d'appel : ( a, ...b ). Retourne la liste des arguments. }
Function ParseCallArgs(Var ctx: TCompilerContext): LongInt;
Var
  first, last, a, sp: LongInt;
Begin
  first := 0;
  last := 0;
  If Expect(ctx, '(') Then
    Begin
      While Not CurIsP(ctx, ')') And Not CurIsEof(ctx) Do
        Begin
          If CurIsP(ctx, '...') Then
            Begin
              sp := NewNode(ctx, N_SPREAD, ctx.ast.pt);
              PAdvance(ctx);
              ctx.ast.nodes[sp].e1 := ParseAssign(ctx, False);
              a := sp;
            End
          Else
            a := ParseAssign(ctx, False);
          If a = 0 Then
            Break;
          ListAdd(ctx, first, last, a);
          If CurIsP(ctx, ',') Then
            PAdvance(ctx)
          Else
            Break;
        End;
      Expect(ctx, ')');
    End;
  ParseCallArgs := first;
End;

Function ParseTemplate(Var ctx: TCompilerContext): LongInt;
Var
  node, part, e, first, last: LongInt;
  done: Boolean;
Begin
  node := NewNode(ctx, N_TEMPLATE, ctx.ast.pt);
  first := 0;
  last := 0;
  part := NewNode(ctx, N_TEMPLATE_STR, ctx.ast.pt);
  ListAdd(ctx, first, last, part);
  If ctx.lex.tokens[ctx.ast.pt].tpl <> TP_NOSUB Then
    Begin
      PAdvance(ctx);
      done := False;
      While Not done Do
        Begin
          e := ParseExpr(ctx, False);
          If e = 0 Then
            Break;
          ListAdd(ctx, first, last, e);
          If (ctx.lex.tokens[ctx.ast.pt].kind = TK_TEMPLATE) And
             ((ctx.lex.tokens[ctx.ast.pt].tpl = TP_MIDDLE) Or
              (ctx.lex.tokens[ctx.ast.pt].tpl = TP_TAIL)) Then
            Begin
              part := NewNode(ctx, N_TEMPLATE_STR, ctx.ast.pt);
              ListAdd(ctx, first, last, part);
              If ctx.lex.tokens[ctx.ast.pt].tpl = TP_TAIL Then
                done := True;
              If Not done Then
                PAdvance(ctx);
            End
          Else
            Begin
              ParseError(ctx, ctx.ast.pt, 'fin de gabarit attendue, trouve ' +
                         TokenDesc(ctx, ctx.ast.pt));
              Break;
            End;
        End;
    End;
  PAdvance(ctx);
  ctx.ast.nodes[node].e1 := first;
  ParseTemplate := node;
End;

Function ParseArrayLiteral(Var ctx: TCompilerContext): LongInt;
Var
  node, el, first, last: LongInt;
Begin
  node := NewNode(ctx, N_ARRAY_LIT, ctx.ast.pt);
  PAdvance(ctx);
  first := 0;
  last := 0;
  While Not CurIsP(ctx, ']') And Not CurIsEof(ctx) Do
    Begin
      If CurIsP(ctx, ',') Then
        Begin
          el := NewNode(ctx, N_ELISION, ctx.ast.pt);
          PAdvance(ctx);
          ListAdd(ctx, first, last, el);
        End
      Else
        Begin
          If CurIsP(ctx, '...') Then
            Begin
              el := NewNode(ctx, N_SPREAD, ctx.ast.pt);
              PAdvance(ctx);
              ctx.ast.nodes[el].e1 := ParseAssign(ctx, False);
            End
          Else
            el := ParseAssign(ctx, False);
          If el = 0 Then
            Break;
          ListAdd(ctx, first, last, el);
          If CurIsP(ctx, ',') Then
            PAdvance(ctx)
          Else
            Break;
        End;
    End;
  Expect(ctx, ']');
  ctx.ast.nodes[node].e1 := first;
  ParseArrayLiteral := node;
End;

Function ParseObjectLiteral(Var ctx: TCompilerContext): LongInt;
Var
  node, prop, first, last, key_tok, fn, nx: LongInt;
  flags, fflags: LongInt;

  { Le jeton courant est un modificateur (get, set, async) si un nom de
    propriete le suit. }
  Function IsModifier: Boolean;
  Begin
    nx := PeekIdx(ctx, 1);
    IsModifier := IsPropNameStart(ctx, nx) Or
                  (TkIsP(ctx, nx, '*') And TkIsId(ctx, ctx.ast.pt, 'async'));
  End;

Begin
  node := NewNode(ctx, N_OBJECT_LIT, ctx.ast.pt);
  PAdvance(ctx);
  first := 0;
  last := 0;
  While Not CurIsP(ctx, '}') And Not CurIsEof(ctx) Do
    Begin
      prop := NewNode(ctx, N_PROP, ctx.ast.pt);
      flags := 0;
      fflags := FN_METHOD;
      If CurIsP(ctx, '...') Then
        Begin
          PAdvance(ctx);
          ctx.ast.nodes[prop].flags := PR_SPREAD;
          ctx.ast.nodes[prop].e1 := ParseAssign(ctx, False);
        End
      Else
        Begin
          If TkIsId(ctx, ctx.ast.pt, 'async') And IsModifier And
             Not ctx.lex.tokens[PeekIdx(ctx, 1)].nl_before Then
            Begin
              PAdvance(ctx);
              fflags := fflags Or FN_ASYNC;
              flags := flags Or PR_METHOD;
            End;
          If CurIsP(ctx, '*') Then
            Begin
              PAdvance(ctx);
              fflags := fflags Or FN_GENERATOR;
              flags := flags Or PR_METHOD;
            End;
          If (TkIsId(ctx, ctx.ast.pt, 'get') Or TkIsId(ctx, ctx.ast.pt, 'set')) And
             IsModifier Then
            Begin
              If TkIsId(ctx, ctx.ast.pt, 'get') Then
                flags := flags Or PR_GETTER
              Else
                flags := flags Or PR_SETTER;
              PAdvance(ctx);
            End;
          key_tok := ctx.ast.pt;
          ctx.ast.nodes[prop].tok := key_tok;
          If CurIsP(ctx, '[') Then
            Begin
              PAdvance(ctx);
              flags := flags Or PR_COMPUTED;
              ctx.ast.nodes[prop].e2 := ParseAssign(ctx, False);
              Expect(ctx, ']');
            End
          Else If IsPropertyNameTok(ctx, key_tok) Then
            PAdvance(ctx)
          Else
            Begin
              ParseError(ctx, key_tok, 'nom de propriete attendu, trouve ' +
                         TokenDesc(ctx, key_tok));
              Break;
            End;
          If CurIsP(ctx, '(') Then
            Begin
              fn := NewNode(ctx, N_FUNC_EXPR, key_tok);
              ctx.ast.nodes[fn].flags := fflags;
              flags := flags Or PR_METHOD;
              ParseFuncRest(ctx, fn);
              ctx.ast.nodes[prop].e1 := fn;
            End
          Else If flags And (PR_METHOD Or PR_GETTER Or PR_SETTER) <> 0 Then
            Begin
              ParseError(ctx, ctx.ast.pt, '"(" attendu apres le nom de methode, trouve ' +
                         TokenDesc(ctx, ctx.ast.pt));
              Break;
            End
          Else If CurIsP(ctx, ':') Then
            Begin
              PAdvance(ctx);
              ctx.ast.nodes[prop].e1 := ParseAssign(ctx, False);
            End
          Else If (ctx.lex.tokens[key_tok].kind = TK_IDENT) And
                  (flags And PR_COMPUTED = 0) And
                  (CurIsP(ctx, ',') Or CurIsP(ctx, '}') Or CurIsP(ctx, '=')) Then
            Begin
              flags := flags Or PR_SHORTHAND;
              fn := NewNode(ctx, N_IDENT, key_tok);
              ctx.ast.nodes[prop].e1 := fn;
              { a = 1 : valeur par defaut d'un motif d'affectation }
              If CurIsP(ctx, '=') Then
                Begin
                  PAdvance(ctx);
                  flags := flags Or PR_DEFAULT;
                  ctx.ast.nodes[prop].e3 := ParseAssign(ctx, False);
                End;
            End
          Else
            Begin
              ParseError(ctx, ctx.ast.pt, '":" attendu apres le nom de propriete, trouve ' +
                         TokenDesc(ctx, ctx.ast.pt));
              Break;
            End;
          ctx.ast.nodes[prop].flags := flags;
        End;
      ListAdd(ctx, first, last, prop);
      If CurIsP(ctx, ',') Then
        PAdvance(ctx)
      Else
        Break;
    End;
  Expect(ctx, '}');
  ctx.ast.nodes[node].e1 := first;
  ParseObjectLiteral := node;
End;

Function ParseFunctionExpr(Var ctx: TCompilerContext; is_async: Boolean): LongInt;
Var
  node, name_tok, save_scope, flags: LongInt;
  has_name: Boolean;
Begin
  flags := 0;
  If is_async Then
    Begin
      flags := flags Or FN_ASYNC;
      PAdvance(ctx);
    End;
  name_tok := ctx.ast.pt;
  PAdvance(ctx);
  If CurIsP(ctx, '*') Then
    Begin
      flags := flags Or FN_GENERATOR;
      PAdvance(ctx);
    End;
  has_name := ctx.lex.tokens[ctx.ast.pt].kind = TK_IDENT;
  If has_name Then
    name_tok := ctx.ast.pt;
  node := NewNode(ctx, N_FUNC_EXPR, name_tok);
  ctx.ast.nodes[node].flags := flags;
  If has_name Then
    Begin
      PAdvance(ctx);
      { le nom d'une expression de fonction vit dans sa propre portee }
      save_scope := ctx.ast.cur_scope;
      ctx.ast.cur_scope := node;
      DeclareName(ctx, DK_FNAME, name_tok, node);
      ctx.ast.cur_scope := save_scope;
    End;
  ParseFuncRest(ctx, node);
  ParseFunctionExpr := node;
End;

{ Fonction fleche : x => ..., (a, b) => ..., async x => ... }
Function ParseArrowFn(Var ctx: TCompilerContext; is_async, no_in: Boolean): LongInt;
Var
  node, par, bnd: LongInt;
  sv: TFuncSave;
Begin
  node := NewNode(ctx, N_FUNC_EXPR, ctx.ast.pt);
  ParseArrowFn := node;
  ctx.ast.nodes[node].flags := FN_ARROW;
  If is_async Then
    Begin
      ctx.ast.nodes[node].flags := ctx.ast.nodes[node].flags Or FN_ASYNC;
      PAdvance(ctx);
    End;
  EnterFunc(ctx, node, sv);
  If ctx.lex.tokens[ctx.ast.pt].kind = TK_IDENT Then
    Begin
      par := NewNode(ctx, N_PARAM, ctx.ast.pt);
      bnd := NewNode(ctx, N_BIND_IDENT, ctx.ast.pt);
      DeclareName(ctx, DK_PARAM, ctx.ast.pt, bnd);
      ctx.ast.nodes[par].e1 := bnd;
      ctx.ast.nodes[node].e1 := par;
      PAdvance(ctx);
    End
  Else
    ParseParamList(ctx, node);
  If Expect(ctx, '=>') Then
    Begin
      If CurIsP(ctx, '{') Then
        ctx.ast.nodes[node].e2 := ParseFuncBlock(ctx)
      Else
        Begin
          ctx.ast.nodes[node].flags := ctx.ast.nodes[node].flags Or FN_EXPR_BODY;
          ctx.ast.nodes[node].e2 := ParseAssign(ctx, no_in);
        End;
    End;
  LeaveFunc(ctx, sv);
End;

Function ParsePrimary(Var ctx: TCompilerContext): LongInt;
Var
  node, t: LongInt;
  s: TTokenText;
Begin
  ParsePrimary := 0;
  t := ctx.ast.pt;
  s := ctx.lex.tokens[t].text;
  Case ctx.lex.tokens[t].kind Of
    TK_IDENT:
      Begin
        If (s = 'async') And TkIsKw(ctx, PeekIdx(ctx, 1), 'function') And
           Not ctx.lex.tokens[PeekIdx(ctx, 1)].nl_before Then
          ParsePrimary := ParseFunctionExpr(ctx, True)
        Else
          Begin
            ParsePrimary := NewNode(ctx, N_IDENT, t);
            PAdvance(ctx);
          End;
      End;
    TK_NUMBER:
      Begin
        ParsePrimary := NewNode(ctx, N_NUMBER, t);
        PAdvance(ctx);
      End;
    TK_STRING:
      Begin
        ParsePrimary := NewNode(ctx, N_STRING, t);
        PAdvance(ctx);
      End;
    TK_REGEX:
      Begin
        ParsePrimary := NewNode(ctx, N_REGEX, t);
        PAdvance(ctx);
      End;
    TK_TEMPLATE:
      Begin
        If (ctx.lex.tokens[t].tpl = TP_NOSUB) Or
           (ctx.lex.tokens[t].tpl = TP_HEAD) Then
          ParsePrimary := ParseTemplate(ctx)
        Else
          ParseError(ctx, t, 'gabarit inattendu');
      End;
    TK_KEYWORD:
      Begin
        If s = 'this' Then
          node := NewNode(ctx, N_THIS, t)
        Else If s = 'super' Then
          node := NewNode(ctx, N_SUPER, t)
        Else If s = 'null' Then
          node := NewNode(ctx, N_NULL, t)
        Else If (s = 'true') Or (s = 'false') Then
          node := NewNode(ctx, N_BOOL, t)
        Else If s = 'function' Then
          Begin
            ParsePrimary := ParseFunctionExpr(ctx, False);
            Exit;
          End
        Else If s = 'class' Then
          Begin
            ParsePrimary := ParseClass(ctx, False);
            Exit;
          End
        Else
          Begin
            ParseError(ctx, t, 'expression attendue, trouve ' + TokenDesc(ctx, t));
            Exit;
          End;
        PAdvance(ctx);
        ParsePrimary := node;
      End;
    TK_PUNCT:
      Begin
        If s = '(' Then
          Begin
            PAdvance(ctx);
            node := ParseExpr(ctx, False);
            Expect(ctx, ')');
            If node <> 0 Then
              ctx.ast.nodes[node].paren := True;
            ParsePrimary := node;
          End
        Else If s = '[' Then
          ParsePrimary := ParseArrayLiteral(ctx)
        Else If s = '{' Then
          ParsePrimary := ParseObjectLiteral(ctx)
        Else
          ParseError(ctx, t, 'expression attendue, trouve ' + TokenDesc(ctx, t));
      End;
  Else
    ParseError(ctx, t, 'expression attendue, trouve ' + TokenDesc(ctx, t));
  End;
End;

{ new X(args) : le callee est un membre sans appel. }
Function ParseNew(Var ctx: TCompilerContext): LongInt;
Var
  node, callee, m, name_tok: LongInt;
Begin
  node := NewNode(ctx, N_NEW, ctx.ast.pt);
  ParseNew := node;
  PAdvance(ctx);
  If CurIsP(ctx, '.') Then
    Begin
      ParseError(ctx, ctx.ast.pt, 'new.target n''est pas supporte');
      Exit;
    End;
  If CurIsKw(ctx, 'new') Then
    callee := ParseNew(ctx)
  Else
    callee := ParsePrimary(ctx);
  While (callee <> 0) And (CurIsP(ctx, '.') Or CurIsP(ctx, '[')) Do
    Begin
      If CurIsP(ctx, '.') Then
        Begin
          PAdvance(ctx);
          name_tok := ctx.ast.pt;
          If Not IsPropertyNameTok(ctx, name_tok) Or
             (ctx.lex.tokens[name_tok].kind in [TK_STRING, TK_NUMBER]) Then
            Begin
              ParseError(ctx, name_tok, 'nom de propriete attendu apres ".", trouve ' +
                         TokenDesc(ctx, name_tok));
              Break;
            End;
          m := NewNode(ctx, N_MEMBER, name_tok);
          ctx.ast.nodes[m].e1 := callee;
          PAdvance(ctx);
        End
      Else
        Begin
          m := NewNode(ctx, N_INDEX, ctx.ast.pt);
          PAdvance(ctx);
          ctx.ast.nodes[m].e1 := callee;
          ctx.ast.nodes[m].e2 := ParseExpr(ctx, False);
          Expect(ctx, ']');
        End;
      callee := m;
    End;
  ctx.ast.nodes[node].e1 := callee;
  If CurIsP(ctx, '(') Then
    ctx.ast.nodes[node].e2 := ParseCallArgs(ctx);
End;

{ Expression gauche : primaire suivi d'acces, d'appels, de ?. et de
  gabarits etiquetes. }
Function ParseLHS(Var ctx: TCompilerContext): LongInt;
Var
  e, m, name_tok: LongInt;
  optional: Boolean;
Begin
  If CurIsKw(ctx, 'new') Then
    e := ParseNew(ctx)
  Else
    e := ParsePrimary(ctx);
  ParseLHS := e;
  If e = 0 Then
    Exit;
  While True Do
    Begin
      optional := False;
      If CurIsP(ctx, '?.') Then
        Begin
          optional := True;
          PAdvance(ctx);
        End;
      If CurIsP(ctx, '(') Then
        Begin
          m := NewNode(ctx, N_CALL, ctx.ast.pt);
          ctx.ast.nodes[m].e1 := e;
          ctx.ast.nodes[m].e2 := ParseCallArgs(ctx);
          If optional Then
            ctx.ast.nodes[m].flags := EF_OPTIONAL;
        End
      Else If CurIsP(ctx, '[') Then
        Begin
          m := NewNode(ctx, N_INDEX, ctx.ast.pt);
          PAdvance(ctx);
          ctx.ast.nodes[m].e1 := e;
          ctx.ast.nodes[m].e2 := ParseExpr(ctx, False);
          Expect(ctx, ']');
          If optional Then
            ctx.ast.nodes[m].flags := EF_OPTIONAL;
        End
      Else If optional Or CurIsP(ctx, '.') Then
        Begin
          If Not optional Then
            PAdvance(ctx);
          name_tok := ctx.ast.pt;
          If Not IsPropertyNameTok(ctx, name_tok) Or
             (ctx.lex.tokens[name_tok].kind in [TK_STRING, TK_NUMBER]) Then
            Begin
              ParseError(ctx, name_tok, 'nom de propriete attendu apres ".", trouve ' +
                         TokenDesc(ctx, name_tok));
              Exit;
            End;
          m := NewNode(ctx, N_MEMBER, name_tok);
          ctx.ast.nodes[m].e1 := e;
          If optional Then
            ctx.ast.nodes[m].flags := EF_OPTIONAL;
          PAdvance(ctx);
        End
      Else If (ctx.lex.tokens[ctx.ast.pt].kind = TK_TEMPLATE) And
              ((ctx.lex.tokens[ctx.ast.pt].tpl = TP_NOSUB) Or
               (ctx.lex.tokens[ctx.ast.pt].tpl = TP_HEAD)) Then
        Begin
          m := NewNode(ctx, N_TAGGED, ctx.ast.pt);
          ctx.ast.nodes[m].e1 := e;
          ctx.ast.nodes[m].e2 := ParseTemplate(ctx);
        End
      Else
        Break;
      e := m;
      ParseLHS := e;
    End;
End;

Function ParseUnary(Var ctx: TCompilerContext): LongInt;
Var
  node, t, operand: LongInt;
  s: TTokenText;
  is_op: Boolean;
Begin
  t := ctx.ast.pt;
  s := ctx.lex.tokens[t].text;
  is_op := False;
  If ctx.lex.tokens[t].kind = TK_OPERATOR Then
    { & unaire : operateur de reference &fn, extension utilisee par test22.js }
    is_op := (s = '!') Or (s = '~') Or (s = '+') Or (s = '-') Or (s = '&')
  Else If ctx.lex.tokens[t].kind = TK_KEYWORD Then
    is_op := (s = 'typeof') Or (s = 'void') Or (s = 'delete');
  If is_op Then
    Begin
      node := NewNode(ctx, N_UNARY, t);
      PAdvance(ctx);
      ctx.ast.nodes[node].e1 := ParseUnary(ctx);
      ParseUnary := node;
    End
  Else If (ctx.lex.tokens[t].kind = TK_OPERATOR) And
          ((s = '++') Or (s = '--')) Then
    Begin
      node := NewNode(ctx, N_UPDATE, t);
      ctx.ast.nodes[node].flags := UF_PREFIX;
      PAdvance(ctx);
      operand := ParseUnary(ctx);
      If (operand <> 0) And Not IsSimpleTarget(ctx, operand) Then
        ParseError(ctx, t, 'operande invalide pour ' + s);
      ctx.ast.nodes[node].e1 := operand;
      ParseUnary := node;
    End
  Else
    Begin
      operand := ParseLHS(ctx);
      ParseUnary := operand;
      If (operand <> 0) And (ctx.lex.tokens[ctx.ast.pt].kind = TK_OPERATOR) And
         ((ctx.lex.tokens[ctx.ast.pt].text = '++') Or
          (ctx.lex.tokens[ctx.ast.pt].text = '--')) And
         Not ctx.lex.tokens[ctx.ast.pt].nl_before Then
        Begin
          If Not IsSimpleTarget(ctx, operand) Then
            ParseError(ctx, ctx.ast.pt, 'operande invalide pour ' +
                       ctx.lex.tokens[ctx.ast.pt].text);
          node := NewNode(ctx, N_UPDATE, ctx.ast.pt);
          ctx.ast.nodes[node].e1 := operand;
          PAdvance(ctx);
          ParseUnary := node;
        End;
    End;
End;

{ Operateurs binaires par escalade de precedence ; ** est associatif a
  droite. }
Function ParseBinary(Var ctx: TCompilerContext; min_prec: LongInt;
                     no_in: Boolean): LongInt;
Var
  left, right, node, op_tok, prec: LongInt;
  s: TTokenText;
  is_logical: Boolean;
Begin
  left := ParseUnary(ctx);
  ParseBinary := left;
  If left = 0 Then
    Exit;
  While True Do
    Begin
      op_tok := ctx.ast.pt;
      s := ctx.lex.tokens[op_tok].text;
      prec := 0;
      If ctx.lex.tokens[op_tok].kind = TK_OPERATOR Then
        prec := BinPrec(s)
      Else If ctx.lex.tokens[op_tok].kind = TK_KEYWORD Then
        Begin
          If (s = 'instanceof') Or ((s = 'in') And Not no_in) Then
            prec := 8;
        End;
      If (prec = 0) Or (prec < min_prec) Then
        Break;
      PAdvance(ctx);
      If s = '**' Then
        right := ParseBinary(ctx, prec, no_in)
      Else
        right := ParseBinary(ctx, prec + 1, no_in);
      is_logical := (s = '&&') Or (s = '||') Or (s = '??');
      If is_logical Then
        node := NewNode(ctx, N_LOGICAL, op_tok)
      Else
        node := NewNode(ctx, N_BINARY, op_tok);
      ctx.ast.nodes[node].e1 := left;
      ctx.ast.nodes[node].e2 := right;
      { -a ** b est ambigu et interdit }
      If (s = '**') And (ctx.ast.nodes[left].kind = N_UNARY) And
         Not ctx.ast.nodes[left].paren Then
        ParseError(ctx, op_tok, 'operande unaire interdit a gauche de **, ajouter des parentheses');
      { a ?? b || c est interdit sans parentheses }
      If is_logical Then
        Begin
          If (s = '??') Then
            Begin
              If ((ctx.ast.nodes[left].kind = N_LOGICAL) And
                  Not ctx.ast.nodes[left].paren And
                  (ctx.lex.tokens[ctx.ast.nodes[left].tok].text <> '??')) Or
                 ((right <> 0) And (ctx.ast.nodes[right].kind = N_LOGICAL) And
                  Not ctx.ast.nodes[right].paren And
                  (ctx.lex.tokens[ctx.ast.nodes[right].tok].text <> '??')) Then
                ParseError(ctx, op_tok, '?? ne peut pas etre melange avec || ou && sans parentheses');
            End
          Else
            Begin
              If ((ctx.ast.nodes[left].kind = N_LOGICAL) And
                  Not ctx.ast.nodes[left].paren And
                  (ctx.lex.tokens[ctx.ast.nodes[left].tok].text = '??')) Or
                 ((right <> 0) And (ctx.ast.nodes[right].kind = N_LOGICAL) And
                  Not ctx.ast.nodes[right].paren And
                  (ctx.lex.tokens[ctx.ast.nodes[right].tok].text = '??')) Then
                ParseError(ctx, op_tok, '?? ne peut pas etre melange avec || ou && sans parentheses');
            End;
        End;
      left := node;
      ParseBinary := left;
    End;
End;

Function ParseConditional(Var ctx: TCompilerContext; no_in: Boolean): LongInt;
Var
  test, node: LongInt;
Begin
  test := ParseBinary(ctx, 1, no_in);
  ParseConditional := test;
  If (test <> 0) And CurIsP(ctx, '?') Then
    Begin
      node := NewNode(ctx, N_COND, ctx.ast.pt);
      PAdvance(ctx);
      ctx.ast.nodes[node].e1 := test;
      ctx.ast.nodes[node].e2 := ParseAssign(ctx, False);
      If Expect(ctx, ':') Then
        ctx.ast.nodes[node].e3 := ParseAssign(ctx, no_in);
      ParseConditional := node;
    End;
End;

Function ParseAssign(Var ctx: TCompilerContext; no_in: Boolean): LongInt;
Var
  left, right, node, op_tok: LongInt;
  s: TTokenText;
  is_async: Boolean;
Begin
  If IsArrowAhead(ctx, is_async) Then
    Begin
      ParseAssign := ParseArrowFn(ctx, is_async, no_in);
      Exit;
    End;
  left := ParseConditional(ctx, no_in);
  ParseAssign := left;
  If left = 0 Then
    Exit;
  op_tok := ctx.ast.pt;
  s := ctx.lex.tokens[op_tok].text;
  If (ctx.lex.tokens[op_tok].kind = TK_OPERATOR) And IsAssignOp(s) Then
    Begin
      If s = '=' Then
        Begin
          If Not IsPatternTarget(ctx, left) Then
            ParseError(ctx, op_tok, 'cible d''affectation invalide');
        End
      Else If Not IsSimpleTarget(ctx, left) Then
        ParseError(ctx, op_tok, 'cible d''affectation invalide pour ' + s);
      PAdvance(ctx);
      right := ParseAssign(ctx, no_in);
      node := NewNode(ctx, N_ASSIGN, op_tok);
      ctx.ast.nodes[node].e1 := left;
      ctx.ast.nodes[node].e2 := right;
      ParseAssign := node;
    End;
End;

{ Expression complete, avec virgules (sequence). }
Function ParseExpr(Var ctx: TCompilerContext; no_in: Boolean): LongInt;
Var
  first, last, e, seq: LongInt;
Begin
  e := ParseAssign(ctx, no_in);
  ParseExpr := e;
  If (e <> 0) And CurIsP(ctx, ',') Then
    Begin
      seq := NewNode(ctx, N_SEQUENCE, ctx.ast.pt);
      first := 0;
      last := 0;
      ListAdd(ctx, first, last, e);
      While CurIsP(ctx, ',') Do
        Begin
          PAdvance(ctx);
          e := ParseAssign(ctx, no_in);
          If e = 0 Then
            Break;
          ListAdd(ctx, first, last, e);
        End;
      ctx.ast.nodes[seq].e1 := first;
      ParseExpr := seq;
    End;
End;

{ ---- Fonctions ---- }

Function ParseStatement(Var ctx: TCompilerContext): LongInt; Forward;
Function ParseBlock(Var ctx: TCompilerContext; new_scope: Boolean): LongInt; Forward;

Function ParseStmtList(Var ctx: TCompilerContext): LongInt;
Var
  first, last, st, before: LongInt;
Begin
  first := 0;
  last := 0;
  While Not CurIsP(ctx, '}') And Not CurIsEof(ctx) And Not ctx.ast.stop Do
    Begin
      before := ctx.ast.pt;
      st := ParseStatement(ctx);
      ListAdd(ctx, first, last, st);
      If ctx.ast.pt = before Then
        PAdvance(ctx);
      If ctx.errors >= MAX_ERRORS Then
        Break;
    End;
  ParseStmtList := first;
End;

Function ParseParam(Var ctx: TCompilerContext): LongInt;
Var
  node: LongInt;
Begin
  node := NewNode(ctx, N_PARAM, ctx.ast.pt);
  If CurIsP(ctx, '...') Then
    Begin
      PAdvance(ctx);
      ctx.ast.nodes[node].flags := PF_REST;
    End;
  ctx.ast.nodes[node].e1 := ParseBindingTarget(ctx, DK_PARAM);
  If ctx.ast.nodes[node].flags <> PF_REST Then
    ctx.ast.nodes[node].e2 := ParseBindingDefault(ctx);
  ParseParam := node;
End;

{ Liste de parametres : ( a, b = 1, ...c ). Le jeton courant est la
  parenthese ouvrante ; la liste est rangee dans node.e1. }
Procedure ParseParamList(Var ctx: TCompilerContext; node: LongInt);
Var
  first, last, p: LongInt;
Begin
  first := 0;
  last := 0;
  If Expect(ctx, '(') Then
    Begin
      While Not CurIsP(ctx, ')') And Not CurIsEof(ctx) Do
        Begin
          p := ParseParam(ctx);
          If p = 0 Then
            Break;
          ListAdd(ctx, first, last, p);
          If CurIsP(ctx, ',') Then
            PAdvance(ctx)
          Else
            Break;
        End;
      Expect(ctx, ')');
    End;
  ctx.ast.nodes[node].e1 := first;
End;

{ Corps de fonction entre accolades, dans la portee de la fonction. }
Function ParseFuncBlock(Var ctx: TCompilerContext): LongInt;
Var
  body: LongInt;
Begin
  body := NewNode(ctx, N_BLOCK, ctx.ast.pt);
  ctx.ast.nodes[body].flags := 1;
  If Expect(ctx, '{') Then
    Begin
      ctx.ast.nodes[body].e1 := ParseStmtList(ctx);
      Expect(ctx, '}');
    End;
  ParseFuncBlock := body;
End;

{ Parametres puis corps, dans la portee du noeud fonction/methode. Le
  jeton courant est la parenthese ouvrante. }
Procedure ParseFuncRest(Var ctx: TCompilerContext; node: LongInt);
Var
  sv: TFuncSave;
Begin
  EnterFunc(ctx, node, sv);
  ParseParamList(ctx, node);
  ctx.ast.nodes[node].e2 := ParseFuncBlock(ctx);
  LeaveFunc(ctx, sv);
End;

{ function [*] nom (...) corps. Le jeton courant est function (ou async
  si is_async). }
Function ParseFunctionDecl(Var ctx: TCompilerContext; is_async: Boolean): LongInt;
Var
  node, name_tok: LongInt;
  flags: LongInt;
Begin
  flags := 0;
  If is_async Then
    Begin
      flags := flags Or FN_ASYNC;
      PAdvance(ctx);
    End;
  PAdvance(ctx);
  If CurIsP(ctx, '*') Then
    Begin
      flags := flags Or FN_GENERATOR;
      PAdvance(ctx);
    End;
  If ctx.lex.tokens[ctx.ast.pt].kind <> TK_IDENT Then
    Begin
      ParseError(ctx, ctx.ast.pt, 'nom de fonction attendu, trouve ' +
                 TokenDesc(ctx, ctx.ast.pt));
      Synchronize(ctx);
      ParseFunctionDecl := 0;
      Exit;
    End;
  name_tok := ctx.ast.pt;
  node := NewNode(ctx, N_FUNC_DECL, name_tok);
  ctx.ast.nodes[node].flags := flags;
  DeclareName(ctx, DK_FUNC, name_tok, node);
  PAdvance(ctx);
  ParseFuncRest(ctx, node);
  ParseFunctionDecl := node;
End;

{ ---- Classes ---- }

Function ParseClassMember(Var ctx: TCompilerContext; has_ctor: Boolean): LongInt;
Var
  node, key_tok, nx, blk: LongInt;
  flags: LongInt;
  is_method: Boolean;

  { Vrai si le jeton suivant est un nom : le jeton courant est alors un
    modificateur (static, async, get, set) et non le nom du membre. }
  Function IsModifier: Boolean;
  Begin
    nx := PeekIdx(ctx, 1);
    IsModifier := Not (TkIsP(ctx, nx, '(') Or TkIsP(ctx, nx, '=') Or
                       TkIsP(ctx, nx, ';') Or TkIsP(ctx, nx, '}')) And
                  (ctx.lex.tokens[nx].kind <> TK_EOF);
  End;

Begin
  ParseClassMember := 0;
  flags := 0;
  If CurIsKw(ctx, 'static') And IsModifier Then
    Begin
      PAdvance(ctx);
      flags := flags Or MF_STATIC;
      If CurIsP(ctx, '{') Then
        Begin
          node := NewNode(ctx, N_STATIC_BLOCK, ctx.ast.pt);
          ctx.ast.nodes[node].flags := MF_STATIC;
          blk := ParseBlock(ctx, True);
          ctx.ast.nodes[node].e1 := blk;
          ParseClassMember := node;
          Exit;
        End;
    End;
  If TkIsId(ctx, ctx.ast.pt, 'async') And IsModifier And
     Not ctx.lex.tokens[PeekIdx(ctx, 1)].nl_before Then
    Begin
      PAdvance(ctx);
      flags := flags Or MF_ASYNC;
    End;
  If CurIsP(ctx, '*') Then
    Begin
      PAdvance(ctx);
      flags := flags Or MF_GENERATOR;
    End;
  If (TkIsId(ctx, ctx.ast.pt, 'get') Or TkIsId(ctx, ctx.ast.pt, 'set')) And
     IsModifier Then
    Begin
      If TkIsId(ctx, ctx.ast.pt, 'get') Then
        flags := flags Or MF_GETTER
      Else
        flags := flags Or MF_SETTER;
      PAdvance(ctx);
    End;

  key_tok := ctx.ast.pt;
  node := NewNode(ctx, N_METHOD, key_tok);
  If CurIsP(ctx, '[') Then
    Begin
      PAdvance(ctx);
      flags := flags Or MF_COMPUTED;
      ctx.ast.nodes[node].e3 := ParseAssign(ctx, False);
      Expect(ctx, ']');
    End
  Else If IsPropertyNameTok(ctx, ctx.ast.pt) Then
    PAdvance(ctx)
  Else
    Begin
      ParseError(ctx, ctx.ast.pt, 'nom de membre de classe attendu, trouve ' +
                 TokenDesc(ctx, ctx.ast.pt));
      Synchronize(ctx);
      ParseClassMember := 0;
      Exit;
    End;

  is_method := CurIsP(ctx, '(');
  If is_method Then
    Begin
      If (flags And (MF_STATIC Or MF_COMPUTED) = 0) And
         (ctx.lex.tokens[key_tok].text = 'constructor') And
         (ctx.lex.tokens[key_tok].kind <> TK_STRING) Then
        Begin
          flags := flags Or MF_CONSTRUCTOR;
          If has_ctor Then
            ParseError(ctx, key_tok, 'une classe ne peut avoir qu''un seul constructeur');
        End;
      ctx.ast.nodes[node].flags := flags;
      ParseFuncRest(ctx, node);
    End
  Else
    Begin
      ctx.ast.nodes[node].kind := N_FIELD;
      ctx.ast.nodes[node].flags := flags;
      If CurIsP(ctx, '=') Then
        Begin
          PAdvance(ctx);
          ctx.ast.nodes[node].e1 := ParseAssign(ctx, False);
        End;
      ConsumeSemi(ctx);
    End;
  ParseClassMember := node;
End;

{ class [Nom] [extends expr] corps. Declaration (nom obligatoire) ou
  expression de classe. }
Function ParseClass(Var ctx: TCompilerContext; is_decl: Boolean): LongInt;
Var
  node, name_tok, first, last, m, before, save_scope: LongInt;
  has_ctor, has_name: Boolean;
Begin
  name_tok := ctx.ast.pt;
  PAdvance(ctx);
  has_name := ctx.lex.tokens[ctx.ast.pt].kind = TK_IDENT;
  If is_decl And Not has_name Then
    Begin
      ParseError(ctx, ctx.ast.pt, 'nom de classe attendu, trouve ' +
                 TokenDesc(ctx, ctx.ast.pt));
      Synchronize(ctx);
      ParseClass := 0;
      Exit;
    End;
  If has_name Then
    name_tok := ctx.ast.pt;
  If is_decl Then
    node := NewNode(ctx, N_CLASS_DECL, name_tok)
  Else
    node := NewNode(ctx, N_CLASS_EXPR, name_tok);
  If is_decl Then
    DeclareName(ctx, DK_CLASS, name_tok, node);
  If has_name Then
    PAdvance(ctx);
  { la classe ouvre une portee : le nom d'une expression de classe y vit }
  save_scope := ctx.ast.cur_scope;
  ctx.ast.cur_scope := node;
  If has_name And Not is_decl Then
    DeclareName(ctx, DK_FNAME, name_tok, node);
  If CurIsKw(ctx, 'extends') Then
    Begin
      PAdvance(ctx);
      ctx.ast.nodes[node].e1 := ParseLHS(ctx);
    End;
  first := 0;
  last := 0;
  has_ctor := False;
  If Expect(ctx, '{') Then
    Begin
      While Not CurIsP(ctx, '}') And Not CurIsEof(ctx) And
            Not ctx.ast.stop Do
        Begin
          If CurIsP(ctx, ';') Then
            PAdvance(ctx)
          Else
            Begin
              before := ctx.ast.pt;
              m := ParseClassMember(ctx, has_ctor);
              If (m <> 0) And (ctx.ast.nodes[m].kind = N_METHOD) And
                 (ctx.ast.nodes[m].flags And MF_CONSTRUCTOR <> 0) Then
                has_ctor := True;
              ListAdd(ctx, first, last, m);
              If ctx.ast.pt = before Then
                PAdvance(ctx);
              If ctx.errors >= MAX_ERRORS Then
                Break;
            End;
        End;
      Expect(ctx, '}');
    End;
  ctx.ast.nodes[node].e2 := first;
  ctx.ast.cur_scope := save_scope;
  ParseClass := node;
End;

{ ---- Instructions ---- }

Function ParseBlock(Var ctx: TCompilerContext; new_scope: Boolean): LongInt;
Var
  node, save_scope: LongInt;
Begin
  node := NewNode(ctx, N_BLOCK, ctx.ast.pt);
  ParseBlock := node;
  If Not Expect(ctx, '{') Then
    Exit;
  save_scope := ctx.ast.cur_scope;
  If new_scope Then
    ctx.ast.cur_scope := node;
  ctx.ast.nodes[node].e1 := ParseStmtList(ctx);
  ctx.ast.cur_scope := save_scope;
  Expect(ctx, '}');
End;

{ Condition entre parentheses : ( expression ) }
Function ParseParenExpr(Var ctx: TCompilerContext): LongInt;
Begin
  ParseParenExpr := 0;
  If Not Expect(ctx, '(') Then
    Exit;
  ParseParenExpr := ParseExpr(ctx, False);
  Expect(ctx, ')');
End;

Function ParseIf(Var ctx: TCompilerContext): LongInt;
Var
  node: LongInt;
Begin
  node := NewNode(ctx, N_IF, ctx.ast.pt);
  PAdvance(ctx);
  ctx.ast.nodes[node].e1 := ParseParenExpr(ctx);
  ctx.ast.nodes[node].e2 := ParseStatement(ctx);
  If CurIsKw(ctx, 'else') Then
    Begin
      PAdvance(ctx);
      ctx.ast.nodes[node].e3 := ParseStatement(ctx);
    End;
  ParseIf := node;
End;

Function ParseWhile(Var ctx: TCompilerContext): LongInt;
Var
  node: LongInt;
Begin
  node := NewNode(ctx, N_WHILE, ctx.ast.pt);
  PAdvance(ctx);
  ctx.ast.nodes[node].e1 := ParseParenExpr(ctx);
  Inc(ctx.ast.loop_depth);
  ctx.ast.nodes[node].e2 := ParseStatement(ctx);
  Dec(ctx.ast.loop_depth);
  ParseWhile := node;
End;

Function ParseDoWhile(Var ctx: TCompilerContext): LongInt;
Var
  node: LongInt;
Begin
  node := NewNode(ctx, N_DO_WHILE, ctx.ast.pt);
  PAdvance(ctx);
  Inc(ctx.ast.loop_depth);
  ctx.ast.nodes[node].e1 := ParseStatement(ctx);
  Dec(ctx.ast.loop_depth);
  If CurIsKw(ctx, 'while') Then
    Begin
      PAdvance(ctx);
      ctx.ast.nodes[node].e2 := ParseParenExpr(ctx);
    End
  Else
    ParseError(ctx, ctx.ast.pt, '"while" attendu, trouve ' +
               TokenDesc(ctx, ctx.ast.pt));
  { le point-virgule apres do-while est toujours facultatif }
  If CurIsP(ctx, ';') Then
    PAdvance(ctx);
  ParseDoWhile := node;
End;

Function ParseFor(Var ctx: TCompilerContext): LongInt;
Var
  node, save_scope, init, test, upd, body: LongInt;
  is_of, is_in: Boolean;
  kind: TNodeKind;
Begin
  node := NewNode(ctx, N_FOR, ctx.ast.pt);
  ParseFor := node;
  PAdvance(ctx);
  If TkIsId(ctx, ctx.ast.pt, 'await') Then
    Begin
      ParseError(ctx, ctx.ast.pt, 'for await n''est pas supporte');
      Synchronize(ctx);
      Exit;
    End;
  If Not Expect(ctx, '(') Then
    Begin
      Synchronize(ctx);
      Exit;
    End;
  save_scope := ctx.ast.cur_scope;
  ctx.ast.cur_scope := node;

  init := 0;
  If CurIsP(ctx, ';') Then
    { pas d'initialisation }
  Else If CurIsKw(ctx, 'var') Or CurIsKw(ctx, 'let') Or CurIsKw(ctx, 'const') Then
    init := ParseVarDecl(ctx, True)
  Else
    init := ParseExpr(ctx, True);

  is_in := CurIsKw(ctx, 'in');
  is_of := TkIsId(ctx, ctx.ast.pt, 'of');
  If (is_in Or is_of) And (init <> 0) Then
    Begin
      If ctx.ast.nodes[init].kind = N_VAR_DECL Then
        Begin
          If (ctx.ast.nodes[init].e1 = 0) Or
             (ctx.ast.nodes[ctx.ast.nodes[init].e1].next <> 0) Then
            ParseError(ctx, ctx.ast.pt,
                       'une seule variable est permise dans for-in / for-of')
          Else If ctx.ast.nodes[ctx.ast.nodes[init].e1].e2 <> 0 Then
            ParseError(ctx, ctx.ast.pt,
                       'initialiseur interdit dans for-in / for-of');
        End;
      If is_of Then
        kind := N_FOR_OF
      Else
        kind := N_FOR_IN;
      ctx.ast.nodes[node].kind := kind;
      PAdvance(ctx);
      ctx.ast.nodes[node].e1 := init;
      If is_in Then
        ctx.ast.nodes[node].e2 := ParseExpr(ctx, False)
      Else
        ctx.ast.nodes[node].e2 := ParseAssign(ctx, False);
      Expect(ctx, ')');
      Inc(ctx.ast.loop_depth);
      ctx.ast.nodes[node].e3 := ParseStatement(ctx);
      Dec(ctx.ast.loop_depth);
    End
  Else
    Begin
      ctx.ast.nodes[node].e1 := init;
      If Expect(ctx, ';') Then
        Begin
          test := 0;
          If Not CurIsP(ctx, ';') Then
            test := ParseExpr(ctx, False);
          ctx.ast.nodes[node].e2 := test;
          If Expect(ctx, ';') Then
            Begin
              upd := 0;
              If Not CurIsP(ctx, ')') Then
                upd := ParseExpr(ctx, False);
              ctx.ast.nodes[node].e3 := upd;
              If Expect(ctx, ')') Then
                Begin
                  Inc(ctx.ast.loop_depth);
                  body := ParseStatement(ctx);
                  Dec(ctx.ast.loop_depth);
                  ctx.ast.nodes[node].e4 := body;
                End;
            End;
        End;
    End;
  ctx.ast.cur_scope := save_scope;
End;

Function ParseSwitch(Var ctx: TCompilerContext): LongInt;
Var
  node, save_scope, cs, first, last, sfirst, slast, st, before: LongInt;
  has_default: Boolean;
Begin
  node := NewNode(ctx, N_SWITCH, ctx.ast.pt);
  ParseSwitch := node;
  PAdvance(ctx);
  ctx.ast.nodes[node].e1 := ParseParenExpr(ctx);
  If Not Expect(ctx, '{') Then
    Begin
      Synchronize(ctx);
      Exit;
    End;
  save_scope := ctx.ast.cur_scope;
  ctx.ast.cur_scope := node;
  Inc(ctx.ast.switch_depth);
  first := 0;
  last := 0;
  has_default := False;
  While Not CurIsP(ctx, '}') And Not CurIsEof(ctx) And Not ctx.ast.stop Do
    Begin
      before := ctx.ast.pt;
      If CurIsKw(ctx, 'case') Or CurIsKw(ctx, 'default') Then
        Begin
          cs := NewNode(ctx, N_CASE, ctx.ast.pt);
          If CurIsKw(ctx, 'case') Then
            Begin
              PAdvance(ctx);
              ctx.ast.nodes[cs].e1 := ParseExpr(ctx, False);
            End
          Else
            Begin
              If has_default Then
                ParseError(ctx, ctx.ast.pt, '"default" en double dans le switch');
              has_default := True;
              PAdvance(ctx);
            End;
          Expect(ctx, ':');
          sfirst := 0;
          slast := 0;
          While Not CurIsP(ctx, '}') And Not CurIsEof(ctx) And
                Not CurIsKw(ctx, 'case') And Not CurIsKw(ctx, 'default') And
                Not ctx.ast.stop Do
            Begin
              before := ctx.ast.pt;
              st := ParseStatement(ctx);
              ListAdd(ctx, sfirst, slast, st);
              If ctx.ast.pt = before Then
                PAdvance(ctx);
              If ctx.errors >= MAX_ERRORS Then
                Break;
            End;
          ctx.ast.nodes[cs].e2 := sfirst;
          ListAdd(ctx, first, last, cs);
        End
      Else
        Begin
          ParseError(ctx, ctx.ast.pt, '"case" ou "default" attendu, trouve ' +
                     TokenDesc(ctx, ctx.ast.pt));
          Synchronize(ctx);
          If ctx.ast.pt = before Then
            PAdvance(ctx);
        End;
      If ctx.errors >= MAX_ERRORS Then
        Break;
    End;
  ctx.ast.nodes[node].e2 := first;
  Expect(ctx, '}');
  Dec(ctx.ast.switch_depth);
  ctx.ast.cur_scope := save_scope;
End;

Function ParseTry(Var ctx: TCompilerContext): LongInt;
Var
  node, cn, save_scope: LongInt;
Begin
  node := NewNode(ctx, N_TRY, ctx.ast.pt);
  ParseTry := node;
  PAdvance(ctx);
  ctx.ast.nodes[node].e1 := ParseBlock(ctx, True);
  If CurIsKw(ctx, 'catch') Then
    Begin
      cn := NewNode(ctx, N_CATCH, ctx.ast.pt);
      PAdvance(ctx);
      save_scope := ctx.ast.cur_scope;
      ctx.ast.cur_scope := cn;
      If CurIsP(ctx, '(') Then
        Begin
          PAdvance(ctx);
          ctx.ast.nodes[cn].e1 := ParseBindingTarget(ctx, DK_CATCH);
          Expect(ctx, ')');
        End;
      ctx.ast.nodes[cn].e2 := ParseBlock(ctx, False);
      ctx.ast.cur_scope := save_scope;
      ctx.ast.nodes[node].e2 := cn;
    End;
  If CurIsKw(ctx, 'finally') Then
    Begin
      PAdvance(ctx);
      ctx.ast.nodes[node].e3 := ParseBlock(ctx, True);
    End;
  If (ctx.ast.nodes[node].e2 = 0) And (ctx.ast.nodes[node].e3 = 0) Then
    ParseError(ctx, ctx.ast.nodes[node].tok,
               'try exige un bloc catch ou finally');
End;

Function FindLabel(Var ctx: TCompilerContext; tok: LongInt): LongInt;
Var
  i: LongInt;
Begin
  FindLabel := 0;
  For i := 1 To ctx.ast.label_count Do
    If ctx.lex.tokens[ctx.ast.labels[i].tok].text = ctx.lex.tokens[tok].text Then
      FindLabel := i;
End;

Function ParseBreakContinue(Var ctx: TCompilerContext; is_break: Boolean): LongInt;
Var
  node, lbl, kw_tok: LongInt;
Begin
  kw_tok := ctx.ast.pt;
  If is_break Then
    node := NewNode(ctx, N_BREAK, kw_tok)
  Else
    node := NewNode(ctx, N_CONTINUE, kw_tok);
  PAdvance(ctx);
  If (ctx.lex.tokens[ctx.ast.pt].kind = TK_IDENT) And
     Not ctx.lex.tokens[ctx.ast.pt].nl_before Then
    Begin
      ctx.ast.nodes[node].e1 := ctx.ast.pt;
      lbl := FindLabel(ctx, ctx.ast.pt);
      If lbl = 0 Then
        ParseError(ctx, ctx.ast.pt, 'etiquette inconnue: ' +
                   ctx.lex.tokens[ctx.ast.pt].text)
      Else If (Not is_break) And (Not ctx.ast.labels[lbl].is_loop) Then
        ParseError(ctx, ctx.ast.pt, 'continue exige une etiquette de boucle: ' +
                   ctx.lex.tokens[ctx.ast.pt].text);
      PAdvance(ctx);
    End
  Else If is_break Then
    Begin
      If ctx.ast.loop_depth + ctx.ast.switch_depth = 0 Then
        ParseError(ctx, kw_tok, 'break en dehors d''une boucle ou d''un switch');
    End
  Else If ctx.ast.loop_depth = 0 Then
    ParseError(ctx, kw_tok, 'continue en dehors d''une boucle');
  ConsumeSemi(ctx);
  ParseBreakContinue := node;
End;

Function ParseReturnThrow(Var ctx: TCompilerContext; is_return: Boolean): LongInt;
Var
  node, kw_tok: LongInt;
Begin
  kw_tok := ctx.ast.pt;
  If is_return Then
    Begin
      node := NewNode(ctx, N_RETURN, kw_tok);
      If ctx.ast.func_depth = 0 Then
        ParseError(ctx, kw_tok, 'return en dehors d''une fonction');
    End
  Else
    node := NewNode(ctx, N_THROW, kw_tok);
  PAdvance(ctx);
  If CurIsP(ctx, ';') Or CurIsP(ctx, '}') Or CurIsEof(ctx) Or
     ctx.lex.tokens[ctx.ast.pt].nl_before Then
    Begin
      If Not is_return Then
        ParseError(ctx, ctx.ast.pt, 'expression attendue apres throw');
    End
  Else
    ctx.ast.nodes[node].e1 := ParseExpr(ctx, False);
  ConsumeSemi(ctx);
  ParseReturnThrow := node;
End;

Function ParseLabeled(Var ctx: TCompilerContext): LongInt;
Var
  node, lbl_tok: LongInt;
Begin
  lbl_tok := ctx.ast.pt;
  node := NewNode(ctx, N_LABELED, lbl_tok);
  ParseLabeled := node;
  If FindLabel(ctx, lbl_tok) <> 0 Then
    ParseError(ctx, lbl_tok, 'etiquette en double: ' +
               ctx.lex.tokens[lbl_tok].text);
  PAdvance(ctx);
  PAdvance(ctx);
  If ctx.ast.label_count < MAX_LABELS Then
    Begin
      Inc(ctx.ast.label_count);
      ctx.ast.labels[ctx.ast.label_count].tok := lbl_tok;
      ctx.ast.labels[ctx.ast.label_count].is_loop :=
        CurIsKw(ctx, 'for') Or CurIsKw(ctx, 'while') Or CurIsKw(ctx, 'do');
      ctx.ast.nodes[node].e1 := ParseStatement(ctx);
      Dec(ctx.ast.label_count);
    End
  Else
    Begin
      ParseError(ctx, lbl_tok, 'etiquettes imbriquees trop profondes');
      ctx.ast.nodes[node].e1 := ParseStatement(ctx);
    End;
End;

Function ParseExprStatement(Var ctx: TCompilerContext): LongInt;
Var
  node, ex: LongInt;
Begin
  node := NewNode(ctx, N_EXPR_STMT, ctx.ast.pt);
  ex := ParseExpr(ctx, False);
  If ex = 0 Then
    Begin
      Synchronize(ctx);
      ParseExprStatement := 0;
      Exit;
    End;
  ctx.ast.nodes[node].e1 := ex;
  ConsumeSemi(ctx);
  ParseExprStatement := node;
End;

Function ParseStatement(Var ctx: TCompilerContext): LongInt;
Var
  node, nx: LongInt;
  s: TTokenText;
Begin
  ParseStatement := 0;
  s := ctx.lex.tokens[ctx.ast.pt].text;
  If CurIsP(ctx, '{') Then
    ParseStatement := ParseBlock(ctx, True)
  Else If CurIsP(ctx, ';') Then
    Begin
      ParseStatement := NewNode(ctx, N_EMPTY, ctx.ast.pt);
      PAdvance(ctx);
    End
  Else If ctx.lex.tokens[ctx.ast.pt].kind = TK_KEYWORD Then
    Begin
      If (s = 'var') Or (s = 'let') Or (s = 'const') Then
        Begin
          node := ParseVarDecl(ctx, False);
          ConsumeSemi(ctx);
          ParseStatement := node;
        End
      Else If s = 'if' Then
        ParseStatement := ParseIf(ctx)
      Else If s = 'for' Then
        ParseStatement := ParseFor(ctx)
      Else If s = 'while' Then
        ParseStatement := ParseWhile(ctx)
      Else If s = 'do' Then
        ParseStatement := ParseDoWhile(ctx)
      Else If s = 'switch' Then
        ParseStatement := ParseSwitch(ctx)
      Else If s = 'break' Then
        ParseStatement := ParseBreakContinue(ctx, True)
      Else If s = 'continue' Then
        ParseStatement := ParseBreakContinue(ctx, False)
      Else If s = 'return' Then
        ParseStatement := ParseReturnThrow(ctx, True)
      Else If s = 'throw' Then
        ParseStatement := ParseReturnThrow(ctx, False)
      Else If s = 'try' Then
        ParseStatement := ParseTry(ctx)
      Else If s = 'function' Then
        ParseStatement := ParseFunctionDecl(ctx, False)
      Else If s = 'class' Then
        ParseStatement := ParseClass(ctx, True)
      Else If s = 'debugger' Then
        Begin
          node := NewNode(ctx, N_DEBUGGER, ctx.ast.pt);
          PAdvance(ctx);
          ConsumeSemi(ctx);
          ParseStatement := node;
        End
      Else If (s = 'with') Or (s = 'import') Or (s = 'export') Or
              (s = 'enum') Then
        Begin
          ParseError(ctx, ctx.ast.pt, '"' + s + '" n''est pas supporte');
          Synchronize(ctx);
        End
      Else If (s = 'else') Or (s = 'case') Or (s = 'default') Or
              (s = 'catch') Or (s = 'finally') Then
        Begin
          ParseError(ctx, ctx.ast.pt, '"' + s + '" inattendu');
          Synchronize(ctx);
        End
      Else
        ParseStatement := ParseExprStatement(ctx);
    End
  Else If ctx.lex.tokens[ctx.ast.pt].kind = TK_IDENT Then
    Begin
      nx := PeekIdx(ctx, 1);
      If TkIsP(ctx, nx, ':') Then
        ParseStatement := ParseLabeled(ctx)
      Else If (s = 'async') And TkIsKw(ctx, nx, 'function') And
              Not ctx.lex.tokens[nx].nl_before Then
        ParseStatement := ParseFunctionDecl(ctx, True)
      Else
        ParseStatement := ParseExprStatement(ctx);
    End
  Else If CurIsP(ctx, '}') Then
    Begin
      ParseError(ctx, ctx.ast.pt, '"}" inattendu');
      PAdvance(ctx);
    End
  Else
    ParseStatement := ParseExprStatement(ctx);
End;

Function ParseProgram(Var ctx: TCompilerContext): Boolean;
Var
  first, last, st, before: LongInt;
Begin
  ParseProgram := False;
  If ctx.lex.token_count = 0 Then
    Begin
      PipelineError(ctx, 'jetons absents avant l''analyse syntaxique');
      Exit;
    End;
  ctx.ast.node_count := 0;
  ctx.ast.decl_count := 0;
  ctx.ast.analyzed := False;
  ctx.ast.pt := 1;
  ctx.ast.stop := False;
  ctx.ast.last_err_tok := 0;
  ctx.ast.loop_depth := 0;
  ctx.ast.switch_depth := 0;
  ctx.ast.func_depth := 0;
  ctx.ast.label_count := 0;
  ctx.ast.root := NewNode(ctx, N_PROGRAM, 1);
  ctx.ast.cur_scope := ctx.ast.root;
  ctx.ast.cur_func := ctx.ast.root;
  first := 0;
  last := 0;
  While Not CurIsEof(ctx) And Not ctx.ast.stop Do
    Begin
      before := ctx.ast.pt;
      st := ParseStatement(ctx);
      ListAdd(ctx, first, last, st);
      If ctx.ast.pt = before Then
        PAdvance(ctx);
      If ctx.errors >= MAX_ERRORS Then
        Begin
          PipelineError(ctx, 'trop d''erreurs, arret du parseur');
          Break;
        End;
    End;
  ctx.ast.nodes[ctx.ast.root].e1 := first;
  If ctx.options.verbose Then
    Writeln('AST    : ', ctx.ast.node_count, ' noeuds, ',
            ctx.ast.decl_count, ' declarations');
  ParseProgram := ctx.errors = 0;
End;

{ ---- Affichage de l'AST (option -ast) ---- }

Function NodeKindName(kind: TNodeKind): TString;
Begin
  Case kind Of
    N_PROGRAM:        NodeKindName := 'Program';
    N_BLOCK:          NodeKindName := 'Block';
    N_EMPTY:          NodeKindName := 'Empty';
    N_EXPR_STMT:      NodeKindName := 'ExprStmt';
    N_VAR_DECL:       NodeKindName := 'VarDecl';
    N_DECLARATOR:     NodeKindName := 'Declarator';
    N_BIND_IDENT:     NodeKindName := 'Bind';
    N_ARRAY_PATTERN:  NodeKindName := 'ArrayPattern';
    N_OBJECT_PATTERN: NodeKindName := 'ObjectPattern';
    N_PATTERN_ELEM:   NodeKindName := 'PatternElem';
    N_PATTERN_PROP:   NodeKindName := 'PatternProp';
    N_IF:             NodeKindName := 'If';
    N_SWITCH:         NodeKindName := 'Switch';
    N_CASE:           NodeKindName := 'Case';
    N_WHILE:          NodeKindName := 'While';
    N_DO_WHILE:       NodeKindName := 'DoWhile';
    N_FOR:            NodeKindName := 'For';
    N_FOR_IN:         NodeKindName := 'ForIn';
    N_FOR_OF:         NodeKindName := 'ForOf';
    N_BREAK:          NodeKindName := 'Break';
    N_CONTINUE:       NodeKindName := 'Continue';
    N_RETURN:         NodeKindName := 'Return';
    N_THROW:          NodeKindName := 'Throw';
    N_TRY:            NodeKindName := 'Try';
    N_CATCH:          NodeKindName := 'Catch';
    N_LABELED:        NodeKindName := 'Labeled';
    N_DEBUGGER:       NodeKindName := 'Debugger';
    N_FUNC_DECL:      NodeKindName := 'FuncDecl';
    N_PARAM:          NodeKindName := 'Param';
    N_CLASS_DECL:     NodeKindName := 'ClassDecl';
    N_METHOD:         NodeKindName := 'Method';
    N_FIELD:          NodeKindName := 'Field';
    N_STATIC_BLOCK:   NodeKindName := 'StaticBlock';
    N_NUMBER:         NodeKindName := 'Number';
    N_STRING:         NodeKindName := 'String';
    N_REGEX:          NodeKindName := 'Regex';
    N_TEMPLATE:       NodeKindName := 'Template';
    N_TEMPLATE_STR:   NodeKindName := 'TemplateStr';
    N_IDENT:          NodeKindName := 'Ident';
    N_THIS:           NodeKindName := 'This';
    N_SUPER:          NodeKindName := 'Super';
    N_NULL:           NodeKindName := 'Null';
    N_BOOL:           NodeKindName := 'Bool';
    N_ARRAY_LIT:      NodeKindName := 'ArrayLit';
    N_ELISION:        NodeKindName := 'Elision';
    N_SPREAD:         NodeKindName := 'Spread';
    N_OBJECT_LIT:     NodeKindName := 'ObjectLit';
    N_PROP:           NodeKindName := 'Prop';
    N_FUNC_EXPR:      NodeKindName := 'FuncExpr';
    N_CLASS_EXPR:     NodeKindName := 'ClassExpr';
    N_UNARY:          NodeKindName := 'Unary';
    N_UPDATE:         NodeKindName := 'Update';
    N_BINARY:         NodeKindName := 'Binary';
    N_LOGICAL:        NodeKindName := 'Logical';
    N_ASSIGN:         NodeKindName := 'Assign';
    N_COND:           NodeKindName := 'Cond';
    N_CALL:           NodeKindName := 'Call';
    N_NEW:            NodeKindName := 'New';
    N_MEMBER:         NodeKindName := 'Member';
    N_INDEX:          NodeKindName := 'Index';
    N_SEQUENCE:       NodeKindName := 'Sequence';
    N_TAGGED:         NodeKindName := 'TaggedTemplate';
  Else
    NodeKindName := 'Node';
  End;
End;

Function DeclKindName(kind: TDeclKind): TString;
Begin
  Case kind Of
    DK_VAR:   DeclKindName := 'var';
    DK_LET:   DeclKindName := 'let';
    DK_CONST: DeclKindName := 'const';
    DK_FUNC:  DeclKindName := 'function';
    DK_CLASS: DeclKindName := 'class';
    DK_PARAM: DeclKindName := 'param';
    DK_CATCH: DeclKindName := 'catch';
    DK_FNAME: DeclKindName := 'fname';
    DK_ARGS:  DeclKindName := 'arguments';
  Else
    DeclKindName := '?';
  End;
End;

Procedure DumpNodeList(Var ctx: TCompilerContext; n, indent: LongInt); Forward;
Procedure WriteAnnotation(Var ctx: TCompilerContext; n: LongInt); Forward;

Procedure DumpNode(Var ctx: TCompilerContext; n, indent: LongInt);
Var
  i, e: LongInt;
  t: TTokenText;
  f: LongInt;
Begin
  If n = 0 Then
    Exit;
  For i := 1 To indent Do
    Write('  ');
  Write(NodeKindName(ctx.ast.nodes[n].kind));
  f := ctx.ast.nodes[n].flags;
  Case ctx.ast.nodes[n].kind Of
    N_VAR_DECL:
      Case f Of
        DF_VAR:   Write(' var');
        DF_LET:   Write(' let');
        DF_CONST: Write(' const');
      End;
    N_BIND_IDENT, N_FUNC_DECL, N_CLASS_DECL, N_LABELED:
      Begin
        Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].tok].text);
        If (ctx.ast.nodes[n].kind = N_FUNC_DECL) Then
          Begin
            If f And FN_ASYNC <> 0 Then
              Write(' async');
            If f And FN_GENERATOR <> 0 Then
              Write(' generator');
          End;
      End;
    N_BREAK, N_CONTINUE:
      If ctx.ast.nodes[n].e1 <> 0 Then
        Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].e1].text);
    N_PARAM:
      If f And PF_REST <> 0 Then
        Write(' ...');
    N_PATTERN_ELEM:
      Begin
        If f And PF_REST <> 0 Then
          Write(' ...');
        If ctx.ast.nodes[n].e1 = 0 Then
          Write(' (trou)');
      End;
    N_PATTERN_PROP:
      Begin
        If f And PP_REST <> 0 Then
          Write(' ...')
        Else If f And PP_COMPUTED = 0 Then
          Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].tok].text);
        If f And PP_SHORTHAND <> 0 Then
          Write(' (raccourci)');
      End;
    N_METHOD, N_FIELD:
      Begin
        If f And MF_COMPUTED <> 0 Then
          Write(' [calcule]')
        Else
          Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].tok].text);
        If f And MF_STATIC <> 0 Then
          Write(' static');
        If f And MF_GETTER <> 0 Then
          Write(' get');
        If f And MF_SETTER <> 0 Then
          Write(' set');
        If f And MF_ASYNC <> 0 Then
          Write(' async');
        If f And MF_GENERATOR <> 0 Then
          Write(' generator');
        If f And MF_CONSTRUCTOR <> 0 Then
          Write(' constructor');
      End;
    N_NUMBER, N_STRING, N_REGEX, N_IDENT, N_BOOL, N_THIS, N_SUPER,
    N_NULL:
      Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].tok].text);
    N_TEMPLATE_STR:
      Begin
        Write(' "');
        PrintPoolText(ctx, ctx.lex.tokens[ctx.ast.nodes[n].tok].sval_off,
                      ctx.lex.tokens[ctx.ast.nodes[n].tok].sval_len);
        Write('"');
      End;
    N_UNARY, N_BINARY, N_LOGICAL, N_ASSIGN:
      Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].tok].text);
    N_UPDATE:
      Begin
        Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].tok].text);
        If f And UF_PREFIX <> 0 Then
          Write(' prefixe')
        Else
          Write(' postfixe');
      End;
    N_MEMBER:
      Begin
        Write(' .', ctx.lex.tokens[ctx.ast.nodes[n].tok].text);
        If f And EF_OPTIONAL <> 0 Then
          Write(' ?.');
      End;
    N_INDEX, N_CALL:
      If f And EF_OPTIONAL <> 0 Then
        Write(' ?.');
    N_PROP:
      Begin
        If f And PR_SPREAD <> 0 Then
          Write(' ...')
        Else If f And PR_COMPUTED = 0 Then
          Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].tok].text)
        Else
          Write(' [calcule]');
        If f And PR_SHORTHAND <> 0 Then
          Write(' (raccourci)');
        If f And PR_GETTER <> 0 Then
          Write(' get');
        If f And PR_SETTER <> 0 Then
          Write(' set');
        If f And PR_METHOD <> 0 Then
          Write(' methode');
      End;
    N_FUNC_EXPR:
      Begin
        If f And FN_ARROW <> 0 Then
          Write(' fleche')
        Else If f And FN_METHOD = 0 Then
          Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].tok].text);
        If f And FN_ASYNC <> 0 Then
          Write(' async');
        If f And FN_GENERATOR <> 0 Then
          Write(' generator');
        If f And FN_EXPR_BODY <> 0 Then
          Write(' (corps expression)');
      End;
    N_CLASS_EXPR:
      If ctx.lex.tokens[ctx.ast.nodes[n].tok].kind = TK_IDENT Then
        Write(' ', ctx.lex.tokens[ctx.ast.nodes[n].tok].text);
  End;
  If ctx.ast.analyzed Then
    WriteAnnotation(ctx, n);
  Write('  @', ctx.lex.tokens[ctx.ast.nodes[n].tok].line, ':',
        ctx.lex.tokens[ctx.ast.nodes[n].tok].col);
  Writeln;
  Case ctx.ast.nodes[n].kind Of
    N_PROGRAM, N_BLOCK, N_VAR_DECL, N_ARRAY_PATTERN, N_OBJECT_PATTERN,
    N_ARRAY_LIT, N_OBJECT_LIT, N_TEMPLATE, N_SEQUENCE:
      DumpNodeList(ctx, ctx.ast.nodes[n].e1, indent + 1);
    N_EXPR_STMT, N_RETURN, N_THROW, N_LABELED, N_SPREAD, N_UNARY, N_UPDATE,
    N_MEMBER:
      DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
    N_DECLARATOR, N_PATTERN_ELEM:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_PATTERN_PROP:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e3, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_IF:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e3, indent + 1);
      End;
    N_WHILE, N_DO_WHILE:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_FOR:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e3, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e4, indent + 1);
      End;
    N_FOR_IN, N_FOR_OF:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e3, indent + 1);
      End;
    N_SWITCH:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNodeList(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_CASE:
      Begin
        If ctx.ast.nodes[n].e1 = 0 Then
          Begin
            For i := 0 To indent Do
              Write('  ');
            Writeln('default');
          End
        Else
          DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNodeList(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_TRY:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e3, indent + 1);
      End;
    N_CATCH:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_BINARY, N_LOGICAL, N_ASSIGN, N_INDEX, N_TAGGED:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_COND:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e3, indent + 1);
      End;
    N_CALL, N_NEW:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNodeList(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_PROP:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e3, indent + 1);
      End;
    N_FUNC_DECL, N_METHOD, N_FUNC_EXPR:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e3, indent + 1);
        DumpNodeList(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_PARAM:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_CLASS_DECL, N_CLASS_EXPR:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
        DumpNodeList(ctx, ctx.ast.nodes[n].e2, indent + 1);
      End;
    N_FIELD:
      Begin
        DumpNode(ctx, ctx.ast.nodes[n].e3, indent + 1);
        DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
      End;
    N_STATIC_BLOCK:
      DumpNode(ctx, ctx.ast.nodes[n].e1, indent + 1);
  End;
End;

Procedure DumpNodeList(Var ctx: TCompilerContext; n, indent: LongInt);
Begin
  While n <> 0 Do
    Begin
      DumpNode(ctx, n, indent);
      n := ctx.ast.nodes[n].next;
    End;
End;

Procedure DumpAst(Var ctx: TCompilerContext);
Var
  i, sc: LongInt;
Begin
  Writeln('AST :');
  DumpNode(ctx, ctx.ast.root, 1);
  Writeln('Declarations (', ctx.ast.decl_count, ') :');
  For i := 1 To ctx.ast.decl_count Do
    Begin
      sc := ctx.ast.decls[i].scope;
      Write('  ', DeclKindName(ctx.ast.decls[i].kind), ' ',
            ctx.lex.tokens[ctx.ast.decls[i].name_tok].text,
            '  portee ', NodeKindName(ctx.ast.nodes[sc].kind), '@',
            ctx.lex.tokens[ctx.ast.nodes[sc].tok].line);
      If ctx.ast.decls[i].origin <> sc Then
        Write(' (hisse depuis ',
              NodeKindName(ctx.ast.nodes[ctx.ast.decls[i].origin].kind), '@',
              ctx.lex.tokens[ctx.ast.nodes[ctx.ast.decls[i].origin].tok].line,
              ')');
      Writeln;
    End;
End;

{ ============================================================
  TODO 6 - ANALYSE SEMANTIQUE

  Une passe sur l'AST construit les portees (globale, fonction, bloc,
  classe, catch) et la table des symboles, puis resout chaque reference.
  Pour chaque identifiant, le noeud recoit le symbole (sym) et le genre
  de resolution (aux) : local, capture depuis une fonction englobante,
  global predefini, global implicite, arguments.

  Diagnostics : variable non declaree, redeclaration, reaffectation
  d'une const, zone morte temporelle (TDZ) detectee a la compilation,
  super hors d'une methode.

  Informations pour la generation de code : variables capturees par des
  fonctions imbriquees (liste des captures par fonction), symboles qui
  exigent une cellule, une copie par iteration de boucle, un test TDZ a
  l'execution, et la resolution de this (global, fonction, methode,
  constructeur, fleche).
  ============================================================ }

Function SemTokText(Var ctx: TCompilerContext; tok: LongInt): TTokenText;
Begin
  SemTokText := ctx.lex.tokens[tok].text;
End;

Procedure SemError(Var ctx: TCompilerContext; tok: LongInt; msg: TString);
Begin
  SourceErrorAt(ctx, ctx.lex.tokens[tok].line, ctx.lex.tokens[tok].col, msg);
End;

Procedure SemWarn(Var ctx: TCompilerContext; tok: LongInt; msg: TString);
Begin
  SourceWarnAt(ctx, ctx.lex.tokens[tok].line, ctx.lex.tokens[tok].col, msg);
End;

Function IsBuiltinGlobal(Const name: TTokenText): Boolean;
Var
  i: Integer;
Begin
  IsBuiltinGlobal := False;
  For i := 1 To BUILTIN_COUNT Do
    If Builtins[i] = name Then
      IsBuiltinGlobal := True;
End;

Function IsLexicalKind(kind: TDeclKind): Boolean;
Begin
  IsLexicalKind := (kind = DK_LET) Or (kind = DK_CONST) Or (kind = DK_CLASS);
End;

Function LineOfTok(Var ctx: TCompilerContext; tok: LongInt): TString;
Var
  s: String[12];
Begin
  Str(ctx.lex.tokens[tok].line, s);
  LineOfTok := s;
End;

{ ---- Table des symboles ---- }

Procedure CreateSymbol(Var ctx: TCompilerContext; sc, d: LongInt);
Var
  old, sy: LongInt;
  name: TTokenText;
  conflict: Boolean;
Begin
  name := SemTokText(ctx, ctx.ast.decls[d].name_tok);
  old := ctx.sem.scopes[sc].first_sym;
  While old <> 0 Do
    Begin
      If SemTokText(ctx, ctx.sem.syms[old].name_tok) = name Then
        Begin
          conflict := False;
          If (ctx.sem.syms[old].kind <> DK_FNAME) And
             (ctx.ast.decls[d].kind <> DK_FNAME) Then
            Begin
              If IsLexicalKind(ctx.ast.decls[d].kind) Or
                 IsLexicalKind(ctx.sem.syms[old].kind) Then
                conflict := True
              Else If (ctx.ast.decls[d].kind = DK_PARAM) And
                      (ctx.sem.syms[old].kind = DK_PARAM) Then
                SemWarn(ctx, ctx.ast.decls[d].name_tok,
                        'parametre en double: ' + name);
            End;
          If conflict Then
            Begin
              SemError(ctx, ctx.ast.decls[d].name_tok,
                       'redeclaration de "' + name + '" (deja declare ligne ' +
                       LineOfTok(ctx, ctx.sem.syms[old].name_tok) + ')');
              Break;
            End;
          { var, function et parametre redeclares : meme variable }
          If (Not conflict) And (ctx.sem.syms[old].kind <> DK_FNAME) And
             (ctx.ast.decls[d].kind <> DK_FNAME) And
             (ctx.sem.syms[old].kind In [DK_VAR, DK_FUNC, DK_PARAM]) And
             (ctx.ast.decls[d].kind In [DK_VAR, DK_FUNC, DK_PARAM]) Then
            Begin
              If ctx.ast.decls[d].kind = DK_FUNC Then
                Begin
                  ctx.sem.syms[old].kind := DK_FUNC;
                  ctx.sem.syms[old].node := ctx.ast.decls[d].node;
                  ctx.sem.syms[old].flags := ctx.sem.syms[old].flags Or SF_HOISTED;
                End;
              ctx.ast.nodes[ctx.ast.decls[d].node].sym := old;
              Exit;
            End;
        End;
      old := ctx.sem.syms[old].next;
    End;
  If ctx.sem.sym_count >= MAX_SYMS Then
    Begin
      SemError(ctx, ctx.ast.decls[d].name_tok, 'trop de symboles');
      Exit;
    End;
  Inc(ctx.sem.sym_count);
  sy := ctx.sem.sym_count;
  ctx.sem.syms[sy].name_tok := ctx.ast.decls[d].name_tok;
  ctx.sem.syms[sy].kind := ctx.ast.decls[d].kind;
  ctx.sem.syms[sy].scope := sc;
  ctx.sem.syms[sy].node := ctx.ast.decls[d].node;
  ctx.sem.syms[sy].next := 0;
  ctx.sem.syms[sy].flags := 0;
  ctx.sem.syms[sy].refs := 0;
  ctx.sem.syms[sy].writes := 0;
  If (ctx.sem.scopes[sc].func = 1) And Not ctx.sem.scopes[sc].in_loop And
     (ctx.sem.syms[sy].kind <> DK_FNAME) Then
    ctx.sem.syms[sy].flags := ctx.sem.syms[sy].flags Or SF_STATIC;
  If (ctx.sem.syms[sy].kind = DK_VAR) Or (ctx.sem.syms[sy].kind = DK_FUNC) Then
    ctx.sem.syms[sy].flags := ctx.sem.syms[sy].flags Or SF_HOISTED;
  ctx.ast.nodes[ctx.ast.decls[d].node].sym := sy;
  If ctx.sem.scopes[sc].first_sym = 0 Then
    ctx.sem.scopes[sc].first_sym := sy
  Else
    ctx.sem.syms[ctx.sem.scopes[sc].last_sym].next := sy;
  ctx.sem.scopes[sc].last_sym := sy;
End;

Function EnterScope(Var ctx: TCompilerContext; node: LongInt;
                    kind: TScopeKind; fk: TFuncKind): LongInt;
Var
  sc, par, d: LongInt;
Begin
  EnterScope := ctx.sem.cur_scope;
  If ctx.sem.scope_count >= MAX_SCOPES Then
    Begin
      If Not ctx.sem.stop Then
        SemError(ctx, ctx.ast.nodes[node].tok, 'trop de portees');
      ctx.sem.stop := True;
      Exit;
    End;
  Inc(ctx.sem.scope_count);
  sc := ctx.sem.scope_count;
  par := ctx.sem.cur_scope;
  ctx.sem.scopes[sc].node := node;
  ctx.sem.scopes[sc].kind := kind;
  ctx.sem.scopes[sc].fkind := fk;
  ctx.sem.scopes[sc].parent := par;
  If (kind = SK_GLOBAL) Or (kind = SK_FUNCTION) Then
    ctx.sem.scopes[sc].func := sc
  Else
    ctx.sem.scopes[sc].func := ctx.sem.scopes[par].func;
  ctx.sem.scopes[sc].in_loop := (ctx.sem.loop_depth > 0) Or ctx.sem.next_in_loop;
  ctx.sem.next_in_loop := False;
  ctx.sem.scopes[sc].first_sym := 0;
  ctx.sem.scopes[sc].last_sym := 0;
  ctx.sem.scopes[sc].uses_this := False;
  ctx.sem.scopes[sc].this_captured := False;
  ctx.sem.scopes[sc].uses_arguments := False;
  ctx.sem.scopes[sc].has_nested := False;
  ctx.sem.scopes[sc].cap_count := 0;
  ctx.ast.nodes[node].scope := sc;
  If (kind = SK_FUNCTION) And (par <> 0) Then
    ctx.sem.scopes[ctx.sem.scopes[par].func].has_nested := True;
  ctx.sem.cur_scope := sc;
  d := ctx.ast.nodes[node].decl_head;
  While d <> 0 Do
    Begin
      CreateSymbol(ctx, sc, d);
      d := ctx.ast.decls[d].next;
    End;
  EnterScope := sc;
End;

Procedure LeaveScope(Var ctx: TCompilerContext; sc: LongInt);
Begin
  If sc <> 0 Then
    ctx.sem.cur_scope := ctx.sem.scopes[sc].parent;
End;

Function LookupSymbol(Var ctx: TCompilerContext; Const name: TTokenText): LongInt;
Var
  sc, sy: LongInt;
Begin
  sc := ctx.sem.cur_scope;
  While sc <> 0 Do
    Begin
      sy := ctx.sem.scopes[sc].first_sym;
      While sy <> 0 Do
        Begin
          If SemTokText(ctx, ctx.sem.syms[sy].name_tok) = name Then
            Begin
              LookupSymbol := sy;
              Exit;
            End;
          sy := ctx.sem.syms[sy].next;
        End;
      sc := ctx.sem.scopes[sc].parent;
    End;
  LookupSymbol := 0;
End;

{ Cherche name de la portee courante jusqu'a la portee stop incluse. }
Function LookupWithin(Var ctx: TCompilerContext; Const name: TTokenText;
                      stop: LongInt): LongInt;
Var
  sc, sy: LongInt;
Begin
  sc := ctx.sem.cur_scope;
  While sc <> 0 Do
    Begin
      sy := ctx.sem.scopes[sc].first_sym;
      While sy <> 0 Do
        Begin
          If SemTokText(ctx, ctx.sem.syms[sy].name_tok) = name Then
            Begin
              LookupWithin := sy;
              Exit;
            End;
          sy := ctx.sem.syms[sy].next;
        End;
      If sc = stop Then
        Break;
      sc := ctx.sem.scopes[sc].parent;
    End;
  LookupWithin := 0;
End;

{ Symbole implicite arguments de la fonction prov. }
Function CreateArgsSymbol(Var ctx: TCompilerContext; prov, tok: LongInt): LongInt;
Var
  sy: LongInt;
Begin
  CreateArgsSymbol := 0;
  If ctx.sem.sym_count >= MAX_SYMS Then
    Exit;
  Inc(ctx.sem.sym_count);
  sy := ctx.sem.sym_count;
  ctx.sem.syms[sy].name_tok := tok;
  ctx.sem.syms[sy].kind := DK_ARGS;
  ctx.sem.syms[sy].scope := prov;
  ctx.sem.syms[sy].node := 0;
  ctx.sem.syms[sy].next := 0;
  ctx.sem.syms[sy].flags := 0;
  ctx.sem.syms[sy].refs := 0;
  ctx.sem.syms[sy].writes := 0;
  If ctx.sem.scopes[prov].first_sym = 0 Then
    ctx.sem.scopes[prov].first_sym := sy
  Else
    ctx.sem.syms[ctx.sem.scopes[prov].last_sym].next := sy;
  ctx.sem.scopes[prov].last_sym := sy;
  CreateArgsSymbol := sy;
End;

{ ---- Captures ---- }

Procedure AddCapture(Var ctx: TCompilerContext; fscope, sy: LongInt);
Var
  i: LongInt;
Begin
  For i := 1 To ctx.sem.cap_count Do
    If (ctx.sem.caps[i].fscope = fscope) And (ctx.sem.caps[i].sym = sy) Then
      Exit;
  If ctx.sem.cap_count >= MAX_CAPS Then
    Exit;
  Inc(ctx.sem.cap_count);
  ctx.sem.caps[ctx.sem.cap_count].fscope := fscope;
  ctx.sem.caps[ctx.sem.cap_count].sym := sy;
  Inc(ctx.sem.scopes[fscope].cap_count);
End;

{ ---- Resolution d'un identifiant ---- }

Function NearestNonArrow(Var ctx: TCompilerContext): LongInt;
Var
  sc: LongInt;
Begin
  sc := ctx.sem.cur_scope;
  While sc <> 0 Do
    Begin
      If ctx.sem.scopes[sc].kind = SK_GLOBAL Then
        Begin
          NearestNonArrow := sc;
          Exit;
        End;
      If (ctx.sem.scopes[sc].kind = SK_FUNCTION) And
         (ctx.sem.scopes[sc].fkind <> FK_ARROW) Then
        Begin
          NearestNonArrow := sc;
          Exit;
        End;
      sc := ctx.sem.scopes[sc].parent;
    End;
  NearestNonArrow := 1;
End;

Procedure ResolveIdent(Var ctx: TCompilerContext; n: LongInt; mode: Integer);
Var
  tok, sy, rf, sf, f, prov: LongInt;
  name: TTokenText;
  is_write, is_read: Boolean;
Begin
  tok := ctx.ast.nodes[n].tok;
  name := SemTokText(ctx, tok);
  is_write := (mode = RM_WRITE) Or (mode = RM_READWRITE);
  is_read := (mode = RM_READ) Or (mode = RM_READWRITE);
  ctx.ast.nodes[n].sym := 0;
  sy := 0;
  If name = 'arguments' Then
    Begin
      { objet arguments : symbole cache de la fonction englobante non
        fleche, capture comme une variable ordinaire par les fleches }
      prov := NearestNonArrow(ctx);
      If ctx.sem.scopes[prov].kind = SK_FUNCTION Then
        Begin
          sy := LookupWithin(ctx, name, prov);
          If sy = 0 Then
            sy := CreateArgsSymbol(ctx, prov, tok);
          ctx.sem.scopes[prov].uses_arguments := True;
        End;
    End;
  If sy = 0 Then
    sy := LookupSymbol(ctx, name);
  If sy = 0 Then
    Begin
      If IsBuiltinGlobal(name) Then
        ctx.ast.nodes[n].aux := RK_BUILTIN
      Else If is_write And Not is_read Then
        Begin
          { affectation a une variable non declaree : globale implicite }
          SemWarn(ctx, tok, 'affectation a la variable non declaree "' + name +
                  '" : creation d''une globale implicite');
          If ctx.sem.sym_count < MAX_SYMS Then
            Begin
              Inc(ctx.sem.sym_count);
              sy := ctx.sem.sym_count;
              ctx.sem.syms[sy].name_tok := tok;
              ctx.sem.syms[sy].kind := DK_VAR;
              ctx.sem.syms[sy].scope := 1;
              ctx.sem.syms[sy].node := n;
              ctx.sem.syms[sy].next := 0;
              ctx.sem.syms[sy].flags := SF_STATIC Or SF_IMPLICIT Or SF_REASSIGNED;
              ctx.sem.syms[sy].refs := 0;
              ctx.sem.syms[sy].writes := 1;
              If ctx.sem.scopes[1].first_sym = 0 Then
                ctx.sem.scopes[1].first_sym := sy
              Else
                ctx.sem.syms[ctx.sem.scopes[1].last_sym].next := sy;
              ctx.sem.scopes[1].last_sym := sy;
              ctx.ast.nodes[n].sym := sy;
              ctx.ast.nodes[n].aux := RK_GLOBAL_IMPLICIT;
            End;
        End
      Else If ctx.sem.in_typeof Then
        ctx.ast.nodes[n].aux := RK_UNDECLARED_OK
      Else
        Begin
          SemError(ctx, tok, 'variable non declaree: ' + name);
          ctx.ast.nodes[n].aux := RK_UNRESOLVED;
        End;
      Exit;
    End;

  ctx.ast.nodes[n].sym := sy;
  rf := ctx.sem.scopes[ctx.sem.cur_scope].func;
  sf := ctx.sem.scopes[ctx.sem.syms[sy].scope].func;
  If is_read Then
    Inc(ctx.sem.syms[sy].refs);

  If rf = sf Then
    ctx.ast.nodes[n].aux := RK_LOCAL
  Else
    Begin
      ctx.ast.nodes[n].aux := RK_OUTER;
      ctx.sem.syms[sy].flags := ctx.sem.syms[sy].flags Or SF_CAPTURED;
      If ctx.sem.syms[sy].flags And SF_STATIC = 0 Then
        Begin
          ctx.sem.syms[sy].flags := ctx.sem.syms[sy].flags Or SF_CELL;
          f := rf;
          While (f <> sf) And (f <> 0) Do
            Begin
              AddCapture(ctx, f, sy);
              f := ctx.sem.scopes[ctx.sem.scopes[f].parent].func;
            End;
        End;
      If ctx.sem.scopes[ctx.sem.syms[sy].scope].in_loop And
         (ctx.sem.syms[sy].kind <> DK_VAR) Then
        ctx.sem.syms[sy].flags := ctx.sem.syms[sy].flags Or SF_PER_ITER;
    End;

  { zone morte temporelle des declarations lexicales }
  If IsLexicalKind(ctx.sem.syms[sy].kind) Then
    Begin
      If rf = sf Then
        Begin
          If tok < ctx.sem.syms[sy].name_tok Then
            SemError(ctx, tok, '"' + name + '" utilise avant sa declaration ' +
                     '(zone morte temporelle, ligne ' +
                     LineOfTok(ctx, ctx.sem.syms[sy].name_tok) + ')')
          Else If ctx.sem.syms[sy].flags And SF_INITIALIZING <> 0 Then
            SemError(ctx, tok, '"' + name + '" utilise dans son propre ' +
                     'initialiseur (zone morte temporelle)');
        End
      Else
        Begin
          { fonction imbriquee ecrite avant la declaration : test a l'execution }
          f := rf;
          While ctx.sem.scopes[ctx.sem.scopes[f].parent].func <> sf Do
            f := ctx.sem.scopes[ctx.sem.scopes[f].parent].func;
          If ctx.ast.nodes[ctx.sem.scopes[f].node].tok <
             ctx.sem.syms[sy].name_tok Then
            ctx.sem.syms[sy].flags := ctx.sem.syms[sy].flags Or SF_TDZ_CHECK;
        End;
    End;

  If is_write Then
    Begin
      Inc(ctx.sem.syms[sy].writes);
      ctx.sem.syms[sy].flags := ctx.sem.syms[sy].flags Or SF_REASSIGNED;
      If ctx.sem.syms[sy].kind = DK_CONST Then
        SemError(ctx, tok, 'reaffectation de la constante "' + name + '"')
      Else If ctx.sem.syms[sy].kind = DK_FNAME Then
        SemWarn(ctx, tok, 'affectation ignoree au nom de fonction "' + name + '"');
    End;
End;

{ ---- Contexte de this et de super ---- }

Function ThisBindingOf(fk: TFuncKind): Integer;
Begin
  Case fk Of
    FK_GLOBAL:       ThisBindingOf := TB_GLOBAL;
    FK_FUNCTION:     ThisBindingOf := TB_FUNCTION;
    FK_METHOD:       ThisBindingOf := TB_METHOD;
    FK_CTOR:         ThisBindingOf := TB_CTOR;
    FK_DERIVED_CTOR: ThisBindingOf := TB_DERIVED_CTOR;
    FK_FIELD_INIT:   ThisBindingOf := TB_FIELD;
  Else
    ThisBindingOf := TB_STATIC;
  End;
End;

{ Portee qui fournit this : la plus proche non fleche. Les fleches
  traversees utilisent le this lexical. Retourne la portee et dit si au
  moins une fleche a ete traversee. }
Function FindThisProvider(Var ctx: TCompilerContext; Var via_arrow: Boolean): LongInt;
Var
  sc: LongInt;
Begin
  via_arrow := False;
  sc := ctx.sem.cur_scope;
  While sc <> 0 Do
    Begin
      If ctx.sem.scopes[sc].kind = SK_GLOBAL Then
        Break;
      If ctx.sem.scopes[sc].kind = SK_FUNCTION Then
        Begin
          If ctx.sem.scopes[sc].fkind <> FK_ARROW Then
            Break;
          via_arrow := True;
          ctx.sem.scopes[sc].uses_this := True;
        End;
      sc := ctx.sem.scopes[sc].parent;
    End;
  If sc = 0 Then
    sc := 1;
  FindThisProvider := sc;
End;

Procedure ResolveThis(Var ctx: TCompilerContext; n: LongInt);
Var
  prov: LongInt;
  via: Boolean;
Begin
  prov := FindThisProvider(ctx, via);
  ctx.sem.scopes[prov].uses_this := True;
  If via Then
    ctx.sem.scopes[prov].this_captured := True;
  ctx.ast.nodes[n].sym := prov;
  ctx.ast.nodes[n].aux := ThisBindingOf(ctx.sem.scopes[prov].fkind);
  If via Then
    ctx.ast.nodes[n].e1 := 1;
End;

Procedure ResolveSuper(Var ctx: TCompilerContext; n: LongInt; is_call: Boolean);
Var
  prov: LongInt;
  via: Boolean;
  fk: TFuncKind;
Begin
  prov := FindThisProvider(ctx, via);
  fk := ctx.sem.scopes[prov].fkind;
  ctx.ast.nodes[n].sym := prov;
  ctx.sem.scopes[prov].uses_this := True;
  If via Then
    ctx.sem.scopes[prov].this_captured := True;
  If is_call Then
    Begin
      If fk <> FK_DERIVED_CTOR Then
        SemError(ctx, ctx.ast.nodes[n].tok,
                 'super(...) n''est permis que dans le constructeur d''une classe derivee');
    End
  Else If (fk = FK_GLOBAL) Or (fk = FK_FUNCTION) Then
    SemError(ctx, ctx.ast.nodes[n].tok,
             'super en dehors d''une methode ou d''un constructeur');
End;

{ ---- Parcours generique ---- }

Function ChildSpec(kind: TNodeKind): String;
Begin
  Case kind Of
    N_PROGRAM, N_BLOCK, N_VAR_DECL, N_ARRAY_PATTERN, N_OBJECT_PATTERN,
    N_TEMPLATE, N_ARRAY_LIT, N_OBJECT_LIT, N_SEQUENCE:
      ChildSpec := 'l';
    N_EXPR_STMT, N_RETURN, N_THROW, N_LABELED, N_SPREAD, N_UNARY, N_MEMBER:
      ChildSpec := 'n';
    N_IF, N_TRY, N_COND, N_PATTERN_PROP:
      ChildSpec := 'nnn';
    N_CASE, N_CALL, N_NEW:
      ChildSpec := 'nl';
    N_WHILE, N_DO_WHILE, N_PARAM, N_PATTERN_ELEM, N_BINARY, N_LOGICAL,
    N_INDEX, N_TAGGED:
      ChildSpec := 'nn';
  Else
    ChildSpec := '';
  End;
End;

Function NodeField(Var ctx: TCompilerContext; n, slot: LongInt): LongInt;
Begin
  Case slot Of
    1: NodeField := ctx.ast.nodes[n].e1;
    2: NodeField := ctx.ast.nodes[n].e2;
    3: NodeField := ctx.ast.nodes[n].e3;
  Else
    NodeField := ctx.ast.nodes[n].e4;
  End;
End;

Procedure SemNode(Var ctx: TCompilerContext; n: LongInt); Forward;

Procedure SemList(Var ctx: TCompilerContext; n: LongInt);
Begin
  While n <> 0 Do
    Begin
      SemNode(ctx, n);
      n := ctx.ast.nodes[n].next;
    End;
End;

Procedure SemChildren(Var ctx: TCompilerContext; n: LongInt);
Var
  spec: String;
  slot: Integer;
  e: LongInt;
Begin
  spec := ChildSpec(ctx.ast.nodes[n].kind);
  For slot := 1 To Length(spec) Do
    Begin
      e := NodeField(ctx, n, slot);
      If spec[slot] = 'n' Then
        SemNode(ctx, e)
      Else
        SemList(ctx, e);
    End;
End;

{ Cible d'une affectation : ecriture d'un identifiant, ou destructuration. }
Procedure SemTarget(Var ctx: TCompilerContext; n: LongInt);
Var
  el, pr: LongInt;
Begin
  If n = 0 Then
    Exit;
  Case ctx.ast.nodes[n].kind Of
    N_IDENT:
      ResolveIdent(ctx, n, RM_WRITE);
    N_ARRAY_LIT:
      Begin
        el := ctx.ast.nodes[n].e1;
        While el <> 0 Do
          Begin
            If ctx.ast.nodes[el].kind = N_SPREAD Then
              SemTarget(ctx, ctx.ast.nodes[el].e1)
            Else
              SemTarget(ctx, el);
            el := ctx.ast.nodes[el].next;
          End;
      End;
    N_OBJECT_LIT:
      Begin
        pr := ctx.ast.nodes[n].e1;
        While pr <> 0 Do
          Begin
            If ctx.ast.nodes[pr].flags And PR_SPREAD <> 0 Then
              SemTarget(ctx, ctx.ast.nodes[pr].e1)
            Else
              Begin
                SemNode(ctx, ctx.ast.nodes[pr].e2);
                SemTarget(ctx, ctx.ast.nodes[pr].e1);
                SemNode(ctx, ctx.ast.nodes[pr].e3);
              End;
            pr := ctx.ast.nodes[pr].next;
          End;
      End;
    N_ASSIGN:
      Begin
        SemTarget(ctx, ctx.ast.nodes[n].e1);
        SemNode(ctx, ctx.ast.nodes[n].e2);
      End;
  Else
    SemNode(ctx, n);
  End;
End;

{ Marque (ou demarque) les symboles lies par un motif de declaration. }
Procedure SetInitializing(Var ctx: TCompilerContext; n: LongInt; on: Boolean);
Var
  e: LongInt;
Begin
  If n = 0 Then
    Exit;
  Case ctx.ast.nodes[n].kind Of
    N_BIND_IDENT:
      Begin
        e := ctx.ast.nodes[n].sym;
        If e <> 0 Then
          If on Then
            ctx.sem.syms[e].flags := ctx.sem.syms[e].flags Or SF_INITIALIZING
          Else
            ctx.sem.syms[e].flags := ctx.sem.syms[e].flags And Not SF_INITIALIZING;
      End;
    N_ARRAY_PATTERN, N_OBJECT_PATTERN:
      Begin
        e := ctx.ast.nodes[n].e1;
        While e <> 0 Do
          Begin
            SetInitializing(ctx, e, on);
            e := ctx.ast.nodes[e].next;
          End;
      End;
    N_PATTERN_ELEM, N_PATTERN_PROP:
      SetInitializing(ctx, ctx.ast.nodes[n].e1, on);
  End;
End;

Function FuncKindOf(Var ctx: TCompilerContext; n: LongInt): TFuncKind;
Var
  f: LongInt;
Begin
  f := ctx.ast.nodes[n].flags;
  Case ctx.ast.nodes[n].kind Of
    N_FUNC_DECL:
      FuncKindOf := FK_FUNCTION;
    N_FUNC_EXPR:
      Begin
        If f And FN_ARROW <> 0 Then
          FuncKindOf := FK_ARROW
        Else If f And FN_METHOD <> 0 Then
          FuncKindOf := FK_METHOD
        Else
          FuncKindOf := FK_FUNCTION;
      End;
    N_METHOD:
      Begin
        If f And MF_STATIC <> 0 Then
          FuncKindOf := FK_STATIC_METHOD
        Else If f And MF_CONSTRUCTOR <> 0 Then
          Begin
            If (ctx.sem.cur_class <> 0) And
               (ctx.ast.nodes[ctx.sem.cur_class].e1 <> 0) Then
              FuncKindOf := FK_DERIVED_CTOR
            Else
              FuncKindOf := FK_CTOR;
          End
        Else
          FuncKindOf := FK_METHOD;
      End;
  Else
    FuncKindOf := FK_FUNCTION;
  End;
End;

Procedure SemFunction(Var ctx: TCompilerContext; n: LongInt);
Var
  sc, save_loop: LongInt;
Begin
  save_loop := ctx.sem.loop_depth;
  ctx.sem.loop_depth := 0;
  sc := EnterScope(ctx, n, SK_FUNCTION, FuncKindOf(ctx, n));
  SemList(ctx, ctx.ast.nodes[n].e1);
  SemNode(ctx, ctx.ast.nodes[n].e2);
  LeaveScope(ctx, sc);
  ctx.sem.loop_depth := save_loop;
End;

Procedure SemClass(Var ctx: TCompilerContext; n: LongInt);
Var
  sc, save_class, m, sc2, save_loop: LongInt;
Begin
  save_class := ctx.sem.cur_class;
  sc := EnterScope(ctx, n, SK_CLASS, FK_NONE);
  ctx.sem.cur_class := n;
  SemNode(ctx, ctx.ast.nodes[n].e1);
  m := ctx.ast.nodes[n].e2;
  While m <> 0 Do
    Begin
      Case ctx.ast.nodes[m].kind Of
        N_METHOD:
          Begin
            SemNode(ctx, ctx.ast.nodes[m].e3);
            SemFunction(ctx, m);
          End;
        N_FIELD:
          Begin
            SemNode(ctx, ctx.ast.nodes[m].e3);
            If ctx.ast.nodes[m].e1 <> 0 Then
              Begin
                save_loop := ctx.sem.loop_depth;
                ctx.sem.loop_depth := 0;
                If ctx.ast.nodes[m].flags And MF_STATIC <> 0 Then
                  sc2 := EnterScope(ctx, m, SK_FUNCTION, FK_STATIC_FIELD_INIT)
                Else
                  sc2 := EnterScope(ctx, m, SK_FUNCTION, FK_FIELD_INIT);
                SemNode(ctx, ctx.ast.nodes[m].e1);
                LeaveScope(ctx, sc2);
                ctx.sem.loop_depth := save_loop;
              End;
          End;
        N_STATIC_BLOCK:
          Begin
            save_loop := ctx.sem.loop_depth;
            ctx.sem.loop_depth := 0;
            sc2 := EnterScope(ctx, m, SK_FUNCTION, FK_STATIC_BLOCK);
            SemNode(ctx, ctx.ast.nodes[m].e1);
            LeaveScope(ctx, sc2);
            ctx.sem.loop_depth := save_loop;
          End;
      End;
      m := ctx.ast.nodes[m].next;
    End;
  LeaveScope(ctx, sc);
  ctx.sem.cur_class := save_class;
End;

Procedure SemNode(Var ctx: TCompilerContext; n: LongInt);
Var
  sc, e, decl_target: LongInt;
  s: TTokenText;
  was_typeof: Boolean;
Begin
  If (n = 0) Or ctx.sem.stop Then
    Exit;
  Case ctx.ast.nodes[n].kind Of
    N_BLOCK:
      Begin
        If ctx.ast.nodes[n].flags = 1 Then
          SemList(ctx, ctx.ast.nodes[n].e1)
        Else
          Begin
            sc := EnterScope(ctx, n, SK_BLOCK, FK_NONE);
            SemList(ctx, ctx.ast.nodes[n].e1);
            LeaveScope(ctx, sc);
          End;
      End;
    N_DECLARATOR:
      Begin
        decl_target := ctx.ast.nodes[n].e1;
        SetInitializing(ctx, decl_target, ctx.ast.nodes[n].e2 <> 0);
        SemNode(ctx, decl_target);
        SemNode(ctx, ctx.ast.nodes[n].e2);
        SetInitializing(ctx, decl_target, False);
      End;
    N_FOR, N_FOR_IN, N_FOR_OF:
      Begin
        ctx.sem.next_in_loop := True;
        sc := EnterScope(ctx, n, SK_BLOCK, FK_NONE);
        If ctx.ast.nodes[n].kind = N_FOR Then
          Begin
            SemNode(ctx, ctx.ast.nodes[n].e1);
            SemNode(ctx, ctx.ast.nodes[n].e2);
            SemNode(ctx, ctx.ast.nodes[n].e3);
            Inc(ctx.sem.loop_depth);
            SemNode(ctx, ctx.ast.nodes[n].e4);
            Dec(ctx.sem.loop_depth);
          End
        Else
          Begin
            SemNode(ctx, ctx.ast.nodes[n].e2);
            e := ctx.ast.nodes[n].e1;
            If (e <> 0) And (ctx.ast.nodes[e].kind = N_VAR_DECL) Then
              SemNode(ctx, e)
            Else
              SemTarget(ctx, e);
            Inc(ctx.sem.loop_depth);
            SemNode(ctx, ctx.ast.nodes[n].e3);
            Dec(ctx.sem.loop_depth);
          End;
        LeaveScope(ctx, sc);
      End;
    N_WHILE:
      Begin
        SemNode(ctx, ctx.ast.nodes[n].e1);
        Inc(ctx.sem.loop_depth);
        SemNode(ctx, ctx.ast.nodes[n].e2);
        Dec(ctx.sem.loop_depth);
      End;
    N_DO_WHILE:
      Begin
        Inc(ctx.sem.loop_depth);
        SemNode(ctx, ctx.ast.nodes[n].e1);
        Dec(ctx.sem.loop_depth);
        SemNode(ctx, ctx.ast.nodes[n].e2);
      End;
    N_SWITCH:
      Begin
        SemNode(ctx, ctx.ast.nodes[n].e1);
        sc := EnterScope(ctx, n, SK_BLOCK, FK_NONE);
        SemList(ctx, ctx.ast.nodes[n].e2);
        LeaveScope(ctx, sc);
      End;
    N_CATCH:
      Begin
        sc := EnterScope(ctx, n, SK_CATCH, FK_NONE);
        SemNode(ctx, ctx.ast.nodes[n].e1);
        e := ctx.ast.nodes[n].e2;
        If e <> 0 Then
          SemList(ctx, ctx.ast.nodes[e].e1);
        LeaveScope(ctx, sc);
      End;
    N_FUNC_DECL, N_FUNC_EXPR, N_METHOD:
      SemFunction(ctx, n);
    N_CLASS_DECL, N_CLASS_EXPR:
      SemClass(ctx, n);
    N_IDENT:
      ResolveIdent(ctx, n, RM_READ);
    N_THIS:
      ResolveThis(ctx, n);
    N_SUPER:
      ResolveSuper(ctx, n, False);
    N_ASSIGN:
      Begin
        s := SemTokText(ctx, ctx.ast.nodes[n].tok);
        e := ctx.ast.nodes[n].e1;
        If s = '=' Then
          SemTarget(ctx, e)
        Else If (e <> 0) And (ctx.ast.nodes[e].kind = N_IDENT) Then
          ResolveIdent(ctx, e, RM_READWRITE)
        Else
          SemNode(ctx, e);
        SemNode(ctx, ctx.ast.nodes[n].e2);
      End;
    N_UPDATE:
      Begin
        e := ctx.ast.nodes[n].e1;
        If (e <> 0) And (ctx.ast.nodes[e].kind = N_IDENT) Then
          ResolveIdent(ctx, e, RM_READWRITE)
        Else
          SemNode(ctx, e);
      End;
    N_UNARY:
      Begin
        e := ctx.ast.nodes[n].e1;
        was_typeof := ctx.sem.in_typeof;
        If (SemTokText(ctx, ctx.ast.nodes[n].tok) = 'typeof') And (e <> 0) And
           (ctx.ast.nodes[e].kind = N_IDENT) Then
          ctx.sem.in_typeof := True;
        SemNode(ctx, e);
        ctx.sem.in_typeof := was_typeof;
      End;
    N_CALL:
      Begin
        e := ctx.ast.nodes[n].e1;
        If (e <> 0) And (ctx.ast.nodes[e].kind = N_SUPER) Then
          ResolveSuper(ctx, e, True)
        Else
          SemNode(ctx, e);
        SemList(ctx, ctx.ast.nodes[n].e2);
      End;
    N_PROP:
      Begin
        If ctx.ast.nodes[n].flags And PR_SPREAD <> 0 Then
          SemNode(ctx, ctx.ast.nodes[n].e1)
        Else
          Begin
            SemNode(ctx, ctx.ast.nodes[n].e2);
            SemNode(ctx, ctx.ast.nodes[n].e1);
            SemNode(ctx, ctx.ast.nodes[n].e3);
          End;
      End;
  Else
    SemChildren(ctx, n);
  End;
End;

{ var declare dans un bloc imbrique : ne doit pas croiser un let/const/class
  du meme nom dans les portees traversees. }
Procedure CheckVarHoisting(Var ctx: TCompilerContext);
Var
  i, sc, target, sy: LongInt;
  name: TTokenText;
Begin
  For i := 1 To ctx.ast.decl_count Do
    If (ctx.ast.decls[i].kind = DK_VAR) And
       (ctx.ast.decls[i].origin <> ctx.ast.decls[i].scope) Then
      Begin
        name := SemTokText(ctx, ctx.ast.decls[i].name_tok);
        target := ctx.ast.nodes[ctx.ast.decls[i].scope].scope;
        sc := ctx.ast.nodes[ctx.ast.decls[i].origin].scope;
        While (sc <> 0) And (sc <> target) Do
          Begin
            sy := ctx.sem.scopes[sc].first_sym;
            While sy <> 0 Do
              Begin
                If IsLexicalKind(ctx.sem.syms[sy].kind) And
                   (SemTokText(ctx, ctx.sem.syms[sy].name_tok) = name) Then
                  SemError(ctx, ctx.ast.decls[i].name_tok,
                           'redeclaration de "' + name +
                           '" (let/const/class ligne ' +
                           LineOfTok(ctx, ctx.sem.syms[sy].name_tok) +
                           ' dans une portee englobante)');
                sy := ctx.sem.syms[sy].next;
              End;
            sc := ctx.sem.scopes[sc].parent;
          End;
      End;
End;

Function AnalyzeProgram(Var ctx: TCompilerContext): Boolean;
Var
  i, sc: LongInt;
Begin
  AnalyzeProgram := False;
  If ctx.ast.root = 0 Then
    Begin
      PipelineError(ctx, 'AST absent avant l''analyse semantique');
      Exit;
    End;
  ctx.sem.scope_count := 0;
  ctx.sem.sym_count := 0;
  ctx.sem.cap_count := 0;
  ctx.sem.cur_scope := 0;
  ctx.sem.loop_depth := 0;
  ctx.sem.cur_class := 0;
  ctx.sem.in_typeof := False;
  ctx.sem.stop := False;
  ctx.sem.next_in_loop := False;
  { liste des declarations de chaque portee, dans l'ordre du source }
  For i := 1 To ctx.ast.node_count Do
    Begin
      ctx.ast.nodes[i].decl_head := 0;
      ctx.ast.nodes[i].scope := 0;
      ctx.ast.nodes[i].sym := 0;
      ctx.ast.nodes[i].aux := 0;
    End;
  For i := ctx.ast.decl_count Downto 1 Do
    Begin
      ctx.ast.decls[i].next := ctx.ast.nodes[ctx.ast.decls[i].scope].decl_head;
      ctx.ast.nodes[ctx.ast.decls[i].scope].decl_head := i;
    End;
  sc := EnterScope(ctx, ctx.ast.root, SK_GLOBAL, FK_GLOBAL);
  SemList(ctx, ctx.ast.nodes[ctx.ast.root].e1);
  CheckVarHoisting(ctx);
  ctx.ast.analyzed := True;
  If ctx.options.verbose Then
    Writeln('Semant.: ', ctx.sem.scope_count, ' portees, ', ctx.sem.sym_count,
            ' symboles, ', ctx.sem.cap_count, ' captures');
  AnalyzeProgram := ctx.errors = 0;
End;

{ ---- Affichage des portees et des symboles (option -scopes) ---- }

Function ScopeKindName(kind: TScopeKind): TString;
Begin
  Case kind Of
    SK_GLOBAL:   ScopeKindName := 'globale';
    SK_FUNCTION: ScopeKindName := 'fonction';
    SK_BLOCK:    ScopeKindName := 'bloc';
    SK_CLASS:    ScopeKindName := 'classe';
    SK_CATCH:    ScopeKindName := 'catch';
  Else
    ScopeKindName := '?';
  End;
End;

Function FuncKindName(fk: TFuncKind): TString;
Begin
  Case fk Of
    FK_GLOBAL:            FuncKindName := 'global';
    FK_FUNCTION:          FuncKindName := 'fonction';
    FK_ARROW:             FuncKindName := 'fleche';
    FK_METHOD:            FuncKindName := 'methode';
    FK_CTOR:              FuncKindName := 'constructeur';
    FK_DERIVED_CTOR:      FuncKindName := 'constructeur-derive';
    FK_STATIC_METHOD:     FuncKindName := 'methode-statique';
    FK_STATIC_BLOCK:      FuncKindName := 'bloc-statique';
    FK_FIELD_INIT:        FuncKindName := 'champ';
    FK_STATIC_FIELD_INIT: FuncKindName := 'champ-statique';
  Else
    FuncKindName := '';
  End;
End;

Function ThisBindingName(b: LongInt): TString;
Begin
  Case b Of
    TB_GLOBAL:       ThisBindingName := 'global';
    TB_FUNCTION:     ThisBindingName := 'fonction';
    TB_METHOD:       ThisBindingName := 'methode';
    TB_CTOR:         ThisBindingName := 'constructeur';
    TB_DERIVED_CTOR: ThisBindingName := 'constructeur-derive';
    TB_STATIC:       ThisBindingName := 'classe';
    TB_FIELD:        ThisBindingName := 'instance-champ';
  Else
    ThisBindingName := '?';
  End;
End;

Procedure DumpScopes(Var ctx: TCompilerContext);
Var
  i, sy, k: LongInt;
  fl: LongInt;
Begin
  Writeln('Portees (', ctx.sem.scope_count, ') :');
  For i := 1 To ctx.sem.scope_count Do
    Begin
      If ctx.sem.scopes[i].kind = SK_FUNCTION Then
        Write('  #', i, ' ', FuncKindName(ctx.sem.scopes[i].fkind))
      Else
        Write('  #', i, ' ', ScopeKindName(ctx.sem.scopes[i].kind));
      Write(' (', NodeKindName(ctx.ast.nodes[ctx.sem.scopes[i].node].kind), '@',
            ctx.lex.tokens[ctx.ast.nodes[ctx.sem.scopes[i].node].tok].line, ')');
      If ctx.ir.built And (ctx.sem.scopes[i].frame_size > 0) Then
        Write(' trame=', ctx.sem.scopes[i].frame_size);
      If ctx.sem.scopes[i].parent <> 0 Then
        Write(' parent=#', ctx.sem.scopes[i].parent);
      If ctx.sem.scopes[i].in_loop Then
        Write(' boucle');
      If ctx.sem.scopes[i].uses_this Then
        Write(' this');
      If ctx.sem.scopes[i].this_captured Then
        Write(' this-capture');
      If ctx.sem.scopes[i].uses_arguments Then
        Write(' arguments');
      Writeln;
      sy := ctx.sem.scopes[i].first_sym;
      While sy <> 0 Do
        Begin
          fl := ctx.sem.syms[sy].flags;
          Write('      ', DeclKindName(ctx.sem.syms[sy].kind), ' ',
                SemTokText(ctx, ctx.sem.syms[sy].name_tok), ' (#', sy, ')');
          If ctx.ir.built And (ctx.sem.syms[sy].slot > 0) Then
            Write(' [ebp-', 8 * ctx.sem.syms[sy].slot, ']');
          If fl And SF_HOISTED <> 0 Then
            Write(' hisse');
          If fl And SF_STATIC <> 0 Then
            Write(' statique');
          If fl And SF_CAPTURED <> 0 Then
            Write(' capture');
          If fl And SF_CELL <> 0 Then
            Write(' cellule');
          If fl And SF_PER_ITER <> 0 Then
            Write(' par-iteration');
          If fl And SF_TDZ_CHECK <> 0 Then
            Write(' test-tdz');
          If fl And SF_REASSIGNED <> 0 Then
            Write(' reaffecte');
          If fl And SF_IMPLICIT <> 0 Then
            Write(' implicite');
          Writeln;
          sy := ctx.sem.syms[sy].next;
        End;
    End;
  Writeln('Captures (', ctx.sem.cap_count, ') :');
  For k := 1 To ctx.sem.cap_count Do
    Writeln('  portee #', ctx.sem.caps[k].fscope, ' capture ',
            SemTokText(ctx, ctx.sem.syms[ctx.sem.caps[k].sym].name_tok),
            ' (#', ctx.sem.caps[k].sym, ')');
End;


Procedure WriteAnnotation(Var ctx: TCompilerContext; n: LongInt);
Begin
  Case ctx.ast.nodes[n].kind Of
    N_IDENT:
      Begin
        Write(' ->');
        Case ctx.ast.nodes[n].aux Of
          RK_LOCAL:           Write(' local #', ctx.ast.nodes[n].sym);
          RK_OUTER:           Write(' capture #', ctx.ast.nodes[n].sym);
          RK_BUILTIN:         Write(' predefini');
          RK_GLOBAL_IMPLICIT: Write(' globale-implicite #', ctx.ast.nodes[n].sym);
          RK_ARGUMENTS:       Write(' arguments');
          RK_UNDECLARED_OK:   Write(' non-declare (typeof)');
        Else
          Write(' non-resolu');
        End;
      End;
    N_THIS:
      Begin
        Write(' -> this ', ThisBindingName(ctx.ast.nodes[n].aux));
        If ctx.ast.nodes[n].e1 = 1 Then
          Write(' lexical (portee #', ctx.ast.nodes[n].sym, ')');
      End;
    N_BIND_IDENT, N_FUNC_DECL, N_CLASS_DECL:
      If ctx.ast.nodes[n].sym <> 0 Then
        Write(' #', ctx.ast.nodes[n].sym);
  End;
End;

{ ============================================================
  TODO 7 - MODELE DE VALEURS RUNTIME ET GESTIONNAIRE MEMOIRE

  Valeur JavaScript : 8 octets (deux DWORD), passee et rangee telle
  quelle dans les variables, les tableaux, les proprietes et les
  cellules. Le DWORD bas (lo) est la charge utile, le DWORD haut (hi)
  est l'etiquette.

    hi <  FFF90000h  nombre IEEE 754 double (lo:hi = les 8 octets du
                     double, lisible directement par fld qword)
    hi >= FFF90000h  valeur etiquetee : hi = FFF90000h + type

  Types : 0 int32, 1 undefined, 2 null, 3 boolean, 4 string, 5 object,
  6 array, 7 function, 8 regexp, 9 marque TDZ et 10 fin d'iteration
  (internes). Un nombre est donc soit un double,
  soit un int32 (chemin rapide entier : add/sub/imul avec test de
  depassement, repli sur le FPU). Les deux formes sont equivalentes ;
  les operations acceptent les deux et la forme canonique n'est pas
  imposee. Un int32 ne represente pas -0 : toute operation qui peut
  produire -0 passe par le double. Le NaN materiel (FFF80000h:0) est un
  double valide.

  Tas : une arene de 1 Mo obtenue par VirtualAlloc, allocation par
  pointeur (alignement 8, memoire mise a zero). Strategie retenue :
  AUCUNE LIBERATION. Un programme compile est de courte duree et le
  systeme rend toute la memoire a la sortie du processus. L'en-tete de
  chaque cellule reserve deja l'octet de marque et le chainage
  gc_next, de sorte qu'un mark & sweep pourra etre ajoute sans changer
  les dispositions. Les blocs de 256 Ko et plus sont alloues
  directement par VirtualAlloc. Les tableaux et tables de proprietes
  grandissent par doublement pour borner le gaspillage a 2 fois la
  taille finale. Memoire epuisee : message sur stderr et ExitProcess(3).
  ============================================================ }

{ ---- Outils de description du modele ---- }

Function RtHex4(v: LongInt): TString;
Const
  H = '0123456789ABCDEF';
Begin
  RtHex4 := H[((v Shr 12) And 15) + 1] + H[((v Shr 8) And 15) + 1] +
            H[((v Shr 4) And 15) + 1] + H[(v And 15) + 1];
End;

{ Etiquette complete (hi) d'un type, en hexadecimal assembleur. }
Function RtTagHex(t: LongInt): TString;
Begin
  RtTagHex := RT_TAG_PREFIX + RtHex4(t) + 'h';
End;

Function RtTagName(t: LongInt): TString;
Begin
  Case t Of
    RT_T_INT32:     RtTagName := 'int32';
    RT_T_UNDEFINED: RtTagName := 'undefined';
    RT_T_NULL:      RtTagName := 'null';
    RT_T_BOOLEAN:   RtTagName := 'boolean';
    RT_T_STRING:    RtTagName := 'string';
    RT_T_OBJECT:    RtTagName := 'object';
    RT_T_ARRAY:     RtTagName := 'array';
    RT_T_FUNCTION:  RtTagName := 'function';
    RT_T_REGEXP:    RtTagName := 'regexp';
    RT_T_TDZ:       RtTagName := 'tdz (interne)';
    RT_T_DONE:      RtTagName := 'fin d''iteration (interne)';
  Else
    RtTagName := '?';
  End;
End;

Function RtComponentName(bit: LongInt): TString;
Begin
  Case bit Of
    RC_HEAP:           RtComponentName := 'tas';
    RC_FPU:            RtComponentName := 'fpu';
    RC_STRING:         RtComponentName := 'chaines';
    RC_NUMTOSTR:       RtComponentName := 'nombre->chaine';
    RC_ARRAY:          RtComponentName := 'tableaux';
    RC_OBJECT:         RtComponentName := 'objets';
    RC_FUNCTION:       RtComponentName := 'fonctions';
    RC_CELL:           RtComponentName := 'cellules';
    RC_CLASS:          RtComponentName := 'classes';
    RC_EXCEPTION:      RtComponentName := 'exceptions';
    RC_REGEXP:         RtComponentName := 'regexp';
    RC_CONSOLE:        RtComponentName := 'console';
    RC_PROCESS:        RtComponentName := 'process';
    RC_MATH:           RtComponentName := 'math';
    RC_JSON:           RtComponentName := 'json';
    RC_STRING_METHODS: RtComponentName := 'methodes-string';
    RC_ARRAY_METHODS:  RtComponentName := 'methodes-tableau';
    RC_OBJECT_STATICS: RtComponentName := 'statiques-object';
    RC_NUMBER_FUNCS:   RtComponentName := 'fonctions-nombre';
    RC_CONVERT:        RtComponentName := 'conversions';
    RC_STDIN:          RtComponentName := 'stdin';
    RC_TYPEOF:         RtComponentName := 'typeof';
    RC_INSTANCEOF:     RtComponentName := 'instanceof/in';
    RC_ARGUMENTS:      RtComponentName := 'arguments';
  Else
    RtComponentName := '?';
  End;
End;

{ Composants du runtime qu'impose l'usage d'une propriete par son nom. }
Function MemberComponents(Const name: TTokenText): LongInt;
Begin
  MemberComponents := 0;
  If (name = 'charAt') Or (name = 'charCodeAt') Or (name = 'toUpperCase') Or
     (name = 'toLowerCase') Or (name = 'trim') Or (name = 'padStart') Or
     (name = 'padEnd') Or (name = 'repeat') Or (name = 'startsWith') Or
     (name = 'endsWith') Or (name = 'substring') Or (name = 'split') Or
     (name = 'replace') Or (name = 'match') Or (name = 'search') Or
     (name = 'lastIndexOf') Or (name = 'fromCharCode') Then
    MemberComponents := RC_STRING Or RC_STRING_METHODS
  Else If (name = 'push') Or (name = 'pop') Or (name = 'shift') Or
          (name = 'unshift') Or (name = 'reverse') Or (name = 'sort') Or
          (name = 'forEach') Or (name = 'map') Or (name = 'filter') Or
          (name = 'reduce') Or (name = 'join') Or (name = 'concat') Or
          (name = 'splice') Or (name = 'isArray') Then
    MemberComponents := RC_ARRAY Or RC_ARRAY_METHODS Or RC_FUNCTION
  Else If (name = 'indexOf') Or (name = 'includes') Or (name = 'slice') Or
          (name = 'length') Then
    MemberComponents := RC_STRING Or RC_ARRAY
  Else If (name = 'keys') Or (name = 'values') Or (name = 'entries') Or
          (name = 'assign') Or (name = 'create') Or (name = 'freeze') Or
          (name = 'getPrototypeOf') Or (name = 'hasOwnProperty') Then
    MemberComponents := RC_OBJECT Or RC_OBJECT_STATICS Or RC_ARRAY
  Else If (name = 'isInteger') Or (name = 'toFixed') Or (name = 'toString') Then
    MemberComponents := RC_NUMBER_FUNCS Or RC_NUMTOSTR Or RC_STRING
  Else If (name = 'stringify') Or (name = 'parse') Then
    MemberComponents := RC_JSON Or RC_STRING Or RC_OBJECT
  Else If (name = 'test') Or (name = 'exec') Then
    MemberComponents := RC_REGEXP Or RC_STRING
  Else If (name = 'write') Or (name = 'exit') Then
    MemberComponents := RC_PROCESS;
End;

{ Composants imposes par un global predefini. }
Function BuiltinComponents(Const name: TTokenText): LongInt;
Begin
  BuiltinComponents := 0;
  If name = 'console' Then
    BuiltinComponents := RC_CONSOLE Or RC_CONVERT Or RC_NUMTOSTR Or RC_STRING
  Else If (name = 'alert') Then
    BuiltinComponents := RC_CONSOLE Or RC_CONVERT Or RC_NUMTOSTR Or RC_STRING
  Else If name = 'prompt' Then
    BuiltinComponents := RC_STDIN Or RC_STRING
  Else If name = 'process' Then
    BuiltinComponents := RC_PROCESS
  Else If name = 'Math' Then
    BuiltinComponents := RC_MATH Or RC_FPU
  Else If name = 'JSON' Then
    BuiltinComponents := RC_JSON Or RC_STRING Or RC_OBJECT
  Else If name = 'Object' Then
    BuiltinComponents := RC_OBJECT Or RC_OBJECT_STATICS
  Else If name = 'Array' Then
    BuiltinComponents := RC_ARRAY
  Else If (name = 'String') Or (name = 'Number') Or (name = 'Boolean') Or
          (name = 'parseInt') Or (name = 'parseFloat') Or (name = 'isNaN') Or
          (name = 'isFinite') Then
    BuiltinComponents := RC_NUMBER_FUNCS Or RC_CONVERT Or RC_STRING
  Else If name = 'RegExp' Then
    BuiltinComponents := RC_REGEXP Or RC_STRING
  Else If (name = 'Error') Or (name = 'TypeError') Or (name = 'RangeError') Or
          (name = 'SyntaxError') Or (name = 'ReferenceError') Or
          (name = 'EvalError') Or (name = 'URIError') Then
    BuiltinComponents := RC_EXCEPTION Or RC_OBJECT Or RC_STRING
  Else If (name = 'NaN') Or (name = 'Infinity') Then
    BuiltinComponents := RC_FPU;
End;

{ ---- Construction du modele a partir du programme ---- }

{ Un litteral entier qui tient dans un int32 reste en TAG_INT32. }
Function FitsInt32(v: Double): Boolean;
Begin
  FitsInt32 := (v >= -2147483648.0) And (v <= 2147483647.0) And (Int(v) = v);
End;

Function BuildRuntimeModel(Var ctx: TCompilerContext): Boolean;
Var
  i, e, sy: LongInt;
  name: TTokenText;
  s: TTokenText;
Begin
  BuildRuntimeModel := False;
  If Not ctx.ast.analyzed Then
    Begin
      PipelineError(ctx, 'analyse semantique absente avant le modele runtime');
      Exit;
    End;
  ctx.rt.comps := RC_HEAP;
  ctx.rt.int_literals := 0;
  ctx.rt.double_literals := 0;
  ctx.rt.string_literals := 0;
  ctx.rt.template_literals := 0;
  ctx.rt.regex_literals := 0;
  ctx.rt.array_literals := 0;
  ctx.rt.object_literals := 0;
  ctx.rt.functions := 0;
  ctx.rt.closures := 0;
  ctx.rt.classes := 0;
  ctx.rt.cells := 0;
  ctx.rt.try_blocks := 0;
  ctx.rt.throws := 0;
  ctx.rt.calls := 0;
  ctx.rt.news := 0;

  For i := 1 To ctx.ast.node_count Do
    Case ctx.ast.nodes[i].kind Of
      N_NUMBER:
        Begin
          If FitsInt32(ctx.lex.tokens[ctx.ast.nodes[i].tok].num_val) Then
            Inc(ctx.rt.int_literals)
          Else
            Begin
              Inc(ctx.rt.double_literals);
              ctx.rt.comps := ctx.rt.comps Or RC_FPU;
            End;
        End;
      N_STRING:
        Begin
          Inc(ctx.rt.string_literals);
          ctx.rt.comps := ctx.rt.comps Or RC_STRING;
        End;
      N_TEMPLATE:
        Begin
          Inc(ctx.rt.template_literals);
          ctx.rt.comps := ctx.rt.comps Or RC_STRING Or RC_NUMTOSTR Or RC_CONVERT;
        End;
      N_TAGGED:
        ctx.rt.comps := ctx.rt.comps Or RC_FUNCTION Or RC_ARRAY Or RC_STRING;
      N_REGEX:
        Begin
          Inc(ctx.rt.regex_literals);
          ctx.rt.comps := ctx.rt.comps Or RC_REGEXP Or RC_STRING;
        End;
      N_ARRAY_LIT:
        Begin
          Inc(ctx.rt.array_literals);
          ctx.rt.comps := ctx.rt.comps Or RC_ARRAY;
        End;
      N_OBJECT_LIT:
        Begin
          Inc(ctx.rt.object_literals);
          ctx.rt.comps := ctx.rt.comps Or RC_OBJECT;
        End;
      N_FUNC_DECL, N_FUNC_EXPR, N_METHOD:
        Begin
          Inc(ctx.rt.functions);
          ctx.rt.comps := ctx.rt.comps Or RC_FUNCTION;
          If ctx.sem.scopes[ctx.ast.nodes[i].scope].cap_count > 0 Then
            Inc(ctx.rt.closures);
        End;
      N_CLASS_DECL, N_CLASS_EXPR:
        Begin
          Inc(ctx.rt.classes);
          ctx.rt.comps := ctx.rt.comps Or RC_CLASS Or RC_OBJECT Or RC_FUNCTION;
        End;
      N_TRY:
        Begin
          Inc(ctx.rt.try_blocks);
          ctx.rt.comps := ctx.rt.comps Or RC_EXCEPTION;
        End;
      N_THROW:
        Begin
          Inc(ctx.rt.throws);
          ctx.rt.comps := ctx.rt.comps Or RC_EXCEPTION;
        End;
      N_CALL:
        Inc(ctx.rt.calls);
      N_NEW:
        Begin
          Inc(ctx.rt.news);
          ctx.rt.comps := ctx.rt.comps Or RC_OBJECT Or RC_FUNCTION;
        End;
      N_MEMBER:
        ctx.rt.comps := ctx.rt.comps Or RC_OBJECT Or
          MemberComponents(ctx.lex.tokens[ctx.ast.nodes[i].tok].text);
      N_INDEX:
        ctx.rt.comps := ctx.rt.comps Or RC_OBJECT Or RC_ARRAY Or RC_STRING;
      N_PROP:
        ctx.rt.comps := ctx.rt.comps Or RC_OBJECT;
      N_UNARY:
        Begin
          s := ctx.lex.tokens[ctx.ast.nodes[i].tok].text;
          If s = 'typeof' Then
            ctx.rt.comps := ctx.rt.comps Or RC_TYPEOF Or RC_STRING
          Else If s = 'delete' Then
            ctx.rt.comps := ctx.rt.comps Or RC_OBJECT;
          { -0 : litteral zero precede d'un moins }
          e := ctx.ast.nodes[i].e1;
          If (s = '-') And (e <> 0) And (ctx.ast.nodes[e].kind = N_NUMBER) And
             (ctx.lex.tokens[ctx.ast.nodes[e].tok].num_val = 0) Then
            ctx.rt.comps := ctx.rt.comps Or RC_FPU;
        End;
      N_BINARY:
        Begin
          s := ctx.lex.tokens[ctx.ast.nodes[i].tok].text;
          If s = '+' Then
            ctx.rt.comps := ctx.rt.comps Or RC_STRING Or RC_CONVERT
          Else If (s = '/') Or (s = '**') Or (s = '%') Then
            ctx.rt.comps := ctx.rt.comps Or RC_FPU
          Else If (s = 'instanceof') Or (s = 'in') Then
            ctx.rt.comps := ctx.rt.comps Or RC_INSTANCEOF Or RC_OBJECT
          Else If (s = '==') Or (s = '!=') Or (s = '<') Or (s = '>') Or
                  (s = '<=') Or (s = '>=') Then
            ctx.rt.comps := ctx.rt.comps Or RC_CONVERT;
        End;
      N_ASSIGN:
        Begin
          s := ctx.lex.tokens[ctx.ast.nodes[i].tok].text;
          If s = '+=' Then
            ctx.rt.comps := ctx.rt.comps Or RC_STRING Or RC_CONVERT
          Else If (s = '/=') Or (s = '**=') Or (s = '%=') Then
            ctx.rt.comps := ctx.rt.comps Or RC_FPU;
        End;
      N_IDENT:
        Begin
          If ctx.ast.nodes[i].aux = RK_BUILTIN Then
            ctx.rt.comps := ctx.rt.comps Or
              BuiltinComponents(ctx.lex.tokens[ctx.ast.nodes[i].tok].text)
          Else If (ctx.ast.nodes[i].sym <> 0) And
                  (ctx.sem.syms[ctx.ast.nodes[i].sym].kind = DK_ARGS) Then
            ctx.rt.comps := ctx.rt.comps Or RC_ARGUMENTS Or RC_ARRAY;
        End;
    End;

  For sy := 1 To ctx.sem.sym_count Do
    If ctx.sem.syms[sy].flags And SF_CELL <> 0 Then
      Inc(ctx.rt.cells);
  If ctx.rt.cells > 0 Then
    ctx.rt.comps := ctx.rt.comps Or RC_CELL Or RC_FUNCTION;

  ctx.rt.built := True;
  If ctx.options.verbose Then
    Writeln('Runtime: valeur ', RT_VALUE_SIZE, ' octets, ',
            ctx.rt.int_literals, ' entiers, ', ctx.rt.double_literals,
            ' flottants, ', ctx.rt.string_literals, ' chaines, ',
            ctx.rt.functions, ' fonctions (', ctx.rt.closures,
            ' avec environnement), ', ctx.rt.cells, ' cellules');
  BuildRuntimeModel := ctx.errors = 0;
End;

{ ---- Affichage du modele (option -runtime) ---- }

Procedure DumpRuntimeModel(Var ctx: TCompilerContext);
Var
  b: LongInt;
  first: Boolean;
Begin
  Writeln('Modele runtime (32 bits) :');
  Writeln('  Valeur : ', RT_VALUE_SIZE, ' octets, lo = charge utile (+', RT_VAL_LO,
          '), hi = etiquette (+', RT_VAL_HI, ')');
  Writeln('    hi < ', RT_TAG_PREFIX, '0000h : nombre double IEEE 754');
  For b := RT_T_INT32 To RT_T_DONE Do
    Writeln('    ', RtTagHex(b), '  ', RtTagName(b));
  Writeln('    nombre = double ou int32 ; -0 et depassement passent par le FPU');
  Writeln('    FPU : mot de controle ', RT_FPU_CW, 'h (double precision, arrondi au plus pres)');
  Writeln('  Cellule du tas : en-tete de ', RT_HDR_SIZE, ' octets, alignement ',
          RT_ALIGN);
  Writeln('    +', RT_HDR_KIND, ' kind(1)  +', RT_HDR_GC, ' gc(1)  +',
          RT_HDR_FLAGS, ' flags(2)  +', RT_HDR_NEXT, ' gc_next(4)');
  Writeln('  Dispositions :');
  Writeln('    kinds    : ', RT_OK_STRING, ' chaine, ', RT_OK_ARRAY, ' tableau, ',
          RT_OK_OBJECT, ' objet, ', RT_OK_FUNCTION, ' fonction, ', RT_OK_CELL,
          ' cellule, ', RT_OK_REGEXP, ' regexp, ', RT_OK_ENV, ' environnement');
  Writeln('    chaine   : len +', RT_STR_LEN, ', hash +', RT_STR_HASH,
          ', octets UTF-8 +', RT_STR_DATA, ' (zero final)');
  Writeln('    tableau  : len +', RT_ARR_LEN, ', cap +', RT_ARR_CAP,
          ', elements +', RT_ARR_ELEMS, ' (taille ', RT_ARR_SIZE, ')');
  Writeln('    objet    : proto +', RT_OBJ_PROTO, ', props +', RT_OBJ_PROPS,
          ', nb +', RT_OBJ_COUNT, ', cap +', RT_OBJ_CAP, ', classe +',
          RT_OBJ_CLASS, ' (taille ', RT_OBJ_SIZE, ')');
  Writeln('    propriete: cle +', RT_PROP_KEY, ', drapeaux +', RT_PROP_FLAGS,
          ', valeur +', RT_PROP_VALUE, ' (', RT_PROP_SIZE, ' octets)');
  Writeln('    fonction : code +', RT_FN_CODE, ', env +', RT_FN_ENV,
          ', descripteur +', RT_FN_DESC, ', props +', RT_FN_PROPS,
          ', this lexical +', RT_FN_THIS, ' (taille ', RT_FN_SIZE, ')');
  Writeln('    descript.: nom +', RT_FD_NAME, ', nb params +', RT_FD_NPARAMS,
          ', drapeaux +', RT_FD_FLAGS, ', nb cellules +', RT_FD_NCELLS,
          ' (', RT_FD_SIZE, ' octets, en .rdata)');
  Writeln('    classe   : nom +', RT_CD_NAME, ', ctor +', RT_CD_CTOR, ', drapeaux +',
          RT_CD_FLAGS, ', nb membres +', RT_CD_NMEMBERS, ', membres +',
          RT_CD_MEMBERS, ' (', RT_CM_SIZE, ' octets : cle, drapeaux, descripteur)');
  Writeln('    cellule  : valeur +', RT_CELL_VALUE, ' (taille ', RT_CELL_SIZE, ')');
  Writeln('    environ. : nb +', RT_ENV_COUNT, ', pointeurs de cellules +',
          RT_ENV_CELLS);
  Writeln('    regexp   : source +', RT_RX_SOURCE, ', drapeaux +', RT_RX_FLAGS,
          ', programme +', RT_RX_PROG, ', lastIndex +', RT_RX_LASTINDEX,
          ' (taille ', RT_RX_SIZE, ')');
  Writeln('  Tas : arene de ', RT_ARENA_SIZE Div 1024, ' Ko (VirtualAlloc), blocs >= ',
          RT_BIG_ALLOC Div 1024, ' Ko directs, strategie sans liberation');
  Writeln('    reserve pour un mark & sweep : octet gc (+', RT_HDR_GC,
          ') et gc_next (+', RT_HDR_NEXT, ')');
  Writeln('  Pile : reserve ', RT_STACK_RESERVE Div 1024, ' Ko, limite souple ',
          RT_STACK_GUARD Div 1024, ' Ko (RangeError si depassee)');
  Writeln('    appel : [EBP+', RT_FRAME_CLOSURE, '] fonction, [EBP+',
          RT_FRAME_ARGC, '] argc, [EBP+', RT_FRAME_THIS, '] this (8 octets),');
  Writeln('            [EBP+', RT_FRAME_ARGS, '] arguments (8 octets chacun)');
  Writeln('            locaux sous EBP par pas de ', RT_VALUE_SIZE,
          ' ; retour dans EDX:EAX ; EBX, ESI, EDI preserves ; appelant nettoie');
  Writeln('    gestionnaire d''exception : prec +', RT_EH_PREV, ', esp +',
          RT_EH_ESP, ', ebp +', RT_EH_EBP, ', catch +', RT_EH_CATCH,
          ' (', RT_EH_SIZE, ' octets)');
  If ctx.rt.built Then
    Begin
      Writeln('Programme :');
      Writeln('  litteraux : ', ctx.rt.int_literals, ' entiers, ',
              ctx.rt.double_literals, ' flottants, ', ctx.rt.string_literals,
              ' chaines, ', ctx.rt.template_literals, ' gabarits, ',
              ctx.rt.regex_literals, ' regexp, ', ctx.rt.array_literals,
              ' tableaux, ', ctx.rt.object_literals, ' objets');
      Writeln('  code : ', ctx.rt.functions, ' fonctions (', ctx.rt.closures,
              ' avec captures), ', ctx.rt.classes, ' classes, ', ctx.rt.cells,
              ' cellules, ', ctx.rt.calls, ' appels, ', ctx.rt.news, ' new, ',
              ctx.rt.try_blocks, ' try, ', ctx.rt.throws, ' throw');
      Write('  composants du runtime a lier :');
      first := True;
      b := 1;
      While b <= RC_LAST Do
        Begin
          If ctx.rt.comps And b <> 0 Then
            Begin
              If Not first Then
                Write(',');
              Write(' ', RtComponentName(b));
              first := False;
            End;
          b := b * 2;
        End;
      Writeln;
    End;
End;

{ ============================================================
  TODO 8 - POOL DE CONSTANTES ET DE DONNEES

  Toutes les donnees statiques du programme sont construites ici, en
  octets, avec leurs symboles et leurs relocations :

    .rdata  chaines internees (une cellule de chaine par chaine
            distincte), constantes double, descripteurs de fonctions,
            descripteurs de classes, table des atomes.
    .data   variables du runtime et variables globales du programme
            (8 octets chacune, initialisees a undefined ou a la marque
            TDZ).

  Une chaine litterale et un nom de propriete identiques partagent la
  meme cellule. Les noms de proprietes sont des atomes : comme les
  atomes sont internes, une propriete se retrouve par comparaison de
  pointeurs. La table des atomes permet au runtime de les enregistrer
  dans sa table de hachage au demarrage. Le hachage des chaines est
  FNV-1a 32 bits sur les octets UTF-8.

  Nommage des symboles (stable, prefixe) :
    _JSK_nnnn  chaine        _JSD_nnnn  constante double
    _JSFD_nnnn descripteur   _JSF_nnnn_nom  code d'une fonction
    _JSC_nnnn  classe        _JSV_nom  variable globale
    _JSL_nnnn  etiquette     _JSRT_nom routine ou donnee du runtime
    _JSATOMS   table des atomes
  ============================================================ }

{ ---- Nommage ---- }

Function Pad4(n: LongInt): TString;
Var
  s: String[12];
Begin
  Str(n, s);
  While Length(s) < 4 Do
    s := '0' + s;
  Pad4 := s;
End;

{ Identifiant JavaScript -> suffixe de symbole : lettres, chiffres et _
  gardes ; $ devient _S_ ; les octets non ASCII deviennent _xHH. }
Function MangleIdent(Const s: TTokenText): TString;
Var
  r: TString;
  i: Integer;
  c: Char;
Begin
  r := '';
  For i := 1 To Length(s) Do
    Begin
      c := s[i];
      If ((c >= 'A') And (c <= 'Z')) Or ((c >= 'a') And (c <= 'z')) Or
         ((c >= '0') And (c <= '9')) Or (c = '_') Then
        r := r + c
      Else If c = '$' Then
        r := r + '_S_'
      Else
        r := r + '_x' + Copy(RtHex4(Ord(c)), 3, 2);
    End;
  MangleIdent := r;
End;

Function SymStr(id: LongInt): TString;
Begin
  SymStr := '_JSK_' + Pad4(id);
End;

Function SymDbl(id: LongInt): TString;
Begin
  SymDbl := '_JSD_' + Pad4(id);
End;

Function SymFdesc(id: LongInt): TString;
Begin
  SymFdesc := '_JSFD_' + Pad4(id);
End;

Function SymClassDesc(id: LongInt): TString;
Begin
  SymClassDesc := '_JSC_' + Pad4(id);
End;

Function SymLabel(id: LongInt): TString;
Begin
  SymLabel := '_JSL_' + Pad4(id);
End;

Function SymRt(Const name: TString): TString;
Begin
  SymRt := '_JSRT_' + name;
End;

{ ---- Ecriture dans les images de sections ---- }

Procedure DataFail(Var ctx: TCompilerContext; Const msg: TString);
Begin
  If Not ctx.data.failed Then
    PipelineError(ctx, msg);
  ctx.data.failed := True;
End;

Procedure PutByte(Var ctx: TCompilerContext; sec: Integer; ofs: LongInt; b: LongInt);
Begin
  If sec = SEC_RDATA Then
    Begin
      If ofs >= MAX_RDATA Then
        Begin
          DataFail(ctx, 'section .rdata trop grande');
          Exit;
        End;
      ctx.data.rd[ofs] := Byte(b And $FF);
    End
  Else
    Begin
      If ofs >= MAX_DATA_IMG Then
        Begin
          DataFail(ctx, 'section .data trop grande');
          Exit;
        End;
      ctx.data.dt[ofs] := Byte(b And $FF);
    End;
End;

{ Ecrit un DWORD petit-boutiste ; v peut etre non signe (Int64). }
Procedure PutDword(Var ctx: TCompilerContext; sec: Integer; ofs: LongInt; v: Int64);
Var
  i: Integer;
  w: Int64;
Begin
  w := v And $FFFFFFFF;
  For i := 0 To 3 Do
    Begin
      PutByte(ctx, sec, ofs + i, w And $FF);
      w := w Shr 8;
    End;
End;

Function SecSize(Var ctx: TCompilerContext; sec: Integer): LongInt;
Begin
  If sec = SEC_RDATA Then
    SecSize := ctx.data.rd_size
  Else
    SecSize := ctx.data.dt_size;
End;

{ Reserve n octets alignes sur 8 ; retourne l'offset. }
Function SecAlloc(Var ctx: TCompilerContext; sec: Integer; n: LongInt): LongInt;
Var
  ofs: LongInt;
Begin
  If sec = SEC_RDATA Then
    Begin
      ofs := (ctx.data.rd_size + 7) And Not 7;
      ctx.data.rd_size := ofs + n;
      If ctx.data.rd_size > MAX_RDATA Then
        DataFail(ctx, 'section .rdata trop grande');
    End
  Else
    Begin
      ofs := (ctx.data.dt_size + 7) And Not 7;
      ctx.data.dt_size := ofs + n;
      If ctx.data.dt_size > MAX_DATA_IMG Then
        DataFail(ctx, 'section .data trop grande');
    End;
  SecAlloc := ofs;
End;

Function NameHash(Const s: TString): LongInt;
Var
  h: Int64;
  i: Integer;
Begin
  h := 2166136261;
  For i := 1 To Length(s) Do
    Begin
      h := h Xor Ord(s[i]);
      h := (h * 16777619) And $FFFFFFFF;
    End;
  NameHash := h And 65535;
End;

{ Indice du symbole de donnees de ce nom, ou 0. }
Function DsymFind(Var ctx: TCompilerContext; Const name: TString): LongInt;
Var
  slot, id: LongInt;
Begin
  slot := NameHash(name);
  DsymFind := 0;
  While ctx.data.dhash[slot] <> 0 Do
    Begin
      id := ctx.data.dhash[slot];
      If ctx.data.syms[id].name = name Then
        Begin
          DsymFind := id;
          Exit;
        End;
      slot := (slot + 1) And 65535;
    End;
End;

Function NewDataSym(Var ctx: TCompilerContext; Const name: TString;
                    sec: Integer; ofs, size: LongInt; kind: Integer): LongInt;
Var
  slot: LongInt;
Begin
  NewDataSym := 0;
  If ctx.data.sym_count >= MAX_DSYMS Then
    Begin
      DataFail(ctx, 'trop de symboles de donnees');
      Exit;
    End;
  Inc(ctx.data.sym_count);
  ctx.data.syms[ctx.data.sym_count].name := name;
  ctx.data.syms[ctx.data.sym_count].sec := sec;
  ctx.data.syms[ctx.data.sym_count].ofs := ofs;
  ctx.data.syms[ctx.data.sym_count].size := size;
  ctx.data.syms[ctx.data.sym_count].kind := kind;
  slot := NameHash(name);
  While ctx.data.dhash[slot] <> 0 Do
    slot := (slot + 1) And 65535;
  ctx.data.dhash[slot] := ctx.data.sym_count;
  NewDataSym := ctx.data.sym_count;
End;

{ Le DWORD a (sec, ofs) contient l'adresse du symbole target. }
Procedure AddReloc(Var ctx: TCompilerContext; sec: Integer; ofs, target: LongInt);
Begin
  If ctx.data.reloc_count >= MAX_RELOCS Then
    Begin
      DataFail(ctx, 'trop de relocations');
      Exit;
    End;
  Inc(ctx.data.reloc_count);
  ctx.data.relocs[ctx.data.reloc_count].sec := sec;
  ctx.data.relocs[ctx.data.reloc_count].tkind := SYMK_D;
  ctx.data.relocs[ctx.data.reloc_count].ofs := ofs;
  ctx.data.relocs[ctx.data.reloc_count].target := target;
End;

{ Relocation vers un symbole de code ou externe (indice de xsyms). }
Procedure AddRelocX(Var ctx: TCompilerContext; sec: Integer; ofs, target: LongInt);
Begin
  AddReloc(ctx, sec, ofs, target);
  If ctx.data.reloc_count > 0 Then
    ctx.data.relocs[ctx.data.reloc_count].tkind := SYMK_X;
End;

{ ---- Chaines internees ---- }

Function JsHash(Var ctx: TCompilerContext; off, len: LongInt): Int64;
Var
  h: Int64;
  i: LongInt;
Begin
  h := 2166136261;
  For i := 0 To len - 1 Do
    Begin
      h := h Xor Ord(ctx.data.dpool[off + i]);
      h := (h * 16777619) And $FFFFFFFF;
    End;
  JsHash := h;
End;

{ La chaine est deja copiee dans dpool a partir de off ; la retire si elle
  existe deja. Retourne son identifiant. }
Function InternAt(Var ctx: TCompilerContext; off, len: LongInt): LongInt;
Var
  h: Int64;
  slot, id, i: LongInt;
  same: Boolean;
Begin
  InternAt := 0;
  h := JsHash(ctx, off, len);
  slot := h And (HASH_SIZE - 1);
  While ctx.data.hash[slot] <> 0 Do
    Begin
      id := ctx.data.hash[slot];
      If (ctx.data.strs[id].len = len) And (ctx.data.strs[id].hash = h) Then
        Begin
          same := True;
          For i := 0 To len - 1 Do
            If ctx.data.dpool[ctx.data.strs[id].off + i] <> ctx.data.dpool[off + i] Then
              same := False;
          If same Then
            Begin
              ctx.data.dpool_len := off;
              InternAt := id;
              Exit;
            End;
        End;
      slot := (slot + 1) And (HASH_SIZE - 1);
    End;
  If ctx.data.str_count >= MAX_STRS Then
    Begin
      DataFail(ctx, 'trop de chaines litterales');
      ctx.data.dpool_len := off;
      Exit;
    End;
  Inc(ctx.data.str_count);
  id := ctx.data.str_count;
  ctx.data.strs[id].off := off;
  ctx.data.strs[id].len := len;
  ctx.data.strs[id].hash := h;
  ctx.data.strs[id].atom_id := 0;
  ctx.data.strs[id].sym := 0;
  ctx.data.hash[slot] := id;
  InternAt := id;
End;

Procedure DpoolPut(Var ctx: TCompilerContext; c: Char);
Begin
  If ctx.data.dpool_len >= MAX_DPOOL Then
    Begin
      DataFail(ctx, 'pool de chaines statiques plein');
      Exit;
    End;
  ctx.data.dpool[ctx.data.dpool_len] := c;
  Inc(ctx.data.dpool_len);
End;

Function InternPool(Var ctx: TCompilerContext; off, len: LongInt): LongInt;
Var
  start, i: LongInt;
Begin
  start := ctx.data.dpool_len;
  For i := 0 To len - 1 Do
    DpoolPut(ctx, ctx.lex.pool[off + i]);
  InternPool := InternAt(ctx, start, len);
End;

Function InternText(Var ctx: TCompilerContext; Const s: TString): LongInt;
Var
  start, i: LongInt;
Begin
  start := ctx.data.dpool_len;
  For i := 1 To Length(s) Do
    DpoolPut(ctx, s[i]);
  InternText := InternAt(ctx, start, Length(s));
End;

{ Marque une chaine comme atome (nom de propriete). }
Function MarkAtom(Var ctx: TCompilerContext; id: LongInt): LongInt;
Begin
  If (id <> 0) And (ctx.data.strs[id].atom_id = 0) Then
    Begin
      Inc(ctx.data.atom_count);
      ctx.data.strs[id].atom_id := ctx.data.atom_count;
      ctx.data.atoms[ctx.data.atom_count] := id;
    End;
  MarkAtom := id;
End;

{ Nom de propriete porte par un jeton : identifiant, mot-cle, chaine ou
  nombre (forme canonique si entier). }
Function KeyString(Var ctx: TCompilerContext; tok: LongInt): LongInt;
Var
  s: String[24];
  v: Double;
Begin
  KeyString := 0;
  Case ctx.lex.tokens[tok].kind Of
    TK_IDENT, TK_KEYWORD:
      KeyString := InternText(ctx, ctx.lex.tokens[tok].text);
    TK_STRING:
      KeyString := InternPool(ctx, ctx.lex.tokens[tok].sval_off,
                              ctx.lex.tokens[tok].sval_len);
    TK_NUMBER:
      Begin
        v := ctx.lex.tokens[tok].num_val;
        If FitsInt32(v) Then
          Begin
            Str(Trunc(v), s);
            KeyString := InternText(ctx, s);
          End
        Else
          KeyString := InternText(ctx, ctx.lex.tokens[tok].text);
      End;
  End;
End;

{ ---- Constantes double ---- }

Function AddDoubleBits(Var ctx: TCompilerContext; lo, hi: Int64): LongInt;
Var
  i: LongInt;
Begin
  For i := 1 To ctx.data.dbl_count Do
    If (ctx.data.dbls[i].lo = lo) And (ctx.data.dbls[i].hi = hi) Then
      Begin
        AddDoubleBits := i;
        Exit;
      End;
  AddDoubleBits := 0;
  If ctx.data.dbl_count >= MAX_DBLS Then
    Begin
      DataFail(ctx, 'trop de constantes flottantes');
      Exit;
    End;
  Inc(ctx.data.dbl_count);
  ctx.data.dbls[ctx.data.dbl_count].lo := lo;
  ctx.data.dbls[ctx.data.dbl_count].hi := hi;
  ctx.data.dbls[ctx.data.dbl_count].sym := 0;
  AddDoubleBits := ctx.data.dbl_count;
End;

Function AddDouble(Var ctx: TCompilerContext; v: Double): LongInt;
Var
  w: Array[0..1] Of LongInt;
Begin
  Move(v, w, 8);
  AddDouble := AddDoubleBits(ctx, Int64(w[0]) And $FFFFFFFF,
                             Int64(w[1]) And $FFFFFFFF);
End;

Function StrText(Var ctx: TCompilerContext; id: LongInt): TString;
Var
  r: TString;
  i, n: LongInt;
Begin
  n := ctx.data.strs[id].len;
  If n > 250 Then
    n := 250;
  r := '';
  For i := 0 To n - 1 Do
    r := r + ctx.data.dpool[ctx.data.strs[id].off + i];
  StrText := r;
End;

{ ---- Descripteurs ---- }

Function NodeFuncName(Var ctx: TCompilerContext; n: LongInt): LongInt;
Var
  t: LongInt;
Begin
  NodeFuncName := InternText(ctx, '');
  t := ctx.ast.nodes[n].tok;
  Case ctx.ast.nodes[n].kind Of
    N_FUNC_DECL, N_CLASS_DECL:
      NodeFuncName := KeyString(ctx, t);
    N_FUNC_EXPR, N_CLASS_EXPR:
      Begin
        If ctx.lex.tokens[t].kind = TK_IDENT Then
          NodeFuncName := KeyString(ctx, t)
        Else If (ctx.ast.nodes[n].flags And FN_METHOD <> 0) And
                (ctx.lex.tokens[t].kind <> TK_PUNCT) Then
          NodeFuncName := KeyString(ctx, t);
      End;
    N_METHOD, N_FIELD:
      If ctx.ast.nodes[n].flags And MF_COMPUTED = 0 Then
        NodeFuncName := KeyString(ctx, t);
  End;
End;

Function ParamLength(Var ctx: TCompilerContext; n: LongInt): LongInt;
Var
  p, cnt: LongInt;
  stop: Boolean;
Begin
  cnt := 0;
  stop := False;
  p := ctx.ast.nodes[n].e1;
  If ctx.ast.nodes[n].kind = N_FIELD Then
    p := 0;
  If ctx.ast.nodes[n].kind = N_STATIC_BLOCK Then
    p := 0;
  While (p <> 0) And Not stop Do
    Begin
      If (ctx.ast.nodes[p].flags And PF_REST <> 0) Or (ctx.ast.nodes[p].e2 <> 0) Then
        stop := True
      Else
        Inc(cnt);
      p := ctx.ast.nodes[p].next;
    End;
  ParamLength := cnt;
End;

Procedure AddFuncDesc(Var ctx: TCompilerContext; n: LongInt);
Var
  id, fl, sc: LongInt;
  nm: LongInt;
Begin
  If ctx.data.fd_count >= MAX_FDESCS Then
    Begin
      DataFail(ctx, 'trop de descripteurs de fonctions');
      Exit;
    End;
  Inc(ctx.data.fd_count);
  id := ctx.data.fd_count;
  fl := 0;
  sc := ctx.ast.nodes[n].scope;
  Case ctx.ast.nodes[n].kind Of
    N_FUNC_DECL, N_FUNC_EXPR:
      Begin
        If ctx.ast.nodes[n].flags And FN_ARROW <> 0 Then
          fl := fl Or FDF_ARROW;
        If ctx.ast.nodes[n].flags And FN_ASYNC <> 0 Then
          fl := fl Or FDF_ASYNC;
        If ctx.ast.nodes[n].flags And FN_GENERATOR <> 0 Then
          fl := fl Or FDF_GENERATOR;
        If ctx.ast.nodes[n].flags And FN_METHOD <> 0 Then
          fl := fl Or FDF_METHOD;
        If ctx.ast.nodes[n].flags And FN_EXPR_BODY <> 0 Then
          fl := fl Or FDF_EXPR_BODY;
      End;
    N_METHOD:
      Begin
        fl := fl Or FDF_METHOD;
        If ctx.ast.nodes[n].flags And MF_STATIC <> 0 Then
          fl := fl Or FDF_STATIC;
        If ctx.ast.nodes[n].flags And MF_GETTER <> 0 Then
          fl := fl Or FDF_GETTER;
        If ctx.ast.nodes[n].flags And MF_SETTER <> 0 Then
          fl := fl Or FDF_SETTER;
        If ctx.ast.nodes[n].flags And MF_ASYNC <> 0 Then
          fl := fl Or FDF_ASYNC;
        If ctx.ast.nodes[n].flags And MF_GENERATOR <> 0 Then
          fl := fl Or FDF_GENERATOR;
        If ctx.ast.nodes[n].flags And MF_CONSTRUCTOR <> 0 Then
          Begin
            fl := fl Or FDF_CTOR;
            If ctx.sem.scopes[sc].fkind = FK_DERIVED_CTOR Then
              fl := fl Or FDF_DERIVED;
          End;
      End;
    N_FIELD:
      Begin
        fl := fl Or FDF_FIELD_INIT;
        If ctx.ast.nodes[n].flags And MF_STATIC <> 0 Then
          fl := fl Or FDF_STATIC;
      End;
    N_STATIC_BLOCK:
      fl := fl Or FDF_STATIC_BLOCK Or FDF_STATIC;
  End;
  If sc <> 0 Then
    Begin
      If ctx.sem.scopes[sc].uses_this Then
        fl := fl Or FDF_USES_THIS;
      If ctx.sem.scopes[sc].uses_arguments Then
        fl := fl Or FDF_USES_ARGS;
      If ctx.sem.scopes[sc].this_captured Then
        fl := fl Or FDF_THIS_CAPTURED;
      ctx.data.fdescs[id].ncells := ctx.sem.scopes[sc].cap_count;
    End
  Else
    ctx.data.fdescs[id].ncells := 0;
  nm := NodeFuncName(ctx, n);
  ctx.data.fdescs[id].node := n;
  ctx.data.fdescs[id].name_str := nm;
  ctx.data.fdescs[id].nparams := ParamLength(ctx, n);
  ctx.data.fdescs[id].flags := fl;
  ctx.data.fdescs[id].sym := 0;
  ctx.data.fdescs[id].code_sym := '_JSF_' + Pad4(id);
  If ctx.data.strs[nm].len > 0 Then
    ctx.data.fdescs[id].code_sym := ctx.data.fdescs[id].code_sym + '_' +
      MangleIdent(Copy(StrText(ctx, nm), 1, 40));
  ctx.ast.nodes[n].ds := id;
End;

Procedure AddClassDesc(Var ctx: TCompilerContext; n: LongInt);
Var
  id, m, f: LongInt;
  cm: LongInt;
Begin
  If ctx.data.cd_count >= MAX_CDESCS Then
    Begin
      DataFail(ctx, 'trop de descripteurs de classes');
      Exit;
    End;
  Inc(ctx.data.cd_count);
  id := ctx.data.cd_count;
  ctx.data.cdescs[id].node := n;
  ctx.data.cdescs[id].name_str := NodeFuncName(ctx, n);
  ctx.data.cdescs[id].ctor_fd := 0;
  ctx.data.cdescs[id].flags := 0;
  ctx.data.cdescs[id].first_member := ctx.data.cm_count + 1;
  ctx.data.cdescs[id].member_count := 0;
  ctx.data.cdescs[id].sym := 0;
  If ctx.ast.nodes[n].e1 <> 0 Then
    ctx.data.cdescs[id].flags := ctx.data.cdescs[id].flags Or CDF_DERIVED;
  m := ctx.ast.nodes[n].e2;
  While m <> 0 Do
    Begin
      If ctx.data.cm_count >= MAX_CMEMBERS Then
        Begin
          DataFail(ctx, 'trop de membres de classe');
          Break;
        End;
      Inc(ctx.data.cm_count);
      cm := ctx.data.cm_count;
      f := 0;
      ctx.data.cmembers[cm].key_str := 0;
      ctx.data.cmembers[cm].fd := ctx.ast.nodes[m].ds;
      Case ctx.ast.nodes[m].kind Of
        N_METHOD:
          Begin
            f := f Or CM_METHOD;
            If ctx.ast.nodes[m].flags And MF_GETTER <> 0 Then
              f := f Or CM_GETTER;
            If ctx.ast.nodes[m].flags And MF_SETTER <> 0 Then
              f := f Or CM_SETTER;
            If ctx.ast.nodes[m].flags And MF_CONSTRUCTOR <> 0 Then
              Begin
                f := f Or CM_CTOR;
                ctx.data.cdescs[id].ctor_fd := ctx.ast.nodes[m].ds;
              End;
          End;
        N_FIELD:
          f := f Or CM_FIELD;
        N_STATIC_BLOCK:
          f := f Or CM_STATIC_BLOCK;
      End;
      If ctx.ast.nodes[m].flags And MF_STATIC <> 0 Then
        f := f Or CM_STATIC;
      If ctx.ast.nodes[m].flags And MF_COMPUTED <> 0 Then
        f := f Or CM_COMPUTED;
      ctx.data.cmembers[cm].flags := f;
      If ctx.ast.nodes[m].kind <> N_STATIC_BLOCK Then
        ctx.data.cmembers[cm].key_str := ctx.ast.nodes[m].aux;
      Inc(ctx.data.cdescs[id].member_count);
      m := ctx.ast.nodes[m].next;
    End;
  ctx.ast.nodes[n].ds := id;
End;

{ ---- Chaines et constantes standard du runtime ---- }

Procedure AddStandardData(Var ctx: TCompilerContext);
Var
  i: Integer;
  id: LongInt;
Begin
  For i := 1 To STD_STR_COUNT Do
    Begin
      id := InternText(ctx, StdStrings[i]);
      If i >= STD_ATOM_FIRST Then
        MarkAtom(ctx, id);
    End;
  { 0, 1, -0, NaN, +Inf, -Inf, 2^31, 2^32, 1e21, 10 }
  AddDoubleBits(ctx, 0, 0);
  AddDoubleBits(ctx, 0, $3FF00000);
  AddDoubleBits(ctx, 0, $80000000);
  AddDoubleBits(ctx, 0, $FFF80000);
  AddDoubleBits(ctx, 0, $7FF00000);
  AddDoubleBits(ctx, 0, $FFF00000);
  AddDoubleBits(ctx, 0, $41E00000);
  AddDoubleBits(ctx, 0, $41F00000);
  AddDoubleBits(ctx, $D6E2EF50, $444B1AE4);
  AddDoubleBits(ctx, 0, $40240000);
End;

{ ---- Collecte dans l'AST ---- }

Procedure CollectData(Var ctx: TCompilerContext);
Var
  i, e: LongInt;
  v: Double;
  s: TTokenText;
Begin
  For i := 1 To ctx.ast.node_count Do
    Begin
      ctx.ast.nodes[i].ds := 0;
      Case ctx.ast.nodes[i].kind Of
        N_STRING, N_TEMPLATE_STR:
          ctx.ast.nodes[i].ds := InternPool(ctx,
            ctx.lex.tokens[ctx.ast.nodes[i].tok].sval_off,
            ctx.lex.tokens[ctx.ast.nodes[i].tok].sval_len);
        N_REGEX:
          Begin
            ctx.ast.nodes[i].ds := InternPool(ctx,
              ctx.lex.tokens[ctx.ast.nodes[i].tok].sval_off,
              ctx.lex.tokens[ctx.ast.nodes[i].tok].sval_len);
            ctx.ast.nodes[i].aux := InternPool(ctx,
              ctx.lex.tokens[ctx.ast.nodes[i].tok].sval_off +
              ctx.lex.tokens[ctx.ast.nodes[i].tok].sval_len,
              ctx.lex.tokens[ctx.ast.nodes[i].tok].flag_len);
          End;
        N_NUMBER:
          Begin
            v := ctx.lex.tokens[ctx.ast.nodes[i].tok].num_val;
            If Not FitsInt32(v) Then
              ctx.ast.nodes[i].ds := AddDouble(ctx, v);
          End;
        N_UNARY:
          Begin
            s := ctx.lex.tokens[ctx.ast.nodes[i].tok].text;
            e := ctx.ast.nodes[i].e1;
            If (s = '-') And (e <> 0) And (ctx.ast.nodes[e].kind = N_NUMBER) And
               (ctx.lex.tokens[ctx.ast.nodes[e].tok].num_val = 0) Then
              ctx.ast.nodes[i].ds := STD_DBL_NEGZERO;
          End;
        N_MEMBER:
          ctx.ast.nodes[i].aux := MarkAtom(ctx,
            InternText(ctx, ctx.lex.tokens[ctx.ast.nodes[i].tok].text));
        N_PROP:
          If ctx.ast.nodes[i].flags And (PR_SPREAD Or PR_COMPUTED) = 0 Then
            ctx.ast.nodes[i].aux := MarkAtom(ctx, KeyString(ctx, ctx.ast.nodes[i].tok));
        N_PATTERN_PROP:
          If ctx.ast.nodes[i].flags And (PP_REST Or PP_COMPUTED) = 0 Then
            ctx.ast.nodes[i].aux := MarkAtom(ctx, KeyString(ctx, ctx.ast.nodes[i].tok));
        N_FUNC_DECL, N_FUNC_EXPR, N_STATIC_BLOCK:
          AddFuncDesc(ctx, i);
        N_METHOD:
          Begin
            If ctx.ast.nodes[i].flags And MF_COMPUTED = 0 Then
              ctx.ast.nodes[i].aux := MarkAtom(ctx, KeyString(ctx, ctx.ast.nodes[i].tok));
            AddFuncDesc(ctx, i);
          End;
        N_FIELD:
          Begin
            If ctx.ast.nodes[i].flags And MF_COMPUTED = 0 Then
              ctx.ast.nodes[i].aux := MarkAtom(ctx, KeyString(ctx, ctx.ast.nodes[i].tok));
            If ctx.ast.nodes[i].e1 <> 0 Then
              AddFuncDesc(ctx, i);
          End;
      End;
    End;
  { noms des variables qui exigent un test TDZ a l'execution }
  For i := 1 To ctx.sem.sym_count Do
    Begin
      ctx.sem.syms[i].name_str := 0;
      If ctx.sem.syms[i].flags And SF_TDZ_CHECK <> 0 Then
        ctx.sem.syms[i].name_str :=
          InternText(ctx, ctx.lex.tokens[ctx.sem.syms[i].name_tok].text);
    End;
  { descripteurs de classes : apres ceux des membres }
  For i := 1 To ctx.ast.node_count Do
    If (ctx.ast.nodes[i].kind = N_CLASS_DECL) Or
       (ctx.ast.nodes[i].kind = N_CLASS_EXPR) Then
      AddClassDesc(ctx, i);
End;

{ ---- Emission des sections ---- }

Procedure EmitStringCell(Var ctx: TCompilerContext; id: LongInt);
Var
  ofs, i, len: LongInt;
Begin
  len := ctx.data.strs[id].len;
  ofs := SecAlloc(ctx, SEC_RDATA, RT_STR_DATA + len + 1);
  If ctx.data.failed Then
    Exit;
  PutByte(ctx, SEC_RDATA, ofs + RT_HDR_KIND, RT_OK_STRING);
  PutByte(ctx, SEC_RDATA, ofs + RT_HDR_GC, 0);
  PutByte(ctx, SEC_RDATA, ofs + RT_HDR_FLAGS, OF_STATIC);
  PutDword(ctx, SEC_RDATA, ofs + RT_STR_LEN, len);
  PutDword(ctx, SEC_RDATA, ofs + RT_STR_HASH, ctx.data.strs[id].hash);
  For i := 0 To len - 1 Do
    PutByte(ctx, SEC_RDATA, ofs + RT_STR_DATA + i,
            Ord(ctx.data.dpool[ctx.data.strs[id].off + i]));
  PutByte(ctx, SEC_RDATA, ofs + RT_STR_DATA + len, 0);
  ctx.data.strs[id].sym := NewDataSym(ctx, SymStr(id), SEC_RDATA, ofs,
                                      RT_STR_DATA + len + 1, DS_STRING);
End;

Procedure EmitDoubles(Var ctx: TCompilerContext);
Var
  i, ofs: LongInt;
Begin
  For i := 1 To ctx.data.dbl_count Do
    Begin
      ofs := SecAlloc(ctx, SEC_RDATA, 8);
      PutDword(ctx, SEC_RDATA, ofs, ctx.data.dbls[i].lo);
      PutDword(ctx, SEC_RDATA, ofs + 4, ctx.data.dbls[i].hi);
      ctx.data.dbls[i].sym := NewDataSym(ctx, SymDbl(i), SEC_RDATA, ofs, 8, DS_DOUBLE);
    End;
End;

Procedure EmitFuncDescs(Var ctx: TCompilerContext);
Var
  i, ofs: LongInt;
Begin
  For i := 1 To ctx.data.fd_count Do
    Begin
      ofs := SecAlloc(ctx, SEC_RDATA, RT_FD_SIZE);
      PutDword(ctx, SEC_RDATA, ofs + RT_FD_NAME, 0);
      AddReloc(ctx, SEC_RDATA, ofs + RT_FD_NAME,
               ctx.data.strs[ctx.data.fdescs[i].name_str].sym);
      PutDword(ctx, SEC_RDATA, ofs + RT_FD_NPARAMS, ctx.data.fdescs[i].nparams);
      PutDword(ctx, SEC_RDATA, ofs + RT_FD_FLAGS, ctx.data.fdescs[i].flags);
      PutDword(ctx, SEC_RDATA, ofs + RT_FD_NCELLS, ctx.data.fdescs[i].ncells);
      ctx.data.fdescs[i].sym := NewDataSym(ctx, SymFdesc(i), SEC_RDATA, ofs,
                                           RT_FD_SIZE, DS_FDESC);
    End;
End;

Procedure EmitClassDescs(Var ctx: TCompilerContext);
Var
  i, j, ofs, size, mo, cm: LongInt;
Begin
  For i := 1 To ctx.data.cd_count Do
    Begin
      size := RT_CD_MEMBERS + RT_CM_SIZE * ctx.data.cdescs[i].member_count;
      ofs := SecAlloc(ctx, SEC_RDATA, size);
      AddReloc(ctx, SEC_RDATA, ofs + RT_CD_NAME,
               ctx.data.strs[ctx.data.cdescs[i].name_str].sym);
      If ctx.data.cdescs[i].ctor_fd <> 0 Then
        AddReloc(ctx, SEC_RDATA, ofs + RT_CD_CTOR,
                 ctx.data.fdescs[ctx.data.cdescs[i].ctor_fd].sym);
      PutDword(ctx, SEC_RDATA, ofs + RT_CD_FLAGS, ctx.data.cdescs[i].flags);
      PutDword(ctx, SEC_RDATA, ofs + RT_CD_NMEMBERS, ctx.data.cdescs[i].member_count);
      For j := 0 To ctx.data.cdescs[i].member_count - 1 Do
        Begin
          cm := ctx.data.cdescs[i].first_member + j;
          mo := ofs + RT_CD_MEMBERS + RT_CM_SIZE * j;
          If ctx.data.cmembers[cm].key_str <> 0 Then
            AddReloc(ctx, SEC_RDATA, mo + RT_CM_KEY,
                     ctx.data.strs[ctx.data.cmembers[cm].key_str].sym);
          PutDword(ctx, SEC_RDATA, mo + RT_CM_FLAGS, ctx.data.cmembers[cm].flags);
          If ctx.data.cmembers[cm].fd <> 0 Then
            AddReloc(ctx, SEC_RDATA, mo + RT_CM_DESC,
                     ctx.data.fdescs[ctx.data.cmembers[cm].fd].sym);
        End;
      ctx.data.cdescs[i].sym := NewDataSym(ctx, SymClassDesc(i), SEC_RDATA, ofs,
                                           size, DS_CLASSDESC);
    End;
End;

Procedure EmitAtomTable(Var ctx: TCompilerContext);
Var
  i, ofs: LongInt;
Begin
  ofs := SecAlloc(ctx, SEC_RDATA, 4 + 4 * ctx.data.atom_count);
  PutDword(ctx, SEC_RDATA, ofs, ctx.data.atom_count);
  For i := 1 To ctx.data.atom_count Do
    AddReloc(ctx, SEC_RDATA, ofs + 4 * i, ctx.data.strs[ctx.data.atoms[i]].sym);
  ctx.data.atom_table_sym := NewDataSym(ctx, '_JSATOMS', SEC_RDATA, ofs,
                                        4 + 4 * ctx.data.atom_count, DS_ATOMS);
End;

{ Valeur initiale d'une variable : undefined, ou la marque TDZ. }
Procedure PutValue(Var ctx: TCompilerContext; ofs, tag: LongInt);
Begin
  PutDword(ctx, SEC_DATA, ofs + RT_VAL_LO, 0);
  PutDword(ctx, SEC_DATA, ofs + RT_VAL_HI, RT_TAG_BASE + tag);
End;

Procedure EmitDataSection(Var ctx: TCompilerContext);
Var
  i, ofs, sy: LongInt;
  nm: TString;
Begin
  For i := 1 To RT_DATA_VAR_COUNT Do
    Begin
      ofs := SecAlloc(ctx, SEC_DATA, 8);
      nm := SymRt('v_' + RtDataVars[i]);
      NewDataSym(ctx, nm, SEC_DATA, ofs, 8, DS_RTVAR);
    End;
  For sy := 1 To ctx.sem.sym_count Do
    If (ctx.sem.syms[sy].flags And SF_STATIC <> 0) And
       ((ctx.sem.syms[sy].kind = DK_VAR) Or (ctx.sem.syms[sy].kind = DK_LET) Or
        (ctx.sem.syms[sy].kind = DK_CONST) Or (ctx.sem.syms[sy].kind = DK_FUNC) Or
        (ctx.sem.syms[sy].kind = DK_CLASS)) Then
      Begin
        ofs := SecAlloc(ctx, SEC_DATA, RT_VALUE_SIZE);
        nm := '_JSV_' + MangleIdent(ctx.lex.tokens[ctx.sem.syms[sy].name_tok].text);
        If ctx.sem.syms[sy].scope <> 1 Then
          nm := nm + '_' + Pad4(sy);
        If IsLexicalKind(ctx.sem.syms[sy].kind) And
           (ctx.sem.syms[sy].flags And SF_TDZ_CHECK <> 0) Then
          PutValue(ctx, ofs, RT_T_TDZ)
        Else
          PutValue(ctx, ofs, RT_T_UNDEFINED);
        ctx.sem.syms[sy].ds := NewDataSym(ctx, nm, SEC_DATA, ofs, RT_VALUE_SIZE,
                                          DS_GLOBAL);
        Inc(ctx.data.global_count);
      End;
End;

Function BuildDataPool(Var ctx: TCompilerContext): Boolean;
Var
  i: LongInt;
Begin
  BuildDataPool := False;
  If Not ctx.rt.built Then
    Begin
      PipelineError(ctx, 'modele runtime absent avant le pool de donnees');
      Exit;
    End;
  ctx.data.failed := False;
  ctx.data.str_count := 0;
  ctx.data.dpool_len := 0;
  ctx.data.atom_count := 0;
  ctx.data.dbl_count := 0;
  ctx.data.fd_count := 0;
  ctx.data.cd_count := 0;
  ctx.data.cm_count := 0;
  ctx.data.sym_count := 0;
  ctx.data.reloc_count := 0;
  ctx.data.rd_size := 0;
  ctx.data.dt_size := 0;
  ctx.data.global_count := 0;
  FillChar(ctx.data.hash, SizeOf(ctx.data.hash), 0);
  FillChar(ctx.data.dhash, SizeOf(ctx.data.dhash), 0);
  For i := 1 To ctx.sem.sym_count Do
    ctx.sem.syms[i].ds := 0;

  AddStandardData(ctx);
  CollectData(ctx);

  For i := 1 To ctx.data.str_count Do
    If Not ctx.data.failed Then
      EmitStringCell(ctx, i);
  If Not ctx.data.failed Then
    EmitDoubles(ctx);
  If Not ctx.data.failed Then
    EmitFuncDescs(ctx);
  If Not ctx.data.failed Then
    EmitClassDescs(ctx);
  If Not ctx.data.failed Then
    EmitAtomTable(ctx);
  If Not ctx.data.failed Then
    EmitDataSection(ctx);

  ctx.data.built := Not ctx.data.failed;
  If ctx.options.verbose And ctx.data.built Then
    Writeln('Donnees: .rdata ', ctx.data.rd_size, ' octets (',
            ctx.data.str_count, ' chaines, ', ctx.data.atom_count, ' atomes, ',
            ctx.data.dbl_count, ' doubles, ', ctx.data.fd_count,
            ' fonctions, ', ctx.data.cd_count, ' classes), .data ',
            ctx.data.dt_size, ' octets (', ctx.data.global_count,
            ' globales), ', ctx.data.reloc_count, ' relocations');
  BuildDataPool := ctx.data.built And (ctx.errors = 0);
End;

{ ---- Affichage du pool (option -data) ---- }

Function DataSecName(sec: Integer): TString;
Begin
  If sec = SEC_RDATA Then
    DataSecName := '.rdata'
  Else
    DataSecName := '.data';
End;

Procedure PrintQuoted(Var ctx: TCompilerContext; id: LongInt);
Var
  i, n: LongInt;
  c: Char;
Begin
  n := ctx.data.strs[id].len;
  Write('"');
  For i := 0 To n - 1 Do
    Begin
      If i >= 40 Then
        Begin
          Write('...');
          Break;
        End;
      c := ctx.data.dpool[ctx.data.strs[id].off + i];
      If c = #10 Then
        Write('\n')
      Else If c < ' ' Then
        Write('?')
      Else
        Write(c);
    End;
  Write('"');
End;

Procedure DumpDataPool(Var ctx: TCompilerContext);
Var
  i, j, k: LongInt;
  fl: LongInt;
  line: LongInt;
Begin
  If Not ctx.data.built Then
    Exit;
  Writeln('Pool de donnees :');
  Writeln('  .rdata ', ctx.data.rd_size, ' octets, .data ', ctx.data.dt_size,
          ' octets, ', ctx.data.sym_count, ' symboles, ', ctx.data.reloc_count,
          ' relocations');
  Writeln('  Chaines (', ctx.data.str_count, ') :');
  For i := 1 To ctx.data.str_count Do
    Begin
      Write('    ', SymStr(i), ' ', DataSecName(ctx.data.syms[ctx.data.strs[i].sym].sec),
            '+', ctx.data.syms[ctx.data.strs[i].sym].ofs, ' ');
      PrintQuoted(ctx, i);
      Write(' len=', ctx.data.strs[i].len);
      If ctx.data.strs[i].atom_id <> 0 Then
        Write(' atome#', ctx.data.strs[i].atom_id);
      Writeln;
    End;
  Writeln('  Doubles (', ctx.data.dbl_count, ') :');
  For i := 1 To ctx.data.dbl_count Do
    Writeln('    ', SymDbl(i), ' hi=', RtHex4(ctx.data.dbls[i].hi Shr 16),
            RtHex4(ctx.data.dbls[i].hi), ' lo=', RtHex4(ctx.data.dbls[i].lo Shr 16),
            RtHex4(ctx.data.dbls[i].lo));
  Writeln('  Descripteurs de fonctions (', ctx.data.fd_count, ') :');
  For i := 1 To ctx.data.fd_count Do
    Begin
      fl := ctx.data.fdescs[i].flags;
      Write('    ', SymFdesc(i), ' nom=');
      PrintQuoted(ctx, ctx.data.fdescs[i].name_str);
      Write(' params=', ctx.data.fdescs[i].nparams, ' cellules=',
            ctx.data.fdescs[i].ncells, ' code=', ctx.data.fdescs[i].code_sym);
      If fl And FDF_ARROW <> 0 Then Write(' fleche');
      If fl And FDF_ASYNC <> 0 Then Write(' async');
      If fl And FDF_GENERATOR <> 0 Then Write(' generateur');
      If fl And FDF_METHOD <> 0 Then Write(' methode');
      If fl And FDF_CTOR <> 0 Then Write(' constructeur');
      If fl And FDF_DERIVED <> 0 Then Write(' derive');
      If fl And FDF_STATIC <> 0 Then Write(' statique');
      If fl And FDF_GETTER <> 0 Then Write(' get');
      If fl And FDF_SETTER <> 0 Then Write(' set');
      If fl And FDF_USES_THIS <> 0 Then Write(' this');
      If fl And FDF_USES_ARGS <> 0 Then Write(' arguments');
      If fl And FDF_THIS_CAPTURED <> 0 Then Write(' this-capture');
      If fl And FDF_FIELD_INIT <> 0 Then Write(' champ');
      If fl And FDF_STATIC_BLOCK <> 0 Then Write(' bloc-statique');
      Writeln;
    End;
  Writeln('  Classes (', ctx.data.cd_count, ') :');
  For i := 1 To ctx.data.cd_count Do
    Begin
      Write('    ', SymClassDesc(i), ' nom=');
      PrintQuoted(ctx, ctx.data.cdescs[i].name_str);
      Write(' membres=', ctx.data.cdescs[i].member_count);
      If ctx.data.cdescs[i].flags And CDF_DERIVED <> 0 Then
        Write(' derivee');
      If ctx.data.cdescs[i].ctor_fd <> 0 Then
        Write(' ctor=', SymFdesc(ctx.data.cdescs[i].ctor_fd));
      Writeln;
      For j := 0 To ctx.data.cdescs[i].member_count - 1 Do
        Begin
          k := ctx.data.cdescs[i].first_member + j;
          fl := ctx.data.cmembers[k].flags;
          Write('      ');
          If ctx.data.cmembers[k].key_str <> 0 Then
            PrintQuoted(ctx, ctx.data.cmembers[k].key_str)
          Else
            Write('(sans cle)');
          If fl And CM_STATIC <> 0 Then Write(' statique');
          If fl And CM_METHOD <> 0 Then Write(' methode');
          If fl And CM_FIELD <> 0 Then Write(' champ');
          If fl And CM_GETTER <> 0 Then Write(' get');
          If fl And CM_SETTER <> 0 Then Write(' set');
          If fl And CM_CTOR <> 0 Then Write(' constructeur');
          If fl And CM_COMPUTED <> 0 Then Write(' calcule');
          If fl And CM_STATIC_BLOCK <> 0 Then Write(' bloc-statique');
          If ctx.data.cmembers[k].fd <> 0 Then
            Write(' ', SymFdesc(ctx.data.cmembers[k].fd));
          Writeln;
        End;
    End;
  Writeln('  Atomes : ', ctx.data.atom_count, ' dans _JSATOMS (.rdata+',
          ctx.data.syms[ctx.data.atom_table_sym].ofs, ')');
  Writeln('  Donnees (.data) :');
  For i := 1 To ctx.data.sym_count Do
    If ctx.data.syms[i].sec = SEC_DATA Then
      Writeln('    ', ctx.data.syms[i].name, ' .data+', ctx.data.syms[i].ofs,
              ' (', ctx.data.syms[i].size, ' octets)');
  Writeln('  Octets .rdata (debut) :');
  i := 0;
  line := 0;
  While (i < ctx.data.rd_size) And (line < 24) Do
    Begin
      Write('    ', RtHex4(i), ':');
      For j := 0 To 15 Do
        If i + j < ctx.data.rd_size Then
          Write(' ', Copy(RtHex4(ctx.data.rd[i + j]), 3, 2));
      Writeln;
      Inc(i, 16);
      Inc(line);
    End;
End;

{ ============================================================
  TODO 9 - CODE 80386 DES VARIABLES ET DES PORTEES

  Representation intermediaire (IR) : une liste d'instructions 80386
  symboliques (mnemonique, deux operandes, etiquettes, commentaires,
  debut et fin de procedure). Le TODO 22 l'ecrira en texte assembleur
  et le TODO 23 l'encodera en octets COFF ; les routines du runtime sont
  appelees par leur nom (_JSRT_nom) et resolues plus tard.

  Convention : toute expression laisse sa valeur de 8 octets dans
  EDX:EAX (hi:lo). ECX sert de registre de travail. Les routines du
  runtime sont appelees en cdecl, valeurs de 8 octets poussees sur la
  pile (poids fort d'abord), resultat dans EDX:EAX.

  Variables :
    statique   variable globale du programme : [_JSV_nom] dans .data
    locale     emplacement de 8 octets sous EBP : [EBP-8*n]
    cellule    l'emplacement contient un pointeur vers une cellule du
               tas (variable capturee par une fonction imbriquee) ;
               la valeur est a cellule+8
    externe    variable d'une fonction englobante : closure en
               [EBP+8], environnement en closure+12, pointeur de
               cellule en environnement+12+4*(k-1)
  Les symboles lexicaux qui exigent un test TDZ sont ranges avec la
  marque TDZ jusqu'a leur initialisation ; chaque lecture ou ecriture
  teste la marque et appelle _JSRT_throw_tdz.

  Les constructions dont le code est ecrit par les TODO suivants
  (operateurs, appels, controle de flux, fermetures, classes...) sont
  emises comme un commentaire EN ATTENTE, avec la valeur undefined, et
  comptees : le TODO 22 refusera de produire un programme tant qu'il en
  reste.
  ============================================================ }

{ ---- Operandes et instructions ---- }

Function ToLong(v: Int64): LongInt;
Begin
  v := v And $FFFFFFFF;
  If v > 2147483647 Then
    ToLong := v - 4294967296
  Else
    ToLong := v;
End;

Function TagImm(t: LongInt): LongInt;
Begin
  TagImm := ToLong(RT_TAG_BASE + t);
End;

Function RegOp(r: TReg): TOperand;
Var
  o: TOperand;
Begin
  FillChar(o, SizeOf(o), 0);
  o.kind := OD_REG;
  o.reg := r;
  RegOp := o;
End;

Function ImmOp(v: LongInt): TOperand;
Var
  o: TOperand;
Begin
  FillChar(o, SizeOf(o), 0);
  o.kind := OD_IMM;
  o.disp := v;
  ImmOp := o;
End;

Function MemReg(base: TReg; disp: LongInt): TOperand;
Var
  o: TOperand;
Begin
  FillChar(o, SizeOf(o), 0);
  o.kind := OD_MEM;
  o.base := base;
  o.disp := disp;
  MemReg := o;
End;

{ Memoire a l'adresse d'un symbole de donnees (pool) ou externe. }
Function MemSym(symkind, sym, disp: LongInt): TOperand;
Var
  o: TOperand;
Begin
  FillChar(o, SizeOf(o), 0);
  o.kind := OD_MEM;
  o.symkind := symkind;
  o.sym := sym;
  o.disp := disp;
  MemSym := o;
End;

Function AddrSym(symkind, sym: LongInt): TOperand;
Var
  o: TOperand;
Begin
  FillChar(o, SizeOf(o), 0);
  o.kind := OD_ADDR;
  o.symkind := symkind;
  o.sym := sym;
  AddrSym := o;
End;

Function LabelOp(id: LongInt): TOperand;
Var
  o: TOperand;
Begin
  FillChar(o, SizeOf(o), 0);
  o.kind := OD_LABEL;
  o.disp := id;
  LabelOp := o;
End;

Function NoOp: TOperand;
Var
  o: TOperand;
Begin
  FillChar(o, SizeOf(o), 0);
  NoOp := o;
End;

Procedure Emit(Var ctx: TCompilerContext; op: TOpc; a, b: TOperand);
Begin
  If ctx.ir.count >= MAX_INSTR Then
    Begin
      If Not ctx.ir.failed Then
        PipelineError(ctx, 'trop d''instructions generees');
      ctx.ir.failed := True;
      Exit;
    End;
  Inc(ctx.ir.count);
  ctx.ir.instrs[ctx.ir.count].op := op;
  ctx.ir.instrs[ctx.ir.count].a := a;
  ctx.ir.instrs[ctx.ir.count].b := b;
  ctx.ir.instrs[ctx.ir.count].line := ctx.ir.cur_line;
End;

Procedure Emit0(Var ctx: TCompilerContext; op: TOpc);
Begin
  Emit(ctx, op, NoOp, NoOp);
End;

Procedure Emit1(Var ctx: TCompilerContext; op: TOpc; a: TOperand);
Begin
  Emit(ctx, op, a, NoOp);
End;

Function NewLabel(Var ctx: TCompilerContext): LongInt;
Begin
  Inc(ctx.ir.label_count);
  NewLabel := ctx.ir.label_count;
End;

Procedure PlaceLabel(Var ctx: TCompilerContext; id: LongInt);
Begin
  Emit1(ctx, OP_LABEL, LabelOp(id));
End;

Procedure EmitComment(Var ctx: TCompilerContext; Const text: TString);
Begin
  If ctx.ir.comment_count >= MAX_COMMENTS Then
    Exit;
  Inc(ctx.ir.comment_count);
  ctx.ir.comments[ctx.ir.comment_count] := text;
  Emit1(ctx, OP_COMMENT, ImmOp(ctx.ir.comment_count));
End;

{ Symbole externe ou de code, retrouve par son nom. }
Function XSym(Var ctx: TCompilerContext; Const name: TString): LongInt;
Var
  i: LongInt;
Begin
  For i := 1 To ctx.ir.xsym_count Do
    If ctx.ir.xsyms[i].name = name Then
      Begin
        XSym := i;
        Exit;
      End;
  XSym := 0;
  If ctx.ir.xsym_count >= MAX_XSYMS Then
    Begin
      PipelineError(ctx, 'trop de symboles externes');
      Exit;
    End;
  Inc(ctx.ir.xsym_count);
  ctx.ir.xsyms[ctx.ir.xsym_count].name := name;
  ctx.ir.xsyms[ctx.ir.xsym_count].defined := False;
  ctx.ir.xsyms[ctx.ir.xsym_count].runtime := False;
  XSym := ctx.ir.xsym_count;
End;

{ Appel d'une routine du runtime : nargbytes octets d'arguments a retirer. }
Procedure CallRt(Var ctx: TCompilerContext; Const name: TString; nargbytes: LongInt);
Begin
  Emit1(ctx, OP_CALL, AddrSym(SYMK_X, XSym(ctx, SymRt(name))));
  If nargbytes > 0 Then
    Emit(ctx, OP_ADD, RegOp(R_ESP), ImmOp(nargbytes));
End;

Procedure LoadUndefined(Var ctx: TCompilerContext);
Begin
  Emit(ctx, OP_XOR, RegOp(R_EAX), RegOp(R_EAX));
  Emit(ctx, OP_MOV, RegOp(R_EDX), ImmOp(TagImm(RT_T_UNDEFINED)));
End;

{ ---- Disposition des trames ---- }

Procedure LayoutFrames(Var ctx: TCompilerContext);
Var
  i, fs: LongInt;
Begin
  For i := 1 To ctx.sem.scope_count Do
    Begin
      ctx.sem.scopes[i].nslots := 0;
      ctx.sem.scopes[i].args_slot := 0;
    End;
  For i := 1 To ctx.sem.sym_count Do
    Begin
      ctx.sem.syms[i].slot := 0;
      If ctx.sem.syms[i].flags And SF_STATIC = 0 Then
        Begin
          fs := ctx.sem.scopes[ctx.sem.syms[i].scope].func;
          Inc(ctx.sem.scopes[fs].nslots);
          ctx.sem.syms[i].slot := ctx.sem.scopes[fs].nslots;
        End;
    End;
End;

Function AllocTemp(Var ctx: TCompilerContext): LongInt;
Begin
  Inc(ctx.sem.scopes[ctx.ir.cg_fs].nslots);
  AllocTemp := ctx.sem.scopes[ctx.ir.cg_fs].nslots;
End;

Function SlotDisp(slot: LongInt): LongInt;
Begin
  SlotDisp := -RT_VALUE_SIZE * slot;
End;

{ Position de sy dans l'environnement de la fonction fs (1 = premier). }
Function CapIndex(Var ctx: TCompilerContext; fs, sy: LongInt): LongInt;
Var
  i, k: LongInt;
Begin
  k := 0;
  CapIndex := 0;
  For i := 1 To ctx.sem.cap_count Do
    If ctx.sem.caps[i].fscope = fs Then
      Begin
        Inc(k);
        If ctx.sem.caps[i].sym = sy Then
          Begin
            CapIndex := k;
            Exit;
          End;
      End;
End;

{ ---- Acces aux symboles ---- }

{ Operandes memoire des deux moities (lo, hi) de la valeur du symbole.
  Peut emettre du code qui charge ECX (cellule ou environnement). }
Procedure SymAccess(Var ctx: TCompilerContext; sy: LongInt; Var lo, hi: TOperand);
Var
  sf, k: LongInt;
Begin
  sf := ctx.sem.scopes[ctx.sem.syms[sy].scope].func;
  If ctx.sem.syms[sy].flags And SF_STATIC <> 0 Then
    Begin
      lo := MemSym(SYMK_D, ctx.sem.syms[sy].ds, 0);
      hi := MemSym(SYMK_D, ctx.sem.syms[sy].ds, 4);
    End
  Else If sf = ctx.ir.cg_fs Then
    Begin
      If ctx.sem.syms[sy].flags And SF_CELL <> 0 Then
        Begin
          Emit(ctx, OP_MOV, RegOp(R_ECX),
               MemReg(R_EBP, SlotDisp(ctx.sem.syms[sy].slot)));
          lo := MemReg(R_ECX, RT_CELL_VALUE);
          hi := MemReg(R_ECX, RT_CELL_VALUE + 4);
        End
      Else
        Begin
          lo := MemReg(R_EBP, SlotDisp(ctx.sem.syms[sy].slot));
          hi := MemReg(R_EBP, SlotDisp(ctx.sem.syms[sy].slot) + 4);
        End;
    End
  Else
    Begin
      k := CapIndex(ctx, ctx.ir.cg_fs, sy);
      If k = 0 Then
        Begin
          PipelineError(ctx, 'capture introuvable pour ' +
                        ctx.lex.tokens[ctx.sem.syms[sy].name_tok].text);
          k := 1;
        End;
      Emit(ctx, OP_MOV, RegOp(R_ECX), MemReg(R_EBP, RT_FRAME_CLOSURE));
      Emit(ctx, OP_MOV, RegOp(R_ECX), MemReg(R_ECX, RT_FN_ENV));
      Emit(ctx, OP_MOV, RegOp(R_ECX),
           MemReg(R_ECX, RT_ENV_CELLS + 4 * (k - 1)));
      lo := MemReg(R_ECX, RT_CELL_VALUE);
      hi := MemReg(R_ECX, RT_CELL_VALUE + 4);
    End;
End;

{ Leve ReferenceError si la valeur d'octet haut hi est la marque TDZ. }
Procedure TdzCheck(Var ctx: TCompilerContext; sy: LongInt; hi: TOperand);
Var
  ok: LongInt;
Begin
  ok := NewLabel(ctx);
  Emit(ctx, OP_CMP, hi, ImmOp(TagImm(RT_T_TDZ)));
  Emit1(ctx, OP_JNE, LabelOp(ok));
  Emit1(ctx, OP_PUSH, AddrSym(SYMK_D, ctx.data.strs[ctx.sem.syms[sy].name_str].sym));
  CallRt(ctx, 'throw_tdz', 4);
  PlaceLabel(ctx, ok);
End;

Procedure LoadSym(Var ctx: TCompilerContext; sy: LongInt);
Var
  lo, hi: TOperand;
Begin
  SymAccess(ctx, sy, lo, hi);
  Emit(ctx, OP_MOV, RegOp(R_EAX), lo);
  Emit(ctx, OP_MOV, RegOp(R_EDX), hi);
  If ctx.sem.syms[sy].flags And SF_TDZ_CHECK <> 0 Then
    TdzCheck(ctx, sy, RegOp(R_EDX));
End;

{ Range EDX:EAX dans le symbole. init : premiere initialisation (pas de
  test TDZ). }
Procedure StoreSym(Var ctx: TCompilerContext; sy: LongInt; init: Boolean);
Var
  lo, hi: TOperand;
Begin
  If (ctx.sem.syms[sy].kind = DK_FNAME) And Not init Then
    Exit;
  SymAccess(ctx, sy, lo, hi);
  If (Not init) And (ctx.sem.syms[sy].flags And SF_TDZ_CHECK <> 0) Then
    TdzCheck(ctx, sy, hi);
  Emit(ctx, OP_MOV, lo, RegOp(R_EAX));
  Emit(ctx, OP_MOV, hi, RegOp(R_EDX));
End;

{ ---- Constructions en attente ---- }

Procedure PendingNote(Var ctx: TCompilerContext; n: LongInt; Const what: TString);
Begin
  Inc(ctx.ir.pending_count);
  If ctx.ir.pending_count <= MAX_PENDING Then
    Begin
      ctx.ir.pendings[ctx.ir.pending_count].line :=
        ctx.lex.tokens[ctx.ast.nodes[n].tok].line;
      ctx.ir.pendings[ctx.ir.pending_count].what := what;
    End;
  EmitComment(ctx, 'EN ATTENTE : ' + what + ' (ligne ' +
              LineOfTok(ctx, ctx.ast.nodes[n].tok) + ')');
End;

Procedure PendingExpr(Var ctx: TCompilerContext; n: LongInt);
Var
  what: TString;
Begin
  what := NodeKindName(ctx.ast.nodes[n].kind);
  Case ctx.ast.nodes[n].kind Of
    N_UNARY, N_BINARY, N_LOGICAL, N_ASSIGN, N_UPDATE:
      what := what + ' ' + ctx.lex.tokens[ctx.ast.nodes[n].tok].text;
  End;
  PendingNote(ctx, n, what);
  LoadUndefined(ctx);
End;

{ ---- Expressions prises en charge par ce TODO ---- }

Procedure GenExpr(Var ctx: TCompilerContext; n: LongInt); Forward;
Procedure BindTo(Var ctx: TCompilerContext; node, tslot: LongInt; init: Boolean); Forward;
Procedure GenScopeEnter(Var ctx: TCompilerContext; sc: LongInt); Forward;

Procedure LoadTag(Var ctx: TCompilerContext; lo: LongInt; tag: LongInt);
Begin
  If lo = 0 Then
    Emit(ctx, OP_XOR, RegOp(R_EAX), RegOp(R_EAX))
  Else
    Emit(ctx, OP_MOV, RegOp(R_EAX), ImmOp(lo));
  Emit(ctx, OP_MOV, RegOp(R_EDX), ImmOp(TagImm(tag)));
End;

Procedure LoadDouble(Var ctx: TCompilerContext; id: LongInt);
Begin
  Emit(ctx, OP_MOV, RegOp(R_EAX), MemSym(SYMK_D, ctx.data.dbls[id].sym, 0));
  Emit(ctx, OP_MOV, RegOp(R_EDX), MemSym(SYMK_D, ctx.data.dbls[id].sym, 4));
End;

Procedure LoadStringConst(Var ctx: TCompilerContext; id: LongInt);
Begin
  Emit(ctx, OP_MOV, RegOp(R_EAX), AddrSym(SYMK_D, ctx.data.strs[id].sym));
  Emit(ctx, OP_MOV, RegOp(R_EDX), ImmOp(TagImm(RT_T_STRING)));
End;

Procedure GenThis(Var ctx: TCompilerContext; n: LongInt);
Begin
  If ctx.ast.nodes[n].aux = TB_GLOBAL Then
    LoadUndefined(ctx)
  Else If ctx.ast.nodes[n].e1 = 1 Then
    Begin
      { fleche : this lexical memorise dans la closure }
      Emit(ctx, OP_MOV, RegOp(R_ECX), MemReg(R_EBP, RT_FRAME_CLOSURE));
      Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_ECX, RT_FN_THIS));
      Emit(ctx, OP_MOV, RegOp(R_EDX), MemReg(R_ECX, RT_FN_THIS + 4));
    End
  Else
    Begin
      Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_EBP, RT_FRAME_THIS));
      Emit(ctx, OP_MOV, RegOp(R_EDX), MemReg(R_EBP, RT_FRAME_THIS + 4));
    End;
End;

Procedure GenIdent(Var ctx: TCompilerContext; n: LongInt);
Var
  name: TTokenText;
  xs: LongInt;
Begin
  name := ctx.lex.tokens[ctx.ast.nodes[n].tok].text;
  Case ctx.ast.nodes[n].aux Of
    RK_LOCAL, RK_OUTER, RK_GLOBAL_IMPLICIT:
      LoadSym(ctx, ctx.ast.nodes[n].sym);
    RK_BUILTIN:
      Begin
        If name = 'undefined' Then
          LoadUndefined(ctx)
        Else If name = 'NaN' Then
          LoadDouble(ctx, STD_DBL_NAN)
        Else If name = 'Infinity' Then
          LoadDouble(ctx, STD_DBL_INF)
        Else
          Begin
            { objet global fourni par le runtime }
            xs := XSym(ctx, SymRt('g_' + name));
            Emit(ctx, OP_MOV, RegOp(R_EAX), MemSym(SYMK_X, xs, 0));
            Emit(ctx, OP_MOV, RegOp(R_EDX), MemSym(SYMK_X, xs, 4));
          End;
      End;
    RK_UNDECLARED_OK:
      LoadUndefined(ctx);
    RK_ARGUMENTS:
      Begin
        If ctx.sem.scopes[ctx.ir.cg_fs].args_slot <> 0 Then
          Begin
            Emit(ctx, OP_MOV, RegOp(R_EAX),
                 MemReg(R_EBP, SlotDisp(ctx.sem.scopes[ctx.ir.cg_fs].args_slot)));
            Emit(ctx, OP_MOV, RegOp(R_EDX),
                 MemReg(R_EBP, SlotDisp(ctx.sem.scopes[ctx.ir.cg_fs].args_slot) + 4));
          End
        Else
          PendingExpr(ctx, n);
      End;
  Else
    PendingExpr(ctx, n);
  End;
End;

Procedure PushTemp(Var ctx: TCompilerContext; slot: LongInt); Forward;

{ ---- Expressions (TODO 10) ----

  Strategie : une operation arithmetique, bit a bit ou relationnelle
  dont les deux operandes sont des int32 s'execute en ligne (add, sub,
  imul avec test de depassement, idiv, decalages, cmp). Dans tous les
  autres cas (double, chaine, objet, depassement, -0) le code appelle
  la routine du runtime de meme nom : _JSRT_add, _JSRT_sub, _JSRT_div,
  _JSRT_pow, _JSRT_lt, _JSRT_eq... qui appliquent ToPrimitive,
  ToNumber et ToString. Le runtime calcule en double avec le FPU
  (division par zero = Infinity ou NaN).

  Operande gauche : rangee dans un temporaire de la trame pendant que
  l'operande droit est evalue (la droite arrive dans EDX:EAX). Les
  routines du runtime recoivent (gauche, droite) en cdecl.

  Les expressions entierement constantes sont repliees a la
  compilation quand le resultat est un int32, un booleen, null ou
  undefined ; sinon le code ordinaire est genere. }

Function TempAcquire(Var ctx: TCompilerContext): LongInt;
Begin
  If ctx.ir.tmp_free_count > 0 Then
    Begin
      TempAcquire := ctx.ir.tmp_free[ctx.ir.tmp_free_count];
      Dec(ctx.ir.tmp_free_count);
    End
  Else
    TempAcquire := AllocTemp(ctx);
End;

Procedure TempRelease(Var ctx: TCompilerContext; t: LongInt);
Begin
  If ctx.ir.tmp_free_count < 64 Then
    Begin
      Inc(ctx.ir.tmp_free_count);
      ctx.ir.tmp_free[ctx.ir.tmp_free_count] := t;
    End;
End;

Procedure SaveTemp(Var ctx: TCompilerContext; t: LongInt);
Begin
  Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(t)), RegOp(R_EAX));
  Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(t) + 4), RegOp(R_EDX));
End;

Procedure LoadTemp(Var ctx: TCompilerContext; t: LongInt);
Begin
  Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_EBP, SlotDisp(t)));
  Emit(ctx, OP_MOV, RegOp(R_EDX), MemReg(R_EBP, SlotDisp(t) + 4));
End;

Function TempLo(t: LongInt): TOperand;
Begin
  TempLo := MemReg(R_EBP, SlotDisp(t));
End;

Function TempHi(t: LongInt): TOperand;
Begin
  TempHi := MemReg(R_EBP, SlotDisp(t) + 4);
End;

{ EAX := 0 ou 1 selon la verite de EDX:EAX (ToBoolean). }
Procedure GenTruthy(Var ctx: TCompilerContext);
Var
  num, fls, done: LongInt;
Begin
  num := NewLabel(ctx);
  fls := NewLabel(ctx);
  done := NewLabel(ctx);
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
  Emit1(ctx, OP_JE, LabelOp(num));
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_BOOLEAN)));
  Emit1(ctx, OP_JE, LabelOp(num));
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_UNDEFINED)));
  Emit1(ctx, OP_JE, LabelOp(fls));
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_NULL)));
  Emit1(ctx, OP_JE, LabelOp(fls));
  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
  CallRt(ctx, 'truthy', 8);
  Emit1(ctx, OP_JMP, LabelOp(done));
  PlaceLabel(ctx, num);
  Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
  Emit1(ctx, OP_JE, LabelOp(fls));
  Emit(ctx, OP_MOV, RegOp(R_EAX), ImmOp(1));
  Emit1(ctx, OP_JMP, LabelOp(done));
  PlaceLabel(ctx, fls);
  Emit(ctx, OP_XOR, RegOp(R_EAX), RegOp(R_EAX));
  PlaceLabel(ctx, done);
End;

{ EAX = 0/1 vers un booleen JavaScript dans EDX:EAX. }
Procedure BoolFromEax(Var ctx: TCompilerContext);
Begin
  Emit(ctx, OP_MOV, RegOp(R_EDX), ImmOp(TagImm(RT_T_BOOLEAN)));
End;

{ Appel d'une routine binaire (gauche = temporaire t, droite = EDX:EAX). }
Procedure CallBinary(Var ctx: TCompilerContext; Const name: TString; t: LongInt);
Begin
  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
  PushTemp(ctx, t);
  CallRt(ctx, name, 16);
End;

{ Saute vers slow si l'un des deux operandes (gauche en t, droite dans
  EDX) n'est pas un int32. }
Procedure CheckBothInt(Var ctx: TCompilerContext; t, slow: LongInt);
Begin
  Emit(ctx, OP_CMP, TempHi(t), ImmOp(TagImm(RT_T_INT32)));
  Emit1(ctx, OP_JNE, LabelOp(slow));
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
  Emit1(ctx, OP_JNE, LabelOp(slow));
End;

{ Operation binaire op : gauche dans le temporaire t, droite dans
  EDX:EAX. Resultat dans EDX:EAX. t n'est pas libere. }
Procedure GenBinaryCore(Var ctx: TCompilerContext; Const op: TTokenText; t: LongInt);
Var
  slow, done, okm, slowr, lb: LongInt;
  opc, jcc: TOpc;
  rt: TString;
  flip, is_shift, is_bit, is_cmp: Boolean;
Begin
  slow := NewLabel(ctx);
  done := NewLabel(ctx);
  rt := '';
  flip := False;
  is_shift := False;
  is_bit := False;
  is_cmp := False;
  opc := OP_NONE;
  jcc := OP_NONE;
  If op = '+' Then
    Begin
      rt := 'add';
      opc := OP_ADD;
    End
  Else If op = '-' Then
    Begin
      rt := 'sub';
      opc := OP_SUB;
    End
  Else If op = '*' Then
    rt := 'mul'
  Else If op = '/' Then
    rt := 'div'
  Else If op = '%' Then
    rt := 'mod'
  Else If op = '**' Then
    rt := 'pow'
  Else If op = '&' Then
    Begin
      rt := 'band';
      opc := OP_AND;
      is_bit := True;
    End
  Else If op = '|' Then
    Begin
      rt := 'bor';
      opc := OP_OR;
      is_bit := True;
    End
  Else If op = '^' Then
    Begin
      rt := 'bxor';
      opc := OP_XOR;
      is_bit := True;
    End
  Else If op = '<<' Then
    Begin
      rt := 'shl';
      opc := OP_SHL;
      is_shift := True;
    End
  Else If op = '>>' Then
    Begin
      rt := 'sar';
      opc := OP_SAR;
      is_shift := True;
    End
  Else If op = '>>>' Then
    Begin
      rt := 'shr';
      opc := OP_SHR;
      is_shift := True;
    End
  Else If op = '<' Then
    Begin
      rt := 'lt';
      jcc := OP_JL;
      is_cmp := True;
    End
  Else If op = '<=' Then
    Begin
      rt := 'le';
      jcc := OP_JLE;
      is_cmp := True;
    End
  Else If op = '>' Then
    Begin
      rt := 'gt';
      jcc := OP_JG;
      is_cmp := True;
    End
  Else If op = '>=' Then
    Begin
      rt := 'ge';
      jcc := OP_JGE;
      is_cmp := True;
    End
  Else If op = '==' Then
    Begin
      rt := 'eq';
      jcc := OP_JE;
      is_cmp := True;
    End
  Else If op = '!=' Then
    Begin
      rt := 'eq';
      jcc := OP_JNE;
      is_cmp := True;
      flip := True;
    End
  Else If op = '===' Then
    Begin
      rt := 'seq';
      jcc := OP_JE;
      is_cmp := True;
    End
  Else If op = '!==' Then
    Begin
      rt := 'seq';
      jcc := OP_JNE;
      is_cmp := True;
      flip := True;
    End
  Else If op = 'instanceof' Then
    rt := 'instanceof'
  Else If op = 'in' Then
    rt := 'in'
  Else
    Begin
      PipelineError(ctx, 'operateur binaire inconnu: ' + op);
      Exit;
    End;

  If (opc = OP_ADD) Or (opc = OP_SUB) Then
    Begin
      { int32 avec test de depassement }
      CheckBothInt(ctx, t, slow);
      Emit(ctx, OP_MOV, RegOp(R_ECX), TempLo(t));
      Emit(ctx, opc, RegOp(R_ECX), RegOp(R_EAX));
      Emit1(ctx, OP_JO, LabelOp(slow));
      Emit(ctx, OP_MOV, RegOp(R_EAX), RegOp(R_ECX));
      Emit1(ctx, OP_JMP, LabelOp(done));
    End
  Else If op = '*' Then
    Begin
      okm := NewLabel(ctx);
      CheckBothInt(ctx, t, slow);
      Emit(ctx, OP_MOV, RegOp(R_ECX), TempLo(t));
      Emit(ctx, OP_IMUL, RegOp(R_ECX), RegOp(R_EAX));
      Emit1(ctx, OP_JO, LabelOp(slow));
      Emit(ctx, OP_TEST, RegOp(R_ECX), RegOp(R_ECX));
      Emit1(ctx, OP_JNE, LabelOp(okm));
      { resultat 0 : -0 si un operande est negatif }
      Emit(ctx, OP_MOV, RegOp(R_ECX), TempLo(t));
      Emit(ctx, OP_OR, RegOp(R_ECX), RegOp(R_EAX));
      Emit1(ctx, OP_JS, LabelOp(slow));
      Emit(ctx, OP_XOR, RegOp(R_ECX), RegOp(R_ECX));
      PlaceLabel(ctx, okm);
      Emit(ctx, OP_MOV, RegOp(R_EAX), RegOp(R_ECX));
      Emit1(ctx, OP_JMP, LabelOp(done));
    End
  Else If op = '%' Then
    Begin
      okm := NewLabel(ctx);
      slowr := NewLabel(ctx);
      CheckBothInt(ctx, t, slow);
      Emit(ctx, OP_MOV, RegOp(R_ECX), RegOp(R_EAX));
      Emit(ctx, OP_TEST, RegOp(R_ECX), RegOp(R_ECX));
      Emit1(ctx, OP_JE, LabelOp(slow));
      Emit(ctx, OP_CMP, RegOp(R_ECX), ImmOp(-1));
      Emit1(ctx, OP_JE, LabelOp(slow));
      Emit(ctx, OP_MOV, RegOp(R_EAX), TempLo(t));
      Emit0(ctx, OP_CDQ);
      Emit1(ctx, OP_IDIV, RegOp(R_ECX));
      Emit(ctx, OP_TEST, RegOp(R_EDX), RegOp(R_EDX));
      Emit1(ctx, OP_JNE, LabelOp(okm));
      { reste 0 : -0 si le dividende est negatif }
      Emit(ctx, OP_CMP, TempLo(t), ImmOp(0));
      Emit1(ctx, OP_JL, LabelOp(slowr));
      PlaceLabel(ctx, okm);
      Emit(ctx, OP_MOV, RegOp(R_EAX), RegOp(R_EDX));
      Emit(ctx, OP_MOV, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
      Emit1(ctx, OP_JMP, LabelOp(done));
      PlaceLabel(ctx, slowr);
      Emit(ctx, OP_MOV, RegOp(R_EAX), RegOp(R_ECX));
      Emit(ctx, OP_MOV, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
    End
  Else If is_bit Then
    Begin
      CheckBothInt(ctx, t, slow);
      Emit(ctx, OP_MOV, RegOp(R_ECX), TempLo(t));
      Emit(ctx, opc, RegOp(R_ECX), RegOp(R_EAX));
      Emit(ctx, OP_MOV, RegOp(R_EAX), RegOp(R_ECX));
      Emit1(ctx, OP_JMP, LabelOp(done));
    End
  Else If is_shift Then
    Begin
      CheckBothInt(ctx, t, slow);
      Emit(ctx, OP_MOV, RegOp(R_ECX), RegOp(R_EAX));
      Emit(ctx, OP_MOV, RegOp(R_EAX), TempLo(t));
      Emit(ctx, opc, RegOp(R_EAX), RegOp(R_CL));
      If op = '>>>' Then
        Begin
          { hors int32 si le bit de signe est positionne : repli }
          slowr := NewLabel(ctx);
          Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
          Emit1(ctx, OP_JS, LabelOp(slowr));
          Emit1(ctx, OP_JMP, LabelOp(done));
          PlaceLabel(ctx, slowr);
          Emit(ctx, OP_MOV, RegOp(R_EAX), RegOp(R_ECX));
          Emit(ctx, OP_MOV, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
        End
      Else
        Emit1(ctx, OP_JMP, LabelOp(done));
    End
  Else If is_cmp Then
    Begin
      lb := NewLabel(ctx);
      CheckBothInt(ctx, t, slow);
      Emit(ctx, OP_MOV, RegOp(R_ECX), TempLo(t));
      Emit(ctx, OP_CMP, RegOp(R_ECX), RegOp(R_EAX));
      Emit(ctx, OP_MOV, RegOp(R_EAX), ImmOp(1));
      Emit1(ctx, jcc, LabelOp(lb));
      Emit(ctx, OP_XOR, RegOp(R_EAX), RegOp(R_EAX));
      PlaceLabel(ctx, lb);
      BoolFromEax(ctx);
      Emit1(ctx, OP_JMP, LabelOp(done));
    End
  ;

  PlaceLabel(ctx, slow);
  CallBinary(ctx, rt, t);
  If flip Then
    Begin
      Emit(ctx, OP_XOR, RegOp(R_EAX), ImmOp(1));
      BoolFromEax(ctx);
    End;
  PlaceLabel(ctx, done);
End;

{ ---- Repli de constantes ---- }

Function ToInt32Of(v: Double): LongInt;
Var
  w: Int64;
Begin
  If (v <> v) Or (v > 9.0E15) Or (v < -9.0E15) Then
    ToInt32Of := 0
  Else
    Begin
      w := Trunc(v);
      ToInt32Of := ToLong(w);
    End;
End;

Function IsNegZero(v: Double): Boolean;
Var
  w: Array[0..1] Of LongInt;
Begin
  Move(v, w, 8);
  IsNegZero := (v = 0) And (w[1] < 0);
End;

Function ConstTruthy(Var c: TConst): Boolean;
Begin
  Case c.k Of
    CK_NUM:  ConstTruthy := (c.n <> 0) And (c.n = c.n);
    CK_BOOL: ConstTruthy := c.b;
  Else
    ConstTruthy := False;
  End;
End;

Function EvalConst(Var ctx: TCompilerContext; n: LongInt; Var c: TConst): Boolean;
Var
  a, b: TConst;
  s: TTokenText;
  x, y: Double;
  ix, iy: Int64;
  r: Boolean;
Begin
  EvalConst := False;
  c.k := CK_NONE;
  If n = 0 Then
    Exit;
  Case ctx.ast.nodes[n].kind Of
    N_NUMBER:
      Begin
        c.k := CK_NUM;
        c.n := ctx.lex.tokens[ctx.ast.nodes[n].tok].num_val;
        EvalConst := True;
      End;
    N_BOOL:
      Begin
        c.k := CK_BOOL;
        c.b := ctx.lex.tokens[ctx.ast.nodes[n].tok].text = 'true';
        EvalConst := True;
      End;
    N_NULL:
      Begin
        c.k := CK_NULL;
        EvalConst := True;
      End;
    N_IDENT:
      If (ctx.ast.nodes[n].aux = RK_BUILTIN) And
         (ctx.lex.tokens[ctx.ast.nodes[n].tok].text = 'undefined') Then
        Begin
          c.k := CK_UNDEF;
          EvalConst := True;
        End;
    N_UNARY:
      Begin
        s := ctx.lex.tokens[ctx.ast.nodes[n].tok].text;
        If Not EvalConst(ctx, ctx.ast.nodes[n].e1, a) Then
          Exit;
        If s = '!' Then
          Begin
            c.k := CK_BOOL;
            c.b := Not ConstTruthy(a);
            EvalConst := True;
          End
        Else If s = 'void' Then
          Begin
            c.k := CK_UNDEF;
            EvalConst := True;
          End
        Else If a.k = CK_NUM Then
          Begin
            If s = '-' Then
              Begin
                c.k := CK_NUM;
                c.n := -a.n;
                EvalConst := True;
              End
            Else If s = '+' Then
              Begin
                c := a;
                EvalConst := True;
              End
            Else If s = '~' Then
              Begin
                c.k := CK_NUM;
                c.n := Not ToInt32Of(a.n);
                EvalConst := True;
              End;
          End;
      End;
    N_BINARY:
      Begin
        s := ctx.lex.tokens[ctx.ast.nodes[n].tok].text;
        If Not (EvalConst(ctx, ctx.ast.nodes[n].e1, a) And
                EvalConst(ctx, ctx.ast.nodes[n].e2, b)) Then
          Exit;
        If (a.k <> CK_NUM) Or (b.k <> CK_NUM) Then
          Exit;
        x := a.n;
        y := b.n;
        If (x <> x) Or (y <> y) Or (Abs(x) > 9.0E15) Or (Abs(y) > 9.0E15) Then
          Exit;
        c.k := CK_NUM;
        r := True;
        If s = '+' Then
          c.n := x + y
        Else If s = '-' Then
          c.n := x - y
        Else If s = '*' Then
          c.n := x * y
        Else If s = '/' Then
          Begin
            If y = 0 Then
              r := False
            Else
              c.n := x / y;
          End
        Else If s = '%' Then
          Begin
            ix := Trunc(x);
            iy := Trunc(y);
            If (ix <> x) Or (iy <> y) Or (iy = 0) Or (ix < 0) Then
              r := False
            Else
              c.n := ix Mod iy;
          End
        Else If s = '**' Then
          Begin
            If (y < 0) Or (y > 62) Or (Int(y) <> y) Or (Int(x) <> x) Or
               (Abs(x) > 65536) Then
              r := False
            Else
              Begin
                c.n := 1;
                ix := Trunc(y);
                While ix > 0 Do
                  Begin
                    c.n := c.n * x;
                    Dec(ix);
                  End;
              End;
          End
        Else If s = '&' Then
          c.n := ToInt32Of(x) And ToInt32Of(y)
        Else If s = '|' Then
          c.n := ToInt32Of(x) Or ToInt32Of(y)
        Else If s = '^' Then
          c.n := ToInt32Of(x) Xor ToInt32Of(y)
        Else If s = '<<' Then
          c.n := ToInt32Of(ToInt32Of(x) Shl (ToInt32Of(y) And 31))
        Else If s = '>>' Then
          Begin
            ix := ToInt32Of(x);
            If ix >= 0 Then
              c.n := ix Shr (ToInt32Of(y) And 31)
            Else
              c.n := Not ((Not ix) Shr (ToInt32Of(y) And 31));
          End
        Else If s = '>>>' Then
          c.n := (Int64(ToInt32Of(x)) And $FFFFFFFF) Shr (ToInt32Of(y) And 31)
        Else If s = '<' Then
          Begin
            c.k := CK_BOOL;
            c.b := x < y;
          End
        Else If s = '<=' Then
          Begin
            c.k := CK_BOOL;
            c.b := x <= y;
          End
        Else If s = '>' Then
          Begin
            c.k := CK_BOOL;
            c.b := x > y;
          End
        Else If s = '>=' Then
          Begin
            c.k := CK_BOOL;
            c.b := x >= y;
          End
        Else If (s = '==') Or (s = '===') Then
          Begin
            c.k := CK_BOOL;
            c.b := x = y;
          End
        Else If (s = '!=') Or (s = '!==') Then
          Begin
            c.k := CK_BOOL;
            c.b := x <> y;
          End
        Else
          r := False;
        EvalConst := r;
      End;
    N_LOGICAL:
      Begin
        s := ctx.lex.tokens[ctx.ast.nodes[n].tok].text;
        If Not EvalConst(ctx, ctx.ast.nodes[n].e1, a) Then
          Exit;
        If s = '&&' Then
          Begin
            If ConstTruthy(a) Then
              EvalConst := EvalConst(ctx, ctx.ast.nodes[n].e2, c)
            Else
              Begin
                c := a;
                EvalConst := True;
              End;
          End
        Else If s = '||' Then
          Begin
            If ConstTruthy(a) Then
              Begin
                c := a;
                EvalConst := True;
              End
            Else
              EvalConst := EvalConst(ctx, ctx.ast.nodes[n].e2, c);
          End
        Else If (a.k = CK_NULL) Or (a.k = CK_UNDEF) Then
          EvalConst := EvalConst(ctx, ctx.ast.nodes[n].e2, c)
        Else
          Begin
            c := a;
            EvalConst := True;
          End;
      End;
    N_COND:
      Begin
        If Not EvalConst(ctx, ctx.ast.nodes[n].e1, a) Then
          Exit;
        If ConstTruthy(a) Then
          EvalConst := EvalConst(ctx, ctx.ast.nodes[n].e2, c)
        Else
          EvalConst := EvalConst(ctx, ctx.ast.nodes[n].e3, c);
      End;
  End;
End;

{ Emet la constante si le programme l'exprime sans nouvelle donnee
  statique : int32 (hors -0), booleen, null ou undefined. }
Function TryFold(Var ctx: TCompilerContext; n: LongInt): Boolean;
Var
  c: TConst;
Begin
  TryFold := False;
  If Not EvalConst(ctx, n, c) Then
    Exit;
  Case c.k Of
    CK_NUM:
      Begin
        If (c.n <> c.n) Or (Int(c.n) <> c.n) Or (c.n < -2147483648.0) Or
           (c.n > 2147483647.0) Or IsNegZero(c.n) Then
          Exit;
        LoadTag(ctx, Trunc(c.n), RT_T_INT32);
      End;
    CK_BOOL:
      Begin
        If c.b Then
          LoadTag(ctx, 1, RT_T_BOOLEAN)
        Else
          LoadTag(ctx, 0, RT_T_BOOLEAN);
      End;
    CK_NULL:
      LoadTag(ctx, 0, RT_T_NULL);
    CK_UNDEF:
      LoadUndefined(ctx);
  Else
    Exit;
  End;
  TryFold := True;
End;

{ ---- Operateurs ---- }

Procedure GenBinary(Var ctx: TCompilerContext; n: LongInt);
Var
  t: LongInt;
Begin
  GenExpr(ctx, ctx.ast.nodes[n].e1);
  t := TempAcquire(ctx);
  SaveTemp(ctx, t);
  GenExpr(ctx, ctx.ast.nodes[n].e2);
  GenBinaryCore(ctx, ctx.lex.tokens[ctx.ast.nodes[n].tok].text, t);
  TempRelease(ctx, t);
End;

{ && || ?? avec court-circuit : le resultat est l'un des operandes. }
Procedure GenLogical(Var ctx: TCompilerContext; n: LongInt);
Var
  t, short, done, evalr: LongInt;
  op: TTokenText;
Begin
  op := ctx.lex.tokens[ctx.ast.nodes[n].tok].text;
  t := TempAcquire(ctx);
  short := NewLabel(ctx);
  done := NewLabel(ctx);
  GenExpr(ctx, ctx.ast.nodes[n].e1);
  SaveTemp(ctx, t);
  If op = '??' Then
    Begin
      evalr := NewLabel(ctx);
      Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_UNDEFINED)));
      Emit1(ctx, OP_JE, LabelOp(evalr));
      Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_NULL)));
      Emit1(ctx, OP_JNE, LabelOp(done));
      PlaceLabel(ctx, evalr);
    End
  Else
    Begin
      GenTruthy(ctx);
      Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
      If op = '&&' Then
        Emit1(ctx, OP_JE, LabelOp(short))
      Else
        Emit1(ctx, OP_JNE, LabelOp(short));
    End;
  GenExpr(ctx, ctx.ast.nodes[n].e2);
  Emit1(ctx, OP_JMP, LabelOp(done));
  PlaceLabel(ctx, short);
  LoadTemp(ctx, t);
  PlaceLabel(ctx, done);
  { sur ?? sans evaluation de la droite, EDX:EAX contient deja la gauche }
  TempRelease(ctx, t);
End;

Procedure GenCond(Var ctx: TCompilerContext; n: LongInt);
Var
  els, done: LongInt;
Begin
  els := NewLabel(ctx);
  done := NewLabel(ctx);
  GenExpr(ctx, ctx.ast.nodes[n].e1);
  GenTruthy(ctx);
  Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
  Emit1(ctx, OP_JE, LabelOp(els));
  GenExpr(ctx, ctx.ast.nodes[n].e2);
  Emit1(ctx, OP_JMP, LabelOp(done));
  PlaceLabel(ctx, els);
  GenExpr(ctx, ctx.ast.nodes[n].e3);
  PlaceLabel(ctx, done);
End;

Procedure GenUnary(Var ctx: TCompilerContext; n: LongInt);
Var
  s: TTokenText;
  e, slow, done, t: LongInt;
Begin
  s := ctx.lex.tokens[ctx.ast.nodes[n].tok].text;
  e := ctx.ast.nodes[n].e1;
  slow := NewLabel(ctx);
  done := NewLabel(ctx);
  If s = '!' Then
    Begin
      GenExpr(ctx, e);
      GenTruthy(ctx);
      Emit(ctx, OP_XOR, RegOp(R_EAX), ImmOp(1));
      BoolFromEax(ctx);
    End
  Else If s = '-' Then
    Begin
      GenExpr(ctx, e);
      Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
      Emit1(ctx, OP_JNE, LabelOp(slow));
      { 0 donne -0 et INT_MIN depasse : repli sur le runtime }
      Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
      Emit1(ctx, OP_JE, LabelOp(slow));
      Emit1(ctx, OP_NEG, RegOp(R_EAX));
      Emit1(ctx, OP_JNO, LabelOp(done));
      PlaceLabel(ctx, slow);
      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
      CallRt(ctx, 'neg', 8);
      PlaceLabel(ctx, done);
    End
  Else If s = '+' Then
    Begin
      GenExpr(ctx, e);
      { int32 et double sont deja des nombres }
      Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
      Emit1(ctx, OP_JBE, LabelOp(done));
      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
      CallRt(ctx, 'tonumber', 8);
      PlaceLabel(ctx, done);
    End
  Else If s = '~' Then
    Begin
      GenExpr(ctx, e);
      Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
      Emit1(ctx, OP_JNE, LabelOp(slow));
      Emit1(ctx, OP_NOT, RegOp(R_EAX));
      Emit1(ctx, OP_JMP, LabelOp(done));
      PlaceLabel(ctx, slow);
      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
      CallRt(ctx, 'bnot', 8);
      PlaceLabel(ctx, done);
    End
  Else If s = 'typeof' Then
    Begin
      GenExpr(ctx, e);
      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
      CallRt(ctx, 'typeof', 8);
    End
  Else If s = 'void' Then
    Begin
      GenExpr(ctx, e);
      LoadUndefined(ctx);
    End
  Else If s = '&' Then
    { operateur de reference &fn (extension) : la valeur de la fonction }
    GenExpr(ctx, e)
  Else If s = 'delete' Then
    Begin
      If (e <> 0) And (ctx.ast.nodes[e].kind = N_MEMBER) Then
        Begin
          GenExpr(ctx, ctx.ast.nodes[e].e1);
          Emit1(ctx, OP_PUSH, AddrSym(SYMK_D,
                ctx.data.strs[ctx.ast.nodes[e].aux].sym));
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          CallRt(ctx, 'delete_prop', 12);
        End
      Else If (e <> 0) And (ctx.ast.nodes[e].kind = N_INDEX) Then
        Begin
          GenExpr(ctx, ctx.ast.nodes[e].e1);
          t := TempAcquire(ctx);
          SaveTemp(ctx, t);
          GenExpr(ctx, ctx.ast.nodes[e].e2);
          CallBinary(ctx, 'delete_member', t);
          TempRelease(ctx, t);
        End
      Else If (e <> 0) And (ctx.ast.nodes[e].kind = N_IDENT) Then
        { une variable ne se supprime pas }
        LoadTag(ctx, 0, RT_T_BOOLEAN)
      Else
        Begin
          GenExpr(ctx, e);
          LoadTag(ctx, 1, RT_T_BOOLEAN);
        End;
    End
  Else
    PendingExpr(ctx, n);
End;

{ ++ et -- sur une variable : le resultat est la nouvelle valeur
  (prefixe) ou l'ancienne valeur convertie en nombre (postfixe). }
{ ---- Cibles membre : objet.nom et objet[cle] en ecriture (TODO 15) ----

  L'objet (et la cle d'un acces par crochets) sont evalues une seule
  fois dans des temporaires ; la valeur courante est lue par
  _JSRT_get_prop / _JSRT_get_member et ecrite par _JSRT_set_prop(objet,
  atome, valeur) ou _JSRT_set_member(objet, cle, valeur), qui rendent la
  valeur ecrite dans EDX:EAX. }

Procedure MemberPrep(Var ctx: TCompilerContext; m: LongInt; Var tobj, tkey: LongInt);
Begin
  tobj := TempAcquire(ctx);
  tkey := 0;
  GenExpr(ctx, ctx.ast.nodes[m].e1);
  SaveTemp(ctx, tobj);
  If ctx.ast.nodes[m].kind = N_INDEX Then
    Begin
      tkey := TempAcquire(ctx);
      GenExpr(ctx, ctx.ast.nodes[m].e2);
      SaveTemp(ctx, tkey);
    End;
End;

Procedure MemberDone(Var ctx: TCompilerContext; tobj, tkey: LongInt);
Begin
  If tkey <> 0 Then
    TempRelease(ctx, tkey);
  TempRelease(ctx, tobj);
End;

Procedure MemberFetch(Var ctx: TCompilerContext; m, tobj, tkey: LongInt);
Begin
  If ctx.ast.nodes[m].kind = N_MEMBER Then
    Begin
      Emit1(ctx, OP_PUSH, AddrSym(SYMK_D, ctx.data.strs[ctx.ast.nodes[m].aux].sym));
      PushTemp(ctx, tobj);
      CallRt(ctx, 'get_prop', 12);
    End
  Else
    Begin
      PushTemp(ctx, tkey);
      PushTemp(ctx, tobj);
      CallRt(ctx, 'get_member', 16);
    End;
End;

{ Ecrit EDX:EAX dans la propriete ; la valeur reste dans EDX:EAX. }
Procedure MemberStore(Var ctx: TCompilerContext; m, tobj, tkey: LongInt);
Begin
  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
  If ctx.ast.nodes[m].kind = N_MEMBER Then
    Begin
      Emit1(ctx, OP_PUSH, AddrSym(SYMK_D, ctx.data.strs[ctx.ast.nodes[m].aux].sym));
      PushTemp(ctx, tobj);
      CallRt(ctx, 'set_prop', 20);
    End
  Else
    Begin
      PushTemp(ctx, tkey);
      PushTemp(ctx, tobj);
      CallRt(ctx, 'set_member', 24);
    End;
End;

Function IsMemberTarget(Var ctx: TCompilerContext; n: LongInt): Boolean;
Begin
  IsMemberTarget := (n <> 0) And ((ctx.ast.nodes[n].kind = N_MEMBER) Or
                                  (ctx.ast.nodes[n].kind = N_INDEX)) And
                    (ctx.ast.nodes[n].flags And EF_OPTIONAL = 0);
End;

{ x.p++, --a[i]... }
Procedure GenUpdateMember(Var ctx: TCompilerContext; n, e: LongInt);
Var
  slow, store, t, tobj, tkey: LongInt;
  inc_op, prefix: Boolean;
Begin
  inc_op := ctx.lex.tokens[ctx.ast.nodes[n].tok].text = '++';
  prefix := ctx.ast.nodes[n].flags And UF_PREFIX <> 0;
  slow := NewLabel(ctx);
  store := NewLabel(ctx);
  t := TempAcquire(ctx);
  MemberPrep(ctx, e, tobj, tkey);
  MemberFetch(ctx, e, tobj, tkey);
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
  Emit1(ctx, OP_JNE, LabelOp(slow));
  Emit(ctx, OP_MOV, RegOp(R_ECX), RegOp(R_EAX));
  If inc_op Then
    Emit(ctx, OP_ADD, RegOp(R_ECX), ImmOp(1))
  Else
    Emit(ctx, OP_SUB, RegOp(R_ECX), ImmOp(1));
  Emit1(ctx, OP_JO, LabelOp(slow));
  If Not prefix Then
    SaveTemp(ctx, t);
  Emit(ctx, OP_MOV, RegOp(R_EAX), RegOp(R_ECX));
  Emit1(ctx, OP_JMP, LabelOp(store));
  PlaceLabel(ctx, slow);
  If Not prefix Then
    Begin
      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
      CallRt(ctx, 'tonumber', 8);
      SaveTemp(ctx, t);
    End;
  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
  If inc_op Then
    CallRt(ctx, 'inc', 8)
  Else
    CallRt(ctx, 'dec', 8);
  PlaceLabel(ctx, store);
  MemberStore(ctx, e, tobj, tkey);
  If Not prefix Then
    LoadTemp(ctx, t);
  MemberDone(ctx, tobj, tkey);
  TempRelease(ctx, t);
End;

{ x.p op= v, a[i] op= v, a[i] &&= v... }
Procedure GenCompoundMember(Var ctx: TCompilerContext; n, lhs: LongInt);
Var
  t, tobj, tkey, keep, done, evalr: LongInt;
  op: TTokenText;
Begin
  op := ctx.lex.tokens[ctx.ast.nodes[n].tok].text;
  t := TempAcquire(ctx);
  MemberPrep(ctx, lhs, tobj, tkey);
  MemberFetch(ctx, lhs, tobj, tkey);
  SaveTemp(ctx, t);
  If (op = '&&=') Or (op = '||=') Or (op = '??=') Then
    Begin
      keep := NewLabel(ctx);
      done := NewLabel(ctx);
      If op = '??=' Then
        Begin
          evalr := NewLabel(ctx);
          Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_UNDEFINED)));
          Emit1(ctx, OP_JE, LabelOp(evalr));
          Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_NULL)));
          Emit1(ctx, OP_JNE, LabelOp(keep));
          PlaceLabel(ctx, evalr);
        End
      Else
        Begin
          GenTruthy(ctx);
          Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
          If op = '&&=' Then
            Emit1(ctx, OP_JE, LabelOp(keep))
          Else
            Emit1(ctx, OP_JNE, LabelOp(keep));
        End;
      GenExpr(ctx, ctx.ast.nodes[n].e2);
      MemberStore(ctx, lhs, tobj, tkey);
      Emit1(ctx, OP_JMP, LabelOp(done));
      PlaceLabel(ctx, keep);
      LoadTemp(ctx, t);
      PlaceLabel(ctx, done);
    End
  Else
    Begin
      GenExpr(ctx, ctx.ast.nodes[n].e2);
      GenBinaryCore(ctx, Copy(op, 1, Length(op) - 1), t);
      MemberStore(ctx, lhs, tobj, tkey);
    End;
  MemberDone(ctx, tobj, tkey);
  TempRelease(ctx, t);
End;

Procedure GenUpdate(Var ctx: TCompilerContext; n: LongInt);
Var
  e, sy, slow, store, t: LongInt;
  inc_op: Boolean;
  prefix: Boolean;
Begin
  e := ctx.ast.nodes[n].e1;
  If IsMemberTarget(ctx, e) Then
    Begin
      GenUpdateMember(ctx, n, e);
      Exit;
    End;
  If (e = 0) Or (ctx.ast.nodes[e].kind <> N_IDENT) Or
     Not ((ctx.ast.nodes[e].aux = RK_LOCAL) Or (ctx.ast.nodes[e].aux = RK_OUTER) Or
          (ctx.ast.nodes[e].aux = RK_GLOBAL_IMPLICIT)) Then
    Begin
      PendingExpr(ctx, n);
      Exit;
    End;
  sy := ctx.ast.nodes[e].sym;
  inc_op := ctx.lex.tokens[ctx.ast.nodes[n].tok].text = '++';
  prefix := ctx.ast.nodes[n].flags And UF_PREFIX <> 0;
  slow := NewLabel(ctx);
  store := NewLabel(ctx);
  t := TempAcquire(ctx);
  LoadSym(ctx, sy);
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_INT32)));
  Emit1(ctx, OP_JNE, LabelOp(slow));
  Emit(ctx, OP_MOV, RegOp(R_ECX), RegOp(R_EAX));
  If inc_op Then
    Emit(ctx, OP_ADD, RegOp(R_ECX), ImmOp(1))
  Else
    Emit(ctx, OP_SUB, RegOp(R_ECX), ImmOp(1));
  Emit1(ctx, OP_JO, LabelOp(slow));
  If Not prefix Then
    SaveTemp(ctx, t);
  Emit(ctx, OP_MOV, RegOp(R_EAX), RegOp(R_ECX));
  Emit1(ctx, OP_JMP, LabelOp(store));
  PlaceLabel(ctx, slow);
  If Not prefix Then
    Begin
      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
      CallRt(ctx, 'tonumber', 8);
      SaveTemp(ctx, t);
    End;
  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
  If inc_op Then
    CallRt(ctx, 'inc', 8)
  Else
    CallRt(ctx, 'dec', 8);
  PlaceLabel(ctx, store);
  StoreSym(ctx, sy, False);
  If Not prefix Then
    LoadTemp(ctx, t);
  TempRelease(ctx, t);
End;

{ Affectation composee sur une variable : x op= v, x &&= v, x ||= v, x ??= v. }
Procedure GenCompound(Var ctx: TCompilerContext; n: LongInt);
Var
  lhs, sy, t, keep, done, evalr: LongInt;
  op: TTokenText;
Begin
  lhs := ctx.ast.nodes[n].e1;
  op := ctx.lex.tokens[ctx.ast.nodes[n].tok].text;
  If IsMemberTarget(ctx, lhs) Then
    Begin
      GenCompoundMember(ctx, n, lhs);
      Exit;
    End;
  If (lhs = 0) Or (ctx.ast.nodes[lhs].kind <> N_IDENT) Or
     Not ((ctx.ast.nodes[lhs].aux = RK_LOCAL) Or (ctx.ast.nodes[lhs].aux = RK_OUTER) Or
          (ctx.ast.nodes[lhs].aux = RK_GLOBAL_IMPLICIT)) Then
    Begin
      PendingExpr(ctx, n);
      Exit;
    End;
  sy := ctx.ast.nodes[lhs].sym;
  t := TempAcquire(ctx);
  GenExpr(ctx, lhs);
  SaveTemp(ctx, t);
  If (op = '&&=') Or (op = '||=') Or (op = '??=') Then
    Begin
      keep := NewLabel(ctx);
      done := NewLabel(ctx);
      If op = '??=' Then
        Begin
          evalr := NewLabel(ctx);
          Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_UNDEFINED)));
          Emit1(ctx, OP_JE, LabelOp(evalr));
          Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_NULL)));
          Emit1(ctx, OP_JNE, LabelOp(keep));
          PlaceLabel(ctx, evalr);
        End
      Else
        Begin
          GenTruthy(ctx);
          Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
          If op = '&&=' Then
            Emit1(ctx, OP_JE, LabelOp(keep))
          Else
            Emit1(ctx, OP_JNE, LabelOp(keep));
        End;
      GenExpr(ctx, ctx.ast.nodes[n].e2);
      StoreSym(ctx, sy, False);
      Emit1(ctx, OP_JMP, LabelOp(done));
      PlaceLabel(ctx, keep);
      LoadTemp(ctx, t);
      PlaceLabel(ctx, done);
    End
  Else
    Begin
      GenExpr(ctx, ctx.ast.nodes[n].e2);
      GenBinaryCore(ctx, Copy(op, 1, Length(op) - 1), t);
      StoreSym(ctx, sy, False);
    End;
  TempRelease(ctx, t);
End;

{ ---- Fonctions, appels et acces aux membres (TODO 12) ----

  Convention d'appel interne. L'appelant reserve sur la pile, de bas en
  haut : la closure (4 octets), argc (4), this (8) puis les arguments
  (8 octets chacun), appelle [closure+code] et retire le tout. Dans la
  fonction appelee, apres push ebp : [EBP+8] closure, [EBP+12] argc,
  [EBP+16] this, [EBP+24] argument 0. Resultat dans EDX:EAX. Les
  arguments sont evalues de gauche a droite directement dans l'espace
  reserve. Avec un argument ...spread, les arguments sont rassembles
  dans un tableau et _JSRT_call_array(fonction, this, tableau) fait
  l'appel.

  Objet fonction : _JSRT_new_function(descripteur, code, environnement,
  this) ; l'environnement (_JSRT_new_env(n)) recoit les pointeurs des
  cellules capturees, dans l'ordre de la table des captures de la
  fonction. Une fleche memorise le this de son createur.

  Acces aux membres en lecture : _JSRT_get_prop(objet, atome) et
  _JSRT_get_member(objet, cle). Un appel de methode passe l'objet comme
  this. Le chainage optionnel a?.b.c() saute a la fin de la chaine avec
  undefined des qu'un maillon ?. rencontre null ou undefined. }

{ this du contexte courant, pour le memoriser dans une fleche. }
Procedure LoadCurrentThis(Var ctx: TCompilerContext);
Begin
  If ctx.ir.cg_fs = 1 Then
    LoadUndefined(ctx)
  Else If ctx.sem.scopes[ctx.ir.cg_fs].fkind = FK_ARROW Then
    Begin
      Emit(ctx, OP_MOV, RegOp(R_ECX), MemReg(R_EBP, RT_FRAME_CLOSURE));
      Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_ECX, RT_FN_THIS));
      Emit(ctx, OP_MOV, RegOp(R_EDX), MemReg(R_ECX, RT_FN_THIS + 4));
    End
  Else
    Begin
      Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_EBP, RT_FRAME_THIS));
      Emit(ctx, OP_MOV, RegOp(R_EDX), MemReg(R_EBP, RT_FRAME_THIS + 4));
    End;
End;

{ Cree l'objet fonction du noeud n (declaration, expression, fleche) ;
  le resultat est dans EDX:EAX. }
Procedure GenMakeClosure(Var ctx: TCompilerContext; n: LongInt);
Var
  fd, sc, ncells, i, k, kk, sy, e: LongInt;
  is_arrow: Boolean;
Begin
  fd := ctx.ast.nodes[n].ds;
  sc := ctx.ast.nodes[n].scope;
  ncells := ctx.sem.scopes[sc].cap_count;
  is_arrow := ctx.sem.scopes[sc].fkind = FK_ARROW;
  e := 0;
  If ncells > 0 Then
    Begin
      e := TempAcquire(ctx);
      Emit1(ctx, OP_PUSH, ImmOp(ncells));
      CallRt(ctx, 'new_env', 4);
      Emit(ctx, OP_MOV, TempLo(e), RegOp(R_EAX));
      k := 0;
      For i := 1 To ctx.sem.cap_count Do
        If ctx.sem.caps[i].fscope = sc Then
          Begin
            Inc(k);
            sy := ctx.sem.caps[i].sym;
            If ctx.sem.scopes[ctx.sem.syms[sy].scope].func = ctx.ir.cg_fs Then
              Emit(ctx, OP_MOV, RegOp(R_ECX),
                   MemReg(R_EBP, SlotDisp(ctx.sem.syms[sy].slot)))
            Else
              Begin
                kk := CapIndex(ctx, ctx.ir.cg_fs, sy);
                If kk = 0 Then
                  Begin
                    PipelineError(ctx, 'capture introuvable pour ' +
                                  ctx.lex.tokens[ctx.sem.syms[sy].name_tok].text);
                    kk := 1;
                  End;
                Emit(ctx, OP_MOV, RegOp(R_ECX), MemReg(R_EBP, RT_FRAME_CLOSURE));
                Emit(ctx, OP_MOV, RegOp(R_ECX), MemReg(R_ECX, RT_FN_ENV));
                Emit(ctx, OP_MOV, RegOp(R_ECX),
                     MemReg(R_ECX, RT_ENV_CELLS + 4 * (kk - 1)));
              End;
            Emit(ctx, OP_MOV, RegOp(R_EDX), TempLo(e));
            Emit(ctx, OP_MOV, MemReg(R_EDX, RT_ENV_CELLS + 4 * (k - 1)), RegOp(R_ECX));
          End;
    End;
  { new_function(descripteur, code, environnement, this) }
  If is_arrow Then
    LoadCurrentThis(ctx)
  Else
    LoadUndefined(ctx);
  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
  If ncells > 0 Then
    Emit1(ctx, OP_PUSH, TempLo(e))
  Else
    Emit1(ctx, OP_PUSH, ImmOp(0));
  Emit1(ctx, OP_PUSH, AddrSym(SYMK_X, XSym(ctx, ctx.data.fdescs[fd].code_sym)));
  Emit1(ctx, OP_PUSH, AddrSym(SYMK_D, ctx.data.fdescs[fd].sym));
  CallRt(ctx, 'new_function', 20);
  If e <> 0 Then
    TempRelease(ctx, e);
End;

{ ---- Chaines d'acces et d'appels ---- }

Function IsChainKind(k: TNodeKind): Boolean;
Begin
  IsChainKind := (k = N_MEMBER) Or (k = N_INDEX) Or (k = N_CALL);
End;

{ Si le maillon est optionnel et que la valeur EDX:EAX est null ou
  undefined, saute a la fin de la chaine avec undefined. }
Procedure ChainNullCheck(Var ctx: TCompilerContext);
Var
  isnull, ok: LongInt;
Begin
  isnull := NewLabel(ctx);
  ok := NewLabel(ctx);
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_UNDEFINED)));
  Emit1(ctx, OP_JE, LabelOp(isnull));
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_NULL)));
  Emit1(ctx, OP_JNE, LabelOp(ok));
  PlaceLabel(ctx, isnull);
  LoadUndefined(ctx);
  Emit1(ctx, OP_JMP, LabelOp(ctx.ir.chain_end));
  ctx.ir.chain_used := True;
  PlaceLabel(ctx, ok);
End;

{ Evalue l'objet d'un maillon membre ou indice et le range dans tobj. }
Procedure GenChainBase(Var ctx: TCompilerContext; m, tobj: LongInt);
Begin
  ctx.ir.in_chain := True;
  GenExpr(ctx, ctx.ast.nodes[m].e1);
  ctx.ir.in_chain := False;
  If ctx.ast.nodes[m].flags And EF_OPTIONAL <> 0 Then
    ChainNullCheck(ctx);
  SaveTemp(ctx, tobj);
End;

{ L'objet est dans tobj : lit la propriete dans EDX:EAX. }
Procedure GenPropFetch(Var ctx: TCompilerContext; m, tobj: LongInt);
Begin
  If (ctx.ast.nodes[ctx.ast.nodes[m].e1].kind = N_SUPER) And
     (ctx.ir.cg_fs > 1) And
     (ctx.sem.scopes[ctx.ir.cg_fs].fkind <> FK_ARROW) Then
    Begin
      { super.nom / super[cle] : recherche dans le prototype de l'objet d'accueil }
      If ctx.ast.nodes[m].kind = N_MEMBER Then
        Begin
          PushTemp(ctx, tobj);
          Emit1(ctx, OP_PUSH, AddrSym(SYMK_D,
                ctx.data.strs[ctx.ast.nodes[m].aux].sym));
        End
      Else
        Begin
          GenExpr(ctx, ctx.ast.nodes[m].e2);
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          CallRt(ctx, 'tokey', 8);
          PushTemp(ctx, tobj);
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
        End;
      Emit1(ctx, OP_PUSH, MemReg(R_EBP, RT_FRAME_CLOSURE));
      CallRt(ctx, 'super_get', 16);
    End
  Else If ctx.ast.nodes[m].kind = N_MEMBER Then
    Begin
      Emit1(ctx, OP_PUSH, AddrSym(SYMK_D,
            ctx.data.strs[ctx.ast.nodes[m].aux].sym));
      PushTemp(ctx, tobj);
      CallRt(ctx, 'get_prop', 12);
    End
  Else
    Begin
      GenExpr(ctx, ctx.ast.nodes[m].e2);
      CallBinary(ctx, 'get_member', tobj);
    End;
End;

Procedure GenMember(Var ctx: TCompilerContext; n: LongInt);
Var
  t, old_end: LongInt;
  top, old_used: Boolean;
Begin
  top := Not ctx.ir.in_chain;
  old_end := ctx.ir.chain_end;
  old_used := ctx.ir.chain_used;
  If top Then
    Begin
      ctx.ir.chain_end := NewLabel(ctx);
      ctx.ir.chain_used := False;
    End;
  t := TempAcquire(ctx);
  GenChainBase(ctx, n, t);
  GenPropFetch(ctx, n, t);
  TempRelease(ctx, t);
  If top Then
    Begin
      If ctx.ir.chain_used Then
        PlaceLabel(ctx, ctx.ir.chain_end);
      ctx.ir.chain_end := old_end;
      ctx.ir.chain_used := old_used;
    End;
  ctx.ir.in_chain := Not top;
End;

Procedure GenCall(Var ctx: TCompilerContext; n: LongInt);
Var
  callee, a, nargs, i, tf, tt, notfn, lbl, old_end, usethis, okl: LongInt;
  top, has_spread, old_used, is_new, is_super: Boolean;
Begin
  callee := ctx.ast.nodes[n].e1;
  is_new := ctx.ast.nodes[n].kind = N_NEW;
  is_super := (callee <> 0) And (ctx.ast.nodes[callee].kind = N_SUPER);
  If is_super And ((ctx.ir.cg_fs <= 1) Or
     (ctx.sem.scopes[ctx.ir.cg_fs].fkind <> FK_DERIVED_CTOR)) Then
    Begin
      PendingNote(ctx, n, 'super(...) hors du constructeur d''une classe derivee');
      LoadUndefined(ctx);
      Exit;
    End;
  top := Not ctx.ir.in_chain;
  old_end := ctx.ir.chain_end;
  old_used := ctx.ir.chain_used;
  If top Then
    Begin
      ctx.ir.chain_end := NewLabel(ctx);
      ctx.ir.chain_used := False;
    End;
  nargs := 0;
  has_spread := False;
  a := ctx.ast.nodes[n].e2;
  While a <> 0 Do
    Begin
      Inc(nargs);
      If ctx.ast.nodes[a].kind = N_SPREAD Then
        has_spread := True;
      a := ctx.ast.nodes[a].next;
    End;
  tf := TempAcquire(ctx);
  tt := TempAcquire(ctx);

  { callee et this }
  If (Not is_new) And (callee <> 0) And ((ctx.ast.nodes[callee].kind = N_MEMBER) Or
                        (ctx.ast.nodes[callee].kind = N_INDEX)) Then
    Begin
      GenChainBase(ctx, callee, tt);
      GenPropFetch(ctx, callee, tt);
    End
  Else
    Begin
      If is_super Then
        Begin
          { constructeur parent : champ this de la classe courante }
          Emit(ctx, OP_MOV, RegOp(R_ECX), MemReg(R_EBP, RT_FRAME_CLOSURE));
          Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_ECX, RT_FN_THIS));
          Emit(ctx, OP_MOV, RegOp(R_EDX), MemReg(R_ECX, RT_FN_THIS + 4));
        End
      Else
        Begin
          ctx.ir.in_chain := True;
          GenExpr(ctx, callee);
          ctx.ir.in_chain := False;
        End;
      SaveTemp(ctx, tf);
      If is_super Then
        Begin
          Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_EBP, RT_FRAME_THIS));
          Emit(ctx, OP_MOV, RegOp(R_EDX), MemReg(R_EBP, RT_FRAME_THIS + 4));
        End
      Else
        LoadUndefined(ctx);
      SaveTemp(ctx, tt);
      If is_new Then
        Begin
          { this d'un appel new : objet neuf, ou undefined pour un natif }
          usethis := NewLabel(ctx);
          LoadTemp(ctx, tf);
          Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_FUNCTION)));
          Emit1(ctx, OP_JNE, LabelOp(usethis));
          PushTemp(ctx, tf);
          CallRt(ctx, 'new_this', 8);
          SaveTemp(ctx, tt);
          PlaceLabel(ctx, usethis);
        End;
      LoadTemp(ctx, tf);
    End;
  If ctx.ast.nodes[n].flags And EF_OPTIONAL <> 0 Then
    ChainNullCheck(ctx);
  SaveTemp(ctx, tf);
  { la valeur appelee doit etre une fonction }
  notfn := NewLabel(ctx);
  lbl := NewLabel(ctx);
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_FUNCTION)));
  Emit1(ctx, OP_JNE, LabelOp(notfn));

  If has_spread Then
    Begin
      { arguments rassembles dans un tableau }
      CallRt(ctx, 'array_new', 0);
      i := TempAcquire(ctx);
      SaveTemp(ctx, i);
      a := ctx.ast.nodes[n].e2;
      While a <> 0 Do
        Begin
          If ctx.ast.nodes[a].kind = N_SPREAD Then
            Begin
              GenExpr(ctx, ctx.ast.nodes[a].e1);
              Emit1(ctx, OP_PUSH, RegOp(R_EDX));
              Emit1(ctx, OP_PUSH, RegOp(R_EAX));
              PushTemp(ctx, i);
              CallRt(ctx, 'array_spread', 16);
            End
          Else
            Begin
              GenExpr(ctx, a);
              Emit1(ctx, OP_PUSH, RegOp(R_EDX));
              Emit1(ctx, OP_PUSH, RegOp(R_EAX));
              PushTemp(ctx, i);
              CallRt(ctx, 'array_push', 16);
            End;
          a := ctx.ast.nodes[a].next;
        End;
      PushTemp(ctx, i);
      PushTemp(ctx, tt);
      PushTemp(ctx, tf);
      CallRt(ctx, 'call_array', 24);
      TempRelease(ctx, i);
    End
  Else
    Begin
      Emit(ctx, OP_SUB, RegOp(R_ESP), ImmOp(16 + RT_VALUE_SIZE * nargs));
      i := 0;
      a := ctx.ast.nodes[n].e2;
      While a <> 0 Do
        Begin
          GenExpr(ctx, a);
          Emit(ctx, OP_MOV, MemReg(R_ESP, 16 + RT_VALUE_SIZE * i), RegOp(R_EAX));
          Emit(ctx, OP_MOV, MemReg(R_ESP, 16 + RT_VALUE_SIZE * i + 4), RegOp(R_EDX));
          Inc(i);
          a := ctx.ast.nodes[a].next;
        End;
      Emit(ctx, OP_MOV, RegOp(R_EAX), TempLo(tf));
      Emit(ctx, OP_MOV, MemReg(R_ESP, 0), RegOp(R_EAX));
      Emit(ctx, OP_MOV, MemReg(R_ESP, 4), ImmOp(nargs));
      Emit(ctx, OP_MOV, RegOp(R_ECX), TempLo(tt));
      Emit(ctx, OP_MOV, MemReg(R_ESP, 8), RegOp(R_ECX));
      Emit(ctx, OP_MOV, RegOp(R_ECX), TempHi(tt));
      Emit(ctx, OP_MOV, MemReg(R_ESP, 12), RegOp(R_ECX));
      Emit1(ctx, OP_CALL, MemReg(R_EAX, RT_FN_CODE));
      Emit(ctx, OP_ADD, RegOp(R_ESP), ImmOp(16 + RT_VALUE_SIZE * nargs));
    End;
  If is_new Then
    Begin
      { le resultat d'un constructeur n'est retenu que s'il est un objet }
      usethis := NewLabel(ctx);
      okl := NewLabel(ctx);
      Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_OBJECT)));
      Emit1(ctx, OP_JB, LabelOp(usethis));
      Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_REGEXP)));
      Emit1(ctx, OP_JBE, LabelOp(okl));
      PlaceLabel(ctx, usethis);
      LoadTemp(ctx, tt);
      PlaceLabel(ctx, okl);
    End;
  If is_super Then
    Begin
      { champs d'instance de cette classe, puis la valeur de l'expression est this }
      PushTemp(ctx, tt);
      Emit1(ctx, OP_PUSH, MemReg(R_EBP, RT_FRAME_CLOSURE));
      CallRt(ctx, 'init_fields', 12);
      LoadTemp(ctx, tt);
    End;
  Emit1(ctx, OP_JMP, LabelOp(lbl));
  PlaceLabel(ctx, notfn);
  CallRt(ctx, 'throw_notfunc', 0);
  PlaceLabel(ctx, lbl);
  TempRelease(ctx, tt);
  TempRelease(ctx, tf);
  If top Then
    Begin
      If ctx.ir.chain_used Then
        PlaceLabel(ctx, ctx.ir.chain_end);
      ctx.ir.chain_end := old_end;
      ctx.ir.chain_used := old_used;
    End;
  ctx.ir.in_chain := Not top;
End;

{ Gabarit avec interpolation : les segments constants et les expressions converties
  par ToString sont concatenes de gauche a droite. }
Procedure GenTemplate(Var ctx: TCompilerContext; n: LongInt);
Var
  e, t: LongInt;
Begin
  e := ctx.ast.nodes[n].e1;
  If (e <> 0) And (ctx.ast.nodes[e].next = 0) Then
    Begin
      LoadStringConst(ctx, ctx.ast.nodes[e].ds);
      Exit;
    End;
  t := TempAcquire(ctx);
  LoadStringConst(ctx, ctx.ast.nodes[e].ds);
  SaveTemp(ctx, t);
  e := ctx.ast.nodes[e].next;
  While e <> 0 Do
    Begin
      If ctx.ast.nodes[e].kind = N_TEMPLATE_STR Then
        Begin
          If ctx.data.strs[ctx.ast.nodes[e].ds].len > 0 Then
            Begin
              LoadStringConst(ctx, ctx.ast.nodes[e].ds);
              Emit1(ctx, OP_PUSH, RegOp(R_EDX));
              Emit1(ctx, OP_PUSH, RegOp(R_EAX));
              PushTemp(ctx, t);
              CallRt(ctx, 'concat', 16);
              SaveTemp(ctx, t);
            End;
        End
      Else
        Begin
          GenExpr(ctx, e);
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          CallRt(ctx, 'tostring', 8);
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          PushTemp(ctx, t);
          CallRt(ctx, 'concat', 16);
          SaveTemp(ctx, t);
        End;
      e := ctx.ast.nodes[e].next;
    End;
  LoadTemp(ctx, t);
  TempRelease(ctx, t);
End;

{ Affectation simple ou destructurante ; la valeur reste dans EDX:EAX. }
Procedure GenAssign(Var ctx: TCompilerContext; n: LongInt);
Var
  lhs, t, tobj, tkey: LongInt;
Begin
  lhs := ctx.ast.nodes[n].e1;
  If ctx.lex.tokens[ctx.ast.nodes[n].tok].text <> '=' Then
    Begin
      GenCompound(ctx, n);
      Exit;
    End;
  If (lhs <> 0) And (ctx.ast.nodes[lhs].kind = N_IDENT) Then
    Begin
      If (ctx.ast.nodes[lhs].aux = RK_LOCAL) Or (ctx.ast.nodes[lhs].aux = RK_OUTER) Or
         (ctx.ast.nodes[lhs].aux = RK_GLOBAL_IMPLICIT) Then
        Begin
          GenExpr(ctx, ctx.ast.nodes[n].e2);
          StoreSym(ctx, ctx.ast.nodes[lhs].sym, False);
        End
      Else
        PendingExpr(ctx, n);
    End
  Else If IsMemberTarget(ctx, lhs) Then
    Begin
      MemberPrep(ctx, lhs, tobj, tkey);
      GenExpr(ctx, ctx.ast.nodes[n].e2);
      MemberStore(ctx, lhs, tobj, tkey);
      MemberDone(ctx, tobj, tkey);
    End
  Else If (lhs <> 0) And ((ctx.ast.nodes[lhs].kind = N_ARRAY_LIT) Or
                          (ctx.ast.nodes[lhs].kind = N_OBJECT_LIT)) Then
    Begin
      GenExpr(ctx, ctx.ast.nodes[n].e2);
      t := AllocTemp(ctx);
      Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(t)), RegOp(R_EAX));
      Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(t) + 4), RegOp(R_EDX));
      BindTo(ctx, lhs, t, False);
      Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_EBP, SlotDisp(t)));
      Emit(ctx, OP_MOV, RegOp(R_EDX), MemReg(R_EBP, SlotDisp(t) + 4));
    End
  Else
    PendingExpr(ctx, n);
End;

{ Litteral de tableau : array_new puis array_push / array_spread. }
Procedure GenArrayLit(Var ctx: TCompilerContext; n: LongInt);
Var
  t, el: LongInt;
Begin
  t := TempAcquire(ctx);
  CallRt(ctx, 'array_new', 0);
  SaveTemp(ctx, t);
  el := ctx.ast.nodes[n].e1;
  While el <> 0 Do
    Begin
      If ctx.ast.nodes[el].kind = N_SPREAD Then
        GenExpr(ctx, ctx.ast.nodes[el].e1)
      Else If ctx.ast.nodes[el].kind = N_ELISION Then
        LoadUndefined(ctx)
      Else
        GenExpr(ctx, el);
      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
      PushTemp(ctx, t);
      If ctx.ast.nodes[el].kind = N_SPREAD Then
        CallRt(ctx, 'array_spread', 16)
      Else
        CallRt(ctx, 'array_push', 16);
      el := ctx.ast.nodes[el].next;
    End;
  LoadTemp(ctx, t);
  TempRelease(ctx, t);
End;

{ Litteral d'objet : obj_new puis obj_define / obj_define_acc / obj_spread. }
Procedure GenObjectLit(Var ctx: TCompilerContext; n: LongInt);
Var
  t, tk, p, fl: LongInt;
Begin
  t := TempAcquire(ctx);
  CallRt(ctx, 'obj_new', 0);
  SaveTemp(ctx, t);
  p := ctx.ast.nodes[n].e1;
  While p <> 0 Do
    Begin
      fl := ctx.ast.nodes[p].flags;
      If fl And PR_SPREAD <> 0 Then
        Begin
          GenExpr(ctx, ctx.ast.nodes[p].e1);
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          PushTemp(ctx, t);
          CallRt(ctx, 'obj_spread', 16);
        End
      Else
        Begin
          tk := 0;
          If fl And PR_COMPUTED <> 0 Then
            Begin
              tk := TempAcquire(ctx);
              GenExpr(ctx, ctx.ast.nodes[p].e2);
              Emit1(ctx, OP_PUSH, RegOp(R_EDX));
              Emit1(ctx, OP_PUSH, RegOp(R_EAX));
              CallRt(ctx, 'tokey', 8);
              SaveTemp(ctx, tk);
            End;
          GenExpr(ctx, ctx.ast.nodes[p].e1);
          If fl And PR_SETTER <> 0 Then
            Emit1(ctx, OP_PUSH, ImmOp(1))
          Else If fl And PR_GETTER <> 0 Then
            Emit1(ctx, OP_PUSH, ImmOp(0));
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          If tk <> 0 Then
            Emit1(ctx, OP_PUSH, TempLo(tk))
          Else
            Emit1(ctx, OP_PUSH, AddrSym(SYMK_D, ctx.data.strs[ctx.ast.nodes[p].aux].sym));
          Emit1(ctx, OP_PUSH, TempLo(t));
          If fl And (PR_GETTER Or PR_SETTER) <> 0 Then
            CallRt(ctx, 'obj_define_acc', 24)
          Else
            CallRt(ctx, 'obj_define', 16);
          If tk <> 0 Then
            TempRelease(ctx, tk);
        End;
      p := ctx.ast.nodes[p].next;
    End;
  LoadTemp(ctx, t);
  TempRelease(ctx, t);
End;

{ ---- Classes (TODO 17) ----

  Une classe est la fonction constructeur elle-meme (objet fonction), avec
  un objet de proprietes (membres statiques, prototype herite de la classe
  parente) et un objet prototype (methodes, accesseurs, constructor).
  _JSRT_class_setup(classe, parent) cree ces deux objets et memorise la
  classe parente dans le champ this de la fonction, que super(...) lit.
  Une methode memorise son objet d'accueil dans ce meme champ, ce qui
  permet super.m(...). Les champs d'instance sont enregistres dans la
  propriete cachee #fields du prototype ; _JSRT_init_fields(classe,
  this) les initialise (au debut du constructeur de base, ou juste apres
  super(...) dans une classe derivee). }

Function ClassCtor(Var ctx: TCompilerContext; n: LongInt): LongInt;
Var
  m: LongInt;
Begin
  ClassCtor := 0;
  m := ctx.ast.nodes[n].e2;
  While m <> 0 Do
    Begin
      If (ctx.ast.nodes[m].kind = N_METHOD) And
         (ctx.ast.nodes[m].flags And MF_CONSTRUCTOR <> 0) Then
        ClassCtor := m;
      m := ctx.ast.nodes[m].next;
    End;
End;

{ Cle d'un membre de classe : EAX = chaine ; resultat dans le temporaire tk
  (calculee) ou 0 si la cle est un atome. }
Function ClassKeyTemp(Var ctx: TCompilerContext; m: LongInt): LongInt;
Var
  tk: LongInt;
Begin
  tk := 0;
  If ctx.ast.nodes[m].flags And MF_COMPUTED <> 0 Then
    Begin
      tk := TempAcquire(ctx);
      GenExpr(ctx, ctx.ast.nodes[m].e3);
      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
      CallRt(ctx, 'tokey', 8);
      SaveTemp(ctx, tk);
    End;
  ClassKeyTemp := tk;
End;

Procedure PushClassKey(Var ctx: TCompilerContext; m, tk: LongInt);
Begin
  If tk <> 0 Then
    Emit1(ctx, OP_PUSH, TempLo(tk))
  Else
    Emit1(ctx, OP_PUSH, AddrSym(SYMK_D, ctx.data.strs[ctx.ast.nodes[m].aux].sym));
End;

Procedure PushUndefinedValue(Var ctx: TCompilerContext);
Begin
  Emit1(ctx, OP_PUSH, ImmOp(TagImm(RT_T_UNDEFINED)));
  Emit1(ctx, OP_PUSH, ImmOp(0));
End;

Procedure GenClass(Var ctx: TCompilerContext; n: LongInt);
Var
  sc, tcls, tpar, tproto, tk, m, ctor, sy, kind: LongInt;
Begin
  sc := ctx.ast.nodes[n].scope;
  If sc <> 0 Then
    GenScopeEnter(ctx, sc);
  tcls := TempAcquire(ctx);
  tpar := TempAcquire(ctx);
  tproto := TempAcquire(ctx);
  If ctx.ast.nodes[n].e1 <> 0 Then
    GenExpr(ctx, ctx.ast.nodes[n].e1)
  Else
    LoadUndefined(ctx);
  SaveTemp(ctx, tpar);
  ctor := ClassCtor(ctx, n);
  If ctor <> 0 Then
    GenMakeClosure(ctx, ctor)
  Else
    Begin
      If ctx.ast.nodes[n].e1 <> 0 Then
        Emit1(ctx, OP_PUSH, ImmOp(1))
      Else
        Emit1(ctx, OP_PUSH, ImmOp(0));
      CallRt(ctx, 'make_default_ctor', 4);
    End;
  SaveTemp(ctx, tcls);
  PushTemp(ctx, tpar);
  PushTemp(ctx, tcls);
  CallRt(ctx, 'class_setup', 16);
  PushTemp(ctx, tcls);
  CallRt(ctx, 'class_proto', 8);
  SaveTemp(ctx, tproto);
  { liaison du nom : exterieure pour une declaration, interieure pour une expression }
  If ctx.ast.nodes[n].kind = N_CLASS_DECL Then
    Begin
      If ctx.ast.nodes[n].sym <> 0 Then
        Begin
          LoadTemp(ctx, tcls);
          StoreSym(ctx, ctx.ast.nodes[n].sym, True);
        End;
    End
  Else If sc <> 0 Then
    Begin
      sy := ctx.sem.scopes[sc].first_sym;
      While sy <> 0 Do
        Begin
          If ctx.sem.syms[sy].kind = DK_FNAME Then
            Begin
              LoadTemp(ctx, tcls);
              StoreSym(ctx, sy, True);
            End;
          sy := ctx.sem.syms[sy].next;
        End;
    End;
  { premiere passe : methodes, accesseurs et champs d'instance }
  m := ctx.ast.nodes[n].e2;
  While m <> 0 Do
    Begin
      If (ctx.ast.nodes[m].kind = N_METHOD) And
         (ctx.ast.nodes[m].flags And MF_CONSTRUCTOR = 0) Then
        Begin
          tk := ClassKeyTemp(ctx, m);
          GenMakeClosure(ctx, m);
          If ctx.ast.nodes[m].flags And MF_GETTER <> 0 Then
            kind := 1
          Else If ctx.ast.nodes[m].flags And MF_SETTER <> 0 Then
            kind := 2
          Else
            kind := 0;
          Emit1(ctx, OP_PUSH, ImmOp(kind));
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          PushClassKey(ctx, m, tk);
          If ctx.ast.nodes[m].flags And MF_STATIC <> 0 Then
            PushTemp(ctx, tcls)
          Else
            PushTemp(ctx, tproto);
          CallRt(ctx, 'class_member', 24);
          If tk <> 0 Then
            TempRelease(ctx, tk);
        End
      Else If (ctx.ast.nodes[m].kind = N_FIELD) And
              (ctx.ast.nodes[m].flags And MF_STATIC = 0) Then
        Begin
          tk := ClassKeyTemp(ctx, m);
          If ctx.ast.nodes[m].e1 <> 0 Then
            GenMakeClosure(ctx, m)
          Else
            LoadUndefined(ctx);
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          PushClassKey(ctx, m, tk);
          PushTemp(ctx, tproto);
          CallRt(ctx, 'class_field', 20);
          If tk <> 0 Then
            TempRelease(ctx, tk);
        End;
      m := ctx.ast.nodes[m].next;
    End;
  { seconde passe : champs statiques et blocs statiques, dans l'ordre }
  m := ctx.ast.nodes[n].e2;
  While m <> 0 Do
    Begin
      If (ctx.ast.nodes[m].kind = N_FIELD) And
         (ctx.ast.nodes[m].flags And MF_STATIC <> 0) Then
        Begin
          tk := ClassKeyTemp(ctx, m);
          If ctx.ast.nodes[m].e1 <> 0 Then
            GenMakeClosure(ctx, m)
          Else
            LoadUndefined(ctx);
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          PushClassKey(ctx, m, tk);
          PushTemp(ctx, tcls);
          CallRt(ctx, 'class_static', 20);
          If tk <> 0 Then
            TempRelease(ctx, tk);
        End
      Else If ctx.ast.nodes[m].kind = N_STATIC_BLOCK Then
        Begin
          GenMakeClosure(ctx, m);
          Emit1(ctx, OP_PUSH, RegOp(R_EDX));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          PushTemp(ctx, tcls);
          CallRt(ctx, 'class_block', 16);
        End;
      m := ctx.ast.nodes[m].next;
    End;
  LoadTemp(ctx, tcls);
  TempRelease(ctx, tproto);
  TempRelease(ctx, tpar);
  TempRelease(ctx, tcls);
End;

Procedure GenExpr(Var ctx: TCompilerContext; n: LongInt);
Var
  e: LongInt;
  save_chain: Boolean;
Begin
  If n = 0 Then
    Begin
      LoadUndefined(ctx);
      Exit;
    End;
  save_chain := ctx.ir.in_chain;
  If Not IsChainKind(ctx.ast.nodes[n].kind) Then
    ctx.ir.in_chain := False;
  Case ctx.ast.nodes[n].kind Of
    N_CALL, N_NEW:
      GenCall(ctx, n);
    N_ARRAY_LIT:
      GenArrayLit(ctx, n);
    N_OBJECT_LIT:
      GenObjectLit(ctx, n);
    N_CLASS_EXPR:
      GenClass(ctx, n);
    N_SUPER:
      Begin
        Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_EBP, RT_FRAME_THIS));
        Emit(ctx, OP_MOV, RegOp(R_EDX), MemReg(R_EBP, RT_FRAME_THIS + 4));
      End;
    N_MEMBER, N_INDEX:
      GenMember(ctx, n);
    N_FUNC_EXPR:
      GenMakeClosure(ctx, n);
    N_NUMBER:
      Begin
        If ctx.ast.nodes[n].ds <> 0 Then
          LoadDouble(ctx, ctx.ast.nodes[n].ds)
        Else
          LoadTag(ctx, Trunc(ctx.lex.tokens[ctx.ast.nodes[n].tok].num_val),
                  RT_T_INT32);
      End;
    N_STRING, N_TEMPLATE_STR:
      LoadStringConst(ctx, ctx.ast.nodes[n].ds);
    N_TEMPLATE:
      GenTemplate(ctx, n);
    N_BOOL:
      Begin
        If ctx.lex.tokens[ctx.ast.nodes[n].tok].text = 'true' Then
          LoadTag(ctx, 1, RT_T_BOOLEAN)
        Else
          LoadTag(ctx, 0, RT_T_BOOLEAN);
      End;
    N_NULL:
      LoadTag(ctx, 0, RT_T_NULL);
    N_IDENT:
      GenIdent(ctx, n);
    N_THIS:
      GenThis(ctx, n);
    N_ASSIGN:
      GenAssign(ctx, n);
    N_UNARY:
      Begin
        If Not TryFold(ctx, n) Then
          GenUnary(ctx, n);
      End;
    N_BINARY:
      Begin
        If Not TryFold(ctx, n) Then
          GenBinary(ctx, n);
      End;
    N_LOGICAL:
      Begin
        If Not TryFold(ctx, n) Then
          GenLogical(ctx, n);
      End;
    N_COND:
      Begin
        If Not TryFold(ctx, n) Then
          GenCond(ctx, n);
      End;
    N_UPDATE:
      GenUpdate(ctx, n);
    N_SEQUENCE:
      Begin
        e := ctx.ast.nodes[n].e1;
        While e <> 0 Do
          Begin
            GenExpr(ctx, e);
            e := ctx.ast.nodes[e].next;
          End;
      End;
  Else
    PendingExpr(ctx, n);
  End;
  ctx.ir.in_chain := save_chain;
End;

{ ---- Destructuration ---- }

Procedure StoreTemp(Var ctx: TCompilerContext; slot: LongInt);
Begin
  Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(slot)), RegOp(R_EAX));
  Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(slot) + 4), RegOp(R_EDX));
End;

Procedure PushTemp(Var ctx: TCompilerContext; slot: LongInt);
Begin
  Emit1(ctx, OP_PUSH, MemReg(R_EBP, SlotDisp(slot) + 4));
  Emit1(ctx, OP_PUSH, MemReg(R_EBP, SlotDisp(slot)));
End;

{ Si EDX:EAX vaut undefined, evalue la valeur par defaut. }
Procedure GenDefault(Var ctx: TCompilerContext; def: LongInt);
Var
  skip: LongInt;
Begin
  If def = 0 Then
    Exit;
  skip := NewLabel(ctx);
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_UNDEFINED)));
  Emit1(ctx, OP_JNE, LabelOp(skip));
  GenExpr(ctx, def);
  PlaceLabel(ctx, skip);
End;

{ Lie EDX:EAX a la cible (identifiant ou sous-motif). }
Procedure BindValue(Var ctx: TCompilerContext; target: LongInt; init: Boolean);
Var
  t, tobj, tkey: LongInt;
Begin
  If target = 0 Then
    Exit;
  Case ctx.ast.nodes[target].kind Of
    N_BIND_IDENT:
      StoreSym(ctx, ctx.ast.nodes[target].sym, True);
    N_IDENT:
      Begin
        If (ctx.ast.nodes[target].aux = RK_LOCAL) Or
           (ctx.ast.nodes[target].aux = RK_OUTER) Or
           (ctx.ast.nodes[target].aux = RK_GLOBAL_IMPLICIT) Then
          StoreSym(ctx, ctx.ast.nodes[target].sym, init)
        Else
          PendingNote(ctx, target, 'cible d''affectation ' +
                      NodeKindName(ctx.ast.nodes[target].kind));
      End;
    N_ARRAY_PATTERN, N_OBJECT_PATTERN, N_ARRAY_LIT, N_OBJECT_LIT:
      Begin
        t := AllocTemp(ctx);
        StoreTemp(ctx, t);
        BindTo(ctx, target, t, init);
      End;
    N_MEMBER, N_INDEX:
      Begin
        t := TempAcquire(ctx);
        SaveTemp(ctx, t);
        MemberPrep(ctx, target, tobj, tkey);
        LoadTemp(ctx, t);
        MemberStore(ctx, target, tobj, tkey);
        MemberDone(ctx, tobj, tkey);
        TempRelease(ctx, t);
      End;
  Else
    PendingNote(ctx, target, 'cible d''affectation ' +
                NodeKindName(ctx.ast.nodes[target].kind));
  End;
End;

{ Destructure la valeur rangee dans le temporaire tslot. node est un
  motif de declaration ou un litteral utilise comme cible. }
Procedure BindTo(Var ctx: TCompilerContext; node, tslot: LongInt; init: Boolean);
Var
  el, idx, target, def, key_atom, nkeys, tex, tk: LongInt;
  rest, hole, pattern_kind, has_rest: Boolean;
  fl: LongInt;
  kn: TNodeKind;
Begin
  kn := ctx.ast.nodes[node].kind;
  If (kn = N_ARRAY_PATTERN) Or (kn = N_ARRAY_LIT) Then
    Begin
      idx := 0;
      el := ctx.ast.nodes[node].e1;
      While el <> 0 Do
        Begin
          rest := False;
          hole := False;
          def := 0;
          target := 0;
          If ctx.ast.nodes[el].kind = N_PATTERN_ELEM Then
            Begin
              target := ctx.ast.nodes[el].e1;
              def := ctx.ast.nodes[el].e2;
              rest := ctx.ast.nodes[el].flags And PF_REST <> 0;
              hole := target = 0;
            End
          Else If ctx.ast.nodes[el].kind = N_ELISION Then
            hole := True
          Else If ctx.ast.nodes[el].kind = N_SPREAD Then
            Begin
              rest := True;
              target := ctx.ast.nodes[el].e1;
            End
          Else If ctx.ast.nodes[el].kind = N_ASSIGN Then
            Begin
              target := ctx.ast.nodes[el].e1;
              def := ctx.ast.nodes[el].e2;
            End
          Else
            target := el;
          If Not hole Then
            Begin
              If rest Then
                Begin
                  Emit1(ctx, OP_PUSH, ImmOp(idx));
                  PushTemp(ctx, tslot);
                  CallRt(ctx, 'array_rest', 12);
                End
              Else
                Begin
                  Emit1(ctx, OP_PUSH, ImmOp(idx));
                  PushTemp(ctx, tslot);
                  CallRt(ctx, 'get_index', 12);
                  GenDefault(ctx, def);
                End;
              BindValue(ctx, target, init);
            End;
          Inc(idx);
          el := ctx.ast.nodes[el].next;
        End;
    End
  Else
    Begin
      nkeys := 0;
      tex := 0;
      has_rest := False;
      el := ctx.ast.nodes[node].e1;
      While el <> 0 Do
        Begin
          If ((ctx.ast.nodes[el].kind = N_PATTERN_PROP) And
              (ctx.ast.nodes[el].flags And PP_REST <> 0)) Or
             ((ctx.ast.nodes[el].kind <> N_PATTERN_PROP) And
              (ctx.ast.nodes[el].flags And PR_SPREAD <> 0)) Then
            has_rest := True;
          el := ctx.ast.nodes[el].next;
        End;
      If has_rest Then
        Begin
          { liste des cles deja prises, pour le reste de l'objet }
          tex := TempAcquire(ctx);
          CallRt(ctx, 'array_new', 0);
          SaveTemp(ctx, tex);
        End;
      el := ctx.ast.nodes[node].e1;
      While el <> 0 Do
        Begin
          If ctx.ast.nodes[el].kind = N_PATTERN_PROP Then
            Begin
              fl := ctx.ast.nodes[el].flags;
              target := ctx.ast.nodes[el].e1;
              def := ctx.ast.nodes[el].e2;
              rest := fl And PP_REST <> 0;
              pattern_kind := fl And PP_COMPUTED <> 0;
              key_atom := ctx.ast.nodes[el].aux;
              If pattern_kind Then
                Begin
                  GenExpr(ctx, ctx.ast.nodes[el].e3);
                  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
                  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
                  CallRt(ctx, 'tokey', 8);
                  If has_rest And Not rest Then
                    Begin
                      tk := TempAcquire(ctx);
                      SaveTemp(ctx, tk);
                      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
                      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
                      PushTemp(ctx, tex);
                      CallRt(ctx, 'array_push', 16);
                      LoadTemp(ctx, tk);
                      TempRelease(ctx, tk);
                    End;
                  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
                  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
                End;
            End
          Else
            Begin
              fl := ctx.ast.nodes[el].flags;
              rest := fl And PR_SPREAD <> 0;
              pattern_kind := fl And PR_COMPUTED <> 0;
              target := ctx.ast.nodes[el].e1;
              def := ctx.ast.nodes[el].e3;
              key_atom := ctx.ast.nodes[el].aux;
              If pattern_kind Then
                Begin
                  GenExpr(ctx, ctx.ast.nodes[el].e2);
                  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
                  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
                  CallRt(ctx, 'tokey', 8);
                  If has_rest And Not rest Then
                    Begin
                      tk := TempAcquire(ctx);
                      SaveTemp(ctx, tk);
                      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
                      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
                      PushTemp(ctx, tex);
                      CallRt(ctx, 'array_push', 16);
                      LoadTemp(ctx, tk);
                      TempRelease(ctx, tk);
                    End;
                  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
                  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
                End;
              { dans a: b = 1, la valeur par defaut enveloppe la cible }
              If (target <> 0) And (ctx.ast.nodes[target].kind = N_ASSIGN) And
                 (fl And PR_SHORTHAND = 0) Then
                Begin
                  def := ctx.ast.nodes[target].e2;
                  target := ctx.ast.nodes[target].e1;
                End;
            End;
          If rest Then
            Begin
              { le reste d'objet : copie sans les cles deja prises }
              PushTemp(ctx, tex);
              PushTemp(ctx, tslot);
              CallRt(ctx, 'obj_rest', 16);
            End
          Else If pattern_kind Then
            Begin
              { cle calculee deja poussee : valeur puis cle }
              PushTemp(ctx, tslot);
              CallRt(ctx, 'get_member', 16);
              GenDefault(ctx, def);
            End
          Else
            Begin
              If has_rest Then
                Begin
                  Emit1(ctx, OP_PUSH, ImmOp(TagImm(RT_T_STRING)));
                  Emit1(ctx, OP_PUSH, AddrSym(SYMK_D, ctx.data.strs[key_atom].sym));
                  PushTemp(ctx, tex);
                  CallRt(ctx, 'array_push', 16);
                End;
              Emit1(ctx, OP_PUSH, AddrSym(SYMK_D, ctx.data.strs[key_atom].sym));
              PushTemp(ctx, tslot);
              CallRt(ctx, 'get_prop', 12);
              GenDefault(ctx, def);
            End;
          BindValue(ctx, target, init);
          Inc(nkeys);
          el := ctx.ast.nodes[el].next;
        End;
      If has_rest Then
        TempRelease(ctx, tex);
    End;
End;

{ ---- Entree de portee, declarations, instructions ---- }

Procedure GenScopeEnter(Var ctx: TCompilerContext; sc: LongInt);
Var
  sy, tag: LongInt;
Begin
  { premiere passe : cellules et valeurs initiales }
  sy := ctx.sem.scopes[sc].first_sym;
  While sy <> 0 Do
    Begin
      If ctx.sem.syms[sy].flags And SF_STATIC = 0 Then
        Begin
          tag := RT_T_UNDEFINED;
          If IsLexicalKind(ctx.sem.syms[sy].kind) And
             (ctx.sem.syms[sy].flags And SF_TDZ_CHECK <> 0) Then
            tag := RT_T_TDZ;
          If ctx.sem.syms[sy].flags And SF_CELL <> 0 Then
            Begin
              Emit1(ctx, OP_PUSH, ImmOp(TagImm(tag)));
              CallRt(ctx, 'new_cell', 4);
              Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(ctx.sem.syms[sy].slot)),
                   RegOp(R_EAX));
            End
          Else If (ctx.sem.syms[sy].kind = DK_VAR) Or
                  (ctx.sem.syms[sy].kind = DK_FUNC) Or (tag = RT_T_TDZ) Then
            Begin
              Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(ctx.sem.syms[sy].slot)),
                   ImmOp(0));
              Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(ctx.sem.syms[sy].slot) + 4),
                   ImmOp(TagImm(tag)));
            End;
        End;
      sy := ctx.sem.syms[sy].next;
    End;
  { seconde passe : les declarations de fonctions sont hissees avec leur valeur }
  sy := ctx.sem.scopes[sc].first_sym;
  While sy <> 0 Do
    Begin
      If ctx.sem.syms[sy].kind = DK_FUNC Then
        Begin
          GenMakeClosure(ctx, ctx.sem.syms[sy].node);
          StoreSym(ctx, sy, True);
        End;
      sy := ctx.sem.syms[sy].next;
    End;
End;

Procedure GenVarDecl(Var ctx: TCompilerContext; n: LongInt);
Var
  d, target, init, sy: LongInt;
  t: LongInt;
Begin
  d := ctx.ast.nodes[n].e1;
  While d <> 0 Do
    Begin
      target := ctx.ast.nodes[d].e1;
      init := ctx.ast.nodes[d].e2;
      If (target <> 0) And (ctx.ast.nodes[target].kind = N_BIND_IDENT) Then
        Begin
          sy := ctx.ast.nodes[target].sym;
          If init <> 0 Then
            Begin
              GenExpr(ctx, init);
              StoreSym(ctx, sy, True);
            End
          Else If ctx.sem.syms[sy].kind = DK_LET Then
            Begin
              LoadUndefined(ctx);
              StoreSym(ctx, sy, True);
            End;
        End
      Else If target <> 0 Then
        Begin
          GenExpr(ctx, init);
          t := AllocTemp(ctx);
          StoreTemp(ctx, t);
          BindTo(ctx, target, t, True);
        End;
      d := ctx.ast.nodes[d].next;
    End;
End;

Procedure GenStmtList(Var ctx: TCompilerContext; n: LongInt); Forward;

{ ---- Controle de flux (TODO 11) ----

  Chaque structure recoit ses etiquettes uniques (_JSL_nnnn). Une pile
  de cibles de saut memorise, pour chaque boucle, switch ou instruction
  etiquetee, l'etiquette de break, celle de continue et ses noms
  d'etiquettes. Une condition constante est resolue a la compilation
  (while (1), if (0)...).

  for-in et for-of passent par le runtime : _JSRT_iter_new(valeur)
  cree un iterateur (tableau ou chaine), _JSRT_iter_next(iterateur)
  rend la valeur suivante ou la marque DONE ; for-in parcourt
  _JSRT_forin_keys(objet), le tableau des noms de proprietes. Les
  variables let capturees de l'en-tete d'un for recoivent une nouvelle
  cellule a chaque iteration (_JSRT_cell_copy). }

Procedure GenStmt(Var ctx: TCompilerContext; n: LongInt); Forward;

Procedure PushTarget(Var ctx: TCompilerContext; kind, brk, cont: LongInt);
Var
  i: LongInt;
Begin
  If ctx.ir.jt_count >= MAX_JT Then
    Begin
      PipelineError(ctx, 'structures de controle imbriquees trop profondes');
      Exit;
    End;
  Inc(ctx.ir.jt_count);
  ctx.ir.jt[ctx.ir.jt_count].kind := kind;
  ctx.ir.jt[ctx.ir.jt_count].brk := brk;
  ctx.ir.jt[ctx.ir.jt_count].cont := cont;
  ctx.ir.jt[ctx.ir.jt_count].nlabels := ctx.ir.plabel_count;
  For i := 1 To ctx.ir.plabel_count Do
    ctx.ir.jt[ctx.ir.jt_count].labels[i] := ctx.ir.plabels[i];
  ctx.ir.plabel_count := 0;
End;

Procedure PopTarget(Var ctx: TCompilerContext);
Begin
  If ctx.ir.jt_count > 0 Then
    Dec(ctx.ir.jt_count);
End;

{ Cible d'un break ou continue : sans etiquette, la plus proche boucle
  (ou switch pour break) ; avec etiquette, celle qui la porte. }
Function FindTarget(Var ctx: TCompilerContext; label_tok: LongInt;
                    is_break: Boolean): LongInt;
Var
  i, j: LongInt;
Begin
  FindTarget := 0;
  For i := ctx.ir.jt_count Downto 1 Do
    Begin
      If label_tok = 0 Then
        Begin
          If (ctx.ir.jt[i].kind = JT_LOOP) Or
             (is_break And (ctx.ir.jt[i].kind = JT_SWITCH)) Then
            Begin
              FindTarget := i;
              Exit;
            End;
        End
      Else
        For j := 1 To ctx.ir.jt[i].nlabels Do
          If ctx.lex.tokens[ctx.ir.jt[i].labels[j]].text =
             ctx.lex.tokens[label_tok].text Then
            Begin
              FindTarget := i;
              Exit;
            End;
    End;
End;

{ Saute vers lfalse si la condition est fausse. }
Procedure GenCondJumpFalse(Var ctx: TCompilerContext; e, lfalse: LongInt);
Var
  c: TConst;
Begin
  If e = 0 Then
    Exit;
  If EvalConst(ctx, e, c) Then
    Begin
      If Not ConstTruthy(c) Then
        Emit1(ctx, OP_JMP, LabelOp(lfalse));
      Exit;
    End;
  GenExpr(ctx, e);
  GenTruthy(ctx);
  Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
  Emit1(ctx, OP_JE, LabelOp(lfalse));
End;

{ Saute vers ltrue si la condition est vraie. }
Procedure GenCondJumpTrue(Var ctx: TCompilerContext; e, ltrue: LongInt);
Var
  c: TConst;
Begin
  If e = 0 Then
    Begin
      Emit1(ctx, OP_JMP, LabelOp(ltrue));
      Exit;
    End;
  If EvalConst(ctx, e, c) Then
    Begin
      If ConstTruthy(c) Then
        Emit1(ctx, OP_JMP, LabelOp(ltrue));
      Exit;
    End;
  GenExpr(ctx, e);
  GenTruthy(ctx);
  Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
  Emit1(ctx, OP_JNE, LabelOp(ltrue));
End;

Procedure GenIf(Var ctx: TCompilerContext; n: LongInt);
Var
  els, done: LongInt;
Begin
  els := NewLabel(ctx);
  GenCondJumpFalse(ctx, ctx.ast.nodes[n].e1, els);
  GenStmt(ctx, ctx.ast.nodes[n].e2);
  If ctx.ast.nodes[n].e3 <> 0 Then
    Begin
      done := NewLabel(ctx);
      Emit1(ctx, OP_JMP, LabelOp(done));
      PlaceLabel(ctx, els);
      GenStmt(ctx, ctx.ast.nodes[n].e3);
      PlaceLabel(ctx, done);
    End
  Else
    PlaceLabel(ctx, els);
End;

Procedure GenWhile(Var ctx: TCompilerContext; n: LongInt);
Var
  top, brk: LongInt;
Begin
  top := NewLabel(ctx);
  brk := NewLabel(ctx);
  PlaceLabel(ctx, top);
  GenCondJumpFalse(ctx, ctx.ast.nodes[n].e1, brk);
  PushTarget(ctx, JT_LOOP, brk, top);
  GenStmt(ctx, ctx.ast.nodes[n].e2);
  PopTarget(ctx);
  Emit1(ctx, OP_JMP, LabelOp(top));
  PlaceLabel(ctx, brk);
End;

Procedure GenDoWhile(Var ctx: TCompilerContext; n: LongInt);
Var
  top, cont, brk: LongInt;
Begin
  top := NewLabel(ctx);
  cont := NewLabel(ctx);
  brk := NewLabel(ctx);
  PlaceLabel(ctx, top);
  PushTarget(ctx, JT_LOOP, brk, cont);
  GenStmt(ctx, ctx.ast.nodes[n].e1);
  PopTarget(ctx);
  PlaceLabel(ctx, cont);
  GenCondJumpTrue(ctx, ctx.ast.nodes[n].e2, top);
  PlaceLabel(ctx, brk);
End;

{ Nouvelle cellule (copie) pour chaque variable de l'en-tete capturee. }
Procedure GenPerIterationCopy(Var ctx: TCompilerContext; sc: LongInt);
Var
  sy: LongInt;
Begin
  sy := ctx.sem.scopes[sc].first_sym;
  While sy <> 0 Do
    Begin
      If (ctx.sem.syms[sy].flags And SF_PER_ITER <> 0) And
         (ctx.sem.syms[sy].flags And SF_CELL <> 0) Then
        Begin
          Emit1(ctx, OP_PUSH, MemReg(R_EBP, SlotDisp(ctx.sem.syms[sy].slot)));
          CallRt(ctx, 'cell_copy', 4);
          Emit(ctx, OP_MOV, MemReg(R_EBP, SlotDisp(ctx.sem.syms[sy].slot)),
               RegOp(R_EAX));
        End;
      sy := ctx.sem.syms[sy].next;
    End;
End;

Procedure GenFor(Var ctx: TCompilerContext; n: LongInt);
Var
  sc, top, cont, brk, init: LongInt;
Begin
  sc := ctx.ast.nodes[n].scope;
  top := NewLabel(ctx);
  cont := NewLabel(ctx);
  brk := NewLabel(ctx);
  GenScopeEnter(ctx, sc);
  init := ctx.ast.nodes[n].e1;
  If init <> 0 Then
    Begin
      If ctx.ast.nodes[init].kind = N_VAR_DECL Then
        GenVarDecl(ctx, init)
      Else
        GenExpr(ctx, init);
    End;
  PlaceLabel(ctx, top);
  If ctx.ast.nodes[n].e2 <> 0 Then
    GenCondJumpFalse(ctx, ctx.ast.nodes[n].e2, brk);
  PushTarget(ctx, JT_LOOP, brk, cont);
  GenStmt(ctx, ctx.ast.nodes[n].e4);
  PopTarget(ctx);
  PlaceLabel(ctx, cont);
  GenPerIterationCopy(ctx, sc);
  If ctx.ast.nodes[n].e3 <> 0 Then
    GenExpr(ctx, ctx.ast.nodes[n].e3);
  Emit1(ctx, OP_JMP, LabelOp(top));
  PlaceLabel(ctx, brk);
End;

{ for (x of valeur) et for (x in objet). }
Procedure GenForInOf(Var ctx: TCompilerContext; n: LongInt; is_of: Boolean);
Var
  sc, top, brk, iter, v, left, target: LongInt;
Begin
  sc := ctx.ast.nodes[n].scope;
  top := NewLabel(ctx);
  brk := NewLabel(ctx);
  iter := TempAcquire(ctx);
  v := TempAcquire(ctx);
  GenExpr(ctx, ctx.ast.nodes[n].e2);
  If Not is_of Then
    Begin
      Emit1(ctx, OP_PUSH, RegOp(R_EDX));
      Emit1(ctx, OP_PUSH, RegOp(R_EAX));
      CallRt(ctx, 'forin_keys', 8);
    End;
  Emit1(ctx, OP_PUSH, RegOp(R_EDX));
  Emit1(ctx, OP_PUSH, RegOp(R_EAX));
  CallRt(ctx, 'iter_new', 8);
  SaveTemp(ctx, iter);
  PlaceLabel(ctx, top);
  PushTemp(ctx, iter);
  CallRt(ctx, 'iter_next', 8);
  Emit(ctx, OP_CMP, RegOp(R_EDX), ImmOp(TagImm(RT_T_DONE)));
  Emit1(ctx, OP_JE, LabelOp(brk));
  SaveTemp(ctx, v);
  { nouvelle portee (nouvelles cellules) a chaque iteration }
  GenScopeEnter(ctx, sc);
  LoadTemp(ctx, v);
  left := ctx.ast.nodes[n].e1;
  If (left <> 0) And (ctx.ast.nodes[left].kind = N_VAR_DECL) Then
    Begin
      target := ctx.ast.nodes[ctx.ast.nodes[left].e1].e1;
      BindValue(ctx, target, True);
    End
  Else
    BindValue(ctx, left, False);
  PushTarget(ctx, JT_LOOP, brk, top);
  GenStmt(ctx, ctx.ast.nodes[n].e3);
  PopTarget(ctx);
  Emit1(ctx, OP_JMP, LabelOp(top));
  PlaceLabel(ctx, brk);
  TempRelease(ctx, v);
  TempRelease(ctx, iter);
End;

Procedure GenSwitch(Var ctx: TCompilerContext; n: LongInt);
Var
  t, brk, base, cs, i, ncases, dflt: LongInt;
Begin
  brk := NewLabel(ctx);
  ncases := 0;
  cs := ctx.ast.nodes[n].e2;
  While cs <> 0 Do
    Begin
      Inc(ncases);
      cs := ctx.ast.nodes[cs].next;
    End;
  base := ctx.ir.label_count + 1;
  Inc(ctx.ir.label_count, ncases);
  t := TempAcquire(ctx);
  GenExpr(ctx, ctx.ast.nodes[n].e1);
  SaveTemp(ctx, t);
  GenScopeEnter(ctx, ctx.ast.nodes[n].scope);
  { tests dans l'ordre : discriminant === valeur du case }
  dflt := 0;
  i := 0;
  cs := ctx.ast.nodes[n].e2;
  While cs <> 0 Do
    Begin
      If ctx.ast.nodes[cs].e1 = 0 Then
        dflt := base + i
      Else
        Begin
          GenExpr(ctx, ctx.ast.nodes[cs].e1);
          GenBinaryCore(ctx, '===', t);
          Emit(ctx, OP_TEST, RegOp(R_EAX), RegOp(R_EAX));
          Emit1(ctx, OP_JNE, LabelOp(base + i));
        End;
      Inc(i);
      cs := ctx.ast.nodes[cs].next;
    End;
  If dflt <> 0 Then
    Emit1(ctx, OP_JMP, LabelOp(dflt))
  Else
    Emit1(ctx, OP_JMP, LabelOp(brk));
  PushTarget(ctx, JT_SWITCH, brk, 0);
  i := 0;
  cs := ctx.ast.nodes[n].e2;
  While cs <> 0 Do
    Begin
      PlaceLabel(ctx, base + i);
      GenStmtList(ctx, ctx.ast.nodes[cs].e2);
      Inc(i);
      cs := ctx.ast.nodes[cs].next;
    End;
  PopTarget(ctx);
  PlaceLabel(ctx, brk);
  TempRelease(ctx, t);
End;

Procedure GenBreakContinue(Var ctx: TCompilerContext; n: LongInt; is_break: Boolean);
Var
  i: LongInt;
Begin
  i := FindTarget(ctx, ctx.ast.nodes[n].e1, is_break);
  If i = 0 Then
    Begin
      PendingNote(ctx, n, 'cible de break/continue introuvable');
      Exit;
    End;
  If is_break Then
    Emit1(ctx, OP_JMP, LabelOp(ctx.ir.jt[i].brk))
  Else
    Emit1(ctx, OP_JMP, LabelOp(ctx.ir.jt[i].cont));
End;

Procedure GenLabeled(Var ctx: TCompilerContext; n: LongInt);
Var
  inner, brk: LongInt;
Begin
  inner := ctx.ast.nodes[n].e1;
  If ctx.ir.plabel_count < 4 Then
    Begin
      Inc(ctx.ir.plabel_count);
      ctx.ir.plabels[ctx.ir.plabel_count] := ctx.ast.nodes[n].tok;
    End;
  If (inner <> 0) And
     ((ctx.ast.nodes[inner].kind = N_WHILE) Or (ctx.ast.nodes[inner].kind = N_DO_WHILE) Or
      (ctx.ast.nodes[inner].kind = N_FOR) Or (ctx.ast.nodes[inner].kind = N_FOR_IN) Or
      (ctx.ast.nodes[inner].kind = N_FOR_OF) Or (ctx.ast.nodes[inner].kind = N_SWITCH) Or
      (ctx.ast.nodes[inner].kind = N_LABELED)) Then
    GenStmt(ctx, inner)
  Else
    Begin
      { instruction etiquetee quelconque : seul break etiquete est permis }
      brk := NewLabel(ctx);
      PushTarget(ctx, JT_BLOCK, brk, 0);
      GenStmt(ctx, inner);
      PopTarget(ctx);
      PlaceLabel(ctx, brk);
    End;
End;

Procedure GenStmt(Var ctx: TCompilerContext; n: LongInt);
Begin
  If n = 0 Then
    Exit;
  ctx.ir.cur_line := ctx.lex.tokens[ctx.ast.nodes[n].tok].line;
  Case ctx.ast.nodes[n].kind Of
    N_VAR_DECL:
      GenVarDecl(ctx, n);
    N_EXPR_STMT:
      GenExpr(ctx, ctx.ast.nodes[n].e1);
    N_CLASS_DECL:
      GenClass(ctx, n);
    N_EMPTY, N_FUNC_DECL:
      ;
    N_DEBUGGER:
      Emit0(ctx, OP_NOP);
    N_BLOCK:
      Begin
        If ctx.ast.nodes[n].flags <> 1 Then
          GenScopeEnter(ctx, ctx.ast.nodes[n].scope);
        GenStmtList(ctx, ctx.ast.nodes[n].e1);
      End;
    N_RETURN:
      Begin
        If ctx.ast.nodes[n].e1 <> 0 Then
          GenExpr(ctx, ctx.ast.nodes[n].e1)
        Else
          LoadUndefined(ctx);
        Emit0(ctx, OP_LEAVE);
        Emit0(ctx, OP_RET);
      End;
    N_IF:
      GenIf(ctx, n);
    N_WHILE:
      GenWhile(ctx, n);
    N_DO_WHILE:
      GenDoWhile(ctx, n);
    N_FOR:
      GenFor(ctx, n);
    N_FOR_IN:
      GenForInOf(ctx, n, False);
    N_FOR_OF:
      GenForInOf(ctx, n, True);
    N_SWITCH:
      GenSwitch(ctx, n);
    N_BREAK:
      GenBreakContinue(ctx, n, True);
    N_CONTINUE:
      GenBreakContinue(ctx, n, False);
    N_LABELED:
      GenLabeled(ctx, n);
  Else
    PendingNote(ctx, n, NodeKindName(ctx.ast.nodes[n].kind));
  End;
End;

Procedure GenStmtList(Var ctx: TCompilerContext; n: LongInt);
Begin
  While n <> 0 Do
    Begin
      GenStmt(ctx, n);
      n := ctx.ast.nodes[n].next;
    End;
End;

{ ---- Procedures ---- }

{ Symbole de donnees d'une variable du runtime (_JSRT_v_nom). }
Function RtVarSym(Var ctx: TCompilerContext; Const name: TString): LongInt;
Var
  i: LongInt;
  full: TString;
Begin
  full := SymRt('v_' + name);
  RtVarSym := 0;
  For i := 1 To ctx.data.sym_count Do
    If (ctx.data.syms[i].sec = SEC_DATA) And (ctx.data.syms[i].name = full) Then
      Begin
        RtVarSym := i;
        Exit;
      End;
End;

Procedure BeginProc(Var ctx: TCompilerContext; Const name: TString; fs: LongInt);
Var
  xs, ok: LongInt;
Begin
  xs := XSym(ctx, name);
  ctx.ir.xsyms[xs].defined := True;
  Inc(ctx.ir.proc_count);
  ctx.ir.cg_fs := fs;
  ctx.ir.tmp_free_count := 0;
  ctx.ir.jt_count := 0;
  ctx.ir.plabel_count := 0;
  ctx.ir.in_chain := False;
  Emit1(ctx, OP_PROC, AddrSym(SYMK_X, xs));
  Emit1(ctx, OP_PUSH, RegOp(R_EBP));
  Emit(ctx, OP_MOV, RegOp(R_EBP), RegOp(R_ESP));
  Emit(ctx, OP_SUB, RegOp(R_ESP), ImmOp(0));
  ctx.ir.frame_patch := ctx.ir.count;
  If fs <> 1 Then
    Begin
      { depassement de pile : RangeError }
      ok := NewLabel(ctx);
      Emit(ctx, OP_CMP, RegOp(R_ESP),
           MemSym(SYMK_D, RtVarSym(ctx, 'stack_limit'), 0));
      Emit1(ctx, OP_JAE, LabelOp(ok));
      CallRt(ctx, 'stack_overflow', 0);
      PlaceLabel(ctx, ok);
    End;
End;

Procedure EndProc(Var ctx: TCompilerContext);
Begin
  LoadUndefined(ctx);
  Emit0(ctx, OP_LEAVE);
  Emit0(ctx, OP_RET);
  Emit1(ctx, OP_ENDP, NoOp);
  { taille definitive de la trame }
  ctx.ir.instrs[ctx.ir.frame_patch].b.disp :=
    RT_VALUE_SIZE * ctx.sem.scopes[ctx.ir.cg_fs].nslots;
  ctx.sem.scopes[ctx.ir.cg_fs].frame_size :=
    RT_VALUE_SIZE * ctx.sem.scopes[ctx.ir.cg_fs].nslots;
End;

{ Charge l'argument i (undefined s'il n'a pas ete fourni). }
Procedure LoadArg(Var ctx: TCompilerContext; i: LongInt);
Var
  have, done: LongInt;
Begin
  have := NewLabel(ctx);
  done := NewLabel(ctx);
  Emit(ctx, OP_CMP, MemReg(R_EBP, RT_FRAME_ARGC), ImmOp(i + 1));
  Emit1(ctx, OP_JAE, LabelOp(have));
  LoadUndefined(ctx);
  Emit1(ctx, OP_JMP, LabelOp(done));
  PlaceLabel(ctx, have);
  Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_EBP, RT_FRAME_ARGS + RT_VALUE_SIZE * i));
  Emit(ctx, OP_MOV, RegOp(R_EDX),
       MemReg(R_EBP, RT_FRAME_ARGS + RT_VALUE_SIZE * i + 4));
  PlaceLabel(ctx, done);
End;

Procedure GenParams(Var ctx: TCompilerContext; fn: LongInt);
Var
  p, i, target: LongInt;
Begin
  p := ctx.ast.nodes[fn].e1;
  i := 0;
  While p <> 0 Do
    Begin
      target := ctx.ast.nodes[p].e1;
      If ctx.ast.nodes[p].flags And PF_REST <> 0 Then
        Begin
          Emit1(ctx, OP_PUSH, ImmOp(i));
          Emit(ctx, OP_LEA, RegOp(R_EAX), MemReg(R_EBP, RT_FRAME_ARGS));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          Emit1(ctx, OP_PUSH, MemReg(R_EBP, RT_FRAME_ARGC));
          CallRt(ctx, 'args_rest', 12);
        End
      Else
        Begin
          LoadArg(ctx, i);
          GenDefault(ctx, ctx.ast.nodes[p].e2);
        End;
      BindValue(ctx, target, True);
      Inc(i);
      p := ctx.ast.nodes[p].next;
    End;
End;

{ Procedure d'une fonction, d'une methode, d'un initialiseur de champ ou
  d'un bloc statique decrit par le descripteur fd. }
Procedure GenFuncProc(Var ctx: TCompilerContext; fd: LongInt);
Var
  n, sc, sy, body: LongInt;
Begin
  n := ctx.data.fdescs[fd].node;
  sc := ctx.ast.nodes[n].scope;
  BeginProc(ctx, ctx.data.fdescs[fd].code_sym, sc);
  ctx.ir.cur_line := ctx.lex.tokens[ctx.ast.nodes[n].tok].line;
  EmitComment(ctx, 'fonction ' + StrText(ctx, ctx.data.fdescs[fd].name_str) +
              ' (' + SymFdesc(fd) + ')');
  GenScopeEnter(ctx, sc);
  { nom d'une expression de fonction : la closure elle-meme }
  sy := ctx.sem.scopes[sc].first_sym;
  While sy <> 0 Do
    Begin
      If ctx.sem.syms[sy].kind = DK_FNAME Then
        Begin
          Emit(ctx, OP_MOV, RegOp(R_EAX), MemReg(R_EBP, RT_FRAME_CLOSURE));
          Emit(ctx, OP_MOV, RegOp(R_EDX), ImmOp(TagImm(RT_T_FUNCTION)));
          StoreSym(ctx, sy, True);
        End;
      sy := ctx.sem.syms[sy].next;
    End;
  sy := ctx.sem.scopes[sc].first_sym;
  While sy <> 0 Do
    Begin
      If ctx.sem.syms[sy].kind = DK_ARGS Then
        Begin
          Emit(ctx, OP_LEA, RegOp(R_EAX), MemReg(R_EBP, RT_FRAME_ARGS));
          Emit1(ctx, OP_PUSH, RegOp(R_EAX));
          Emit1(ctx, OP_PUSH, MemReg(R_EBP, RT_FRAME_ARGC));
          CallRt(ctx, 'make_arguments', 8);
          StoreSym(ctx, sy, True);
        End;
      sy := ctx.sem.syms[sy].next;
    End;
  Case ctx.ast.nodes[n].kind Of
    N_FUNC_DECL, N_FUNC_EXPR, N_METHOD:
      Begin
        GenParams(ctx, n);
        If (ctx.ast.nodes[n].kind = N_METHOD) And
           (ctx.sem.scopes[sc].fkind = FK_CTOR) Then
          Begin
            { constructeur de base : champs d'instance avant le corps }
            Emit1(ctx, OP_PUSH, MemReg(R_EBP, RT_FRAME_THIS + 4));
            Emit1(ctx, OP_PUSH, MemReg(R_EBP, RT_FRAME_THIS));
            Emit1(ctx, OP_PUSH, MemReg(R_EBP, RT_FRAME_CLOSURE));
            CallRt(ctx, 'init_fields', 12);
          End;
        body := ctx.ast.nodes[n].e2;
        If (ctx.ast.nodes[n].kind = N_FUNC_EXPR) And
           (ctx.ast.nodes[n].flags And FN_EXPR_BODY <> 0) Then
          Begin
            { corps expression d'une fleche : sa valeur est le resultat }
            GenExpr(ctx, body);
            Emit0(ctx, OP_LEAVE);
            Emit0(ctx, OP_RET);
          End
        Else
          GenStmtList(ctx, ctx.ast.nodes[body].e1);
      End;
    N_FIELD:
      Begin
        GenExpr(ctx, ctx.ast.nodes[n].e1);
        Emit0(ctx, OP_LEAVE);
        Emit0(ctx, OP_RET);
      End;
    N_STATIC_BLOCK:
      GenStmt(ctx, ctx.ast.nodes[n].e1);
  End;
  EndProc(ctx);
End;

Procedure EmitRuntime(Var ctx: TCompilerContext); Forward;

Function BuildIR(Var ctx: TCompilerContext): Boolean;
Var
  i: LongInt;
Begin
  BuildIR := False;
  If Not ctx.data.built Then
    Begin
      PipelineError(ctx, 'pool de donnees absent avant la generation du code');
      Exit;
    End;
  ctx.ir.count := 0;
  ctx.ir.xsym_count := 0;
  ctx.ir.comment_count := 0;
  ctx.ir.label_count := 0;
  ctx.ir.proc_count := 0;
  ctx.ir.pending_count := 0;
  ctx.ir.failed := False;
  ctx.ir.cur_line := 1;
  LayoutFrames(ctx);

  { programme principal : portee globale }
  BeginProc(ctx, SymRt('main'), 1);
  EmitComment(ctx, 'programme principal');
  GenScopeEnter(ctx, 1);
  GenStmtList(ctx, ctx.ast.nodes[ctx.ast.root].e1);
  EndProc(ctx);

  For i := 1 To ctx.data.fd_count Do
    If Not ctx.ir.failed Then
      GenFuncProc(ctx, i);

  If Not ctx.ir.failed Then
    EmitRuntime(ctx);
  ctx.ir.built := Not ctx.ir.failed;
  If ctx.options.verbose Then
    Writeln('Code   : ', ctx.ir.proc_count, ' procedures, ', ctx.ir.count,
            ' instructions, ', ctx.ir.pending_count,
            ' constructions en attente');
  BuildIR := ctx.ir.built And (ctx.errors = 0);
End;

{ ---- Affichage de l'IR (option -ir) ---- }

Function HexU(v: Int64): TString;
Const
  H = '0123456789ABCDEF';
Var
  s: TString;
  i: Integer;
Begin
  v := v And $FFFFFFFF;
  s := '';
  For i := 1 To 8 Do
    Begin
      s := H[(v And 15) + 1] + s;
      v := v Shr 4;
    End;
  HexU := s;
End;

Function ImmText(v: LongInt): TString;
Var
  s: String[12];
Begin
  If (v > -65536) And (v < 1048576) Then
    Begin
      Str(v, s);
      ImmText := s;
    End
  Else
    ImmText := '0' + HexU(v) + 'h';
End;

Function RegName(r: TReg): TString;
Begin
  Case r Of
    R_EAX: RegName := 'eax';
    R_ECX: RegName := 'ecx';
    R_EDX: RegName := 'edx';
    R_EBX: RegName := 'ebx';
    R_ESP: RegName := 'esp';
    R_EBP: RegName := 'ebp';
    R_ESI: RegName := 'esi';
    R_EDI: RegName := 'edi';
    R_CL:  RegName := 'cl';
    R_AL:  RegName := 'al';
    R_DL:  RegName := 'dl';
    R_BL:  RegName := 'bl';
  Else
    RegName := '?';
  End;
End;

Function SymNameOf(Var ctx: TCompilerContext; symkind, sym: LongInt): TString;
Begin
  If symkind = SYMK_D Then
    SymNameOf := ctx.data.syms[sym].name
  Else
    SymNameOf := ctx.ir.xsyms[sym].name;
End;

Function DispText(d: LongInt): TString;
Var
  s: String[12];
Begin
  If d = 0 Then
    DispText := ''
  Else If d > 0 Then
    Begin
      Str(d, s);
      DispText := '+' + s;
    End
  Else
    Begin
      Str(d, s);
      DispText := s;
    End;
End;

Function OperandText(Var ctx: TCompilerContext; Var o: TOperand): TString;
Var
  pfx, inner: TString;
Begin
  Case o.kind Of
    OD_REG:
      OperandText := RegName(o.reg);
    OD_IMM:
      OperandText := ImmText(o.disp);
    OD_MEM:
      Begin
        Begin
          If o.size = 1 Then
            pfx := 'byte ptr ['
          Else
            pfx := 'dword ptr [';
          inner := '';
          If o.base <> R_NONE Then
            inner := RegName(o.base);
          If o.index <> R_NONE Then
            Begin
              If inner <> '' Then
                inner := inner + '+';
              inner := inner + RegName(o.index);
            End;
          If o.symkind <> 0 Then
            Begin
              If inner <> '' Then
                inner := inner + '+';
              inner := inner + SymNameOf(ctx, o.symkind, o.sym);
            End;
          OperandText := pfx + inner + DispText(o.disp) + ']';
        End;
      End;
    OD_ADDR:
      OperandText := 'offset ' + SymNameOf(ctx, o.symkind, o.sym);
    OD_LABEL:
      OperandText := SymLabel(o.disp);
  Else
    OperandText := '';
  End;
End;

Function OpName(op: TOpc): TString;
Begin
  Case op of
    OP_MOV: OpName := 'mov';
    OP_LEA: OpName := 'lea';
    OP_PUSH: OpName := 'push';
    OP_POP: OpName := 'pop';
    OP_ADD: OpName := 'add';
    OP_SUB: OpName := 'sub';
    OP_CMP: OpName := 'cmp';
    OP_TEST: OpName := 'test';
    OP_XOR: OpName := 'xor';
    OP_AND: OpName := 'and';
    OP_JMP: OpName := 'jmp';
    OP_JE: OpName := 'je';
    OP_JNE: OpName := 'jne';
    OP_JB: OpName := 'jb';
    OP_JAE: OpName := 'jae';
    OP_CALL: OpName := 'call';
    OP_RET: OpName := 'ret';
    OP_LEAVE: OpName := 'leave';
    OP_NOP: OpName := 'nop';
    OP_IMUL: OpName := 'imul';
    OP_OR: OpName := 'or';
    OP_NOT: OpName := 'not';
    OP_NEG: OpName := 'neg';
    OP_SHL: OpName := 'shl';
    OP_SHR: OpName := 'shr';
    OP_SAR: OpName := 'sar';
    OP_CDQ: OpName := 'cdq';
    OP_IDIV: OpName := 'idiv';
    OP_JL: OpName := 'jl';
    OP_JLE: OpName := 'jle';
    OP_JG: OpName := 'jg';
    OP_JGE: OpName := 'jge';
    OP_JA: OpName := 'ja';
    OP_JBE: OpName := 'jbe';
    OP_JO: OpName := 'jo';
    OP_JNO: OpName := 'jno';
    OP_JS: OpName := 'js';
    OP_JNS: OpName := 'jns';
    OP_MOVZX: OpName := 'movzx';
    OP_INC: OpName := 'inc';
    OP_DEC: OpName := 'dec';
    OP_DIV: OpName := 'div';
    OP_REP_MOVSB: OpName := 'rep movsb';
  Else
    OpName := '?';
  End;
End;

Procedure DumpIR(Var ctx: TCompilerContext);
Var
  i, limit: LongInt;
  a, b: TString;
  op: TOpc;
Begin
  If Not ctx.ir.built Then
    Exit;
  Writeln('Code (', ctx.ir.proc_count, ' procedures, ', ctx.ir.count,
          ' instructions) :');
  If ctx.options.dump_rt Then
    limit := ctx.ir.count
  Else
    limit := ctx.ir.user_count;
  For i := 1 To limit Do
    Begin
      op := ctx.ir.instrs[i].op;
      Case op Of
        OP_LABEL:
          Writeln(OperandText(ctx, ctx.ir.instrs[i].a), ':');
        OP_COMMENT:
          Writeln('        ; ', ctx.ir.comments[ctx.ir.instrs[i].a.disp]);
        OP_PROC:
          Begin
            Writeln;
            Writeln(SymNameOf(ctx, ctx.ir.instrs[i].a.symkind, ctx.ir.instrs[i].a.sym), ' proc');
          End;
        OP_ENDP:
          Writeln('        endp');
      Else
        Begin
          a := OperandText(ctx, ctx.ir.instrs[i].a);
          b := OperandText(ctx, ctx.ir.instrs[i].b);
          If (op = OP_CALL) And (ctx.ir.instrs[i].a.kind = OD_ADDR) Then
            a := SymNameOf(ctx, ctx.ir.instrs[i].a.symkind, ctx.ir.instrs[i].a.sym);
          Write('        ', OpName(op));
          If a <> '' Then
            Write(' ', a);
          If b <> '' Then
            Write(', ', b);
          Writeln;
        End;
      End;
    End;
  Writeln('Symboles externes non definis :');
  For i := 1 To ctx.ir.xsym_count Do
    If Not ctx.ir.xsyms[i].defined And
       (DsymFind(ctx, ctx.ir.xsyms[i].name) = 0) Then
      Writeln('  ', ctx.ir.xsyms[i].name);
  If ctx.ir.pending_count > 0 Then
    Begin
      Writeln('Constructions en attente (', ctx.ir.pending_count, ') :');
      For i := 1 To ctx.ir.pending_count Do
        If i <= MAX_PENDING Then
          Writeln('  ligne ', ctx.ir.pendings[i].line, ' : ',
                  ctx.ir.pendings[i].what);
    End;
End;

Function IntToStr(n: LongInt): TString;
Var
  s: String[12];
Begin
  Str(n, s);
  IntToStr := s;
End;

{ ============================================================
  MINI-ASSEMBLEUR ET GENERATEUR DU RUNTIME (TODO 14)

  Le runtime est ecrit en assembleur 80386 sous forme de lignes de texte
  (A('mov eax, [ebp+8]')) assemblees vers la meme IR que le code genere.
  Syntaxe : mnemoniques en minuscules, registres eax..edi et al, cl, dl,
  bl ; operandes memoire [base+index+deplacement], dword ptr / byte ptr
  facultatifs ; offset symbole ; etiquettes locales .nom ; macros $NOM
  (etiquettes de type $STR, deplacements $STR_LEN...). Un symbole inconnu
  est un symbole externe, resolu a l'edition de liens.

  Convention du runtime : cdecl, arguments de 8 octets (valeurs) ou de 4
  octets (pointeurs, entiers), resultat dans EDX:EAX ou EAX ; EBX, ESI,
  EDI et EBP preserves ; ECX, EDX et EAX libres.
  ============================================================ }

Type
  PCtx = ^TCompilerContext;

Var
  asm_ctx: PCtx;
  asm_lbl_name: Array[1..160] Of String[24];
  asm_lbl_id: Array[1..160] Of LongInt;
  asm_lbl_count: LongInt;
  asm_uniq: LongInt;
  asm_failed: Boolean;

Function AsmTrim(s: TString): TString;
Begin
  While (Length(s) > 0) And (s[1] = ' ') Do
    Delete(s, 1, 1);
  While (Length(s) > 0) And (s[Length(s)] = ' ') Do
    Delete(s, Length(s), 1);
  AsmTrim := s;
End;

Procedure AsmFail(Const msg, line: TString);
Begin
  If Not asm_failed Then
    PipelineError(asm_ctx^, 'assembleur interne: ' + msg + ' : ' + line);
  asm_failed := True;
End;

{ Valeur d'une macro $NOM. }
Function AsmMacro(Const nm: TString; Var v: LongInt): Boolean;
Begin
  AsmMacro := True;
  If nm = 'INT' Then v := TagImm(RT_T_INT32)
  Else If nm = 'UNDEF' Then v := TagImm(RT_T_UNDEFINED)
  Else If nm = 'NULL' Then v := TagImm(RT_T_NULL)
  Else If nm = 'BOOL' Then v := TagImm(RT_T_BOOLEAN)
  Else If nm = 'STR' Then v := TagImm(RT_T_STRING)
  Else If nm = 'OBJ' Then v := TagImm(RT_T_OBJECT)
  Else If nm = 'ARR' Then v := TagImm(RT_T_ARRAY)
  Else If nm = 'FN' Then v := TagImm(RT_T_FUNCTION)
  Else If nm = 'RX' Then v := TagImm(RT_T_REGEXP)
  Else If nm = 'TDZ' Then v := TagImm(RT_T_TDZ)
  Else If nm = 'DONE' Then v := TagImm(RT_T_DONE)
  Else If nm = 'STR_LEN' Then v := RT_STR_LEN
  Else If nm = 'STR_HASH' Then v := RT_STR_HASH
  Else If nm = 'STR_DATA' Then v := RT_STR_DATA
  Else If nm = 'ARR_LEN' Then v := RT_ARR_LEN
  Else If nm = 'ARR_CAP' Then v := RT_ARR_CAP
  Else If nm = 'ARR_ELEMS' Then v := RT_ARR_ELEMS
  Else If nm = 'OBJ_PROTO' Then v := RT_OBJ_PROTO
  Else If nm = 'OBJ_PROPS' Then v := RT_OBJ_PROPS
  Else If nm = 'OBJ_COUNT' Then v := RT_OBJ_COUNT
  Else If nm = 'OBJ_CAP' Then v := RT_OBJ_CAP
  Else If nm = 'OBJ_CLASS' Then v := RT_OBJ_CLASS
  Else If nm = 'FN_CODE' Then v := RT_FN_CODE
  Else If nm = 'FN_ENV' Then v := RT_FN_ENV
  Else If nm = 'FN_DESC' Then v := RT_FN_DESC
  Else If nm = 'FN_PROPS' Then v := RT_FN_PROPS
  Else If nm = 'FN_THIS' Then v := RT_FN_THIS
  Else If nm = 'CELL_VALUE' Then v := RT_CELL_VALUE
  Else If nm = 'ENV_CELLS' Then v := RT_ENV_CELLS
  Else If nm = 'HDR_SIZE' Then v := RT_HDR_SIZE
  Else If nm = 'OK_STRING' Then v := RT_OK_STRING
  Else If nm = 'OK_ARRAY' Then v := RT_OK_ARRAY
  Else If nm = 'OK_OBJECT' Then v := RT_OK_OBJECT
  Else If nm = 'OK_FUNCTION' Then v := RT_OK_FUNCTION
  Else If nm = 'OK_CELL' Then v := RT_OK_CELL
  Else If nm = 'OK_ENV' Then v := RT_OK_ENV
  Else
    AsmMacro := False;
End;

Function AsmHexVal(c: Char): LongInt;
Begin
  If (c >= '0') And (c <= '9') Then
    AsmHexVal := Ord(c) - 48
  Else If (c >= 'a') And (c <= 'f') Then
    AsmHexVal := Ord(c) - 87
  Else If (c >= 'A') And (c <= 'F') Then
    AsmHexVal := Ord(c) - 55
  Else
    AsmHexVal := -1;
End;

{ Nombre decimal, hexadecimal 0x..., caractere 'c' ou macro $NOM. }
Function AsmNumber(Const t: TString; Var v: LongInt): Boolean;
Var
  i: Integer;
  neg: Boolean;
  w: Int64;
  d: LongInt;
Begin
  AsmNumber := False;
  If t = '' Then
    Exit;
  If t[1] = '$' Then
    Begin
      AsmNumber := AsmMacro(Copy(t, 2, Length(t) - 1), v);
      Exit;
    End;
  If (Length(t) = 3) And (t[1] = '''') And (t[3] = '''') Then
    Begin
      v := Ord(t[2]);
      AsmNumber := True;
      Exit;
    End;
  i := 1;
  neg := False;
  If t[1] = '-' Then
    Begin
      neg := True;
      i := 2;
    End;
  If i > Length(t) Then
    Exit;
  w := 0;
  If (Length(t) >= i + 2) And (t[i] = '0') And ((t[i + 1] = 'x') Or (t[i + 1] = 'X')) Then
    Begin
      Inc(i, 2);
      If i > Length(t) Then
        Exit;
      While i <= Length(t) Do
        Begin
          d := AsmHexVal(t[i]);
          If d < 0 Then
            Exit;
          w := w * 16 + d;
          Inc(i);
        End;
    End
  Else
    While i <= Length(t) Do
      Begin
        If (t[i] < '0') Or (t[i] > '9') Then
          Exit;
        w := w * 10 + (Ord(t[i]) - 48);
        Inc(i);
      End;
  If neg Then
    w := -w;
  v := ToLong(w);
  AsmNumber := True;
End;

Function AsmReg(Const t: TString): TReg;
Begin
  AsmReg := R_NONE;
  If t = 'eax' Then AsmReg := R_EAX
  Else If t = 'ecx' Then AsmReg := R_ECX
  Else If t = 'edx' Then AsmReg := R_EDX
  Else If t = 'ebx' Then AsmReg := R_EBX
  Else If t = 'esp' Then AsmReg := R_ESP
  Else If t = 'ebp' Then AsmReg := R_EBP
  Else If t = 'esi' Then AsmReg := R_ESI
  Else If t = 'edi' Then AsmReg := R_EDI
  Else If t = 'al' Then AsmReg := R_AL
  Else If t = 'cl' Then AsmReg := R_CL
  Else If t = 'dl' Then AsmReg := R_DL
  Else If t = 'bl' Then AsmReg := R_BL;
End;

Function IsReg8(r: TReg): Boolean;
Begin
  IsReg8 := (r = R_AL) Or (r = R_CL) Or (r = R_DL) Or (r = R_BL);
End;

Function AsmLabelId(Const nm: TString): LongInt;
Var
  i: LongInt;
Begin
  For i := 1 To asm_lbl_count Do
    If asm_lbl_name[i] = nm Then
      Begin
        AsmLabelId := asm_lbl_id[i];
        Exit;
      End;
  If asm_lbl_count >= 160 Then
    Begin
      AsmFail('trop d''etiquettes locales', nm);
      AsmLabelId := 0;
      Exit;
    End;
  Inc(asm_lbl_count);
  asm_lbl_name[asm_lbl_count] := nm;
  asm_lbl_id[asm_lbl_count] := NewLabel(asm_ctx^);
  AsmLabelId := asm_lbl_id[asm_lbl_count];
End;

{ Symbole de donnees (pool) ou, a defaut, symbole de code ou externe. }
Procedure AsmSymbol(Const nm: TString; Var symkind, sym: LongInt);
Var
  d: LongInt;
Begin
  d := DsymFind(asm_ctx^, nm);
  If d <> 0 Then
    Begin
      symkind := SYMK_D;
      sym := d;
    End
  Else
    Begin
      symkind := SYMK_X;
      sym := XSym(asm_ctx^, nm);
    End;
End;

Function AsmIsIdentStart(c: Char): Boolean;
Begin
  AsmIsIdentStart := ((c >= 'A') And (c <= 'Z')) Or ((c >= 'a') And (c <= 'z')) Or
                     (c = '_') Or (c = '@');
End;

Procedure AsmMemory(Const inner: TString; Var o: TOperand; Const line: TString);
Var
  i, j: Integer;
  sign, v: LongInt;
  tok: TString;
  r: TReg;
Begin
  i := 1;
  sign := 1;
  While i <= Length(inner) Do
    Begin
      If inner[i] = ' ' Then
        Inc(i)
      Else If inner[i] = '+' Then
        Begin
          sign := 1;
          Inc(i);
        End
      Else If inner[i] = '-' Then
        Begin
          sign := -1;
          Inc(i);
        End
      Else
        Begin
          j := i;
          While (j <= Length(inner)) And (inner[j] <> '+') And (inner[j] <> '-') And
                (inner[j] <> ' ') Do
            Inc(j);
          tok := Copy(inner, i, j - i);
          i := j;
          r := AsmReg(tok);
          If r <> R_NONE Then
            Begin
              If o.base = R_NONE Then
                o.base := r
              Else
                o.index := r;
            End
          Else If AsmNumber(tok, v) Then
            o.disp := o.disp + sign * v
          Else If AsmIsIdentStart(tok[1]) Then
            AsmSymbol(tok, o.symkind, o.sym)
          Else
            AsmFail('terme memoire invalide ' + tok, line);
          sign := 1;
        End;
    End;
End;

Procedure AsmOperand(Const txt0: TString; Var o: TOperand; Const line: TString);
Var
  txt: TString;
  v: LongInt;
  r: TReg;
  sz: Byte;
Begin
  FillChar(o, SizeOf(o), 0);
  txt := AsmTrim(txt0);
  sz := 0;
  If Copy(txt, 1, 10) = 'dword ptr ' Then
    Begin
      Delete(txt, 1, 10);
      sz := 4;
    End
  Else If Copy(txt, 1, 9) = 'byte ptr ' Then
    Begin
      Delete(txt, 1, 9);
      sz := 1;
    End;
  If txt = '' Then
    Exit;
  If txt[1] = '[' Then
    Begin
      o.kind := OD_MEM;
      o.size := sz;
      AsmMemory(Copy(txt, 2, Length(txt) - 2), o, line);
      Exit;
    End;
  If Copy(txt, 1, 7) = 'offset ' Then
    Begin
      o.kind := OD_ADDR;
      AsmSymbol(AsmTrim(Copy(txt, 8, Length(txt) - 7)), o.symkind, o.sym);
      Exit;
    End;
  r := AsmReg(txt);
  If r <> R_NONE Then
    Begin
      o.kind := OD_REG;
      o.reg := r;
      Exit;
    End;
  If AsmNumber(txt, v) Then
    Begin
      o.kind := OD_IMM;
      o.disp := v;
      Exit;
    End;
  If txt[1] = '.' Then
    Begin
      o.kind := OD_LABEL;
      o.disp := AsmLabelId(txt);
      Exit;
    End;
  If AsmIsIdentStart(txt[1]) Then
    Begin
      o.kind := OD_ADDR;
      AsmSymbol(txt, o.symkind, o.sym);
      Exit;
    End;
  AsmFail('operande invalide ' + txt, line);
End;

Function AsmFindOp(Const m: TString): TOpc;
Var
  op: TOpc;
Begin
  AsmFindOp := OP_NONE;
  If m = 'jz' Then
    AsmFindOp := OP_JE
  Else If m = 'jnz' Then
    AsmFindOp := OP_JNE
  Else If m = 'jc' Then
    AsmFindOp := OP_JB
  Else If m = 'jnc' Then
    AsmFindOp := OP_JAE
  Else
    For op := OP_MOV To OP_REP_MOVSB Do
      If OpName(op) = m Then
        AsmFindOp := op;
End;

{ Assemble une ligne : etiquette locale, directive proc/endp ou
  instruction. }
Procedure A(Const line0: TString);
Var
  line, m, rest, a1, a2: TString;
  p, i, depth: Integer;
  op: TOpc;
  oa, ob: TOperand;
  xs: LongInt;
Begin
  line := line0;
  p := Pos(';', line);
  If p > 0 Then
    line := Copy(line, 1, p - 1);
  line := AsmTrim(line);
  If line = '' Then
    Exit;
  If (line[1] = '.') And (line[Length(line)] = ':') Then
    Begin
      PlaceLabel(asm_ctx^, AsmLabelId(Copy(line, 1, Length(line) - 1)));
      Exit;
    End;
  If Copy(line, 1, 5) = 'proc ' Then
    Begin
      xs := XSym(asm_ctx^, AsmTrim(Copy(line, 6, Length(line) - 5)));
      asm_ctx^.ir.xsyms[xs].defined := True;
      asm_ctx^.ir.xsyms[xs].runtime := True;
      Inc(asm_ctx^.ir.proc_count);
      asm_lbl_count := 0;
      Emit1(asm_ctx^, OP_PROC, AddrSym(SYMK_X, xs));
      Exit;
    End;
  If line = 'endp' Then
    Begin
      Emit1(asm_ctx^, OP_ENDP, NoOp);
      Exit;
    End;
  If line = 'rep movsb' Then
    Begin
      Emit0(asm_ctx^, OP_REP_MOVSB);
      Exit;
    End;
  p := Pos(' ', line);
  If p = 0 Then
    Begin
      m := line;
      rest := '';
    End
  Else
    Begin
      m := Copy(line, 1, p - 1);
      rest := AsmTrim(Copy(line, p + 1, Length(line) - p));
    End;
  op := AsmFindOp(m);
  If op = OP_NONE Then
    Begin
      AsmFail('mnemonique inconnu ' + m, line0);
      Exit;
    End;
  { separer les deux operandes a la premiere virgule hors crochets }
  a1 := rest;
  a2 := '';
  depth := 0;
  For i := 1 To Length(rest) Do
    Begin
      If rest[i] = '[' Then
        Inc(depth)
      Else If rest[i] = ']' Then
        Dec(depth)
      Else If (rest[i] = ',') And (depth = 0) Then
        Begin
          a1 := Copy(rest, 1, i - 1);
          a2 := Copy(rest, i + 1, Length(rest) - i);
          Break;
        End;
    End;
  AsmOperand(a1, oa, line0);
  AsmOperand(a2, ob, line0);
  { un registre 8 bits impose la taille octet a l'autre operande memoire }
  If ((oa.kind = OD_REG) And IsReg8(oa.reg) And (op <> OP_SHL) And (op <> OP_SHR) And
      (op <> OP_SAR)) Or ((ob.kind = OD_REG) And IsReg8(ob.reg) And (op <> OP_SHL) And
      (op <> OP_SHR) And (op <> OP_SAR)) Then
    Begin
      If oa.kind = OD_MEM Then
        oa.size := 1;
      If ob.kind = OD_MEM Then
        ob.size := 1;
    End;
  Emit(asm_ctx^, op, oa, ob);
End;

{ Etiquette locale unique pour les macros d'assembleur. }
Function U(Const prefix: TString): TString;
Var
  s: String[12];
Begin
  Inc(asm_uniq);
  Str(asm_uniq, s);
  U := '.' + prefix + s;
End;

{ ---- Donnees statiques du runtime ---- }

{ Symbole de la chaine statique text (elle est creee si besoin). }
Function RtStr(Const text: TString): TString;
Var
  id: LongInt;
Begin
  id := InternText(asm_ctx^, text);
  If (id <> 0) And (asm_ctx^.data.strs[id].sym = 0) Then
    EmitStringCell(asm_ctx^, id);
  RtStr := SymStr(id);
End;

{ Octets d'une chaine C (zero final) dans .rdata. }
Procedure RtCString(Const name, text: TString);
Var
  ofs, i: LongInt;
Begin
  ofs := SecAlloc(asm_ctx^, SEC_RDATA, Length(text) + 1);
  For i := 1 To Length(text) Do
    PutByte(asm_ctx^, SEC_RDATA, ofs + i - 1, Ord(text[i]));
  NewDataSym(asm_ctx^, name, SEC_RDATA, ofs, Length(text) + 1, DS_STRING);
End;

{ Descripteur de fonction statique pour le code ; retourne son symbole. }
Function RtDescSym(Const jsname, code: TString; nparams, flags: LongInt): LongInt;
Var
  fd_ofs: LongInt;
Begin
  fd_ofs := SecAlloc(asm_ctx^, SEC_RDATA, RT_FD_SIZE);
  AddReloc(asm_ctx^, SEC_RDATA, fd_ofs + RT_FD_NAME,
           DsymFind(asm_ctx^, RtStr(jsname)));
  PutDword(asm_ctx^, SEC_RDATA, fd_ofs + RT_FD_NPARAMS, nparams);
  PutDword(asm_ctx^, SEC_RDATA, fd_ofs + RT_FD_FLAGS, flags);
  RtDescSym := NewDataSym(asm_ctx^, '_JSND_' + code, SEC_RDATA, fd_ofs, RT_FD_SIZE,
                          DS_FDESC);
End;

{ Objet fonction natif statique ; retourne le symbole de donnees. }
Function RtFuncObjP(Const jsname, code: TString; nparams, props: LongInt): LongInt;
Var
  fd_ofs, fo_ofs, fd_sym: LongInt;
Begin
  fd_ofs := SecAlloc(asm_ctx^, SEC_RDATA, RT_FD_SIZE);
  AddReloc(asm_ctx^, SEC_RDATA, fd_ofs + RT_FD_NAME,
           DsymFind(asm_ctx^, RtStr(jsname)));
  PutDword(asm_ctx^, SEC_RDATA, fd_ofs + RT_FD_NPARAMS, nparams);
  PutDword(asm_ctx^, SEC_RDATA, fd_ofs + RT_FD_FLAGS, FDF_NATIVE);
  fd_sym := NewDataSym(asm_ctx^, '_JSND_' + code, SEC_RDATA, fd_ofs, RT_FD_SIZE,
                       DS_FDESC);
  fo_ofs := SecAlloc(asm_ctx^, SEC_RDATA, RT_FN_SIZE);
  PutByte(asm_ctx^, SEC_RDATA, fo_ofs + RT_HDR_KIND, RT_OK_FUNCTION);
  PutByte(asm_ctx^, SEC_RDATA, fo_ofs + RT_HDR_FLAGS, OF_STATIC);
  AddRelocX(asm_ctx^, SEC_RDATA, fo_ofs + RT_FN_CODE, XSym(asm_ctx^, code));
  AddReloc(asm_ctx^, SEC_RDATA, fo_ofs + RT_FN_DESC, fd_sym);
  If props <> 0 Then
    AddReloc(asm_ctx^, SEC_RDATA, fo_ofs + RT_FN_PROPS, props);
  PutDword(asm_ctx^, SEC_RDATA, fo_ofs + RT_FN_THIS + 4, TagImm(RT_T_UNDEFINED));
  RtFuncObjP := NewDataSym(asm_ctx^, '_JSNF_' + code, SEC_RDATA, fo_ofs, RT_FN_SIZE,
                          DS_FDESC);
End;

Function RtFuncObj(Const jsname, code: TString; nparams: LongInt): LongInt;
Begin
  RtFuncObj := RtFuncObjP(jsname, code, nparams, 0);
End;

{ Construction d'un objet statique : proprietes ajoutees puis objet cree. }
Var
  bo_key: Array[1..64] Of String[40];
  bo_val: Array[1..64] Of LongInt;
  bo_tag: Array[1..64] Of LongInt;
  bo_n: LongInt;

Procedure BoReset;
Begin
  bo_n := 0;
End;

Procedure BoAdd(Const key: TString; valsym, tag: LongInt);
Begin
  Inc(bo_n);
  bo_key[bo_n] := key;
  bo_val[bo_n] := valsym;
  bo_tag[bo_n] := tag;
End;

{ proto : symbole de donnees du prototype (0 aucun). }
Function BoFinish(Const name: TString; proto: LongInt): LongInt;
Var
  props_ofs, obj_ofs, i, props_sym: LongInt;
Begin
  props_sym := 0;
  props_ofs := 0;
  If bo_n > 0 Then
    Begin
      props_ofs := SecAlloc(asm_ctx^, SEC_RDATA, RT_PROP_SIZE * bo_n);
      For i := 1 To bo_n Do
        Begin
          AddReloc(asm_ctx^, SEC_RDATA, props_ofs + RT_PROP_SIZE * (i - 1) + RT_PROP_KEY,
                   DsymFind(asm_ctx^, RtStr(bo_key[i])));
          AddReloc(asm_ctx^, SEC_RDATA, props_ofs + RT_PROP_SIZE * (i - 1) + RT_PROP_VALUE,
                   bo_val[i]);
          PutDword(asm_ctx^, SEC_RDATA,
                   props_ofs + RT_PROP_SIZE * (i - 1) + RT_PROP_VALUE + 4, TagImm(bo_tag[i]));
        End;
      props_sym := NewDataSym(asm_ctx^, name + '_props', SEC_RDATA, props_ofs,
                              RT_PROP_SIZE * bo_n, DS_FDESC);
    End;
  { l'en-tete est dans .data (modifiable) ; le tableau de proprietes reste
    en lecture seule et est copie au premier changement }
  obj_ofs := SecAlloc(asm_ctx^, SEC_DATA, RT_OBJ_SIZE);
  PutByte(asm_ctx^, SEC_DATA, obj_ofs + RT_HDR_KIND, RT_OK_OBJECT);
  If bo_n > 0 Then
    PutByte(asm_ctx^, SEC_DATA, obj_ofs + RT_HDR_FLAGS, OF_STATIC Or OF_ROPROPS)
  Else
    PutByte(asm_ctx^, SEC_DATA, obj_ofs + RT_HDR_FLAGS, OF_STATIC);
  If proto <> 0 Then
    AddReloc(asm_ctx^, SEC_DATA, obj_ofs + RT_OBJ_PROTO, proto);
  If bo_n > 0 Then
    AddReloc(asm_ctx^, SEC_DATA, obj_ofs + RT_OBJ_PROPS, props_sym);
  PutDword(asm_ctx^, SEC_DATA, obj_ofs + RT_OBJ_COUNT, bo_n);
  PutDword(asm_ctx^, SEC_DATA, obj_ofs + RT_OBJ_CAP, bo_n);
  BoFinish := NewDataSym(asm_ctx^, name, SEC_DATA, obj_ofs, RT_OBJ_SIZE, DS_GLOBAL);
End;

{ Variable globale du runtime _JSRT_g_nom (valeur de 8 octets) qui designe
  l'objet ou la fonction de symbole sym. }
Procedure RtGlobal(Const name: TString; sym, tag: LongInt);
Var
  ofs: LongInt;
Begin
  ofs := SecAlloc(asm_ctx^, SEC_DATA, RT_VALUE_SIZE);
  AddReloc(asm_ctx^, SEC_DATA, ofs, sym);
  PutDword(asm_ctx^, SEC_DATA, ofs + 4, TagImm(tag));
  NewDataSym(asm_ctx^, SymRt('g_' + name), SEC_DATA, ofs, RT_VALUE_SIZE, DS_GLOBAL);
End;

{ ---- Demarrage, allocateur, erreurs ---- }

Procedure RtStartAndAlloc;
Begin
  A('proc _JSSTART');
  A('call _JSRT_init');
  A('call _JSRT_main');
  A('push 0');
  A('call dword ptr [__imp__ExitProcess@4]');
  A('endp');

  A('proc _JSRT_init');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, esp');
  A('sub eax, ' + IntToStr(RT_STACK_RESERVE - RT_STACK_GUARD));
  A('mov dword ptr [_JSRT_v_stack_limit], eax');
  A('push -11');
  A('call dword ptr [__imp__GetStdHandle@4]');
  A('mov dword ptr [_JSRT_v_stdout], eax');
  A('push -12');
  A('call dword ptr [__imp__GetStdHandle@4]');
  A('mov dword ptr [_JSRT_v_stderr], eax');
  A('push -10');
  A('call dword ptr [__imp__GetStdHandle@4]');
  A('mov dword ptr [_JSRT_v_stdin], eax');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_alloc(taille) -> EAX : bloc de 8 octets alignes, mis a zero }
  A('proc _JSRT_alloc');
  A('push ebp');
  A('mov ebp, esp');
  A('mov ecx, dword ptr [ebp+8]');
  A('add ecx, 7');
  A('and ecx, -8');
  A('cmp ecx, ' + IntToStr(RT_BIG_ALLOC));
  A('jae .big');
  A('mov eax, dword ptr [_JSRT_v_heap_cur]');
  A('lea edx, [eax+ecx]');
  A('cmp edx, dword ptr [_JSRT_v_heap_end]');
  A('ja .grow');
  A('mov dword ptr [_JSRT_v_heap_cur], edx');
  A('leave');
  A('ret');
  A('.grow:');
  A('push ecx');
  A('push 4');
  A('push 12288');
  A('push ' + IntToStr(RT_ARENA_SIZE));
  A('push 0');
  A('call dword ptr [__imp__VirtualAlloc@16]');
  A('pop ecx');
  A('test eax, eax');
  A('jz .oom');
  A('lea edx, [eax+ecx]');
  A('mov dword ptr [_JSRT_v_heap_cur], edx');
  A('lea edx, [eax+' + IntToStr(RT_ARENA_SIZE) + ']');
  A('mov dword ptr [_JSRT_v_heap_end], edx');
  A('leave');
  A('ret');
  A('.big:');
  A('push 4');
  A('push 12288');
  A('push ecx');
  A('push 0');
  A('call dword ptr [__imp__VirtualAlloc@16]');
  A('test eax, eax');
  A('jz .oom');
  A('leave');
  A('ret');
  A('.oom:');
  A('push offset _JSRT_c_oom');
  A('call _JSRT_fatal');
  A('endp');

  { _JSRT_write(handle, octets, nombre) }
  A('proc _JSRT_write');
  A('push ebp');
  A('mov ebp, esp');
  A('sub esp, 4');
  A('push 0');
  A('lea eax, [ebp-4]');
  A('push eax');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call dword ptr [__imp__WriteFile@20]');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_write_cstr(handle, chaine C) }
  A('proc _JSRT_write_cstr');
  A('push ebp');
  A('mov ebp, esp');
  A('push esi');
  A('mov esi, dword ptr [ebp+12]');
  A('xor ecx, ecx');
  A('.len:');
  A('cmp byte ptr [esi+ecx], 0');
  A('je .got');
  A('inc ecx');
  A('jmp .len');
  A('.got:');
  A('push ecx');
  A('push esi');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_write');
  A('add esp, 12');
  A('pop esi');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_fatal(chaine C) : message sur stderr puis fin du processus }
  A('proc _JSRT_fatal');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+8]');
  A('push dword ptr [_JSRT_v_stderr]');
  A('call _JSRT_write_cstr');
  A('add esp, 8');
  A('push 1');
  A('call dword ptr [__imp__ExitProcess@4]');
  A('leave');
  A('ret');
  A('endp');

  A('proc _JSRT_throw_notfunc');
  A('push offset _JSRT_c_notfunc');
  A('call _JSRT_fatal');
  A('endp');

  A('proc _JSRT_throw_type');
  A('push offset _JSRT_c_type');
  A('call _JSRT_fatal');
  A('endp');

  A('proc _JSRT_stack_overflow');
  A('push offset _JSRT_c_stack');
  A('call _JSRT_fatal');
  A('endp');

  { _JSRT_throw_tdz(chaine du nom) }
  A('proc _JSRT_throw_tdz');
  A('push ebp');
  A('mov ebp, esp');
  A('push offset _JSRT_c_tdz1');
  A('push dword ptr [_JSRT_v_stderr]');
  A('call _JSRT_write_cstr');
  A('add esp, 8');
  A('mov eax, dword ptr [ebp+8]');
  A('push dword ptr [eax+$STR_LEN]');
  A('add eax, $STR_DATA');
  A('push eax');
  A('push dword ptr [_JSRT_v_stderr]');
  A('call _JSRT_write');
  A('add esp, 12');
  A('push offset _JSRT_c_tdz2');
  A('call _JSRT_fatal');
  A('endp');
End;

{ ---- Chaines : creation, concatenation, conversions ---- }

Procedure RtStrings;
Begin
  { _JSRT_str_new(longueur) -> EAX : cellule de chaine (octets a ecrire) }
  A('proc _JSRT_str_new');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('add eax, ' + IntToStr(RT_STR_DATA + 1));
  A('push eax');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov byte ptr [eax], $OK_STRING');
  A('mov ecx, dword ptr [ebp+8]');
  A('mov dword ptr [eax+$STR_LEN], ecx');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_concat(a, b) : deux chaines -> chaine }
  A('proc _JSRT_concat');
  A('push ebp');
  A('mov ebp, esp');
  A('push esi');
  A('push edi');
  A('push ebx');
  A('mov esi, dword ptr [ebp+8]');
  A('mov edi, dword ptr [ebp+16]');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('test ecx, ecx');
  A('jnz .a_ok');
  A('mov eax, edi');
  A('jmp .done');
  A('.a_ok:');
  A('mov edx, dword ptr [edi+$STR_LEN]');
  A('test edx, edx');
  A('jnz .both');
  A('mov eax, esi');
  A('jmp .done');
  A('.both:');
  A('lea ebx, [ecx+edx]');
  A('push ebx');
  A('call _JSRT_str_new');
  A('add esp, 4');
  A('push eax');
  A('mov edi, eax');
  A('add edi, $STR_DATA');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('add esi, $STR_DATA');
  A('rep movsb');
  A('mov esi, dword ptr [ebp+16]');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('add esi, $STR_DATA');
  A('rep movsb');
  A('pop eax');
  A('.done:');
  A('mov edx, $STR');
  A('pop ebx');
  A('pop edi');
  A('pop esi');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_int_to_str(n) : entier signe -> chaine decimale }
  A('proc _JSRT_int_to_str');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('sub esp, 16');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ebx, eax');
  A('test eax, eax');
  A('jns .pos');
  A('neg eax');
  A('.pos:');
  A('lea esi, [ebp-12]');
  A('mov ecx, 10');
  A('.loop:');
  A('xor edx, edx');
  A('div ecx');
  A('add edx, 48');
  A('dec esi');
  A('mov byte ptr [esi], dl');
  A('test eax, eax');
  A('jnz .loop');
  A('test ebx, ebx');
  A('jns .nosign');
  A('dec esi');
  A('mov byte ptr [esi], 45');
  A('.nosign:');
  A('lea eax, [ebp-12]');
  A('sub eax, esi');
  A('mov edi, eax');
  A('push edi');
  A('call _JSRT_str_new');
  A('add esp, 4');
  A('mov ecx, edi');
  A('mov edi, eax');
  A('add edi, $STR_DATA');
  A('rep movsb');
  A('mov edx, $STR');
  A('add esp, 16');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_tostring(v) -> chaine (ToString des primitives) }
  A('proc _JSRT_tostring');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov edx, dword ptr [ebp+12]');
  A('cmp edx, $STR');
  A('je .self');
  A('cmp edx, $INT');
  A('je .int');
  A('jb .dbl');
  A('cmp edx, $BOOL');
  A('je .bool');
  A('cmp edx, $UNDEF');
  A('je .undef');
  A('cmp edx, $NULL');
  A('je .null');
  A('cmp edx, $FN');
  A('je .fn');
  A('cmp edx, $ARR');
  A('je .arr');
  A('cmp edx, $OBJ');
  A('je .objs');
  A('mov eax, offset ' + RtStr('[object Object]'));
  A('jmp .str');
  A('.arr:');
  A('push offset ' + RtStr(','));
  A('push eax');
  A('call _JSRT_arr_join');
  A('leave');
  A('ret');
  A('.objs:');
  A('push offset ' + RtStr('toString'));
  A('push eax');
  A('call _JSRT_prop_lookup');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .objdef');
  A('test dword ptr [eax+4], 2');
  A('jnz .objdef');
  A('cmp dword ptr [eax+12], $FN');
  A('jne .objdef');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('push dword ptr [eax+8]');
  A('call _JSRT_call0');
  A('add esp, 12');
  A('cmp edx, $STR');
  A('je .objret');
  A('.objdef:');
  A('mov eax, offset ' + RtStr('[object Object]'));
  A('mov edx, $STR');
  A('.objret:');
  A('leave');
  A('ret');
  A('.fn:');
  A('mov eax, offset ' + RtStr('function'));
  A('jmp .str');
  A('.bool:');
  A('test eax, eax');
  A('jz .false');
  A('mov eax, offset ' + RtStr('true'));
  A('jmp .str');
  A('.false:');
  A('mov eax, offset ' + RtStr('false'));
  A('jmp .str');
  A('.undef:');
  A('mov eax, offset ' + RtStr('undefined'));
  A('jmp .str');
  A('.null:');
  A('mov eax, offset ' + RtStr('null'));
  A('.str:');
  A('mov edx, $STR');
  A('.self:');
  A('leave');
  A('ret');
  A('.int:');
  A('push eax');
  A('call _JSRT_int_to_str');
  A('add esp, 4');
  A('leave');
  A('ret');
  A('.dbl:');
  A('push edx');
  A('push eax');
  A('call _JSRT_double_to_str');
  A('add esp, 8');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_str_equal(pa, pb) -> EAX = 0 ou 1 (contenu des chaines) }
  A('proc _JSRT_str_equal');
  A('push ebp');
  A('mov ebp, esp');
  A('push esi');
  A('push edi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov edi, dword ptr [ebp+12]');
  A('cmp esi, edi');
  A('je .eq');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('cmp ecx, dword ptr [edi+$STR_LEN]');
  A('jne .ne');
  A('add esi, $STR_DATA');
  A('add edi, $STR_DATA');
  A('.loop:');
  A('test ecx, ecx');
  A('jz .eq');
  A('mov al, byte ptr [esi]');
  A('cmp al, byte ptr [edi]');
  A('jne .ne');
  A('inc esi');
  A('inc edi');
  A('dec ecx');
  A('jmp .loop');
  A('.eq:');
  A('mov eax, 1');
  A('jmp .out');
  A('.ne:');
  A('xor eax, eax');
  A('.out:');
  A('pop edi');
  A('pop esi');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_str_cmp(pa, pb) -> EAX = -1, 0 ou 1 (ordre des octets) }
  A('proc _JSRT_str_cmp');
  A('push ebp');
  A('mov ebp, esp');
  A('push esi');
  A('push edi');
  A('sub esp, 8');
  A('mov esi, dword ptr [ebp+8]');
  A('mov edi, dword ptr [ebp+12]');
  A('mov eax, dword ptr [esi+$STR_LEN]');
  A('mov dword ptr [ebp-12], eax');
  A('mov eax, dword ptr [edi+$STR_LEN]');
  A('mov dword ptr [ebp-16], eax');
  A('mov ecx, dword ptr [ebp-12]');
  A('cmp ecx, dword ptr [ebp-16]');
  A('jbe .m');
  A('mov ecx, dword ptr [ebp-16]');
  A('.m:');
  A('add esi, $STR_DATA');
  A('add edi, $STR_DATA');
  A('.loop:');
  A('test ecx, ecx');
  A('jz .lens');
  A('movzx eax, byte ptr [esi]');
  A('movzx edx, byte ptr [edi]');
  A('cmp eax, edx');
  A('jb .less');
  A('ja .greater');
  A('inc esi');
  A('inc edi');
  A('dec ecx');
  A('jmp .loop');
  A('.lens:');
  A('mov eax, dword ptr [ebp-12]');
  A('cmp eax, dword ptr [ebp-16]');
  A('jb .less');
  A('ja .greater');
  A('xor eax, eax');
  A('jmp .out');
  A('.less:');
  A('mov eax, -1');
  A('jmp .out');
  A('.greater:');
  A('mov eax, 1');
  A('.out:');
  A('add esp, 8');
  A('pop edi');
  A('pop esi');
  A('pop ebp');
  A('ret');
  A('endp');
End;

{ ---- Egalite et addition ---- }

Procedure RtEquality;
Begin
  { _JSRT_seq(a, b) : === ; booleen dans EDX:EAX }
  A('proc _JSRT_seq');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+12]');
  A('cmp eax, dword ptr [ebp+20]');
  A('jne .diff');
  A('cmp eax, $INT');
  A('jb .num');
  A('cmp eax, $STR');
  A('je .str');
  A('cmp eax, $UNDEF');
  A('je .true');
  A('cmp eax, $NULL');
  A('je .true');
  A('mov ecx, dword ptr [ebp+8]');
  A('cmp ecx, dword ptr [ebp+16]');
  A('jne .false');
  A('.true:');
  A('mov eax, 1');
  A('jmp .ret');
  A('.str:');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('jmp .ret');
  A('.num:');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_num_eq');
  A('add esp, 16');
  A('jmp .ret');
  A('.diff:');
  A('cmp eax, $INT');
  A('ja .false');
  A('mov ecx, dword ptr [ebp+20]');
  A('cmp ecx, $INT');
  A('ja .false');
  A('jmp .num');
  A('.false:');
  A('xor eax, eax');
  A('.ret:');
  A('mov edx, $BOOL');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_eq(a, b) : == }
  A('proc _JSRT_eq');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+12]');
  A('mov ecx, dword ptr [ebp+20]');
  A('cmp eax, ecx');
  A('je .same');
  A('cmp eax, $INT');
  A('jbe .an');
  A('cmp eax, $UNDEF');
  A('je .au');
  A('cmp eax, $NULL');
  A('je .au');
  A('jmp .slow');
  A('.an:');
  A('cmp ecx, $INT');
  A('jbe .same');
  A('jmp .slow');
  A('.au:');
  A('cmp ecx, $UNDEF');
  A('je .true');
  A('cmp ecx, $NULL');
  A('je .true');
  A('xor eax, eax');
  A('mov edx, $BOOL');
  A('leave');
  A('ret');
  A('.true:');
  A('mov eax, 1');
  A('mov edx, $BOOL');
  A('leave');
  A('ret');
  A('.same:');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_seq');
  A('add esp, 16');
  A('leave');
  A('ret');
  A('.slow:');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_eq_slow');
  A('add esp, 16');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_add(a, b) : + (concatenation ou addition numerique) }
  A('proc _JSRT_add');
  A('push ebp');
  A('mov ebp, esp');
  A('cmp dword ptr [ebp+12], $STR');
  A('je .str');
  A('cmp dword ptr [ebp+20], $STR');
  A('je .str');
  A('cmp dword ptr [ebp+12], $OBJ');
  A('jae .str');
  A('cmp dword ptr [ebp+20], $OBJ');
  A('jae .str');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_num_add');
  A('add esp, 16');
  A('leave');
  A('ret');
  A('.str:');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push edx');
  A('push eax');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push edx');
  A('push eax');
  A('call _JSRT_concat');
  A('add esp, 16');
  A('leave');
  A('ret');
  A('endp');
End;

{ ---- Proprietes ---- }

Procedure RtProperties;
Begin
  { _JSRT_str_get_prop(pstr, pcle) : propriete d'une chaine par nom }
  A('proc _JSRT_str_get_prop');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+12]');
  A('push offset ' + RtStr('length'));
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .proto');
  A('mov eax, dword ptr [ebp+8]');
  A('mov eax, dword ptr [eax+$STR_LEN]');
  A('mov edx, $INT');
  A('leave');
  A('ret');
  A('.proto:');
  A('push dword ptr [ebp+12]');
  A('push offset _JSNO_string_proto');
  A('call _JSRT_obj_lookup_str');
  A('add esp, 8');
  A('leave');
  A('ret');
  A('endp');
End;

{ ---- console ---- }

Procedure RtConsoleFn(Const code, handle_var: TString);
Begin
  A('proc ' + code);
  A('push ebp');
  A('mov ebp, esp');
  A('push esi');
  A('push edi');
  A('mov edi, dword ptr [' + handle_var + ']');
  A('xor esi, esi');
  A('.loop:');
  A('cmp esi, dword ptr [ebp+12]');
  A('jae .nl');
  A('test esi, esi');
  A('jz .arg');
  A('push 1');
  A('push offset _JSRT_c_space');
  A('push edi');
  A('call _JSRT_write');
  A('add esp, 12');
  A('.arg:');
  A('mov ecx, esi');
  A('shl ecx, 3');
  A('lea eax, [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('add ecx, eax');
  A('push dword ptr [ecx+4]');
  A('push dword ptr [ecx]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push dword ptr [eax+$STR_LEN]');
  A('add eax, $STR_DATA');
  A('push eax');
  A('push edi');
  A('call _JSRT_write');
  A('add esp, 12');
  A('inc esi');
  A('jmp .loop');
  A('.nl:');
  A('push 1');
  A('push offset _JSRT_c_nl');
  A('push edi');
  A('call _JSRT_write');
  A('add esp, 12');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('pop edi');
  A('pop esi');
  A('pop ebp');
  A('ret');
  A('endp');
End;

{ ---- Methodes de String (TODO 14) ----

  Les chaines sont des octets UTF-8 : length, les indices et les
  positions comptent des octets, ce qui est exact pour l'ASCII. Les
  methodes natives suivent la convention d'appel des fonctions : this en
  [EBP+16], argc en [EBP+12], arguments a partir de [EBP+24]. }

{ Entier d'un argument (valeur par defaut si absent ou undefined) dans EAX. }
Procedure MArgInt(i: LongInt; Const def: TString);
Var
  d, ok: TString;
Begin
  d := U('d');
  ok := U('k');
  A('cmp dword ptr [ebp+12], ' + IntToStr(i + 1));
  A('jb ' + d);
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8 * i) + ']');
  A('mov edx, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8 * i + 4) + ']');
  A('cmp edx, $INT');
  A('je ' + ok);
  A('cmp edx, $UNDEF');
  A('je ' + d);
  A('push edx');
  A('push eax');
  A('call _JSRT_toint32');
  A('add esp, 8');
  A('jmp ' + ok);
  A(d + ':');
  A('mov eax, ' + def);
  A(ok + ':');
End;

{ Chaine d'un argument (ToString) dans le registre reg. }
Procedure MArgStr(i: LongInt; Const reg: TString);
Var
  have, ok: TString;
Begin
  have := U('h');
  ok := U('k');
  A('cmp dword ptr [ebp+12], ' + IntToStr(i + 1));
  A('jae ' + have);
  A('mov eax, offset ' + RtStr('undefined'));
  A('jmp ' + ok);
  A(have + ':');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8 * i + 4) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8 * i) + ']');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A(ok + ':');
  A('mov ' + reg + ', eax');
End;

{ Debut d'une methode : this converti en chaine, pointeur dans ESI. }
Procedure MethBegin(Const code: TString);
Begin
  A('proc ' + code);
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('mov eax, dword ptr [ebp+16]');
  A('mov edx, dword ptr [ebp+20]');
  A('cmp edx, $STR');
  A('je .thisok');
  A('push edx');
  A('push eax');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('.thisok:');
  A('mov esi, eax');
End;

Procedure MethEnd;
Begin
  A('.ret:');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');
End;

{ Routines communes : conversions, recherche, extraction. }
Procedure RtStringHelpers;
Begin
  { _JSRT_cmp3(a, b) -> EAX = -1, 0 ou 1 : chaines par ordre des octets,
    sinon comparaison des valeurs converties en entier 32 bits }
  A('proc _JSRT_cmp3');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('cmp dword ptr [ebp+12], $STR');
  A('jne .num');
  A('cmp dword ptr [ebp+20], $STR');
  A('jne .num');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_str_cmp');
  A('add esp, 8');
  A('jmp .out');
  A('.num:');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_toint32');
  A('add esp, 8');
  A('mov ebx, eax');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_toint32');
  A('add esp, 8');
  A('cmp ebx, eax');
  A('jl .less');
  A('jg .greater');
  A('xor eax, eax');
  A('jmp .out');
  A('.less:');
  A('mov eax, -1');
  A('jmp .out');
  A('.greater:');
  A('mov eax, 1');
  A('.out:');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  A('proc _JSRT_lt');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_cmp3');
  A('add esp, 16');
  A('cmp eax, 0');
  A('mov eax, 0');
  A('jl .t');
  A('jmp .o');
  A('.t:');
  A('mov eax, 1');
  A('.o:');
  A('mov edx, $BOOL');
  A('pop ebp');
  A('ret');
  A('endp');

  A('proc _JSRT_le');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_cmp3');
  A('add esp, 16');
  A('cmp eax, 0');
  A('mov eax, 0');
  A('jle .t');
  A('jmp .o');
  A('.t:');
  A('mov eax, 1');
  A('.o:');
  A('mov edx, $BOOL');
  A('pop ebp');
  A('ret');
  A('endp');

  A('proc _JSRT_gt');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_cmp3');
  A('add esp, 16');
  A('cmp eax, 0');
  A('mov eax, 0');
  A('jg .t');
  A('jmp .o');
  A('.t:');
  A('mov eax, 1');
  A('.o:');
  A('mov edx, $BOOL');
  A('pop ebp');
  A('ret');
  A('endp');

  A('proc _JSRT_ge');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_cmp3');
  A('add esp, 16');
  A('cmp eax, 0');
  A('mov eax, 0');
  A('jge .t');
  A('jmp .o');
  A('.t:');
  A('mov eax, 1');
  A('.o:');
  A('mov edx, $BOOL');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_toint32(v) -> EAX }
  A('proc _JSRT_toint32');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov edx, dword ptr [ebp+12]');
  A('cmp edx, $INT');
  A('je .ret');
  A('cmp edx, $BOOL');
  A('je .ret');
  A('cmp edx, $UNDEF');
  A('je .zero');
  A('cmp edx, $NULL');
  A('je .zero');
  A('push edx');
  A('push eax');
  A('call _JSRT_toint32_slow');
  A('add esp, 8');
  A('leave');
  A('ret');
  A('.zero:');
  A('xor eax, eax');
  A('.ret:');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_relidx(v, n) : indice relatif (negatif depuis la fin), borne a [0, n] }
  A('proc _JSRT_relidx');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('test eax, eax');
  A('jns .pos');
  A('add eax, ecx');
  A('jns .ret');
  A('xor eax, eax');
  A('jmp .ret');
  A('.pos:');
  A('cmp eax, ecx');
  A('jle .ret');
  A('mov eax, ecx');
  A('.ret:');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_clampidx(v, n) : borne a [0, n] }
  A('proc _JSRT_clampidx');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('test eax, eax');
  A('jns .pos');
  A('xor eax, eax');
  A('jmp .ret');
  A('.pos:');
  A('cmp eax, ecx');
  A('jle .ret');
  A('mov eax, ecx');
  A('.ret:');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_str_sub(chaine, debut, fin) -> valeur chaine ; 0 <= debut <= fin <= longueur }
  A('proc _JSRT_str_sub');
  A('push ebp');
  A('mov ebp, esp');
  A('push esi');
  A('push edi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov eax, dword ptr [ebp+12]');
  A('mov ecx, dword ptr [ebp+16]');
  A('sub ecx, eax');
  A('jle .empty');
  A('cmp ecx, dword ptr [esi+$STR_LEN]');
  A('jne .make');
  A('mov eax, esi');
  A('jmp .ret');
  A('.make:');
  A('push ecx');
  A('push ecx');
  A('call _JSRT_str_new');
  A('add esp, 4');
  A('pop ecx');
  A('mov edi, eax');
  A('add edi, $STR_DATA');
  A('mov edx, dword ptr [ebp+12]');
  A('lea esi, [esi+edx+$STR_DATA]');
  A('push eax');
  A('rep movsb');
  A('pop eax');
  A('jmp .ret');
  A('.empty:');
  A('mov eax, offset ' + RtStr(''));
  A('.ret:');
  A('mov edx, $STR');
  A('pop edi');
  A('pop esi');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_str_index(botte, aiguille, depuis) -> indice ou -1 }
  A('proc _JSRT_str_index');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('sub esp, 4');
  A('mov esi, dword ptr [ebp+8]');
  A('mov edi, dword ptr [ebp+12]');
  A('mov ebx, dword ptr [ebp+16]');
  A('mov eax, dword ptr [esi+$STR_LEN]');
  A('mov ecx, dword ptr [edi+$STR_LEN]');
  A('test ebx, ebx');
  A('jns .f1');
  A('xor ebx, ebx');
  A('.f1:');
  A('cmp ebx, eax');
  A('jle .f2');
  A('mov ebx, eax');
  A('.f2:');
  A('sub eax, ecx');
  A('js .none');
  A('mov dword ptr [ebp-16], eax');
  A('.outer:');
  A('cmp ebx, dword ptr [ebp-16]');
  A('jg .none');
  A('xor edx, edx');
  A('.inner:');
  A('cmp edx, ecx');
  A('jae .found');
  A('lea eax, [ebx+edx]');
  A('movzx eax, byte ptr [esi+eax+$STR_DATA]');
  A('cmp al, byte ptr [edi+edx+$STR_DATA]');
  A('jne .next');
  A('inc edx');
  A('jmp .inner');
  A('.next:');
  A('inc ebx');
  A('jmp .outer');
  A('.found:');
  A('mov eax, ebx');
  A('jmp .out');
  A('.none:');
  A('mov eax, -1');
  A('.out:');
  A('add esp, 4');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_str_lindex(botte, aiguille, depuis) -> dernier indice <= depuis ou -1 }
  A('proc _JSRT_str_lindex');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov edi, dword ptr [ebp+12]');
  A('mov ebx, dword ptr [ebp+16]');
  A('mov eax, dword ptr [esi+$STR_LEN]');
  A('mov ecx, dword ptr [edi+$STR_LEN]');
  A('sub eax, ecx');
  A('js .none');
  A('cmp ebx, eax');
  A('jle .f1');
  A('mov ebx, eax');
  A('.f1:');
  A('test ebx, ebx');
  A('jns .outer');
  A('xor ebx, ebx');
  A('.outer:');
  A('test ebx, ebx');
  A('js .none');
  A('xor edx, edx');
  A('.inner:');
  A('cmp edx, ecx');
  A('jae .found');
  A('lea eax, [ebx+edx]');
  A('movzx eax, byte ptr [esi+eax+$STR_DATA]');
  A('cmp al, byte ptr [edi+edx+$STR_DATA]');
  A('jne .next');
  A('inc edx');
  A('jmp .inner');
  A('.next:');
  A('dec ebx');
  A('jmp .outer');
  A('.found:');
  A('mov eax, ebx');
  A('jmp .out');
  A('.none:');
  A('mov eax, -1');
  A('.out:');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_str_match_at(botte, aiguille, pos) -> 1 si l'aiguille est a pos }
  A('proc _JSRT_str_match_at');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov edi, dword ptr [ebp+12]');
  A('mov ebx, dword ptr [ebp+16]');
  A('test ebx, ebx');
  A('js .no');
  A('mov eax, dword ptr [esi+$STR_LEN]');
  A('mov ecx, dword ptr [edi+$STR_LEN]');
  A('sub eax, ebx');
  A('cmp ecx, eax');
  A('jg .no');
  A('xor edx, edx');
  A('.l:');
  A('cmp edx, ecx');
  A('jae .yes');
  A('lea eax, [ebx+edx]');
  A('movzx eax, byte ptr [esi+eax+$STR_DATA]');
  A('cmp al, byte ptr [edi+edx+$STR_DATA]');
  A('jne .no');
  A('inc edx');
  A('jmp .l');
  A('.yes:');
  A('mov eax, 1');
  A('jmp .out');
  A('.no:');
  A('xor eax, eax');
  A('.out:');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_str_case(chaine, majuscules) }
  A('proc _JSRT_str_case');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ebx, dword ptr [ebp+12]');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('test ecx, ecx');
  A('jz .same');
  A('push ecx');
  A('call _JSRT_str_new');
  A('add esp, 4');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('xor edi, edi');
  A('.l:');
  A('cmp edi, ecx');
  A('jae .done');
  A('movzx edx, byte ptr [esi+edi+$STR_DATA]');
  A('test ebx, ebx');
  A('jz .lower');
  A('cmp edx, 97');
  A('jb .st');
  A('cmp edx, 122');
  A('ja .st');
  A('sub edx, 32');
  A('jmp .st');
  A('.lower:');
  A('cmp edx, 65');
  A('jb .st');
  A('cmp edx, 90');
  A('ja .st');
  A('add edx, 32');
  A('.st:');
  A('mov byte ptr [eax+edi+$STR_DATA], dl');
  A('inc edi');
  A('jmp .l');
  A('.same:');
  A('mov eax, esi');
  A('.done:');
  A('mov edx, $STR');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_str_trim(chaine, mode) : mode 1 = debut, 2 = fin, 3 = les deux }
  A('proc _JSRT_str_trim');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ebx, dword ptr [ebp+12]');
  A('xor edi, edi');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('test ebx, 1');
  A('jz .end');
  A('.sl:');
  A('cmp edi, ecx');
  A('jae .end');
  A('movzx eax, byte ptr [esi+edi+$STR_DATA]');
  A('cmp eax, 32');
  A('je .sn');
  A('cmp eax, 9');
  A('jb .end');
  A('cmp eax, 13');
  A('ja .end');
  A('.sn:');
  A('inc edi');
  A('jmp .sl');
  A('.end:');
  A('test ebx, 2');
  A('jz .go');
  A('.el:');
  A('cmp ecx, edi');
  A('jbe .go');
  A('movzx eax, byte ptr [esi+ecx+' + IntToStr(RT_STR_DATA - 1) + ']');
  A('cmp eax, 32');
  A('je .en');
  A('cmp eax, 9');
  A('jb .go');
  A('cmp eax, 13');
  A('ja .go');
  A('.en:');
  A('dec ecx');
  A('jmp .el');
  A('.go:');
  A('push ecx');
  A('push edi');
  A('push esi');
  A('call _JSRT_str_sub');
  A('add esp, 12');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_str_fillpad(dest, nombre, remplissage) -> EAX = dest apres ecriture }
  A('proc _JSRT_str_fillpad');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ebx, dword ptr [ebp+12]');
  A('mov edx, dword ptr [ebp+16]');
  A('mov esi, dword ptr [edx+$STR_LEN]');
  A('xor ecx, ecx');
  A('.fl:');
  A('test ebx, ebx');
  A('jz .fd');
  A('movzx edx, byte ptr [edx+ecx+$STR_DATA]');
  A('mov byte ptr [eax], dl');
  A('mov edx, dword ptr [ebp+16]');
  A('inc eax');
  A('inc ecx');
  A('cmp ecx, esi');
  A('jb .fk');
  A('xor ecx, ecx');
  A('.fk:');
  A('dec ebx');
  A('jmp .fl');
  A('.fd:');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_str_pad(chaine, longueur cible, remplissage, debut) }
  A('proc _JSRT_str_pad');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('sub esp, 8');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ebx, dword ptr [ebp+12]');
  A('mov edi, dword ptr [ebp+16]');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('cmp ebx, ecx');
  A('jle .same');
  A('mov edx, dword ptr [edi+$STR_LEN]');
  A('test edx, edx');
  A('jz .same');
  A('sub ebx, ecx');
  A('mov dword ptr [ebp-16], ebx');
  A('lea eax, [ebx+ecx]');
  A('push eax');
  A('call _JSRT_str_new');
  A('add esp, 4');
  A('mov dword ptr [ebp-20], eax');
  A('mov edi, eax');
  A('add edi, $STR_DATA');
  A('cmp dword ptr [ebp+20], 0');
  A('je .tail');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp-16]');
  A('push edi');
  A('call _JSRT_str_fillpad');
  A('add esp, 12');
  A('mov edi, eax');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('lea esi, [esi+$STR_DATA]');
  A('rep movsb');
  A('jmp .fin');
  A('.tail:');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('lea esi, [esi+$STR_DATA]');
  A('rep movsb');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp-16]');
  A('push edi');
  A('call _JSRT_str_fillpad');
  A('add esp, 12');
  A('.fin:');
  A('mov eax, dword ptr [ebp-20]');
  A('mov edx, $STR');
  A('jmp .out');
  A('.same:');
  A('mov eax, esi');
  A('mov edx, $STR');
  A('.out:');
  A('add esp, 8');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');
End;

{ ---- Methodes natives ---- }

Procedure RtStringMethods;
Begin
  RtStringHelpers;

  { _JSRT_str_char_at(pstr, indice) -> chaine d'un caractere ou vide }
  A('proc _JSRT_str_char_at');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, 0');
  A('jl .empty');
  A('cmp ecx, dword ptr [eax+$STR_LEN]');
  A('jae .empty');
  A('movzx ecx, byte ptr [eax+ecx+$STR_DATA]');
  A('push ecx');
  A('push 1');
  A('call _JSRT_str_new');
  A('add esp, 4');
  A('pop ecx');
  A('mov byte ptr [eax+$STR_DATA], cl');
  A('mov edx, $STR');
  A('leave');
  A('ret');
  A('.empty:');
  A('mov eax, offset ' + RtStr(''));
  A('mov edx, $STR');
  A('leave');
  A('ret');
  A('endp');

  MethBegin('_JSRT_sm_charAt');
  MArgInt(0, '0');
  A('push eax');
  A('push esi');
  A('call _JSRT_str_char_at');
  A('add esp, 8');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_charCodeAt');
  MArgInt(0, '0');
  A('cmp eax, 0');
  A('jl .nan');
  A('cmp eax, dword ptr [esi+$STR_LEN]');
  A('jae .nan');
  A('movzx eax, byte ptr [esi+eax+$STR_DATA]');
  A('mov edx, $INT');
  A('jmp .ret');
  A('.nan:');
  A('mov eax, dword ptr [' + SymDbl(STD_DBL_NAN) + ']');
  A('mov edx, dword ptr [' + SymDbl(STD_DBL_NAN) + '+4]');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_indexOf');
  MArgStr(0, 'ebx');
  MArgInt(1, '0');
  A('push eax');
  A('push ebx');
  A('push esi');
  A('call _JSRT_str_index');
  A('add esp, 12');
  A('mov edx, $INT');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_lastIndexOf');
  MArgStr(0, 'ebx');
  MArgInt(1, '2147483647');
  A('push eax');
  A('push ebx');
  A('push esi');
  A('call _JSRT_str_lindex');
  A('add esp, 12');
  A('mov edx, $INT');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_includes');
  MArgStr(0, 'ebx');
  MArgInt(1, '0');
  A('push eax');
  A('push ebx');
  A('push esi');
  A('call _JSRT_str_index');
  A('add esp, 12');
  A('mov ecx, eax');
  A('xor eax, eax');
  A('test ecx, ecx');
  A('js .no');
  A('mov eax, 1');
  A('.no:');
  A('mov edx, $BOOL');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_startsWith');
  MArgStr(0, 'ebx');
  MArgInt(1, '0');
  A('push eax');
  A('push ebx');
  A('push esi');
  A('call _JSRT_str_match_at');
  A('add esp, 12');
  A('mov edx, $BOOL');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_endsWith');
  MArgStr(0, 'ebx');
  MArgInt(1, '2147483647');
  A('cmp eax, dword ptr [esi+$STR_LEN]');
  A('jle .e1');
  A('mov eax, dword ptr [esi+$STR_LEN]');
  A('.e1:');
  A('sub eax, dword ptr [ebx+$STR_LEN]');
  A('push eax');
  A('push ebx');
  A('push esi');
  A('call _JSRT_str_match_at');
  A('add esp, 12');
  A('mov edx, $BOOL');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_toUpperCase');
  A('push 1');
  A('push esi');
  A('call _JSRT_str_case');
  A('add esp, 8');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_toLowerCase');
  A('push 0');
  A('push esi');
  A('call _JSRT_str_case');
  A('add esp, 8');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_trim');
  A('push 3');
  A('push esi');
  A('call _JSRT_str_trim');
  A('add esp, 8');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_trimStart');
  A('push 1');
  A('push esi');
  A('call _JSRT_str_trim');
  A('add esp, 8');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_trimEnd');
  A('push 2');
  A('push esi');
  A('call _JSRT_str_trim');
  A('add esp, 8');
  A('jmp .ret');
  MethEnd;

  { slice(debut, fin) : indices negatifs comptes depuis la fin }
  MethBegin('_JSRT_sm_slice');
  MArgInt(0, '0');
  A('push dword ptr [esi+$STR_LEN]');
  A('push eax');
  A('call _JSRT_relidx');
  A('add esp, 8');
  A('mov ebx, eax');
  MArgInt(1, '2147483647');
  A('push dword ptr [esi+$STR_LEN]');
  A('push eax');
  A('call _JSRT_relidx');
  A('add esp, 8');
  A('cmp ebx, eax');
  A('jl .ok');
  A('mov ebx, eax');
  A('.ok:');
  A('push eax');
  A('push ebx');
  A('push esi');
  A('call _JSRT_str_sub');
  A('add esp, 12');
  A('jmp .ret');
  MethEnd;

  { substring(a, b) : bornes a [0, longueur], echangees si a > b }
  MethBegin('_JSRT_sm_substring');
  MArgInt(0, '0');
  A('push dword ptr [esi+$STR_LEN]');
  A('push eax');
  A('call _JSRT_clampidx');
  A('add esp, 8');
  A('mov ebx, eax');
  MArgInt(1, '2147483647');
  A('push dword ptr [esi+$STR_LEN]');
  A('push eax');
  A('call _JSRT_clampidx');
  A('add esp, 8');
  A('cmp ebx, eax');
  A('jle .ok');
  A('mov ecx, ebx');
  A('mov ebx, eax');
  A('mov eax, ecx');
  A('.ok:');
  A('push eax');
  A('push ebx');
  A('push esi');
  A('call _JSRT_str_sub');
  A('add esp, 12');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_repeat');
  MArgInt(0, '0');
  A('test eax, eax');
  A('js .range');
  A('mov ebx, eax');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('imul ecx, ebx');
  A('jz .empty');
  A('push ecx');
  A('call _JSRT_str_new');
  A('add esp, 4');
  A('push eax');
  A('mov edi, eax');
  A('add edi, $STR_DATA');
  A('.l:');
  A('test ebx, ebx');
  A('jz .d');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('push esi');
  A('add esi, $STR_DATA');
  A('rep movsb');
  A('pop esi');
  A('dec ebx');
  A('jmp .l');
  A('.d:');
  A('pop eax');
  A('mov edx, $STR');
  A('jmp .ret');
  A('.empty:');
  A('mov eax, offset ' + RtStr(''));
  A('mov edx, $STR');
  A('jmp .ret');
  A('.range:');
  A('push offset _JSRT_c_range');
  A('call _JSRT_fatal');
  MethEnd;

  { padStart / padEnd(longueur, remplissage = " ") }
  MethBegin('_JSRT_sm_padStart');
  MArgInt(0, '0');
  A('mov ebx, eax');
  A('cmp dword ptr [ebp+12], 2');
  A('jb .dflt');
  A('mov edx, dword ptr [ebp+36]');
  A('cmp edx, $UNDEF');
  A('je .dflt');
  A('push edx');
  A('push dword ptr [ebp+32]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('jmp .go');
  A('.dflt:');
  A('mov eax, offset ' + RtStr(' '));
  A('.go:');
  A('push 1');
  A('push eax');
  A('push ebx');
  A('push esi');
  A('call _JSRT_str_pad');
  A('add esp, 16');
  A('jmp .ret');
  MethEnd;

  MethBegin('_JSRT_sm_padEnd');
  MArgInt(0, '0');
  A('mov ebx, eax');
  A('cmp dword ptr [ebp+12], 2');
  A('jb .dflt');
  A('mov edx, dword ptr [ebp+36]');
  A('cmp edx, $UNDEF');
  A('je .dflt');
  A('push edx');
  A('push dword ptr [ebp+32]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('jmp .go');
  A('.dflt:');
  A('mov eax, offset ' + RtStr(' '));
  A('.go:');
  A('push 0');
  A('push eax');
  A('push ebx');
  A('push esi');
  A('call _JSRT_str_pad');
  A('add esp, 16');
  A('jmp .ret');
  MethEnd;

  { toString() et valueOf() : la chaine elle-meme }
  MethBegin('_JSRT_sm_toString');
  A('mov eax, esi');
  A('mov edx, $STR');
  A('jmp .ret');
  MethEnd;

  { String(valeur) : conversion en chaine }
  A('proc _JSRT_String_call');
  A('push ebp');
  A('mov ebp, esp');
  A('cmp dword ptr [ebp+12], 0');
  A('je .empty');
  A('push dword ptr [ebp+28]');
  A('push dword ptr [ebp+24]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('leave');
  A('ret');
  A('.empty:');
  A('mov eax, offset ' + RtStr(''));
  A('mov edx, $STR');
  A('leave');
  A('ret');
  A('endp');

  { String.fromCharCode(c1, c2, ...) : unites de code encodees en UTF-8 }
  A('proc _JSRT_String_fromCharCode');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('xor ebx, ebx');
  A('xor esi, esi');
  A('.count:');
  A('cmp esi, dword ptr [ebp+12]');
  A('jae .alloc');
  A('lea eax, [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('mov ecx, esi');
  A('shl ecx, 3');
  A('push dword ptr [eax+ecx+4]');
  A('push dword ptr [eax+ecx]');
  A('call _JSRT_toint32');
  A('add esp, 8');
  A('and eax, 65535');
  A('inc ebx');
  A('cmp eax, 128');
  A('jb .cn');
  A('inc ebx');
  A('cmp eax, 2048');
  A('jb .cn');
  A('inc ebx');
  A('.cn:');
  A('inc esi');
  A('jmp .count');
  A('.alloc:');
  A('push ebx');
  A('call _JSRT_str_new');
  A('add esp, 4');
  A('push eax');
  A('mov edi, eax');
  A('add edi, $STR_DATA');
  A('xor esi, esi');
  A('.fill:');
  A('cmp esi, dword ptr [ebp+12]');
  A('jae .done');
  A('lea eax, [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('mov ecx, esi');
  A('shl ecx, 3');
  A('push dword ptr [eax+ecx+4]');
  A('push dword ptr [eax+ecx]');
  A('call _JSRT_toint32');
  A('add esp, 8');
  A('and eax, 65535');
  A('cmp eax, 128');
  A('jae .two');
  A('mov byte ptr [edi], al');
  A('inc edi');
  A('jmp .next');
  A('.two:');
  A('cmp eax, 2048');
  A('jae .three');
  A('mov ecx, eax');
  A('shr ecx, 6');
  A('or ecx, 192');
  A('mov byte ptr [edi], cl');
  A('and eax, 63');
  A('or eax, 128');
  A('mov byte ptr [edi+1], al');
  A('add edi, 2');
  A('jmp .next');
  A('.three:');
  A('mov ecx, eax');
  A('shr ecx, 12');
  A('or ecx, 224');
  A('mov byte ptr [edi], cl');
  A('mov ecx, eax');
  A('shr ecx, 6');
  A('and ecx, 63');
  A('or ecx, 128');
  A('mov byte ptr [edi+1], cl');
  A('and eax, 63');
  A('or eax, 128');
  A('mov byte ptr [edi+2], al');
  A('add edi, 3');
  A('.next:');
  A('inc esi');
  A('jmp .fill');
  A('.done:');
  A('pop eax');
  A('mov edx, $STR');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');
End;

{ Enregistre les methodes natives dans le prototype des chaines. }
Procedure RtStringProtoMethods;
  Procedure M(Const name, code: TString; nparams: LongInt);
  Begin
    BoAdd(name, RtFuncObj(name, code, nparams), RT_T_FUNCTION);
  End;
Begin
  M('charAt', '_JSRT_sm_charAt', 1);
  M('charCodeAt', '_JSRT_sm_charCodeAt', 1);
  M('indexOf', '_JSRT_sm_indexOf', 1);
  M('lastIndexOf', '_JSRT_sm_lastIndexOf', 1);
  M('includes', '_JSRT_sm_includes', 1);
  M('startsWith', '_JSRT_sm_startsWith', 1);
  M('endsWith', '_JSRT_sm_endsWith', 1);
  M('toUpperCase', '_JSRT_sm_toUpperCase', 0);
  M('toLowerCase', '_JSRT_sm_toLowerCase', 0);
  M('trim', '_JSRT_sm_trim', 0);
  M('trimStart', '_JSRT_sm_trimStart', 0);
  M('trimEnd', '_JSRT_sm_trimEnd', 0);
  M('slice', '_JSRT_sm_slice', 2);
  M('substring', '_JSRT_sm_substring', 2);
  M('repeat', '_JSRT_sm_repeat', 1);
  M('padStart', '_JSRT_sm_padStart', 2);
  M('padEnd', '_JSRT_sm_padEnd', 2);
  M('split', '_JSRT_sm_split', 2);
  M('toString', '_JSRT_sm_toString', 0);
  M('valueOf', '_JSRT_sm_toString', 0);
End;

{ Globales fournies par les chaines : String et String.fromCharCode. }
Procedure RtStaticGlobals;
Var
  f_from, props, f_str: LongInt;
Begin
  f_from := RtFuncObj('fromCharCode', '_JSRT_String_fromCharCode', 1);
  BoReset;
  BoAdd('fromCharCode', f_from, RT_T_FUNCTION);
  props := BoFinish('_JSNO_String_props', 0);
  f_str := RtFuncObjP('String', '_JSRT_String_call', 1, props);
  RtGlobal('String', f_str, RT_T_FUNCTION);
End;

{ ---- Tableaux et primitives de base du runtime (TODO 15) ----

  Tableau : en-tete (8), longueur +8, capacite +12, pointeur vers les
  elements +16 (valeurs de 8 octets, bloc separe qui grandit par
  doublement). Les methodes natives utilisent la convention d'appel
  interne : [EBP+12] argc, [EBP+16] this, [EBP+24] argument 0. }

{ Emplacement local numero k (de 1 a n) sous les registres sauvegardes. }
Function Lv(k: LongInt): TString;
Begin
  Lv := 'dword ptr [ebp-' + IntToStr(12 + 4 * k) + ']';
End;

{ Debut d'une methode de tableau : this verifie, pointeur dans ESI. }
Procedure ArrBegin(Const code: TString; nloc: LongInt);
Begin
  A('proc ' + code);
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  If nloc > 0 Then
    A('sub esp, ' + IntToStr(4 * nloc));
  A('cmp dword ptr [ebp+20], $ARR');
  A('jne .badthis');
  A('mov esi, dword ptr [ebp+16]');
End;

Procedure ArrEnd;
Begin
  A('.ret:');
  A('mov esp, ebp');
  A('sub esp, 12');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('.badthis:');
  A('push offset _JSRT_c_type');
  A('call _JSRT_fatal');
  A('endp');
End;

{ Argument i copie dans les locaux klo/khi (undefined si absent). }
Procedure ArgToLocals(i, klo, khi: LongInt);
Var
  have, ok: TString;
Begin
  have := U('h');
  ok := U('k');
  A('cmp dword ptr [ebp+12], ' + IntToStr(i + 1));
  A('jae ' + have);
  A('mov ' + Lv(klo) + ', 0');
  A('mov ' + Lv(khi) + ', $UNDEF');
  A('jmp ' + ok);
  A(have + ':');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8 * i) + ']');
  A('mov ' + Lv(klo) + ', eax');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8 * i + 4) + ']');
  A('mov ' + Lv(khi) + ', eax');
  A(ok + ':');
End;

{ Empile (valeur de 8 octets) la chaine dont EAX est le pointeur vers le tableau EBX. }
Procedure PushStrToArr(Const arrreg: TString);
Begin
  A('push $STR');
  A('push eax');
  A('push $ARR');
  A('push ' + arrreg);
  A('call _JSRT_array_push');
  A('add esp, 16');
End;

Procedure RtArrayCore;
Begin
  { _JSRT_array_new() -> tableau vide }
  A('proc _JSRT_array_new');
  A('push ebp');
  A('mov ebp, esp');
  A('push ' + IntToStr(RT_ARR_SIZE));
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov byte ptr [eax], $OK_ARRAY');
  A('mov edx, $ARR');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_arr_reserve(arr, capacite minimale) }
  A('proc _JSRT_arr_reserve');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov eax, dword ptr [ebp+12]');
  A('cmp eax, dword ptr [esi+$ARR_CAP]');
  A('jbe .ret');
  A('mov ebx, dword ptr [esi+$ARR_CAP]');
  A('add ebx, ebx');
  A('cmp ebx, eax');
  A('jae .c1');
  A('mov ebx, eax');
  A('.c1:');
  A('cmp ebx, 4');
  A('jae .c2');
  A('mov ebx, 4');
  A('.c2:');
  A('mov ecx, ebx');
  A('shl ecx, 3');
  A('push ecx');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('push eax');
  A('mov edi, eax');
  A('mov edx, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [edx+$ARR_LEN]');
  A('shl ecx, 3');
  A('mov esi, dword ptr [edx+$ARR_ELEMS]');
  A('rep movsb');
  A('pop eax');
  A('mov edx, dword ptr [ebp+8]');
  A('mov dword ptr [edx+$ARR_ELEMS], eax');
  A('mov dword ptr [edx+$ARR_CAP], ebx');
  A('.ret:');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_array_push(tableau, valeur) -> EAX = nouvelle longueur, EDX = int }
  A('proc _JSRT_array_push');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('mov ebx, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebx+$ARR_LEN]');
  A('inc ecx');
  A('push ecx');
  A('push ecx');
  A('push ebx');
  A('call _JSRT_arr_reserve');
  A('add esp, 8');
  A('pop ecx');
  A('mov edx, dword ptr [ebx+$ARR_LEN]');
  A('shl edx, 3');
  A('add edx, dword ptr [ebx+$ARR_ELEMS]');
  A('mov eax, dword ptr [ebp+16]');
  A('mov dword ptr [edx], eax');
  A('mov eax, dword ptr [ebp+20]');
  A('mov dword ptr [edx+4], eax');
  A('mov dword ptr [ebx+$ARR_LEN], ecx');
  A('mov eax, ecx');
  A('mov edx, $INT');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_arr_setlen(arr, nouvelle longueur) : complete avec undefined }
  A('proc _JSRT_arr_setlen');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ebx, dword ptr [ebp+12]');
  A('cmp ebx, 50000000');
  A('ja .range');
  A('cmp ebx, dword ptr [esi+$ARR_LEN]');
  A('jbe .set');
  A('push ebx');
  A('push esi');
  A('call _JSRT_arr_reserve');
  A('add esp, 8');
  A('mov ecx, dword ptr [esi+$ARR_LEN]');
  A('.fill:');
  A('cmp ecx, ebx');
  A('jae .set');
  A('mov eax, ecx');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('mov dword ptr [eax], 0');
  A('mov dword ptr [eax+4], $UNDEF');
  A('inc ecx');
  A('jmp .fill');
  A('.set:');
  A('mov dword ptr [esi+$ARR_LEN], ebx');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('.range:');
  A('push offset _JSRT_c_range');
  A('call _JSRT_fatal');
  A('endp');

  { _JSRT_arr_get(arr, indice) -> valeur ou undefined }
  A('proc _JSRT_arr_get');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, dword ptr [eax+$ARR_LEN]');
  A('jae .undef');
  A('shl ecx, 3');
  A('add ecx, dword ptr [eax+$ARR_ELEMS]');
  A('mov eax, dword ptr [ecx]');
  A('mov edx, dword ptr [ecx+4]');
  A('leave');
  A('ret');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_arr_set(arr, indice, valeur lo, valeur hi) }
  A('proc _JSRT_arr_set');
  A('push ebp');
  A('mov ebp, esp');
  A('push esi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, dword ptr [esi+$ARR_LEN]');
  A('jb .store');
  A('inc ecx');
  A('push ecx');
  A('push esi');
  A('call _JSRT_arr_setlen');
  A('add esp, 8');
  A('mov ecx, dword ptr [ebp+12]');
  A('.store:');
  A('shl ecx, 3');
  A('add ecx, dword ptr [esi+$ARR_ELEMS]');
  A('mov eax, dword ptr [ebp+16]');
  A('mov dword ptr [ecx], eax');
  A('mov edx, dword ptr [ebp+20]');
  A('mov dword ptr [ecx+4], edx');
  A('pop esi');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_arr_from(pointeur de valeurs, nombre) -> nouveau tableau }
  A('proc _JSRT_arr_from');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('call _JSRT_array_new');
  A('mov ebx, eax');
  A('mov esi, dword ptr [ebp+12]');
  A('push esi');
  A('push ebx');
  A('call _JSRT_arr_reserve');
  A('add esp, 8');
  A('mov edi, dword ptr [ebx+$ARR_ELEMS]');
  A('mov ecx, esi');
  A('shl ecx, 3');
  A('mov esi, dword ptr [ebp+8]');
  A('rep movsb');
  A('mov eax, dword ptr [ebp+12]');
  A('mov dword ptr [ebx+$ARR_LEN], eax');
  A('mov eax, ebx');
  A('mov edx, $ARR');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_memmove(dest, source, octets) : copie avec recouvrement }
  A('proc _JSRT_memmove');
  A('push ebp');
  A('mov ebp, esp');
  A('push esi');
  A('push edi');
  A('mov edi, dword ptr [ebp+8]');
  A('mov esi, dword ptr [ebp+12]');
  A('mov ecx, dword ptr [ebp+16]');
  A('cmp edi, esi');
  A('jbe .fwd');
  A('.b:');
  A('test ecx, ecx');
  A('jz .d');
  A('dec ecx');
  A('movzx eax, byte ptr [esi+ecx]');
  A('mov byte ptr [edi+ecx], al');
  A('jmp .b');
  A('.fwd:');
  A('rep movsb');
  A('.d:');
  A('pop edi');
  A('pop esi');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_args_rest(argc, pointeur, debut) : arguments restants }
  A('proc _JSRT_args_rest');
  A('push ebp');
  A('mov ebp, esp');
  A('mov ecx, dword ptr [ebp+8]');
  A('sub ecx, dword ptr [ebp+16]');
  A('jns .ok');
  A('xor ecx, ecx');
  A('.ok:');
  A('mov eax, dword ptr [ebp+16]');
  A('cmp eax, dword ptr [ebp+8]');
  A('jle .a');
  A('mov eax, dword ptr [ebp+8]');
  A('.a:');
  A('shl eax, 3');
  A('add eax, dword ptr [ebp+12]');
  A('push ecx');
  A('push eax');
  A('call _JSRT_arr_from');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_make_arguments(argc, pointeur) : objet arguments (un tableau) }
  A('proc _JSRT_make_arguments');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+8]');
  A('push dword ptr [ebp+12]');
  A('call _JSRT_arr_from');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_call_array(f, this, tableau) : appel avec les elements du tableau }
  A('proc _JSRT_call_array');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('mov esi, dword ptr [ebp+24]');
  A('mov ebx, dword ptr [esi+$ARR_LEN]');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('add eax, 16');
  A('sub esp, eax');
  A('mov eax, dword ptr [ebp+8]');
  A('mov dword ptr [esp], eax');
  A('mov dword ptr [esp+4], ebx');
  A('mov eax, dword ptr [ebp+16]');
  A('mov dword ptr [esp+8], eax');
  A('mov eax, dword ptr [ebp+20]');
  A('mov dword ptr [esp+12], eax');
  A('lea edi, [esp+16]');
  A('mov ecx, ebx');
  A('shl ecx, 3');
  A('mov esi, dword ptr [esi+$ARR_ELEMS]');
  A('rep movsb');
  A('mov eax, dword ptr [ebp+8]');
  A('call dword ptr [eax+$FN_CODE]');
  A('mov esp, ebp');
  A('sub esp, 12');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_array_rest(tableau, debut) : elements restants }
  A('proc _JSRT_array_rest');
  A('push ebp');
  A('mov ebp, esp');
  A('mov edx, dword ptr [ebp+8]');
  A('cmp dword ptr [ebp+12], $ARR');
  A('jne .empty');
  A('mov ecx, dword ptr [edx+$ARR_LEN]');
  A('mov eax, dword ptr [ebp+16]');
  A('cmp eax, ecx');
  A('jle .a');
  A('mov eax, ecx');
  A('.a:');
  A('sub ecx, eax');
  A('shl eax, 3');
  A('add eax, dword ptr [edx+$ARR_ELEMS]');
  A('push ecx');
  A('push eax');
  A('call _JSRT_arr_from');
  A('leave');
  A('ret');
  A('.empty:');
  A('push 0');
  A('push 0');
  A('call _JSRT_arr_from');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_get_index(valeur, indice) : element d'un tableau ou d'une chaine }
  A('proc _JSRT_get_index');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, $ARR');
  A('je .arr');
  A('cmp ecx, $STR');
  A('je .str');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('leave');
  A('ret');
  A('.arr:');
  A('push dword ptr [ebp+16]');
  A('push eax');
  A('call _JSRT_arr_get');
  A('leave');
  A('ret');
  A('.str:');
  A('push dword ptr [ebp+16]');
  A('push eax');
  A('call _JSRT_str_char_at');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_str_to_idx(chaine) -> indice de tableau ou -1 }
  A('proc _JSRT_str_to_idx');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('test ecx, ecx');
  A('jz .no');
  A('cmp ecx, 9');
  A('ja .no');
  A('lea esi, [esi+$STR_DATA]');
  A('cmp ecx, 1');
  A('je .go');
  A('cmp byte ptr [esi], 48');
  A('je .no');
  A('.go:');
  A('xor eax, eax');
  A('.l:');
  A('movzx edx, byte ptr [esi]');
  A('sub edx, 48');
  A('cmp edx, 9');
  A('ja .no');
  A('mov ebx, eax');
  A('shl eax, 3');
  A('add eax, ebx');
  A('add eax, ebx');
  A('add eax, edx');
  A('inc esi');
  A('dec ecx');
  A('jnz .l');
  A('jmp .out');
  A('.no:');
  A('mov eax, -1');
  A('.out:');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_arr_get_name(arr, cle chaine) : length, indice texte ou methode }
  A('proc _JSRT_arr_get_name');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+12]');
  A('call _JSRT_str_to_idx');
  A('add esp, 4');
  A('cmp eax, -1');
  A('je .name');
  A('push eax');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_arr_get');
  A('leave');
  A('ret');
  A('.name:');
  A('push dword ptr [ebp+12]');
  A('push offset ' + RtStr('length'));
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .proto');
  A('mov eax, dword ptr [ebp+8]');
  A('mov eax, dword ptr [eax+$ARR_LEN]');
  A('mov edx, $INT');
  A('leave');
  A('ret');
  A('.proto:');
  A('push dword ptr [ebp+12]');
  A('push offset _JSNO_array_proto');
  A('call _JSRT_obj_lookup_str');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_set_prop(objet, atome, valeur) : objet.nom = valeur }
  A('proc _JSRT_set_prop');
  A('push ebp');
  A('mov ebp, esp');
  A('cmp dword ptr [ebp+12], $ARR');
  A('jne .other');
  A('mov ecx, offset ' + RtStr('length'));
  A('cmp dword ptr [ebp+16], ecx');
  A('jne .other');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+20]');
  A('call _JSRT_toint32');
  A('add esp, 8');
  A('test eax, eax');
  A('js .range');
  A('push eax');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_arr_setlen');
  A('add esp, 8');
  A('mov eax, dword ptr [ebp+20]');
  A('mov edx, dword ptr [ebp+24]');
  A('leave');
  A('ret');
  A('.other:');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_obj_set');
  A('leave');
  A('ret');
  A('.range:');
  A('push offset _JSRT_c_range');
  A('call _JSRT_fatal');
  A('endp');

  { _JSRT_set_member(objet, cle, valeur) : objet[cle] = valeur }
  A('proc _JSRT_set_member');
  A('push ebp');
  A('mov ebp, esp');
  A('cmp dword ptr [ebp+12], $ARR');
  A('jne .other');
  A('mov ecx, dword ptr [ebp+20]');
  A('cmp ecx, $INT');
  A('je .idx');
  A('cmp ecx, $STR');
  A('jne .other');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_str_to_idx');
  A('add esp, 4');
  A('cmp eax, -1');
  A('je .name');
  A('jmp .store');
  A('.name:');
  A('push dword ptr [ebp+28]');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_set_prop_str');
  A('leave');
  A('ret');
  A('.idx:');
  A('mov eax, dword ptr [ebp+16]');
  A('test eax, eax');
  A('js .range');
  A('.store:');
  A('push dword ptr [ebp+28]');
  A('push dword ptr [ebp+24]');
  A('push eax');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_arr_set');
  A('mov eax, dword ptr [ebp+24]');
  A('mov edx, dword ptr [ebp+28]');
  A('leave');
  A('ret');
  A('.other:');
  A('push dword ptr [ebp+28]');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_obj_set_member');
  A('leave');
  A('ret');
  A('.range:');
  A('push offset _JSRT_c_range');
  A('call _JSRT_fatal');
  A('endp');

  { _JSRT_set_prop_str(objet, chaine, valeur) : length d'un tableau par nom dynamique }
  A('proc _JSRT_set_prop_str');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+16]');
  A('push offset ' + RtStr('length'));
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .other');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+20]');
  A('push offset ' + RtStr('length'));
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_set_prop');
  A('leave');
  A('ret');
  A('.other:');
  A('push offset _JSRT_c_type');
  A('call _JSRT_fatal');
  A('endp');

End;

{ Iterateurs (for-of, for-in, spread) et jointure. }
Procedure RtArrayIter;
Begin
  { _JSRT_u8len(octet de tete) -> longueur de la sequence UTF-8 }
  A('proc _JSRT_u8len');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('cmp eax, 128');
  A('jb .one');
  A('cmp eax, 224');
  A('jb .two');
  A('cmp eax, 240');
  A('jb .three');
  A('mov eax, 4');
  A('leave');
  A('ret');
  A('.one:');
  A('mov eax, 1');
  A('leave');
  A('ret');
  A('.two:');
  A('mov eax, 2');
  A('leave');
  A('ret');
  A('.three:');
  A('mov eax, 3');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_iter_new(valeur) -> iterateur (source +8, indice +16) }
  A('proc _JSRT_iter_new');
  A('push ebp');
  A('mov ebp, esp');
  A('cmp dword ptr [ebp+12], $ARR');
  A('je .ok');
  A('cmp dword ptr [ebp+12], $STR');
  A('je .ok');
  A('push offset _JSRT_c_noiter');
  A('call _JSRT_fatal');
  A('.ok:');
  A('push 24');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov byte ptr [eax], $OK_ENV');
  A('mov ecx, dword ptr [ebp+8]');
  A('mov dword ptr [eax+8], ecx');
  A('mov ecx, dword ptr [ebp+12]');
  A('mov dword ptr [eax+12], ecx');
  A('mov edx, $OBJ');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_iter_next(iterateur) -> valeur suivante ou DONE }
  A('proc _JSRT_iter_next');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('mov esi, dword ptr [ebp+8]');
  A('mov eax, dword ptr [esi+8]');
  A('mov ecx, dword ptr [esi+16]');
  A('cmp dword ptr [esi+12], $ARR');
  A('jne .str');
  A('cmp ecx, dword ptr [eax+$ARR_LEN]');
  A('jae .done');
  A('lea edx, [ecx+1]');
  A('mov dword ptr [esi+16], edx');
  A('shl ecx, 3');
  A('add ecx, dword ptr [eax+$ARR_ELEMS]');
  A('mov eax, dword ptr [ecx]');
  A('mov edx, dword ptr [ecx+4]');
  A('jmp .out');
  A('.str:');
  A('cmp ecx, dword ptr [eax+$STR_LEN]');
  A('jae .done');
  A('movzx edx, byte ptr [eax+ecx+$STR_DATA]');
  A('push edx');
  A('call _JSRT_u8len');
  A('add esp, 4');
  A('mov ebx, eax');
  A('mov ecx, dword ptr [esi+16]');
  A('mov eax, dword ptr [esi+8]');
  A('mov edx, dword ptr [eax+$STR_LEN]');
  A('sub edx, ecx');
  A('cmp ebx, edx');
  A('jbe .n');
  A('mov ebx, edx');
  A('.n:');
  A('lea edx, [ecx+ebx]');
  A('mov dword ptr [esi+16], edx');
  A('push edx');
  A('push ecx');
  A('push eax');
  A('call _JSRT_str_sub');
  A('add esp, 12');
  A('jmp .out');
  A('.done:');
  A('xor eax, eax');
  A('mov edx, $DONE');
  A('.out:');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_array_spread(tableau, source) : ajoute les elements de la source }
  A('proc _JSRT_array_spread');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_iter_new');
  A('add esp, 8');
  A('mov esi, eax');
  A('.l:');
  A('push $OBJ');
  A('push esi');
  A('call _JSRT_iter_next');
  A('add esp, 8');
  A('cmp edx, $DONE');
  A('je .d');
  A('push edx');
  A('push eax');
  A('push $ARR');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_array_push');
  A('add esp, 16');
  A('jmp .l');
  A('.d:');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_arr_join(tableau, separateur) -> chaine }
  A('proc _JSRT_arr_join');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  A('sub esp, 12');
  A('mov esi, dword ptr [ebp+8]');
  A('mov eax, dword ptr [esi+$ARR_LEN]');
  A('mov ' + Lv(3) + ', eax');
  A('test eax, eax');
  A('jz .empty');
  A('shl eax, 2');
  A('push eax');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov ' + Lv(1) + ', eax');
  A('mov ' + Lv(2) + ', 0');
  A('xor ebx, ebx');
  A('.c:');
  A('cmp ebx, ' + Lv(3));
  A('jae .alloc');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('mov ecx, dword ptr [eax+4]');
  A('cmp ecx, $UNDEF');
  A('je .e');
  A('cmp ecx, $NULL');
  A('je .e');
  A('push ecx');
  A('push dword ptr [eax]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('jmp .s');
  A('.e:');
  A('mov eax, offset ' + RtStr(''));
  A('.s:');
  A('mov edx, ebx');
  A('shl edx, 2');
  A('add edx, ' + Lv(1));
  A('mov dword ptr [edx], eax');
  A('mov ecx, dword ptr [eax+$STR_LEN]');
  A('mov edx, ' + Lv(2));
  A('add edx, ecx');
  A('mov ' + Lv(2) + ', edx');
  A('inc ebx');
  A('jmp .c');
  A('.alloc:');
  A('mov eax, ' + Lv(3));
  A('dec eax');
  A('mov ecx, dword ptr [ebp+12]');
  A('mov edx, dword ptr [ecx+$STR_LEN]');
  A('imul eax, edx');
  A('add eax, ' + Lv(2));
  A('push eax');
  A('call _JSRT_str_new');
  A('add esp, 4');
  A('mov edi, eax');
  A('add edi, $STR_DATA');
  A('push eax');
  A('xor ebx, ebx');
  A('.f:');
  A('cmp ebx, ' + Lv(3));
  A('jae .done');
  A('test ebx, ebx');
  A('jz .nosep');
  A('mov esi, dword ptr [ebp+12]');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('lea esi, [esi+$STR_DATA]');
  A('rep movsb');
  A('.nosep:');
  A('mov eax, ebx');
  A('shl eax, 2');
  A('add eax, ' + Lv(1));
  A('mov esi, dword ptr [eax]');
  A('mov ecx, dword ptr [esi+$STR_LEN]');
  A('lea esi, [esi+$STR_DATA]');
  A('rep movsb');
  A('inc ebx');
  A('jmp .f');
  A('.done:');
  A('pop eax');
  A('mov edx, $STR');
  A('jmp .out');
  A('.empty:');
  A('mov eax, offset ' + RtStr(''));
  A('mov edx, $STR');
  A('.out:');
  A('mov esp, ebp');
  A('sub esp, 12');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');
End;

{ Appels de rappel : _JSRT_arr_cb(f, this, ptr valeur, indice, tableau) et
  _JSRT_arr_cb4 avec accumulateur, _JSRT_sort_cmp. }
Procedure RtArrayCallbacks;
Begin
  A('proc _JSRT_arr_cb');
  A('push ebp');
  A('mov ebp, esp');
  A('cmp dword ptr [ebp+12], $FN');
  A('jne .nf');
  A('sub esp, 40');
  A('mov eax, dword ptr [ebp+8]');
  A('mov dword ptr [esp], eax');
  A('mov dword ptr [esp+4], 3');
  A('mov eax, dword ptr [ebp+16]');
  A('mov dword ptr [esp+8], eax');
  A('mov eax, dword ptr [ebp+20]');
  A('mov dword ptr [esp+12], eax');
  A('mov ecx, dword ptr [ebp+24]');
  A('mov eax, dword ptr [ecx]');
  A('mov dword ptr [esp+16], eax');
  A('mov eax, dword ptr [ecx+4]');
  A('mov dword ptr [esp+20], eax');
  A('mov eax, dword ptr [ebp+28]');
  A('mov dword ptr [esp+24], eax');
  A('mov dword ptr [esp+28], $INT');
  A('mov eax, dword ptr [ebp+32]');
  A('mov dword ptr [esp+32], eax');
  A('mov dword ptr [esp+36], $ARR');
  A('mov eax, dword ptr [ebp+8]');
  A('call dword ptr [eax+$FN_CODE]');
  A('leave');
  A('ret');
  A('.nf:');
  A('call _JSRT_throw_notfunc');
  A('endp');

  { _JSRT_arr_cb4(f, acc, ptr valeur, indice, tableau) }
  A('proc _JSRT_arr_cb4');
  A('push ebp');
  A('mov ebp, esp');
  A('cmp dword ptr [ebp+12], $FN');
  A('jne .nf');
  A('sub esp, 48');
  A('mov eax, dword ptr [ebp+8]');
  A('mov dword ptr [esp], eax');
  A('mov dword ptr [esp+4], 4');
  A('mov dword ptr [esp+8], 0');
  A('mov dword ptr [esp+12], $UNDEF');
  A('mov eax, dword ptr [ebp+16]');
  A('mov dword ptr [esp+16], eax');
  A('mov eax, dword ptr [ebp+20]');
  A('mov dword ptr [esp+20], eax');
  A('mov ecx, dword ptr [ebp+24]');
  A('mov eax, dword ptr [ecx]');
  A('mov dword ptr [esp+24], eax');
  A('mov eax, dword ptr [ecx+4]');
  A('mov dword ptr [esp+28], eax');
  A('mov eax, dword ptr [ebp+28]');
  A('mov dword ptr [esp+32], eax');
  A('mov dword ptr [esp+36], $INT');
  A('mov eax, dword ptr [ebp+32]');
  A('mov dword ptr [esp+40], eax');
  A('mov dword ptr [esp+44], $ARR');
  A('mov eax, dword ptr [ebp+8]');
  A('call dword ptr [eax+$FN_CODE]');
  A('leave');
  A('ret');
  A('.nf:');
  A('call _JSRT_throw_notfunc');
  A('endp');

  { _JSRT_sort_cmp(f lo, f hi, pa, pb) -> EAX < 0, 0 ou > 0 }
  A('proc _JSRT_sort_cmp');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('mov ecx, dword ptr [ebp+16]');
  A('mov eax, dword ptr [ecx+4]');
  A('mov edx, dword ptr [ebp+20]');
  A('mov edx, dword ptr [edx+4]');
  A('cmp eax, $UNDEF');
  A('jne .adef');
  A('cmp edx, $UNDEF');
  A('je .eq0');
  A('mov eax, 1');
  A('jmp .out');
  A('.adef:');
  A('cmp edx, $UNDEF');
  A('jne .both');
  A('mov eax, -1');
  A('jmp .out');
  A('.eq0:');
  A('xor eax, eax');
  A('jmp .out');
  A('.both:');
  A('cmp dword ptr [ebp+12], $FN');
  A('jne .dflt');
  A('sub esp, 32');
  A('mov eax, dword ptr [ebp+8]');
  A('mov dword ptr [esp], eax');
  A('mov dword ptr [esp+4], 2');
  A('mov dword ptr [esp+8], 0');
  A('mov dword ptr [esp+12], $UNDEF');
  A('mov ecx, dword ptr [ebp+16]');
  A('mov eax, dword ptr [ecx]');
  A('mov dword ptr [esp+16], eax');
  A('mov eax, dword ptr [ecx+4]');
  A('mov dword ptr [esp+20], eax');
  A('mov ecx, dword ptr [ebp+20]');
  A('mov eax, dword ptr [ecx]');
  A('mov dword ptr [esp+24], eax');
  A('mov eax, dword ptr [ecx+4]');
  A('mov dword ptr [esp+28], eax');
  A('mov eax, dword ptr [ebp+8]');
  A('call dword ptr [eax+$FN_CODE]');
  A('add esp, 32');
  A('cmp edx, $INT');
  A('je .out');
  A('cmp edx, $BOOL');
  A('je .out');
  A('push edx');
  A('push eax');
  A('call _JSRT_toint32');
  A('add esp, 8');
  A('jmp .out');
  A('.dflt:');
  A('mov ecx, dword ptr [ebp+16]');
  A('push dword ptr [ecx+4]');
  A('push dword ptr [ecx]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('mov ebx, eax');
  A('mov ecx, dword ptr [ebp+20]');
  A('push dword ptr [ecx+4]');
  A('push dword ptr [ecx]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push eax');
  A('push ebx');
  A('call _JSRT_str_cmp');
  A('add esp, 8');
  A('.out:');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');
End;

{ push / pop / shift / unshift }
Procedure RtArrayStack;
Begin
  ArrBegin('_JSRT_am_push', 0);
  A('xor ebx, ebx');
  A('.l:');
  A('cmp ebx, dword ptr [ebp+12]');
  A('jae .d');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('lea eax, [ebp+eax+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('push dword ptr [eax+4]');
  A('push dword ptr [eax]');
  A('push $ARR');
  A('push esi');
  A('call _JSRT_array_push');
  A('add esp, 16');
  A('inc ebx');
  A('jmp .l');
  A('.d:');
  A('mov eax, dword ptr [esi+$ARR_LEN]');
  A('mov edx, $INT');
  A('jmp .ret');
  ArrEnd;

  ArrBegin('_JSRT_am_pop', 0);
  A('mov ecx, dword ptr [esi+$ARR_LEN]');
  A('test ecx, ecx');
  A('jz .undef');
  A('dec ecx');
  A('mov dword ptr [esi+$ARR_LEN], ecx');
  A('shl ecx, 3');
  A('add ecx, dword ptr [esi+$ARR_ELEMS]');
  A('mov eax, dword ptr [ecx]');
  A('mov edx, dword ptr [ecx+4]');
  A('jmp .ret');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('jmp .ret');
  ArrEnd;

  ArrBegin('_JSRT_am_shift', 2);
  A('mov ecx, dword ptr [esi+$ARR_LEN]');
  A('test ecx, ecx');
  A('jz .undef');
  A('mov edi, dword ptr [esi+$ARR_ELEMS]');
  A('mov eax, dword ptr [edi]');
  A('mov ' + Lv(1) + ', eax');
  A('mov eax, dword ptr [edi+4]');
  A('mov ' + Lv(2) + ', eax');
  A('dec ecx');
  A('mov dword ptr [esi+$ARR_LEN], ecx');
  A('shl ecx, 3');
  A('push ecx');
  A('lea eax, [edi+8]');
  A('push eax');
  A('push edi');
  A('call _JSRT_memmove');
  A('add esp, 12');
  A('mov eax, ' + Lv(1));
  A('mov edx, ' + Lv(2));
  A('jmp .ret');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('jmp .ret');
  ArrEnd;

  ArrBegin('_JSRT_am_unshift', 1);
  A('mov ebx, dword ptr [ebp+12]');
  A('test ebx, ebx');
  A('jz .d');
  A('mov eax, dword ptr [esi+$ARR_LEN]');
  A('add eax, ebx');
  A('push eax');
  A('push esi');
  A('call _JSRT_arr_reserve');
  A('add esp, 8');
  A('mov edi, dword ptr [esi+$ARR_ELEMS]');
  A('mov ecx, dword ptr [esi+$ARR_LEN]');
  A('shl ecx, 3');
  A('mov edx, ebx');
  A('shl edx, 3');
  A('add edx, edi');
  A('push ecx');
  A('push edi');
  A('push edx');
  A('call _JSRT_memmove');
  A('add esp, 12');
  A('mov ecx, ebx');
  A('shl ecx, 3');
  A('lea eax, [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('push ecx');
  A('push eax');
  A('push edi');
  A('call _JSRT_memmove');
  A('add esp, 12');
  A('add ebx, dword ptr [esi+$ARR_LEN]');
  A('mov dword ptr [esi+$ARR_LEN], ebx');
  A('.d:');
  A('mov eax, dword ptr [esi+$ARR_LEN]');
  A('mov edx, $INT');
  A('jmp .ret');
  ArrEnd;
End;

{ indexOf / lastIndexOf / includes ; mode 0 indexOf, 1 lastIndexOf, 2 includes }
Procedure ArrSearch(Const code: TString; mode: LongInt);
Begin
  ArrBegin(code, 3);
  ArgToLocals(0, 1, 2);
  If mode = 1 Then
    Begin
      A('mov ebx, dword ptr [esi+$ARR_LEN]');
      A('dec ebx');
      MArgInt(1, '2147483647');
      A('cmp eax, 2147483647');
      A('je .l');
      A('test eax, eax');
      A('jns .fp');
      A('add eax, dword ptr [esi+$ARR_LEN]');
      A('.fp:');
      A('cmp eax, ebx');
      A('jge .l');
      A('mov ebx, eax');
      A('.l:');
      A('test ebx, ebx');
      A('js .nf');
    End
  Else
    Begin
      MArgInt(1, '0');
      A('test eax, eax');
      A('jns .fp');
      A('add eax, dword ptr [esi+$ARR_LEN]');
      A('jns .fp');
      A('xor eax, eax');
      A('.fp:');
      A('mov ebx, eax');
      A('.l:');
      A('cmp ebx, dword ptr [esi+$ARR_LEN]');
      A('jae .nf');
    End;
  A('mov eax, ebx');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('push ' + Lv(2));
  A('push ' + Lv(1));
  A('push dword ptr [eax+4]');
  A('push dword ptr [eax]');
  A('call _JSRT_seq');
  A('add esp, 16');
  A('test eax, eax');
  A('jnz .found');
  If mode = 1 Then
    A('dec ebx')
  Else
    A('inc ebx');
  A('jmp .l');
  A('.found:');
  If mode = 2 Then
    Begin
      A('mov eax, 1');
      A('mov edx, $BOOL');
    End
  Else
    Begin
      A('mov eax, ebx');
      A('mov edx, $INT');
    End;
  A('jmp .ret');
  A('.nf:');
  If mode = 2 Then
    Begin
      A('xor eax, eax');
      A('mov edx, $BOOL');
    End
  Else
    Begin
      A('mov eax, -1');
      A('mov edx, $INT');
    End;
  A('jmp .ret');
  ArrEnd;
End;

{ Methodes a rappel : forEach, map, filter, some, every, find, findIndex }
Procedure ArrIter(Const code: TString; mode: LongInt);
Begin
  ArrBegin(code, 6);
  ArgToLocals(0, 1, 2);
  ArgToLocals(1, 3, 4);
  A('mov eax, dword ptr [esi+$ARR_LEN]');
  A('mov ' + Lv(5) + ', eax');
  If (mode = 1) Or (mode = 2) Then
    Begin
      A('call _JSRT_array_new');
      A('mov ' + Lv(6) + ', eax');
    End;
  A('xor ebx, ebx');
  A('.l:');
  A('cmp ebx, ' + Lv(5));
  A('jae .done');
  A('cmp ebx, dword ptr [esi+$ARR_LEN]');
  A('jae .done');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('push esi');
  A('push ebx');
  A('push eax');
  A('push ' + Lv(4));
  A('push ' + Lv(3));
  A('push ' + Lv(2));
  A('push ' + Lv(1));
  A('call _JSRT_arr_cb');
  A('add esp, 28');
  Case mode Of
    1:
      Begin
        A('push edx');
        A('push eax');
        A('push $ARR');
        A('push ' + Lv(6));
        A('call _JSRT_array_push');
        A('add esp, 16');
      End;
    2, 3, 4, 5, 6:
      Begin
        A('push edx');
        A('push eax');
        A('call _JSRT_truthy');
        A('add esp, 8');
        A('test eax, eax');
        Case mode Of
          2:
            Begin
              A('jz .skip');
              A('mov eax, ebx');
              A('shl eax, 3');
              A('add eax, dword ptr [esi+$ARR_ELEMS]');
              A('push dword ptr [eax+4]');
              A('push dword ptr [eax]');
              A('push $ARR');
              A('push ' + Lv(6));
              A('call _JSRT_array_push');
              A('add esp, 16');
            End;
          3: A('jnz .rtrue');
          4: A('jz .rfalse');
          5, 6:
            Begin
              A('jz .skip');
              If mode = 5 Then
                Begin
                  A('mov eax, ebx');
                  A('shl eax, 3');
                  A('add eax, dword ptr [esi+$ARR_ELEMS]');
                  A('mov edx, dword ptr [eax+4]');
                  A('mov eax, dword ptr [eax]');
                  A('jmp .ret');
                End
              Else
                Begin
                  A('mov eax, ebx');
                  A('mov edx, $INT');
                  A('jmp .ret');
                End;
            End;
        End;
      End;
  End;
  A('.skip:');
  A('inc ebx');
  A('jmp .l');
  A('.done:');
  Case mode Of
    1, 2:
      Begin
        A('mov eax, ' + Lv(6));
        A('mov edx, $ARR');
      End;
    3:
      Begin
        A('xor eax, eax');
        A('mov edx, $BOOL');
      End;
    4:
      Begin
        A('mov eax, 1');
        A('mov edx, $BOOL');
      End;
    6:
      Begin
        A('mov eax, -1');
        A('mov edx, $INT');
      End;
  Else
    Begin
      A('xor eax, eax');
      A('mov edx, $UNDEF');
    End;
  End;
  A('jmp .ret');
  If mode = 3 Then
    Begin
      A('.rtrue:');
      A('mov eax, 1');
      A('mov edx, $BOOL');
      A('jmp .ret');
    End;
  If mode = 4 Then
    Begin
      A('.rfalse:');
      A('xor eax, eax');
      A('mov edx, $BOOL');
      A('jmp .ret');
    End;
  ArrEnd;
End;

Procedure RtArrayMethods;
Begin
  RtArrayStack;
  ArrSearch('_JSRT_am_indexOf', 0);
  ArrSearch('_JSRT_am_lastIndexOf', 1);
  ArrSearch('_JSRT_am_includes', 2);
  ArrIter('_JSRT_am_forEach', 0);
  ArrIter('_JSRT_am_map', 1);
  ArrIter('_JSRT_am_filter', 2);
  ArrIter('_JSRT_am_some', 3);
  ArrIter('_JSRT_am_every', 4);
  ArrIter('_JSRT_am_find', 5);
  ArrIter('_JSRT_am_findIndex', 6);

  { reverse() : sur place }
  ArrBegin('_JSRT_am_reverse', 0);
  A('mov ecx, dword ptr [esi+$ARR_LEN]');
  A('cmp ecx, 2');
  A('jb .d');
  A('mov ebx, dword ptr [esi+$ARR_ELEMS]');
  A('dec ecx');
  A('shl ecx, 3');
  A('lea edi, [ebx+ecx]');
  A('.l:');
  A('cmp ebx, edi');
  A('jae .d');
  A('mov eax, dword ptr [ebx]');
  A('mov ecx, dword ptr [edi]');
  A('mov dword ptr [ebx], ecx');
  A('mov dword ptr [edi], eax');
  A('mov eax, dword ptr [ebx+4]');
  A('mov ecx, dword ptr [edi+4]');
  A('mov dword ptr [ebx+4], ecx');
  A('mov dword ptr [edi+4], eax');
  A('add ebx, 8');
  A('sub edi, 8');
  A('jmp .l');
  A('.d:');
  A('mov eax, esi');
  A('mov edx, $ARR');
  A('jmp .ret');
  ArrEnd;

  { sort(comparateur) : tri fusion stable }
  ArrBegin('_JSRT_am_sort', 12);
  A('mov ' + Lv(1) + ', 0');
  A('mov ' + Lv(2) + ', $UNDEF');
  A('cmp dword ptr [ebp+12], 1');
  A('jb .nocmp');
  A('mov eax, dword ptr [ebp+24]');
  A('mov ' + Lv(1) + ', eax');
  A('mov eax, dword ptr [ebp+28]');
  A('mov ' + Lv(2) + ', eax');
  A('.nocmp:');
  A('mov eax, dword ptr [esi+$ARR_LEN]');
  A('mov ' + Lv(3) + ', eax');
  A('cmp eax, 2');
  A('jb .retthis');
  A('shl eax, 3');
  A('push eax');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov ' + Lv(5) + ', eax');
  A('mov eax, dword ptr [esi+$ARR_ELEMS]');
  A('mov ' + Lv(4) + ', eax');
  A('mov ' + Lv(6) + ', 1');
  A('.pass:');
  A('mov eax, ' + Lv(6));
  A('cmp eax, ' + Lv(3));
  A('jae .passes');
  A('mov ' + Lv(7) + ', 0');
  A('.blk:');
  A('mov eax, ' + Lv(7));
  A('cmp eax, ' + Lv(3));
  A('jae .blkdone');
  A('add eax, ' + Lv(6));
  A('cmp eax, ' + Lv(3));
  A('jbe .m1');
  A('mov eax, ' + Lv(3));
  A('.m1:');
  A('mov ' + Lv(8) + ', eax');
  A('add eax, ' + Lv(6));
  A('cmp eax, ' + Lv(3));
  A('jbe .m2');
  A('mov eax, ' + Lv(3));
  A('.m2:');
  A('mov ' + Lv(9) + ', eax');
  A('mov eax, ' + Lv(7));
  A('mov ' + Lv(10) + ', eax');
  A('mov ' + Lv(12) + ', eax');
  A('mov eax, ' + Lv(8));
  A('mov ' + Lv(11) + ', eax');
  A('.mrg:');
  A('mov eax, ' + Lv(10));
  A('cmp eax, ' + Lv(8));
  A('jae .rt');
  A('mov eax, ' + Lv(11));
  A('cmp eax, ' + Lv(9));
  A('jae .tl');
  A('shl eax, 3');
  A('add eax, ' + Lv(4));
  A('mov ecx, ' + Lv(10));
  A('shl ecx, 3');
  A('add ecx, ' + Lv(4));
  A('push eax');
  A('push ecx');
  A('push ' + Lv(2));
  A('push ' + Lv(1));
  A('call _JSRT_sort_cmp');
  A('add esp, 16');
  A('cmp eax, 0');
  A('jg .tr');
  A('.tl:');
  A('mov eax, ' + Lv(10));
  A('shl eax, 3');
  A('add eax, ' + Lv(4));
  A('mov ecx, ' + Lv(12));
  A('shl ecx, 3');
  A('add ecx, ' + Lv(5));
  A('mov edx, dword ptr [eax]');
  A('mov dword ptr [ecx], edx');
  A('mov edx, dword ptr [eax+4]');
  A('mov dword ptr [ecx+4], edx');
  A('mov eax, ' + Lv(10));
  A('inc eax');
  A('mov ' + Lv(10) + ', eax');
  A('mov eax, ' + Lv(12));
  A('inc eax');
  A('mov ' + Lv(12) + ', eax');
  A('jmp .mrg');
  A('.rt:');
  A('mov eax, ' + Lv(11));
  A('cmp eax, ' + Lv(9));
  A('jae .blknext');
  A('.tr:');
  A('mov eax, ' + Lv(11));
  A('shl eax, 3');
  A('add eax, ' + Lv(4));
  A('mov ecx, ' + Lv(12));
  A('shl ecx, 3');
  A('add ecx, ' + Lv(5));
  A('mov edx, dword ptr [eax]');
  A('mov dword ptr [ecx], edx');
  A('mov edx, dword ptr [eax+4]');
  A('mov dword ptr [ecx+4], edx');
  A('mov eax, ' + Lv(11));
  A('inc eax');
  A('mov ' + Lv(11) + ', eax');
  A('mov eax, ' + Lv(12));
  A('inc eax');
  A('mov ' + Lv(12) + ', eax');
  A('jmp .mrg');
  A('.blknext:');
  A('mov eax, ' + Lv(6));
  A('add eax, eax');
  A('add eax, ' + Lv(7));
  A('mov ' + Lv(7) + ', eax');
  A('jmp .blk');
  A('.blkdone:');
  A('mov eax, ' + Lv(4));
  A('mov edx, ' + Lv(5));
  A('mov ' + Lv(4) + ', edx');
  A('mov ' + Lv(5) + ', eax');
  A('mov eax, ' + Lv(6));
  A('add eax, eax');
  A('mov ' + Lv(6) + ', eax');
  A('jmp .pass');
  A('.passes:');
  A('mov eax, ' + Lv(4));
  A('cmp eax, dword ptr [esi+$ARR_ELEMS]');
  A('je .retthis');
  A('mov ecx, ' + Lv(3));
  A('shl ecx, 3');
  A('mov edi, dword ptr [esi+$ARR_ELEMS]');
  A('push esi');
  A('mov esi, eax');
  A('rep movsb');
  A('pop esi');
  A('.retthis:');
  A('mov eax, esi');
  A('mov edx, $ARR');
  A('jmp .ret');
  ArrEnd;

  { reduce(rappel, initial) }
  ArrBegin('_JSRT_am_reduce', 5);
  ArgToLocals(0, 1, 2);
  A('xor ebx, ebx');
  A('cmp dword ptr [ebp+12], 2');
  A('jb .noinit');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8) + ']');
  A('mov ' + Lv(3) + ', eax');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 12) + ']');
  A('mov ' + Lv(4) + ', eax');
  A('jmp .l');
  A('.noinit:');
  A('cmp dword ptr [esi+$ARR_LEN], 0');
  A('je .empty');
  A('mov eax, dword ptr [esi+$ARR_ELEMS]');
  A('mov ecx, dword ptr [eax]');
  A('mov ' + Lv(3) + ', ecx');
  A('mov ecx, dword ptr [eax+4]');
  A('mov ' + Lv(4) + ', ecx');
  A('mov ebx, 1');
  A('.l:');
  A('cmp ebx, dword ptr [esi+$ARR_LEN]');
  A('jae .done');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('push esi');
  A('push ebx');
  A('push eax');
  A('push ' + Lv(4));
  A('push ' + Lv(3));
  A('push ' + Lv(2));
  A('push ' + Lv(1));
  A('call _JSRT_arr_cb4');
  A('add esp, 28');
  A('mov ' + Lv(3) + ', eax');
  A('mov ' + Lv(4) + ', edx');
  A('inc ebx');
  A('jmp .l');
  A('.done:');
  A('mov eax, ' + Lv(3));
  A('mov edx, ' + Lv(4));
  A('jmp .ret');
  A('.empty:');
  A('push offset _JSRT_c_type');
  A('call _JSRT_fatal');
  ArrEnd;

  { slice(debut, fin) }
  ArrBegin('_JSRT_am_slice', 1);
  MArgInt(0, '0');
  A('push dword ptr [esi+$ARR_LEN]');
  A('push eax');
  A('call _JSRT_relidx');
  A('add esp, 8');
  A('mov ebx, eax');
  MArgInt(1, '2147483647');
  A('push dword ptr [esi+$ARR_LEN]');
  A('push eax');
  A('call _JSRT_relidx');
  A('add esp, 8');
  A('sub eax, ebx');
  A('jg .ok');
  A('xor eax, eax');
  A('.ok:');
  A('push eax');
  A('shl ebx, 3');
  A('add ebx, dword ptr [esi+$ARR_ELEMS]');
  A('push ebx');
  A('call _JSRT_arr_from');
  A('add esp, 8');
  A('jmp .ret');
  ArrEnd;

  { splice(debut, nombre, ...elements) }
  ArrBegin('_JSRT_am_splice', 5);
  MArgInt(0, '0');
  A('push dword ptr [esi+$ARR_LEN]');
  A('push eax');
  A('call _JSRT_relidx');
  A('add esp, 8');
  A('mov ' + Lv(1) + ', eax');
  A('mov ecx, dword ptr [esi+$ARR_LEN]');
  A('sub ecx, eax');
  A('cmp dword ptr [ebp+12], 0');
  A('je .dc0');
  A('cmp dword ptr [ebp+12], 1');
  A('je .dcset');
  MArgInt(1, '0');
  A('mov ecx, dword ptr [esi+$ARR_LEN]');
  A('sub ecx, ' + Lv(1));
  A('push ecx');
  A('push eax');
  A('call _JSRT_clampidx');
  A('add esp, 8');
  A('mov ecx, eax');
  A('jmp .dcset');
  A('.dc0:');
  A('xor ecx, ecx');
  A('.dcset:');
  A('mov ' + Lv(2) + ', ecx');
  A('mov eax, dword ptr [ebp+12]');
  A('sub eax, 2');
  A('jns .k');
  A('xor eax, eax');
  A('.k:');
  A('mov ' + Lv(3) + ', eax');
  { tableau retire }
  A('mov eax, ' + Lv(1));
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('push ' + Lv(2));
  A('push eax');
  A('call _JSRT_arr_from');
  A('add esp, 8');
  A('mov ' + Lv(4) + ', eax');
  { reserve newlen = len - dc + k }
  A('mov eax, dword ptr [esi+$ARR_LEN]');
  A('sub eax, ' + Lv(2));
  A('add eax, ' + Lv(3));
  A('mov ' + Lv(5) + ', eax');
  A('push eax');
  A('push esi');
  A('call _JSRT_arr_reserve');
  A('add esp, 8');
  { deplace la queue : [debut+dc, len) vers debut+k }
  A('mov edi, dword ptr [esi+$ARR_ELEMS]');
  A('mov eax, ' + Lv(1));
  A('add eax, ' + Lv(2));
  A('mov ecx, dword ptr [esi+$ARR_LEN]');
  A('sub ecx, eax');
  A('shl ecx, 3');
  A('shl eax, 3');
  A('add eax, edi');
  A('mov edx, ' + Lv(1));
  A('add edx, ' + Lv(3));
  A('shl edx, 3');
  A('add edx, edi');
  A('push ecx');
  A('push eax');
  A('push edx');
  A('call _JSRT_memmove');
  A('add esp, 12');
  { elements inseres }
  A('mov ecx, ' + Lv(3));
  A('shl ecx, 3');
  A('mov edx, ' + Lv(1));
  A('shl edx, 3');
  A('add edx, edi');
  A('lea eax, [ebp+' + IntToStr(RT_FRAME_ARGS + 16) + ']');
  A('push ecx');
  A('push eax');
  A('push edx');
  A('call _JSRT_memmove');
  A('add esp, 12');
  A('mov eax, ' + Lv(5));
  A('mov dword ptr [esi+$ARR_LEN], eax');
  A('mov eax, ' + Lv(4));
  A('mov edx, $ARR');
  A('jmp .ret');
  ArrEnd;

  { concat(...) }
  ArrBegin('_JSRT_am_concat', 1);
  A('push dword ptr [esi+$ARR_LEN]');
  A('push dword ptr [esi+$ARR_ELEMS]');
  A('call _JSRT_arr_from');
  A('add esp, 8');
  A('mov ' + Lv(1) + ', eax');
  A('xor ebx, ebx');
  A('.l:');
  A('cmp ebx, dword ptr [ebp+12]');
  A('jae .d');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('lea eax, [ebp+eax+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('push dword ptr [eax+4]');
  A('push dword ptr [eax]');
  A('cmp dword ptr [eax+4], $ARR');
  A('je .sp');
  A('push $ARR');
  A('push ' + Lv(1));
  A('call _JSRT_array_push');
  A('add esp, 16');
  A('jmp .n');
  A('.sp:');
  A('push $ARR');
  A('push ' + Lv(1));
  A('call _JSRT_array_spread');
  A('add esp, 16');
  A('.n:');
  A('inc ebx');
  A('jmp .l');
  A('.d:');
  A('mov eax, ' + Lv(1));
  A('mov edx, $ARR');
  A('jmp .ret');
  ArrEnd;

  { join(separateur) et toString() }
  ArrBegin('_JSRT_am_join', 0);
  A('cmp dword ptr [ebp+12], 0');
  A('je .dflt');
  A('cmp dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + '], $UNDEF');
  A('je .dflt');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('jmp .go');
  A('.dflt:');
  A('mov eax, offset ' + RtStr(','));
  A('.go:');
  A('push eax');
  A('push esi');
  A('call _JSRT_arr_join');
  A('add esp, 8');
  A('jmp .ret');
  ArrEnd;

  { fill(valeur, debut, fin) }
  ArrBegin('_JSRT_am_fill', 3);
  MArgInt(1, '0');
  A('push dword ptr [esi+$ARR_LEN]');
  A('push eax');
  A('call _JSRT_relidx');
  A('add esp, 8');
  A('mov ebx, eax');
  MArgInt(2, '2147483647');
  A('push dword ptr [esi+$ARR_LEN]');
  A('push eax');
  A('call _JSRT_relidx');
  A('add esp, 8');
  A('mov ' + Lv(1) + ', eax');
  ArgToLocals(0, 2, 3);
  A('.l:');
  A('cmp ebx, ' + Lv(1));
  A('jge .d');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('mov ecx, ' + Lv(2));
  A('mov dword ptr [eax], ecx');
  A('mov ecx, ' + Lv(3));
  A('mov dword ptr [eax+4], ecx');
  A('inc ebx');
  A('jmp .l');
  A('.d:');
  A('mov eax, esi');
  A('mov edx, $ARR');
  A('jmp .ret');
  ArrEnd;
End;

{ Tableau(n) / Array(a, b, c) et Array.isArray }
Procedure RtArrayCtor;
Begin
  A('proc _JSRT_Array_call');
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('cmp dword ptr [ebp+12], 1');
  A('jne .list');
  A('cmp dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + '], $INT');
  A('jne .list');
  A('call _JSRT_array_new');
  A('mov ebx, eax');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('push ebx');
  A('call _JSRT_arr_setlen');
  A('add esp, 8');
  A('mov eax, ebx');
  A('mov edx, $ARR');
  A('jmp .out');
  A('.list:');
  A('push dword ptr [ebp+12]');
  A('lea eax, [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('push eax');
  A('call _JSRT_arr_from');
  A('add esp, 8');
  A('.out:');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');

  A('proc _JSRT_Array_isArray');
  A('push ebp');
  A('mov ebp, esp');
  A('xor eax, eax');
  A('cmp dword ptr [ebp+12], 1');
  A('jb .r');
  A('cmp dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + '], $ARR');
  A('jne .r');
  A('mov eax, 1');
  A('.r:');
  A('mov edx, $BOOL');
  A('leave');
  A('ret');
  A('endp');
End;

{ String.split(separateur) }
Procedure RtStringSplit;
Begin
  MethBegin('_JSRT_sm_split');
  A('sub esp, 8');
  A('call _JSRT_array_new');
  A('push eax');
  A('cmp dword ptr [ebp+12], 1');
  A('jb .whole');
  A('cmp dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + '], $UNDEF');
  A('je .whole');
  MArgStr(0, 'edi');
  A('pop ebx');
  A('mov ecx, dword ptr [edi+$STR_LEN]');
  A('test ecx, ecx');
  A('jz .chars');
  A('mov dword ptr [ebp-16], 0');
  A('.find:');
  A('push dword ptr [ebp-16]');
  A('push edi');
  A('push esi');
  A('call _JSRT_str_index');
  A('add esp, 12');
  A('cmp eax, -1');
  A('je .last');
  A('mov dword ptr [ebp-20], eax');
  A('push eax');
  A('push dword ptr [ebp-16]');
  A('push esi');
  A('call _JSRT_str_sub');
  A('add esp, 12');
  PushStrToArr('ebx');
  A('mov eax, dword ptr [ebp-20]');
  A('add eax, dword ptr [edi+$STR_LEN]');
  A('mov dword ptr [ebp-16], eax');
  A('jmp .find');
  A('.last:');
  A('push dword ptr [esi+$STR_LEN]');
  A('push dword ptr [ebp-16]');
  A('push esi');
  A('call _JSRT_str_sub');
  A('add esp, 12');
  PushStrToArr('ebx');
  A('jmp .done');
  A('.chars:');
  A('mov dword ptr [ebp-16], 0');
  A('.cl:');
  A('mov ecx, dword ptr [ebp-16]');
  A('cmp ecx, dword ptr [esi+$STR_LEN]');
  A('jae .done');
  A('movzx eax, byte ptr [esi+ecx+$STR_DATA]');
  A('push eax');
  A('call _JSRT_u8len');
  A('add esp, 4');
  A('mov ecx, dword ptr [ebp-16]');
  A('add eax, ecx');
  A('cmp eax, dword ptr [esi+$STR_LEN]');
  A('jbe .cn');
  A('mov eax, dword ptr [esi+$STR_LEN]');
  A('.cn:');
  A('mov dword ptr [ebp-16], eax');
  A('push eax');
  A('push ecx');
  A('push esi');
  A('call _JSRT_str_sub');
  A('add esp, 12');
  PushStrToArr('ebx');
  A('jmp .cl');
  A('.whole:');
  A('pop ebx');
  A('mov eax, esi');
  PushStrToArr('ebx');
  A('.done:');
  A('mov eax, ebx');
  A('mov edx, $ARR');
  A('add esp, 8');
  A('jmp .ret');
  MethEnd;
End;

{ Fonctions et valeurs de base : truthy, typeof, fonctions, cellules. }
Procedure RtBasics;
Begin
  A('proc _JSRT_truthy');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov edx, dword ptr [ebp+12]');
  A('cmp edx, $INT');
  A('je .iv');
  A('cmp edx, $BOOL');
  A('je .iv');
  A('cmp edx, $UNDEF');
  A('je .f');
  A('cmp edx, $NULL');
  A('je .f');
  A('cmp edx, $INT');
  A('jb .dbl');
  A('cmp edx, $STR');
  A('jne .t');
  A('cmp dword ptr [eax+$STR_LEN], 0');
  A('je .f');
  A('.t:');
  A('mov eax, 1');
  A('leave');
  A('ret');
  A('.iv:');
  A('test eax, eax');
  A('jz .f');
  A('mov eax, 1');
  A('leave');
  A('ret');
  A('.dbl:');
  A('mov ecx, edx');
  A('and ecx, 0x7FFFFFFF');
  A('or ecx, eax');
  A('jz .f');
  A('mov ecx, edx');
  A('and ecx, 0x7FF00000');
  A('cmp ecx, 0x7FF00000');
  A('jne .t');
  A('mov ecx, edx');
  A('and ecx, 0xFFFFF');
  A('or ecx, eax');
  A('jnz .f');
  A('jmp .t');
  A('.f:');
  A('xor eax, eax');
  A('leave');
  A('ret');
  A('endp');

  A('proc _JSRT_typeof');
  A('push ebp');
  A('mov ebp, esp');
  A('mov edx, dword ptr [ebp+12]');
  A('cmp edx, $INT');
  A('jbe .num');
  A('cmp edx, $STR');
  A('je .string');
  A('cmp edx, $BOOL');
  A('je .boolean');
  A('cmp edx, $UNDEF');
  A('je .undefined');
  A('cmp edx, $FN');
  A('je .function');
  A('mov eax, offset ' + RtStr('object'));
  A('jmp .r');
  A('.num:');
  A('mov eax, offset ' + RtStr('number'));
  A('jmp .r');
  A('.string:');
  A('mov eax, offset ' + RtStr('string'));
  A('jmp .r');
  A('.boolean:');
  A('mov eax, offset ' + RtStr('boolean'));
  A('jmp .r');
  A('.undefined:');
  A('mov eax, offset ' + RtStr('undefined'));
  A('jmp .r');
  A('.function:');
  A('mov eax, offset ' + RtStr('function'));
  A('.r:');
  A('mov edx, $STR');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_new_function(descripteur, code, environnement, this) }
  A('proc _JSRT_new_function');
  A('push ebp');
  A('mov ebp, esp');
  A('push ' + IntToStr(RT_FN_SIZE));
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov byte ptr [eax], $OK_FUNCTION');
  A('mov ecx, dword ptr [ebp+8]');
  A('mov dword ptr [eax+$FN_DESC], ecx');
  A('mov ecx, dword ptr [ebp+12]');
  A('mov dword ptr [eax+$FN_CODE], ecx');
  A('mov ecx, dword ptr [ebp+16]');
  A('mov dword ptr [eax+$FN_ENV], ecx');
  A('mov ecx, dword ptr [ebp+20]');
  A('mov dword ptr [eax+$FN_THIS], ecx');
  A('mov ecx, dword ptr [ebp+24]');
  A('mov dword ptr [eax+$FN_THIS+4], ecx');
  A('mov edx, $FN');
  A('leave');
  A('ret');
  A('endp');

  A('proc _JSRT_new_env');
  A('push ebp');
  A('mov ebp, esp');
  A('mov ecx, dword ptr [ebp+8]');
  A('shl ecx, 2');
  A('add ecx, $ENV_CELLS');
  A('push ecx');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov byte ptr [eax], $OK_ENV');
  A('mov ecx, dword ptr [ebp+8]');
  A('mov dword ptr [eax+8], ecx');
  A('leave');
  A('ret');
  A('endp');

  A('proc _JSRT_new_cell');
  A('push ebp');
  A('mov ebp, esp');
  A('push ' + IntToStr(RT_CELL_SIZE));
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov byte ptr [eax], $OK_CELL');
  A('mov ecx, dword ptr [ebp+8]');
  A('mov dword ptr [eax+$CELL_VALUE+4], ecx');
  A('leave');
  A('ret');
  A('endp');

  A('proc _JSRT_cell_copy');
  A('push ebp');
  A('mov ebp, esp');
  A('push ' + IntToStr(RT_CELL_SIZE));
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov byte ptr [eax], $OK_CELL');
  A('mov ecx, dword ptr [ebp+8]');
  A('mov edx, dword ptr [ecx+$CELL_VALUE]');
  A('mov dword ptr [eax+$CELL_VALUE], edx');
  A('mov edx, dword ptr [ecx+$CELL_VALUE+4]');
  A('mov dword ptr [eax+$CELL_VALUE+4], edx');
  A('leave');
  A('ret');
  A('endp');

End;

Procedure RtArrays;
Begin
  A('proc _JSRT_process_exit');
  A('push ebp');
  A('mov ebp, esp');
  A('xor eax, eax');
  A('cmp dword ptr [ebp+12], 1');
  A('jb .go');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('call _JSRT_toint32');
  A('add esp, 8');
  A('.go:');
  A('push eax');
  A('call dword ptr [__imp__ExitProcess@4]');
  A('leave');
  A('ret');
  A('endp');
  RtArrayCore;
  RtArrayIter;
  RtArrayCallbacks;
  RtArrayMethods;
  RtArrayCtor;
  RtStringSplit;
  RtBasics;
End;

{ Prototype des tableaux et globale Array. }
Procedure RtArrayProtoMethods;
  Procedure M(Const name, code: TString; nparams: LongInt);
  Begin
    BoAdd(name, RtFuncObj(name, code, nparams), RT_T_FUNCTION);
  End;
Begin
  M('push', '_JSRT_am_push', 1);
  M('pop', '_JSRT_am_pop', 0);
  M('shift', '_JSRT_am_shift', 0);
  M('unshift', '_JSRT_am_unshift', 1);
  M('indexOf', '_JSRT_am_indexOf', 1);
  M('lastIndexOf', '_JSRT_am_lastIndexOf', 1);
  M('includes', '_JSRT_am_includes', 1);
  M('reverse', '_JSRT_am_reverse', 0);
  M('sort', '_JSRT_am_sort', 1);
  M('forEach', '_JSRT_am_forEach', 1);
  M('map', '_JSRT_am_map', 1);
  M('filter', '_JSRT_am_filter', 1);
  M('some', '_JSRT_am_some', 1);
  M('every', '_JSRT_am_every', 1);
  M('find', '_JSRT_am_find', 1);
  M('findIndex', '_JSRT_am_findIndex', 1);
  M('reduce', '_JSRT_am_reduce', 2);
  M('slice', '_JSRT_am_slice', 2);
  M('splice', '_JSRT_am_splice', 2);
  M('concat', '_JSRT_am_concat', 1);
  M('join', '_JSRT_am_join', 1);
  M('toString', '_JSRT_am_join', 0);
  M('fill', '_JSRT_am_fill', 1);
End;

Procedure RtArrayGlobals;
Var
  f_is, props, f_arr, f_exit: LongInt;
Begin
  { process.exit(code) : le reste de process vient avec le TODO 21 }
  f_exit := RtFuncObj('exit', '_JSRT_process_exit', 1);
  BoReset;
  BoAdd('exit', f_exit, RT_T_FUNCTION);
  RtGlobal('process', BoFinish('_JSNO_process', 0), RT_T_OBJECT);
  f_is := RtFuncObj('isArray', '_JSRT_Array_isArray', 1);
  BoReset;
  BoAdd('isArray', f_is, RT_T_FUNCTION);
  BoAdd('prototype', DsymFind(asm_ctx^, '_JSNO_array_proto'), RT_T_OBJECT);
  props := BoFinish('_JSNO_Array_props', 0);
  f_arr := RtFuncObjP('Array', '_JSRT_Array_call', 1, props);
  RtGlobal('Array', f_arr, RT_T_FUNCTION);
End;

{ ---- Objets, proprietes et prototypes (TODO 16) ----

  Objet : en-tete (8), prototype +8, tableau des proprietes +12, nombre
  +16, capacite +20, classe +24, index de hachage +28. Propriete (16
  octets) : cle +0 (pointeur de chaine), drapeaux +4, valeur +8. Les
  proprietes restent dans l'ordre d'insertion ; au-dela de 8 proprietes
  un index de hachage (adressage ouvert, indices+1) accelere la
  recherche. Drapeaux : 1 non enumerable, 2 accesseur (la valeur est
  alors un enregistrement getter, setter), 4 lecture seule. Drapeaux
  d'en-tete : 1 statique, 2 gele, 4 tableau de proprietes en lecture
  seule (copie au premier changement). }

Procedure FBegin(Const code: TString; nloc: LongInt);
Begin
  A('proc ' + code);
  A('push ebp');
  A('mov ebp, esp');
  A('push ebx');
  A('push esi');
  A('push edi');
  If nloc > 0 Then
    A('sub esp, ' + IntToStr(4 * nloc));
End;

Procedure FEnd;
Begin
  A('.ret:');
  A('mov esp, ebp');
  A('sub esp, 12');
  A('pop edi');
  A('pop esi');
  A('pop ebx');
  A('pop ebp');
  A('ret');
  A('endp');
End;

{ Ajoute (valeur hi, lo ; drapeau) au tableau dont le pointeur est dans loc. }
Procedure PushToArrLocal(Const hi, lo, arr: TString);
Begin
  A('push ' + hi);
  A('push ' + lo);
  A('push $ARR');
  A('push ' + arr);
  A('call _JSRT_array_push');
  A('add esp, 16');
End;

Procedure RtObjCore;
Begin
  { _JSRT_str_hash(chaine) -> FNV-1a 32 bits, mis en cache }
  A('proc _JSRT_str_hash');
  A('push ebp');
  A('mov ebp, esp');
  A('mov edx, dword ptr [ebp+8]');
  A('mov eax, dword ptr [edx+$STR_HASH]');
  A('test eax, eax');
  A('jnz .quick');
  A('push ebx');
  A('push esi');
  A('mov eax, 0x811C9DC5');
  A('mov ecx, dword ptr [edx+$STR_LEN]');
  A('lea esi, [edx+$STR_DATA]');
  A('mov edx, 16777619');
  A('.l:');
  A('test ecx, ecx');
  A('jz .d');
  A('movzx ebx, byte ptr [esi]');
  A('xor eax, ebx');
  A('imul eax, edx');
  A('inc esi');
  A('dec ecx');
  A('jmp .l');
  A('.d:');
  A('mov edx, dword ptr [ebp+8]');
  A('movzx ecx, byte ptr [edx+2]');
  A('test ecx, 1');
  A('jnz .nostore');
  A('mov dword ptr [edx+$STR_HASH], eax');
  A('.nostore:');
  A('pop esi');
  A('pop ebx');
  A('.quick:');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_obj_new_proto(prototype) -> pointeur d'objet vide }
  A('proc _JSRT_obj_new_proto');
  A('push ebp');
  A('mov ebp, esp');
  A('push ' + IntToStr(RT_OBJ_SIZE));
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov byte ptr [eax], $OK_OBJECT');
  A('mov ecx, dword ptr [ebp+8]');
  A('mov dword ptr [eax+$OBJ_PROTO], ecx');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_obj_new() -> objet vide (prototype Object.prototype) }
  A('proc _JSRT_obj_new');
  A('push ebp');
  A('mov ebp, esp');
  A('push offset _JSNO_object_proto');
  A('call _JSRT_obj_new_proto');
  A('add esp, 4');
  A('mov edx, $OBJ');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_obj_own(obj) : rend le tableau de proprietes modifiable }
  A('proc _JSRT_obj_own');
  A('push ebp');
  A('mov ebp, esp');
  A('push esi');
  A('push edi');
  A('mov esi, dword ptr [ebp+8]');
  A('movzx ecx, byte ptr [esi+2]');
  A('test ecx, 4');
  A('jz .ret');
  A('mov eax, dword ptr [esi+$OBJ_COUNT]');
  A('cmp eax, 4');
  A('jae .c');
  A('mov eax, 4');
  A('.c:');
  A('push eax');
  A('shl eax, 4');
  A('push eax');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('pop ecx');
  A('mov edi, eax');
  A('mov dword ptr [esi+$OBJ_CAP], ecx');
  A('mov ecx, dword ptr [esi+$OBJ_COUNT]');
  A('shl ecx, 4');
  A('push ecx');
  A('push dword ptr [esi+$OBJ_PROPS]');
  A('push edi');
  A('call _JSRT_memmove');
  A('add esp, 12');
  A('mov dword ptr [esi+$OBJ_PROPS], edi');
  A('movzx ecx, byte ptr [esi+2]');
  A('and ecx, -5');
  A('mov byte ptr [esi+2], cl');
  A('.ret:');
  A('pop edi');
  A('pop esi');
  A('pop ebp');
  A('ret');
  A('endp');

  { _JSRT_idx_insert(obj, i) : inscrit la propriete i dans l'index }
  FBegin('_JSRT_idx_insert', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('mov edi, dword ptr [ebp+12]');
  A('mov eax, edi');
  A('shl eax, 4');
  A('add eax, dword ptr [esi+$OBJ_PROPS]');
  A('push dword ptr [eax]');
  A('call _JSRT_str_hash');
  A('add esp, 4');
  A('mov ecx, dword ptr [esi+' + IntToStr(RT_OBJ_INDEX) + ']');
  A('mov edx, dword ptr [ecx]');
  A('and eax, edx');
  A('.p:');
  A('mov ebx, eax');
  A('shl ebx, 2');
  A('add ebx, ecx');
  A('cmp dword ptr [ebx+4], 0');
  A('je .put');
  A('inc eax');
  A('and eax, edx');
  A('jmp .p');
  A('.put:');
  A('lea eax, [edi+1]');
  A('mov dword ptr [ebx+4], eax');
  FEnd;

  { _JSRT_obj_reindex(obj) : reconstruit l'index de hachage }
  FBegin('_JSRT_obj_reindex', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [esi+$OBJ_CAP]');
  A('add ecx, ecx');
  A('mov ebx, 16');
  A('.s:');
  A('cmp ebx, ecx');
  A('jae .g');
  A('add ebx, ebx');
  A('jmp .s');
  A('.g:');
  A('mov eax, ebx');
  A('shl eax, 2');
  A('add eax, 4');
  A('push eax');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov edx, ebx');
  A('dec edx');
  A('mov dword ptr [eax], edx');
  A('mov dword ptr [esi+' + IntToStr(RT_OBJ_INDEX) + '], eax');
  A('xor edi, edi');
  A('.l:');
  A('cmp edi, dword ptr [esi+$OBJ_COUNT]');
  A('jae .ret');
  A('push edi');
  A('push esi');
  A('call _JSRT_idx_insert');
  A('add esp, 8');
  A('inc edi');
  A('jmp .l');
  FEnd;

  { _JSRT_prop_find(obj, cle) -> propriete propre ou 0 }
  FBegin('_JSRT_prop_find', 2);
  A('mov esi, dword ptr [ebp+8]');
  A('mov edi, dword ptr [ebp+12]');
  A('push edi');
  A('call _JSRT_str_hash');
  A('add esp, 4');
  A('mov ebx, eax');
  A('mov ecx, dword ptr [esi+' + IntToStr(RT_OBJ_INDEX) + ']');
  A('test ecx, ecx');
  A('jnz .hashed');
  A('mov ecx, dword ptr [esi+$OBJ_COUNT]');
  A('mov edx, dword ptr [esi+$OBJ_PROPS]');
  A('.lin:');
  A('test ecx, ecx');
  A('jz .none');
  A('mov eax, dword ptr [edx]');
  A('cmp eax, edi');
  A('je .yes');
  A('cmp ebx, dword ptr [eax+$STR_HASH]');
  A('jne .nx');
  A('push ecx');
  A('push edx');
  A('push edi');
  A('push eax');
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('pop edx');
  A('pop ecx');
  A('test eax, eax');
  A('jnz .yes');
  A('.nx:');
  A('add edx, ' + IntToStr(RT_PROP_SIZE));
  A('dec ecx');
  A('jmp .lin');
  A('.yes:');
  A('mov eax, edx');
  A('jmp .ret');
  A('.none:');
  A('xor eax, eax');
  A('jmp .ret');
  A('.hashed:');
  A('mov edx, dword ptr [ecx]');
  A('mov eax, ebx');
  A('and eax, edx');
  A('mov ' + Lv(1) + ', eax');
  A('.hl:');
  A('mov eax, ' + Lv(1));
  A('shl eax, 2');
  A('add eax, dword ptr [esi+' + IntToStr(RT_OBJ_INDEX) + ']');
  A('mov eax, dword ptr [eax+4]');
  A('test eax, eax');
  A('jz .none');
  A('dec eax');
  A('shl eax, 4');
  A('add eax, dword ptr [esi+$OBJ_PROPS]');
  A('mov ' + Lv(2) + ', eax');
  A('mov ecx, dword ptr [eax]');
  A('cmp ecx, edi');
  A('je .y2');
  A('cmp ebx, dword ptr [ecx+$STR_HASH]');
  A('jne .hn');
  A('push edi');
  A('push ecx');
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('test eax, eax');
  A('jnz .y2');
  A('.hn:');
  A('mov ecx, dword ptr [esi+' + IntToStr(RT_OBJ_INDEX) + ']');
  A('mov edx, dword ptr [ecx]');
  A('mov eax, ' + Lv(1));
  A('inc eax');
  A('and eax, edx');
  A('mov ' + Lv(1) + ', eax');
  A('jmp .hl');
  A('.y2:');
  A('mov eax, ' + Lv(2));
  FEnd;

  { _JSRT_prop_lookup(obj, cle) -> EAX propriete (chaine de prototypes), EDX proprietaire }
  FBegin('_JSRT_prop_lookup', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('.c:');
  A('test esi, esi');
  A('jz .none');
  A('push dword ptr [ebp+12]');
  A('push esi');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jnz .found');
  A('mov esi, dword ptr [esi+$OBJ_PROTO]');
  A('jmp .c');
  A('.found:');
  A('mov edx, esi');
  A('jmp .ret');
  A('.none:');
  A('xor eax, eax');
  A('xor edx, edx');
  FEnd;

  { _JSRT_call0(fonction, this lo, this hi) / _JSRT_call1(..., arg lo, arg hi) }
  A('proc _JSRT_call0');
  A('push ebp');
  A('mov ebp, esp');
  A('sub esp, 16');
  A('mov eax, dword ptr [ebp+8]');
  A('mov dword ptr [esp], eax');
  A('mov dword ptr [esp+4], 0');
  A('mov eax, dword ptr [ebp+12]');
  A('mov dword ptr [esp+8], eax');
  A('mov eax, dword ptr [ebp+16]');
  A('mov dword ptr [esp+12], eax');
  A('mov eax, dword ptr [ebp+8]');
  A('call dword ptr [eax+$FN_CODE]');
  A('leave');
  A('ret');
  A('endp');
  A('proc _JSRT_call1');
  A('push ebp');
  A('mov ebp, esp');
  A('sub esp, 24');
  A('mov eax, dword ptr [ebp+8]');
  A('mov dword ptr [esp], eax');
  A('mov dword ptr [esp+4], 1');
  A('mov eax, dword ptr [ebp+12]');
  A('mov dword ptr [esp+8], eax');
  A('mov eax, dword ptr [ebp+16]');
  A('mov dword ptr [esp+12], eax');
  A('mov eax, dword ptr [ebp+20]');
  A('mov dword ptr [esp+16], eax');
  A('mov eax, dword ptr [ebp+24]');
  A('mov dword ptr [esp+20], eax');
  A('mov eax, dword ptr [ebp+8]');
  A('call dword ptr [eax+$FN_CODE]');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_prop_get(propriete, recepteur lo, hi) -> valeur (appelle le getter) }
  A('proc _JSRT_prop_get');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [eax+4]');
  A('test ecx, 2');
  A('jnz .acc');
  A('mov edx, dword ptr [eax+12]');
  A('mov eax, dword ptr [eax+8]');
  A('leave');
  A('ret');
  A('.acc:');
  A('mov ecx, dword ptr [eax+8]');
  A('mov eax, dword ptr [ecx]');
  A('test eax, eax');
  A('jz .undef');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push eax');
  A('call _JSRT_call0');
  A('leave');
  A('ret');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_obj_get(recepteur lo, hi, obj, cle) -> valeur ou undefined }
  A('proc _JSRT_obj_get');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_prop_lookup');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .undef');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('push eax');
  A('call _JSRT_prop_get');
  A('leave');
  A('ret');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_obj_lookup(_str)(obj, cle) : EDX:EAX valeur brute, ECX = 1 si trouvee }
  A('proc _JSRT_obj_lookup');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_prop_lookup');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .nf');
  A('mov edx, dword ptr [eax+12]');
  A('mov eax, dword ptr [eax+8]');
  A('mov ecx, 1');
  A('leave');
  A('ret');
  A('.nf:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('xor ecx, ecx');
  A('leave');
  A('ret');
  A('endp');
  A('proc _JSRT_obj_lookup_str');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_obj_lookup');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_obj_add(obj, cle, drapeaux, valeur lo, valeur hi) }
  FBegin('_JSRT_obj_add', 1);
  A('mov esi, dword ptr [ebp+8]');
  A('push esi');
  A('call _JSRT_obj_own');
  A('add esp, 4');
  A('push dword ptr [ebp+12]');
  A('call _JSRT_str_hash');
  A('add esp, 4');
  A('mov ' + Lv(1) + ', 0');
  A('mov ecx, dword ptr [esi+$OBJ_COUNT]');
  A('cmp ecx, dword ptr [esi+$OBJ_CAP]');
  A('jb .room');
  A('mov ebx, dword ptr [esi+$OBJ_CAP]');
  A('add ebx, ebx');
  A('cmp ebx, 4');
  A('jae .g1');
  A('mov ebx, 4');
  A('.g1:');
  A('mov eax, ebx');
  A('shl eax, 4');
  A('push eax');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov edi, eax');
  A('mov ecx, dword ptr [esi+$OBJ_COUNT]');
  A('shl ecx, 4');
  A('push ecx');
  A('push dword ptr [esi+$OBJ_PROPS]');
  A('push edi');
  A('call _JSRT_memmove');
  A('add esp, 12');
  A('mov dword ptr [esi+$OBJ_PROPS], edi');
  A('mov dword ptr [esi+$OBJ_CAP], ebx');
  A('mov ' + Lv(1) + ', 1');
  A('.room:');
  A('mov ecx, dword ptr [esi+$OBJ_COUNT]');
  A('mov edx, ecx');
  A('shl edx, 4');
  A('add edx, dword ptr [esi+$OBJ_PROPS]');
  A('mov eax, dword ptr [ebp+12]');
  A('mov dword ptr [edx], eax');
  A('mov eax, dword ptr [ebp+16]');
  A('mov edi, dword ptr [ebp+12]');
  A('cmp byte ptr [edi+$STR_DATA], 35');
  A('jne .vis');
  A('or eax, 1');
  A('.vis:');
  A('mov dword ptr [edx+4], eax');
  A('mov eax, dword ptr [ebp+20]');
  A('mov dword ptr [edx+8], eax');
  A('mov eax, dword ptr [ebp+24]');
  A('mov dword ptr [edx+12], eax');
  A('inc ecx');
  A('mov dword ptr [esi+$OBJ_COUNT], ecx');
  A('cmp ecx, 8');
  A('jbe .ret');
  A('cmp ' + Lv(1) + ', 1');
  A('je .build');
  A('cmp dword ptr [esi+' + IntToStr(RT_OBJ_INDEX) + '], 0');
  A('je .build');
  A('dec ecx');
  A('push ecx');
  A('push esi');
  A('call _JSRT_idx_insert');
  A('add esp, 8');
  A('jmp .ret');
  A('.build:');
  A('push esi');
  A('call _JSRT_obj_reindex');
  A('add esp, 4');
  FEnd;

  { _JSRT_obj_remove(obj, cle) -> 1 si supprimee }
  FBegin('_JSRT_obj_remove', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('push esi');
  A('call _JSRT_obj_own');
  A('add esp, 4');
  A('push dword ptr [ebp+12]');
  A('push esi');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .no');
  A('mov edx, eax');
  A('sub edx, dword ptr [esi+$OBJ_PROPS]');
  A('shr edx, 4');
  A('mov ecx, dword ptr [esi+$OBJ_COUNT]');
  A('dec ecx');
  A('mov dword ptr [esi+$OBJ_COUNT], ecx');
  A('sub ecx, edx');
  A('shl ecx, 4');
  A('lea ebx, [eax+16]');
  A('push ecx');
  A('push ebx');
  A('push eax');
  A('call _JSRT_memmove');
  A('add esp, 12');
  A('cmp dword ptr [esi+' + IntToStr(RT_OBJ_INDEX) + '], 0');
  A('je .ok');
  A('cmp dword ptr [esi+$OBJ_COUNT], 8');
  A('ja .re');
  A('mov dword ptr [esi+' + IntToStr(RT_OBJ_INDEX) + '], 0');
  A('jmp .ok');
  A('.re:');
  A('push esi');
  A('call _JSRT_obj_reindex');
  A('add esp, 4');
  A('.ok:');
  A('mov eax, 1');
  A('jmp .ret');
  A('.no:');
  A('xor eax, eax');
  FEnd;

  { _JSRT_obj_define(obj, cle, valeur lo, hi) : propriete de donnee (litteraux) }
  FBegin('_JSRT_obj_define', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('push esi');
  A('call _JSRT_obj_own');
  A('add esp, 4');
  A('push dword ptr [ebp+12]');
  A('push esi');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .add');
  A('mov dword ptr [eax+4], 0');
  A('mov ecx, dword ptr [ebp+16]');
  A('mov dword ptr [eax+8], ecx');
  A('mov ecx, dword ptr [ebp+20]');
  A('mov dword ptr [eax+12], ecx');
  A('jmp .ret');
  A('.add:');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push 0');
  A('push dword ptr [ebp+12]');
  A('push esi');
  A('call _JSRT_obj_add');
  A('add esp, 20');
  FEnd;

  { _JSRT_obj_define_acc(obj, cle, fonction lo, hi, setter) : getter ou setter }
  FBegin('_JSRT_obj_define_acc', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('push esi');
  A('call _JSRT_obj_own');
  A('add esp, 4');
  A('push dword ptr [ebp+12]');
  A('push esi');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .new');
  A('mov ecx, dword ptr [eax+4]');
  A('test ecx, 2');
  A('jnz .have');
  A('mov ebx, eax');
  A('push 8');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov dword ptr [ebx+4], 2');
  A('mov dword ptr [ebx+8], eax');
  A('mov dword ptr [ebx+12], 0');
  A('mov edi, eax');
  A('jmp .store');
  A('.have:');
  A('mov edi, dword ptr [eax+8]');
  A('jmp .store');
  A('.new:');
  A('push 8');
  A('call _JSRT_alloc');
  A('add esp, 4');
  A('mov edi, eax');
  A('push 0');
  A('push edi');
  A('push 2');
  A('push dword ptr [ebp+12]');
  A('push esi');
  A('call _JSRT_obj_add');
  A('add esp, 20');
  A('.store:');
  A('mov eax, dword ptr [ebp+24]');
  A('shl eax, 2');
  A('add eax, edi');
  A('mov ecx, dword ptr [ebp+16]');
  A('mov dword ptr [eax], ecx');
  FEnd;

  { _JSRT_tokey(valeur) -> chaine de la cle de propriete }
  A('proc _JSRT_tokey');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_tostring');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_fn_prototype(fonction) : Fonction.prototype, creee a la demande }
  FBegin('_JSRT_fn_prototype', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('mov eax, dword ptr [esi+$FN_PROPS]');
  A('test eax, eax');
  A('jnz .have');
  A('push offset _JSNO_object_proto');
  A('call _JSRT_obj_new_proto');
  A('add esp, 4');
  A('mov dword ptr [esi+$FN_PROPS], eax');
  A('.have:');
  A('mov edi, eax');
  A('push offset ' + RtStr('prototype'));
  A('push edi');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .mk');
  A('mov edx, dword ptr [eax+12]');
  A('mov eax, dword ptr [eax+8]');
  A('jmp .ret');
  A('.mk:');
  A('call _JSRT_obj_new');
  A('mov ebx, eax');
  A('push $FN');
  A('push esi');
  A('push 1');
  A('push offset ' + RtStr('constructor'));
  A('push ebx');
  A('call _JSRT_obj_add');
  A('add esp, 20');
  A('push $OBJ');
  A('push ebx');
  A('push 1');
  A('push offset ' + RtStr('prototype'));
  A('push edi');
  A('call _JSRT_obj_add');
  A('add esp, 20');
  A('mov eax, ebx');
  A('mov edx, $OBJ');
  FEnd;

  { _JSRT_get_named(recepteur lo, hi, cle) : propriete d'un objet ou d'une fonction }
  FBegin('_JSRT_get_named', 0);
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, $FN');
  A('jne .o');
  A('mov esi, dword ptr [eax+$FN_PROPS]');
  A('test esi, esi');
  A('jz .fnproto');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_prop_lookup');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .fnproto');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('push eax');
  A('call _JSRT_prop_get');
  A('add esp, 12');
  A('jmp .ret');
  A('.fnproto:');
  A('mov eax, dword ptr [ebp+8]');
  A('movzx ecx, byte ptr [eax+2]');
  A('test ecx, 1');
  A('jnz .undef');
  A('push dword ptr [ebp+16]');
  A('push offset ' + RtStr('prototype'));
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .undef');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_fn_prototype');
  A('add esp, 4');
  A('jmp .ret');
  A('.o:');
  A('cmp ecx, $OBJ');
  A('jne .undef');
  A('push dword ptr [ebp+16]');
  A('push eax');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_obj_get');
  A('add esp, 16');
  A('jmp .ret');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  FEnd;

  { _JSRT_obj_set(objet lo, hi, cle, valeur lo, hi) : objet.cle = valeur }
  FBegin('_JSRT_obj_set', 0);
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, $OBJ');
  A('je .obj');
  A('cmp ecx, $FN');
  A('je .fn');
  A('cmp ecx, $UNDEF');
  A('je .bad');
  A('cmp ecx, $NULL');
  A('je .bad');
  A('jmp .done');
  A('.fn:');
  A('mov eax, dword ptr [ebp+8]');
  A('movzx ecx, byte ptr [eax+2]');
  A('test ecx, 1');
  A('jnz .done');
  A('mov esi, dword ptr [eax+$FN_PROPS]');
  A('test esi, esi');
  A('jnz .setobj');
  A('push offset _JSNO_object_proto');
  A('call _JSRT_obj_new_proto');
  A('add esp, 4');
  A('mov esi, eax');
  A('mov ecx, dword ptr [ebp+8]');
  A('mov dword ptr [ecx+$FN_PROPS], eax');
  A('jmp .setobj');
  A('.obj:');
  A('mov esi, dword ptr [ebp+8]');
  A('.setobj:');
  A('movzx ecx, byte ptr [esi+2]');
  A('test ecx, 2');
  A('jnz .done');
  A('push esi');
  A('call _JSRT_obj_own');
  A('add esp, 4');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_prop_lookup');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .newprop');
  A('mov ebx, eax');
  A('mov edi, edx');
  A('mov ecx, dword ptr [ebx+4]');
  A('test ecx, 2');
  A('jnz .acc');
  A('test ecx, 4');
  A('jnz .done');
  A('cmp edi, esi');
  A('jne .newprop');
  A('mov eax, dword ptr [ebp+20]');
  A('mov dword ptr [ebx+8], eax');
  A('mov eax, dword ptr [ebp+24]');
  A('mov dword ptr [ebx+12], eax');
  A('jmp .done');
  A('.acc:');
  A('mov ecx, dword ptr [ebx+8]');
  A('mov eax, dword ptr [ecx+4]');
  A('test eax, eax');
  A('jz .done');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('push eax');
  A('call _JSRT_call1');
  A('add esp, 20');
  A('jmp .done');
  A('.newprop:');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+20]');
  A('push 0');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_obj_add');
  A('add esp, 20');
  A('.done:');
  A('mov eax, dword ptr [ebp+20]');
  A('mov edx, dword ptr [ebp+24]');
  A('jmp .ret');
  A('.bad:');
  A('push offset _JSRT_c_setundef');
  A('call _JSRT_fatal');
  FEnd;

  { _JSRT_obj_set_member(objet, cle, valeur) : cle quelconque }
  A('proc _JSRT_obj_set_member');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push dword ptr [ebp+28]');
  A('push dword ptr [ebp+24]');
  A('push eax');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_obj_set');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_arr_has_str(tableau, chaine) -> 1 si un element chaine est egal }
  FBegin('_JSRT_arr_has_str', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('xor ebx, ebx');
  A('.l:');
  A('cmp ebx, dword ptr [esi+$ARR_LEN]');
  A('jae .no');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('cmp dword ptr [eax+4], $STR');
  A('jne .nx');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [eax]');
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('test eax, eax');
  A('jnz .ret');
  A('.nx:');
  A('inc ebx');
  A('jmp .l');
  A('.no:');
  A('xor eax, eax');
  FEnd;

  { _JSRT_obj_spread(cible, source) : copie les proprietes enumerables propres }
  FBegin('_JSRT_obj_spread', 1);
  A('mov ecx, dword ptr [ebp+20]');
  A('cmp ecx, $OBJ');
  A('je .obj');
  A('cmp ecx, $ARR');
  A('jne .ret');
  A('mov esi, dword ptr [ebp+16]');
  A('xor edi, edi');
  A('.al:');
  A('cmp edi, dword ptr [esi+$ARR_LEN]');
  A('jae .ret');
  A('push edi');
  A('call _JSRT_int_to_str');
  A('add esp, 4');
  A('mov ebx, eax');
  A('push edi');
  A('push esi');
  A('call _JSRT_arr_get');
  A('add esp, 8');
  A('push edx');
  A('push eax');
  A('push ebx');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_obj_define');
  A('add esp, 16');
  A('inc edi');
  A('jmp .al');
  A('.obj:');
  A('mov esi, dword ptr [ebp+16]');
  A('xor edi, edi');
  A('.ol:');
  A('cmp edi, dword ptr [esi+$OBJ_COUNT]');
  A('jae .ret');
  A('mov ebx, edi');
  A('shl ebx, 4');
  A('add ebx, dword ptr [esi+$OBJ_PROPS]');
  A('test dword ptr [ebx+4], 1');
  A('jnz .on');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push ebx');
  A('call _JSRT_prop_get');
  A('add esp, 12');
  A('push edx');
  A('push eax');
  A('push dword ptr [ebx]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_obj_define');
  A('add esp, 16');
  A('.on:');
  A('inc edi');
  A('jmp .ol');
  FEnd;

  { _JSRT_obj_rest(source, cles exclues) : copie sans les cles exclues }
  FBegin('_JSRT_obj_rest', 0);
  A('call _JSRT_obj_new');
  A('mov ebx, eax');
  A('cmp dword ptr [ebp+12], $OBJ');
  A('jne .done');
  A('mov esi, dword ptr [ebp+8]');
  A('xor edi, edi');
  A('.l:');
  A('cmp edi, dword ptr [esi+$OBJ_COUNT]');
  A('jae .done');
  A('mov eax, edi');
  A('shl eax, 4');
  A('add eax, dword ptr [esi+$OBJ_PROPS]');
  A('test dword ptr [eax+4], 1');
  A('jnz .nx');
  A('push eax');
  A('push dword ptr [eax]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_arr_has_str');
  A('add esp, 8');
  A('mov ecx, eax');
  A('pop eax');
  A('test ecx, ecx');
  A('jnz .nx');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('push eax');
  A('call _JSRT_prop_get');
  A('add esp, 12');
  A('mov ecx, edi');
  A('shl ecx, 4');
  A('add ecx, dword ptr [esi+$OBJ_PROPS]');
  A('push edx');
  A('push eax');
  A('push dword ptr [ecx]');
  A('push ebx');
  A('call _JSRT_obj_define');
  A('add esp, 16');
  A('.nx:');
  A('inc edi');
  A('jmp .l');
  A('.done:');
  A('mov eax, ebx');
  A('mov edx, $OBJ');
  FEnd;

  { _JSRT_delete_prop(objet, cle) : delete objet.cle }
  FBegin('_JSRT_delete_prop', 0);
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, $OBJ');
  A('je .obj');
  A('cmp ecx, $ARR');
  A('jne .true');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_str_to_idx');
  A('add esp, 4');
  A('cmp eax, -1');
  A('je .true');
  A('mov esi, dword ptr [ebp+8]');
  A('cmp eax, dword ptr [esi+$ARR_LEN]');
  A('jae .true');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('mov dword ptr [eax], 0');
  A('mov dword ptr [eax+4], $UNDEF');
  A('jmp .true');
  A('.obj:');
  A('mov esi, dword ptr [ebp+8]');
  A('movzx ecx, byte ptr [esi+2]');
  A('test ecx, 2');
  A('jnz .false');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_obj_remove');
  A('add esp, 8');
  A('.true:');
  A('mov eax, 1');
  A('mov edx, $BOOL');
  A('jmp .ret');
  A('.false:');
  A('xor eax, eax');
  A('mov edx, $BOOL');
  FEnd;

  { _JSRT_delete_member(objet, cle) }
  A('proc _JSRT_delete_member');
  A('push ebp');
  A('mov ebp, esp');
  A('cmp dword ptr [ebp+12], $ARR');
  A('jne .gen');
  A('cmp dword ptr [ebp+20], $INT');
  A('jne .gen');
  A('mov eax, dword ptr [ebp+16]');
  A('mov ecx, dword ptr [ebp+8]');
  A('cmp eax, dword ptr [ecx+$ARR_LEN]');
  A('jae .true');
  A('shl eax, 3');
  A('add eax, dword ptr [ecx+$ARR_ELEMS]');
  A('mov dword ptr [eax], 0');
  A('mov dword ptr [eax+4], $UNDEF');
  A('.true:');
  A('mov eax, 1');
  A('mov edx, $BOOL');
  A('leave');
  A('ret');
  A('.gen:');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push eax');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_delete_prop');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_has_own(valeur lo, hi, cle chaine) -> 0 ou 1 }
  FBegin('_JSRT_has_own', 0);
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, $OBJ');
  A('je .obj');
  A('cmp ecx, $FN');
  A('je .fn');
  A('cmp ecx, $ARR');
  A('je .arr');
  A('cmp ecx, $STR');
  A('je .str');
  A('xor eax, eax');
  A('jmp .ret');
  A('.fn:');
  A('mov esi, dword ptr [ebp+8]');
  A('mov esi, dword ptr [esi+$FN_PROPS]');
  A('test esi, esi');
  A('jz .no');
  A('jmp .look');
  A('.obj:');
  A('mov esi, dword ptr [ebp+8]');
  A('.look:');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .no');
  A('mov eax, 1');
  A('jmp .ret');
  A('.arr:');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ebx, dword ptr [esi+$ARR_LEN]');
  A('jmp .idx');
  A('.str:');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ebx, dword ptr [esi+$STR_LEN]');
  A('.idx:');
  A('push dword ptr [ebp+16]');
  A('push offset ' + RtStr('length'));
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('test eax, eax');
  A('jnz .ret');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_str_to_idx');
  A('add esp, 4');
  A('cmp eax, -1');
  A('je .no');
  A('cmp eax, ebx');
  A('jae .no');
  A('mov eax, 1');
  A('jmp .ret');
  A('.no:');
  A('xor eax, eax');
  FEnd;

End;

{ Acces aux proprietes, enumeration, operateurs in / instanceof, new. }

{ Une entree de _JSRT_ownkeys : kind 0 = propriete EBX, kind 1 = indice EDI
  (cle texte dans le local 3). Selon le mode : cles, valeurs ou paires. }
Procedure EmitOwnEntry(kind: LongInt);
Var
  keyop, valcode1, valcode2, valcode3, valcode4, l1, l2, done: TString;
Begin
  If kind = 0 Then
    keyop := 'dword ptr [ebx]'
  Else
    keyop := Lv(3);
  l1 := U('m');
  l2 := U('e');
  done := U('n');
  A('mov eax, dword ptr [ebp+16]');
  A('cmp eax, 1');
  A('je ' + l1);
  A('cmp eax, 2');
  A('je ' + l2);
  PushToArrLocal('$STR', keyop, Lv(1));
  A('jmp ' + done);
  A(l1 + ':');
  If kind = 0 Then
    Begin
      A('push dword ptr [ebp+12]');
      A('push dword ptr [ebp+8]');
      A('push ebx');
      A('call _JSRT_prop_get');
    End
  Else
    Begin
      A('push edi');
      A('push dword ptr [ebp+12]');
      A('push dword ptr [ebp+8]');
      A('call _JSRT_get_index');
    End;
  A('add esp, 12');
  A('push edx');
  A('push eax');
  A('push $ARR');
  A('push ' + Lv(1));
  A('call _JSRT_array_push');
  A('add esp, 16');
  A('jmp ' + done);
  A(l2 + ':');
  If kind = 0 Then
    Begin
      A('push dword ptr [ebp+12]');
      A('push dword ptr [ebp+8]');
      A('push ebx');
      A('call _JSRT_prop_get');
    End
  Else
    Begin
      A('push edi');
      A('push dword ptr [ebp+12]');
      A('push dword ptr [ebp+8]');
      A('call _JSRT_get_index');
    End;
  A('add esp, 12');
  A('push edx');
  A('push eax');
  A('call _JSRT_array_new');
  A('mov ' + Lv(2) + ', eax');
  PushToArrLocal('$STR', keyop, Lv(2));
  A('pop eax');
  A('pop edx');
  A('push edx');
  A('push eax');
  A('push $ARR');
  A('push ' + Lv(2));
  A('call _JSRT_array_push');
  A('add esp, 16');
  PushToArrLocal('$ARR', Lv(2), Lv(1));
  A(done + ':');
End;

Procedure RtObjAccess;
Begin
  { _JSRT_in(cle, objet) : cle in objet }
  FBegin('_JSRT_in', 0);
  A('mov ecx, dword ptr [ebp+20]');
  A('cmp ecx, $OBJ');
  A('je .obj');
  A('cmp ecx, $FN');
  A('je .fn');
  A('cmp ecx, $ARR');
  A('je .arr');
  A('push offset _JSRT_c_type');
  A('call _JSRT_fatal');
  A('.fn:');
  A('mov esi, dword ptr [ebp+16]');
  A('mov esi, dword ptr [esi+$FN_PROPS]');
  A('test esi, esi');
  A('jz .no');
  A('jmp .look');
  A('.obj:');
  A('mov esi, dword ptr [ebp+16]');
  A('.look:');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push eax');
  A('push esi');
  A('call _JSRT_prop_lookup');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .no');
  A('jmp .yes');
  A('.arr:');
  A('cmp dword ptr [ebp+12], $INT');
  A('jne .arrname');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+16]');
  A('cmp eax, dword ptr [ecx+$ARR_LEN]');
  A('jae .no');
  A('jmp .yes');
  A('.arrname:');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('mov ebx, eax');
  A('push ebx');
  A('push offset ' + RtStr('length'));
  A('call _JSRT_str_equal');
  A('add esp, 8');
  A('test eax, eax');
  A('jnz .yes');
  A('push ebx');
  A('call _JSRT_str_to_idx');
  A('add esp, 4');
  A('cmp eax, -1');
  A('je .proto');
  A('mov ecx, dword ptr [ebp+16]');
  A('cmp eax, dword ptr [ecx+$ARR_LEN]');
  A('jb .yes');
  A('.proto:');
  A('push ebx');
  A('push offset _JSNO_array_proto');
  A('call _JSRT_prop_lookup');
  A('add esp, 8');
  A('test eax, eax');
  A('jnz .yes');
  A('.no:');
  A('xor eax, eax');
  A('mov edx, $BOOL');
  A('jmp .ret');
  A('.yes:');
  A('mov eax, 1');
  A('mov edx, $BOOL');
  FEnd;

  { _JSRT_instanceof(valeur, fonction) }
  FBegin('_JSRT_instanceof', 0);
  A('cmp dword ptr [ebp+20], $FN');
  A('jne .bad');
  A('push offset ' + RtStr('prototype'));
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_get_named');
  A('add esp, 12');
  A('cmp edx, $OBJ');
  A('jne .no');
  A('mov ebx, eax');
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, $OBJ');
  A('je .o');
  A('cmp ecx, $ARR');
  A('je .a');
  A('jmp .no');
  A('.o:');
  A('mov esi, dword ptr [ebp+8]');
  A('mov esi, dword ptr [esi+$OBJ_PROTO]');
  A('jmp .walk');
  A('.a:');
  A('mov esi, offset _JSNO_array_proto');
  A('.walk:');
  A('test esi, esi');
  A('jz .no');
  A('cmp esi, ebx');
  A('je .yes');
  A('mov esi, dword ptr [esi+$OBJ_PROTO]');
  A('jmp .walk');
  A('.bad:');
  A('push offset _JSRT_c_type');
  A('call _JSRT_fatal');
  A('.no:');
  A('xor eax, eax');
  A('mov edx, $BOOL');
  A('jmp .ret');
  A('.yes:');
  A('mov eax, 1');
  A('mov edx, $BOOL');
  FEnd;

  { _JSRT_new_this(fonction) : this d'un appel new }
  FBegin('_JSRT_new_this', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [esi+$FN_DESC]');
  A('mov edx, dword ptr [ecx+8]');
  A('test edx, 32768');
  A('jnz .native');
  A('push offset ' + RtStr('prototype'));
  A('push $FN');
  A('push esi');
  A('call _JSRT_get_named');
  A('add esp, 12');
  A('cmp edx, $OBJ');
  A('jne .dflt');
  A('push eax');
  A('call _JSRT_obj_new_proto');
  A('add esp, 4');
  A('jmp .o');
  A('.dflt:');
  A('push offset _JSNO_object_proto');
  A('call _JSRT_obj_new_proto');
  A('add esp, 4');
  A('.o:');
  A('mov edx, $OBJ');
  A('jmp .ret');
  A('.native:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  FEnd;

  { _JSRT_get_prop(objet, atome) : objet.nom }
  A('proc _JSRT_get_prop');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, $OBJ');
  A('je .named');
  A('cmp ecx, $STR');
  A('je .str');
  A('cmp ecx, $FN');
  A('je .named');
  A('cmp ecx, $ARR');
  A('je .arr');
  A('cmp ecx, $UNDEF');
  A('je .bad');
  A('cmp ecx, $NULL');
  A('je .bad');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('leave');
  A('ret');
  A('.named:');
  A('push dword ptr [ebp+16]');
  A('push ecx');
  A('push eax');
  A('call _JSRT_get_named');
  A('leave');
  A('ret');
  A('.str:');
  A('mov edx, dword ptr [ebp+16]');
  A('mov ecx, offset ' + RtStr('length'));
  A('cmp edx, ecx');
  A('jne .strproto');
  A('mov eax, dword ptr [eax+$STR_LEN]');
  A('mov edx, $INT');
  A('leave');
  A('ret');
  A('.strproto:');
  A('push edx');
  A('push offset _JSNO_string_proto');
  A('call _JSRT_obj_lookup');
  A('add esp, 8');
  A('leave');
  A('ret');
  A('.arr:');
  A('mov edx, dword ptr [ebp+16]');
  A('mov ecx, offset ' + RtStr('length'));
  A('cmp edx, ecx');
  A('jne .arrproto');
  A('mov eax, dword ptr [eax+$ARR_LEN]');
  A('mov edx, $INT');
  A('leave');
  A('ret');
  A('.arrproto:');
  A('push edx');
  A('push offset _JSNO_array_proto');
  A('call _JSRT_obj_lookup');
  A('add esp, 8');
  A('leave');
  A('ret');
  A('.bad:');
  A('push offset _JSRT_c_read');
  A('call _JSRT_fatal');
  A('endp');

  { _JSRT_get_member(objet, cle) : objet[cle] }
  A('proc _JSRT_get_member');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('mov edx, dword ptr [ebp+20]');
  A('cmp ecx, $UNDEF');
  A('je .bad');
  A('cmp ecx, $NULL');
  A('je .bad');
  A('cmp ecx, $STR');
  A('jne .notstr');
  A('cmp edx, $INT');
  A('je .stridx');
  A('cmp edx, $STR');
  A('jne .undef');
  A('push dword ptr [ebp+16]');
  A('push eax');
  A('call _JSRT_str_get_prop');
  A('add esp, 8');
  A('leave');
  A('ret');
  A('.stridx:');
  A('push dword ptr [ebp+16]');
  A('push eax');
  A('call _JSRT_str_char_at');
  A('add esp, 8');
  A('leave');
  A('ret');
  A('.notstr:');
  A('cmp ecx, $ARR');
  A('jne .nota');
  A('cmp edx, $INT');
  A('jne .ak');
  A('push dword ptr [ebp+16]');
  A('push eax');
  A('call _JSRT_arr_get');
  A('leave');
  A('ret');
  A('.ak:');
  A('cmp edx, $STR');
  A('jne .undef');
  A('push dword ptr [ebp+16]');
  A('push eax');
  A('call _JSRT_arr_get_name');
  A('leave');
  A('ret');
  A('.nota:');
  A('cmp ecx, $OBJ');
  A('je .named');
  A('cmp ecx, $FN');
  A('jne .undef');
  A('.named:');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push eax');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_get_named');
  A('leave');
  A('ret');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('leave');
  A('ret');
  A('.bad:');
  A('push offset _JSRT_c_read');
  A('call _JSRT_fatal');
  A('endp');

  { _JSRT_ownkeys(valeur, mode) : 0 cles, 1 valeurs, 2 paires, 3 noms (tous) }
  FBegin('_JSRT_ownkeys', 3);
  A('call _JSRT_array_new');
  A('mov ' + Lv(1) + ', eax');
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, $OBJ');
  A('je .obj');
  A('cmp ecx, $FN');
  A('je .fn');
  A('cmp ecx, $ARR');
  A('je .arr');
  A('cmp ecx, $STR');
  A('je .str');
  A('jmp .done');
  A('.fn:');
  A('mov esi, dword ptr [ebp+8]');
  A('mov esi, dword ptr [esi+$FN_PROPS]');
  A('test esi, esi');
  A('jz .done');
  A('jmp .props');
  A('.obj:');
  A('mov esi, dword ptr [ebp+8]');
  A('.props:');
  A('xor edi, edi');
  A('.pl:');
  A('cmp edi, dword ptr [esi+$OBJ_COUNT]');
  A('jae .done');
  A('mov ebx, edi');
  A('shl ebx, 4');
  A('add ebx, dword ptr [esi+$OBJ_PROPS]');
  A('test dword ptr [ebx+4], 1');
  A('jz .vis');
  A('cmp dword ptr [ebp+16], 3');
  A('jne .pn');
  A('.vis:');
  EmitOwnEntry(0);
  A('.pn:');
  A('inc edi');
  A('jmp .pl');
  A('.arr:');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ebx, dword ptr [esi+$ARR_LEN]');
  A('jmp .idx');
  A('.str:');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ebx, dword ptr [esi+$STR_LEN]');
  A('.idx:');
  A('xor edi, edi');
  A('.il:');
  A('cmp edi, ebx');
  A('jae .idone');
  A('push edi');
  A('call _JSRT_int_to_str');
  A('add esp, 4');
  A('mov ' + Lv(3) + ', eax');
  EmitOwnEntry(1);
  A('inc edi');
  A('jmp .il');
  A('.idone:');
  A('cmp dword ptr [ebp+12], $ARR');
  A('jne .done');
  A('cmp dword ptr [ebp+16], 3');
  A('jne .done');
  PushToArrLocal('$STR', 'offset ' + RtStr('length'), Lv(1));
  A('.done:');
  A('mov eax, ' + Lv(1));
  A('mov edx, $ARR');
  FEnd;

  { _JSRT_forin_keys(valeur) : cles enumerables, heritees comprises }
  FBegin('_JSRT_forin_keys', 2);
  A('call _JSRT_array_new');
  A('mov ' + Lv(1) + ', eax');
  A('mov ' + Lv(2) + ', 0');
  A('mov esi, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [ebp+12]');
  A('cmp ecx, $OBJ');
  A('je .cn');
  A('cmp ecx, $ARR');
  A('je .arr');
  A('cmp ecx, $STR');
  A('jne .done');
  A('mov edi, dword ptr [esi+$STR_LEN]');
  A('jmp .num');
  A('.arr:');
  A('mov edi, dword ptr [esi+$ARR_LEN]');
  A('.num:');
  A('xor esi, esi');
  A('.nl:');
  A('cmp esi, edi');
  A('jae .done');
  A('push esi');
  A('call _JSRT_int_to_str');
  A('add esp, 4');
  PushToArrLocal('$STR', 'eax', Lv(1));
  A('inc esi');
  A('jmp .nl');
  A('.cn:');
  A('test esi, esi');
  A('jz .done');
  A('cmp ' + Lv(2) + ', 0');
  A('je .own');
  A('movzx eax, byte ptr [esi+2]');
  A('test eax, 1');
  A('jnz .done');
  A('.own:');
  A('xor edi, edi');
  A('.pl:');
  A('cmp edi, dword ptr [esi+$OBJ_COUNT]');
  A('jae .next');
  A('mov ebx, edi');
  A('shl ebx, 4');
  A('add ebx, dword ptr [esi+$OBJ_PROPS]');
  A('test dword ptr [ebx+4], 1');
  A('jnz .pn');
  A('push dword ptr [ebx]');
  A('push ' + Lv(1));
  A('call _JSRT_arr_has_str');
  A('add esp, 8');
  A('test eax, eax');
  A('jnz .pn');
  PushToArrLocal('$STR', 'dword ptr [ebx]', Lv(1));
  A('.pn:');
  A('inc edi');
  A('jmp .pl');
  A('.next:');
  A('mov ' + Lv(2) + ', 1');
  A('mov esi, dword ptr [esi+$OBJ_PROTO]');
  A('jmp .cn');
  A('.done:');
  A('mov eax, ' + Lv(1));
  A('mov edx, $ARR');
  FEnd;
End;

{ Object.keys / values / entries / getOwnPropertyNames }
Procedure ObjOwnNative(Const code: TString; mode: LongInt);
Begin
  FBegin(code, 0);
  A('push ' + IntToStr(mode));
  A('cmp dword ptr [ebp+12], 1');
  A('jb .u');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('jmp .go');
  A('.u:');
  A('push $UNDEF');
  A('push 0');
  A('.go:');
  A('call _JSRT_ownkeys');
  A('add esp, 12');
  FEnd;
End;

Procedure ObjArg(i: LongInt; Const lo, hi: TString);
Var
  have, ok: TString;
Begin
  have := U('h');
  ok := U('k');
  A('cmp dword ptr [ebp+12], ' + IntToStr(i + 1));
  A('jae ' + have);
  A('mov ' + lo + ', 0');
  A('mov ' + hi + ', $UNDEF');
  A('jmp ' + ok);
  A(have + ':');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8 * i) + ']');
  A('mov ' + lo + ', eax');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8 * i + 4) + ']');
  A('mov ' + hi + ', eax');
  A(ok + ':');
End;

{ Attribut de defineProperty : s'il est present dans le descripteur, met a
  jour le bit du local 2 (0 = vrai pour le bit, sinon positionne). }
Procedure DescAttr(Const name: TString; bit: LongInt);
Var
  skip, falsy: TString;
Begin
  skip := U('s');
  falsy := U('f');
  A('push offset ' + RtStr(name));
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 20) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 16) + ']');
  A('call _JSRT_has_own');
  A('add esp, 12');
  A('test eax, eax');
  A('jz ' + skip);
  A('push offset ' + RtStr(name));
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 20) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 16) + ']');
  A('call _JSRT_get_named');
  A('add esp, 12');
  A('push edx');
  A('push eax');
  A('call _JSRT_truthy');
  A('add esp, 8');
  A('mov ecx, ' + Lv(2));
  A('and ecx, ' + IntToStr(-1 - bit));
  A('test eax, eax');
  A('jnz ' + falsy);
  A('or ecx, ' + IntToStr(bit));
  A(falsy + ':');
  A('mov ' + Lv(2) + ', ecx');
  A(skip + ':');
End;

Procedure RtObjNatives;
Begin
  ObjOwnNative('_JSRT_Object_keys', 0);
  ObjOwnNative('_JSRT_Object_values', 1);
  ObjOwnNative('_JSRT_Object_entries', 2);
  ObjOwnNative('_JSRT_Object_getOwnPropertyNames', 3);

  { Object.assign(cible, ...sources) }
  FBegin('_JSRT_Object_assign', 3);
  A('mov ebx, 1');
  A('.sl:');
  A('cmp ebx, dword ptr [ebp+12]');
  A('jae .done');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('lea esi, [ebp+eax+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('push 0');
  A('push dword ptr [esi+4]');
  A('push dword ptr [esi]');
  A('call _JSRT_ownkeys');
  A('add esp, 12');
  A('mov ' + Lv(2) + ', eax');
  A('xor edi, edi');
  A('.kl:');
  A('mov ecx, ' + Lv(2));
  A('cmp edi, dword ptr [ecx+$ARR_LEN]');
  A('jae .sn');
  A('mov eax, edi');
  A('shl eax, 3');
  A('add eax, dword ptr [ecx+$ARR_ELEMS]');
  A('mov ecx, dword ptr [eax]');
  A('mov ' + Lv(3) + ', ecx');
  A('push $STR');
  A('push ecx');
  A('push dword ptr [esi+4]');
  A('push dword ptr [esi]');
  A('call _JSRT_get_member');
  A('add esp, 16');
  A('push edx');
  A('push eax');
  A('push $STR');
  A('push ' + Lv(3));
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('call _JSRT_set_member');
  A('add esp, 24');
  A('inc edi');
  A('jmp .kl');
  A('.sn:');
  A('inc ebx');
  A('jmp .sl');
  A('.done:');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('mov edx, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + ']');
  FEnd;

  { Object.create(prototype) }
  FBegin('_JSRT_Object_create', 0);
  A('cmp dword ptr [ebp+12], 1');
  A('jb .null');
  A('cmp dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + '], $OBJ');
  A('jne .null');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('jmp .go');
  A('.null:');
  A('push 0');
  A('.go:');
  A('call _JSRT_obj_new_proto');
  A('add esp, 4');
  A('mov edx, $OBJ');
  FEnd;

  { Object.freeze / isFrozen }
  FBegin('_JSRT_Object_freeze', 2);
  ObjArg(0, 'dword ptr [ebp-16]', 'dword ptr [ebp-20]');
  A('mov eax, dword ptr [ebp-16]');
  A('mov ecx, dword ptr [ebp-20]');
  A('cmp ecx, $OBJ');
  A('je .f');
  A('cmp ecx, $ARR');
  A('je .f');
  A('cmp ecx, $FN');
  A('jne .r');
  A('.f:');
  A('movzx ecx, byte ptr [eax+2]');
  A('or ecx, 2');
  A('mov byte ptr [eax+2], cl');
  A('.r:');
  A('mov eax, dword ptr [ebp-16]');
  A('mov edx, dword ptr [ebp-20]');
  FEnd;

  FBegin('_JSRT_Object_isFrozen', 2);
  ObjArg(0, 'dword ptr [ebp-16]', 'dword ptr [ebp-20]');
  A('mov eax, dword ptr [ebp-16]');
  A('mov ecx, dword ptr [ebp-20]');
  A('cmp ecx, $OBJ');
  A('je .t');
  A('cmp ecx, $ARR');
  A('je .t');
  A('cmp ecx, $FN');
  A('jne .yes');
  A('.t:');
  A('movzx ecx, byte ptr [eax+2]');
  A('test ecx, 2');
  A('jz .no');
  A('.yes:');
  A('mov eax, 1');
  A('mov edx, $BOOL');
  A('jmp .ret');
  A('.no:');
  A('xor eax, eax');
  A('mov edx, $BOOL');
  FEnd;

  { Object.getPrototypeOf / setPrototypeOf }
  FBegin('_JSRT_Object_getPrototypeOf', 2);
  ObjArg(0, 'dword ptr [ebp-16]', 'dword ptr [ebp-20]');
  A('mov eax, dword ptr [ebp-16]');
  A('mov ecx, dword ptr [ebp-20]');
  A('cmp ecx, $OBJ');
  A('je .o');
  A('cmp ecx, $ARR');
  A('je .a');
  A('cmp ecx, $STR');
  A('je .s');
  A('jmp .null');
  A('.o:');
  A('mov eax, dword ptr [eax+$OBJ_PROTO]');
  A('test eax, eax');
  A('jz .null');
  A('jmp .obj');
  A('.a:');
  A('mov eax, offset _JSNO_array_proto');
  A('jmp .obj');
  A('.s:');
  A('mov eax, offset _JSNO_string_proto');
  A('.obj:');
  A('mov edx, $OBJ');
  A('jmp .ret');
  A('.null:');
  A('xor eax, eax');
  A('mov edx, $NULL');
  FEnd;

  FBegin('_JSRT_Object_setPrototypeOf', 2);
  ObjArg(0, 'dword ptr [ebp-16]', 'dword ptr [ebp-20]');
  A('cmp dword ptr [ebp-20], $OBJ');
  A('jne .r');
  A('cmp dword ptr [ebp+12], 2');
  A('jb .r');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8) + ']');
  A('mov ecx, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 12) + ']');
  A('cmp ecx, $OBJ');
  A('je .set');
  A('xor eax, eax');
  A('.set:');
  A('mov edx, dword ptr [ebp-16]');
  A('mov dword ptr [edx+$OBJ_PROTO], eax');
  A('.r:');
  A('mov eax, dword ptr [ebp-16]');
  A('mov edx, dword ptr [ebp-20]');
  FEnd;

  { Object.fromEntries(paires) }
  FBegin('_JSRT_Object_fromEntries', 0);
  A('call _JSRT_obj_new');
  A('mov ebx, eax');
  A('cmp dword ptr [ebp+12], 1');
  A('jb .done');
  A('cmp dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + '], $ARR');
  A('jne .done');
  A('mov esi, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('xor edi, edi');
  A('.l:');
  A('cmp edi, dword ptr [esi+$ARR_LEN]');
  A('jae .done');
  A('mov eax, edi');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('cmp dword ptr [eax+4], $ARR');
  A('jne .nx');
  A('mov ecx, dword ptr [eax]');
  A('push 1');
  A('push ecx');
  A('call _JSRT_arr_get');
  A('add esp, 8');
  A('push edx');
  A('push eax');
  A('mov eax, edi');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('push 0');
  A('push dword ptr [eax]');
  A('call _JSRT_arr_get');
  A('add esp, 8');
  A('push edx');
  A('push eax');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('mov ecx, eax');
  A('pop eax');
  A('pop edx');
  A('push edx');
  A('push eax');
  A('push ecx');
  A('push ebx');
  A('call _JSRT_obj_define');
  A('add esp, 16');
  A('.nx:');
  A('inc edi');
  A('jmp .l');
  A('.done:');
  A('mov eax, ebx');
  A('mov edx, $OBJ');
  FEnd;

  { Object.hasOwn(objet, cle) }
  FBegin('_JSRT_Object_hasOwn', 2);
  ObjArg(1, 'dword ptr [ebp-16]', 'dword ptr [ebp-20]');
  A('push dword ptr [ebp-20]');
  A('push dword ptr [ebp-16]');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push eax');
  A('cmp dword ptr [ebp+12], 1');
  A('jb .u');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('jmp .go');
  A('.u:');
  A('push $UNDEF');
  A('push 0');
  A('.go:');
  A('call _JSRT_has_own');
  A('add esp, 12');
  A('mov edx, $BOOL');
  FEnd;

  { Object.defineProperty(objet, cle, descripteur) }
  FBegin('_JSRT_Object_defineProperty', 3);
  A('cmp dword ptr [ebp+12], 3');
  A('jb .bad');
  A('cmp dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + '], $OBJ');
  A('jne .bad');
  A('cmp dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 20) + '], $OBJ');
  A('jne .bad');
  A('mov esi, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 12) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 8) + ']');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('mov ' + Lv(1) + ', eax');
  { drapeaux de depart : ceux de la propriete existante, sinon cachee et en lecture seule }
  A('mov ' + Lv(2) + ', 5');
  A('push esi');
  A('call _JSRT_obj_own');
  A('add esp, 4');
  A('push ' + Lv(1));
  A('push esi');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .fresh');
  A('mov ecx, dword ptr [eax+4]');
  A('mov ' + Lv(2) + ', ecx');
  A('.fresh:');
  DescAttr('enumerable', 1);
  DescAttr('writable', 4);
  { accesseur ou donnee }
  A('push offset ' + RtStr('get'));
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 20) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 16) + ']');
  A('call _JSRT_get_named');
  A('add esp, 12');
  A('mov ebx, 0');
  A('cmp edx, $FN');
  A('jne .nog');
  A('push 0');
  A('push edx');
  A('push eax');
  A('push ' + Lv(1));
  A('push esi');
  A('call _JSRT_obj_define_acc');
  A('add esp, 20');
  A('mov ebx, 1');
  A('.nog:');
  A('push offset ' + RtStr('set'));
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 20) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 16) + ']');
  A('call _JSRT_get_named');
  A('add esp, 12');
  A('cmp edx, $FN');
  A('jne .nos');
  A('push 1');
  A('push edx');
  A('push eax');
  A('push ' + Lv(1));
  A('push esi');
  A('call _JSRT_obj_define_acc');
  A('add esp, 20');
  A('mov ebx, 1');
  A('.nos:');
  A('test ebx, ebx');
  A('jnz .flags');
  A('push offset ' + RtStr('value'));
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 20) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 16) + ']');
  A('call _JSRT_get_named');
  A('add esp, 12');
  A('push edx');
  A('push eax');
  A('push ' + Lv(1));
  A('push esi');
  A('call _JSRT_obj_define');
  A('add esp, 16');
  A('.flags:');
  A('push ' + Lv(1));
  A('push esi');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('mov ecx, dword ptr [eax+4]');
  A('and ecx, 2');
  A('mov edx, ' + Lv(2));
  A('and edx, -3');
  A('or edx, ecx');
  A('mov dword ptr [eax+4], edx');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('mov edx, $OBJ');
  A('jmp .ret');
  A('.bad:');
  A('push offset _JSRT_c_type');
  A('call _JSRT_fatal');
  FEnd;

  { Object(valeur) }
  FBegin('_JSRT_Object_call', 0);
  A('cmp dword ptr [ebp+12], 1');
  A('jb .new');
  A('mov edx, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + ']');
  A('cmp edx, $UNDEF');
  A('je .new');
  A('cmp edx, $NULL');
  A('je .new');
  A('mov eax, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('jmp .ret');
  A('.new:');
  A('call _JSRT_obj_new');
  FEnd;

  { Object.prototype : hasOwnProperty, isPrototypeOf, propertyIsEnumerable, toString, valueOf }
  FBegin('_JSRT_op_hasOwnProperty', 0);
  A('cmp dword ptr [ebp+12], 1');
  A('jb .u');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('jmp .k');
  A('.u:');
  A('push $UNDEF');
  A('push 0');
  A('.k:');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push eax');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_has_own');
  A('add esp, 12');
  A('mov edx, $BOOL');
  FEnd;

  FBegin('_JSRT_op_propertyIsEnumerable', 0);
  A('xor eax, eax');
  A('cmp dword ptr [ebp+20], $OBJ');
  A('jne .r');
  A('cmp dword ptr [ebp+12], 1');
  A('jb .u');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + ']');
  A('push dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('jmp .k');
  A('.u:');
  A('push $UNDEF');
  A('push 0');
  A('.k:');
  A('call _JSRT_tostring');
  A('add esp, 8');
  A('push eax');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .r');
  A('test dword ptr [eax+4], 1');
  A('mov eax, 1');
  A('jz .r');
  A('xor eax, eax');
  A('.r:');
  A('mov edx, $BOOL');
  FEnd;

  FBegin('_JSRT_op_isPrototypeOf', 0);
  A('xor eax, eax');
  A('cmp dword ptr [ebp+20], $OBJ');
  A('jne .r');
  A('cmp dword ptr [ebp+12], 1');
  A('jb .r');
  A('cmp dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS + 4) + '], $OBJ');
  A('jne .r');
  A('mov esi, dword ptr [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('mov esi, dword ptr [esi+$OBJ_PROTO]');
  A('.w:');
  A('test esi, esi');
  A('jz .r');
  A('cmp esi, dword ptr [ebp+16]');
  A('je .y');
  A('mov esi, dword ptr [esi+$OBJ_PROTO]');
  A('jmp .w');
  A('.y:');
  A('mov eax, 1');
  A('.r:');
  A('mov edx, $BOOL');
  FEnd;

  FBegin('_JSRT_op_toString', 0);
  A('mov eax, offset ' + RtStr('[object Object]'));
  A('mov edx, $STR');
  FEnd;

  FBegin('_JSRT_op_valueOf', 0);
  A('mov eax, dword ptr [ebp+16]');
  A('mov edx, dword ptr [ebp+20]');
  FEnd;
End;

Procedure RtObjects;
Begin
  RtObjCore;
  RtObjAccess;
  RtObjNatives;
End;

{ Object.prototype et la globale Object. }
Procedure RtObjectProtoMethods;
  Procedure M(Const name, code: TString; nparams: LongInt);
  Begin
    BoAdd(name, RtFuncObj(name, code, nparams), RT_T_FUNCTION);
  End;
Begin
  M('hasOwnProperty', '_JSRT_op_hasOwnProperty', 1);
  M('isPrototypeOf', '_JSRT_op_isPrototypeOf', 1);
  M('propertyIsEnumerable', '_JSRT_op_propertyIsEnumerable', 1);
  M('toString', '_JSRT_op_toString', 0);
  M('valueOf', '_JSRT_op_valueOf', 0);
End;

Procedure RtObjectGlobals;
  Procedure M(Const name, code: TString; nparams: LongInt);
  Begin
    BoAdd(name, RtFuncObj(name, code, nparams), RT_T_FUNCTION);
  End;
Var
  props, f_obj: LongInt;
Begin
  BoReset;
  M('keys', '_JSRT_Object_keys', 1);
  M('values', '_JSRT_Object_values', 1);
  M('entries', '_JSRT_Object_entries', 1);
  M('assign', '_JSRT_Object_assign', 2);
  M('create', '_JSRT_Object_create', 2);
  M('freeze', '_JSRT_Object_freeze', 1);
  M('isFrozen', '_JSRT_Object_isFrozen', 1);
  M('getPrototypeOf', '_JSRT_Object_getPrototypeOf', 1);
  M('setPrototypeOf', '_JSRT_Object_setPrototypeOf', 2);
  M('getOwnPropertyNames', '_JSRT_Object_getOwnPropertyNames', 1);
  M('fromEntries', '_JSRT_Object_fromEntries', 1);
  M('hasOwn', '_JSRT_Object_hasOwn', 2);
  M('defineProperty', '_JSRT_Object_defineProperty', 3);
  BoAdd('prototype', DsymFind(asm_ctx^, '_JSNO_object_proto'), RT_T_OBJECT);
  props := BoFinish('_JSNO_Object_props', 0);
  f_obj := RtFuncObjP('Object', '_JSRT_Object_call', 1, props);
  RtGlobal('Object', f_obj, RT_T_FUNCTION);
End;

{ ---- Classes : routines du runtime (TODO 17) ---- }

Procedure RtClassData;
Var
  d: LongInt;
Begin
  d := RtDescSym('constructor', '_JSRT_ctor_base', 0, FDF_CTOR);
  d := RtDescSym('constructor', '_JSRT_ctor_derived', 0, FDF_CTOR Or FDF_DERIVED);
End;

Procedure RtClasses;
Begin
  { _JSRT_obj_hide(obj, cle) : rend la propriete non enumerable }
  A('proc _JSRT_obj_hide');
  A('push ebp');
  A('mov ebp, esp');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .r');
  A('mov ecx, dword ptr [eax+4]');
  A('or ecx, 1');
  A('mov dword ptr [eax+4], ecx');
  A('.r:');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_make_default_ctor(derive) -> fonction constructeur par defaut }
  A('proc _JSRT_make_default_ctor');
  A('push ebp');
  A('mov ebp, esp');
  A('push $UNDEF');
  A('push 0');
  A('push 0');
  A('cmp dword ptr [ebp+8], 0');
  A('jne .d');
  A('push offset _JSRT_ctor_base');
  A('push offset _JSND__JSRT_ctor_base');
  A('jmp .go');
  A('.d:');
  A('push offset _JSRT_ctor_derived');
  A('push offset _JSND__JSRT_ctor_derived');
  A('.go:');
  A('call _JSRT_new_function');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_init_fields(classe, this) : initialise les champs d'instance }
  FBegin('_JSRT_init_fields', 1);
  A('cmp dword ptr [ebp+16], $OBJ');
  A('jne .ret');
  A('mov esi, dword ptr [ebp+8]');
  A('mov eax, dword ptr [esi+$FN_PROPS]');
  A('test eax, eax');
  A('jz .ret');
  A('push offset ' + RtStr('prototype'));
  A('push eax');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .ret');
  A('cmp dword ptr [eax+12], $OBJ');
  A('jne .ret');
  A('mov eax, dword ptr [eax+8]');
  A('push offset ' + RtStr('#fields'));
  A('push eax');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .ret');
  A('mov esi, dword ptr [eax+8]');
  A('xor ebx, ebx');
  A('.l:');
  A('cmp ebx, dword ptr [esi+$ARR_LEN]');
  A('jae .ret');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('add eax, dword ptr [esi+$ARR_ELEMS]');
  A('mov ecx, dword ptr [eax]');
  A('mov ' + Lv(1) + ', ecx');
  A('mov edx, dword ptr [eax+12]');
  A('mov eax, dword ptr [eax+8]');
  A('cmp edx, $FN');
  A('jne .undef');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+12]');
  A('push eax');
  A('call _JSRT_call0');
  A('add esp, 12');
  A('jmp .def');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('.def:');
  A('push edx');
  A('push eax');
  A('push ' + Lv(1));
  A('push dword ptr [ebp+12]');
  A('call _JSRT_obj_define');
  A('add esp, 16');
  A('add ebx, 2');
  A('jmp .l');
  FEnd;

  { Constructeur par defaut d'une classe de base }
  FBegin('_JSRT_ctor_base', 0);
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push dword ptr [ebp+8]');
  A('call _JSRT_init_fields');
  A('add esp, 12');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  FEnd;

  { Constructeur par defaut d'une classe derivee : transmet les arguments }
  FBegin('_JSRT_ctor_derived', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('cmp dword ptr [esi+$FN_THIS+4], $FN');
  A('jne .nopar');
  A('mov ebx, dword ptr [ebp+12]');
  A('mov eax, ebx');
  A('shl eax, 3');
  A('add eax, 16');
  A('sub esp, eax');
  A('mov eax, dword ptr [esi+$FN_THIS]');
  A('mov dword ptr [esp], eax');
  A('mov dword ptr [esp+4], ebx');
  A('mov eax, dword ptr [ebp+16]');
  A('mov dword ptr [esp+8], eax');
  A('mov eax, dword ptr [ebp+20]');
  A('mov dword ptr [esp+12], eax');
  A('lea edi, [esp+16]');
  A('mov ecx, ebx');
  A('shl ecx, 3');
  A('lea esi, [ebp+' + IntToStr(RT_FRAME_ARGS) + ']');
  A('rep movsb');
  A('mov esi, dword ptr [ebp+8]');
  A('mov eax, dword ptr [esi+$FN_THIS]');
  A('call dword ptr [eax+$FN_CODE]');
  A('mov esp, ebp');
  A('sub esp, 12');
  A('.nopar:');
  A('mov esi, dword ptr [ebp+8]');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_init_fields');
  A('add esp, 12');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  FEnd;

  { _JSRT_class_setup(classe, parent) : proprietes, prototype et lien au parent }
  FBegin('_JSRT_class_setup', 2);
  A('mov esi, dword ptr [ebp+8]');
  A('mov ' + Lv(1) + ', offset _JSNO_object_proto');
  A('mov ' + Lv(2) + ', offset _JSNO_object_proto');
  A('cmp dword ptr [ebp+20], $FN');
  A('je .fnp');
  A('cmp dword ptr [ebp+20], $NULL');
  A('jne .make');
  A('mov ' + Lv(2) + ', 0');
  A('jmp .make');
  A('.fnp:');
  A('mov edi, dword ptr [ebp+16]');
  A('push offset ' + RtStr('prototype'));
  A('push $FN');
  A('push edi');
  A('call _JSRT_get_named');
  A('add esp, 12');
  A('cmp edx, $OBJ');
  A('jne .p2');
  A('mov ' + Lv(2) + ', eax');
  A('.p2:');
  A('mov eax, dword ptr [edi+$FN_PROPS]');
  A('test eax, eax');
  A('jz .make');
  A('mov ' + Lv(1) + ', eax');
  A('.make:');
  A('push ' + Lv(1));
  A('call _JSRT_obj_new_proto');
  A('add esp, 4');
  A('mov ebx, eax');
  A('mov dword ptr [esi+$FN_PROPS], ebx');
  A('push ' + Lv(2));
  A('call _JSRT_obj_new_proto');
  A('add esp, 4');
  A('mov edi, eax');
  A('push $OBJ');
  A('push edi');
  A('push 1');
  A('push offset ' + RtStr('prototype'));
  A('push ebx');
  A('call _JSRT_obj_add');
  A('add esp, 20');
  A('push $FN');
  A('push esi');
  A('push 1');
  A('push offset ' + RtStr('constructor'));
  A('push edi');
  A('call _JSRT_obj_add');
  A('add esp, 20');
  A('cmp dword ptr [ebp+20], $FN');
  A('jne .done');
  A('mov eax, dword ptr [ebp+16]');
  A('mov dword ptr [esi+$FN_THIS], eax');
  A('mov dword ptr [esi+$FN_THIS+4], $FN');
  A('.done:');
  FEnd;

  { _JSRT_class_proto(classe) -> objet prototype }
  A('proc _JSRT_class_proto');
  A('push ebp');
  A('mov ebp, esp');
  A('mov eax, dword ptr [ebp+8]');
  A('push offset ' + RtStr('prototype'));
  A('push dword ptr [eax+$FN_PROPS]');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('mov edx, dword ptr [eax+12]');
  A('mov eax, dword ptr [eax+8]');
  A('leave');
  A('ret');
  A('endp');

  { _JSRT_class_member(accueil, cle, fonction, genre) : methode ou accesseur }
  FBegin('_JSRT_class_member', 0);
  A('cmp dword ptr [ebp+12], $OBJ');
  A('jne .fnhome');
  A('mov esi, dword ptr [ebp+8]');
  A('jmp .have');
  A('.fnhome:');
  A('mov eax, dword ptr [ebp+8]');
  A('mov esi, dword ptr [eax+$FN_PROPS]');
  A('.have:');
  A('mov eax, dword ptr [ebp+20]');
  A('mov ecx, dword ptr [ebp+8]');
  A('mov dword ptr [eax+$FN_THIS], ecx');
  A('mov ecx, dword ptr [ebp+12]');
  A('mov dword ptr [eax+$FN_THIS+4], ecx');
  A('mov ecx, dword ptr [ebp+28]');
  A('test ecx, ecx');
  A('jnz .acc');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_obj_define');
  A('add esp, 16');
  A('jmp .hide');
  A('.acc:');
  A('dec ecx');
  A('push ecx');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_obj_define_acc');
  A('add esp, 20');
  A('.hide:');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_obj_hide');
  A('add esp, 8');
  FEnd;

  { _JSRT_class_field(prototype, cle, initialiseur) : enregistre un champ d'instance }
  FBegin('_JSRT_class_field', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('push offset ' + RtStr('#fields'));
  A('push esi');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jnz .have');
  A('call _JSRT_array_new');
  A('mov ebx, eax');
  A('push $ARR');
  A('push ebx');
  A('push 1');
  A('push offset ' + RtStr('#fields'));
  A('push esi');
  A('call _JSRT_obj_add');
  A('add esp, 20');
  A('jmp .push');
  A('.have:');
  A('mov ebx, dword ptr [eax+8]');
  A('.push:');
  PushToArrLocal('$STR', 'dword ptr [ebp+16]', 'ebx');
  A('push dword ptr [ebp+24]');
  A('push dword ptr [ebp+20]');
  A('push $ARR');
  A('push ebx');
  A('call _JSRT_array_push');
  A('add esp, 16');
  FEnd;

  { _JSRT_class_static(classe, cle, initialiseur) : champ statique }
  FBegin('_JSRT_class_static', 0);
  A('mov eax, dword ptr [ebp+8]');
  A('mov esi, dword ptr [eax+$FN_PROPS]');
  A('cmp dword ptr [ebp+24], $FN');
  A('jne .undef');
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('push dword ptr [ebp+20]');
  A('call _JSRT_call0');
  A('add esp, 12');
  A('jmp .def');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  A('.def:');
  A('push edx');
  A('push eax');
  A('push dword ptr [ebp+16]');
  A('push esi');
  A('call _JSRT_obj_define');
  A('add esp, 16');
  FEnd;

  { _JSRT_class_block(classe, fonction) : bloc statique }
  FBegin('_JSRT_class_block', 0);
  A('push dword ptr [ebp+12]');
  A('push dword ptr [ebp+8]');
  A('push dword ptr [ebp+16]');
  A('call _JSRT_call0');
  A('add esp, 12');
  FEnd;

  { _JSRT_super_get(fermeture, cle, this) : super.cle }
  FBegin('_JSRT_super_get', 0);
  A('mov esi, dword ptr [ebp+8]');
  A('mov ecx, dword ptr [esi+$FN_DESC]');
  A('mov edx, dword ptr [ecx+8]');
  A('test edx, ' + IntToStr(FDF_CTOR));
  A('jnz .ctor');
  A('cmp dword ptr [esi+$FN_THIS+4], $OBJ');
  A('jne .fnhome');
  A('mov esi, dword ptr [esi+$FN_THIS]');
  A('jmp .parent');
  A('.fnhome:');
  A('cmp dword ptr [esi+$FN_THIS+4], $FN');
  A('jne .undef');
  A('mov esi, dword ptr [esi+$FN_THIS]');
  A('mov esi, dword ptr [esi+$FN_PROPS]');
  A('test esi, esi');
  A('jz .undef');
  A('jmp .parent');
  A('.ctor:');
  A('mov eax, dword ptr [esi+$FN_PROPS]');
  A('test eax, eax');
  A('jz .undef');
  A('push offset ' + RtStr('prototype'));
  A('push eax');
  A('call _JSRT_prop_find');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .undef');
  A('mov esi, dword ptr [eax+8]');
  A('.parent:');
  A('mov esi, dword ptr [esi+$OBJ_PROTO]');
  A('test esi, esi');
  A('jz .undef');
  A('push dword ptr [ebp+12]');
  A('push esi');
  A('call _JSRT_prop_lookup');
  A('add esp, 8');
  A('test eax, eax');
  A('jz .undef');
  A('push dword ptr [ebp+20]');
  A('push dword ptr [ebp+16]');
  A('push eax');
  A('call _JSRT_prop_get');
  A('add esp, 12');
  A('jmp .ret');
  A('.undef:');
  A('xor eax, eax');
  A('mov edx, $UNDEF');
  FEnd;
End;

{ ---- Assemblage du runtime ---- }

Procedure RtStaticData;
Var
  f_log, f_err, f_warn, proto, cons, oproto: LongInt;
Begin
  RtCString('_JSRT_c_oom', 'JSCW32: memoire epuisee' + #10);
  RtCString('_JSRT_c_notfunc', 'TypeError: la valeur appelee n''est pas une fonction' + #10);
  RtCString('_JSRT_c_type', 'TypeError' + #10);
  RtCString('_JSRT_c_stack', 'RangeError: pile d''appels epuisee' + #10);
  RtCString('_JSRT_c_read', 'TypeError: lecture d''une propriete de null ou undefined' + #10);
  RtCString('_JSRT_c_tdz1', 'ReferenceError: ');
  RtCString('_JSRT_c_tdz2', ' ne peut pas etre utilise avant son initialisation' + #10);
  RtCString('_JSRT_c_space', ' ');
  RtCString('_JSRT_c_nl', #10);
  RtCString('_JSRT_c_setundef', 'TypeError: impossible de definir une propriete de null ou undefined' + #10);
  RtCString('_JSRT_c_noiter', 'TypeError: la valeur n''est pas iterable' + #10);
  RtCString('_JSRT_c_setprop', 'TypeError: affectation de propriete non prise en charge pour cet objet' + #10);
  RtCString('_JSRT_c_range', 'RangeError: argument invalide' + #10);

  { prototype des chaines : les methodes natives }
  RtClassData;
  BoReset;
  RtObjectProtoMethods;
  oproto := BoFinish('_JSNO_object_proto', 0);

  BoReset;
  RtStringProtoMethods;
  proto := BoFinish('_JSNO_string_proto', oproto);

  BoReset;
  RtArrayProtoMethods;
  BoFinish('_JSNO_array_proto', oproto);

  f_log := RtFuncObj('log', '_JSRT_console_log', 0);
  f_err := RtFuncObj('error', '_JSRT_console_error', 0);
  f_warn := RtFuncObj('warn', '_JSRT_console_error', 0);
  BoReset;
  BoAdd('log', f_log, RT_T_FUNCTION);
  BoAdd('error', f_err, RT_T_FUNCTION);
  BoAdd('warn', f_warn, RT_T_FUNCTION);
  cons := BoFinish('_JSNO_console', 0);
  RtGlobal('console', cons, RT_T_OBJECT);
  RtStaticGlobals;
  RtArrayGlobals;
  RtObjectGlobals;
End;

Procedure EmitRuntime(Var ctx: TCompilerContext);
Begin
  asm_ctx := @ctx;
  asm_failed := False;
  asm_uniq := 0;
  asm_lbl_count := 0;
  ctx.ir.user_count := ctx.ir.count;
  RtStaticData;
  RtStartAndAlloc;
  RtStrings;
  RtEquality;
  RtProperties;
  RtConsoleFn('_JSRT_console_log', '_JSRT_v_stdout');
  RtConsoleFn('_JSRT_console_error', '_JSRT_v_stderr');
  RtStringMethods;
  RtArrays;
  RtObjects;
  RtClasses;
End;

{ ============================================================
  EMULATEUR 80386 (option -run)

  Execute l'IR directement : memoire plate de 64 Mo, les sections
  .rdata et .data chargees avec leurs relocations, les procedures du
  programme et du runtime, la pile des appels et les drapeaux. Les
  appels systeme Windows importes (VirtualAlloc, GetStdHandle,
  WriteFile, ReadFile, ExitProcess) sont simules. Sert a verifier le
  programme compile sans edition de liens ni machine Windows.
  ============================================================ }

Const
  EMU_MEM_SIZE = 67108864;
  EMU_BASE     = $00400000;
  EMU_CODE     = $60000000;
  EMU_TRAP     = $70000000;
  EMU_HALTADDR     = $7FFFFFF0;
  EMU_HEAP     = $01000000;
  EMU_STACK    = $043FFF00;
  EMU_STEPLIMIT    = 400000000;

Type
  TEmuMem = Array[0..0] Of Byte;
  PEmuMem = ^TEmuMem;

Var
  emu_mem: PEmuMem;
  emu_reg: Array[0..12] Of LongWord;
  emu_zf, emu_sf, emu_cf, emu_of: Boolean;
  emu_pc: LongInt;
  emu_halt: Boolean;
  emu_exit: LongInt;
  emu_fault_msg: String[120];
  emu_steps: Int64;
  emu_rd_base, emu_dt_base, emu_brk: LongWord;
  emu_xaddr: Array[1..MAX_XSYMS] Of LongWord;
  emu_lbl: Array[0..262143] Of LongInt;
  emu_ctx: PCtx;
  emu_trap_names: Array[1..8] Of String[40];
  emu_trap_count: LongInt;
  emu_iat_next: LongWord;

Procedure EmuFault(Const msg: TString);
Begin
  If Not emu_halt Then
    Begin
      emu_fault_msg := msg;
      emu_exit := -1;
    End;
  emu_halt := True;
End;

Function MemOk(a: LongWord; n: LongWord): Boolean;
Begin
  MemOk := (a >= EMU_BASE) And (Int64(a) + n <= Int64(EMU_BASE) + EMU_MEM_SIZE);
End;

Function MemRd(a: LongWord; size: Integer): LongWord;
Var
  v: LongWord;
Begin
  MemRd := 0;
  If Not MemOk(a, size) Then
    Begin
      EmuFault('lecture hors memoire a ' + HexU(a));
      Exit;
    End;
  v := 0;
  Move(emu_mem^[a - EMU_BASE], v, size);
  MemRd := v;
End;

Procedure MemWr(a: LongWord; v: LongWord; size: Integer);
Begin
  If Not MemOk(a, size) Then
    Begin
      EmuFault('ecriture hors memoire a ' + HexU(a));
      Exit;
    End;
  Move(v, emu_mem^[a - EMU_BASE], size);
End;

Function DsymAddr(Var ctx: TCompilerContext; d: LongInt): LongWord;
Begin
  If ctx.data.syms[d].sec = SEC_RDATA Then
    DsymAddr := emu_rd_base + ctx.data.syms[d].ofs
  Else
    DsymAddr := emu_dt_base + ctx.data.syms[d].ofs;
End;

Function SymAddr(Var ctx: TCompilerContext; symkind, sym: LongInt): LongWord;
Begin
  If symkind = SYMK_D Then
    SymAddr := DsymAddr(ctx, sym)
  Else
    SymAddr := emu_xaddr[sym];
End;

Function RegIdx(r: TReg): Integer;
Begin
  Case r Of
    R_AL: RegIdx := Ord(R_EAX);
    R_CL: RegIdx := Ord(R_ECX);
    R_DL: RegIdx := Ord(R_EDX);
    R_BL: RegIdx := Ord(R_EBX);
  Else
    RegIdx := Ord(r);
  End;
End;

Function EffAddr(Var ctx: TCompilerContext; Var o: TOperand): LongWord;
Var
  a: Int64;
Begin
  a := o.disp;
  If o.base <> R_NONE Then
    a := a + emu_reg[RegIdx(o.base)];
  If o.index <> R_NONE Then
    a := a + emu_reg[RegIdx(o.index)];
  If o.symkind <> 0 Then
    a := a + SymAddr(ctx, o.symkind, o.sym);
  EffAddr := LongWord(a And $FFFFFFFF);
End;

{ Taille de l'operation : octet si un registre ou une memoire 8 bits. }
Function OpSz(Var o: TOperand): Integer;
Begin
  OpSz := 4;
  If o.kind = OD_REG Then
    Begin
      If IsReg8(o.reg) Then
        OpSz := 1;
    End
  Else If (o.kind = OD_MEM) And (o.size = 1) Then
    OpSz := 1;
End;

Function OpRd(Var ctx: TCompilerContext; Var o: TOperand; size: Integer): LongWord;
Var
  v: LongWord;
Begin
  v := 0;
  Case o.kind Of
    OD_REG:
      Begin
        v := emu_reg[RegIdx(o.reg)];
        If IsReg8(o.reg) Then
          v := v And $FF;
      End;
    OD_IMM:
      v := LongWord(Int64(o.disp) And $FFFFFFFF);
    OD_MEM:
      v := MemRd(EffAddr(ctx, o), size);
    OD_ADDR:
      v := SymAddr(ctx, o.symkind, o.sym);
  End;
  If size = 1 Then
    v := v And $FF;
  OpRd := v;
End;

Procedure OpWr(Var ctx: TCompilerContext; Var o: TOperand; v: LongWord; size: Integer);
Var
  i: Integer;
Begin
  Case o.kind Of
    OD_REG:
      Begin
        i := RegIdx(o.reg);
        If IsReg8(o.reg) Then
          emu_reg[i] := (emu_reg[i] And $FFFFFF00) Or (v And $FF)
        Else
          emu_reg[i] := v;
      End;
    OD_MEM:
      MemWr(EffAddr(ctx, o), v, size);
  Else
    EmuFault('destination invalide');
  End;
End;

Procedure EmuPush(v: LongWord);
Begin
  emu_reg[Ord(R_ESP)] := emu_reg[Ord(R_ESP)] - 4;
  MemWr(emu_reg[Ord(R_ESP)], v, 4);
End;

Function EmuPop: LongWord;
Begin
  EmuPop := MemRd(emu_reg[Ord(R_ESP)], 4);
  emu_reg[Ord(R_ESP)] := emu_reg[Ord(R_ESP)] + 4;
End;

Procedure SetZS(res: LongWord; size: Integer);
Begin
  If size = 1 Then
    Begin
      emu_zf := (res And $FF) = 0;
      emu_sf := (res And $80) <> 0;
    End
  Else
    Begin
      emu_zf := res = 0;
      emu_sf := (res And $80000000) <> 0;
    End;
End;

Function AluAdd(a, b: LongWord; size: Integer): LongWord;
Var
  r, m, sb: Int64;
Begin
  If size = 1 Then
    Begin
      m := $FF;
      sb := $80;
    End
  Else
    Begin
      m := $FFFFFFFF;
      sb := $80000000;
    End;
  r := Int64(a) + Int64(b);
  emu_cf := r > m;
  r := r And m;
  emu_of := ((Int64(a) Xor r) And (Int64(b) Xor r) And sb) <> 0;
  SetZS(r, size);
  AluAdd := r;
End;

Function AluSub(a, b: LongWord; size: Integer): LongWord;
Var
  r, m, sb: Int64;
Begin
  If size = 1 Then
    Begin
      m := $FF;
      sb := $80;
    End
  Else
    Begin
      m := $FFFFFFFF;
      sb := $80000000;
    End;
  emu_cf := Int64(a) < Int64(b);
  r := (Int64(a) - Int64(b)) And m;
  emu_of := ((Int64(a) Xor Int64(b)) And (Int64(a) Xor r) And sb) <> 0;
  SetZS(r, size);
  AluSub := r;
End;

Function EmuCond(op: TOpc): Boolean;
Begin
  Case op Of
    OP_JE:  EmuCond := emu_zf;
    OP_JNE: EmuCond := Not emu_zf;
    OP_JL:  EmuCond := emu_sf <> emu_of;
    OP_JLE: EmuCond := emu_zf Or (emu_sf <> emu_of);
    OP_JG:  EmuCond := (Not emu_zf) And (emu_sf = emu_of);
    OP_JGE: EmuCond := emu_sf = emu_of;
    OP_JB:  EmuCond := emu_cf;
    OP_JAE: EmuCond := Not emu_cf;
    OP_JA:  EmuCond := (Not emu_cf) And (Not emu_zf);
    OP_JBE: EmuCond := emu_cf Or emu_zf;
    OP_JO:  EmuCond := emu_of;
    OP_JNO: EmuCond := Not emu_of;
    OP_JS:  EmuCond := emu_sf;
    OP_JNS: EmuCond := Not emu_sf;
  Else
    EmuCond := False;
  End;
End;

{ Appels systeme simules (stdcall : l'appele retire ses arguments). }
Procedure EmuTrap(id: LongInt);
Var
  esp, a1, a2, a3, a4, n, i: LongWord;
  c: Byte;
  s: String;
Begin
  esp := emu_reg[Ord(R_ESP)];
  a1 := MemRd(esp + 4, 4);
  a2 := MemRd(esp + 8, 4);
  a3 := MemRd(esp + 12, 4);
  a4 := MemRd(esp + 16, 4);
  n := 0;
  Case id Of
    1: { VirtualAlloc(adresse, taille, type, protection) }
      Begin
        n := 16;
        a2 := (a2 + $FFF) And $FFFFF000;
        If emu_brk + a2 > EMU_BASE + EMU_MEM_SIZE - $500000 Then
          emu_reg[Ord(R_EAX)] := 0
        Else
          Begin
            emu_reg[Ord(R_EAX)] := emu_brk;
            emu_brk := emu_brk + a2;
          End;
      End;
    2: { ExitProcess(code) }
      Begin
        n := 4;
        emu_exit := a1;
        emu_halt := True;
      End;
    3: { GetStdHandle(n) : 0 stdin, 1 stdout, 2 stderr }
      Begin
        n := 4;
        If LongInt(a1) = -10 Then
          emu_reg[Ord(R_EAX)] := 0
        Else If LongInt(a1) = -11 Then
          emu_reg[Ord(R_EAX)] := 1
        Else
          emu_reg[Ord(R_EAX)] := 2;
      End;
    4: { WriteFile(handle, tampon, nombre, ecrits, recouvrement) }
      Begin
        n := 20;
        s := '';
        For i := 0 To Int64(a3) - 1 Do
          Begin
            c := MemRd(a2 + i, 1);
            If c <> 13 Then
              s := s + Chr(c);
            If Length(s) >= 200 Then
              Begin
                If a1 = 2 Then
                  Write(ErrOutput, s)
                Else
                  Write(s);
                s := '';
              End;
          End;
        If a1 = 2 Then
          Write(ErrOutput, s)
        Else
          Write(s);
        If a4 <> 0 Then
          MemWr(a4, a3, 4);
        emu_reg[Ord(R_EAX)] := 1;
      End;
    5: { ReadFile(handle, tampon, nombre, lus, recouvrement) : fin de fichier }
      Begin
        n := 20;
        If a4 <> 0 Then
          MemWr(a4, 0, 4);
        emu_reg[Ord(R_EAX)] := 1;
      End;
  Else
    EmuFault('appel systeme inconnu');
  End;
  { retour a l'appelant : adresse puis arguments }
  emu_reg[Ord(R_ESP)] := emu_reg[Ord(R_ESP)] + 4 + n;
  If Not emu_halt Then
    Begin
      emu_pc := (MemRd(esp, 4) - EMU_CODE) Div 4;
      If MemRd(esp, 4) = EMU_HALTADDR Then
        emu_halt := True;
    End;
End;

{ Transfere l'execution a l'adresse de code a ; ret est l'adresse de
  retour a empiler (0 pour un saut). }
Procedure EmuCall(a: LongWord; ret: LongWord);
Begin
  If ret <> 0 Then
    EmuPush(ret);
  If a >= EMU_TRAP Then
    Begin
      EmuTrap((a - EMU_TRAP) Div 4);
      Exit;
    End;
  If (a < EMU_CODE) Or (a >= EMU_TRAP) Then
    Begin
      EmuFault('appel vers une adresse invalide ' + HexU(a));
      Exit;
    End;
  emu_pc := (a - EMU_CODE) Div 4;
End;

Procedure EmuStep(Var ctx: TCompilerContext);
Var
  ins: ^TInstr;
  sz, tmp, i: Integer;
  a, b, r: LongWord;
  w: Int64;
  cnt: Integer;
  d: LongWord;
  si, di, cx: LongWord;
Begin
  If (emu_pc < 1) Or (emu_pc > ctx.ir.count) Then
    Begin
      EmuFault('compteur ordinal hors programme');
      Exit;
    End;
  ins := @ctx.ir.instrs[emu_pc];
  Inc(emu_pc);
  Case ins^.op Of
    OP_NONE, OP_LABEL, OP_COMMENT, OP_PROC, OP_ENDP, OP_NOP:
      ;
    OP_MOV:
      Begin
        sz := OpSz(ins^.a);
        OpWr(ctx, ins^.a, OpRd(ctx, ins^.b, sz), sz);
      End;
    OP_LEA:
      OpWr(ctx, ins^.a, EffAddr(ctx, ins^.b), 4);
    OP_MOVZX:
      Begin
        sz := OpSz(ins^.b);
        If (ins^.b.kind = OD_MEM) And (ins^.b.size = 0) Then
          sz := 1;
        OpWr(ctx, ins^.a, OpRd(ctx, ins^.b, sz), 4);
      End;
    OP_PUSH:
      EmuPush(OpRd(ctx, ins^.a, 4));
    OP_POP:
      Begin
        r := EmuPop;
        OpWr(ctx, ins^.a, r, 4);
      End;
    OP_ADD:
      Begin
        sz := OpSz(ins^.a);
        OpWr(ctx, ins^.a, AluAdd(OpRd(ctx, ins^.a, sz), OpRd(ctx, ins^.b, sz), sz), sz);
      End;
    OP_SUB:
      Begin
        sz := OpSz(ins^.a);
        OpWr(ctx, ins^.a, AluSub(OpRd(ctx, ins^.a, sz), OpRd(ctx, ins^.b, sz), sz), sz);
      End;
    OP_CMP:
      Begin
        sz := OpSz(ins^.a);
        AluSub(OpRd(ctx, ins^.a, sz), OpRd(ctx, ins^.b, sz), sz);
      End;
    OP_AND, OP_OR, OP_XOR, OP_TEST:
      Begin
        sz := OpSz(ins^.a);
        a := OpRd(ctx, ins^.a, sz);
        b := OpRd(ctx, ins^.b, sz);
        Case ins^.op Of
          OP_AND, OP_TEST: r := a And b;
          OP_OR:           r := a Or b;
        Else
          r := a Xor b;
        End;
        emu_cf := False;
        emu_of := False;
        SetZS(r, sz);
        If ins^.op <> OP_TEST Then
          OpWr(ctx, ins^.a, r, sz);
      End;
    OP_NOT:
      Begin
        sz := OpSz(ins^.a);
        OpWr(ctx, ins^.a, Not OpRd(ctx, ins^.a, sz), sz);
      End;
    OP_NEG:
      Begin
        sz := OpSz(ins^.a);
        a := OpRd(ctx, ins^.a, sz);
        r := AluSub(0, a, sz);
        OpWr(ctx, ins^.a, r, sz);
      End;
    OP_INC, OP_DEC:
      Begin
        sz := OpSz(ins^.a);
        a := OpRd(ctx, ins^.a, sz);
        If emu_cf Then
          d := 1
        Else
          d := 0;
        If ins^.op = OP_INC Then
          r := AluAdd(a, 1, sz)
        Else
          r := AluSub(a, 1, sz);
        emu_cf := d <> 0;
        OpWr(ctx, ins^.a, r, sz);
      End;
    OP_IMUL:
      Begin
        w := Int64(LongInt(OpRd(ctx, ins^.a, 4))) * Int64(LongInt(OpRd(ctx, ins^.b, 4)));
        r := LongWord(w And $FFFFFFFF);
        emu_of := (w > 2147483647) Or (w < -2147483648);
        emu_cf := emu_of;
        SetZS(r, 4);
        OpWr(ctx, ins^.a, r, 4);
      End;
    OP_CDQ:
      Begin
        If (emu_reg[Ord(R_EAX)] And $80000000) <> 0 Then
          emu_reg[Ord(R_EDX)] := $FFFFFFFF
        Else
          emu_reg[Ord(R_EDX)] := 0;
      End;
    OP_IDIV:
      Begin
        b := OpRd(ctx, ins^.a, 4);
        If b = 0 Then
          Begin
            EmuFault('division entiere par zero');
            Exit;
          End;
        w := (Int64(LongInt(emu_reg[Ord(R_EDX)])) Shl 32) Or Int64(emu_reg[Ord(R_EAX)]);
        If (w Div Int64(LongInt(b)) > 2147483647) Or (w Div Int64(LongInt(b)) < -2147483648) Then
          Begin
            EmuFault('depassement de idiv');
            Exit;
          End;
        emu_reg[Ord(R_EAX)] := LongWord((w Div Int64(LongInt(b))) And $FFFFFFFF);
        emu_reg[Ord(R_EDX)] := LongWord((w Mod Int64(LongInt(b))) And $FFFFFFFF);
      End;
    OP_DIV:
      Begin
        b := OpRd(ctx, ins^.a, 4);
        If b = 0 Then
          Begin
            EmuFault('division entiere par zero');
            Exit;
          End;
        w := (Int64(emu_reg[Ord(R_EDX)]) Shl 32) Or Int64(emu_reg[Ord(R_EAX)]);
        If (w Div Int64(b)) > $FFFFFFFF Then
          Begin
            EmuFault('depassement de div');
            Exit;
          End;
        emu_reg[Ord(R_EAX)] := LongWord((w Div Int64(b)) And $FFFFFFFF);
        emu_reg[Ord(R_EDX)] := LongWord((w Mod Int64(b)) And $FFFFFFFF);
      End;
    OP_SHL, OP_SHR, OP_SAR:
      Begin
        sz := OpSz(ins^.a);
        a := OpRd(ctx, ins^.a, sz);
        cnt := OpRd(ctx, ins^.b, 1) And 31;
        If cnt > 0 Then
          Begin
            If ins^.op = OP_SHL Then
              Begin
                w := Int64(a) Shl cnt;
                emu_cf := ((Int64(a) Shr (sz * 8 - cnt)) And 1) <> 0;
                r := LongWord(w And $FFFFFFFF);
              End
            Else If ins^.op = OP_SHR Then
              Begin
                emu_cf := ((a Shr (cnt - 1)) And 1) <> 0;
                r := a Shr cnt;
              End
            Else
              Begin
                emu_cf := ((a Shr (cnt - 1)) And 1) <> 0;
                r := LongWord(LongInt(a) Shr cnt);
                If (a And $80000000) <> 0 Then
                  r := r Or (LongWord($FFFFFFFF) Shl (32 - cnt));
              End;
            emu_of := False;
            SetZS(r, sz);
            OpWr(ctx, ins^.a, r, sz);
          End;
      End;
    OP_JMP:
      emu_pc := emu_lbl[ins^.a.disp];
    OP_JE, OP_JNE, OP_JL, OP_JLE, OP_JG, OP_JGE, OP_JB, OP_JAE, OP_JA, OP_JBE,
    OP_JO, OP_JNO, OP_JS, OP_JNS:
      If EmuCond(ins^.op) Then
        emu_pc := emu_lbl[ins^.a.disp];
    OP_CALL:
      Begin
        If (ins^.a.kind = OD_ADDR) And
           (SymAddr(ctx, ins^.a.symkind, ins^.a.sym) = 0) Then
          EmuFault('symbole non resolu : ' + SymNameOf(ctx, ins^.a.symkind, ins^.a.sym))
        Else If ins^.a.kind = OD_ADDR Then
          EmuCall(SymAddr(ctx, ins^.a.symkind, ins^.a.sym), EMU_CODE + 4 * LongWord(emu_pc))
        Else
          EmuCall(OpRd(ctx, ins^.a, 4), EMU_CODE + 4 * LongWord(emu_pc));
      End;
    OP_RET:
      Begin
        r := EmuPop;
        If r = EMU_HALTADDR Then
          emu_halt := True
        Else If (r < EMU_CODE) Or (r >= EMU_TRAP) Then
          EmuFault('retour vers une adresse invalide ' + HexU(r))
        Else
          emu_pc := (r - EMU_CODE) Div 4;
      End;
    OP_LEAVE:
      Begin
        emu_reg[Ord(R_ESP)] := emu_reg[Ord(R_EBP)];
        emu_reg[Ord(R_EBP)] := EmuPop;
      End;
    OP_REP_MOVSB:
      Begin
        si := emu_reg[Ord(R_ESI)];
        di := emu_reg[Ord(R_EDI)];
        cx := emu_reg[Ord(R_ECX)];
        While (cx > 0) And Not emu_halt Do
          Begin
            MemWr(di, MemRd(si, 1), 1);
            Inc(si);
            Inc(di);
            Dec(cx);
          End;
        emu_reg[Ord(R_ESI)] := si;
        emu_reg[Ord(R_EDI)] := di;
        emu_reg[Ord(R_ECX)] := cx;
      End;
  Else
    EmuFault('instruction non emulee : ' + OpName(ins^.op));
  End;
End;

{ Charge le programme et l'execute depuis _JSSTART. Retourne le code de
  sortie. }
Function RunEmulator(Var ctx: TCompilerContext): LongInt;
Var
  i, start_idx: LongInt;
  nm: TString;
  d: LongInt;
  rdsz, a: LongWord;
  names_done: Boolean;
Begin
  RunEmulator := 1;
  emu_ctx := @ctx;
  GetMem(emu_mem, EMU_MEM_SIZE);
  FillChar(emu_mem^, EMU_MEM_SIZE, 0);
  FillChar(emu_reg, SizeOf(emu_reg), 0);
  emu_halt := False;
  emu_exit := 0;
  emu_fault_msg := '';
  emu_steps := 0;
  emu_zf := False;
  emu_sf := False;
  emu_cf := False;
  emu_of := False;
  emu_rd_base := EMU_BASE + $10000;
  rdsz := (ctx.data.rd_size + $FFF) And $FFFFF000;
  emu_dt_base := emu_rd_base + rdsz + $1000;
  emu_brk := EMU_HEAP;
  emu_iat_next := EMU_BASE + $1000;
  If ctx.data.rd_size > 0 Then
    Move(ctx.data.rd[0], emu_mem^[emu_rd_base - EMU_BASE], ctx.data.rd_size);
  If ctx.data.dt_size > 0 Then
    Move(ctx.data.dt[0], emu_mem^[emu_dt_base - EMU_BASE], ctx.data.dt_size);

  { etiquettes et procedures }
  FillChar(emu_lbl, SizeOf(emu_lbl), 0);
  FillChar(emu_xaddr, SizeOf(emu_xaddr), 0);
  For i := 1 To ctx.ir.count Do
    Begin
      If ctx.ir.instrs[i].op = OP_LABEL Then
        emu_lbl[ctx.ir.instrs[i].a.disp] := i
      Else If ctx.ir.instrs[i].op = OP_PROC Then
        emu_xaddr[ctx.ir.instrs[i].a.sym] := EMU_CODE + 4 * LongWord(i);
    End;
  { symboles externes : donnees du pool par leur nom, appels systeme }
  For i := 1 To ctx.ir.xsym_count Do
    If emu_xaddr[i] = 0 Then
      Begin
        nm := ctx.ir.xsyms[i].name;
        d := DsymFind(ctx, nm);
        If d <> 0 Then
          emu_xaddr[i] := DsymAddr(ctx, d)
        Else If Copy(nm, 1, 6) = '__imp_' Then
          Begin
            { cellule de la table d'import pointant vers un piege }
            a := 0;
            If nm = '__imp__VirtualAlloc@16' Then a := 1
            Else If nm = '__imp__ExitProcess@4' Then a := 2
            Else If nm = '__imp__GetStdHandle@4' Then a := 3
            Else If nm = '__imp__WriteFile@20' Then a := 4
            Else If nm = '__imp__ReadFile@20' Then a := 5;
            If a <> 0 Then
              Begin
                MemWr(emu_iat_next, EMU_TRAP + 4 * a, 4);
                emu_xaddr[i] := emu_iat_next;
                emu_iat_next := emu_iat_next + 4;
              End;
          End;
      End;
  { relocations }
  For i := 1 To ctx.data.reloc_count Do
    Begin
      If ctx.data.relocs[i].tkind = SYMK_D Then
        a := DsymAddr(ctx, ctx.data.relocs[i].target)
      Else
        a := emu_xaddr[ctx.data.relocs[i].target];
      If ctx.data.relocs[i].sec = SEC_RDATA Then
        MemWr(emu_rd_base + ctx.data.relocs[i].ofs, a, 4)
      Else
        MemWr(emu_dt_base + ctx.data.relocs[i].ofs, a, 4);
    End;

  d := XSym(ctx, '_JSSTART');
  If emu_xaddr[d] = 0 Then
    Begin
      Writeln('JSCW32: _JSSTART introuvable');
      Exit;
    End;
  start_idx := (emu_xaddr[d] - EMU_CODE) Div 4;
  emu_pc := start_idx;
  emu_reg[Ord(R_ESP)] := EMU_STACK;
  EmuPush(EMU_HALTADDR);
  While Not emu_halt Do
    Begin
      Inc(emu_steps);
      If emu_steps > EMU_STEPLIMIT Then
        EmuFault('limite d''instructions depassee')
      Else
        EmuStep(ctx);
    End;
  If emu_fault_msg <> '' Then
    Begin
      Writeln;
      Writeln('JSCW32: erreur d''emulation : ', emu_fault_msg, ' (instruction ',
              emu_pc - 1, ', ligne ', ctx.ir.instrs[emu_pc - 1].line, ')');
      RunEmulator := 3;
    End
  Else
    RunEmulator := emu_exit;
  FreeMem(emu_mem, EMU_MEM_SIZE);
End;

{ Les etapes sont implementees par les TODO suivants. Tant qu'une etape
  n'existe pas, elle echoue explicitement au lieu de produire un faux
  resultat. }
Function RunStage(Var ctx: TCompilerContext; stage: TCompileStage): Boolean;
Var
  ok: Boolean;
Begin
  Case stage Of
    CS_LOAD_SOURCE:
      RunStage := LoadSource(ctx);
    CS_LEX_TOKENS:
      Begin
        RunStage := LexSource(ctx);
        If ctx.options.dump_tokens Then
          DumpTokens(ctx);
      End;
    CS_PARSE_AST:
      Begin
        ok := ParseProgram(ctx);
        RunStage := ok;
        { si l'analyse suit, l'AST est affiche annote apres elle }
        If ctx.options.dump_ast And Not ok Then
          DumpAst(ctx);
      End;
    CS_BUILD_IR:
      Begin
        ok := BuildIR(ctx);
        RunStage := ok;
        If ctx.options.dump_ir Then
          DumpIR(ctx);
        If ctx.options.dump_scopes And ctx.ir.built Then
          DumpScopes(ctx);
      End;
    CS_ANALYZE:
      Begin
        ok := AnalyzeProgram(ctx);
        If ok Then
          ok := BuildRuntimeModel(ctx);
        If ok Then
          ok := BuildDataPool(ctx);
        RunStage := ok;
        If ctx.options.dump_scopes Then
          DumpScopes(ctx);
        If ctx.options.dump_ast And ctx.ast.analyzed Then
          DumpAst(ctx);
        If ctx.options.dump_runtime Then
          DumpRuntimeModel(ctx);
        If ctx.options.dump_data Then
          DumpDataPool(ctx);
      End;
  Else
    Begin
      PipelineError(ctx, 'etape pipeline non implementee: ' + StageName(stage));
      RunStage := False;
    End;
  End;
End;

Function RunPipeline(Var ctx: TCompilerContext): Boolean;
Var
  s: TCompileStage;
  done: Boolean;
Begin
  RunPipeline := False;
  done := False;
  s := CS_LOAD_SOURCE;
  While Not done Do
    Begin
      ctx.stage := s;
      If ctx.options.verbose Then
        Writeln('Etape ', StageName(s), ' -> ',
                ArtifactName(StageOutputArtifact(s)));
      If Not RunStage(ctx, s) Then
        Exit;
      ctx.last_art := StageOutputArtifact(s);
      If ctx.options.verbose And ArtifactIsPersisted(ctx, ctx.last_art) Then
        Writeln('  ecriture sur disque: ', ArtifactName(ctx.last_art));
      If (ctx.last_art = PipelineTargetArtifact(ctx)) Or (s = CS_LINK_EXE) Then
        done := True
      Else
        s := Succ(s);
    End;
  RunPipeline := ctx.errors = 0;
End;

Procedure PrintFinalDiagnostics(Var ctx: TCompilerContext);
Begin
  Writeln('Resultat: ', ArtifactName(ctx.last_art));
  Writeln('Erreurs : ', ctx.errors);
  Writeln('Warnings: ', ctx.warnings);
End;

Var
  ctx: TCompilerContext;
  parse_result: Integer;

BEGIN
  InitPipelineDefaults(ctx);
  parse_result := ParseArgs(ctx);

  If ctx.options.show_help Then
    Begin
      PrintUsage;
      Halt(EXIT_OK);
    End;

  If ctx.options.show_version Then
    Begin
      Writeln('JSCW32 ', JSCW32_VERSION, ' (', JSCW32_DATE, ')');
      Halt(EXIT_OK);
    End;

  If parse_result <> EXIT_OK Then
    Begin
      Writeln('Essayez: jscw32 -h');
      Halt(parse_result);
    End;

  { -runtime sans fichier source : decrit seulement le modele }
  If ctx.options.dump_runtime And (ctx.source_name = '') Then
    Begin
      DumpRuntimeModel(ctx);
      Halt(EXIT_OK);
    End;

  If ctx.options.verbose Then
    Begin
      PrintPipeline;
      PrintOptions(ctx);
    End;

  If Not RunPipeline(ctx) Then
    Halt(EXIT_ERROR);

  If ctx.options.run Then
    Halt(RunEmulator(ctx));

  If ctx.options.verbose Then
    PrintFinalDiagnostics(ctx);
  Halt(EXIT_OK);
END.
