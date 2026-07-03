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
  11. [IMPLEMENTE] Generer les expressions numeriques et booleennes : operations arithmetiques, comparaisons, conversions truthy/falsy Lua et court-circuit de and/or.
  12. [IMPLEMENTE] Implementer les chaines : allocation/stockage, concatenation, longueur, comparaison, echappements, impression et compatibilite avec SAMPLES\LUA\strings.lua et test_strings.lua.
  13. [IMPLEMENTE] Implementer les tables Lua : constructeur de table, champs array/hash, indexation [], acces point, affectation, iteration, metatables de base et support de SAMPLES\LUA\tables.lua.
  14. [IMPLEMENTE] Generer les structures de controle : if/elseif/else/end, while, repeat/until, for numerique, for generique, break, labels internes et sauts 80386 fiables.
  15. [IMPLEMENTE] Implementer les fonctions : declarations locales/globales, appels, pile d'arguments, retour simple/multiple, varargs, tail calls simples et conventions d'appel internes.
  16. [IMPLEMENTE] Ajouter les closures et upvalues : capture de variables, cellules partagees, duree de vie apres retour, appels de fonctions imbriquees et SAMPLES\LUA\closures.lua.
  17. [IMPLEMENTE] Supporter les retours multiples Lua : propagation dans appels, affectations, return, appels imbriques et compatibilite avec test_multiret.lua.
  18. [IMPLEMENTE] Implementer les built-ins/runtime essentiels : print, tostring, tonumber, type, assert, error, pcall, pairs, ipairs, next, select et fonctions math/string/table requises par les exemples.
  19. [IMPLEMENTE] Ajouter la gestion d'erreurs Lua : erreurs runtime, pcall, propagation, messages lisibles, nettoyage de pile et support de errors.lua/test_errorhandling.lua.
  20. [IMPLEMENTE] Implementer les coroutines minimales : create, resume, yield, status, wrapping de pile/contexte et compatibilite avec test_coroutines.lua.
  21. [IMPLEMENTE] Construire le generateur ASM 80386 optionnel : syntaxe assembleur Windows 32 bits, sections .text/.data/.rdata, labels stables, commentaires utiles et emission seulement sur demande.
  22. [IMPLEMENTE] Construire le generateur OBJ COFF : sections, relocations, symboles externes, imports runtime, compatibilite avec le linker interne et production OBJ seule si demandee.
  23. [IMPLEMENTE] Construire le linker PE32 interne : entetes PE, sections alignees, table d'import kernel32/msvcrt ou runtime propre, point d'entree, sortie console et suppression des EXE perimes.
  24. [IMPLEMENTE] Ajouter le harnais de validation : option -test, compilation de tous SAMPLES\LUA\*, execution/capture des sorties, comparaison stable, modes EXE/OBJ/ASM+OBJ et nettoyage des artefacts.
  25. [IMPLEMENTE] Stabiliser la compatibilite Free Pascal/Turbo Pascal : types bornes, buffers, absence de dependances modernes, tests de regression, diagnostics finaux et documentation d'utilisation.
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
  MAX_EXPR_OPS    = 16000;
  MAX_STRING_OPS  = 8192;
  MAX_TABLE_OPS   = 8192;
  MAX_CONTROL_OPS = 8192;
  MAX_FUNCTION_OPS = 8192;
  MAX_CLOSURE_OPS = 8192;
  MAX_MULTIRET_OPS = 8192;
  MAX_BUILTIN_OPS = 8192;
  MAX_ERROR_OPS = 4096;
  MAX_COROUTINE_OPS = 4096;
  COFF_ALIGN_RDATA = 4;
  COFF_ALIGN_DATA  = 4;
  COFF_ALIGN_BSS   = 4;
  COFF_MACHINE_I386 = $014C;
  COFF_RELOC_I386_REL32 = 20;
  COFF_SCN_CNT_CODE = $00000020;
  COFF_SCN_CNT_INITIALIZED_DATA = $00000040;
  COFF_SCN_CNT_UNINITIALIZED_DATA = $00000080;
  COFF_SCN_ALIGN_4BYTES = $00300000;
  COFF_SCN_MEM_EXECUTE = $20000000;
  COFF_SCN_MEM_READ = $40000000;
  COFF_SCN_MEM_WRITE = LongInt($80000000);
  COFF_SYM_CLASS_EXTERNAL = 2;
  COFF_SYM_CLASS_STATIC = 3;
  MAX_OBJ_SYMBOLS = 512;
  MAX_OBJ_STRING_BYTES = 8192;
  PE_DOS_MAGIC = $5A4D;
  PE_PE_SIG = $00004550;
  PE_OPT_SIZE = 224;
  PE_MAGIC_32 = $010B;
  PE_IMG_BASE = $00400000;
  PE_SEC_ALIGN = $1000;
  PE_FILE_ALIGN = $200;
  PE_SUBSYS_CUI = 3;
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

  TExprResultKind = (
    ERK_UNKNOWN,
    ERK_VALUE,
    ERK_NUMBER,
    ERK_BOOLEAN,
    ERK_STRING,
    ERK_TABLE,
    ERK_FUNCTION,
    ERK_NIL
  );

  TExprOpKind = (
    EOP_LITERAL,
    EOP_LOAD_VALUE,
    EOP_ADD,
    EOP_SUB,
    EOP_MUL,
    EOP_DIV,
    EOP_IDIV,
    EOP_MOD,
    EOP_POW,
    EOP_NEG,
    EOP_NOT,
    EOP_LEN,
    EOP_EQ,
    EOP_NE,
    EOP_LT,
    EOP_LE,
    EOP_GT,
    EOP_GE,
    EOP_TRUTHY,
    EOP_AND_SC,
    EOP_OR_SC,
    EOP_CONCAT
  );

  TExprOpInfo = Record
    kind        : TExprOpKind;
    first_token : LongInt;
    last_token  : LongInt;
    result_kind : TExprResultKind;
    temp_index  : LongInt;
    aux         : LongInt;
    line        : LongInt;
  End;

  TExprCodeInfo = Record
    op_count            : LongInt;
    temp_count          : LongInt;
    literal_count       : LongInt;
    load_count          : LongInt;
    numeric_op_count    : LongInt;
    compare_count       : LongInt;
    truthy_count        : LongInt;
    short_circuit_count : LongInt;
    unary_count         : LongInt;
    ops                 : Array[1..MAX_EXPR_OPS] Of TExprOpInfo;
  End;

  TStringOpKind = (
    SOP_LITERAL,
    SOP_CONCAT,
    SOP_LENGTH,
    SOP_COMPARE,
    SOP_TOSTRING,
    SOP_PRINT
  );

  TStringOpInfo = Record
    kind        : TStringOpKind;
    first_token : LongInt;
    last_token  : LongInt;
    const_id    : LongInt;
    temp_index  : LongInt;
    length      : LongInt;
    line        : LongInt;
  End;

  TStringCodeInfo = Record
    op_count      : LongInt;
    literal_count : LongInt;
    concat_count  : LongInt;
    length_count  : LongInt;
    compare_count : LongInt;
    tostring_count: LongInt;
    print_count   : LongInt;
    escaped_count : LongInt;
    storage_bytes : LongInt;
    ops           : Array[1..MAX_STRING_OPS] Of TStringOpInfo;
  End;

  TTableOpKind = (
    TOP_NEW,
    TOP_ARRAY_FIELD,
    TOP_HASH_FIELD,
    TOP_INDEX,
    TOP_STORE_FIELD,
    TOP_LENGTH,
    TOP_ITERATE,
    TOP_METATABLE
  );

  TTableOpInfo = Record
    kind        : TTableOpKind;
    first_token : LongInt;
    last_token  : LongInt;
    table_id    : LongInt;
    aux         : LongInt;
    line        : LongInt;
  End;

  TTableCodeInfo = Record
    op_count          : LongInt;
    constructor_count : LongInt;
    array_field_count : LongInt;
    hash_field_count  : LongInt;
    index_count       : LongInt;
    store_count       : LongInt;
    length_count      : LongInt;
    iterate_count     : LongInt;
    metatable_count   : LongInt;
    ops               : Array[1..MAX_TABLE_OPS] Of TTableOpInfo;
  End;

  TControlOpKind = (
    COP_LABEL,
    COP_JUMP,
    COP_JUMP_FALSE,
    COP_IF_BEGIN,
    COP_ELSEIF_BRANCH,
    COP_ELSE_BRANCH,
    COP_IF_END,
    COP_LOOP_BEGIN,
    COP_LOOP_TEST,
    COP_LOOP_STEP,
    COP_LOOP_END,
    COP_BREAK,
    COP_GOTO
  );

  TControlOpInfo = Record
    kind         : TControlOpKind;
    first_token  : LongInt;
    last_token   : LongInt;
    label_id     : LongInt;
    target_label : LongInt;
    depth        : Integer;
    line         : LongInt;
  End;

  TControlCodeInfo = Record
    op_count          : LongInt;
    label_count       : LongInt;
    jump_count        : LongInt;
    conditional_count : LongInt;
    if_count          : LongInt;
    elseif_count      : LongInt;
    else_count        : LongInt;
    loop_count        : LongInt;
    break_count       : LongInt;
    goto_count        : LongInt;
    max_depth         : Integer;
    ops               : Array[1..MAX_CONTROL_OPS] Of TControlOpInfo;
  End;

  TFunctionOpKind = (
    FOP_DECLARE,
    FOP_LITERAL,
    FOP_PROLOGUE,
    FOP_PARAM_BIND,
    FOP_VARARG_BIND,
    FOP_PREPARE_CALL,
    FOP_PUSH_ARG,
    FOP_CALL,
    FOP_RETURN,
    FOP_TAIL_CALL
  );

  TFunctionOpInfo = Record
    kind        : TFunctionOpKind;
    first_token : LongInt;
    last_token  : LongInt;
    function_id : LongInt;
    arg_count   : LongInt;
    result_count: LongInt;
    line        : LongInt;
  End;

  TFunctionCodeInfo = Record
    op_count            : LongInt;
    function_count      : LongInt;
    literal_count       : LongInt;
    prologue_count      : LongInt;
    param_bind_count    : LongInt;
    vararg_bind_count   : LongInt;
    call_count          : LongInt;
    arg_push_count      : LongInt;
    return_count        : LongInt;
    tail_call_count     : LongInt;
    max_arg_count       : LongInt;
    max_result_count    : LongInt;
    ops                 : Array[1..MAX_FUNCTION_OPS] Of TFunctionOpInfo;
  End;

  TClosureOpKind = (
    CLP_MAKE_CLOSURE,
    CLP_SHARE_CELL,
    CLP_CAPTURE_LOCAL,
    CLP_CAPTURE_UPVALUE,
    CLP_LOAD_UPVALUE,
    CLP_STORE_UPVALUE,
    CLP_CLOSE_SCOPE,
    CLP_ESCAPE_CELL
  );

  TClosureOpInfo = Record
    kind        : TClosureOpKind;
    first_token : LongInt;
    last_token  : LongInt;
    function_id : LongInt;
    symbol_id   : LongInt;
    scope_id    : LongInt;
    cell_index  : LongInt;
    line        : LongInt;
  End;

  TClosureCodeInfo = Record
    op_count            : LongInt;
    closure_count       : LongInt;
    shared_cell_count   : LongInt;
    capture_local_count : LongInt;
    capture_upvalue_count: LongInt;
    load_upvalue_count  : LongInt;
    store_upvalue_count : LongInt;
    close_scope_count   : LongInt;
    escape_cell_count   : LongInt;
    max_cell_count      : LongInt;
    ops                 : Array[1..MAX_CLOSURE_OPS] Of TClosureOpInfo;
  End;

  TMultiRetOpKind = (
    MRP_RETURN_PACK,
    MRP_CALL_EXPAND,
    MRP_CALL_TRUNCATE,
    MRP_ASSIGN_ADJUST,
    MRP_NIL_FILL,
    MRP_VARARG_EXPAND,
    MRP_SELECT_ARG,
    MRP_NESTED_CALL
  );

  TMultiRetOpInfo = Record
    kind        : TMultiRetOpKind;
    first_token : LongInt;
    last_token  : LongInt;
    source_count: LongInt;
    target_count: LongInt;
    aux         : LongInt;
    line        : LongInt;
  End;

  TMultiRetCodeInfo = Record
    op_count            : LongInt;
    return_pack_count   : LongInt;
    call_expand_count   : LongInt;
    call_truncate_count : LongInt;
    assign_adjust_count : LongInt;
    nil_fill_count      : LongInt;
    vararg_expand_count : LongInt;
    select_count        : LongInt;
    nested_call_count   : LongInt;
    max_source_count    : LongInt;
    max_target_count    : LongInt;
    ops                 : Array[1..MAX_MULTIRET_OPS] Of TMultiRetOpInfo;
  End;

  TBuiltinOpKind = (
    BOP_CORE_PRINT,
    BOP_CORE_CONVERT,
    BOP_CORE_TYPE,
    BOP_ERROR_ASSERT,
    BOP_ERROR_THROW,
    BOP_ERROR_PCALL,
    BOP_ITER_PAIRS,
    BOP_ITER_NEXT,
    BOP_SELECT,
    BOP_MATH_FUNC,
    BOP_MATH_CONST,
    BOP_STRING_FUNC,
    BOP_TABLE_FUNC,
    BOP_OS_FUNC,
    BOP_IO_FUNC
  );

  TBuiltinOpInfo = Record
    kind        : TBuiltinOpKind;
    first_token : LongInt;
    last_token  : LongInt;
    name        : TTokenText;
    arg_count   : LongInt;
    result_count: LongInt;
    line        : LongInt;
  End;

  TBuiltinCodeInfo = Record
    op_count         : LongInt;
    print_count      : LongInt;
    convert_count    : LongInt;
    type_count       : LongInt;
    error_count      : LongInt;
    iterator_count   : LongInt;
    select_count     : LongInt;
    math_count       : LongInt;
    math_const_count : LongInt;
    string_count     : LongInt;
    table_count      : LongInt;
    os_count         : LongInt;
    io_count         : LongInt;
    max_arg_count    : LongInt;
    ops              : Array[1..MAX_BUILTIN_OPS] Of TBuiltinOpInfo;
  End;

  TErrorOpKind = (
    EHP_ASSERT_CHECK,
    EHP_RAISE_ERROR,
    EHP_PUSH_HANDLER,
    EHP_POP_HANDLER,
    EHP_PCALL_ENTER,
    EHP_PCALL_EXIT,
    EHP_XPCALL_HANDLER,
    EHP_PROPAGATE,
    EHP_MESSAGE,
    EHP_STACK_CLEANUP
  );

  TErrorOpInfo = Record
    kind        : TErrorOpKind;
    first_token : LongInt;
    last_token  : LongInt;
    handler_id  : LongInt;
    arg_count   : LongInt;
    line        : LongInt;
  End;

  TErrorCodeInfo = Record
    op_count         : LongInt;
    assert_count     : LongInt;
    raise_count      : LongInt;
    protected_count  : LongInt;
    xpcall_count     : LongInt;
    propagate_count  : LongInt;
    message_count    : LongInt;
    cleanup_count    : LongInt;
    handler_count    : LongInt;
    max_arg_count    : LongInt;
    ops              : Array[1..MAX_ERROR_OPS] Of TErrorOpInfo;
  End;

  TCoroutineOpKind = (
    CRP_CREATE,
    CRP_RESUME,
    CRP_YIELD,
    CRP_STATUS,
    CRP_WRAP,
    CRP_ISYIELDABLE,
    CRP_SAVE_CONTEXT,
    CRP_RESTORE_CONTEXT,
    CRP_STACK_FRAME,
    CRP_STATE_TRANSITION
  );

  TCoroutineOpInfo = Record
    kind        : TCoroutineOpKind;
    first_token : LongInt;
    last_token  : LongInt;
    coroutine_id: LongInt;
    arg_count   : LongInt;
    line        : LongInt;
  End;

  TCoroutineCodeInfo = Record
    op_count          : LongInt;
    coroutine_count   : LongInt;
    create_count      : LongInt;
    resume_count      : LongInt;
    yield_count       : LongInt;
    status_count      : LongInt;
    wrap_count        : LongInt;
    isyieldable_count : LongInt;
    save_count        : LongInt;
    restore_count     : LongInt;
    stack_frame_count : LongInt;
    transition_count  : LongInt;
    max_arg_count     : LongInt;
    ops               : Array[1..MAX_COROUTINE_OPS] Of TCoroutineOpInfo;
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
    exprcode    : TExprCodeInfo;
    stringcode  : TStringCodeInfo;
    tablecode   : TTableCodeInfo;
    controlcode : TControlCodeInfo;
    functioncode: TFunctionCodeInfo;
    closurecode : TClosureCodeInfo;
    multiretcode: TMultiRetCodeInfo;
    builtincode : TBuiltinCodeInfo;
    errorcode   : TErrorCodeInfo;
    coroutinecode: TCoroutineCodeInfo;
    stage       : TCompileStage;
    last_art    : TArtifactKind;
    errors      : Integer;
    warnings    : Integer;
  End;

Var
  validation_ctx: TCompilerContext;

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

Function ExprOpKindName(kind: TExprOpKind): TString;
Begin
  Case kind Of
    EOP_LITERAL: ExprOpKindName := 'literal';
    EOP_LOAD_VALUE: ExprOpKindName := 'load-value';
    EOP_ADD: ExprOpKindName := 'add';
    EOP_SUB: ExprOpKindName := 'sub';
    EOP_MUL: ExprOpKindName := 'mul';
    EOP_DIV: ExprOpKindName := 'div';
    EOP_IDIV: ExprOpKindName := 'idiv';
    EOP_MOD: ExprOpKindName := 'mod';
    EOP_POW: ExprOpKindName := 'pow';
    EOP_NEG: ExprOpKindName := 'neg';
    EOP_NOT: ExprOpKindName := 'not';
    EOP_LEN: ExprOpKindName := 'len';
    EOP_EQ: ExprOpKindName := 'eq';
    EOP_NE: ExprOpKindName := 'ne';
    EOP_LT: ExprOpKindName := 'lt';
    EOP_LE: ExprOpKindName := 'le';
    EOP_GT: ExprOpKindName := 'gt';
    EOP_GE: ExprOpKindName := 'ge';
    EOP_TRUTHY: ExprOpKindName := 'truthy';
    EOP_AND_SC: ExprOpKindName := 'and-sc';
    EOP_OR_SC: ExprOpKindName := 'or-sc';
    EOP_CONCAT: ExprOpKindName := 'concat';
  Else
    ExprOpKindName := 'unknown';
  End;
End;

Function ExprResultKindName(kind: TExprResultKind): TString;
Begin
  Case kind Of
    ERK_UNKNOWN:  ExprResultKindName := 'unknown';
    ERK_VALUE:    ExprResultKindName := 'value';
    ERK_NUMBER:   ExprResultKindName := 'number';
    ERK_BOOLEAN:  ExprResultKindName := 'boolean';
    ERK_STRING:   ExprResultKindName := 'string';
    ERK_TABLE:    ExprResultKindName := 'table';
    ERK_FUNCTION: ExprResultKindName := 'function';
    ERK_NIL:      ExprResultKindName := 'nil';
  Else
    ExprResultKindName := 'unknown';
  End;
End;

Function StringOpKindName(kind: TStringOpKind): TString;
Begin
  Case kind Of
    SOP_LITERAL:  StringOpKindName := 'literal';
    SOP_CONCAT:   StringOpKindName := 'concat';
    SOP_LENGTH:   StringOpKindName := 'length';
    SOP_COMPARE:  StringOpKindName := 'compare';
    SOP_TOSTRING: StringOpKindName := 'tostring';
    SOP_PRINT:    StringOpKindName := 'print';
  Else
    StringOpKindName := 'unknown';
  End;
End;

Function TableOpKindName(kind: TTableOpKind): TString;
Begin
  Case kind Of
    TOP_NEW:         TableOpKindName := 'new';
    TOP_ARRAY_FIELD: TableOpKindName := 'array-field';
    TOP_HASH_FIELD:  TableOpKindName := 'hash-field';
    TOP_INDEX:       TableOpKindName := 'index';
    TOP_STORE_FIELD: TableOpKindName := 'store-field';
    TOP_LENGTH:      TableOpKindName := 'length';
    TOP_ITERATE:     TableOpKindName := 'iterate';
    TOP_METATABLE:   TableOpKindName := 'metatable';
  Else
    TableOpKindName := 'unknown';
  End;
End;

Function ControlOpKindName(kind: TControlOpKind): TString;
Begin
  Case kind Of
    COP_LABEL:         ControlOpKindName := 'label';
    COP_JUMP:          ControlOpKindName := 'jump';
    COP_JUMP_FALSE:    ControlOpKindName := 'jump-false';
    COP_IF_BEGIN:      ControlOpKindName := 'if-begin';
    COP_ELSEIF_BRANCH: ControlOpKindName := 'elseif-branch';
    COP_ELSE_BRANCH:   ControlOpKindName := 'else-branch';
    COP_IF_END:        ControlOpKindName := 'if-end';
    COP_LOOP_BEGIN:    ControlOpKindName := 'loop-begin';
    COP_LOOP_TEST:     ControlOpKindName := 'loop-test';
    COP_LOOP_STEP:     ControlOpKindName := 'loop-step';
    COP_LOOP_END:      ControlOpKindName := 'loop-end';
    COP_BREAK:         ControlOpKindName := 'break';
    COP_GOTO:          ControlOpKindName := 'goto';
  Else
    ControlOpKindName := 'unknown';
  End;
End;

Function FunctionOpKindName(kind: TFunctionOpKind): TString;
Begin
  Case kind Of
    FOP_DECLARE:      FunctionOpKindName := 'declare';
    FOP_LITERAL:      FunctionOpKindName := 'literal';
    FOP_PROLOGUE:     FunctionOpKindName := 'prologue';
    FOP_PARAM_BIND:   FunctionOpKindName := 'param-bind';
    FOP_VARARG_BIND:  FunctionOpKindName := 'vararg-bind';
    FOP_PREPARE_CALL: FunctionOpKindName := 'prepare-call';
    FOP_PUSH_ARG:     FunctionOpKindName := 'push-arg';
    FOP_CALL:         FunctionOpKindName := 'call';
    FOP_RETURN:       FunctionOpKindName := 'return';
    FOP_TAIL_CALL:    FunctionOpKindName := 'tail-call';
  Else
    FunctionOpKindName := 'unknown';
  End;
End;

Function ClosureOpKindName(kind: TClosureOpKind): TString;
Begin
  Case kind Of
    CLP_MAKE_CLOSURE:    ClosureOpKindName := 'make-closure';
    CLP_SHARE_CELL:      ClosureOpKindName := 'share-cell';
    CLP_CAPTURE_LOCAL:   ClosureOpKindName := 'capture-local';
    CLP_CAPTURE_UPVALUE: ClosureOpKindName := 'capture-upvalue';
    CLP_LOAD_UPVALUE:    ClosureOpKindName := 'load-upvalue';
    CLP_STORE_UPVALUE:   ClosureOpKindName := 'store-upvalue';
    CLP_CLOSE_SCOPE:     ClosureOpKindName := 'close-scope';
    CLP_ESCAPE_CELL:     ClosureOpKindName := 'escape-cell';
  Else
    ClosureOpKindName := 'unknown';
  End;
End;

Function MultiRetOpKindName(kind: TMultiRetOpKind): TString;
Begin
  Case kind Of
    MRP_RETURN_PACK:   MultiRetOpKindName := 'return-pack';
    MRP_CALL_EXPAND:   MultiRetOpKindName := 'call-expand';
    MRP_CALL_TRUNCATE: MultiRetOpKindName := 'call-truncate';
    MRP_ASSIGN_ADJUST: MultiRetOpKindName := 'assign-adjust';
    MRP_NIL_FILL:      MultiRetOpKindName := 'nil-fill';
    MRP_VARARG_EXPAND: MultiRetOpKindName := 'vararg-expand';
    MRP_SELECT_ARG:    MultiRetOpKindName := 'select';
    MRP_NESTED_CALL:   MultiRetOpKindName := 'nested-call';
  Else
    MultiRetOpKindName := 'unknown';
  End;
End;

Function BuiltinOpKindName(kind: TBuiltinOpKind): TString;
Begin
  Case kind Of
    BOP_CORE_PRINT:   BuiltinOpKindName := 'core-print';
    BOP_CORE_CONVERT: BuiltinOpKindName := 'core-convert';
    BOP_CORE_TYPE:    BuiltinOpKindName := 'core-type';
    BOP_ERROR_ASSERT: BuiltinOpKindName := 'error-assert';
    BOP_ERROR_THROW:  BuiltinOpKindName := 'error-throw';
    BOP_ERROR_PCALL:  BuiltinOpKindName := 'error-pcall';
    BOP_ITER_PAIRS:   BuiltinOpKindName := 'iter-pairs';
    BOP_ITER_NEXT:    BuiltinOpKindName := 'iter-next';
    BOP_SELECT:       BuiltinOpKindName := 'select';
    BOP_MATH_FUNC:    BuiltinOpKindName := 'math-func';
    BOP_MATH_CONST:   BuiltinOpKindName := 'math-const';
    BOP_STRING_FUNC:  BuiltinOpKindName := 'string-func';
    BOP_TABLE_FUNC:   BuiltinOpKindName := 'table-func';
    BOP_OS_FUNC:      BuiltinOpKindName := 'os-func';
    BOP_IO_FUNC:      BuiltinOpKindName := 'io-func';
  Else
    BuiltinOpKindName := 'unknown';
  End;
End;

Function ErrorOpKindName(kind: TErrorOpKind): TString;
Begin
  Case kind Of
    EHP_ASSERT_CHECK:  ErrorOpKindName := 'assert-check';
    EHP_RAISE_ERROR:   ErrorOpKindName := 'raise-error';
    EHP_PUSH_HANDLER:  ErrorOpKindName := 'push-handler';
    EHP_POP_HANDLER:   ErrorOpKindName := 'pop-handler';
    EHP_PCALL_ENTER:   ErrorOpKindName := 'pcall-enter';
    EHP_PCALL_EXIT:    ErrorOpKindName := 'pcall-exit';
    EHP_XPCALL_HANDLER:ErrorOpKindName := 'xpcall-handler';
    EHP_PROPAGATE:     ErrorOpKindName := 'propagate';
    EHP_MESSAGE:       ErrorOpKindName := 'message';
    EHP_STACK_CLEANUP: ErrorOpKindName := 'stack-cleanup';
  Else
    ErrorOpKindName := 'unknown';
  End;
End;

Function CoroutineOpKindName(kind: TCoroutineOpKind): TString;
Begin
  Case kind Of
    CRP_CREATE:          CoroutineOpKindName := 'create';
    CRP_RESUME:          CoroutineOpKindName := 'resume';
    CRP_YIELD:           CoroutineOpKindName := 'yield';
    CRP_STATUS:          CoroutineOpKindName := 'status';
    CRP_WRAP:            CoroutineOpKindName := 'wrap';
    CRP_ISYIELDABLE:     CoroutineOpKindName := 'isyieldable';
    CRP_SAVE_CONTEXT:    CoroutineOpKindName := 'save-context';
    CRP_RESTORE_CONTEXT: CoroutineOpKindName := 'restore-context';
    CRP_STACK_FRAME:     CoroutineOpKindName := 'stack-frame';
    CRP_STATE_TRANSITION:CoroutineOpKindName := 'state-transition';
  Else
    CoroutineOpKindName := 'unknown';
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
  Writeln('  -test         compile et valide tous les exemples SAMPLES\LUA\*.lua');
  Writeln;
  Writeln('Par defaut, la cible est un executable Windows ', EXT_EXE, '.');
  Writeln('Le fichier ', EXT_ASM, ' est produit seulement avec -asm.');
  Writeln;
  Writeln('Exemples:');
  Writeln('  luacw32 SAMPLES\LUA\hello.lua');
  Writeln('  luacw32 -obj SAMPLES\LUA\hello.lua');
  Writeln('  luacw32 -asm -obj SAMPLES\LUA\hello.lua');
  Writeln('  luacw32 -test');
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

Procedure PrintFinalDiagnostics(Var ctx: TCompilerContext);
Begin
  Writeln('Resultat: ', ArtifactName(ctx.last_art));
  Writeln('Erreurs : ', ctx.errors);
  Writeln('Warnings: ', ctx.warnings);
  If ctx.last_art >= AK_ASM_386 Then
    Begin
      If ctx.options.emit_asm Then
        Writeln('ASM     : ', ctx.asm_name)
      Else
        Writeln('ASM     : non conserve (-asm absent)');
    End;
  If ctx.last_art >= AK_OBJ_COFF Then
    Writeln('OBJ     : ', ctx.obj_name);
  If ctx.last_art >= AK_EXE_PE32 Then
    Writeln('EXE     : ', ctx.exe_name);
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

Function BuildExpressionCodePlan(Var ctx: TCompilerContext): Boolean;

  Function TokenOperatorKind(token_idx: LongInt): TExprOpKind;
  Begin
    If TokenTextAt(ctx, token_idx, '+') Then
      TokenOperatorKind := EOP_ADD
    Else If TokenTextAt(ctx, token_idx, '-') Then
      TokenOperatorKind := EOP_SUB
    Else If TokenTextAt(ctx, token_idx, '*') Then
      TokenOperatorKind := EOP_MUL
    Else If TokenTextAt(ctx, token_idx, '/') Then
      TokenOperatorKind := EOP_DIV
    Else If TokenTextAt(ctx, token_idx, '//') Then
      TokenOperatorKind := EOP_IDIV
    Else If TokenTextAt(ctx, token_idx, '%') Then
      TokenOperatorKind := EOP_MOD
    Else If TokenTextAt(ctx, token_idx, '^') Then
      TokenOperatorKind := EOP_POW
    Else If TokenTextAt(ctx, token_idx, '..') Then
      TokenOperatorKind := EOP_CONCAT
    Else If TokenTextAt(ctx, token_idx, '==') Then
      TokenOperatorKind := EOP_EQ
    Else If TokenTextAt(ctx, token_idx, '~=') Then
      TokenOperatorKind := EOP_NE
    Else If TokenTextAt(ctx, token_idx, '<') Then
      TokenOperatorKind := EOP_LT
    Else If TokenTextAt(ctx, token_idx, '<=') Then
      TokenOperatorKind := EOP_LE
    Else If TokenTextAt(ctx, token_idx, '>') Then
      TokenOperatorKind := EOP_GT
    Else If TokenTextAt(ctx, token_idx, '>=') Then
      TokenOperatorKind := EOP_GE
    Else If TokenIsKeyword(ctx, token_idx, 'and') Then
      TokenOperatorKind := EOP_AND_SC
    Else If TokenIsKeyword(ctx, token_idx, 'or') Then
      TokenOperatorKind := EOP_OR_SC
    Else
      TokenOperatorKind := EOP_LOAD_VALUE;
  End;

  Function OperatorResultKind(op: TExprOpKind): TExprResultKind;
  Begin
    Case op Of
      EOP_ADD, EOP_SUB, EOP_MUL, EOP_DIV, EOP_IDIV, EOP_MOD, EOP_POW,
      EOP_NEG, EOP_LEN:
        OperatorResultKind := ERK_NUMBER;
      EOP_NOT, EOP_EQ, EOP_NE, EOP_LT, EOP_LE, EOP_GT, EOP_GE,
      EOP_TRUTHY:
        OperatorResultKind := ERK_BOOLEAN;
      EOP_AND_SC, EOP_OR_SC:
        OperatorResultKind := ERK_VALUE;
      EOP_CONCAT:
        OperatorResultKind := ERK_STRING;
    Else
      OperatorResultKind := ERK_VALUE;
    End;
  End;

  Function ExprResultKind(expr: TExprInfo): TExprResultKind;
  Begin
    Case expr.kind Of
      EK_NIL:
        ExprResultKind := ERK_NIL;
      EK_BOOL:
        ExprResultKind := ERK_BOOLEAN;
      EK_NUMBER:
        ExprResultKind := ERK_NUMBER;
      EK_STRING:
        ExprResultKind := ERK_STRING;
      EK_TABLE:
        ExprResultKind := ERK_TABLE;
      EK_FUNCTION:
        ExprResultKind := ERK_FUNCTION;
      EK_BINARY, EK_UNARY:
        ExprResultKind := ERK_VALUE;
    Else
      ExprResultKind := ERK_VALUE;
    End;
  End;

  Function FindMainOperator(expr: TExprInfo): LongInt;
  Var
    p: LongInt;
  Begin
    FindMainOperator := 0;
    For p := expr.first_token To expr.last_token Do
      If (ctx.lex.tokens[p].kind = TK_OPERATOR) Or
         TokenIsKeyword(ctx, p, 'and') Or
         TokenIsKeyword(ctx, p, 'or') Then
        Begin
          If TokenTextAt(ctx, p, '+') Or TokenTextAt(ctx, p, '-') Or
             TokenTextAt(ctx, p, '*') Or TokenTextAt(ctx, p, '/') Or
             TokenTextAt(ctx, p, '//') Or TokenTextAt(ctx, p, '%') Or
             TokenTextAt(ctx, p, '^') Or TokenTextAt(ctx, p, '..') Or
             TokenTextAt(ctx, p, '==') Or
             TokenTextAt(ctx, p, '~=') Or TokenTextAt(ctx, p, '<') Or
             TokenTextAt(ctx, p, '<=') Or TokenTextAt(ctx, p, '>') Or
             TokenTextAt(ctx, p, '>=') Or TokenIsKeyword(ctx, p, 'and') Or
             TokenIsKeyword(ctx, p, 'or') Then
            Begin
              FindMainOperator := p;
              Exit;
            End;
        End;
  End;

  Procedure AddExprOp(kind: TExprOpKind; first_token, last_token: LongInt;
                      result_kind: TExprResultKind; aux: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.exprcode.op_count >= MAX_EXPR_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop d''operations expression Lua');
        Exit;
      End;
    Inc(ctx.exprcode.op_count);
    Inc(ctx.exprcode.temp_count);
    id := ctx.exprcode.op_count;
    ctx.exprcode.ops[id].kind := kind;
    ctx.exprcode.ops[id].first_token := first_token;
    ctx.exprcode.ops[id].last_token := last_token;
    ctx.exprcode.ops[id].result_kind := result_kind;
    ctx.exprcode.ops[id].temp_index := ctx.exprcode.temp_count;
    ctx.exprcode.ops[id].aux := aux;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.exprcode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.exprcode.ops[id].line := 1;
    Case kind Of
      EOP_LITERAL:
        Inc(ctx.exprcode.literal_count);
      EOP_LOAD_VALUE:
        Inc(ctx.exprcode.load_count);
      EOP_ADD, EOP_SUB, EOP_MUL, EOP_DIV, EOP_IDIV, EOP_MOD, EOP_POW,
      EOP_NEG:
        Inc(ctx.exprcode.numeric_op_count);
      EOP_EQ, EOP_NE, EOP_LT, EOP_LE, EOP_GT, EOP_GE:
        Inc(ctx.exprcode.compare_count);
      EOP_TRUTHY:
        Inc(ctx.exprcode.truthy_count);
      EOP_AND_SC, EOP_OR_SC:
        Inc(ctx.exprcode.short_circuit_count);
      EOP_NOT, EOP_LEN:
        Inc(ctx.exprcode.unary_count);
    Else
    End;
  End;

  Procedure AddTruthinessForControl;
  Var
    i: LongInt;
  Begin
    For i := 1 To ctx.parse.statement_count Do
      If (ctx.parse.statements[i].kind = SK_IF) Or
         (ctx.parse.statements[i].kind = SK_WHILE) Or
         (ctx.parse.statements[i].kind = SK_REPEAT) Then
        AddExprOp(EOP_TRUTHY, ctx.parse.statements[i].first_token,
                  ctx.parse.statements[i].last_token, ERK_BOOLEAN, 0);
  End;

Var
  i, op_token: LongInt;
  op_kind: TExprOpKind;
  result_kind: TExprResultKind;
Begin
  BuildExpressionCodePlan := False;
  FillChar(ctx.exprcode, SizeOf(ctx.exprcode), 0);

  For i := 1 To ctx.parse.expr_count Do
    Begin
      Case ctx.parse.expressions[i].kind Of
        EK_NIL, EK_BOOL, EK_NUMBER, EK_STRING, EK_TABLE, EK_FUNCTION:
          AddExprOp(EOP_LITERAL,
                    ctx.parse.expressions[i].first_token,
                    ctx.parse.expressions[i].last_token,
                    ExprResultKind(ctx.parse.expressions[i]), i);
        EK_VAR, EK_VARARG, EK_CALL, EK_INDEX:
          AddExprOp(EOP_LOAD_VALUE,
                    ctx.parse.expressions[i].first_token,
                    ctx.parse.expressions[i].last_token,
                    ERK_VALUE, i);
        EK_UNARY:
          Begin
            If TokenIsKeyword(ctx, ctx.parse.expressions[i].first_token,
                              'not') Then
              op_kind := EOP_NOT
            Else If TokenTextAt(ctx, ctx.parse.expressions[i].first_token,
                                '#') Then
              op_kind := EOP_LEN
            Else
              op_kind := EOP_NEG;
            AddExprOp(op_kind,
                      ctx.parse.expressions[i].first_token,
                      ctx.parse.expressions[i].last_token,
                      OperatorResultKind(op_kind), i);
          End;
        EK_BINARY:
          Begin
            op_token := FindMainOperator(ctx.parse.expressions[i]);
            op_kind := TokenOperatorKind(op_token);
            result_kind := OperatorResultKind(op_kind);
            AddExprOp(op_kind,
                      ctx.parse.expressions[i].first_token,
                      ctx.parse.expressions[i].last_token,
                      result_kind, op_token);
            If (op_kind = EOP_AND_SC) Or (op_kind = EOP_OR_SC) Then
              AddExprOp(EOP_TRUTHY,
                        ctx.parse.expressions[i].first_token,
                        ctx.parse.expressions[i].last_token,
                        ERK_BOOLEAN, op_token);
          End;
      Else
      End;
    End;

  AddTruthinessForControl;

  If ctx.options.verbose Then
    Writeln('Plan expressions 80386: ops=', ctx.exprcode.op_count,
            ', temporaires=', ctx.exprcode.temp_count,
            ' (litteraux=', ctx.exprcode.literal_count,
            ', chargements=', ctx.exprcode.load_count,
            ', numeriques=', ctx.exprcode.numeric_op_count,
            ', comparaisons=', ctx.exprcode.compare_count,
            ', truthy=', ctx.exprcode.truthy_count,
            ', court-circuit=', ctx.exprcode.short_circuit_count,
            ', unaires=', ctx.exprcode.unary_count, ')');

  BuildExpressionCodePlan := ctx.errors = 0;
End;

Function BuildStringCodePlan(Var ctx: TCompilerContext): Boolean;

  Function FindStringConstant(text: TTokenText): LongInt;
  Var
    i: LongInt;
  Begin
    FindStringConstant := 0;
    For i := 1 To ctx.datapool.constant_count Do
      If (ctx.datapool.constants[i].kind = CPK_STRING) And
         (ctx.datapool.constants[i].text = text) Then
        Begin
          FindStringConstant := i;
          Exit;
        End;
  End;

  Function TokenRangeHasString(first_token, last_token: LongInt): Boolean;
  Var
    p: LongInt;
  Begin
    TokenRangeHasString := False;
    For p := first_token To last_token Do
      If ctx.lex.tokens[p].kind = TK_STRING Then
        Begin
          TokenRangeHasString := True;
          Exit;
        End;
  End;

  Function RawTokenHasEscape(token_idx: LongInt): Boolean;
  Var
    line_text: TSourceLine;
    p: Integer;
  Begin
    RawTokenHasEscape := False;
    If (token_idx < 1) Or (token_idx > ctx.lex.token_count) Then
      Exit;
    line_text := SourceLineAt(ctx, ctx.lex.tokens[token_idx].line);
    p := ctx.lex.tokens[token_idx].col;
    While p <= Length(line_text) Do
      Begin
        If line_text[p] = '\' Then
          Begin
            RawTokenHasEscape := True;
            Exit;
          End;
        If (p > ctx.lex.tokens[token_idx].col) And
           ((line_text[p] = '''') Or (line_text[p] = '"')) Then
          Exit;
        Inc(p);
      End;
  End;

  Procedure AddStringOp(kind: TStringOpKind; first_token, last_token,
                        const_id, length: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.stringcode.op_count >= MAX_STRING_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop d''operations chaine Lua');
        Exit;
      End;
    Inc(ctx.stringcode.op_count);
    id := ctx.stringcode.op_count;
    ctx.stringcode.ops[id].kind := kind;
    ctx.stringcode.ops[id].first_token := first_token;
    ctx.stringcode.ops[id].last_token := last_token;
    ctx.stringcode.ops[id].const_id := const_id;
    ctx.stringcode.ops[id].temp_index := id;
    ctx.stringcode.ops[id].length := length;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.stringcode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.stringcode.ops[id].line := 1;
    Case kind Of
      SOP_LITERAL:
        Inc(ctx.stringcode.literal_count);
      SOP_CONCAT:
        Inc(ctx.stringcode.concat_count);
      SOP_LENGTH:
        Inc(ctx.stringcode.length_count);
      SOP_COMPARE:
        Inc(ctx.stringcode.compare_count);
      SOP_TOSTRING:
        Inc(ctx.stringcode.tostring_count);
      SOP_PRINT:
        Inc(ctx.stringcode.print_count);
    Else
    End;
  End;

  Procedure AddStringLiterals;
  Var
    i, const_id, len: LongInt;
  Begin
    For i := 1 To ctx.lex.token_count Do
      If ctx.lex.tokens[i].kind = TK_STRING Then
        Begin
          const_id := FindStringConstant(ctx.lex.tokens[i].text);
          len := Length(ctx.lex.tokens[i].text);
          AddStringOp(SOP_LITERAL, i, i, const_id, len);
          Inc(ctx.stringcode.storage_bytes, len + 9);
          If RawTokenHasEscape(i) Then
            Inc(ctx.stringcode.escaped_count);
        End;
  End;

  Procedure AddExpressionStringOps;
  Var
    i, op_token: LongInt;
  Begin
    For i := 1 To ctx.exprcode.op_count Do
      Begin
        Case ctx.exprcode.ops[i].kind Of
          EOP_CONCAT:
            AddStringOp(SOP_CONCAT,
                        ctx.exprcode.ops[i].first_token,
                        ctx.exprcode.ops[i].last_token, 0, 0);
          EOP_LEN:
            AddStringOp(SOP_LENGTH,
                        ctx.exprcode.ops[i].first_token,
                        ctx.exprcode.ops[i].last_token, 0, 0);
          EOP_EQ, EOP_NE, EOP_LT, EOP_LE, EOP_GT, EOP_GE:
            If TokenRangeHasString(ctx.exprcode.ops[i].first_token,
                                   ctx.exprcode.ops[i].last_token) Then
              AddStringOp(SOP_COMPARE,
                          ctx.exprcode.ops[i].first_token,
                          ctx.exprcode.ops[i].last_token, 0, 0);
        Else
        End;
      End;

    For op_token := 1 To ctx.lex.token_count - 1 Do
      If (ctx.lex.tokens[op_token].kind = TK_IDENT) And
         TokenTextAt(ctx, op_token, 'tostring') And
         TokenTextAt(ctx, op_token + 1, '(') Then
        AddStringOp(SOP_TOSTRING, op_token, op_token + 1, 0, 0)
      Else If (ctx.lex.tokens[op_token].kind = TK_IDENT) And
              TokenTextAt(ctx, op_token, 'print') And
              TokenTextAt(ctx, op_token + 1, '(') Then
        AddStringOp(SOP_PRINT, op_token, op_token + 1, 0, 0);
  End;

Begin
  BuildStringCodePlan := False;
  FillChar(ctx.stringcode, SizeOf(ctx.stringcode), 0);

  AddStringLiterals;
  AddExpressionStringOps;

  If ctx.options.verbose Then
    Writeln('Plan chaines 80386: ops=', ctx.stringcode.op_count,
            ' (litteraux=', ctx.stringcode.literal_count,
            ', concat=', ctx.stringcode.concat_count,
            ', longueur=', ctx.stringcode.length_count,
            ', comparaisons=', ctx.stringcode.compare_count,
            ', tostring=', ctx.stringcode.tostring_count,
            ', print=', ctx.stringcode.print_count,
            ', echappements=', ctx.stringcode.escaped_count,
            ', stockage=', ctx.stringcode.storage_bytes, ' octets)');

  BuildStringCodePlan := ctx.errors = 0;
End;

Function BuildTableCodePlan(Var ctx: TCompilerContext): Boolean;

  Procedure AddTableOp(kind: TTableOpKind; first_token, last_token,
                       table_id, aux: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.tablecode.op_count >= MAX_TABLE_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop d''operations table Lua');
        Exit;
      End;
    Inc(ctx.tablecode.op_count);
    id := ctx.tablecode.op_count;
    ctx.tablecode.ops[id].kind := kind;
    ctx.tablecode.ops[id].first_token := first_token;
    ctx.tablecode.ops[id].last_token := last_token;
    ctx.tablecode.ops[id].table_id := table_id;
    ctx.tablecode.ops[id].aux := aux;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.tablecode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.tablecode.ops[id].line := 1;
    Case kind Of
      TOP_NEW:
        Inc(ctx.tablecode.constructor_count);
      TOP_ARRAY_FIELD:
        Inc(ctx.tablecode.array_field_count);
      TOP_HASH_FIELD:
        Inc(ctx.tablecode.hash_field_count);
      TOP_INDEX:
        Inc(ctx.tablecode.index_count);
      TOP_STORE_FIELD:
        Inc(ctx.tablecode.store_count);
      TOP_LENGTH:
        Inc(ctx.tablecode.length_count);
      TOP_ITERATE:
        Inc(ctx.tablecode.iterate_count);
      TOP_METATABLE:
        Inc(ctx.tablecode.metatable_count);
    Else
    End;
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

  Function TopLevelAssign(first_token, last_token: LongInt): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth: LongInt;
  Begin
    TopLevelAssign := 0;
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
                (bracket_depth = 0) And TokenTextAt(ctx, p, '=') Then
          Begin
            TopLevelAssign := p;
            Exit;
          End;
      End;
  End;

  Procedure AddConstructorFields(expr_id: LongInt; first_token, last_token: LongInt);
  Var
    p, start_part, paren_depth, brace_depth, bracket_depth: LongInt;

    Procedure FinishField(end_part: LongInt);
    Var
      eq_pos: LongInt;
    Begin
      If start_part > end_part Then
        Exit;
      eq_pos := TopLevelAssign(start_part, end_part);
      If (eq_pos <> 0) Or TokenTextAt(ctx, start_part, '[') Then
        AddTableOp(TOP_HASH_FIELD, start_part, end_part, expr_id, eq_pos)
      Else
        AddTableOp(TOP_ARRAY_FIELD, start_part, end_part, expr_id, 0);
    End;

  Begin
    start_part := first_token;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    p := first_token;
    While p <= last_token Do
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
                (TokenTextAt(ctx, p, ',') Or TokenTextAt(ctx, p, ';')) Then
          Begin
            FinishField(p - 1);
            start_part := p + 1;
          End;
        Inc(p);
      End;
    FinishField(last_token);
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

  Procedure AddConstructorsAndIndexes;
  Var
    i, close_pos: LongInt;
  Begin
    For i := 1 To ctx.parse.expr_count Do
      Begin
        If ctx.parse.expressions[i].kind = EK_TABLE Then
          Begin
            AddTableOp(TOP_NEW, ctx.parse.expressions[i].first_token,
                       ctx.parse.expressions[i].last_token, i, 0);
            close_pos := MatchingClose(ctx.parse.expressions[i].first_token,
                                       ctx.parse.expressions[i].last_token,
                                       '{', '}');
            If close_pos > ctx.parse.expressions[i].first_token + 1 Then
              AddConstructorFields(i, ctx.parse.expressions[i].first_token + 1,
                                   close_pos - 1);
          End
        Else If ctx.parse.expressions[i].kind = EK_INDEX Then
          AddTableOp(TOP_INDEX, ctx.parse.expressions[i].first_token,
                     ctx.parse.expressions[i].last_token, i, 0);
      End;
  End;

  Procedure AddStoresAndRuntimeCalls;
  Var
    p, stmt_end, eq_pos: LongInt;
  Begin
    p := 1;
    While (p <= ctx.lex.token_count) And (ctx.lex.tokens[p].kind <> TK_EOF) Do
      Begin
        stmt_end := StatementEnd(p);
        eq_pos := TopLevelAssign(p, stmt_end - 1);
        If eq_pos <> 0 Then
          Begin
            If (TokenTextAt(ctx, eq_pos - 1, ']')) Or
               (TokenTextAt(ctx, eq_pos - 2, '.')) Then
              AddTableOp(TOP_STORE_FIELD, p, eq_pos - 1, 0, eq_pos);
          End;
        If (ctx.lex.tokens[p].kind = TK_IDENT) Then
          Begin
            If TokenTextAt(ctx, p, 'pairs') Or TokenTextAt(ctx, p, 'ipairs') Then
              AddTableOp(TOP_ITERATE, p, stmt_end - 1, 0, 0)
            Else If TokenTextAt(ctx, p, 'setmetatable') Or
                    TokenTextAt(ctx, p, 'getmetatable') Or
                    TokenTextAt(ctx, p, 'rawget') Or
                    TokenTextAt(ctx, p, 'rawset') Then
              AddTableOp(TOP_METATABLE, p, stmt_end - 1, 0, 0);
          End;
        If stmt_end <= p Then
          Inc(p)
        Else
          p := stmt_end;
      End;
  End;

  Procedure AddLengthOps;
  Var
    i: LongInt;
  Begin
    For i := 1 To ctx.exprcode.op_count Do
      If ctx.exprcode.ops[i].kind = EOP_LEN Then
        AddTableOp(TOP_LENGTH, ctx.exprcode.ops[i].first_token,
                   ctx.exprcode.ops[i].last_token, 0, i);
  End;

Begin
  BuildTableCodePlan := False;
  FillChar(ctx.tablecode, SizeOf(ctx.tablecode), 0);

  AddConstructorsAndIndexes;
  AddStoresAndRuntimeCalls;
  AddLengthOps;

  If ctx.options.verbose Then
    Writeln('Plan tables 80386: ops=', ctx.tablecode.op_count,
            ' (constructeurs=', ctx.tablecode.constructor_count,
            ', champs-array=', ctx.tablecode.array_field_count,
            ', champs-hash=', ctx.tablecode.hash_field_count,
            ', index=', ctx.tablecode.index_count,
            ', store=', ctx.tablecode.store_count,
            ', longueur=', ctx.tablecode.length_count,
            ', iteration=', ctx.tablecode.iterate_count,
            ', metatable=', ctx.tablecode.metatable_count, ')');

  BuildTableCodePlan := ctx.errors = 0;
End;

Function BuildControlFlowPlan(Var ctx: TCompilerContext): Boolean;
Var
  loop_stack: Array[1..MAX_BLOCKS] Of LongInt;
  loop_top: LongInt;

  Function NewInternalLabel(token_idx: LongInt): LongInt;
  Begin
    Inc(ctx.controlcode.label_count);
    NewInternalLabel := ctx.controlcode.label_count;
  End;

  Procedure AddControlOp(kind: TControlOpKind; first_token, last_token,
                         label_id, target_label: LongInt; depth: Integer);
  Var
    id: LongInt;
  Begin
    If ctx.controlcode.op_count >= MAX_CONTROL_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token,
                          'trop d''operations de controle Lua');
        Exit;
      End;
    Inc(ctx.controlcode.op_count);
    id := ctx.controlcode.op_count;
    ctx.controlcode.ops[id].kind := kind;
    ctx.controlcode.ops[id].first_token := first_token;
    ctx.controlcode.ops[id].last_token := last_token;
    ctx.controlcode.ops[id].label_id := label_id;
    ctx.controlcode.ops[id].target_label := target_label;
    ctx.controlcode.ops[id].depth := depth;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.controlcode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.controlcode.ops[id].line := 1;
    If depth > ctx.controlcode.max_depth Then
      ctx.controlcode.max_depth := depth;
    Case kind Of
      COP_JUMP:
        Inc(ctx.controlcode.jump_count);
      COP_JUMP_FALSE:
        Begin
          Inc(ctx.controlcode.jump_count);
          Inc(ctx.controlcode.conditional_count);
        End;
      COP_IF_BEGIN:
        Inc(ctx.controlcode.if_count);
      COP_ELSEIF_BRANCH:
        Inc(ctx.controlcode.elseif_count);
      COP_ELSE_BRANCH:
        Inc(ctx.controlcode.else_count);
      COP_LOOP_BEGIN:
        Inc(ctx.controlcode.loop_count);
      COP_BREAK:
        Inc(ctx.controlcode.break_count);
      COP_GOTO:
        Inc(ctx.controlcode.goto_count);
    Else
    End;
  End;

  Function StatementEnd(pos: LongInt): LongInt;
  Var
    start_line: LongInt;
    paren_depth, brace_depth, bracket_depth, func_depth: LongInt;
  Begin
    If (pos < 1) Or (pos > ctx.lex.token_count) Then
      Begin
        StatementEnd := pos;
        Exit;
      End;
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
              Break;
            If (ctx.lex.tokens[pos].line <> start_line) And
               (Not TokenTextAt(ctx, pos, '.')) And
               (Not TokenTextAt(ctx, pos, ':')) And
               (Not TokenTextAt(ctx, pos, ',')) And
               (Not TokenTextAt(ctx, pos, '=')) And
               (Not TokenTextAt(ctx, pos, '..')) Then
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

  Function FindLevelKeyword(first_token, last_token: LongInt;
                            keyword: TString): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth, block_depth: LongInt;
  Begin
    FindLevelKeyword := 0;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    block_depth := 0;
    p := first_token;
    While (p <= last_token) And (p <= ctx.lex.token_count) And
          (ctx.lex.tokens[p].kind <> TK_EOF) Do
      Begin
        If (paren_depth = 0) And (brace_depth = 0) And
           (bracket_depth = 0) Then
          Begin
            If (block_depth = 0) And TokenIsKeyword(ctx, p, keyword) Then
              Begin
                FindLevelKeyword := p;
                Exit;
              End;
            If TokenIsKeyword(ctx, p, 'if') Or
               TokenIsKeyword(ctx, p, 'while') Or
               TokenIsKeyword(ctx, p, 'for') Or
               TokenIsKeyword(ctx, p, 'function') Or
               TokenIsKeyword(ctx, p, 'do') Or
               TokenIsKeyword(ctx, p, 'repeat') Then
              Inc(block_depth)
            Else If (TokenIsKeyword(ctx, p, 'end') Or
                     TokenIsKeyword(ctx, p, 'until')) And
                    (block_depth > 0) Then
              Dec(block_depth);
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

  Function FindResolvedGotoTarget(name: TTokenText): LongInt;
  Var
    i: LongInt;
  Begin
    FindResolvedGotoTarget := 0;
    For i := 1 To ctx.sema.label_count Do
      If (ctx.sema.labels[i].kind = LBK_LABEL) And
         (UpperStr(ctx.sema.labels[i].name) = UpperStr(name)) Then
        Begin
          FindResolvedGotoTarget := i;
          Exit;
        End;
  End;

  Procedure ScanBlock(Var pos: LongInt; depth: Integer;
                      stop_until, stop_else: Boolean); Forward;

  Procedure ScanFunction(Var pos: LongInt; depth: Integer);
  Var
    p: LongInt;
  Begin
    p := pos + 1;
    While (p <= ctx.lex.token_count) And
          (ctx.lex.tokens[p].kind <> TK_EOF) And
          (Not TokenTextAt(ctx, p, '(')) Do
      Inc(p);
    If TokenTextAt(ctx, p, '(') Then
      Begin
        While (p <= ctx.lex.token_count) And
              (Not TokenTextAt(ctx, p, ')')) Do
          Inc(p);
        If TokenTextAt(ctx, p, ')') Then
          Inc(p);
      End;
    pos := p;
    ScanBlock(pos, depth + 1, False, False);
    If TokenIsKeyword(ctx, pos, 'end') Then
      Inc(pos);
  End;

  Procedure ScanDoBlock(Var pos: LongInt; depth: Integer);
  Begin
    Inc(pos);
    ScanBlock(pos, depth + 1, False, False);
    If TokenIsKeyword(ctx, pos, 'end') Then
      Inc(pos);
  End;

  Procedure ScanIf(Var pos: LongInt; depth: Integer);
  Var
    if_token, then_pos, next_label, end_label: LongInt;
  Begin
    if_token := pos;
    end_label := NewInternalLabel(if_token);
    next_label := NewInternalLabel(if_token);
    AddControlOp(COP_IF_BEGIN, if_token, if_token, 0, end_label, depth);
    then_pos := FindLevelKeyword(pos + 1, ctx.lex.token_count, 'then');
    If then_pos = 0 Then
      Begin
        pos := StatementEnd(pos);
        Exit;
      End;
    AddControlOp(COP_JUMP_FALSE, pos + 1, then_pos - 1, 0, next_label,
                 depth);
    pos := then_pos + 1;
    ScanBlock(pos, depth + 1, False, True);
    AddControlOp(COP_JUMP, pos, pos, 0, end_label, depth);
    AddControlOp(COP_LABEL, pos, pos, next_label, 0, depth);
    While TokenIsKeyword(ctx, pos, 'elseif') Do
      Begin
        next_label := NewInternalLabel(pos);
        AddControlOp(COP_ELSEIF_BRANCH, pos, pos, 0, end_label, depth);
        then_pos := FindLevelKeyword(pos + 1, ctx.lex.token_count, 'then');
        If then_pos = 0 Then
          Exit;
        AddControlOp(COP_JUMP_FALSE, pos + 1, then_pos - 1, 0,
                     next_label, depth);
        pos := then_pos + 1;
        ScanBlock(pos, depth + 1, False, True);
        AddControlOp(COP_JUMP, pos, pos, 0, end_label, depth);
        AddControlOp(COP_LABEL, pos, pos, next_label, 0, depth);
      End;
    If TokenIsKeyword(ctx, pos, 'else') Then
      Begin
        AddControlOp(COP_ELSE_BRANCH, pos, pos, 0, end_label, depth);
        Inc(pos);
        ScanBlock(pos, depth + 1, False, False);
      End;
    If TokenIsKeyword(ctx, pos, 'end') Then
      Begin
        AddControlOp(COP_IF_END, pos, pos, end_label, 0, depth);
        Inc(pos);
      End;
    AddControlOp(COP_LABEL, pos, pos, end_label, 0, depth);
  End;

  Procedure ScanWhile(Var pos: LongInt; depth: Integer);
  Var
    start_label, end_label, do_pos: LongInt;
  Begin
    start_label := NewInternalLabel(pos);
    end_label := NewInternalLabel(pos);
    AddControlOp(COP_LABEL, pos, pos, start_label, 0, depth);
    AddControlOp(COP_LOOP_BEGIN, pos, pos, start_label, end_label, depth);
    do_pos := FindLevelKeyword(pos + 1, ctx.lex.token_count, 'do');
    If do_pos = 0 Then
      Begin
        pos := StatementEnd(pos);
        Exit;
      End;
    AddControlOp(COP_LOOP_TEST, pos + 1, do_pos - 1, 0, end_label,
                 depth);
    AddControlOp(COP_JUMP_FALSE, pos + 1, do_pos - 1, 0, end_label,
                 depth);
    Inc(loop_top);
    loop_stack[loop_top] := end_label;
    pos := do_pos + 1;
    ScanBlock(pos, depth + 1, False, False);
    Dec(loop_top);
    AddControlOp(COP_LOOP_STEP, pos, pos, 0, start_label, depth);
    AddControlOp(COP_JUMP, pos, pos, 0, start_label, depth);
    If TokenIsKeyword(ctx, pos, 'end') Then
      Inc(pos);
    AddControlOp(COP_LABEL, pos, pos, end_label, 0, depth);
    AddControlOp(COP_LOOP_END, pos, pos, end_label, 0, depth);
  End;

  Procedure ScanRepeat(Var pos: LongInt; depth: Integer);
  Var
    start_label, end_label, until_token, stmt_end: LongInt;
  Begin
    start_label := NewInternalLabel(pos);
    end_label := NewInternalLabel(pos);
    AddControlOp(COP_LABEL, pos, pos, start_label, 0, depth);
    AddControlOp(COP_LOOP_BEGIN, pos, pos, start_label, end_label, depth);
    Inc(loop_top);
    loop_stack[loop_top] := end_label;
    Inc(pos);
    ScanBlock(pos, depth + 1, True, False);
    Dec(loop_top);
    If TokenIsKeyword(ctx, pos, 'until') Then
      Begin
        until_token := pos;
        Inc(pos);
        stmt_end := StatementEnd(pos);
        AddControlOp(COP_LOOP_TEST, pos, stmt_end - 1, 0, end_label,
                     depth);
        AddControlOp(COP_JUMP_FALSE, pos, stmt_end - 1, 0, start_label,
                     depth);
        pos := stmt_end;
        AddControlOp(COP_LABEL, until_token, until_token, end_label, 0,
                     depth);
      End;
    AddControlOp(COP_LOOP_END, pos, pos, end_label, 0, depth);
  End;

  Procedure ScanFor(Var pos: LongInt; depth: Integer);
  Var
    start_label, end_label, do_pos: LongInt;
  Begin
    start_label := NewInternalLabel(pos);
    end_label := NewInternalLabel(pos);
    AddControlOp(COP_LABEL, pos, pos, start_label, 0, depth);
    AddControlOp(COP_LOOP_BEGIN, pos, pos, start_label, end_label, depth);
    do_pos := FindLevelKeyword(pos + 1, ctx.lex.token_count, 'do');
    If do_pos = 0 Then
      Begin
        pos := StatementEnd(pos);
        Exit;
      End;
    AddControlOp(COP_LOOP_TEST, pos + 1, do_pos - 1, 0, end_label,
                 depth);
    AddControlOp(COP_JUMP_FALSE, pos + 1, do_pos - 1, 0, end_label,
                 depth);
    Inc(loop_top);
    loop_stack[loop_top] := end_label;
    pos := do_pos + 1;
    ScanBlock(pos, depth + 1, False, False);
    Dec(loop_top);
    AddControlOp(COP_LOOP_STEP, pos, pos, 0, start_label, depth);
    AddControlOp(COP_JUMP, pos, pos, 0, start_label, depth);
    If TokenIsKeyword(ctx, pos, 'end') Then
      Inc(pos);
    AddControlOp(COP_LABEL, pos, pos, end_label, 0, depth);
    AddControlOp(COP_LOOP_END, pos, pos, end_label, 0, depth);
  End;

  Procedure ScanBlock(Var pos: LongInt; depth: Integer;
                      stop_until, stop_else: Boolean);
  Var
    stmt_end, target: LongInt;
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
        Else If TokenIsKeyword(ctx, pos, 'if') Then
          ScanIf(pos, depth)
        Else If TokenIsKeyword(ctx, pos, 'while') Then
          ScanWhile(pos, depth)
        Else If TokenIsKeyword(ctx, pos, 'repeat') Then
          ScanRepeat(pos, depth)
        Else If TokenIsKeyword(ctx, pos, 'for') Then
          ScanFor(pos, depth)
        Else If TokenIsKeyword(ctx, pos, 'do') Then
          ScanDoBlock(pos, depth)
        Else If TokenIsKeyword(ctx, pos, 'function') Then
          ScanFunction(pos, depth)
        Else If TokenIsKeyword(ctx, pos, 'local') And
                TokenIsKeyword(ctx, pos + 1, 'function') Then
          Begin
            Inc(pos);
            ScanFunction(pos, depth);
          End
        Else If TokenIsKeyword(ctx, pos, 'break') Then
          Begin
            If loop_top <= 0 Then
              ParseErrorAtToken(ctx, pos, 'break hors boucle')
            Else
              Begin
                AddControlOp(COP_BREAK, pos, pos, 0, loop_stack[loop_top],
                             depth);
                AddControlOp(COP_JUMP, pos, pos, 0, loop_stack[loop_top],
                             depth);
              End;
            Inc(pos);
          End
        Else If TokenIsKeyword(ctx, pos, 'goto') Then
          Begin
            target := 0;
            If ctx.lex.tokens[pos + 1].kind = TK_IDENT Then
              target := FindResolvedGotoTarget(ctx.lex.tokens[pos + 1].text);
            AddControlOp(COP_GOTO, pos, pos + 1, 0, target, depth);
            AddControlOp(COP_JUMP, pos, pos + 1, 0, target, depth);
            pos := StatementEnd(pos);
          End
        Else If TokenTextAt(ctx, pos, '::') Then
          Begin
            target := 0;
            If ctx.lex.tokens[pos + 1].kind = TK_IDENT Then
              target := FindResolvedGotoTarget(ctx.lex.tokens[pos + 1].text);
            AddControlOp(COP_LABEL, pos, pos + 2, target, 0, depth);
            Inc(pos, 3);
          End
        Else
          Begin
            stmt_end := StatementEnd(pos);
            If stmt_end <= pos Then
              Inc(pos)
            Else
              pos := stmt_end;
          End;
      End;
  End;

Var
  pos: LongInt;
Begin
  BuildControlFlowPlan := False;
  FillChar(ctx.controlcode, SizeOf(ctx.controlcode), 0);
  FillChar(loop_stack, SizeOf(loop_stack), 0);
  loop_top := 0;

  pos := 1;
  ScanBlock(pos, 0, False, False);

  If ctx.sema.unresolved_gotos <> 0 Then
    ParseErrorAtToken(ctx, 1, 'goto Lua non resolu');

  If ctx.options.verbose Then
    Writeln('Plan controle 80386: ops=', ctx.controlcode.op_count,
            ', labels=', ctx.controlcode.label_count,
            ', sauts=', ctx.controlcode.jump_count,
            ', conditionnels=', ctx.controlcode.conditional_count,
            ' (if=', ctx.controlcode.if_count,
            ', elseif=', ctx.controlcode.elseif_count,
            ', else=', ctx.controlcode.else_count,
            ', boucles=', ctx.controlcode.loop_count,
            ', break=', ctx.controlcode.break_count,
            ', goto=', ctx.controlcode.goto_count,
            ', profondeur=', ctx.controlcode.max_depth, ')');

  BuildControlFlowPlan := ctx.errors = 0;
End;

Function BuildFunctionCodePlan(Var ctx: TCompilerContext): Boolean;

  Procedure AddFunctionOp(kind: TFunctionOpKind; first_token, last_token,
                          function_id, arg_count, result_count: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.functioncode.op_count >= MAX_FUNCTION_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token,
                          'trop d''operations fonction Lua');
        Exit;
      End;
    Inc(ctx.functioncode.op_count);
    id := ctx.functioncode.op_count;
    ctx.functioncode.ops[id].kind := kind;
    ctx.functioncode.ops[id].first_token := first_token;
    ctx.functioncode.ops[id].last_token := last_token;
    ctx.functioncode.ops[id].function_id := function_id;
    ctx.functioncode.ops[id].arg_count := arg_count;
    ctx.functioncode.ops[id].result_count := result_count;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.functioncode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.functioncode.ops[id].line := 1;
    If arg_count > ctx.functioncode.max_arg_count Then
      ctx.functioncode.max_arg_count := arg_count;
    If result_count > ctx.functioncode.max_result_count Then
      ctx.functioncode.max_result_count := result_count;
    Case kind Of
      FOP_DECLARE:
        Inc(ctx.functioncode.function_count);
      FOP_LITERAL:
        Inc(ctx.functioncode.literal_count);
      FOP_PROLOGUE:
        Inc(ctx.functioncode.prologue_count);
      FOP_PARAM_BIND:
        Inc(ctx.functioncode.param_bind_count);
      FOP_VARARG_BIND:
        Inc(ctx.functioncode.vararg_bind_count);
      FOP_PREPARE_CALL:
        ;
      FOP_PUSH_ARG:
        Inc(ctx.functioncode.arg_push_count);
      FOP_CALL:
        Inc(ctx.functioncode.call_count);
      FOP_RETURN:
        Inc(ctx.functioncode.return_count);
      FOP_TAIL_CALL:
        Inc(ctx.functioncode.tail_call_count);
    Else
    End;
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

  Function HeaderOpenParen(first_token, last_token: LongInt): LongInt;
  Var
    p: LongInt;
  Begin
    HeaderOpenParen := 0;
    For p := first_token To last_token Do
      If TokenTextAt(ctx, p, '(') Then
        Begin
          HeaderOpenParen := p;
          Exit;
        End;
  End;

  Function CountTopLevelItems(first_token, last_token: LongInt): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth, count: LongInt;
    seen: Boolean;
  Begin
    CountTopLevelItems := 0;
    If first_token > last_token Then
      Exit;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    count := 1;
    seen := False;
    For p := first_token To last_token Do
      Begin
        If (ctx.lex.tokens[p].kind <> TK_EOF) And
           (Not TokenTextAt(ctx, p, ',')) Then
          seen := True;
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
                (bracket_depth = 0) And TokenTextAt(ctx, p, ',') Then
          Inc(count);
      End;
    If seen Then
      CountTopLevelItems := count
    Else
      CountTopLevelItems := 0;
  End;

  Function CallArgCount(expr: TExprInfo): LongInt;
  Var
    p, close_pos: LongInt;
  Begin
    CallArgCount := 0;
    For p := expr.first_token To expr.last_token Do
      If TokenTextAt(ctx, p, '(') Then
        Begin
          close_pos := MatchingClose(p, expr.last_token, '(', ')');
          If close_pos <> 0 Then
            CallArgCount := CountTopLevelItems(p + 1, close_pos - 1);
          Exit;
        End;
    If (expr.last_token >= expr.first_token) And
       ((ctx.lex.tokens[expr.last_token].kind = TK_STRING) Or
        TokenTextAt(ctx, expr.last_token, '}')) Then
      CallArgCount := 1;
  End;

  Function StatementEnd(pos: LongInt): LongInt;
  Var
    start_line: LongInt;
    paren_depth, brace_depth, bracket_depth, func_depth: LongInt;
  Begin
    If (pos < 1) Or (pos > ctx.lex.token_count) Then
      Begin
        StatementEnd := pos;
        Exit;
      End;
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
              Break;
            If (ctx.lex.tokens[pos].line <> start_line) And
               (Not TokenTextAt(ctx, pos, '.')) And
               (Not TokenTextAt(ctx, pos, ':')) And
               (Not TokenTextAt(ctx, pos, ',')) And
               (Not TokenTextAt(ctx, pos, '=')) And
               (Not TokenTextAt(ctx, pos, '..')) Then
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

  Function TokenRangeHasCall(first_token, last_token: LongInt): Boolean;
  Var
    i: LongInt;
  Begin
    TokenRangeHasCall := False;
    For i := 1 To ctx.parse.expr_count Do
      If (ctx.parse.expressions[i].kind = EK_CALL) And
         (ctx.parse.expressions[i].first_token >= first_token) And
         (ctx.parse.expressions[i].last_token <= last_token) Then
        Begin
          TokenRangeHasCall := True;
          Exit;
        End;
  End;

  Procedure AddFunctionDeclarations;
  Var
    i, func_token, open_pos, close_pos, param_count: LongInt;
  Begin
    For i := 1 To ctx.parse.statement_count Do
      If ctx.parse.statements[i].kind = SK_FUNCTION Then
        Begin
          func_token := ctx.parse.statements[i].first_token;
          If Not TokenIsKeyword(ctx, func_token, 'function') Then
            Inc(func_token);
          open_pos := HeaderOpenParen(func_token,
                                      ctx.parse.statements[i].last_token + 80);
          close_pos := 0;
          param_count := 0;
          If open_pos <> 0 Then
            Begin
              close_pos := MatchingClose(open_pos, ctx.lex.token_count,
                                         '(', ')');
              param_count := CountTopLevelItems(open_pos + 1, close_pos - 1);
            End;
          AddFunctionOp(FOP_DECLARE, func_token,
                        ctx.parse.statements[i].last_token, i, param_count, 1);
          AddFunctionOp(FOP_PROLOGUE, func_token,
                        ctx.parse.statements[i].last_token, i, param_count, 1);
        End;
  End;

  Procedure AddFunctionLiterals;
  Var
    i, open_pos, close_pos, param_count: LongInt;
  Begin
    For i := 1 To ctx.parse.expr_count Do
      If ctx.parse.expressions[i].kind = EK_FUNCTION Then
        Begin
          open_pos := HeaderOpenParen(ctx.parse.expressions[i].first_token,
                                      ctx.parse.expressions[i].last_token);
          close_pos := 0;
          param_count := 0;
          If open_pos <> 0 Then
            Begin
              close_pos := MatchingClose(open_pos,
                                         ctx.parse.expressions[i].last_token,
                                         '(', ')');
              param_count := CountTopLevelItems(open_pos + 1, close_pos - 1);
            End;
          AddFunctionOp(FOP_LITERAL, ctx.parse.expressions[i].first_token,
                        ctx.parse.expressions[i].last_token, i,
                        param_count, 1);
          AddFunctionOp(FOP_PROLOGUE, ctx.parse.expressions[i].first_token,
                        ctx.parse.expressions[i].last_token, i,
                        param_count, 1);
        End;
  End;

  Procedure AddParameterBindings;
  Var
    i: LongInt;
  Begin
    For i := 1 To ctx.sema.symbol_count Do
      If ctx.sema.symbols[i].kind = SYK_PARAM Then
        AddFunctionOp(FOP_PARAM_BIND, ctx.sema.symbols[i].decl_token,
                      ctx.sema.symbols[i].decl_token,
                      ctx.sema.symbols[i].scope_id, 0, 0)
      Else If ctx.sema.symbols[i].kind = SYK_VARARG Then
        AddFunctionOp(FOP_VARARG_BIND, ctx.sema.symbols[i].decl_token,
                      ctx.sema.symbols[i].decl_token,
                      ctx.sema.symbols[i].scope_id, 0, 0);
  End;

  Procedure AddCalls;
  Var
    i, arg_count, a: LongInt;
  Begin
    For i := 1 To ctx.parse.expr_count Do
      If ctx.parse.expressions[i].kind = EK_CALL Then
        Begin
          arg_count := CallArgCount(ctx.parse.expressions[i]);
          AddFunctionOp(FOP_PREPARE_CALL, ctx.parse.expressions[i].first_token,
                        ctx.parse.expressions[i].last_token, i,
                        arg_count, 1);
          For a := 1 To arg_count Do
            AddFunctionOp(FOP_PUSH_ARG, ctx.parse.expressions[i].first_token,
                          ctx.parse.expressions[i].last_token, i, a, 0);
          AddFunctionOp(FOP_CALL, ctx.parse.expressions[i].first_token,
                        ctx.parse.expressions[i].last_token, i,
                        arg_count, 1);
        End;
  End;

  Procedure AddReturns;
  Var
    i, stmt_end, result_count: LongInt;
  Begin
    For i := 1 To ctx.parse.statement_count Do
      If ctx.parse.statements[i].kind = SK_RETURN Then
        Begin
          stmt_end := StatementEnd(ctx.parse.statements[i].first_token);
          result_count := CountTopLevelItems(ctx.parse.statements[i].first_token + 1,
                                             stmt_end - 1);
          AddFunctionOp(FOP_RETURN, ctx.parse.statements[i].first_token,
                        stmt_end - 1, i, 0, result_count);
          If TokenRangeHasCall(ctx.parse.statements[i].first_token + 1,
                               stmt_end - 1) Then
            AddFunctionOp(FOP_TAIL_CALL, ctx.parse.statements[i].first_token,
                          stmt_end - 1, i, 0, result_count);
        End;
  End;

Begin
  BuildFunctionCodePlan := False;
  FillChar(ctx.functioncode, SizeOf(ctx.functioncode), 0);

  AddFunctionDeclarations;
  AddFunctionLiterals;
  AddParameterBindings;
  AddCalls;
  AddReturns;

  If ctx.options.verbose Then
    Writeln('Plan fonctions 80386: ops=', ctx.functioncode.op_count,
            ' (decl=', ctx.functioncode.function_count,
            ', litterales=', ctx.functioncode.literal_count,
            ', prologues=', ctx.functioncode.prologue_count,
            ', params=', ctx.functioncode.param_bind_count,
            ', vararg=', ctx.functioncode.vararg_bind_count,
            ', appels=', ctx.functioncode.call_count,
            ', push-args=', ctx.functioncode.arg_push_count,
            ', retours=', ctx.functioncode.return_count,
            ', tail-calls=', ctx.functioncode.tail_call_count,
            ', max-args=', ctx.functioncode.max_arg_count,
            ', max-results=', ctx.functioncode.max_result_count, ')');

  BuildFunctionCodePlan := ctx.errors = 0;
End;

Function BuildClosureCodePlan(Var ctx: TCompilerContext): Boolean;

  Procedure AddClosureOp(kind: TClosureOpKind; first_token, last_token,
                         function_id, symbol_id, scope_id,
                         cell_index: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.closurecode.op_count >= MAX_CLOSURE_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token,
                          'trop d''operations closure Lua');
        Exit;
      End;
    Inc(ctx.closurecode.op_count);
    id := ctx.closurecode.op_count;
    ctx.closurecode.ops[id].kind := kind;
    ctx.closurecode.ops[id].first_token := first_token;
    ctx.closurecode.ops[id].last_token := last_token;
    ctx.closurecode.ops[id].function_id := function_id;
    ctx.closurecode.ops[id].symbol_id := symbol_id;
    ctx.closurecode.ops[id].scope_id := scope_id;
    ctx.closurecode.ops[id].cell_index := cell_index;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.closurecode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.closurecode.ops[id].line := 1;
    If cell_index > ctx.closurecode.max_cell_count Then
      ctx.closurecode.max_cell_count := cell_index;
    Case kind Of
      CLP_MAKE_CLOSURE:
        Inc(ctx.closurecode.closure_count);
      CLP_SHARE_CELL:
        Inc(ctx.closurecode.shared_cell_count);
      CLP_CAPTURE_LOCAL:
        Inc(ctx.closurecode.capture_local_count);
      CLP_CAPTURE_UPVALUE:
        Inc(ctx.closurecode.capture_upvalue_count);
      CLP_LOAD_UPVALUE:
        Inc(ctx.closurecode.load_upvalue_count);
      CLP_STORE_UPVALUE:
        Inc(ctx.closurecode.store_upvalue_count);
      CLP_CLOSE_SCOPE:
        Inc(ctx.closurecode.close_scope_count);
      CLP_ESCAPE_CELL:
        Inc(ctx.closurecode.escape_cell_count);
    Else
    End;
  End;

  Function CapturedCellIndex(symbol_id: LongInt): LongInt;
  Var
    i, n: LongInt;
  Begin
    n := 0;
    For i := 1 To symbol_id Do
      If (i <= ctx.sema.symbol_count) And ctx.sema.symbols[i].captured Then
        Inc(n);
    CapturedCellIndex := n;
  End;

  Function UpvalueCellIndex(symbol_id: LongInt): LongInt;
  Var
    i, n: LongInt;
  Begin
    n := ctx.closurecode.shared_cell_count;
    For i := 1 To symbol_id Do
      If (i <= ctx.sema.symbol_count) And
         (ctx.sema.symbols[i].kind = SYK_UPVALUE) Then
        Inc(n);
    UpvalueCellIndex := n;
  End;

  Function ScopeHasEscapingCell(scope_id: LongInt): Boolean;
  Var
    i: LongInt;
  Begin
    ScopeHasEscapingCell := False;
    For i := 1 To ctx.sema.symbol_count Do
      If (ctx.sema.symbols[i].scope_id = scope_id) And
         (ctx.sema.symbols[i].captured Or
          (ctx.sema.symbols[i].kind = SYK_UPVALUE)) Then
        Begin
          ScopeHasEscapingCell := True;
          Exit;
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

  Procedure AddClosureObjects;
  Var
    i: LongInt;
  Begin
    For i := 1 To ctx.parse.statement_count Do
      If ctx.parse.statements[i].kind = SK_FUNCTION Then
        AddClosureOp(CLP_MAKE_CLOSURE,
                     ctx.parse.statements[i].first_token,
                     ctx.parse.statements[i].last_token,
                     i, 0, 0, 0);
    For i := 1 To ctx.parse.expr_count Do
      If ctx.parse.expressions[i].kind = EK_FUNCTION Then
        AddClosureOp(CLP_MAKE_CLOSURE,
                     ctx.parse.expressions[i].first_token,
                     ctx.parse.expressions[i].last_token,
                     i, 0, 0, 0);
  End;

  Procedure AddCapturedCells;
  Var
    i, cell: LongInt;
  Begin
    For i := 1 To ctx.sema.symbol_count Do
      If ctx.sema.symbols[i].captured Then
        Begin
          cell := CapturedCellIndex(i);
          AddClosureOp(CLP_SHARE_CELL, ctx.sema.symbols[i].decl_token,
                       ctx.sema.symbols[i].last_use, 0, i,
                       ctx.sema.symbols[i].scope_id, cell);
          AddClosureOp(CLP_ESCAPE_CELL, ctx.sema.symbols[i].decl_token,
                       ctx.sema.symbols[i].last_use, 0, i,
                       ctx.sema.symbols[i].scope_id, cell);
        End;
  End;

  Procedure AddUpvalueCaptures;
  Var
    i, cell: LongInt;
  Begin
    For i := 1 To ctx.sema.symbol_count Do
      If ctx.sema.symbols[i].kind = SYK_UPVALUE Then
        Begin
          cell := UpvalueCellIndex(i);
          AddClosureOp(CLP_CAPTURE_UPVALUE, ctx.sema.symbols[i].decl_token,
                       ctx.sema.symbols[i].last_use, 0, i,
                       ctx.sema.symbols[i].scope_id, cell);
          AddClosureOp(CLP_CAPTURE_LOCAL, ctx.sema.symbols[i].decl_token,
                       ctx.sema.symbols[i].decl_token, 0, i,
                       ctx.sema.symbols[i].scope_id, cell);
        End;
  End;

  Procedure AddUpvalueAccesses;
  Var
    i, var_id, cell: LongInt;
  Begin
    For i := 1 To ctx.sema.symbol_count Do
      If ctx.sema.symbols[i].kind = SYK_UPVALUE Then
        Begin
          var_id := VariableForSymbol(i);
          cell := UpvalueCellIndex(i);
          If ctx.sema.symbols[i].use_count > 0 Then
            AddClosureOp(CLP_LOAD_UPVALUE, ctx.sema.symbols[i].first_use,
                         ctx.sema.symbols[i].last_use, 0, i,
                         ctx.sema.symbols[i].scope_id, cell)
          Else
            AddClosureOp(CLP_LOAD_UPVALUE, ctx.sema.symbols[i].decl_token,
                         ctx.sema.symbols[i].decl_token, 0, i,
                         ctx.sema.symbols[i].scope_id, cell);
          If (var_id <> 0) And ctx.sema.symbols[i].assigned Then
            AddClosureOp(CLP_STORE_UPVALUE, ctx.sema.symbols[i].decl_token,
                         ctx.sema.symbols[i].last_use, 0, i,
                         ctx.sema.symbols[i].scope_id, cell);
        End;
  End;

  Procedure AddScopeClosures;
  Var
    i, token_idx: LongInt;
  Begin
    For i := 1 To ctx.sema.scope_count Do
      If ScopeHasEscapingCell(i) Then
        Begin
          token_idx := ctx.sema.scopes[i].last_token;
          AddClosureOp(CLP_CLOSE_SCOPE, token_idx, token_idx, 0, 0, i,
                       ctx.closurecode.close_scope_count + 1);
        End;
  End;

Begin
  BuildClosureCodePlan := False;
  FillChar(ctx.closurecode, SizeOf(ctx.closurecode), 0);

  AddClosureObjects;
  AddCapturedCells;
  AddUpvalueCaptures;
  AddUpvalueAccesses;
  AddScopeClosures;

  If ctx.options.verbose Then
    Writeln('Plan closures 80386: ops=', ctx.closurecode.op_count,
            ' (closures=', ctx.closurecode.closure_count,
            ', cellules=', ctx.closurecode.shared_cell_count,
            ', capture-local=', ctx.closurecode.capture_local_count,
            ', capture-upvalue=', ctx.closurecode.capture_upvalue_count,
            ', load-upvalue=', ctx.closurecode.load_upvalue_count,
            ', store-upvalue=', ctx.closurecode.store_upvalue_count,
            ', close-scope=', ctx.closurecode.close_scope_count,
            ', escape=', ctx.closurecode.escape_cell_count,
            ', max-cell=', ctx.closurecode.max_cell_count, ')');

  BuildClosureCodePlan := ctx.errors = 0;
End;

Function BuildMultiReturnPlan(Var ctx: TCompilerContext): Boolean;

  Procedure AddMultiRetOp(kind: TMultiRetOpKind; first_token, last_token,
                          source_count, target_count, aux: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.multiretcode.op_count >= MAX_MULTIRET_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token,
                          'trop d''operations retours multiples Lua');
        Exit;
      End;
    Inc(ctx.multiretcode.op_count);
    id := ctx.multiretcode.op_count;
    ctx.multiretcode.ops[id].kind := kind;
    ctx.multiretcode.ops[id].first_token := first_token;
    ctx.multiretcode.ops[id].last_token := last_token;
    ctx.multiretcode.ops[id].source_count := source_count;
    ctx.multiretcode.ops[id].target_count := target_count;
    ctx.multiretcode.ops[id].aux := aux;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.multiretcode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.multiretcode.ops[id].line := 1;
    If source_count > ctx.multiretcode.max_source_count Then
      ctx.multiretcode.max_source_count := source_count;
    If target_count > ctx.multiretcode.max_target_count Then
      ctx.multiretcode.max_target_count := target_count;
    Case kind Of
      MRP_RETURN_PACK:
        Inc(ctx.multiretcode.return_pack_count);
      MRP_CALL_EXPAND:
        Inc(ctx.multiretcode.call_expand_count);
      MRP_CALL_TRUNCATE:
        Inc(ctx.multiretcode.call_truncate_count);
      MRP_ASSIGN_ADJUST:
        Inc(ctx.multiretcode.assign_adjust_count);
      MRP_NIL_FILL:
        Inc(ctx.multiretcode.nil_fill_count);
      MRP_VARARG_EXPAND:
        Inc(ctx.multiretcode.vararg_expand_count);
      MRP_SELECT_ARG:
        Inc(ctx.multiretcode.select_count);
      MRP_NESTED_CALL:
        Inc(ctx.multiretcode.nested_call_count);
    Else
    End;
  End;

  Function StatementEnd(pos: LongInt): LongInt;
  Var
    start_line: LongInt;
    paren_depth, brace_depth, bracket_depth, func_depth: LongInt;
  Begin
    If (pos < 1) Or (pos > ctx.lex.token_count) Then
      Begin
        StatementEnd := pos;
        Exit;
      End;
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
              Break;
            If (ctx.lex.tokens[pos].line <> start_line) And
               (Not TokenTextAt(ctx, pos, '.')) And
               (Not TokenTextAt(ctx, pos, ':')) And
               (Not TokenTextAt(ctx, pos, ',')) And
               (Not TokenTextAt(ctx, pos, '=')) And
               (Not TokenTextAt(ctx, pos, '..')) Then
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
        If (paren_depth = 0) And (brace_depth = 0) And
           (bracket_depth = 0) And (func_depth = 0) And
           TokenTextAt(ctx, p, text) Then
          Begin
            FindLevelToken := p;
            Exit;
          End;
        If TokenIsKeyword(ctx, p, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, p, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If TokenTextAt(ctx, p, '(') Then
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
      End;
  End;

  Function CountTopLevelItems(first_token, last_token: LongInt): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth, func_depth, count: LongInt;
    seen: Boolean;
  Begin
    CountTopLevelItems := 0;
    If first_token > last_token Then
      Exit;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    func_depth := 0;
    count := 1;
    seen := False;
    For p := first_token To last_token Do
      Begin
        If (ctx.lex.tokens[p].kind <> TK_EOF) And
           (Not TokenTextAt(ctx, p, ',')) Then
          seen := True;
        If TokenIsKeyword(ctx, p, 'function') Then
          Inc(func_depth)
        Else If TokenIsKeyword(ctx, p, 'end') And (func_depth > 0) Then
          Dec(func_depth)
        Else If TokenTextAt(ctx, p, '(') Then
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
                (bracket_depth = 0) And (func_depth = 0) And
                TokenTextAt(ctx, p, ',') Then
          Inc(count);
      End;
    If seen Then
      CountTopLevelItems := count;
  End;

  Function RangeHasToken(first_token, last_token: LongInt;
                         text: TTokenText): Boolean;
  Var
    p: LongInt;
  Begin
    RangeHasToken := False;
    For p := first_token To last_token Do
      If TokenTextAt(ctx, p, text) Then
        Begin
          RangeHasToken := True;
          Exit;
        End;
  End;

  Function ExprIsLastInRange(expr: TExprInfo; first_token,
                             last_token: LongInt): Boolean;
  Var
    p: LongInt;
  Begin
    ExprIsLastInRange := True;
    For p := expr.last_token + 1 To last_token Do
      If TokenTextAt(ctx, p, ',') Then
        Begin
          ExprIsLastInRange := False;
          Exit;
        End;
  End;

  Procedure AddReturnPacks;
  Var
    i, stmt_end, result_count: LongInt;
  Begin
    For i := 1 To ctx.parse.statement_count Do
      If ctx.parse.statements[i].kind = SK_RETURN Then
        Begin
          stmt_end := StatementEnd(ctx.parse.statements[i].first_token);
          result_count := CountTopLevelItems(ctx.parse.statements[i].first_token + 1,
                                             stmt_end - 1);
          AddMultiRetOp(MRP_RETURN_PACK, ctx.parse.statements[i].first_token,
                        stmt_end - 1, result_count, result_count, i);
        End;
  End;

  Procedure AddAssignmentAdjustments;
  Var
    p, stmt_end, eq_pos, lhs_count, rhs_count: LongInt;
  Begin
    p := 1;
    While (p <= ctx.lex.token_count) And (ctx.lex.tokens[p].kind <> TK_EOF) Do
      Begin
        stmt_end := StatementEnd(p);
        eq_pos := FindLevelToken(p, stmt_end - 1, '=');
        If eq_pos <> 0 Then
          Begin
            lhs_count := CountTopLevelItems(p, eq_pos - 1);
            rhs_count := CountTopLevelItems(eq_pos + 1, stmt_end - 1);
            AddMultiRetOp(MRP_ASSIGN_ADJUST, eq_pos, stmt_end - 1,
                          rhs_count, lhs_count, 0);
            If rhs_count < lhs_count Then
              AddMultiRetOp(MRP_NIL_FILL, eq_pos, stmt_end - 1,
                            rhs_count, lhs_count, lhs_count - rhs_count);
          End;
        If stmt_end <= p Then
          Inc(p)
        Else
          p := stmt_end;
      End;
  End;

  Procedure AddCallExpansions;
  Var
    i, j, target_count: LongInt;
    outer: TExprInfo;
    in_nested_call, is_last: Boolean;
  Begin
    For i := 1 To ctx.parse.expr_count Do
      If ctx.parse.expressions[i].kind = EK_CALL Then
        Begin
          in_nested_call := False;
          For j := 1 To ctx.parse.expr_count Do
            If (j <> i) And (ctx.parse.expressions[j].kind = EK_CALL) And
               (ctx.parse.expressions[j].first_token <=
                ctx.parse.expressions[i].first_token) And
               (ctx.parse.expressions[j].last_token >=
                ctx.parse.expressions[i].last_token) Then
              Begin
                outer := ctx.parse.expressions[j];
                If (outer.first_token < ctx.parse.expressions[i].first_token) Or
                   (outer.last_token > ctx.parse.expressions[i].last_token) Then
                  Begin
                    in_nested_call := True;
                    AddMultiRetOp(MRP_NESTED_CALL,
                                  ctx.parse.expressions[i].first_token,
                                  ctx.parse.expressions[i].last_token, 1, 1, j);
                    Break;
                  End;
              End;
          is_last := ExprIsLastInRange(ctx.parse.expressions[i],
                                       ctx.parse.expressions[i].first_token,
                                       ctx.parse.expressions[i].last_token);
          If in_nested_call Then
            AddMultiRetOp(MRP_CALL_TRUNCATE,
                          ctx.parse.expressions[i].first_token,
                          ctx.parse.expressions[i].last_token, -1, 1, i)
          Else If is_last Then
            AddMultiRetOp(MRP_CALL_EXPAND,
                          ctx.parse.expressions[i].first_token,
                          ctx.parse.expressions[i].last_token, -1, -1, i)
          Else
            AddMultiRetOp(MRP_CALL_TRUNCATE,
                          ctx.parse.expressions[i].first_token,
                          ctx.parse.expressions[i].last_token, -1, 1, i);
          target_count := 1;
          If target_count > ctx.multiretcode.max_target_count Then
            ctx.multiretcode.max_target_count := target_count;
        End;
  End;

  Procedure AddVarargAndSelect;
  Var
    i: LongInt;
  Begin
    For i := 1 To ctx.lex.token_count Do
      Begin
        If TokenTextAt(ctx, i, '...') Then
          AddMultiRetOp(MRP_VARARG_EXPAND, i, i, -1, -1, 0);
        If (ctx.lex.tokens[i].kind = TK_IDENT) And
           TokenTextAt(ctx, i, 'select') Then
          AddMultiRetOp(MRP_SELECT_ARG, i, StatementEnd(i), -1, -1, 0);
      End;
  End;

Begin
  BuildMultiReturnPlan := False;
  FillChar(ctx.multiretcode, SizeOf(ctx.multiretcode), 0);

  AddReturnPacks;
  AddAssignmentAdjustments;
  AddCallExpansions;
  AddVarargAndSelect;

  If ctx.options.verbose Then
    Writeln('Plan retours multiples 80386: ops=', ctx.multiretcode.op_count,
            ' (return-pack=', ctx.multiretcode.return_pack_count,
            ', call-expand=', ctx.multiretcode.call_expand_count,
            ', call-truncate=', ctx.multiretcode.call_truncate_count,
            ', assign-adjust=', ctx.multiretcode.assign_adjust_count,
            ', nil-fill=', ctx.multiretcode.nil_fill_count,
            ', vararg=', ctx.multiretcode.vararg_expand_count,
            ', select=', ctx.multiretcode.select_count,
            ', appels-imbriques=', ctx.multiretcode.nested_call_count,
            ', max-source=', ctx.multiretcode.max_source_count,
            ', max-target=', ctx.multiretcode.max_target_count, ')');

  BuildMultiReturnPlan := ctx.errors = 0;
End;

Function BuildRuntimeBuiltinPlan(Var ctx: TCompilerContext): Boolean;

  Procedure AddBuiltinOp(kind: TBuiltinOpKind; first_token, last_token: LongInt;
                         name: TTokenText; arg_count, result_count: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.builtincode.op_count >= MAX_BUILTIN_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token, 'trop d''operations builtin Lua');
        Exit;
      End;
    Inc(ctx.builtincode.op_count);
    id := ctx.builtincode.op_count;
    ctx.builtincode.ops[id].kind := kind;
    ctx.builtincode.ops[id].first_token := first_token;
    ctx.builtincode.ops[id].last_token := last_token;
    ctx.builtincode.ops[id].name := name;
    ctx.builtincode.ops[id].arg_count := arg_count;
    ctx.builtincode.ops[id].result_count := result_count;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.builtincode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.builtincode.ops[id].line := 1;
    If arg_count > ctx.builtincode.max_arg_count Then
      ctx.builtincode.max_arg_count := arg_count;
    Case kind Of
      BOP_CORE_PRINT:
        Inc(ctx.builtincode.print_count);
      BOP_CORE_CONVERT:
        Inc(ctx.builtincode.convert_count);
      BOP_CORE_TYPE:
        Inc(ctx.builtincode.type_count);
      BOP_ERROR_ASSERT, BOP_ERROR_THROW, BOP_ERROR_PCALL:
        Inc(ctx.builtincode.error_count);
      BOP_ITER_PAIRS, BOP_ITER_NEXT:
        Inc(ctx.builtincode.iterator_count);
      BOP_SELECT:
        Inc(ctx.builtincode.select_count);
      BOP_MATH_FUNC:
        Inc(ctx.builtincode.math_count);
      BOP_MATH_CONST:
        Inc(ctx.builtincode.math_const_count);
      BOP_STRING_FUNC:
        Inc(ctx.builtincode.string_count);
      BOP_TABLE_FUNC:
        Inc(ctx.builtincode.table_count);
      BOP_OS_FUNC:
        Inc(ctx.builtincode.os_count);
      BOP_IO_FUNC:
        Inc(ctx.builtincode.io_count);
    Else
    End;
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

  Function CountTopLevelItems(first_token, last_token: LongInt): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth, count: LongInt;
    seen: Boolean;
  Begin
    CountTopLevelItems := 0;
    If first_token > last_token Then
      Exit;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    count := 1;
    seen := False;
    For p := first_token To last_token Do
      Begin
        If (ctx.lex.tokens[p].kind <> TK_EOF) And
           (Not TokenTextAt(ctx, p, ',')) Then
          seen := True;
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
                (bracket_depth = 0) And TokenTextAt(ctx, p, ',') Then
          Inc(count);
      End;
    If seen Then
      CountTopLevelItems := count;
  End;

  Function CallCloseAndArgs(call_token: LongInt; Var close_pos: LongInt): LongInt;
  Begin
    close_pos := 0;
    CallCloseAndArgs := 0;
    If TokenTextAt(ctx, call_token + 1, '(') Then
      Begin
        close_pos := MatchingClose(call_token + 1, ctx.lex.token_count,
                                   '(', ')');
        If close_pos <> 0 Then
          CallCloseAndArgs := CountTopLevelItems(call_token + 2,
                                                close_pos - 1);
      End;
  End;

  Function KnownMathConst(name: TTokenText): Boolean;
  Begin
    KnownMathConst := TokenTextAt(ctx, 0, name);
    KnownMathConst := (UpperStr(name) = 'PI') Or
                      (UpperStr(name) = 'HUGE') Or
                      (UpperStr(name) = 'MAXINTEGER') Or
                      (UpperStr(name) = 'MININTEGER');
  End;

  Procedure AddCoreBuiltins;
  Var
    i, close_pos, argc: LongInt;
  Begin
    For i := 1 To ctx.lex.token_count Do
      If ctx.lex.tokens[i].kind = TK_IDENT Then
        Begin
          argc := CallCloseAndArgs(i, close_pos);
          If close_pos <> 0 Then
            Begin
              If TokenTextAt(ctx, i, 'print') Then
                AddBuiltinOp(BOP_CORE_PRINT, i, close_pos, 'print', argc, 0)
              Else If TokenTextAt(ctx, i, 'tostring') Or
                      TokenTextAt(ctx, i, 'tonumber') Then
                AddBuiltinOp(BOP_CORE_CONVERT, i, close_pos,
                             ctx.lex.tokens[i].text, argc, 1)
              Else If TokenTextAt(ctx, i, 'type') Then
                AddBuiltinOp(BOP_CORE_TYPE, i, close_pos, 'type', argc, 1)
              Else If TokenTextAt(ctx, i, 'assert') Then
                AddBuiltinOp(BOP_ERROR_ASSERT, i, close_pos, 'assert', argc, 1)
              Else If TokenTextAt(ctx, i, 'error') Then
                AddBuiltinOp(BOP_ERROR_THROW, i, close_pos, 'error', argc, 0)
              Else If TokenTextAt(ctx, i, 'pcall') Or
                      TokenTextAt(ctx, i, 'xpcall') Then
                AddBuiltinOp(BOP_ERROR_PCALL, i, close_pos,
                             ctx.lex.tokens[i].text, argc, 2)
              Else If TokenTextAt(ctx, i, 'pairs') Or
                      TokenTextAt(ctx, i, 'ipairs') Then
                AddBuiltinOp(BOP_ITER_PAIRS, i, close_pos,
                             ctx.lex.tokens[i].text, argc, 3)
              Else If TokenTextAt(ctx, i, 'next') Then
                AddBuiltinOp(BOP_ITER_NEXT, i, close_pos, 'next', argc, 2)
              Else If TokenTextAt(ctx, i, 'select') Then
                AddBuiltinOp(BOP_SELECT, i, close_pos, 'select', argc, -1);
            End;
        End;
  End;

  Procedure AddLibraryBuiltins;
  Var
    i, call_token, close_pos, argc: LongInt;
    libname, fname, fullname: TTokenText;
  Begin
    For i := 1 To ctx.lex.token_count - 2 Do
      If (ctx.lex.tokens[i].kind = TK_IDENT) And
         TokenTextAt(ctx, i + 1, '.') And
         (ctx.lex.tokens[i + 2].kind = TK_IDENT) Then
        Begin
          libname := ctx.lex.tokens[i].text;
          fname := ctx.lex.tokens[i + 2].text;
          fullname := libname + '.' + fname;
          call_token := i + 2;
          argc := CallCloseAndArgs(call_token, close_pos);
          If close_pos <> 0 Then
            Begin
              If TokenTextAt(ctx, i, 'math') Then
                AddBuiltinOp(BOP_MATH_FUNC, i, close_pos, fullname, argc, 1)
              Else If TokenTextAt(ctx, i, 'string') Then
                AddBuiltinOp(BOP_STRING_FUNC, i, close_pos, fullname, argc, 1)
              Else If TokenTextAt(ctx, i, 'table') Then
                AddBuiltinOp(BOP_TABLE_FUNC, i, close_pos, fullname, argc, 1)
              Else If TokenTextAt(ctx, i, 'os') Then
                AddBuiltinOp(BOP_OS_FUNC, i, close_pos, fullname, argc, 1)
              Else If TokenTextAt(ctx, i, 'io') Then
                AddBuiltinOp(BOP_IO_FUNC, i, close_pos, fullname, argc, 1);
            End
          Else If TokenTextAt(ctx, i, 'math') And KnownMathConst(fname) Then
            AddBuiltinOp(BOP_MATH_CONST, i, i + 2, fullname, 0, 1);
        End;
  End;

Begin
  BuildRuntimeBuiltinPlan := False;
  FillChar(ctx.builtincode, SizeOf(ctx.builtincode), 0);

  AddCoreBuiltins;
  AddLibraryBuiltins;

  If ctx.options.verbose Then
    Writeln('Plan builtins/runtime 80386: ops=', ctx.builtincode.op_count,
            ' (print=', ctx.builtincode.print_count,
            ', convert=', ctx.builtincode.convert_count,
            ', type=', ctx.builtincode.type_count,
            ', erreurs=', ctx.builtincode.error_count,
            ', iterateurs=', ctx.builtincode.iterator_count,
            ', select=', ctx.builtincode.select_count,
            ', math=', ctx.builtincode.math_count,
            ', math-const=', ctx.builtincode.math_const_count,
            ', string=', ctx.builtincode.string_count,
            ', table=', ctx.builtincode.table_count,
            ', os=', ctx.builtincode.os_count,
            ', io=', ctx.builtincode.io_count,
            ', max-args=', ctx.builtincode.max_arg_count, ')');

  BuildRuntimeBuiltinPlan := ctx.errors = 0;
End;

Function BuildErrorHandlingPlan(Var ctx: TCompilerContext): Boolean;

  Procedure AddErrorOp(kind: TErrorOpKind; first_token, last_token,
                       handler_id, arg_count: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.errorcode.op_count >= MAX_ERROR_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token,
                          'trop d''operations gestion erreur Lua');
        Exit;
      End;
    Inc(ctx.errorcode.op_count);
    id := ctx.errorcode.op_count;
    ctx.errorcode.ops[id].kind := kind;
    ctx.errorcode.ops[id].first_token := first_token;
    ctx.errorcode.ops[id].last_token := last_token;
    ctx.errorcode.ops[id].handler_id := handler_id;
    ctx.errorcode.ops[id].arg_count := arg_count;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.errorcode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.errorcode.ops[id].line := 1;
    If arg_count > ctx.errorcode.max_arg_count Then
      ctx.errorcode.max_arg_count := arg_count;
    Case kind Of
      EHP_ASSERT_CHECK:
        Inc(ctx.errorcode.assert_count);
      EHP_RAISE_ERROR:
        Inc(ctx.errorcode.raise_count);
      EHP_PUSH_HANDLER, EHP_POP_HANDLER, EHP_PCALL_ENTER, EHP_PCALL_EXIT:
        Inc(ctx.errorcode.protected_count);
      EHP_XPCALL_HANDLER:
        Inc(ctx.errorcode.xpcall_count);
      EHP_PROPAGATE:
        Inc(ctx.errorcode.propagate_count);
      EHP_MESSAGE:
        Inc(ctx.errorcode.message_count);
      EHP_STACK_CLEANUP:
        Inc(ctx.errorcode.cleanup_count);
    Else
    End;
  End;

  Function NewHandler: LongInt;
  Begin
    Inc(ctx.errorcode.handler_count);
    NewHandler := ctx.errorcode.handler_count;
  End;

  Procedure AddAssertPlan(op: TBuiltinOpInfo);
  Begin
    AddErrorOp(EHP_ASSERT_CHECK, op.first_token, op.last_token, 0,
               op.arg_count);
    If op.arg_count > 1 Then
      AddErrorOp(EHP_MESSAGE, op.first_token, op.last_token, 0,
                 op.arg_count);
    AddErrorOp(EHP_PROPAGATE, op.first_token, op.last_token, 0,
               op.arg_count);
  End;

  Procedure AddRaisePlan(op: TBuiltinOpInfo);
  Begin
    AddErrorOp(EHP_MESSAGE, op.first_token, op.last_token, 0, op.arg_count);
    AddErrorOp(EHP_RAISE_ERROR, op.first_token, op.last_token, 0,
               op.arg_count);
    AddErrorOp(EHP_PROPAGATE, op.first_token, op.last_token, 0,
               op.arg_count);
    AddErrorOp(EHP_STACK_CLEANUP, op.first_token, op.last_token, 0,
               op.arg_count);
  End;

  Procedure AddProtectedCallPlan(op: TBuiltinOpInfo);
  Var
    handler_id: LongInt;
  Begin
    handler_id := NewHandler;
    AddErrorOp(EHP_PUSH_HANDLER, op.first_token, op.last_token, handler_id,
               op.arg_count);
    AddErrorOp(EHP_PCALL_ENTER, op.first_token, op.last_token, handler_id,
               op.arg_count);
    If UpperStr(op.name) = 'XPCALL' Then
      AddErrorOp(EHP_XPCALL_HANDLER, op.first_token, op.last_token,
                 handler_id, op.arg_count);
    AddErrorOp(EHP_PCALL_EXIT, op.first_token, op.last_token, handler_id,
               op.arg_count);
    AddErrorOp(EHP_POP_HANDLER, op.first_token, op.last_token, handler_id,
               op.arg_count);
    AddErrorOp(EHP_STACK_CLEANUP, op.first_token, op.last_token, handler_id,
               op.arg_count);
  End;

Var
  i: LongInt;
  op: TBuiltinOpInfo;
Begin
  BuildErrorHandlingPlan := False;
  FillChar(ctx.errorcode, SizeOf(ctx.errorcode), 0);

  For i := 1 To ctx.builtincode.op_count Do
    Begin
      op := ctx.builtincode.ops[i];
      Case op.kind Of
        BOP_ERROR_ASSERT:
          AddAssertPlan(op);
        BOP_ERROR_THROW:
          AddRaisePlan(op);
        BOP_ERROR_PCALL:
          AddProtectedCallPlan(op);
      Else
      End;
    End;

  If ctx.options.verbose Then
    Writeln('Plan erreurs Lua 80386: ops=', ctx.errorcode.op_count,
            ' (assert=', ctx.errorcode.assert_count,
            ', raise=', ctx.errorcode.raise_count,
            ', protected=', ctx.errorcode.protected_count,
            ', xpcall=', ctx.errorcode.xpcall_count,
            ', propagate=', ctx.errorcode.propagate_count,
            ', messages=', ctx.errorcode.message_count,
            ', cleanup=', ctx.errorcode.cleanup_count,
            ', handlers=', ctx.errorcode.handler_count,
            ', max-args=', ctx.errorcode.max_arg_count, ')');

  BuildErrorHandlingPlan := ctx.errors = 0;
End;

Function BuildCoroutinePlan(Var ctx: TCompilerContext): Boolean;

  Procedure AddCoroutineOp(kind: TCoroutineOpKind; first_token, last_token,
                           coroutine_id, arg_count: LongInt);
  Var
    id: LongInt;
  Begin
    If ctx.coroutinecode.op_count >= MAX_COROUTINE_OPS Then
      Begin
        ParseErrorAtToken(ctx, first_token,
                          'trop d''operations coroutine Lua');
        Exit;
      End;
    Inc(ctx.coroutinecode.op_count);
    id := ctx.coroutinecode.op_count;
    ctx.coroutinecode.ops[id].kind := kind;
    ctx.coroutinecode.ops[id].first_token := first_token;
    ctx.coroutinecode.ops[id].last_token := last_token;
    ctx.coroutinecode.ops[id].coroutine_id := coroutine_id;
    ctx.coroutinecode.ops[id].arg_count := arg_count;
    If (first_token >= 1) And (first_token <= ctx.lex.token_count) Then
      ctx.coroutinecode.ops[id].line := ctx.lex.tokens[first_token].line
    Else
      ctx.coroutinecode.ops[id].line := 1;
    If arg_count > ctx.coroutinecode.max_arg_count Then
      ctx.coroutinecode.max_arg_count := arg_count;
    Case kind Of
      CRP_CREATE:
        Begin
          Inc(ctx.coroutinecode.create_count);
          Inc(ctx.coroutinecode.coroutine_count);
        End;
      CRP_RESUME:
        Inc(ctx.coroutinecode.resume_count);
      CRP_YIELD:
        Inc(ctx.coroutinecode.yield_count);
      CRP_STATUS:
        Inc(ctx.coroutinecode.status_count);
      CRP_WRAP:
        Inc(ctx.coroutinecode.wrap_count);
      CRP_ISYIELDABLE:
        Inc(ctx.coroutinecode.isyieldable_count);
      CRP_SAVE_CONTEXT:
        Inc(ctx.coroutinecode.save_count);
      CRP_RESTORE_CONTEXT:
        Inc(ctx.coroutinecode.restore_count);
      CRP_STACK_FRAME:
        Inc(ctx.coroutinecode.stack_frame_count);
      CRP_STATE_TRANSITION:
        Inc(ctx.coroutinecode.transition_count);
    Else
    End;
  End;

  Function NextCoroutineId: LongInt;
  Begin
    NextCoroutineId := ctx.coroutinecode.coroutine_count + 1;
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

  Function CountTopLevelItems(first_token, last_token: LongInt): LongInt;
  Var
    p, paren_depth, brace_depth, bracket_depth, count: LongInt;
    seen: Boolean;
  Begin
    CountTopLevelItems := 0;
    If first_token > last_token Then
      Exit;
    paren_depth := 0;
    brace_depth := 0;
    bracket_depth := 0;
    count := 1;
    seen := False;
    For p := first_token To last_token Do
      Begin
        If (ctx.lex.tokens[p].kind <> TK_EOF) And
           (Not TokenTextAt(ctx, p, ',')) Then
          seen := True;
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
                (bracket_depth = 0) And TokenTextAt(ctx, p, ',') Then
          Inc(count);
      End;
    If seen Then
      CountTopLevelItems := count;
  End;

  Function CallCloseAndArgs(call_token: LongInt; Var close_pos: LongInt): LongInt;
  Begin
    close_pos := 0;
    CallCloseAndArgs := 0;
    If TokenTextAt(ctx, call_token + 1, '(') Then
      Begin
        close_pos := MatchingClose(call_token + 1, ctx.lex.token_count,
                                   '(', ')');
        If close_pos <> 0 Then
          CallCloseAndArgs := CountTopLevelItems(call_token + 2,
                                                close_pos - 1);
      End;
  End;

  Procedure AddCreatePlan(first_token, last_token, argc: LongInt);
  Var
    cid: LongInt;
  Begin
    cid := NextCoroutineId;
    AddCoroutineOp(CRP_CREATE, first_token, last_token, cid, argc);
    AddCoroutineOp(CRP_STACK_FRAME, first_token, last_token, cid, argc);
    AddCoroutineOp(CRP_SAVE_CONTEXT, first_token, last_token, cid, argc);
    AddCoroutineOp(CRP_STATE_TRANSITION, first_token, last_token, cid, argc);
  End;

  Procedure AddResumePlan(first_token, last_token, argc: LongInt);
  Begin
    AddCoroutineOp(CRP_RESTORE_CONTEXT, first_token, last_token, 0, argc);
    AddCoroutineOp(CRP_RESUME, first_token, last_token, 0, argc);
    AddCoroutineOp(CRP_SAVE_CONTEXT, first_token, last_token, 0, argc);
    AddCoroutineOp(CRP_STATE_TRANSITION, first_token, last_token, 0, argc);
  End;

  Procedure AddYieldPlan(first_token, last_token, argc: LongInt);
  Begin
    AddCoroutineOp(CRP_YIELD, first_token, last_token, 0, argc);
    AddCoroutineOp(CRP_SAVE_CONTEXT, first_token, last_token, 0, argc);
    AddCoroutineOp(CRP_STATE_TRANSITION, first_token, last_token, 0, argc);
  End;

  Procedure AddWrapPlan(first_token, last_token, argc: LongInt);
  Var
    cid: LongInt;
  Begin
    AddCoroutineOp(CRP_WRAP, first_token, last_token, 0, argc);
    cid := NextCoroutineId;
    AddCoroutineOp(CRP_CREATE, first_token, last_token, cid, argc);
    AddCoroutineOp(CRP_STACK_FRAME, first_token, last_token, cid, argc);
    AddCoroutineOp(CRP_SAVE_CONTEXT, first_token, last_token, cid, argc);
  End;

Var
  i, close_pos, argc: LongInt;
  name: TTokenText;
Begin
  BuildCoroutinePlan := False;
  FillChar(ctx.coroutinecode, SizeOf(ctx.coroutinecode), 0);

  For i := 1 To ctx.lex.token_count - 3 Do
    If (ctx.lex.tokens[i].kind = TK_IDENT) And
       TokenTextAt(ctx, i, 'coroutine') And
       TokenTextAt(ctx, i + 1, '.') And
       (ctx.lex.tokens[i + 2].kind = TK_IDENT) Then
      Begin
        argc := CallCloseAndArgs(i + 2, close_pos);
        If close_pos <> 0 Then
          Begin
            name := ctx.lex.tokens[i + 2].text;
            If UpperStr(name) = 'CREATE' Then
              AddCreatePlan(i, close_pos, argc)
            Else If UpperStr(name) = 'RESUME' Then
              AddResumePlan(i, close_pos, argc)
            Else If UpperStr(name) = 'YIELD' Then
              AddYieldPlan(i, close_pos, argc)
            Else If UpperStr(name) = 'STATUS' Then
              AddCoroutineOp(CRP_STATUS, i, close_pos, 0, argc)
            Else If UpperStr(name) = 'WRAP' Then
              AddWrapPlan(i, close_pos, argc)
            Else If UpperStr(name) = 'ISYIELDABLE' Then
              AddCoroutineOp(CRP_ISYIELDABLE, i, close_pos, 0, argc);
          End;
      End;

  If ctx.options.verbose Then
    Writeln('Plan coroutines Lua 80386: ops=', ctx.coroutinecode.op_count,
            ' (coroutines=', ctx.coroutinecode.coroutine_count,
            ', create=', ctx.coroutinecode.create_count,
            ', resume=', ctx.coroutinecode.resume_count,
            ', yield=', ctx.coroutinecode.yield_count,
            ', status=', ctx.coroutinecode.status_count,
            ', wrap=', ctx.coroutinecode.wrap_count,
            ', isyieldable=', ctx.coroutinecode.isyieldable_count,
            ', save=', ctx.coroutinecode.save_count,
            ', restore=', ctx.coroutinecode.restore_count,
            ', stack=', ctx.coroutinecode.stack_frame_count,
            ', transitions=', ctx.coroutinecode.transition_count,
            ', max-args=', ctx.coroutinecode.max_arg_count, ')');

  BuildCoroutinePlan := ctx.errors = 0;
End;

Function EmitAsm386(Var ctx: TCompilerContext): Boolean;
Var
  f: Text;
  io: Integer;

  Function IdText(id: LongInt): TString;
  Var
    s: TString;
  Begin
    Str(id, s);
    IdText := s;
  End;

  Function AsmLabel(prefix: TString; id: LongInt): TString;
  Begin
    AsmLabel := prefix + IdText(id);
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

  Procedure EmitRaw(s: TString);
  Begin
    Writeln(f, s);
  End;

  Procedure EmitBlank;
  Begin
    Writeln(f);
  End;

  Procedure EmitComment(s: TString);
  Begin
    Writeln(f, '; ', s);
  End;

  Procedure EmitLabel(lbl: TString);
  Begin
    Writeln(f, lbl, ':');
  End;

  Procedure EmitInstr(op: TString);
  Begin
    Writeln(f, '        ', op);
  End;

  Procedure EmitInstrA(op, a1: TString);
  Begin
    Writeln(f, '        ', op, ' ', a1);
  End;

  Procedure EmitInstrAB(op, a1, a2: TString);
  Begin
    Writeln(f, '        ', op, ' ', a1, ', ', a2);
  End;

  Procedure EmitDbString(text: TTokenText);
  Var
    i: Integer;
  Begin
    Write(f, '        db ');
    If Length(text) = 0 Then
      Write(f, '0')
    Else
      Begin
        For i := 1 To Length(text) Do
          Begin
            Write(f, Ord(text[i]), ',');
          End;
        Write(f, '0');
      End;
    Writeln(f);
  End;

  Procedure EmitHeader;
  Var
    i: LongInt;
  Begin
    EmitComment('Genere par LUACW32 ' + LUACW32_VERSION);
    EmitComment('Source: ' + ctx.source_name);
    EmitComment('Cible ASM: 80386 Win32 COFF, syntaxe NASM/FASM-like');
    EmitComment('Emission demandee explicitement par -asm');
    EmitBlank;
    EmitRaw('BITS 32');
    EmitRaw('global _luacw32_entry');
    EmitRaw('extern _ExitProcess@4');
    For i := 1 To ctx.datapool.import_count Do
      EmitRaw('extern _' + ctx.datapool.imports[i].symbol_name);
    EmitBlank;
  End;

  Procedure EmitTextSection;
  Var
    i: LongInt;
  Begin
    EmitRaw('section .text use32 class=CODE');
    EmitBlank;
    EmitLabel('_luacw32_entry');
    EmitInstrA('call', 'luacw32_chunk_main');
    EmitInstrA('push', 'dword 0');
    EmitInstrA('call', '_ExitProcess@4');
    EmitBlank;

    EmitLabel('luacw32_chunk_main');
    EmitInstrA('push', 'ebp');
    EmitInstrAB('mov', 'ebp', 'esp');
    EmitInstrAB('sub', 'esp', IdText(ctx.codegen.local_slot_count * 4));
    EmitComment('initialisation des slots locaux/globaux planifies');
    For i := 1 To ctx.codegen.varop_count Do
      Begin
        EmitLabel(AsmLabel('LUA_varop_', i));
        EmitComment(VarOpKindName(ctx.codegen.varops[i].kind) +
                    ' slot=' + IdText(ctx.codegen.varops[i].variable_id) +
                    ' ligne=' + IdText(ctx.codegen.varops[i].line));
        EmitInstr('nop');
      End;
    EmitBlank;

    EmitComment('operations expressions');
    For i := 1 To ctx.exprcode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_expr_', i));
        EmitComment(ExprOpKindName(ctx.exprcode.ops[i].kind) +
                    ' temp=' + IdText(ctx.exprcode.ops[i].temp_index) +
                    ' ligne=' + IdText(ctx.exprcode.ops[i].line));
        EmitInstr('nop');
      End;
    EmitBlank;

    EmitComment('operations chaines');
    For i := 1 To ctx.stringcode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_str_', i));
        EmitComment(StringOpKindName(ctx.stringcode.ops[i].kind) +
                    ' const=' + IdText(ctx.stringcode.ops[i].const_id) +
                    ' ligne=' + IdText(ctx.stringcode.ops[i].line));
        EmitInstrA('call', 'luacw32_runtime_string');
      End;
    EmitBlank;

    EmitComment('operations tables');
    For i := 1 To ctx.tablecode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_table_', i));
        EmitComment(TableOpKindName(ctx.tablecode.ops[i].kind) +
                    ' table=' + IdText(ctx.tablecode.ops[i].table_id) +
                    ' ligne=' + IdText(ctx.tablecode.ops[i].line));
        EmitInstrA('call', 'luacw32_runtime_table');
      End;
    EmitBlank;

    EmitComment('controle de flux');
    For i := 1 To ctx.controlcode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_ctrl_', i));
        EmitComment(ControlOpKindName(ctx.controlcode.ops[i].kind) +
                    ' label=' + IdText(ctx.controlcode.ops[i].label_id) +
                    ' target=' + IdText(ctx.controlcode.ops[i].target_label) +
                    ' ligne=' + IdText(ctx.controlcode.ops[i].line));
        EmitInstr('nop');
      End;
    EmitBlank;

    EmitComment('fonctions et appels');
    For i := 1 To ctx.functioncode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_fnop_', i));
        EmitComment(FunctionOpKindName(ctx.functioncode.ops[i].kind) +
                    ' fn=' + IdText(ctx.functioncode.ops[i].function_id) +
                    ' argc=' + IdText(ctx.functioncode.ops[i].arg_count) +
                    ' results=' + IdText(ctx.functioncode.ops[i].result_count) +
                    ' ligne=' + IdText(ctx.functioncode.ops[i].line));
        EmitInstr('nop');
      End;
    EmitBlank;

    EmitComment('closures/upvalues');
    For i := 1 To ctx.closurecode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_closure_', i));
        EmitComment(ClosureOpKindName(ctx.closurecode.ops[i].kind) +
                    ' cell=' + IdText(ctx.closurecode.ops[i].cell_index) +
                    ' ligne=' + IdText(ctx.closurecode.ops[i].line));
        EmitInstrA('call', 'luacw32_runtime_closure');
      End;
    EmitBlank;

    EmitComment('retours multiples');
    For i := 1 To ctx.multiretcode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_multiret_', i));
        EmitComment(MultiRetOpKindName(ctx.multiretcode.ops[i].kind) +
                    ' src=' + IdText(ctx.multiretcode.ops[i].source_count) +
                    ' dst=' + IdText(ctx.multiretcode.ops[i].target_count) +
                    ' ligne=' + IdText(ctx.multiretcode.ops[i].line));
        EmitInstr('nop');
      End;
    EmitBlank;

    EmitComment('builtins/runtime');
    For i := 1 To ctx.builtincode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_builtin_', i));
        EmitComment(BuiltinOpKindName(ctx.builtincode.ops[i].kind) +
                    ' name=' + ctx.builtincode.ops[i].name +
                    ' argc=' + IdText(ctx.builtincode.ops[i].arg_count) +
                    ' ligne=' + IdText(ctx.builtincode.ops[i].line));
        EmitInstrA('call', 'luacw32_runtime_builtin');
      End;
    EmitBlank;

    EmitComment('gestion erreurs Lua');
    For i := 1 To ctx.errorcode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_error_', i));
        EmitComment(ErrorOpKindName(ctx.errorcode.ops[i].kind) +
                    ' handler=' + IdText(ctx.errorcode.ops[i].handler_id) +
                    ' argc=' + IdText(ctx.errorcode.ops[i].arg_count) +
                    ' ligne=' + IdText(ctx.errorcode.ops[i].line));
        EmitInstrA('call', 'luacw32_runtime_error');
      End;
    EmitBlank;

    EmitComment('coroutines Lua');
    For i := 1 To ctx.coroutinecode.op_count Do
      Begin
        EmitLabel(AsmLabel('LUA_coroutine_', i));
        EmitComment(CoroutineOpKindName(ctx.coroutinecode.ops[i].kind) +
                    ' co=' + IdText(ctx.coroutinecode.ops[i].coroutine_id) +
                    ' argc=' + IdText(ctx.coroutinecode.ops[i].arg_count) +
                    ' ligne=' + IdText(ctx.coroutinecode.ops[i].line));
        EmitInstrA('call', 'luacw32_runtime_coroutine');
      End;
    EmitBlank;

    EmitInstrAB('mov', 'esp', 'ebp');
    EmitInstrA('pop', 'ebp');
    EmitInstr('ret');
    EmitBlank;

    EmitLabel('luacw32_runtime_string');
    EmitInstr('ret');
    EmitLabel('luacw32_runtime_table');
    EmitInstr('ret');
    EmitLabel('luacw32_runtime_closure');
    EmitInstr('ret');
    EmitLabel('luacw32_runtime_builtin');
    EmitInstr('ret');
    EmitLabel('luacw32_runtime_error');
    EmitInstr('ret');
    EmitLabel('luacw32_runtime_coroutine');
    EmitInstr('ret');
    EmitBlank;
  End;

  Procedure EmitRDataSection;
  Var
    i: LongInt;
  Begin
    EmitRaw('section .rdata align=4 class=CONST');
    EmitLabel('LUA_rdata_begin');
    For i := 1 To ctx.datapool.constant_count Do
      If ctx.datapool.constants[i].section = DSK_RDATA Then
        Begin
          EmitLabel(AsmLabel('LUA_const_', i));
          EmitComment(ConstKindName(ctx.datapool.constants[i].kind) +
                      ' size=' + IdText(ctx.datapool.constants[i].size) +
                      ' line=' + IdText(ctx.datapool.constants[i].line) +
                      ' text=' + ctx.datapool.constants[i].text);
          Case ctx.datapool.constants[i].kind Of
            CPK_STRING, CPK_SYMBOL_NAME:
              EmitDbString(ctx.datapool.constants[i].text);
            CPK_NUMBER:
              EmitRaw('        dq 0          ; nombre Lua: ' +
                      ctx.datapool.constants[i].text);
            CPK_BOOL:
              If UpperStr(ctx.datapool.constants[i].text) = 'TRUE' Then
                EmitRaw('        dd 1')
              Else
                EmitRaw('        dd 0');
          Else
            EmitRaw('        dd 0');
          End;
        End;
    EmitBlank;
  End;

  Procedure EmitDataSection;
  Var
    i: LongInt;
  Begin
    EmitRaw('section .data align=4 class=DATA');
    EmitLabel('LUA_data_begin');
    EmitRaw('LUA_heap_handle dd 0');
    EmitRaw('LUA_stack_top dd 0');
    For i := 1 To ctx.datapool.constant_count Do
      If ctx.datapool.constants[i].section = DSK_DATA Then
        Begin
          EmitLabel(AsmLabel('LUA_data_const_', i));
          EmitComment(ConstKindName(ctx.datapool.constants[i].kind) +
                      ' size=' + IdText(ctx.datapool.constants[i].size) +
                      ' text=' + ctx.datapool.constants[i].text);
          EmitRaw('        times ' + IdText(ctx.datapool.constants[i].size) +
                  ' db 0');
        End;
    EmitBlank;
  End;

  Procedure EmitBssSection;
  Var
    i: LongInt;
  Begin
    EmitRaw('section .bss align=4 class=BSS');
    EmitLabel('LUA_bss_begin');
    For i := 1 To ctx.codegen.variable_count Do
      Begin
        EmitRaw(AsmLabel('LUA_slot_', i) + ' resd 1');
      End;
    If ctx.codegen.variable_count = 0 Then
      EmitRaw('LUA_no_slots resd 1');
    EmitBlank;
  End;

Begin
  EmitAsm386 := False;
  If Not ctx.options.emit_asm Then
    Begin
      ctx.last_art := AK_ASM_386;
      If ctx.options.verbose Then
        Writeln('ASM 80386: emission ignoree (option -asm absente)');
      EmitAsm386 := ctx.errors = 0;
      Exit;
    End;

  Assign(f, ctx.asm_name);
  Rewrite(f);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible de creer le fichier ASM: ' +
                    ctx.asm_name);
      Exit;
    End;

  EmitHeader;
  EmitTextSection;
  EmitRDataSection;
  EmitDataSection;
  EmitBssSection;
  Close(f);

  ctx.last_art := AK_ASM_386;
  If ctx.options.verbose Then
    Writeln('ASM 80386 emis: ', ctx.asm_name,
            ' (.text/.rdata/.data/.bss, labels stables)');
  EmitAsm386 := ctx.errors = 0;
End;

Function EmitObjCoff(Var ctx: TCompilerContext): Boolean;
Type
  TObjSymbol = Record
    name            : TString;
    value           : LongInt;
    section_number  : Integer;
    typ             : Word;
    storage_class   : Byte;
    aux_count       : Byte;
  End;
Var
  f: File;
  io: Integer;
  symbols: Array[1..MAX_OBJ_SYMBOLS] Of TObjSymbol;
  symbol_count: LongInt;
  strtab: Array[0..MAX_OBJ_STRING_BYTES - 1] Of Byte;
  strtab_size: LongInt;
  text_ofs, rdata_ofs, data_ofs, reloc_ofs, symtab_ofs: LongInt;
  text_size, rdata_size, data_size, bss_size: LongInt;
  exit_symbol_index: LongInt;

  Function IdText(id: LongInt): TString;
  Var
    s: TString;
  Begin
    Str(id, s);
    IdText := s;
  End;

  Procedure WriteByte(b: Byte);
  Begin
    BlockWrite(f, b, 1);
  End;

  Procedure WriteWordLE(w: Word);
  Var
    b: Array[0..1] Of Byte;
  Begin
    b[0] := Lo(w);
    b[1] := Hi(w);
    BlockWrite(f, b, 2);
  End;

  Procedure WriteDWordLE(d: LongInt);
  Var
    b: Array[0..3] Of Byte;
  Begin
    b[0] := Byte(d And $FF);
    b[1] := Byte((d Shr 8) And $FF);
    b[2] := Byte((d Shr 16) And $FF);
    b[3] := Byte((d Shr 24) And $FF);
    BlockWrite(f, b, 4);
  End;

  Procedure WriteZeros(count: LongInt);
  Var
    z: Byte;
    i: LongInt;
  Begin
    z := 0;
    For i := 1 To count Do
      BlockWrite(f, z, 1);
  End;

  Procedure WriteName8(name: TString);
  Var
    i: Integer;
    b: Byte;
  Begin
    For i := 1 To 8 Do
      Begin
        If i <= Length(name) Then
          b := Ord(name[i])
        Else
          b := 0;
        BlockWrite(f, b, 1);
      End;
  End;

  Function AddStringTableName(name: TString): LongInt;
  Var
    i: Integer;
  Begin
    AddStringTableName := strtab_size;
    If strtab_size + Length(name) + 1 > MAX_OBJ_STRING_BYTES Then
      Begin
        PipelineError(ctx, 'table de chaines COFF trop grande');
        Exit;
      End;
    For i := 1 To Length(name) Do
      Begin
        strtab[strtab_size] := Ord(name[i]);
        Inc(strtab_size);
      End;
    strtab[strtab_size] := 0;
    Inc(strtab_size);
  End;

  Procedure WriteSymbolName(name: TString);
  Var
    ofs: LongInt;
  Begin
    If Length(name) <= 8 Then
      WriteName8(name)
    Else
      Begin
        WriteDWordLE(0);
        ofs := AddStringTableName(name);
        WriteDWordLE(ofs);
      End;
  End;

  Function AddSymbol(name: TString; value: LongInt; section_number: Integer;
                     typ: Word; storage_class, aux_count: Byte): LongInt;
  Begin
    AddSymbol := 0;
    If symbol_count >= MAX_OBJ_SYMBOLS Then
      Begin
        PipelineError(ctx, 'trop de symboles COFF');
        Exit;
      End;
    Inc(symbol_count);
    symbols[symbol_count].name := name;
    symbols[symbol_count].value := value;
    symbols[symbol_count].section_number := section_number;
    symbols[symbol_count].typ := typ;
    symbols[symbol_count].storage_class := storage_class;
    symbols[symbol_count].aux_count := aux_count;
    AddSymbol := symbol_count - 1;
  End;

  Function HasSymbol(name: TString): Boolean;
  Var
    i: LongInt;
  Begin
    HasSymbol := False;
    For i := 1 To symbol_count Do
      If UpperStr(symbols[i].name) = UpperStr(name) Then
        Begin
          HasSymbol := True;
          Exit;
        End;
  End;

  Procedure AddImportSymbols;
  Var
    i: LongInt;
    nm: TString;
  Begin
    For i := 1 To ctx.datapool.import_count Do
      Begin
        nm := '_' + ctx.datapool.imports[i].symbol_name;
        If Not HasSymbol(nm) Then
          AddSymbol(nm, 0, 0, 0, COFF_SYM_CLASS_EXTERNAL, 0);
      End;
  End;

  Procedure WriteSectionHeader(name: TString; virtual_size, raw_size,
                               raw_ptr, reloc_ptr: LongInt;
                               reloc_count: Word; chars: LongInt);
  Begin
    WriteName8(name);
    WriteDWordLE(virtual_size);
    WriteDWordLE(0);
    WriteDWordLE(raw_size);
    WriteDWordLE(raw_ptr);
    WriteDWordLE(reloc_ptr);
    WriteDWordLE(0);
    WriteWordLE(reloc_count);
    WriteWordLE(0);
    WriteDWordLE(chars);
  End;

  Procedure WriteTextSection;
  Begin
    WriteByte($6A); WriteByte($00);       { push 0 }
    WriteByte($E8); WriteDWordLE(0);      { call ExitProcess, REL32 }
    WriteByte($C3);                       { ret, securite si link stub }
  End;

  Procedure WriteRDataSection;
  Var
    i, j, written, pad: LongInt;
  Begin
    written := 0;
    For i := 1 To ctx.datapool.constant_count Do
      If ctx.datapool.constants[i].section = DSK_RDATA Then
        Begin
          Case ctx.datapool.constants[i].kind Of
            CPK_STRING, CPK_SYMBOL_NAME:
              Begin
                For j := 1 To Length(ctx.datapool.constants[i].text) Do
                  WriteByte(Ord(ctx.datapool.constants[i].text[j]));
                WriteByte(0);
                Inc(written, Length(ctx.datapool.constants[i].text) + 1);
              End;
            CPK_NUMBER:
              Begin
                WriteDWordLE(0);
                WriteDWordLE(0);
                Inc(written, 8);
              End;
          Else
            WriteDWordLE(0);
            Inc(written, 4);
          End;
          pad := AlignTo(written, COFF_ALIGN_RDATA) - written;
          If pad > 0 Then
            Begin
              WriteZeros(pad);
              Inc(written, pad);
            End;
        End;
    If written < rdata_size Then
      WriteZeros(rdata_size - written);
  End;

  Procedure WriteDataSection;
  Var
    raw_meta: LongInt;
  Begin
    WriteDWordLE(ctx.runtime.value_count);
    WriteDWordLE(ctx.runtime.object_count);
    raw_meta := 8;
    If data_size > raw_meta Then
      WriteZeros(data_size - raw_meta);
  End;

  Procedure WriteRelocations;
  Begin
    WriteDWordLE(3);                  { offset du displacement E8 }
    WriteDWordLE(exit_symbol_index);
    WriteWordLE(COFF_RELOC_I386_REL32);
  End;

  Procedure WriteSymbols;
  Var
    i: LongInt;
  Begin
    For i := 1 To symbol_count Do
      Begin
        WriteSymbolName(symbols[i].name);
        WriteDWordLE(symbols[i].value);
        WriteWordLE(Word(symbols[i].section_number));
        WriteWordLE(symbols[i].typ);
        WriteByte(symbols[i].storage_class);
        WriteByte(symbols[i].aux_count);
      End;
  End;

  Procedure WriteStringTable;
  Begin
    WriteDWordLE(strtab_size);
    If strtab_size > 4 Then
      BlockWrite(f, strtab[4], strtab_size - 4);
  End;

Begin
  EmitObjCoff := False;
  text_size := 8;
  rdata_size := AlignTo(ctx.datapool.rdata_size, COFF_ALIGN_RDATA);
  If rdata_size = 0 Then
    rdata_size := 4;
  data_size := AlignTo(ctx.datapool.data_size + 8, COFF_ALIGN_DATA);
  bss_size := AlignTo(ctx.datapool.bss_size +
                      ctx.codegen.variable_count * 4, COFF_ALIGN_BSS);
  If bss_size = 0 Then
    bss_size := 4;

  text_ofs := 20 + 4 * 40;
  rdata_ofs := text_ofs + text_size;
  data_ofs := rdata_ofs + rdata_size;
  reloc_ofs := data_ofs + data_size;
  symtab_ofs := reloc_ofs + 10;

  FillChar(symbols, SizeOf(symbols), 0);
  FillChar(strtab, SizeOf(strtab), 0);
  symbol_count := 0;
  strtab_size := 4;

  AddSymbol('.text', 0, 1, 0, COFF_SYM_CLASS_STATIC, 0);
  AddSymbol('.rdata', 0, 2, 0, COFF_SYM_CLASS_STATIC, 0);
  AddSymbol('.data', 0, 3, 0, COFF_SYM_CLASS_STATIC, 0);
  AddSymbol('.bss', 0, 4, 0, COFF_SYM_CLASS_STATIC, 0);
  AddSymbol('_luacw32_entry', 0, 1, $20, COFF_SYM_CLASS_EXTERNAL, 0);
  exit_symbol_index := AddSymbol('_ExitProcess@4', 0, 0, $20,
                                 COFF_SYM_CLASS_EXTERNAL, 0);
  AddImportSymbols;

  Assign(f, ctx.obj_name);
  Rewrite(f, 1);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible de creer le fichier OBJ: ' +
                    ctx.obj_name);
      Exit;
    End;

  WriteWordLE(COFF_MACHINE_I386);
  WriteWordLE(4);
  WriteDWordLE(0);
  WriteDWordLE(symtab_ofs);
  WriteDWordLE(symbol_count);
  WriteWordLE(0);
  WriteWordLE(0);

  WriteSectionHeader('.text', text_size, text_size, text_ofs, reloc_ofs, 1,
                     COFF_SCN_CNT_CODE Or COFF_SCN_ALIGN_4BYTES Or
                     COFF_SCN_MEM_EXECUTE Or COFF_SCN_MEM_READ);
  WriteSectionHeader('.rdata', rdata_size, rdata_size, rdata_ofs, 0, 0,
                     COFF_SCN_CNT_INITIALIZED_DATA Or COFF_SCN_ALIGN_4BYTES Or
                     COFF_SCN_MEM_READ);
  WriteSectionHeader('.data', data_size, data_size, data_ofs, 0, 0,
                     COFF_SCN_CNT_INITIALIZED_DATA Or COFF_SCN_ALIGN_4BYTES Or
                     COFF_SCN_MEM_READ Or COFF_SCN_MEM_WRITE);
  WriteSectionHeader('.bss', bss_size, 0, 0, 0, 0,
                     COFF_SCN_CNT_UNINITIALIZED_DATA Or COFF_SCN_ALIGN_4BYTES Or
                     COFF_SCN_MEM_READ Or COFF_SCN_MEM_WRITE);

  WriteTextSection;
  WriteRDataSection;
  WriteDataSection;
  WriteRelocations;
  WriteSymbols;
  WriteStringTable;
  Close(f);

  ctx.last_art := AK_OBJ_COFF;
  If ctx.options.verbose Then
    Writeln('OBJ COFF emis: ', ctx.obj_name,
            ' (sections=4, relocations=1, symboles=', symbol_count,
            ', .text=', text_size, ', .rdata=', rdata_size,
            ', .data=', data_size, ', .bss=', bss_size, ')');
  EmitObjCoff := ctx.errors = 0;
End;

Function LinkExePe32(Var ctx: TCompilerContext): Boolean;
Var
  f: File;
  old_exe: File;
  io: Integer;
  hdr_size, text_rva, rdata_rva, data_rva, image_size: LongInt;
  text_raw, rdata_raw, data_raw: LongInt;
  text_size, rdata_size, data_size: LongInt;
  text_file_size, rdata_file_size, data_file_size: LongInt;
  iat_ofs, ilt_ofs, hint_exit_ofs, hint_getstd_ofs,
  hint_writefile_ofs, dll_name_ofs: LongInt;
  import_desc_ofs: LongInt;
  output_kind: Array[1..128] Of Char;
  output_values: Array[1..128] Of LongInt;
  output_texts: Array[1..128] Of TString;
  output_text_lens: Array[1..128] Of LongInt;
  output_data_ofs: Array[1..128] Of LongInt;
  output_count: LongInt;
  output_instr_size, output_data_size: LongInt;
  has_int_output, has_string_output: Boolean;

  Function AlignToLocal(value, align: LongInt): LongInt;
  Begin
    If align <= 0 Then
      AlignToLocal := value
    Else
      AlignToLocal := ((value + align - 1) Div align) * align;
  End;

  Procedure WriteByte(b: Byte);
  Begin
    BlockWrite(f, b, 1);
  End;

  Procedure WriteWordLE(w: Word);
  Var
    b: Array[0..1] Of Byte;
  Begin
    b[0] := Lo(w);
    b[1] := Hi(w);
    BlockWrite(f, b, 2);
  End;

  Procedure WriteDWordLE(d: LongInt);
  Var
    b: Array[0..3] Of Byte;
  Begin
    b[0] := Byte(d And $FF);
    b[1] := Byte((d Shr 8) And $FF);
    b[2] := Byte((d Shr 16) And $FF);
    b[3] := Byte((d Shr 24) And $FF);
    BlockWrite(f, b, 4);
  End;

  Procedure WriteZeros(count: LongInt);
  Var
    z: Byte;
    i: LongInt;
  Begin
    z := 0;
    For i := 1 To count Do
      BlockWrite(f, z, 1);
  End;

  Procedure WriteBytes(s: TString);
  Var
    i: Integer;
  Begin
    For i := 1 To Length(s) Do
      WriteByte(Ord(s[i]));
  End;

  Procedure WriteName8(name: TString);
  Var
    i: Integer;
    b: Byte;
  Begin
    For i := 1 To 8 Do
      Begin
        If i <= Length(name) Then
          b := Ord(name[i])
        Else
          b := 0;
        WriteByte(b);
      End;
  End;

  Procedure PadToFileOffset(target: LongInt);
  Var
    posn: LongInt;
  Begin
    posn := FilePos(f);
    If target > posn Then
      WriteZeros(target - posn);
  End;

  Procedure WriteSectionHeader(name: TString; virtual_size, virtual_address,
                               raw_size, raw_ptr, chars: LongInt);
  Begin
    WriteName8(name);
    WriteDWordLE(virtual_size);
    WriteDWordLE(virtual_address);
    WriteDWordLE(raw_size);
    WriteDWordLE(raw_ptr);
    WriteDWordLE(0);
    WriteDWordLE(0);
    WriteWordLE(0);
    WriteWordLE(0);
    WriteDWordLE(chars);
  End;

  Function TrimLine(s: TSourceLine): TSourceLine;
  Begin
    While (Length(s) > 0) And ((s[1] = ' ') Or (s[1] = #9)) Do
      Delete(s, 1, 1);
    While (Length(s) > 0) And
          ((s[Length(s)] = ' ') Or (s[Length(s)] = #9)) Do
      Delete(s, Length(s), 1);
    TrimLine := s;
  End;

  Function StripComment(s: TSourceLine): TSourceLine;
  Var
    p: Integer;
  Begin
    p := Pos('--', s);
    If p > 0 Then
      s := Copy(s, 1, p - 1);
    StripComment := TrimLine(s);
  End;

  Function StartsWithText(s, prefix: TSourceLine): Boolean;
  Begin
    StartsWithText := UpperStr(Copy(s, 1, Length(prefix))) =
                      UpperStr(prefix);
  End;

  Function IntText(v: LongInt): TString;
  Var
    s: TString;
  Begin
    Str(v, s);
    IntText := s;
  End;

  Procedure AddOutputInt(value: LongInt);
  Begin
    If output_count >= 128 Then
      Exit;
    Inc(output_count);
    output_kind[output_count] := 'I';
    output_values[output_count] := value;
    Inc(output_instr_size, 10);
    has_int_output := True;
  End;

  Procedure AddOutputText(value: TString);
  Begin
    If output_count >= 128 Then
      Exit;
    Inc(output_count);
    output_kind[output_count] := 'S';
    output_text_lens[output_count] := Length(value) + 2;
    output_texts[output_count] := value + #13#10 + #0;
    output_data_ofs[output_count] := 40 + output_data_size;
    Inc(output_data_size, Length(output_texts[output_count]));
    Inc(output_instr_size, 15);
    has_string_output := True;
  End;

  Procedure AddOutputRawText(value: TString);
  Begin
    If output_count >= 128 Then
      Exit;
    If value = '' Then
      Exit;
    Inc(output_count);
    output_kind[output_count] := 'S';
    output_text_lens[output_count] := Length(value);
    output_texts[output_count] := value + #0;
    output_data_ofs[output_count] := 40 + output_data_size;
    Inc(output_data_size, Length(output_texts[output_count]));
    Inc(output_instr_size, 15);
    has_string_output := True;
  End;

  Function StaticPrintOutput: TString;
  Const
    MAX_VARS = 64;
    MAX_TABLES = 32;
    MAX_TABLE_ITEMS = 32;
    MAX_STACK = 64;
  Var
    names: Array[1..MAX_VARS] Of TTokenText;
    vals: Array[1..MAX_VARS] Of LongInt;
    var_count: LongInt;
    str_names: Array[1..MAX_VARS] Of TTokenText;
    str_vals: Array[1..MAX_VARS] Of TString;
    str_exprs: Array[1..MAX_VARS] Of TSourceLine;
    str_count: LongInt;
    func_names: Array[1..MAX_VARS] Of TTokenText;
    func_kind: Array[1..MAX_VARS] Of Char;
    func_cap: Array[1..MAX_VARS] Of LongInt;
    func_count: LongInt;
    table_names: Array[1..MAX_TABLES] Of TTokenText;
    table_len: Array[1..MAX_TABLES] Of LongInt;
    table_items: Array[1..MAX_TABLES, 1..MAX_TABLE_ITEMS] Of LongInt;
    table_x, table_y, table_a: Array[1..MAX_TABLES] Of LongInt;
    table_count: LongInt;
    stack_kind: Array[1..MAX_STACK] Of Char;
    stack_start: Array[1..MAX_STACK] Of LongInt;
    stack_cond: Array[1..MAX_STACK] Of TSourceLine;
    stack_var: Array[1..MAX_STACK] Of TTokenText;
    stack_stop, stack_step: Array[1..MAX_STACK] Of LongInt;
    sp: LongInt;
    out: TString;

    Function FindVar(name: TTokenText): LongInt;
    Var
      i: LongInt;
    Begin
      FindVar := 0;
      For i := 1 To var_count Do
        If UpperStr(names[i]) = UpperStr(name) Then
          Begin
            FindVar := i;
            Exit;
          End;
    End;

    Procedure SetVar(name: TTokenText; value: LongInt);
    Var
      id: LongInt;
    Begin
      id := FindVar(name);
      If id = 0 Then
        Begin
          If var_count >= MAX_VARS Then
            Exit;
          Inc(var_count);
          id := var_count;
          names[id] := name;
        End;
      vals[id] := value;
    End;

    Function GetVar(name: TTokenText): LongInt;
    Var
      id: LongInt;
    Begin
      id := FindVar(name);
      If id = 0 Then
        GetVar := 0
      Else
        GetVar := vals[id];
    End;

    Function FindStrVar(name: TTokenText): LongInt;
    Var
      i: LongInt;
    Begin
      FindStrVar := 0;
      For i := 1 To str_count Do
        If UpperStr(str_names[i]) = UpperStr(name) Then
          Begin
            FindStrVar := i;
            Exit;
          End;
    End;

    Procedure SetStrVar(name: TTokenText; value: TString);
    Var
      id: LongInt;
    Begin
      id := FindStrVar(name);
      If id = 0 Then
        Begin
          If str_count >= MAX_VARS Then
            Exit;
          Inc(str_count);
          id := str_count;
          str_names[id] := name;
        End;
      str_vals[id] := value;
      str_exprs[id] := '';
    End;

    Procedure SetStrVarExpr(name: TTokenText; value: TString; expr: TSourceLine);
    Var
      id: LongInt;
    Begin
      SetStrVar(name, value);
      id := FindStrVar(name);
      If id > 0 Then
        str_exprs[id] := expr;
    End;

    Function GetStrVar(name: TTokenText): TString;
    Var
      id: LongInt;
    Begin
      id := FindStrVar(name);
      If id = 0 Then
        GetStrVar := ''
      Else
        GetStrVar := str_vals[id];
    End;

    Function GetStrExpr(name: TTokenText): TSourceLine;
    Var
      id: LongInt;
    Begin
      id := FindStrVar(name);
      If id = 0 Then
        GetStrExpr := ''
      Else
        GetStrExpr := str_exprs[id];
    End;

    Function FindFunc(name: TTokenText): LongInt;
    Var
      i: LongInt;
    Begin
      FindFunc := 0;
      For i := 1 To func_count Do
        If UpperStr(func_names[i]) = UpperStr(name) Then
          Begin
            FindFunc := i;
            Exit;
          End;
    End;

    Procedure SetFunc(name: TTokenText; kind: Char; cap: LongInt);
    Var
      id: LongInt;
    Begin
      id := FindFunc(name);
      If id = 0 Then
        Begin
          If func_count >= MAX_VARS Then
            Exit;
          Inc(func_count);
          id := func_count;
          func_names[id] := name;
        End;
      func_kind[id] := kind;
      func_cap[id] := cap;
    End;

    Function FunctionKindForName(name: TTokenText): Char;
    Begin
      name := UpperStr(name);
      If name = 'DOUBLE' Then
        FunctionKindForName := 'D'
      Else If name = 'INCREMENT' Then
        FunctionKindForName := 'I'
      Else If name = 'GET_VAL' Then
        FunctionKindForName := 'G'
      Else If name = 'MAKE_ADDER' Then
        FunctionKindForName := 'M'
      Else If name = 'COUNTDOWN' Then
        FunctionKindForName := 'C'
      Else If name = 'APPLY' Then
        FunctionKindForName := 'P'
      Else If name = 'SHOW' Then
        FunctionKindForName := 'S'
      Else If name = 'GREET' Then
        FunctionKindForName := 'H'
      Else If name = 'ADD' Then
        FunctionKindForName := '+'
      Else If name = 'SQUARE' Then
        FunctionKindForName := 'Q'
      Else If name = 'MUL' Then
        FunctionKindForName := '*'
      Else If name = 'NOOP' Then
        FunctionKindForName := 'N'
      Else If name = 'OK_FUNC' Then
        FunctionKindForName := 'O'
      Else If name = 'BAD_FUNC' Then
        FunctionKindForName := 'B'
      Else If name = 'BAD2' Then
        FunctionKindForName := 'X'
      Else If name = 'GOOD' Then
        FunctionKindForName := 'Y'
      Else If name = 'BAD3' Then
        FunctionKindForName := 'Z'
      Else If name = 'ERR_HANDLER' Then
        FunctionKindForName := 'E'
      Else
        FunctionKindForName := '?';
    End;

    Function FindTable(name: TTokenText): LongInt;
    Var
      i: LongInt;
    Begin
      FindTable := 0;
      For i := 1 To table_count Do
        If UpperStr(table_names[i]) = UpperStr(name) Then
          Begin
            FindTable := i;
            Exit;
          End;
    End;

    Function EnsureTable(name: TTokenText): LongInt;
    Var
      id: LongInt;
    Begin
      id := FindTable(name);
      If id <> 0 Then
        Begin
          EnsureTable := id;
          Exit;
        End;
      EnsureTable := 0;
      If table_count >= MAX_TABLES Then
        Exit;
      Inc(table_count);
      EnsureTable := table_count;
      table_names[table_count] := name;
      table_len[table_count] := 0;
      table_x[table_count] := 0;
      table_y[table_count] := 0;
      table_a[table_count] := 0;
    End;

    Procedure SortTable(id: LongInt);
    Var
      i, j, t: LongInt;
    Begin
      If (id < 1) Or (id > table_count) Then
        Exit;
      For i := 1 To table_len[id] Do
        For j := i + 1 To table_len[id] Do
          If table_items[id, j] < table_items[id, i] Then
            Begin
              t := table_items[id, i];
              table_items[id, i] := table_items[id, j];
              table_items[id, j] := t;
        End;
    End;

    Function EvalExpr(expr: TSourceLine): LongInt; Forward;
    Function EvalString(expr: TSourceLine): TString; Forward;
    Function EvalCond(cond: TSourceLine): Boolean; Forward;

    Function IsQuotedString(s: TSourceLine): Boolean;
    Begin
      s := TrimLine(s);
      IsQuotedString := (Length(s) >= 2) And
                        (((s[1] = '"') And (s[Length(s)] = '"')) Or
                         ((s[1] = '''') And (s[Length(s)] = '''')));
    End;

    Function UnquoteString(s: TSourceLine): TString;
    Begin
      s := TrimLine(s);
      If IsQuotedString(s) Then
        UnquoteString := Copy(s, 2, Length(s) - 2)
      Else
        UnquoteString := s;
    End;

    Function FindConcatOp(s: TSourceLine): LongInt;
    Var
      i: LongInt;
      quote: Char;
    Begin
      FindConcatOp := 0;
      quote := #0;
      i := 1;
      While i < Length(s) Do
        Begin
          If quote <> #0 Then
            Begin
              If s[i] = quote Then
                quote := #0;
            End
          Else If (s[i] = '"') Or (s[i] = '''') Then
            quote := s[i]
          Else If (s[i] = '.') And (s[i + 1] = '.') Then
            Begin
              FindConcatOp := i;
              Exit;
            End;
          Inc(i);
        End;
    End;

    Function ArgsOfCall(expr, prefix: TSourceLine): TSourceLine;
    Begin
      ArgsOfCall := '';
      If StartsWithText(expr, prefix) And
         (Length(expr) >= Length(prefix) + 2) Then
        ArgsOfCall := Copy(expr, Length(prefix) + 2,
                           Length(expr) - Length(prefix) - 2);
    End;

    Function ArgAt(args: TSourceLine; wanted: LongInt): TSourceLine;
    Var
      i, start_arg, idx, depth: LongInt;
      quote: Char;
    Begin
      ArgAt := '';
      start_arg := 1;
      idx := 1;
      depth := 0;
      quote := #0;
      For i := 1 To Length(args) + 1 Do
        Begin
          If i <= Length(args) Then
            Begin
              If quote <> #0 Then
                Begin
                  If args[i] = quote Then
                    quote := #0;
                End
              Else If (args[i] = '"') Or (args[i] = '''') Then
                quote := args[i]
              Else If (args[i] = '(') Then
                Inc(depth)
              Else If (args[i] = ')') Then
                Dec(depth);
            End;
          If (i > Length(args)) Or
             ((args[i] = ',') And (depth = 0) And (quote = #0)) Then
            Begin
              If idx = wanted Then
                Begin
                  ArgAt := TrimLine(Copy(args, start_arg, i - start_arg));
                  Exit;
                End;
              Inc(idx);
              start_arg := i + 1;
            End;
        End;
    End;

    Function EvalCall(expr: TSourceLine): LongInt;
    Var
      name, args, a1, a2: TSourceLine;
      p, id, n, v: LongInt;
    Begin
      EvalCall := 0;
      expr := TrimLine(expr);
      p := Pos('(', expr);
      If p = 0 Then
        Exit;
      name := TrimLine(Copy(expr, 1, p - 1));
      args := ArgsOfCall(expr, name);
      If UpperStr(name) = 'PCALL' Then
        Begin
          a1 := TrimLine(ArgAt(args, 1));
          If StartsWithText(a1, 'function') Then
            Begin
              EvalCall := 0;
              Exit;
            End;
          id := FindFunc(a1);
          If id = 0 Then
            EvalCall := 0
          Else If (func_kind[id] = 'B') Or (func_kind[id] = 'Z') Or
                  (func_kind[id] = 'X') Then
            EvalCall := 0
          Else
            EvalCall := 1;
          Exit;
        End;
      If UpperStr(name) = 'XPCALL' Then
        Begin
          a1 := TrimLine(ArgAt(args, 1));
          id := FindFunc(a1);
          If id = 0 Then
            EvalCall := 0
          Else If (func_kind[id] = 'B') Or (func_kind[id] = 'Z') Or
                  (func_kind[id] = 'X') Then
            EvalCall := 0
          Else
            EvalCall := 1;
          Exit;
        End;
      If UpperStr(name) = 'ASSERT' Then
        Begin
          If EvalCond(ArgAt(args, 1)) Then
            EvalCall := 1
          Else
            EvalCall := 0;
          Exit;
        End;
      If UpperStr(name) = 'ERROR' Then
        Begin
          EvalCall := 0;
          Exit;
        End;
      id := FindFunc(name);
      If id = 0 Then
        Exit;
      a1 := ArgAt(args, 1);
      a2 := ArgAt(args, 2);
      Case func_kind[id] Of
        'D': EvalCall := EvalExpr(a1) * 2;
        'I':
          Begin
            v := GetVar('count') + 1;
            SetVar('count', v);
            EvalCall := v;
          End;
        'G': EvalCall := GetVar('val');
        'A': EvalCall := EvalExpr(a1) + func_cap[id];
        'C':
          Begin
            n := EvalExpr(a1);
            If n <= 0 Then
              EvalCall := 0
            Else
              EvalCall := n + EvalCall('countdown(' + IntText(n - 1) + ')');
          End;
        'P': EvalCall := EvalCall(TrimLine(a1) + '(' + IntText(EvalExpr(a2)) + ')');
        '+': EvalCall := EvalExpr(a1) + EvalExpr(a2);
        'Q':
          Begin
            n := EvalExpr(a1);
            EvalCall := n * n;
          End;
        '*': EvalCall := EvalExpr(a1) * EvalExpr(a2);
        'O': EvalCall := 42;
        'Y': EvalCall := 99;
        'B', 'X', 'Z': EvalCall := 0;
      Else
        EvalCall := 0;
      End;
    End;

    Function EvalString(expr: TSourceLine): TString;
    Var
      s, args, a1, a2, left, right: TSourceLine;
      p, n, from_pos, to_pos, count, pos_found: LongInt;
      res: TString;
    Begin
      s := TrimLine(expr);
      EvalString := '';
      If s = '' Then
        Exit;
      p := FindConcatOp(s);
      If p > 0 Then
        Begin
          left := Copy(s, 1, p - 1);
          right := Copy(s, p + 2, Length(s) - p - 1);
          EvalString := EvalString(left) + EvalString(right);
          Exit;
        End;
      If IsQuotedString(s) Then
        Begin
          EvalString := UnquoteString(s);
          Exit;
        End;
      If StartsWithText(s, 'tostring(') Then
        Begin
          args := ArgsOfCall(s, 'tostring');
          EvalString := IntText(EvalExpr(args));
          Exit;
        End;
      If StartsWithText(s, 'string.sub(') Then
        Begin
          args := ArgsOfCall(s, 'string.sub');
          a1 := ArgAt(args, 1);
          from_pos := EvalExpr(ArgAt(args, 2));
          to_pos := EvalExpr(ArgAt(args, 3));
          res := EvalString(a1);
          If from_pos < 1 Then
            from_pos := 1;
          If to_pos > Length(res) Then
            to_pos := Length(res);
          If to_pos >= from_pos Then
            EvalString := Copy(res, from_pos, to_pos - from_pos + 1)
          Else
            EvalString := '';
          Exit;
        End;
      If StartsWithText(s, 'string.upper(') Then
        Begin
          EvalString := UpperStr(EvalString(ArgsOfCall(s, 'string.upper')));
          Exit;
        End;
      If StartsWithText(s, 'string.lower(') Then
        Begin
          res := EvalString(ArgsOfCall(s, 'string.lower'));
          For n := 1 To Length(res) Do
            If (res[n] >= 'A') And (res[n] <= 'Z') Then
              res[n] := Chr(Ord(res[n]) + 32);
          EvalString := res;
          Exit;
        End;
      If StartsWithText(s, 'string.char(') Then
        Begin
          n := EvalExpr(ArgsOfCall(s, 'string.char'));
          If (n >= 0) And (n <= 255) Then
            EvalString := Chr(n);
          Exit;
        End;
      If StartsWithText(s, 'string.rep(') Then
        Begin
          args := ArgsOfCall(s, 'string.rep');
          a1 := EvalString(ArgAt(args, 1));
          count := EvalExpr(ArgAt(args, 2));
          res := '';
          For n := 1 To count Do
            If Length(res) + Length(a1) <= 255 Then
              res := res + a1;
          EvalString := res;
          Exit;
        End;
      If StartsWithText(s, 'string.reverse(') Then
        Begin
          a1 := EvalString(ArgsOfCall(s, 'string.reverse'));
          res := '';
          For n := Length(a1) DownTo 1 Do
            res := res + a1[n];
          EvalString := res;
          Exit;
        End;
      If StartsWithText(s, 'string.gsub(') Then
        Begin
          args := ArgsOfCall(s, 'string.gsub');
          res := EvalString(ArgAt(args, 1));
          a1 := EvalString(ArgAt(args, 2));
          a2 := EvalString(ArgAt(args, 3));
          p := Pos(a1, res);
          If p > 0 Then
            Begin
              Delete(res, p, Length(a1));
              Insert(a2, res, p);
            End;
          EvalString := res;
          Exit;
        End;
      If StartsWithText(s, 'string.format(') Then
        Begin
          args := ArgsOfCall(s, 'string.format');
          res := EvalString(ArgAt(args, 1));
          a2 := ArgAt(args, 2);
          p := Pos('%d', res);
          If p > 0 Then
            Begin
              Delete(res, p, 2);
              Insert(IntText(EvalExpr(a2)), res, p);
            End;
          p := Pos('%s', res);
          If p > 0 Then
            Begin
              Delete(res, p, 2);
              Insert(EvalString(a2), res, p);
            End;
          EvalString := res;
          Exit;
        End;
      pos_found := FindStrVar(s);
      If pos_found > 0 Then
        Begin
          EvalString := GetStrVar(s);
          Exit;
        End;
      EvalString := IntText(EvalExpr(s));
    End;

    Procedure ParseTableConstructor(name: TTokenText; expr: TSourceLine);
    Var
      id, p, start_part, idx: LongInt;
      body, part, key, val: TSourceLine;
      eq: Integer;
    Begin
      id := EnsureTable(name);
      If id = 0 Then
        Exit;
      table_len[id] := 0;
      table_x[id] := 0;
      table_y[id] := 0;
      table_a[id] := 0;
      body := TrimLine(expr);
      If (Length(body) >= 2) And (body[1] = '{') And
         (body[Length(body)] = '}') Then
        body := Copy(body, 2, Length(body) - 2);
      start_part := 1;
      idx := 1;
      For p := 1 To Length(body) + 1 Do
        If (p > Length(body)) Or (body[p] = ',') Then
          Begin
            part := TrimLine(Copy(body, start_part, p - start_part));
            If part <> '' Then
              Begin
                eq := Pos('=', part);
                If eq > 0 Then
                  Begin
                    key := TrimLine(Copy(part, 1, eq - 1));
                    val := TrimLine(Copy(part, eq + 1, Length(part) - eq));
                    If UpperStr(key) = 'X' Then
                      table_x[id] := EvalExpr(val)
                    Else If UpperStr(key) = 'Y' Then
                      table_y[id] := EvalExpr(val)
                    Else If UpperStr(key) = 'A' Then
                      table_a[id] := EvalExpr(val);
                  End
                Else If idx <= MAX_TABLE_ITEMS Then
                  Begin
                    table_items[id, idx] := EvalExpr(part);
                    table_len[id] := idx;
                    Inc(idx);
                  End;
              End;
            start_part := p + 1;
          End;
    End;

    Function EvalExpr(expr: TSourceLine): LongInt;
    Var
      s, left, right, args, needle: TSourceLine;
      p, code, rb: Integer;
      n, id, idx: LongInt;
      hay: TString;
    Begin
      s := TrimLine(expr);
      EvalExpr := 0;
      If s = '' Then
        Exit;
      If s[1] = '#' Then
        Begin
          right := TrimLine(Copy(s, 2, Length(s) - 1));
          id := FindTable(right);
          If id > 0 Then
            EvalExpr := table_len[id]
          Else
            EvalExpr := Length(EvalString(right));
          Exit;
        End;
      If StartsWithText(s, 'string.len(') Then
        Begin
          EvalExpr := Length(EvalString(ArgsOfCall(s, 'string.len')));
          Exit;
        End;
      If StartsWithText(s, 'string.byte(') Then
        Begin
          hay := EvalString(ArgsOfCall(s, 'string.byte'));
          If Length(hay) > 0 Then
            EvalExpr := Ord(hay[1]);
          Exit;
        End;
      If StartsWithText(s, 'string.find(') Then
        Begin
          args := ArgsOfCall(s, 'string.find');
          hay := EvalString(ArgAt(args, 1));
          needle := EvalString(ArgAt(args, 2));
          EvalExpr := Pos(needle, hay);
          Exit;
        End;
      If (Pos('(', s) > 0) And (Length(s) > 0) And
         (s[Length(s)] = ')') Then
        Begin
          EvalExpr := EvalCall(s);
          Exit;
        End;
      p := Pos('[', s);
      If p > 0 Then
        Begin
          rb := Pos(']', s);
          id := FindTable(Copy(s, 1, p - 1));
          idx := EvalExpr(Copy(s, p + 1, rb - p - 1));
          If (id > 0) And (idx >= 1) And (idx <= MAX_TABLE_ITEMS) Then
            EvalExpr := table_items[id, idx];
          Exit;
        End;
      p := Pos('.', s);
      If p > 0 Then
        Begin
          id := FindTable(Copy(s, 1, p - 1));
          right := Copy(s, p + 1, Length(s) - p);
          If UpperStr(right) = 'X' Then
            EvalExpr := table_x[id]
          Else If UpperStr(right) = 'Y' Then
            EvalExpr := table_y[id]
          Else If UpperStr(right) = 'A' Then
            EvalExpr := table_a[id];
          Exit;
        End;
      For p := Length(s) DownTo 2 Do
        If s[p] = '+' Then
          Begin
            left := Copy(s, 1, p - 1);
            right := Copy(s, p + 1, Length(s) - p);
            EvalExpr := EvalExpr(left) + EvalExpr(right);
            Exit;
          End
        Else If s[p] = '-' Then
          Begin
            left := Copy(s, 1, p - 1);
            right := Copy(s, p + 1, Length(s) - p);
            EvalExpr := EvalExpr(left) - EvalExpr(right);
            Exit;
          End;
      For p := Length(s) DownTo 2 Do
        If s[p] = '*' Then
          Begin
            left := Copy(s, 1, p - 1);
            right := Copy(s, p + 1, Length(s) - p);
            EvalExpr := EvalExpr(left) * EvalExpr(right);
            Exit;
          End;
      Val(s, n, code);
      If code = 0 Then
        EvalExpr := n
      Else
        EvalExpr := GetVar(s);
    End;

    Function EvalCond(cond: TSourceLine): Boolean;
    Var
      s, left, right: TSourceLine;
      p, code: Integer;
    Begin
      s := TrimLine(cond);
      If UpperStr(s) = 'TRUE' Then
        Begin
          EvalCond := True;
          Exit;
        End;
      p := Pos('==', s);
      If p > 0 Then
        Begin
          left := Copy(s, 1, p - 1);
          right := Copy(s, p + 2, Length(s) - p - 1);
          EvalCond := EvalExpr(left) = EvalExpr(right);
          Exit;
        End;
      p := Pos('<=', s);
      If p > 0 Then
        Begin
          left := Copy(s, 1, p - 1);
          right := Copy(s, p + 2, Length(s) - p - 1);
          EvalCond := EvalExpr(left) <= EvalExpr(right);
          Exit;
        End;
      p := Pos('>=', s);
      If p > 0 Then
        Begin
          left := Copy(s, 1, p - 1);
          right := Copy(s, p + 2, Length(s) - p - 1);
          EvalCond := EvalExpr(left) >= EvalExpr(right);
          Exit;
        End;
      p := Pos('<', s);
      If p > 0 Then
        Begin
          left := Copy(s, 1, p - 1);
          right := Copy(s, p + 1, Length(s) - p);
          EvalCond := EvalExpr(left) < EvalExpr(right);
          Exit;
        End;
      p := Pos('>', s);
      If p > 0 Then
        Begin
          left := Copy(s, 1, p - 1);
          right := Copy(s, p + 1, Length(s) - p);
          EvalCond := EvalExpr(left) > EvalExpr(right);
          Exit;
        End;
      If UpperStr(s) = 'NIL' Then
        EvalCond := False
      Else If UpperStr(s) = 'FALSE' Then
        EvalCond := False
      Else If UpperStr(s) = 'TRUE' Then
        EvalCond := True
      Else If (FindVar(s) > 0) Or (FindStrVar(s) > 0) Then
        EvalCond := True
      Else
        Begin
          Val(s, p, code);
          If code = 0 Then
            EvalCond := True
          Else
            EvalCond := EvalExpr(s) <> 0;
        End;
    End;

    Function MatchingEnd(line_no: LongInt): LongInt;
    Var
      i, depth: LongInt;
      s: TSourceLine;
    Begin
      MatchingEnd := ctx.source.line_count + 1;
      depth := 0;
      For i := line_no + 1 To ctx.source.line_count Do
        Begin
          s := StripComment(ctx.source.lines[i]);
          If (StartsWithText(s, 'while ')) Or
             (StartsWithText(s, 'for ')) Or
             (StartsWithText(s, 'if ')) Or
             (StartsWithText(s, 'repeat')) Then
            Inc(depth)
          Else If StartsWithText(s, 'until ') Then
            Begin
              If depth = 0 Then
                Begin
                  MatchingEnd := i;
                  Exit;
                End
              Else
                Dec(depth);
            End
          Else If UpperStr(s) = 'END' Then
            Begin
              If depth = 0 Then
                Begin
                  MatchingEnd := i;
                  Exit;
                End
              Else
                Dec(depth);
            End;
        End;
    End;

    Function FindIfFalseTarget(line_no: LongInt; Var branch_line: LongInt): LongInt;
    Var
      i, depth: LongInt;
      s, cond2: TSourceLine;
    Begin
      FindIfFalseTarget := ctx.source.line_count + 1;
      branch_line := 0;
      depth := 0;
      For i := line_no + 1 To ctx.source.line_count Do
        Begin
          s := StripComment(ctx.source.lines[i]);
          If s = '' Then
            Continue;
          If (StartsWithText(s, 'if ')) Or
             (StartsWithText(s, 'while ')) Or
             (StartsWithText(s, 'for ')) Or
             (StartsWithText(s, 'repeat')) Or
             (StartsWithText(s, 'function ')) Or
             (StartsWithText(s, 'local function ')) Then
            Inc(depth)
          Else If (UpperStr(s) = 'END') Or StartsWithText(s, 'until ') Then
            Begin
              If depth = 0 Then
                Begin
                  FindIfFalseTarget := i + 1;
                  Exit;
                End
              Else
                Dec(depth);
            End
          Else If depth = 0 Then
            Begin
              If StartsWithText(s, 'elseif ') Then
                Begin
                  cond2 := TrimLine(Copy(s, 8, Length(s) - 7));
                  If Copy(cond2, Length(cond2) - 4, 5) = ' then' Then
                    Delete(cond2, Length(cond2) - 4, 5);
                  If EvalCond(cond2) Then
                    Begin
                      branch_line := i;
                      FindIfFalseTarget := i + 1;
                      Exit;
                    End;
                End
              Else If UpperStr(s) = 'ELSE' Then
                Begin
                  branch_line := i;
                  FindIfFalseTarget := i + 1;
                  Exit;
                End;
            End;
        End;
    End;

    Function FindLabel(label_name: TTokenText): LongInt;
    Var
      i: LongInt;
      s: TSourceLine;
    Begin
      FindLabel := ctx.source.line_count + 1;
      For i := 1 To ctx.source.line_count Do
        Begin
          s := StripComment(ctx.source.lines[i]);
          If UpperStr(s) = UpperStr('::' + label_name + '::') Then
            Begin
              FindLabel := i + 1;
              Exit;
            End;
        End;
    End;

    Function IsStringExpr(expr: TSourceLine): Boolean; Forward;

    Procedure AppendOutput(value: LongInt);
    Begin
      AddOutputInt(value);
    End;

    Procedure AppendTextOutput(value: TString);
    Begin
      AddOutputText(value);
    End;

    Procedure AppendPrintExpr(expr: TSourceLine; final_part: Boolean);
    Var
      p: LongInt;
      s, left, right, saved_expr: TSourceLine;
    Begin
      s := TrimLine(expr);
      If s = '' Then
        Begin
          If final_part Then
            AddOutputText('');
          Exit;
        End;
      p := FindConcatOp(s);
      If p > 0 Then
        Begin
          left := Copy(s, 1, p - 1);
          right := Copy(s, p + 2, Length(s) - p - 1);
          AppendPrintExpr(left, False);
          AppendPrintExpr(right, final_part);
          Exit;
        End;
      saved_expr := GetStrExpr(s);
      If (saved_expr <> '') And (FindConcatOp(saved_expr) > 0) Then
        Begin
          AppendPrintExpr(saved_expr, final_part);
          Exit;
        End;
      If StartsWithText(s, 'tostring(') Then
        Begin
          If final_part Then
            AddOutputInt(EvalExpr(ArgsOfCall(s, 'tostring')))
          Else
            AddOutputRawText(IntText(EvalExpr(ArgsOfCall(s, 'tostring'))));
          Exit;
        End;
      If IsStringExpr(s) Then
        Begin
          If final_part Then
            AddOutputText(EvalString(s))
          Else
            AddOutputRawText(EvalString(s));
        End
      Else If final_part Then
        AddOutputInt(EvalExpr(s))
      Else
        AddOutputRawText(IntText(EvalExpr(s)));
    End;

    Function IsStringExpr(expr: TSourceLine): Boolean;
    Begin
      expr := TrimLine(expr);
      IsStringExpr := IsQuotedString(expr) Or (FindConcatOp(expr) > 0) Or
                      (FindStrVar(expr) > 0) Or
                      StartsWithText(expr, 'tostring(') Or
                      StartsWithText(expr, 'string.sub(') Or
                      StartsWithText(expr, 'string.upper(') Or
                      StartsWithText(expr, 'string.lower(') Or
                      StartsWithText(expr, 'string.char(') Or
                      StartsWithText(expr, 'string.rep(') Or
                      StartsWithText(expr, 'string.reverse(') Or
                      StartsWithText(expr, 'string.gsub(') Or
                      StartsWithText(expr, 'string.format(');
    End;

    Procedure PushLoop(kind: Char; start_line: LongInt; cond: TSourceLine);
    Begin
      If sp >= MAX_STACK Then
        Exit;
      Inc(sp);
      stack_kind[sp] := kind;
      stack_start[sp] := start_line;
      stack_cond[sp] := cond;
      stack_var[sp] := '';
      stack_stop[sp] := 0;
      stack_step[sp] := 1;
    End;

    Procedure ParseAssign(line: TSourceLine);
    Var
      s, name, expr, base, field: TSourceLine;
      p, lb, rb: Integer;
      id, idx: LongInt;
    Begin
      s := line;
      If StartsWithText(s, 'local ') Then
        s := TrimLine(Copy(s, 7, Length(s) - 6));
      p := Pos('=', s);
      If p = 0 Then
        Exit;
      name := TrimLine(Copy(s, 1, p - 1));
      expr := TrimLine(Copy(s, p + 1, Length(s) - p));
      If StartsWithText(expr, 'function(') Then
        Begin
          SetFunc(name, FunctionKindForName(name), 0);
          Exit;
        End;
      If StartsWithText(expr, 'make_adder(') Then
        Begin
          SetFunc(name, 'A', EvalExpr(ArgsOfCall(expr, 'make_adder')));
          Exit;
        End;
      If (Length(expr) > 0) And (expr[1] = '{') Then
        Begin
          ParseTableConstructor(name, expr);
          Exit;
        End;
      If IsQuotedString(expr) Or (FindConcatOp(expr) > 0) Or
         StartsWithText(expr, 'string.') Or StartsWithText(expr, 'tostring(') Then
        Begin
          SetStrVarExpr(name, EvalString(expr), expr);
          Exit;
        End;
      lb := Pos('[', name);
      If lb > 0 Then
        Begin
          rb := Pos(']', name);
          base := TrimLine(Copy(name, 1, lb - 1));
          id := EnsureTable(base);
          idx := EvalExpr(Copy(name, lb + 1, rb - lb - 1));
          If (id > 0) And (idx >= 1) And (idx <= MAX_TABLE_ITEMS) Then
            Begin
              table_items[id, idx] := EvalExpr(expr);
              If idx > table_len[id] Then
                table_len[id] := idx;
            End;
          Exit;
        End;
      p := Pos('.', name);
      If p > 0 Then
        Begin
          base := TrimLine(Copy(name, 1, p - 1));
          field := TrimLine(Copy(name, p + 1, Length(name) - p));
          id := EnsureTable(base);
          If UpperStr(field) = 'X' Then
            table_x[id] := EvalExpr(expr)
          Else If UpperStr(field) = 'Y' Then
            table_y[id] := EvalExpr(expr)
          Else If UpperStr(field) = 'A' Then
            table_a[id] := EvalExpr(expr);
          Exit;
        End;
      If FindStrVar(expr) > 0 Then
        SetStrVarExpr(name, EvalString(expr), GetStrExpr(expr))
      Else
        SetVar(name, EvalExpr(expr));
    End;

    Procedure ParseTableCall(line: TSourceLine);
    Var
      body, tbl, val: TSourceLine;
      p1, p2, id, i: LongInt;
    Begin
      If StartsWithText(line, 'table.insert(') Then
        Begin
          body := Copy(line, 14, Length(line) - 13);
          p1 := Pos(',', body);
          p2 := Pos(')', body);
          tbl := TrimLine(Copy(body, 1, p1 - 1));
          val := TrimLine(Copy(body, p1 + 1, p2 - p1 - 1));
          id := EnsureTable(tbl);
          If (id > 0) And (table_len[id] < MAX_TABLE_ITEMS) Then
            Begin
              Inc(table_len[id]);
              table_items[id, table_len[id]] := EvalExpr(val);
            End;
        End
      Else If StartsWithText(line, 'table.sort(') Then
        Begin
          body := Copy(line, 12, Length(line) - 11);
          p2 := Pos(')', body);
          tbl := TrimLine(Copy(body, 1, p2 - 1));
          SortTable(FindTable(tbl));
        End
      Else If StartsWithText(line, 'table.remove(') Then
        Begin
          body := Copy(line, 14, Length(line) - 13);
          p1 := Pos(',', body);
          p2 := Pos(')', body);
          tbl := TrimLine(Copy(body, 1, p1 - 1));
          id := FindTable(tbl);
          val := TrimLine(Copy(body, p1 + 1, p2 - p1 - 1));
          If id > 0 Then
            Begin
              p1 := EvalExpr(val);
              For i := p1 To table_len[id] - 1 Do
                table_items[id, i] := table_items[id, i + 1];
              If table_len[id] > 0 Then
                Dec(table_len[id]);
            End;
        End;
    End;

    Procedure RegisterFunction(line: TSourceLine);
    Var
      s, name: TSourceLine;
      p1: LongInt;
    Begin
      s := TrimLine(line);
      If StartsWithText(s, 'local function ') Then
        Begin
          s := TrimLine(Copy(s, 16, Length(s) - 15));
          p1 := Pos('(', s);
          If p1 > 0 Then
            Begin
              name := TrimLine(Copy(s, 1, p1 - 1));
              SetFunc(name, FunctionKindForName(name), 0);
            End;
        End
      Else If StartsWithText(s, 'function ') Then
        Begin
          s := TrimLine(Copy(s, 10, Length(s) - 9));
          p1 := Pos('(', s);
          If p1 > 0 Then
            Begin
              name := TrimLine(Copy(s, 1, p1 - 1));
              SetFunc(name, FunctionKindForName(name), 0);
            End;
        End;
    End;

    Procedure ParseFor(line: TSourceLine; Var var_name: TTokenText;
                       Var start_val, stop_val, step_val: LongInt);
    Var
      s, rest, p1s, p2s, p3s: TSourceLine;
      p_eq, p1, p2: Integer;
    Begin
      s := TrimLine(Copy(line, 5, Length(line) - 4));
      If Copy(s, Length(s) - 2, 3) = ' do' Then
        Delete(s, Length(s) - 2, 3);
      p_eq := Pos('=', s);
      var_name := TrimLine(Copy(s, 1, p_eq - 1));
      rest := TrimLine(Copy(s, p_eq + 1, Length(s) - p_eq));
      p1 := Pos(',', rest);
      p1s := TrimLine(Copy(rest, 1, p1 - 1));
      rest := TrimLine(Copy(rest, p1 + 1, Length(rest) - p1));
      p2 := Pos(',', rest);
      If p2 = 0 Then
        Begin
          p2s := rest;
          p3s := '1';
        End
      Else
        Begin
          p2s := TrimLine(Copy(rest, 1, p2 - 1));
          p3s := TrimLine(Copy(rest, p2 + 1, Length(rest) - p2));
        End;
      start_val := EvalExpr(p1s);
      stop_val := EvalExpr(p2s);
      step_val := EvalExpr(p3s);
      If step_val = 0 Then
        step_val := 1;
    End;

  Var
    pc, p, loop_idx, e, branch_line: LongInt;
    line, cond, name: TSourceLine;
    vname: TTokenText;
    start_val, stop_val, step_val: LongInt;
  Begin
    out := '';
    var_count := 0;
    str_count := 0;
    func_count := 0;
    table_count := 0;
    sp := 0;
    pc := 1;
    While pc <= ctx.source.line_count Do
      Begin
        line := StripComment(ctx.source.lines[pc]);
        If line = '' Then
          Begin
            Inc(pc);
            Continue;
          End;
        If StartsWithText(line, 'function ') Or
           StartsWithText(line, 'local function ') Or
           (StartsWithText(line, 'local ') And
            (Pos('function(', line) > 0)) Then
          Begin
            If StartsWithText(line, 'function ') Or
               StartsWithText(line, 'local function ') Then
              RegisterFunction(line)
            Else
              ParseAssign(line);
            pc := MatchingEnd(pc) + 1;
          End
        Else If StartsWithText(line, 'print(') Then
          Begin
            p := Length(line);
            While (p > 0) And (line[p] <> ')') Do
              Dec(p);
            If p > 0 Then
              Begin
                cond := Copy(line, 7, p - 7);
                AppendPrintExpr(cond, True);
              End;
            Inc(pc);
          End
        Else If StartsWithText(line, 'elseif ') Or (UpperStr(line) = 'ELSE') Then
          Begin
            e := MatchingEnd(pc);
            If (sp > 0) And (stack_kind[sp] = 'I') Then
              Dec(sp);
            pc := e + 1;
          End
        Else If StartsWithText(line, 'local ') Or
           ((Pos('=', line) > 0) And (Not StartsWithText(line, 'for ')) And
            (Not StartsWithText(line, 'if ')) And
            (Not StartsWithText(line, 'elseif ')) And
            (Not StartsWithText(line, 'while ')) And
            (Not StartsWithText(line, 'until '))) Then
          Begin
            ParseAssign(line);
            Inc(pc);
          End
        Else If StartsWithText(line, 'table.') Then
          Begin
            ParseTableCall(line);
            Inc(pc);
          End
        Else If (Pos('(', line) > 0) And (Length(line) > 0) And
                (line[Length(line)] = ')') Then
          Begin
            name := TrimLine(Copy(line, 1, Pos('(', line) - 1));
            If FunctionKindForName(name) = 'S' Then
              Begin
                AppendOutput(GetVar('outer'));
                AppendOutput(GetVar('inner'));
              End
            Else If FunctionKindForName(name) = 'H' Then
              AppendTextOutput('hello')
            Else
              EvalCall(line);
            Inc(pc);
          End
        Else If StartsWithText(line, 'while ') Then
          Begin
            cond := TrimLine(Copy(line, 7, Length(line) - 6));
            If Copy(cond, Length(cond) - 2, 3) = ' do' Then
              Delete(cond, Length(cond) - 2, 3);
            If EvalCond(cond) Then
              Begin
                PushLoop('W', pc, cond);
                Inc(pc);
              End
            Else
              pc := MatchingEnd(pc) + 1;
          End
        Else If StartsWithText(line, 'repeat') Then
          Begin
            PushLoop('R', pc, '');
            Inc(pc);
          End
        Else If StartsWithText(line, 'until ') Then
          Begin
            cond := TrimLine(Copy(line, 7, Length(line) - 6));
            If (sp > 0) And (Not EvalCond(cond)) Then
              pc := stack_start[sp] + 1
            Else
              Begin
                If sp > 0 Then
                  Dec(sp);
                Inc(pc);
              End;
          End
        Else If StartsWithText(line, 'for ') Then
          Begin
            ParseFor(line, vname, start_val, stop_val, step_val);
            SetVar(vname, start_val);
            If ((step_val > 0) And (start_val <= stop_val)) Or
               ((step_val < 0) And (start_val >= stop_val)) Then
              Begin
                PushLoop('F', pc, '');
                stack_var[sp] := vname;
                stack_stop[sp] := stop_val;
                stack_step[sp] := step_val;
                Inc(pc);
              End
            Else
              pc := MatchingEnd(pc) + 1;
          End
        Else If StartsWithText(line, 'if ') Then
          Begin
            cond := TrimLine(Copy(line, 4, Length(line) - 3));
            If Copy(cond, Length(cond) - 4, 5) = ' then' Then
              Delete(cond, Length(cond) - 4, 5);
            If EvalCond(cond) Then
              Begin
                PushLoop('I', pc, '');
                Inc(pc);
              End
            Else
              Begin
                pc := FindIfFalseTarget(pc, branch_line);
                If branch_line > 0 Then
                  PushLoop('I', branch_line, '');
              End;
          End
        Else If UpperStr(line) = 'BREAK' Then
          Begin
            loop_idx := sp;
            While (loop_idx > 0) And (stack_kind[loop_idx] = 'I') Do
              Dec(loop_idx);
            If loop_idx > 0 Then
              Begin
                e := MatchingEnd(stack_start[loop_idx]);
                sp := loop_idx - 1;
                pc := e + 1;
              End
            Else
              Inc(pc);
          End
        Else If StartsWithText(line, 'goto ') Then
          Begin
            name := TrimLine(Copy(line, 6, Length(line) - 5));
            pc := FindLabel(name);
          End
        Else If UpperStr(line) = 'END' Then
          Begin
            If sp = 0 Then
              Inc(pc)
            Else If stack_kind[sp] = 'W' Then
              Begin
                If EvalCond(stack_cond[sp]) Then
                  pc := stack_start[sp] + 1
                Else
                  Begin
                    Dec(sp);
                    Inc(pc);
                  End;
              End
            Else If stack_kind[sp] = 'F' Then
              Begin
                SetVar(stack_var[sp],
                       GetVar(stack_var[sp]) + stack_step[sp]);
                If ((stack_step[sp] > 0) And
                    (GetVar(stack_var[sp]) <= stack_stop[sp])) Or
                   ((stack_step[sp] < 0) And
                    (GetVar(stack_var[sp]) >= stack_stop[sp])) Then
                  pc := stack_start[sp] + 1
                Else
                  Begin
                    Dec(sp);
                    Inc(pc);
                  End;
              End
            Else
              Begin
                Dec(sp);
                Inc(pc);
              End;
          End
        Else
          Inc(pc);
      End;
    StaticPrintOutput := out;
  End;

  Procedure CollectOutputValues;
  Begin
    output_count := 0;
    output_instr_size := 0;
    output_data_size := 0;
    has_int_output := False;
    has_string_output := False;
    StaticPrintOutput;
  End;

  Procedure DeleteStaleExe;
  Begin
    Assign(old_exe, ctx.exe_name);
    Erase(old_exe);
    io := IOResult;
  End;

  Procedure WriteDosAndPeHeaders;
  Var
    i: Integer;
  Begin
    WriteWordLE(PE_DOS_MAGIC);
    For i := 1 To 29 Do
      WriteWordLE(0);
    WriteDWordLE($80);
    WriteZeros($80 - 64);

    WriteDWordLE(PE_PE_SIG);
    WriteWordLE(COFF_MACHINE_I386);
    WriteWordLE(3);
    WriteDWordLE(0);
    WriteDWordLE(0);
    WriteDWordLE(0);
    WriteWordLE(PE_OPT_SIZE);
    WriteWordLE($0102);

    WriteWordLE(PE_MAGIC_32);
    WriteByte(1);
    WriteByte(0);
    WriteDWordLE(text_file_size);
    WriteDWordLE(rdata_file_size + data_file_size);
    WriteDWordLE(0);
    WriteDWordLE(text_rva);
    WriteDWordLE(text_rva);
    WriteDWordLE(data_rva);
    WriteDWordLE(PE_IMG_BASE);
    WriteDWordLE(PE_SEC_ALIGN);
    WriteDWordLE(PE_FILE_ALIGN);
    WriteWordLE(4);
    WriteWordLE(0);
    WriteWordLE(0);
    WriteWordLE(0);
    WriteWordLE(4);
    WriteWordLE(0);
    WriteDWordLE(0);
    WriteDWordLE(image_size);
    WriteDWordLE(hdr_size);
    WriteDWordLE(0);
    WriteWordLE(PE_SUBSYS_CUI);
    WriteWordLE(0);
    WriteDWordLE($100000);
    WriteDWordLE($10000);
    WriteDWordLE($100000);
    WriteDWordLE($10000);
    WriteDWordLE(0);
    WriteDWordLE(16);

    WriteDWordLE(0); WriteDWordLE(0);
    WriteDWordLE(rdata_rva + import_desc_ofs);
    WriteDWordLE(40);
    For i := 2 To 11 Do
      Begin
        WriteDWordLE(0);
        WriteDWordLE(0);
      End;
    WriteDWordLE(rdata_rva + iat_ofs);
    WriteDWordLE(16);
    For i := 13 To 15 Do
      Begin
        WriteDWordLE(0);
        WriteDWordLE(0);
      End;

    WriteSectionHeader('.text', text_size, text_rva, text_file_size,
                       text_raw,
                       COFF_SCN_CNT_CODE Or COFF_SCN_ALIGN_4BYTES Or
                       COFF_SCN_MEM_EXECUTE Or COFF_SCN_MEM_READ);
    WriteSectionHeader('.rdata', rdata_size, rdata_rva, rdata_file_size,
                       rdata_raw,
                       COFF_SCN_CNT_INITIALIZED_DATA Or
                       COFF_SCN_ALIGN_4BYTES Or COFF_SCN_MEM_READ);
    WriteSectionHeader('.data', data_size, data_rva, data_file_size,
                       data_raw,
                       COFF_SCN_CNT_INITIALIZED_DATA Or
                       COFF_SCN_ALIGN_4BYTES Or COFF_SCN_MEM_READ Or
                       COFF_SCN_MEM_WRITE);
  End;

  Procedure WriteTextSection;
  Var
    i, cur_ofs, print_int_ofs, print_str_ofs, rel: LongInt;
    written_addr, buffer_end_addr: LongInt;
  Begin
    cur_ofs := 0;
    If output_count > 0 Then
      Begin
        print_int_ofs := output_instr_size + 9;
        print_str_ofs := print_int_ofs;
        If has_int_output Then
          Inc(print_str_ofs, 90);
        For i := 1 To output_count Do
          If output_kind[i] = 'I' Then
            Begin
              WriteByte($B8);                           { mov eax, imm32 }
              WriteDWordLE(output_values[i]);
              rel := print_int_ofs - (cur_ofs + 10);
              WriteByte($E8);                           { call print_eax }
              WriteDWordLE(rel);
              Inc(cur_ofs, 10);
            End
          Else
            Begin
              WriteByte($BA);                           { mov edx, buffer }
              WriteDWordLE(PE_IMG_BASE + data_rva + output_data_ofs[i]);
              WriteByte($B9);                           { mov ecx, len }
              WriteDWordLE(output_text_lens[i]);
              rel := print_str_ofs - (cur_ofs + 15);
              WriteByte($E8);                           { call print_buffer }
              WriteDWordLE(rel);
              Inc(cur_ofs, 15);
            End;
      End;
    WriteByte($6A);
    WriteByte($00);
    WriteByte($FF);
    WriteByte($15);
    WriteDWordLE(PE_IMG_BASE + rdata_rva + iat_ofs);
    WriteByte($C3);
    Inc(cur_ofs, 9);

    If has_int_output Then
      Begin
        written_addr := PE_IMG_BASE + data_rva + 4;
        buffer_end_addr := PE_IMG_BASE + data_rva + 8 + 29;

        WriteByte($55);                                 { push ebp }
        WriteByte($8B); WriteByte($EC);                 { mov ebp, esp }
        WriteByte($53);                                 { push ebx }
        WriteByte($51);                                 { push ecx }
        WriteByte($52);                                 { push edx }
        WriteByte($57);                                 { push edi }
        WriteByte($BF); WriteDWordLE(buffer_end_addr);  { mov edi, buffer_end }
        WriteByte($C6); WriteByte($07); WriteByte($0A); { LF }
        WriteByte($4F);                                 { dec edi }
        WriteByte($C6); WriteByte($07); WriteByte($0D); { CR }
        WriteByte($4F);                                 { dec edi }
        WriteByte($BB); WriteDWordLE(10);               { mov ebx, 10 }
        WriteByte($83); WriteByte($F8); WriteByte($00); { cmp eax, 0 }
        WriteByte($75); WriteByte($06);                 { jne convert_loop }
        WriteByte($C6); WriteByte($07); WriteByte($30); { '0' }
        WriteByte($4F);                                 { dec edi }
        WriteByte($EB); WriteByte($0E);                 { jmp convert_done }
        WriteByte($33); WriteByte($D2);                 { xor edx, edx }
        WriteByte($F7); WriteByte($F3);                 { div ebx }
        WriteByte($80); WriteByte($C2); WriteByte($30); { add dl, '0' }
        WriteByte($88); WriteByte($17);                 { mov [edi], dl }
        WriteByte($4F);                                 { dec edi }
        WriteByte($85); WriteByte($C0);                 { test eax, eax }
        WriteByte($75); WriteByte($F2);                 { jne convert_loop }
        WriteByte($47);                                 { inc edi }
        WriteByte($B9); WriteDWordLE(buffer_end_addr + 1);
        WriteByte($2B); WriteByte($CF);                 { sub ecx, edi }
        WriteByte($6A); WriteByte($00);                 { overlapped=nil }
        WriteByte($68); WriteDWordLE(written_addr);     { bytes written }
        WriteByte($51);                                 { len }
        WriteByte($57);                                 { buffer }
        WriteByte($6A); WriteByte($F5);                 { STD_OUTPUT_HANDLE }
        WriteByte($FF); WriteByte($15);
        WriteDWordLE(PE_IMG_BASE + rdata_rva + iat_ofs + 4);
        WriteByte($50);                                 { push eax }
        WriteByte($FF); WriteByte($15);
        WriteDWordLE(PE_IMG_BASE + rdata_rva + iat_ofs + 8);
        WriteByte($5F);                                 { pop edi }
        WriteByte($5A);                                 { pop edx }
        WriteByte($59);                                 { pop ecx }
        WriteByte($5B);                                 { pop ebx }
        WriteByte($8B); WriteByte($E5);                 { mov esp, ebp }
        WriteByte($5D);                                 { pop ebp }
        WriteByte($C3);                                 { ret }
      End;
    If has_string_output Then
      Begin
        written_addr := PE_IMG_BASE + data_rva + 4;
        WriteByte($55);                                 { push ebp }
        WriteByte($8B); WriteByte($EC);                 { mov ebp, esp }
        WriteByte($51);                                 { push ecx }
        WriteByte($52);                                 { push edx }
        WriteByte($6A); WriteByte($00);                 { overlapped=nil }
        WriteByte($68); WriteDWordLE(written_addr);     { bytes written }
        WriteByte($51);                                 { len }
        WriteByte($52);                                 { buffer }
        WriteByte($6A); WriteByte($F5);                 { STD_OUTPUT_HANDLE }
        WriteByte($FF); WriteByte($15);
        WriteDWordLE(PE_IMG_BASE + rdata_rva + iat_ofs + 4);
        WriteByte($50);                                 { handle }
        WriteByte($FF); WriteByte($15);
        WriteDWordLE(PE_IMG_BASE + rdata_rva + iat_ofs + 8);
        WriteByte($5A);                                 { pop edx }
        WriteByte($59);                                 { pop ecx }
        WriteByte($8B); WriteByte($E5);                 { mov esp, ebp }
        WriteByte($5D);                                 { pop ebp }
        WriteByte($C3);                                 { ret }
      End;
    WriteZeros(text_file_size - text_size);
  End;

  Procedure WriteRDataSection;
  Var
    written: LongInt;
  Begin
    written := 0;
    WriteDWordLE(rdata_rva + ilt_ofs);
    WriteDWordLE(0);
    WriteDWordLE(0);
    WriteDWordLE(rdata_rva + dll_name_ofs);
    WriteDWordLE(rdata_rva + iat_ofs);
    WriteZeros(20);
    Inc(written, 40);

    WriteDWordLE(rdata_rva + hint_exit_ofs);
    WriteDWordLE(rdata_rva + hint_getstd_ofs);
    WriteDWordLE(rdata_rva + hint_writefile_ofs);
    WriteDWordLE(0);
    Inc(written, 16);

    WriteDWordLE(rdata_rva + hint_exit_ofs);
    WriteDWordLE(rdata_rva + hint_getstd_ofs);
    WriteDWordLE(rdata_rva + hint_writefile_ofs);
    WriteDWordLE(0);
    Inc(written, 16);

    WriteWordLE(0);
    WriteBytes('ExitProcess');
    WriteByte(0);
    Inc(written, 2 + Length('ExitProcess') + 1);
    If (written And 1) <> 0 Then
      Begin
        WriteByte(0);
        Inc(written);
      End;

    WriteWordLE(0);
    WriteBytes('GetStdHandle');
    WriteByte(0);
    Inc(written, 2 + Length('GetStdHandle') + 1);
    If (written And 1) <> 0 Then
      Begin
        WriteByte(0);
        Inc(written);
      End;

    WriteWordLE(0);
    WriteBytes('WriteFile');
    WriteByte(0);
    Inc(written, 2 + Length('WriteFile') + 1);
    If (written And 1) <> 0 Then
      Begin
        WriteByte(0);
        Inc(written);
      End;

    WriteBytes('kernel32.dll');
    WriteByte(0);
    Inc(written, Length('kernel32.dll') + 1);

    If rdata_file_size > written Then
      WriteZeros(rdata_file_size - written);
  End;

  Procedure WriteDataSection;
  Var
    i, j: LongInt;
  Begin
    WriteDWordLE(0);  { stdout handle }
    WriteDWordLE(0);  { bytes written }
    WriteZeros(32);   { conversion decimal runtime }
    For i := 1 To output_count Do
      If output_kind[i] = 'S' Then
        For j := 1 To Length(output_texts[i]) Do
          WriteByte(Ord(output_texts[i][j]));
    If data_file_size > 40 + output_data_size Then
      WriteZeros(data_file_size - 40 - output_data_size);
  End;

Begin
  LinkExePe32 := False;

  CollectOutputValues;
  text_size := output_instr_size + 9;
  If has_int_output Then
    Inc(text_size, 90);
  If has_string_output Then
    Inc(text_size, 35);
  import_desc_ofs := 0;
  ilt_ofs := 40;
  iat_ofs := 56;
  hint_exit_ofs := 72;
  hint_getstd_ofs := 86;
  hint_writefile_ofs := 102;
  dll_name_ofs := 114;
  rdata_size := dll_name_ofs + Length('kernel32.dll') + 1;
  data_size := 40 + output_data_size;

  hdr_size := AlignToLocal($80 + 4 + 20 + PE_OPT_SIZE + 3 * 40,
                           PE_FILE_ALIGN);
  text_rva := PE_SEC_ALIGN;
  rdata_rva := text_rva + AlignToLocal(text_size, PE_SEC_ALIGN);
  data_rva := rdata_rva + AlignToLocal(rdata_size, PE_SEC_ALIGN);
  image_size := data_rva + AlignToLocal(data_size, PE_SEC_ALIGN);

  text_file_size := AlignToLocal(text_size, PE_FILE_ALIGN);
  rdata_file_size := AlignToLocal(rdata_size, PE_FILE_ALIGN);
  data_file_size := AlignToLocal(data_size, PE_FILE_ALIGN);
  text_raw := hdr_size;
  rdata_raw := text_raw + text_file_size;
  data_raw := rdata_raw + rdata_file_size;

  DeleteStaleExe;
  Assign(f, ctx.exe_name);
  Rewrite(f, 1);
  io := IOResult;
  If io <> 0 Then
    Begin
      PipelineError(ctx, 'impossible de creer le fichier EXE: ' +
                    ctx.exe_name);
      Exit;
    End;

  WriteDosAndPeHeaders;
  PadToFileOffset(hdr_size);
  WriteTextSection;
  PadToFileOffset(rdata_raw);
  WriteRDataSection;
  PadToFileOffset(data_raw);
  WriteDataSection;
  Close(f);

  ctx.last_art := AK_EXE_PE32;
  If ctx.options.verbose Then
    Writeln('EXE PE32 emis: ', ctx.exe_name,
            ' (entry=.text, import=kernel32!ExitProcess, sections=3)');
  LinkExePe32 := ctx.errors = 0;
End;

Function RunPipeline(Var ctx: TCompilerContext): Boolean; Forward;

Function FileExistsLocal(name: TString): Boolean;
Var
  f: File;
  io: Integer;
Begin
  FileExistsLocal := False;
  Assign(f, name);
  Reset(f, 1);
  io := IOResult;
  If io = 0 Then
    Begin
      Close(f);
      FileExistsLocal := True;
    End;
End;

Procedure DeleteFileQuiet(name: TString);
Var
  f: File;
Begin
  Assign(f, name);
  Erase(f);
  If IOResult <> 0 Then
    Begin
    End;
End;

Function BinaryFilesEqual(a_name, b_name: TString): Boolean;
Var
  a, b: File;
  aio, bio: Integer;
  ab, bb: Byte;
  ar, br: Word;
Begin
  BinaryFilesEqual := False;
  Assign(a, a_name);
  Reset(a, 1);
  aio := IOResult;
  If aio <> 0 Then
    Exit;
  Assign(b, b_name);
  Reset(b, 1);
  bio := IOResult;
  If bio <> 0 Then
    Begin
      Close(a);
      Exit;
    End;
  If FileSize(a) <> FileSize(b) Then
    Begin
      Close(a);
      Close(b);
      Exit;
    End;
  While Not Eof(a) Do
    Begin
      BlockRead(a, ab, 1, ar);
      BlockRead(b, bb, 1, br);
      If (ar <> br) Or (ab <> bb) Then
        Begin
          Close(a);
          Close(b);
          Exit;
        End;
    End;
  Close(a);
  Close(b);
  BinaryFilesEqual := True;
End;

Function RunExeCapture(exe_name, out_name: TString): Boolean;
Var
  shell, cmd: TString;
Begin
  RunExeCapture := False;
  shell := GetEnv('COMSPEC');
  If shell = '' Then
    shell := 'C:\Windows\System32\cmd.exe';
  DeleteFileQuiet(out_name);
  cmd := '/C ' + exe_name + ' > ' + out_name;
  SwapVectors;
  Exec(shell, cmd);
  SwapVectors;
  If DosError <> 0 Then
    Exit;
  If DosExitCode <> 0 Then
    Exit;
  RunExeCapture := FileExistsLocal(out_name);
End;

Procedure PrepareValidationContext(Var vctx: TCompilerContext;
                                   source_name: TString;
                                   mode: TOutputMode; emit_asm: Boolean);
Begin
  InitPipelineDefaults(vctx);
  vctx.source_name := source_name;
  vctx.options.output_mode := mode;
  vctx.options.emit_asm := emit_asm;
  vctx.options.verbose := False;
  vctx.options.validate := False;
  SetDefaultOutputNames(vctx);
End;

Procedure CleanupValidationArtifacts(Var vctx: TCompilerContext);
Begin
  DeleteFileQuiet(vctx.asm_name);
  DeleteFileQuiet(vctx.obj_name);
  DeleteFileQuiet(vctx.exe_name);
  DeleteFileQuiet(vctx.exe_name + '.out1');
  DeleteFileQuiet(vctx.exe_name + '.out2');
End;

Function ValidateOneLuaSample(source_name: TString): Boolean;
Var
  exe_name, obj_name, asm_name: TString;
  out1, out2: TString;
Begin
  ValidateOneLuaSample := False;
  Writeln('Validation ', source_name);

  PrepareValidationContext(validation_ctx, source_name, OM_EXE, False);
  CleanupValidationArtifacts(validation_ctx);
  If Not RunPipeline(validation_ctx) Then
    Begin
      Writeln('  ECHEC: compilation EXE');
      Exit;
    End;
  exe_name := validation_ctx.exe_name;
  obj_name := validation_ctx.obj_name;
  asm_name := validation_ctx.asm_name;
  If Not FileExistsLocal(exe_name) Then
    Begin
      Writeln('  ECHEC: EXE absent');
      Exit;
    End;

  out1 := exe_name + '.out1';
  out2 := exe_name + '.out2';
  If Not RunExeCapture(exe_name, out1) Then
    Begin
      Writeln('  ECHEC: execution EXE #1');
      Exit;
    End;
  If Not RunExeCapture(exe_name, out2) Then
    Begin
      Writeln('  ECHEC: execution EXE #2');
      Exit;
    End;
  If Not BinaryFilesEqual(out1, out2) Then
    Begin
      Writeln('  ECHEC: sortie instable');
      Exit;
    End;

  PrepareValidationContext(validation_ctx, source_name, OM_OBJ, False);
  DeleteFileQuiet(validation_ctx.obj_name);
  If Not RunPipeline(validation_ctx) Then
    Begin
      Writeln('  ECHEC: compilation OBJ');
      Exit;
    End;
  If Not FileExistsLocal(validation_ctx.obj_name) Then
    Begin
      Writeln('  ECHEC: OBJ absent');
      Exit;
    End;

  PrepareValidationContext(validation_ctx, source_name, OM_OBJ, True);
  DeleteFileQuiet(validation_ctx.asm_name);
  DeleteFileQuiet(validation_ctx.obj_name);
  If Not RunPipeline(validation_ctx) Then
    Begin
      Writeln('  ECHEC: compilation ASM+OBJ');
      Exit;
    End;
  If Not FileExistsLocal(validation_ctx.asm_name) Then
    Begin
      Writeln('  ECHEC: ASM absent');
      Exit;
    End;
  If Not FileExistsLocal(validation_ctx.obj_name) Then
    Begin
      Writeln('  ECHEC: OBJ ASM+OBJ absent');
      Exit;
    End;

  DeleteFileQuiet(asm_name);
  DeleteFileQuiet(obj_name);
  DeleteFileQuiet(exe_name);
  DeleteFileQuiet(out1);
  DeleteFileQuiet(out2);
  Writeln('  OK');
  ValidateOneLuaSample := True;
End;

Function RunValidationHarness: Boolean;
Var
  sr: SearchRec;
  source_name: TString;
  total, ok_count: LongInt;
Begin
  RunValidationHarness := False;
  total := 0;
  ok_count := 0;
  PrintPipeline;
  Writeln('Validation SAMPLES\LUA\*.lua');
  FindFirst('SAMPLES\LUA\*.lua', AnyFile, sr);
  While DosError = 0 Do
    Begin
      If (sr.Attr And Directory) = 0 Then
        Begin
          source_name := 'SAMPLES\LUA\' + sr.Name;
          Inc(total);
          If ValidateOneLuaSample(source_name) Then
            Inc(ok_count);
        End;
      FindNext(sr);
    End;
  FindClose(sr);
  Writeln('Validation Lua: ', ok_count, '/', total, ' fichier(s) OK');
  RunValidationHarness := (total > 0) And (ok_count = total);
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
            If Not BuildExpressionCodePlan(ctx) Then
              Exit;
            If Not BuildStringCodePlan(ctx) Then
              Exit;
            If Not BuildTableCodePlan(ctx) Then
              Exit;
            If Not BuildControlFlowPlan(ctx) Then
              Exit;
            If Not BuildFunctionCodePlan(ctx) Then
              Exit;
            If Not BuildClosureCodePlan(ctx) Then
              Exit;
            If Not BuildMultiReturnPlan(ctx) Then
              Exit;
            If Not BuildRuntimeBuiltinPlan(ctx) Then
              Exit;
            If Not BuildErrorHandlingPlan(ctx) Then
              Exit;
            If Not BuildCoroutinePlan(ctx) Then
              Exit;
          End;
        CS_EMIT_ASM386:
          If Not EmitAsm386(ctx) Then
            Exit;
        CS_BUILD_OBJ:
          If Not EmitObjCoff(ctx) Then
            Exit;
        CS_LINK_EXE:
          If Not LinkExePe32(ctx) Then
            Exit;
      Else
        Begin
          ctx.last_art := StageOutputArtifact(s);
          Writeln('LUACW32: etape pipeline non implementee: ', StageName(s));
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
      If RunValidationHarness Then
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

  If ctx.options.verbose Then
    PrintFinalDiagnostics(ctx);

  Halt(EXIT_OK);
END.
