{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur JavaScript vers assembleur 80386, 32 bits, pour Windows 32 bits.

  TODO - feuille de route JSCW32.PAS
  01. [IMPLEMENTE] Definir le pipeline canonique .JS -> tokens -> AST -> analyse semantique -> IR -> ASM 80386 -> OBJ COFF -> EXE PE32, avec .EXE Windows produit par defaut ; l'ASM n'est qu'une etape intermediaire optionnelle (jamais ecrite sur disque sans demande explicite).
  02. [IMPLEMENTE] Ajouter le parsing des options de ligne de commande : mode EXE par defaut, parametre pour produire uniquement un .OBJ (sans edition de liens), parametre explicite pour emettre aussi le .ASM, noms de sortie (-o), mode verbose, aide/version, et regles de nommage par defaut (HELLO.JS -> HELLO.EXE / HELLO.OBJ / HELLO.ASM).
  03. [A FAIRE] Implementer le chargeur source et le lexer JavaScript complet : normalisation CR/LF, suivi ligne/colonne, diagnostics avec caret, identifiants, mots-cles (var/let/const/function/class/extends/super/new/this/typeof/void/instanceof/in/of/try/catch/finally/throw...), nombres (decimal, flottant, exposant 1.5e3, hexa 0xFF, binaire 0b1010, octal, separateurs 1_000_000), chaines '...' et "..." avec echappements, template literals avec interpolation (dollar-accolade), litteraux RegExp /re/flags (desambiguises de la division), commentaires // et /* */, tous les operateurs (=== !== ** ?? ?. => ... >>> et affectations composees) et NaN/Infinity/null/undefined/true/false.
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

Type
  TString = String[MAX_PATH_LEN];

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
    output_name : TString;
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
  End;

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
          ctx.options.output_name := ParamStr(i);
        End
      Else If (Length(arg) > 0) And ((arg[1] = '-') Or (arg[1] = '/')) Then
        Begin
          Writeln('JSCW32: option inconnue: ', arg);
          ParseArgs := EXIT_USAGE;
          Exit;
        End
      Else If ctx.source_name = '' Then
        ctx.source_name := arg
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

{ Les etapes sont implementees par les TODO suivants. Tant qu'une etape
  n'existe pas, elle echoue explicitement au lieu de produire un faux
  resultat. }
Function RunStage(Var ctx: TCompilerContext; stage: TCompileStage): Boolean;
Begin
  PipelineError(ctx, 'etape pipeline non implementee: ' + StageName(stage));
  RunStage := False;
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
