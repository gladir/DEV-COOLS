{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur PL/1 vers assembleur 80386, 32 bits, pour Windows 32 bits.
}

{TODO PL1CW32.PAS:
1. [IMPLEMENTE] Definir le pipeline canonique du compilateur : source .PLI/.PL1 -> tokens -> AST/intermediaire -> assembleur 80386 -> OBJ COFF -> EXE PE Win32.
2. [IMPLEMENTE] Ajouter les options de ligne de commande : fichier source, -o sortie, mode par defaut .EXE, -obj pour produire seulement un .OBJ, -asm pour generer/conserver explicitement le .ASM, -v, -h.
3. Definir les conventions de fichiers : accepter SAMPLES\PL1\*.PLI, produire .EXE par defaut, produire .OBJ final avec -obj, ne produire .ASM que si -asm est demande.
4. Mettre en place l'infrastructure commune : lecture source, suivi ligne/colonne, messages d'erreur clairs, codes de sortie, limites internes compatibles Turbo Pascal 7 et Free Pascal 3.2.
5. Implementer le scanner lexical PL/1 : identifiants, mots-cles, entiers, chaines, commentaires /* ... */, operateurs, parentheses, virgules, deux-points, points-virgules.
6. Construire la table des mots-cles necessaires aux exemples : PROCEDURE, OPTIONS, MAIN, DECLARE, FIXED, BINARY, INITIAL, STATIC, RETURNS, RETURN, DO, TO, END, PUT, LIST, SKIP, SELECT, WHEN, OTHERWISE, GOTO.
7. Parser les etiquettes PL/1 de procedure et de controle : MAIN:, ABSVAL:, FIN:, avec resolution des references avant/arriere pour GOTO.
8. Parser les declarations PROCEDURE, y compris OPTIONS(MAIN), listes de parametres, RETURNS(FIXED BINARY), corps de procedure et END nom optionnel.
9. Construire une table des symboles avec portees : procedures, parametres, variables locales, variables STATIC, tableaux, etiquettes et symboles runtime.
10. Parser les declarations DECLARE simples : FIXED BINARY, INITIAL(expr), STATIC, declarations multiples si ajoutees plus tard, et diagnostics de redeclaration.
11. Supporter les tableaux PL/1 unidimensionnels utilises par TEST2.PLI : DECLARE TAB(10) FIXED BINARY STATIC, indexation TAB(I), bornes 1..N.
12. Definir la representation 32 bits des types minimaux : FIXED BINARY comme entier signe 32 bits, tableaux d'entiers 32 bits, valeurs de retour dans EAX.
13. Implementer le parseur d'expressions avec precedence : litteraux, variables, tableaux, parentheses, appels, unaire -, *, / si prevu, +, -, comparaisons.
14. Implementer les built-ins requis : ABS, MAX, MIN, MOD, avec evaluation correcte dans les expressions et preparation a d'autres built-ins PL/1.
15. Generer le code des affectations : variable = expression, tableau(index) = expression, initialisation explicite, initialisation STATIC et locales.
16. Implementer DO I = debut TO fin ; ... END ; avec variable de controle, test de fin, increment implicite, labels 80386 uniques et imbrication.
17. Implementer SELECT(expr), WHEN(valeurs), OTHERWISE et END, en generation de comparaisons et branchements structures.
18. Implementer GOTO label et les etiquettes internes en emission ASM/OBJ, avec verification des labels inexistants ou dupliques.
19. Implementer RETURN(expr) pour les procedures avec RETURNS, prologue/epilogue propre et retour de valeur dans EAX.
20. Definir la convention d'appel interne 32 bits : parametres sur pile, frame EBP, sauvegarde minimale des registres, nettoyage de pile documente.
21. Generer les prologues/epilogues 80386 Win32 : allocation des locales, acces [EBP-offset] et [EBP+offset], alignement simple de pile.
22. Fournir le runtime console minimal : PUT LIST(expr) pour afficher les entiers, PUT SKIP pour nouvelle ligne, sortie propre via ExitProcess ou equivalent.
23. Implementer l'emission ASM optionnelle : syntaxe MASM 80386 lisible, sections .text/.data/.rdata, labels stables, commentaires utiles pour le debug.
24. Implementer l'emission OBJ COFF et le lien EXE PE Win32 par defaut, avec imports runtime necessaires et mode -obj qui s'arrete apres le fichier objet.
25. Creer une validation automatique compilant et executant tous les fichiers SAMPLES\PL1\*.PLI, en couvrant TEST.PLI et TEST2.PLI, avec verification des sorties attendues et des modes .EXE, .OBJ et .ASM optionnel.
}
Program PL1CW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  INFRASTRUCTURE DE BASE
  ============================================================ }

Const
  PL1CW32_VERSION = '1.0';
  PL1CW32_DATE    = '2026';
  MAX_PATH_LEN    = 255;
  EXIT_OK         = 0;
  EXIT_ERROR      = 1;
  EXIT_USAGE      = 2;

Type
  TString = String[MAX_PATH_LEN];

  { TODO 1 - Pipeline canonique du compilateur.

    Le compilateur PL1CW32 est organise comme une suite d'etapes
    explicites. Chaque etape consomme l'artefact de l'etape precedente
    et produit le suivant :

      .PLI/.PL1 source PL/1
        -> flux de tokens
        -> AST / representation intermediaire PL/1
        -> assembleur 80386 Win32
        -> objet COFF 32 bits
        -> executable PE Win32

    Par defaut, le pipeline va jusqu'a l'executable PE Win32. Les TODO 2
    et 3 brancheront les options permettant de s'arreter au fichier OBJ
    et de generer ou conserver explicitement le fichier ASM.
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
    AK_SOURCE_PL1,
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
    emit_asm    : Boolean;
    verbose     : Boolean;
    show_help   : Boolean;
    output_name : TString;
  End;

  TCompilerContext = Record
    source_name : TString;
    asm_name    : TString;
    obj_name    : TString;
    exe_name    : TString;
    options     : TPipelineOptions;
    stage       : TCompileStage;
    last_art    : TArtifactKind;
    errors      : Integer;
  End;

Function StageName(stage: TCompileStage): TString;
Begin
  Case stage Of
    CS_LOAD_SOURCE: StageName := 'source';
    CS_LEX_TOKENS:  StageName := 'tokens';
    CS_PARSE_AST:   StageName := 'ast-ir';
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
    AK_SOURCE_PL1:   ArtifactName := 'source-pl1';
    AK_TOKEN_STREAM: ArtifactName := 'token-stream';
    AK_AST_IR:       ArtifactName := 'ast-ir';
    AK_ASM_386:      ArtifactName := 'asm-80386';
    AK_OBJ_COFF:     ArtifactName := 'obj-coff';
    AK_EXE_PE32:     ArtifactName := 'exe-pe32';
  Else
    ArtifactName := 'unknown';
  End;
End;

Procedure InitPipelineDefaults(Var ctx: TCompilerContext);
Begin
  ctx.source_name := '';
  ctx.asm_name := '';
  ctx.obj_name := '';
  ctx.exe_name := '';
  ctx.options.output_mode := OM_EXE;
  ctx.options.emit_asm := False;
  ctx.options.verbose := False;
  ctx.options.show_help := False;
  ctx.options.output_name := '';
  ctx.stage := CS_LOAD_SOURCE;
  ctx.last_art := AK_NONE;
  ctx.errors := 0;
End;

Procedure PipelineError(Var ctx: TCompilerContext; msg: TString);
Begin
  Inc(ctx.errors);
  Writeln('PL1CW32: ', StageName(ctx.stage), ': ', msg);
End;

Function UpperStr(s: TString): TString;
Var
  i: Integer;
Begin
  For i := 1 To Length(s) Do
    s[i] := UpCase(s[i]);
  UpperStr := s;
End;

Function IsOption(s: TString): Boolean;
Begin
  IsOption := (Length(s) > 0) And ((s[1] = '-') Or (s[1] = '/'));
End;

Function StripOptionPrefix(s: TString): TString;
Begin
  If IsOption(s) Then
    Delete(s, 1, 1);
  StripOptionPrefix := s;
End;

Function BaseNameNoExt(name: TString): TString;
Var
  i, dot_pos, slash_pos: Integer;
Begin
  dot_pos := 0;
  slash_pos := 0;
  For i := 1 To Length(name) Do
    Begin
      If (name[i] = '\') Or (name[i] = '/') Or (name[i] = ':') Then
        slash_pos := i;
      If name[i] = '.' Then
        dot_pos := i;
    End;

  If dot_pos <= slash_pos Then
    dot_pos := Length(name) + 1;

  BaseNameNoExt := Copy(name, 1, dot_pos - 1);
End;

Function WithExt(name, ext: TString): TString;
Begin
  WithExt := BaseNameNoExt(name) + ext;
End;

Procedure PrintUsage;
Begin
  Writeln('PL1CW32 - Cette commande permet de lancer le compilateur PL/1 ',
          'vers assembleur 80386, 32 bits, pour Windows 32 bits.');
  WriteLn;
  Writeln('Syntaxe: pl1cw32 source.pli [-o sortie] [-obj] [-asm] [-v] [-h]');
  Writeln;
  Writeln('Options:');
  Writeln('  -o sortie   Nom du fichier de sortie principal');
  Writeln('  -obj        Produire seulement un fichier .OBJ COFF');
  Writeln('  -asm        Generer/conserver aussi un fichier .ASM lisible');
  Writeln('  -v          Afficher les etapes du pipeline');
  Writeln('  -h          Afficher cette aide');
End;

Procedure PrintOptions(Var ctx: TCompilerContext);
Begin
  Writeln('Source : ', ctx.source_name);
  If ctx.options.output_mode = OM_OBJ Then
    Writeln('Mode   : OBJ seulement')
  Else
    Writeln('Mode   : EXE Win32');
  If ctx.options.emit_asm Then
    Writeln('ASM    : oui')
  Else
    Writeln('ASM    : non');
  Writeln('ASM out: ', ctx.asm_name);
  Writeln('OBJ out: ', ctx.obj_name);
  Writeln('EXE out: ', ctx.exe_name);
End;

Procedure SetDefaultOutputNames(Var ctx: TCompilerContext);
Var
  base_name: TString;
Begin
  base_name := BaseNameNoExt(ctx.source_name);

  If ctx.options.output_name <> '' Then
    Begin
      If ctx.options.output_mode = OM_OBJ Then
        ctx.obj_name := ctx.options.output_name
      Else
        ctx.exe_name := ctx.options.output_name;
    End;

  If ctx.asm_name = '' Then
    ctx.asm_name := WithExt(base_name, '.asm');
  If ctx.obj_name = '' Then
    ctx.obj_name := WithExt(base_name, '.obj');
  If ctx.exe_name = '' Then
    ctx.exe_name := WithExt(base_name, '.exe');
End;

Function ParseArgs(Var ctx: TCompilerContext): Integer;
Var
  i: Integer;
  arg, opt: TString;
Begin
  ParseArgs := EXIT_OK;
  i := 1;

  While i <= ParamCount Do
    Begin
      arg := ParamStr(i);

      If IsOption(arg) Then
        Begin
          opt := UpperStr(StripOptionPrefix(arg));
          If opt = 'H' Then
            ctx.options.show_help := True
          Else If opt = '?' Then
            ctx.options.show_help := True
          Else If opt = 'V' Then
            ctx.options.verbose := True
          Else If opt = 'ASM' Then
            ctx.options.emit_asm := True
          Else If opt = 'OBJ' Then
            ctx.options.output_mode := OM_OBJ
          Else If opt = 'O' Then
            Begin
              Inc(i);
              If i > ParamCount Then
                Begin
                  Writeln('PL1CW32: option -o sans nom de sortie');
                  ParseArgs := EXIT_USAGE;
                  Exit;
                End;
              ctx.options.output_name := ParamStr(i);
            End
          Else
            Begin
              Writeln('PL1CW32: option inconnue: ', arg);
              ParseArgs := EXIT_USAGE;
              Exit;
            End;
        End
      Else
        Begin
          If ctx.source_name <> '' Then
            Begin
              Writeln('PL1CW32: plusieurs fichiers sources indiques');
              ParseArgs := EXIT_USAGE;
              Exit;
            End;
          ctx.source_name := arg;
        End;

      Inc(i);
    End;

  If ctx.options.show_help Then
    Begin
      ParseArgs := EXIT_OK;
      Exit;
    End;

  If ctx.source_name = '' Then
    Begin
      Writeln('PL1CW32: aucun fichier source indique');
      ParseArgs := EXIT_USAGE;
      Exit;
    End;

  SetDefaultOutputNames(ctx);
End;

Function RunStage(Var ctx: TCompilerContext; stage: TCompileStage): Boolean;
Begin
  ctx.stage := stage;
  RunStage := False;

  Case stage Of
    CS_LOAD_SOURCE:
      Begin
        { TODO 4 chargera reellement le fichier source. }
        ctx.last_art := AK_SOURCE_PL1;
        RunStage := True;
      End;
    CS_LEX_TOKENS:
      Begin
        { TODO 5 produira le flux lexical PL/1. }
        If ctx.last_art <> AK_SOURCE_PL1 Then
          PipelineError(ctx, 'source PL/1 attendue')
        Else
          Begin
            ctx.last_art := AK_TOKEN_STREAM;
            RunStage := True;
          End;
      End;
    CS_PARSE_AST:
      Begin
        { TODO 8 a 18 construiront l'AST / IR PL/1. }
        If ctx.last_art <> AK_TOKEN_STREAM Then
          PipelineError(ctx, 'flux de tokens attendu')
        Else
          Begin
            ctx.last_art := AK_AST_IR;
            RunStage := True;
          End;
      End;
    CS_EMIT_ASM386:
      Begin
        { TODO 20 a 23 genereront l'assembleur 80386 Win32. }
        If ctx.last_art <> AK_AST_IR Then
          PipelineError(ctx, 'AST / IR attendu')
        Else
          Begin
            ctx.last_art := AK_ASM_386;
            RunStage := True;
          End;
      End;
    CS_BUILD_OBJ:
      Begin
        { TODO 24 produira l'objet COFF 32 bits. }
        If ctx.last_art <> AK_ASM_386 Then
          PipelineError(ctx, 'assembleur 80386 attendu')
        Else
          Begin
            ctx.last_art := AK_OBJ_COFF;
            RunStage := True;
          End;
      End;
    CS_LINK_EXE:
      Begin
        { TODO 24 liera l'objet en executable PE Win32 par defaut. }
        If ctx.last_art <> AK_OBJ_COFF Then
          PipelineError(ctx, 'objet COFF attendu')
        Else
          Begin
            ctx.last_art := AK_EXE_PE32;
            RunStage := True;
          End;
      End;
  End;
End;

Function RunPipeline(Var ctx: TCompilerContext): Boolean;
Begin
  RunPipeline := False;

  If Not RunStage(ctx, CS_LOAD_SOURCE) Then
    Exit;
  If Not RunStage(ctx, CS_LEX_TOKENS) Then
    Exit;
  If Not RunStage(ctx, CS_PARSE_AST) Then
    Exit;
  If Not RunStage(ctx, CS_EMIT_ASM386) Then
    Exit;
  If Not RunStage(ctx, CS_BUILD_OBJ) Then
    Exit;

  If ctx.options.output_mode = OM_EXE Then
    If Not RunStage(ctx, CS_LINK_EXE) Then
      Exit;

  RunPipeline := ctx.errors = 0;
End;

Procedure PrintPipeline;
Begin
  Writeln('PL1CW32 ', PL1CW32_VERSION, ' - pipeline canonique');
  Writeln('  .PLI/.PL1 -> ', ArtifactName(AK_TOKEN_STREAM),
          ' -> ', ArtifactName(AK_AST_IR),
          ' -> ', ArtifactName(AK_ASM_386),
          ' -> ', ArtifactName(AK_OBJ_COFF),
          ' -> ', ArtifactName(AK_EXE_PE32));
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

  If parse_result <> EXIT_OK Then
    Begin
      PrintUsage;
      Halt(parse_result);
    End;

  If ctx.options.verbose Then
    Begin
      PrintPipeline;
      PrintOptions(ctx);
    End;

  If Not RunPipeline(ctx) Then
    Halt(EXIT_ERROR);

  Halt(EXIT_OK);
END.
