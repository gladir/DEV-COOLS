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
  04. [A FAIRE] Parser les instructions : var/let/const (avec destructuration simple), blocs, if/else if/else, switch/case/default, while, do-while, for, for-in, for-of, break/continue (avec etiquettes), return, throw, try/catch/finally, declarations function et class, instructions vides/expressions, insertion automatique des points-virgules (ASI) et hoisting des declarations.
  05. [A FAIRE] Parser les expressions avec precedences et associativites exactes : virgule, affectations (= += -= *= /= %= **= <<= >>= >>>= &= |= ^= &&= ||= ??=), ternaire, ?? || &&, bit a bit, ==/!=/===/!==, relationnels (instanceof, in), decalages, + -, * / %, **, unaires (typeof void delete ! ~ + - ++ --), postfixes, appels/membres/new, optional chaining, spread/rest, fonctions anonymes, fonctions fleches (x => x*2, (a,b) => corps de bloc), litteraux de tableaux et d'objets (raccourcis, cles calculees, methodes, getters/setters), parametres par defaut.
  06. [A FAIRE] Construire l'AST et l'analyse semantique : table des symboles et des scopes (global, fonction, bloc), hoisting de var/function, zone morte temporelle (TDZ) de let/const, erreur sur reaffectation d'une const, detection des variables capturees par des fonctions imbriquees (necessaire aux closures), resolution de this (global, methode, constructeur, fleche) et diagnostics de redeclaration/variable non declaree.
  07. [A FAIRE] Definir le modele de valeurs runtime 32 bits et le gestionnaire memoire : valeurs etiquetees (undefined, null, booleen, nombre, chaine, objet, tableau, fonction/closure, RegExp), nombres IEEE 754 via FPU x87 avec chemin rapide entier, allocation sur le tas Windows (HeapAlloc/VirtualAlloc), tampons de chaines, pile d'appels, et ramasse-miettes simple (mark & sweep) ou strategie documentee de non-liberation.
  08. [A FAIRE] Implementer le pool de constantes et de donnees : chaines litterales internees, constantes flottantes, atomes de noms de proprietes, descripteurs de fonctions/classes, sections .data/.rdata, alignement et noms de symboles stables prefixes (variables, fonctions, chaines, runtime, labels).
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

{ Les etapes sont implementees par les TODO suivants. Tant qu'une etape
  n'existe pas, elle echoue explicitement au lieu de produire un faux
  resultat. }
Function RunStage(Var ctx: TCompilerContext; stage: TCompileStage): Boolean;
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
