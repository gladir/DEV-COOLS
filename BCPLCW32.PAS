{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur BCPL vers assembleur 80386, 32 bits, pour Windows 32 bits.
}

{TODO BCPLCW32.PAS:
1. Définir précisément le pipeline du compilateur : source .b -> tokens -> AST/intermédiaire -> ASM 80386 -> OBJ -> EXE Win32.
2. Ajouter la gestion des paramètres de ligne de commande : fichier source, nom de sortie, mode par défaut .EXE, option .OBJ seule, option explicite pour conserver/générer le .ASM.
3. Définir les conventions de fichiers : extension .b en entrée, .asm optionnel, .obj intermédiaire ou final, .exe par défaut.
4. Implémenter le scanner lexical BCPL : identifiants, nombres entiers, chaînes, commentaires //, opérateurs, ponctuation, mots-clés.
5. Supporter les chaînes BCPL avec séquences spéciales utilisées par les exemples : *N, *T, *", **.
6. Créer une table des mots-clés BCPL : LET, BE, VALOF, RESULTIS, STATIC, IF, UNLESS, TEST, THEN, ELSE, FOR, TO, BY, WHILE, UNTIL, REPEAT, REPEATWHILE, BREAK, SWITCHON, INTO, CASE, DEFAULT, ENDCASE, FINISH.
7. Implémenter un parseur récursif descendant pour les blocs BCPL $( ... $).
8. Parser les déclarations globales LET name(...) BE ... pour les procédures.
9. Parser les déclarations globales LET name(...) = expression pour les fonctions retournant une valeur.
10. Parser les déclarations locales LET variable = expression.
11. Parser les blocs STATIC $( name = value ... $) et générer des symboles globaux initialisés.
12. Construire une table des symboles séparant fonctions, procédures, variables locales, paramètres et statiques.
13. Définir une convention d’appel 32 bits interne : passage des paramètres, valeur de retour dans EAX, sauvegarde/restauration des registres nécessaires.
14. Corriger dès le départ le support multi-paramètres, car les exemples actuels contournent déjà un problème ABI avec les seconds paramètres.
15. Générer les prologues/épilogues de fonctions Win32 32 bits : pile, frame pointer, variables locales, retour propre.
16. Implémenter l’évaluation des expressions entières : +, -, *, division si prévue, MOD, unaire -, parenthèses, appels de fonctions.
17. Implémenter les comparaisons : =, ~=, <, <=, >, >=, avec résultat booléen exploitable par les branchements.
18. Implémenter l’expression conditionnelle BCPL cond -> exprTrue, exprFalse.
19. Implémenter VALOF $( ... RESULTIS expr ... $) comme bloc expression avec sortie contrôlée.
20. Générer le code des affectations := pour variables locales, paramètres modifiables si accepté, et statiques.
21. Implémenter les structures de contrôle : IF ... DO, UNLESS ... DO, TEST ... THEN ... ELSE ....
22. Implémenter les boucles : FOR ... TO ... DO, FOR ... TO ... BY ... DO, WHILE, UNTIL, REPEAT ... REPEATWHILE, avec gestion correcte de BREAK.
23. Implémenter SWITCHON expr INTO $( CASE n: ... DEFAULT: ... ENDCASE ... $) avec fall-through contrôlé et sortie par ENDCASE.
24. Fournir une petite bibliothèque runtime Win32 pour WRITES, WRITEN, WRITECH, NEWLINE, FINISH, en s’appuyant sur les API console Windows ou des imports C/Win32.
25. Créer une suite de validation automatique compilant et exécutant SAMPLES\BCPL\hello.b, fib.b, func.b, loops.b, switchon.b, avec comparaison des sorties attendues et tests des modes .EXE, .OBJ et .ASM optionnel.
}
Program BCPLCW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-} { Desactiver les IO-check pour gerer nous-memes les erreurs }

{ ============================================================
  INFRASTRUCTURE DE BASE
  ============================================================ }

Const
  BCPLCW32_VERSION = '1.0';
  BCPLCW32_DATE    = '2026';
  MAX_PATH_LEN     = 255;
  EXIT_OK          = 0;
  EXIT_ERROR       = 1;
  EXIT_USAGE       = 2;

Type
  TString = String[MAX_PATH_LEN];

  { TODO 1 - Pipeline canonique du compilateur.

    Le compilateur BCPLCW32 est organise comme une suite d'etapes
    explicites. Chaque etape consomme l'artefact de l'etape precedente
    et produit le suivant :

      .b source BCPL
        -> flux de tokens
        -> AST / representation intermediaire BCPL
        -> assembleur 80386 Win32
        -> objet COFF 32 bits
        -> executable PE Win32

    Par defaut, le pipeline va jusqu'a l'executable. Les TODO 2 et 3
    brancheront les options permettant de s'arreter a l'OBJ et de
    conserver explicitement l'ASM.
  }
  TCompileStage = (
    CS_LOAD_SOURCE,
    CS_LEX_TOKENS,
    CS_PARSE_AST,
    CS_EMIT_ASM386,
    CS_BUILD_OBJ,
    CS_LINK_EXE
  );

  TArtifactKind = (
    AK_NONE,
    AK_SOURCE_BCPL,
    AK_TOKEN_STREAM,
    AK_AST_IR,
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
    keep_asm    : Boolean;
    verbose     : Boolean;
    output_name : TString;
  End;

  TCompilerContext = Record
    source_name : TString;
    asm_name    : TString;
    obj_name    : TString;
    exe_name    : TString;
    options     : TPipelineOptions;
    last_art    : TArtifactKind;
    errors      : Integer;
  End;

Function StageName(stage : TCompileStage) : TString;
Begin
  Case stage Of
    CS_LOAD_SOURCE: StageName := 'chargement source .b';
    CS_LEX_TOKENS : StageName := 'analyse lexicale -> tokens';
    CS_PARSE_AST  : StageName := 'analyse syntaxique -> AST/IR';
    CS_EMIT_ASM386: StageName := 'generation assembleur 80386 Win32';
    CS_BUILD_OBJ  : StageName := 'assemblage -> objet COFF 32 bits';
    CS_LINK_EXE   : StageName := 'edition de liens -> executable PE Win32';
  Else
    StageName := 'etape inconnue';
  End;
End;

Function ArtifactName(artifact : TArtifactKind) : TString;
Begin
  Case artifact Of
    AK_NONE        : ArtifactName := 'aucun artefact';
    AK_SOURCE_BCPL : ArtifactName := 'source BCPL .b';
    AK_TOKEN_STREAM: ArtifactName := 'flux de tokens';
    AK_AST_IR      : ArtifactName := 'AST/IR BCPL';
    AK_ASM_386     : ArtifactName := 'assembleur 80386 Win32';
    AK_OBJ_COFF    : ArtifactName := 'objet COFF 32 bits';
    AK_EXE_PE32    : ArtifactName := 'executable PE Win32';
  Else
    ArtifactName := 'artefact inconnu';
  End;
End;

Function UpChar(c : Char) : Char;
Begin
  If (c >= 'a') And (c <= 'z') Then
    UpChar := Chr(Ord(c) - 32)
  Else
    UpChar := c;
End;

Function StrUpper(Const s : TString) : TString;
Var
  i : Integer;
  r : TString;
Begin
  r := s;
  For i := 1 To Length(r) Do
    r[i] := UpChar(r[i]);
  StrUpper := r;
End;

Function SameText(Const a, b : TString) : Boolean;
Begin
  SameText := StrUpper(a) = StrUpper(b);
End;

Function ChangeExtension(Const file_name, new_ext : TString) : TString;
Var
  i : Integer;
  r : TString;
Begin
  r := file_name;
  i := Length(r);
  While (i > 0) And (r[i] <> '.') And (r[i] <> '\') And (r[i] <> '/') Do
    Dec(i);

  If (i > 0) And (r[i] = '.') Then
    r := Copy(r, 1, i - 1);

  If (new_ext <> '') And (new_ext[1] = '.') Then
    ChangeExtension := r + new_ext
  Else
    ChangeExtension := r + '.' + new_ext;
End;

Function FileExtension(Const file_name : TString) : TString;
Var
  i : Integer;
Begin
  i := Length(file_name);
  While (i > 0) And (file_name[i] <> '.') And
        (file_name[i] <> '\') And (file_name[i] <> '/') Do
    Dec(i);

  If (i > 0) And (file_name[i] = '.') Then
    FileExtension := StrUpper(Copy(file_name, i, Length(file_name) - i + 1))
  Else
    FileExtension := '';
End;

Function OutputModeName(mode : TOutputMode) : TString;
Begin
  Case mode Of
    OM_EXE: OutputModeName := 'EXE Win32';
    OM_OBJ: OutputModeName := 'OBJ COFF';
  Else
    OutputModeName := 'mode inconnu';
  End;
End;

Procedure InitDefaultOptions(Var options : TPipelineOptions);
Begin
  options.output_mode := OM_EXE;
  options.keep_asm    := False;
  options.verbose     := True;
  options.output_name := '';
End;

Procedure ShowUsage; Forward;
Procedure UsageError(Const msg : TString); Forward;

Procedure DeriveOutputNames(Var ctx : TCompilerContext);
Var
  main_out : TString;
  ext      : TString;
Begin
  If ctx.options.output_name <> '' Then
    main_out := ctx.options.output_name
  Else If ctx.options.output_mode = OM_OBJ Then
    main_out := ChangeExtension(ctx.source_name, '.obj')
  Else
    main_out := ChangeExtension(ctx.source_name, '.exe');

  ext := FileExtension(main_out);
  If ctx.options.output_mode = OM_OBJ Then
  Begin
    If ext = '' Then
      main_out := main_out + '.obj'
    Else If ext <> '.OBJ' Then
      UsageError('avec -obj, la sortie principale doit etre un fichier .OBJ: ' + main_out);
  End
  Else
  Begin
    If ext = '' Then
      main_out := main_out + '.exe'
    Else If ext <> '.EXE' Then
      UsageError('par defaut, la sortie principale doit etre un fichier .EXE: ' + main_out);
  End;

  If ctx.options.output_mode = OM_OBJ Then
  Begin
    ctx.obj_name := main_out;
    ctx.exe_name := '';
    ctx.asm_name := ChangeExtension(main_out, '.asm');
  End
  Else
  Begin
    ctx.exe_name := main_out;
    ctx.obj_name := ChangeExtension(main_out, '.obj');
    ctx.asm_name := ChangeExtension(main_out, '.asm');
  End;
End;

Procedure InitCompilerContext(Var ctx : TCompilerContext);
Begin
  ctx.source_name := '';
  ctx.asm_name    := '';
  ctx.obj_name    := '';
  ctx.exe_name    := '';
  InitDefaultOptions(ctx.options);
  ctx.last_art    := AK_NONE;
  ctx.errors      := 0;
End;

Procedure UsageError(Const msg : TString);
Begin
  WriteLn('Erreur: ', msg);
  WriteLn;
  ShowUsage;
  Halt(EXIT_USAGE);
End;

Procedure ValidateFileConventions(Var ctx : TCompilerContext);
Var
  src_ext : TString;
Begin
  src_ext := FileExtension(ctx.source_name);
  If src_ext = '' Then
    UsageError('le fichier source doit porter l''extension .b: ' + ctx.source_name);
  If src_ext <> '.B' Then
    UsageError('extension source invalide, .b attendu: ' + ctx.source_name);

  DeriveOutputNames(ctx);
End;

Procedure ParseCommandLine(Var ctx : TCompilerContext);
Var
  i   : Integer;
  arg : TString;
Begin
  If ParamCount < 1 Then
  Begin
    ShowUsage;
    Halt(EXIT_USAGE);
  End;

  i := 1;
  While i <= ParamCount Do
  Begin
    arg := ParamStr(i);

    If SameText(arg, '-h') Or SameText(arg, '--help') Or
       SameText(arg, '/?') Or SameText(arg, '/h') Then
    Begin
      ShowUsage;
      Halt(EXIT_OK);
    End
    Else If SameText(arg, '-obj') Or SameText(arg, '/obj') Then
      ctx.options.output_mode := OM_OBJ
    Else If SameText(arg, '-asm') Or SameText(arg, '/asm') Then
      ctx.options.keep_asm := True
    Else If SameText(arg, '-v') Or SameText(arg, '/v') Then
      ctx.options.verbose := True
    Else If SameText(arg, '-q') Or SameText(arg, '/q') Then
      ctx.options.verbose := False
    Else If SameText(arg, '-o') Or SameText(arg, '/o') Then
    Begin
      Inc(i);
      If i > ParamCount Then
        UsageError('option -o sans nom de fichier');
      If ctx.options.output_name <> '' Then
        UsageError('nom de sortie deja specifie: ' + ctx.options.output_name);
      ctx.options.output_name := ParamStr(i);
    End
    Else If (Length(arg) > 0) And ((arg[1] = '-') Or (arg[1] = '/')) Then
      UsageError('option inconnue: ' + arg)
    Else If ctx.source_name = '' Then
      ctx.source_name := arg
    Else If ctx.options.output_name = '' Then
      ctx.options.output_name := arg
    Else
      UsageError('argument inattendu: ' + arg);

    Inc(i);
  End;

  If ctx.source_name = '' Then
    UsageError('aucun fichier source BCPL specifie');

  ValidateFileConventions(ctx);
End;

Procedure TraceStage(Const ctx : TCompilerContext; stage : TCompileStage);
Begin
  If ctx.options.verbose Then
    WriteLn('BCPLCW32: ', StageName(stage));
End;

Function RunStage(Var ctx : TCompilerContext; stage : TCompileStage) : Boolean;
Begin
  TraceStage(ctx, stage);

  Case stage Of
    CS_LOAD_SOURCE: ctx.last_art := AK_SOURCE_BCPL;
    CS_LEX_TOKENS : ctx.last_art := AK_TOKEN_STREAM;
    CS_PARSE_AST  : ctx.last_art := AK_AST_IR;
    CS_EMIT_ASM386: ctx.last_art := AK_ASM_386;
    CS_BUILD_OBJ  : ctx.last_art := AK_OBJ_COFF;
    CS_LINK_EXE   : ctx.last_art := AK_EXE_PE32;
  End;

  { Les etapes seront implementees par les TODO suivantes. Pour l'instant,
    la TODO 1 fixe seulement l'ordre et les contrats d'artefacts. }
  RunStage := True;
End;

Function RunCompilerPipeline(Var ctx : TCompilerContext) : Boolean;
Begin
  RunCompilerPipeline := False;

  If Not RunStage(ctx, CS_LOAD_SOURCE) Then Exit;
  If Not RunStage(ctx, CS_LEX_TOKENS) Then Exit;
  If Not RunStage(ctx, CS_PARSE_AST) Then Exit;
  If Not RunStage(ctx, CS_EMIT_ASM386) Then Exit;
  If Not RunStage(ctx, CS_BUILD_OBJ) Then Exit;

  If ctx.options.output_mode = OM_EXE Then
    If Not RunStage(ctx, CS_LINK_EXE) Then Exit;

  RunCompilerPipeline := ctx.errors = 0;
End;

Procedure ShowUsage;
Begin
  WriteLn('BCPLCW32 ', BCPLCW32_VERSION, ' - Cette commande permet de lancer le compilateur BCPL vers l''assembleur du ',
          'microprocesseur 80386 pour Windows 32 bits (Win32 PE).');
  WriteLn;
  WriteLn('Syntaxe: BCPLCW32 fichier.b [sortie] [options]');
  WriteLn;
  WriteLn('Options de sortie:');
  WriteLn('  -obj           Produire seulement un fichier .OBJ COFF');
  WriteLn('  -asm           Produire/conserver explicitement un fichier .ASM lisible');
  WriteLn('  -o <fichier>   Nom de la sortie principale (.EXE par defaut, .OBJ avec -obj)');
  WriteLn('                 Sans extension, .EXE ou .OBJ est ajoute selon le mode');
  WriteLn;
  WriteLn('Options generales:');
  WriteLn('  -v             Mode verbeux');
  WriteLn('  -q             Mode silencieux');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Pipeline defini: .b -> tokens -> AST/IR -> .asm 80386 -> .obj COFF -> .exe PE32');
  WriteLn;
  WriteLn('Exemples:');
  WriteLn('  BCPLCW32 SAMPLES\BCPL\hello.b');
  WriteLn('  BCPLCW32 SAMPLES\BCPL\hello.b -asm');
  WriteLn('  BCPLCW32 SAMPLES\BCPL\hello.b -obj -o hello.obj');
End;

Var
  ctx : TCompilerContext;

 BEGIN
  InitCompilerContext(ctx);
  ParseCommandLine(ctx);

  If RunCompilerPipeline(ctx) Then
  Begin
    WriteLn('Pipeline defini jusqu''a: ', ArtifactName(ctx.last_art));
    WriteLn('Mode  : ', OutputModeName(ctx.options.output_mode));
    WriteLn('Source: ', ctx.source_name);
    If ctx.options.keep_asm Then
      WriteLn('ASM   : ', ctx.asm_name);
    WriteLn('OBJ   : ', ctx.obj_name);
    If ctx.options.output_mode = OM_EXE Then
      WriteLn('EXE   : ', ctx.exe_name);
    WriteLn('TODO suivante: implementer le scanner lexical BCPL.');
  End
  Else
  Begin
    WriteLn('Compilation arretee avec ', ctx.errors, ' erreur(s).');
    Halt(EXIT_ERROR);
  End;
  Halt(EXIT_OK);
END.
