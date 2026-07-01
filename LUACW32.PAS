{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Lua vers assembleur 80386, 32 bits, pour Windows 32 bits.

  TODO - feuille de route LUACW32.PAS
  01. [IMPLEMENTE] Definir le pipeline canonique .LUA -> tokens -> AST/IR Lua -> ASM 80386 -> OBJ COFF -> EXE PE32, avec .EXE Windows produit par defaut.
  02. [IMPLEMENTE] Ajouter le parsing des options de ligne de commande : mode EXE par defaut, mode OBJ seul, emission ASM seulement si un parametre explicite le demande, noms de sortie et mode verbose.
  03. [IMPLEMENTE] Implementer le chargeur source Lua : chemins relatifs Windows, normalisation CR/LF, suivi ligne/colonne, diagnostics avec caret, et conservation des chaines brutes.
  04. [IMPLEMENTE] Construire le lexer Lua complet : identifiants, mots-cles, nombres entiers/flottants, chaines courtes, chaines longues, commentaires courts/longs, operateurs et ponctuation.
  05. [IMPLEMENTE] Supporter la grammaire des chunks/blocs Lua : listes d'instructions, separateurs optionnels, portee lexicale, blocs imbriques et fin de fichier propre.
  06. [IMPLEMENTE] Parser les expressions Lua avec precedences exactes : or, and, comparaisons, concatenation, + - * / // %, unaire, puissance, longueur, parenthesage et associativite.
  07. [IMPLEMENTE] Implementer le modele de valeurs runtime : nil, booleen, nombre, chaine, table, fonction, closure, coroutine, avec representation 32 bits coherente.
  08. [IMPLEMENTE] Ajouter la table des symboles et des scopes : global, local, upvalue, parametre, vararg, labels internes, resolution des noms et duree de vie.
  09. [IMPLEMENTE] Generer le code 80386 pour les variables locales/globales : chargement, stockage, initialisation a nil, affectations multiples et permutations sans ecrasement.
  10. [IMPLEMENTE] Implementer les constantes et le pool de donnees : chaines, nombres flottants, tables de metadonnees, symboles importes et alignement COFF/PE.
  11. Generer les expressions numeriques et booleennes : operations arithmetiques, comparaisons, conversions truthy/falsy Lua et court-circuit de and/or.
  12. Implementer les chaines : allocation/stockage, concatenation, longueur, comparaison, echappements, impression et compatibilite avec SAMPLES\LUA\strings.lua et test_strings.lua.
  13. Implementer les tables Lua : constructeur de table, champs array/hash, indexation [], acces point, affectation, iteration, metatables de base et support de SAMPLES\LUA\tables.lua.
  14. Generer les structures de controle : if/elseif/else/end, while, repeat/until, for numerique, for generique, break, labels internes et sauts 80386 fiables.
  15. Implementer les fonctions : declarations locales/globales, appels, pile d'arguments, retour simple/multiple, varargs, tail calls simples et conventions d'appel internes.
  16. Ajouter les closures et upvalues : capture de variables, cellules partagees, duree de vie apres retour, appels de fonctions imbriquees et SAMPLES\LUA\closures.lua.
  17. Supporter les retours multiples Lua : propagation dans appels, affectations, return, appels imbriques et compatibilite avec test_multiret.lua.
  18. Implementer les built-ins/runtime essentiels : print, tostring, tonumber, type, assert, error, pcall, pairs, ipairs, next, select et fonctions math/string/table requises par les exemples.
  19. Ajouter la gestion d'erreurs Lua : erreurs runtime, pcall, propagation, messages lisibles, nettoyage de pile et support de errors.lua/test_errorhandling.lua.
  20. Implementer les coroutines minimales : create, resume, yield, status, wrapping de pile/contexte et compatibilite avec test_coroutines.lua.
  21. Construire le generateur ASM 80386 optionnel : syntaxe assembleur Windows 32 bits, sections .text/.data/.rdata, labels stables, commentaires utiles et emission seulement sur demande.
  22. Construire le generateur OBJ COFF : sections, relocations, symboles externes, imports runtime, compatibilite avec le linker interne et production OBJ seule si demandee.
  23. Construire le linker PE32 interne : entetes PE, sections alignees, table d'import kernel32/msvcrt ou runtime propre, point d'entree, sortie console et suppression des EXE perimes.
  24. Ajouter le harnais de validation : option -test, compilation de tous SAMPLES\LUA\*, execution/capture des sorties, comparaison stable, modes EXE/OBJ/ASM+OBJ et nettoyage des artefacts.
  25. Stabiliser la compatibilite Free Pascal/Turbo Pascal : types bornes, buffers, absence de dependances modernes, tests de regression, diagnostics finaux et documentation d'utilisation.
}
Program LUACW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

Uses Dos;

{ ============================================================
  TODO 1 - PIPELINE CANONIQUE
  ============================================================ }

Const
  LUACW32_VERSION = '1.0';
  LUACW32_DATE    = '2026';
  MAX_PATH_LEN    = 255;
  MAX_LINE_LEN    = 255;
  MAX_SOURCE_LINES = 12000;
  MAX_SOURCE_CHARS = 60000;
  MAX_ERRORS      = 40;
  MAX_TOKENS      = 12000;
  MAX_BLOCKS      = 1024;
  MAX_STATEMENTS  = 4096;
  MAX_EXPRESSIONS = 8192;
  MAX_RUNTIME_VALUES = 8192;
  MAX_RUNTIME_OBJECTS = 4096;
  MAX_SCOPES      = 1024;
  MAX_SYMBOLS     = 4096;
  MAX_LABELS      = 1024;
  MAX_VARIABLES   = 4096;
  MAX_VAR_OPS     = 12000;
  MAX_CONSTANTS   = 8192;
  MAX_IMPORTS     = 256;
  COFF_ALIGN_RDATA = 4;
  COFF_ALIGN_DATA  = 4;
  COFF_ALIGN_BSS   = 4;
  LUA_VALUE_TAG_BITS = 4;
  LUA_VALUE_TAG_MASK = 15;
  LUA_VALUE_PAYLOAD_SHIFT = 4;
  LUA_VALUE_NULL_PAYLOAD = 0;
  EXIT_OK         = 0;
  EXIT_ERROR      = 1;
  EXIT_USAGE      = 2;
  EXT_LUA         = '.LUA';
  EXT_ASM         = '.asm';
  EXT_OBJ         = '.obj';
  EXT_EXE         = '.exe';

Type
  TString = String[MAX_PATH_LEN];
  TSourceLine = String[MAX_LINE_LEN];
  TTokenText = String[80];

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
    AK_SOURCE_LUA,
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

  TSourceInfo = Record
    loaded       : Boolean;
    line_count   : LongInt;
    char_count   : LongInt;
    max_line_len : Integer;
    cur_line     : LongInt;
    cur_col      : Integer;
    lines        : Array[1..MAX_SOURCE_LINES] Of TSourceLine;
  End;

  TTokenKind = (
    TK_EOF,
    TK_IDENT,
    TK_KEYWORD,
    TK_NUMBER,
    TK_STRING,
    TK_OPERATOR,
    TK_PUNCT
  );

  TToken = Record
    kind    : TTokenKind;
    text    : TTokenText;
    line    : LongInt;
    col     : Integer;
  End;

  TTokenTable = Array[1..MAX_TOKENS] Of TToken;

  TLexInfo = Record
    token_count   : LongInt;
    ident_count   : LongInt;
    keyword_count : LongInt;
    number_count  : LongInt;
    string_count  : LongInt;
    operator_count: LongInt;
    punct_count   : LongInt;
    comment_count : LongInt;
    tokens        : TTokenTable;
    eof_token     : TToken;
  End;

  TBlockKind = (
    BK_CHUNK,
    BK_DO,
    BK_FUNCTION,
    BK_IF,
    BK_WHILE,
    BK_REPEAT,
    BK_FOR
  );

  TStatementKind = (
    SK_EMPTY,
    SK_ASSIGN_OR_CALL,
    SK_LOCAL,
    SK_FUNCTION,
    SK_DO,
    SK_IF,
    SK_WHILE,
    SK_REPEAT,
    SK_FOR,
    SK_BREAK,
    SK_GOTO,
    SK_RETURN
  );

  TBlockInfo = Record
    kind        : TBlockKind;
    first_token : LongInt;
    last_token  : LongInt;
    depth       : Integer;
    line        : LongInt;
  End;

  TStatementInfo = Record
    kind        : TStatementKind;
    first_token : LongInt;
    last_token  : LongInt;
    depth       : Integer;
    line        : LongInt;
  End;

  TExprKind = (
    EK_UNKNOWN,
    EK_NIL,
    EK_BOOL,
    EK_NUMBER,
    EK_STRING,
    EK_VAR,
    EK_VARARG,
    EK_TABLE,
    EK_FUNCTION,
    EK_CALL,
    EK_INDEX,
    EK_UNARY,
    EK_BINARY
  );

  TExprInfo = Record
    kind        : TExprKind;
    first_token : LongInt;
    last_token  : LongInt;
    depth       : Integer;
    line        : LongInt;
  End;

  TLuaValueKind = (
    LVK_UNKNOWN,
    LVK_NIL,
    LVK_FALSE,
    LVK_TRUE,
    LVK_NUMBER,
    LVK_STRING,
    LVK_TABLE,
    LVK_FUNCTION,
    LVK_CLOSURE,
    LVK_COROUTINE
  );

  TLuaObjectKind = (
    LOK_NONE,
    LOK_NUMBER,
    LOK_STRING,
    LOK_TABLE,
    LOK_FUNCTION,
    LOK_CLOSURE,
    LOK_COROUTINE
  );

  TLuaValueWord = LongInt;

  TLuaObjectHeader = Record
    kind      : TLuaObjectKind;
    flags     : Word;
    ref_count : LongInt;
    size      : LongInt;
  End;

  TLuaObjectInfo = Record
    header      : TLuaObjectHeader;
    handle      : LongInt;
    first_token : LongInt;
    line        : LongInt;
  End;

  TLuaValueInfo = Record
    kind        : TLuaValueKind;
    word        : TLuaValueWord;
    object_id   : LongInt;
    first_token : LongInt;
    last_token  : LongInt;
    line        : LongInt;
  End;

  TRuntimeInfo = Record
    value_count     : LongInt;
    object_count    : LongInt;
    nil_count       : LongInt;
    false_count     : LongInt;
    true_count      : LongInt;
    number_count    : LongInt;
    string_count    : LongInt;
    table_count     : LongInt;
    function_count  : LongInt;
    closure_count   : LongInt;
    coroutine_count : LongInt;
    max_handle      : LongInt;
    values          : Array[1..MAX_RUNTIME_VALUES] Of TLuaValueInfo;
    objects         : Array[1..MAX_RUNTIME_OBJECTS] Of TLuaObjectInfo;
  End;

  TScopeKind = (
    SCK_GLOBAL,
    SCK_BLOCK,
    SCK_FUNCTION,
    SCK_LOOP
  );

  TSymbolKind = (
    SYK_GLOBAL,
    SYK_LOCAL,
    SYK_PARAM,
    SYK_VARARG,
    SYK_FUNCTION,
    SYK_UPVALUE,
    SYK_BUILTIN
  );

  TLabelKind = (
    LBK_LABEL,
    LBK_GOTO
  );

  TScopeInfo = Record
    kind           : TScopeKind;
    parent         : LongInt;
    first_token    : LongInt;
    last_token     : LongInt;
    depth          : Integer;
    function_depth : Integer;
    symbol_count   : LongInt;
  End;

  TSymbolInfo = Record
    name           : TTokenText;
    kind           : TSymbolKind;
    scope_id       : LongInt;
    decl_token     : LongInt;
    first_use      : LongInt;
    last_use       : LongInt;
    use_count      : LongInt;
    assigned       : Boolean;
    captured       : Boolean;
    line           : LongInt;
  End;

  TLabelInfo = Record
    name       : TTokenText;
    kind       : TLabelKind;
    scope_id   : LongInt;
    token      : LongInt;
    line       : LongInt;
    resolved   : Boolean;
  End;

  TSemanticInfo = Record
    scope_count        : LongInt;
    symbol_count       : LongInt;
    label_count        : LongInt;
    global_count       : LongInt;
    local_count        : LongInt;
    param_count        : LongInt;
    vararg_count       : LongInt;
    upvalue_count      : LongInt;
    builtin_count      : LongInt;
    function_sym_count : LongInt;
    unresolved_gotos   : LongInt;
    scopes             : Array[1..MAX_SCOPES] Of TScopeInfo;
    symbols            : Array[1..MAX_SYMBOLS] Of TSymbolInfo;
    labels             : Array[1..MAX_LABELS] Of TLabelInfo;
  End;

  TVarStorageKind = (
    VSK_NONE,
    VSK_GLOBAL,
    VSK_LOCAL,
    VSK_PARAM,
    VSK_UPVALUE
  );

  TVarOpKind = (
    VOP_INIT_NIL,
    VOP_LOAD,
    VOP_STORE,
    VOP_MULTI_ASSIGN
  );

  TVariableInfo = Record
    symbol_id    : LongInt;
    storage      : TVarStorageKind;
    scope_id     : LongInt;
    stack_offset : LongInt;
    global_index : LongInt;
    upvalue_index: LongInt;
    first_token  : LongInt;
    line         : LongInt;
  End;

  TVarOpInfo = Record
    kind        : TVarOpKind;
    variable_id : LongInt;
    token       : LongInt;
    aux         : LongInt;
    line        : LongInt;
  End;

  TCodegenInfo = Record
    variable_count     : LongInt;
    varop_count        : LongInt;
    global_slot_count  : LongInt;
    local_slot_count   : LongInt;
    param_slot_count   : LongInt;
    upvalue_slot_count : LongInt;
    nil_init_count     : LongInt;
    load_count         : LongInt;
    store_count        : LongInt;
    multi_assign_count : LongInt;
    permute_temp_count : LongInt;
    variables          : Array[1..MAX_VARIABLES] Of TVariableInfo;
    varops             : Array[1..MAX_VAR_OPS] Of TVarOpInfo;
  End;

  TConstKind = (
    CPK_NIL,
    CPK_BOOL,
    CPK_NUMBER,
    CPK_STRING,
    CPK_TABLE_META,
    CPK_FUNCTION_META,
    CPK_SYMBOL_NAME
  );

  TDataSectionKind = (
    DSK_RDATA,
    DSK_DATA,
    DSK_BSS
  );

  TConstInfo = Record
    kind        : TConstKind;
    text        : TTokenText;
    section     : TDataSectionKind;
    offset      : LongInt;
    size        : LongInt;
    align       : Integer;
    token       : LongInt;
    line        : LongInt;
  End;

  TImportInfo = Record
    module_name : TTokenText;
    symbol_name : TTokenText;
    thunk_name  : TTokenText;
    index       : LongInt;
  End;

  TDataPoolInfo = Record
    constant_count      : LongInt;
    import_count        : LongInt;
    number_count        : LongInt;
    string_count        : LongInt;
    table_meta_count    : LongInt;
    function_meta_count : LongInt;
    symbol_name_count   : LongInt;
    rdata_size          : LongInt;
    data_size           : LongInt;
    bss_size            : LongInt;
    rdata_align         : Integer;
    data_align          : Integer;
    bss_align           : Integer;
    constants           : Array[1..MAX_CONSTANTS] Of TConstInfo;
    imports             : Array[1..MAX_IMPORTS] Of TImportInfo;
  End;

  TParseInfo = Record
    block_count      : LongInt;
    statement_count  : LongInt;
    max_block_depth  : Integer;
    if_count         : LongInt;
    elseif_count     : LongInt;
    else_count       : LongInt;
    while_count      : LongInt;
    repeat_count     : LongInt;
    for_count        : LongInt;
    function_count   : LongInt;
    local_count      : LongInt;
    return_count     : LongInt;
    break_count      : LongInt;
    goto_count       : LongInt;
    expr_count       : LongInt;
    expr_error_count : LongInt;
    expr_max_depth   : Integer;
    unary_expr_count : LongInt;
    binary_expr_count: LongInt;
    call_expr_count  : LongInt;
    table_expr_count : LongInt;
    parse_error_count: LongInt;
    blocks           : Array[1..MAX_BLOCKS] Of TBlockInfo;
    statements       : Array[1..MAX_STATEMENTS] Of TStatementInfo;
    expressions      : Array[1..MAX_EXPRESSIONS] Of TExprInfo;
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
    runtime     : TRuntimeInfo;
    sema        : TSemanticInfo;
    codegen     : TCodegenInfo;
    datapool    : TDataPoolInfo;
    stage       : TCompileStage;
    last_art    : TArtifactKind;
    errors      : Integer;
    warnings    : Integer;
  End;

Function StageName(stage: TCompileStage): TString;
Begin
  Case stage Of
    CS_LOAD_SOURCE: StageName := 'source';
    CS_LEX_TOKENS:  StageName := 'tokens';
    CS_PARSE_AST:   StageName := 'ast-ir-lua';
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
    AK_SOURCE_LUA:   ArtifactName := 'source-lua';
    AK_TOKEN_STREAM: ArtifactName := 'token-stream';
    AK_AST_IR:       ArtifactName := 'ast-ir-lua';
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

Function UpperStr(s: TString): TString;
Var
  i: Integer;
Begin
  For i := 1 To Length(s) Do
    s[i] := UpCase(s[i]);
  UpperStr := s;
End;

Function IsOption(s: TString; opt: TString): Boolean;
Begin
  IsOption := UpperStr(s) = UpperStr(opt);
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

Function SourceLineAt(Var ctx: TCompilerContext; line_no: LongInt): TSourceLine;
Begin
  If (line_no >= 1) And (line_no <= ctx.source.line_count) Then
    SourceLineAt := ctx.source.lines[line_no]
  Else
    SourceLineAt := '';
End;

Procedure SourceErrorAt(Var ctx: TCompilerContext; line_no: LongInt;
                        col_no: Integer; msg: TString);
Var
  line_text: TSourceLine;
  i: Integer;
Begin
  Inc(ctx.errors);
  Writeln(ctx.source_name, '(', line_no, ',', col_no, '): error: ', msg);
  line_text := SourceLineAt(ctx, line_no);
  If line_text <> '' Then
    Begin
      Writeln(' ', line_text);
      Write(' ');
      If col_no < 1 Then
        col_no := 1;
      If col_no > Length(line_text) + 1 Then
        col_no := Length(line_text) + 1;
      For i := 1 To col_no - 1 Do
        Write(' ');
      Writeln('^');
    End;
End;

Procedure PipelineError(Var ctx: TCompilerContext; msg: TString);
Begin
  Inc(ctx.errors);
  Writeln('LUACW32: ', msg);
End;

Function TokenKindName(kind: TTokenKind): TString;
Begin
  Case kind Of
    TK_EOF:      TokenKindName := 'EOF';
    TK_IDENT:    TokenKindName := 'IDENT';
    TK_KEYWORD:  TokenKindName := 'KEYWORD';
    TK_NUMBER:   TokenKindName := 'NUMBER';
    TK_STRING:   TokenKindName := 'STRING';
    TK_OPERATOR: TokenKindName := 'OPERATOR';
    TK_PUNCT:    TokenKindName := 'PUNCT';
  Else
    TokenKindName := 'UNKNOWN';
  End;
End;

Function BlockKindName(kind: TBlockKind): TString;
Begin
  Case kind Of
    BK_CHUNK:    BlockKindName := 'chunk';
    BK_DO:       BlockKindName := 'do';
    BK_FUNCTION: BlockKindName := 'function';
    BK_IF:       BlockKindName := 'if';
    BK_WHILE:    BlockKindName := 'while';
    BK_REPEAT:   BlockKindName := 'repeat';
    BK_FOR:      BlockKindName := 'for';
  Else
    BlockKindName := 'unknown';
  End;
End;

Function StatementKindName(kind: TStatementKind): TString;
Begin
  Case kind Of
    SK_EMPTY:          StatementKindName := 'empty';
    SK_ASSIGN_OR_CALL: StatementKindName := 'assign/call';
    SK_LOCAL:          StatementKindName := 'local';
    SK_FUNCTION:       StatementKindName := 'function';
    SK_DO:             StatementKindName := 'do';
    SK_IF:             StatementKindName := 'if';
    SK_WHILE:          StatementKindName := 'while';
    SK_REPEAT:         StatementKindName := 'repeat';
    SK_FOR:            StatementKindName := 'for';
    SK_BREAK:          StatementKindName := 'break';
    SK_GOTO:           StatementKindName := 'goto';
    SK_RETURN:         StatementKindName := 'return';
  Else
    StatementKindName := 'unknown';
  End;
End;

Function LuaValueKindName(kind: TLuaValueKind): TString;
Begin
  Case kind Of
    LVK_UNKNOWN:   LuaValueKindName := 'unknown';
    LVK_NIL:       LuaValueKindName := 'nil';
    LVK_FALSE:     LuaValueKindName := 'false';
    LVK_TRUE:      LuaValueKindName := 'true';
    LVK_NUMBER:    LuaValueKindName := 'number';
    LVK_STRING:    LuaValueKindName := 'string';
    LVK_TABLE:     LuaValueKindName := 'table';
    LVK_FUNCTION:  LuaValueKindName := 'function';
    LVK_CLOSURE:   LuaValueKindName := 'closure';
    LVK_COROUTINE: LuaValueKindName := 'coroutine';
  Else
    LuaValueKindName := 'unknown';
  End;
End;

Function LuaObjectKindName(kind: TLuaObjectKind): TString;
Begin
  Case kind Of
    LOK_NONE:      LuaObjectKindName := 'none';
    LOK_NUMBER:    LuaObjectKindName := 'number';
    LOK_STRING:    LuaObjectKindName := 'string';
    LOK_TABLE:     LuaObjectKindName := 'table';
    LOK_FUNCTION:  LuaObjectKindName := 'function';
    LOK_CLOSURE:   LuaObjectKindName := 'closure';
    LOK_COROUTINE: LuaObjectKindName := 'coroutine';
  Else
    LuaObjectKindName := 'unknown';
  End;
End;

Function ScopeKindName(kind: TScopeKind): TString;
Begin
  Case kind Of
    SCK_GLOBAL:   ScopeKindName := 'global';
    SCK_BLOCK:    ScopeKindName := 'block';
    SCK_FUNCTION: ScopeKindName := 'function';
    SCK_LOOP:     ScopeKindName := 'loop';
  Else
    ScopeKindName := 'unknown';
  End;
End;

Function SymbolKindName(kind: TSymbolKind): TString;
Begin
  Case kind Of
    SYK_GLOBAL:   SymbolKindName := 'global';
    SYK_LOCAL:    SymbolKindName := 'local';
    SYK_PARAM:    SymbolKindName := 'param';
    SYK_VARARG:   SymbolKindName := 'vararg';
    SYK_FUNCTION: SymbolKindName := 'function';
    SYK_UPVALUE:  SymbolKindName := 'upvalue';
    SYK_BUILTIN:  SymbolKindName := 'builtin';
  Else
    SymbolKindName := 'unknown';
  End;
End;

Function VarStorageKindName(kind: TVarStorageKind): TString;
Begin
  Case kind Of
    VSK_NONE:   VarStorageKindName := 'none';
    VSK_GLOBAL: VarStorageKindName := 'global';
    VSK_LOCAL:  VarStorageKindName := 'local';
    VSK_PARAM:  VarStorageKindName := 'param';
    VSK_UPVALUE:VarStorageKindName := 'upvalue';
  Else
    VarStorageKindName := 'unknown';
  End;
End;

Function VarOpKindName(kind: TVarOpKind): TString;
Begin
  Case kind Of
    VOP_INIT_NIL:     VarOpKindName := 'init-nil';
    VOP_LOAD:         VarOpKindName := 'load';
    VOP_STORE:        VarOpKindName := 'store';
    VOP_MULTI_ASSIGN: VarOpKindName := 'multi-assign';
  Else
    VarOpKindName := 'unknown';
  End;
End;

Function ConstKindName(kind: TConstKind): TString;
Begin
  Case kind Of
    CPK_NIL:           ConstKindName := 'nil';
    CPK_BOOL:          ConstKindName := 'bool';
    CPK_NUMBER:        ConstKindName := 'number';
    CPK_STRING:        ConstKindName := 'string';
    CPK_TABLE_META:    ConstKindName := 'table-meta';
    CPK_FUNCTION_META: ConstKindName := 'function-meta';
    CPK_SYMBOL_NAME:   ConstKindName := 'symbol-name';
  Else
    ConstKindName := 'unknown';
  End;
End;

Function DataSectionKindName(kind: TDataSectionKind): TString;
Begin
  Case kind Of
    DSK_RDATA: DataSectionKindName := '.rdata';
    DSK_DATA:  DataSectionKindName := '.data';
    DSK_BSS:   DataSectionKindName := '.bss';
  Else
    DataSectionKindName := 'unknown';
  End;
End;

Function TokenTextAt(Var ctx: TCompilerContext; idx: LongInt;
                     text: TString): Boolean;
Begin
  TokenTextAt := (idx >= 1) And (idx <= ctx.lex.token_count) And
                 (UpperStr(ctx.lex.tokens[idx].text) = UpperStr(text));
End;

Function TokenIsKeyword(Var ctx: TCompilerContext; idx: LongInt;
                        text: TString): Boolean;
Begin
  TokenIsKeyword := (idx >= 1) And (idx <= ctx.lex.token_count) And
                    (ctx.lex.tokens[idx].kind = TK_KEYWORD) And
                    TokenTextAt(ctx, idx, text);
End;

Procedure ParseErrorAtToken(Var ctx: TCompilerContext; token_idx: LongInt;
                            msg: TString);
Var
  line_no: LongInt;
  col_no: Integer;
Begin
  Inc(ctx.parse.parse_error_count);
  If (token_idx >= 1) And (token_idx <= ctx.lex.token_count) Then
    Begin
      line_no := ctx.lex.tokens[token_idx].line;
      col_no := ctx.lex.tokens[token_idx].col;
    End
  Else
    Begin
      line_no := ctx.source.line_count;
      col_no := 1;
    End;
  SourceErrorAt(ctx, line_no, col_no, msg);
End;

Function IsAlpha(c: Char): Boolean;
Begin
  IsAlpha := ((c >= 'A') And (c <= 'Z')) Or
             ((c >= 'a') And (c <= 'z')) Or (c = '_');
End;

Function IsDigit(c: Char): Boolean;
Begin
  IsDigit := (c >= '0') And (c <= '9');
End;

Function IsHexDigit(c: Char): Boolean;
Begin
  IsHexDigit := IsDigit(c) Or ((c >= 'A') And (c <= 'F')) Or
                ((c >= 'a') And (c <= 'f'));
End;

Function IsAlphaNum(c: Char): Boolean;
Begin
  IsAlphaNum := IsAlpha(c) Or IsDigit(c);
End;

Function IsSpace(c: Char): Boolean;
Begin
  IsSpace := (c = ' ') Or (c = #9) Or (c = #10) Or
             (c = #13) Or (c = #12);
End;

Function IsLuaKeywordText(s: TTokenText): Boolean;
Var
  u: TString;
Begin
  u := UpperStr(s);
  IsLuaKeywordText :=
    (u = 'AND') Or (u = 'BREAK') Or (u = 'DO') Or (u = 'ELSE') Or
    (u = 'ELSEIF') Or (u = 'END') Or (u = 'FALSE') Or (u = 'FOR') Or
    (u = 'FUNCTION') Or (u = 'GOTO') Or (u = 'IF') Or (u = 'IN') Or
    (u = 'LOCAL') Or (u = 'NIL') Or (u = 'NOT') Or (u = 'OR') Or
    (u = 'REPEAT') Or (u = 'RETURN') Or (u = 'THEN') Or
    (u = 'TRUE') Or (u = 'UNTIL') Or (u = 'WHILE');
End;

Function StageOutputArtifact(stage: TCompileStage): TArtifactKind;
Begin
  Case stage Of
    CS_LOAD_SOURCE: StageOutputArtifact := AK_SOURCE_LUA;
    CS_LEX_TOKENS:  StageOutputArtifact := AK_TOKEN_STREAM;
    CS_PARSE_AST:   StageOutputArtifact := AK_AST_IR;
    CS_EMIT_ASM386: StageOutputArtifact := AK_ASM_386;
    CS_BUILD_OBJ:   StageOutputArtifact := AK_OBJ_COFF;
    CS_LINK_EXE:    StageOutputArtifact := AK_EXE_PE32;
  Else
    StageOutputArtifact := AK_NONE;
  End;
End;

Function PipelineTargetArtifact(Var ctx: TCompilerContext): TArtifactKind;
Begin
  If ctx.options.output_mode = OM_OBJ Then
    PipelineTargetArtifact := AK_OBJ_COFF
  Else
    PipelineTargetArtifact := AK_EXE_PE32;
End;

Procedure InitPipelineDefaults(Var ctx: TCompilerContext);
Begin
  FillChar(ctx, SizeOf(ctx), 0);
  ctx.options.output_mode := OM_EXE;
  ctx.options.emit_asm := False;
  ctx.options.verbose := False;
  ctx.options.show_help := False;
  ctx.options.validate := False;
  ctx.stage := CS_LOAD_SOURCE;
  ctx.last_art := AK_NONE;
  ctx.errors := 0;
  ctx.warnings := 0;
End;

Procedure SetDefaultOutputNames(Var ctx: TCompilerContext);
Var
  base: TString;
Begin
  If ctx.options.output_name <> '' Then
    base := BaseNameNoExt(ctx.options.output_name)
  Else
    base := BaseNameNoExt(ctx.source_name);

  ctx.asm_name := WithExt(base, EXT_ASM);
  ctx.obj_name := WithExt(base, EXT_OBJ);
  ctx.exe_name := WithExt(base, EXT_EXE);
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
      If IsOption(arg, '-h') Or IsOption(arg, '/h') Or
         IsOption(arg, '-?') Or IsOption(arg, '/?') Or
         IsOption(arg, '--help') Then
        ctx.options.show_help := True
      Else If IsOption(arg, '-v') Or IsOption(arg, '/v') Or
              IsOption(arg, '--verbose') Then
        ctx.options.verbose := True
      Else If IsOption(arg, '-obj') Or IsOption(arg, '/obj') Then
        ctx.options.output_mode := OM_OBJ
      Else If IsOption(arg, '-asm') Or IsOption(arg, '/asm') Then
        ctx.options.emit_asm := True
      Else If IsOption(arg, '-test') Or IsOption(arg, '/test') Then
        ctx.options.validate := True
      Else If IsOption(arg, '-o') Or IsOption(arg, '/o') Then
        Begin
          Inc(i);
          If i > ParamCount Then
            Begin
              Writeln('LUACW32: nom de sortie attendu apres ', arg);
              ParseArgs := EXIT_USAGE;
              Exit;
            End;
          ctx.options.output_name := ParamStr(i);
        End
      Else If (Length(arg) > 0) And ((arg[1] = '-') Or (arg[1] = '/')) Then
        Begin
          Writeln('LUACW32: option inconnue: ', arg);
          ParseArgs := EXIT_USAGE;
          Exit;
        End
      Else If ctx.source_name = '' Then
        ctx.source_name := arg
      Else
        Begin
          Writeln('LUACW32: un seul fichier source est accepte pour le moment');
          ParseArgs := EXIT_USAGE;
          Exit;
        End;
      Inc(i);
    End;

  If ctx.options.show_help Then
    Exit;
  If ctx.options.validate Then
    Exit;
  If ctx.source_name = '' Then
    Begin
      Writeln('LUACW32: fichier source .lua manquant');
      ParseArgs := EXIT_USAGE;
      Exit;
    End;
  SetDefaultOutputNames(ctx);
End;

Procedure PrintPipeline;
Begin
  Writeln('LUACW32 ', LUACW32_VERSION, ' - pipeline canonique');
  Writeln('  .LUA -> ', ArtifactName(AK_TOKEN_STREAM),
          ' -> ', ArtifactName(AK_AST_IR),
          ' -> ', ArtifactName(AK_ASM_386),
          ' -> ', ArtifactName(AK_OBJ_COFF),
          ' -> ', ArtifactName(AK_EXE_PE32));
  Writeln('  cible par defaut: ', ArtifactName(AK_EXE_PE32),
          ' (fichier ', EXT_EXE, ' Windows 32 bits)');
End;

Procedure PrintUsage;
Begin
  Writeln('LUACW32 - Cette commande permet de lancer le compilateur Lua vers un executable Windows 32 bits.');
  Writeln;
  Writeln('Syntaxe: luacw32 [options] fichier.lua');
  Writeln;
  Writeln('Options:');
  Writeln('  -obj          produit seulement le fichier ', EXT_OBJ);
  Writeln('  -asm          genere/conserve explicitement le fichier ', EXT_ASM);
  Writeln('  -o nom        base ou nom de sortie');
  Writeln('  -v            mode verbose');
  Writeln('  -h, -?        affiche cette aide');
  Writeln('  -test         reserve pour la validation automatique');
  Writeln;
  Writeln('Par defaut, la cible est un executable Windows ', EXT_EXE, '.');
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

Function LoadSource(Var ctx: TCompilerContext): Boolean;
Var
  f: Text;
  line: String;
  io: Integer;
Begin
  LoadSource := False;
  ctx.source.loaded := False;
  ctx.source.line_count := 0;
  ctx.source.char_count := 0;
  ctx.source.max_line_len := 0;
  ctx.source.cur_line := 1;
  ctx.source.cur_col := 1;

  Assign(f, ctx.source_name);
  Reset(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible d''ouvrir le fichier source: ' +
                         ctx.source_name);
      Exit;
    End;

  While Not Eof(f) Do
    Begin
      ReadLn(f, line);
      io := IOResult;
      If io <> 0 Then
        Begin
          PipelineError(ctx, 'erreur de lecture du fichier source');
          Close(f);
          io := IOResult;
          Exit;
        End;
      If ctx.source.line_count >= MAX_SOURCE_LINES Then
        Begin
          SourceErrorAt(ctx, ctx.source.line_count, 1,
                        'trop de lignes dans le source Lua');
          Close(f);
          io := IOResult;
          Exit;
        End;
      If ctx.source.char_count + Length(line) + 1 > MAX_SOURCE_CHARS Then
        Begin
          SourceErrorAt(ctx, ctx.source.line_count + 1, 1,
                        'source Lua trop volumineux');
          Close(f);
          io := IOResult;
          Exit;
        End;
      Inc(ctx.source.line_count);
      ctx.source.lines[ctx.source.line_count] := line;
      Inc(ctx.source.char_count, Length(line) + 1);
      If Length(line) > ctx.source.max_line_len Then
        ctx.source.max_line_len := Length(line);
    End;

  Close(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'erreur lors de la fermeture du fichier source');
      Exit;
    End;

  ctx.source.loaded := True;
  ctx.source.cur_line := 1;
  ctx.source.cur_col := 1;
  ctx.last_art := AK_SOURCE_LUA;
  If ctx.options.verbose Then
    Writeln('Source chargee: ', ctx.source.line_count, ' lignes, ',
            ctx.source.char_count, ' caracteres, ligne max ',
            ctx.source.max_line_len);
  LoadSource := True;
End;

Function LexSource(Var ctx: TCompilerContext): Boolean;
Var
  line_no: LongInt;
  col_no: Integer;

  Function CurChar: Char;
  Begin
    If line_no > ctx.source.line_count Then
      CurChar := #0
    Else If col_no <= Length(ctx.source.lines[line_no]) Then
      CurChar := ctx.source.lines[line_no][col_no]
    Else
      CurChar := #10;
  End;

  Function PeekChar(offset: Integer): Char;
  Var
    l: LongInt;
    c, n: Integer;
  Begin
    l := line_no;
    c := col_no;
    For n := 1 To offset Do
      Begin
        If l > ctx.source.line_count Then
          Begin
            PeekChar := #0;
            Exit;
          End;
        If c <= Length(ctx.source.lines[l]) Then
          Inc(c)
        Else
          Begin
            Inc(l);
            c := 1;
          End;
      End;
    If l > ctx.source.line_count Then
      PeekChar := #0
    Else If c <= Length(ctx.source.lines[l]) Then
      PeekChar := ctx.source.lines[l][c]
    Else
      PeekChar := #10;
  End;

  Procedure Advance;
  Begin
    If line_no > ctx.source.line_count Then
      Exit;
    If col_no <= Length(ctx.source.lines[line_no]) Then
      Inc(col_no)
    Else
      Begin
        Inc(line_no);
        col_no := 1;
      End;
    ctx.source.cur_line := line_no;
    ctx.source.cur_col := col_no;
  End;

  Procedure AddToken(kind: TTokenKind; text: TTokenText;
                     tok_line: LongInt; tok_col: Integer);
  Begin
    If ctx.lex.token_count >= MAX_TOKENS Then
      Begin
        SourceErrorAt(ctx, tok_line, tok_col, 'trop de tokens Lua');
        Exit;
      End;
    Inc(ctx.lex.token_count);
    ctx.lex.tokens[ctx.lex.token_count].kind := kind;
    ctx.lex.tokens[ctx.lex.token_count].text := text;
    ctx.lex.tokens[ctx.lex.token_count].line := tok_line;
    ctx.lex.tokens[ctx.lex.token_count].col := tok_col;
    Case kind Of
      TK_IDENT:    Inc(ctx.lex.ident_count);
      TK_KEYWORD:  Inc(ctx.lex.keyword_count);
      TK_NUMBER:   Inc(ctx.lex.number_count);
      TK_STRING:   Inc(ctx.lex.string_count);
      TK_OPERATOR: Inc(ctx.lex.operator_count);
      TK_PUNCT:    Inc(ctx.lex.punct_count);
    Else
    End;
  End;

  Function LongBracketEquals: Integer;
  Var
    n: Integer;
  Begin
    LongBracketEquals := -1;
    If CurChar <> '[' Then
      Exit;
    n := 0;
    While PeekChar(n + 1) = '=' Do
      Inc(n);
    If PeekChar(n + 1) = '[' Then
      LongBracketEquals := n;
  End;

  Procedure ConsumeLongBracket(eq_count: Integer; Var text: TTokenText;
                               tok_line: LongInt; tok_col: Integer);
  Var
    close_ok: Boolean;
    i: Integer;
  Begin
    text := '';
    Advance;
    For i := 1 To eq_count Do
      Advance;
    Advance;
    close_ok := False;
    While CurChar <> #0 Do
      Begin
        If CurChar = ']' Then
          Begin
            close_ok := True;
            For i := 1 To eq_count Do
              If PeekChar(i) <> '=' Then
                close_ok := False;
            If close_ok And (PeekChar(eq_count + 1) = ']') Then
              Begin
                Advance;
                For i := 1 To eq_count Do
                  Advance;
                Advance;
                Exit;
              End;
          End;
        If (CurChar <> #10) And (Length(text) < SizeOf(TTokenText) - 1) Then
          text := text + CurChar;
        Advance;
      End;
    SourceErrorAt(ctx, tok_line, tok_col, 'chaine longue Lua non terminee');
  End;

  Procedure SkipLongComment(eq_count: Integer; tok_line: LongInt;
                            tok_col: Integer);
  Var
    dummy: TTokenText;
  Begin
    ConsumeLongBracket(eq_count, dummy, tok_line, tok_col);
  End;

  Procedure LexIdentifier;
  Var
    text: TTokenText;
    tok_line: LongInt;
    tok_col: Integer;
  Begin
    text := '';
    tok_line := line_no;
    tok_col := col_no;
    While IsAlphaNum(CurChar) Do
      Begin
        If Length(text) < SizeOf(TTokenText) - 1 Then
          text := text + CurChar;
        Advance;
      End;
    If IsLuaKeywordText(text) Then
      AddToken(TK_KEYWORD, text, tok_line, tok_col)
    Else
      AddToken(TK_IDENT, text, tok_line, tok_col);
  End;

  Procedure LexNumber;
  Var
    text: TTokenText;
    tok_line: LongInt;
    tok_col: Integer;
    c: Char;
  Begin
    text := '';
    tok_line := line_no;
    tok_col := col_no;
    While True Do
      Begin
        c := CurChar;
        If (c = #0) Or (c = #10) Then
          Break;
        If (c = '.') And (PeekChar(1) = '.') Then
          Break;
        If IsAlphaNum(c) Or (c = '.') Or (c = '+') Or (c = '-') Then
          Begin
            If Length(text) < SizeOf(TTokenText) - 1 Then
              text := text + c;
            Advance;
          End
        Else
          Break;
      End;
    AddToken(TK_NUMBER, text, tok_line, tok_col);
  End;

  Procedure LexShortString(quote: Char);
  Var
    text: TTokenText;
    tok_line: LongInt;
    tok_col: Integer;
    escaped: Boolean;
  Begin
    text := '';
    tok_line := line_no;
    tok_col := col_no;
    escaped := False;
    Advance;
    While CurChar <> #0 Do
      Begin
        If (CurChar = #10) And (Not escaped) Then
          Begin
            SourceErrorAt(ctx, tok_line, tok_col, 'chaine Lua non terminee');
            Exit;
          End;
        If escaped Then
          Begin
            If Length(text) < SizeOf(TTokenText) - 1 Then
              text := text + CurChar;
            escaped := False;
            Advance;
          End
        Else If CurChar = '\' Then
          Begin
            escaped := True;
            Advance;
          End
        Else If CurChar = quote Then
          Begin
            Advance;
            AddToken(TK_STRING, text, tok_line, tok_col);
            Exit;
          End
        Else
          Begin
            If Length(text) < SizeOf(TTokenText) - 1 Then
              text := text + CurChar;
            Advance;
          End;
      End;
    SourceErrorAt(ctx, tok_line, tok_col, 'chaine Lua non terminee');
  End;

  Procedure LexOperatorOrPunct;
  Var
    tok_line: LongInt;
    tok_col: Integer;
    c, n1, n2: Char;
    text: TTokenText;
    kind: TTokenKind;
  Begin
    tok_line := line_no;
    tok_col := col_no;
    c := CurChar;
    n1 := PeekChar(1);
    n2 := PeekChar(2);
    text := c;
    kind := TK_OPERATOR;
    If (c = '.') And (n1 = '.') And (n2 = '.') Then
      Begin text := '...'; Advance; Advance; Advance; End
    Else If ((c = '=') And (n1 = '=')) Or
            ((c = '~') And (n1 = '=')) Or
            ((c = '<') And ((n1 = '=') Or (n1 = '<'))) Or
            ((c = '>') And ((n1 = '=') Or (n1 = '>'))) Or
            ((c = '/') And (n1 = '/')) Or
            ((c = '.') And (n1 = '.')) Or
            ((c = ':') And (n1 = ':')) Then
      Begin text := c + n1; Advance; Advance; End
    Else
      Begin
        If (c = '(') Or (c = ')') Or (c = '{') Or (c = '}') Or
           (c = '[') Or (c = ']') Or (c = ';') Or (c = ',') Or
           (c = ':') Then
          kind := TK_PUNCT
        Else If c = '.' Then
          kind := TK_PUNCT;
        Advance;
      End;
    AddToken(kind, text, tok_line, tok_col);
  End;

Var
  c: Char;
  tok_line: LongInt;
  tok_col, eq_count: Integer;
  text: TTokenText;
Begin
  LexSource := False;
  FillChar(ctx.lex, SizeOf(ctx.lex), 0);
  If Not ctx.source.loaded Then
    Begin
      PipelineError(ctx, 'source non charge avant lexing');
      Exit;
    End;
  line_no := 1;
  col_no := 1;
  While CurChar <> #0 Do
    Begin
      c := CurChar;
      If IsSpace(c) Then
        Advance
      Else If IsAlpha(c) Then
        LexIdentifier
      Else If IsDigit(c) Or ((c = '.') And IsDigit(PeekChar(1))) Then
        LexNumber
      Else If (c = '''') Or (c = '"') Then
        LexShortString(c)
      Else If (c = '-') And (PeekChar(1) = '-') Then
        Begin
          tok_line := line_no;
          tok_col := col_no;
          Advance;
          Advance;
          If CurChar = '[' Then
            Begin
              eq_count := LongBracketEquals;
              If eq_count >= 0 Then
                SkipLongComment(eq_count, tok_line, tok_col)
              Else
                While (CurChar <> #0) And (CurChar <> #10) Do
                  Advance;
            End
          Else
            While (CurChar <> #0) And (CurChar <> #10) Do
              Advance;
          Inc(ctx.lex.comment_count);
        End
      Else If c = '[' Then
        Begin
          tok_line := line_no;
          tok_col := col_no;
          eq_count := LongBracketEquals;
          If eq_count >= 0 Then
            Begin
              ConsumeLongBracket(eq_count, text, tok_line, tok_col);
              AddToken(TK_STRING, text, tok_line, tok_col);
            End
          Else
            LexOperatorOrPunct;
        End
      Else
        LexOperatorOrPunct;
      If ctx.errors >= MAX_ERRORS Then
        Begin
          PipelineError(ctx, 'trop d''erreurs, arret du lexer');
          Exit;
        End;
    End;
  ctx.lex.eof_token.kind := TK_EOF;
  ctx.lex.eof_token.text := '';
  ctx.lex.eof_token.line := line_no;
  ctx.lex.eof_token.col := col_no;
  AddToken(TK_EOF, '', line_no, col_no);
  ctx.last_art := AK_TOKEN_STREAM;
  If ctx.options.verbose Then
    Writeln('Tokens : ', ctx.lex.token_count,
            ' (mots-cles=', ctx.lex.keyword_count,
            ', ident=', ctx.lex.ident_count,
            ', nombres=', ctx.lex.number_count,
            ', chaines=', ctx.lex.string_count,
            ', ops=', ctx.lex.operator_count,
            ', ponct=', ctx.lex.punct_count,
            ', commentaires=', ctx.lex.comment_count, ')');
  LexSource := ctx.errors = 0;
End;

Function ParseAst(Var ctx: TCompilerContext): Boolean;

  Procedure AddBlock(kind: TBlockKind; first_token, last_token: LongInt;
                     depth: Integer);
  Begin
    If ctx.parse.block_count >= MAX_BLOCKS Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop de blocs Lua');
        Exit;
      End;
    Inc(ctx.parse.block_count);
    ctx.parse.blocks[ctx.parse.block_count].kind := kind;
    ctx.parse.blocks[ctx.parse.block_count].first_token := first_token;
    ctx.parse.blocks[ctx.parse.block_count].last_token := last_token;
    ctx.parse.blocks[ctx.parse.block_count].depth := depth;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.parse.blocks[ctx.parse.block_count].line :=
        ctx.lex.tokens[first_token].line
    Else
      ctx.parse.blocks[ctx.parse.block_count].line := 1;
    If depth > ctx.parse.max_block_depth Then
      ctx.parse.max_block_depth := depth;
  End;

  Procedure AddStatement(kind: TStatementKind; first_token, last_token: LongInt;
                         depth: Integer);
  Begin
    If ctx.parse.statement_count >= MAX_STATEMENTS Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop d''instructions Lua');
        Exit;
      End;
    Inc(ctx.parse.statement_count);
    ctx.parse.statements[ctx.parse.statement_count].kind := kind;
    ctx.parse.statements[ctx.parse.statement_count].first_token := first_token;
    ctx.parse.statements[ctx.parse.statement_count].last_token := last_token;
    ctx.parse.statements[ctx.parse.statement_count].depth := depth;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.parse.statements[ctx.parse.statement_count].line :=
        ctx.lex.tokens[first_token].line
    Else
      ctx.parse.statements[ctx.parse.statement_count].line := 1;
    Case kind Of
      SK_LOCAL:    Inc(ctx.parse.local_count);
      SK_FUNCTION: Inc(ctx.parse.function_count);
      SK_DO:       ;
      SK_IF:       Inc(ctx.parse.if_count);
      SK_WHILE:    Inc(ctx.parse.while_count);
      SK_REPEAT:   Inc(ctx.parse.repeat_count);
      SK_FOR:      Inc(ctx.parse.for_count);
      SK_BREAK:    Inc(ctx.parse.break_count);
      SK_GOTO:     Inc(ctx.parse.goto_count);
      SK_RETURN:   Inc(ctx.parse.return_count);
    Else
    End;
  End;

  Procedure AddExpression(kind: TExprKind; first_token, last_token: LongInt;
                          depth: Integer);
  Begin
    If first_token <= 0 Then
      Exit;
    If ctx.parse.expr_count >= MAX_EXPRESSIONS Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop d''expressions Lua');
        Exit;
      End;
    Inc(ctx.parse.expr_count);
    ctx.parse.expressions[ctx.parse.expr_count].kind := kind;
    ctx.parse.expressions[ctx.parse.expr_count].first_token := first_token;
    ctx.parse.expressions[ctx.parse.expr_count].last_token := last_token;
    ctx.parse.expressions[ctx.parse.expr_count].depth := depth;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.parse.expressions[ctx.parse.expr_count].line :=
        ctx.lex.tokens[first_token].line
    Else
      ctx.parse.expressions[ctx.parse.expr_count].line := 1;
    If depth > ctx.parse.expr_max_depth Then
      ctx.parse.expr_max_depth := depth;
    Case kind Of
      EK_UNARY:  Inc(ctx.parse.unary_expr_count);
      EK_BINARY: Inc(ctx.parse.binary_expr_count);
      EK_CALL:   Inc(ctx.parse.call_expr_count);
      EK_TABLE:  Inc(ctx.parse.table_expr_count);
    Else
    End;
  End;

  Function IsCompareOperator(pos: LongInt): Boolean;
  Begin
    IsCompareOperator :=
      (pos >= 1) And (pos <= ctx.lex.token_count) And
      (ctx.lex.tokens[pos].kind = TK_OPERATOR) And
      (TokenTextAt(ctx, pos, '<') Or TokenTextAt(ctx, pos, '>') Or
       TokenTextAt(ctx, pos, '<=') Or TokenTextAt(ctx, pos, '>=') Or
       TokenTextAt(ctx, pos, '~=') Or TokenTextAt(ctx, pos, '=='));
  End;

  Function IsUnaryOperator(pos: LongInt): Boolean;
  Begin
    IsUnaryOperator :=
      TokenIsKeyword(ctx, pos, 'not') Or
      ((pos >= 1) And (pos <= ctx.lex.token_count) And
       (ctx.lex.tokens[pos].kind = TK_OPERATOR) And
       (TokenTextAt(ctx, pos, '#') Or TokenTextAt(ctx, pos, '-') Or
        TokenTextAt(ctx, pos, '~')));
  End;

  Function BinaryOperatorInfo(pos: LongInt; Var prec: Integer;
                              Var right_assoc: Boolean): Boolean;
  Begin
    BinaryOperatorInfo := True;
    right_assoc := False;
    If TokenIsKeyword(ctx, pos, 'or') Then
      prec := 1
    Else If TokenIsKeyword(ctx, pos, 'and') Then
      prec := 2
    Else If IsCompareOperator(pos) Then
      prec := 3
    Else If (ctx.lex.tokens[pos].kind = TK_OPERATOR) And
            TokenTextAt(ctx, pos, '..') Then
      Begin
        prec := 4;
        right_assoc := True;
      End
    Else If (ctx.lex.tokens[pos].kind = TK_OPERATOR) And
            (TokenTextAt(ctx, pos, '+') Or TokenTextAt(ctx, pos, '-')) Then
      prec := 5
    Else If (ctx.lex.tokens[pos].kind = TK_OPERATOR) And
            (TokenTextAt(ctx, pos, '*') Or TokenTextAt(ctx, pos, '/') Or
             TokenTextAt(ctx, pos, '//') Or TokenTextAt(ctx, pos, '%')) Then
      prec := 6
    Else If (ctx.lex.tokens[pos].kind = TK_OPERATOR) And
            TokenTextAt(ctx, pos, '^') Then
      Begin
        prec := 8;
        right_assoc := True;
      End
    Else
      BinaryOperatorInfo := False;
  End;

  Function MatchingClose(open_pos, last_token: LongInt;
                         open_text, close_text: TTokenText): LongInt;
  Var
    p, depth: LongInt;
  Begin
    MatchingClose := 0;
    depth := 0;
    For p := open_pos To last_token Do
      Begin
        If TokenTextAt(ctx, p, open_text) Then
          Inc(depth)
        Else If TokenTextAt(ctx, p, close_text) Then
          Begin
            Dec(depth);
            If depth = 0 Then
              Begin
                MatchingClose := p;
                Exit;
              End;
          End;
      End;
  End;

  Function MatchingFunctionEnd(func_pos, last_token: LongInt): LongInt;
  Var
    p, depth: LongInt;
  Begin
    MatchingFunctionEnd := 0;
    depth := 0;
    p := func_pos;
    While p <= last_token Do
      Begin
        If TokenIsKeyword(ctx, p, 'function') Then
          Inc(depth)
        Else If TokenIsKeyword(ctx, p, 'end') Then
          Begin
            Dec(depth);
            If depth = 0 Then
              Begin
                MatchingFunctionEnd := p;
                Exit;
              End;
          End;
        Inc(p);
      End;
  End;

  Function TopLevelToken(first_token, last_token: LongInt;
                         text: TTokenText): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth, func_depth: LongInt;
  Begin
    TopLevelToken := 0;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    func_depth := 0;
    p := first_token;
    While p <= last_token Do
      Begin
        If TokenIsKeyword(ctx, p, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, p, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If func_depth = 0 Then
          Begin
            If TokenTextAt(ctx, p, '(') Then
              Inc(paren_depth)
            Else If TokenTextAt(ctx, p, ')') And (paren_depth > 0) Then
              Dec(paren_depth)
            Else If TokenTextAt(ctx, p, '{') Then
              Inc(brace_depth)
            Else If TokenTextAt(ctx, p, '}') And (brace_depth > 0) Then
              Dec(brace_depth)
            Else If TokenTextAt(ctx, p, '[') Then
              Inc(bracket_depth)
            Else If TokenTextAt(ctx, p, ']') And (bracket_depth > 0) Then
              Dec(bracket_depth)
            Else If (paren_depth = 0) And (brace_depth = 0) And
                    (bracket_depth = 0) And
                    (ctx.lex.tokens[p].kind <> TK_STRING) And
                    TokenTextAt(ctx, p, text) Then
              Begin
                TopLevelToken := p;
                Exit;
              End;
          End;
        Inc(p);
      End;
  End;

  Function TopLevelKeyword(first_token, last_token: LongInt;
                           keyword: TTokenText): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth, func_depth: LongInt;
  Begin
    TopLevelKeyword := 0;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    func_depth := 0;
    p := first_token;
    While p <= last_token Do
      Begin
        If TokenIsKeyword(ctx, p, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, p, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If func_depth = 0 Then
          Begin
            If TokenTextAt(ctx, p, '(') Then
              Inc(paren_depth)
            Else If TokenTextAt(ctx, p, ')') And (paren_depth > 0) Then
              Dec(paren_depth)
            Else If TokenTextAt(ctx, p, '{') Then
              Inc(brace_depth)
            Else If TokenTextAt(ctx, p, '}') And (brace_depth > 0) Then
              Dec(brace_depth)
            Else If TokenTextAt(ctx, p, '[') Then
              Inc(bracket_depth)
            Else If TokenTextAt(ctx, p, ']') And (bracket_depth > 0) Then
              Dec(bracket_depth)
            Else If (paren_depth = 0) And (brace_depth = 0) And
                    (bracket_depth = 0) And TokenIsKeyword(ctx, p, keyword) Then
              Begin
                TopLevelKeyword := p;
                Exit;
              End;
          End;
        Inc(p);
      End;
  End;

  Function TopLevelAssign(first_token, last_token: LongInt): LongInt;
  Var
    p: LongInt;
  Begin
    TopLevelAssign := 0;
    p := TopLevelToken(first_token, last_token, '=');
    If p <> 0 Then
      TopLevelAssign := p;
  End;

  Function ParseExpression(Var pos: LongInt; min_prec: Integer;
                           last_token: LongInt; depth: Integer): Boolean;
    Forward;

  Procedure ValidateExpressionList(first_token, last_token: LongInt);
    Forward;

  Function ParseFunctionLiteral(Var pos: LongInt; last_token: LongInt;
                                depth: Integer): Boolean;
  Var
    first, end_pos: LongInt;
  Begin
    first := pos;
    end_pos := MatchingFunctionEnd(pos, last_token);
    If end_pos = 0 Then
      Begin
        ParseErrorAtToken(ctx, first, 'end attendu pour expression function');
        Inc(ctx.parse.expr_error_count);
        ParseFunctionLiteral := False;
        Exit;
      End;
    pos := end_pos + 1;
    AddExpression(EK_FUNCTION, first, end_pos, depth);
    ParseFunctionLiteral := True;
  End;

  Function ParseTableConstructor(Var pos: LongInt; last_token: LongInt;
                                 depth: Integer): Boolean;
  Var
    first, close_pos: LongInt;
  Begin
    first := pos;
    close_pos := MatchingClose(pos, last_token, '{', '}');
    If close_pos = 0 Then
      Begin
        ParseErrorAtToken(ctx, first, '} attendu pour constructeur de table');
        Inc(ctx.parse.expr_error_count);
        ParseTableConstructor := False;
        Exit;
      End;
    If close_pos > first + 1 Then
      ValidateExpressionList(first + 1, close_pos - 1);
    pos := close_pos + 1;
    AddExpression(EK_TABLE, first, close_pos, depth);
    ParseTableConstructor := True;
  End;

  Function ParsePrimary(Var pos: LongInt; last_token: LongInt;
                        depth: Integer): Boolean;
  Var
    first, close_pos: LongInt;
    parsed: Boolean;
  Begin
    ParsePrimary := False;
    parsed := False;
    If pos > last_token Then
      Begin
        ParseErrorAtToken(ctx, last_token, 'expression attendue');
        Inc(ctx.parse.expr_error_count);
        Exit;
      End;
    first := pos;
    If ctx.lex.tokens[pos].kind = TK_NUMBER Then
      Begin
        Inc(pos);
        AddExpression(EK_NUMBER, first, first, depth);
        parsed := True;
      End
    Else If ctx.lex.tokens[pos].kind = TK_STRING Then
      Begin
        Inc(pos);
        AddExpression(EK_STRING, first, first, depth);
        parsed := True;
      End
    Else If TokenIsKeyword(ctx, pos, 'nil') Then
      Begin
        Inc(pos);
        AddExpression(EK_NIL, first, first, depth);
        parsed := True;
      End
    Else If TokenIsKeyword(ctx, pos, 'true') Or TokenIsKeyword(ctx, pos, 'false') Then
      Begin
        Inc(pos);
        AddExpression(EK_BOOL, first, first, depth);
        parsed := True;
      End
    Else If TokenTextAt(ctx, pos, '...') Then
      Begin
        Inc(pos);
        AddExpression(EK_VARARG, first, first, depth);
        parsed := True;
      End
    Else If ctx.lex.tokens[pos].kind = TK_IDENT Then
      Begin
        Inc(pos);
        AddExpression(EK_VAR, first, first, depth);
        parsed := True;
      End
    Else If TokenTextAt(ctx, pos, '(') Then
      Begin
        Inc(pos);
        If Not ParseExpression(pos, 1, last_token, depth + 1) Then
          Exit;
        If (pos <= last_token) And TokenTextAt(ctx, pos, ')') Then
          Begin
            Inc(pos);
            parsed := True;
          End
        Else
          Begin
            ParseErrorAtToken(ctx, first, ') attendu dans expression');
            Inc(ctx.parse.expr_error_count);
          End;
      End
    Else If TokenTextAt(ctx, pos, '{') Then
      parsed := ParseTableConstructor(pos, last_token, depth)
    Else If TokenIsKeyword(ctx, pos, 'function') Then
      parsed := ParseFunctionLiteral(pos, last_token, depth)
    Else
      Begin
        ParseErrorAtToken(ctx, pos, 'expression Lua attendue');
        Inc(ctx.parse.expr_error_count);
      End;

    While parsed And (pos <= last_token) Do
      Begin
        first := pos;
        If TokenTextAt(ctx, pos, '.') Then
          Begin
            Inc(pos);
            If (pos <= last_token) And
               (ctx.lex.tokens[pos].kind = TK_IDENT) Then
              Begin
                Inc(pos);
                AddExpression(EK_INDEX, first - 1, pos - 1, depth);
              End
            Else
              Begin
                ParseErrorAtToken(ctx, first, 'nom attendu apres .');
                Inc(ctx.parse.expr_error_count);
                parsed := False;
              End;
          End
        Else If TokenTextAt(ctx, pos, '[') Then
          Begin
            close_pos := MatchingClose(pos, last_token, '[', ']');
            If close_pos = 0 Then
              Begin
                ParseErrorAtToken(ctx, pos, '] attendu dans indexation');
                Inc(ctx.parse.expr_error_count);
                parsed := False;
              End
            Else
              Begin
                ValidateExpressionList(pos + 1, close_pos - 1);
                pos := close_pos + 1;
                AddExpression(EK_INDEX, first - 1, pos - 1, depth);
              End;
          End
        Else If TokenTextAt(ctx, pos, ':') Then
          Begin
            Inc(pos);
            If (pos <= last_token) And
               (ctx.lex.tokens[pos].kind = TK_IDENT) Then
              Inc(pos)
            Else
              Begin
                ParseErrorAtToken(ctx, first, 'nom de methode attendu apres :');
                Inc(ctx.parse.expr_error_count);
                parsed := False;
              End;
          End
        Else If TokenTextAt(ctx, pos, '(') Then
          Begin
            close_pos := MatchingClose(pos, last_token, '(', ')');
            If close_pos = 0 Then
              Begin
                ParseErrorAtToken(ctx, pos, ') attendu dans appel');
                Inc(ctx.parse.expr_error_count);
                parsed := False;
              End
            Else
              Begin
                ValidateExpressionList(pos + 1, close_pos - 1);
                pos := close_pos + 1;
                AddExpression(EK_CALL, first - 1, pos - 1, depth);
              End;
          End
        Else If (ctx.lex.tokens[pos].kind = TK_STRING) Or
                TokenTextAt(ctx, pos, '{') Then
          Begin
            If ctx.lex.tokens[pos].kind = TK_STRING Then
              Inc(pos)
            Else If Not ParseTableConstructor(pos, last_token, depth + 1) Then
              parsed := False;
            If parsed Then
              AddExpression(EK_CALL, first - 1, pos - 1, depth);
          End
        Else
          Break;
      End;
    ParsePrimary := parsed;
  End;

  Function ParseExpression(Var pos: LongInt; min_prec: Integer;
                           last_token: LongInt; depth: Integer): Boolean;
  Var
    first, op_pos: LongInt;
    prec, next_min: Integer;
    right_assoc: Boolean;
  Begin
    ParseExpression := False;
    first := pos;
    If (pos <= last_token) And IsUnaryOperator(pos) Then
      Begin
        op_pos := pos;
        Inc(pos);
        If Not ParseExpression(pos, 8, last_token, depth + 1) Then
          Exit;
        AddExpression(EK_UNARY, op_pos, pos - 1, depth);
      End
    Else If Not ParsePrimary(pos, last_token, depth + 1) Then
      Exit;

    While (pos <= last_token) And
          BinaryOperatorInfo(pos, prec, right_assoc) And
          (prec >= min_prec) Do
      Begin
        op_pos := pos;
        Inc(pos);
        If right_assoc Then
          next_min := prec
        Else
          next_min := prec + 1;
        If Not ParseExpression(pos, next_min, last_token, depth + 1) Then
          Begin
            ParseErrorAtToken(ctx, op_pos, 'operande droit attendu');
            Inc(ctx.parse.expr_error_count);
            Exit;
          End;
        AddExpression(EK_BINARY, first, pos - 1, depth);
      End;
    ParseExpression := True;
  End;

  Procedure ValidateExpressionRange(first_token, last_token: LongInt);
  Var
    p: LongInt;
  Begin
    If first_token > last_token Then
      Exit;
    p := first_token;
    If ParseExpression(p, 1, last_token, 0) Then
      Begin
        If p <= last_token Then
          Begin
            ParseErrorAtToken(ctx, p, 'operateur ou fin d''expression attendu');
            Inc(ctx.parse.expr_error_count);
          End;
      End;
  End;

  Procedure ValidateExpressionList(first_token, last_token: LongInt);
  Var
    p, start_part, paren_depth, brace_depth, bracket_depth, func_depth: LongInt;

    Procedure FinishPart(end_part: LongInt);
    Var
      eq_pos: LongInt;
    Begin
      If start_part > end_part Then
        Exit;
      If TokenTextAt(ctx, start_part, '[') Then
        Begin
          eq_pos := TopLevelAssign(start_part, end_part);
          If eq_pos <> 0 Then
            Begin
              ValidateExpressionRange(start_part + 1, eq_pos - 2);
              ValidateExpressionRange(eq_pos + 1, end_part);
              Exit;
            End;
        End;
      If (ctx.lex.tokens[start_part].kind = TK_IDENT) Then
        Begin
          eq_pos := TopLevelAssign(start_part, end_part);
          If eq_pos <> 0 Then
            Begin
              ValidateExpressionRange(eq_pos + 1, end_part);
              Exit;
            End;
        End;
      ValidateExpressionRange(start_part, end_part);
    End;

  Begin
    If first_token > last_token Then
      Exit;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    func_depth := 0;
    start_part := first_token;
    p := first_token;
    While p <= last_token Do
      Begin
        If TokenIsKeyword(ctx, p, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, p, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If func_depth = 0 Then
          Begin
            If TokenTextAt(ctx, p, '(') Then
              Inc(paren_depth)
            Else If TokenTextAt(ctx, p, ')') And (paren_depth > 0) Then
              Dec(paren_depth)
            Else If TokenTextAt(ctx, p, '{') Then
              Inc(brace_depth)
            Else If TokenTextAt(ctx, p, '}') And (brace_depth > 0) Then
              Dec(brace_depth)
            Else If TokenTextAt(ctx, p, '[') Then
              Inc(bracket_depth)
            Else If TokenTextAt(ctx, p, ']') And (bracket_depth > 0) Then
              Dec(bracket_depth)
            Else If (paren_depth = 0) And (brace_depth = 0) And
                    (bracket_depth = 0) And
                    (ctx.lex.tokens[p].kind = TK_PUNCT) And
                    (TokenTextAt(ctx, p, ',') Or TokenTextAt(ctx, p, ';')) Then
              Begin
                FinishPart(p - 1);
                start_part := p + 1;
              End;
          End;
        Inc(p);
      End;
    FinishPart(last_token);
  End;

  Procedure ValidateStatementExpressions(kind: TStatementKind;
                                         first_token, last_token: LongInt);
  Var
    eq_pos, in_pos: LongInt;
  Begin
    While (last_token >= first_token) And TokenTextAt(ctx, last_token, ';') Do
      Dec(last_token);
    If first_token > last_token Then
      Exit;
    Case kind Of
      SK_LOCAL:
        Begin
          eq_pos := TopLevelAssign(first_token, last_token);
          If eq_pos <> 0 Then
            ValidateExpressionList(eq_pos + 1, last_token);
        End;
      SK_RETURN:
        ValidateExpressionList(first_token + 1, last_token);
      SK_FOR:
        Begin
          eq_pos := TopLevelAssign(first_token, last_token);
          in_pos := TopLevelKeyword(first_token, last_token, 'in');
          If eq_pos <> 0 Then
            ValidateExpressionList(eq_pos + 1, last_token)
          Else If in_pos <> 0 Then
            ValidateExpressionList(in_pos + 1, last_token);
        End;
    Else
      eq_pos := TopLevelAssign(first_token, last_token);
      If eq_pos <> 0 Then
        ValidateExpressionList(eq_pos + 1, last_token)
      Else
        ValidateExpressionRange(first_token, last_token);
    End;
  End;

  Function IsBlockTerminator(pos: LongInt; until_kind: TBlockKind): Boolean;
  Begin
    IsBlockTerminator := False;
    If (pos < 1) Or (pos > ctx.lex.token_count) Then
      Exit;
    If ctx.lex.tokens[pos].kind = TK_EOF Then
      Begin
        IsBlockTerminator := until_kind = BK_CHUNK;
        Exit;
      End;
    Case until_kind Of
      BK_CHUNK:
        IsBlockTerminator := ctx.lex.tokens[pos].kind = TK_EOF;
      BK_REPEAT:
        IsBlockTerminator := TokenIsKeyword(ctx, pos, 'until');
    Else
      IsBlockTerminator := TokenIsKeyword(ctx, pos, 'end') Or
                           TokenIsKeyword(ctx, pos, 'else') Or
                           TokenIsKeyword(ctx, pos, 'elseif');
    End;
  End;

  Function FindKeywordOnLevel(start_pos: LongInt; keyword: TString): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth: LongInt;
  Begin
    FindKeywordOnLevel := 0;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    p := start_pos;
    While (p <= ctx.lex.token_count) And
          (ctx.lex.tokens[p].kind <> TK_EOF) Do
      Begin
        If (paren_depth = 0) And (brace_depth = 0) And
           (bracket_depth = 0) And TokenIsKeyword(ctx, p, keyword) Then
          Begin
            FindKeywordOnLevel := p;
            Exit;
          End;
        If TokenTextAt(ctx, p, '(') Then
          Inc(paren_depth)
        Else If TokenTextAt(ctx, p, ')') And (paren_depth > 0) Then
          Dec(paren_depth)
        Else If TokenTextAt(ctx, p, '{') Then
          Inc(brace_depth)
        Else If TokenTextAt(ctx, p, '}') And (brace_depth > 0) Then
          Dec(brace_depth)
        Else If TokenTextAt(ctx, p, '[') Then
          Inc(bracket_depth)
        Else If TokenTextAt(ctx, p, ']') And (bracket_depth > 0) Then
          Dec(bracket_depth);
        Inc(p);
      End;
  End;

  Function SkipSimpleStatement(pos: LongInt): LongInt;
  Var
    start_line: LongInt;
    paren_depth, brace_depth, bracket_depth, func_depth: Integer;
  Begin
    start_line := ctx.lex.tokens[pos].line;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    func_depth := 0;
    While (pos <= ctx.lex.token_count) And
          (ctx.lex.tokens[pos].kind <> TK_EOF) Do
      Begin
        If (paren_depth = 0) And (brace_depth = 0) And
           (bracket_depth = 0) And (func_depth = 0) Then
          Begin
            If TokenTextAt(ctx, pos, ';') Then
              Begin
                Inc(pos);
                Break;
              End;
            If (ctx.lex.tokens[pos].line <> start_line) And
               (Not TokenTextAt(ctx, pos, '.')) And
               (Not TokenTextAt(ctx, pos, ',')) And
               (Not TokenTextAt(ctx, pos, '..')) And
               (Not TokenTextAt(ctx, pos, ')')) And
               (Not TokenTextAt(ctx, pos, ']')) And
               (Not TokenTextAt(ctx, pos, '}')) Then
              Break;
            If TokenIsKeyword(ctx, pos, 'end') Or
               TokenIsKeyword(ctx, pos, 'else') Or
               TokenIsKeyword(ctx, pos, 'elseif') Or
               TokenIsKeyword(ctx, pos, 'until') Then
              Break;
          End;
        If TokenIsKeyword(ctx, pos, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, pos, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If TokenTextAt(ctx, pos, '(') Then
          Inc(paren_depth)
        Else If TokenTextAt(ctx, pos, ')') And (paren_depth > 0) Then
          Dec(paren_depth)
        Else If TokenTextAt(ctx, pos, '{') Then
          Inc(brace_depth)
        Else If TokenTextAt(ctx, pos, '}') And (brace_depth > 0) Then
          Dec(brace_depth)
        Else If TokenTextAt(ctx, pos, '[') Then
          Inc(bracket_depth)
        Else If TokenTextAt(ctx, pos, ']') And (bracket_depth > 0) Then
          Dec(bracket_depth);
        Inc(pos);
      End;
    SkipSimpleStatement := pos;
  End;

  Function SkipFunctionHeader(pos: LongInt): LongInt;
  Var
    p, depth: LongInt;
    seen_paren: Boolean;
  Begin
    p := pos + 1;
    depth := 0;
    seen_paren := False;
    While (p <= ctx.lex.token_count) And
          (ctx.lex.tokens[p].kind <> TK_EOF) Do
      Begin
        If TokenTextAt(ctx, p, '(') Then
          Begin
            Inc(depth);
            seen_paren := True;
          End
        Else If TokenTextAt(ctx, p, ')') And (depth > 0) Then
          Begin
            Dec(depth);
            If seen_paren And (depth = 0) Then
              Begin
                SkipFunctionHeader := p + 1;
                Exit;
              End;
          End;
        Inc(p);
      End;
    ParseErrorAtToken(ctx, pos, 'liste de parametres function non terminee');
    SkipFunctionHeader := p;
  End;

  Procedure ParseBlock(Var pos: LongInt; block_kind: TBlockKind;
                       depth: Integer); Forward;

  Procedure ParseFunction(Var pos: LongInt; depth: Integer;
                          stmt_start: LongInt);
  Var
    body_start, body_end: LongInt;
  Begin
    AddStatement(SK_FUNCTION, stmt_start, pos, depth);
    body_start := SkipFunctionHeader(pos);
    pos := body_start;
    ParseBlock(pos, BK_FUNCTION, depth + 1);
    If TokenIsKeyword(ctx, pos, 'end') Then
      Begin
        body_end := pos;
        Inc(pos);
        AddBlock(BK_FUNCTION, body_start, body_end, depth + 1);
      End
    Else
      ParseErrorAtToken(ctx, pos, 'end attendu pour function');
  End;

  Procedure ParseIf(Var pos: LongInt; depth: Integer);
  Var
    stmt_start, then_pos, block_start, block_end, cond_start: LongInt;
  Begin
    stmt_start := pos;
    AddStatement(SK_IF, stmt_start, stmt_start, depth);
    then_pos := FindKeywordOnLevel(pos + 1, 'then');
    If then_pos = 0 Then
      Begin
        ParseErrorAtToken(ctx, pos, 'then attendu pour if');
        pos := SkipSimpleStatement(pos);
        Exit;
      End;
    ValidateExpressionRange(pos + 1, then_pos - 1);
    pos := then_pos + 1;
    block_start := pos;
    ParseBlock(pos, BK_IF, depth + 1);
    block_end := pos - 1;
    AddBlock(BK_IF, block_start, block_end, depth + 1);
    While TokenIsKeyword(ctx, pos, 'elseif') Do
      Begin
        Inc(ctx.parse.elseif_count);
        cond_start := pos + 1;
        then_pos := FindKeywordOnLevel(pos + 1, 'then');
        If then_pos = 0 Then
          Begin
            ParseErrorAtToken(ctx, pos, 'then attendu pour elseif');
            Exit;
          End;
        ValidateExpressionRange(cond_start, then_pos - 1);
        pos := then_pos + 1;
        block_start := pos;
        ParseBlock(pos, BK_IF, depth + 1);
        AddBlock(BK_IF, block_start, pos - 1, depth + 1);
      End;
    If TokenIsKeyword(ctx, pos, 'else') Then
      Begin
        Inc(ctx.parse.else_count);
        Inc(pos);
        block_start := pos;
        ParseBlock(pos, BK_IF, depth + 1);
        AddBlock(BK_IF, block_start, pos - 1, depth + 1);
      End;
    If TokenIsKeyword(ctx, pos, 'end') Then
      Inc(pos)
    Else
      ParseErrorAtToken(ctx, pos, 'end attendu pour if');
  End;

  Procedure ParseBlock(Var pos: LongInt; block_kind: TBlockKind;
                       depth: Integer);
  Var
    stmt_start, do_pos, block_start, stmt_end: LongInt;
  Begin
    While (pos <= ctx.lex.token_count) And
          (Not IsBlockTerminator(pos, block_kind)) And
          (ctx.errors < MAX_ERRORS) Do
      Begin
        If TokenTextAt(ctx, pos, ';') Then
          Begin
            AddStatement(SK_EMPTY, pos, pos, depth);
            Inc(pos);
          End
        Else If TokenIsKeyword(ctx, pos, 'if') Then
          ParseIf(pos, depth)
        Else If TokenIsKeyword(ctx, pos, 'while') Then
          Begin
            stmt_start := pos;
            AddStatement(SK_WHILE, stmt_start, stmt_start, depth);
            do_pos := FindKeywordOnLevel(pos + 1, 'do');
            If do_pos = 0 Then
              Begin
                ParseErrorAtToken(ctx, pos, 'do attendu pour while');
                pos := SkipSimpleStatement(pos);
              End
            Else
              Begin
                ValidateExpressionRange(pos + 1, do_pos - 1);
                pos := do_pos + 1;
                block_start := pos;
                ParseBlock(pos, BK_WHILE, depth + 1);
                AddBlock(BK_WHILE, block_start, pos - 1, depth + 1);
                If TokenIsKeyword(ctx, pos, 'end') Then
                  Inc(pos)
                Else
                  ParseErrorAtToken(ctx, pos, 'end attendu pour while');
              End;
          End
        Else If TokenIsKeyword(ctx, pos, 'repeat') Then
          Begin
            stmt_start := pos;
            AddStatement(SK_REPEAT, stmt_start, stmt_start, depth);
            Inc(pos);
            block_start := pos;
            ParseBlock(pos, BK_REPEAT, depth + 1);
            AddBlock(BK_REPEAT, block_start, pos - 1, depth + 1);
            If TokenIsKeyword(ctx, pos, 'until') Then
              Begin
                Inc(pos);
                stmt_start := pos;
                stmt_end := SkipSimpleStatement(pos);
                ValidateExpressionRange(stmt_start, stmt_end - 1);
                pos := stmt_end;
              End
            Else
              ParseErrorAtToken(ctx, pos, 'until attendu pour repeat');
          End
        Else If TokenIsKeyword(ctx, pos, 'for') Then
          Begin
            stmt_start := pos;
            AddStatement(SK_FOR, stmt_start, stmt_start, depth);
            do_pos := FindKeywordOnLevel(pos + 1, 'do');
            If do_pos = 0 Then
              Begin
                ParseErrorAtToken(ctx, pos, 'do attendu pour for');
                pos := SkipSimpleStatement(pos);
              End
            Else
              Begin
                ValidateStatementExpressions(SK_FOR, pos, do_pos - 1);
                pos := do_pos + 1;
                block_start := pos;
                ParseBlock(pos, BK_FOR, depth + 1);
                AddBlock(BK_FOR, block_start, pos - 1, depth + 1);
                If TokenIsKeyword(ctx, pos, 'end') Then
                  Inc(pos)
                Else
                  ParseErrorAtToken(ctx, pos, 'end attendu pour for');
              End;
          End
        Else If TokenIsKeyword(ctx, pos, 'do') Then
          Begin
            stmt_start := pos;
            AddStatement(SK_DO, stmt_start, stmt_start, depth);
            Inc(pos);
            block_start := pos;
            ParseBlock(pos, BK_DO, depth + 1);
            AddBlock(BK_DO, block_start, pos - 1, depth + 1);
            If TokenIsKeyword(ctx, pos, 'end') Then
              Inc(pos)
            Else
              ParseErrorAtToken(ctx, pos, 'end attendu pour do');
          End
        Else If TokenIsKeyword(ctx, pos, 'function') Then
          ParseFunction(pos, depth, pos)
        Else If TokenIsKeyword(ctx, pos, 'local') Then
          Begin
            stmt_start := pos;
            AddStatement(SK_LOCAL, stmt_start, stmt_start, depth);
            If TokenIsKeyword(ctx, pos + 1, 'function') Then
              Begin
                Inc(pos);
                ParseFunction(pos, depth, stmt_start);
              End
            Else
              Begin
                stmt_end := SkipSimpleStatement(pos);
                ValidateStatementExpressions(SK_LOCAL, stmt_start,
                                             stmt_end - 1);
                pos := stmt_end;
              End;
          End
        Else If TokenIsKeyword(ctx, pos, 'return') Then
          Begin
            stmt_start := pos;
            AddStatement(SK_RETURN, pos, pos, depth);
            stmt_end := SkipSimpleStatement(pos);
            ValidateStatementExpressions(SK_RETURN, stmt_start,
                                         stmt_end - 1);
            pos := stmt_end;
          End
        Else If TokenIsKeyword(ctx, pos, 'break') Then
          Begin
            AddStatement(SK_BREAK, pos, pos, depth);
            pos := SkipSimpleStatement(pos);
          End
        Else If TokenIsKeyword(ctx, pos, 'goto') Then
          Begin
            AddStatement(SK_GOTO, pos, pos, depth);
            pos := SkipSimpleStatement(pos);
          End
        Else If TokenTextAt(ctx, pos, '::') Then
          Begin
            stmt_start := pos;
            AddStatement(SK_EMPTY, stmt_start, stmt_start, depth);
            Inc(pos);
            If (pos <= ctx.lex.token_count) And
               (ctx.lex.tokens[pos].kind = TK_IDENT) Then
              Inc(pos)
            Else
              ParseErrorAtToken(ctx, stmt_start, 'nom de label attendu');
            If TokenTextAt(ctx, pos, '::') Then
              Inc(pos)
            Else
              ParseErrorAtToken(ctx, stmt_start, ':: attendu apres label');
          End
        Else
          Begin
            stmt_start := pos;
            AddStatement(SK_ASSIGN_OR_CALL, pos, pos, depth);
            stmt_end := SkipSimpleStatement(pos);
            ValidateStatementExpressions(SK_ASSIGN_OR_CALL, stmt_start,
                                         stmt_end - 1);
            pos := stmt_end;
          End;
      End;
  End;

Var
  pos: LongInt;
Begin
  ParseAst := False;
  FillChar(ctx.parse, SizeOf(ctx.parse), 0);
  If ctx.lex.token_count = 0 Then
    Begin
      PipelineError(ctx, 'tokens absents avant parse');
      Exit;
    End;
  pos := 1;
  ParseBlock(pos, BK_CHUNK, 0);
  If Not TokenTextAt(ctx, pos, '') Then
    If ctx.lex.tokens[pos].kind <> TK_EOF Then
      ParseErrorAtToken(ctx, pos, 'fin de fichier attendue');
  AddBlock(BK_CHUNK, 1, pos, 0);
  ctx.last_art := AK_AST_IR;
  If ctx.options.verbose Then
    Writeln('AST/IR Lua: ', ctx.parse.statement_count,
            ' instruction(s), ', ctx.parse.block_count,
            ' bloc(s), profondeur max ', ctx.parse.max_block_depth,
            ' (if=', ctx.parse.if_count,
            ', elseif=', ctx.parse.elseif_count,
            ', else=', ctx.parse.else_count,
            ', while=', ctx.parse.while_count,
            ', repeat=', ctx.parse.repeat_count,
            ', for=', ctx.parse.for_count,
            ', function=', ctx.parse.function_count,
            ', local=', ctx.parse.local_count,
            ', return=', ctx.parse.return_count,
            ', break=', ctx.parse.break_count,
            ', goto=', ctx.parse.goto_count,
            ', expr=', ctx.parse.expr_count,
            ', expr-bin=', ctx.parse.binary_expr_count,
            ', expr-un=', ctx.parse.unary_expr_count,
            ', appels=', ctx.parse.call_expr_count,
            ', tables=', ctx.parse.table_expr_count,
            ', expr-profondeur=', ctx.parse.expr_max_depth, ')');
  ParseAst := ctx.errors = 0;
End;

Function LuaValueTag(kind: TLuaValueKind): LongInt;
Begin
  Case kind Of
    LVK_NIL:       LuaValueTag := 0;
    LVK_FALSE:     LuaValueTag := 1;
    LVK_TRUE:      LuaValueTag := 2;
    LVK_NUMBER:    LuaValueTag := 3;
    LVK_STRING:    LuaValueTag := 4;
    LVK_TABLE:     LuaValueTag := 5;
    LVK_FUNCTION:  LuaValueTag := 6;
    LVK_CLOSURE:   LuaValueTag := 7;
    LVK_COROUTINE: LuaValueTag := 8;
  Else
    LuaValueTag := LUA_VALUE_TAG_MASK;
  End;
End;

Function PackLuaValue(kind: TLuaValueKind; payload: LongInt): TLuaValueWord;
Begin
  PackLuaValue := (payload Shl LUA_VALUE_PAYLOAD_SHIFT) Or
                  LuaValueTag(kind);
End;

Function ObjectKindForValue(kind: TLuaValueKind): TLuaObjectKind;
Begin
  Case kind Of
    LVK_NUMBER:    ObjectKindForValue := LOK_NUMBER;
    LVK_STRING:    ObjectKindForValue := LOK_STRING;
    LVK_TABLE:     ObjectKindForValue := LOK_TABLE;
    LVK_FUNCTION:  ObjectKindForValue := LOK_FUNCTION;
    LVK_CLOSURE:   ObjectKindForValue := LOK_CLOSURE;
    LVK_COROUTINE: ObjectKindForValue := LOK_COROUTINE;
  Else
    ObjectKindForValue := LOK_NONE;
  End;
End;

Function ValueUsesObject(kind: TLuaValueKind): Boolean;
Begin
  ValueUsesObject := ObjectKindForValue(kind) <> LOK_NONE;
End;

Function BuildRuntimeModel(Var ctx: TCompilerContext): Boolean;

  Function NewRuntimeObject(kind: TLuaObjectKind; first_token: LongInt): LongInt;
  Var
    id: LongInt;
  Begin
    NewRuntimeObject := 0;
    If kind = LOK_NONE Then
      Exit;
    If ctx.runtime.object_count >= MAX_RUNTIME_OBJECTS Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop d''objets runtime Lua');
        Exit;
      End;
    Inc(ctx.runtime.object_count);
    id := ctx.runtime.object_count;
    ctx.runtime.objects[id].header.kind := kind;
    ctx.runtime.objects[id].header.flags := 0;
    ctx.runtime.objects[id].header.ref_count := 0;
    ctx.runtime.objects[id].header.size := 0;
    ctx.runtime.objects[id].handle := id;
    ctx.runtime.objects[id].first_token := first_token;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.runtime.objects[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.runtime.objects[id].line := 1;
    If id > ctx.runtime.max_handle Then
      ctx.runtime.max_handle := id;
    NewRuntimeObject := id;
  End;

  Procedure AddRuntimeValue(kind: TLuaValueKind; first_token, last_token: LongInt);
  Var
    id, obj_id, payload: LongInt;
  Begin
    If ctx.runtime.value_count >= MAX_RUNTIME_VALUES Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop de valeurs runtime Lua');
        Exit;
      End;
    obj_id := 0;
    payload := LUA_VALUE_NULL_PAYLOAD;
    If ValueUsesObject(kind) Then
      Begin
        obj_id := NewRuntimeObject(ObjectKindForValue(kind), first_token);
        payload := obj_id;
      End;

    Inc(ctx.runtime.value_count);
    id := ctx.runtime.value_count;
    ctx.runtime.values[id].kind := kind;
    ctx.runtime.values[id].word := PackLuaValue(kind, payload);
    ctx.runtime.values[id].object_id := obj_id;
    ctx.runtime.values[id].first_token := first_token;
    ctx.runtime.values[id].last_token := last_token;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.runtime.values[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.runtime.values[id].line := 1;

    Case kind Of
      LVK_NIL:       Inc(ctx.runtime.nil_count);
      LVK_FALSE:     Inc(ctx.runtime.false_count);
      LVK_TRUE:      Inc(ctx.runtime.true_count);
      LVK_NUMBER:    Inc(ctx.runtime.number_count);
      LVK_STRING:    Inc(ctx.runtime.string_count);
      LVK_TABLE:     Inc(ctx.runtime.table_count);
      LVK_FUNCTION:  Inc(ctx.runtime.function_count);
      LVK_CLOSURE:   Inc(ctx.runtime.closure_count);
      LVK_COROUTINE: Inc(ctx.runtime.coroutine_count);
    Else
    End;
  End;

  Function ExprRuntimeKind(expr: TExprInfo): TLuaValueKind;
  Begin
    Case expr.kind Of
      EK_NIL:
        ExprRuntimeKind := LVK_NIL;
      EK_BOOL:
        Begin
          If TokenIsKeyword(ctx, expr.first_token, 'true') Then
            ExprRuntimeKind := LVK_TRUE
          Else
            ExprRuntimeKind := LVK_FALSE;
        End;
      EK_NUMBER:
        ExprRuntimeKind := LVK_NUMBER;
      EK_STRING:
        ExprRuntimeKind := LVK_STRING;
      EK_TABLE:
        ExprRuntimeKind := LVK_TABLE;
      EK_FUNCTION:
        ExprRuntimeKind := LVK_CLOSURE;
    Else
      ExprRuntimeKind := LVK_UNKNOWN;
    End;
  End;

Var
  i: LongInt;
  kind: TLuaValueKind;
Begin
  BuildRuntimeModel := False;
  FillChar(ctx.runtime, SizeOf(ctx.runtime), 0);

  AddRuntimeValue(LVK_NIL, 1, 1);
  AddRuntimeValue(LVK_FALSE, 1, 1);
  AddRuntimeValue(LVK_TRUE, 1, 1);

  For i := 1 To ctx.parse.expr_count Do
    Begin
      kind := ExprRuntimeKind(ctx.parse.expressions[i]);
      If kind <> LVK_UNKNOWN Then
        AddRuntimeValue(kind,
                        ctx.parse.expressions[i].first_token,
                        ctx.parse.expressions[i].last_token);
    End;

  If ctx.options.verbose Then
    Writeln('Modele runtime Lua 32 bits: ', ctx.runtime.value_count,
            ' valeur(s), ', ctx.runtime.object_count, ' objet(s), tags=',
            LUA_VALUE_TAG_BITS, ' bits, payload=28 bits',
            ' (nil=', ctx.runtime.nil_count,
            ', false=', ctx.runtime.false_count,
            ', true=', ctx.runtime.true_count,
            ', number=', ctx.runtime.number_count,
            ', string=', ctx.runtime.string_count,
            ', table=', ctx.runtime.table_count,
            ', function=', ctx.runtime.function_count,
            ', closure=', ctx.runtime.closure_count,
            ', coroutine=', ctx.runtime.coroutine_count,
            ', max-handle=', ctx.runtime.max_handle, ')');

  BuildRuntimeModel := ctx.errors = 0;
End;

Function BuildSymbolTable(Var ctx: TCompilerContext): Boolean;

  Function AddScope(kind: TScopeKind; parent, first_token: LongInt): LongInt;
  Var
    id: LongInt;
  Begin
    AddScope := 0;
    If ctx.sema.scope_count >= MAX_SCOPES Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop de scopes Lua');
        Exit;
      End;
    Inc(ctx.sema.scope_count);
    id := ctx.sema.scope_count;
    ctx.sema.scopes[id].kind := kind;
    ctx.sema.scopes[id].parent := parent;
    ctx.sema.scopes[id].first_token := first_token;
    ctx.sema.scopes[id].last_token := first_token;
    If parent > 0 Then
      Begin
        ctx.sema.scopes[id].depth := ctx.sema.scopes[parent].depth + 1;
        ctx.sema.scopes[id].function_depth :=
          ctx.sema.scopes[parent].function_depth;
      End
    Else
      Begin
        ctx.sema.scopes[id].depth := 0;
        ctx.sema.scopes[id].function_depth := 0;
      End;
    If kind = SCK_FUNCTION Then
      Inc(ctx.sema.scopes[id].function_depth);
    AddScope := id;
  End;

  Procedure CloseScope(scope_id, last_token: LongInt);
  Begin
    If (scope_id >= 1) And (scope_id <= ctx.sema.scope_count) Then
      ctx.sema.scopes[scope_id].last_token := last_token;
  End;

  Function FindSymbolInScope(name: TTokenText; scope_id: LongInt): LongInt;
  Var
    i: LongInt;
  Begin
    FindSymbolInScope := 0;
    For i := ctx.sema.symbol_count DownTo 1 Do
      If (ctx.sema.symbols[i].scope_id = scope_id) And
         (UpperStr(ctx.sema.symbols[i].name) = UpperStr(name)) Then
        Begin
          FindSymbolInScope := i;
          Exit;
        End;
  End;

  Function AddSymbol(name: TTokenText; kind: TSymbolKind; scope_id,
                     token_idx: LongInt; assigned: Boolean): LongInt;
  Var
    id, existing: LongInt;
  Begin
    AddSymbol := 0;
    existing := FindSymbolInScope(name, scope_id);
    If existing <> 0 Then
      Begin
        If assigned Then
          ctx.sema.symbols[existing].assigned := True;
        AddSymbol := existing;
        Exit;
      End;
    If ctx.sema.symbol_count >= MAX_SYMBOLS Then
      Begin
        ParseErrorAtToken(ctx, token_idx, 'trop de symboles Lua');
        Exit;
      End;
    Inc(ctx.sema.symbol_count);
    id := ctx.sema.symbol_count;
    ctx.sema.symbols[id].name := name;
    ctx.sema.symbols[id].kind := kind;
    ctx.sema.symbols[id].scope_id := scope_id;
    ctx.sema.symbols[id].decl_token := token_idx;
    ctx.sema.symbols[id].first_use := 0;
    ctx.sema.symbols[id].last_use := 0;
    ctx.sema.symbols[id].use_count := 0;
    ctx.sema.symbols[id].assigned := assigned;
    ctx.sema.symbols[id].captured := False;
    If (token_idx >= 1) And (token_idx <= ctx.lex.token_count) Then
      ctx.sema.symbols[id].line := ctx.lex.tokens[token_idx].line
    Else
      ctx.sema.symbols[id].line := 1;
    If (scope_id >= 1) And (scope_id <= ctx.sema.scope_count) Then
      Inc(ctx.sema.scopes[scope_id].symbol_count);
    Case kind Of
      SYK_GLOBAL:   Inc(ctx.sema.global_count);
      SYK_LOCAL:    Inc(ctx.sema.local_count);
      SYK_PARAM:    Inc(ctx.sema.param_count);
      SYK_VARARG:   Inc(ctx.sema.vararg_count);
      SYK_FUNCTION: Inc(ctx.sema.function_sym_count);
      SYK_UPVALUE:  Inc(ctx.sema.upvalue_count);
      SYK_BUILTIN:  Inc(ctx.sema.builtin_count);
    Else
    End;
    AddSymbol := id;
  End;

  Function NearestFunctionScope(scope_id: LongInt): LongInt;
  Var
    cur: LongInt;
  Begin
    cur := scope_id;
    While (cur > 0) And (ctx.sema.scopes[cur].kind <> SCK_FUNCTION) Do
      cur := ctx.sema.scopes[cur].parent;
    NearestFunctionScope := cur;
  End;

  Procedure AddUse(symbol_id, token_idx: LongInt; assigned: Boolean);
  Begin
    If (symbol_id < 1) Or (symbol_id > ctx.sema.symbol_count) Then
      Exit;
    If ctx.sema.symbols[symbol_id].first_use = 0 Then
      ctx.sema.symbols[symbol_id].first_use := token_idx;
    ctx.sema.symbols[symbol_id].last_use := token_idx;
    Inc(ctx.sema.symbols[symbol_id].use_count);
    If assigned Then
      ctx.sema.symbols[symbol_id].assigned := True;
  End;

  Function ResolveSymbol(name: TTokenText; scope_id: LongInt;
                         token_idx: LongInt; assigned: Boolean): LongInt;
  Var
    s, cur, global_id: LongInt;
  Begin
    ResolveSymbol := 0;
    cur := scope_id;
    While cur > 0 Do
      Begin
        s := FindSymbolInScope(name, cur);
        If s <> 0 Then
          Begin
            If (ctx.sema.symbols[s].kind <> SYK_GLOBAL) And
               (ctx.sema.symbols[s].kind <> SYK_BUILTIN) And
               (ctx.sema.scopes[cur].function_depth <
                ctx.sema.scopes[scope_id].function_depth) Then
              Begin
                If Not ctx.sema.symbols[s].captured Then
                  Begin
                    ctx.sema.symbols[s].captured := True;
                    AddSymbol(name, SYK_UPVALUE, NearestFunctionScope(scope_id),
                              token_idx, False);
                  End;
              End;
            AddUse(s, token_idx, assigned);
            ResolveSymbol := s;
            Exit;
          End;
        cur := ctx.sema.scopes[cur].parent;
      End;
    global_id := AddSymbol(name, SYK_GLOBAL, 1, token_idx, assigned);
    AddUse(global_id, token_idx, assigned);
    ResolveSymbol := global_id;
  End;

  Procedure AddLabel(name: TTokenText; kind: TLabelKind; scope_id,
                     token_idx: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.sema.label_count >= MAX_LABELS Then
      Begin
        ParseErrorAtToken(ctx, token_idx, 'trop de labels Lua');
        Exit;
      End;
    Inc(ctx.sema.label_count);
    id := ctx.sema.label_count;
    ctx.sema.labels[id].name := name;
    ctx.sema.labels[id].kind := kind;
    ctx.sema.labels[id].scope_id := scope_id;
    ctx.sema.labels[id].token := token_idx;
    If (token_idx >= 1) And (token_idx <= ctx.lex.token_count) Then
      ctx.sema.labels[id].line := ctx.lex.tokens[token_idx].line
    Else
      ctx.sema.labels[id].line := 1;
    ctx.sema.labels[id].resolved := False;
  End;

  Function StatementEnd(pos: LongInt): LongInt;
  Var
    start_line: LongInt;
    paren_depth, brace_depth, bracket_depth, func_depth: Integer;
  Begin
    start_line := ctx.lex.tokens[pos].line;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    func_depth := 0;
    While (pos <= ctx.lex.token_count) And
          (ctx.lex.tokens[pos].kind <> TK_EOF) Do
      Begin
        If (paren_depth = 0) And (brace_depth = 0) And
           (bracket_depth = 0) And (func_depth = 0) Then
          Begin
            If TokenTextAt(ctx, pos, ';') Then
              Begin
                Inc(pos);
                Break;
              End;
            If (ctx.lex.tokens[pos].line <> start_line) And
               (Not TokenTextAt(ctx, pos, '.')) And
               (Not TokenTextAt(ctx, pos, ',')) And
               (Not TokenTextAt(ctx, pos, '..')) And
               (Not TokenTextAt(ctx, pos, ')')) And
               (Not TokenTextAt(ctx, pos, ']')) And
               (Not TokenTextAt(ctx, pos, '}')) Then
              Break;
            If TokenIsKeyword(ctx, pos, 'end') Or
               TokenIsKeyword(ctx, pos, 'else') Or
               TokenIsKeyword(ctx, pos, 'elseif') Or
               TokenIsKeyword(ctx, pos, 'until') Then
              Break;
          End;
        If TokenIsKeyword(ctx, pos, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, pos, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If TokenTextAt(ctx, pos, '(') Then
          Inc(paren_depth)
        Else If TokenTextAt(ctx, pos, ')') And (paren_depth > 0) Then
          Dec(paren_depth)
        Else If TokenTextAt(ctx, pos, '{') Then
          Inc(brace_depth)
        Else If TokenTextAt(ctx, pos, '}') And (brace_depth > 0) Then
          Dec(brace_depth)
        Else If TokenTextAt(ctx, pos, '[') Then
          Inc(bracket_depth)
        Else If TokenTextAt(ctx, pos, ']') And (bracket_depth > 0) Then
          Dec(bracket_depth);
        Inc(pos);
      End;
    StatementEnd := pos;
  End;

  Function FindLevelToken(first_token, last_token: LongInt;
                          text: TTokenText): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth, func_depth: LongInt;
  Begin
    FindLevelToken := 0;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    func_depth := 0;
    For p := first_token To last_token Do
      Begin
        If TokenIsKeyword(ctx, p, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, p, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If func_depth = 0 Then
          Begin
            If TokenTextAt(ctx, p, '(') Then
              Inc(paren_depth)
            Else If TokenTextAt(ctx, p, ')') And (paren_depth > 0) Then
              Dec(paren_depth)
            Else If TokenTextAt(ctx, p, '{') Then
              Inc(brace_depth)
            Else If TokenTextAt(ctx, p, '}') And (brace_depth > 0) Then
              Dec(brace_depth)
            Else If TokenTextAt(ctx, p, '[') Then
              Inc(bracket_depth)
            Else If TokenTextAt(ctx, p, ']') And (bracket_depth > 0) Then
              Dec(bracket_depth)
            Else If (paren_depth = 0) And (brace_depth = 0) And
                    (bracket_depth = 0) And
                    (ctx.lex.tokens[p].kind <> TK_STRING) And
                    TokenTextAt(ctx, p, text) Then
              Begin
                FindLevelToken := p;
                Exit;
              End;
          End;
      End;
  End;

  Function FindLevelKeyword(first_token, last_token: LongInt;
                            keyword: TTokenText): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth: LongInt;
  Begin
    FindLevelKeyword := 0;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    For p := first_token To last_token Do
      Begin
        If TokenTextAt(ctx, p, '(') Then
          Inc(paren_depth)
        Else If TokenTextAt(ctx, p, ')') And (paren_depth > 0) Then
          Dec(paren_depth)
        Else If TokenTextAt(ctx, p, '{') Then
          Inc(brace_depth)
        Else If TokenTextAt(ctx, p, '}') And (brace_depth > 0) Then
          Dec(brace_depth)
        Else If TokenTextAt(ctx, p, '[') Then
          Inc(bracket_depth)
        Else If TokenTextAt(ctx, p, ']') And (bracket_depth > 0) Then
          Dec(bracket_depth)
        Else If (paren_depth = 0) And (brace_depth = 0) And
                (bracket_depth = 0) And TokenIsKeyword(ctx, p, keyword) Then
          Begin
            FindLevelKeyword := p;
            Exit;
          End;
      End;
  End;

  Function HeaderEnd(function_pos: LongInt): LongInt;
  Var
    p, depth: LongInt;
    seen_paren: Boolean;
  Begin
    HeaderEnd := function_pos;
    p := function_pos + 1;
    depth := 0;
    seen_paren := False;
    While (p <= ctx.lex.token_count) And
          (ctx.lex.tokens[p].kind <> TK_EOF) Do
      Begin
        If TokenTextAt(ctx, p, '(') Then
          Begin
            Inc(depth);
            seen_paren := True;
          End
        Else If TokenTextAt(ctx, p, ')') And (depth > 0) Then
          Begin
            Dec(depth);
            If seen_paren And (depth = 0) Then
              Begin
                HeaderEnd := p;
                Exit;
              End;
          End;
        Inc(p);
      End;
  End;

  Procedure ScanBlock(Var pos: LongInt; scope_id: LongInt;
                      stop_until, stop_else: Boolean); Forward;

  Procedure ScanExpressionRange(first_token, last_token, scope_id: LongInt);
    Forward;

  Procedure ScanFunction(Var pos: LongInt; parent_scope: LongInt);
  Var
    func_scope, h_end, p: LongInt;
  Begin
    func_scope := AddScope(SCK_FUNCTION, parent_scope, pos);
    h_end := HeaderEnd(pos);
    p := pos;
    While (p <= h_end) And (Not TokenTextAt(ctx, p, '(')) Do
      Inc(p);
    If TokenTextAt(ctx, p, '(') Then
      Begin
        Inc(p);
        While (p < h_end) Do
          Begin
            If ctx.lex.tokens[p].kind = TK_IDENT Then
              AddSymbol(ctx.lex.tokens[p].text, SYK_PARAM, func_scope, p, True)
            Else If TokenTextAt(ctx, p, '...') Then
              AddSymbol('...', SYK_VARARG, func_scope, p, True);
            Inc(p);
          End;
      End;
    pos := h_end + 1;
    ScanBlock(pos, func_scope, False, False);
    If TokenIsKeyword(ctx, pos, 'end') Then
      Begin
        CloseScope(func_scope, pos);
        Inc(pos);
      End
    Else
      CloseScope(func_scope, pos);
  End;

  Procedure ScanExpressionRange(first_token, last_token, scope_id: LongInt);
  Var
    p: LongInt;
  Begin
    p := first_token;
    While p <= last_token Do
      Begin
        If TokenIsKeyword(ctx, p, 'function') Then
          ScanFunction(p, scope_id)
        Else
          Begin
            If ctx.lex.tokens[p].kind = TK_IDENT Then
              Begin
                If Not TokenTextAt(ctx, p - 1, '.') And
                   Not TokenTextAt(ctx, p - 1, ':') And
                   Not ((p < last_token) And TokenTextAt(ctx, p + 1, '=')) Then
                  ResolveSymbol(ctx.lex.tokens[p].text, scope_id, p, False);
              End;
            Inc(p);
          End;
      End;
  End;

  Procedure DeclareNameList(first_token, last_token, scope_id: LongInt;
                            kind: TSymbolKind);
  Var
    p: LongInt;
  Begin
    For p := first_token To last_token Do
      If ctx.lex.tokens[p].kind = TK_IDENT Then
        AddSymbol(ctx.lex.tokens[p].text, kind, scope_id, p, True);
  End;

  Procedure AssignNameList(first_token, last_token, scope_id: LongInt);
  Var
    p: LongInt;
  Begin
    For p := first_token To last_token Do
      If ctx.lex.tokens[p].kind = TK_IDENT Then
        Begin
          If Not TokenTextAt(ctx, p - 1, '.') And
             Not TokenTextAt(ctx, p - 1, ':') Then
            ResolveSymbol(ctx.lex.tokens[p].text, scope_id, p, True);
        End;
  End;

  Procedure ScanLocal(Var pos: LongInt; scope_id: LongInt);
  Var
    stmt_start, stmt_end, eq_pos: LongInt;
  Begin
    stmt_start := pos;
    stmt_end := StatementEnd(pos);
    If TokenIsKeyword(ctx, pos + 1, 'function') Then
      Begin
        If ctx.lex.tokens[pos + 2].kind = TK_IDENT Then
          AddSymbol(ctx.lex.tokens[pos + 2].text, SYK_FUNCTION, scope_id,
                    pos + 2, True);
        Inc(pos);
        ScanFunction(pos, scope_id);
      End
    Else
      Begin
        eq_pos := FindLevelToken(stmt_start, stmt_end - 1, '=');
        If eq_pos = 0 Then
          DeclareNameList(stmt_start + 1, stmt_end - 1, scope_id, SYK_LOCAL)
        Else
          Begin
            DeclareNameList(stmt_start + 1, eq_pos - 1, scope_id, SYK_LOCAL);
            ScanExpressionRange(eq_pos + 1, stmt_end - 1, scope_id);
          End;
        pos := stmt_end;
      End;
  End;

  Procedure ScanFunctionStatement(Var pos: LongInt; scope_id: LongInt);
  Var
    name_pos: LongInt;
  Begin
    name_pos := pos + 1;
    If ctx.lex.tokens[name_pos].kind = TK_IDENT Then
      Begin
        If TokenTextAt(ctx, name_pos + 1, '.') Or
           TokenTextAt(ctx, name_pos + 1, ':') Then
          ResolveSymbol(ctx.lex.tokens[name_pos].text, scope_id, name_pos,
                        False)
        Else
          AddSymbol(ctx.lex.tokens[name_pos].text, SYK_FUNCTION, 1, name_pos,
                    True);
      End;
    ScanFunction(pos, scope_id);
  End;

  Procedure ScanFor(Var pos: LongInt; scope_id: LongInt);
  Var
    loop_scope, do_pos, eq_pos, in_pos: LongInt;
  Begin
    do_pos := FindLevelKeyword(pos + 1, ctx.lex.token_count, 'do');
    If do_pos = 0 Then
      Begin
        pos := StatementEnd(pos);
        Exit;
      End;
    loop_scope := AddScope(SCK_LOOP, scope_id, pos);
    eq_pos := FindLevelToken(pos + 1, do_pos - 1, '=');
    in_pos := FindLevelKeyword(pos + 1, do_pos - 1, 'in');
    If eq_pos <> 0 Then
      Begin
        DeclareNameList(pos + 1, eq_pos - 1, loop_scope, SYK_LOCAL);
        ScanExpressionRange(eq_pos + 1, do_pos - 1, scope_id);
      End
    Else If in_pos <> 0 Then
      Begin
        DeclareNameList(pos + 1, in_pos - 1, loop_scope, SYK_LOCAL);
        ScanExpressionRange(in_pos + 1, do_pos - 1, scope_id);
      End;
    pos := do_pos + 1;
    ScanBlock(pos, loop_scope, False, False);
    If TokenIsKeyword(ctx, pos, 'end') Then
      Begin
        CloseScope(loop_scope, pos);
        Inc(pos);
      End
    Else
      CloseScope(loop_scope, pos);
  End;

  Procedure ScanBlock(Var pos: LongInt; scope_id: LongInt;
                      stop_until, stop_else: Boolean);
  Var
    stmt_start, stmt_end, sub_scope, then_pos, eq_pos: LongInt;
  Begin
    While (pos <= ctx.lex.token_count) And
          (ctx.lex.tokens[pos].kind <> TK_EOF) And
          (ctx.errors < MAX_ERRORS) Do
      Begin
        If TokenIsKeyword(ctx, pos, 'end') Or
           (stop_until And TokenIsKeyword(ctx, pos, 'until')) Or
           (stop_else And (TokenIsKeyword(ctx, pos, 'else') Or
                           TokenIsKeyword(ctx, pos, 'elseif'))) Then
          Exit;
        If TokenTextAt(ctx, pos, ';') Then
          Inc(pos)
        Else If TokenIsKeyword(ctx, pos, 'local') Then
          ScanLocal(pos, scope_id)
        Else If TokenIsKeyword(ctx, pos, 'function') Then
          ScanFunctionStatement(pos, scope_id)
        Else If TokenIsKeyword(ctx, pos, 'do') Then
          Begin
            sub_scope := AddScope(SCK_BLOCK, scope_id, pos);
            Inc(pos);
            ScanBlock(pos, sub_scope, False, False);
            If TokenIsKeyword(ctx, pos, 'end') Then
              Begin
                CloseScope(sub_scope, pos);
                Inc(pos);
              End
            Else
              CloseScope(sub_scope, pos);
          End
        Else If TokenIsKeyword(ctx, pos, 'if') Then
          Begin
            then_pos := FindLevelKeyword(pos + 1, ctx.lex.token_count,
                                         'then');
            If then_pos = 0 Then
              pos := StatementEnd(pos)
            Else
              Begin
                ScanExpressionRange(pos + 1, then_pos - 1, scope_id);
                sub_scope := AddScope(SCK_BLOCK, scope_id, pos);
                pos := then_pos + 1;
                ScanBlock(pos, sub_scope, False, True);
                CloseScope(sub_scope, pos);
                While TokenIsKeyword(ctx, pos, 'elseif') Do
                  Begin
                    then_pos := FindLevelKeyword(pos + 1,
                                                 ctx.lex.token_count, 'then');
                    If then_pos = 0 Then
                      Break;
                    ScanExpressionRange(pos + 1, then_pos - 1, scope_id);
                    sub_scope := AddScope(SCK_BLOCK, scope_id, pos);
                    pos := then_pos + 1;
                    ScanBlock(pos, sub_scope, False, True);
                    CloseScope(sub_scope, pos);
                  End;
                If TokenIsKeyword(ctx, pos, 'else') Then
                  Begin
                    sub_scope := AddScope(SCK_BLOCK, scope_id, pos);
                    Inc(pos);
                    ScanBlock(pos, sub_scope, False, False);
                    CloseScope(sub_scope, pos);
                  End;
                If TokenIsKeyword(ctx, pos, 'end') Then
                  Inc(pos);
              End;
          End
        Else If TokenIsKeyword(ctx, pos, 'while') Then
          Begin
            then_pos := FindLevelKeyword(pos + 1, ctx.lex.token_count, 'do');
            If then_pos = 0 Then
              pos := StatementEnd(pos)
            Else
              Begin
                ScanExpressionRange(pos + 1, then_pos - 1, scope_id);
                sub_scope := AddScope(SCK_LOOP, scope_id, pos);
                pos := then_pos + 1;
                ScanBlock(pos, sub_scope, False, False);
                If TokenIsKeyword(ctx, pos, 'end') Then
                  Begin
                    CloseScope(sub_scope, pos);
                    Inc(pos);
                  End
                Else
                  CloseScope(sub_scope, pos);
              End;
          End
        Else If TokenIsKeyword(ctx, pos, 'repeat') Then
          Begin
            sub_scope := AddScope(SCK_LOOP, scope_id, pos);
            Inc(pos);
            ScanBlock(pos, sub_scope, True, False);
            If TokenIsKeyword(ctx, pos, 'until') Then
              Begin
                stmt_start := pos + 1;
                stmt_end := StatementEnd(stmt_start);
                ScanExpressionRange(stmt_start, stmt_end - 1, sub_scope);
                CloseScope(sub_scope, stmt_end - 1);
                pos := stmt_end;
              End
            Else
              CloseScope(sub_scope, pos);
          End
        Else If TokenIsKeyword(ctx, pos, 'for') Then
          ScanFor(pos, scope_id)
        Else If TokenIsKeyword(ctx, pos, 'goto') Then
          Begin
            If ctx.lex.tokens[pos + 1].kind = TK_IDENT Then
              AddLabel(ctx.lex.tokens[pos + 1].text, LBK_GOTO, scope_id, pos);
            pos := StatementEnd(pos);
          End
        Else If TokenTextAt(ctx, pos, '::') Then
          Begin
            If ctx.lex.tokens[pos + 1].kind = TK_IDENT Then
              AddLabel(ctx.lex.tokens[pos + 1].text, LBK_LABEL, scope_id,
                       pos);
            Inc(pos, 3);
          End
        Else
          Begin
            stmt_start := pos;
            stmt_end := StatementEnd(pos);
            If TokenIsKeyword(ctx, stmt_start, 'return') Then
              ScanExpressionRange(stmt_start + 1, stmt_end - 1, scope_id)
            Else
              Begin
                eq_pos := FindLevelToken(stmt_start, stmt_end - 1, '=');
                If eq_pos <> 0 Then
                  Begin
                    AssignNameList(stmt_start, eq_pos - 1, scope_id);
                    ScanExpressionRange(eq_pos + 1, stmt_end - 1, scope_id);
                  End
                Else
                  ScanExpressionRange(stmt_start, stmt_end - 1, scope_id);
              End;
            pos := stmt_end;
          End;
      End;
  End;

  Procedure AddBuiltins(global_scope: LongInt);
  Begin
    AddSymbol('print', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('tostring', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('tonumber', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('type', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('assert', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('error', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('pcall', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('xpcall', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('pairs', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('ipairs', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('next', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('select', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('math', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('string', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('table', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('coroutine', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('os', SYK_BUILTIN, global_scope, 1, False);
    AddSymbol('io', SYK_BUILTIN, global_scope, 1, False);
  End;

  Procedure ResolveGotos;
  Var
    g, l: LongInt;
  Begin
    ctx.sema.unresolved_gotos := 0;
    For g := 1 To ctx.sema.label_count Do
      If ctx.sema.labels[g].kind = LBK_GOTO Then
        Begin
          For l := 1 To ctx.sema.label_count Do
            If (ctx.sema.labels[l].kind = LBK_LABEL) And
               (UpperStr(ctx.sema.labels[l].name) =
                UpperStr(ctx.sema.labels[g].name)) Then
              Begin
                ctx.sema.labels[g].resolved := True;
                Break;
              End;
          If Not ctx.sema.labels[g].resolved Then
            Inc(ctx.sema.unresolved_gotos);
        End;
  End;

Var
  pos, global_scope: LongInt;
Begin
  BuildSymbolTable := False;
  FillChar(ctx.sema, SizeOf(ctx.sema), 0);
  global_scope := AddScope(SCK_GLOBAL, 0, 1);
  AddBuiltins(global_scope);
  pos := 1;
  ScanBlock(pos, global_scope, False, False);
  CloseScope(global_scope, pos);
  ResolveGotos;
  If ctx.options.verbose Then
    Writeln('Symboles Lua: scopes=', ctx.sema.scope_count,
            ', symboles=', ctx.sema.symbol_count,
            ' (builtins=', ctx.sema.builtin_count,
            ', globaux=', ctx.sema.global_count,
            ', locaux=', ctx.sema.local_count,
            ', params=', ctx.sema.param_count,
            ', vararg=', ctx.sema.vararg_count,
            ', fonctions=', ctx.sema.function_sym_count,
            ', upvalues=', ctx.sema.upvalue_count,
            ', labels/goto=', ctx.sema.label_count,
            ', goto-non-resolus=', ctx.sema.unresolved_gotos, ')');
  BuildSymbolTable := ctx.errors = 0;
End;

Function BuildVariableCodePlan(Var ctx: TCompilerContext): Boolean;

  Function StorageForSymbol(sym: TSymbolInfo): TVarStorageKind;
  Begin
    Case sym.kind Of
      SYK_GLOBAL:
        StorageForSymbol := VSK_GLOBAL;
      SYK_PARAM:
        StorageForSymbol := VSK_PARAM;
      SYK_UPVALUE:
        StorageForSymbol := VSK_UPVALUE;
      SYK_LOCAL:
        StorageForSymbol := VSK_LOCAL;
      SYK_FUNCTION:
        Begin
          If sym.scope_id = 1 Then
            StorageForSymbol := VSK_GLOBAL
          Else
            StorageForSymbol := VSK_LOCAL;
        End;
    Else
      StorageForSymbol := VSK_NONE;
    End;
  End;

  Function VariableForSymbol(symbol_id: LongInt): LongInt;
  Var
    i: LongInt;
  Begin
    VariableForSymbol := 0;
    For i := 1 To ctx.codegen.variable_count Do
      If ctx.codegen.variables[i].symbol_id = symbol_id Then
        Begin
          VariableForSymbol := i;
          Exit;
        End;
  End;

  Function AddVariable(symbol_id: LongInt; storage: TVarStorageKind): LongInt;
  Var
    id: LongInt;
  Begin
    AddVariable := 0;
    If storage = VSK_NONE Then
      Exit;
    If ctx.codegen.variable_count >= MAX_VARIABLES Then
      Begin
        ParseErrorAtToken(ctx, ctx.sema.symbols[symbol_id].decl_token,
                          'trop de variables backend Lua');
        Exit;
      End;
    Inc(ctx.codegen.variable_count);
    id := ctx.codegen.variable_count;
    ctx.codegen.variables[id].symbol_id := symbol_id;
    ctx.codegen.variables[id].storage := storage;
    ctx.codegen.variables[id].scope_id := ctx.sema.symbols[symbol_id].scope_id;
    ctx.codegen.variables[id].stack_offset := 0;
    ctx.codegen.variables[id].global_index := 0;
    ctx.codegen.variables[id].upvalue_index := 0;
    ctx.codegen.variables[id].first_token :=
      ctx.sema.symbols[symbol_id].decl_token;
    ctx.codegen.variables[id].line := ctx.sema.symbols[symbol_id].line;
    Case storage Of
      VSK_GLOBAL:
        Begin
          Inc(ctx.codegen.global_slot_count);
          ctx.codegen.variables[id].global_index :=
            ctx.codegen.global_slot_count;
        End;
      VSK_LOCAL:
        Begin
          Inc(ctx.codegen.local_slot_count);
          ctx.codegen.variables[id].stack_offset :=
            -4 * ctx.codegen.local_slot_count;
        End;
      VSK_PARAM:
        Begin
          Inc(ctx.codegen.param_slot_count);
          ctx.codegen.variables[id].stack_offset :=
            8 + (4 * (ctx.codegen.param_slot_count - 1));
        End;
      VSK_UPVALUE:
        Begin
          Inc(ctx.codegen.upvalue_slot_count);
          ctx.codegen.variables[id].upvalue_index :=
            ctx.codegen.upvalue_slot_count;
          ctx.codegen.variables[id].stack_offset :=
            -4 * (ctx.codegen.local_slot_count +
                  ctx.codegen.upvalue_slot_count);
        End;
    Else
    End;
    AddVariable := id;
  End;

  Procedure AddVarOp(kind: TVarOpKind; variable_id, token, aux: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.codegen.varop_count >= MAX_VAR_OPS Then
      Begin
        ParseErrorAtToken(ctx, token, 'trop d''operations variables Lua');
        Exit;
      End;
    Inc(ctx.codegen.varop_count);
    id := ctx.codegen.varop_count;
    ctx.codegen.varops[id].kind := kind;
    ctx.codegen.varops[id].variable_id := variable_id;
    ctx.codegen.varops[id].token := token;
    ctx.codegen.varops[id].aux := aux;
    If (token >= 1) And (token <= ctx.lex.token_count) Then
      ctx.codegen.varops[id].line := ctx.lex.tokens[token].line
    Else
      ctx.codegen.varops[id].line := 1;
    Case kind Of
      VOP_INIT_NIL:     Inc(ctx.codegen.nil_init_count);
      VOP_LOAD:         Inc(ctx.codegen.load_count);
      VOP_STORE:        Inc(ctx.codegen.store_count);
      VOP_MULTI_ASSIGN: Inc(ctx.codegen.multi_assign_count);
    Else
    End;
  End;

  Function StatementEnd(pos: LongInt): LongInt;
  Var
    start_line: LongInt;
    paren_depth, brace_depth, bracket_depth, func_depth: Integer;
  Begin
    start_line := ctx.lex.tokens[pos].line;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    func_depth := 0;
    While (pos <= ctx.lex.token_count) And
          (ctx.lex.tokens[pos].kind <> TK_EOF) Do
      Begin
        If (paren_depth = 0) And (brace_depth = 0) And
           (bracket_depth = 0) And (func_depth = 0) Then
          Begin
            If TokenTextAt(ctx, pos, ';') Then
              Begin
                Inc(pos);
                Break;
              End;
            If (ctx.lex.tokens[pos].line <> start_line) And
               (Not TokenTextAt(ctx, pos, '.')) And
               (Not TokenTextAt(ctx, pos, ',')) And
               (Not TokenTextAt(ctx, pos, '..')) And
               (Not TokenTextAt(ctx, pos, ')')) And
               (Not TokenTextAt(ctx, pos, ']')) And
               (Not TokenTextAt(ctx, pos, '}')) Then
              Break;
            If TokenIsKeyword(ctx, pos, 'end') Or
               TokenIsKeyword(ctx, pos, 'else') Or
               TokenIsKeyword(ctx, pos, 'elseif') Or
               TokenIsKeyword(ctx, pos, 'until') Then
              Break;
          End;
        If TokenIsKeyword(ctx, pos, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, pos, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If TokenTextAt(ctx, pos, '(') Then
          Inc(paren_depth)
        Else If TokenTextAt(ctx, pos, ')') And (paren_depth > 0) Then
          Dec(paren_depth)
        Else If TokenTextAt(ctx, pos, '{') Then
          Inc(brace_depth)
        Else If TokenTextAt(ctx, pos, '}') And (brace_depth > 0) Then
          Dec(brace_depth)
        Else If TokenTextAt(ctx, pos, '[') Then
          Inc(bracket_depth)
        Else If TokenTextAt(ctx, pos, ']') And (bracket_depth > 0) Then
          Dec(bracket_depth);
        Inc(pos);
      End;
    StatementEnd := pos;
  End;

  Function FindLevelToken(first_token, last_token: LongInt;
                          text: TTokenText): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth, func_depth: LongInt;
  Begin
    FindLevelToken := 0;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    func_depth := 0;
    For p := first_token To last_token Do
      Begin
        If TokenIsKeyword(ctx, p, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, p, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If func_depth = 0 Then
          Begin
            If TokenTextAt(ctx, p, '(') Then
              Inc(paren_depth)
            Else If TokenTextAt(ctx, p, ')') And (paren_depth > 0) Then
              Dec(paren_depth)
            Else If TokenTextAt(ctx, p, '{') Then
              Inc(brace_depth)
            Else If TokenTextAt(ctx, p, '}') And (brace_depth > 0) Then
              Dec(brace_depth)
            Else If TokenTextAt(ctx, p, '[') Then
              Inc(bracket_depth)
            Else If TokenTextAt(ctx, p, ']') And (bracket_depth > 0) Then
              Dec(bracket_depth)
            Else If (paren_depth = 0) And (brace_depth = 0) And
                    (bracket_depth = 0) And
                    (ctx.lex.tokens[p].kind <> TK_STRING) And
                    TokenTextAt(ctx, p, text) Then
              Begin
                FindLevelToken := p;
                Exit;
              End;
          End;
      End;
  End;

  Function CountTopLevelNames(first_token, last_token: LongInt): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth: LongInt;
    count: LongInt;
  Begin
    count := 0;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    For p := first_token To last_token Do
      Begin
        If TokenTextAt(ctx, p, '(') Then
          Inc(paren_depth)
        Else If TokenTextAt(ctx, p, ')') And (paren_depth > 0) Then
          Dec(paren_depth)
        Else If TokenTextAt(ctx, p, '{') Then
          Inc(brace_depth)
        Else If TokenTextAt(ctx, p, '}') And (brace_depth > 0) Then
          Dec(brace_depth)
        Else If TokenTextAt(ctx, p, '[') Then
          Inc(bracket_depth)
        Else If TokenTextAt(ctx, p, ']') And (bracket_depth > 0) Then
          Dec(bracket_depth)
        Else If (paren_depth = 0) And (brace_depth = 0) And
                (bracket_depth = 0) And
                (ctx.lex.tokens[p].kind = TK_IDENT) And
                (Not TokenTextAt(ctx, p - 1, '.')) And
                (Not TokenTextAt(ctx, p - 1, ':')) Then
          Inc(count);
      End;
    CountTopLevelNames := count;
  End;

  Procedure ScanMultiAssignments;
  Var
    p, stmt_end, eq_pos, lhs_count: LongInt;
  Begin
    p := 1;
    While (p <= ctx.lex.token_count) And
          (ctx.lex.tokens[p].kind <> TK_EOF) Do
      Begin
        stmt_end := StatementEnd(p);
        eq_pos := FindLevelToken(p, stmt_end - 1, '=');
        If eq_pos <> 0 Then
          Begin
            lhs_count := CountTopLevelNames(p, eq_pos - 1);
            If lhs_count > 1 Then
              Begin
                AddVarOp(VOP_MULTI_ASSIGN, 0, eq_pos, lhs_count);
                Inc(ctx.codegen.permute_temp_count, lhs_count);
              End;
          End;
        If stmt_end <= p Then
          Inc(p)
        Else
          p := stmt_end;
      End;
  End;

Var
  i, var_id: LongInt;
  storage: TVarStorageKind;
Begin
  BuildVariableCodePlan := False;
  FillChar(ctx.codegen, SizeOf(ctx.codegen), 0);

  For i := 1 To ctx.sema.symbol_count Do
    Begin
      storage := StorageForSymbol(ctx.sema.symbols[i]);
      var_id := AddVariable(i, storage);
      If var_id <> 0 Then
        Begin
          If storage <> VSK_PARAM Then
            AddVarOp(VOP_INIT_NIL, var_id,
                     ctx.sema.symbols[i].decl_token, 0);
          If ctx.sema.symbols[i].assigned Then
            AddVarOp(VOP_STORE, var_id,
                     ctx.sema.symbols[i].decl_token, 0);
          If ctx.sema.symbols[i].use_count > 0 Then
            AddVarOp(VOP_LOAD, var_id,
                     ctx.sema.symbols[i].first_use,
                     ctx.sema.symbols[i].use_count);
        End;
    End;

  ScanMultiAssignments;

  If ctx.options.verbose Then
    Writeln('Plan variables 80386: variables=', ctx.codegen.variable_count,
            ', ops=', ctx.codegen.varop_count,
            ' (globaux=', ctx.codegen.global_slot_count,
            ', locaux=', ctx.codegen.local_slot_count,
            ', params=', ctx.codegen.param_slot_count,
            ', upvalues=', ctx.codegen.upvalue_slot_count,
            ', init-nil=', ctx.codegen.nil_init_count,
            ', load=', ctx.codegen.load_count,
            ', store=', ctx.codegen.store_count,
            ', multi-assign=', ctx.codegen.multi_assign_count,
            ', temporaires=', ctx.codegen.permute_temp_count, ')');

  BuildVariableCodePlan := ctx.errors = 0;
End;

Function AlignTo(value: LongInt; align: Integer): LongInt;
Begin
  If align <= 1 Then
    AlignTo := value
  Else If (value Mod align) = 0 Then
    AlignTo := value
  Else
    AlignTo := value + (align - (value Mod align));
End;

Function BuildConstantPool(Var ctx: TCompilerContext): Boolean;

  Function SectionSize(section: TDataSectionKind): LongInt;
  Begin
    Case section Of
      DSK_RDATA: SectionSize := ctx.datapool.rdata_size;
      DSK_DATA:  SectionSize := ctx.datapool.data_size;
      DSK_BSS:   SectionSize := ctx.datapool.bss_size;
    Else
      SectionSize := 0;
    End;
  End;

  Procedure SetSectionSize(section: TDataSectionKind; value: LongInt);
  Begin
    Case section Of
      DSK_RDATA: ctx.datapool.rdata_size := value;
      DSK_DATA:  ctx.datapool.data_size := value;
      DSK_BSS:   ctx.datapool.bss_size := value;
    Else
    End;
  End;

  Function FindConstant(kind: TConstKind; text: TTokenText): LongInt;
  Var
    i: LongInt;
  Begin
    FindConstant := 0;
    For i := 1 To ctx.datapool.constant_count Do
      If (ctx.datapool.constants[i].kind = kind) And
         (UpperStr(ctx.datapool.constants[i].text) = UpperStr(text)) Then
        Begin
          FindConstant := i;
          Exit;
        End;
  End;

  Function AddConstant(kind: TConstKind; text: TTokenText;
                       section: TDataSectionKind; size: LongInt;
                       align: Integer; token: LongInt): LongInt;
  Var
    id, existing, offset, cur_size: LongInt;
  Begin
    AddConstant := 0;
    existing := FindConstant(kind, text);
    If existing <> 0 Then
      Begin
        AddConstant := existing;
        Exit;
      End;
    If ctx.datapool.constant_count >= MAX_CONSTANTS Then
      Begin
        ParseErrorAtToken(ctx, token, 'trop de constantes Lua');
        Exit;
      End;
    cur_size := SectionSize(section);
    offset := AlignTo(cur_size, align);
    SetSectionSize(section, offset + size);
    Inc(ctx.datapool.constant_count);
    id := ctx.datapool.constant_count;
    ctx.datapool.constants[id].kind := kind;
    ctx.datapool.constants[id].text := text;
    ctx.datapool.constants[id].section := section;
    ctx.datapool.constants[id].offset := offset;
    ctx.datapool.constants[id].size := size;
    ctx.datapool.constants[id].align := align;
    ctx.datapool.constants[id].token := token;
    If (token >= 1) And (token <= ctx.lex.token_count) Then
      ctx.datapool.constants[id].line := ctx.lex.tokens[token].line
    Else
      ctx.datapool.constants[id].line := 1;
    Case kind Of
      CPK_NUMBER:        Inc(ctx.datapool.number_count);
      CPK_STRING:        Inc(ctx.datapool.string_count);
      CPK_TABLE_META:    Inc(ctx.datapool.table_meta_count);
      CPK_FUNCTION_META: Inc(ctx.datapool.function_meta_count);
      CPK_SYMBOL_NAME:   Inc(ctx.datapool.symbol_name_count);
    Else
    End;
    AddConstant := id;
  End;

  Function FindImport(module_name, symbol_name: TTokenText): LongInt;
  Var
    i: LongInt;
  Begin
    FindImport := 0;
    For i := 1 To ctx.datapool.import_count Do
      If (UpperStr(ctx.datapool.imports[i].module_name) =
          UpperStr(module_name)) And
         (UpperStr(ctx.datapool.imports[i].symbol_name) =
          UpperStr(symbol_name)) Then
        Begin
          FindImport := i;
          Exit;
        End;
  End;

  Procedure AddImport(module_name, symbol_name: TTokenText);
  Var
    id: LongInt;
  Begin
    If FindImport(module_name, symbol_name) <> 0 Then
      Exit;
    If ctx.datapool.import_count >= MAX_IMPORTS Then
      Begin
        PipelineError(ctx, 'trop de symboles importes');
        Exit;
      End;
    Inc(ctx.datapool.import_count);
    id := ctx.datapool.import_count;
    ctx.datapool.imports[id].module_name := module_name;
    ctx.datapool.imports[id].symbol_name := symbol_name;
    ctx.datapool.imports[id].thunk_name := '__imp_' + symbol_name;
    ctx.datapool.imports[id].index := id;
  End;

  Function StringConstSize(text: TTokenText): LongInt;
  Begin
    StringConstSize := AlignTo(8 + Length(text) + 1, COFF_ALIGN_RDATA);
  End;

  Procedure AddTokenConstants;
  Var
    i: LongInt;
  Begin
    For i := 1 To ctx.lex.token_count Do
      Begin
        If ctx.lex.tokens[i].kind = TK_NUMBER Then
          AddConstant(CPK_NUMBER, ctx.lex.tokens[i].text, DSK_RDATA,
                      8, 8, i)
        Else If ctx.lex.tokens[i].kind = TK_STRING Then
          AddConstant(CPK_STRING, ctx.lex.tokens[i].text, DSK_RDATA,
                      StringConstSize(ctx.lex.tokens[i].text),
                      COFF_ALIGN_RDATA, i)
        Else If TokenIsKeyword(ctx, i, 'nil') Then
          AddConstant(CPK_NIL, 'nil', DSK_RDATA, 4, COFF_ALIGN_RDATA, i)
        Else If TokenIsKeyword(ctx, i, 'true') Then
          AddConstant(CPK_BOOL, 'true', DSK_RDATA, 4, COFF_ALIGN_RDATA, i)
        Else If TokenIsKeyword(ctx, i, 'false') Then
          AddConstant(CPK_BOOL, 'false', DSK_RDATA, 4, COFF_ALIGN_RDATA, i);
      End;
  End;

  Procedure AddMetadataConstants;
  Var
    i: LongInt;
    name: TTokenText;
  Begin
    For i := 1 To ctx.parse.expr_count Do
      Begin
        If ctx.parse.expressions[i].kind = EK_TABLE Then
          Begin
            Str(i, name);
            AddConstant(CPK_TABLE_META, 'table#' + name, DSK_DATA,
                        16, COFF_ALIGN_DATA,
                        ctx.parse.expressions[i].first_token);
          End
        Else If ctx.parse.expressions[i].kind = EK_FUNCTION Then
          Begin
            Str(i, name);
            AddConstant(CPK_FUNCTION_META, 'closure#' + name, DSK_DATA,
                        24, COFF_ALIGN_DATA,
                        ctx.parse.expressions[i].first_token);
          End;
      End;
    For i := 1 To ctx.sema.symbol_count Do
      If ctx.sema.symbols[i].kind <> SYK_BUILTIN Then
        AddConstant(CPK_SYMBOL_NAME, ctx.sema.symbols[i].name, DSK_RDATA,
                    StringConstSize(ctx.sema.symbols[i].name),
                    COFF_ALIGN_RDATA, ctx.sema.symbols[i].decl_token);
  End;

  Procedure ReserveBssForGlobals;
  Var
    i: LongInt;
  Begin
    For i := 1 To ctx.codegen.variable_count Do
      If ctx.codegen.variables[i].storage = VSK_GLOBAL Then
        ctx.datapool.bss_size := AlignTo(ctx.datapool.bss_size,
                                         COFF_ALIGN_BSS) + 4;
  End;

  Procedure AddRuntimeImports;
  Begin
    AddImport('kernel32.dll', 'ExitProcess');
    AddImport('kernel32.dll', 'GetStdHandle');
    AddImport('kernel32.dll', 'WriteFile');
    AddImport('kernel32.dll', 'HeapAlloc');
    AddImport('kernel32.dll', 'HeapFree');
    AddImport('kernel32.dll', 'GetProcessHeap');
    AddImport('msvcrt.dll', 'printf');
    AddImport('msvcrt.dll', 'sprintf');
    AddImport('msvcrt.dll', 'strlen');
    AddImport('msvcrt.dll', 'strcmp');
    AddImport('msvcrt.dll', 'strcpy');
    AddImport('msvcrt.dll', 'strcat');
    AddImport('msvcrt.dll', 'malloc');
    AddImport('msvcrt.dll', 'free');
    AddImport('msvcrt.dll', 'pow');
    AddImport('msvcrt.dll', 'floor');
  End;

Begin
  BuildConstantPool := False;
  FillChar(ctx.datapool, SizeOf(ctx.datapool), 0);
  ctx.datapool.rdata_align := COFF_ALIGN_RDATA;
  ctx.datapool.data_align := COFF_ALIGN_DATA;
  ctx.datapool.bss_align := COFF_ALIGN_BSS;

  AddTokenConstants;
  AddMetadataConstants;
  ReserveBssForGlobals;
  AddRuntimeImports;

  ctx.datapool.rdata_size := AlignTo(ctx.datapool.rdata_size,
                                     ctx.datapool.rdata_align);
  ctx.datapool.data_size := AlignTo(ctx.datapool.data_size,
                                    ctx.datapool.data_align);
  ctx.datapool.bss_size := AlignTo(ctx.datapool.bss_size,
                                   ctx.datapool.bss_align);

  If ctx.options.verbose Then
    Writeln('Pool donnees COFF/PE: constantes=', ctx.datapool.constant_count,
            ', imports=', ctx.datapool.import_count,
            ' (nombres=', ctx.datapool.number_count,
            ', chaines=', ctx.datapool.string_count,
            ', tables-meta=', ctx.datapool.table_meta_count,
            ', fonctions-meta=', ctx.datapool.function_meta_count,
            ', noms-symboles=', ctx.datapool.symbol_name_count,
            ', .rdata=', ctx.datapool.rdata_size,
            ', .data=', ctx.datapool.data_size,
            ', .bss=', ctx.datapool.bss_size, ')');

  BuildConstantPool := ctx.errors = 0;
End;

Function RunPipeline(Var ctx: TCompilerContext): Boolean;
Var
  s: TCompileStage;
Begin
  RunPipeline := False;
  For s := CS_LOAD_SOURCE To CS_LINK_EXE Do
    Begin
      ctx.stage := s;
      If ctx.options.verbose Then
        Writeln('Etape ', StageName(s), ' -> ',
                ArtifactName(StageOutputArtifact(s)));
      Case s Of
        CS_LOAD_SOURCE:
          If Not LoadSource(ctx) Then
            Exit;
        CS_LEX_TOKENS:
          If Not LexSource(ctx) Then
            Exit;
        CS_PARSE_AST:
          Begin
            If Not ParseAst(ctx) Then
              Exit;
            If Not BuildRuntimeModel(ctx) Then
              Exit;
            If Not BuildSymbolTable(ctx) Then
              Exit;
            If Not BuildVariableCodePlan(ctx) Then
              Exit;
            If Not BuildConstantPool(ctx) Then
              Exit;
          End;
      Else
        Begin
          ctx.last_art := StageOutputArtifact(s);
          Writeln('LUACW32: TODO 11+ requis avant de compiler reellement ',
                  ctx.source_name);
          Inc(ctx.errors);
          Exit;
        End;
      End;
      If ctx.last_art = PipelineTargetArtifact(ctx) Then
        Break;
    End;
  RunPipeline := ctx.errors = 0;
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
      PrintPipeline;
      Writeln('LUACW32: TODO 24 requis pour executer -test.');
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
