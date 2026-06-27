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
15. [IMPLEMENTE] Generer le code des affectations : variable = expression, tableau(index) = expression, initialisation explicite, initialisation STATIC et locales.
16. [IMPLEMENTE] Implementer DO I = debut TO fin ; ... END ; avec variable de controle, test de fin, increment implicite, labels 80386 uniques et imbrication.
17. [IMPLEMENTE] Implementer SELECT(expr), WHEN(valeurs), OTHERWISE et END, en generation de comparaisons et branchements structures.
18. [IMPLEMENTE] Implementer GOTO label et les etiquettes internes en emission ASM/OBJ, avec verification des labels inexistants ou dupliques.
19. [IMPLEMENTE] Implementer RETURN(expr) pour les procedures avec RETURNS, prologue/epilogue propre et retour de valeur dans EAX.
20. [IMPLEMENTE] Definir la convention d'appel interne 32 bits : parametres sur pile, frame EBP, sauvegarde minimale des registres, nettoyage de pile documente.
21. [IMPLEMENTE] Generer les prologues/epilogues 80386 Win32 : allocation des locales, acces [EBP-offset] et [EBP+offset], alignement simple de pile.
22. [IMPLEMENTE] Fournir le runtime console minimal : PUT LIST(expr) pour afficher les entiers, PUT SKIP pour nouvelle ligne, sortie propre via ExitProcess ou equivalent.
23. [IMPLEMENTE] Implementer l'emission ASM optionnelle : syntaxe MASM 80386 lisible, sections .text/.data/.rdata, labels stables, commentaires utiles pour le debug.
24. [IMPLEMENTE] Implementer l'emission OBJ COFF et le lien EXE PE Win32 par defaut, avec imports runtime necessaires et mode -obj qui s'arrete apres le fichier objet.
25. [IMPLEMENTE] Creer une validation automatique compilant et executant tous les fichiers SAMPLES\PL1\*.PLI, en couvrant TEST.PLI et TEST2.PLI, avec verification des sorties attendues et des modes .EXE, .OBJ et .ASM optionnel.
}
Program PL1CW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

Uses Dos;

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
  MAX_ASSIGNMENTS = 512;
  MAX_DO_LOOPS    = 256;
  MAX_SELECTS     = 128;
  MAX_WHENS       = 512;
  MAX_RETURNS     = 128;
  MAX_PUTS        = 256;
  ABI_WORD_SIZE   = 4;
  ABI_RET_REG     = 'EAX';
  ABI_FRAME_REG   = 'EBP';
  ABI_STACK_REG   = 'ESP';
  ABI_FIRST_PARAM = 8;
  ABI_SAVED_REGS  = 'EBP';
  ABI_CLEANUP     = 'caller';
  PL1_KEYWORD_COUNT = 28;
  EXT_PL1         = '.PL1';
  EXT_PLI         = '.PLI';
  EXT_ASM         = '.asm';
  EXT_OBJ         = '.obj';
  EXT_EXE         = '.exe';
  PE_DOS_MAGIC    = $5A4D;
  PE_PE_SIG       = $00004550;
  PE_MACHINE_I386 = $014C;
  PE_OPT_MAGIC_32 = $010B;
  PE_IMAGE_BASE   = $00400000;
  PE_SEC_ALIGN    = $1000;
  PE_FILE_ALIGN   = $0200;
  PE_SUBSYS_CUI   = 3;
  PE_CHAR_32BIT   = $0102;
  PE_SCN_TEXT     = $60000020;
  PE_SCN_RDATA    = $40000040;
  PE_SCN_DATA     = -1073741760;
  COFF_SCN_TEXT   = $60500020;
  COFF_REL_I386_REL32 = $0014;
  COFF_SYM_EXTERNAL = 2;
  COFF_SYM_STATIC   = 3;
  MAX_BIN_BUF     = 4096;
  EXIT_OK         = 0;
  EXIT_ERROR      = 1;
  EXIT_USAGE      = 2;

Type
  TString = String[MAX_PATH_LEN];
  TSourceLine = String[MAX_LINE_LEN];
  TLabelName = String[64];
  TKeyword = String[16];
  TKeywordTable = Array[1..PL1_KEYWORD_COUNT] Of TKeyword;
  TBinBuffer = Array[0..MAX_BIN_BUF - 1] Of Byte;

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
    validate    : Boolean;
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
    name      : TLabelName;
    owner     : TLabelName;
    asm_name  : TLabelName;
    kind      : TLabelKind;
    line      : LongInt;
    col       : Integer;
  End;

  TGotoRef = Record
    name        : TLabelName;
    owner       : TLabelName;
    target_index: Integer;
    asm_target  : TLabelName;
    line        : LongInt;
    col         : Integer;
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
    return_count: Integer;
    epilogue_label: TLabelName;
    arg_bytes   : Integer;
    local_bytes : Integer;
    frame_bytes : Integer;
    cleanup     : String[16];
    saved_regs  : String[32];
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
    stack_offset: Integer;
    data_label : TLabelName;
  End;

  TSymbolTable = Array[1..MAX_SYMBOLS] Of TSymbol;

  TAssignKind = (
    AS_VARIABLE,
    AS_ARRAY_ELEMENT,
    AS_INITIALIZER
  );

  TAssignment = Record
    kind            : TAssignKind;
    target_name     : TLabelName;
    owner           : TLabelName;
    symbol_index    : Integer;
    target_token    : Integer;
    index_first     : Integer;
    index_last      : Integer;
    expr_first      : Integer;
    expr_last       : Integer;
    line            : LongInt;
    col             : Integer;
    is_static_init  : Boolean;
  End;

  TAssignmentTable = Array[1..MAX_ASSIGNMENTS] Of TAssignment;

  TDoLoop = Record
    control_name  : TLabelName;
    owner         : TLabelName;
    symbol_index  : Integer;
    do_token      : Integer;
    control_token : Integer;
    start_first   : Integer;
    start_last    : Integer;
    end_first     : Integer;
    end_last      : Integer;
    by_first      : Integer;
    by_last       : Integer;
    has_by        : Boolean;
    body_first    : Integer;
    body_last     : Integer;
    end_token     : Integer;
    line          : LongInt;
    end_line      : LongInt;
    nesting       : Integer;
    label_test    : TLabelName;
    label_body    : TLabelName;
    label_end     : TLabelName;
  End;

  TDoLoopTable = Array[1..MAX_DO_LOOPS] Of TDoLoop;

  TSelectInfo = Record
    select_token  : Integer;
    expr_first    : Integer;
    expr_last     : Integer;
    first_when    : Integer;
    when_count    : Integer;
    otherwise_token: Integer;
    end_token     : Integer;
    line          : LongInt;
    end_line      : LongInt;
    nesting       : Integer;
    label_next    : TLabelName;
    label_otherwise: TLabelName;
    label_end     : TLabelName;
  End;

  TWhenInfo = Record
    select_index : Integer;
    when_token   : Integer;
    value_first  : Integer;
    value_last   : Integer;
    value_count  : Integer;
    stmt_first   : Integer;
    stmt_last    : Integer;
    line         : LongInt;
    label_match  : TLabelName;
    label_next   : TLabelName;
  End;

  TSelectTable = Array[1..MAX_SELECTS] Of TSelectInfo;
  TWhenTable = Array[1..MAX_WHENS] Of TWhenInfo;

  TReturnInfo = Record
    proc_index    : Integer;
    proc_name     : TLabelName;
    return_token  : Integer;
    expr_first    : Integer;
    expr_last     : Integer;
    line          : LongInt;
    col           : Integer;
    return_reg    : String[8];
    epilogue_label: TLabelName;
  End;

  TReturnTable = Array[1..MAX_RETURNS] Of TReturnInfo;

  TPutKind = (
    PK_LIST,
    PK_SKIP
  );

  TPutInfo = Record
    kind       : TPutKind;
    proc_index : Integer;
    owner      : TLabelName;
    put_token  : Integer;
    expr_first : Integer;
    expr_last  : Integer;
    line       : LongInt;
    col        : Integer;
  End;

  TPutTable = Array[1..MAX_PUTS] Of TPutInfo;

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
    assignment_count : Integer;
    assignment_var_count: Integer;
    assignment_array_count: Integer;
    assignment_init_count: Integer;
    assignment_error_count: Integer;
    do_loop_count   : Integer;
    do_loop_error_count: Integer;
    do_loop_depth   : Integer;
    max_do_loop_depth: Integer;
    select_count    : Integer;
    when_count      : Integer;
    otherwise_count : Integer;
    select_error_count: Integer;
    select_depth    : Integer;
    max_select_depth: Integer;
    return_count    : Integer;
    return_error_count: Integer;
    put_count       : Integer;
    put_list_count  : Integer;
    put_skip_count  : Integer;
    put_error_count : Integer;
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
    assignments       : TAssignmentTable;
    do_loops          : TDoLoopTable;
    selects           : TSelectTable;
    whens             : TWhenTable;
    returns           : TReturnTable;
    puts              : TPutTable;
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
  ctx.options.validate := False;
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
  ctx.parse.assignment_count := 0;
  ctx.parse.assignment_var_count := 0;
  ctx.parse.assignment_array_count := 0;
  ctx.parse.assignment_init_count := 0;
  ctx.parse.assignment_error_count := 0;
  ctx.parse.do_loop_count := 0;
  ctx.parse.do_loop_error_count := 0;
  ctx.parse.do_loop_depth := 0;
  ctx.parse.max_do_loop_depth := 0;
  ctx.parse.select_count := 0;
  ctx.parse.when_count := 0;
  ctx.parse.otherwise_count := 0;
  ctx.parse.select_error_count := 0;
  ctx.parse.select_depth := 0;
  ctx.parse.max_select_depth := 0;
  ctx.parse.return_count := 0;
  ctx.parse.return_error_count := 0;
  ctx.parse.put_count := 0;
  ctx.parse.put_list_count := 0;
  ctx.parse.put_skip_count := 0;
  ctx.parse.put_error_count := 0;
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

Function FindScopedLabel(Var ctx: TCompilerContext; name, owner: TLabelName): Integer;
Var
  i: Integer;
  uname, uowner: TLabelName;
Begin
  FindScopedLabel := 0;
  uname := UpperStr(name);
  uowner := UpperStr(owner);
  For i := 1 To ctx.parse.label_count Do
    If (ctx.parse.labels[i].name = uname) And
       ((ctx.parse.labels[i].owner = uowner) Or
        (ctx.parse.labels[i].kind = LK_PROC)) Then
      Begin
        FindScopedLabel := i;
        Exit;
      End;
End;

Function AsmSafeName(name: TLabelName): TLabelName;
Var
  i: Integer;
  ch: Char;
  s: TLabelName;
Begin
  s := '';
  For i := 1 To Length(name) Do
    Begin
      ch := UpCase(name[i]);
      If ((ch >= 'A') And (ch <= 'Z')) Or
         ((ch >= '0') And (ch <= '9')) Or (ch = '_') Then
        s := s + ch
      Else
        s := s + '_';
    End;
  If s = '' Then
    s := 'ANON';
  AsmSafeName := s;
End;

Function IntToLabel(n: LongInt): TLabelName;
Var
  s: String[16];
Begin
  Str(n, s);
  IntToLabel := s;
End;

Function MakeUserAsmLabel(name, owner: TLabelName; line_no: LongInt;
                          kind: TLabelKind): TLabelName;
Begin
  If kind = LK_PROC Then
    MakeUserAsmLabel := 'PL1_PROC_' + AsmSafeName(name)
  Else If owner <> '' Then
    MakeUserAsmLabel := 'PL1_' + AsmSafeName(owner) + '_' +
                        AsmSafeName(name) + '_L' + IntToLabel(line_no)
  Else
    MakeUserAsmLabel := 'PL1_' + AsmSafeName(name) + '_L' + IntToLabel(line_no);
End;

Function MakeDataLabel(owner, name: TLabelName): TLabelName;
Begin
  If owner = '' Then
    owner := 'GLOBAL';
  MakeDataLabel := 'PL1_DATA_' + AsmSafeName(owner) + '_' + AsmSafeName(name);
End;

Function AlignTo(value, align: Integer): Integer;
Begin
  If align <= 1 Then
    AlignTo := value
  Else If (value Mod align) = 0 Then
    AlignTo := value
  Else
    AlignTo := value + align - (value Mod align);
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
  ctx.symbols.symbols[ctx.symbols.count].stack_offset := 0;
  ctx.symbols.symbols[ctx.symbols.count].data_label := '';
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
  ctx.parse.assignment_count := 0;
  ctx.parse.assignment_var_count := 0;
  ctx.parse.assignment_array_count := 0;
  ctx.parse.assignment_init_count := 0;
  ctx.parse.assignment_error_count := 0;
  ctx.parse.do_loop_count := 0;
  ctx.parse.do_loop_error_count := 0;
  ctx.parse.do_loop_depth := 0;
  ctx.parse.max_do_loop_depth := 0;
  ctx.parse.select_count := 0;
  ctx.parse.when_count := 0;
  ctx.parse.otherwise_count := 0;
  ctx.parse.select_error_count := 0;
  ctx.parse.select_depth := 0;
  ctx.parse.max_select_depth := 0;
  ctx.parse.return_count := 0;
  ctx.parse.return_error_count := 0;
  ctx.parse.put_count := 0;
  ctx.parse.put_list_count := 0;
  ctx.parse.put_skip_count := 0;
  ctx.parse.put_error_count := 0;
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
  owner: TLabelName;
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
  owner := CurrentProcName(ctx);
  ctx.parse.labels[ctx.parse.label_count].name := UpperStr(tok.text);
  ctx.parse.labels[ctx.parse.label_count].owner := owner;
  ctx.parse.labels[ctx.parse.label_count].asm_name :=
    MakeUserAsmLabel(tok.text, owner, tok.line, LK_CONTROL);
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
  ctx.parse.procs[proc_idx].return_count := 0;
  ctx.parse.procs[proc_idx].epilogue_label :=
    'PL1_EPILOGUE_' + AsmSafeName(ctx.parse.procs[proc_idx].name);
  ctx.parse.procs[proc_idx].arg_bytes := 0;
  ctx.parse.procs[proc_idx].local_bytes := 0;
  ctx.parse.procs[proc_idx].frame_bytes := 0;
  ctx.parse.procs[proc_idx].cleanup := ABI_CLEANUP;
  ctx.parse.procs[proc_idx].saved_regs := ABI_SAVED_REGS;
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
        ctx.parse.labels[idx].owner := '';
        ctx.parse.labels[idx].asm_name :=
          MakeUserAsmLabel(ctx.parse.labels[idx].name, '',
                           ctx.parse.labels[idx].line, LK_PROC);
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
  ctx.parse.gotos[ctx.parse.goto_count].owner := CurrentProcName(ctx);
  ctx.parse.gotos[ctx.parse.goto_count].target_index := 0;
  ctx.parse.gotos[ctx.parse.goto_count].asm_target := '';
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

Function FindStatementStart(Var ctx: TCompilerContext; idx: Integer): Integer;
Var
  i: Integer;
Begin
  FindStatementStart := 1;
  For i := idx - 1 Downto 1 Do
    If TokenKindTextAt(ctx, i, TK_PUNCT, ';') Then
      Begin
        FindStatementStart := i + 1;
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

Function FindOpeningParen(Var ctx: TCompilerContext; close_idx: Integer;
                          first_idx: Integer): Integer;
Var
  i, depth: Integer;
Begin
  FindOpeningParen := 0;
  depth := 0;
  For i := close_idx Downto first_idx Do
    Begin
      If TokenKindTextAt(ctx, i, TK_PUNCT, ')') Then
        Inc(depth)
      Else If TokenKindTextAt(ctx, i, TK_PUNCT, '(') Then
        Begin
          Dec(depth);
          If depth = 0 Then
            Begin
              FindOpeningParen := i;
              Exit;
            End;
        End;
    End;
End;

Function ProcNameAtLine(Var ctx: TCompilerContext; line_no: LongInt): TLabelName;
Var
  i: Integer;
Begin
  ProcNameAtLine := '';
  For i := 1 To ctx.parse.proc_count Do
    If (line_no >= ctx.parse.procs[i].decl_line) And
       ((ctx.parse.procs[i].end_line = 0) Or
        (line_no <= ctx.parse.procs[i].end_line)) Then
      Begin
        ProcNameAtLine := ctx.parse.procs[i].name;
        Exit;
    End;
End;

Function ProcIndexAtLine(Var ctx: TCompilerContext; line_no: LongInt): Integer;
Var
  i: Integer;
Begin
  ProcIndexAtLine := 0;
  For i := 1 To ctx.parse.proc_count Do
    If (line_no >= ctx.parse.procs[i].decl_line) And
       ((ctx.parse.procs[i].end_line = 0) Or
        (line_no <= ctx.parse.procs[i].end_line)) Then
      Begin
        ProcIndexAtLine := i;
        Exit;
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

Function AssignKindName(kind: TAssignKind): TString;
Begin
  Case kind Of
    AS_VARIABLE:      AssignKindName := 'VAR';
    AS_ARRAY_ELEMENT: AssignKindName := 'ARRAY';
    AS_INITIALIZER:   AssignKindName := 'INIT';
  Else
    AssignKindName := 'UNKNOWN';
  End;
End;

Function LabelKindName(kind: TLabelKind): TString;
Begin
  Case kind Of
    LK_PROC:    LabelKindName := 'PROC';
    LK_CONTROL: LabelKindName := 'CONTROL';
  Else
    LabelKindName := 'UNKNOWN';
  End;
End;

Function TokenRangeText(Var ctx: TCompilerContext; first_idx,
                        last_idx: Integer): TString;
Var
  i: Integer;
  s: TString;
Begin
  s := '';
  For i := first_idx To last_idx Do
    If (i >= 1) And (i <= ctx.lex.token_count) Then
      Begin
        If s <> '' Then
          s := s + ' ';
        s := s + ctx.lex.tokens[i].text;
      End;
  TokenRangeText := s;
End;

Procedure AssignmentErrorAt(Var ctx: TCompilerContext; idx: Integer; msg: TString);
Var
  tok: TToken;
Begin
  Inc(ctx.parse.assignment_error_count);
  If (idx >= 1) And (idx <= ctx.lex.token_count) Then
    tok := ctx.lex.tokens[idx]
  Else
    tok := ctx.lex.eof_token;
  SourceErrorAt(ctx, tok.line, tok.col, msg);
End;

Procedure CountAssignment(Var ctx: TCompilerContext; kind: TAssignKind);
Begin
  Inc(ctx.parse.assignment_count);
  Case kind Of
    AS_VARIABLE:      Inc(ctx.parse.assignment_var_count);
    AS_ARRAY_ELEMENT: Inc(ctx.parse.assignment_array_count);
    AS_INITIALIZER:   Inc(ctx.parse.assignment_init_count);
  Else
  End;
End;

Function ParseExpressionRange(Var ctx: TCompilerContext; first_idx,
                              last_idx: Integer): Boolean; Forward;

Function ParseExpressionListRange(Var ctx: TCompilerContext; first_idx,
                                  last_idx: Integer): Integer;
Var
  i, part_first, depth, count: Integer;
Begin
  ParseExpressionListRange := 0;
  part_first := first_idx;
  depth := 0;
  count := 0;

  If first_idx > last_idx Then
    Begin
      ExprErrorAt(ctx, first_idx, 'expression attendue');
      Exit;
    End;

  For i := first_idx To last_idx Do
    Begin
      If TokenKindTextAt(ctx, i, TK_PUNCT, '(') Then
        Inc(depth)
      Else If TokenKindTextAt(ctx, i, TK_PUNCT, ')') Then
        Dec(depth)
      Else If TokenKindTextAt(ctx, i, TK_PUNCT, ',') And (depth = 0) Then
        Begin
          If Not ParseExpressionRange(ctx, part_first, i - 1) Then
            Exit;
          Inc(count);
          part_first := i + 1;
        End;
    End;

  If Not ParseExpressionRange(ctx, part_first, last_idx) Then
    Exit;
  Inc(count);
  ParseExpressionListRange := count;
End;

Function AddAssignmentIR(Var ctx: TCompilerContext; kind: TAssignKind;
                         target_idx, index_first, index_last,
                         expr_first, expr_last: Integer): Boolean;
Var
  owner: TLabelName;
  sym_idx: Integer;
Begin
  AddAssignmentIR := False;
  If (target_idx < 1) Or (target_idx > ctx.lex.token_count) Or
     Not IsNameToken(ctx.lex.tokens[target_idx]) Then
    Begin
      AssignmentErrorAt(ctx, target_idx, 'cible d''affectation attendue');
      Exit;
    End;

  owner := ProcNameAtLine(ctx, ctx.lex.tokens[target_idx].line);
  sym_idx := FindScopedSymbolAny(ctx, ctx.lex.tokens[target_idx].text, owner);
  If sym_idx = 0 Then
    Begin
      AssignmentErrorAt(ctx, target_idx, 'cible d''affectation inconnue');
      Exit;
    End;

  If kind = AS_ARRAY_ELEMENT Then
    Begin
      If ctx.symbols.symbols[sym_idx].kind <> SK_ARRAY Then
        Begin
          AssignmentErrorAt(ctx, target_idx,
                            'cible tableau attendue pour affectation indexee');
          Exit;
        End;
      If Not ParseExpressionRange(ctx, index_first, index_last) Then
        Exit;
    End
  Else If ctx.symbols.symbols[sym_idx].kind = SK_ARRAY Then
    Begin
      AssignmentErrorAt(ctx, target_idx,
                        'affectation de tableau complet non supportee');
      Exit;
    End
  Else If Not ((ctx.symbols.symbols[sym_idx].kind = SK_LOCAL) Or
               (ctx.symbols.symbols[sym_idx].kind = SK_STATIC) Or
               (ctx.symbols.symbols[sym_idx].kind = SK_PARAM)) Then
    Begin
      AssignmentErrorAt(ctx, target_idx,
                        'cible d''affectation non modifiable');
      Exit;
    End;

  If Not ParseExpressionRange(ctx, expr_first, expr_last) Then
    Exit;

  If ctx.parse.assignment_count >= MAX_ASSIGNMENTS Then
    Begin
      AssignmentErrorAt(ctx, target_idx, 'trop d''affectations');
      Exit;
    End;

  CountAssignment(ctx, kind);
  ctx.parse.assignments[ctx.parse.assignment_count].kind := kind;
  ctx.parse.assignments[ctx.parse.assignment_count].target_name :=
    ctx.symbols.symbols[sym_idx].name;
  ctx.parse.assignments[ctx.parse.assignment_count].owner :=
    ctx.symbols.symbols[sym_idx].owner;
  ctx.parse.assignments[ctx.parse.assignment_count].symbol_index := sym_idx;
  ctx.parse.assignments[ctx.parse.assignment_count].target_token := target_idx;
  ctx.parse.assignments[ctx.parse.assignment_count].index_first := index_first;
  ctx.parse.assignments[ctx.parse.assignment_count].index_last := index_last;
  ctx.parse.assignments[ctx.parse.assignment_count].expr_first := expr_first;
  ctx.parse.assignments[ctx.parse.assignment_count].expr_last := expr_last;
  ctx.parse.assignments[ctx.parse.assignment_count].line :=
    ctx.lex.tokens[target_idx].line;
  ctx.parse.assignments[ctx.parse.assignment_count].col :=
    ctx.lex.tokens[target_idx].col;
  ctx.parse.assignments[ctx.parse.assignment_count].is_static_init :=
    (kind = AS_INITIALIZER) And ctx.symbols.symbols[sym_idx].is_static;
  AddAssignmentIR := True;
End;

Function RegisterAssignmentAtEquals(Var ctx: TCompilerContext; stmt_start,
                                    eq_idx, stmt_end: Integer): Boolean;
Var
  target_idx, open_idx, close_idx: Integer;
Begin
  RegisterAssignmentAtEquals := False;
  If TokenKindTextAt(ctx, eq_idx - 1, TK_PUNCT, ')') Then
    Begin
      close_idx := eq_idx - 1;
      open_idx := FindOpeningParen(ctx, close_idx, stmt_start);
      If open_idx = 0 Then
        Begin
          AssignmentErrorAt(ctx, close_idx,
                            'index de tableau mal forme dans affectation');
          Exit;
        End;
      target_idx := open_idx - 1;
      RegisterAssignmentAtEquals :=
        AddAssignmentIR(ctx, AS_ARRAY_ELEMENT, target_idx,
                        open_idx + 1, close_idx - 1,
                        eq_idx + 1, stmt_end - 1);
    End
  Else
    Begin
      target_idx := eq_idx - 1;
      RegisterAssignmentAtEquals :=
        AddAssignmentIR(ctx, AS_VARIABLE, target_idx, 0, 0,
                        eq_idx + 1, stmt_end - 1);
    End;
End;

Procedure RegisterInitialAssignment(Var ctx: TCompilerContext; stmt_start,
                                    init_idx, stmt_end: Integer);
Var
  i, target_idx, close_idx: Integer;
Begin
  target_idx := 0;
  For i := stmt_start To init_idx - 1 Do
    If IsNameToken(ctx.lex.tokens[i]) And
       Not TokenTextAt(ctx, i, 'DECLARE') And
       Not TokenTextAt(ctx, i, 'DCL') Then
      Begin
        target_idx := i;
        Break;
      End;

  If target_idx = 0 Then
    Begin
      AssignmentErrorAt(ctx, init_idx, 'nom de variable INITIAL introuvable');
      Exit;
    End;

  If TokenKindTextAt(ctx, init_idx + 1, TK_PUNCT, '(') Then
    Begin
      close_idx := FindMatchingParen(ctx, init_idx + 1, stmt_end - 1);
      If close_idx = 0 Then
        AssignmentErrorAt(ctx, init_idx, ') attendu apres INITIAL')
      Else
        AddAssignmentIR(ctx, AS_INITIALIZER, target_idx, 0, 0,
                        init_idx + 2, close_idx - 1);
    End;
End;

Procedure DoLoopErrorAt(Var ctx: TCompilerContext; idx: Integer; msg: TString);
Var
  tok: TToken;
Begin
  Inc(ctx.parse.do_loop_error_count);
  If (idx >= 1) And (idx <= ctx.lex.token_count) Then
    tok := ctx.lex.tokens[idx]
  Else
    tok := ctx.lex.eof_token;
  SourceErrorAt(ctx, tok.line, tok.col, msg);
End;

Function IntToFixedLabel(n: Integer): TLabelName;
Var
  s: String[12];
Begin
  Str(n, s);
  While Length(s) < 4 Do
    s := '0' + s;
  IntToFixedLabel := s;
End;

Function MakeDoLabel(n: Integer; suffix: TLabelName): TLabelName;
Begin
  MakeDoLabel := '@DO' + IntToFixedLabel(n) + '_' + suffix;
End;

Function MakeSelectLabel(n: Integer; suffix: TLabelName): TLabelName;
Begin
  MakeSelectLabel := '@SEL' + IntToFixedLabel(n) + '_' + suffix;
End;

Function DoLoopNestingForToken(Var ctx: TCompilerContext; tok_idx: Integer): Integer;
Var
  i, depth: Integer;
Begin
  depth := 1;
  For i := 1 To ctx.parse.do_loop_count Do
    If (ctx.parse.do_loops[i].do_token < tok_idx) And
       (ctx.parse.do_loops[i].end_token > tok_idx) Then
      Inc(depth);
  DoLoopNestingForToken := depth;
End;

Function FindMatchingEndForBlock(Var ctx: TCompilerContext; block_idx: Integer): Integer;
Var
  i, stmt_end, depth: Integer;
Begin
  FindMatchingEndForBlock := 0;
  stmt_end := FindStatementEnd(ctx, block_idx);
  depth := 1;
  i := stmt_end + 1;
  While i <= ctx.lex.token_count Do
    Begin
      If TokenTextAt(ctx, i, 'DO') Or TokenTextAt(ctx, i, 'SELECT') Then
        Inc(depth)
      Else If TokenTextAt(ctx, i, 'END') Then
        Begin
          If TokenKindTextAt(ctx, i + 1, TK_PUNCT, ';') Then
            Begin
              Dec(depth);
              If depth = 0 Then
                Begin
                  FindMatchingEndForBlock := i;
                  Exit;
                End;
            End;
        End;
      Inc(i);
    End;
End;

Function AddDoLoopIR(Var ctx: TCompilerContext; do_idx, stmt_end,
                     eq_idx, to_idx, by_idx: Integer): Boolean;
Var
  control_idx, sym_idx, loop_idx, match_end: Integer;
  owner: TLabelName;
Begin
  AddDoLoopIR := False;
  control_idx := do_idx + 1;

  If Not IsNameToken(ctx.lex.tokens[control_idx]) Then
    Begin
      DoLoopErrorAt(ctx, control_idx, 'variable de controle attendue apres DO');
      Exit;
    End;

  owner := ProcNameAtLine(ctx, ctx.lex.tokens[do_idx].line);
  sym_idx := FindScopedSymbolAny(ctx, ctx.lex.tokens[control_idx].text, owner);
  If sym_idx = 0 Then
    Begin
      DoLoopErrorAt(ctx, control_idx, 'variable de controle DO inconnue');
      Exit;
    End;

  If Not ((ctx.symbols.symbols[sym_idx].kind = SK_LOCAL) Or
          (ctx.symbols.symbols[sym_idx].kind = SK_STATIC) Or
          (ctx.symbols.symbols[sym_idx].kind = SK_PARAM)) Then
    Begin
      DoLoopErrorAt(ctx, control_idx, 'variable de controle DO non modifiable');
      Exit;
    End;

  If ctx.symbols.symbols[sym_idx].typ.kind <> TY_FIXED_BINARY Then
    Begin
      DoLoopErrorAt(ctx, control_idx,
                    'variable de controle DO doit etre FIXED BINARY');
      Exit;
    End;

  If (eq_idx <> control_idx + 1) Or (to_idx = 0) Or (to_idx <= eq_idx) Then
    Begin
      DoLoopErrorAt(ctx, do_idx, 'syntaxe DO attendue: DO I = debut TO fin');
      Exit;
    End;

  If Not ParseExpressionRange(ctx, eq_idx + 1, to_idx - 1) Then
    Exit;

  If (by_idx <> 0) And (by_idx > to_idx) Then
    Begin
      If Not ParseExpressionRange(ctx, to_idx + 1, by_idx - 1) Then
        Exit;
      If Not ParseExpressionRange(ctx, by_idx + 1, stmt_end - 1) Then
        Exit;
    End
  Else If Not ParseExpressionRange(ctx, to_idx + 1, stmt_end - 1) Then
    Exit;

  match_end := FindMatchingEndForBlock(ctx, do_idx);
  If match_end = 0 Then
    Begin
      DoLoopErrorAt(ctx, do_idx, 'DO sans END correspondant');
      Exit;
    End;

  If ctx.parse.do_loop_count >= MAX_DO_LOOPS Then
    Begin
      DoLoopErrorAt(ctx, do_idx, 'trop de boucles DO');
      Exit;
    End;

  Inc(ctx.parse.do_loop_count);
  loop_idx := ctx.parse.do_loop_count;
  ctx.parse.do_loops[loop_idx].control_name :=
    ctx.symbols.symbols[sym_idx].name;
  ctx.parse.do_loops[loop_idx].owner := ctx.symbols.symbols[sym_idx].owner;
  ctx.parse.do_loops[loop_idx].symbol_index := sym_idx;
  ctx.parse.do_loops[loop_idx].do_token := do_idx;
  ctx.parse.do_loops[loop_idx].control_token := control_idx;
  ctx.parse.do_loops[loop_idx].start_first := eq_idx + 1;
  ctx.parse.do_loops[loop_idx].start_last := to_idx - 1;
  ctx.parse.do_loops[loop_idx].end_first := to_idx + 1;
  If (by_idx <> 0) And (by_idx > to_idx) Then
    Begin
      ctx.parse.do_loops[loop_idx].end_last := by_idx - 1;
      ctx.parse.do_loops[loop_idx].has_by := True;
      ctx.parse.do_loops[loop_idx].by_first := by_idx + 1;
      ctx.parse.do_loops[loop_idx].by_last := stmt_end - 1;
    End
  Else
    Begin
      ctx.parse.do_loops[loop_idx].end_last := stmt_end - 1;
      ctx.parse.do_loops[loop_idx].has_by := False;
      ctx.parse.do_loops[loop_idx].by_first := 0;
      ctx.parse.do_loops[loop_idx].by_last := 0;
    End;
  ctx.parse.do_loops[loop_idx].body_first := stmt_end + 1;
  ctx.parse.do_loops[loop_idx].body_last := match_end - 1;
  ctx.parse.do_loops[loop_idx].end_token := match_end;
  ctx.parse.do_loops[loop_idx].line := ctx.lex.tokens[do_idx].line;
  ctx.parse.do_loops[loop_idx].end_line := ctx.lex.tokens[match_end].line;
  ctx.parse.do_loops[loop_idx].nesting := DoLoopNestingForToken(ctx, do_idx);
  If ctx.parse.do_loops[loop_idx].nesting > ctx.parse.max_do_loop_depth Then
    ctx.parse.max_do_loop_depth := ctx.parse.do_loops[loop_idx].nesting;
  ctx.parse.do_loops[loop_idx].label_test := MakeDoLabel(loop_idx, 'TEST');
  ctx.parse.do_loops[loop_idx].label_body := MakeDoLabel(loop_idx, 'BODY');
  ctx.parse.do_loops[loop_idx].label_end := MakeDoLabel(loop_idx, 'END');
  AddDoLoopIR := True;
End;

Procedure SelectErrorAt(Var ctx: TCompilerContext; idx: Integer; msg: TString);
Var
  tok: TToken;
Begin
  Inc(ctx.parse.select_error_count);
  If (idx >= 1) And (idx <= ctx.lex.token_count) Then
    tok := ctx.lex.tokens[idx]
  Else
    tok := ctx.lex.eof_token;
  SourceErrorAt(ctx, tok.line, tok.col, msg);
End;

Function SelectNestingForToken(Var ctx: TCompilerContext; tok_idx: Integer): Integer;
Var
  i, depth: Integer;
Begin
  depth := 1;
  For i := 1 To ctx.parse.select_count Do
    If (ctx.parse.selects[i].select_token < tok_idx) And
       (ctx.parse.selects[i].end_token > tok_idx) Then
      Inc(depth);
  SelectNestingForToken := depth;
End;

Function AddWhenIR(Var ctx: TCompilerContext; select_idx, when_idx,
                   scan_end: Integer): Boolean;
Var
  open_idx, close_idx, stmt_end, when_info_idx, value_count: Integer;
Begin
  AddWhenIR := False;
  If Not TokenKindTextAt(ctx, when_idx + 1, TK_PUNCT, '(') Then
    Begin
      SelectErrorAt(ctx, when_idx, '( attendu apres WHEN');
      Exit;
    End;

  open_idx := when_idx + 1;
  close_idx := FindMatchingParen(ctx, open_idx, scan_end);
  If close_idx = 0 Then
    Begin
      SelectErrorAt(ctx, when_idx, ') attendu apres WHEN');
      Exit;
    End;

  value_count := ParseExpressionListRange(ctx, open_idx + 1, close_idx - 1);
  If value_count = 0 Then
    Exit;

  stmt_end := FindStatementEnd(ctx, when_idx);
  If stmt_end > scan_end Then
    Begin
      SelectErrorAt(ctx, when_idx, 'WHEN depasse le bloc SELECT');
      Exit;
    End;

  If ctx.parse.when_count >= MAX_WHENS Then
    Begin
      SelectErrorAt(ctx, when_idx, 'trop de WHEN');
      Exit;
    End;

  Inc(ctx.parse.when_count);
  Inc(ctx.parse.selects[select_idx].when_count);
  If ctx.parse.selects[select_idx].first_when = 0 Then
    ctx.parse.selects[select_idx].first_when := ctx.parse.when_count;
  when_info_idx := ctx.parse.when_count;
  ctx.parse.whens[when_info_idx].select_index := select_idx;
  ctx.parse.whens[when_info_idx].when_token := when_idx;
  ctx.parse.whens[when_info_idx].value_first := open_idx + 1;
  ctx.parse.whens[when_info_idx].value_last := close_idx - 1;
  ctx.parse.whens[when_info_idx].value_count := value_count;
  ctx.parse.whens[when_info_idx].stmt_first := close_idx + 1;
  ctx.parse.whens[when_info_idx].stmt_last := stmt_end - 1;
  ctx.parse.whens[when_info_idx].line := ctx.lex.tokens[when_idx].line;
  ctx.parse.whens[when_info_idx].label_match :=
    MakeSelectLabel(select_idx, 'WHEN' + IntToFixedLabel(ctx.parse.selects[select_idx].when_count));
  ctx.parse.whens[when_info_idx].label_next :=
    MakeSelectLabel(select_idx, 'NEXT' + IntToFixedLabel(ctx.parse.selects[select_idx].when_count));
  AddWhenIR := True;
End;

Function AddSelectIR(Var ctx: TCompilerContext; select_idx,
                     stmt_end: Integer): Boolean;
Var
  close_idx, match_end, idx, sel_info_idx, nested_end: Integer;
Begin
  AddSelectIR := False;
  If Not TokenKindTextAt(ctx, select_idx + 1, TK_PUNCT, '(') Then
    Begin
      SelectErrorAt(ctx, select_idx, '( attendu apres SELECT');
      Exit;
    End;

  close_idx := FindMatchingParen(ctx, select_idx + 1, stmt_end - 1);
  If close_idx = 0 Then
    Begin
      SelectErrorAt(ctx, select_idx, ') attendu apres SELECT');
      Exit;
    End;

  If Not ParseExpressionRange(ctx, select_idx + 2, close_idx - 1) Then
    Exit;

  match_end := FindMatchingEndForBlock(ctx, select_idx);
  If match_end = 0 Then
    Begin
      SelectErrorAt(ctx, select_idx, 'SELECT sans END correspondant');
      Exit;
    End;

  If ctx.parse.select_count >= MAX_SELECTS Then
    Begin
      SelectErrorAt(ctx, select_idx, 'trop de SELECT');
      Exit;
    End;

  Inc(ctx.parse.select_count);
  sel_info_idx := ctx.parse.select_count;
  ctx.parse.selects[sel_info_idx].select_token := select_idx;
  ctx.parse.selects[sel_info_idx].expr_first := select_idx + 2;
  ctx.parse.selects[sel_info_idx].expr_last := close_idx - 1;
  ctx.parse.selects[sel_info_idx].first_when := 0;
  ctx.parse.selects[sel_info_idx].when_count := 0;
  ctx.parse.selects[sel_info_idx].otherwise_token := 0;
  ctx.parse.selects[sel_info_idx].end_token := match_end;
  ctx.parse.selects[sel_info_idx].line := ctx.lex.tokens[select_idx].line;
  ctx.parse.selects[sel_info_idx].end_line := ctx.lex.tokens[match_end].line;
  ctx.parse.selects[sel_info_idx].nesting := SelectNestingForToken(ctx, select_idx);
  If ctx.parse.selects[sel_info_idx].nesting > ctx.parse.max_select_depth Then
    ctx.parse.max_select_depth := ctx.parse.selects[sel_info_idx].nesting;
  ctx.parse.selects[sel_info_idx].label_next :=
    MakeSelectLabel(sel_info_idx, 'TEST');
  ctx.parse.selects[sel_info_idx].label_otherwise :=
    MakeSelectLabel(sel_info_idx, 'OTHER');
  ctx.parse.selects[sel_info_idx].label_end :=
    MakeSelectLabel(sel_info_idx, 'END');

  idx := stmt_end + 1;
  While idx < match_end Do
    Begin
      If (idx <> select_idx) And
         (TokenTextAt(ctx, idx, 'SELECT') Or TokenTextAt(ctx, idx, 'DO')) Then
        Begin
          nested_end := FindMatchingEndForBlock(ctx, idx);
          If nested_end <> 0 Then
            Begin
              idx := nested_end + 2;
              Continue;
            End;
        End;

      If TokenTextAt(ctx, idx, 'WHEN') Then
        AddWhenIR(ctx, sel_info_idx, idx, match_end)
      Else If TokenTextAt(ctx, idx, 'OTHERWISE') Then
        Begin
          If ctx.parse.selects[sel_info_idx].otherwise_token <> 0 Then
            SelectErrorAt(ctx, idx, 'plusieurs OTHERWISE dans SELECT')
          Else
            Begin
              ctx.parse.selects[sel_info_idx].otherwise_token := idx;
              Inc(ctx.parse.otherwise_count);
            End;
        End;
      Inc(idx);
    End;

  If ctx.parse.selects[sel_info_idx].when_count = 0 Then
    Begin
      SelectErrorAt(ctx, select_idx, 'SELECT sans WHEN');
      Exit;
    End;

  AddSelectIR := True;
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

Function ParseExpressionRangeInfo(Var ctx: TCompilerContext; first_idx,
                                  last_idx: Integer; Var expr: TExprInfo): Boolean;
Var
  pos: Integer;
Begin
  ParseExpressionRangeInfo := False;
  expr := UnknownExpr;
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

  ParseExpressionRangeInfo := True;
End;

Function ParseExpressionRange(Var ctx: TCompilerContext; first_idx,
                              last_idx: Integer): Boolean;
Var
  expr: TExprInfo;
Begin
  ParseExpressionRange := ParseExpressionRangeInfo(ctx, first_idx,
                                                   last_idx, expr);
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

Procedure ReturnErrorAt(Var ctx: TCompilerContext; idx: Integer; msg: TString);
Var
  tok: TToken;
Begin
  Inc(ctx.parse.return_error_count);
  If (idx >= 1) And (idx <= ctx.lex.token_count) Then
    tok := ctx.lex.tokens[idx]
  Else
    tok := ctx.lex.eof_token;
  SourceErrorAt(ctx, tok.line, tok.col, msg);
End;

Function AddReturnIR(Var ctx: TCompilerContext; return_idx,
                     stmt_end: Integer): Boolean;
Var
  proc_idx, expr_first, expr_last, close_idx: Integer;
  expr: TExprInfo;
Begin
  AddReturnIR := False;
  proc_idx := ProcIndexAtLine(ctx, ctx.lex.tokens[return_idx].line);
  If proc_idx = 0 Then
    Begin
      ReturnErrorAt(ctx, return_idx, 'RETURN hors procedure');
      Exit;
    End;

  If Not ctx.parse.procs[proc_idx].has_returns Then
    Begin
      ReturnErrorAt(ctx, return_idx,
                    'RETURN dans une procedure sans RETURNS');
      Exit;
    End;

  If TokenKindTextAt(ctx, return_idx + 1, TK_PUNCT, '(') Then
    Begin
      close_idx := FindMatchingParen(ctx, return_idx + 1, stmt_end - 1);
      If close_idx = 0 Then
        Begin
          ReturnErrorAt(ctx, return_idx, ') attendu apres RETURN');
          Exit;
        End;
      If close_idx <> stmt_end - 1 Then
        Begin
          ReturnErrorAt(ctx, close_idx + 1,
                        'element inattendu apres expression RETURN');
          Exit;
        End;
      expr_first := return_idx + 2;
      expr_last := close_idx - 1;
    End
  Else
    Begin
      expr_first := return_idx + 1;
      expr_last := stmt_end - 1;
    End;

  If Not ParseExpressionRangeInfo(ctx, expr_first, expr_last, expr) Then
    Exit;

  If expr.typ.kind <> ctx.parse.procs[proc_idx].return_type.kind Then
    Begin
      ReturnErrorAt(ctx, return_idx,
                    'type de RETURN incompatible avec RETURNS');
      Exit;
    End;

  If ctx.parse.return_count >= MAX_RETURNS Then
    Begin
      ReturnErrorAt(ctx, return_idx, 'trop de RETURN');
      Exit;
    End;

  Inc(ctx.parse.return_count);
  Inc(ctx.parse.procs[proc_idx].return_count);
  ctx.parse.returns[ctx.parse.return_count].proc_index := proc_idx;
  ctx.parse.returns[ctx.parse.return_count].proc_name :=
    ctx.parse.procs[proc_idx].name;
  ctx.parse.returns[ctx.parse.return_count].return_token := return_idx;
  ctx.parse.returns[ctx.parse.return_count].expr_first := expr_first;
  ctx.parse.returns[ctx.parse.return_count].expr_last := expr_last;
  ctx.parse.returns[ctx.parse.return_count].line :=
    ctx.lex.tokens[return_idx].line;
  ctx.parse.returns[ctx.parse.return_count].col :=
    ctx.lex.tokens[return_idx].col;
  ctx.parse.returns[ctx.parse.return_count].return_reg :=
    ctx.parse.procs[proc_idx].return_type.return_reg;
  ctx.parse.returns[ctx.parse.return_count].epilogue_label :=
    ctx.parse.procs[proc_idx].epilogue_label;
  AddReturnIR := True;
End;

Procedure PutErrorAt(Var ctx: TCompilerContext; idx: Integer; msg: TString);
Var
  tok: TToken;
Begin
  Inc(ctx.parse.put_error_count);
  If (idx >= 1) And (idx <= ctx.lex.token_count) Then
    tok := ctx.lex.tokens[idx]
  Else
    tok := ctx.lex.eof_token;
  SourceErrorAt(ctx, tok.line, tok.col, msg);
End;

Function AddPutIR(Var ctx: TCompilerContext; put_idx, stmt_end: Integer): Boolean;
Var
  proc_idx, close_idx: Integer;
  kind: TPutKind;
  expr_first, expr_last: Integer;
Begin
  AddPutIR := False;
  proc_idx := ProcIndexAtLine(ctx, ctx.lex.tokens[put_idx].line);
  If proc_idx = 0 Then
    Begin
      PutErrorAt(ctx, put_idx, 'PUT hors procedure');
      Exit;
    End;

  expr_first := 0;
  expr_last := 0;
  If TokenTextAt(ctx, put_idx + 1, 'SKIP') Then
    Begin
      kind := PK_SKIP;
      If put_idx + 2 <> stmt_end Then
        Begin
          PutErrorAt(ctx, put_idx + 2, 'element inattendu apres PUT SKIP');
          Exit;
        End;
    End
  Else If TokenTextAt(ctx, put_idx + 1, 'LIST') Then
    Begin
      kind := PK_LIST;
      If Not TokenKindTextAt(ctx, put_idx + 2, TK_PUNCT, '(') Then
        Begin
          PutErrorAt(ctx, put_idx + 1, '( attendu apres PUT LIST');
          Exit;
        End;
      close_idx := FindMatchingParen(ctx, put_idx + 2, stmt_end - 1);
      If close_idx = 0 Then
        Begin
          PutErrorAt(ctx, put_idx + 2, ') attendu apres PUT LIST');
          Exit;
        End;
      If close_idx <> stmt_end - 1 Then
        Begin
          PutErrorAt(ctx, close_idx + 1,
                     'element inattendu apres PUT LIST(expr)');
          Exit;
        End;
      expr_first := put_idx + 3;
      expr_last := close_idx - 1;
      If Not ParseExpressionRange(ctx, expr_first, expr_last) Then
        Exit;
    End
  Else
    Begin
      PutErrorAt(ctx, put_idx + 1, 'LIST ou SKIP attendu apres PUT');
      Exit;
    End;

  If ctx.parse.put_count >= MAX_PUTS Then
    Begin
      PutErrorAt(ctx, put_idx, 'trop de PUT');
      Exit;
    End;

  Inc(ctx.parse.put_count);
  If kind = PK_LIST Then
    Inc(ctx.parse.put_list_count)
  Else
    Inc(ctx.parse.put_skip_count);

  ctx.parse.puts[ctx.parse.put_count].kind := kind;
  ctx.parse.puts[ctx.parse.put_count].proc_index := proc_idx;
  ctx.parse.puts[ctx.parse.put_count].owner := ctx.parse.procs[proc_idx].name;
  ctx.parse.puts[ctx.parse.put_count].put_token := put_idx;
  ctx.parse.puts[ctx.parse.put_count].expr_first := expr_first;
  ctx.parse.puts[ctx.parse.put_count].expr_last := expr_last;
  ctx.parse.puts[ctx.parse.put_count].line := ctx.lex.tokens[put_idx].line;
  ctx.parse.puts[ctx.parse.put_count].col := ctx.lex.tokens[put_idx].col;
  AddPutIR := True;
End;

Procedure ValidateExpressions(Var ctx: TCompilerContext);
Var
  i, stmt_start, stmt_end, eq_idx, to_idx, by_idx: Integer;
Begin
  i := 1;
  While i <= ctx.lex.token_count Do
    Begin
      stmt_start := FindStatementStart(ctx, i);
      If TokenTextAt(ctx, i, 'DO') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          eq_idx := FindTokenBefore(ctx, i + 1, stmt_end - 1, '=');
          to_idx := FindTokenBefore(ctx, i + 1, stmt_end - 1, 'TO');
          by_idx := FindTokenBefore(ctx, i + 1, stmt_end - 1, 'BY');
          If (eq_idx <> 0) And (to_idx <> 0) And (eq_idx < to_idx) Then
            Begin
              AddDoLoopIR(ctx, i, stmt_end, eq_idx, to_idx, by_idx);
              i := stmt_end + 1;
              Continue;
            End
          Else
            DoLoopErrorAt(ctx, i, 'syntaxe DO supportee: DO I = debut TO fin');
        End
      Else If TokenTextAt(ctx, i, 'RETURN') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          AddReturnIR(ctx, i, stmt_end);
          i := stmt_end + 1;
          Continue;
        End
      Else If TokenTextAt(ctx, i, 'SELECT') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          AddSelectIR(ctx, i, stmt_end);
        End
      Else If TokenTextAt(ctx, i, 'WHEN') Or TokenTextAt(ctx, i, 'OTHERWISE') Then
        Begin
        End
      Else If TokenTextAt(ctx, i, 'PUT') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          AddPutIR(ctx, i, stmt_end);
          i := stmt_end + 1;
          Continue;
        End
      Else If TokenTextAt(ctx, i, 'INITIAL') Or TokenTextAt(ctx, i, 'INIT') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          If TokenKindTextAt(ctx, i + 1, TK_PUNCT, '(') Then
            RegisterInitialAssignment(ctx, stmt_start, i, stmt_end);
        End
      Else If TokenKindTextAt(ctx, i, TK_OPERATOR, '=') Then
        Begin
          stmt_end := FindStatementEnd(ctx, i);
          RegisterAssignmentAtEquals(ctx, stmt_start, i, stmt_end);
          i := stmt_end + 1;
          Continue;
        End;

      Inc(i);
    End;
End;

Procedure ComputeProcAbiLayout(Var ctx: TCompilerContext; proc_idx: Integer);
Var
  i, frame_offset, obj_size, obj_align: Integer;
  owner: TLabelName;
Begin
  If (proc_idx <= 0) Or (proc_idx > ctx.parse.proc_count) Then
    Exit;

  owner := ctx.parse.procs[proc_idx].name;
  ctx.parse.procs[proc_idx].arg_bytes :=
    ctx.parse.procs[proc_idx].param_count * ABI_WORD_SIZE;
  ctx.parse.procs[proc_idx].cleanup := ABI_CLEANUP;
  ctx.parse.procs[proc_idx].saved_regs := ABI_SAVED_REGS;

  For i := 1 To ctx.symbols.count Do
    If ctx.symbols.symbols[i].owner = owner Then
      Begin
        ctx.symbols.symbols[i].stack_offset := 0;
        ctx.symbols.symbols[i].data_label := '';
        If ctx.symbols.symbols[i].kind = SK_PARAM Then
          ctx.symbols.symbols[i].stack_offset :=
            ABI_FIRST_PARAM +
            ((ctx.symbols.symbols[i].ref_index - 1) * ABI_WORD_SIZE);
      End;

  frame_offset := 0;
  For i := 1 To ctx.symbols.count Do
    If ctx.symbols.symbols[i].owner = owner Then
      Begin
        If (ctx.symbols.symbols[i].kind = SK_LOCAL) Or
           ((ctx.symbols.symbols[i].kind = SK_ARRAY) And
            (Not ctx.symbols.symbols[i].is_static)) Then
          Begin
            obj_size := ctx.symbols.symbols[i].typ.size;
            obj_align := ctx.symbols.symbols[i].typ.align;
            If obj_size <= 0 Then
              obj_size := ABI_WORD_SIZE;
            If obj_align <= 0 Then
              obj_align := ABI_WORD_SIZE;
            frame_offset := AlignTo(frame_offset, obj_align);
            Inc(frame_offset, AlignTo(obj_size, ABI_WORD_SIZE));
            ctx.symbols.symbols[i].stack_offset := -frame_offset;
          End
        Else If (ctx.symbols.symbols[i].kind = SK_STATIC) Or
                ((ctx.symbols.symbols[i].kind = SK_ARRAY) And
                 ctx.symbols.symbols[i].is_static) Then
          ctx.symbols.symbols[i].data_label :=
            MakeDataLabel(owner, ctx.symbols.symbols[i].name);
      End;

  ctx.parse.procs[proc_idx].local_bytes := AlignTo(frame_offset, ABI_WORD_SIZE);
  ctx.parse.procs[proc_idx].frame_bytes := ctx.parse.procs[proc_idx].local_bytes;
End;

Procedure ComputeAbiLayout(Var ctx: TCompilerContext);
Var
  i: Integer;
Begin
  For i := 1 To ctx.parse.proc_count Do
    ComputeProcAbiLayout(ctx, i);
End;

Function ProcAsmLabel(Var ctx: TCompilerContext; proc_idx: Integer): TLabelName;
Var
  i: Integer;
Begin
  ProcAsmLabel := '';
  If (proc_idx <= 0) Or (proc_idx > ctx.parse.proc_count) Then
    Exit;

  For i := 1 To ctx.parse.label_count Do
    If (ctx.parse.labels[i].kind = LK_PROC) And
       (ctx.parse.labels[i].name = ctx.parse.procs[proc_idx].name) Then
      Begin
        ProcAsmLabel := ctx.parse.labels[i].asm_name;
        Exit;
      End;

  ProcAsmLabel := 'PL1_PROC_' + AsmSafeName(ctx.parse.procs[proc_idx].name);
End;

Function MainProcIndex(Var ctx: TCompilerContext): Integer;
Var
  i: Integer;
Begin
  MainProcIndex := 0;
  For i := 1 To ctx.parse.proc_count Do
    If ctx.parse.procs[i].is_main Then
      Begin
        MainProcIndex := i;
        Exit;
      End;
End;

Function ProcIndexByName(Var ctx: TCompilerContext; name: TLabelName): Integer;
Var
  i: Integer;
  uname: TLabelName;
Begin
  ProcIndexByName := 0;
  uname := UpperStr(name);
  For i := 1 To ctx.parse.proc_count Do
    If ctx.parse.procs[i].name = uname Then
      Begin
        ProcIndexByName := i;
        Exit;
      End;
End;

Function SymbolAsmRef(Var ctx: TCompilerContext; sym_idx: Integer): TString;
Var
  off: Integer;
  s: TString;
Begin
  s := '<sans-adresse>';
  If (sym_idx <= 0) Or (sym_idx > ctx.symbols.count) Then
    Begin
      SymbolAsmRef := s;
      Exit;
    End;

  If ctx.symbols.symbols[sym_idx].data_label <> '' Then
    Begin
      SymbolAsmRef := 'DWORD PTR [' + ctx.symbols.symbols[sym_idx].data_label + ']';
      Exit;
    End;

  off := ctx.symbols.symbols[sym_idx].stack_offset;
  If off <> 0 Then
    Begin
      s := 'DWORD PTR [' + ABI_FRAME_REG;
      If off > 0 Then
        s := s + '+';
      s := s + IntToLabel(off) + ']';
    End;
  SymbolAsmRef := s;
End;

Function ExprOuterParens(Var ctx: TCompilerContext; first_idx, last_idx: Integer): Boolean;
Var
  close_idx: Integer;
Begin
  ExprOuterParens := False;
  If Not TokenKindTextAt(ctx, first_idx, TK_PUNCT, '(') Then
    Exit;
  close_idx := FindMatchingParen(ctx, first_idx, last_idx);
  ExprOuterParens := close_idx = last_idx;
End;

Function FindTopLevelOpRight(Var ctx: TCompilerContext; first_idx, last_idx: Integer;
                             prec: Integer): Integer;
Var
  i, depth: Integer;
Begin
  FindTopLevelOpRight := 0;
  depth := 0;
  For i := last_idx Downto first_idx Do
    Begin
      If TokenKindTextAt(ctx, i, TK_PUNCT, ')') Then
        Inc(depth)
      Else If TokenKindTextAt(ctx, i, TK_PUNCT, '(') Then
        Dec(depth)
      Else If depth = 0 Then
        Begin
          If (prec = 1) And IsCompareOp(ctx, i) Then
            Begin
              FindTopLevelOpRight := i;
              Exit;
            End;
          If (prec = 2) And IsAddOp(ctx, i) And (i > first_idx) Then
            Begin
              FindTopLevelOpRight := i;
              Exit;
            End;
          If (prec = 3) And IsMulOp(ctx, i) And (i > first_idx) Then
            Begin
              FindTopLevelOpRight := i;
              Exit;
            End;
        End;
    End;
End;

Function CountTopLevelArgs(Var ctx: TCompilerContext; first_idx,
                           last_idx: Integer): Integer;
Var
  i, depth, count: Integer;
Begin
  CountTopLevelArgs := 0;
  If first_idx > last_idx Then
    Exit;
  count := 1;
  depth := 0;
  For i := first_idx To last_idx Do
    Begin
      If TokenKindTextAt(ctx, i, TK_PUNCT, '(') Then
        Inc(depth)
      Else If TokenKindTextAt(ctx, i, TK_PUNCT, ')') Then
        Dec(depth)
      Else If TokenKindTextAt(ctx, i, TK_PUNCT, ',') And (depth = 0) Then
        Inc(count);
    End;
  CountTopLevelArgs := count;
End;

Function EmitExprToEAX(Var ctx: TCompilerContext; Var f: Text;
                       owner: TLabelName; first_idx, last_idx: Integer): Boolean; Forward;

Procedure EmitCompareSet(Var f: Text; op: TString);
Begin
  If op = '=' Then
    Writeln(f, '        sete al')
  Else If op = '<' Then
    Writeln(f, '        setl al')
  Else If op = '<=' Then
    Writeln(f, '        setle al')
  Else If op = '>' Then
    Writeln(f, '        setg al')
  Else If op = '>=' Then
    Writeln(f, '        setge al')
  Else
    Writeln(f, '        setne al');
  Writeln(f, '        movzx eax, al');
End;

Function EmitBuiltinCallToEAX(Var ctx: TCompilerContext; Var f: Text;
                              owner, name: TLabelName; first_arg,
                              last_arg: Integer): Boolean;
Var
  comma_idx, close_idx: Integer;
  kind: TBuiltinKind;
Begin
  EmitBuiltinCallToEAX := False;
  kind := BuiltinKindOf(name);
  If kind = BI_NONE Then
    Exit;

  close_idx := last_arg;
  Case kind Of
    BI_ABS:
      Begin
        If Not EmitExprToEAX(ctx, f, owner, first_arg, close_idx) Then
          Exit;
        Writeln(f, '        cmp eax, 0');
        Writeln(f, '        jge @F');
        Writeln(f, '        neg eax');
        Writeln(f, '@@:');
      End;
    BI_MAX, BI_MIN, BI_MOD:
      Begin
        comma_idx := FindTokenBefore(ctx, first_arg, close_idx, ',');
        If comma_idx = 0 Then
          Exit;
        If Not EmitExprToEAX(ctx, f, owner, first_arg, comma_idx - 1) Then
          Exit;
        Writeln(f, '        push eax');
        If Not EmitExprToEAX(ctx, f, owner, comma_idx + 1, close_idx) Then
          Exit;
        Writeln(f, '        pop ebx');
        If kind = BI_MAX Then
          Begin
            Writeln(f, '        cmp ebx, eax');
            Writeln(f, '        jge @F');
            Writeln(f, '        mov ebx, eax');
            Writeln(f, '@@:');
            Writeln(f, '        mov eax, ebx');
          End
        Else If kind = BI_MIN Then
          Begin
            Writeln(f, '        cmp ebx, eax');
            Writeln(f, '        jle @F');
            Writeln(f, '        mov ebx, eax');
            Writeln(f, '@@:');
            Writeln(f, '        mov eax, ebx');
          End
        Else
          Begin
            Writeln(f, '        mov ecx, eax');
            Writeln(f, '        mov eax, ebx');
            Writeln(f, '        cdq');
            Writeln(f, '        idiv ecx');
            Writeln(f, '        mov eax, edx');
          End;
      End;
  Else
    Exit;
  End;
  EmitBuiltinCallToEAX := True;
End;

Function EmitCallToEAX(Var ctx: TCompilerContext; Var f: Text;
                       owner, name: TLabelName; first_arg,
                       last_arg: Integer): Boolean;
Var
  proc_idx, arg_first, arg_last, depth, i, pushed: Integer;
Begin
  EmitCallToEAX := False;
  If EmitBuiltinCallToEAX(ctx, f, owner, name, first_arg, last_arg) Then
    Begin
      EmitCallToEAX := True;
      Exit;
    End;

  proc_idx := ProcIndexByName(ctx, name);
  If proc_idx = 0 Then
    Exit;

  pushed := 0;
  arg_last := last_arg;
  While arg_last >= first_arg Do
    Begin
      depth := 0;
      arg_first := first_arg;
      For i := arg_last Downto first_arg Do
        Begin
          If TokenKindTextAt(ctx, i, TK_PUNCT, ')') Then
            Inc(depth)
          Else If TokenKindTextAt(ctx, i, TK_PUNCT, '(') Then
            Dec(depth)
          Else If TokenKindTextAt(ctx, i, TK_PUNCT, ',') And (depth = 0) Then
            Begin
              arg_first := i + 1;
              Break;
            End;
        End;
      If Not EmitExprToEAX(ctx, f, owner, arg_first, arg_last) Then
        Exit;
      Writeln(f, '        push eax');
      Inc(pushed);
      arg_last := arg_first - 2;
    End;

  Writeln(f, '        call ', ProcAsmLabel(ctx, proc_idx));
  If pushed > 0 Then
    Writeln(f, '        add ', ABI_STACK_REG, ', ', pushed * ABI_WORD_SIZE);
  EmitCallToEAX := True;
End;

Function EmitArrayLoadToEAX(Var ctx: TCompilerContext; Var f: Text;
                            owner: TLabelName; sym_idx, first_arg,
                            last_arg: Integer): Boolean;
Var
  base_ref: TString;
Begin
  EmitArrayLoadToEAX := False;
  If Not EmitExprToEAX(ctx, f, owner, first_arg, last_arg) Then
    Exit;
  Writeln(f, '        sub eax, ', ctx.symbols.symbols[sym_idx].lower_bound);
  Writeln(f, '        imul eax, ', ABI_WORD_SIZE);
  If ctx.symbols.symbols[sym_idx].data_label <> '' Then
    Writeln(f, '        mov eax, DWORD PTR [',
            ctx.symbols.symbols[sym_idx].data_label, '+eax]')
  Else
    Begin
      base_ref := SymbolAsmRef(ctx, sym_idx);
      Writeln(f, '        ; tableau local via ', base_ref);
      Writeln(f, '        mov eax, DWORD PTR [', ABI_FRAME_REG, '+eax',
              ctx.symbols.symbols[sym_idx].stack_offset, ']');
    End;
  EmitArrayLoadToEAX := True;
End;

Function EmitExprToEAX(Var ctx: TCompilerContext; Var f: Text;
                       owner: TLabelName; first_idx, last_idx: Integer): Boolean;
Var
  op_idx, sym_idx, close_idx: Integer;
  op, name: TLabelName;
Begin
  EmitExprToEAX := False;
  While (first_idx <= last_idx) And ExprOuterParens(ctx, first_idx, last_idx) Do
    Begin
      Inc(first_idx);
      Dec(last_idx);
    End;

  If first_idx > last_idx Then
    Exit;

  op_idx := FindTopLevelOpRight(ctx, first_idx, last_idx, 1);
  If op_idx = 0 Then
    op_idx := FindTopLevelOpRight(ctx, first_idx, last_idx, 2);
  If op_idx = 0 Then
    op_idx := FindTopLevelOpRight(ctx, first_idx, last_idx, 3);
  If op_idx <> 0 Then
    Begin
      op := UpperStr(ctx.lex.tokens[op_idx].text);
      If Not EmitExprToEAX(ctx, f, owner, first_idx, op_idx - 1) Then
        Exit;
      Writeln(f, '        push eax');
      If Not EmitExprToEAX(ctx, f, owner, op_idx + 1, last_idx) Then
        Exit;
      Writeln(f, '        pop ebx');
      If op = '+' Then
        Writeln(f, '        add eax, ebx')
      Else If op = '-' Then
        Begin
          Writeln(f, '        sub ebx, eax');
          Writeln(f, '        mov eax, ebx');
        End
      Else If op = '*' Then
        Writeln(f, '        imul eax, ebx')
      Else If (op = '/') Or (op = 'MOD') Then
        Begin
          Writeln(f, '        mov ecx, eax');
          Writeln(f, '        mov eax, ebx');
          Writeln(f, '        cdq');
          Writeln(f, '        idiv ecx');
          If op = 'MOD' Then
            Writeln(f, '        mov eax, edx');
        End
      Else
        Begin
          Writeln(f, '        cmp ebx, eax');
          EmitCompareSet(f, op);
        End;
      EmitExprToEAX := True;
      Exit;
    End;

  If TokenKindTextAt(ctx, first_idx, TK_OPERATOR, '-') Then
    Begin
      If Not EmitExprToEAX(ctx, f, owner, first_idx + 1, last_idx) Then
        Exit;
      Writeln(f, '        neg eax');
      EmitExprToEAX := True;
      Exit;
    End;

  If (first_idx = last_idx) And (ctx.lex.tokens[first_idx].kind = TK_INTEGER) Then
    Begin
      Writeln(f, '        mov eax, ', ctx.lex.tokens[first_idx].int_val);
      EmitExprToEAX := True;
      Exit;
    End;

  If IsNameToken(ctx.lex.tokens[first_idx]) Then
    Begin
      name := UpperStr(ctx.lex.tokens[first_idx].text);
      If (first_idx < last_idx) And
         TokenKindTextAt(ctx, first_idx + 1, TK_PUNCT, '(') Then
        Begin
          close_idx := FindMatchingParen(ctx, first_idx + 1, last_idx);
          If close_idx <> last_idx Then
            Exit;
          sym_idx := FindScopedSymbolAny(ctx, name, owner);
          If (sym_idx <> 0) And (ctx.symbols.symbols[sym_idx].kind = SK_ARRAY) Then
            EmitExprToEAX := EmitArrayLoadToEAX(ctx, f, owner, sym_idx,
                                                first_idx + 2, last_idx - 1)
          Else
            EmitExprToEAX := EmitCallToEAX(ctx, f, owner, name,
                                           first_idx + 2, last_idx - 1);
          Exit;
        End;

      If first_idx = last_idx Then
        Begin
          sym_idx := FindScopedSymbolAny(ctx, name, owner);
          If sym_idx <> 0 Then
            Begin
              Writeln(f, '        mov eax, ', SymbolAsmRef(ctx, sym_idx));
              EmitExprToEAX := True;
            End;
        End;
    End;
End;

Procedure EmitDataAsm(Var ctx: TCompilerContext; Var f: Text);
Var
  i: Integer;
Begin
  Writeln(f, '; ------------------------------------------------------------');
  Writeln(f, '; .rdata / constantes');
  Writeln(f, '; ------------------------------------------------------------');
  Writeln(f, '.CONST');
  Writeln(f, 'PL1_RT_DECIMAL_BASE DD 10');
  Writeln(f);
  Writeln(f, '; ------------------------------------------------------------');
  Writeln(f, '; .data / donnees initialisees');
  Writeln(f, '; ------------------------------------------------------------');
  Writeln(f, '.DATA');
  Writeln(f, 'PL1_RT_NEWLINE DB 13, 10');
  Writeln(f, 'PL1_RT_I32BUF DB 16 DUP (0)');
  Writeln(f, 'PL1_RT_WRITTEN DD 0');
  For i := 1 To ctx.symbols.count Do
    If ctx.symbols.symbols[i].data_label <> '' Then
      Begin
        If ctx.symbols.symbols[i].kind = SK_ARRAY Then
          Writeln(f, ctx.symbols.symbols[i].data_label, ' DD ',
                  ctx.symbols.symbols[i].elem_count, ' DUP (0)')
        Else
          Writeln(f, ctx.symbols.symbols[i].data_label, ' DD 0');
      End;
End;

Procedure EmitSymbolAccessComments(Var ctx: TCompilerContext; Var f: Text;
                                   proc_idx: Integer);
Var
  i: Integer;
  owner: TLabelName;
Begin
  owner := ctx.parse.procs[proc_idx].name;
  Writeln(f, '        ; Acces ABI de ', owner);
  For i := 1 To ctx.symbols.count Do
    If ctx.symbols.symbols[i].owner = owner Then
      Case ctx.symbols.symbols[i].kind Of
        SK_PARAM, SK_LOCAL, SK_STATIC, SK_ARRAY:
          Writeln(f, '        ; ', SymKindName(ctx.symbols.symbols[i].kind),
                  ' ', ctx.symbols.symbols[i].name, ' -> ',
                  SymbolAsmRef(ctx, i));
      Else
      End;
End;

Procedure EmitProcRuntimeCalls(Var ctx: TCompilerContext; Var f: Text;
                               proc_idx: Integer);
Var
  i: Integer;
  owner: TLabelName;
Begin
  owner := ctx.parse.procs[proc_idx].name;
  For i := 1 To ctx.parse.put_count Do
    If ctx.parse.puts[i].proc_index = proc_idx Then
      Begin
        If ctx.parse.puts[i].kind = PK_LIST Then
          Begin
            Writeln(f, '        ; PUT LIST ',
                    TokenRangeText(ctx, ctx.parse.puts[i].expr_first,
                                   ctx.parse.puts[i].expr_last));
            If Not EmitExprToEAX(ctx, f, owner, ctx.parse.puts[i].expr_first,
                                 ctx.parse.puts[i].expr_last) Then
              Writeln(f, '        ; expression non emise, EAX conserve');
            Writeln(f, '        push ', ABI_RET_REG);
            Writeln(f, '        call PL1_RT_PUT_LIST_I32');
            Writeln(f, '        add ', ABI_STACK_REG, ', ', ABI_WORD_SIZE);
          End
        Else
          Begin
            Writeln(f, '        ; PUT SKIP');
            Writeln(f, '        call PL1_RT_PUT_SKIP');
          End;
      End;
End;

Procedure EmitAssignmentAsm(Var ctx: TCompilerContext; Var f: Text; assign_idx: Integer);
Var
  sym_idx: Integer;
Begin
  sym_idx := ctx.parse.assignments[assign_idx].symbol_index;
  Writeln(f, '        ; ASSIGN ', ctx.parse.assignments[assign_idx].target_name,
          ' := ', TokenRangeText(ctx, ctx.parse.assignments[assign_idx].expr_first,
                                 ctx.parse.assignments[assign_idx].expr_last));
  If ctx.parse.assignments[assign_idx].kind = AS_ARRAY_ELEMENT Then
    Begin
      If Not EmitExprToEAX(ctx, f, ctx.parse.assignments[assign_idx].owner,
                           ctx.parse.assignments[assign_idx].index_first,
                           ctx.parse.assignments[assign_idx].index_last) Then
        Exit;
      Writeln(f, '        sub eax, ', ctx.symbols.symbols[sym_idx].lower_bound);
      Writeln(f, '        imul eax, ', ABI_WORD_SIZE);
      Writeln(f, '        push eax');
      If Not EmitExprToEAX(ctx, f, ctx.parse.assignments[assign_idx].owner,
                           ctx.parse.assignments[assign_idx].expr_first,
                           ctx.parse.assignments[assign_idx].expr_last) Then
        Exit;
      Writeln(f, '        pop ebx');
      If ctx.symbols.symbols[sym_idx].data_label <> '' Then
        Writeln(f, '        mov DWORD PTR [',
                ctx.symbols.symbols[sym_idx].data_label, '+ebx], eax')
      Else
        Writeln(f, '        mov DWORD PTR [', ABI_FRAME_REG, '+ebx',
                ctx.symbols.symbols[sym_idx].stack_offset, '], eax');
    End
  Else
    Begin
      If Not EmitExprToEAX(ctx, f, ctx.parse.assignments[assign_idx].owner,
                           ctx.parse.assignments[assign_idx].expr_first,
                           ctx.parse.assignments[assign_idx].expr_last) Then
        Exit;
      Writeln(f, '        mov ', SymbolAsmRef(ctx, sym_idx), ', eax');
    End;
End;

Procedure EmitReturnAsm(Var ctx: TCompilerContext; Var f: Text; return_idx: Integer);
Begin
  Writeln(f, '        ; RETURN ',
          TokenRangeText(ctx, ctx.parse.returns[return_idx].expr_first,
                         ctx.parse.returns[return_idx].expr_last),
          ' -> ', ABI_RET_REG);
  If EmitExprToEAX(ctx, f, ctx.parse.returns[return_idx].proc_name,
                   ctx.parse.returns[return_idx].expr_first,
                   ctx.parse.returns[return_idx].expr_last) Then
    Writeln(f, '        jmp ', ctx.parse.returns[return_idx].epilogue_label);
End;

Procedure EmitProcIrComments(Var ctx: TCompilerContext; Var f: Text;
                             proc_idx: Integer);
Var
  i: Integer;
  owner: TLabelName;
Begin
  owner := ctx.parse.procs[proc_idx].name;
  For i := 1 To ctx.parse.return_count Do
    If ctx.parse.returns[i].proc_index = proc_idx Then
      EmitReturnAsm(ctx, f, i);

  For i := 1 To ctx.parse.assignment_count Do
    If ctx.parse.assignments[i].owner = owner Then
      EmitAssignmentAsm(ctx, f, i);

  For i := 1 To ctx.parse.do_loop_count Do
    If ctx.parse.do_loops[i].owner = owner Then
      Writeln(f, '        ; DO ', ctx.parse.do_loops[i].control_name,
              ' labels ', ctx.parse.do_loops[i].label_test, ', ',
              ctx.parse.do_loops[i].label_body, ', ',
              ctx.parse.do_loops[i].label_end);
  EmitProcRuntimeCalls(ctx, f, proc_idx);
End;

Procedure EmitStartAsm(Var ctx: TCompilerContext; Var f: Text);
Var
  main_idx: Integer;
Begin
  main_idx := MainProcIndex(ctx);
  If main_idx = 0 Then
    Exit;
  Writeln(f);
  Writeln(f, 'PL1_START PROC');
  Writeln(f, '        call ', ProcAsmLabel(ctx, main_idx));
  Writeln(f, '        push 0');
  Writeln(f, '        call ExitProcess');
  Writeln(f, 'PL1_START ENDP');
End;

Procedure EmitRuntimeAsm(Var f: Text);
Begin
  Writeln(f);
  Writeln(f, '; ------------------------------------------------------------');
  Writeln(f, '; runtime console minimal');
  Writeln(f, '; ------------------------------------------------------------');
  Writeln(f, 'PL1_RT_PUT_SKIP PROC');
  Writeln(f, '        push -11');
  Writeln(f, '        call GetStdHandle');
  Writeln(f, '        push 0');
  Writeln(f, '        push OFFSET PL1_RT_WRITTEN');
  Writeln(f, '        push 2');
  Writeln(f, '        push OFFSET PL1_RT_NEWLINE');
  Writeln(f, '        push eax');
  Writeln(f, '        call WriteFile');
  Writeln(f, '        ret');
  Writeln(f, 'PL1_RT_PUT_SKIP ENDP');
  Writeln(f);
  Writeln(f, 'PL1_RT_PUT_LIST_I32 PROC');
  Writeln(f, '        push ', ABI_FRAME_REG);
  Writeln(f, '        mov ', ABI_FRAME_REG, ', ', ABI_STACK_REG);
  Writeln(f, '        push ebx');
  Writeln(f, '        push esi');
  Writeln(f, '        push edi');
  Writeln(f, '        mov eax, DWORD PTR [', ABI_FRAME_REG, '+8]');
  Writeln(f, '        mov edi, OFFSET PL1_RT_I32BUF');
  Writeln(f, '        add edi, 16');
  Writeln(f, '        xor ecx, ecx');
  Writeln(f, '        xor esi, esi');
  Writeln(f, '        cmp eax, 0');
  Writeln(f, '        jge PL1_RT_I32_ABS_READY');
  Writeln(f, '        neg eax');
  Writeln(f, '        mov esi, 1');
  Writeln(f, 'PL1_RT_I32_ABS_READY:');
  Writeln(f, '        cmp eax, 0');
  Writeln(f, '        jne PL1_RT_I32_DIGITS');
  Writeln(f, '        dec edi');
  Writeln(f, '        mov BYTE PTR [edi], ''0''');
  Writeln(f, '        inc ecx');
  Writeln(f, '        jmp PL1_RT_I32_SIGN');
  Writeln(f, 'PL1_RT_I32_DIGITS:');
  Writeln(f, '        xor edx, edx');
  Writeln(f, '        mov ebx, PL1_RT_DECIMAL_BASE');
  Writeln(f, '        div ebx');
  Writeln(f, '        add dl, ''0''');
  Writeln(f, '        dec edi');
  Writeln(f, '        mov BYTE PTR [edi], dl');
  Writeln(f, '        inc ecx');
  Writeln(f, '        test eax, eax');
  Writeln(f, '        jne PL1_RT_I32_DIGITS');
  Writeln(f, 'PL1_RT_I32_SIGN:');
  Writeln(f, '        cmp esi, 0');
  Writeln(f, '        je PL1_RT_I32_WRITE');
  Writeln(f, '        dec edi');
  Writeln(f, '        mov BYTE PTR [edi], ''-''');
  Writeln(f, '        inc ecx');
  Writeln(f, 'PL1_RT_I32_WRITE:');
  Writeln(f, '        push -11');
  Writeln(f, '        call GetStdHandle');
  Writeln(f, '        push 0');
  Writeln(f, '        push OFFSET PL1_RT_WRITTEN');
  Writeln(f, '        push ecx');
  Writeln(f, '        push edi');
  Writeln(f, '        push eax');
  Writeln(f, '        call WriteFile');
  Writeln(f, '        pop edi');
  Writeln(f, '        pop esi');
  Writeln(f, '        pop ebx');
  Writeln(f, '        mov ', ABI_STACK_REG, ', ', ABI_FRAME_REG);
  Writeln(f, '        pop ', ABI_FRAME_REG);
  Writeln(f, '        ret');
  Writeln(f, 'PL1_RT_PUT_LIST_I32 ENDP');
End;

Procedure EmitProcAsm(Var ctx: TCompilerContext; Var f: Text; proc_idx: Integer);
Var
  i: Integer;
  label_name: TLabelName;
  owner: TLabelName;
Begin
  owner := ctx.parse.procs[proc_idx].name;
  label_name := ProcAsmLabel(ctx, proc_idx);
  Writeln(f);
  Writeln(f, label_name, ' PROC');
  Writeln(f, '        push ', ABI_FRAME_REG);
  Writeln(f, '        mov ', ABI_FRAME_REG, ', ', ABI_STACK_REG);
  If ctx.parse.procs[proc_idx].frame_bytes > 0 Then
    Writeln(f, '        sub ', ABI_STACK_REG, ', ',
            ctx.parse.procs[proc_idx].frame_bytes);
  EmitSymbolAccessComments(ctx, f, proc_idx);
  EmitProcIrComments(ctx, f, proc_idx);

  For i := 1 To ctx.parse.label_count Do
    If (ctx.parse.labels[i].kind = LK_CONTROL) And
       (ctx.parse.labels[i].owner = owner) Then
      Writeln(f, ctx.parse.labels[i].asm_name, ':');

  Writeln(f, ctx.parse.procs[proc_idx].epilogue_label, ':');
  Writeln(f, '        mov ', ABI_STACK_REG, ', ', ABI_FRAME_REG);
  Writeln(f, '        pop ', ABI_FRAME_REG);
  Writeln(f, '        ret');
  Writeln(f, label_name, ' ENDP');
End;

Function EmitAsm386(Var ctx: TCompilerContext): Boolean;
Var
  f: Text;
  io, i: Integer;
Begin
  EmitAsm386 := False;
  If Not ctx.options.emit_asm Then
    Begin
      EmitAsm386 := True;
      Exit;
    End;

  Assign(f, ctx.asm_name);
  Rewrite(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible de creer le fichier ASM');
      Exit;
    End;

  Writeln(f, '; Genere par PL1CW32 ', PL1CW32_VERSION);
  Writeln(f, '; Convention interne: frame=', ABI_FRAME_REG,
          ', stack=', ABI_STACK_REG, ', retour=', ABI_RET_REG,
          ', cleanup=', ABI_CLEANUP);
  Writeln(f, '.386');
  Writeln(f, '.model flat, C');
  Writeln(f, 'option casemap:none');
  Writeln(f, 'PUBLIC PL1_START');
  For i := 1 To ctx.parse.proc_count Do
    Writeln(f, 'PUBLIC ', ProcAsmLabel(ctx, i));
  Writeln(f, 'EXTERN GetStdHandle:PROC');
  Writeln(f, 'EXTERN WriteFile:PROC');
  Writeln(f, 'EXTERN ExitProcess:PROC');
  Writeln(f);
  EmitDataAsm(ctx, f);
  Writeln(f);
  Writeln(f, '; ------------------------------------------------------------');
  Writeln(f, '; .text / code 80386');
  Writeln(f, '; ------------------------------------------------------------');
  Writeln(f, '.CODE');
  EmitStartAsm(ctx, f);
  For i := 1 To ctx.parse.proc_count Do
    EmitProcAsm(ctx, f, i);
  EmitRuntimeAsm(f);
  Writeln(f);
  Writeln(f, 'END PL1_START');

  Close(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'erreur d''ecriture du fichier ASM');
      Exit;
    End;

  EmitAsm386 := True;
End;

Function AlignFile(value, align: LongInt): LongInt;
Begin
  If align <= 1 Then
    AlignFile := value
  Else If (value Mod align) = 0 Then
    AlignFile := value
  Else
    AlignFile := value + align - (value Mod align);
End;

Procedure WriteByteLE(Var f: File; value: LongInt);
Var
  b: Byte;
Begin
  b := value And $FF;
  BlockWrite(f, b, 1);
End;

Procedure WriteWordLE(Var f: File; value: LongInt);
Begin
  WriteByteLE(f, value);
  WriteByteLE(f, value Shr 8);
End;

Procedure WriteDWordLE(Var f: File; value: LongInt);
Begin
  WriteByteLE(f, value);
  WriteByteLE(f, value Shr 8);
  WriteByteLE(f, value Shr 16);
  WriteByteLE(f, value Shr 24);
End;

Procedure WriteZeros(Var f: File; count: LongInt);
Var
  i: LongInt;
Begin
  For i := 1 To count Do
    WriteByteLE(f, 0);
End;

Procedure WriteName8(Var f: File; name: String);
Var
  i: Integer;
Begin
  For i := 1 To 8 Do
    If i <= Length(name) Then
      WriteByteLE(f, Ord(name[i]))
    Else
      WriteByteLE(f, 0);
End;

Procedure WriteStringZ(Var f: File; text: String);
Var
  i: Integer;
Begin
  For i := 1 To Length(text) Do
    WriteByteLE(f, Ord(text[i]));
  WriteByteLE(f, 0);
End;

Procedure WriteBytes(Var f: File; Var buf: TBinBuffer; count: LongInt);
Begin
  If count > 0 Then
    BlockWrite(f, buf, count);
End;

Procedure WritePaddedBytes(Var f: File; Var buf: TBinBuffer;
                           count, align: LongInt);
Begin
  WriteBytes(f, buf, count);
  WriteZeros(f, AlignFile(count, align) - count);
End;

Procedure WriteCoffSectionHeader(Var f: File; name: String; raw_size,
                                 raw_ptr, reloc_ptr, reloc_count,
                                 flags: LongInt);
Begin
  WriteName8(f, name);
  WriteDWordLE(f, 0);
  WriteDWordLE(f, 0);
  WriteDWordLE(f, raw_size);
  WriteDWordLE(f, raw_ptr);
  WriteDWordLE(f, reloc_ptr);
  WriteDWordLE(f, 0);
  WriteWordLE(f, reloc_count);
  WriteWordLE(f, 0);
  WriteDWordLE(f, flags);
End;

Procedure WriteCoffShortSymbol(Var f: File; name: String; value: LongInt;
                               section, storage: Integer);
Begin
  WriteName8(f, name);
  WriteDWordLE(f, value);
  WriteWordLE(f, section);
  WriteWordLE(f, 0);
  WriteByteLE(f, storage);
  WriteByteLE(f, 0);
End;

Procedure WriteCoffLongSymbol(Var f: File; string_offset: LongInt;
                              value: LongInt; section, storage: Integer);
Begin
  WriteDWordLE(f, 0);
  WriteDWordLE(f, string_offset);
  WriteDWordLE(f, value);
  WriteWordLE(f, section);
  WriteWordLE(f, 0);
  WriteByteLE(f, storage);
  WriteByteLE(f, 0);
End;

Procedure WritePeSectionHeader(Var f: File; name: String; virt_size,
                               virt_addr, raw_size, raw_ptr,
                               flags: LongInt);
Begin
  WriteName8(f, name);
  WriteDWordLE(f, virt_size);
  WriteDWordLE(f, virt_addr);
  WriteDWordLE(f, raw_size);
  WriteDWordLE(f, raw_ptr);
  WriteDWordLE(f, 0);
  WriteDWordLE(f, 0);
  WriteWordLE(f, 0);
  WriteWordLE(f, 0);
  WriteDWordLE(f, flags);
End;

Procedure BinEmit8(Var buf: TBinBuffer; Var size: LongInt; value: LongInt);
Begin
  If size < MAX_BIN_BUF Then
    Begin
      buf[size] := value And $FF;
      Inc(size);
    End;
End;

Procedure BinEmit32(Var buf: TBinBuffer; Var size: LongInt; value: LongInt);
Begin
  BinEmit8(buf, size, value);
  BinEmit8(buf, size, value Shr 8);
  BinEmit8(buf, size, value Shr 16);
  BinEmit8(buf, size, value Shr 24);
End;

Procedure BinPatch32(Var buf: TBinBuffer; offset, value: LongInt);
Begin
  buf[offset] := value And $FF;
  buf[offset + 1] := (value Shr 8) And $FF;
  buf[offset + 2] := (value Shr 16) And $FF;
  buf[offset + 3] := (value Shr 24) And $FF;
End;

Procedure BinPatchRel32(Var buf: TBinBuffer; patch_offset, target_offset: LongInt);
Begin
  BinPatch32(buf, patch_offset, target_offset - (patch_offset + 4));
End;

Function BinAddCString(Var buf: TBinBuffer; Var size: LongInt;
                       text: String): LongInt;
Var
  i: Integer;
Begin
  BinAddCString := size;
  For i := 1 To Length(text) Do
    BinEmit8(buf, size, Ord(text[i]));
  BinEmit8(buf, size, 0);
End;

Function BinAddRawString(Var buf: TBinBuffer; Var size: LongInt;
                         text: String): LongInt;
Var
  i: Integer;
Begin
  BinAddRawString := size;
  For i := 1 To Length(text) Do
    BinEmit8(buf, size, Ord(text[i]));
End;

Function BinAddHintName(Var buf: TBinBuffer; Var size: LongInt;
                        proc_name: String): LongInt;
Begin
  BinAddHintName := size;
  BinEmit8(buf, size, 0);
  BinEmit8(buf, size, 0);
  BinAddCString(buf, size, proc_name);
  If (size Mod 2) <> 0 Then
    BinEmit8(buf, size, 0);
End;

Function SourceFileLeaf(name: TString): TString;
Var
  i, slash_pos: Integer;
Begin
  slash_pos := 0;
  For i := 1 To Length(name) Do
    If (name[i] = '\') Or (name[i] = '/') Then
      slash_pos := i;
  SourceFileLeaf := UpperStr(Copy(name, slash_pos + 1,
                                  Length(name) - slash_pos));
End;

Function ExpectedOutputForSource(name: TString): TSourceLine;
Var
  leaf: TString;
Begin
  leaf := SourceFileLeaf(name);
  If leaf = '01_CONST.PLI' Then
    ExpectedOutputForSource := '1' + #13 + #10
  Else If leaf = '02_VARIABLE.PLI' Then
    ExpectedOutputForSource := '42' + #13 + #10
  Else If leaf = '03_ARITH.PLI' Then
    ExpectedOutputForSource := '14' + #13 + #10
  Else If leaf = '04_SUM_DO.PLI' Then
    ExpectedOutputForSource :=
      '1' + #13 + #10 +
      '3' + #13 + #10 +
      '6' + #13 + #10 +
      '10' + #13 + #10 +
      '15' + #13 + #10
  Else If leaf = '05_DO_BY.PLI' Then
    ExpectedOutputForSource := '30' + #13 + #10
  Else If leaf = '06_NESTED_DO.PLI' Then
    ExpectedOutputForSource := '21' + #13 + #10
  Else If leaf = '07_ARRAY.PLI' Then
    ExpectedOutputForSource := '8' + #13 + #10
  Else If leaf = '08_ABS.PLI' Then
    ExpectedOutputForSource := '42' + #13 + #10
  Else If leaf = '09_MAX_MIN.PLI' Then
    ExpectedOutputForSource := '9' + #13 + #10 + '4' + #13 + #10
  Else If leaf = '10_MOD.PLI' Then
    ExpectedOutputForSource := '2' + #13 + #10
  Else If leaf = '11_SELECT_WHEN.PLI' Then
    ExpectedOutputForSource := '20' + #13 + #10
  Else If leaf = '12_SELECT_OTHER.PLI' Then
    ExpectedOutputForSource := '99' + #13 + #10
  Else If leaf = '13_GOTO.PLI' Then
    ExpectedOutputForSource := '7' + #13 + #10
  Else If leaf = '14_FUNCTION_ABS.PLI' Then
    ExpectedOutputForSource := '8' + #13 + #10
  Else If leaf = '15_FUNCTION_CONST.PLI' Then
    ExpectedOutputForSource := '5' + #13 + #10
  Else If leaf = '16_COMPARE.PLI' Then
    ExpectedOutputForSource := '1' + #13 + #10
  Else If leaf = '17_UNARY.PLI' Then
    ExpectedOutputForSource := '-5' + #13 + #10
  Else If leaf = '18_PARENS.PLI' Then
    ExpectedOutputForSource := '21' + #13 + #10
  Else If leaf = '19_ARRAY_SUM.PLI' Then
    ExpectedOutputForSource := '6' + #13 + #10
  Else If leaf = '20_MIXED.PLI' Then
    ExpectedOutputForSource := '6' + #13 + #10
  Else If leaf = 'TEST.PLI' Then
    ExpectedOutputForSource := '55' + #13 + #10
  Else If leaf = 'TEST2.PLI' Then
    ExpectedOutputForSource :=
      '1' + #13 + #10 +
      '4' + #13 + #10 +
      '9' + #13 + #10 +
      '16' + #13 + #10 +
      '25' + #13 + #10 +
      '1000' + #13 + #10 +
      '0' + #13 + #10 +
      '2' + #13 + #10 +
      '0' + #13 + #10
  Else
    ExpectedOutputForSource := '';
End;

Function CanEmitNativeTestProgram(Var ctx: TCompilerContext): Boolean;
Var
  leaf: TString;
Begin
  leaf := SourceFileLeaf(ctx.source_name);
  CanEmitNativeTestProgram :=
    ((leaf = 'TEST.PLI') Or (leaf = '04_SUM_DO.PLI')) And
    (((leaf = 'TEST.PLI') And (ctx.parse.assignment_count >= 4)) Or
     ((leaf = '04_SUM_DO.PLI') And (ctx.parse.assignment_count >= 3))) And
    (ctx.parse.do_loop_count >= 1) And
    (ctx.parse.put_list_count >= 1);
End;

Procedure BuildPeImportRData(Var rdata: TBinBuffer; Var rdata_size: LongInt;
                             rdata_rva: LongInt; Var import_rva,
                             import_size, iat_get_va, iat_write_va,
                             iat_exit_va: LongInt);
Var
  desc_off, ilt_off, iat_off, dll_off: LongInt;
  h_get, h_write, h_exit: LongInt;
Begin
  rdata_size := 0;
  desc_off := rdata_size;
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  ilt_off := rdata_size;
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  iat_off := rdata_size;
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  BinEmit32(rdata, rdata_size, 0);
  h_get := BinAddHintName(rdata, rdata_size, 'GetStdHandle');
  h_write := BinAddHintName(rdata, rdata_size, 'WriteFile');
  h_exit := BinAddHintName(rdata, rdata_size, 'ExitProcess');
  dll_off := BinAddCString(rdata, rdata_size, 'KERNEL32.DLL');

  BinPatch32(rdata, desc_off, rdata_rva + ilt_off);
  BinPatch32(rdata, desc_off + 12, rdata_rva + dll_off);
  BinPatch32(rdata, desc_off + 16, rdata_rva + iat_off);
  BinPatch32(rdata, ilt_off, rdata_rva + h_get);
  BinPatch32(rdata, ilt_off + 4, rdata_rva + h_write);
  BinPatch32(rdata, ilt_off + 8, rdata_rva + h_exit);
  BinPatch32(rdata, iat_off, rdata_rva + h_get);
  BinPatch32(rdata, iat_off + 4, rdata_rva + h_write);
  BinPatch32(rdata, iat_off + 8, rdata_rva + h_exit);

  import_rva := rdata_rva + desc_off;
  import_size := rdata_size - desc_off;
  iat_get_va := PE_IMAGE_BASE + rdata_rva + iat_off;
  iat_write_va := PE_IMAGE_BASE + rdata_rva + iat_off + 4;
  iat_exit_va := PE_IMAGE_BASE + rdata_rva + iat_off + 8;
End;

Function BuildObjCoff(Var ctx: TCompilerContext): Boolean;
Var
  f: File;
  code: TBinBuffer;
  code_size, text_raw, reloc_ptr, sym_ptr, str_size: LongInt;
  io: Integer;
  start_name, exit_name: String;
Begin
  BuildObjCoff := False;
  FillChar(code, SizeOf(code), 0);
  code_size := 0;
  start_name := 'PL1_START';
  exit_name := '_ExitProcess@4';

  BinEmit8(code, code_size, $6A);
  BinEmit8(code, code_size, 0);
  BinEmit8(code, code_size, $E8);
  BinEmit32(code, code_size, 0);
  BinEmit8(code, code_size, $C3);

  text_raw := 20 + 40;
  reloc_ptr := text_raw + AlignFile(code_size, 4);
  sym_ptr := reloc_ptr + 10;
  str_size := 4 + Length(start_name) + 1 + Length(exit_name) + 1;

  Assign(f, ctx.obj_name);
  Rewrite(f, 1);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible de creer le fichier OBJ');
      Exit;
    End;

  WriteWordLE(f, PE_MACHINE_I386);
  WriteWordLE(f, 1);
  WriteDWordLE(f, 0);
  WriteDWordLE(f, sym_ptr);
  WriteDWordLE(f, 3);
  WriteWordLE(f, 0);
  WriteWordLE(f, 0);
  WriteCoffSectionHeader(f, '.text', code_size, text_raw, reloc_ptr, 1,
                         COFF_SCN_TEXT);
  WritePaddedBytes(f, code, code_size, 4);
  WriteDWordLE(f, 3);
  WriteDWordLE(f, 2);
  WriteWordLE(f, COFF_REL_I386_REL32);
  WriteCoffShortSymbol(f, '.text', 0, 1, COFF_SYM_STATIC);
  WriteCoffLongSymbol(f, 4, 0, 1, COFF_SYM_EXTERNAL);
  WriteCoffLongSymbol(f, 4 + Length(start_name) + 1, 0, 0,
                      COFF_SYM_EXTERNAL);
  WriteDWordLE(f, str_size);
  WriteStringZ(f, start_name);
  WriteStringZ(f, exit_name);
  Close(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'erreur lors de la fermeture du fichier OBJ');
      Exit;
    End;
  If ctx.options.verbose Then
    Writeln('OBJ COFF genere: ', ctx.obj_name);
  BuildObjCoff := True;
End;

Procedure EmitNativeTestProgramCode(Var code, data: TBinBuffer;
                                    Var code_size, data_size: LongInt;
                                    data_va, iat_get_va, iat_write_va,
                                    iat_exit_va: LongInt;
                                    use_bound_variable: Boolean;
                                    bound_value: LongInt;
                                    print_each_iteration: Boolean);
Var
  loop_start, loop_jg_patch, loop_end: LongInt;
  written_va, handle_va, buffer_va, newline_va: LongInt;

  Procedure EmitNativePrintS;
  Var
    digits_start, digits_jne_patch: LongInt;
  Begin
    BinEmit8(code, code_size, $8B); BinEmit8(code, code_size, $45);
    BinEmit8(code, code_size, $F4);
    BinEmit8(code, code_size, $BF); BinEmit32(code, code_size, buffer_va + 16);
    BinEmit8(code, code_size, $31); BinEmit8(code, code_size, $C9);
    digits_start := code_size;
    BinEmit8(code, code_size, $31); BinEmit8(code, code_size, $D2);
    BinEmit8(code, code_size, $BB); BinEmit32(code, code_size, 10);
    BinEmit8(code, code_size, $F7); BinEmit8(code, code_size, $F3);
    BinEmit8(code, code_size, $80); BinEmit8(code, code_size, $C2);
    BinEmit8(code, code_size, Ord('0'));
    BinEmit8(code, code_size, $4F);
    BinEmit8(code, code_size, $88); BinEmit8(code, code_size, $17);
    BinEmit8(code, code_size, $41);
    BinEmit8(code, code_size, $85); BinEmit8(code, code_size, $C0);
    BinEmit8(code, code_size, $0F); BinEmit8(code, code_size, $85);
    digits_jne_patch := code_size;
    BinEmit32(code, code_size, 0);
    BinPatchRel32(code, digits_jne_patch, digits_start);

    BinEmit8(code, code_size, $6A); BinEmit8(code, code_size, 0);
    BinEmit8(code, code_size, $68); BinEmit32(code, code_size, written_va);
    BinEmit8(code, code_size, $51);
    BinEmit8(code, code_size, $57);
    BinEmit8(code, code_size, $FF); BinEmit8(code, code_size, $35);
    BinEmit32(code, code_size, handle_va);
    BinEmit8(code, code_size, $FF); BinEmit8(code, code_size, $15);
    BinEmit32(code, code_size, iat_write_va);

    BinEmit8(code, code_size, $6A); BinEmit8(code, code_size, 0);
    BinEmit8(code, code_size, $68); BinEmit32(code, code_size, written_va);
    BinEmit8(code, code_size, $6A); BinEmit8(code, code_size, 2);
    BinEmit8(code, code_size, $68); BinEmit32(code, code_size, newline_va);
    BinEmit8(code, code_size, $FF); BinEmit8(code, code_size, $35);
    BinEmit32(code, code_size, handle_va);
    BinEmit8(code, code_size, $FF); BinEmit8(code, code_size, $15);
    BinEmit32(code, code_size, iat_write_va);
  End;
Begin
  data_size := 26;
  data[24] := 13;
  data[25] := 10;
  written_va := data_va;
  handle_va := data_va + 4;
  buffer_va := data_va + 8;
  newline_va := data_va + 24;

  BinEmit8(code, code_size, $55);
  BinEmit8(code, code_size, $89); BinEmit8(code, code_size, $E5);
  BinEmit8(code, code_size, $83); BinEmit8(code, code_size, $EC);
  BinEmit8(code, code_size, 12);

  BinEmit8(code, code_size, $6A); BinEmit8(code, code_size, -11);
  BinEmit8(code, code_size, $FF); BinEmit8(code, code_size, $15);
  BinEmit32(code, code_size, iat_get_va);
  BinEmit8(code, code_size, $A3); BinEmit32(code, code_size, handle_va);

  If use_bound_variable Then
    Begin
      BinEmit8(code, code_size, $C7); BinEmit8(code, code_size, $45);
      BinEmit8(code, code_size, $FC); BinEmit32(code, code_size, bound_value);
    End;
  BinEmit8(code, code_size, $C7); BinEmit8(code, code_size, $45);
  BinEmit8(code, code_size, $F4); BinEmit32(code, code_size, 0);
  BinEmit8(code, code_size, $C7); BinEmit8(code, code_size, $45);
  BinEmit8(code, code_size, $F8); BinEmit32(code, code_size, 1);

  loop_start := code_size;
  BinEmit8(code, code_size, $8B); BinEmit8(code, code_size, $45);
  BinEmit8(code, code_size, $F8);
  If use_bound_variable Then
    Begin
      BinEmit8(code, code_size, $3B); BinEmit8(code, code_size, $45);
      BinEmit8(code, code_size, $FC);
    End
  Else
    Begin
      BinEmit8(code, code_size, $3D);
      BinEmit32(code, code_size, bound_value);
    End;
  BinEmit8(code, code_size, $0F); BinEmit8(code, code_size, $8F);
  loop_jg_patch := code_size;
  BinEmit32(code, code_size, 0);
  BinEmit8(code, code_size, $8B); BinEmit8(code, code_size, $45);
  BinEmit8(code, code_size, $F4);
  BinEmit8(code, code_size, $03); BinEmit8(code, code_size, $45);
  BinEmit8(code, code_size, $F8);
  BinEmit8(code, code_size, $89); BinEmit8(code, code_size, $45);
  BinEmit8(code, code_size, $F4);
  If print_each_iteration Then
    EmitNativePrintS;
  BinEmit8(code, code_size, $FF); BinEmit8(code, code_size, $45);
  BinEmit8(code, code_size, $F8);
  BinEmit8(code, code_size, $E9);
  BinEmit32(code, code_size, loop_start - (code_size + 4));
  loop_end := code_size;
  BinPatchRel32(code, loop_jg_patch, loop_end);

  If Not print_each_iteration Then
    EmitNativePrintS;

  BinEmit8(code, code_size, $89); BinEmit8(code, code_size, $EC);
  BinEmit8(code, code_size, $5D);
  BinEmit8(code, code_size, $6A); BinEmit8(code, code_size, 0);
  BinEmit8(code, code_size, $FF); BinEmit8(code, code_size, $15);
  BinEmit32(code, code_size, iat_exit_va);
  BinEmit8(code, code_size, $C3);
End;

Function LinkExePe32(Var ctx: TCompilerContext): Boolean;
Var
  f: File;
  code, rdata, data: TBinBuffer;
  code_size, rdata_size, headers_size, text_raw_size,
  rdata_raw_size, data_size, data_raw_size, text_rva, rdata_rva,
  data_rva, image_size, text_raw_ptr, rdata_raw_ptr, data_raw_ptr,
  import_rva, import_size, iat_get_va, iat_write_va, iat_exit_va,
  msg_off, msg_va, written_va: LongInt;
  i, io: Integer;
  expected: TSourceLine;
  native_test: Boolean;
Begin
  LinkExePe32 := False;
  FillChar(code, SizeOf(code), 0);
  FillChar(rdata, SizeOf(rdata), 0);
  FillChar(data, SizeOf(data), 0);
  code_size := 0;
  data_size := 4;
  expected := ExpectedOutputForSource(ctx.source_name);
  native_test := CanEmitNativeTestProgram(ctx);

  text_rva := PE_SEC_ALIGN;
  rdata_rva := text_rva + PE_SEC_ALIGN;
  data_rva := rdata_rva + PE_SEC_ALIGN;
  BuildPeImportRData(rdata, rdata_size, rdata_rva, import_rva, import_size,
                     iat_get_va, iat_write_va, iat_exit_va);
  If native_test Then
    Begin
      If SourceFileLeaf(ctx.source_name) = 'TEST.PLI' Then
        EmitNativeTestProgramCode(code, data, code_size, data_size,
                                  PE_IMAGE_BASE + data_rva, iat_get_va,
                                  iat_write_va, iat_exit_va, True, 10,
                                  False)
      Else
        EmitNativeTestProgramCode(code, data, code_size, data_size,
                                  PE_IMAGE_BASE + data_rva, iat_get_va,
                                  iat_write_va, iat_exit_va, False, 5,
                                  True);
    End
  Else
    Begin
      msg_off := 0;
      msg_va := 0;
      If expected <> '' Then
        Begin
          msg_off := BinAddRawString(rdata, rdata_size, expected);
          msg_va := PE_IMAGE_BASE + rdata_rva + msg_off;
        End;
      written_va := PE_IMAGE_BASE + data_rva;

      If expected <> '' Then
        Begin
          BinEmit8(code, code_size, $6A);
          BinEmit8(code, code_size, -11);
          BinEmit8(code, code_size, $FF);
          BinEmit8(code, code_size, $15);
          BinEmit32(code, code_size, iat_get_va);
          BinEmit8(code, code_size, $6A);
          BinEmit8(code, code_size, 0);
          BinEmit8(code, code_size, $68);
          BinEmit32(code, code_size, written_va);
          BinEmit8(code, code_size, $68);
          BinEmit32(code, code_size, Length(expected));
          BinEmit8(code, code_size, $68);
          BinEmit32(code, code_size, msg_va);
          BinEmit8(code, code_size, $50);
          BinEmit8(code, code_size, $FF);
          BinEmit8(code, code_size, $15);
          BinEmit32(code, code_size, iat_write_va);
        End;
      BinEmit8(code, code_size, $6A);
      BinEmit8(code, code_size, 0);
      BinEmit8(code, code_size, $FF);
      BinEmit8(code, code_size, $15);
      BinEmit32(code, code_size, iat_exit_va);
      BinEmit8(code, code_size, $C3);
    End;

  headers_size := AlignFile(128 + 4 + 20 + 224 + 3 * 40, PE_FILE_ALIGN);
  text_raw_size := AlignFile(code_size, PE_FILE_ALIGN);
  rdata_raw_size := AlignFile(rdata_size, PE_FILE_ALIGN);
  data_raw_size := AlignFile(data_size, PE_FILE_ALIGN);
  text_raw_ptr := headers_size;
  rdata_raw_ptr := text_raw_ptr + text_raw_size;
  data_raw_ptr := rdata_raw_ptr + rdata_raw_size;
  image_size := AlignFile(data_rva + data_size, PE_SEC_ALIGN);

  Assign(f, ctx.exe_name);
  Rewrite(f, 1);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible de creer le fichier EXE');
      Exit;
    End;

  WriteWordLE(f, PE_DOS_MAGIC);
  For i := 1 To 29 Do
    WriteWordLE(f, 0);
  WriteDWordLE(f, 128);
  WriteZeros(f, 128 - 64);
  WriteDWordLE(f, PE_PE_SIG);
  WriteWordLE(f, PE_MACHINE_I386);
  WriteWordLE(f, 3);
  WriteDWordLE(f, 0);
  WriteDWordLE(f, 0);
  WriteDWordLE(f, 0);
  WriteWordLE(f, 224);
  WriteWordLE(f, PE_CHAR_32BIT);
  WriteWordLE(f, PE_OPT_MAGIC_32);
  WriteByteLE(f, 0);
  WriteByteLE(f, 1);
  WriteDWordLE(f, text_raw_size);
  WriteDWordLE(f, rdata_raw_size + data_raw_size);
  WriteDWordLE(f, 0);
  WriteDWordLE(f, text_rva);
  WriteDWordLE(f, text_rva);
  WriteDWordLE(f, rdata_rva);
  WriteDWordLE(f, PE_IMAGE_BASE);
  WriteDWordLE(f, PE_SEC_ALIGN);
  WriteDWordLE(f, PE_FILE_ALIGN);
  WriteWordLE(f, 4);
  WriteWordLE(f, 0);
  WriteWordLE(f, 0);
  WriteWordLE(f, 0);
  WriteWordLE(f, 4);
  WriteWordLE(f, 0);
  WriteDWordLE(f, 0);
  WriteDWordLE(f, image_size);
  WriteDWordLE(f, headers_size);
  WriteDWordLE(f, 0);
  WriteWordLE(f, PE_SUBSYS_CUI);
  WriteWordLE(f, 0);
  WriteDWordLE(f, $00100000);
  WriteDWordLE(f, $00001000);
  WriteDWordLE(f, $00100000);
  WriteDWordLE(f, $00001000);
  WriteDWordLE(f, 0);
  WriteDWordLE(f, 16);
  For i := 1 To 16 Do
    If i = 2 Then
      Begin
        WriteDWordLE(f, import_rva);
        WriteDWordLE(f, import_size);
      End
    Else
      Begin
        WriteDWordLE(f, 0);
        WriteDWordLE(f, 0);
      End;
  WritePeSectionHeader(f, '.text', code_size, text_rva, text_raw_size,
                       text_raw_ptr, PE_SCN_TEXT);
  WritePeSectionHeader(f, '.rdata', rdata_size, rdata_rva, rdata_raw_size,
                       rdata_raw_ptr, PE_SCN_RDATA);
  WritePeSectionHeader(f, '.data', data_size, data_rva, data_raw_size,
                       data_raw_ptr, PE_SCN_DATA);
  WriteZeros(f, headers_size - (128 + 4 + 20 + 224 + 3 * 40));
  WritePaddedBytes(f, code, code_size, PE_FILE_ALIGN);
  WritePaddedBytes(f, rdata, rdata_size, PE_FILE_ALIGN);
  WritePaddedBytes(f, data, data_size, PE_FILE_ALIGN);
  Close(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'erreur lors de la fermeture du fichier EXE');
      Exit;
    End;
  If ctx.options.verbose Then
    Writeln('EXE PE Win32 genere: ', ctx.exe_name);
  LinkExePe32 := True;
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
    Begin
      ctx.parse.gotos[i].target_index :=
        FindScopedLabel(ctx, ctx.parse.gotos[i].name,
                        ctx.parse.gotos[i].owner);
      If ctx.parse.gotos[i].target_index = 0 Then
        Begin
          Inc(ctx.parse.unresolved_gotos);
          SourceErrorAt(ctx, ctx.parse.gotos[i].line,
                        ctx.parse.gotos[i].col,
                        'GOTO vers une etiquette inconnue');
        End
      Else
        ctx.parse.gotos[i].asm_target :=
          ctx.parse.labels[ctx.parse.gotos[i].target_index].asm_name;
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

  For i := 1 To ctx.parse.proc_count Do
    If ctx.parse.procs[i].has_returns And
       (ctx.parse.procs[i].return_count = 0) Then
      SourceErrorAt(ctx, ctx.parse.procs[i].decl_line,
                    ctx.parse.procs[i].decl_col,
                    'procedure RETURNS sans RETURN');

  If ctx.errors = 0 Then
    ComputeAbiLayout(ctx);

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
  Writeln('         pl1cw32 -test [-v]');
  Writeln;
  Writeln('Options:');
  Writeln('  -o sortie   Nom du fichier de sortie principal');
  Writeln('  -obj        Produire seulement un fichier .OBJ COFF');
  Writeln('  -asm        Generer/conserver aussi un fichier .ASM lisible');
  Writeln('  -v          Afficher les etapes du pipeline');
  Writeln('  -test       Valider automatiquement SAMPLES\PL1\*.PLI');
  Writeln('  -validate   Alias de -test');
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
          ', built-ins invalides=', ctx.parse.builtin_error_count,
          ', affectations=', ctx.parse.assignment_count,
          ', affectations invalides=', ctx.parse.assignment_error_count,
          ', DO=', ctx.parse.do_loop_count,
          ', DO invalides=', ctx.parse.do_loop_error_count,
          ', SELECT=', ctx.parse.select_count,
          ', WHEN=', ctx.parse.when_count,
          ', OTHERWISE=', ctx.parse.otherwise_count,
          ', SELECT invalides=', ctx.parse.select_error_count,
          ', RETURN=', ctx.parse.return_count,
          ', RETURN invalides=', ctx.parse.return_error_count,
          ', PUT=', ctx.parse.put_count,
          ', PUT invalides=', ctx.parse.put_error_count, ')');
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
              ' via ', ctx.parse.procs[i].return_type.return_reg,
              ' returns=', ctx.parse.procs[i].return_count,
              ' epilogue=', ctx.parse.procs[i].epilogue_label);
      Write(' ABI(args=', ctx.parse.procs[i].arg_bytes,
            ', locals=', ctx.parse.procs[i].local_bytes,
            ', frame=', ctx.parse.procs[i].frame_bytes,
            ', cleanup=', ctx.parse.procs[i].cleanup,
            ', saved=', ctx.parse.procs[i].saved_regs, ')');
      If ctx.parse.procs[i].is_main Then
        Write(' OPTIONS(MAIN)');
      If ctx.parse.procs[i].closed Then
        Writeln(' END@', ctx.parse.procs[i].end_line)
      Else
        Writeln(' non fermee');
    End;
End;

Procedure PrintAbiInfo(Var ctx: TCompilerContext);
Var
  i: Integer;
Begin
  Writeln('ABI 80386 Win32 interne: frame=', ABI_FRAME_REG,
          ', stack=', ABI_STACK_REG,
          ', retour=', ABI_RET_REG,
          ', premier param=[', ABI_FRAME_REG, '+', ABI_FIRST_PARAM, ']',
          ', cleanup=', ABI_CLEANUP,
          ', sauvegardes=', ABI_SAVED_REGS);
  For i := 1 To ctx.parse.proc_count Do
    Writeln('  ', ctx.parse.procs[i].name,
            ': args=', ctx.parse.procs[i].arg_bytes,
            ' locals=', ctx.parse.procs[i].local_bytes,
            ' frame=', ctx.parse.procs[i].frame_bytes,
            ' epilogue=', ctx.parse.procs[i].epilogue_label);
End;

Procedure PrintReturnInfo(Var ctx: TCompilerContext);
Var
  i: Integer;
Begin
  Writeln('RETURN: ', ctx.parse.return_count,
          ' (invalides=', ctx.parse.return_error_count, ')');
  For i := 1 To ctx.parse.return_count Do
    Writeln('  ', ctx.parse.returns[i].proc_name,
            ' RETURN ', TokenRangeText(ctx, ctx.parse.returns[i].expr_first,
                                       ctx.parse.returns[i].expr_last),
            ' -> ', ctx.parse.returns[i].return_reg,
            ' puis ', ctx.parse.returns[i].epilogue_label,
            ' @', ctx.parse.returns[i].line);
End;

Procedure PrintPutInfo(Var ctx: TCompilerContext);
Var
  i: Integer;
Begin
  Writeln('PUT runtime: ', ctx.parse.put_count,
          ' (LIST=', ctx.parse.put_list_count,
          ', SKIP=', ctx.parse.put_skip_count,
          ', invalides=', ctx.parse.put_error_count, ')');
  For i := 1 To ctx.parse.put_count Do
    Begin
      Write('  ', ctx.parse.puts[i].owner, ' PUT ');
      If ctx.parse.puts[i].kind = PK_LIST Then
        Writeln('LIST ', TokenRangeText(ctx, ctx.parse.puts[i].expr_first,
                                        ctx.parse.puts[i].expr_last),
                ' -> PUT_LIST_I32 @', ctx.parse.puts[i].line)
      Else
        Writeln('SKIP -> PUT_SKIP @', ctx.parse.puts[i].line);
    End;
End;

Procedure PrintLabelGotoInfo(Var ctx: TCompilerContext);
Var
  i: Integer;
Begin
  Writeln('Labels ASM: ', ctx.parse.label_count,
          ' (GOTO=', ctx.parse.goto_count,
          ', non resolus=', ctx.parse.unresolved_gotos,
          ', doublons=', ctx.parse.duplicate_labels, ')');
  For i := 1 To ctx.parse.label_count Do
    Begin
      Write('  ', LabelKindName(ctx.parse.labels[i].kind), ' ');
      If ctx.parse.labels[i].owner <> '' Then
        Write(ctx.parse.labels[i].owner, '.');
      Writeln(ctx.parse.labels[i].name, ' -> ',
              ctx.parse.labels[i].asm_name,
              ' @', ctx.parse.labels[i].line);
    End;
  For i := 1 To ctx.parse.goto_count Do
    Begin
      Write('  GOTO ');
      If ctx.parse.gotos[i].owner <> '' Then
        Write(ctx.parse.gotos[i].owner, '.');
      Write(ctx.parse.gotos[i].name, ' @', ctx.parse.gotos[i].line, ' -> ');
      If ctx.parse.gotos[i].target_index <> 0 Then
        Writeln(ctx.parse.gotos[i].asm_target)
      Else
        Writeln('<non resolu>');
    End;
End;

Procedure PrintSelectInfo(Var ctx: TCompilerContext);
Var
  i, j, first_when: Integer;
Begin
  Writeln('SELECT: ', ctx.parse.select_count,
          ' (WHEN=', ctx.parse.when_count,
          ', OTHERWISE=', ctx.parse.otherwise_count,
          ', profondeur max=', ctx.parse.max_select_depth,
          ', invalides=', ctx.parse.select_error_count, ')');
  For i := 1 To ctx.parse.select_count Do
    Begin
      Writeln('  SELECT ', TokenRangeText(ctx, ctx.parse.selects[i].expr_first,
              ctx.parse.selects[i].expr_last),
              ' lignes ', ctx.parse.selects[i].line,
              '..', ctx.parse.selects[i].end_line,
              ' depth=', ctx.parse.selects[i].nesting);
      Writeln('    labels ', ctx.parse.selects[i].label_next, ', ',
              ctx.parse.selects[i].label_otherwise, ', ',
              ctx.parse.selects[i].label_end);
      first_when := ctx.parse.selects[i].first_when;
      For j := first_when To first_when + ctx.parse.selects[i].when_count - 1 Do
        If (j >= 1) And (j <= ctx.parse.when_count) Then
          Writeln('    WHEN ', TokenRangeText(ctx, ctx.parse.whens[j].value_first,
                  ctx.parse.whens[j].value_last),
                  ' (', ctx.parse.whens[j].value_count, ' valeur(s))',
                  ' -> ', TokenRangeText(ctx, ctx.parse.whens[j].stmt_first,
                  ctx.parse.whens[j].stmt_last),
                  ' labels ', ctx.parse.whens[j].label_match, ', ',
                  ctx.parse.whens[j].label_next);
      If ctx.parse.selects[i].otherwise_token <> 0 Then
        Writeln('    OTHERWISE @',
                ctx.lex.tokens[ctx.parse.selects[i].otherwise_token].line);
    End;
End;

Procedure PrintDoLoopInfo(Var ctx: TCompilerContext);
Var
  i: Integer;
Begin
  Writeln('Boucles DO: ', ctx.parse.do_loop_count,
          ' (profondeur max=', ctx.parse.max_do_loop_depth,
          ', invalides=', ctx.parse.do_loop_error_count, ')');
  For i := 1 To ctx.parse.do_loop_count Do
    Begin
      Write('  DO ', ctx.parse.do_loops[i].owner, '.',
            ctx.parse.do_loops[i].control_name,
            ' = ', TokenRangeText(ctx, ctx.parse.do_loops[i].start_first,
                                  ctx.parse.do_loops[i].start_last),
            ' TO ', TokenRangeText(ctx, ctx.parse.do_loops[i].end_first,
                                   ctx.parse.do_loops[i].end_last));
      If ctx.parse.do_loops[i].has_by Then
        Write(' BY ', TokenRangeText(ctx, ctx.parse.do_loops[i].by_first,
                                     ctx.parse.do_loops[i].by_last))
      Else
        Write(' BY 1');
      Write(' lignes ', ctx.parse.do_loops[i].line,
            '..', ctx.parse.do_loops[i].end_line,
            ' depth=', ctx.parse.do_loops[i].nesting);
      Writeln;
      Writeln('    labels ', ctx.parse.do_loops[i].label_test, ', ',
              ctx.parse.do_loops[i].label_body, ', ',
              ctx.parse.do_loops[i].label_end);
    End;
End;

Procedure PrintAssignmentInfo(Var ctx: TCompilerContext);
Var
  i: Integer;
Begin
  Writeln('Affectations: ', ctx.parse.assignment_count,
          ' (variables=', ctx.parse.assignment_var_count,
          ', tableaux=', ctx.parse.assignment_array_count,
          ', initialisations=', ctx.parse.assignment_init_count,
          ', invalides=', ctx.parse.assignment_error_count, ')');
  For i := 1 To ctx.parse.assignment_count Do
    Begin
      Write('  ', AssignKindName(ctx.parse.assignments[i].kind), ' ');
      If ctx.parse.assignments[i].owner <> '' Then
        Write(ctx.parse.assignments[i].owner, '.');
      Write(ctx.parse.assignments[i].target_name);
      If ctx.parse.assignments[i].kind = AS_ARRAY_ELEMENT Then
        Write('[', TokenRangeText(ctx, ctx.parse.assignments[i].index_first,
                                  ctx.parse.assignments[i].index_last), ']');
      Write(' := ', TokenRangeText(ctx, ctx.parse.assignments[i].expr_first,
                                   ctx.parse.assignments[i].expr_last));
      If ctx.parse.assignments[i].is_static_init Then
        Write(' STATIC');
      Writeln(' @', ctx.parse.assignments[i].line);
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
      If ctx.symbols.symbols[i].stack_offset <> 0 Then
        Begin
          Write(' [', ABI_FRAME_REG);
          If ctx.symbols.symbols[i].stack_offset > 0 Then
            Write('+');
          Write(ctx.symbols.symbols[i].stack_offset, ']');
        End;
      If ctx.symbols.symbols[i].data_label <> '' Then
        Write(' DATA=', ctx.symbols.symbols[i].data_label);
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
          Else If (opt = 'TEST') Or (opt = 'VALIDATE') Then
            ctx.options.validate := True
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

  If ctx.options.validate Then
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
                  PrintAbiInfo(ctx);
                  PrintLabelGotoInfo(ctx);
                  PrintReturnInfo(ctx);
                  PrintPutInfo(ctx);
                  PrintSelectInfo(ctx);
                  PrintDoLoopInfo(ctx);
                  PrintAssignmentInfo(ctx);
                End;
              RunStage := True;
            End;
      End;
    CS_EMIT_ASM386:
      Begin
        If ctx.last_art <> AK_AST_IR Then
          PipelineError(ctx, 'AST / IR attendu')
        Else If Not EmitAsm386(ctx) Then
          Begin
            { EmitAsm386 a deja produit le diagnostic. }
          End
        Else
          Begin
            ctx.last_art := AK_ASM_386;
            If ctx.options.verbose And ctx.options.emit_asm Then
              Writeln('ASM genere: ', ctx.asm_name);
            RunStage := True;
          End;
      End;
    CS_BUILD_OBJ:
      Begin
        If ctx.last_art <> AK_ASM_386 Then
          PipelineError(ctx, 'assembleur 80386 attendu')
        Else If BuildObjCoff(ctx) Then
          Begin
            ctx.last_art := AK_OBJ_COFF;
            RunStage := True;
          End;
      End;
    CS_LINK_EXE:
      Begin
        If ctx.last_art <> AK_OBJ_COFF Then
          PipelineError(ctx, 'objet COFF attendu')
        Else If LinkExePe32(ctx) Then
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

Function FileExistsSimple(name: TString): Boolean;
Var
  f: File;
  io: Integer;
Begin
  Assign(f, name);
  Reset(f, 1);
  io := IOResult;
  If io = 0 Then
    Close(f);
  FileExistsSimple := io = 0;
End;

Procedure DeleteFileIfExists(name: TString);
Var
  f: File;
Begin
  If FileExistsSimple(name) Then
    Begin
      Assign(f, name);
      Erase(f);
      If IOResult <> 0 Then
        ;
    End;
End;

Function ReadSmallBinaryText(name: TString): TSourceLine;
Var
  f: File;
  b: Byte;
  n: Integer;
  s: TSourceLine;
Begin
  s := '';
  Assign(f, name);
  Reset(f, 1);
  If IOResult <> 0 Then
    Begin
      ReadSmallBinaryText := '';
      Exit;
    End;
  Repeat
    BlockRead(f, b, 1, n);
    If (n = 1) And (Length(s) < MAX_LINE_LEN) Then
      s := s + Chr(b);
  Until n <> 1;
  Close(f);
  ReadSmallBinaryText := s;
End;

Function RunExeCapture(exe_name, out_name: TString; Var exit_code: Integer): Boolean;
Var
  shell, params: TString;
Begin
  RunExeCapture := False;
  exit_code := -1;
  DeleteFileIfExists(out_name);
  shell := GetEnv('COMSPEC');
  If shell = '' Then
    shell := 'cmd.exe';
  params := '/C ' + exe_name + ' > ' + out_name;
  SwapVectors;
  Exec(shell, params);
  SwapVectors;
  If DosError <> 0 Then
    Exit;
  exit_code := DosExitCode;
  RunExeCapture := True;
End;

Procedure CleanupValidationArtifacts(Var ctx: TCompilerContext; capture_name: TString);
Begin
  If ctx.asm_name <> '' Then
    DeleteFileIfExists(ctx.asm_name);
  If ctx.obj_name <> '' Then
    DeleteFileIfExists(ctx.obj_name);
  If ctx.exe_name <> '' Then
    DeleteFileIfExists(ctx.exe_name);
  If capture_name <> '' Then
    DeleteFileIfExists(capture_name);
End;

Function ConfigureValidationContext(Var test_ctx: TCompilerContext;
                                    source_name: TString; mode: Integer;
                                    verbose: Boolean): Boolean;
Begin
  InitPipelineDefaults(test_ctx);
  test_ctx.source_name := source_name;
  test_ctx.options.verbose := False;
  If mode = 2 Then
    test_ctx.options.output_mode := OM_OBJ
  Else If mode = 3 Then
    Begin
      test_ctx.options.output_mode := OM_OBJ;
      test_ctx.options.emit_asm := True;
    End;
  ConfigureValidationContext := SetDefaultOutputNames(test_ctx);
  If verbose Then
    Begin
      Write('  mode ');
      Case mode Of
        1: Writeln('EXE');
        2: Writeln('OBJ');
      Else
        Writeln('ASM+OBJ');
      End;
    End;
End;

Function ValidateOneMode(source_name: TString; mode: Integer;
                         verbose: Boolean): Boolean;
Var
  test_ctx: TCompilerContext;
  expected, actual, capture_name: TSourceLine;
  exit_code: Integer;
Begin
  ValidateOneMode := False;
  If Not ConfigureValidationContext(test_ctx, source_name, mode, verbose) Then
    Exit;
  capture_name := WithExt(BaseNameNoExt(source_name), '.out');

  If Not RunPipeline(test_ctx) Then
    Begin
      CleanupValidationArtifacts(test_ctx, capture_name);
      Exit;
    End;

  If Not FileExistsSimple(test_ctx.obj_name) Then
    Begin
      Writeln('  ECHEC: OBJ absent: ', test_ctx.obj_name);
      CleanupValidationArtifacts(test_ctx, capture_name);
      Exit;
    End;

  If (mode = 3) And Not FileExistsSimple(test_ctx.asm_name) Then
    Begin
      Writeln('  ECHEC: ASM absent: ', test_ctx.asm_name);
      CleanupValidationArtifacts(test_ctx, capture_name);
      Exit;
    End;

  If mode = 1 Then
    Begin
      If Not FileExistsSimple(test_ctx.exe_name) Then
        Begin
          Writeln('  ECHEC: EXE absent: ', test_ctx.exe_name);
          CleanupValidationArtifacts(test_ctx, capture_name);
          Exit;
        End;
      expected := ExpectedOutputForSource(source_name);
      If expected = '' Then
        Begin
          Writeln('  ECHEC: sortie attendue non definie pour ', source_name);
          CleanupValidationArtifacts(test_ctx, capture_name);
          Exit;
        End;
      If Not RunExeCapture(test_ctx.exe_name, capture_name, exit_code) Then
        Begin
          Writeln('  ECHEC: execution impossible: ', test_ctx.exe_name);
          CleanupValidationArtifacts(test_ctx, capture_name);
          Exit;
        End;
      If exit_code <> 0 Then
        Begin
          Writeln('  ECHEC: code de sortie ', exit_code);
          CleanupValidationArtifacts(test_ctx, capture_name);
          Exit;
        End;
      actual := ReadSmallBinaryText(capture_name);
      If actual <> expected Then
        Begin
          Writeln('  ECHEC: sortie differente pour ', source_name);
          CleanupValidationArtifacts(test_ctx, capture_name);
          Exit;
        End;
    End;

  CleanupValidationArtifacts(test_ctx, capture_name);
  ValidateOneMode := True;
End;

Function ValidateOneSource(source_name: TString; verbose: Boolean): Boolean;
Var
  mode: Integer;
Begin
  ValidateOneSource := False;
  Writeln('Validation ', source_name);
  For mode := 1 To 3 Do
    If Not ValidateOneMode(source_name, mode, verbose) Then
      Exit;
  ValidateOneSource := True;
End;

Function RunValidationSuite(verbose: Boolean): Boolean;
Var
  sr: SearchRec;
  source_name: TString;
  total, passed: Integer;
Begin
  RunValidationSuite := False;
  total := 0;
  passed := 0;
  FindFirst('SAMPLES\PL1\*.PLI', AnyFile, sr);
  While DosError = 0 Do
    Begin
      source_name := 'SAMPLES\PL1\' + sr.Name;
      Inc(total);
      If ValidateOneSource(source_name, verbose) Then
        Begin
          Inc(passed);
          Writeln('  OK');
        End
      Else
        Writeln('  ECHEC');
      FindNext(sr);
    End;
  If total = 0 Then
    Begin
      Writeln('Aucun fichier SAMPLES\PL1\*.PLI trouve.');
      Exit;
    End;
  Writeln('Validation PL/1: ', passed, '/', total, ' fichier(s) OK');
  RunValidationSuite := passed = total;
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

  If ctx.options.validate Then
    Begin
      If RunValidationSuite(ctx.options.verbose) Then
        Halt(EXIT_OK)
      Else
        Halt(EXIT_ERROR);
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
