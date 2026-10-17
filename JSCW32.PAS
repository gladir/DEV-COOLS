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
  09. [A FAIRE] Generer le code 80386 pour les variables et leur portee : globales, locales sur cadre EBP, parametres, cellules heap pour les variables capturees, initialisation a undefined, TDZ de let/const, affectation, declarations multiples et destructuration, compatibilite avec hello.js, test03/test03b, test04/test04b et test09.
  10. [A FAIRE] Generer les expressions et les conversions de types JavaScript : arithmetique (+ - * / % **), division par zero (Infinity/NaN), comparaisons, == (coercition) vs === (strict), ToNumber/ToString/ToBoolean/ToPrimitive, truthy/falsy, court-circuit && || ??, ternaire, operateurs bit a bit et decalages, ++/-- pre/post, affectations composees, typeof/void/delete/in/instanceof, compatibilite avec test10/test10adv, test11/test11adv, t04_12, t09_15 et t09full.
  11. [A FAIRE] Generer les structures de controle : if/else if/else, switch/case (egalite stricte, fall-through, default), while, do-while, for, for-in, for-of (tableaux et chaines), break/continue simples et etiquetes, labels internes uniques et sauts 80386 fiables, avec control.js, test13 et test14.
  12. [A FAIRE] Implementer les fonctions : declarations (hoistees), expressions, fonctions fleches (corps expression ou bloc), convention d'appel interne (arguments, this, environnement de closure, nombre d'arguments), recursion (factorial/fib de math.js), return sans valeur -> undefined, parametres par defaut/rest/spread, objet arguments, fonctions de premier ordre (callbacks, apply(f, v)), operateur de reference &fn supporte par test22.js, avec test17 et test18.
  13. [A FAIRE] Implementer les closures et le this lexical : environnements captures (cellules partagees entre fonctions), duree de vie apres le retour de la fonction englobante, fonctions imbriquees, fleches capturant this, makeCounter/makeAdder/makeMultiplier, variable modifiee apres creation de la closure (test22.js) et profondeur d'imbrication (test18.js).
  14. [A FAIRE] Implementer les chaines : allocation et concatenation (+), template literals avec interpolation de nombres/chaines/expressions, length, indexation, comparaison, echappements, conversion nombre -> chaine et methodes String (indexOf, lastIndexOf, includes, startsWith, endsWith, charAt, charCodeAt, toUpperCase, toLowerCase, trim, slice, substring, repeat, padStart, split, String.fromCharCode), avec test20.js.
  15. [A FAIRE] Implementer les tableaux : litteraux (imbriques, vides), new Array(n), acces et affectation par index, length, push/pop/shift/unshift, indexOf, reverse, sort (par defaut lexicographique + comparateur), forEach, slice/splice/concat/join/includes/map/filter/reduce, Array.isArray, iteration for-of, avec arrays.js, test10adv, test15 et control.js.
  16. [A FAIRE] Implementer les objets et prototypes : litteraux, acces par point et par crochets, ajout/modification/suppression dynamique de proprietes (table de hachage avec ordre d'insertion), in, hasOwnProperty, chaine de prototypes, getters/setters, Object.keys/values/entries/assign/create/freeze/getPrototypeOf, avec objects.js et test16.
  17. [A FAIRE] Implementer les classes : declaration et expression de classe, constructor, methodes d'instance, methodes statiques, extends, super(...) et super.methode(), new, instanceof, getters/setters, champs, ordre d'initialisation, heritage multi-niveaux (Dog/Cat extends Animal), avec classes.js et test21.js.
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
  StdStrings: Array[1..STD_STR_COUNT] Of String[20] = (
    '', 'undefined', 'null', 'true', 'false', 'NaN', 'Infinity', '-Infinity',
    'object', 'boolean', 'number', 'string', 'function', '[object Object]',
    'length', 'prototype', 'constructor', 'name', 'message', 'toString',
    'valueOf'
  );
  RT_DATA_VAR_COUNT = 12;
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
                 DK_FNAME);

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
    kind  : TScopeKind;
    fkind : TFuncKind;
    in_loop, uses_this, this_captured, uses_arguments, has_nested: Boolean;
  End;

  TSymbol = Record
    name_tok, scope, node, next, flags, refs, writes: LongInt;
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
    rd    : Array[0..MAX_RDATA - 1] Of Byte;
    dt    : Array[0..MAX_DATA_IMG - 1] Of Byte;
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
  If ctx.options.output_mode = OM_OBJ Then
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
      Else If IsIdentStart(c) Then
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
  If (ctx.sem.scopes[sc].func = 1) And Not ctx.sem.scopes[sc].in_loop Then
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
  sy := LookupSymbol(ctx, name);
  If sy = 0 Then
    Begin
      If name = 'arguments' Then
        Begin
          prov := NearestNonArrow(ctx);
          If ctx.sem.scopes[prov].kind = SK_FUNCTION Then
            Begin
              ctx.sem.scopes[prov].uses_arguments := True;
              ctx.ast.nodes[n].aux := RK_ARGUMENTS;
              Exit;
            End;
        End;
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
  6 array, 7 function, 8 regexp, 9 marque TDZ (interne). Un nombre est donc soit un double,
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
          Else If ctx.ast.nodes[i].aux = RK_ARGUMENTS Then
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
  For b := RT_T_INT32 To RT_T_TDZ Do
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

Function NewDataSym(Var ctx: TCompilerContext; Const name: TString;
                    sec: Integer; ofs, size: LongInt; kind: Integer): LongInt;
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
  ctx.data.relocs[ctx.data.reloc_count].ofs := ofs;
  ctx.data.relocs[ctx.data.reloc_count].target := target;
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

  If ctx.options.verbose Then
    PrintFinalDiagnostics(ctx);
  Halt(EXIT_OK);
END.
