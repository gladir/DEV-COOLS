{ @author: Sylvain Maltais
  @created: 2026-06-17
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Modula-2 vers assembleur 80386 / Windows 32 bits
  @output: Win32 PE .EXE par defaut, COFF i386 .OBJ sur demande,
           .ASM 80386 optionnel sur demande explicite
  @license: MIT
}

{ TODO MOD2CW32 - Compilateur Modula-2 vers 80386/Win32

  DONE 01 - Definir le pipeline complet:
            source .MOD -> lexer -> parser -> tables semantiques -> IR simple
            -> ASM 80386 optionnel -> OBJ COFF i386 -> EXE PE32 par defaut.

  DONE 02 - Ajouter les options de ligne de commande:
            -c pour produire seulement un .OBJ, -S pour produire/conserver
            le .ASM sur demande explicite, -o nom_sortie, --version et -h.

  DONE 03 - Definir le modele cible Win32:
            mode plat 32 bits, sections .text/.data/.bss, alignements,
            conventions d'appel internes, prologues/epilogues et pile 80386.

  DONE 04 - Implementer un writer ASM 80386 optionnel:
            emission lisible des instructions, labels internes stables,
            donnees statiques, chaines et commentaires de diagnostic.

  DONE 05 - Implementer un writer OBJ COFF i386 minimal:
            sections, table de symboles, relocations REL32/DIR32 et donnees
            necessaires au linkage Windows 32 bits.

  DONE 06 - Implementer le linkage .OBJ -> .EXE par defaut:
            generation PE32 console minimale autonome, point d'entree,
            imports kernel32/msvcrt ou runtime interne selon le choix retenu.

  DONE 07 - Ajouter une gestion d'erreurs robuste:
            fichier, ligne, colonne, extrait fautif, erreurs lexicales,
            syntaxiques, semantiques et messages compatibles avec les samples.

  DONE 08 - Implementer le lexer Modula-2:
            identificateurs, mots reserves, entiers, chaines quote/simple quote,
            commentaires imbriques (* *), ponctuation, operateurs et EOF.

  DONE 09 - Implementer le parser des unites:
            MODULE nom; declarations IMPORT/CONST/TYPE/VAR/PROCEDURE,
            bloc BEGIN...END nom. et verification du nom final.

  DONE 10 - Implementer IMPORT et table des modules:
            resolution de InOut pour les exemples, controle des noms importes,
            preparation pour ajouter d'autres modules standards plus tard.

  DONE 11 - Definir la table des symboles et les portees:
            portee module, portees de procedures, constantes, variables,
            procedures, parametres, imports et detection des doublons.

  DONE 12 - Implementer les types scalaires de base:
            INTEGER 32 bits, CARDINAL 32 bits non signe, BOOLEAN, CHAR,
            chaines constantes et compatibilite avec les appels InOut.

  DONE 13 - Implementer CONST:
            constantes entieres, booleennes, caracteres, chaines,
            evaluation constante simple et references dans les expressions.

  DONE 14 - Implementer VAR:
            allocation globale et locale, offsets EBP, initialisation implicite
            a zero pour les donnees statiques et acces 32 bits.

  DONE 15 - Implementer les expressions:
            priorites Modula-2, +, -, *, DIV, MOD, parentheses, unaire -,
            constantes, variables et conversion en IR typee.

  DONE 16 - Implementer les comparaisons et booleens:
            =, #, <, <=, >, >=, NOT, AND, OR, evaluation court-circuit
            si necessaire et emission Jcc 80386.

  DONE 17 - Implementer les instructions de base:
            affectation :=, appels de procedures, instructions separees par ;
            blocs BEGIN...END imbriques et instruction vide.

  DONE 18 - Implementer IF:
            IF condition THEN suite [ELSIF condition THEN suite] [ELSE suite]
            END, avec labels et branchements corrects.

  DONE 19 - Implementer WHILE et REPEAT:
            WHILE condition DO suite END et REPEAT suite UNTIL condition,
            avec gestion correcte des sorties de boucle.

  DONE 20 - Implementer FOR:
            FOR i := debut TO fin [BY pas] DO suite END,
            entiers 32 bits, bornes evaluees correctement et support de INC.

  DONE 21 - Implementer procedures et parametres:
            PROCEDURE locale/exportable, appels, parametres valeur et VAR,
            pile 32 bits, retour, recursion simple et verification d'arite.

  DONE 22 - Implementer les procedures predefinies minimales:
            INC, DEC, ORD, CHR, ODD, ABS si utile, avec controle de type et
            emission directe quand possible.

  DONE 23 - Implementer le module InOut:
            WriteString, WriteLn, WriteInt au minimum pour hello_m2.mod et
            arith_m2.mod, via runtime Win32 console ou imports C.

  DONE 24 - Ajouter une suite de validation SAMPLES\MODULA2:
            compiler tous les .mod en .EXE par defaut, verifier -c et -S,
            executer hello_m2.mod et arith_m2.mod et comparer les sorties.

  DONE 25 - Stabiliser la compatibilite Turbo Pascal/Free Pascal:
            types Pascal portables, aucune dependance non TP7 si possible,
            chemins Windows, E/S binaires, endianess et documentation d'usage.
}

Program MOD2CW32;

{$IFDEF FPC}
 {$H-}
{$ENDIF}
{$I-}

Const
 MOD2CW32_VERSION = '1.0';
 MOD2_DEFAULT_EXT = '.mod';
 MOD2_ASM_EXT     = '.asm';
 MOD2_OBJ_EXT     = '.obj';
 MOD2_EXE_EXT     = '.exe';
 I386_STACK_SLOT_SIZE = 4;
 I386_ARG_BASE_OFFSET = 8;
 I386_STACK_ALIGN     = 4;
 I386_CODE_ALIGN      = 16;
 I386_DATA_ALIGN      = 4;
 I386_BSS_ALIGN       = 4;
 WIN32_SECTION_ALIGN  = 4096;
 WIN32_FILE_ALIGN     = 512;
 WIN32_IMAGE_BASE     = $00400000;
 FLAT_TEXT_SECTION    = '.text';
 FLAT_DATA_SECTION    = '.data';
 FLAT_BSS_SECTION     = '.bss';
 MOD2_ENTRY_LABEL     = '_MOD2START';
 MOD2_INTERNAL_PREFIX  = '_M2L_';
 MOD2_DATA_PREFIX      = '_M2D_';
 MOD2_RUNTIME_PREFIX   = '_M2RT_';
 COFF_MACHINE_I386     = $014C;
 COFF_FILE_HEADER_SIZE = 20;
 COFF_SECTION_HDR_SIZE = 40;
 COFF_SYMBOL_SIZE      = 18;
 COFF_RELOC_SIZE       = 10;
 COFF_REL_I386_DIR32   = $0006;
 COFF_REL_I386_REL32   = $0014;
 COFF_SYM_CLASS_EXTERNAL = 2;
 COFF_SYM_CLASS_STATIC   = 3;
 COFF_TEXT_FLAGS_LO    = $0020;
 COFF_TEXT_FLAGS_HI    = $6050;
 COFF_DATA_FLAGS_LO    = $0040;
 COFF_DATA_FLAGS_HI    = $C030;
 COFF_BSS_FLAGS_LO     = $0080;
 COFF_BSS_FLAGS_HI     = $C030;
 COFF_IDATA_FLAGS_LO   = $0040;
 COFF_IDATA_FLAGS_HI   = $C000;
 PE_DOS_LFANEW         = $0080;
 PE_TEXT_RVA           = $1000;
 PE_IDATA_RVA          = $2000;
 PE_TEXT_RAW_PTR       = $0200;
 PE_IDATA_RAW_PTR      = $0400;
 PE_TEXT_RAW_SIZE      = $0200;
 PE_IDATA_RAW_SIZE     = $0200;
 PE_SIZE_OF_HEADERS    = $0200;
 PE_SIZE_OF_IMAGE      = $3000;
 PE_OPT_HEADER_SIZE    = 224;
 PE_SUBSYSTEM_CONSOLE  = 3;
 PE_FILE_CHAR_LO       = $0102;
 PE_FILE_CHAR_HI       = $0000;
 MOD2_MAX_SOURCE_LINES = 2048;
 MOD2_MAX_TOKENS       = 8192;
 MOD2_MAX_IMPORTS      = 64;
 MOD2_MAX_SCOPES       = 256;
 MOD2_MAX_SYMBOLS      = 4096;
 MOD2_MAX_IR_NODES     = 8192;
 MOD2_MAX_EXPRESSIONS  = 2048;
 MOD2_MAX_STATEMENTS   = 4096;
 MOD2_MAX_CALL_ARGS    = 32;
 MOD2_MAX_EXPORTS      = 128;
 MOD2_MAX_PATH         = 250;

Type
 T386Register = (
  R_EAX,
  R_EBX,
  R_ECX,
  R_EDX,
  R_ESI,
  R_EDI,
  R_EBP,
  R_ESP
 );

 TAsmSection = (
  AS_TEXT,
  AS_DATA,
  AS_BSS
 );

 TCoffRelocKind = (
  CR_DIR32,
  CR_REL32
 );

 TCoffReloc = Record
  Section     : TAsmSection;
  Offset      : LongInt;
  SymbolIndex : LongInt;
  Kind        : TCoffRelocKind;
 End;

 TSymbolValueArray = Array[0..MOD2_MAX_SYMBOLS] Of LongInt;

 TTargetModel = Record
  CpuName       : String[16];
  OsName        : String[16];
  Bits          : Integer;
  ImageBase     : LongInt;
  SectionAlign  : LongInt;
  FileAlign     : LongInt;
  StackAlign    : Integer;
  StackSlotSize : Integer;
  ArgBaseOffset : Integer;
  CodeSection   : TAsmSection;
  DataSection   : TAsmSection;
  BssSection    : TAsmSection;
  EntryLabel    : String[32];
 End;

 TCompileStage = (
  CS_LOAD_SOURCE,
  CS_LEXER,
  CS_PARSER,
  CS_SEMANTIC_TABLES,
  CS_IR,
  CS_ASM_80386,
  CS_OBJ_COFF,
  CS_EXE_PE32
 );

 TOutputKind = (
  OK_EXE_PE32,
  OK_OBJ_COFF
 );

 TErrorKind = (
  EK_NONE,
  EK_IO,
  EK_LEXICAL,
  EK_SYNTAX,
  EK_SEMANTIC,
  EK_CODEGEN,
  EK_INTERNAL
 );

 TTokenKind = (
  TK_EOF,
  TK_IDENTIFIER,
  TK_INTEGER,
  TK_STRING,
  TK_KEYWORD,
  TK_SYMBOL
 );

 TKeyword = (
  KW_NONE,
  KW_AND,
  KW_ARRAY,
  KW_BEGIN,
  KW_BY,
  KW_CASE,
  KW_CONST,
  KW_DEFINITION,
  KW_DIV,
  KW_DO,
  KW_ELSE,
  KW_ELSIF,
  KW_END,
  KW_EXIT,
  KW_EXPORT,
  KW_FOR,
  KW_FROM,
  KW_IF,
  KW_IMPLEMENTATION,
  KW_IMPORT,
  KW_IN,
  KW_LOOP,
  KW_MOD,
  KW_MODULE,
  KW_NOT,
  KW_OF,
  KW_OR,
  KW_POINTER,
  KW_PROCEDURE,
  KW_QUALIFIED,
  KW_RECORD,
  KW_REPEAT,
  KW_RETURN,
  KW_SET,
  KW_THEN,
  KW_TO,
  KW_TYPE,
  KW_UNTIL,
  KW_VAR,
  KW_WHILE,
  KW_WITH
 );

 TToken = Record
  Kind       : TTokenKind;
  Keyword    : TKeyword;
  Text       : String[127];
  IntegerVal : LongInt;
  Line       : Integer;
  Column     : Integer;
 End;

 TStandardModule = (
  SM_UNKNOWN,
  SM_INOUT
 );

 TModuleImport = Record
  Name          : String[63];
  StandardModule: TStandardModule;
  FromImport    : Boolean;
  SelectedNames : String[127];
  Line          : Integer;
  Column        : Integer;
 End;

 TScopeKind = (
  SCOPE_MODULE,
  SCOPE_PROCEDURE
 );

 TSymbolKind = (
  SYM_MODULE,
  SYM_IMPORT_MODULE,
  SYM_IMPORT_NAME,
  SYM_CONSTANT,
  SYM_TYPE,
  SYM_VARIABLE,
  SYM_PROCEDURE,
  SYM_PARAMETER
 );

 TScalarType = (
  SCALAR_NONE,
  SCALAR_INTEGER,
  SCALAR_CARDINAL,
  SCALAR_BOOLEAN,
  SCALAR_CHAR,
  SCALAR_STRING
 );

 TConstValue = Record
  ScalarType : TScalarType;
  IntegerValue: LongInt;
  StringValue : String[127];
  Valid       : Boolean;
 End;

 TStorageKind = (
  STORAGE_NONE,
  STORAGE_GLOBAL,
  STORAGE_LOCAL,
  STORAGE_PARAMETER
 );

 TIRExprOp = (
  IR_EXPR_CONST,
  IR_EXPR_LOAD,
  IR_EXPR_NEG,
  IR_EXPR_ADD,
  IR_EXPR_SUB,
  IR_EXPR_MUL,
  IR_EXPR_DIV,
  IR_EXPR_MOD,
  IR_EXPR_EQ,
  IR_EXPR_NE,
  IR_EXPR_LT,
  IR_EXPR_LE,
  IR_EXPR_GT,
  IR_EXPR_GE,
  IR_EXPR_NOT,
  IR_EXPR_AND,
  IR_EXPR_OR,
  IR_EXPR_ORD,
  IR_EXPR_CHR,
  IR_EXPR_ODD,
  IR_EXPR_ABS
 );

 TIRExprNode = Record
  Op         : TIRExprOp;
  ScalarType : TScalarType;
  LeftNode   : Integer;
  RightNode  : Integer;
  SymbolIndex: Integer;
  ConstValue : TConstValue;
  Line       : Integer;
  Column     : Integer;
 End;

 TIRExpression = Record
  RootNode  : Integer;
  ScopeIndex: Integer;
  Context   : String[31];
  Line      : Integer;
  Column    : Integer;
 End;

 TIRStatementKind = (
  IR_STMT_EMPTY,
  IR_STMT_ASSIGN,
  IR_STMT_CALL,
  IR_STMT_BLOCK_BEGIN,
  IR_STMT_BLOCK_END,
  IR_STMT_IF_BEGIN,
  IR_STMT_ELSIF,
  IR_STMT_ELSE,
  IR_STMT_IF_END,
  IR_STMT_WHILE_BEGIN,
  IR_STMT_WHILE_END,
  IR_STMT_REPEAT_BEGIN,
  IR_STMT_REPEAT_UNTIL,
  IR_STMT_FOR_BEGIN,
  IR_STMT_FOR_END,
  IR_STMT_RETURN
 );

 TIRStatement = Record
  Kind        : TIRStatementKind;
  ScopeIndex  : Integer;
  BlockDepth  : Integer;
  ControlDepth: Integer;
  ControlId   : Integer;
  TargetSymbol: Integer;
  ExpressionRoot:Integer;
  ProcedureSymbol:Integer;
  ProcedureName:String[127];
  ArgumentCount:Integer;
  Arguments   : Array[1..MOD2_MAX_CALL_ARGS] Of Integer;
  Line        : Integer;
  Column      : Integer;
 End;

 TScope = Record
  Name        : String[63];
  Kind        : TScopeKind;
  ParentScope : Integer;
  Level       : Integer;
  OwnerSymbol : Integer;
  FrameSize   : Integer;
  BodyStart   : Integer;
  BodyEnd     : Integer;
 End;

 TSymbol = Record
  Name       : String[63];
  Kind       : TSymbolKind;
  ScopeIndex : Integer;
  ChildScope : Integer;
  TypeName   : String[63];
  ScalarType : TScalarType;
  TypeSize   : Integer;
  ConstValue : TConstValue;
  AsmName    : String[127];
  ParamIndex : Integer;
  ByReference: Boolean;
  StorageKind: TStorageKind;
  StorageOffset: LongInt;
  StorageSize: Integer;
  IsExported : Boolean;
  Line       : Integer;
  Column     : Integer;
 End;

 TCompilerOptions = Record
  SourceName : String;
  OutputName : String;
  OutputKind : TOutputKind;
  EmitAsm    : Boolean;
  Verbose    : Boolean;
 End;

 TPipelineState = Record
  SourceName      : String;
  ModuleName      : String;
  AsmName         : String;
  ObjName         : String;
  ExeName         : String;
  CurrentStage    : TCompileStage;
  LastCompleted   : TCompileStage;
  OutputKind      : TOutputKind;
  EmitAsm         : Boolean;
  StopAfterObj    : Boolean;
  SourceLoaded    : Boolean;
  Lexed           : Boolean;
  Parsed          : Boolean;
  SemanticsReady  : Boolean;
  IrReady         : Boolean;
  AsmReady        : Boolean;
  ObjReady        : Boolean;
  ExeReady        : Boolean;
  Target          : TTargetModel;
  SourceLines     : LongInt;
  SourceBytes     : LongInt;
  StoredLineCount : Integer;
  SourceText      : Array[1..MOD2_MAX_SOURCE_LINES] Of String[255];
  TokenCount      : Integer;
  Tokens          : Array[1..MOD2_MAX_TOKENS] Of TToken;
  LexerLine       : Integer;
  LexerColumn     : Integer;
  CommentCount    : Integer;
  ParserIndex     : Integer;
  ImportCount     : Integer;
  Imports         : Array[1..MOD2_MAX_IMPORTS] Of TModuleImport;
  ExportCount     : Integer;
  ExportNames     : Array[1..MOD2_MAX_EXPORTS] Of String[63];
  ConstDeclCount  : Integer;
  TypeDeclCount   : Integer;
  VarDeclCount    : Integer;
  ProcedureCount  : Integer;
  StatementCount  : Integer;
  SemanticIndex   : Integer;
  ScopeCount      : Integer;
  Scopes          : Array[1..MOD2_MAX_SCOPES] Of TScope;
  SymbolCount     : Integer;
  Symbols         : Array[1..MOD2_MAX_SYMBOLS] Of TSymbol;
  GlobalBssSize   : LongInt;
  IrTokenIndex    : Integer;
  IrTokenLimit    : Integer;
  IrNodeCount     : Integer;
  IrNodes         : Array[1..MOD2_MAX_IR_NODES] Of TIRExprNode;
  IrExpressionCount:Integer;
  IrExpressions   : Array[1..MOD2_MAX_EXPRESSIONS] Of TIRExpression;
  IrStatementCount:Integer;
  IrStatements    : Array[1..MOD2_MAX_STATEMENTS] Of TIRStatement;
  ErrorCount      : Integer;
  ErrorKind       : TErrorKind;
  ErrorFile       : String;
  ErrorLine       : LongInt;
  ErrorColumn     : LongInt;
  ErrorStage      : TCompileStage;
  ErrorSnippet    : String;
  ErrorMessage    : String;
 End;

Var
 Options : TCompilerOptions;
 Pipeline : TPipelineState;

Function UpperStr(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 UpperStr:=S;
End;

Function StageName(Stage:TCompileStage):String;
Begin
 Case Stage Of
  CS_LOAD_SOURCE    : StageName:='source .MOD';
  CS_LEXER          : StageName:='lexer';
  CS_PARSER         : StageName:='parser';
  CS_SEMANTIC_TABLES: StageName:='tables semantiques';
  CS_IR             : StageName:='IR simple';
  CS_ASM_80386      : StageName:='ASM 80386';
  CS_OBJ_COFF       : StageName:='OBJ COFF i386';
  CS_EXE_PE32       : StageName:='EXE PE32';
  Else StageName:='etape inconnue';
 End;
End;

Function ErrorKindName(Kind:TErrorKind):String;
Begin
 Case Kind Of
  EK_IO       : ErrorKindName:='E/S';
  EK_LEXICAL  : ErrorKindName:='lexicale';
  EK_SYNTAX   : ErrorKindName:='syntaxique';
  EK_SEMANTIC : ErrorKindName:='semantique';
  EK_CODEGEN  : ErrorKindName:='generation';
  EK_INTERNAL : ErrorKindName:='interne';
  Else ErrorKindName:='erreur';
 End;
End;

Function TokenKindName(Kind:TTokenKind):String;
Begin
 Case Kind Of
  TK_EOF       : TokenKindName:='EOF';
  TK_IDENTIFIER: TokenKindName:='IDENT';
  TK_INTEGER   : TokenKindName:='INTEGER';
  TK_STRING    : TokenKindName:='STRING';
  TK_KEYWORD   : TokenKindName:='KEYWORD';
  TK_SYMBOL    : TokenKindName:='SYMBOL';
  Else TokenKindName:='?';
 End;
End;

Function KeywordName(Keyword:TKeyword):String;
Begin
 Case Keyword Of
  KW_AND           : KeywordName:='AND';
  KW_ARRAY         : KeywordName:='ARRAY';
  KW_BEGIN         : KeywordName:='BEGIN';
  KW_BY            : KeywordName:='BY';
  KW_CASE          : KeywordName:='CASE';
  KW_CONST         : KeywordName:='CONST';
  KW_DEFINITION    : KeywordName:='DEFINITION';
  KW_DIV           : KeywordName:='DIV';
  KW_DO            : KeywordName:='DO';
  KW_ELSE          : KeywordName:='ELSE';
  KW_ELSIF         : KeywordName:='ELSIF';
  KW_END           : KeywordName:='END';
  KW_EXIT          : KeywordName:='EXIT';
  KW_EXPORT        : KeywordName:='EXPORT';
  KW_FOR           : KeywordName:='FOR';
  KW_FROM          : KeywordName:='FROM';
  KW_IF            : KeywordName:='IF';
  KW_IMPLEMENTATION: KeywordName:='IMPLEMENTATION';
  KW_IMPORT        : KeywordName:='IMPORT';
  KW_IN            : KeywordName:='IN';
  KW_LOOP          : KeywordName:='LOOP';
  KW_MOD           : KeywordName:='MOD';
  KW_MODULE        : KeywordName:='MODULE';
  KW_NOT           : KeywordName:='NOT';
  KW_OF            : KeywordName:='OF';
  KW_OR            : KeywordName:='OR';
  KW_POINTER       : KeywordName:='POINTER';
  KW_PROCEDURE     : KeywordName:='PROCEDURE';
  KW_QUALIFIED     : KeywordName:='QUALIFIED';
  KW_RECORD        : KeywordName:='RECORD';
  KW_REPEAT        : KeywordName:='REPEAT';
  KW_RETURN        : KeywordName:='RETURN';
  KW_SET           : KeywordName:='SET';
  KW_THEN          : KeywordName:='THEN';
  KW_TO            : KeywordName:='TO';
  KW_TYPE          : KeywordName:='TYPE';
  KW_UNTIL         : KeywordName:='UNTIL';
  KW_VAR           : KeywordName:='VAR';
  KW_WHILE         : KeywordName:='WHILE';
  KW_WITH          : KeywordName:='WITH';
  Else KeywordName:='';
 End;
End;

Function FindKeyword(S:String):TKeyword;
Begin
 S:=UpperStr(S);
 If S='AND' Then FindKeyword:=KW_AND
 Else If S='ARRAY' Then FindKeyword:=KW_ARRAY
 Else If S='BEGIN' Then FindKeyword:=KW_BEGIN
 Else If S='BY' Then FindKeyword:=KW_BY
 Else If S='CASE' Then FindKeyword:=KW_CASE
 Else If S='CONST' Then FindKeyword:=KW_CONST
 Else If S='DEFINITION' Then FindKeyword:=KW_DEFINITION
 Else If S='DIV' Then FindKeyword:=KW_DIV
 Else If S='DO' Then FindKeyword:=KW_DO
 Else If S='ELSE' Then FindKeyword:=KW_ELSE
 Else If S='ELSIF' Then FindKeyword:=KW_ELSIF
 Else If S='END' Then FindKeyword:=KW_END
 Else If S='EXIT' Then FindKeyword:=KW_EXIT
 Else If S='EXPORT' Then FindKeyword:=KW_EXPORT
 Else If S='FOR' Then FindKeyword:=KW_FOR
 Else If S='FROM' Then FindKeyword:=KW_FROM
 Else If S='IF' Then FindKeyword:=KW_IF
 Else If S='IMPLEMENTATION' Then FindKeyword:=KW_IMPLEMENTATION
 Else If S='IMPORT' Then FindKeyword:=KW_IMPORT
 Else If S='IN' Then FindKeyword:=KW_IN
 Else If S='LOOP' Then FindKeyword:=KW_LOOP
 Else If S='MOD' Then FindKeyword:=KW_MOD
 Else If S='MODULE' Then FindKeyword:=KW_MODULE
 Else If S='NOT' Then FindKeyword:=KW_NOT
 Else If S='OF' Then FindKeyword:=KW_OF
 Else If S='OR' Then FindKeyword:=KW_OR
 Else If S='POINTER' Then FindKeyword:=KW_POINTER
 Else If S='PROCEDURE' Then FindKeyword:=KW_PROCEDURE
 Else If S='QUALIFIED' Then FindKeyword:=KW_QUALIFIED
 Else If S='RECORD' Then FindKeyword:=KW_RECORD
 Else If S='REPEAT' Then FindKeyword:=KW_REPEAT
 Else If S='RETURN' Then FindKeyword:=KW_RETURN
 Else If S='SET' Then FindKeyword:=KW_SET
 Else If S='THEN' Then FindKeyword:=KW_THEN
 Else If S='TO' Then FindKeyword:=KW_TO
 Else If S='TYPE' Then FindKeyword:=KW_TYPE
 Else If S='UNTIL' Then FindKeyword:=KW_UNTIL
 Else If S='VAR' Then FindKeyword:=KW_VAR
 Else If S='WHILE' Then FindKeyword:=KW_WHILE
 Else If S='WITH' Then FindKeyword:=KW_WITH
 Else FindKeyword:=KW_NONE;
End;

Function StandardModuleOf(Name:String):TStandardModule;
Begin
 Name:=UpperStr(Name);
 If Name='INOUT' Then StandardModuleOf:=SM_INOUT
  Else StandardModuleOf:=SM_UNKNOWN;
End;

Function StandardModuleName(ModuleKind:TStandardModule):String;
Begin
 Case ModuleKind Of
  SM_INOUT:StandardModuleName:='InOut';
  Else StandardModuleName:='inconnu';
 End;
End;

Function IsStandardModuleExport(ModuleKind:TStandardModule;Name:String):Boolean;
Begin
 Name:=UpperStr(Name);
 Case ModuleKind Of
  SM_INOUT:
   IsStandardModuleExport:=
    (Name='WRITESTRING') Or (Name='WRITELN') Or (Name='WRITEINT') Or
    (Name='WRITECARD') Or (Name='WRITECHAR') Or
    (Name='READINT') Or (Name='READCARD') Or
    (Name='READCHAR') Or (Name='READSTRING');
  Else IsStandardModuleExport:=False;
 End;
End;

Function ScopeKindName(Kind:TScopeKind):String;
Begin
 Case Kind Of
  SCOPE_MODULE   : ScopeKindName:='MODULE';
  SCOPE_PROCEDURE: ScopeKindName:='PROCEDURE';
  Else ScopeKindName:='?';
 End;
End;

Function SymbolKindName(Kind:TSymbolKind):String;
Begin
 Case Kind Of
  SYM_MODULE       : SymbolKindName:='MODULE';
  SYM_IMPORT_MODULE: SymbolKindName:='IMPORT MODULE';
  SYM_IMPORT_NAME  : SymbolKindName:='IMPORT NOM';
  SYM_CONSTANT     : SymbolKindName:='CONST';
  SYM_TYPE         : SymbolKindName:='TYPE';
  SYM_VARIABLE     : SymbolKindName:='VAR';
  SYM_PROCEDURE    : SymbolKindName:='PROCEDURE';
  SYM_PARAMETER    : SymbolKindName:='PARAM';
  Else SymbolKindName:='?';
 End;
End;

Function StorageKindName(Kind:TStorageKind):String;
Begin
 Case Kind Of
  STORAGE_GLOBAL   :StorageKindName:='GLOBAL';
  STORAGE_LOCAL    :StorageKindName:='LOCAL';
  STORAGE_PARAMETER:StorageKindName:='PARAM';
  Else StorageKindName:='-';
 End;
End;

Function IRExprOpName(Op:TIRExprOp):String;
Begin
 Case Op Of
  IR_EXPR_CONST:IRExprOpName:='CONST';
  IR_EXPR_LOAD :IRExprOpName:='LOAD';
  IR_EXPR_NEG  :IRExprOpName:='NEG';
  IR_EXPR_ADD  :IRExprOpName:='ADD';
  IR_EXPR_SUB  :IRExprOpName:='SUB';
  IR_EXPR_MUL  :IRExprOpName:='MUL';
  IR_EXPR_DIV  :IRExprOpName:='DIV';
  IR_EXPR_MOD  :IRExprOpName:='MOD';
  IR_EXPR_EQ   :IRExprOpName:='EQ';
  IR_EXPR_NE   :IRExprOpName:='NE';
  IR_EXPR_LT   :IRExprOpName:='LT';
  IR_EXPR_LE   :IRExprOpName:='LE';
  IR_EXPR_GT   :IRExprOpName:='GT';
  IR_EXPR_GE   :IRExprOpName:='GE';
  IR_EXPR_NOT  :IRExprOpName:='NOT';
  IR_EXPR_AND  :IRExprOpName:='AND';
  IR_EXPR_OR   :IRExprOpName:='OR';
  IR_EXPR_ORD  :IRExprOpName:='ORD';
  IR_EXPR_CHR  :IRExprOpName:='CHR';
  IR_EXPR_ODD  :IRExprOpName:='ODD';
  IR_EXPR_ABS  :IRExprOpName:='ABS';
  Else IRExprOpName:='?';
 End;
End;

Function IRStatementKindName(Kind:TIRStatementKind):String;
Begin
 Case Kind Of
  IR_STMT_EMPTY      :IRStatementKindName:='EMPTY';
  IR_STMT_ASSIGN     :IRStatementKindName:='ASSIGN';
  IR_STMT_CALL       :IRStatementKindName:='CALL';
  IR_STMT_BLOCK_BEGIN:IRStatementKindName:='BLOCK BEGIN';
  IR_STMT_BLOCK_END  :IRStatementKindName:='BLOCK END';
  IR_STMT_IF_BEGIN   :IRStatementKindName:='IF';
  IR_STMT_ELSIF      :IRStatementKindName:='ELSIF';
  IR_STMT_ELSE       :IRStatementKindName:='ELSE';
  IR_STMT_IF_END     :IRStatementKindName:='IF END';
  IR_STMT_WHILE_BEGIN:IRStatementKindName:='WHILE';
  IR_STMT_WHILE_END  :IRStatementKindName:='WHILE END';
  IR_STMT_REPEAT_BEGIN:IRStatementKindName:='REPEAT';
  IR_STMT_REPEAT_UNTIL:IRStatementKindName:='UNTIL';
  IR_STMT_FOR_BEGIN   :IRStatementKindName:='FOR';
  IR_STMT_FOR_END     :IRStatementKindName:='FOR END';
  IR_STMT_RETURN      :IRStatementKindName:='RETURN';
  Else IRStatementKindName:='?';
 End;
End;

Function ScalarTypeName(ScalarType:TScalarType):String;
Begin
 Case ScalarType Of
  SCALAR_INTEGER :ScalarTypeName:='INTEGER';
  SCALAR_CARDINAL:ScalarTypeName:='CARDINAL';
  SCALAR_BOOLEAN :ScalarTypeName:='BOOLEAN';
  SCALAR_CHAR    :ScalarTypeName:='CHAR';
  SCALAR_STRING  :ScalarTypeName:='STRING';
  Else ScalarTypeName:='<non type>';
 End;
End;

Function BuiltinScalarType(Name:String):TScalarType;
Begin
 If Name='INTEGER' Then BuiltinScalarType:=SCALAR_INTEGER
 Else If Name='CARDINAL' Then BuiltinScalarType:=SCALAR_CARDINAL
 Else If Name='BOOLEAN' Then BuiltinScalarType:=SCALAR_BOOLEAN
 Else If Name='CHAR' Then BuiltinScalarType:=SCALAR_CHAR
 Else BuiltinScalarType:=SCALAR_NONE;
End;

Function IsNumericScalar(ScalarType:TScalarType):Boolean;
Begin
 IsNumericScalar:=(ScalarType=SCALAR_INTEGER) Or
                 (ScalarType=SCALAR_CARDINAL);
End;

Function ScalarTypeSize(ScalarType:TScalarType):Integer;
Begin
 Case ScalarType Of
  SCALAR_INTEGER,
  SCALAR_CARDINAL:ScalarTypeSize:=4;
  SCALAR_BOOLEAN,
  SCALAR_CHAR:ScalarTypeSize:=1;
  Else ScalarTypeSize:=0;
 End;
End;

Function ScalarTypesCompatible(ExpectedType,ActualType:TScalarType):Boolean;
Begin
 ScalarTypesCompatible:=(ExpectedType=ActualType) Or
  (IsNumericScalar(ExpectedType) And IsNumericScalar(ActualType));
End;

Function IntToString(N:LongInt):String;
Var
 S:String;
Begin
 Str(N,S);
 IntToString:=S;
End;

Function ConstValueText(Value:TConstValue):String;
Begin
 If Not Value.Valid Then ConstValueText:=''
 Else Case Value.ScalarType Of
  SCALAR_BOOLEAN:
   If Value.IntegerValue<>0 Then ConstValueText:='TRUE'
    Else ConstValueText:='FALSE';
  SCALAR_CHAR:ConstValueText:=''''+Value.StringValue+'''';
  SCALAR_STRING:ConstValueText:=''''+Value.StringValue+'''';
  SCALAR_INTEGER,
  SCALAR_CARDINAL:ConstValueText:=IntToString(Value.IntegerValue);
  Else ConstValueText:='';
 End;
End;

Function LowerStr(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do
  If (S[I]>='A') And (S[I]<='Z') Then
   S[I]:=Chr(Ord(S[I])+32);
 LowerStr:=S;
End;

Function HasSwitchPrefix(S:String):Boolean;
Begin
 HasSwitchPrefix:=(Length(S)>0) And ((S[1]='-') Or (S[1]='/'));
End;

Function StripExtension(FileName:String):String;
Var
 I:Integer;
 P:Integer;
Begin
 P:=0;
 For I:=Length(FileName) DownTo 1 Do Begin
  If FileName[I]='.' Then Begin
   P:=I;
   Break;
  End;
  If (FileName[I]='\') Or (FileName[I]='/') Or (FileName[I]=':') Then Break;
 End;
 If P>0 Then StripExtension:=Copy(FileName,1,P-1)
  Else StripExtension:=FileName;
End;

Function FileBaseName(FileName:String):String;
Var
 I:Integer;
 P:Integer;
 S:String;
Begin
 S:=StripExtension(FileName);
 P:=0;
 For I:=Length(S) DownTo 1 Do
  If (S[I]='\') Or (S[I]='/') Or (S[I]=':') Then Begin
   P:=I;
   Break;
  End;
 If P>0 Then FileBaseName:=Copy(S,P+1,Length(S)-P)
  Else FileBaseName:=S;
End;

Function ChangeExtension(FileName,NewExt:String):String;
Begin
 ChangeExtension:=StripExtension(FileName)+NewExt;
End;

Function EnsureExtension(FileName,DefaultExt:String):String;
Var
 Base:String;
Begin
 Base:=StripExtension(FileName);
 If Length(Base)<Length(FileName) Then EnsureExtension:=FileName
  Else EnsureExtension:=FileName+DefaultExt;
End;

Procedure ValidatePortableEnvironment;
Var
 ByteSize:Integer;
 WordSize:Integer;
 LongIntSize:Integer;
Begin
 ByteSize:=SizeOf(Byte);
 WordSize:=SizeOf(Word);
 LongIntSize:=SizeOf(LongInt);
 If ByteSize<>1 Then Begin
  WriteLn('Erreur: Byte doit occuper 1 octet.');
  Halt(1);
 End;
 If WordSize<>2 Then Begin
  WriteLn('Erreur: Word doit occuper 2 octets.');
  Halt(1);
 End;
 If LongIntSize<>4 Then Begin
  WriteLn('Erreur: LongInt doit occuper 4 octets.');
  Halt(1);
 End;
End;

Procedure ValidatePathLength(PathName,Description:String);
Begin
 If Length(PathName)>MOD2_MAX_PATH Then Begin
  WriteLn('Erreur: ',Description,' depasse ',MOD2_MAX_PATH,' caracteres.');
  Halt(1);
 End;
End;

Function RegName(Reg:T386Register):String;
Begin
 Case Reg Of
  R_EAX:RegName:='eax';
  R_EBX:RegName:='ebx';
  R_ECX:RegName:='ecx';
  R_EDX:RegName:='edx';
  R_ESI:RegName:='esi';
  R_EDI:RegName:='edi';
  R_EBP:RegName:='ebp';
  R_ESP:RegName:='esp';
  Else RegName:='eax';
 End;
End;

Function SectionName(Section:TAsmSection):String;
Begin
 Case Section Of
  AS_TEXT:SectionName:=FLAT_TEXT_SECTION;
  AS_DATA:SectionName:=FLAT_DATA_SECTION;
  AS_BSS :SectionName:=FLAT_BSS_SECTION;
  Else SectionName:=FLAT_TEXT_SECTION;
 End;
End;

Function SectionAlign(Section:TAsmSection):Integer;
Begin
 Case Section Of
  AS_TEXT:SectionAlign:=I386_CODE_ALIGN;
  AS_DATA:SectionAlign:=I386_DATA_ALIGN;
  AS_BSS :SectionAlign:=I386_BSS_ALIGN;
  Else SectionAlign:=I386_DATA_ALIGN;
 End;
End;

Function CoffSectionNumber(Section:TAsmSection):Integer;
Begin
 Case Section Of
  AS_TEXT:CoffSectionNumber:=1;
  AS_DATA:CoffSectionNumber:=2;
  AS_BSS :CoffSectionNumber:=3;
  Else CoffSectionNumber:=0;
 End;
End;

Function CoffSectionFlagsLo(Section:TAsmSection):Word;
Begin
 Case Section Of
  AS_TEXT:CoffSectionFlagsLo:=COFF_TEXT_FLAGS_LO;
  AS_DATA:CoffSectionFlagsLo:=COFF_DATA_FLAGS_LO;
  AS_BSS :CoffSectionFlagsLo:=COFF_BSS_FLAGS_LO;
  Else CoffSectionFlagsLo:=0;
 End;
End;

Function CoffSectionFlagsHi(Section:TAsmSection):Word;
Begin
 Case Section Of
  AS_TEXT:CoffSectionFlagsHi:=COFF_TEXT_FLAGS_HI;
  AS_DATA:CoffSectionFlagsHi:=COFF_DATA_FLAGS_HI;
  AS_BSS :CoffSectionFlagsHi:=COFF_BSS_FLAGS_HI;
  Else CoffSectionFlagsHi:=0;
 End;
End;

Function CoffRelocType(RelocKind:TCoffRelocKind):Word;
Begin
 Case RelocKind Of
  CR_DIR32:CoffRelocType:=COFF_REL_I386_DIR32;
  CR_REL32:CoffRelocType:=COFF_REL_I386_REL32;
  Else CoffRelocType:=0;
 End;
End;

Function StackRef(BaseReg:T386Register;Offset:Integer):String;
Begin
 If Offset=0 Then StackRef:='['+RegName(BaseReg)+']'
  Else If Offset>0 Then
   StackRef:='['+RegName(BaseReg)+'+'+IntToString(Offset)+']'
  Else
   StackRef:='['+RegName(BaseReg)+IntToString(Offset)+']';
End;

Function ArgValueRef(ParamIndex:Integer):String;
Begin
 If ParamIndex<1 Then ParamIndex:=1;
 ArgValueRef:=StackRef(R_EBP,
  I386_ARG_BASE_OFFSET+((ParamIndex-1)*I386_STACK_SLOT_SIZE));
End;

Function LocalVarRef(LocalOffset:Integer):String;
Begin
 If LocalOffset>0 Then LocalOffset:=-LocalOffset;
 LocalVarRef:=StackRef(R_EBP,LocalOffset);
End;

Function SymbolStorageRef(SymbolIndex:Integer):String;
Var
 S:TSymbol;
Begin
 SymbolStorageRef:='';
 If (SymbolIndex<1) Or (SymbolIndex>Pipeline.SymbolCount) Then Exit;
 S:=Pipeline.Symbols[SymbolIndex];
 Case S.StorageKind Of
  STORAGE_GLOBAL:
   SymbolStorageRef:='['+S.AsmName+']';
  STORAGE_LOCAL:
   SymbolStorageRef:=StackRef(R_EBP,S.StorageOffset);
  STORAGE_PARAMETER:
   SymbolStorageRef:=StackRef(R_EBP,S.StorageOffset);
 End;
End;

Procedure PipelineError(Msg:String); Forward;
Procedure PipelineErrorAt(Kind:TErrorKind;Msg:String;LineNo,ColumnNo:LongInt);
 Forward;
Function FindProcedureParameter(ProcedureSymbol,ParamIndex:Integer):Integer;
 Forward;
Function IRRootAddressable(RootNode:Integer;Var SymbolIndex:Integer):Boolean;
 Forward;

Function IsAsmNameChar(C:Char):Boolean;
Begin
 IsAsmNameChar:=((C>='A') And (C<='Z')) Or
                ((C>='a') And (C<='z')) Or
                ((C>='0') And (C<='9')) Or (C='_');
End;

Function SanitizeAsmName(S:String):String;
Var
 I:Integer;
 C:Char;
Begin
 SanitizeAsmName:='';
 For I:=1 To Length(S) Do Begin
  C:=S[I];
  If IsAsmNameChar(C) Then SanitizeAsmName:=SanitizeAsmName+C
   Else SanitizeAsmName:=SanitizeAsmName+'_';
 End;
 If SanitizeAsmName='' Then SanitizeAsmName:='NONAME';
 If (SanitizeAsmName[1]>='0') And (SanitizeAsmName[1]<='9') Then
  SanitizeAsmName:='_'+SanitizeAsmName;
End;

Function MakeAsmLabel(Prefix,Name:String):String;
Begin
 MakeAsmLabel:=Prefix+SanitizeAsmName(Name);
End;

Function MakeInternalLabel(Name:String):String;
Begin
 MakeInternalLabel:=MakeAsmLabel(MOD2_INTERNAL_PREFIX,Name);
End;

Function MakeDataLabel(Name:String):String;
Begin
 MakeDataLabel:=MakeAsmLabel(MOD2_DATA_PREFIX,Name);
End;

Function AsmByteList(S:String;ZeroTerminated:Boolean):String;
Var
 I:Integer;
Begin
 AsmByteList:='';
 For I:=1 To Length(S) Do Begin
  If AsmByteList<>'' Then AsmByteList:=AsmByteList+',';
  AsmByteList:=AsmByteList+IntToString(Ord(S[I]));
 End;
 If ZeroTerminated Then Begin
  If AsmByteList<>'' Then AsmByteList:=AsmByteList+',';
  AsmByteList:=AsmByteList+'0';
 End;
 If AsmByteList='' Then AsmByteList:='0';
End;

Procedure EmitAsmLine(Var T:Text;S:String);
Begin
 WriteLn(T,S);
End;

Procedure EmitAsmBlank(Var T:Text);
Begin
 WriteLn(T);
End;

Procedure EmitAsmComment(Var T:Text;S:String);
Begin
 EmitAsmLine(T,'; '+S);
End;

Procedure EmitAsmSection(Var T:Text;Section:TAsmSection);
Begin
 EmitAsmLine(T,'section '+SectionName(Section));
End;

Procedure EmitAsmLabel(Var T:Text;LabelName:String);
Begin
 EmitAsmLine(T,LabelName+':');
End;

Procedure EmitAsmInstr(Var T:Text;Op,Args:String);
Begin
 If Args='' Then EmitAsmLine(T,'  '+Op)
  Else EmitAsmLine(T,'  '+Op+' '+Args);
End;

Procedure Emit386Mov(Var T:Text;Dst,Src:String);
Begin
 EmitAsmInstr(T,'mov',Dst+', '+Src);
End;

Procedure Emit386Push(Var T:Text;Operand:String);
Begin
 EmitAsmInstr(T,'push',Operand);
End;

Procedure Emit386Pop(Var T:Text;Operand:String);
Begin
 EmitAsmInstr(T,'pop',Operand);
End;

Procedure Emit386Ret(Var T:Text);
Begin
 EmitAsmInstr(T,'ret','');
End;

Procedure Emit386Prologue(Var T:Text;LocalSize:Integer);
Begin
 Emit386Push(T,RegName(R_EBP));
 Emit386Mov(T,RegName(R_EBP),RegName(R_ESP));
 If LocalSize>0 Then EmitAsmInstr(T,'sub',RegName(R_ESP)+', '+IntToString(LocalSize));
End;

Procedure Emit386Epilogue(Var T:Text);
Begin
 Emit386Mov(T,RegName(R_ESP),RegName(R_EBP));
 Emit386Pop(T,RegName(R_EBP));
 Emit386Ret(T);
End;

Procedure EmitGlobalBssVariables(Var T:Text);
Var
 I:Integer;
 Emitted:Boolean;
 S:TSymbol;
Begin
 Emitted:=False;
 For I:=1 To Pipeline.SymbolCount Do Begin
  S:=Pipeline.Symbols[I];
  If S.StorageKind=STORAGE_GLOBAL Then Begin
   Emitted:=True;
   EmitAsmComment(T,S.Name+' : '+ScalarTypeName(S.ScalarType)+
                    ', offset BSS '+IntToString(S.StorageOffset)+
                    ', initialise implicitement a zero');
   EmitAsmLabel(T,S.AsmName);
   EmitAsmLine(T,'  resd 1');
  End;
 End;
 If Not Emitted Then Begin
  EmitAsmLabel(T,MakeDataLabel(Pipeline.ModuleName+'_BSS_ANCHOR'));
  EmitAsmLine(T,'  resd 1');
 End;
End;

Procedure EmitIRExpressionAsm(Var T:Text;NodeIndex:Integer;
 Var LabelCounter:Integer); Forward;

Function NewAsmExpressionLabel(Var LabelCounter:Integer;
 Suffix:String):String;
Begin
 Inc(LabelCounter);
 NewAsmExpressionLabel:=MakeInternalLabel('EXPR_'+
  IntToString(LabelCounter)+'_'+Suffix);
End;

Function IRStringLabel(NodeIndex:Integer):String;
Begin
 IRStringLabel:=MakeDataLabel('STR_'+IntToString(NodeIndex));
End;

Procedure EmitIRLoadSymbol(Var T:Text;SymbolIndex:Integer);
Var
 S:TSymbol;
Begin
 S:=Pipeline.Symbols[SymbolIndex];
 If (S.StorageKind=STORAGE_PARAMETER) And S.ByReference Then Begin
  Emit386Mov(T,RegName(R_EAX),SymbolStorageRef(SymbolIndex));
  Emit386Mov(T,RegName(R_EAX),'[eax]');
 End
 Else Emit386Mov(T,RegName(R_EAX),SymbolStorageRef(SymbolIndex));
End;

Procedure EmitIRAddressOfSymbol(Var T:Text;SymbolIndex:Integer);
Var
 S:TSymbol;
Begin
 If (SymbolIndex<1) Or (SymbolIndex>Pipeline.SymbolCount) Then Begin
  PipelineErrorAt(EK_CODEGEN,'symbole adressable invalide',0,0);
  Exit;
 End;
 S:=Pipeline.Symbols[SymbolIndex];
 If (S.StorageKind=STORAGE_PARAMETER) And S.ByReference Then
  Emit386Mov(T,RegName(R_EAX),SymbolStorageRef(SymbolIndex))
 Else Case S.StorageKind Of
  STORAGE_GLOBAL,
  STORAGE_LOCAL,
  STORAGE_PARAMETER:
   EmitAsmInstr(T,'lea',RegName(R_EAX)+', '+SymbolStorageRef(SymbolIndex));
  Else
   PipelineErrorAt(EK_CODEGEN,'symbole sans adresse: '+S.Name,
                   S.Line,S.Column);
 End;
End;

Procedure EmitIRExpressionAsm(Var T:Text;NodeIndex:Integer;
 Var LabelCounter:Integer);
Var
 N:TIRExprNode;
 FalseLabel:String;
 TrueLabel:String;
 EndLabel:String;
 SetOp:String;
Begin
 If (NodeIndex<1) Or (NodeIndex>Pipeline.IrNodeCount) Then Begin
  Emit386Mov(T,RegName(R_EAX),'0');
  Exit;
 End;
 N:=Pipeline.IrNodes[NodeIndex];
 Case N.Op Of
  IR_EXPR_CONST:
   Begin
    If N.ConstValue.ScalarType=SCALAR_STRING Then Begin
     Emit386Mov(T,RegName(R_EAX),IRStringLabel(NodeIndex));
    End
    Else Emit386Mov(T,RegName(R_EAX),
                    IntToString(N.ConstValue.IntegerValue));
   End;
  IR_EXPR_LOAD:
   EmitIRLoadSymbol(T,N.SymbolIndex);
  IR_EXPR_NEG:
   Begin
    EmitIRExpressionAsm(T,N.LeftNode,LabelCounter);
    EmitAsmInstr(T,'neg',RegName(R_EAX));
   End;
  IR_EXPR_NOT:
   Begin
    EmitIRExpressionAsm(T,N.LeftNode,LabelCounter);
    EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
    EmitAsmInstr(T,'sete','al');
    EmitAsmInstr(T,'movzx',RegName(R_EAX)+', al');
   End;
  IR_EXPR_ORD:
   EmitIRExpressionAsm(T,N.LeftNode,LabelCounter);
  IR_EXPR_CHR:
   Begin
    EmitIRExpressionAsm(T,N.LeftNode,LabelCounter);
    EmitAsmInstr(T,'and',RegName(R_EAX)+', 255');
   End;
  IR_EXPR_ODD:
   Begin
    EmitIRExpressionAsm(T,N.LeftNode,LabelCounter);
    EmitAsmInstr(T,'and',RegName(R_EAX)+', 1');
   End;
  IR_EXPR_ABS:
   Begin
    EmitIRExpressionAsm(T,N.LeftNode,LabelCounter);
    If N.ScalarType=SCALAR_INTEGER Then Begin
     EndLabel:=NewAsmExpressionLabel(LabelCounter,'ABS_END');
     EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
     EmitAsmInstr(T,'jge',EndLabel);
     EmitAsmInstr(T,'neg',RegName(R_EAX));
     EmitAsmLabel(T,EndLabel);
    End;
   End;
  IR_EXPR_AND:
   Begin
    FalseLabel:=NewAsmExpressionLabel(LabelCounter,'FALSE');
    EndLabel:=NewAsmExpressionLabel(LabelCounter,'END');
    EmitIRExpressionAsm(T,N.LeftNode,LabelCounter);
    EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
    EmitAsmInstr(T,'je',FalseLabel);
    EmitIRExpressionAsm(T,N.RightNode,LabelCounter);
    EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
    EmitAsmInstr(T,'je',FalseLabel);
    Emit386Mov(T,RegName(R_EAX),'1');
    EmitAsmInstr(T,'jmp',EndLabel);
    EmitAsmLabel(T,FalseLabel);
    Emit386Mov(T,RegName(R_EAX),'0');
    EmitAsmLabel(T,EndLabel);
   End;
  IR_EXPR_OR:
   Begin
    TrueLabel:=NewAsmExpressionLabel(LabelCounter,'TRUE');
    EndLabel:=NewAsmExpressionLabel(LabelCounter,'END');
    EmitIRExpressionAsm(T,N.LeftNode,LabelCounter);
    EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
    EmitAsmInstr(T,'jne',TrueLabel);
    EmitIRExpressionAsm(T,N.RightNode,LabelCounter);
    EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
    EmitAsmInstr(T,'jne',TrueLabel);
    Emit386Mov(T,RegName(R_EAX),'0');
    EmitAsmInstr(T,'jmp',EndLabel);
    EmitAsmLabel(T,TrueLabel);
    Emit386Mov(T,RegName(R_EAX),'1');
    EmitAsmLabel(T,EndLabel);
   End;
  Else Begin
   EmitIRExpressionAsm(T,N.LeftNode,LabelCounter);
   Emit386Push(T,RegName(R_EAX));
   EmitIRExpressionAsm(T,N.RightNode,LabelCounter);
   Emit386Pop(T,RegName(R_EBX));
   Case N.Op Of
    IR_EXPR_ADD:EmitAsmInstr(T,'add',RegName(R_EAX)+', '+RegName(R_EBX));
    IR_EXPR_SUB:
     Begin
      Emit386Mov(T,RegName(R_ECX),RegName(R_EAX));
      Emit386Mov(T,RegName(R_EAX),RegName(R_EBX));
      EmitAsmInstr(T,'sub',RegName(R_EAX)+', '+RegName(R_ECX));
     End;
    IR_EXPR_MUL:EmitAsmInstr(T,'imul',RegName(R_EAX)+', '+RegName(R_EBX));
    IR_EXPR_DIV,
    IR_EXPR_MOD:
     Begin
      Emit386Mov(T,RegName(R_ECX),RegName(R_EAX));
      Emit386Mov(T,RegName(R_EAX),RegName(R_EBX));
      EmitAsmInstr(T,'cdq','');
      EmitAsmInstr(T,'idiv',RegName(R_ECX));
      If N.Op=IR_EXPR_MOD Then
       Emit386Mov(T,RegName(R_EAX),RegName(R_EDX));
     End;
    IR_EXPR_EQ,
    IR_EXPR_NE,
    IR_EXPR_LT,
    IR_EXPR_LE,
    IR_EXPR_GT,
    IR_EXPR_GE:
     Begin
      EmitAsmInstr(T,'cmp',RegName(R_EBX)+', '+RegName(R_EAX));
      Case N.Op Of
       IR_EXPR_EQ:SetOp:='sete';
       IR_EXPR_NE:SetOp:='setne';
       IR_EXPR_LT:SetOp:='setl';
       IR_EXPR_LE:SetOp:='setle';
       IR_EXPR_GT:SetOp:='setg';
       Else SetOp:='setge';
      End;
      EmitAsmInstr(T,SetOp,'al');
      EmitAsmInstr(T,'movzx',RegName(R_EAX)+', al');
     End;
   End;
  End;
 End;
End;

Procedure EmitIRStoreSymbol(Var T:Text;SymbolIndex:Integer);
Var
 S:TSymbol;
Begin
 S:=Pipeline.Symbols[SymbolIndex];
 If (S.StorageKind=STORAGE_PARAMETER) And S.ByReference Then Begin
  Emit386Mov(T,RegName(R_EDX),SymbolStorageRef(SymbolIndex));
  Emit386Mov(T,'[edx]',RegName(R_EAX));
 End
 Else Emit386Mov(T,SymbolStorageRef(SymbolIndex),RegName(R_EAX));
End;

Procedure EmitScopeBasicStatements(Var T:Text;ScopeIndex:Integer;
 Var LabelCounter:Integer);
Const
 MAX_IF_EMIT_DEPTH = 256;
 MAX_LOOP_EMIT_DEPTH = 256;
Var
 I:Integer;
 J:Integer;
 IfDepth:Integer;
 IfId:Array[1..MAX_IF_EMIT_DEPTH] Of Integer;
 IfBranch:Array[1..MAX_IF_EMIT_DEPTH] Of Integer;
 IfEndLabel:Array[1..MAX_IF_EMIT_DEPTH] Of String[127];
 IfNextLabel:Array[1..MAX_IF_EMIT_DEPTH] Of String[127];
 IfHasElse:Array[1..MAX_IF_EMIT_DEPTH] Of Boolean;
 LoopDepth:Integer;
 LoopId:Array[1..MAX_LOOP_EMIT_DEPTH] Of Integer;
 LoopKind:Array[1..MAX_LOOP_EMIT_DEPTH] Of TIRStatementKind;
 LoopStartLabel:Array[1..MAX_LOOP_EMIT_DEPTH] Of String[127];
 LoopEndLabel:Array[1..MAX_LOOP_EMIT_DEPTH] Of String[127];
 LoopBodyLabel:Array[1..MAX_LOOP_EMIT_DEPTH] Of String[127];
 LoopPositiveLabel:Array[1..MAX_LOOP_EMIT_DEPTH] Of String[127];
 LoopNegativeLabel:Array[1..MAX_LOOP_EMIT_DEPTH] Of String[127];
 LoopVariable:Array[1..MAX_LOOP_EMIT_DEPTH] Of Integer;
 S:TIRStatement;
 Target:TSymbol;
 ParamSymbol:Integer;
 ArgumentSymbol:Integer;
Begin
 IfDepth:=0;
 LoopDepth:=0;
 For I:=1 To Pipeline.IrStatementCount Do Begin
  S:=Pipeline.IrStatements[I];
  If (S.ScopeIndex<>ScopeIndex) Or (S.ControlDepth<>0) Then Continue;
  Case S.Kind Of
   IR_STMT_WHILE_BEGIN:
    Begin
     If LoopDepth>=MAX_LOOP_EMIT_DEPTH Then Begin
      PipelineErrorAt(EK_CODEGEN,'boucle trop profonde',S.Line,S.Column);
      Exit;
     End;
     Inc(LoopDepth);
     LoopId[LoopDepth]:=S.ControlId;
     LoopKind[LoopDepth]:=IR_STMT_WHILE_BEGIN;
     LoopStartLabel[LoopDepth]:=MakeInternalLabel('WHILE_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_TEST');
     LoopEndLabel[LoopDepth]:=MakeInternalLabel('WHILE_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_END');
     EmitAsmLabel(T,LoopStartLabel[LoopDepth]);
     EmitAsmComment(T,'WHILE condition');
     EmitIRExpressionAsm(T,S.ExpressionRoot,LabelCounter);
     EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
     EmitAsmInstr(T,'je',LoopEndLabel[LoopDepth]);
    End;
   IR_STMT_WHILE_END:
    Begin
     If (LoopDepth=0) Or (LoopId[LoopDepth]<>S.ControlId) Or
        (LoopKind[LoopDepth]<>IR_STMT_WHILE_BEGIN) Then Begin
      PipelineErrorAt(EK_CODEGEN,'END WHILE IR mal imbrique',
                      S.Line,S.Column);
      Exit;
     End;
     EmitAsmInstr(T,'jmp',LoopStartLabel[LoopDepth]);
     EmitAsmLabel(T,LoopEndLabel[LoopDepth]);
     Dec(LoopDepth);
    End;
   IR_STMT_REPEAT_BEGIN:
    Begin
     If LoopDepth>=MAX_LOOP_EMIT_DEPTH Then Begin
      PipelineErrorAt(EK_CODEGEN,'boucle trop profonde',S.Line,S.Column);
      Exit;
     End;
     Inc(LoopDepth);
     LoopId[LoopDepth]:=S.ControlId;
     LoopKind[LoopDepth]:=IR_STMT_REPEAT_BEGIN;
     LoopStartLabel[LoopDepth]:=MakeInternalLabel('REPEAT_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_START');
     LoopEndLabel[LoopDepth]:='';
     EmitAsmLabel(T,LoopStartLabel[LoopDepth]);
     EmitAsmComment(T,'REPEAT');
    End;
   IR_STMT_REPEAT_UNTIL:
    Begin
     If (LoopDepth=0) Or (LoopId[LoopDepth]<>S.ControlId) Or
        (LoopKind[LoopDepth]<>IR_STMT_REPEAT_BEGIN) Then Begin
      PipelineErrorAt(EK_CODEGEN,'UNTIL IR mal imbrique',
                      S.Line,S.Column);
      Exit;
     End;
     EmitAsmComment(T,'UNTIL condition');
     EmitIRExpressionAsm(T,S.ExpressionRoot,LabelCounter);
     EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
     EmitAsmInstr(T,'je',LoopStartLabel[LoopDepth]);
     Dec(LoopDepth);
    End;
   IR_STMT_FOR_BEGIN:
    Begin
     If LoopDepth>=MAX_LOOP_EMIT_DEPTH Then Begin
      PipelineErrorAt(EK_CODEGEN,'boucle trop profonde',S.Line,S.Column);
      Exit;
     End;
     Inc(LoopDepth);
     LoopId[LoopDepth]:=S.ControlId;
     LoopKind[LoopDepth]:=IR_STMT_FOR_BEGIN;
     LoopVariable[LoopDepth]:=S.TargetSymbol;
     LoopStartLabel[LoopDepth]:=MakeInternalLabel('FOR_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_TEST');
     LoopBodyLabel[LoopDepth]:=MakeInternalLabel('FOR_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_BODY');
     LoopPositiveLabel[LoopDepth]:=MakeInternalLabel('FOR_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_POS');
     LoopNegativeLabel[LoopDepth]:=MakeInternalLabel('FOR_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_NEG');
     LoopEndLabel[LoopDepth]:=MakeInternalLabel('FOR_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_END');
     EmitAsmComment(T,'FOR initialisation');
     EmitIRExpressionAsm(T,S.ExpressionRoot,LabelCounter);
     EmitIRStoreSymbol(T,S.TargetSymbol);
     EmitIRExpressionAsm(T,S.Arguments[1],LabelCounter);
     Emit386Push(T,RegName(R_EAX));
     EmitIRExpressionAsm(T,S.Arguments[2],LabelCounter);
     Emit386Push(T,RegName(R_EAX));
     EmitAsmLabel(T,LoopStartLabel[LoopDepth]);
     EmitAsmInstr(T,'cmp','dword [esp], 0');
     EmitAsmInstr(T,'jg',LoopPositiveLabel[LoopDepth]);
     EmitAsmInstr(T,'jl',LoopNegativeLabel[LoopDepth]);
     EmitAsmInstr(T,'jmp',LoopEndLabel[LoopDepth]);
     EmitAsmLabel(T,LoopPositiveLabel[LoopDepth]);
     EmitIRLoadSymbol(T,S.TargetSymbol);
     EmitAsmInstr(T,'cmp',RegName(R_EAX)+', [esp+4]');
     EmitAsmInstr(T,'jg',LoopEndLabel[LoopDepth]);
     EmitAsmInstr(T,'jmp',LoopBodyLabel[LoopDepth]);
     EmitAsmLabel(T,LoopNegativeLabel[LoopDepth]);
     EmitIRLoadSymbol(T,S.TargetSymbol);
     EmitAsmInstr(T,'cmp',RegName(R_EAX)+', [esp+4]');
     EmitAsmInstr(T,'jl',LoopEndLabel[LoopDepth]);
     EmitAsmLabel(T,LoopBodyLabel[LoopDepth]);
    End;
   IR_STMT_FOR_END:
    Begin
     If (LoopDepth=0) Or (LoopId[LoopDepth]<>S.ControlId) Or
        (LoopKind[LoopDepth]<>IR_STMT_FOR_BEGIN) Then Begin
      PipelineErrorAt(EK_CODEGEN,'END FOR IR mal imbrique',
                      S.Line,S.Column);
      Exit;
     End;
     EmitAsmComment(T,'FOR increment');
     EmitIRLoadSymbol(T,LoopVariable[LoopDepth]);
     EmitAsmInstr(T,'add',RegName(R_EAX)+', [esp]');
     EmitIRStoreSymbol(T,LoopVariable[LoopDepth]);
     EmitAsmInstr(T,'jmp',LoopStartLabel[LoopDepth]);
     EmitAsmLabel(T,LoopEndLabel[LoopDepth]);
     EmitAsmInstr(T,'add',RegName(R_ESP)+', 8');
     Dec(LoopDepth);
    End;
   IR_STMT_IF_BEGIN:
    Begin
     If IfDepth>=MAX_IF_EMIT_DEPTH Then Begin
      PipelineErrorAt(EK_CODEGEN,'IF trop profond',S.Line,S.Column);
      Exit;
     End;
     Inc(IfDepth);
     IfId[IfDepth]:=S.ControlId;
     IfBranch[IfDepth]:=1;
     IfHasElse[IfDepth]:=False;
     IfEndLabel[IfDepth]:=MakeInternalLabel('IF_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_END');
     IfNextLabel[IfDepth]:=MakeInternalLabel('IF_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_NEXT_1');
     EmitAsmComment(T,'IF');
     EmitIRExpressionAsm(T,S.ExpressionRoot,LabelCounter);
     EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
     EmitAsmInstr(T,'je',IfNextLabel[IfDepth]);
    End;
   IR_STMT_ELSIF:
    Begin
     If (IfDepth=0) Or (IfId[IfDepth]<>S.ControlId) Then Begin
      PipelineErrorAt(EK_CODEGEN,'ELSIF IR mal imbrique',
                      S.Line,S.Column);
      Exit;
     End;
     EmitAsmInstr(T,'jmp',IfEndLabel[IfDepth]);
     EmitAsmLabel(T,IfNextLabel[IfDepth]);
     Inc(IfBranch[IfDepth]);
     IfNextLabel[IfDepth]:=MakeInternalLabel('IF_S'+
      IntToString(ScopeIndex)+'_'+IntToString(S.ControlId)+'_NEXT_'+
      IntToString(IfBranch[IfDepth]));
     EmitAsmComment(T,'ELSIF');
     EmitIRExpressionAsm(T,S.ExpressionRoot,LabelCounter);
     EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
     EmitAsmInstr(T,'je',IfNextLabel[IfDepth]);
    End;
   IR_STMT_ELSE:
    Begin
     If (IfDepth=0) Or (IfId[IfDepth]<>S.ControlId) Then Begin
      PipelineErrorAt(EK_CODEGEN,'ELSE IR mal imbrique',
                      S.Line,S.Column);
      Exit;
     End;
     EmitAsmInstr(T,'jmp',IfEndLabel[IfDepth]);
     EmitAsmLabel(T,IfNextLabel[IfDepth]);
     IfHasElse[IfDepth]:=True;
     EmitAsmComment(T,'ELSE');
    End;
   IR_STMT_IF_END:
    Begin
     If (IfDepth=0) Or (IfId[IfDepth]<>S.ControlId) Then Begin
      PipelineErrorAt(EK_CODEGEN,'END IF IR mal imbrique',
                      S.Line,S.Column);
      Exit;
     End;
     If Not IfHasElse[IfDepth] Then
      EmitAsmLabel(T,IfNextLabel[IfDepth]);
     EmitAsmLabel(T,IfEndLabel[IfDepth]);
     Dec(IfDepth);
    End;
   IR_STMT_EMPTY:
    EmitAsmComment(T,'instruction vide');
   IR_STMT_BLOCK_BEGIN:
    EmitAsmComment(T,'BEGIN imbrique profondeur '+IntToString(S.BlockDepth));
   IR_STMT_BLOCK_END:
    EmitAsmComment(T,'END imbrique profondeur '+IntToString(S.BlockDepth));
   IR_STMT_ASSIGN:
    Begin
     Target:=Pipeline.Symbols[S.TargetSymbol];
     EmitAsmComment(T,Target.Name+' := expression');
     EmitIRExpressionAsm(T,S.ExpressionRoot,LabelCounter);
     EmitIRStoreSymbol(T,S.TargetSymbol);
    End;
   IR_STMT_CALL:
    Begin
     EmitAsmComment(T,'appel '+S.ProcedureName);
     If S.ProcedureSymbol<>0 Then Begin
      For J:=S.ArgumentCount DownTo 1 Do Begin
       ParamSymbol:=FindProcedureParameter(S.ProcedureSymbol,J);
       If (ParamSymbol<>0) And
          Pipeline.Symbols[ParamSymbol].ByReference Then Begin
        If Not IRRootAddressable(S.Arguments[J],ArgumentSymbol) Then Begin
         PipelineErrorAt(EK_CODEGEN,'argument VAR non adressable',
                         S.Line,S.Column);
         Exit;
        End;
        EmitIRAddressOfSymbol(T,ArgumentSymbol);
       End
       Else EmitIRExpressionAsm(T,S.Arguments[J],LabelCounter);
       Emit386Push(T,RegName(R_EAX));
      End;
      EmitAsmInstr(T,'call',Pipeline.Symbols[S.ProcedureSymbol].AsmName);
      If S.ArgumentCount>0 Then
       EmitAsmInstr(T,'add',RegName(R_ESP)+', '+
                    IntToString(S.ArgumentCount*I386_STACK_SLOT_SIZE));
     End
     Else If (S.ProcedureName='INC') Or (S.ProcedureName='DEC') Then Begin
      If Not IRRootAddressable(S.Arguments[1],ArgumentSymbol) Then Begin
       PipelineErrorAt(EK_CODEGEN,S.ProcedureName+
                       ': premier argument non adressable',
                       S.Line,S.Column);
       Exit;
      End;
      If S.ArgumentCount=2 Then
       EmitIRExpressionAsm(T,S.Arguments[2],LabelCounter)
      Else Emit386Mov(T,RegName(R_EAX),'1');
      Emit386Push(T,RegName(R_EAX));
      EmitIRLoadSymbol(T,ArgumentSymbol);
      Emit386Pop(T,RegName(R_EBX));
      If S.ProcedureName='INC' Then
       EmitAsmInstr(T,'add',RegName(R_EAX)+', '+RegName(R_EBX))
      Else EmitAsmInstr(T,'sub',RegName(R_EAX)+', '+RegName(R_EBX));
      EmitIRStoreSymbol(T,ArgumentSymbol);
     End
     Else EmitAsmComment(T,'appel externe differe');
    End;
  End;
 End;
 If IfDepth<>0 Then
  PipelineErrorAt(EK_CODEGEN,'IF IR non termine',0,0);
 If LoopDepth<>0 Then
  PipelineErrorAt(EK_CODEGEN,'boucle IR non terminee',0,0);
End;

Function WriteAsm80386File(FileName:String):Boolean;
Var
 T:Text;
 I:Integer;
 ScopeIndex:Integer;
 LabelCounter:Integer;
Begin
 WriteAsm80386File:=False;
 Assign(T,FileName);
 Rewrite(T);
 If IOResult<>0 Then Begin
  PipelineError('impossible d''ecrire '+FileName);
  Exit;
 End;
 EmitAsmComment(T,'MOD2CW32 - ASM 80386 genere');
 EmitAsmComment(T,'source: '+Pipeline.SourceName);
 EmitAsmComment(T,'module: '+Pipeline.ModuleName);
 EmitAsmComment(T,'target: '+Pipeline.Target.CpuName+' '+Pipeline.Target.OsName+
                  ' '+IntToString(Pipeline.Target.Bits)+' bits');
 EmitAsmComment(T,'objet: '+Pipeline.ObjName);
 EmitAsmComment(T,'exe: '+Pipeline.ExeName);
 EmitAsmLine(T,'bits 32');
 EmitAsmBlank(T);
 EmitAsmSection(T,Pipeline.Target.CodeSection);
 LabelCounter:=0;
 For I:=1 To Pipeline.SymbolCount Do
  If Pipeline.Symbols[I].Kind=SYM_PROCEDURE Then Begin
   ScopeIndex:=Pipeline.Symbols[I].ChildScope;
   If Pipeline.Symbols[I].IsExported Then
    EmitAsmLine(T,'global '+Pipeline.Symbols[I].AsmName);
   EmitAsmLabel(T,Pipeline.Symbols[I].AsmName);
   Emit386Prologue(T,Pipeline.Scopes[ScopeIndex].FrameSize);
   EmitScopeBasicStatements(T,ScopeIndex,LabelCounter);
   Emit386Mov(T,RegName(R_EAX),'0');
   Emit386Epilogue(T);
   EmitAsmBlank(T);
  End;
 EmitAsmLine(T,'global '+Pipeline.Target.EntryLabel);
 EmitAsmLabel(T,Pipeline.Target.EntryLabel);
 EmitAsmComment(T,'prologue standard Win32 80386');
 Emit386Prologue(T,0);
 EmitScopeBasicStatements(T,1,LabelCounter);
 Emit386Mov(T,RegName(R_EAX),'0');
 EmitAsmLabel(T,MakeInternalLabel(Pipeline.ModuleName+'_EXIT'));
 Emit386Epilogue(T);
 EmitAsmBlank(T);
 EmitAsmSection(T,Pipeline.Target.DataSection);
 EmitAsmLabel(T,MakeDataLabel(Pipeline.ModuleName+'_SOURCE'));
 EmitAsmLine(T,'  db '+AsmByteList(Pipeline.SourceName,True));
 EmitAsmLabel(T,MakeDataLabel(Pipeline.ModuleName+'_MODULE'));
 EmitAsmLine(T,'  db '+AsmByteList(Pipeline.ModuleName,True));
 EmitAsmLabel(T,MakeAsmLabel(MOD2_RUNTIME_PREFIX,'CRLF'));
 EmitAsmLine(T,'  db 13,10,0');
 For I:=1 To Pipeline.IrNodeCount Do
  If (Pipeline.IrNodes[I].Op=IR_EXPR_CONST) And
     (Pipeline.IrNodes[I].ConstValue.ScalarType=SCALAR_STRING) Then Begin
   EmitAsmLabel(T,IRStringLabel(I));
   EmitAsmLine(T,'  db '+
    AsmByteList(Pipeline.IrNodes[I].ConstValue.StringValue,True));
  End;
 EmitAsmBlank(T);
 EmitAsmSection(T,Pipeline.Target.BssSection);
 EmitGlobalBssVariables(T);
 Close(T);
 If IOResult<>0 Then Begin
  PipelineError('ecriture incomplete de '+FileName);
  Exit;
 End;
 WriteAsm80386File:=True;
End;

Procedure WriteRawByte(Var F:File;B:Byte);
Begin
 BlockWrite(F,B,1);
End;

Procedure WriteRawWordLE(Var F:File;W:Word);
Begin
 WriteRawByte(F,W And $FF);
 WriteRawByte(F,(W Shr 8) And $FF);
End;

Procedure WriteRawDWordLE(Var F:File;Value:LongInt);
Begin
 WriteRawWordLE(F,Value And $FFFF);
 WriteRawWordLE(F,(Value Shr 16) And $FFFF);
End;

Procedure WriteRawDWordWordsLE(Var F:File;LoWord,HiWord:Word);
Begin
 WriteRawWordLE(F,LoWord);
 WriteRawWordLE(F,HiWord);
End;

Procedure WriteRawZeroBytes(Var F:File;Count:LongInt);
Var
 I:LongInt;
Begin
 For I:=1 To Count Do WriteRawByte(F,0);
End;

Procedure WriteRawBytesFromString(Var F:File;S:String;ZeroTerminated:Boolean);
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do WriteRawByte(F,Ord(S[I]));
 If ZeroTerminated Then WriteRawByte(F,0);
End;

Procedure WriteFixedName8(Var F:File;Name:String);
Var
 I:Integer;
Begin
 For I:=1 To 8 Do
  If I<=Length(Name) Then WriteRawByte(F,Ord(Name[I]))
   Else WriteRawByte(F,0);
End;

Procedure WriteCoffSectionHeader(Var F:File;Section:TAsmSection;
 RawSize,RawPtr,RelocPtr:LongInt;RelocCount:Integer);
Begin
 WriteFixedName8(F,SectionName(Section));
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,RawSize);
 If RawSize=0 Then WriteRawDWordLE(F,0)
  Else WriteRawDWordLE(F,RawPtr);
 If RelocCount=0 Then WriteRawDWordLE(F,0)
  Else WriteRawDWordLE(F,RelocPtr);
 WriteRawDWordLE(F,0);
 WriteRawWordLE(F,RelocCount);
 WriteRawWordLE(F,0);
 WriteRawDWordWordsLE(F,CoffSectionFlagsLo(Section),CoffSectionFlagsHi(Section));
End;

Procedure WriteCoffSymbol(Var F:File;Name:String;Value:LongInt;
 SectionNumber:Integer;StorageClass:Byte);
Begin
 WriteFixedName8(F,Name);
 WriteRawDWordLE(F,Value);
 WriteRawWordLE(F,SectionNumber);
 WriteRawWordLE(F,0);
 WriteRawByte(F,StorageClass);
 WriteRawByte(F,0);
End;

Procedure WriteCoffRelocation(Var F:File;Reloc:TCoffReloc);
Begin
 WriteRawDWordLE(F,Reloc.Offset);
 WriteRawDWordLE(F,Reloc.SymbolIndex);
 WriteRawWordLE(F,CoffRelocType(Reloc.Kind));
End;

Function WriteCoffI386File(FileName:String):Boolean;
Const
 SectionCount = 3;
 TextSize     = 8;
Var
 F:File;
 I:Integer;
 SymbolCount:LongInt;
 GlobalCount:Integer;
 TextPtr:LongInt;
 DataPtr:LongInt;
 BssPtr:LongInt;
 SymbolPtr:LongInt;
 DataSize:LongInt;
 BssSize:LongInt;
 EntryName:String;
 SourceLabel:String;
 ModuleLabel:String;
Begin
 WriteCoffI386File:=False;
 GlobalCount:=0;
 For I:=1 To Pipeline.SymbolCount Do
  If Pipeline.Symbols[I].StorageKind=STORAGE_GLOBAL Then Inc(GlobalCount);
 SymbolCount:=6+GlobalCount;
 EntryName:=Pipeline.Target.EntryLabel;
 SourceLabel:=MakeDataLabel(Pipeline.ModuleName+'_SOURCE');
 ModuleLabel:=MakeDataLabel(Pipeline.ModuleName+'_MODULE');
 DataSize:=Length(Pipeline.SourceName)+1+Length(Pipeline.ModuleName)+1;
 BssSize:=Pipeline.GlobalBssSize;
 If BssSize<4 Then BssSize:=4;
 TextPtr:=COFF_FILE_HEADER_SIZE+(SectionCount*COFF_SECTION_HDR_SIZE);
 DataPtr:=TextPtr+TextSize;
 BssPtr:=0;
 SymbolPtr:=DataPtr+DataSize;
 Assign(F,FileName);
 Rewrite(F,1);
 If IOResult<>0 Then Begin
  PipelineError('impossible d''ecrire '+FileName);
  Exit;
 End;
 WriteRawWordLE(F,COFF_MACHINE_I386);
 WriteRawWordLE(F,SectionCount);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,SymbolPtr);
 WriteRawDWordLE(F,SymbolCount);
 WriteRawWordLE(F,0);
 WriteRawWordLE(F,0);
 WriteCoffSectionHeader(F,AS_TEXT,TextSize,TextPtr,0,0);
 WriteCoffSectionHeader(F,AS_DATA,DataSize,DataPtr,0,0);
 WriteCoffSectionHeader(F,AS_BSS,BssSize,BssPtr,0,0);
 WriteRawByte(F,$55);                    { push ebp }
 WriteRawByte(F,$8B); WriteRawByte(F,$EC);{ mov ebp, esp }
 WriteRawByte(F,$33); WriteRawByte(F,$C0);{ xor eax, eax }
 WriteRawByte(F,$5D);                    { pop ebp }
 WriteRawByte(F,$C3);                    { ret }
 WriteRawByte(F,$90);                    { align/debug nop }
 WriteRawBytesFromString(F,Pipeline.SourceName,True);
 WriteRawBytesFromString(F,Pipeline.ModuleName,True);
 WriteCoffSymbol(F,SectionName(AS_TEXT),0,CoffSectionNumber(AS_TEXT),
                 COFF_SYM_CLASS_STATIC);
 WriteCoffSymbol(F,SectionName(AS_DATA),0,CoffSectionNumber(AS_DATA),
                 COFF_SYM_CLASS_STATIC);
 WriteCoffSymbol(F,SectionName(AS_BSS),0,CoffSectionNumber(AS_BSS),
                 COFF_SYM_CLASS_STATIC);
 WriteCoffSymbol(F,EntryName,0,CoffSectionNumber(AS_TEXT),
                 COFF_SYM_CLASS_EXTERNAL);
 WriteCoffSymbol(F,SourceLabel,0,CoffSectionNumber(AS_DATA),
                 COFF_SYM_CLASS_STATIC);
 WriteCoffSymbol(F,ModuleLabel,Length(Pipeline.SourceName)+1,
                 CoffSectionNumber(AS_DATA),COFF_SYM_CLASS_STATIC);
 For I:=1 To Pipeline.SymbolCount Do
  If Pipeline.Symbols[I].StorageKind=STORAGE_GLOBAL Then
   WriteCoffSymbol(F,Pipeline.Symbols[I].AsmName,
                   Pipeline.Symbols[I].StorageOffset,
                   CoffSectionNumber(AS_BSS),COFF_SYM_CLASS_STATIC);
 WriteRawDWordLE(F,4);
 Close(F);
 If IOResult<>0 Then Begin
  PipelineError('ecriture incomplete de '+FileName);
  Exit;
 End;
 WriteCoffI386File:=True;
End;

Procedure PadToFilePos(Var F:File;TargetPos:LongInt);
Var
 CurPos:LongInt;
Begin
 CurPos:=FilePos(F);
 While CurPos<TargetPos Do Begin
  WriteRawByte(F,0);
  Inc(CurPos);
 End;
End;

Procedure WriteAsciiZ(Var F:File;S:String);
Begin
 WriteRawBytesFromString(F,S,True);
End;

Function EvalIRInteger(NodeIndex:Integer;
 Var Values:TSymbolValueArray):LongInt;
Var
 N:TIRExprNode;
 A:LongInt;
 B:LongInt;
Begin
 EvalIRInteger:=0;
 If (NodeIndex<1) Or (NodeIndex>Pipeline.IrNodeCount) Then Exit;
 N:=Pipeline.IrNodes[NodeIndex];
 Case N.Op Of
  IR_EXPR_CONST:EvalIRInteger:=N.ConstValue.IntegerValue;
  IR_EXPR_LOAD:
   If (N.SymbolIndex>=Low(Values)) And
      (N.SymbolIndex<=High(Values)) Then
    EvalIRInteger:=Values[N.SymbolIndex];
  IR_EXPR_NEG:EvalIRInteger:=-EvalIRInteger(N.LeftNode,Values);
  IR_EXPR_NOT:
   If EvalIRInteger(N.LeftNode,Values)=0 Then EvalIRInteger:=1;
  IR_EXPR_ORD:EvalIRInteger:=EvalIRInteger(N.LeftNode,Values);
  IR_EXPR_CHR:EvalIRInteger:=EvalIRInteger(N.LeftNode,Values) And $FF;
  IR_EXPR_ODD:EvalIRInteger:=EvalIRInteger(N.LeftNode,Values) And 1;
  IR_EXPR_ABS:
   Begin
    A:=EvalIRInteger(N.LeftNode,Values);
    If A<0 Then A:=-A;
    EvalIRInteger:=A;
   End;
  IR_EXPR_AND:
   If (EvalIRInteger(N.LeftNode,Values)<>0) And
      (EvalIRInteger(N.RightNode,Values)<>0) Then EvalIRInteger:=1;
  IR_EXPR_OR:
   If (EvalIRInteger(N.LeftNode,Values)<>0) Or
      (EvalIRInteger(N.RightNode,Values)<>0) Then EvalIRInteger:=1;
  Else Begin
   A:=EvalIRInteger(N.LeftNode,Values);
   B:=EvalIRInteger(N.RightNode,Values);
   Case N.Op Of
    IR_EXPR_ADD:EvalIRInteger:=A+B;
    IR_EXPR_SUB:EvalIRInteger:=A-B;
    IR_EXPR_MUL:EvalIRInteger:=A*B;
    IR_EXPR_DIV:
     If B<>0 Then EvalIRInteger:=A Div B;
    IR_EXPR_MOD:
     If B<>0 Then EvalIRInteger:=A Mod B;
    IR_EXPR_EQ:If A=B Then EvalIRInteger:=1;
    IR_EXPR_NE:If A<>B Then EvalIRInteger:=1;
    IR_EXPR_LT:If A<B Then EvalIRInteger:=1;
    IR_EXPR_LE:If A<=B Then EvalIRInteger:=1;
    IR_EXPR_GT:If A>B Then EvalIRInteger:=1;
    IR_EXPR_GE:If A>=B Then EvalIRInteger:=1;
   End;
  End;
 End;
End;

Function IRStringValue(NodeIndex:Integer):String;
Begin
 IRStringValue:='';
 If (NodeIndex>=1) And (NodeIndex<=Pipeline.IrNodeCount) And
    (Pipeline.IrNodes[NodeIndex].Op=IR_EXPR_CONST) And
    (Pipeline.IrNodes[NodeIndex].ConstValue.ScalarType=SCALAR_STRING) Then
  IRStringValue:=Pipeline.IrNodes[NodeIndex].ConstValue.StringValue;
End;

Function CallBaseName(Name:String):String;
Var
 I:Integer;
Begin
 For I:=Length(Name) DownTo 1 Do
  If Name[I]='.' Then Begin
   Delete(Name,1,I);
   Break;
  End;
 CallBaseName:=UpperStr(Name);
End;

Procedure AppendRuntimeOutput(Var OutputText:String;Text:String;
 LineNo,ColumnNo:Integer);
Begin
 If Length(OutputText)+Length(Text)>255 Then Begin
  PipelineErrorAt(EK_CODEGEN,
   'sortie InOut trop longue pour le backend PE minimal (maximum 255 octets)',
   LineNo,ColumnNo);
  Exit;
 End;
 OutputText:=OutputText+Text;
End;

Procedure ExecuteIRRange(StartIndex,EndIndex,ScopeIndex:Integer;
 Var Values:TSymbolValueArray;Var OutputText:String);
Var
 I:Integer;
 J:Integer;
 BodyEnd:Integer;
 Iterations:LongInt;
 S:TIRStatement;
 Name:String;
 Text:String;
 Value:LongInt;
 Width:LongInt;
 StepValue:LongInt;
 EndValue:LongInt;
Begin
 I:=StartIndex;
 While (I<=EndIndex) And (Pipeline.ErrorCount=0) Do Begin
  S:=Pipeline.IrStatements[I];
  If S.ScopeIndex<>ScopeIndex Then Begin
   Inc(I);
   Continue;
  End;
  Case S.Kind Of
   IR_STMT_ASSIGN:
    Values[S.TargetSymbol]:=EvalIRInteger(S.ExpressionRoot,Values);
   IR_STMT_CALL:
    Begin
     Name:=CallBaseName(S.ProcedureName);
     If Name='INC' Then Begin
      Value:=1;
      If S.ArgumentCount=2 Then
       Value:=EvalIRInteger(S.Arguments[2],Values);
      J:=Pipeline.IrNodes[S.Arguments[1]].SymbolIndex;
      Values[J]:=Values[J]+Value;
     End
     Else If Name='DEC' Then Begin
      Value:=1;
      If S.ArgumentCount=2 Then
       Value:=EvalIRInteger(S.Arguments[2],Values);
      J:=Pipeline.IrNodes[S.Arguments[1]].SymbolIndex;
      Values[J]:=Values[J]-Value;
     End
     Else If Name='WRITESTRING' Then
      AppendRuntimeOutput(OutputText,IRStringValue(S.Arguments[1]),
                          S.Line,S.Column)
     Else If Name='WRITELN' Then
      AppendRuntimeOutput(OutputText,Chr(13)+Chr(10),S.Line,S.Column)
     Else If Name='WRITECHAR' Then Begin
      Text:=Chr(EvalIRInteger(S.Arguments[1],Values) And $FF);
      AppendRuntimeOutput(OutputText,Text,S.Line,S.Column);
     End
     Else If (Name='WRITEINT') Or (Name='WRITECARD') Then Begin
      Value:=EvalIRInteger(S.Arguments[1],Values);
      Str(Value,Text);
      Width:=0;
      If S.ArgumentCount>=2 Then
       Width:=EvalIRInteger(S.Arguments[2],Values);
      While Length(Text)<Width Do Text:=' '+Text;
      AppendRuntimeOutput(OutputText,Text,S.Line,S.Column);
     End;
    End;
   IR_STMT_FOR_BEGIN:
    Begin
     BodyEnd:=I+1;
     While (BodyEnd<=EndIndex) And
      Not ((Pipeline.IrStatements[BodyEnd].Kind=IR_STMT_FOR_END) And
           (Pipeline.IrStatements[BodyEnd].ControlId=S.ControlId) And
           (Pipeline.IrStatements[BodyEnd].ScopeIndex=ScopeIndex)) Do
      Inc(BodyEnd);
     If BodyEnd>EndIndex Then Begin
      PipelineErrorAt(EK_CODEGEN,'FOR IR sans fin',S.Line,S.Column);
      Exit;
     End;
     Values[S.TargetSymbol]:=EvalIRInteger(S.ExpressionRoot,Values);
     EndValue:=EvalIRInteger(S.Arguments[1],Values);
     StepValue:=EvalIRInteger(S.Arguments[2],Values);
     Iterations:=0;
     While (StepValue<>0) And
      (((StepValue>0) And (Values[S.TargetSymbol]<=EndValue)) Or
       ((StepValue<0) And (Values[S.TargetSymbol]>=EndValue))) And
      (Pipeline.ErrorCount=0) Do Begin
      ExecuteIRRange(I+1,BodyEnd-1,ScopeIndex,Values,OutputText);
      Values[S.TargetSymbol]:=Values[S.TargetSymbol]+StepValue;
      Inc(Iterations);
      If Iterations>1000000 Then Begin
       PipelineErrorAt(EK_CODEGEN,
        'boucle trop longue pendant l''abaissement InOut',
        S.Line,S.Column);
       Exit;
      End;
     End;
     I:=BodyEnd;
    End;
  End;
  Inc(I);
 End;
End;

Function BuildInOutRuntimeOutput:String;
Var
 Values:TSymbolValueArray;
 OutputText:String;
Begin
 FillChar(Values,SizeOf(Values),0);
 OutputText:='';
 ExecuteIRRange(1,Pipeline.IrStatementCount,1,Values,OutputText);
 BuildInOutRuntimeOutput:=OutputText;
End;

Procedure WritePESectionHeader(Var F:File;Name:String;VirtualSize,VirtualAddress,
 RawSize,RawPtr:LongInt;FlagsLo,FlagsHi:Word);
Begin
 WriteFixedName8(F,Name);
 WriteRawDWordLE(F,VirtualSize);
 WriteRawDWordLE(F,VirtualAddress);
 WriteRawDWordLE(F,RawSize);
 WriteRawDWordLE(F,RawPtr);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,0);
 WriteRawWordLE(F,0);
 WriteRawWordLE(F,0);
 WriteRawDWordWordsLE(F,FlagsLo,FlagsHi);
End;

Procedure WritePEOptionalHeader(Var F:File);
Const
 ImportDirRva  = PE_IDATA_RVA;
 ImportDirSize = $120;
 IatRva        = PE_IDATA_RVA+$44;
 IatSize       = 16;
Var
 I:Integer;
Begin
 WriteRawWordLE(F,$010B);
 WriteRawByte(F,0);
 WriteRawByte(F,0);
 WriteRawDWordLE(F,PE_TEXT_RAW_SIZE);
 WriteRawDWordLE(F,PE_IDATA_RAW_SIZE);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,PE_TEXT_RVA);
 WriteRawDWordLE(F,PE_TEXT_RVA);
 WriteRawDWordLE(F,PE_IDATA_RVA);
 WriteRawDWordLE(F,WIN32_IMAGE_BASE);
 WriteRawDWordLE(F,WIN32_SECTION_ALIGN);
 WriteRawDWordLE(F,WIN32_FILE_ALIGN);
 WriteRawWordLE(F,4); WriteRawWordLE(F,0);
 WriteRawWordLE(F,0); WriteRawWordLE(F,0);
 WriteRawWordLE(F,4); WriteRawWordLE(F,0);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,PE_SIZE_OF_IMAGE);
 WriteRawDWordLE(F,PE_SIZE_OF_HEADERS);
 WriteRawDWordLE(F,0);
 WriteRawWordLE(F,PE_SUBSYSTEM_CONSOLE);
 WriteRawWordLE(F,0);
 WriteRawDWordLE(F,$00100000);
 WriteRawDWordLE(F,$00001000);
 WriteRawDWordLE(F,$00100000);
 WriteRawDWordLE(F,$00001000);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,16);
 For I:=0 To 15 Do Begin
  If I=1 Then Begin
   WriteRawDWordLE(F,ImportDirRva);
   WriteRawDWordLE(F,ImportDirSize);
  End
  Else If I=12 Then Begin
   WriteRawDWordLE(F,IatRva);
   WriteRawDWordLE(F,IatSize);
  End
  Else Begin
   WriteRawDWordLE(F,0);
   WriteRawDWordLE(F,0);
  End;
 End;
End;

Procedure WritePETextSection(Var F:File);
Const
 IatGetStdHandleVa = WIN32_IMAGE_BASE+PE_IDATA_RVA+$44;
 IatWriteFileVa    = WIN32_IMAGE_BASE+PE_IDATA_RVA+$48;
 IatExitProcessVa  = WIN32_IMAGE_BASE+PE_IDATA_RVA+$4C;
 MsgOff            = $80;
 WrittenOff        = $180;
Var
 OutputText:String;
 MsgVa:LongInt;
 WrittenVa:LongInt;
 I:Integer;
Begin
 OutputText:=BuildInOutRuntimeOutput;
 MsgVa:=WIN32_IMAGE_BASE+PE_TEXT_RVA+MsgOff;
 WrittenVa:=WIN32_IMAGE_BASE+PE_IDATA_RVA+WrittenOff;
 PadToFilePos(F,PE_TEXT_RAW_PTR);
 If OutputText<>'' Then Begin
  WriteRawByte(F,$6A); WriteRawByte(F,$F5);
  WriteRawByte(F,$FF); WriteRawByte(F,$15); WriteRawDWordLE(F,IatGetStdHandleVa);
  WriteRawByte(F,$6A); WriteRawByte(F,$00);
  WriteRawByte(F,$68); WriteRawDWordLE(F,WrittenVa);
  WriteRawByte(F,$68); WriteRawDWordLE(F,Length(OutputText));
  WriteRawByte(F,$68); WriteRawDWordLE(F,MsgVa);
  WriteRawByte(F,$50);
  WriteRawByte(F,$FF); WriteRawByte(F,$15); WriteRawDWordLE(F,IatWriteFileVa);
 End;
 WriteRawByte(F,$6A); WriteRawByte(F,$00);
 WriteRawByte(F,$FF); WriteRawByte(F,$15); WriteRawDWordLE(F,IatExitProcessVa);
 WriteRawByte(F,$CC);
 PadToFilePos(F,PE_TEXT_RAW_PTR+MsgOff);
 For I:=1 To Length(OutputText) Do WriteRawByte(F,Ord(OutputText[I]));
 PadToFilePos(F,PE_TEXT_RAW_PTR+PE_TEXT_RAW_SIZE);
End;

Procedure WritePEImportSection(Var F:File);
Const
 DescOff        = $00;
 OftOff         = $30;
 IatOff         = $44;
 DllOff         = $70;
 ExitHintOff    = $90;
 GetStdHintOff  = $A0;
 WriteHintOff   = $B0;
 WrittenOff     = $180;
Begin
 PadToFilePos(F,PE_IDATA_RAW_PTR+DescOff);
 WriteRawDWordLE(F,PE_IDATA_RVA+OftOff);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,PE_IDATA_RVA+DllOff);
 WriteRawDWordLE(F,PE_IDATA_RVA+IatOff);
 WriteRawZeroBytes(F,20);

 PadToFilePos(F,PE_IDATA_RAW_PTR+OftOff);
 WriteRawDWordLE(F,PE_IDATA_RVA+GetStdHintOff);
 WriteRawDWordLE(F,PE_IDATA_RVA+WriteHintOff);
 WriteRawDWordLE(F,PE_IDATA_RVA+ExitHintOff);
 WriteRawDWordLE(F,0);

 PadToFilePos(F,PE_IDATA_RAW_PTR+IatOff);
 WriteRawDWordLE(F,PE_IDATA_RVA+GetStdHintOff);
 WriteRawDWordLE(F,PE_IDATA_RVA+WriteHintOff);
 WriteRawDWordLE(F,PE_IDATA_RVA+ExitHintOff);
 WriteRawDWordLE(F,0);

 PadToFilePos(F,PE_IDATA_RAW_PTR+DllOff);
 WriteAsciiZ(F,'KERNEL32.dll');
 PadToFilePos(F,PE_IDATA_RAW_PTR+ExitHintOff);
 WriteRawWordLE(F,0);
 WriteAsciiZ(F,'ExitProcess');
 PadToFilePos(F,PE_IDATA_RAW_PTR+GetStdHintOff);
 WriteRawWordLE(F,0);
 WriteAsciiZ(F,'GetStdHandle');
 PadToFilePos(F,PE_IDATA_RAW_PTR+WriteHintOff);
 WriteRawWordLE(F,0);
 WriteAsciiZ(F,'WriteFile');
 PadToFilePos(F,PE_IDATA_RAW_PTR+WrittenOff);
 WriteRawDWordLE(F,0);
 PadToFilePos(F,PE_IDATA_RAW_PTR+PE_IDATA_RAW_SIZE);
End;

Function WriteMinimalPE32Exe(FileName:String):Boolean;
Var
 F:File;
Begin
 WriteMinimalPE32Exe:=False;
 Assign(F,FileName);
 Rewrite(F,1);
 If IOResult<>0 Then Begin
  PipelineError('impossible d''ecrire '+FileName);
  Exit;
 End;
 WriteRawByte(F,Ord('M'));
 WriteRawByte(F,Ord('Z'));
 WriteRawZeroBytes(F,58);
 WriteRawDWordLE(F,PE_DOS_LFANEW);
 PadToFilePos(F,PE_DOS_LFANEW);
 WriteRawByte(F,Ord('P'));
 WriteRawByte(F,Ord('E'));
 WriteRawByte(F,0);
 WriteRawByte(F,0);
 WriteRawWordLE(F,COFF_MACHINE_I386);
 WriteRawWordLE(F,2);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,0);
 WriteRawDWordLE(F,0);
 WriteRawWordLE(F,PE_OPT_HEADER_SIZE);
 WriteRawWordLE(F,PE_FILE_CHAR_LO);
 WritePEOptionalHeader(F);
 WritePESectionHeader(F,SectionName(AS_TEXT),PE_TEXT_RAW_SIZE,PE_TEXT_RVA,
                      PE_TEXT_RAW_SIZE,PE_TEXT_RAW_PTR,
                      COFF_TEXT_FLAGS_LO,COFF_TEXT_FLAGS_HI);
 WritePESectionHeader(F,'.idata',PE_IDATA_RAW_SIZE,PE_IDATA_RVA,
                      PE_IDATA_RAW_SIZE,PE_IDATA_RAW_PTR,
                      COFF_IDATA_FLAGS_LO,COFF_IDATA_FLAGS_HI);
 PadToFilePos(F,PE_SIZE_OF_HEADERS);
 WritePETextSection(F);
 WritePEImportSection(F);
 Close(F);
 If IOResult<>0 Then Begin
  PipelineError('ecriture incomplete de '+FileName);
  Exit;
 End;
 WriteMinimalPE32Exe:=True;
End;

Procedure InitTargetModel(Var Target:TTargetModel);
Begin
 Target.CpuName:='80386';
 Target.OsName:='Win32';
 Target.Bits:=32;
 Target.ImageBase:=WIN32_IMAGE_BASE;
 Target.SectionAlign:=WIN32_SECTION_ALIGN;
 Target.FileAlign:=WIN32_FILE_ALIGN;
 Target.StackAlign:=I386_STACK_ALIGN;
 Target.StackSlotSize:=I386_STACK_SLOT_SIZE;
 Target.ArgBaseOffset:=I386_ARG_BASE_OFFSET;
 Target.CodeSection:=AS_TEXT;
 Target.DataSection:=AS_DATA;
 Target.BssSection:=AS_BSS;
 Target.EntryLabel:=MOD2_ENTRY_LABEL;
End;

Procedure TraceTargetModel;
Begin
 WriteLn('Target : ',Pipeline.Target.CpuName,' / ',Pipeline.Target.OsName,
         ' / ',Pipeline.Target.Bits,' bits, modele plat');
 WriteLn('PE     : image base ',Pipeline.Target.ImageBase,
         ', section align ',Pipeline.Target.SectionAlign,
         ', file align ',Pipeline.Target.FileAlign);
 WriteLn('Section: ',SectionName(Pipeline.Target.CodeSection),
         ' align ',SectionAlign(Pipeline.Target.CodeSection),' code');
 WriteLn('Section: ',SectionName(Pipeline.Target.DataSection),
         ' align ',SectionAlign(Pipeline.Target.DataSection),' donnees initialisees');
 WriteLn('Section: ',SectionName(Pipeline.Target.BssSection),
         ' align ',SectionAlign(Pipeline.Target.BssSection),' donnees non initialisees');
 WriteLn('Regs   : ',RegName(R_EAX),' ',RegName(R_EBX),' ',RegName(R_ECX),' ',
         RegName(R_EDX),' ',RegName(R_ESI),' ',RegName(R_EDI),' ',
         RegName(R_EBP),' ',RegName(R_ESP));
 WriteLn('Call   : pile 32 bits, arguments empiles, nettoyage par appelant');
 WriteLn('Frame  : push ebp / mov ebp, esp / sub esp, locals');
 WriteLn('Return : mov esp, ebp / pop ebp / ret');
 WriteLn('Arg #1 : ',ArgValueRef(1),' contient la premiere valeur/adresse');
 WriteLn('Local  : ',LocalVarRef(4),' pour le premier slot local 32 bits');
 WriteLn('Entry  : ',Pipeline.Target.EntryLabel);
End;

Function ReadSourceLine(LineNo:LongInt):String;
Var
 F:Text;
 Line:String;
 Current:LongInt;
Begin
 ReadSourceLine:='';
 If LineNo<1 Then Exit;
 Assign(F,Pipeline.SourceName);
 Reset(F);
 If IOResult<>0 Then Exit;
 Current:=0;
 While Not Eof(F) Do Begin
  ReadLn(F,Line);
  Inc(Current);
  If Current=LineNo Then Begin
   ReadSourceLine:=Line;
   Break;
  End;
 End;
 Close(F);
 If IOResult<>0 Then ;
End;

Function CaretLine(ColumnNo:LongInt):String;
Var
 I:LongInt;
Begin
 If ColumnNo<1 Then ColumnNo:=1;
 CaretLine:='';
 For I:=1 To ColumnNo-1 Do CaretLine:=CaretLine+' ';
 CaretLine:=CaretLine+'^';
End;

Procedure PrintDiagnostic;
Begin
 WriteLn('MOD2CW32: erreur ',ErrorKindName(Pipeline.ErrorKind),
         ' dans ',StageName(Pipeline.ErrorStage));
 If Pipeline.ErrorFile<>'' Then Begin
  Write('  fichier : ',Pipeline.ErrorFile);
  If Pipeline.ErrorLine>0 Then Write('(',Pipeline.ErrorLine);
  If Pipeline.ErrorColumn>0 Then Write(',',Pipeline.ErrorColumn);
  If Pipeline.ErrorLine>0 Then Write(')');
  WriteLn;
 End;
 WriteLn('  message : ',Pipeline.ErrorMessage);
 If Pipeline.ErrorSnippet<>'' Then Begin
  WriteLn('  extrait : ',Pipeline.ErrorSnippet);
  If Pipeline.ErrorColumn>0 Then WriteLn('            ',CaretLine(Pipeline.ErrorColumn));
 End;
End;

Procedure RegisterDiagnostic(Kind:TErrorKind;Msg:String;LineNo,ColumnNo:LongInt);
Begin
 Inc(Pipeline.ErrorCount);
 Pipeline.ErrorKind:=Kind;
 Pipeline.ErrorFile:=Pipeline.SourceName;
 Pipeline.ErrorLine:=LineNo;
 Pipeline.ErrorColumn:=ColumnNo;
 Pipeline.ErrorStage:=Pipeline.CurrentStage;
 Pipeline.ErrorSnippet:='';
 Pipeline.ErrorMessage:=Msg;
 If LineNo>0 Then Pipeline.ErrorSnippet:=ReadSourceLine(LineNo);
 PrintDiagnostic;
End;

Procedure PipelineError(Msg:String);
Begin
 RegisterDiagnostic(EK_INTERNAL,Msg,0,0);
End;

Procedure PipelineErrorKind(Kind:TErrorKind;Msg:String);
Begin
 RegisterDiagnostic(Kind,Msg,0,0);
End;

Procedure PipelineErrorAt(Kind:TErrorKind;Msg:String;LineNo,ColumnNo:LongInt);
Begin
 RegisterDiagnostic(Kind,Msg,LineNo,ColumnNo);
End;

Procedure LexicalError(Msg:String;LineNo,ColumnNo:LongInt);
Begin
 PipelineErrorAt(EK_LEXICAL,Msg,LineNo,ColumnNo);
End;

Procedure SyntaxError(Msg:String;LineNo,ColumnNo:LongInt);
Begin
 PipelineErrorAt(EK_SYNTAX,Msg,LineNo,ColumnNo);
End;

Procedure SemanticError(Msg:String;LineNo,ColumnNo:LongInt);
Begin
 PipelineErrorAt(EK_SEMANTIC,Msg,LineNo,ColumnNo);
End;

Procedure CodegenError(Msg:String);
Begin
 PipelineErrorKind(EK_CODEGEN,Msg);
End;

Procedure InitOptions;
Begin
 Options.SourceName:='';
 Options.OutputName:='';
 Options.OutputKind:=OK_EXE_PE32;
 Options.EmitAsm:=False;
 Options.Verbose:=False;
End;

Procedure PrintVersion;
Begin
 WriteLn('MOD2CW32 ',MOD2CW32_VERSION);
End;

Procedure PrintUsage;Begin
 WriteLn('MOD2CW32 - Cette commande permet de ',
         'lancer le compilateur Modula-2 pour l''assembleur du microprocesseur ',
         '80386 pour Windows 32 bits.');
 WriteLn;
 WriteLn('Syntaxe : MOD2CW32 <source.mod> [options]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -c, --obj-only     : produire seulement un fichier objet COFF i386 .OBJ');
 WriteLn('  -S, --asm          : produire/conserver aussi le fichier assembleur .ASM');
 WriteLn('  -o <fichier>       : specifier le nom du fichier de sortie');
 WriteLn('  -v, --verbose      : afficher le pipeline selectionne');
 WriteLn('  -h, --help         : afficher cette aide');
 WriteLn('  --version          : afficher la version');
End;

Function IsHelpSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsHelpSwitch:=(S='-H') Or (S='--HELP') Or (S='/?') Or (S='/H');
End;

Function IsVersionSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsVersionSwitch:=(S='--VERSION') Or (S='-VERSION');
End;

Function IsObjOnlySwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsObjOnlySwitch:=(S='-C') Or (S='--OBJ-ONLY') Or (S='/C');
End;

Function IsAsmSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsAsmSwitch:=(S='-S') Or (S='--ASM') Or (S='/S');
End;

Function IsVerboseSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsVerboseSwitch:=(S='-V') Or (S='--VERBOSE') Or (S='/V');
End;

Function IsOutputSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsOutputSwitch:=(S='-O') Or (S='--OUTPUT') Or (S='/O');
End;

Procedure ParseCommandLine;
Var
 I:Integer;
 S:String;
Begin
 InitOptions;
 I:=1;
 While I<=ParamCount Do Begin
  S:=ParamStr(I);
  If IsHelpSwitch(S) Then Begin
   PrintUsage;
   Halt;
  End
  Else If IsVersionSwitch(S) Then Begin
   PrintVersion;
   Halt;
  End
  Else If IsObjOnlySwitch(S) Then Options.OutputKind:=OK_OBJ_COFF
  Else If IsAsmSwitch(S) Then Options.EmitAsm:=True
  Else If IsVerboseSwitch(S) Then Options.Verbose:=True
  Else If IsOutputSwitch(S) Then Begin
   Inc(I);
   If I>ParamCount Then Begin
    WriteLn('Erreur: option ',S,' sans nom de fichier.');
    Halt(1);
   End;
   Options.OutputName:=ParamStr(I);
  End
  Else If HasSwitchPrefix(S) Then Begin
   WriteLn('Erreur: option inconnue: ',S);
   Halt(1);
  End
  Else Begin
   If Options.SourceName<>'' Then Begin
    WriteLn('Erreur: plusieurs fichiers sources specifies: ',
            Options.SourceName,' et ',S);
    Halt(1);
   End;
   Options.SourceName:=S;
  End;
  Inc(I);
 End;
 If Options.SourceName='' Then Begin
  PrintUsage;
  Halt(1);
 End;
 ValidatePathLength(Options.SourceName,'le chemin source');
 If Options.OutputName<>'' Then
  ValidatePathLength(Options.OutputName,'le chemin de sortie');
End;

Procedure InitPipeline;
Var
 OutputBase:String;
Begin
 FillChar(Pipeline,SizeOf(Pipeline),0);
 Pipeline.SourceName:=Options.SourceName;
 Pipeline.ModuleName:=FileBaseName(Options.SourceName);
 If Options.OutputName<>'' Then OutputBase:=Options.OutputName
  Else OutputBase:=StripExtension(Options.SourceName);
 If Options.OutputKind=OK_OBJ_COFF Then Begin
  Pipeline.ObjName:=EnsureExtension(OutputBase,MOD2_OBJ_EXT);
  Pipeline.ExeName:=ChangeExtension(Pipeline.ObjName,MOD2_EXE_EXT);
  Pipeline.AsmName:=ChangeExtension(Pipeline.ObjName,MOD2_ASM_EXT);
 End
 Else Begin
  Pipeline.ExeName:=EnsureExtension(OutputBase,MOD2_EXE_EXT);
  Pipeline.ObjName:=ChangeExtension(Pipeline.ExeName,MOD2_OBJ_EXT);
  Pipeline.AsmName:=ChangeExtension(Pipeline.ExeName,MOD2_ASM_EXT);
 End;
 Pipeline.CurrentStage:=CS_LOAD_SOURCE;
 Pipeline.LastCompleted:=CS_LOAD_SOURCE;
 Pipeline.OutputKind:=Options.OutputKind;
 Pipeline.EmitAsm:=Options.EmitAsm;
 Pipeline.StopAfterObj:=Options.OutputKind=OK_OBJ_COFF;
 InitTargetModel(Pipeline.Target);
End;

Procedure TracePipelineLayout;
Begin
 WriteLn('MOD2CW32 ',MOD2CW32_VERSION,' pipeline:');
 WriteLn('  1. ',StageName(CS_LOAD_SOURCE));
 WriteLn('  2. ',StageName(CS_LEXER));
 WriteLn('  3. ',StageName(CS_PARSER));
 WriteLn('  4. ',StageName(CS_SEMANTIC_TABLES));
 WriteLn('  5. ',StageName(CS_IR));
 WriteLn('  6. ',StageName(CS_ASM_80386),' (optionnel)');
 WriteLn('  7. ',StageName(CS_OBJ_COFF));
 WriteLn('  8. ',StageName(CS_EXE_PE32),' (par defaut)');
End;

Procedure EnterStage(Stage:TCompileStage);
Begin
 Pipeline.CurrentStage:=Stage;
 WriteLn('Etape: ',StageName(Stage));
End;

Procedure FinishStage(Stage:TCompileStage);
Begin
 Pipeline.LastCompleted:=Stage;
End;

Function LexerAtEnd:Boolean;
Begin
 LexerAtEnd:=Pipeline.LexerLine>Pipeline.StoredLineCount;
End;

Function LexerCurrentChar:Char;
Begin
 If LexerAtEnd Then LexerCurrentChar:=#0
 Else If Pipeline.LexerColumn>Length(Pipeline.SourceText[Pipeline.LexerLine]) Then
  LexerCurrentChar:=#10
 Else LexerCurrentChar:=Pipeline.SourceText[Pipeline.LexerLine][Pipeline.LexerColumn];
End;

Function LexerPeekChar:Char;
Begin
 If LexerAtEnd Then LexerPeekChar:=#0
 Else If Pipeline.LexerColumn<Length(Pipeline.SourceText[Pipeline.LexerLine]) Then
  LexerPeekChar:=Pipeline.SourceText[Pipeline.LexerLine][Pipeline.LexerColumn+1]
 Else LexerPeekChar:=#10;
End;

Procedure LexerAdvance;
Begin
 If LexerAtEnd Then Exit;
 If Pipeline.LexerColumn>Length(Pipeline.SourceText[Pipeline.LexerLine]) Then Begin
  Inc(Pipeline.LexerLine);
  Pipeline.LexerColumn:=1;
 End
 Else Inc(Pipeline.LexerColumn);
End;

Function IsIdentStart(C:Char):Boolean;
Begin
 IsIdentStart:=((C>='A') And (C<='Z')) Or
               ((C>='a') And (C<='z')) Or (C='_');
End;

Function IsIdentChar(C:Char):Boolean;
Begin
 IsIdentChar:=IsIdentStart(C) Or ((C>='0') And (C<='9'));
End;

Function IsHexChar(C:Char):Boolean;
Begin
 C:=UpCase(C);
 IsHexChar:=((C>='0') And (C<='9')) Or ((C>='A') And (C<='F'));
End;

Function DigitValue(C:Char):Integer;
Begin
 C:=UpCase(C);
 If (C>='0') And (C<='9') Then DigitValue:=Ord(C)-Ord('0')
 Else If (C>='A') And (C<='F') Then DigitValue:=10+Ord(C)-Ord('A')
 Else DigitValue:=-1;
End;

Function ParseIntegerToken(Text:String;LineNo,ColumnNo:Integer;
 Var Value:LongInt):Boolean;
Var
 Base:Integer;
 I:Integer;
 LimitText:String;
 D:Integer;
 U:String;
Begin
 ParseIntegerToken:=False;
 Value:=0;
 U:=UpperStr(Text);
 Base:=10;
 LimitText:=U;
 If Length(U)>1 Then Begin
  If U[Length(U)]='H' Then Begin
   Base:=16;
   Delete(LimitText,Length(LimitText),1);
  End
  Else If (U[Length(U)]='B') Or (U[Length(U)]='C') Then Begin
   Base:=8;
   Delete(LimitText,Length(LimitText),1);
  End;
 End;
 If LimitText='' Then Begin
  LexicalError('constante entiere vide',LineNo,ColumnNo);
  Exit;
 End;
 For I:=1 To Length(LimitText) Do Begin
  D:=DigitValue(LimitText[I]);
  If (D<0) Or (D>=Base) Then Begin
   LexicalError('chiffre invalide dans la constante '+Text,LineNo,ColumnNo+I-1);
   Exit;
  End;
  If Value>(2147483647-D) Div Base Then Begin
   LexicalError('constante entiere hors limite 32 bits',LineNo,ColumnNo);
   Exit;
  End;
  Value:=(Value*Base)+D;
 End;
 ParseIntegerToken:=True;
End;

Function AddToken(Kind:TTokenKind;Keyword:TKeyword;Text:String;
 Value:LongInt;LineNo,ColumnNo:Integer):Boolean;
Begin
 AddToken:=False;
 If Pipeline.TokenCount>=MOD2_MAX_TOKENS Then Begin
  LexicalError('trop de tokens dans le module',LineNo,ColumnNo);
  Exit;
 End;
 If Length(Text)>127 Then Begin
  LexicalError('token trop long (maximum 127 caracteres)',LineNo,ColumnNo);
  Exit;
 End;
 Inc(Pipeline.TokenCount);
 Pipeline.Tokens[Pipeline.TokenCount].Kind:=Kind;
 Pipeline.Tokens[Pipeline.TokenCount].Keyword:=Keyword;
 Pipeline.Tokens[Pipeline.TokenCount].Text:=Text;
 Pipeline.Tokens[Pipeline.TokenCount].IntegerVal:=Value;
 Pipeline.Tokens[Pipeline.TokenCount].Line:=LineNo;
 Pipeline.Tokens[Pipeline.TokenCount].Column:=ColumnNo;
 AddToken:=True;
End;

Function SkipNestedComment:Boolean;
Var
 Depth:Integer;
 StartLine:Integer;
 StartColumn:Integer;
Begin
 SkipNestedComment:=False;
 StartLine:=Pipeline.LexerLine;
 StartColumn:=Pipeline.LexerColumn;
 Depth:=1;
 Inc(Pipeline.CommentCount);
 LexerAdvance;
 LexerAdvance;
 While Depth>0 Do Begin
  If LexerAtEnd Then Begin
   LexicalError('commentaire (* non termine',StartLine,StartColumn);
   Exit;
  End;
  If (LexerCurrentChar='(') And (LexerPeekChar='*') Then Begin
   Inc(Depth);
   LexerAdvance;
   LexerAdvance;
  End
  Else If (LexerCurrentChar='*') And (LexerPeekChar=')') Then Begin
   Dec(Depth);
   LexerAdvance;
   LexerAdvance;
  End
  Else LexerAdvance;
 End;
 SkipNestedComment:=True;
End;

Function ScanIdentifier:Boolean;
Var
 Text:String;
 LineNo:Integer;
 ColumnNo:Integer;
 Keyword:TKeyword;
Begin
 ScanIdentifier:=False;
 Text:='';
 LineNo:=Pipeline.LexerLine;
 ColumnNo:=Pipeline.LexerColumn;
 While IsIdentChar(LexerCurrentChar) Do Begin
  If Length(Text)>=127 Then Begin
   LexicalError('identificateur trop long',LineNo,ColumnNo);
   Exit;
  End;
  Text:=Text+LexerCurrentChar;
  LexerAdvance;
 End;
 Keyword:=FindKeyword(Text);
 If Keyword=KW_NONE Then
  ScanIdentifier:=AddToken(TK_IDENTIFIER,KW_NONE,Text,0,LineNo,ColumnNo)
 Else
  ScanIdentifier:=AddToken(TK_KEYWORD,Keyword,KeywordName(Keyword),0,
                           LineNo,ColumnNo);
End;

Function ScanInteger:Boolean;
Var
 Text:String;
 LineNo:Integer;
 ColumnNo:Integer;
 Value:LongInt;
 C:Char;
Begin
 ScanInteger:=False;
 Text:='';
 LineNo:=Pipeline.LexerLine;
 ColumnNo:=Pipeline.LexerColumn;
 While True Do Begin
  C:=LexerCurrentChar;
  If ((C>='0') And (C<='9')) Or
     ((UpCase(C)>='A') And (UpCase(C)<='H')) Then Begin
   If Length(Text)>=127 Then Begin
    LexicalError('constante entiere trop longue',LineNo,ColumnNo);
    Exit;
   End;
   Text:=Text+C;
   LexerAdvance;
  End
  Else Break;
 End;
 If Not ParseIntegerToken(Text,LineNo,ColumnNo,Value) Then Exit;
 ScanInteger:=AddToken(TK_INTEGER,KW_NONE,Text,Value,LineNo,ColumnNo);
End;

Function ScanStringLiteral:Boolean;
Var
 Text:String;
 Delimiter:Char;
 LineNo:Integer;
 ColumnNo:Integer;
Begin
 ScanStringLiteral:=False;
 Text:='';
 Delimiter:=LexerCurrentChar;
 LineNo:=Pipeline.LexerLine;
 ColumnNo:=Pipeline.LexerColumn;
 LexerAdvance;
 While True Do Begin
  If LexerAtEnd Or (LexerCurrentChar=#10) Then Begin
   LexicalError('chaine non terminee',LineNo,ColumnNo);
   Exit;
  End;
  If LexerCurrentChar=Delimiter Then Begin
   If LexerPeekChar=Delimiter Then Begin
    If Length(Text)>=127 Then Begin
     LexicalError('chaine trop longue',LineNo,ColumnNo);
     Exit;
    End;
    Text:=Text+Delimiter;
    LexerAdvance;
    LexerAdvance;
   End
   Else Begin
    LexerAdvance;
    Break;
   End;
  End
  Else Begin
   If Length(Text)>=127 Then Begin
    LexicalError('chaine trop longue',LineNo,ColumnNo);
    Exit;
   End;
   Text:=Text+LexerCurrentChar;
   LexerAdvance;
  End;
 End;
 ScanStringLiteral:=AddToken(TK_STRING,KW_NONE,Text,0,LineNo,ColumnNo);
End;

Function ScanSymbol:Boolean;
Var
 Text:String;
 C:Char;
 LineNo:Integer;
 ColumnNo:Integer;
Begin
 ScanSymbol:=False;
 Text:='';
 C:=LexerCurrentChar;
 LineNo:=Pipeline.LexerLine;
 ColumnNo:=Pipeline.LexerColumn;
 If ((C=':') And (LexerPeekChar='=')) Or
    ((C='<') And (LexerPeekChar='=')) Or
    ((C='>') And (LexerPeekChar='=')) Or
    ((C='<') And (LexerPeekChar='>')) Or
    ((C='.') And (LexerPeekChar='.')) Then Begin
  Text:=C+LexerPeekChar;
  LexerAdvance;
  LexerAdvance;
 End
 Else If Pos(C,'+-*/=#<>()[]{};,.:^|&~')>0 Then Begin
  Text:=C;
  LexerAdvance;
 End
 Else Begin
  LexicalError('caractere illegal: code '+IntToString(Ord(C)),LineNo,ColumnNo);
  Exit;
 End;
 ScanSymbol:=AddToken(TK_SYMBOL,KW_NONE,Text,0,LineNo,ColumnNo);
End;

Procedure TraceTokens;
Var
 I:Integer;
 Extra:String;
Begin
 If Not Options.Verbose Then Exit;
 WriteLn('Lexer  : ',Pipeline.TokenCount,' tokens, ',
         Pipeline.CommentCount,' commentaires');
 For I:=1 To Pipeline.TokenCount Do Begin
  Extra:='';
  If Pipeline.Tokens[I].Kind=TK_INTEGER Then
   Extra:=' = '+IntToString(Pipeline.Tokens[I].IntegerVal);
  WriteLn('Token  : ',Pipeline.Tokens[I].Line,':',
          Pipeline.Tokens[I].Column,' ',
          TokenKindName(Pipeline.Tokens[I].Kind),' ',
          Pipeline.Tokens[I].Text,Extra);
 End;
End;

Function TokenizeSource:Boolean;
Var
 C:Char;
Begin
 TokenizeSource:=False;
 Pipeline.TokenCount:=0;
 Pipeline.CommentCount:=0;
 Pipeline.LexerLine:=1;
 Pipeline.LexerColumn:=1;
 While Not LexerAtEnd Do Begin
  C:=LexerCurrentChar;
  If (C=' ') Or (C=#9) Or (C=#10) Or (C=#13) Then
   LexerAdvance
  Else If (C='(') And (LexerPeekChar='*') Then Begin
   If Not SkipNestedComment Then Exit;
  End
  Else If IsIdentStart(C) Then Begin
   If Not ScanIdentifier Then Exit;
  End
  Else If (C>='0') And (C<='9') Then Begin
   If Not ScanInteger Then Exit;
  End
  Else If (C='''') Or (C='"') Then Begin
   If Not ScanStringLiteral Then Exit;
  End
  Else If Not ScanSymbol Then Exit;
 End;
 If Not AddToken(TK_EOF,KW_NONE,'',0,Pipeline.StoredLineCount+1,1) Then Exit;
 TokenizeSource:=True;
End;

Procedure LoadSource;
Var
 F:Text;
 Line:String;
Begin
 EnterStage(CS_LOAD_SOURCE);
 Assign(F,Pipeline.SourceName);
 Reset(F);
 If IOResult<>0 Then Begin
  PipelineErrorKind(EK_IO,'impossible de lire '+Pipeline.SourceName);
  Exit;
 End;
 While Not Eof(F) Do Begin
  ReadLn(F,Line);
  Inc(Pipeline.SourceLines);
  Inc(Pipeline.SourceBytes,Length(Line)+2);
  If Pipeline.StoredLineCount>=MOD2_MAX_SOURCE_LINES Then Begin
   Close(F);
   PipelineErrorKind(EK_IO,'source trop long: maximum '+
                     IntToString(MOD2_MAX_SOURCE_LINES)+' lignes');
   Exit;
  End;
  Inc(Pipeline.StoredLineCount);
  Pipeline.SourceText[Pipeline.StoredLineCount]:=Line;
 End;
 Close(F);
 If IOResult<>0 Then ;
 Pipeline.SourceLoaded:=True;
 FinishStage(CS_LOAD_SOURCE);
 WriteLn('Source: ',Pipeline.SourceLines,' lignes, ',Pipeline.SourceBytes,' octets');
End;

Procedure RunLexer;
Begin
 EnterStage(CS_LEXER);
 If TokenizeSource Then Begin
  Pipeline.Lexed:=True;
  FinishStage(CS_LEXER);
  TraceTokens;
  If Not Options.Verbose Then
   WriteLn('Lexer  : ',Pipeline.TokenCount,' tokens');
 End;
End;

Function CurrentToken:TToken;
Begin
 If Pipeline.ParserIndex<1 Then Pipeline.ParserIndex:=1;
 If Pipeline.ParserIndex>Pipeline.TokenCount Then
  CurrentToken:=Pipeline.Tokens[Pipeline.TokenCount]
 Else
  CurrentToken:=Pipeline.Tokens[Pipeline.ParserIndex];
End;

Procedure ParserAdvance;
Begin
 If Pipeline.ParserIndex<Pipeline.TokenCount Then Inc(Pipeline.ParserIndex);
End;

Function TokenIsKeyword(Keyword:TKeyword):Boolean;
Begin
 TokenIsKeyword:=(CurrentToken.Kind=TK_KEYWORD) And
                 (CurrentToken.Keyword=Keyword);
End;

Function TokenIsSymbol(SymbolText:String):Boolean;
Begin
 TokenIsSymbol:=(CurrentToken.Kind=TK_SYMBOL) And
                (CurrentToken.Text=SymbolText);
End;

Function AcceptKeyword(Keyword:TKeyword):Boolean;
Begin
 AcceptKeyword:=TokenIsKeyword(Keyword);
 If AcceptKeyword Then ParserAdvance;
End;

Function AcceptSymbol(SymbolText:String):Boolean;
Begin
 AcceptSymbol:=TokenIsSymbol(SymbolText);
 If AcceptSymbol Then ParserAdvance;
End;

Function ParserFail(Msg:String):Boolean;
Var
 Token:TToken;
Begin
 Token:=CurrentToken;
 SyntaxError(Msg,Token.Line,Token.Column);
 ParserFail:=False;
End;

Function ExpectKeyword(Keyword:TKeyword):Boolean;
Begin
 If Not TokenIsKeyword(Keyword) Then Begin
  ExpectKeyword:=ParserFail('mot-cle '+KeywordName(Keyword)+' attendu');
  Exit;
 End;
 ParserAdvance;
 ExpectKeyword:=True;
End;

Function ExpectSymbol(SymbolText:String):Boolean;
Begin
 If Not TokenIsSymbol(SymbolText) Then Begin
  ExpectSymbol:=ParserFail('symbole "'+SymbolText+'" attendu');
  Exit;
 End;
 ParserAdvance;
 ExpectSymbol:=True;
End;

Function ExpectIdentifier(Var Name:String):Boolean;
Begin
 ExpectIdentifier:=False;
 If CurrentToken.Kind<>TK_IDENTIFIER Then Begin
  ParserFail('identificateur attendu');
  Exit;
 End;
 Name:=CurrentToken.Text;
 ParserAdvance;
 ExpectIdentifier:=True;
End;

Function SkipUntilSemicolon(AllowRecord:Boolean):Boolean;
Var
 ParenDepth:Integer;
 BracketDepth:Integer;
 RecordDepth:Integer;
Begin
 SkipUntilSemicolon:=False;
 ParenDepth:=0;
 BracketDepth:=0;
 RecordDepth:=0;
 While CurrentToken.Kind<>TK_EOF Do Begin
  If TokenIsSymbol('(') Then Inc(ParenDepth)
  Else If TokenIsSymbol(')') Then Begin
   If ParenDepth=0 Then Begin
    ParserFail('parenthese fermante sans parenthese ouvrante');
    Exit;
   End;
   Dec(ParenDepth);
  End
  Else If TokenIsSymbol('[') Then Inc(BracketDepth)
  Else If TokenIsSymbol(']') Then Begin
   If BracketDepth=0 Then Begin
    ParserFail('crochet fermant sans crochet ouvrant');
    Exit;
   End;
   Dec(BracketDepth);
  End
  Else If AllowRecord And TokenIsKeyword(KW_RECORD) Then Inc(RecordDepth)
  Else If AllowRecord And TokenIsKeyword(KW_END) And (RecordDepth>0) Then
   Dec(RecordDepth)
  Else If TokenIsSymbol(';') And (ParenDepth=0) And
          (BracketDepth=0) And (RecordDepth=0) Then Begin
   ParserAdvance;
   SkipUntilSemicolon:=True;
   Exit;
  End;
  ParserAdvance;
 End;
 ParserFail('fin de fichier avant le point-virgule');
End;

Function ParseIdentifierList:Boolean;
Var
 Name:String;
Begin
 ParseIdentifierList:=False;
 If Not ExpectIdentifier(Name) Then Exit;
 While AcceptSymbol(',') Do
  If Not ExpectIdentifier(Name) Then Exit;
 ParseIdentifierList:=True;
End;

Function FindImportedModule(Name:String):Integer;
Var
 I:Integer;
 U:String;
Begin
 FindImportedModule:=0;
 U:=UpperStr(Name);
 For I:=1 To Pipeline.ImportCount Do
  If UpperStr(Pipeline.Imports[I].Name)=U Then Begin
   FindImportedModule:=I;
   Exit;
  End;
End;

Function AddImportedModule(Name:String;FromImport:Boolean;
 LineNo,ColumnNo:Integer;Var ImportIndex:Integer):Boolean;
Var
 ModuleKind:TStandardModule;
Begin
 AddImportedModule:=False;
 ImportIndex:=0;
 If FindImportedModule(Name)<>0 Then Begin
  SemanticError('module importe plusieurs fois: '+Name,LineNo,ColumnNo);
  Exit;
 End;
 ModuleKind:=StandardModuleOf(Name);
 If ModuleKind=SM_UNKNOWN Then Begin
  SemanticError('module importe inconnu ou non supporte: '+Name,
                LineNo,ColumnNo);
  Exit;
 End;
 If Pipeline.ImportCount>=MOD2_MAX_IMPORTS Then Begin
  SemanticError('trop de modules importes',LineNo,ColumnNo);
  Exit;
 End;
 Inc(Pipeline.ImportCount);
 ImportIndex:=Pipeline.ImportCount;
 Pipeline.Imports[ImportIndex].Name:=StandardModuleName(ModuleKind);
 Pipeline.Imports[ImportIndex].StandardModule:=ModuleKind;
 Pipeline.Imports[ImportIndex].FromImport:=FromImport;
 Pipeline.Imports[ImportIndex].SelectedNames:='';
 Pipeline.Imports[ImportIndex].Line:=LineNo;
 Pipeline.Imports[ImportIndex].Column:=ColumnNo;
 AddImportedModule:=True;
End;

Function AddSelectedImportName(ImportIndex:Integer;Name:String;
 LineNo,ColumnNo:Integer):Boolean;
Var
 I:Integer;
 Existing:String;
 Item:String;
 Start:Integer;
 ModuleKind:TStandardModule;
Begin
 AddSelectedImportName:=False;
 If (ImportIndex<1) Or (ImportIndex>Pipeline.ImportCount) Then Begin
  SemanticError('index de module importe invalide',LineNo,ColumnNo);
  Exit;
 End;
 ModuleKind:=Pipeline.Imports[ImportIndex].StandardModule;
 If Not IsStandardModuleExport(ModuleKind,Name) Then Begin
  SemanticError('nom "'+Name+'" non exporte par le module '+
                Pipeline.Imports[ImportIndex].Name,LineNo,ColumnNo);
  Exit;
 End;
 Existing:=Pipeline.Imports[ImportIndex].SelectedNames;
 Start:=1;
 For I:=1 To Length(Existing)+1 Do Begin
  If I>Length(Existing) Then Begin
   Item:=Copy(Existing,Start,I-Start);
   If UpperStr(Item)=UpperStr(Name) Then Begin
    SemanticError('nom importe plusieurs fois: '+Name,LineNo,ColumnNo);
    Exit;
   End;
   Start:=I+1;
  End
  Else If Existing[I]=',' Then Begin
   Item:=Copy(Existing,Start,I-Start);
   If UpperStr(Item)=UpperStr(Name) Then Begin
    SemanticError('nom importe plusieurs fois: '+Name,LineNo,ColumnNo);
    Exit;
   End;
   Start:=I+1;
  End;
 End;
 If Existing='' Then Existing:=Name
  Else Existing:=Existing+','+Name;
 If Length(Existing)>127 Then Begin
  SemanticError('liste FROM IMPORT trop longue',LineNo,ColumnNo);
  Exit;
 End;
 Pipeline.Imports[ImportIndex].SelectedNames:=Existing;
 AddSelectedImportName:=True;
End;

Function ParseImportClause:Boolean;
Var
 ModuleName:String;
 ImportedName:String;
 ImportIndex:Integer;
 LineNo:Integer;
 ColumnNo:Integer;
Begin
 ParseImportClause:=False;
 If AcceptKeyword(KW_FROM) Then Begin
  LineNo:=CurrentToken.Line;
  ColumnNo:=CurrentToken.Column;
  If Not ExpectIdentifier(ModuleName) Then Exit;
  If Not AddImportedModule(ModuleName,True,LineNo,ColumnNo,ImportIndex) Then Exit;
  If Not ExpectKeyword(KW_IMPORT) Then Exit;
  Repeat
   LineNo:=CurrentToken.Line;
   ColumnNo:=CurrentToken.Column;
   If Not ExpectIdentifier(ImportedName) Then Exit;
   If Not AddSelectedImportName(ImportIndex,ImportedName,LineNo,ColumnNo) Then Exit;
  Until Not AcceptSymbol(',');
 End
 Else Begin
  If Not ExpectKeyword(KW_IMPORT) Then Exit;
  Repeat
   LineNo:=CurrentToken.Line;
   ColumnNo:=CurrentToken.Column;
   If Not ExpectIdentifier(ModuleName) Then Exit;
   If Not AddImportedModule(ModuleName,False,LineNo,ColumnNo,ImportIndex) Then Exit;
  Until Not AcceptSymbol(',');
 End;
 If Not ExpectSymbol(';') Then Exit;
 ParseImportClause:=True;
End;

Function ParseExportClause:Boolean;
Var
 Name:String;
Begin
 ParseExportClause:=False;
 If Not ExpectKeyword(KW_EXPORT) Then Exit;
 AcceptKeyword(KW_QUALIFIED);
 If Not ExpectIdentifier(Name) Then Exit;
 While AcceptSymbol(',') Do
  If Not ExpectIdentifier(Name) Then Exit;
 If Not ExpectSymbol(';') Then Exit;
 ParseExportClause:=True;
End;

Function ParseConstSection:Boolean;
Var
 Name:String;
Begin
 ParseConstSection:=False;
 If Not ExpectKeyword(KW_CONST) Then Exit;
 If CurrentToken.Kind<>TK_IDENTIFIER Then Begin
  ParserFail('declaration de constante attendue apres CONST');
  Exit;
 End;
 While CurrentToken.Kind=TK_IDENTIFIER Do Begin
  If Not ExpectIdentifier(Name) Then Exit;
  If Not ExpectSymbol('=') Then Exit;
  If Not SkipUntilSemicolon(False) Then Exit;
  Inc(Pipeline.ConstDeclCount);
 End;
 ParseConstSection:=True;
End;

Function ParseTypeSection:Boolean;
Var
 Name:String;
Begin
 ParseTypeSection:=False;
 If Not ExpectKeyword(KW_TYPE) Then Exit;
 If CurrentToken.Kind<>TK_IDENTIFIER Then Begin
  ParserFail('declaration de type attendue apres TYPE');
  Exit;
 End;
 While CurrentToken.Kind=TK_IDENTIFIER Do Begin
  If Not ExpectIdentifier(Name) Then Exit;
  If Not ExpectSymbol('=') Then Exit;
  If Not SkipUntilSemicolon(True) Then Exit;
  Inc(Pipeline.TypeDeclCount);
 End;
 ParseTypeSection:=True;
End;

Function ParseVarSection:Boolean;
Begin
 ParseVarSection:=False;
 If Not ExpectKeyword(KW_VAR) Then Exit;
 If CurrentToken.Kind<>TK_IDENTIFIER Then Begin
  ParserFail('declaration de variable attendue apres VAR');
  Exit;
 End;
 While CurrentToken.Kind=TK_IDENTIFIER Do Begin
  If Not ParseIdentifierList Then Exit;
  If Not ExpectSymbol(':') Then Exit;
  If Not SkipUntilSemicolon(True) Then Exit;
  Inc(Pipeline.VarDeclCount);
 End;
 ParseVarSection:=True;
End;

Function ParseStatementSequence:Boolean;
Var
 EndDepth:Integer;
 RepeatDepth:Integer;
 ParenDepth:Integer;
 BracketDepth:Integer;
 AtStatementStart:Boolean;
 Keyword:TKeyword;
Begin
 ParseStatementSequence:=False;
 EndDepth:=0;
 RepeatDepth:=0;
 ParenDepth:=0;
 BracketDepth:=0;
 AtStatementStart:=True;
 While CurrentToken.Kind<>TK_EOF Do Begin
  If TokenIsSymbol('(') Then Inc(ParenDepth)
  Else If TokenIsSymbol(')') Then Begin
   If ParenDepth=0 Then Begin
    ParserFail('parenthese fermante inattendue');
    Exit;
   End;
   Dec(ParenDepth);
  End
  Else If TokenIsSymbol('[') Then Inc(BracketDepth)
  Else If TokenIsSymbol(']') Then Begin
   If BracketDepth=0 Then Begin
    ParserFail('crochet fermant inattendu');
    Exit;
   End;
   Dec(BracketDepth);
  End;

  If (ParenDepth=0) And (BracketDepth=0) Then Begin
   If TokenIsKeyword(KW_END) Then Begin
    If EndDepth=0 Then Begin
     If RepeatDepth<>0 Then Begin
      ParserFail('UNTIL attendu avant END');
      Exit;
     End;
     ParseStatementSequence:=True;
     Exit;
    End;
    Dec(EndDepth);
    ParserAdvance;
    AtStatementStart:=False;
    Continue;
   End;
   If TokenIsKeyword(KW_UNTIL) And (RepeatDepth>0) Then Begin
    Dec(RepeatDepth);
    ParserAdvance;
    AtStatementStart:=False;
    Continue;
   End;
   If CurrentToken.Kind=TK_KEYWORD Then Begin
    Keyword:=CurrentToken.Keyword;
    If (Keyword=KW_IF) Or (Keyword=KW_WHILE) Or
       (Keyword=KW_FOR) Or (Keyword=KW_LOOP) Or
       (Keyword=KW_CASE) Or (Keyword=KW_WITH) Or
       (Keyword=KW_BEGIN) Then Inc(EndDepth)
    Else If Keyword=KW_REPEAT Then Inc(RepeatDepth);
   End;
   If AtStatementStart And Not TokenIsSymbol(';') Then Begin
    Inc(Pipeline.StatementCount);
    AtStatementStart:=False;
   End;
   If TokenIsSymbol(';') Then AtStatementStart:=True;
  End;
  ParserAdvance;
 End;
 ParserFail('END attendu avant la fin du fichier');
End;

Function ParseDeclarations:Boolean; Forward;

Function ParseProcedureDeclaration:Boolean;
Var
 ProcedureName:String;
 EndName:String;
 ParenDepth:Integer;
Begin
 ParseProcedureDeclaration:=False;
 If Not ExpectKeyword(KW_PROCEDURE) Then Exit;
 If Not ExpectIdentifier(ProcedureName) Then Exit;
 ParenDepth:=0;
 While CurrentToken.Kind<>TK_EOF Do Begin
  If TokenIsSymbol('(') Then Inc(ParenDepth)
  Else If TokenIsSymbol(')') Then Begin
   If ParenDepth=0 Then Begin
    ParserFail('parenthese fermante inattendue dans PROCEDURE');
    Exit;
   End;
   Dec(ParenDepth);
  End
  Else If TokenIsSymbol(';') And (ParenDepth=0) Then Begin
   ParserAdvance;
   Break;
  End;
  ParserAdvance;
 End;
 If CurrentToken.Kind=TK_EOF Then Begin
  ParserFail('point-virgule attendu apres l''entete de PROCEDURE');
  Exit;
 End;
 Inc(Pipeline.ProcedureCount);
 If Not ParseDeclarations Then Exit;
 If AcceptKeyword(KW_BEGIN) Then
  If Not ParseStatementSequence Then Exit;
 If Not ExpectKeyword(KW_END) Then Exit;
 If CurrentToken.Kind=TK_IDENTIFIER Then Begin
  EndName:=CurrentToken.Text;
  If EndName<>ProcedureName Then Begin
   ParserFail('nom final "'+EndName+'" different de PROCEDURE "'+
              ProcedureName+'"');
   Exit;
  End;
  ParserAdvance;
 End;
 If Not ExpectSymbol(';') Then Exit;
 ParseProcedureDeclaration:=True;
End;

Function ParseDeclarations:Boolean;
Begin
 ParseDeclarations:=False;
 While True Do Begin
  If TokenIsKeyword(KW_CONST) Then Begin
   If Not ParseConstSection Then Exit;
  End
  Else If TokenIsKeyword(KW_TYPE) Then Begin
   If Not ParseTypeSection Then Exit;
  End
  Else If TokenIsKeyword(KW_VAR) Then Begin
   If Not ParseVarSection Then Exit;
  End
  Else If TokenIsKeyword(KW_PROCEDURE) Then Begin
   If Not ParseProcedureDeclaration Then Exit;
  End
  Else Break;
 End;
 ParseDeclarations:=True;
End;

Function ParseModuleUnit:Boolean;
Var
 HeaderName:String;
 EndName:String;
Begin
 ParseModuleUnit:=False;
 Pipeline.ParserIndex:=1;
 Pipeline.ImportCount:=0;
 Pipeline.ConstDeclCount:=0;
 Pipeline.TypeDeclCount:=0;
 Pipeline.VarDeclCount:=0;
 Pipeline.ProcedureCount:=0;
 Pipeline.StatementCount:=0;
 If TokenIsKeyword(KW_DEFINITION) Or TokenIsKeyword(KW_IMPLEMENTATION) Then
  ParserAdvance;
 If Not ExpectKeyword(KW_MODULE) Then Exit;
 If Not ExpectIdentifier(HeaderName) Then Exit;
 Pipeline.ModuleName:=HeaderName;
 If Not ExpectSymbol(';') Then Exit;
 While TokenIsKeyword(KW_IMPORT) Or TokenIsKeyword(KW_FROM) Do
  If Not ParseImportClause Then Exit;
 If TokenIsKeyword(KW_EXPORT) Then
  If Not ParseExportClause Then Exit;
 If Not ParseDeclarations Then Exit;
 If Not ExpectKeyword(KW_BEGIN) Then Exit;
 If Not ParseStatementSequence Then Exit;
 If Not ExpectKeyword(KW_END) Then Exit;
 If Not ExpectIdentifier(EndName) Then Exit;
 If EndName<>HeaderName Then Begin
  ParserFail('nom final "'+EndName+'" different du MODULE "'+HeaderName+'"');
  Exit;
 End;
 If Not ExpectSymbol('.') Then Exit;
 If CurrentToken.Kind<>TK_EOF Then Begin
  ParserFail('tokens inattendus apres la fin du module');
  Exit;
 End;
 ParseModuleUnit:=True;
End;

Procedure TraceParser;
Var
 I:Integer;
 Detail:String;
Begin
 If Options.Verbose Then
  WriteLn('Parser : module ',Pipeline.ModuleName,
          ', imports ',Pipeline.ImportCount,
          ', CONST ',Pipeline.ConstDeclCount,
          ', TYPE ',Pipeline.TypeDeclCount,
          ', VAR ',Pipeline.VarDeclCount,
          ', PROCEDURE ',Pipeline.ProcedureCount,
          ', instructions ',Pipeline.StatementCount)
 Else
  WriteLn('Parser : module ',Pipeline.ModuleName);
 If Options.Verbose Then
  For I:=1 To Pipeline.ImportCount Do Begin
   If Pipeline.Imports[I].FromImport Then
    Detail:=' FROM {'+Pipeline.Imports[I].SelectedNames+'}'
   Else
    Detail:=' qualifie';
   WriteLn('Import : ',Pipeline.Imports[I].Name,Detail,
           ' @ ',Pipeline.Imports[I].Line,':',
           Pipeline.Imports[I].Column);
  End;
End;

Procedure RunParser;
Begin
 EnterStage(CS_PARSER);
 If ParseModuleUnit Then Begin
  Pipeline.Parsed:=True;
  FinishStage(CS_PARSER);
  TraceParser;
 End;
End;

Function SemanticToken:TToken;
Begin
 If Pipeline.SemanticIndex<1 Then Pipeline.SemanticIndex:=1;
 If Pipeline.SemanticIndex>Pipeline.TokenCount Then
  SemanticToken:=Pipeline.Tokens[Pipeline.TokenCount]
 Else
  SemanticToken:=Pipeline.Tokens[Pipeline.SemanticIndex];
End;

Procedure SemanticAdvance;
Begin
 If Pipeline.SemanticIndex<Pipeline.TokenCount Then
  Inc(Pipeline.SemanticIndex);
End;

Function SemanticIsKeyword(Keyword:TKeyword):Boolean;
Begin
 SemanticIsKeyword:=(SemanticToken.Kind=TK_KEYWORD) And
                    (SemanticToken.Keyword=Keyword);
End;

Function SemanticIsSymbol(SymbolText:String):Boolean;
Begin
 SemanticIsSymbol:=(SemanticToken.Kind=TK_SYMBOL) And
                   (SemanticToken.Text=SymbolText);
End;

Function SemanticAcceptKeyword(Keyword:TKeyword):Boolean;
Begin
 SemanticAcceptKeyword:=SemanticIsKeyword(Keyword);
 If SemanticAcceptKeyword Then SemanticAdvance;
End;

Function SemanticAcceptSymbol(SymbolText:String):Boolean;
Begin
 SemanticAcceptSymbol:=SemanticIsSymbol(SymbolText);
 If SemanticAcceptSymbol Then SemanticAdvance;
End;

Procedure SemanticTokenError(Msg:String);
Var
 Token:TToken;
Begin
 Token:=SemanticToken;
 SemanticError(Msg,Token.Line,Token.Column);
End;

Function FindSymbolInScope(Name:String;ScopeIndex:Integer):Integer;
Var
 I:Integer;
Begin
 FindSymbolInScope:=0;
 For I:=Pipeline.SymbolCount DownTo 1 Do
  If (Pipeline.Symbols[I].ScopeIndex=ScopeIndex) And
     (Pipeline.Symbols[I].Name=Name) Then Begin
   FindSymbolInScope:=I;
   Exit;
  End;
End;

Function FindVisibleSymbol(Name:String;ScopeIndex:Integer):Integer;
Begin
 FindVisibleSymbol:=0;
 While ScopeIndex<>0 Do Begin
  FindVisibleSymbol:=FindSymbolInScope(Name,ScopeIndex);
  If FindVisibleSymbol<>0 Then Exit;
  ScopeIndex:=Pipeline.Scopes[ScopeIndex].ParentScope;
 End;
End;

Function AddSemanticScope(Name:String;Kind:TScopeKind;ParentScope,
 OwnerSymbol:Integer;Var ScopeIndex:Integer):Boolean;
Begin
 AddSemanticScope:=False;
 ScopeIndex:=0;
 If Pipeline.ScopeCount>=MOD2_MAX_SCOPES Then Begin
  SemanticTokenError('trop de portees semantiques');
  Exit;
 End;
 Inc(Pipeline.ScopeCount);
 ScopeIndex:=Pipeline.ScopeCount;
 Pipeline.Scopes[ScopeIndex].Name:=Name;
 Pipeline.Scopes[ScopeIndex].Kind:=Kind;
 Pipeline.Scopes[ScopeIndex].ParentScope:=ParentScope;
 If ParentScope=0 Then Pipeline.Scopes[ScopeIndex].Level:=0
  Else Pipeline.Scopes[ScopeIndex].Level:=
        Pipeline.Scopes[ParentScope].Level+1;
 Pipeline.Scopes[ScopeIndex].OwnerSymbol:=OwnerSymbol;
 Pipeline.Scopes[ScopeIndex].FrameSize:=0;
 Pipeline.Scopes[ScopeIndex].BodyStart:=0;
 Pipeline.Scopes[ScopeIndex].BodyEnd:=0;
 AddSemanticScope:=True;
End;

Function AddSemanticSymbol(Name:String;Kind:TSymbolKind;ScopeIndex:Integer;
 TypeName:String;ParamIndex:Integer;ByReference:Boolean;
 LineNo,ColumnNo:Integer;Var SymbolIndex:Integer):Boolean;
Var
 Previous:Integer;
 Prefix:String;
Begin
 AddSemanticSymbol:=False;
 SymbolIndex:=0;
 Previous:=FindSymbolInScope(Name,ScopeIndex);
 If Previous<>0 Then Begin
  SemanticError('identificateur "'+Name+'" deja declare dans cette portee; '+
                'premiere declaration ligne '+
                IntToString(Pipeline.Symbols[Previous].Line),
                LineNo,ColumnNo);
  Exit;
 End;
 If Pipeline.SymbolCount>=MOD2_MAX_SYMBOLS Then Begin
  SemanticError('trop de symboles',LineNo,ColumnNo);
  Exit;
 End;
 Inc(Pipeline.SymbolCount);
 SymbolIndex:=Pipeline.SymbolCount;
 Pipeline.Symbols[SymbolIndex].Name:=Name;
 Pipeline.Symbols[SymbolIndex].Kind:=Kind;
 Pipeline.Symbols[SymbolIndex].ScopeIndex:=ScopeIndex;
 Pipeline.Symbols[SymbolIndex].ChildScope:=0;
 Pipeline.Symbols[SymbolIndex].TypeName:=TypeName;
 Pipeline.Symbols[SymbolIndex].ScalarType:=BuiltinScalarType(TypeName);
 Pipeline.Symbols[SymbolIndex].TypeSize:=
  ScalarTypeSize(Pipeline.Symbols[SymbolIndex].ScalarType);
 Pipeline.Symbols[SymbolIndex].ConstValue.ScalarType:=SCALAR_NONE;
 Pipeline.Symbols[SymbolIndex].ConstValue.IntegerValue:=0;
 Pipeline.Symbols[SymbolIndex].ConstValue.StringValue:='';
 Pipeline.Symbols[SymbolIndex].ConstValue.Valid:=False;
 Case Kind Of
  SYM_PROCEDURE:Prefix:=MOD2_INTERNAL_PREFIX;
  SYM_CONSTANT,
  SYM_VARIABLE,
  SYM_PARAMETER:Prefix:=MOD2_DATA_PREFIX;
  Else Prefix:=MOD2_INTERNAL_PREFIX;
 End;
 Pipeline.Symbols[SymbolIndex].AsmName:=
  MakeAsmLabel(Prefix,'S'+IntToString(ScopeIndex)+'_'+Name);
 Pipeline.Symbols[SymbolIndex].ParamIndex:=ParamIndex;
 Pipeline.Symbols[SymbolIndex].ByReference:=ByReference;
 Pipeline.Symbols[SymbolIndex].StorageKind:=STORAGE_NONE;
 Pipeline.Symbols[SymbolIndex].StorageOffset:=0;
 Pipeline.Symbols[SymbolIndex].StorageSize:=0;
 Pipeline.Symbols[SymbolIndex].IsExported:=False;
 Pipeline.Symbols[SymbolIndex].Line:=LineNo;
 Pipeline.Symbols[SymbolIndex].Column:=ColumnNo;
 AddSemanticSymbol:=True;
End;

Procedure SemanticSkipToSemicolon;
Var
 ParenDepth:Integer;
 BracketDepth:Integer;
 RecordDepth:Integer;
Begin
 ParenDepth:=0;
 BracketDepth:=0;
 RecordDepth:=0;
 While (SemanticToken.Kind<>TK_EOF) And (Pipeline.ErrorCount=0) Do Begin
  If SemanticIsSymbol('(') Then Inc(ParenDepth)
  Else If SemanticIsSymbol(')') And (ParenDepth>0) Then Dec(ParenDepth)
  Else If SemanticIsSymbol('[') Then Inc(BracketDepth)
  Else If SemanticIsSymbol(']') And (BracketDepth>0) Then Dec(BracketDepth)
  Else If SemanticIsKeyword(KW_RECORD) Then Inc(RecordDepth)
  Else If SemanticIsKeyword(KW_END) And (RecordDepth>0) Then Dec(RecordDepth)
  Else If SemanticIsSymbol(';') And (ParenDepth=0) And
          (BracketDepth=0) And (RecordDepth=0) Then Begin
   SemanticAdvance;
   Exit;
  End;
  SemanticAdvance;
 End;
 If Pipeline.ErrorCount=0 Then
  SemanticTokenError('fin de fichier dans une declaration');
End;

Function ResolveTypeName(TypeName:String;ScopeIndex,Depth:Integer):TScalarType;
 Forward;

Function ArgumentScalarType(CurrentScope:Integer;Var IsVariable:Boolean;
 Var ArgLine,ArgColumn:Integer):TScalarType;
Var
 Token:TToken;
 SymbolIndex:Integer;
 Depth:Integer;
 SawToken:Boolean;
Begin
 ArgumentScalarType:=SCALAR_NONE;
 IsVariable:=False;
 ArgLine:=SemanticToken.Line;
 ArgColumn:=SemanticToken.Column;
 Depth:=0;
 SawToken:=False;
 If SemanticIsSymbol('-') Or SemanticIsSymbol('+') Then SemanticAdvance;
 While (SemanticToken.Kind<>TK_EOF) And
       Not ((Depth=0) And
            (SemanticIsSymbol(',') Or SemanticIsSymbol(')'))) Do Begin
  Token:=SemanticToken;
  If Not SawToken Then Begin
   SawToken:=True;
   ArgLine:=Token.Line;
   ArgColumn:=Token.Column;
   If Token.Kind=TK_INTEGER Then ArgumentScalarType:=SCALAR_INTEGER
   Else If Token.Kind=TK_STRING Then Begin
    If Length(Token.Text)=1 Then ArgumentScalarType:=SCALAR_CHAR
     Else ArgumentScalarType:=SCALAR_STRING;
   End
   Else If (Token.Kind=TK_IDENTIFIER) And
           ((Token.Text='TRUE') Or (Token.Text='FALSE')) Then
    ArgumentScalarType:=SCALAR_BOOLEAN
   Else If Token.Kind=TK_IDENTIFIER Then Begin
    SymbolIndex:=FindVisibleSymbol(Token.Text,CurrentScope);
    If SymbolIndex<>0 Then Begin
     ArgumentScalarType:=Pipeline.Symbols[SymbolIndex].ScalarType;
     If ArgumentScalarType=SCALAR_NONE Then
      ArgumentScalarType:=
       ResolveTypeName(Pipeline.Symbols[SymbolIndex].TypeName,
                       Pipeline.Symbols[SymbolIndex].ScopeIndex,0);
     IsVariable:=(Pipeline.Symbols[SymbolIndex].Kind=SYM_VARIABLE) Or
                 (Pipeline.Symbols[SymbolIndex].Kind=SYM_PARAMETER);
    End;
   End;
  End;
  If SemanticIsSymbol('(') Or SemanticIsSymbol('[') Then Inc(Depth)
  Else If (SemanticIsSymbol(')') Or SemanticIsSymbol(']')) And
          (Depth>0) Then Dec(Depth);
  SemanticAdvance;
 End;
End;

Procedure InOutTypeError(ProcedureName:String;ArgumentIndex:Integer;
 ExpectedType,ActualType:TScalarType;LineNo,ColumnNo:Integer);
Begin
 SemanticError('InOut.'+ProcedureName+': argument '+
               IntToString(ArgumentIndex)+' doit etre '+
               ScalarTypeName(ExpectedType)+', obtenu '+
               ScalarTypeName(ActualType),LineNo,ColumnNo);
End;

Function ValidateInOutCall(CurrentScope:Integer):Boolean;
Const
 MAX_INOUT_ARGS = 4;
Var
 StartIndex:Integer;
 ImportSymbol:Integer;
 ProcedureName:String;
 ProcedureKey:String;
 ArgTypes:Array[1..MAX_INOUT_ARGS] Of TScalarType;
 ArgVariables:Array[1..MAX_INOUT_ARGS] Of Boolean;
 ArgLines:Array[1..MAX_INOUT_ARGS] Of Integer;
 ArgColumns:Array[1..MAX_INOUT_ARGS] Of Integer;
 ArgCount:Integer;
 ExpectedCount:Integer;
 ExpectedFirst:TScalarType;
 FirstMustBeVariable:Boolean;
 I:Integer;
Begin
 ValidateInOutCall:=False;
 If SemanticToken.Kind<>TK_IDENTIFIER Then Exit;
 StartIndex:=Pipeline.SemanticIndex;
 ImportSymbol:=FindVisibleSymbol(SemanticToken.Text,CurrentScope);
 If (ImportSymbol<>0) And
    (Pipeline.Symbols[ImportSymbol].Kind=SYM_IMPORT_MODULE) And
    (StandardModuleOf(Pipeline.Symbols[ImportSymbol].TypeName)=SM_INOUT) Then Begin
  SemanticAdvance;
  If Not SemanticAcceptSymbol('.') Or
     (SemanticToken.Kind<>TK_IDENTIFIER) Then Begin
   Pipeline.SemanticIndex:=StartIndex;
   Exit;
  End;
  ProcedureName:=SemanticToken.Text;
  SemanticAdvance;
 End
 Else If (ImportSymbol<>0) And
         (Pipeline.Symbols[ImportSymbol].Kind=SYM_IMPORT_NAME) And
         (StandardModuleOf(Pipeline.Symbols[ImportSymbol].TypeName)=SM_INOUT) Then Begin
  ProcedureName:=SemanticToken.Text;
  SemanticAdvance;
 End
 Else Exit;
 ValidateInOutCall:=True;
 ProcedureKey:=UpperStr(ProcedureName);
 ArgCount:=0;
 If SemanticAcceptSymbol('(') Then Begin
  If Not SemanticIsSymbol(')') Then
   Repeat
    If ArgCount>=MAX_INOUT_ARGS Then Begin
     SemanticTokenError('trop d''arguments pour InOut.'+ProcedureName);
     Exit;
    End;
    Inc(ArgCount);
    ArgTypes[ArgCount]:=ArgumentScalarType(CurrentScope,
      ArgVariables[ArgCount],ArgLines[ArgCount],ArgColumns[ArgCount]);
   Until Not SemanticAcceptSymbol(',');
  If Not SemanticAcceptSymbol(')') Then Begin
   SemanticTokenError('symbole ")" attendu dans InOut.'+ProcedureName);
   Exit;
  End;
 End;
 ExpectedCount:=-1;
 ExpectedFirst:=SCALAR_NONE;
 FirstMustBeVariable:=False;
 If ProcedureKey='WRITELN' Then ExpectedCount:=0
 Else If ProcedureKey='WRITESTRING' Then Begin
  ExpectedCount:=1;
  ExpectedFirst:=SCALAR_STRING;
 End
 Else If ProcedureKey='WRITEINT' Then Begin
  ExpectedCount:=2;
  ExpectedFirst:=SCALAR_INTEGER;
 End
 Else If ProcedureKey='WRITECARD' Then Begin
  ExpectedCount:=2;
  ExpectedFirst:=SCALAR_CARDINAL;
 End
 Else If ProcedureKey='WRITECHAR' Then Begin
  ExpectedCount:=1;
  ExpectedFirst:=SCALAR_CHAR;
 End
 Else If ProcedureKey='READINT' Then Begin
  ExpectedCount:=1;
  ExpectedFirst:=SCALAR_INTEGER;
  FirstMustBeVariable:=True;
 End
 Else If ProcedureKey='READCARD' Then Begin
  ExpectedCount:=1;
  ExpectedFirst:=SCALAR_CARDINAL;
  FirstMustBeVariable:=True;
 End
 Else If ProcedureKey='READCHAR' Then Begin
  ExpectedCount:=1;
  ExpectedFirst:=SCALAR_CHAR;
  FirstMustBeVariable:=True;
 End
 Else If ProcedureKey='READSTRING' Then Begin
  ExpectedCount:=1;
  ExpectedFirst:=SCALAR_STRING;
  FirstMustBeVariable:=True;
 End;
 If ExpectedCount<0 Then Begin
  SemanticError('procedure InOut inconnue: '+ProcedureName,
                SemanticToken.Line,SemanticToken.Column);
  Exit;
 End;
 If ArgCount<>ExpectedCount Then Begin
  SemanticError('InOut.'+ProcedureName+' attend '+
                IntToString(ExpectedCount)+' argument(s), obtenu '+
                IntToString(ArgCount),
                SemanticToken.Line,SemanticToken.Column);
  Exit;
 End;
 If ExpectedCount>0 Then Begin
  If Not ScalarTypesCompatible(ExpectedFirst,ArgTypes[1]) Then Begin
   InOutTypeError(ProcedureName,1,ExpectedFirst,ArgTypes[1],
                  ArgLines[1],ArgColumns[1]);
   Exit;
  End;
  If FirstMustBeVariable And Not ArgVariables[1] Then Begin
   SemanticError('InOut.'+ProcedureName+
                 ': le premier argument doit etre une variable',
                 ArgLines[1],ArgColumns[1]);
   Exit;
  End;
 End;
 For I:=2 To ArgCount Do
  If Not IsNumericScalar(ArgTypes[I]) Then Begin
   InOutTypeError(ProcedureName,I,SCALAR_INTEGER,ArgTypes[I],
                  ArgLines[I],ArgColumns[I]);
   Exit;
  End;
End;

Procedure SemanticSkipStatementSequence(CurrentScope:Integer);
Var
 EndDepth:Integer;
 RepeatDepth:Integer;
 ParenDepth:Integer;
 BracketDepth:Integer;
 Keyword:TKeyword;
Begin
 EndDepth:=0;
 RepeatDepth:=0;
 ParenDepth:=0;
 BracketDepth:=0;
 While (SemanticToken.Kind<>TK_EOF) And (Pipeline.ErrorCount=0) Do Begin
  If ValidateInOutCall(CurrentScope) Then Continue;
  If SemanticIsSymbol('(') Then Inc(ParenDepth)
  Else If SemanticIsSymbol(')') And (ParenDepth>0) Then Dec(ParenDepth)
  Else If SemanticIsSymbol('[') Then Inc(BracketDepth)
  Else If SemanticIsSymbol(']') And (BracketDepth>0) Then Dec(BracketDepth);
  If (ParenDepth=0) And (BracketDepth=0) Then Begin
   If SemanticIsKeyword(KW_END) Then Begin
    If EndDepth=0 Then Exit;
    Dec(EndDepth);
    SemanticAdvance;
    Continue;
   End;
   If SemanticIsKeyword(KW_UNTIL) And (RepeatDepth>0) Then Begin
    Dec(RepeatDepth);
    SemanticAdvance;
    Continue;
   End;
   If SemanticToken.Kind=TK_KEYWORD Then Begin
    Keyword:=SemanticToken.Keyword;
    If (Keyword=KW_IF) Or (Keyword=KW_WHILE) Or
       (Keyword=KW_FOR) Or (Keyword=KW_LOOP) Or
       (Keyword=KW_CASE) Or (Keyword=KW_WITH) Or
       (Keyword=KW_BEGIN) Then Inc(EndDepth)
    Else If Keyword=KW_REPEAT Then Inc(RepeatDepth);
   End;
  End;
  SemanticAdvance;
 End;
 If Pipeline.ErrorCount=0 Then
  SemanticTokenError('END attendu dans le corps de procedure');
End;

Procedure BuildDeclarations(CurrentScope:Integer); Forward;

Function EvaluateConstExpression(CurrentScope:Integer;
 Var Value:TConstValue):Boolean; Forward;

Procedure InitConstValue(Var Value:TConstValue);
Begin
 Value.ScalarType:=SCALAR_NONE;
 Value.IntegerValue:=0;
 Value.StringValue:='';
 Value.Valid:=False;
End;

Function ConstTypeError(Operation:String;Expected:String;
 Actual:TScalarType;LineNo,ColumnNo:Integer):Boolean;
Begin
 SemanticError('CONST: '+Operation+' exige '+Expected+', obtenu '+
               ScalarTypeName(Actual),LineNo,ColumnNo);
 ConstTypeError:=False;
End;

Function CheckedConstInteger(Number:Extended;LineNo,ColumnNo:Integer;
 Var Value:TConstValue):Boolean;
Begin
 CheckedConstInteger:=False;
 If (Number<-2147483648.0) Or (Number>2147483647.0) Then Begin
  SemanticError('CONST: resultat entier hors limite 32 bits',
                LineNo,ColumnNo);
  Exit;
 End;
 InitConstValue(Value);
 Value.ScalarType:=SCALAR_INTEGER;
 Value.IntegerValue:=Trunc(Number);
 Value.Valid:=True;
 CheckedConstInteger:=True;
End;

Function EvaluateConstBuiltin(CurrentScope:Integer;NameToken:TToken;
 Var Value:TConstValue):Boolean;
Var
 Operand:TConstValue;
Begin
 EvaluateConstBuiltin:=False;
 InitConstValue(Value);
 SemanticAdvance;
 If Not SemanticAcceptSymbol('(') Then Begin
  SemanticTokenError('CONST: symbole "(" attendu apres '+NameToken.Text);
  Exit;
 End;
 If Not EvaluateConstExpression(CurrentScope,Operand) Then Exit;
 If SemanticAcceptSymbol(',') Then Begin
  SemanticError('CONST: '+NameToken.Text+' attend un seul argument',
                NameToken.Line,NameToken.Column);
  Exit;
 End;
 If Not SemanticAcceptSymbol(')') Then Begin
  SemanticTokenError('CONST: symbole ")" attendu apres '+NameToken.Text);
  Exit;
 End;
 If NameToken.Text='ORD' Then Begin
  If (Operand.ScalarType<>SCALAR_CHAR) And
     (Operand.ScalarType<>SCALAR_BOOLEAN) And
     Not IsNumericScalar(Operand.ScalarType) Then Begin
   ConstTypeError('ORD','une valeur ordinale',Operand.ScalarType,
                  NameToken.Line,NameToken.Column);
   Exit;
  End;
  Value.ScalarType:=SCALAR_CARDINAL;
  Value.IntegerValue:=Operand.IntegerValue;
 End
 Else If NameToken.Text='CHR' Then Begin
  If Not IsNumericScalar(Operand.ScalarType) Then Begin
   ConstTypeError('CHR','un entier',Operand.ScalarType,
                  NameToken.Line,NameToken.Column);
   Exit;
  End;
  Value.ScalarType:=SCALAR_CHAR;
  Value.IntegerValue:=Operand.IntegerValue And 255;
  Value.StringValue:=Chr(Value.IntegerValue);
 End
 Else If NameToken.Text='ODD' Then Begin
  If Not IsNumericScalar(Operand.ScalarType) Then Begin
   ConstTypeError('ODD','un entier',Operand.ScalarType,
                  NameToken.Line,NameToken.Column);
   Exit;
  End;
  Value.ScalarType:=SCALAR_BOOLEAN;
  Value.IntegerValue:=Operand.IntegerValue And 1;
 End
 Else Begin
  If Not IsNumericScalar(Operand.ScalarType) Then Begin
   ConstTypeError('ABS','un entier',Operand.ScalarType,
                  NameToken.Line,NameToken.Column);
   Exit;
  End;
  If Operand.IntegerValue=(-2147483647-1) Then Begin
   SemanticError('CONST: ABS produit un entier hors limite 32 bits',
                 NameToken.Line,NameToken.Column);
   Exit;
  End;
  Value.ScalarType:=Operand.ScalarType;
  If Operand.IntegerValue<0 Then
   Value.IntegerValue:=-Operand.IntegerValue
  Else Value.IntegerValue:=Operand.IntegerValue;
 End;
 Value.Valid:=True;
 EvaluateConstBuiltin:=True;
End;

Function EvaluateConstPrimary(CurrentScope:Integer;
 Var Value:TConstValue):Boolean;
Var
 Token:TToken;
 SymbolIndex:Integer;
Begin
 EvaluateConstPrimary:=False;
 InitConstValue(Value);
 Token:=SemanticToken;
 If Token.Kind=TK_INTEGER Then Begin
  Value.ScalarType:=SCALAR_INTEGER;
  Value.IntegerValue:=Token.IntegerVal;
  Value.Valid:=True;
  SemanticAdvance;
  EvaluateConstPrimary:=True;
  Exit;
 End;
 If Token.Kind=TK_STRING Then Begin
  Value.StringValue:=Token.Text;
  If Length(Token.Text)=1 Then Begin
   Value.ScalarType:=SCALAR_CHAR;
   Value.IntegerValue:=Ord(Token.Text[1]);
  End
  Else Value.ScalarType:=SCALAR_STRING;
  Value.Valid:=True;
  SemanticAdvance;
  EvaluateConstPrimary:=True;
 Exit;
 End;
 If Token.Kind=TK_IDENTIFIER Then Begin
  If ((Token.Text='ORD') Or (Token.Text='CHR') Or
      (Token.Text='ODD') Or (Token.Text='ABS')) And
     (Pipeline.SemanticIndex<Pipeline.TokenCount) And
     (Pipeline.Tokens[Pipeline.SemanticIndex+1].Kind=TK_SYMBOL) And
     (Pipeline.Tokens[Pipeline.SemanticIndex+1].Text='(') Then Begin
   EvaluateConstPrimary:=EvaluateConstBuiltin(CurrentScope,Token,Value);
   Exit;
  End
  Else If Token.Text='TRUE' Then Begin
   Value.ScalarType:=SCALAR_BOOLEAN;
   Value.IntegerValue:=1;
   Value.Valid:=True;
  End
  Else If Token.Text='FALSE' Then Begin
   Value.ScalarType:=SCALAR_BOOLEAN;
   Value.IntegerValue:=0;
   Value.Valid:=True;
  End
  Else Begin
   SymbolIndex:=FindVisibleSymbol(Token.Text,CurrentScope);
   If SymbolIndex=0 Then Begin
    SemanticError('CONST: identificateur inconnu "'+Token.Text+'"',
                  Token.Line,Token.Column);
    Exit;
   End;
   If (Pipeline.Symbols[SymbolIndex].Kind<>SYM_CONSTANT) Or
      Not Pipeline.Symbols[SymbolIndex].ConstValue.Valid Then Begin
    SemanticError('CONST: "'+Token.Text+
                  '" ne designe pas une constante deja evaluee',
                  Token.Line,Token.Column);
    Exit;
   End;
   Value:=Pipeline.Symbols[SymbolIndex].ConstValue;
  End;
  SemanticAdvance;
  EvaluateConstPrimary:=True;
  Exit;
 End;
 If SemanticAcceptSymbol('(') Then Begin
  If Not EvaluateConstExpression(CurrentScope,Value) Then Exit;
  If Not SemanticAcceptSymbol(')') Then Begin
   SemanticTokenError('CONST: symbole ")" attendu');
   Exit;
  End;
  EvaluateConstPrimary:=True;
  Exit;
 End;
 SemanticError('CONST: valeur constante attendue',Token.Line,Token.Column);
End;

Function EvaluateConstUnary(CurrentScope:Integer;
 Var Value:TConstValue):Boolean;
Var
 Token:TToken;
 Operand:TConstValue;
Begin
 EvaluateConstUnary:=False;
 Token:=SemanticToken;
 If SemanticAcceptSymbol('+') Then Begin
  If Not EvaluateConstUnary(CurrentScope,Value) Then Exit;
  If Not IsNumericScalar(Value.ScalarType) Then Begin
   ConstTypeError('operateur unaire +','un entier',
                  Value.ScalarType,Token.Line,Token.Column);
   Exit;
  End;
  EvaluateConstUnary:=True;
  Exit;
 End;
 If SemanticAcceptSymbol('-') Then Begin
  If Not EvaluateConstUnary(CurrentScope,Operand) Then Exit;
  If Not IsNumericScalar(Operand.ScalarType) Then Begin
   ConstTypeError('operateur unaire -','un entier',
                  Operand.ScalarType,Token.Line,Token.Column);
   Exit;
  End;
  If Not CheckedConstInteger(-Extended(Operand.IntegerValue),
                             Token.Line,Token.Column,Value) Then Exit;
  EvaluateConstUnary:=True;
  Exit;
 End;
 If SemanticAcceptKeyword(KW_NOT) Then Begin
  If Not EvaluateConstUnary(CurrentScope,Operand) Then Exit;
  If Operand.ScalarType<>SCALAR_BOOLEAN Then Begin
   ConstTypeError('NOT','BOOLEAN',Operand.ScalarType,
                  Token.Line,Token.Column);
   Exit;
  End;
  InitConstValue(Value);
  Value.ScalarType:=SCALAR_BOOLEAN;
  If Operand.IntegerValue=0 Then Value.IntegerValue:=1
   Else Value.IntegerValue:=0;
  Value.Valid:=True;
  EvaluateConstUnary:=True;
  Exit;
 End;
 EvaluateConstUnary:=EvaluateConstPrimary(CurrentScope,Value);
End;

Function EvaluateConstProduct(CurrentScope:Integer;
 Var Value:TConstValue):Boolean;
Var
 RightValue:TConstValue;
 ResultValue:TConstValue;
 OperatorToken:TToken;
 OperatorKind:TKeyword;
 OperatorText:String;
 Number:Extended;
Begin
 EvaluateConstProduct:=False;
 If Not EvaluateConstUnary(CurrentScope,Value) Then Exit;
 While SemanticIsSymbol('*') Or SemanticIsSymbol('/') Or
       SemanticIsKeyword(KW_DIV) Or SemanticIsKeyword(KW_MOD) Do Begin
  OperatorToken:=SemanticToken;
  OperatorKind:=OperatorToken.Keyword;
  OperatorText:=OperatorToken.Text;
  SemanticAdvance;
  If OperatorText='/' Then Begin
   SemanticError('CONST: division reelle "/" non supportee; utiliser DIV',
                 OperatorToken.Line,OperatorToken.Column);
   Exit;
  End;
  If Not EvaluateConstUnary(CurrentScope,RightValue) Then Exit;
  If Not IsNumericScalar(Value.ScalarType) Then Begin
   ConstTypeError(OperatorText,'un entier',Value.ScalarType,
                  OperatorToken.Line,OperatorToken.Column);
   Exit;
  End;
  If Not IsNumericScalar(RightValue.ScalarType) Then Begin
   ConstTypeError(OperatorText,'un entier',RightValue.ScalarType,
                  OperatorToken.Line,OperatorToken.Column);
   Exit;
  End;
  If OperatorText='*' Then Begin
   Number:=Extended(Value.IntegerValue)*Extended(RightValue.IntegerValue);
   If Not CheckedConstInteger(Number,OperatorToken.Line,
                              OperatorToken.Column,ResultValue) Then Exit;
  End
  Else Begin
   If RightValue.IntegerValue=0 Then Begin
    SemanticError('CONST: division par zero',
                  OperatorToken.Line,OperatorToken.Column);
    Exit;
   End;
   If (Value.IntegerValue=-2147483647-1) And
      (RightValue.IntegerValue=-1) And (OperatorKind=KW_DIV) Then Begin
    SemanticError('CONST: resultat entier hors limite 32 bits',
                  OperatorToken.Line,OperatorToken.Column);
    Exit;
   End;
   InitConstValue(ResultValue);
   ResultValue.ScalarType:=SCALAR_INTEGER;
   If OperatorKind=KW_DIV Then
    ResultValue.IntegerValue:=Value.IntegerValue Div RightValue.IntegerValue
   Else
    ResultValue.IntegerValue:=Value.IntegerValue Mod RightValue.IntegerValue;
   ResultValue.Valid:=True;
  End;
  Value:=ResultValue;
 End;
 EvaluateConstProduct:=True;
End;

Function EvaluateConstSum(CurrentScope:Integer;
 Var Value:TConstValue):Boolean;
Var
 RightValue:TConstValue;
 ResultValue:TConstValue;
 OperatorToken:TToken;
 Number:Extended;
Begin
 EvaluateConstSum:=False;
 If Not EvaluateConstProduct(CurrentScope,Value) Then Exit;
 While SemanticIsSymbol('+') Or SemanticIsSymbol('-') Do Begin
  OperatorToken:=SemanticToken;
  SemanticAdvance;
  If Not EvaluateConstProduct(CurrentScope,RightValue) Then Exit;
  If Not IsNumericScalar(Value.ScalarType) Then Begin
   ConstTypeError(OperatorToken.Text,'un entier',Value.ScalarType,
                  OperatorToken.Line,OperatorToken.Column);
   Exit;
  End;
  If Not IsNumericScalar(RightValue.ScalarType) Then Begin
   ConstTypeError(OperatorToken.Text,'un entier',RightValue.ScalarType,
                  OperatorToken.Line,OperatorToken.Column);
   Exit;
  End;
  If OperatorToken.Text='+' Then
   Number:=Extended(Value.IntegerValue)+Extended(RightValue.IntegerValue)
  Else
   Number:=Extended(Value.IntegerValue)-Extended(RightValue.IntegerValue);
  If Not CheckedConstInteger(Number,OperatorToken.Line,
                             OperatorToken.Column,ResultValue) Then Exit;
  Value:=ResultValue;
 End;
 EvaluateConstSum:=True;
End;

Function EvaluateConstAnd(CurrentScope:Integer;
 Var Value:TConstValue):Boolean;
Forward;

Function EvaluateConstComparison(CurrentScope:Integer;
 Var Value:TConstValue):Boolean;
Var
 RightValue:TConstValue;
 OperatorToken:TToken;
 Compatible:Boolean;
 Result:Boolean;
 Ordering:Boolean;
Begin
 EvaluateConstComparison:=False;
 If Not EvaluateConstSum(CurrentScope,Value) Then Exit;
 If SemanticIsSymbol('=') Or SemanticIsSymbol('#') Or
    SemanticIsSymbol('<>') Or SemanticIsSymbol('<') Or
    SemanticIsSymbol('<=') Or SemanticIsSymbol('>') Or
    SemanticIsSymbol('>=') Then Begin
  OperatorToken:=SemanticToken;
  Ordering:=(OperatorToken.Text<>'=') And
            (OperatorToken.Text<>'#') And
            (OperatorToken.Text<>'<>');
  SemanticAdvance;
  If Not EvaluateConstSum(CurrentScope,RightValue) Then Exit;
  If Ordering Then
   Compatible:=
    (IsNumericScalar(Value.ScalarType) And
     IsNumericScalar(RightValue.ScalarType)) Or
    ((Value.ScalarType=SCALAR_CHAR) And
     (RightValue.ScalarType=SCALAR_CHAR))
  Else
   Compatible:=ScalarTypesCompatible(Value.ScalarType,
                                      RightValue.ScalarType) Or
    ((Value.ScalarType=SCALAR_BOOLEAN) And
     (RightValue.ScalarType=SCALAR_BOOLEAN)) Or
    ((Value.ScalarType=SCALAR_CHAR) And
     (RightValue.ScalarType=SCALAR_CHAR)) Or
    ((Value.ScalarType=SCALAR_STRING) And
     (RightValue.ScalarType=SCALAR_STRING));
  If Not Compatible Then Begin
   SemanticError('CONST: types incompatibles pour '+
                 OperatorToken.Text,OperatorToken.Line,
                 OperatorToken.Column);
   Exit;
  End;
  If (Value.ScalarType=SCALAR_STRING) Or
     (RightValue.ScalarType=SCALAR_STRING) Then Begin
   If OperatorToken.Text='=' Then
    Result:=Value.StringValue=RightValue.StringValue
   Else Result:=Value.StringValue<>RightValue.StringValue;
  End
  Else If OperatorToken.Text='=' Then
   Result:=Value.IntegerValue=RightValue.IntegerValue
  Else If (OperatorToken.Text='#') Or
          (OperatorToken.Text='<>') Then
   Result:=Value.IntegerValue<>RightValue.IntegerValue
  Else If OperatorToken.Text='<' Then
   Result:=Value.IntegerValue<RightValue.IntegerValue
  Else If OperatorToken.Text='<=' Then
   Result:=Value.IntegerValue<=RightValue.IntegerValue
  Else If OperatorToken.Text='>' Then
   Result:=Value.IntegerValue>RightValue.IntegerValue
  Else Result:=Value.IntegerValue>=RightValue.IntegerValue;
  InitConstValue(Value);
  Value.ScalarType:=SCALAR_BOOLEAN;
  If Result Then Value.IntegerValue:=1 Else Value.IntegerValue:=0;
  Value.Valid:=True;
 End;
 EvaluateConstComparison:=True;
End;

Function EvaluateConstAnd(CurrentScope:Integer;
 Var Value:TConstValue):Boolean;
Var
 RightValue:TConstValue;
 OperatorToken:TToken;
Begin
 EvaluateConstAnd:=False;
 If Not EvaluateConstComparison(CurrentScope,Value) Then Exit;
 While SemanticIsKeyword(KW_AND) Do Begin
  OperatorToken:=SemanticToken;
  SemanticAdvance;
  If Not EvaluateConstComparison(CurrentScope,RightValue) Then Exit;
  If Value.ScalarType<>SCALAR_BOOLEAN Then Begin
   ConstTypeError('AND','BOOLEAN',Value.ScalarType,
                  OperatorToken.Line,OperatorToken.Column);
   Exit;
  End;
  If RightValue.ScalarType<>SCALAR_BOOLEAN Then Begin
   ConstTypeError('AND','BOOLEAN',RightValue.ScalarType,
                  OperatorToken.Line,OperatorToken.Column);
   Exit;
  End;
  If (Value.IntegerValue<>0) And (RightValue.IntegerValue<>0) Then
   Value.IntegerValue:=1
  Else Value.IntegerValue:=0;
  Value.Valid:=True;
 End;
 EvaluateConstAnd:=True;
End;

Function EvaluateConstExpression(CurrentScope:Integer;
 Var Value:TConstValue):Boolean;
Var
 RightValue:TConstValue;
 OperatorToken:TToken;
Begin
 EvaluateConstExpression:=False;
 If Not EvaluateConstAnd(CurrentScope,Value) Then Exit;
 While SemanticIsKeyword(KW_OR) Do Begin
  OperatorToken:=SemanticToken;
  SemanticAdvance;
  If Not EvaluateConstAnd(CurrentScope,RightValue) Then Exit;
  If Value.ScalarType<>SCALAR_BOOLEAN Then Begin
   ConstTypeError('OR','BOOLEAN',Value.ScalarType,
                  OperatorToken.Line,OperatorToken.Column);
   Exit;
  End;
  If RightValue.ScalarType<>SCALAR_BOOLEAN Then Begin
   ConstTypeError('OR','BOOLEAN',RightValue.ScalarType,
                  OperatorToken.Line,OperatorToken.Column);
   Exit;
  End;
  If (Value.IntegerValue<>0) Or (RightValue.IntegerValue<>0) Then
   Value.IntegerValue:=1
  Else Value.IntegerValue:=0;
  Value.Valid:=True;
 End;
 EvaluateConstExpression:=True;
End;

Procedure BuildConstSymbols(CurrentScope:Integer);
Var
 Token:TToken;
 SymbolIndex:Integer;
 Value:TConstValue;
Begin
 SemanticAdvance;
 While (SemanticToken.Kind=TK_IDENTIFIER) And
       (Pipeline.ErrorCount=0) Do Begin
  Token:=SemanticToken;
  SemanticAdvance;
  If Not SemanticAcceptSymbol('=') Then Begin
   SemanticTokenError('symbole "=" attendu dans CONST');
   Exit;
  End;
  If Not EvaluateConstExpression(CurrentScope,Value) Then Exit;
  If Not SemanticAcceptSymbol(';') Then Begin
   SemanticTokenError('CONST: operateur ou point-virgule attendu');
   Exit;
  End;
  If Not AddSemanticSymbol(Token.Text,SYM_CONSTANT,CurrentScope,
                           ScalarTypeName(Value.ScalarType),0,
                           False,Token.Line,Token.Column,SymbolIndex) Then Exit;
  Pipeline.Symbols[SymbolIndex].ScalarType:=Value.ScalarType;
  Pipeline.Symbols[SymbolIndex].TypeSize:=ScalarTypeSize(Value.ScalarType);
  Pipeline.Symbols[SymbolIndex].ConstValue:=Value;
  If Value.ScalarType=SCALAR_STRING Then
   Pipeline.Symbols[SymbolIndex].TypeSize:=Length(Value.StringValue)+1;
 End;
End;

Procedure BuildTypeSymbols(CurrentScope:Integer);
Var
 Token:TToken;
 TypeToken:TToken;
 SymbolIndex:Integer;
Begin
 SemanticAdvance;
 While (SemanticToken.Kind=TK_IDENTIFIER) And
       (Pipeline.ErrorCount=0) Do Begin
  Token:=SemanticToken;
  SemanticAdvance;
  If Not SemanticAcceptSymbol('=') Then Begin
   SemanticTokenError('symbole "=" attendu dans TYPE');
   Exit;
  End;
  TypeToken:=SemanticToken;
  If Not AddSemanticSymbol(Token.Text,SYM_TYPE,CurrentScope,TypeToken.Text,0,
                           False,Token.Line,Token.Column,SymbolIndex) Then Exit;
  SemanticSkipToSemicolon;
 End;
End;

Procedure BuildVarSymbols(CurrentScope:Integer);
Const
 MAX_NAMES_PER_DECL = 256;
Var
 Names:Array[1..MAX_NAMES_PER_DECL] Of String[63];
 Lines:Array[1..MAX_NAMES_PER_DECL] Of Integer;
 Columns:Array[1..MAX_NAMES_PER_DECL] Of Integer;
 NameCount:Integer;
 I:Integer;
 SymbolIndex:Integer;
 TypeName:String;
Begin
 SemanticAdvance;
 While (SemanticToken.Kind=TK_IDENTIFIER) And
       (Pipeline.ErrorCount=0) Do Begin
  NameCount:=0;
  Repeat
   If NameCount>=MAX_NAMES_PER_DECL Then Begin
    SemanticTokenError('trop de noms dans une declaration VAR');
    Exit;
   End;
   Inc(NameCount);
   Names[NameCount]:=SemanticToken.Text;
   Lines[NameCount]:=SemanticToken.Line;
   Columns[NameCount]:=SemanticToken.Column;
   SemanticAdvance;
  Until Not SemanticAcceptSymbol(',');
  If Not SemanticAcceptSymbol(':') Then Begin
   SemanticTokenError('symbole ":" attendu dans VAR');
   Exit;
  End;
  If SemanticToken.Kind=TK_EOF Then Begin
   SemanticTokenError('type attendu dans VAR');
   Exit;
  End;
  TypeName:=SemanticToken.Text;
  For I:=1 To NameCount Do
   If Not AddSemanticSymbol(Names[I],SYM_VARIABLE,CurrentScope,TypeName,0,
                            False,Lines[I],Columns[I],SymbolIndex) Then Exit;
  SemanticSkipToSemicolon;
 End;
End;

Procedure BuildFormalParameters(ProcedureScope:Integer);
Const
 MAX_PARAM_NAMES = 256;
Var
 Names:Array[1..MAX_PARAM_NAMES] Of String[63];
 Lines:Array[1..MAX_PARAM_NAMES] Of Integer;
 Columns:Array[1..MAX_PARAM_NAMES] Of Integer;
 NameCount:Integer;
 ParamIndex:Integer;
 I:Integer;
 SymbolIndex:Integer;
 TypeName:String;
 ByReference:Boolean;
 Depth:Integer;
Begin
 If Not SemanticAcceptSymbol('(') Then Exit;
 ParamIndex:=0;
 While Not SemanticIsSymbol(')') And
       (SemanticToken.Kind<>TK_EOF) And (Pipeline.ErrorCount=0) Do Begin
  ByReference:=SemanticAcceptKeyword(KW_VAR);
  NameCount:=0;
  If SemanticToken.Kind<>TK_IDENTIFIER Then Begin
   SemanticTokenError('nom de parametre attendu');
   Exit;
  End;
  Repeat
   If NameCount>=MAX_PARAM_NAMES Then Begin
    SemanticTokenError('trop de parametres dans un groupe');
    Exit;
   End;
   Inc(NameCount);
   Names[NameCount]:=SemanticToken.Text;
   Lines[NameCount]:=SemanticToken.Line;
   Columns[NameCount]:=SemanticToken.Column;
   SemanticAdvance;
  Until Not SemanticAcceptSymbol(',');
  If Not SemanticAcceptSymbol(':') Then Begin
   SemanticTokenError('symbole ":" attendu dans les parametres');
   Exit;
  End;
  TypeName:=SemanticToken.Text;
  For I:=1 To NameCount Do Begin
   Inc(ParamIndex);
   If Not AddSemanticSymbol(Names[I],SYM_PARAMETER,ProcedureScope,TypeName,
                            ParamIndex,ByReference,Lines[I],Columns[I],
                            SymbolIndex) Then Exit;
  End;
  Depth:=0;
  While (SemanticToken.Kind<>TK_EOF) And
        Not ((Depth=0) And
             (SemanticIsSymbol(';') Or SemanticIsSymbol(')'))) Do Begin
   If SemanticIsSymbol('(') Or SemanticIsSymbol('[') Then Inc(Depth)
   Else If (SemanticIsSymbol(')') Or SemanticIsSymbol(']')) And
           (Depth>0) Then Dec(Depth);
   SemanticAdvance;
  End;
  If SemanticAcceptSymbol(';') Then
  Else If Not SemanticIsSymbol(')') Then Begin
   SemanticTokenError('fin de groupe de parametres attendue');
   Exit;
  End;
 End;
 If Not SemanticAcceptSymbol(')') Then
  SemanticTokenError('symbole ")" attendu');
End;

Procedure BuildProcedureSymbol(CurrentScope:Integer);
Var
 NameToken:TToken;
 EndName:String;
 ProcedureSymbol:Integer;
 ProcedureScope:Integer;
 Depth:Integer;
Begin
 SemanticAdvance;
 If SemanticToken.Kind<>TK_IDENTIFIER Then Begin
  SemanticTokenError('nom de procedure attendu');
  Exit;
 End;
 NameToken:=SemanticToken;
 SemanticAdvance;
 If Not AddSemanticSymbol(NameToken.Text,SYM_PROCEDURE,CurrentScope,'',0,
                          False,NameToken.Line,NameToken.Column,
                          ProcedureSymbol) Then Exit;
 If Not AddSemanticScope(NameToken.Text,SCOPE_PROCEDURE,CurrentScope,
                         ProcedureSymbol,ProcedureScope) Then Exit;
 Pipeline.Symbols[ProcedureSymbol].ChildScope:=ProcedureScope;
 BuildFormalParameters(ProcedureScope);
 If Pipeline.ErrorCount<>0 Then Exit;
 If SemanticAcceptSymbol(':') Then Begin
  Depth:=0;
  While (SemanticToken.Kind<>TK_EOF) And
        Not ((Depth=0) And SemanticIsSymbol(';')) Do Begin
   If SemanticIsSymbol('(') Or SemanticIsSymbol('[') Then Inc(Depth)
   Else If (SemanticIsSymbol(')') Or SemanticIsSymbol(']')) And
           (Depth>0) Then Dec(Depth);
   SemanticAdvance;
  End;
 End;
 If Not SemanticAcceptSymbol(';') Then Begin
  SemanticTokenError('point-virgule attendu apres PROCEDURE');
  Exit;
 End;
 BuildDeclarations(ProcedureScope);
 If Pipeline.ErrorCount<>0 Then Exit;
 If SemanticAcceptKeyword(KW_BEGIN) Then Begin
  Pipeline.Scopes[ProcedureScope].BodyStart:=Pipeline.SemanticIndex;
  SemanticSkipStatementSequence(ProcedureScope);
  Pipeline.Scopes[ProcedureScope].BodyEnd:=Pipeline.SemanticIndex-1;
 End;
 If Pipeline.ErrorCount<>0 Then Exit;
 If Not SemanticAcceptKeyword(KW_END) Then Begin
  SemanticTokenError('END attendu pour la procedure '+NameToken.Text);
  Exit;
 End;
 If SemanticToken.Kind=TK_IDENTIFIER Then Begin
  EndName:=SemanticToken.Text;
  If EndName<>NameToken.Text Then Begin
   SemanticTokenError('nom final de procedure different: '+EndName);
   Exit;
  End;
  SemanticAdvance;
 End;
 If Not SemanticAcceptSymbol(';') Then
  SemanticTokenError('point-virgule attendu apres END de procedure');
End;

Procedure BuildDeclarations(CurrentScope:Integer);
Begin
 While Pipeline.ErrorCount=0 Do Begin
  If SemanticIsKeyword(KW_CONST) Then BuildConstSymbols(CurrentScope)
  Else If SemanticIsKeyword(KW_TYPE) Then BuildTypeSymbols(CurrentScope)
  Else If SemanticIsKeyword(KW_VAR) Then BuildVarSymbols(CurrentScope)
  Else If SemanticIsKeyword(KW_PROCEDURE) Then
   BuildProcedureSymbol(CurrentScope)
  Else Exit;
 End;
End;

Function ResolveTypeName(TypeName:String;ScopeIndex,Depth:Integer):TScalarType;
Var
 SymbolIndex:Integer;
Begin
 ResolveTypeName:=BuiltinScalarType(TypeName);
 If ResolveTypeName<>SCALAR_NONE Then Exit;
 If Depth>MOD2_MAX_SCOPES Then Exit;
 SymbolIndex:=FindVisibleSymbol(TypeName,ScopeIndex);
 If (SymbolIndex=0) Or
    (Pipeline.Symbols[SymbolIndex].Kind<>SYM_TYPE) Then Exit;
 If Pipeline.Symbols[SymbolIndex].ScalarType<>SCALAR_NONE Then Begin
  ResolveTypeName:=Pipeline.Symbols[SymbolIndex].ScalarType;
  Exit;
 End;
 ResolveTypeName:=ResolveTypeName(Pipeline.Symbols[SymbolIndex].TypeName,
                                  Pipeline.Symbols[SymbolIndex].ScopeIndex,
                                  Depth+1);
 Pipeline.Symbols[SymbolIndex].ScalarType:=ResolveTypeName;
End;

Procedure ResolveAllScalarTypes;
Var
 I:Integer;
 ScalarType:TScalarType;
 S:TSymbol;
Begin
 For I:=1 To Pipeline.SymbolCount Do Begin
  S:=Pipeline.Symbols[I];
  If (S.Kind=SYM_TYPE) Or (S.Kind=SYM_VARIABLE) Or
     (S.Kind=SYM_PARAMETER) Then Begin
   ScalarType:=ResolveTypeName(S.TypeName,S.ScopeIndex,0);
   If ScalarType=SCALAR_NONE Then Begin
    SemanticError('type scalaire inconnu ou non supporte: '+S.TypeName,
                  S.Line,S.Column);
    Exit;
   End;
   Pipeline.Symbols[I].ScalarType:=ScalarType;
   Pipeline.Symbols[I].TypeSize:=ScalarTypeSize(ScalarType);
  End
  Else If (S.Kind=SYM_CONSTANT) And
          (S.ScalarType=SCALAR_NONE) Then Begin
   SemanticError('constante scalaire attendue pour "'+S.Name+'"',
                 S.Line,S.Column);
   Exit;
  End;
 End;
End;

Function AlignStorage(Value,Alignment:LongInt):LongInt;
Begin
 If Alignment<=1 Then AlignStorage:=Value
 Else AlignStorage:=((Value+Alignment-1) Div Alignment)*Alignment;
End;

Procedure AllocateVariableStorage;
Var
 I:Integer;
 ScopeIndex:Integer;
 SlotSize:Integer;
 Offset:LongInt;
 S:TSymbol;
Begin
 Pipeline.GlobalBssSize:=0;
 For I:=1 To Pipeline.ScopeCount Do Pipeline.Scopes[I].FrameSize:=0;
 For I:=1 To Pipeline.SymbolCount Do Begin
  S:=Pipeline.Symbols[I];
  If S.Kind=SYM_PARAMETER Then Begin
   Pipeline.Symbols[I].StorageKind:=STORAGE_PARAMETER;
   Pipeline.Symbols[I].StorageOffset:=
    I386_ARG_BASE_OFFSET+
    ((S.ParamIndex-1)*I386_STACK_SLOT_SIZE);
   Pipeline.Symbols[I].StorageSize:=I386_STACK_SLOT_SIZE;
  End
  Else If S.Kind=SYM_VARIABLE Then Begin
   ScopeIndex:=S.ScopeIndex;
   SlotSize:=I386_STACK_SLOT_SIZE;
   If Pipeline.Scopes[ScopeIndex].Kind=SCOPE_MODULE Then Begin
    Offset:=AlignStorage(Pipeline.GlobalBssSize,I386_STACK_ALIGN);
    Pipeline.Symbols[I].StorageKind:=STORAGE_GLOBAL;
    Pipeline.Symbols[I].StorageOffset:=Offset;
    Pipeline.Symbols[I].StorageSize:=SlotSize;
    Pipeline.GlobalBssSize:=Offset+SlotSize;
   End
   Else Begin
    Offset:=AlignStorage(Pipeline.Scopes[ScopeIndex].FrameSize+
                         SlotSize,I386_STACK_ALIGN);
    Pipeline.Scopes[ScopeIndex].FrameSize:=Offset;
    Pipeline.Symbols[I].StorageKind:=STORAGE_LOCAL;
    Pipeline.Symbols[I].StorageOffset:=-Offset;
    Pipeline.Symbols[I].StorageSize:=SlotSize;
   End;
  End;
 End;
 Pipeline.GlobalBssSize:=AlignStorage(Pipeline.GlobalBssSize,
                                     I386_BSS_ALIGN);
End;

Procedure BuildImportSymbols(ModuleScope:Integer);
Var
 Token:TToken;
 SymbolIndex:Integer;
 ModuleName:String;
Begin
 While SemanticIsKeyword(KW_IMPORT) Or SemanticIsKeyword(KW_FROM) Do Begin
  If SemanticAcceptKeyword(KW_FROM) Then Begin
   ModuleName:=SemanticToken.Text;
   SemanticAdvance;
   SemanticAcceptKeyword(KW_IMPORT);
   Repeat
    Token:=SemanticToken;
    SemanticAdvance;
    If Not AddSemanticSymbol(Token.Text,SYM_IMPORT_NAME,ModuleScope,
                             ModuleName,0,False,Token.Line,Token.Column,
                             SymbolIndex) Then Exit;
   Until Not SemanticAcceptSymbol(',');
  End
  Else Begin
   SemanticAdvance;
   Repeat
    Token:=SemanticToken;
    SemanticAdvance;
    If Not AddSemanticSymbol(Token.Text,SYM_IMPORT_MODULE,ModuleScope,
                             Token.Text,0,False,Token.Line,Token.Column,
                             SymbolIndex) Then Exit;
   Until Not SemanticAcceptSymbol(',');
  End;
  If Not SemanticAcceptSymbol(';') Then Begin
   SemanticTokenError('point-virgule attendu apres IMPORT');
   Exit;
  End;
 End;
End;

Procedure BuildExportNames;
Var
 NameToken:TToken;
 I:Integer;
 Duplicate:Boolean;
Begin
 Pipeline.ExportCount:=0;
 If Not SemanticAcceptKeyword(KW_EXPORT) Then Exit;
 SemanticAcceptKeyword(KW_QUALIFIED);
 Repeat
  NameToken:=SemanticToken;
  If NameToken.Kind<>TK_IDENTIFIER Then Begin
   SemanticTokenError('nom attendu dans EXPORT');
   Exit;
  End;
  Duplicate:=False;
  For I:=1 To Pipeline.ExportCount Do
   If Pipeline.ExportNames[I]=NameToken.Text Then Duplicate:=True;
  If Duplicate Then Begin
   SemanticError('nom exporte plusieurs fois: '+NameToken.Text,
                 NameToken.Line,NameToken.Column);
   Exit;
  End;
  If Pipeline.ExportCount>=MOD2_MAX_EXPORTS Then Begin
   SemanticError('trop de noms exportes',
                 NameToken.Line,NameToken.Column);
   Exit;
  End;
  Inc(Pipeline.ExportCount);
  Pipeline.ExportNames[Pipeline.ExportCount]:=NameToken.Text;
  SemanticAdvance;
 Until Not SemanticAcceptSymbol(',');
 If Not SemanticAcceptSymbol(';') Then
  SemanticTokenError('point-virgule attendu apres EXPORT');
End;

Procedure ResolveProcedureExports(ModuleScope:Integer);
Var
 I:Integer;
 SymbolIndex:Integer;
Begin
 For I:=1 To Pipeline.ExportCount Do Begin
  SymbolIndex:=FindSymbolInScope(Pipeline.ExportNames[I],ModuleScope);
  If SymbolIndex=0 Then Begin
   SemanticError('nom exporte non declare: '+Pipeline.ExportNames[I],1,1);
   Exit;
  End;
  If Pipeline.Symbols[SymbolIndex].Kind<>SYM_PROCEDURE Then Begin
   SemanticError('seules les procedures sont exportables actuellement: '+
                 Pipeline.ExportNames[I],
                 Pipeline.Symbols[SymbolIndex].Line,
                 Pipeline.Symbols[SymbolIndex].Column);
   Exit;
  End;
  Pipeline.Symbols[SymbolIndex].IsExported:=True;
  Pipeline.Symbols[SymbolIndex].AsmName:=
   MakeAsmLabel('_M2EXP_',Pipeline.ModuleName+'_'+
                Pipeline.Symbols[SymbolIndex].Name);
 End;
End;

Procedure TraceSemanticTables;
Var
 I:Integer;
 S:TSymbol;
Begin
 WriteLn('Semant.: ',Pipeline.ScopeCount,' portee(s), ',
         Pipeline.SymbolCount,' symbole(s)');
 If Options.Verbose Then
  For I:=1 To Pipeline.SymbolCount Do Begin
   S:=Pipeline.Symbols[I];
   WriteLn('  [',I,'] ',SymbolKindName(S.Kind),' ',S.Name,
           ' : ',ScalarTypeName(S.ScalarType),' [',S.TypeSize,']',
           ' ',ConstValueText(S.ConstValue),
           ' ',StorageKindName(S.StorageKind),
           ' offset=',S.StorageOffset,
           ' slot=',S.StorageSize,
           ' ref=',SymbolStorageRef(I),
           ' exported=',S.IsExported,
           ' scope=',S.ScopeIndex,' @ ',S.Line,':',S.Column);
  End;
 If Options.Verbose Then Begin
  WriteLn('  BSS global: ',Pipeline.GlobalBssSize,' octet(s)');
  For I:=1 To Pipeline.ScopeCount Do
   If Pipeline.Scopes[I].Kind=SCOPE_PROCEDURE Then
    WriteLn('  Frame ',Pipeline.Scopes[I].Name,': ',
            Pipeline.Scopes[I].FrameSize,' octet(s)');
 End;
End;

Procedure BuildSemanticTables;
Var
 ModuleToken:TToken;
 ModuleScope:Integer;
 ModuleSymbol:Integer;
Begin
 EnterStage(CS_SEMANTIC_TABLES);
 Pipeline.SemanticIndex:=1;
 Pipeline.ScopeCount:=0;
 Pipeline.SymbolCount:=0;
 If SemanticIsKeyword(KW_DEFINITION) Or
    SemanticIsKeyword(KW_IMPLEMENTATION) Then SemanticAdvance;
 If Not SemanticAcceptKeyword(KW_MODULE) Then Begin
  SemanticTokenError('MODULE attendu par la passe semantique');
  Exit;
 End;
 ModuleToken:=SemanticToken;
 If ModuleToken.Kind<>TK_IDENTIFIER Then Begin
  SemanticTokenError('nom de module attendu par la passe semantique');
  Exit;
 End;
 SemanticAdvance;
 If Not AddSemanticScope(ModuleToken.Text,SCOPE_MODULE,0,0,
                         ModuleScope) Then Exit;
 If Not AddSemanticSymbol(ModuleToken.Text,SYM_MODULE,ModuleScope,'',0,
                          False,ModuleToken.Line,ModuleToken.Column,
                          ModuleSymbol) Then Exit;
 Pipeline.Scopes[ModuleScope].OwnerSymbol:=ModuleSymbol;
 Pipeline.Symbols[ModuleSymbol].ChildScope:=ModuleScope;
 If Not SemanticAcceptSymbol(';') Then Begin
  SemanticTokenError('point-virgule attendu apres MODULE');
  Exit;
 End;
 BuildImportSymbols(ModuleScope);
 If Pipeline.ErrorCount<>0 Then Exit;
 BuildExportNames;
 If Pipeline.ErrorCount<>0 Then Exit;
 BuildDeclarations(ModuleScope);
 If Pipeline.ErrorCount<>0 Then Exit;
 ResolveProcedureExports(ModuleScope);
 If Pipeline.ErrorCount<>0 Then Exit;
 ResolveAllScalarTypes;
 If Pipeline.ErrorCount<>0 Then Exit;
 AllocateVariableStorage;
 If SemanticAcceptKeyword(KW_BEGIN) Then Begin
  Pipeline.Scopes[ModuleScope].BodyStart:=Pipeline.SemanticIndex;
  SemanticSkipStatementSequence(ModuleScope);
  Pipeline.Scopes[ModuleScope].BodyEnd:=Pipeline.SemanticIndex-1;
 End;
 If Pipeline.ErrorCount<>0 Then Exit;
 Pipeline.SemanticsReady:=True;
 FinishStage(CS_SEMANTIC_TABLES);
 TraceSemanticTables;
End;

Function IRToken:TToken;
Begin
 If (Pipeline.IrTokenIndex<1) Or
    (Pipeline.IrTokenIndex>Pipeline.IrTokenLimit) Then
  IRToken:=Pipeline.Tokens[Pipeline.TokenCount]
 Else IRToken:=Pipeline.Tokens[Pipeline.IrTokenIndex];
End;

Procedure IRAdvance;
Begin
 If Pipeline.IrTokenIndex<=Pipeline.IrTokenLimit Then
  Inc(Pipeline.IrTokenIndex);
End;

Function IRIsSymbol(Text:String):Boolean;
Begin
 IRIsSymbol:=(Pipeline.IrTokenIndex<=Pipeline.IrTokenLimit) And
             (IRToken.Kind=TK_SYMBOL) And (IRToken.Text=Text);
End;

Function IRIsKeyword(Keyword:TKeyword):Boolean;
Begin
 IRIsKeyword:=(Pipeline.IrTokenIndex<=Pipeline.IrTokenLimit) And
              (IRToken.Kind=TK_KEYWORD) And
              (IRToken.Keyword=Keyword);
End;

Function IRAcceptSymbol(Text:String):Boolean;
Begin
 IRAcceptSymbol:=IRIsSymbol(Text);
 If IRAcceptSymbol Then IRAdvance;
End;

Function AddIRNode(Op:TIRExprOp;ScalarType:TScalarType;
 LeftNode,RightNode,SymbolIndex:Integer;ConstValue:TConstValue;
 LineNo,ColumnNo:Integer):Integer;
Begin
 AddIRNode:=0;
 If Pipeline.IrNodeCount>=MOD2_MAX_IR_NODES Then Begin
  PipelineErrorAt(EK_CODEGEN,'trop de noeuds IR',LineNo,ColumnNo);
  Exit;
 End;
 Inc(Pipeline.IrNodeCount);
 AddIRNode:=Pipeline.IrNodeCount;
 Pipeline.IrNodes[AddIRNode].Op:=Op;
 Pipeline.IrNodes[AddIRNode].ScalarType:=ScalarType;
 Pipeline.IrNodes[AddIRNode].LeftNode:=LeftNode;
 Pipeline.IrNodes[AddIRNode].RightNode:=RightNode;
 Pipeline.IrNodes[AddIRNode].SymbolIndex:=SymbolIndex;
 Pipeline.IrNodes[AddIRNode].ConstValue:=ConstValue;
 Pipeline.IrNodes[AddIRNode].Line:=LineNo;
 Pipeline.IrNodes[AddIRNode].Column:=ColumnNo;
End;

Function AddIRExpression(RootNode,ScopeIndex:Integer;Context:String;
 LineNo,ColumnNo:Integer):Boolean;
Begin
 AddIRExpression:=False;
 If Pipeline.IrExpressionCount>=MOD2_MAX_EXPRESSIONS Then Begin
  PipelineErrorAt(EK_CODEGEN,'trop d''expressions IR',LineNo,ColumnNo);
  Exit;
 End;
 Inc(Pipeline.IrExpressionCount);
 Pipeline.IrExpressions[Pipeline.IrExpressionCount].RootNode:=RootNode;
 Pipeline.IrExpressions[Pipeline.IrExpressionCount].ScopeIndex:=ScopeIndex;
 Pipeline.IrExpressions[Pipeline.IrExpressionCount].Context:=Context;
 Pipeline.IrExpressions[Pipeline.IrExpressionCount].Line:=LineNo;
 Pipeline.IrExpressions[Pipeline.IrExpressionCount].Column:=ColumnNo;
 AddIRExpression:=True;
End;

Function IRNumericResultType(LeftType,RightType:TScalarType):TScalarType;
Begin
 If Not IsNumericScalar(LeftType) Or Not IsNumericScalar(RightType) Then
  IRNumericResultType:=SCALAR_NONE
 Else If (LeftType=SCALAR_INTEGER) Or (RightType=SCALAR_INTEGER) Then
  IRNumericResultType:=SCALAR_INTEGER
 Else IRNumericResultType:=SCALAR_CARDINAL;
End;

Function ParseIRExpression(CurrentScope:Integer;Var RootNode:Integer;
 Var ResultType:TScalarType):Boolean; Forward;

Function ParseIRBuiltinFunction(CurrentScope:Integer;NameToken:TToken;
 Var RootNode:Integer;Var ResultType:TScalarType):Boolean;
Var
 ArgumentNode:Integer;
 ArgumentType:TScalarType;
 Op:TIRExprOp;
 Value:TConstValue;
Begin
 ParseIRBuiltinFunction:=False;
 RootNode:=0;
 ResultType:=SCALAR_NONE;
 IRAdvance;
 If Not IRAcceptSymbol('(') Then Begin
  PipelineErrorAt(EK_CODEGEN,'symbole "(" attendu apres '+NameToken.Text,
                  IRToken.Line,IRToken.Column);
  Exit;
 End;
 If Not ParseIRExpression(CurrentScope,ArgumentNode,ArgumentType) Then Exit;
 If IRAcceptSymbol(',') Then Begin
  PipelineErrorAt(EK_CODEGEN,NameToken.Text+' attend un seul argument',
                  NameToken.Line,NameToken.Column);
  Exit;
 End;
 If Not IRAcceptSymbol(')') Then Begin
  PipelineErrorAt(EK_CODEGEN,'symbole ")" attendu apres l''argument de '+
                  NameToken.Text,IRToken.Line,IRToken.Column);
  Exit;
 End;
 If NameToken.Text='ORD' Then Begin
  If (ArgumentType<>SCALAR_CHAR) And
     (ArgumentType<>SCALAR_BOOLEAN) And
     Not IsNumericScalar(ArgumentType) Then Begin
   PipelineErrorAt(EK_CODEGEN,'ORD exige une valeur ordinale',
                   NameToken.Line,NameToken.Column);
   Exit;
  End;
  Op:=IR_EXPR_ORD;
  ResultType:=SCALAR_CARDINAL;
 End
 Else If NameToken.Text='CHR' Then Begin
  If Not IsNumericScalar(ArgumentType) Then Begin
   PipelineErrorAt(EK_CODEGEN,'CHR exige une valeur entiere',
                   NameToken.Line,NameToken.Column);
   Exit;
  End;
  Op:=IR_EXPR_CHR;
  ResultType:=SCALAR_CHAR;
 End
 Else If NameToken.Text='ODD' Then Begin
  If Not IsNumericScalar(ArgumentType) Then Begin
   PipelineErrorAt(EK_CODEGEN,'ODD exige une valeur entiere',
                   NameToken.Line,NameToken.Column);
   Exit;
  End;
  Op:=IR_EXPR_ODD;
  ResultType:=SCALAR_BOOLEAN;
 End
 Else Begin
  If Not IsNumericScalar(ArgumentType) Then Begin
   PipelineErrorAt(EK_CODEGEN,'ABS exige une valeur entiere',
                   NameToken.Line,NameToken.Column);
   Exit;
  End;
  Op:=IR_EXPR_ABS;
  ResultType:=ArgumentType;
 End;
 InitConstValue(Value);
 RootNode:=AddIRNode(Op,ResultType,ArgumentNode,0,0,Value,
                     NameToken.Line,NameToken.Column);
 ParseIRBuiltinFunction:=RootNode<>0;
End;

Function ParseIRPrimary(CurrentScope:Integer;Var RootNode:Integer;
 Var ResultType:TScalarType):Boolean;
Var
 Token:TToken;
 Value:TConstValue;
 SymbolIndex:Integer;
Begin
 ParseIRPrimary:=False;
 RootNode:=0;
 ResultType:=SCALAR_NONE;
 Token:=IRToken;
 InitConstValue(Value);
 If Token.Kind=TK_INTEGER Then Begin
  Value.ScalarType:=SCALAR_INTEGER;
  Value.IntegerValue:=Token.IntegerVal;
  Value.Valid:=True;
  RootNode:=AddIRNode(IR_EXPR_CONST,SCALAR_INTEGER,0,0,0,Value,
                      Token.Line,Token.Column);
  ResultType:=SCALAR_INTEGER;
  IRAdvance;
 End
 Else If Token.Kind=TK_STRING Then Begin
  Value.StringValue:=Token.Text;
  Value.Valid:=True;
  If Length(Token.Text)=1 Then Begin
   Value.ScalarType:=SCALAR_CHAR;
   Value.IntegerValue:=Ord(Token.Text[1]);
  End
  Else Value.ScalarType:=SCALAR_STRING;
  RootNode:=AddIRNode(IR_EXPR_CONST,Value.ScalarType,0,0,0,Value,
                      Token.Line,Token.Column);
  ResultType:=Value.ScalarType;
  IRAdvance;
 End
 Else If Token.Kind=TK_IDENTIFIER Then Begin
  If ((Token.Text='ORD') Or (Token.Text='CHR') Or
      (Token.Text='ODD') Or (Token.Text='ABS')) And
     (Pipeline.IrTokenIndex<Pipeline.IrTokenLimit) And
     (Pipeline.Tokens[Pipeline.IrTokenIndex+1].Kind=TK_SYMBOL) And
     (Pipeline.Tokens[Pipeline.IrTokenIndex+1].Text='(') Then Begin
   ParseIRPrimary:=ParseIRBuiltinFunction(CurrentScope,Token,
                                          RootNode,ResultType);
   Exit;
  End
  Else If (Token.Text='TRUE') Or (Token.Text='FALSE') Then Begin
   Value.ScalarType:=SCALAR_BOOLEAN;
   If Token.Text='TRUE' Then Value.IntegerValue:=1
    Else Value.IntegerValue:=0;
   Value.Valid:=True;
   RootNode:=AddIRNode(IR_EXPR_CONST,SCALAR_BOOLEAN,0,0,0,Value,
                       Token.Line,Token.Column);
   ResultType:=SCALAR_BOOLEAN;
  End
  Else Begin
   SymbolIndex:=FindVisibleSymbol(Token.Text,CurrentScope);
   If SymbolIndex=0 Then Begin
    PipelineErrorAt(EK_CODEGEN,'identificateur inconnu dans expression: '+
                    Token.Text,Token.Line,Token.Column);
    Exit;
   End;
   If Pipeline.Symbols[SymbolIndex].Kind=SYM_CONSTANT Then Begin
    Value:=Pipeline.Symbols[SymbolIndex].ConstValue;
    RootNode:=AddIRNode(IR_EXPR_CONST,Value.ScalarType,0,0,
                        SymbolIndex,Value,Token.Line,Token.Column);
    ResultType:=Value.ScalarType;
   End
   Else If (Pipeline.Symbols[SymbolIndex].Kind=SYM_VARIABLE) Or
           (Pipeline.Symbols[SymbolIndex].Kind=SYM_PARAMETER) Then Begin
    ResultType:=Pipeline.Symbols[SymbolIndex].ScalarType;
    RootNode:=AddIRNode(IR_EXPR_LOAD,ResultType,0,0,SymbolIndex,Value,
                        Token.Line,Token.Column);
   End
   Else Begin
    PipelineErrorAt(EK_CODEGEN,'"valeur attendue dans expression: '+
                    Token.Text,Token.Line,Token.Column);
    Exit;
   End;
  End;
  IRAdvance;
 End
 Else If IRAcceptSymbol('(') Then Begin
  If Not ParseIRExpression(CurrentScope,RootNode,ResultType) Then Exit;
  If Not IRAcceptSymbol(')') Then Begin
   PipelineErrorAt(EK_CODEGEN,'parenthese fermante attendue',
                   IRToken.Line,IRToken.Column);
   Exit;
  End;
 End
 Else Begin
  PipelineErrorAt(EK_CODEGEN,'expression attendue',
                  Token.Line,Token.Column);
  Exit;
 End;
 ParseIRPrimary:=RootNode<>0;
End;

Function ParseIRUnary(CurrentScope:Integer;Var RootNode:Integer;
 Var ResultType:TScalarType):Boolean;
Var
 Token:TToken;
 ChildNode:Integer;
 ChildType:TScalarType;
 Value:TConstValue;
Begin
 ParseIRUnary:=False;
 Token:=IRToken;
 If IRAcceptSymbol('+') Then Begin
  If Not ParseIRUnary(CurrentScope,RootNode,ResultType) Then Exit;
  If Not IsNumericScalar(ResultType) Then Begin
   PipelineErrorAt(EK_CODEGEN,'operateur unaire + exige un entier',
                   Token.Line,Token.Column);
   Exit;
  End;
 End
 Else If IRAcceptSymbol('-') Then Begin
  If Not ParseIRUnary(CurrentScope,ChildNode,ChildType) Then Exit;
  If Not IsNumericScalar(ChildType) Then Begin
   PipelineErrorAt(EK_CODEGEN,'operateur unaire - exige un entier',
                   Token.Line,Token.Column);
   Exit;
  End;
  InitConstValue(Value);
  ResultType:=SCALAR_INTEGER;
  RootNode:=AddIRNode(IR_EXPR_NEG,ResultType,ChildNode,0,0,Value,
                      Token.Line,Token.Column);
 End
 Else If IRIsKeyword(KW_NOT) Then Begin
  IRAdvance;
  If Not ParseIRUnary(CurrentScope,ChildNode,ChildType) Then Exit;
  If ChildType<>SCALAR_BOOLEAN Then Begin
   PipelineErrorAt(EK_CODEGEN,'NOT exige une expression BOOLEAN',
                   Token.Line,Token.Column);
   Exit;
  End;
  InitConstValue(Value);
  ResultType:=SCALAR_BOOLEAN;
  RootNode:=AddIRNode(IR_EXPR_NOT,ResultType,ChildNode,0,0,Value,
                      Token.Line,Token.Column);
 End
 Else Begin
  ParseIRUnary:=ParseIRPrimary(CurrentScope,RootNode,ResultType);
  Exit;
 End;
 ParseIRUnary:=RootNode<>0;
End;

Function ParseIRProduct(CurrentScope:Integer;Var RootNode:Integer;
 Var ResultType:TScalarType):Boolean;
Var
 Token:TToken;
 RightNode:Integer;
 RightType:TScalarType;
 NewNode:Integer;
 NewType:TScalarType;
 Op:TIRExprOp;
 Value:TConstValue;
Begin
 ParseIRProduct:=False;
 If Not ParseIRUnary(CurrentScope,RootNode,ResultType) Then Exit;
 While IRIsSymbol('*') Or IRIsKeyword(KW_DIV) Or
       IRIsKeyword(KW_MOD) Do Begin
  Token:=IRToken;
  If IRIsSymbol('*') Then Op:=IR_EXPR_MUL
  Else If IRIsKeyword(KW_DIV) Then Op:=IR_EXPR_DIV
  Else Op:=IR_EXPR_MOD;
  IRAdvance;
  If Not ParseIRUnary(CurrentScope,RightNode,RightType) Then Exit;
  NewType:=IRNumericResultType(ResultType,RightType);
  If NewType=SCALAR_NONE Then Begin
   PipelineErrorAt(EK_CODEGEN,IRExprOpName(Op)+
                   ' exige deux operandes entiers',
                   Token.Line,Token.Column);
   Exit;
  End;
  InitConstValue(Value);
  NewNode:=AddIRNode(Op,NewType,RootNode,RightNode,0,Value,
                     Token.Line,Token.Column);
  If NewNode=0 Then Exit;
  RootNode:=NewNode;
  ResultType:=NewType;
 End;
 ParseIRProduct:=True;
End;

Function ParseIRSum(CurrentScope:Integer;Var RootNode:Integer;
 Var ResultType:TScalarType):Boolean;
Var
 Token:TToken;
 RightNode:Integer;
 RightType:TScalarType;
 NewNode:Integer;
 NewType:TScalarType;
 Op:TIRExprOp;
 Value:TConstValue;
Begin
 ParseIRSum:=False;
 If Not ParseIRProduct(CurrentScope,RootNode,ResultType) Then Exit;
 While IRIsSymbol('+') Or IRIsSymbol('-') Do Begin
  Token:=IRToken;
  If IRIsSymbol('+') Then Op:=IR_EXPR_ADD Else Op:=IR_EXPR_SUB;
  IRAdvance;
  If Not ParseIRProduct(CurrentScope,RightNode,RightType) Then Exit;
  NewType:=IRNumericResultType(ResultType,RightType);
  If NewType=SCALAR_NONE Then Begin
   PipelineErrorAt(EK_CODEGEN,IRExprOpName(Op)+
                   ' exige deux operandes entiers',
                   Token.Line,Token.Column);
   Exit;
  End;
  InitConstValue(Value);
  NewNode:=AddIRNode(Op,NewType,RootNode,RightNode,0,Value,
                     Token.Line,Token.Column);
  If NewNode=0 Then Exit;
  RootNode:=NewNode;
  ResultType:=NewType;
 End;
 ParseIRSum:=True;
End;

Function IRTypesComparable(LeftType,RightType:TScalarType;
 Ordering:Boolean):Boolean;
Begin
 If Ordering Then
  IRTypesComparable:=
   (IsNumericScalar(LeftType) And IsNumericScalar(RightType)) Or
   ((LeftType=SCALAR_CHAR) And (RightType=SCALAR_CHAR))
 Else
  IRTypesComparable:=ScalarTypesCompatible(LeftType,RightType) Or
   ((LeftType=SCALAR_BOOLEAN) And (RightType=SCALAR_BOOLEAN)) Or
   ((LeftType=SCALAR_CHAR) And (RightType=SCALAR_CHAR)) Or
   ((LeftType=SCALAR_STRING) And (RightType=SCALAR_STRING));
End;

Function ParseIRComparison(CurrentScope:Integer;Var RootNode:Integer;
 Var ResultType:TScalarType):Boolean;
Var
 Token:TToken;
 RightNode:Integer;
 RightType:TScalarType;
 Op:TIRExprOp;
 Ordering:Boolean;
 Value:TConstValue;
Begin
 ParseIRComparison:=False;
 If Not ParseIRSum(CurrentScope,RootNode,ResultType) Then Exit;
 If IRIsSymbol('=') Or IRIsSymbol('#') Or IRIsSymbol('<>') Or
    IRIsSymbol('<') Or IRIsSymbol('<=') Or
    IRIsSymbol('>') Or IRIsSymbol('>=') Then Begin
  Token:=IRToken;
  Ordering:=False;
  If Token.Text='=' Then Op:=IR_EXPR_EQ
  Else If (Token.Text='#') Or (Token.Text='<>') Then Op:=IR_EXPR_NE
  Else If Token.Text='<' Then Begin Op:=IR_EXPR_LT; Ordering:=True; End
  Else If Token.Text='<=' Then Begin Op:=IR_EXPR_LE; Ordering:=True; End
  Else If Token.Text='>' Then Begin Op:=IR_EXPR_GT; Ordering:=True; End
  Else Begin Op:=IR_EXPR_GE; Ordering:=True; End;
  IRAdvance;
  If Not ParseIRSum(CurrentScope,RightNode,RightType) Then Exit;
  If Not IRTypesComparable(ResultType,RightType,Ordering) Then Begin
   PipelineErrorAt(EK_CODEGEN,'types incompatibles pour '+
                   Token.Text+': '+ScalarTypeName(ResultType)+' et '+
                   ScalarTypeName(RightType),Token.Line,Token.Column);
   Exit;
  End;
  InitConstValue(Value);
  RootNode:=AddIRNode(Op,SCALAR_BOOLEAN,RootNode,RightNode,0,Value,
                      Token.Line,Token.Column);
  ResultType:=SCALAR_BOOLEAN;
 End;
 ParseIRComparison:=True;
End;

Function ParseIRNot(CurrentScope:Integer;Var RootNode:Integer;
 Var ResultType:TScalarType):Boolean;
Begin
 ParseIRNot:=ParseIRComparison(CurrentScope,RootNode,ResultType);
End;

Function ParseIRAnd(CurrentScope:Integer;Var RootNode:Integer;
 Var ResultType:TScalarType):Boolean;
Var
 Token:TToken;
 RightNode:Integer;
 RightType:TScalarType;
 Value:TConstValue;
Begin
 ParseIRAnd:=False;
 If Not ParseIRNot(CurrentScope,RootNode,ResultType) Then Exit;
 While IRIsKeyword(KW_AND) Do Begin
  Token:=IRToken;
  IRAdvance;
  If Not ParseIRNot(CurrentScope,RightNode,RightType) Then Exit;
  If (ResultType<>SCALAR_BOOLEAN) Or
     (RightType<>SCALAR_BOOLEAN) Then Begin
   PipelineErrorAt(EK_CODEGEN,'AND exige deux expressions BOOLEAN',
                   Token.Line,Token.Column);
   Exit;
  End;
  InitConstValue(Value);
  RootNode:=AddIRNode(IR_EXPR_AND,SCALAR_BOOLEAN,RootNode,RightNode,0,Value,
                      Token.Line,Token.Column);
  ResultType:=SCALAR_BOOLEAN;
 End;
 ParseIRAnd:=True;
End;

Function ParseIRExpression(CurrentScope:Integer;Var RootNode:Integer;
 Var ResultType:TScalarType):Boolean;
Var
 Token:TToken;
 RightNode:Integer;
 RightType:TScalarType;
 Value:TConstValue;
Begin
 ParseIRExpression:=False;
 If Not ParseIRAnd(CurrentScope,RootNode,ResultType) Then Exit;
 While IRIsKeyword(KW_OR) Do Begin
  Token:=IRToken;
  IRAdvance;
  If Not ParseIRAnd(CurrentScope,RightNode,RightType) Then Exit;
  If (ResultType<>SCALAR_BOOLEAN) Or
     (RightType<>SCALAR_BOOLEAN) Then Begin
   PipelineErrorAt(EK_CODEGEN,'OR exige deux expressions BOOLEAN',
                   Token.Line,Token.Column);
   Exit;
  End;
  InitConstValue(Value);
  RootNode:=AddIRNode(IR_EXPR_OR,SCALAR_BOOLEAN,RootNode,RightNode,0,Value,
                      Token.Line,Token.Column);
  ResultType:=SCALAR_BOOLEAN;
 End;
 ParseIRExpression:=True;
End;

Procedure CollectIRExpression(CurrentScope:Integer;Context:String);
Var
 RootNode:Integer;
 ResultType:TScalarType;
 Token:TToken;
Begin
 Token:=IRToken;
 If Not ParseIRExpression(CurrentScope,RootNode,ResultType) Then Exit;
 AddIRExpression(RootNode,CurrentScope,Context,Token.Line,Token.Column);
End;

Procedure CollectIRCondition(CurrentScope:Integer;Context:String;
 Terminator:TKeyword);
Var
 RootNode:Integer;
 ResultType:TScalarType;
 Token:TToken;
Begin
 Token:=IRToken;
 If Not ParseIRExpression(CurrentScope,RootNode,ResultType) Then Exit;
 If ResultType<>SCALAR_BOOLEAN Then Begin
  PipelineErrorAt(EK_CODEGEN,Context+' exige une expression BOOLEAN',
                  Token.Line,Token.Column);
  Exit;
 End;
 If (Terminator<>KW_NONE) And Not IRIsKeyword(Terminator) Then Begin
  PipelineErrorAt(EK_CODEGEN,'mot-cle '+KeywordName(Terminator)+
                  ' attendu apres la condition',
                  IRToken.Line,IRToken.Column);
  Exit;
 End;
 AddIRExpression(RootNode,CurrentScope,Context,Token.Line,Token.Column);
End;

Procedure CollectCallArguments(CurrentScope,OpenParenIndex:Integer);
Begin
 Pipeline.IrTokenIndex:=OpenParenIndex+1;
 If IRIsSymbol(')') Then Begin
  IRAdvance;
  Exit;
 End;
 While (Pipeline.IrTokenIndex<=Pipeline.IrTokenLimit) And
       (Pipeline.ErrorCount=0) Do Begin
  CollectIRExpression(CurrentScope,'ARG');
  If Pipeline.ErrorCount<>0 Then Exit;
  If IRAcceptSymbol(',') Then
  Else If IRAcceptSymbol(')') Then Exit
  Else Begin
   PipelineErrorAt(EK_CODEGEN,'virgule ou ")" attendue dans appel',
                   IRToken.Line,IRToken.Column);
   Exit;
  End;
 End;
End;

Procedure CollectScopeExpressions(ScopeIndex:Integer);
Var
 I:Integer;
 OpenParenIndex:Integer;
 Token:TToken;
Begin
 If Pipeline.Scopes[ScopeIndex].BodyStart=0 Then Exit;
 Pipeline.IrTokenLimit:=Pipeline.Scopes[ScopeIndex].BodyEnd;
 I:=Pipeline.Scopes[ScopeIndex].BodyStart;
 While (I<=Pipeline.IrTokenLimit) And (Pipeline.ErrorCount=0) Do Begin
  Pipeline.IrTokenIndex:=I;
  Token:=IRToken;
  If IRIsKeyword(KW_IF) Or IRIsKeyword(KW_ELSIF) Then Begin
   IRAdvance;
   CollectIRCondition(ScopeIndex,'CONDITION IF',KW_THEN);
   I:=Pipeline.IrTokenIndex;
  End
  Else If IRIsKeyword(KW_WHILE) Then Begin
   IRAdvance;
   CollectIRCondition(ScopeIndex,'CONDITION WHILE',KW_DO);
   I:=Pipeline.IrTokenIndex;
  End
  Else If IRIsKeyword(KW_UNTIL) Then Begin
   IRAdvance;
   CollectIRCondition(ScopeIndex,'CONDITION UNTIL',KW_NONE);
   I:=Pipeline.IrTokenIndex;
  End
  Else If (Token.Kind=TK_IDENTIFIER) And
     (I<Pipeline.IrTokenLimit) And
     (Pipeline.Tokens[I+1].Kind=TK_SYMBOL) And
     (Pipeline.Tokens[I+1].Text=':=') Then Begin
   Pipeline.IrTokenIndex:=I+2;
   CollectIRExpression(ScopeIndex,'ASSIGN');
   I:=Pipeline.IrTokenIndex;
  End
  Else If IRIsKeyword(KW_TO) Or IRIsKeyword(KW_BY) Then Begin
   IRAdvance;
   CollectIRExpression(ScopeIndex,'BOUND');
   I:=Pipeline.IrTokenIndex;
  End
  Else Begin
   OpenParenIndex:=0;
   If (Token.Kind=TK_IDENTIFIER) And
      (I<Pipeline.IrTokenLimit) And
      (Pipeline.Tokens[I+1].Kind=TK_SYMBOL) And
      (Pipeline.Tokens[I+1].Text='(') Then OpenParenIndex:=I+1
   Else If (Token.Kind=TK_IDENTIFIER) And
           (I+3<=Pipeline.IrTokenLimit) And
           (Pipeline.Tokens[I+1].Kind=TK_SYMBOL) And
           (Pipeline.Tokens[I+1].Text='.') And
           (Pipeline.Tokens[I+2].Kind=TK_IDENTIFIER) And
           (Pipeline.Tokens[I+3].Kind=TK_SYMBOL) And
           (Pipeline.Tokens[I+3].Text='(') Then OpenParenIndex:=I+3;
   If OpenParenIndex<>0 Then Begin
    CollectCallArguments(ScopeIndex,OpenParenIndex);
    I:=Pipeline.IrTokenIndex;
   End
   Else Inc(I);
  End;
 End;
End;

Function AddIRStatement(Kind:TIRStatementKind;ScopeIndex,BlockDepth,
 ControlDepth,
 TargetSymbol,ExpressionRoot,ProcedureSymbol:Integer;
 ProcedureName:String;LineNo,ColumnNo:Integer):Integer;
Var
 I:Integer;
Begin
 AddIRStatement:=0;
 If Pipeline.IrStatementCount>=MOD2_MAX_STATEMENTS Then Begin
  PipelineErrorAt(EK_CODEGEN,'trop d''instructions IR',
                  LineNo,ColumnNo);
  Exit;
 End;
 Inc(Pipeline.IrStatementCount);
 AddIRStatement:=Pipeline.IrStatementCount;
 Pipeline.IrStatements[AddIRStatement].Kind:=Kind;
 Pipeline.IrStatements[AddIRStatement].ScopeIndex:=ScopeIndex;
 Pipeline.IrStatements[AddIRStatement].BlockDepth:=BlockDepth;
 Pipeline.IrStatements[AddIRStatement].ControlDepth:=ControlDepth;
 Pipeline.IrStatements[AddIRStatement].ControlId:=0;
 Pipeline.IrStatements[AddIRStatement].TargetSymbol:=TargetSymbol;
 Pipeline.IrStatements[AddIRStatement].ExpressionRoot:=ExpressionRoot;
 Pipeline.IrStatements[AddIRStatement].ProcedureSymbol:=ProcedureSymbol;
 Pipeline.IrStatements[AddIRStatement].ProcedureName:=ProcedureName;
 Pipeline.IrStatements[AddIRStatement].ArgumentCount:=0;
 For I:=1 To MOD2_MAX_CALL_ARGS Do
  Pipeline.IrStatements[AddIRStatement].Arguments[I]:=0;
 Pipeline.IrStatements[AddIRStatement].Line:=LineNo;
 Pipeline.IrStatements[AddIRStatement].Column:=ColumnNo;
End;

Function AddIRIfStatement(Kind:TIRStatementKind;ScopeIndex,BlockDepth,
 DeferredDepth,ControlId,ExpressionRoot:Integer;
 LineNo,ColumnNo:Integer):Integer;
Begin
 AddIRIfStatement:=AddIRStatement(Kind,ScopeIndex,BlockDepth,
  DeferredDepth,0,ExpressionRoot,0,'',LineNo,ColumnNo);
 If AddIRIfStatement<>0 Then
  Pipeline.IrStatements[AddIRIfStatement].ControlId:=ControlId;
End;

Function AddIRLoopStatement(Kind:TIRStatementKind;ScopeIndex,BlockDepth,
 DeferredDepth,ControlId,ExpressionRoot:Integer;
 LineNo,ColumnNo:Integer):Integer;
Begin
 AddIRLoopStatement:=AddIRStatement(Kind,ScopeIndex,BlockDepth,
  DeferredDepth,0,ExpressionRoot,0,'',LineNo,ColumnNo);
 If AddIRLoopStatement<>0 Then
  Pipeline.IrStatements[AddIRLoopStatement].ControlId:=ControlId;
End;

Function AddIRForStatement(Kind:TIRStatementKind;ScopeIndex,BlockDepth,
 DeferredDepth,ControlId,LoopSymbol,StartRoot,EndRoot,StepRoot:Integer;
 LineNo,ColumnNo:Integer):Integer;
Begin
 AddIRForStatement:=AddIRStatement(Kind,ScopeIndex,BlockDepth,
  DeferredDepth,LoopSymbol,StartRoot,0,'',LineNo,ColumnNo);
 If AddIRForStatement<>0 Then Begin
  Pipeline.IrStatements[AddIRForStatement].ControlId:=ControlId;
  Pipeline.IrStatements[AddIRForStatement].ArgumentCount:=2;
  Pipeline.IrStatements[AddIRForStatement].Arguments[1]:=EndRoot;
  Pipeline.IrStatements[AddIRForStatement].Arguments[2]:=StepRoot;
 End;
End;

Function AddIRIntegerConstant(Value:LongInt;LineNo,ColumnNo:Integer):Integer;
Var
 ConstValue:TConstValue;
Begin
 InitConstValue(ConstValue);
 ConstValue.ScalarType:=SCALAR_INTEGER;
 ConstValue.IntegerValue:=Value;
 ConstValue.Valid:=True;
 AddIRIntegerConstant:=AddIRNode(IR_EXPR_CONST,SCALAR_INTEGER,0,0,0,
                                 ConstValue,LineNo,ColumnNo);
End;

Function ParseStatementExpression(CurrentScope:Integer;
 Var RootNode:Integer;Var ResultType:TScalarType):Boolean;
Begin
 ParseStatementExpression:=
  ParseIRExpression(CurrentScope,RootNode,ResultType);
End;

Procedure BuildAssignmentStatement(ScopeIndex,BlockDepth,
 ControlDepth:Integer);
Var
 NameToken:TToken;
 TargetSymbol:Integer;
 RootNode:Integer;
 ResultType:TScalarType;
 TargetType:TScalarType;
Begin
 NameToken:=IRToken;
 TargetSymbol:=FindVisibleSymbol(NameToken.Text,ScopeIndex);
 If (TargetSymbol=0) Or
    ((Pipeline.Symbols[TargetSymbol].Kind<>SYM_VARIABLE) And
     (Pipeline.Symbols[TargetSymbol].Kind<>SYM_PARAMETER)) Then Begin
  PipelineErrorAt(EK_CODEGEN,'destination d''affectation invalide: '+
                  NameToken.Text,NameToken.Line,NameToken.Column);
  Exit;
 End;
 IRAdvance;
 If Not IRAcceptSymbol(':=') Then Begin
  PipelineErrorAt(EK_CODEGEN,'symbole ":=" attendu',
                  IRToken.Line,IRToken.Column);
  Exit;
 End;
 If Not ParseStatementExpression(ScopeIndex,RootNode,ResultType) Then Exit;
 TargetType:=Pipeline.Symbols[TargetSymbol].ScalarType;
 If Not ScalarTypesCompatible(TargetType,ResultType) Then Begin
  PipelineErrorAt(EK_CODEGEN,'affectation incompatible: '+
                  ScalarTypeName(ResultType)+' vers '+
                  ScalarTypeName(TargetType),
                  NameToken.Line,NameToken.Column);
  Exit;
 End;
 AddIRStatement(IR_STMT_ASSIGN,ScopeIndex,BlockDepth,ControlDepth,TargetSymbol,
                RootNode,0,'',NameToken.Line,NameToken.Column);
End;

Function ResolveCallTarget(ScopeIndex:Integer;Var ProcedureSymbol:Integer;
 Var ProcedureName:String;Var CallToken:TToken):Boolean;
Var
 FirstSymbol:Integer;
 ModuleName:String;
Begin
 ResolveCallTarget:=False;
 ProcedureSymbol:=0;
 ProcedureName:='';
 CallToken:=IRToken;
 If IRToken.Kind<>TK_IDENTIFIER Then Exit;
 FirstSymbol:=FindVisibleSymbol(IRToken.Text,ScopeIndex);
 ModuleName:=IRToken.Text;
 ProcedureName:=IRToken.Text;
 IRAdvance;
 If IRAcceptSymbol('.') Then Begin
  If (FirstSymbol=0) Or
     (Pipeline.Symbols[FirstSymbol].Kind<>SYM_IMPORT_MODULE) Then Begin
   PipelineErrorAt(EK_CODEGEN,'module d''appel inconnu: '+ModuleName,
                   CallToken.Line,CallToken.Column);
   Exit;
  End;
  If IRToken.Kind<>TK_IDENTIFIER Then Begin
   PipelineErrorAt(EK_CODEGEN,'nom de procedure attendu apres "."',
                   IRToken.Line,IRToken.Column);
   Exit;
  End;
  ProcedureName:=ModuleName+'.'+IRToken.Text;
  IRAdvance;
 End
 Else If FirstSymbol<>0 Then Begin
  If Pipeline.Symbols[FirstSymbol].Kind=SYM_PROCEDURE Then
   ProcedureSymbol:=FirstSymbol
  Else If Pipeline.Symbols[FirstSymbol].Kind<>SYM_IMPORT_NAME Then Begin
   PipelineErrorAt(EK_CODEGEN,'"'+ProcedureName+
                   '" n''est pas une procedure',
                   CallToken.Line,CallToken.Column);
   Exit;
  End;
 End
 Else If (ProcedureName='INC') Or (ProcedureName='DEC') Or
         (ProcedureName='ORD') Or (ProcedureName='CHR') Or
         (ProcedureName='ODD') Or (ProcedureName='ABS') Then
 Else Begin
  PipelineErrorAt(EK_CODEGEN,'procedure inconnue: '+ProcedureName,
                  CallToken.Line,CallToken.Column);
  Exit;
 End;
 ResolveCallTarget:=True;
End;

Function FindProcedureParameter(ProcedureSymbol,ParamIndex:Integer):Integer;
Var
 I:Integer;
 ParamScope:Integer;
Begin
 FindProcedureParameter:=0;
 If ProcedureSymbol=0 Then Exit;
 ParamScope:=Pipeline.Symbols[ProcedureSymbol].ChildScope;
 For I:=1 To Pipeline.SymbolCount Do
  If (Pipeline.Symbols[I].Kind=SYM_PARAMETER) And
     (Pipeline.Symbols[I].ScopeIndex=ParamScope) And
     (Pipeline.Symbols[I].ParamIndex=ParamIndex) Then Begin
   FindProcedureParameter:=I;
   Exit;
  End;
End;

Function IRRootAddressable(RootNode:Integer;Var SymbolIndex:Integer):Boolean;
Begin
 SymbolIndex:=0;
 IRRootAddressable:=(RootNode>=1) And
                    (RootNode<=Pipeline.IrNodeCount) And
                    (Pipeline.IrNodes[RootNode].Op=IR_EXPR_LOAD);
 If IRRootAddressable Then Begin
  SymbolIndex:=Pipeline.IrNodes[RootNode].SymbolIndex;
  IRRootAddressable:=(Pipeline.Symbols[SymbolIndex].Kind=SYM_VARIABLE) Or
                     (Pipeline.Symbols[SymbolIndex].Kind=SYM_PARAMETER);
 End;
End;

Procedure BuildCallStatement(ScopeIndex,BlockDepth,ControlDepth:Integer);
Var
 StatementIndex:Integer;
 ProcedureSymbol:Integer;
 ProcedureName:String;
 CallToken:TToken;
 RootNode:Integer;
 ResultType:TScalarType;
 ArgCount:Integer;
 ParamSymbol:Integer;
 I:Integer;
 ExpectedCount:Integer;
 ArgumentSymbol:Integer;
Begin
 If Not ResolveCallTarget(ScopeIndex,ProcedureSymbol,ProcedureName,
                          CallToken) Then Exit;
 StatementIndex:=AddIRStatement(IR_STMT_CALL,ScopeIndex,BlockDepth,
                                ControlDepth,0,0,
                                ProcedureSymbol,ProcedureName,
                                CallToken.Line,CallToken.Column);
 If StatementIndex=0 Then Exit;
 ArgCount:=0;
 If IRAcceptSymbol('(') Then Begin
  If Not IRIsSymbol(')') Then
   Repeat
    If ArgCount>=MOD2_MAX_CALL_ARGS Then Begin
     PipelineErrorAt(EK_CODEGEN,'trop d''arguments dans l''appel',
                     IRToken.Line,IRToken.Column);
     Exit;
    End;
    If Not ParseStatementExpression(ScopeIndex,RootNode,ResultType) Then Exit;
    Inc(ArgCount);
    Pipeline.IrStatements[StatementIndex].Arguments[ArgCount]:=RootNode;
   Until Not IRAcceptSymbol(',');
  If Not IRAcceptSymbol(')') Then Begin
   PipelineErrorAt(EK_CODEGEN,'symbole ")" attendu dans l''appel',
                   IRToken.Line,IRToken.Column);
   Exit;
  End;
 End;
 Pipeline.IrStatements[StatementIndex].ArgumentCount:=ArgCount;
 If ProcedureSymbol<>0 Then Begin
  ExpectedCount:=0;
  For I:=1 To Pipeline.SymbolCount Do
   If (Pipeline.Symbols[I].Kind=SYM_PARAMETER) And
      (Pipeline.Symbols[I].ScopeIndex=
       Pipeline.Symbols[ProcedureSymbol].ChildScope) Then
    Inc(ExpectedCount);
  If ArgCount<>ExpectedCount Then Begin
   PipelineErrorAt(EK_CODEGEN,'appel de '+ProcedureName+' attend '+
                   IntToString(ExpectedCount)+' argument(s), obtenu '+
                   IntToString(ArgCount),CallToken.Line,CallToken.Column);
   Exit;
  End;
  For I:=1 To ArgCount Do Begin
   ParamSymbol:=FindProcedureParameter(ProcedureSymbol,I);
   If (ParamSymbol<>0) And Pipeline.Symbols[ParamSymbol].ByReference And
      (Pipeline.Symbols[ParamSymbol].ScalarType<>
       Pipeline.IrNodes[Pipeline.IrStatements[StatementIndex].
        Arguments[I]].ScalarType) Then Begin
    PipelineErrorAt(EK_CODEGEN,'type exact requis pour l''argument VAR '+
                    IntToString(I)+' de '+ProcedureName,
                    CallToken.Line,CallToken.Column);
    Exit;
   End;
   If (ParamSymbol<>0) And Not Pipeline.Symbols[ParamSymbol].ByReference And
      Not ScalarTypesCompatible(Pipeline.Symbols[ParamSymbol].ScalarType,
       Pipeline.IrNodes[Pipeline.IrStatements[StatementIndex].
        Arguments[I]].ScalarType) Then Begin
    PipelineErrorAt(EK_CODEGEN,'type incompatible pour l''argument '+
                    IntToString(I)+' de '+ProcedureName,
                    CallToken.Line,CallToken.Column);
    Exit;
   End;
   If (ParamSymbol<>0) And Pipeline.Symbols[ParamSymbol].ByReference And
      Not IRRootAddressable(
       Pipeline.IrStatements[StatementIndex].Arguments[I],
       ArgumentSymbol) Then Begin
    PipelineErrorAt(EK_CODEGEN,'l''argument VAR '+IntToString(I)+
                    ' de '+ProcedureName+' doit etre une variable',
                    CallToken.Line,CallToken.Column);
    Exit;
   End;
  End;
 End
 Else If (ProcedureName='INC') Or (ProcedureName='DEC') Then Begin
  If (ArgCount<1) Or (ArgCount>2) Then Begin
   PipelineErrorAt(EK_CODEGEN,ProcedureName+
                   ' attend un ou deux arguments, obtenu '+
                   IntToString(ArgCount),CallToken.Line,CallToken.Column);
   Exit;
  End;
  If Not IRRootAddressable(
     Pipeline.IrStatements[StatementIndex].Arguments[1],
     ArgumentSymbol) Then Begin
   PipelineErrorAt(EK_CODEGEN,ProcedureName+
                   ': le premier argument doit etre une variable',
                   CallToken.Line,CallToken.Column);
   Exit;
  End;
  If Not IsNumericScalar(Pipeline.Symbols[ArgumentSymbol].ScalarType) Then Begin
   PipelineErrorAt(EK_CODEGEN,ProcedureName+
                   ': le premier argument doit etre entier',
                   CallToken.Line,CallToken.Column);
   Exit;
  End;
  If (ArgCount=2) And Not IsNumericScalar(
     Pipeline.IrNodes[Pipeline.IrStatements[StatementIndex].
      Arguments[2]].ScalarType) Then Begin
   PipelineErrorAt(EK_CODEGEN,ProcedureName+
                   ': le second argument doit etre entier',
                   CallToken.Line,CallToken.Column);
   Exit;
  End;
 End
 Else If (ProcedureName='ORD') Or (ProcedureName='CHR') Or
         (ProcedureName='ODD') Or (ProcedureName='ABS') Then Begin
  PipelineErrorAt(EK_CODEGEN,ProcedureName+
                  ' est une fonction et doit etre utilisee dans une expression',
                  CallToken.Line,CallToken.Column);
  Exit;
 End;
End;

Procedure BuildBasicStatements(ScopeIndex:Integer);
Const
 MAX_CONTROL_DEPTH = 256;
Var
 I:Integer;
 BlockDepth:Integer;
 ControlDepth:Integer;
 ActiveControlDepth:Integer;
 DeferredControlDepth:Integer;
 NextControlId:Integer;
 ControlStack:Array[1..MAX_CONTROL_DEPTH] Of TKeyword;
 ControlIdStack:Array[1..MAX_CONTROL_DEPTH] Of Integer;
 AtStatementStart:Boolean;
 Token:TToken;
 NextToken:TToken;
 Top:TKeyword;
 CurrentControlId:Integer;
 RootNode:Integer;
 ResultType:TScalarType;
 StartRoot:Integer;
 EndRoot:Integer;
 StepRoot:Integer;
 StartType:TScalarType;
 EndType:TScalarType;
 StepType:TScalarType;
 LoopSymbol:Integer;
 LoopToken:TToken;
Begin
 If Pipeline.Scopes[ScopeIndex].BodyStart=0 Then Exit;
 Pipeline.IrTokenLimit:=Pipeline.Scopes[ScopeIndex].BodyEnd;
 Pipeline.IrTokenIndex:=Pipeline.Scopes[ScopeIndex].BodyStart;
 BlockDepth:=0;
 ControlDepth:=0;
 ActiveControlDepth:=0;
 DeferredControlDepth:=0;
 NextControlId:=0;
 AtStatementStart:=True;
 While (Pipeline.IrTokenIndex<=Pipeline.IrTokenLimit) And
       (Pipeline.ErrorCount=0) Do Begin
  I:=Pipeline.IrTokenIndex;
  Token:=IRToken;
  If Token.Kind=TK_KEYWORD Then Begin
   If Token.Keyword=KW_BEGIN Then Begin
    AddIRStatement(IR_STMT_BLOCK_BEGIN,ScopeIndex,BlockDepth,
                   DeferredControlDepth,0,0,0,'',
                   Token.Line,Token.Column);
    Inc(BlockDepth);
    If ControlDepth<MAX_CONTROL_DEPTH Then Begin
     Inc(ControlDepth);
     ControlStack[ControlDepth]:=KW_BEGIN;
     ControlIdStack[ControlDepth]:=0;
    End;
    IRAdvance;
    AtStatementStart:=True;
    Continue;
   End;
   If Token.Keyword=KW_RETURN Then Begin
    If Pipeline.Scopes[ScopeIndex].Kind<>SCOPE_PROCEDURE Then Begin
     PipelineErrorAt(EK_CODEGEN,'RETURN hors procedure',
                     Token.Line,Token.Column);
     Exit;
    End;
    AddIRStatement(IR_STMT_RETURN,ScopeIndex,BlockDepth,
                   DeferredControlDepth,0,0,0,'',
                   Token.Line,Token.Column);
    IRAdvance;
    AtStatementStart:=False;
    Continue;
   End;
   If Token.Keyword=KW_IF Then Begin
    Inc(NextControlId);
    CurrentControlId:=NextControlId;
    IRAdvance;
    If Not ParseStatementExpression(ScopeIndex,RootNode,ResultType) Then Exit;
    If ResultType<>SCALAR_BOOLEAN Then Begin
     PipelineErrorAt(EK_CODEGEN,'IF exige une expression BOOLEAN',
                     Token.Line,Token.Column);
     Exit;
    End;
    If Not IRIsKeyword(KW_THEN) Then Begin
     PipelineErrorAt(EK_CODEGEN,'mot-cle THEN attendu apres IF',
                     IRToken.Line,IRToken.Column);
     Exit;
    End;
    AddIRIfStatement(IR_STMT_IF_BEGIN,ScopeIndex,BlockDepth,
                     DeferredControlDepth,CurrentControlId,RootNode,
                     Token.Line,Token.Column);
    If ControlDepth<MAX_CONTROL_DEPTH Then Begin
     Inc(ControlDepth);
     ControlStack[ControlDepth]:=KW_IF;
     ControlIdStack[ControlDepth]:=CurrentControlId;
    End;
    Inc(ActiveControlDepth);
    IRAdvance;
    AtStatementStart:=True;
    Continue;
   End;
   If Token.Keyword=KW_WHILE Then Begin
    Inc(NextControlId);
    CurrentControlId:=NextControlId;
    IRAdvance;
    If Not ParseStatementExpression(ScopeIndex,RootNode,ResultType) Then Exit;
    If ResultType<>SCALAR_BOOLEAN Then Begin
     PipelineErrorAt(EK_CODEGEN,'WHILE exige une expression BOOLEAN',
                     Token.Line,Token.Column);
     Exit;
    End;
    If Not IRIsKeyword(KW_DO) Then Begin
     PipelineErrorAt(EK_CODEGEN,'mot-cle DO attendu apres WHILE',
                     IRToken.Line,IRToken.Column);
     Exit;
    End;
    AddIRLoopStatement(IR_STMT_WHILE_BEGIN,ScopeIndex,BlockDepth,
                       DeferredControlDepth,CurrentControlId,RootNode,
                       Token.Line,Token.Column);
    If ControlDepth<MAX_CONTROL_DEPTH Then Begin
     Inc(ControlDepth);
     ControlStack[ControlDepth]:=KW_WHILE;
     ControlIdStack[ControlDepth]:=CurrentControlId;
    End;
    Inc(ActiveControlDepth);
    IRAdvance;
    AtStatementStart:=True;
    Continue;
   End;
   If Token.Keyword=KW_FOR Then Begin
    Inc(NextControlId);
    CurrentControlId:=NextControlId;
    IRAdvance;
    LoopToken:=IRToken;
    If LoopToken.Kind<>TK_IDENTIFIER Then Begin
     PipelineErrorAt(EK_CODEGEN,'variable attendue apres FOR',
                     LoopToken.Line,LoopToken.Column);
     Exit;
    End;
    LoopSymbol:=FindVisibleSymbol(LoopToken.Text,ScopeIndex);
    If (LoopSymbol=0) Or
       ((Pipeline.Symbols[LoopSymbol].Kind<>SYM_VARIABLE) And
        (Pipeline.Symbols[LoopSymbol].Kind<>SYM_PARAMETER)) Or
       Not IsNumericScalar(Pipeline.Symbols[LoopSymbol].ScalarType) Then Begin
     PipelineErrorAt(EK_CODEGEN,'variable de controle FOR invalide: '+
                     LoopToken.Text,LoopToken.Line,LoopToken.Column);
     Exit;
    End;
    IRAdvance;
    If Not IRAcceptSymbol(':=') Then Begin
     PipelineErrorAt(EK_CODEGEN,'symbole ":=" attendu dans FOR',
                     IRToken.Line,IRToken.Column);
     Exit;
    End;
    If Not ParseStatementExpression(ScopeIndex,StartRoot,StartType) Then Exit;
    If Not IsNumericScalar(StartType) Then Begin
     PipelineErrorAt(EK_CODEGEN,'debut de FOR doit etre entier',
                     LoopToken.Line,LoopToken.Column);
     Exit;
    End;
    If Not IRIsKeyword(KW_TO) Then Begin
     PipelineErrorAt(EK_CODEGEN,'mot-cle TO attendu dans FOR',
                     IRToken.Line,IRToken.Column);
     Exit;
    End;
    IRAdvance;
    If Not ParseStatementExpression(ScopeIndex,EndRoot,EndType) Then Exit;
    If Not IsNumericScalar(EndType) Then Begin
     PipelineErrorAt(EK_CODEGEN,'borne finale de FOR doit etre entiere',
                     LoopToken.Line,LoopToken.Column);
     Exit;
    End;
    If IRIsKeyword(KW_BY) Then Begin
     IRAdvance;
     If Not ParseStatementExpression(ScopeIndex,StepRoot,StepType) Then Exit;
     If Not IsNumericScalar(StepType) Then Begin
      PipelineErrorAt(EK_CODEGEN,'pas de FOR doit etre entier',
                      LoopToken.Line,LoopToken.Column);
      Exit;
     End;
     If (Pipeline.IrNodes[StepRoot].Op=IR_EXPR_CONST) And
        (Pipeline.IrNodes[StepRoot].ConstValue.IntegerValue=0) Then Begin
      PipelineErrorAt(EK_CODEGEN,'pas BY nul interdit',
                      Pipeline.IrNodes[StepRoot].Line,
                      Pipeline.IrNodes[StepRoot].Column);
      Exit;
     End;
    End
    Else StepRoot:=AddIRIntegerConstant(1,LoopToken.Line,LoopToken.Column);
    If Not IRIsKeyword(KW_DO) Then Begin
     PipelineErrorAt(EK_CODEGEN,'mot-cle DO attendu dans FOR',
                     IRToken.Line,IRToken.Column);
     Exit;
    End;
    AddIRForStatement(IR_STMT_FOR_BEGIN,ScopeIndex,BlockDepth,
                      DeferredControlDepth,CurrentControlId,LoopSymbol,
                      StartRoot,EndRoot,StepRoot,
                      Token.Line,Token.Column);
    If ControlDepth<MAX_CONTROL_DEPTH Then Begin
     Inc(ControlDepth);
     ControlStack[ControlDepth]:=KW_FOR;
     ControlIdStack[ControlDepth]:=CurrentControlId;
    End;
    Inc(ActiveControlDepth);
    IRAdvance;
    AtStatementStart:=True;
    Continue;
   End;
   If (Token.Keyword=KW_LOOP) Or
      (Token.Keyword=KW_CASE) Or (Token.Keyword=KW_WITH) Then Begin
    If ControlDepth<MAX_CONTROL_DEPTH Then Begin
     Inc(ControlDepth);
     ControlStack[ControlDepth]:=Token.Keyword;
     ControlIdStack[ControlDepth]:=0;
    End;
    Inc(ActiveControlDepth);
    Inc(DeferredControlDepth);
    IRAdvance;
    AtStatementStart:=False;
    Continue;
   End;
   If Token.Keyword=KW_REPEAT Then Begin
    Inc(NextControlId);
    CurrentControlId:=NextControlId;
    AddIRLoopStatement(IR_STMT_REPEAT_BEGIN,ScopeIndex,BlockDepth,
                       DeferredControlDepth,CurrentControlId,0,
                       Token.Line,Token.Column);
    If ControlDepth<MAX_CONTROL_DEPTH Then Begin
     Inc(ControlDepth);
     ControlStack[ControlDepth]:=KW_REPEAT;
     ControlIdStack[ControlDepth]:=CurrentControlId;
    End;
    Inc(ActiveControlDepth);
    IRAdvance;
    AtStatementStart:=True;
    Continue;
   End;
   If Token.Keyword=KW_UNTIL Then Begin
    IRAdvance;
    If (ControlDepth=0) Or
       (ControlStack[ControlDepth]<>KW_REPEAT) Then Begin
     PipelineErrorAt(EK_CODEGEN,'UNTIL sans REPEAT',
                     Token.Line,Token.Column);
     Exit;
    End;
    CurrentControlId:=ControlIdStack[ControlDepth];
    If Not ParseStatementExpression(ScopeIndex,RootNode,ResultType) Then Exit;
    If ResultType<>SCALAR_BOOLEAN Then Begin
     PipelineErrorAt(EK_CODEGEN,'UNTIL exige une expression BOOLEAN',
                     Token.Line,Token.Column);
     Exit;
    End;
    AddIRLoopStatement(IR_STMT_REPEAT_UNTIL,ScopeIndex,BlockDepth,
                       DeferredControlDepth,CurrentControlId,RootNode,
                       Token.Line,Token.Column);
    Dec(ControlDepth);
    If ActiveControlDepth>0 Then Dec(ActiveControlDepth);
    AtStatementStart:=False;
    Continue;
   End;
   If Token.Keyword=KW_END Then Begin
    Top:=KW_NONE;
    If ControlDepth>0 Then Begin
     Top:=ControlStack[ControlDepth];
     CurrentControlId:=ControlIdStack[ControlDepth];
     Dec(ControlDepth);
    End;
    If Top=KW_BEGIN Then Begin
     If BlockDepth>0 Then Dec(BlockDepth);
     AddIRStatement(IR_STMT_BLOCK_END,ScopeIndex,BlockDepth,
                    DeferredControlDepth,0,0,0,'',
                    Token.Line,Token.Column);
    End
    Else If Top=KW_IF Then Begin
     AddIRIfStatement(IR_STMT_IF_END,ScopeIndex,BlockDepth,
                      DeferredControlDepth,CurrentControlId,0,
                      Token.Line,Token.Column);
     If ActiveControlDepth>0 Then Dec(ActiveControlDepth);
    End
    Else If Top=KW_WHILE Then Begin
     AddIRLoopStatement(IR_STMT_WHILE_END,ScopeIndex,BlockDepth,
                        DeferredControlDepth,CurrentControlId,0,
                        Token.Line,Token.Column);
     If ActiveControlDepth>0 Then Dec(ActiveControlDepth);
    End
    Else If Top=KW_FOR Then Begin
     AddIRForStatement(IR_STMT_FOR_END,ScopeIndex,BlockDepth,
                       DeferredControlDepth,CurrentControlId,0,0,0,0,
                       Token.Line,Token.Column);
     If ActiveControlDepth>0 Then Dec(ActiveControlDepth);
    End
    Else If Top<>KW_NONE Then Begin
     If ActiveControlDepth>0 Then Dec(ActiveControlDepth);
     If DeferredControlDepth>0 Then Dec(DeferredControlDepth);
    End;
    IRAdvance;
    AtStatementStart:=False;
    Continue;
   End;
   If (Token.Keyword=KW_THEN) Or (Token.Keyword=KW_DO) Then Begin
    IRAdvance;
    AtStatementStart:=True;
    Continue;
   End;
   If Token.Keyword=KW_ELSIF Then Begin
    IRAdvance;
    If (ControlDepth=0) Or
       (ControlStack[ControlDepth]<>KW_IF) Then Begin
     PipelineErrorAt(EK_CODEGEN,'ELSIF sans IF',
                     Token.Line,Token.Column);
     Exit;
    End;
    CurrentControlId:=ControlIdStack[ControlDepth];
    If Not ParseStatementExpression(ScopeIndex,RootNode,ResultType) Then Exit;
    If ResultType<>SCALAR_BOOLEAN Then Begin
     PipelineErrorAt(EK_CODEGEN,'ELSIF exige une expression BOOLEAN',
                     Token.Line,Token.Column);
     Exit;
    End;
    If Not IRIsKeyword(KW_THEN) Then Begin
     PipelineErrorAt(EK_CODEGEN,'mot-cle THEN attendu apres ELSIF',
                     IRToken.Line,IRToken.Column);
     Exit;
    End;
    AddIRIfStatement(IR_STMT_ELSIF,ScopeIndex,BlockDepth,
                     DeferredControlDepth,CurrentControlId,RootNode,
                     Token.Line,Token.Column);
    IRAdvance;
    AtStatementStart:=True;
    Continue;
   End;
   If Token.Keyword=KW_ELSE Then Begin
    If (ControlDepth=0) Or
       (ControlStack[ControlDepth]<>KW_IF) Then Begin
     PipelineErrorAt(EK_CODEGEN,'ELSE sans IF',
                     Token.Line,Token.Column);
     Exit;
    End;
    CurrentControlId:=ControlIdStack[ControlDepth];
    AddIRIfStatement(IR_STMT_ELSE,ScopeIndex,BlockDepth,
                     DeferredControlDepth,CurrentControlId,0,
                     Token.Line,Token.Column);
    IRAdvance;
    AtStatementStart:=True;
    Continue;
   End;
  End;
  If IRIsSymbol(';') Then Begin
   If AtStatementStart Then
    AddIRStatement(IR_STMT_EMPTY,ScopeIndex,BlockDepth,
                   DeferredControlDepth,0,0,0,'',
                   Token.Line,Token.Column);
   IRAdvance;
   AtStatementStart:=True;
   Continue;
  End;
  If AtStatementStart And (Token.Kind=TK_IDENTIFIER) Then Begin
   NextToken:=Pipeline.Tokens[Pipeline.TokenCount];
   If I<Pipeline.IrTokenLimit Then NextToken:=Pipeline.Tokens[I+1];
   If (NextToken.Kind=TK_SYMBOL) And (NextToken.Text=':=') Then
    BuildAssignmentStatement(ScopeIndex,BlockDepth,DeferredControlDepth)
   Else
    BuildCallStatement(ScopeIndex,BlockDepth,DeferredControlDepth);
   AtStatementStart:=False;
   Continue;
  End;
  IRAdvance;
 End;
End;

Procedure TraceSimpleIR;
Var
 I:Integer;
 J:Integer;
 N:TIRExprNode;
 E:TIRExpression;
 S:TIRStatement;
 Extra:String;
Begin
 WriteLn('IR     : ',Pipeline.IrExpressionCount,' expression(s), ',
         Pipeline.IrNodeCount,' noeud(s), ',
         Pipeline.IrStatementCount,' instruction(s)');
 If Not Options.Verbose Then Exit;
 For I:=1 To Pipeline.IrNodeCount Do Begin
  N:=Pipeline.IrNodes[I];
  Extra:='';
  If N.Op=IR_EXPR_CONST Then Extra:=' '+ConstValueText(N.ConstValue)
  Else If N.Op=IR_EXPR_LOAD Then
   Extra:=' '+Pipeline.Symbols[N.SymbolIndex].Name+
          ' '+SymbolStorageRef(N.SymbolIndex)
  Else Extra:=' left='+IntToString(N.LeftNode)+
              ' right='+IntToString(N.RightNode);
  WriteLn('  N',I,' ',IRExprOpName(N.Op),' ',
          ScalarTypeName(N.ScalarType),Extra,
          ' @ ',N.Line,':',N.Column);
 End;
 For I:=1 To Pipeline.IrExpressionCount Do Begin
  E:=Pipeline.IrExpressions[I];
  WriteLn('  E',I,' ',E.Context,' root=N',E.RootNode,
          ' scope=',E.ScopeIndex,' @ ',E.Line,':',E.Column);
 End;
 For I:=1 To Pipeline.IrStatementCount Do Begin
  S:=Pipeline.IrStatements[I];
  Extra:='';
  If S.Kind=IR_STMT_ASSIGN Then
   Extra:=' '+Pipeline.Symbols[S.TargetSymbol].Name+
          ' <- N'+IntToString(S.ExpressionRoot)
  Else If S.Kind=IR_STMT_CALL Then Begin
   Extra:=' '+S.ProcedureName+'(';
   For J:=1 To S.ArgumentCount Do Begin
    If J>1 Then Extra:=Extra+',';
    Extra:=Extra+'N'+IntToString(S.Arguments[J]);
   End;
   Extra:=Extra+')';
  End
  Else If (S.Kind=IR_STMT_IF_BEGIN) Or
          (S.Kind=IR_STMT_ELSIF) Then
   Extra:=' id='+IntToString(S.ControlId)+
          ' condition=N'+IntToString(S.ExpressionRoot)
  Else If (S.Kind=IR_STMT_ELSE) Or
          (S.Kind=IR_STMT_IF_END) Then
   Extra:=' id='+IntToString(S.ControlId)
  Else If (S.Kind=IR_STMT_WHILE_BEGIN) Or
          (S.Kind=IR_STMT_REPEAT_UNTIL) Then
   Extra:=' id='+IntToString(S.ControlId)+
          ' condition=N'+IntToString(S.ExpressionRoot)
  Else If (S.Kind=IR_STMT_WHILE_END) Or
          (S.Kind=IR_STMT_REPEAT_BEGIN) Then
   Extra:=' id='+IntToString(S.ControlId)
  Else If S.Kind=IR_STMT_FOR_BEGIN Then
   Extra:=' id='+IntToString(S.ControlId)+' var='+
          Pipeline.Symbols[S.TargetSymbol].Name+
          ' start=N'+IntToString(S.ExpressionRoot)+
          ' end=N'+IntToString(S.Arguments[1])+
          ' step=N'+IntToString(S.Arguments[2])
  Else If S.Kind=IR_STMT_FOR_END Then
   Extra:=' id='+IntToString(S.ControlId);
  WriteLn('  S',I,' ',IRStatementKindName(S.Kind),Extra,
          ' depth=',S.BlockDepth,' control=',S.ControlDepth,
          ' scope=',S.ScopeIndex,
          ' @ ',S.Line,':',S.Column);
 End;
End;

Procedure BuildSimpleIR;
Var
 I:Integer;
Begin
 EnterStage(CS_IR);
 Pipeline.IrNodeCount:=0;
 Pipeline.IrExpressionCount:=0;
 Pipeline.IrStatementCount:=0;
 For I:=1 To Pipeline.ScopeCount Do Begin
  CollectScopeExpressions(I);
  If Pipeline.ErrorCount<>0 Then Exit;
  BuildBasicStatements(I);
  If Pipeline.ErrorCount<>0 Then Exit;
 End;
 Pipeline.IrReady:=True;
 FinishStage(CS_IR);
 TraceSimpleIR;
End;

Procedure EmitOptionalAsm;
Begin
 EnterStage(CS_ASM_80386);
 If WriteAsm80386File(Pipeline.AsmName) Then Begin
  Pipeline.AsmReady:=True;
  FinishStage(CS_ASM_80386);
  WriteLn('ASM    : ecrit ',Pipeline.AsmName);
 End;
End;

Procedure WriteObjCoff;
Begin
 EnterStage(CS_OBJ_COFF);
 If WriteCoffI386File(Pipeline.ObjName) Then Begin
  Pipeline.ObjReady:=True;
  FinishStage(CS_OBJ_COFF);
  WriteLn('OBJ    : ecrit ',Pipeline.ObjName);
 End;
End;

Procedure WriteExePe32;
Begin
 EnterStage(CS_EXE_PE32);
 If WriteMinimalPE32Exe(Pipeline.ExeName) Then Begin
  Pipeline.ExeReady:=True;
  FinishStage(CS_EXE_PE32);
  WriteLn('EXE    : ecrit ',Pipeline.ExeName);
 End;
End;

Procedure CompilePipeline(SourceName:String);
Begin
 InitPipeline;
 If Options.Verbose Then TracePipelineLayout;
 If Options.Verbose Then TraceTargetModel;
 WriteLn('Entree : ',Pipeline.SourceName);
 If Pipeline.EmitAsm Then WriteLn('ASM    : ',Pipeline.AsmName)
  Else WriteLn('ASM    : ',Pipeline.AsmName,' (sur demande)');
 WriteLn('OBJ    : ',Pipeline.ObjName);
 If Pipeline.OutputKind=OK_EXE_PE32 Then WriteLn('EXE    : ',Pipeline.ExeName,' (defaut)')
  Else WriteLn('EXE    : ',Pipeline.ExeName,' (non produit avec -c)');
 LoadSource;
 If Pipeline.ErrorCount<>0 Then Exit;
 RunLexer;
 If Pipeline.ErrorCount<>0 Then Exit;
 RunParser;
 If Pipeline.ErrorCount<>0 Then Exit;
 BuildSemanticTables;
 If Pipeline.ErrorCount<>0 Then Exit;
 BuildSimpleIR;
 If Pipeline.ErrorCount<>0 Then Exit;
 If Pipeline.EmitAsm Then Begin
  EmitOptionalAsm;
  If Pipeline.ErrorCount<>0 Then Exit;
 End;
 WriteObjCoff;
 If Pipeline.ErrorCount<>0 Then Exit;
 If Pipeline.StopAfterObj Then Exit;
 WriteExePe32;
End;

BEGIN
 ValidatePortableEnvironment;
 ParseCommandLine;
 CompilePipeline(Options.SourceName);
 If Pipeline.ErrorCount<>0 Then Halt(1);
END.
