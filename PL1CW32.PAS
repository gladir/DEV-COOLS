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
3. [IMPLEMENTE] Definir les conventions de fichiers : accepter SAMPLES\PL1\*.PLI, produire .EXE par defaut, produire .OBJ final avec -obj, ne produire .ASM que si -asm est demande.
4. [IMPLEMENTE] Mettre en place l'infrastructure commune : lecture source, suivi ligne/colonne, messages d'erreur clairs, codes de sortie, limites internes compatibles Turbo Pascal 7 et Free Pascal 3.2.
5. [IMPLEMENTE] Implementer le scanner lexical PL/1 : identifiants, mots-cles, entiers, chaines, commentaires /* ... */, operateurs, parentheses, virgules, deux-points, points-virgules.
6. [IMPLEMENTE] Construire la table des mots-cles necessaires aux exemples : PROCEDURE, OPTIONS, MAIN, DECLARE, FIXED, BINARY, INITIAL, STATIC, RETURNS, RETURN, DO, TO, END, PUT, LIST, SKIP, SELECT, WHEN, OTHERWISE, GOTO.
7. [IMPLEMENTE] Parser les etiquettes PL/1 de procedure et de controle : MAIN:, ABSVAL:, FIN:, avec resolution des references avant/arriere pour GOTO.
8. [IMPLEMENTE] Parser les declarations PROCEDURE, y compris OPTIONS(MAIN), listes de parametres, RETURNS(FIXED BINARY), corps de procedure et END nom optionnel.
9. [IMPLEMENTE] Construire une table des symboles avec portees : procedures, parametres, variables locales, variables STATIC, tableaux, etiquettes et symboles runtime.
10. [IMPLEMENTE] Parser les declarations DECLARE simples : FIXED BINARY, INITIAL(expr), STATIC, declarations multiples si ajoutees plus tard, et diagnostics de redeclaration.
11. [IMPLEMENTE] Supporter les tableaux PL/1 unidimensionnels utilises par TEST2.PLI : DECLARE TAB(10) FIXED BINARY STATIC, indexation TAB(I), bornes 1..N.
12. [IMPLEMENTE] Definir la representation 32 bits des types minimaux : FIXED BINARY comme entier signe 32 bits, tableaux d'entiers 32 bits, valeurs de retour dans EAX.
13. [IMPLEMENTE] Implementer le parseur d'expressions avec precedence : litteraux, variables, tableaux, parentheses, appels, unaire -, *, / si prevu, +, -, comparaisons.
14. [IMPLEMENTE] Implementer les built-ins requis : ABS, MAX, MIN, MOD, avec evaluation correcte dans les expressions et preparation a d'autres built-ins PL/1.
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
  MAX_LINE_LEN    = 255;
  MAX_SOURCE_LINES = 12000;
  MAX_SOURCE_CHARS = 60000;
  MAX_ERRORS      = 40;
  MAX_LABELS      = 256;
  MAX_GOTOS       = 256;
  MAX_PROCS       = 128;
  MAX_PARAMS      = 16;
  MAX_SYMBOLS     = 1024;
  MAX_TOKENS      = 4096;
  MAX_CALL_ARGS   = 8;
  ABI_WORD_SIZE   = 4;
  ABI_RET_REG     = 'EAX';
  PL1_KEYWORD_COUNT = 28;
  EXT_PL1         = '.PL1';
  EXT_PLI         = '.PLI';
  EXT_ASM         = '.asm';
  EXT_OBJ         = '.obj';
  EXT_EXE         = '.exe';
  EXIT_OK         = 0;
  EXIT_ERROR      = 1;
  EXIT_USAGE      = 2;

Type
  TString = String[MAX_PATH_LEN];
  TSourceLine = String[MAX_LINE_LEN];
  TLabelName = String[64];
  TKeyword = String[16];
  TKeywordTable = Array[1..PL1_KEYWORD_COUNT] Of TKeyword;

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

  TTokenKind = (
    TK_EOF,
    TK_IDENT,
    TK_KEYWORD,
    TK_INTEGER,
    TK_STRING,
    TK_OPERATOR,
    TK_PUNCT
  );

  TToken = Record
    kind    : TTokenKind;
    text    : TString;
    int_val : LongInt;
    line    : LongInt;
    col     : Integer;
  End;

  TTokenTable = Array[1..MAX_TOKENS] Of TToken;

  TLabelKind = (
    LK_PROC,
    LK_CONTROL
  );

  TLabelRef = Record
    name : TLabelName;
    kind : TLabelKind;
    line : LongInt;
    col  : Integer;
  End;

  TGotoRef = Record
    name : TLabelName;
    line : LongInt;
    col  : Integer;
  End;

  TLabelTable = Array[1..MAX_LABELS] Of TLabelRef;
  TGotoTable = Array[1..MAX_GOTOS] Of TGotoRef;
  TParamTable = Array[1..MAX_PARAMS] Of TLabelName;

  TTypeKind = (
    TY_NONE,
    TY_FIXED_BINARY,
    TY_ARRAY_FIXED_BINARY
  );

  TTypeInfo = Record
    kind       : TTypeKind;
    size       : Integer;
    align      : Integer;
    signed     : Boolean;
    elem_kind  : TTypeKind;
    elem_size  : Integer;
    return_reg : String[8];
  End;

  TBuiltinKind = (
    BI_NONE,
    BI_ABS,
    BI_MAX,
    BI_MIN,
    BI_MOD
  );

  TExprInfo = Record
    typ       : TTypeInfo;
    is_const  : Boolean;
    int_value : LongInt;
  End;

  TExprArgTable = Array[1..MAX_CALL_ARGS] Of TExprInfo;

  TProcInfo = Record
    name        : TLabelName;
    param_count : Integer;
    params      : TParamTable;
    has_returns : Boolean;
    return_type : TTypeInfo;
    is_main     : Boolean;
    decl_line   : LongInt;
    decl_col    : Integer;
    body_line   : LongInt;
    end_line    : LongInt;
    closed      : Boolean;
  End;

  TProcTable = Array[1..MAX_PROCS] Of TProcInfo;

  TProcDeclState = (
    PDS_NONE,
    PDS_AFTER_PROCEDURE,
    PDS_PARAMS,
    PDS_AFTER_PARAMS,
    PDS_OPTIONS,
    PDS_OPTIONS_ARGS,
    PDS_RETURNS,
    PDS_RETURNS_ARGS
  );

  TDeclState = (
    DS_NONE,
    DS_EXPECT_NAME,
    DS_AFTER_NAME,
    DS_ARRAY_DIMS,
    DS_INITIAL
  );

  TSymKind = (
    SK_PROC,
    SK_PARAM,
    SK_LOCAL,
    SK_STATIC,
    SK_ARRAY,
    SK_LABEL,
    SK_RUNTIME,
    SK_BUILTIN
  );

  TSymbol = Record
    name      : TLabelName;
    owner     : TLabelName;
    kind      : TSymKind;
    typ       : TTypeInfo;
    line      : LongInt;
    col       : Integer;
    ref_index : Integer;
    is_static : Boolean;
    has_initial: Boolean;
    lower_bound: LongInt;
    upper_bound: LongInt;
    elem_count : LongInt;
  End;

  TSymbolTable = Array[1..MAX_SYMBOLS] Of TSymbol;

  TSymbolInfo = Record
    count              : Integer;
    proc_count         : Integer;
    param_count        : Integer;
    local_count        : Integer;
    static_count       : Integer;
    array_count        : Integer;
    label_count        : Integer;
    runtime_count      : Integer;
    builtin_count      : Integer;
    duplicate_count    : Integer;
    symbols            : TSymbolTable;
  End;

  TSourceInfo = Record
    loaded       : Boolean;
    line_count   : LongInt;
    char_count   : LongInt;
    max_line_len : Integer;
    cur_line     : LongInt;
    cur_col      : Integer;
  End;

  TLexInfo = Record
    token_count   : LongInt;
    ident_count   : LongInt;
    keyword_count : LongInt;
    integer_count : LongInt;
    string_count  : LongInt;
    operator_count: LongInt;
    punct_count   : LongInt;
    comment_count : LongInt;
    tokens        : TTokenTable;
    eof_token     : TToken;
  End;

  TParseInfo = Record
    label_count       : Integer;
    proc_label_count  : Integer;
    control_label_count: Integer;
    goto_count        : Integer;
    unresolved_gotos  : Integer;
    duplicate_labels  : Integer;
    array_ref_count   : Integer;
    bad_array_ref_count: Integer;
    expr_count       : Integer;
    expr_error_count : Integer;
    builtin_call_count : Integer;
    builtin_error_count: Integer;
    proc_count        : Integer;
    main_proc_count   : Integer;
    open_proc         : Integer;
    block_depth       : Integer;
    proc_decl_state   : TProcDeclState;
    current_decl_proc : Integer;
    end_pending       : Boolean;
    end_name          : TLabelName;
    decl_state        : TDeclState;
    decl_name         : TLabelName;
    decl_line         : LongInt;
    decl_col          : Integer;
    decl_static       : Boolean;
    decl_initial      : Boolean;
    decl_array        : Boolean;
    decl_array_size   : LongInt;
    decl_paren_depth  : Integer;
    pending_index_name: TLabelName;
    pending_index_line: LongInt;
    pending_index_col : Integer;
    procs             : TProcTable;
    labels            : TLabelTable;
    gotos             : TGotoTable;
    have_prev         : Boolean;
    prev_token        : TToken;
    pending_goto      : Boolean;
    pending_label     : Integer;
  End;

  TCompilerContext = Record
    source_name : TString;
    asm_name    : TString;
    obj_name    : TString;
    exe_name    : TString;
    options     : TPipelineOptions;
    source      : TSourceInfo;
    lex         : TLexInfo;
    parse       : TParseInfo;
    symbols     : TSymbolInfo;
    stage       : TCompileStage;
    last_art    : TArtifactKind;
    errors      : Integer;
    warnings    : Integer;
  End;

Const
  PL1_KEYWORDS: TKeywordTable = (
    'PROCEDURE',
    'OPTIONS',
    'MAIN',
    'DECLARE',
    'FIXED',
    'BINARY',
    'INITIAL',
    'STATIC',
    'RETURNS',
    'RETURN',
    'DO',
    'TO',
    'END',
    'PUT',
    'LIST',
    'SKIP',
    'SELECT',
    'WHEN',
    'OTHERWISE',
    'GOTO',
    'PROC',
    'DCL',
    'INIT',
    'GO',
    'BY',
    'IF',
    'THEN',
    'ELSE'
  );

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
  ctx.source.loaded := False;
  ctx.source.line_count := 0;
  ctx.source.char_count := 0;
  ctx.source.max_line_len := 0;
  ctx.source.cur_line := 1;
  ctx.source.cur_col := 1;
  ctx.lex.token_count := 0;
  ctx.lex.ident_count := 0;
  ctx.lex.keyword_count := 0;
  ctx.lex.integer_count := 0;
  ctx.lex.string_count := 0;
  ctx.lex.operator_count := 0;
  ctx.lex.punct_count := 0;
  ctx.lex.comment_count := 0;
  ctx.lex.eof_token.kind := TK_EOF;
  ctx.lex.eof_token.text := '';
  ctx.lex.eof_token.int_val := 0;
  ctx.lex.eof_token.line := 1;
  ctx.lex.eof_token.col := 1;
  ctx.parse.label_count := 0;
  ctx.parse.proc_label_count := 0;
  ctx.parse.control_label_count := 0;
  ctx.parse.goto_count := 0;
  ctx.parse.unresolved_gotos := 0;
  ctx.parse.duplicate_labels := 0;
  ctx.parse.array_ref_count := 0;
  ctx.parse.bad_array_ref_count := 0;
  ctx.parse.expr_count := 0;
  ctx.parse.expr_error_count := 0;
  ctx.parse.builtin_call_count := 0;
  ctx.parse.builtin_error_count := 0;
  ctx.parse.proc_count := 0;
  ctx.parse.main_proc_count := 0;
  ctx.parse.open_proc := 0;
  ctx.parse.block_depth := 0;
  ctx.parse.proc_decl_state := PDS_NONE;
  ctx.parse.current_decl_proc := 0;
  ctx.parse.end_pending := False;
  ctx.parse.end_name := '';
  ctx.parse.decl_state := DS_NONE;
  ctx.parse.decl_name := '';
  ctx.parse.decl_line := 1;
  ctx.parse.decl_col := 1;
  ctx.parse.decl_static := False;
  ctx.parse.decl_initial := False;
  ctx.parse.decl_array := False;
  ctx.parse.decl_paren_depth := 0;
  ctx.parse.have_prev := False;
  ctx.parse.prev_token.kind := TK_EOF;
  ctx.parse.prev_token.text := '';
  ctx.parse.prev_token.int_val := 0;
  ctx.parse.prev_token.line := 1;
  ctx.parse.prev_token.col := 1;
  ctx.parse.pending_goto := False;
  ctx.parse.pending_label := 0;
  ctx.symbols.count := 0;
  ctx.symbols.proc_count := 0;
  ctx.symbols.param_count := 0;
  ctx.symbols.local_count := 0;
  ctx.symbols.static_count := 0;
  ctx.symbols.array_count := 0;
  ctx.symbols.label_count := 0;
  ctx.symbols.runtime_count := 0;
  ctx.symbols.builtin_count := 0;
  ctx.symbols.duplicate_count := 0;
  ctx.stage := CS_LOAD_SOURCE;
  ctx.last_art := AK_NONE;
  ctx.errors := 0;
  ctx.warnings := 0;
End;

Procedure PipelineError(Var ctx: TCompilerContext; msg: TString);
Begin
  If ctx.errors < MAX_ERRORS Then
    Writeln('PL1CW32: ', StageName(ctx.stage), ': ', msg);
  Inc(ctx.errors);
  If ctx.errors = MAX_ERRORS Then
    Writeln('PL1CW32: trop d''erreurs, arret des diagnostics.');
End;

Function UpperStr(s: TString): TString;
Var
  i: Integer;
Begin
  For i := 1 To Length(s) Do
    s[i] := UpCase(s[i]);
  UpperStr := s;
End;

Function FetchSourceLine(name: TString; wanted: LongInt; Var line: TSourceLine): Boolean;
Var
  f: Text;
  cur: LongInt;
  io: Integer;
Begin
  FetchSourceLine := False;
  line := '';
  Assign(f, name);
  Reset(f);
  io := IOResult;
  If io <> 0 Then
    Exit;

  cur := 0;
  While (Not Eof(f)) And (cur < wanted) Do
    Begin
      ReadLn(f, line);
      io := IOResult;
      If io <> 0 Then
        Begin
          Close(f);
          io := IOResult;
          Exit;
        End;
      Inc(cur);
    End;

  Close(f);
  io := IOResult;
  FetchSourceLine := cur = wanted;
End;

Procedure SourceErrorAt(Var ctx: TCompilerContext; line_no: LongInt;
                        col_no: Integer; msg: TString);
Var
  line: TSourceLine;
  i: Integer;
Begin
  If ctx.errors < MAX_ERRORS Then
    Begin
      Writeln(ctx.source_name, '(', line_no, ',', col_no, '): error: ', msg);
      If FetchSourceLine(ctx.source_name, line_no, line) Then
        Begin
          Writeln(line);
          For i := 1 To col_no - 1 Do
            Write(' ');
          Writeln('^');
        End;
    End;
  Inc(ctx.errors);
  If ctx.errors = MAX_ERRORS Then
    Writeln('PL1CW32: trop d''erreurs, arret des diagnostics.');
End;

Procedure SourceWarningAt(Var ctx: TCompilerContext; line_no: LongInt;
                          col_no: Integer; msg: TString);
Begin
  Inc(ctx.warnings);
  Writeln(ctx.source_name, '(', line_no, ',', col_no, '): warning: ', msg);
End;

Procedure ResetSourceCursor(Var ctx: TCompilerContext);
Begin
  ctx.source.cur_line := 1;
  ctx.source.cur_col := 1;
End;

Procedure AdvanceSourceCursor(Var ctx: TCompilerContext; ch: Char);
Begin
  If ch = #10 Then
    Begin
      Inc(ctx.source.cur_line);
      ctx.source.cur_col := 1;
    End
  Else
    Inc(ctx.source.cur_col);
End;

Function LoadSourceFile(Var ctx: TCompilerContext): Boolean;
Var
  f: Text;
  line: TSourceLine;
  io: Integer;
  len: Integer;
Begin
  LoadSourceFile := False;
  ctx.source.loaded := False;
  ctx.source.line_count := 0;
  ctx.source.char_count := 0;
  ctx.source.max_line_len := 0;
  ResetSourceCursor(ctx);

  Assign(f, ctx.source_name);
  Reset(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible d''ouvrir le fichier source');
      Exit;
    End;

  While Not Eof(f) Do
    Begin
      ReadLn(f, line);
      io := IOResult;
      If io <> 0 Then
        Begin
          Close(f);
          io := IOResult;
          PipelineError(ctx, 'erreur de lecture du fichier source');
          Exit;
        End;

      Inc(ctx.source.line_count);
      len := Length(line);
      Inc(ctx.source.char_count, len + 1);
      If len > ctx.source.max_line_len Then
        ctx.source.max_line_len := len;

      If ctx.source.line_count > MAX_SOURCE_LINES Then
        Begin
          SourceErrorAt(ctx, ctx.source.line_count, 1,
                        'limite de lignes source depassee');
          Close(f);
          io := IOResult;
          Exit;
        End;

      If ctx.source.char_count > MAX_SOURCE_CHARS Then
        Begin
          SourceErrorAt(ctx, ctx.source.line_count, len,
                        'limite de taille source depassee');
          Close(f);
          io := IOResult;
          Exit;
        End;
    End;

  Close(f);
  io := IOResult;

  If ctx.source.line_count = 0 Then
    SourceWarningAt(ctx, 1, 1, 'fichier source vide');

  ctx.source.loaded := True;
  LoadSourceFile := ctx.errors = 0;
End;

Function IsLetter(ch: Char): Boolean;
Begin
  IsLetter := ((ch >= 'A') And (ch <= 'Z')) Or
              ((ch >= 'a') And (ch <= 'z')) Or
              (ch = '_') Or (ch = '#') Or (ch = '@') Or (ch = '$');
End;

Function IsDigit(ch: Char): Boolean;
Begin
  IsDigit := (ch >= '0') And (ch <= '9');
End;

Function IsIdentChar(ch: Char): Boolean;
Begin
  IsIdentChar := IsLetter(ch) Or IsDigit(ch);
End;

Function IsSpace(ch: Char): Boolean;
Begin
  IsSpace := (ch = ' ') Or (ch = #9);
End;

Function IsPunct(ch: Char): Boolean;
Begin
  IsPunct := (ch = '(') Or (ch = ')') Or (ch = ',') Or
             (ch = ':') Or (ch = ';');
End;

Function IsOperatorStart(ch: Char): Boolean;
Begin
  IsOperatorStart := (ch = '+') Or (ch = '-') Or (ch = '*') Or
                     (ch = '/') Or (ch = '=') Or (ch = '<') Or
                     (ch = '>') Or (ch = '^') Or (ch = '~') Or
                     (ch = '.') Or (ch = '&') Or (ch = '|');
End;

Function IsPL1Keyword(word: TString): Boolean;
Var
  u: TString;
  i: Integer;
Begin
  u := UpperStr(word);
  IsPL1Keyword := False;
  For i := 1 To PL1_KEYWORD_COUNT Do
    If u = PL1_KEYWORDS[i] Then
      Begin
        IsPL1Keyword := True;
        Exit;
      End;
End;

Procedure CountToken(Var ctx: TCompilerContext; kind: TTokenKind);
Begin
  Inc(ctx.lex.token_count);
  Case kind Of
    TK_IDENT:    Inc(ctx.lex.ident_count);
    TK_KEYWORD:  Inc(ctx.lex.keyword_count);
    TK_INTEGER:  Inc(ctx.lex.integer_count);
    TK_STRING:   Inc(ctx.lex.string_count);
    TK_OPERATOR: Inc(ctx.lex.operator_count);
    TK_PUNCT:    Inc(ctx.lex.punct_count);
  Else
  End;
End;

Procedure ParseLabelToken(Var ctx: TCompilerContext; tok: TToken); Forward;
Procedure ParseProcedureToken(Var ctx: TCompilerContext; tok: TToken); Forward;
Procedure ParseDeclareToken(Var ctx: TCompilerContext; tok: TToken); Forward;
Procedure ParseArrayUseToken(Var ctx: TCompilerContext; tok: TToken); Forward;

Procedure RegisterToken(Var ctx: TCompilerContext; tok: TToken);
Var
  code: Integer;
Begin
  If ctx.lex.token_count >= MAX_TOKENS Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col, 'trop de tokens');
      Exit;
    End;
  If tok.kind = TK_INTEGER Then
    Begin
      Val(tok.text, tok.int_val, code);
      If code <> 0 Then
        SourceErrorAt(ctx, tok.line, tok.col, 'entier invalide');
    End;
  CountToken(ctx, tok.kind);
  ctx.lex.tokens[ctx.lex.token_count] := tok;
  ParseArrayUseToken(ctx, tok);
  ParseLabelToken(ctx, tok);
  ParseProcedureToken(ctx, tok);
  ParseDeclareToken(ctx, tok);
End;

Procedure MakeToken(Var tok: TToken; kind: TTokenKind; text: TString;
                    line_no: LongInt; col_no: Integer);
Begin
  tok.kind := kind;
  tok.text := text;
  tok.int_val := 0;
  tok.line := line_no;
  tok.col := col_no;
End;

Function IsNameToken(tok: TToken): Boolean;
Begin
  IsNameToken := (tok.kind = TK_IDENT) Or
                 ((tok.kind = TK_KEYWORD) And (tok.text = 'MAIN'));
End;

Function TokenIs(tok: TToken; text: TString): Boolean;
Begin
  TokenIs := UpperStr(tok.text) = UpperStr(text);
End;

Function ParseLong(s: TString; Var value: LongInt): Boolean;
Var
  code: Integer;
Begin
  Val(s, value, code);
  ParseLong := code = 0;
End;

Function FindLabel(Var ctx: TCompilerContext; name: TLabelName): Integer;
Var
  i: Integer;
  u: TLabelName;
Begin
  FindLabel := 0;
  u := UpperStr(name);
  For i := 1 To ctx.parse.label_count Do
    If UpperStr(ctx.parse.labels[i].name) = u Then
      Begin
        FindLabel := i;
        Exit;
      End;
End;

Function SymKindName(kind: TSymKind): TString;
Begin
  Case kind Of
    SK_PROC:    SymKindName := 'PROC';
    SK_PARAM:   SymKindName := 'PARAM';
    SK_LOCAL:   SymKindName := 'LOCAL';
    SK_STATIC:  SymKindName := 'STATIC';
    SK_ARRAY:   SymKindName := 'ARRAY';
    SK_LABEL:   SymKindName := 'LABEL';
    SK_RUNTIME: SymKindName := 'RUNTIME';
    SK_BUILTIN: SymKindName := 'BUILTIN';
  Else
    SymKindName := 'UNKNOWN';
  End;
End;

Function TypeKindName(kind: TTypeKind): TString;
Begin
  Case kind Of
    TY_NONE:               TypeKindName := 'NONE';
    TY_FIXED_BINARY:       TypeKindName := 'FIXED BINARY';
    TY_ARRAY_FIXED_BINARY: TypeKindName := 'ARRAY FIXED BINARY';
  Else
    TypeKindName := 'UNKNOWN';
  End;
End;

Function NoType: TTypeInfo;
Begin
  NoType.kind := TY_NONE;
  NoType.size := 0;
  NoType.align := 1;
  NoType.signed := False;
  NoType.elem_kind := TY_NONE;
  NoType.elem_size := 0;
  NoType.return_reg := '';
End;

Function FixedBinaryType: TTypeInfo;
Begin
  FixedBinaryType.kind := TY_FIXED_BINARY;
  FixedBinaryType.size := ABI_WORD_SIZE;
  FixedBinaryType.align := ABI_WORD_SIZE;
  FixedBinaryType.signed := True;
  FixedBinaryType.elem_kind := TY_NONE;
  FixedBinaryType.elem_size := 0;
  FixedBinaryType.return_reg := ABI_RET_REG;
End;

Function ArrayFixedBinaryType(elem_count: LongInt): TTypeInfo;
Begin
  ArrayFixedBinaryType.kind := TY_ARRAY_FIXED_BINARY;
  ArrayFixedBinaryType.size := elem_count * ABI_WORD_SIZE;
  ArrayFixedBinaryType.align := ABI_WORD_SIZE;
  ArrayFixedBinaryType.signed := True;
  ArrayFixedBinaryType.elem_kind := TY_FIXED_BINARY;
  ArrayFixedBinaryType.elem_size := ABI_WORD_SIZE;
  ArrayFixedBinaryType.return_reg := '';
End;

Function FindSymbol(Var ctx: TCompilerContext; name, owner: TLabelName;
                    kind: TSymKind): Integer;
Var
  i: Integer;
  uname, uowner: TLabelName;
Begin
  FindSymbol := 0;
  uname := UpperStr(name);
  uowner := UpperStr(owner);
  For i := 1 To ctx.symbols.count Do
    If (ctx.symbols.symbols[i].name = uname) And
       (ctx.symbols.symbols[i].owner = uowner) And
       (ctx.symbols.symbols[i].kind = kind) Then
      Begin
        FindSymbol := i;
        Exit;
      End;
End;

Function FindScopedSymbol(Var ctx: TCompilerContext; name, owner: TLabelName): Integer;
Var
  i: Integer;
  uname, uowner: TLabelName;
Begin
  FindScopedSymbol := 0;
  uname := UpperStr(name);
  uowner := UpperStr(owner);
  For i := 1 To ctx.symbols.count Do
    If (ctx.symbols.symbols[i].name = uname) And
       (ctx.symbols.symbols[i].owner = uowner) Then
      Begin
        FindScopedSymbol := i;
        Exit;
      End;
End;

Function FindScopedSymbolAny(Var ctx: TCompilerContext; name, owner: TLabelName): Integer;
Var
  idx: Integer;
Begin
  idx := FindScopedSymbol(ctx, name, owner);
  If idx <> 0 Then
    FindScopedSymbolAny := idx
  Else
    FindScopedSymbolAny := FindScopedSymbol(ctx, name, '');
End;

Function CurrentProcName(Var ctx: TCompilerContext): TLabelName;
Begin
  If (ctx.parse.open_proc > 0) And
     (ctx.parse.open_proc <= ctx.parse.proc_count) Then
    CurrentProcName := ctx.parse.procs[ctx.parse.open_proc].name
  Else If (ctx.parse.current_decl_proc > 0) And
          (ctx.parse.current_decl_proc <= ctx.parse.proc_count) Then
    CurrentProcName := ctx.parse.procs[ctx.parse.current_decl_proc].name
  Else
    CurrentProcName := '';
End;

Procedure IncSymbolKind(Var ctx: TCompilerContext; kind: TSymKind);
Begin
  Case kind Of
    SK_PROC:    Inc(ctx.symbols.proc_count);
    SK_PARAM:   Inc(ctx.symbols.param_count);
    SK_LOCAL:   Inc(ctx.symbols.local_count);
    SK_STATIC:  Inc(ctx.symbols.static_count);
    SK_ARRAY:   Inc(ctx.symbols.array_count);
    SK_LABEL:   Inc(ctx.symbols.label_count);
    SK_RUNTIME: Inc(ctx.symbols.runtime_count);
    SK_BUILTIN: Inc(ctx.symbols.builtin_count);
  Else
  End;
End;

Function AddSymbol(Var ctx: TCompilerContext; name, owner: TLabelName;
                   kind: TSymKind; line_no: LongInt; col_no: Integer;
                   ref_index: Integer): Boolean;
Var
  uname, uowner: TLabelName;
Begin
  AddSymbol := False;
  uname := UpperStr(name);
  uowner := UpperStr(owner);

  If FindSymbol(ctx, uname, uowner, kind) <> 0 Then
    Begin
      Inc(ctx.symbols.duplicate_count);
      SourceErrorAt(ctx, line_no, col_no, 'symbole deja declare dans cette portee');
      Exit;
    End;

  If (kind = SK_PARAM) Or (kind = SK_LOCAL) Or
     (kind = SK_STATIC) Or (kind = SK_ARRAY) Then
    If FindScopedSymbol(ctx, uname, uowner) <> 0 Then
      Begin
        Inc(ctx.symbols.duplicate_count);
        SourceErrorAt(ctx, line_no, col_no,
                      'nom deja declare dans cette portee');
        Exit;
      End;

  If ctx.symbols.count >= MAX_SYMBOLS Then
    Begin
      SourceErrorAt(ctx, line_no, col_no, 'trop de symboles');
      Exit;
    End;

  Inc(ctx.symbols.count);
  ctx.symbols.symbols[ctx.symbols.count].name := uname;
  ctx.symbols.symbols[ctx.symbols.count].owner := uowner;
  ctx.symbols.symbols[ctx.symbols.count].kind := kind;
  ctx.symbols.symbols[ctx.symbols.count].typ := NoType;
  ctx.symbols.symbols[ctx.symbols.count].line := line_no;
  ctx.symbols.symbols[ctx.symbols.count].col := col_no;
  ctx.symbols.symbols[ctx.symbols.count].ref_index := ref_index;
  ctx.symbols.symbols[ctx.symbols.count].is_static := False;
  ctx.symbols.symbols[ctx.symbols.count].has_initial := False;
  ctx.symbols.symbols[ctx.symbols.count].lower_bound := 0;
  ctx.symbols.symbols[ctx.symbols.count].upper_bound := 0;
  ctx.symbols.symbols[ctx.symbols.count].elem_count := 0;
  IncSymbolKind(ctx, kind);
  AddSymbol := True;
End;

Procedure AddBuiltinSymbol(Var ctx: TCompilerContext; name: TLabelName;
                           kind: TBuiltinKind);
Begin
  If AddSymbol(ctx, name, '', SK_BUILTIN, 1, 1, Ord(kind)) Then
    If ctx.symbols.count > 0 Then
      ctx.symbols.symbols[ctx.symbols.count].typ := FixedBinaryType;
End;

Procedure SetSymbolStorage(Var ctx: TCompilerContext; sym_idx: Integer;
                           is_static, has_initial: Boolean;
                           lower_bound, upper_bound: LongInt);
Begin
  If (sym_idx <= 0) Or (sym_idx > ctx.symbols.count) Then
    Exit;

  ctx.symbols.symbols[sym_idx].is_static := is_static;
  ctx.symbols.symbols[sym_idx].has_initial := has_initial;
  ctx.symbols.symbols[sym_idx].lower_bound := lower_bound;
  ctx.symbols.symbols[sym_idx].upper_bound := upper_bound;
  If upper_bound >= lower_bound Then
    ctx.symbols.symbols[sym_idx].elem_count := upper_bound - lower_bound + 1
  Else
    ctx.symbols.symbols[sym_idx].elem_count := 0;

  If ctx.symbols.symbols[sym_idx].kind = SK_ARRAY Then
    ctx.symbols.symbols[sym_idx].typ :=
      ArrayFixedBinaryType(ctx.symbols.symbols[sym_idx].elem_count)
  Else If (ctx.symbols.symbols[sym_idx].kind = SK_LOCAL) Or
          (ctx.symbols.symbols[sym_idx].kind = SK_STATIC) Or
          (ctx.symbols.symbols[sym_idx].kind = SK_PARAM) Then
    ctx.symbols.symbols[sym_idx].typ := FixedBinaryType;
End;

Procedure AddRuntimeSymbols(Var ctx: TCompilerContext);
Begin
  AddSymbol(ctx, 'PUT_LIST_I32', '', SK_RUNTIME, 1, 1, 0);
  AddSymbol(ctx, 'PUT_SKIP', '', SK_RUNTIME, 1, 1, 0);
  AddSymbol(ctx, 'EXIT_PROCESS', '', SK_RUNTIME, 1, 1, 0);
  AddBuiltinSymbol(ctx, 'ABS', BI_ABS);
  AddBuiltinSymbol(ctx, 'MAX', BI_MAX);
  AddBuiltinSymbol(ctx, 'MIN', BI_MIN);
  AddBuiltinSymbol(ctx, 'MOD', BI_MOD);
End;

Procedure ResetParseInfo(Var ctx: TCompilerContext);
Begin
  ctx.symbols.count := 0;
  ctx.symbols.proc_count := 0;
  ctx.symbols.param_count := 0;
  ctx.symbols.local_count := 0;
  ctx.symbols.static_count := 0;
  ctx.symbols.array_count := 0;
  ctx.symbols.label_count := 0;
  ctx.symbols.runtime_count := 0;
  ctx.symbols.builtin_count := 0;
  ctx.symbols.duplicate_count := 0;
  ctx.parse.label_count := 0;
  ctx.parse.proc_label_count := 0;
  ctx.parse.control_label_count := 0;
  ctx.parse.goto_count := 0;
  ctx.parse.unresolved_gotos := 0;
  ctx.parse.duplicate_labels := 0;
  ctx.parse.array_ref_count := 0;
  ctx.parse.bad_array_ref_count := 0;
  ctx.parse.expr_count := 0;
  ctx.parse.expr_error_count := 0;
  ctx.parse.builtin_call_count := 0;
  ctx.parse.builtin_error_count := 0;
  ctx.parse.proc_count := 0;
  ctx.parse.main_proc_count := 0;
  ctx.parse.open_proc := 0;
  ctx.parse.block_depth := 0;
  ctx.parse.proc_decl_state := PDS_NONE;
  ctx.parse.current_decl_proc := 0;
  ctx.parse.end_pending := False;
  ctx.parse.end_name := '';
  ctx.parse.decl_state := DS_NONE;
  ctx.parse.decl_name := '';
  ctx.parse.decl_line := 1;
  ctx.parse.decl_col := 1;
  ctx.parse.decl_static := False;
  ctx.parse.decl_initial := False;
  ctx.parse.decl_array := False;
  ctx.parse.decl_array_size := 0;
  ctx.parse.decl_paren_depth := 0;
  ctx.parse.pending_index_name := '';
  ctx.parse.pending_index_line := 1;
  ctx.parse.pending_index_col := 1;
  ctx.parse.have_prev := False;
  ctx.parse.prev_token.kind := TK_EOF;
  ctx.parse.prev_token.text := '';
  ctx.parse.prev_token.int_val := 0;
  ctx.parse.prev_token.line := 1;
  ctx.parse.prev_token.col := 1;
  ctx.parse.pending_goto := False;
  ctx.parse.pending_label := 0;
  AddRuntimeSymbols(ctx);
End;

Procedure AddLabel(Var ctx: TCompilerContext; tok: TToken);
Var
  idx: Integer;
Begin
  idx := FindLabel(ctx, tok.text);
  If idx <> 0 Then
    Begin
      Inc(ctx.parse.duplicate_labels);
      SourceErrorAt(ctx, tok.line, tok.col, 'etiquette deja definie');
      Exit;
    End;

  If ctx.parse.label_count >= MAX_LABELS Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col, 'trop d''etiquettes');
      Exit;
    End;

  Inc(ctx.parse.label_count);
  ctx.parse.labels[ctx.parse.label_count].name := UpperStr(tok.text);
  ctx.parse.labels[ctx.parse.label_count].kind := LK_CONTROL;
  ctx.parse.labels[ctx.parse.label_count].line := tok.line;
  ctx.parse.labels[ctx.parse.label_count].col := tok.col;
  Inc(ctx.parse.control_label_count);
  AddSymbol(ctx, tok.text, CurrentProcName(ctx), SK_LABEL,
            tok.line, tok.col, ctx.parse.label_count);
  ctx.parse.pending_label := ctx.parse.label_count;
End;

Procedure AddProcedureFromLabel(Var ctx: TCompilerContext; label_idx: Integer;
                                tok: TToken);
Var
  proc_idx: Integer;
Begin
  If (label_idx <= 0) Or (label_idx > ctx.parse.label_count) Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col,
                    'PROCEDURE sans etiquette precedente');
      Exit;
    End;

  If ctx.parse.open_proc <> 0 Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col,
                    'declaration PROCEDURE imbriquee non supportee');
      Exit;
    End;

  If ctx.parse.proc_count >= MAX_PROCS Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col, 'trop de procedures');
      Exit;
    End;

  Inc(ctx.parse.proc_count);
  proc_idx := ctx.parse.proc_count;
  ctx.parse.procs[proc_idx].name := ctx.parse.labels[label_idx].name;
  ctx.parse.procs[proc_idx].param_count := 0;
  ctx.parse.procs[proc_idx].has_returns := False;
  ctx.parse.procs[proc_idx].return_type := NoType;
  ctx.parse.procs[proc_idx].is_main := False;
  ctx.parse.procs[proc_idx].decl_line := ctx.parse.labels[label_idx].line;
  ctx.parse.procs[proc_idx].decl_col := ctx.parse.labels[label_idx].col;
  ctx.parse.procs[proc_idx].body_line := 0;
  ctx.parse.procs[proc_idx].end_line := 0;
  ctx.parse.procs[proc_idx].closed := False;
  AddSymbol(ctx, ctx.parse.procs[proc_idx].name, '', SK_PROC,
            ctx.parse.procs[proc_idx].decl_line,
            ctx.parse.procs[proc_idx].decl_col, proc_idx);
  ctx.parse.current_decl_proc := proc_idx;
  ctx.parse.proc_decl_state := PDS_AFTER_PROCEDURE;
End;

Procedure MarkPendingLabelAsProcedure(Var ctx: TCompilerContext; tok: TToken);
Var
  idx: Integer;
Begin
  idx := ctx.parse.pending_label;
  If (idx > 0) And (idx <= ctx.parse.label_count) Then
    If ctx.parse.labels[idx].kind <> LK_PROC Then
      Begin
        ctx.parse.labels[idx].kind := LK_PROC;
        Inc(ctx.parse.proc_label_count);
        Dec(ctx.parse.control_label_count);
        AddProcedureFromLabel(ctx, idx, tok);
      End;
  ctx.parse.pending_label := 0;
End;

Procedure AddGotoRef(Var ctx: TCompilerContext; tok: TToken);
Begin
  If ctx.parse.goto_count >= MAX_GOTOS Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col, 'trop de GOTO');
      Exit;
    End;

  Inc(ctx.parse.goto_count);
  ctx.parse.gotos[ctx.parse.goto_count].name := UpperStr(tok.text);
  ctx.parse.gotos[ctx.parse.goto_count].line := tok.line;
  ctx.parse.gotos[ctx.parse.goto_count].col := tok.col;
End;

Procedure ParseLabelToken(Var ctx: TCompilerContext; tok: TToken);
Begin
  If (ctx.parse.pending_label > 0) And
     Not ((tok.kind = TK_KEYWORD) And (tok.text = 'PROCEDURE')) Then
    ctx.parse.pending_label := 0;

  If (tok.kind = TK_KEYWORD) And (tok.text = 'PROCEDURE') Then
    MarkPendingLabelAsProcedure(ctx, tok);

  If ctx.parse.pending_goto Then
    Begin
      If IsNameToken(tok) Then
        AddGotoRef(ctx, tok)
      Else
        SourceErrorAt(ctx, tok.line, tok.col, 'nom d''etiquette attendu apres GOTO');
      ctx.parse.pending_goto := False;
    End
  Else If (tok.kind = TK_KEYWORD) And (tok.text = 'GOTO') Then
    ctx.parse.pending_goto := True;

  If (tok.kind = TK_PUNCT) And (tok.text = ':') And
     ctx.parse.have_prev And IsNameToken(ctx.parse.prev_token) Then
    AddLabel(ctx, ctx.parse.prev_token);

  ctx.parse.prev_token := tok;
  ctx.parse.have_prev := True;
End;

Procedure AddProcedureParam(Var ctx: TCompilerContext; tok: TToken);
Var
  proc_idx, i: Integer;
  pname: TLabelName;
Begin
  proc_idx := ctx.parse.current_decl_proc;
  If proc_idx = 0 Then
    Exit;

  pname := UpperStr(tok.text);
  For i := 1 To ctx.parse.procs[proc_idx].param_count Do
    If ctx.parse.procs[proc_idx].params[i] = pname Then
      Begin
        SourceErrorAt(ctx, tok.line, tok.col,
                      'parametre deja declare dans cette procedure');
        Exit;
      End;

  If ctx.parse.procs[proc_idx].param_count >= MAX_PARAMS Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col,
                    'trop de parametres dans la procedure');
      Exit;
    End;

  Inc(ctx.parse.procs[proc_idx].param_count);
  ctx.parse.procs[proc_idx].params[
    ctx.parse.procs[proc_idx].param_count] := pname;
  AddSymbol(ctx, pname, ctx.parse.procs[proc_idx].name, SK_PARAM,
            tok.line, tok.col, ctx.parse.procs[proc_idx].param_count);
  If ctx.symbols.count > 0 Then
    ctx.symbols.symbols[ctx.symbols.count].typ := FixedBinaryType;
End;

Procedure BeginProcedureBody(Var ctx: TCompilerContext; tok: TToken);
Var
  proc_idx: Integer;
Begin
  proc_idx := ctx.parse.current_decl_proc;
  If proc_idx = 0 Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col,
                    'corps de PROCEDURE sans declaration active');
      Exit;
    End;

  ctx.parse.procs[proc_idx].body_line := tok.line;
  ctx.parse.open_proc := proc_idx;
  ctx.parse.block_depth := 0;
  ctx.parse.current_decl_proc := 0;
  ctx.parse.proc_decl_state := PDS_NONE;
End;

Procedure MarkProcedureMain(Var ctx: TCompilerContext; tok: TToken);
Var
  proc_idx: Integer;
Begin
  proc_idx := ctx.parse.current_decl_proc;
  If proc_idx = 0 Then
    Exit;

  If Not ctx.parse.procs[proc_idx].is_main Then
    Begin
      ctx.parse.procs[proc_idx].is_main := True;
      Inc(ctx.parse.main_proc_count);
      If ctx.parse.main_proc_count > 1 Then
        SourceErrorAt(ctx, tok.line, tok.col,
                      'plusieurs PROCEDURE OPTIONS(MAIN)');
    End;
End;

Procedure MarkProcedureReturns(Var ctx: TCompilerContext);
Var
  proc_idx: Integer;
Begin
  proc_idx := ctx.parse.current_decl_proc;
  If proc_idx <> 0 Then
    Begin
      ctx.parse.procs[proc_idx].has_returns := True;
      ctx.parse.procs[proc_idx].return_type := FixedBinaryType;
    End;
End;

Procedure CloseCurrentProcedure(Var ctx: TCompilerContext; tok: TToken;
                                end_name: TLabelName);
Var
  proc_idx: Integer;
  u: TLabelName;
Begin
  proc_idx := ctx.parse.open_proc;
  If proc_idx = 0 Then
    Begin
      If end_name <> '' Then
        SourceErrorAt(ctx, tok.line, tok.col,
                      'END nom hors procedure');
      Exit;
    End;

  u := UpperStr(end_name);
  If (u <> '') And (u <> ctx.parse.procs[proc_idx].name) Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col,
                    'END nom ne correspond pas a la procedure ouverte');
      Exit;
    End;

  ctx.parse.procs[proc_idx].closed := True;
  ctx.parse.procs[proc_idx].end_line := tok.line;
  ctx.parse.open_proc := 0;
  ctx.parse.block_depth := 0;
End;

Procedure ParseEndToken(Var ctx: TCompilerContext; tok: TToken);
Begin
  If (tok.kind = TK_KEYWORD) And (tok.text = 'END') Then
    Begin
      ctx.parse.end_pending := True;
      ctx.parse.end_name := '';
      Exit;
    End;

  If Not ctx.parse.end_pending Then
    Exit;

  If IsNameToken(tok) Then
    Begin
      ctx.parse.end_name := UpperStr(tok.text);
      Exit;
    End;

  If (tok.kind = TK_PUNCT) And (tok.text = ';') Then
    Begin
      If ctx.parse.end_name <> '' Then
        CloseCurrentProcedure(ctx, tok, ctx.parse.end_name)
      Else If ctx.parse.block_depth > 0 Then
        Dec(ctx.parse.block_depth)
      Else
        CloseCurrentProcedure(ctx, tok, '');
      ctx.parse.end_pending := False;
      ctx.parse.end_name := '';
      Exit;
    End;

  SourceErrorAt(ctx, tok.line, tok.col,
                'nom de procedure ou ; attendu apres END');
  ctx.parse.end_pending := False;
  ctx.parse.end_name := '';
End;

Procedure ParseProcedureToken(Var ctx: TCompilerContext; tok: TToken);
Begin
  If (ctx.parse.proc_decl_state = PDS_NONE) Then
    Begin
      If (ctx.parse.open_proc <> 0) And (Not ctx.parse.end_pending) Then
        Begin
          If (tok.kind = TK_KEYWORD) And
             ((tok.text = 'DO') Or (tok.text = 'SELECT')) Then
            Inc(ctx.parse.block_depth);
        End;
      ParseEndToken(ctx, tok);
      Exit;
    End;

  Case ctx.parse.proc_decl_state Of
    PDS_AFTER_PROCEDURE:
      Begin
        If (tok.kind = TK_KEYWORD) And (tok.text = 'PROCEDURE') Then
          Exit;
        If (tok.kind = TK_PUNCT) And (tok.text = '(') Then
          ctx.parse.proc_decl_state := PDS_PARAMS
        Else If (tok.kind = TK_KEYWORD) And (tok.text = 'OPTIONS') Then
          ctx.parse.proc_decl_state := PDS_OPTIONS
        Else If (tok.kind = TK_KEYWORD) And (tok.text = 'RETURNS') Then
          ctx.parse.proc_decl_state := PDS_RETURNS
        Else If (tok.kind = TK_PUNCT) And (tok.text = ';') Then
          BeginProcedureBody(ctx, tok)
        Else
          SourceErrorAt(ctx, tok.line, tok.col,
                        'element inattendu dans declaration PROCEDURE');
      End;
    PDS_PARAMS:
      Begin
        If IsNameToken(tok) Then
          AddProcedureParam(ctx, tok)
        Else If (tok.kind = TK_PUNCT) And (tok.text = ',') Then
          Begin
          End
        Else If (tok.kind = TK_PUNCT) And (tok.text = ')') Then
          ctx.parse.proc_decl_state := PDS_AFTER_PARAMS
        Else
          SourceErrorAt(ctx, tok.line, tok.col,
                        'parametre ou ) attendu dans PROCEDURE');
      End;
    PDS_AFTER_PARAMS:
      Begin
        If (tok.kind = TK_KEYWORD) And (tok.text = 'OPTIONS') Then
          ctx.parse.proc_decl_state := PDS_OPTIONS
        Else If (tok.kind = TK_KEYWORD) And (tok.text = 'RETURNS') Then
          ctx.parse.proc_decl_state := PDS_RETURNS
        Else If (tok.kind = TK_PUNCT) And (tok.text = ';') Then
          BeginProcedureBody(ctx, tok)
        Else
          SourceErrorAt(ctx, tok.line, tok.col,
                        'OPTIONS, RETURNS ou ; attendu apres parametres');
      End;
    PDS_OPTIONS:
      Begin
        If (tok.kind = TK_PUNCT) And (tok.text = '(') Then
          ctx.parse.proc_decl_state := PDS_OPTIONS_ARGS
        Else
          SourceErrorAt(ctx, tok.line, tok.col,
                        '( attendu apres OPTIONS');
      End;
    PDS_OPTIONS_ARGS:
      Begin
        If (tok.kind = TK_KEYWORD) And (tok.text = 'MAIN') Then
          MarkProcedureMain(ctx, tok)
        Else If (tok.kind = TK_PUNCT) And (tok.text = ')') Then
          ctx.parse.proc_decl_state := PDS_AFTER_PARAMS;
      End;
    PDS_RETURNS:
      Begin
        If (tok.kind = TK_PUNCT) And (tok.text = '(') Then
          Begin
            MarkProcedureReturns(ctx);
            ctx.parse.proc_decl_state := PDS_RETURNS_ARGS;
          End
        Else
          SourceErrorAt(ctx, tok.line, tok.col,
                        '( attendu apres RETURNS');
      End;
    PDS_RETURNS_ARGS:
      Begin
        If (tok.kind = TK_PUNCT) And (tok.text = ')') Then
          ctx.parse.proc_decl_state := PDS_AFTER_PARAMS;
      End;
  End;
End;

Procedure ResetDeclareState(Var ctx: TCompilerContext);
Begin
  ctx.parse.decl_state := DS_NONE;
  ctx.parse.decl_name := '';
  ctx.parse.decl_line := 1;
  ctx.parse.decl_col := 1;
  ctx.parse.decl_static := False;
  ctx.parse.decl_initial := False;
  ctx.parse.decl_array := False;
  ctx.parse.decl_array_size := 0;
  ctx.parse.decl_paren_depth := 0;
  ctx.parse.pending_index_name := '';
  ctx.parse.pending_index_line := 1;
  ctx.parse.pending_index_col := 1;
End;

Procedure FinishDeclare(Var ctx: TCompilerContext; tok: TToken);
Var
  owner: TLabelName;
  kind: TSymKind;
  before_count: Integer;
Begin
  owner := CurrentProcName(ctx);
  If owner = '' Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col,
                    'DECLARE hors procedure non supporte pour le moment');
      ResetDeclareState(ctx);
      Exit;
    End;

  If ctx.parse.decl_name = '' Then
    Begin
      SourceErrorAt(ctx, tok.line, tok.col,
                    'nom manquant dans DECLARE');
      ResetDeclareState(ctx);
      Exit;
    End;

  If ctx.parse.decl_array Then
    kind := SK_ARRAY
  Else If ctx.parse.decl_static Then
    kind := SK_STATIC
  Else
    kind := SK_LOCAL;

  before_count := ctx.symbols.count;
  AddSymbol(ctx, ctx.parse.decl_name, owner, kind,
            ctx.parse.decl_line, ctx.parse.decl_col, 0);
  If ctx.symbols.count > before_count Then
    Begin
      If ctx.parse.decl_array Then
        SetSymbolStorage(ctx, ctx.symbols.count, ctx.parse.decl_static,
                         ctx.parse.decl_initial, 1,
                         ctx.parse.decl_array_size)
      Else
        SetSymbolStorage(ctx, ctx.symbols.count, ctx.parse.decl_static,
                         ctx.parse.decl_initial, 0, 0);
    End;
  ResetDeclareState(ctx);
End;

Procedure ParseDeclareToken(Var ctx: TCompilerContext; tok: TToken);
Begin
  If ctx.parse.proc_decl_state <> PDS_NONE Then
    Exit;

  Case ctx.parse.decl_state Of
    DS_NONE:
      Begin
        If (tok.kind = TK_KEYWORD) And
           ((tok.text = 'DECLARE') Or (tok.text = 'DCL')) Then
          Begin
            If ctx.parse.open_proc = 0 Then
              SourceErrorAt(ctx, tok.line, tok.col,
                            'DECLARE hors procedure')
            Else
              ctx.parse.decl_state := DS_EXPECT_NAME;
          End;
      End;
    DS_EXPECT_NAME:
      Begin
        If IsNameToken(tok) Then
          Begin
            ctx.parse.decl_name := UpperStr(tok.text);
            ctx.parse.decl_line := tok.line;
            ctx.parse.decl_col := tok.col;
            ctx.parse.decl_state := DS_AFTER_NAME;
          End
        Else
          Begin
            SourceErrorAt(ctx, tok.line, tok.col,
                          'nom attendu apres DECLARE');
            ResetDeclareState(ctx);
          End;
      End;
    DS_AFTER_NAME:
      Begin
        If (tok.kind = TK_PUNCT) And (tok.text = '(') And
           (Not ctx.parse.decl_array) And
           (Not ctx.parse.decl_initial) Then
          Begin
            ctx.parse.decl_array := True;
            ctx.parse.decl_paren_depth := 1;
            ctx.parse.decl_state := DS_ARRAY_DIMS;
          End
        Else If (tok.kind = TK_KEYWORD) And
                ((tok.text = 'FIXED') Or (tok.text = 'BINARY')) Then
          Begin
          End
        Else If (tok.kind = TK_KEYWORD) And (tok.text = 'STATIC') Then
          ctx.parse.decl_static := True
        Else If (tok.kind = TK_KEYWORD) And
                ((tok.text = 'INITIAL') Or (tok.text = 'INIT')) Then
          Begin
            ctx.parse.decl_initial := True;
            ctx.parse.decl_state := DS_INITIAL;
          End
        Else If (tok.kind = TK_PUNCT) And (tok.text = ';') Then
          FinishDeclare(ctx, tok)
        Else
          SourceErrorAt(ctx, tok.line, tok.col,
                        'attribut DECLARE inattendu');
      End;
    DS_ARRAY_DIMS:
      Begin
        If (tok.kind = TK_PUNCT) And (tok.text = '(') Then
          Inc(ctx.parse.decl_paren_depth)
        Else If (tok.kind = TK_INTEGER) And (ctx.parse.decl_paren_depth = 1) Then
          Begin
            If (Not ParseLong(tok.text, ctx.parse.decl_array_size)) Or
               (ctx.parse.decl_array_size <= 0) Then
              SourceErrorAt(ctx, tok.line, tok.col,
                            'dimension de tableau invalide');
          End
        Else If IsNameToken(tok) Then
          SourceErrorAt(ctx, tok.line, tok.col,
                        'dimension de tableau constante attendue')
        Else If (tok.kind = TK_PUNCT) And (tok.text = ')') Then
          Begin
            Dec(ctx.parse.decl_paren_depth);
            If ctx.parse.decl_paren_depth = 0 Then
              Begin
                If ctx.parse.decl_array_size <= 0 Then
                  SourceErrorAt(ctx, tok.line, tok.col,
                                'dimension de tableau manquante');
                ctx.parse.decl_state := DS_AFTER_NAME;
              End;
          End;
      End;
    DS_INITIAL:
      Begin
        If (tok.kind = TK_PUNCT) And (tok.text = '(') Then
          Inc(ctx.parse.decl_paren_depth)
        Else If (tok.kind = TK_PUNCT) And (tok.text = ')') Then
          Begin
            If ctx.parse.decl_paren_depth > 0 Then
              Dec(ctx.parse.decl_paren_depth);
            If ctx.parse.decl_paren_depth = 0 Then
              ctx.parse.decl_state := DS_AFTER_NAME;
          End
        Else If (tok.kind = TK_PUNCT) And (tok.text = ';') And
                (ctx.parse.decl_paren_depth = 0) Then
          FinishDeclare(ctx, tok);
      End;
  End;
End;

Procedure ParseArrayUseToken(Var ctx: TCompilerContext; tok: TToken);
Var
  sym_idx: Integer;
  owner: TLabelName;
Begin
  If ctx.parse.proc_decl_state <> PDS_NONE Then
    Exit;
  If ctx.parse.decl_state <> DS_NONE Then
    Exit;
  If ctx.parse.end_pending Then
    Exit;

  If (tok.kind = TK_PUNCT) And (tok.text = '(') And
     ctx.parse.have_prev And IsNameToken(ctx.parse.prev_token) Then
    Begin
      owner := CurrentProcName(ctx);
      sym_idx := FindScopedSymbolAny(ctx, ctx.parse.prev_token.text, owner);
      If sym_idx <> 0 Then
        Begin
          If ctx.symbols.symbols[sym_idx].kind = SK_ARRAY Then
            Inc(ctx.parse.array_ref_count)
          Else If (ctx.symbols.symbols[sym_idx].kind = SK_LOCAL) Or
                  (ctx.symbols.symbols[sym_idx].kind = SK_STATIC) Or
                  (ctx.symbols.symbols[sym_idx].kind = SK_PARAM) Then
            Begin
              Inc(ctx.parse.bad_array_ref_count);
              SourceErrorAt(ctx, ctx.parse.prev_token.line,
                            ctx.parse.prev_token.col,
                            'indexation appliquee a un symbole non tableau');
            End;
        End;
    End;
End;

Function TokenTextAt(Var ctx: TCompilerContext; idx: Integer;
                     text: TString): Boolean;
Begin
  If (idx < 1) Or (idx > ctx.lex.token_count) Then
    TokenTextAt := False
  Else
    TokenTextAt := UpperStr(ctx.lex.tokens[idx].text) = UpperStr(text);
End;

Function TokenKindTextAt(Var ctx: TCompilerContext; idx: Integer;
                         kind: TTokenKind; text: TString): Boolean;
Begin
  TokenKindTextAt := (idx >= 1) And (idx <= ctx.lex.token_count) And
                     (ctx.lex.tokens[idx].kind = kind) And
                     (UpperStr(ctx.lex.tokens[idx].text) = UpperStr(text));
End;

Function FindStatementEnd(Var ctx: TCompilerContext; start_idx: Integer): Integer;
Var
  i: Integer;
Begin
  FindStatementEnd := Integer(ctx.lex.token_count);
  For i := start_idx To Integer(ctx.lex.token_count) Do
    If TokenKindTextAt(ctx, i, TK_PUNCT, ';') Then
      Begin
        FindStatementEnd := i;
        Exit;
      End;
End;

Function FindTokenBefore(Var ctx: TCompilerContext; first_idx, last_idx: Integer;
                         text: TString): Integer;
Var
  i: Integer;
Begin
  FindTokenBefore := 0;
  For i := first_idx To last_idx Do
    If TokenTextAt(ctx, i, text) Then
      Begin
        FindTokenBefore := i;
        Exit;
      End;
End;

Function FindMatchingParen(Var ctx: TCompilerContext; open_idx: Integer;
                           last_idx: Integer): Integer;
Var
  i, depth: Integer;
Begin
  FindMatchingParen := 0;
  depth := 0;
  For i := open_idx To last_idx Do
    Begin
      If TokenKindTextAt(ctx, i, TK_PUNCT, '(') Then
        Inc(depth)
      Else If TokenKindTextAt(ctx, i, TK_PUNCT, ')') Then
        Begin
          Dec(depth);
          If depth = 0 Then
            Begin
              FindMatchingParen := i;
              Exit;
            End;
        End;
    End;
End;

Procedure ExprErrorAt(Var ctx: TCompilerContext; idx: Integer; msg: TString);
Var
  tok: TToken;
Begin
  Inc(ctx.parse.expr_error_count);
  If (idx >= 1) And (idx <= ctx.lex.token_count) Then
    tok := ctx.lex.tokens[idx]
  Else
    tok := ctx.lex.eof_token;
  SourceErrorAt(ctx, tok.line, tok.col, msg);
End;

Function IsMulOp(Var ctx: TCompilerContext; idx: Integer): Boolean;
Begin
  IsMulOp := TokenKindTextAt(ctx, idx, TK_OPERATOR, '*') Or
             TokenKindTextAt(ctx, idx, TK_OPERATOR, '/') Or
             TokenTextAt(ctx, idx, 'MOD');
End;

Function IsAddOp(Var ctx: TCompilerContext; idx: Integer): Boolean;
Begin
  IsAddOp := TokenKindTextAt(ctx, idx, TK_OPERATOR, '+') Or
             TokenKindTextAt(ctx, idx, TK_OPERATOR, '-');
End;

Function IsCompareOp(Var ctx: TCompilerContext; idx: Integer): Boolean;
Begin
  IsCompareOp := TokenKindTextAt(ctx, idx, TK_OPERATOR, '=') Or
                 TokenKindTextAt(ctx, idx, TK_OPERATOR, '<') Or
                 TokenKindTextAt(ctx, idx, TK_OPERATOR, '<=') Or
                 TokenKindTextAt(ctx, idx, TK_OPERATOR, '>') Or
                 TokenKindTextAt(ctx, idx, TK_OPERATOR, '>=') Or
                 TokenKindTextAt(ctx, idx, TK_OPERATOR, '^=') Or
                 TokenKindTextAt(ctx, idx, TK_OPERATOR, '~=');
End;

Function UnknownFixedExpr: TExprInfo;
Begin
  UnknownFixedExpr.typ := FixedBinaryType;
  UnknownFixedExpr.is_const := False;
  UnknownFixedExpr.int_value := 0;
End;

Function ConstFixedExpr(value: LongInt): TExprInfo;
Begin
  ConstFixedExpr.typ := FixedBinaryType;
  ConstFixedExpr.is_const := True;
  ConstFixedExpr.int_value := value;
End;

Function UnknownExpr: TExprInfo;
Begin
  UnknownExpr.typ := NoType;
  UnknownExpr.is_const := False;
  UnknownExpr.int_value := 0;
End;

Function BuiltinKindOf(name: TLabelName): TBuiltinKind;
Var
  u: TLabelName;
Begin
  u := UpperStr(name);
  If u = 'ABS' Then
    BuiltinKindOf := BI_ABS
  Else If u = 'MAX' Then
    BuiltinKindOf := BI_MAX
  Else If u = 'MIN' Then
    BuiltinKindOf := BI_MIN
  Else If u = 'MOD' Then
    BuiltinKindOf := BI_MOD
  Else
    BuiltinKindOf := BI_NONE;
End;

Function BuiltinName(kind: TBuiltinKind): TString;
Begin
  Case kind Of
    BI_ABS: BuiltinName := 'ABS';
    BI_MAX: BuiltinName := 'MAX';
    BI_MIN: BuiltinName := 'MIN';
    BI_MOD: BuiltinName := 'MOD';
  Else
    BuiltinName := '<unknown>';
  End;
End;

Function BuiltinArity(kind: TBuiltinKind): Integer;
Begin
  Case kind Of
    BI_ABS: BuiltinArity := 1;
    BI_MAX: BuiltinArity := 2;
    BI_MIN: BuiltinArity := 2;
    BI_MOD: BuiltinArity := 2;
  Else
    BuiltinArity := 0;
  End;
End;

Procedure BuiltinErrorAt(Var ctx: TCompilerContext; idx: Integer; msg: TString);
Begin
  Inc(ctx.parse.builtin_error_count);
  ExprErrorAt(ctx, idx, msg);
End;

Function ValidateBuiltinCall(Var ctx: TCompilerContext; kind: TBuiltinKind;
                             tok_idx: Integer; arg_count: Integer;
                             Var args: TExprArgTable;
                             Var result_expr: TExprInfo): Boolean;
Var
  i, expected: Integer;
  all_const: Boolean;
Begin
  ValidateBuiltinCall := False;
  result_expr := UnknownFixedExpr;
  Inc(ctx.parse.builtin_call_count);

  expected := BuiltinArity(kind);
  If arg_count <> expected Then
    Begin
      BuiltinErrorAt(ctx, tok_idx, BuiltinName(kind) + ' attend ' +
                     Chr(Ord('0') + expected) + ' argument(s)');
      Exit;
    End;

  For i := 1 To arg_count Do
    If args[i].typ.kind <> TY_FIXED_BINARY Then
      Begin
        BuiltinErrorAt(ctx, tok_idx,
                       BuiltinName(kind) + ' attend des arguments FIXED BINARY');
        Exit;
      End;

  all_const := True;
  For i := 1 To arg_count Do
    If Not args[i].is_const Then
      all_const := False;

  If all_const Then
    Case kind Of
      BI_ABS:
        Begin
          If args[1].int_value < 0 Then
            result_expr := ConstFixedExpr(-args[1].int_value)
          Else
            result_expr := ConstFixedExpr(args[1].int_value);
        End;
      BI_MAX:
        Begin
          If args[1].int_value >= args[2].int_value Then
            result_expr := ConstFixedExpr(args[1].int_value)
          Else
            result_expr := ConstFixedExpr(args[2].int_value);
        End;
      BI_MIN:
        Begin
          If args[1].int_value <= args[2].int_value Then
            result_expr := ConstFixedExpr(args[1].int_value)
          Else
            result_expr := ConstFixedExpr(args[2].int_value);
        End;
      BI_MOD:
        Begin
          If args[2].int_value = 0 Then
            Begin
              BuiltinErrorAt(ctx, tok_idx, 'MOD avec diviseur constant nul');
              Exit;
            End;
          result_expr := ConstFixedExpr(args[1].int_value Mod args[2].int_value);
        End;
    End;

  ValidateBuiltinCall := True;
End;

Function ParseExprCompare(Var ctx: TCompilerContext; Var pos: Integer;
                          limit: Integer; Var expr: TExprInfo): Boolean; Forward;

Function ParseExprPrimary(Var ctx: TCompilerContext; Var pos: Integer;
                          limit: Integer; Var expr: TExprInfo): Boolean;
Var
  ok: Boolean;
  name: TLabelName;
  name_idx: Integer;
  args: TExprArgTable;
  arg_count: Integer;
  arg_expr: TExprInfo;
  builtin: TBuiltinKind;
Begin
  ParseExprPrimary := False;
  expr := UnknownExpr;
  If pos > limit Then
    Begin
      ExprErrorAt(ctx, limit, 'expression incomplete');
      Exit;
    End;

  If (ctx.lex.tokens[pos].kind = TK_INTEGER) Or
     (ctx.lex.tokens[pos].kind = TK_STRING) Then
    Begin
      If ctx.lex.tokens[pos].kind = TK_INTEGER Then
        expr := ConstFixedExpr(ctx.lex.tokens[pos].int_val)
      Else
        expr := UnknownExpr;
      Inc(pos);
      ParseExprPrimary := True;
      Exit;
    End;

  If IsNameToken(ctx.lex.tokens[pos]) Then
    Begin
      name := UpperStr(ctx.lex.tokens[pos].text);
      name_idx := pos;
      expr := UnknownFixedExpr;
      Inc(pos);
      If (pos <= limit) And TokenKindTextAt(ctx, pos, TK_PUNCT, '(') Then
        Begin
          arg_count := 0;
          Inc(pos);
          If (pos <= limit) And TokenKindTextAt(ctx, pos, TK_PUNCT, ')') Then
            Inc(pos)
          Else
            Begin
              Repeat
                ok := ParseExprCompare(ctx, pos, limit, arg_expr);
                If Not ok Then
                  Exit;
                If arg_count >= MAX_CALL_ARGS Then
                  Begin
                    ExprErrorAt(ctx, name_idx, 'trop d''arguments dans appel');
                    Exit;
                  End;
                Inc(arg_count);
                args[arg_count] := arg_expr;
                If (pos <= limit) And TokenKindTextAt(ctx, pos, TK_PUNCT, ',') Then
                  Inc(pos)
                Else
                  Break;
              Until False;

              If (pos <= limit) And TokenKindTextAt(ctx, pos, TK_PUNCT, ')') Then
                Inc(pos)
              Else
                Begin
                  ExprErrorAt(ctx, pos, ') attendu dans appel ou indexation');
                  Exit;
                End;
            End;

          builtin := BuiltinKindOf(name);
          If builtin <> BI_NONE Then
            If Not ValidateBuiltinCall(ctx, builtin, name_idx, arg_count,
                                       args, expr) Then
              Exit;
        End;
      ParseExprPrimary := True;
      Exit;
    End;

  If TokenKindTextAt(ctx, pos, TK_PUNCT, '(') Then
    Begin
      Inc(pos);
      ok := ParseExprCompare(ctx, pos, limit, expr);
      If Not ok Then
        Exit;
      If (pos <= limit) And TokenKindTextAt(ctx, pos, TK_PUNCT, ')') Then
        Begin
          Inc(pos);
          ParseExprPrimary := True;
        End
      Else
        ExprErrorAt(ctx, pos, ') attendu dans expression');
      Exit;
    End;

  ExprErrorAt(ctx, pos, 'terme attendu dans expression');
End;

Function ParseExprUnary(Var ctx: TCompilerContext; Var pos: Integer;
                        limit: Integer; Var expr: TExprInfo): Boolean;
Var
  ok: Boolean;
Begin
  If (pos <= limit) And
     (TokenKindTextAt(ctx, pos, TK_OPERATOR, '-') Or
      TokenKindTextAt(ctx, pos, TK_OPERATOR, '+')) Then
    Begin
      If TokenKindTextAt(ctx, pos, TK_OPERATOR, '-') Then
        Begin
          Inc(pos);
          ok := ParseExprUnary(ctx, pos, limit, expr);
          ParseExprUnary := ok;
          If ok And expr.is_const Then
            expr.int_value := -expr.int_value;
        End
      Else
        Begin
          Inc(pos);
          ParseExprUnary := ParseExprUnary(ctx, pos, limit, expr);
        End;
    End
  Else
    ParseExprUnary := ParseExprPrimary(ctx, pos, limit, expr);
End;

Function ApplyBinaryConst(Var ctx: TCompilerContext; op_idx: Integer;
                          left, right: TExprInfo;
                          Var expr: TExprInfo): Boolean;
Var
  op: TString;
Begin
  ApplyBinaryConst := True;
  expr := UnknownFixedExpr;
  op := UpperStr(ctx.lex.tokens[op_idx].text);
  If Not (left.is_const And right.is_const) Then
    Exit;

  If op = '+' Then
    expr := ConstFixedExpr(left.int_value + right.int_value)
  Else If op = '-' Then
    expr := ConstFixedExpr(left.int_value - right.int_value)
  Else If op = '*' Then
    expr := ConstFixedExpr(left.int_value * right.int_value)
  Else If op = '/' Then
    Begin
      If right.int_value = 0 Then
        Begin
          ExprErrorAt(ctx, op_idx, 'division constante par zero');
          ApplyBinaryConst := False;
          Exit;
        End;
      expr := ConstFixedExpr(left.int_value Div right.int_value);
    End
  Else If op = 'MOD' Then
    Begin
      If right.int_value = 0 Then
        Begin
          BuiltinErrorAt(ctx, op_idx, 'MOD avec diviseur constant nul');
          ApplyBinaryConst := False;
          Exit;
        End;
      expr := ConstFixedExpr(left.int_value Mod right.int_value);
    End
  Else If op = '=' Then
    expr := ConstFixedExpr(Ord(left.int_value = right.int_value))
  Else If op = '<' Then
    expr := ConstFixedExpr(Ord(left.int_value < right.int_value))
  Else If op = '<=' Then
    expr := ConstFixedExpr(Ord(left.int_value <= right.int_value))
  Else If op = '>' Then
    expr := ConstFixedExpr(Ord(left.int_value > right.int_value))
  Else If op = '>=' Then
    expr := ConstFixedExpr(Ord(left.int_value >= right.int_value))
  Else If (op = '^=') Or (op = '~=') Then
    expr := ConstFixedExpr(Ord(left.int_value <> right.int_value));
End;

Function ParseExprMul(Var ctx: TCompilerContext; Var pos: Integer;
                      limit: Integer; Var expr: TExprInfo): Boolean;
Var
  ok: Boolean;
  right: TExprInfo;
  op_idx: Integer;
Begin
  ok := ParseExprUnary(ctx, pos, limit, expr);
  ParseExprMul := ok;
  If Not ok Then
    Exit;

  While (pos <= limit) And IsMulOp(ctx, pos) Do
    Begin
      op_idx := pos;
      If TokenTextAt(ctx, op_idx, 'MOD') Then
        Inc(ctx.parse.builtin_call_count);
      Inc(pos);
      If Not ParseExprUnary(ctx, pos, limit, right) Then
        Begin
          ParseExprMul := False;
          Exit;
        End;
      If Not ApplyBinaryConst(ctx, op_idx, expr, right, expr) Then
        Begin
          ParseExprMul := False;
          Exit;
        End;
    End;
End;

Function ParseExprAdd(Var ctx: TCompilerContext; Var pos: Integer;
                      limit: Integer; Var expr: TExprInfo): Boolean;
Var
  ok: Boolean;
  right: TExprInfo;
  op_idx: Integer;
Begin
  ok := ParseExprMul(ctx, pos, limit, expr);
  ParseExprAdd := ok;
  If Not ok Then
    Exit;

  While (pos <= limit) And IsAddOp(ctx, pos) Do
    Begin
      op_idx := pos;
      Inc(pos);
      If Not ParseExprMul(ctx, pos, limit, right) Then
        Begin
          ParseExprAdd := False;
          Exit;
        End;
      If Not ApplyBinaryConst(ctx, op_idx, expr, right, expr) Then
        Begin
          ParseExprAdd := False;
          Exit;
        End;
    End;
End;

Function ParseExprCompare(Var ctx: TCompilerContext; Var pos: Integer;
                          limit: Integer; Var expr: TExprInfo): Boolean;
Var
  ok: Boolean;
  right: TExprInfo;
  op_idx: Integer;
Begin
  ok := ParseExprAdd(ctx, pos, limit, expr);
  ParseExprCompare := ok;
  If Not ok Then
    Exit;

  While (pos <= limit) And IsCompareOp(ctx, pos) Do
    Begin
      op_idx := pos;
      Inc(pos);
      If Not ParseExprAdd(ctx, pos, limit, right) Then
        Begin
          ParseExprCompare := False;
          Exit;
        End;
      If Not ApplyBinaryConst(ctx, op_idx, expr, right, expr) Then
        Begin
          ParseExprCompare := False;
          Exit;
        End;
    End;
End;

Function ParseExpressionRange(Var ctx: TCompilerContext; first_idx,
                              last_idx: Integer): Boolean;
Var
  pos: Integer;
  expr: TExprInfo;
Begin
  ParseExpressionRange := False;
  Inc(ctx.parse.expr_count);

  If first_idx > last_idx Then
    Begin
      ExprErrorAt(ctx, first_idx, 'expression attendue');
      Exit;
    End;

  pos := first_idx;
  If Not ParseExprCompare(ctx, pos, last_idx, expr) Then
    Exit;

  If pos <= last_idx Then
    Begin
      ExprErrorAt(ctx, pos, 'operateur inattendu dans expression');
      Exit;
    End;

  ParseExpressionRange := True;
End;

Function ParseParenExpressionAt(Var ctx: TCompilerContext; open_idx,
                                limit_idx: Integer; Var close_idx: Integer): Boolean;
Begin
  ParseParenExpressionAt := False;
  close_idx := FindMatchingParen(ctx, open_idx, limit_idx);
  If close_idx = 0 Then
    Begin
      ExprErrorAt(ctx, open_idx, ') attendu dans expression parenthesee');
      Exit;
    End;
  ParseParenExpressionAt := ParseExpressionRange(ctx, open_idx + 1,
                                                 close_idx - 1);
End;

Procedure ValidateExpressions(Var ctx: TCompilerContext);
Var
  i, stmt_end, close_idx, eq_idx, to_idx, by_idx: Integer;
Begin
  i := 1;
  While i <= ctx.lex.token_count Do
    Begin
      If TokenTextAt(ctx, i, 'DO') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          eq_idx := FindTokenBefore(ctx, i + 1, stmt_end - 1, '=');
          to_idx := FindTokenBefore(ctx, i + 1, stmt_end - 1, 'TO');
          by_idx := FindTokenBefore(ctx, i + 1, stmt_end - 1, 'BY');
          If (eq_idx <> 0) And (to_idx <> 0) And (eq_idx < to_idx) Then
            Begin
              ParseExpressionRange(ctx, eq_idx + 1, to_idx - 1);
              If (by_idx <> 0) And (by_idx > to_idx) Then
                Begin
                  ParseExpressionRange(ctx, to_idx + 1, by_idx - 1);
                  ParseExpressionRange(ctx, by_idx + 1, stmt_end - 1);
                End
              Else
                ParseExpressionRange(ctx, to_idx + 1, stmt_end - 1);
              i := stmt_end + 1;
              Continue;
            End;
        End
      Else If TokenTextAt(ctx, i, 'RETURN') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          If TokenKindTextAt(ctx, i + 1, TK_PUNCT, '(') Then
            ParseParenExpressionAt(ctx, i + 1, stmt_end - 1, close_idx)
          Else
            ParseExpressionRange(ctx, i + 1, stmt_end - 1);
          i := stmt_end + 1;
          Continue;
        End
      Else If TokenTextAt(ctx, i, 'SELECT') Or TokenTextAt(ctx, i, 'WHEN') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          If TokenKindTextAt(ctx, i + 1, TK_PUNCT, '(') Then
            ParseParenExpressionAt(ctx, i + 1, stmt_end - 1, close_idx);
        End
      Else If TokenTextAt(ctx, i, 'PUT') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          If TokenTextAt(ctx, i + 1, 'LIST') And
             TokenKindTextAt(ctx, i + 2, TK_PUNCT, '(') Then
            ParseParenExpressionAt(ctx, i + 2, stmt_end - 1, close_idx);
        End
      Else If TokenTextAt(ctx, i, 'INITIAL') Or TokenTextAt(ctx, i, 'INIT') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          If TokenKindTextAt(ctx, i + 1, TK_PUNCT, '(') Then
            ParseParenExpressionAt(ctx, i + 1, stmt_end - 1, close_idx);
        End
      Else If TokenKindTextAt(ctx, i, TK_OPERATOR, '=') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          ParseExpressionRange(ctx, i + 1, stmt_end - 1);
          i := stmt_end + 1;
          Continue;
        End;

      Inc(i);
    End;
End;

Function ResolveLabelsAndGotos(Var ctx: TCompilerContext): Boolean;
Var
  i: Integer;
Begin
  ResolveLabelsAndGotos := False;

  If ctx.parse.pending_goto Then
    SourceErrorAt(ctx, ctx.lex.eof_token.line, ctx.lex.eof_token.col,
                  'nom d''etiquette attendu apres GOTO');

  If ctx.parse.end_pending Then
    SourceErrorAt(ctx, ctx.lex.eof_token.line, ctx.lex.eof_token.col,
                  'fin de fichier apres END incomplet');

  If ctx.parse.proc_decl_state <> PDS_NONE Then
    SourceErrorAt(ctx, ctx.lex.eof_token.line, ctx.lex.eof_token.col,
                  'declaration PROCEDURE incomplete');

  If ctx.parse.decl_state <> DS_NONE Then
    SourceErrorAt(ctx, ctx.lex.eof_token.line, ctx.lex.eof_token.col,
                  'declaration DECLARE incomplete');

  For i := 1 To ctx.parse.goto_count Do
    If FindLabel(ctx, ctx.parse.gotos[i].name) = 0 Then
      Begin
        Inc(ctx.parse.unresolved_gotos);
        SourceErrorAt(ctx, ctx.parse.gotos[i].line,
                      ctx.parse.gotos[i].col,
                      'GOTO vers une etiquette inconnue');
      End;

  If ctx.parse.proc_count = 0 Then
    SourceErrorAt(ctx, 1, 1, 'aucune PROCEDURE trouvee');

  If ctx.parse.main_proc_count = 0 Then
    SourceErrorAt(ctx, 1, 1, 'aucune PROCEDURE OPTIONS(MAIN) trouvee');

  For i := 1 To ctx.parse.proc_count Do
    If Not ctx.parse.procs[i].closed Then
      SourceErrorAt(ctx, ctx.parse.procs[i].decl_line,
                    ctx.parse.procs[i].decl_col,
                    'procedure non fermee par END');

  ValidateExpressions(ctx);

  ResolveLabelsAndGotos := ctx.errors = 0;
End;

Function LexSourceFile(Var ctx: TCompilerContext): Boolean;
Var
  f: Text;
  line: TSourceLine;
  io, pos, len, start_col: Integer;
  line_no: LongInt;
  ch: Char;
  text: TString;
  tok: TToken;
  in_comment: Boolean;
  comment_line: LongInt;
  comment_col: Integer;
Begin
  LexSourceFile := False;
  If Not ctx.source.loaded Then
    Begin
      PipelineError(ctx, 'source non chargee');
      Exit;
    End;

  ctx.lex.token_count := 0;
  ctx.lex.ident_count := 0;
  ctx.lex.keyword_count := 0;
  ctx.lex.integer_count := 0;
  ctx.lex.string_count := 0;
  ctx.lex.operator_count := 0;
  ctx.lex.punct_count := 0;
  ctx.lex.comment_count := 0;
  ResetParseInfo(ctx);
  ResetSourceCursor(ctx);

  Assign(f, ctx.source_name);
  Reset(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible de relire le fichier source');
      Exit;
    End;

  in_comment := False;
  comment_line := 1;
  comment_col := 1;
  line_no := 0;

  While Not Eof(f) Do
    Begin
      ReadLn(f, line);
      io := IOResult;
      If io <> 0 Then
        Begin
          Close(f);
          io := IOResult;
          PipelineError(ctx, 'erreur de lecture pendant le scan lexical');
          Exit;
        End;

      Inc(line_no);
      pos := 1;
      len := Length(line);

      While pos <= len Do
        Begin
          ctx.source.cur_line := line_no;
          ctx.source.cur_col := pos;
          ch := line[pos];

          If in_comment Then
            Begin
              If (ch = '*') And (pos < len) And (line[pos + 1] = '/') Then
                Begin
                  in_comment := False;
                  Inc(pos, 2);
                End
              Else
                Inc(pos);
            End
          Else If IsSpace(ch) Then
            Inc(pos)
          Else If (ch = '/') And (pos < len) And (line[pos + 1] = '*') Then
            Begin
              Inc(ctx.lex.comment_count);
              in_comment := True;
              comment_line := line_no;
              comment_col := pos;
              Inc(pos, 2);
            End
          Else If IsLetter(ch) Then
            Begin
              start_col := pos;
              text := '';
              While (pos <= len) And IsIdentChar(line[pos]) Do
                Begin
                  text := text + line[pos];
                  Inc(pos);
                End;
              If IsPL1Keyword(text) Then
                MakeToken(tok, TK_KEYWORD, UpperStr(text), line_no, start_col)
              Else
                MakeToken(tok, TK_IDENT, text, line_no, start_col);
              RegisterToken(ctx, tok);
            End
          Else If IsDigit(ch) Then
            Begin
              start_col := pos;
              text := '';
              While (pos <= len) And IsDigit(line[pos]) Do
                Begin
                  text := text + line[pos];
                  Inc(pos);
                End;
              MakeToken(tok, TK_INTEGER, text, line_no, start_col);
              RegisterToken(ctx, tok);
            End
          Else If ch = '''' Then
            Begin
              start_col := pos;
              text := '';
              Inc(pos);
              While (pos <= len) And (line[pos] <> '''') Do
                Begin
                  text := text + line[pos];
                  Inc(pos);
                End;
              If pos > len Then
                SourceErrorAt(ctx, line_no, start_col,
                              'chaine non terminee')
              Else
                Begin
                  Inc(pos);
                  MakeToken(tok, TK_STRING, text, line_no, start_col);
                  RegisterToken(ctx, tok);
                End;
            End
          Else If IsPunct(ch) Then
            Begin
              text := ch;
              MakeToken(tok, TK_PUNCT, text, line_no, pos);
              RegisterToken(ctx, tok);
              Inc(pos);
            End
          Else If IsOperatorStart(ch) Then
            Begin
              start_col := pos;
              text := ch;
              If (pos < len) Then
                Begin
                  If ((ch = '<') Or (ch = '>') Or (ch = '^') Or
                      (ch = '~')) And (line[pos + 1] = '=') Then
                    Begin
                      text := text + '=';
                      Inc(pos);
                    End;
                End;
              MakeToken(tok, TK_OPERATOR, text, line_no, start_col);
              RegisterToken(ctx, tok);
              Inc(pos);
            End
          Else
            Begin
              SourceErrorAt(ctx, line_no, pos,
                            'caractere inattendu dans le source');
              Inc(pos);
            End;
        End;
    End;

  Close(f);
  io := IOResult;

  If in_comment Then
    SourceErrorAt(ctx, comment_line, comment_col,
                  'commentaire non termine');

  MakeToken(ctx.lex.eof_token, TK_EOF, '', ctx.source.line_count + 1, 1);
  LexSourceFile := ctx.errors = 0;
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

Function FileExt(name: TString): TString;
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
    FileExt := ''
  Else
    FileExt := Copy(name, dot_pos, Length(name) - dot_pos + 1);
End;

Function HasFileExt(name: TString): Boolean;
Begin
  HasFileExt := FileExt(name) <> '';
End;

Function WithExt(name, ext: TString): TString;
Begin
  WithExt := BaseNameNoExt(name) + ext;
End;

Function EnsureExt(name, ext: TString): TString;
Begin
  If HasFileExt(name) Then
    EnsureExt := name
  Else
    EnsureExt := name + ext;
End;

Function SameExt(name, ext: TString): Boolean;
Begin
  SameExt := UpperStr(FileExt(name)) = UpperStr(ext);
End;

Function IsValidSourceName(name: TString): Boolean;
Begin
  IsValidSourceName := SameExt(name, EXT_PLI) Or SameExt(name, EXT_PL1);
End;

Function IsValidOutputName(name, ext: TString): Boolean;
Begin
  IsValidOutputName := (Not HasFileExt(name)) Or SameExt(name, ext);
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
  Writeln;
  Writeln('Conventions: entree .PLI/.PL1, sortie .EXE par defaut, .OBJ avec -obj.');
End;

Procedure PrintOptions(Var ctx: TCompilerContext);
Begin
  Writeln('Source : ', ctx.source_name);
  If ctx.options.output_mode = OM_OBJ Then
    Writeln('Mode   : OBJ seulement')
  Else
    Writeln('Mode   : EXE Win32');
  If ctx.options.emit_asm Then
    Begin
      Writeln('ASM    : oui');
      Writeln('ASM out: ', ctx.asm_name);
    End
  Else
    Writeln('ASM    : non');
  If ctx.options.output_mode = OM_OBJ Then
    Writeln('OBJ out: ', ctx.obj_name, ' (final)')
  Else
    Begin
      Writeln('OBJ out: ', ctx.obj_name, ' (intermediaire)');
      Writeln('EXE out: ', ctx.exe_name, ' (final)');
    End;
End;

Procedure PrintSourceInfo(Var ctx: TCompilerContext);
Begin
  Writeln('Source chargee: ', ctx.source.line_count, ' lignes, ',
          ctx.source.char_count, ' caracteres, ligne max ',
          ctx.source.max_line_len);
End;

Procedure PrintLexInfo(Var ctx: TCompilerContext);
Begin
  Writeln('Table mots-cles PL/1: ', PL1_KEYWORD_COUNT, ' entrees');
  Writeln('Tokens : ', ctx.lex.token_count,
          ' (mots-cles=', ctx.lex.keyword_count,
          ', ident=', ctx.lex.ident_count,
          ', entiers=', ctx.lex.integer_count,
          ', chaines=', ctx.lex.string_count,
          ', ops=', ctx.lex.operator_count,
          ', ponct=', ctx.lex.punct_count,
          ', commentaires=', ctx.lex.comment_count, ')');
End;

Procedure PrintParseInfo(Var ctx: TCompilerContext);
Var
  i, j: Integer;
Begin
  Writeln('Etiquettes: ', ctx.parse.label_count,
          ' (procedures=', ctx.parse.proc_label_count,
          ', controle=', ctx.parse.control_label_count,
          ', GOTO=', ctx.parse.goto_count,
          ', non resolus=', ctx.parse.unresolved_gotos,
          ', doublons=', ctx.parse.duplicate_labels,
          ', indexations=', ctx.parse.array_ref_count,
          ', indexations invalides=', ctx.parse.bad_array_ref_count,
          ', expressions=', ctx.parse.expr_count,
          ', expressions invalides=', ctx.parse.expr_error_count,
          ', built-ins=', ctx.parse.builtin_call_count,
          ', built-ins invalides=', ctx.parse.builtin_error_count, ')');
  Writeln('Procedures: ', ctx.parse.proc_count,
          ' (MAIN=', ctx.parse.main_proc_count, ')');
  For i := 1 To ctx.parse.proc_count Do
    Begin
      Write('  ', ctx.parse.procs[i].name, '(');
      For j := 1 To ctx.parse.procs[i].param_count Do
        Begin
          If j > 1 Then
            Write(', ');
          Write(ctx.parse.procs[i].params[j]);
        End;
      Write(')');
      If ctx.parse.procs[i].has_returns Then
        Write(' RETURNS ', TypeKindName(ctx.parse.procs[i].return_type.kind),
              ' via ', ctx.parse.procs[i].return_type.return_reg);
      If ctx.parse.procs[i].is_main Then
        Write(' OPTIONS(MAIN)');
      If ctx.parse.procs[i].closed Then
        Writeln(' END@', ctx.parse.procs[i].end_line)
      Else
        Writeln(' non fermee');
    End;
End;

Procedure PrintSymbolInfo(Var ctx: TCompilerContext);
Var
  i: Integer;
Begin
  Writeln('Symboles: ', ctx.symbols.count,
          ' (proc=', ctx.symbols.proc_count,
          ', param=', ctx.symbols.param_count,
          ', local=', ctx.symbols.local_count,
          ', static=', ctx.symbols.static_count,
          ', array=', ctx.symbols.array_count,
          ', label=', ctx.symbols.label_count,
          ', runtime=', ctx.symbols.runtime_count,
          ', builtin=', ctx.symbols.builtin_count,
          ', doublons=', ctx.symbols.duplicate_count, ')');
  For i := 1 To ctx.symbols.count Do
    Begin
      Write('  ', SymKindName(ctx.symbols.symbols[i].kind), ' ');
      If ctx.symbols.symbols[i].owner <> '' Then
        Write(ctx.symbols.symbols[i].owner, '.');
      Write(ctx.symbols.symbols[i].name);
      If ctx.symbols.symbols[i].kind = SK_ARRAY Then
        Write(' [', ctx.symbols.symbols[i].lower_bound,
              '..', ctx.symbols.symbols[i].upper_bound, ']');
      If ctx.symbols.symbols[i].typ.kind <> TY_NONE Then
        Begin
          Write(' : ', TypeKindName(ctx.symbols.symbols[i].typ.kind),
                ' size=', ctx.symbols.symbols[i].typ.size,
                ' align=', ctx.symbols.symbols[i].typ.align);
          If ctx.symbols.symbols[i].typ.signed Then
            Write(' signed');
        End;
      If ctx.symbols.symbols[i].is_static Then
        Write(' STATIC');
      If ctx.symbols.symbols[i].has_initial Then
        Write(' INITIAL');
      Writeln;
    End;
End;

Function SetDefaultOutputNames(Var ctx: TCompilerContext): Boolean;
Var
  base_name: TString;
Begin
  SetDefaultOutputNames := False;
  base_name := BaseNameNoExt(ctx.source_name);

  If ctx.options.output_name <> '' Then
    Begin
      If ctx.options.output_mode = OM_OBJ Then
        Begin
          If Not IsValidOutputName(ctx.options.output_name, EXT_OBJ) Then
            Begin
              Writeln('PL1CW32: avec -obj, la sortie doit etre .obj');
              Exit;
            End;
          ctx.obj_name := EnsureExt(ctx.options.output_name, EXT_OBJ);
        End
      Else
        Begin
          If Not IsValidOutputName(ctx.options.output_name, EXT_EXE) Then
            Begin
              Writeln('PL1CW32: en mode par defaut, la sortie doit etre .exe');
              Exit;
            End;
          ctx.exe_name := EnsureExt(ctx.options.output_name, EXT_EXE);
        End;
    End;

  If ctx.options.emit_asm And (ctx.asm_name = '') Then
    ctx.asm_name := WithExt(base_name, EXT_ASM);
  If ctx.obj_name = '' Then
    ctx.obj_name := WithExt(base_name, EXT_OBJ);
  If (ctx.options.output_mode = OM_EXE) And (ctx.exe_name = '') Then
    ctx.exe_name := WithExt(base_name, EXT_EXE);

  SetDefaultOutputNames := True;
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

  If Not IsValidSourceName(ctx.source_name) Then
    Begin
      Writeln('PL1CW32: le fichier source doit avoir une extension .PLI ou .PL1');
      ParseArgs := EXIT_USAGE;
      Exit;
    End;

  If Not SetDefaultOutputNames(ctx) Then
    Begin
      ParseArgs := EXIT_USAGE;
      Exit;
    End;
End;

Function RunStage(Var ctx: TCompilerContext; stage: TCompileStage): Boolean;
Begin
  ctx.stage := stage;
  RunStage := False;

  Case stage Of
    CS_LOAD_SOURCE:
      Begin
        If LoadSourceFile(ctx) Then
          Begin
            ctx.last_art := AK_SOURCE_PL1;
            If ctx.options.verbose Then
              PrintSourceInfo(ctx);
            RunStage := True;
          End;
      End;
    CS_LEX_TOKENS:
      Begin
        If ctx.last_art <> AK_SOURCE_PL1 Then
          PipelineError(ctx, 'source PL/1 attendue')
        Else
          If LexSourceFile(ctx) Then
            Begin
              ctx.last_art := AK_TOKEN_STREAM;
              If ctx.options.verbose Then
                PrintLexInfo(ctx);
              RunStage := True;
            End;
      End;
    CS_PARSE_AST:
      Begin
        If ctx.last_art <> AK_TOKEN_STREAM Then
          PipelineError(ctx, 'flux de tokens attendu')
        Else
          If ResolveLabelsAndGotos(ctx) Then
            Begin
              ctx.last_art := AK_AST_IR;
              If ctx.options.verbose Then
                Begin
                  PrintParseInfo(ctx);
                  PrintSymbolInfo(ctx);
                End;
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
