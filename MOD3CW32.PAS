{ @author: Sylvain Maltais
  @created: 2026-06-19
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Modula-3 vers assembleur 80386 / Windows 32 bits
  @output: Win32 PE .EXE par defaut, COFF i386 .OBJ sur demande,
           .ASM 80386 optionnel sur demande explicite
  @license: MIT
}

{ TODO MOD3CW32 - Compilateur Modula-3 vers 80386/Win32

  DONE 01 - Definir le pipeline complet:
            source .i3/.m3 -> lexer -> parser -> tables semantiques -> IR
            -> ASM 80386 optionnel -> OBJ COFF i386 -> EXE PE32 par defaut.

  DONE 02 - Ajouter les options de ligne de commande:
            -c pour produire seulement un .OBJ, -S pour produire/conserver
            le .ASM sur demande explicite, -o nom_sortie, --version, -h,
            et acceptation de plusieurs fichiers .i3/.m3 en entree.

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

  DONE 08 - Implementer le lexer Modula-3:
            identificateurs, mots reserves, entiers, reels, chaines et
            caracteres quotes, commentaires imbriques (* *), operateurs
            (:=, <:, .., etc.), ponctuation et EOF.

  DONE 09 - Implementer le parser des interfaces (.i3):
            INTERFACE nom; IMPORT, declarations exportees, END nom.,
            distinction entre fichier .i3 (interface) et .m3 (module).

  DONE 10 - Implementer le parser des modules (.m3):
            MODULE nom EXPORTS interfaces; IMPORT, declarations,
            bloc BEGIN...END nom. et verification de coherence
            entre une interface et son module d'implementation.

  DONE 11 - Implementer IMPORT / FROM...IMPORT et la table des unites:
            resolution des interfaces et modules, ordre de compilation,
            detection des cycles et des exports manquants.

  DONE 12 - Definir la table des symboles et les portees:
            portee interface, module, procedure, objet, generique,
            constantes, variables, parametres et detection des doublons.

  DONE 13 - Implementer les types scalaires de base:
            INTEGER, CARDINAL, BOOLEAN, CHAR, REAL/LONGREAL si vise, TEXT,
            compatibilite et conversions implicites/explicites.

  DONE 14 - Implementer les types composes:
            ARRAY (bornes fixes et ouvertes), RECORD, REF (pointeurs, NEW,
            allocation) et types opaques (revelation partielle/complete).

  DONE 15 - Implementer CONST et les litteraux:
            constantes entieres, reelles, booleennes, caracteres, chaines,
            evaluation constante simple et references dans les expressions.

  DONE 16 - Implementer VAR et l'allocation des donnees:
            allocation globale (.data/.bss) et locale (offsets EBP),
            initialisation implicite a zero et segment de donnees statiques.

  DONE 17 - Implementer les expressions et operateurs:
            priorites Modula-3, arithmetique, comparaisons, booleens
            (AND/OR/NOT court-circuit) et evaluation en IR typee.

  DONE 18 - Implementer les instructions de base et le controle:
            affectation :=, appel de procedure, IF/ELSIF/ELSE, CASE,
            blocs imbriques et instruction vide.

  DONE 19 - Implementer les boucles:
            LOOP...EXIT...END, WHILE, REPEAT, FOR, avec gestion correcte
            de EXIT et des bornes.

  DONE 20 - Implementer les procedures et leurs parametres:
            PROCEDURE, parametres VALUE/VAR/READONLY, valeurs de retour,
            recursion et verification d'arite et de types.

  DONE 21 - Implementer les objets:
            OBJECT types, heritage, champs et methodes, OVERRIDE, NEW,
            et appels de methodes virtuelles via table de methodes.

  TODO 22 - Implementer les exceptions:
            EXCEPTION, RAISE, TRY...EXCEPT...FINALLY, propagation et
            nettoyage de pile lors du deroulement.

  TODO 23 - Implementer les generiques:
            GENERIC INTERFACE/MODULE, parametres generiques, instanciation
            (nom AS generic(params)) et generation du code instancie.

  DONE 24 - Implementer le runtime et les E/S minimales:
            support minimal de IO/Stdio (Put, etc.), fonctions mathematiques
            de base necessaires aux samples et demarrage/arret du runtime.

  TODO 25 - Ajouter une suite de validation SAMPLES\MODULA3 et stabiliser
            la compatibilite Turbo Pascal/Free Pascal:
            compiler tous les .i3/.m3 en .EXE par defaut, verifier -c et -S,
            executer hello.m3 et comparer les sorties, types Pascal
            portables, chemins Windows, E/S binaires et documentation d'usage.
}

Program MOD3CW32;

{$IFDEF FPC}
 {$H-}
{$ENDIF}
{$I-}

Const
 MOD3CW32_VERSION   = '1.0';
 MOD3_INTERFACE_EXT = '.i3';
 MOD3_MODULE_EXT     = '.m3';
 MOD3_ASM_EXT        = '.asm';
 MOD3_OBJ_EXT        = '.obj';
 MOD3_EXE_EXT        = '.exe';
 MOD3_MAX_SOURCES    = 64;
 MOD3_MAX_PATH       = 250;
 MOD3_MAX_SOURCE_LINES = 2048;
 MOD3_MAX_TOKENS       = 8192;
 MOD3_MAX_IMPORTS      = 64;
 MOD3_MAX_EXPORTS      = 16;
 MOD3_MAX_SCOPES       = 256;
 MOD3_MAX_SYMBOLS      = 2048;
 MOD3_MAX_TYPES        = 512;
 MOD3_MAX_IR_NODES     = 8192;
 MOD3_MAX_IR_ARGUMENTS = 16384;
 MOD3_MAX_IR_ROOTS     = 2048;
 MOD3_MAX_STATEMENTS   = 4096;
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
 MOD3_ENTRY_LABEL     = '_MOD3START';
 MOD3_INTERNAL_PREFIX = '_M3L_';
 MOD3_DATA_PREFIX     = '_M3D_';
 MOD3_RUNTIME_PREFIX  = '_M3RT_';
 COFF_MACHINE_I386       = $014C;
 COFF_FILE_HEADER_SIZE   = 20;
 COFF_SECTION_HDR_SIZE   = 40;
 COFF_SYMBOL_SIZE        = 18;
 COFF_RELOC_SIZE         = 10;
 COFF_REL_I386_DIR32     = $0006;
 COFF_REL_I386_REL32     = $0014;
 COFF_SYM_CLASS_EXTERNAL = 2;
 COFF_SYM_CLASS_STATIC   = 3;
 COFF_TEXT_FLAGS_LO      = $0020;
 COFF_TEXT_FLAGS_HI      = $6050;
 COFF_DATA_FLAGS_LO      = $0040;
 COFF_DATA_FLAGS_HI      = $C030;
 COFF_BSS_FLAGS_LO       = $0080;
 COFF_BSS_FLAGS_HI       = $C030;
 COFF_IDATA_FLAGS_LO     = $0040;
 COFF_IDATA_FLAGS_HI     = $C000;
 PE_DOS_LFANEW           = $0080;
 PE_TEXT_RVA             = $1000;
 PE_IDATA_RVA            = $2000;
 PE_TEXT_RAW_PTR         = $0200;
 PE_IDATA_RAW_PTR        = $0400;
 PE_TEXT_RAW_SIZE        = $0200;
 PE_IDATA_RAW_SIZE       = $0200;
 PE_SIZE_OF_HEADERS      = $0200;
 PE_SIZE_OF_IMAGE        = $3000;
 PE_OPT_HEADER_SIZE      = 224;
 PE_SUBSYSTEM_CONSOLE    = 3;
 PE_FILE_CHAR_LO         = $0102;

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
  TK_KEYWORD,
  TK_INTEGER,
  TK_REAL,
  TK_STRING,
  TK_CHAR,
  TK_SYMBOL
 );

 TKeyword = (
  KW_NONE,
  KW_AND,
  KW_ANY,
  KW_ARRAY,
  KW_AS,
  KW_BEGIN,
  KW_BITS,
  KW_BRANDED,
  KW_BY,
  KW_CASE,
  KW_CONST,
  KW_DIV,
  KW_DO,
  KW_ELSE,
  KW_ELSIF,
  KW_END,
  KW_EVAL,
  KW_EXCEPT,
  KW_EXCEPTION,
  KW_EXIT,
  KW_EXPORTS,
  KW_EXTENDS,
  KW_FINALLY,
  KW_FOR,
  KW_FROM,
  KW_GENERIC,
  KW_IF,
  KW_IMPORT,
  KW_IN,
  KW_INTERFACE,
  KW_LOCK,
  KW_LOOP,
  KW_METHODS,
  KW_MOD,
  KW_MODULE,
  KW_NOT,
  KW_OBJECT,
  KW_OF,
  KW_OR,
  KW_OVERRIDES,
  KW_PROCEDURE,
  KW_RAISE,
  KW_RAISES,
  KW_READONLY,
  KW_RECORD,
  KW_REF,
  KW_REPEAT,
  KW_RETURN,
  KW_REVEAL,
  KW_SET,
  KW_THEN,
  KW_TO,
  KW_TRY,
  KW_TYPE,
  KW_TYPECASE,
  KW_UNSAFE,
  KW_UNTIL,
  KW_UNTRACED,
  KW_VALUE,
  KW_VAR,
  KW_WHILE,
  KW_WITH
 );

 TToken = Record
  Kind       : TTokenKind;
  Keyword    : TKeyword;
  Text       : String[127];
  IntegerVal : LongInt;
  RealVal    : Extended;
  Line       : Integer;
  Column     : Integer;
 End;

 TUnitImport = Record
  Name          : String[63];
  FromImport    : Boolean;
  SelectedNames : String[127];
  Line          : Integer;
  Column        : Integer;
 End;

 TExportItem = Record
  Name   : String[63];
  Line   : Integer;
  Column : Integer;
 End;

 TUnitKind = (
  UK_INTERFACE,
  UK_MODULE
 );

 TScopeKind = (
  SCOPE_UNIVERSE,
  SCOPE_INTERFACE,
  SCOPE_MODULE,
  SCOPE_PROCEDURE,
  SCOPE_OBJECT,
  SCOPE_GENERIC
 );

 TSymbolKind = (
  SYM_IMPORT,
  SYM_CONST,
  SYM_TYPE,
  SYM_VAR,
  SYM_PARAM,
  SYM_PROCEDURE,
  SYM_FIELD,
  SYM_METHOD,
  SYM_EXCEPTION,
  SYM_GENERIC_PARAM
 );

 TTypeKind = (
  TYPE_ERROR,
  TYPE_INTEGER,
  TYPE_CARDINAL,
  TYPE_BOOLEAN,
  TYPE_CHAR,
  TYPE_REAL,
  TYPE_LONGREAL,
  TYPE_TEXT,
  TYPE_NIL,
  TYPE_ALIAS,
  TYPE_SUBRANGE,
  TYPE_ARRAY,
  TYPE_RECORD,
  TYPE_REF,
  TYPE_OPAQUE,
  TYPE_OBJECT,
  TYPE_COMPOSITE
 );

 TSemanticType = Record
  Name       : String[63];
  Kind       : TTypeKind;
  Size       : Integer;
  Align      : Integer;
  BaseType   : Integer;
  ElementType: Integer;
  LowBound   : LongInt;
  HighBound  : LongInt;
  OpenArray  : Boolean;
  FieldScope : Integer;
  Branded    : Boolean;
  Untraced   : Boolean;
  Revealed   : Boolean;
  InstanceSize: Integer;
  TypeCode    : Integer;
  MethodCount : Integer;
  Line       : Integer;
  Column     : Integer;
 End;

 TConstKind = (
  CONST_INVALID,
  CONST_INTEGER,
  CONST_REAL,
  CONST_BOOLEAN,
  CONST_CHAR,
  CONST_TEXT,
  CONST_NIL
 );

 TConstValue = Record
  Kind       : TConstKind;
  TypeIndex  : Integer;
  IntegerVal : LongInt;
  RealVal    : Extended;
  TextVal    : String[255];
  Valid      : Boolean;
 End;

 TStorageKind = (
  STORAGE_NONE,
  STORAGE_GLOBAL_DATA,
  STORAGE_GLOBAL_BSS,
  STORAGE_LOCAL,
  STORAGE_PARAMETER,
  STORAGE_FIELD
 );

 TParameterMode = (
  PARAM_VALUE,
  PARAM_VAR,
  PARAM_READONLY
 );

 TIRKind = (
  IR_INVALID,
  IR_LITERAL,
  IR_SYMBOL,
  IR_CALL,
  IR_INDEX,
  IR_FIELD,
  IR_DEREF,
  IR_UNARY,
  IR_BINARY,
  IR_COMPARE,
  IR_AND_SHORT,
  IR_OR_SHORT
 );

 TIRNode = Record
  Kind        : TIRKind;
  TypeIndex   : Integer;
  Left        : Integer;
  Right       : Integer;
  SymbolIndex : Integer;
  OperatorText: String[8];
  Text        : String[127];
  IntegerVal  : LongInt;
  RealVal     : Extended;
  Line        : Integer;
  Column      : Integer;
  TrueLabel   : Integer;
  FalseLabel  : Integer;
  FirstArg    : Integer;
  ArgCount    : Integer;
  Receiver    : Integer;
  VirtualSlot : Integer;
 End;

 TIRRootKind = (
  IR_ROOT_ASSIGN,
  IR_ROOT_RETURN,
  IR_ROOT_CONDITION,
  IR_ROOT_EXPRESSION
 );

 TIRRoot = Record
  Kind       : TIRRootKind;
  NodeIndex  : Integer;
  ScopeIndex : Integer;
  TargetType : Integer;
  Line       : Integer;
  Column     : Integer;
 End;

 TIRArgumentList = Array[0..63] Of Integer;

 TStatementKind = (
  ST_EMPTY,
  ST_ASSIGN,
  ST_CALL,
  ST_BLOCK_BEGIN,
  ST_BLOCK_END,
  ST_IF,
  ST_ELSIF,
  ST_ELSE,
  ST_CASE,
  ST_CASE_ARM,
  ST_CASE_ELSE,
  ST_RETURN,
  ST_WHILE,
  ST_FOR,
  ST_LOOP,
  ST_REPEAT,
  ST_UNTIL,
  ST_EXIT
 );

 TStatementIR = Record
  Kind          : TStatementKind;
  ScopeIndex    : Integer;
  ExpressionNode: Integer;
  BoundNode     : Integer;
  StepNode      : Integer;
  TargetNode    : Integer;
  ParentIndex   : Integer;
  StartLabel    : Integer;
  FalseLabel    : Integer;
  ContinueLabel : Integer;
  EndLabel      : Integer;
  CaseLow       : LongInt;
  CaseHigh      : LongInt;
  HasCaseRange  : Boolean;
  Line          : Integer;
  Column        : Integer;
 End;

 TScope = Record
  Kind        : TScopeKind;
  Parent      : Integer;
  Level       : Integer;
 OwnerName   : String[63];
 FirstSymbol : Integer;
  SymbolCount : Integer;
  StartToken  : Integer;
  EndToken    : Integer;
  FrameSize   : Integer;
  TemplateKind: TUnitKind;
 End;

 TSemanticSymbol = Record
  Name       : String[63];
  Kind       : TSymbolKind;
  ScopeIndex : Integer;
  NextSymbol : Integer;
  Line       : Integer;
  Column     : Integer;
  TypeIndex  : Integer;
  Offset     : Integer;
  Size       : Integer;
  Storage    : TStorageKind;
  AsmLabel   : String[127];
  HasInitializer:Boolean;
  ConstValue : TConstValue;
  ParamMode  : TParameterMode;
  ProcScope  : Integer;
  MethodImpl : Integer;
 End;

 TCompilationUnit = Record
  Name       : String[63];
  Kind       : TUnitKind;
  SourceName : String;
  DepCount   : Integer;
  DepUnit    : Array[1..MOD3_MAX_IMPORTS] Of Integer;
  Visiting   : Boolean;
  Visited    : Boolean;
 End;

 TCompilerOptions = Record
  SourceNames : Array[1..MOD3_MAX_SOURCES] Of String;
  SourceCount : Integer;
  OutputName  : String;
  OutputKind  : TOutputKind;
  EmitAsm     : Boolean;
  Verbose     : Boolean;
 End;

 TPipelineState = Record
  SourceName    : String;
  ModuleName    : String;
  AsmName       : String;
  ObjName       : String;
  ExeName       : String;
  CurrentStage  : TCompileStage;
  LastCompleted : TCompileStage;
  OutputKind    : TOutputKind;
  EmitAsm       : Boolean;
  StopAfterObj  : Boolean;
  Target        : TTargetModel;
  AsmReady      : Boolean;
  ObjReady      : Boolean;
  ExeReady      : Boolean;
  ErrorCount    : Integer;
  ErrorKind     : TErrorKind;
  ErrorFile     : String;
  ErrorLine     : LongInt;
  ErrorColumn   : LongInt;
  ErrorStage    : TCompileStage;
  ErrorSnippet  : String;
  ErrorMessage  : String;
  SourceLines     : LongInt;
  SourceBytes     : LongInt;
  SourceLoaded    : Boolean;
  StoredLineCount : Integer;
  SourceText      : Array[1..MOD3_MAX_SOURCE_LINES] Of String[255];
  LexerLine       : Integer;
  LexerColumn     : Integer;
  CommentCount    : Integer;
  TokenCount      : Integer;
  Tokens          : Array[1..MOD3_MAX_TOKENS] Of TToken;
  Lexed           : Boolean;
  ParserIndex     : Integer;
  ImportCount     : Integer;
  Imports         : Array[1..MOD3_MAX_IMPORTS] Of TUnitImport;
  ConstDeclCount  : Integer;
  TypeDeclCount   : Integer;
  VarDeclCount    : Integer;
  ProcedureCount  : Integer;
  ExceptionDeclCount : Integer;
  StatementCount  : Integer;
  ExportCount     : Integer;
  ExportItems     : Array[1..MOD3_MAX_EXPORTS] Of TExportItem;
  Parsed          : Boolean;
 End;

Var
 Options          : TCompilerOptions;
 Pipeline         : TPipelineState;
 TotalErrors      : Integer;
 SourceIndex      : Integer;
 Units            : Array[1..MOD3_MAX_SOURCES] Of TCompilationUnit;
 UnitCount        : Integer;
 CompileOrder     : Array[1..MOD3_MAX_SOURCES] Of Integer;
 CompileOrderCount: Integer;
 PreScanErrorCount: Integer;
 QuietDiagnostics : Boolean;
 HasImportCycle   : Boolean;
 SemanticScopes   : Array[1..MOD3_MAX_SCOPES] Of TScope;
 SemanticSymbols  : Array[1..MOD3_MAX_SYMBOLS] Of TSemanticSymbol;
 SemanticScopeCount : Integer;
 SemanticSymbolCount: Integer;
 SemanticIndex      : Integer;
 SemanticTypes      : Array[1..MOD3_MAX_TYPES] Of TSemanticType;
 SemanticTypeCount  : Integer;
 TypeInteger        : Integer;
 TypeCardinal       : Integer;
 TypeBoolean        : Integer;
 TypeChar           : Integer;
 TypeReal           : Integer;
 TypeLongReal       : Integer;
 TypeText           : Integer;
 TypeNil            : Integer;
 TypeRoot           : Integer;
 IRNodes            : Array[1..MOD3_MAX_IR_NODES] Of TIRNode;
 IRNodeCount        : Integer;
 IRArguments        : Array[1..MOD3_MAX_IR_ARGUMENTS] Of Integer;
 IRArgumentCount    : Integer;
 IRRoots            : Array[1..MOD3_MAX_IR_ROOTS] Of TIRRoot;
 IRRootCount        : Integer;
 IRTokenIndex       : Integer;
 IRCurrentScope     : Integer;
 IRLabelCounter     : Integer;
 StatementIR        : Array[1..MOD3_MAX_STATEMENTS] Of TStatementIR;
 StatementCount     : Integer;

Function UpperStr(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do S[I]:=UpCase(S[I]);
 UpperStr:=S;
End;

Function HasSwitchPrefix(S:String):Boolean;
Begin
 HasSwitchPrefix:=(Length(S)>0) And ((S[1]='-') Or (S[1]='/'));
End;

Function IsModula3Source(FileName:String):Boolean;
Var
 Ext:String;
Begin
 If Length(FileName)<3 Then Begin
  IsModula3Source:=False;
  Exit;
 End;
 Ext:=UpperStr(Copy(FileName,Length(FileName)-2,3));
 IsModula3Source:=(Ext='.I3') Or (Ext='.M3');
End;

Function IsInterfaceFile(FileName:String):Boolean;
Begin
 If Length(FileName)<3 Then Begin
  IsInterfaceFile:=False;
  Exit;
 End;
 IsInterfaceFile:=UpperStr(Copy(FileName,Length(FileName)-2,3))='.I3';
End;

Function IsRuntimeInterface(Name:String):Boolean;
Var
 U:String;
Begin
 U:=UpperStr(Name);
 IsRuntimeInterface:=(U='WR') Or (U='FMT') Or (U='TEXT') Or
                     (U='RD') Or (U='STDIO') Or (U='MATH');
End;

Procedure ValidatePathLength(PathName,Description:String);
Begin
 If Length(PathName)>MOD3_MAX_PATH Then Begin
  WriteLn('Erreur: ',Description,' depasse ',MOD3_MAX_PATH,' caracteres.');
  Halt(1);
 End;
End;

Function IntToString(N:LongInt):String;
Var
 S:String;
Begin
 Str(N,S);
 IntToString:=S;
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
 Target.EntryLabel:=MOD3_ENTRY_LABEL;
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
 WriteLn('Entree : ',Pipeline.Target.EntryLabel);
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

Function StageName(Stage:TCompileStage):String;
Begin
 Case Stage Of
  CS_LOAD_SOURCE    : StageName:='source .i3/.m3';
  CS_LEXER          : StageName:='lexer';
  CS_PARSER         : StageName:='parser';
  CS_SEMANTIC_TABLES: StageName:='tables semantiques';
  CS_IR             : StageName:='IR';
  CS_ASM_80386      : StageName:='ASM 80386';
  CS_OBJ_COFF       : StageName:='OBJ COFF i386';
  CS_EXE_PE32       : StageName:='EXE PE32';
  Else StageName:='etape inconnue';
 End;
End;

Function TokenKindName(Kind:TTokenKind):String;
Begin
 Case Kind Of
  TK_EOF       : TokenKindName:='EOF';
  TK_IDENTIFIER: TokenKindName:='IDENT';
  TK_KEYWORD   : TokenKindName:='KEYWORD';
  TK_INTEGER   : TokenKindName:='INTEGER';
  TK_REAL      : TokenKindName:='REAL';
  TK_STRING    : TokenKindName:='STRING';
  TK_CHAR      : TokenKindName:='CHAR';
  TK_SYMBOL    : TokenKindName:='SYMBOL';
  Else TokenKindName:='?';
 End;
End;

Function KeywordName(Keyword:TKeyword):String;
Begin
 Case Keyword Of
  KW_AND       : KeywordName:='AND';
  KW_ANY       : KeywordName:='ANY';
  KW_ARRAY     : KeywordName:='ARRAY';
  KW_AS        : KeywordName:='AS';
  KW_BEGIN     : KeywordName:='BEGIN';
  KW_BITS      : KeywordName:='BITS';
  KW_BRANDED   : KeywordName:='BRANDED';
  KW_BY        : KeywordName:='BY';
  KW_CASE      : KeywordName:='CASE';
  KW_CONST     : KeywordName:='CONST';
  KW_DIV       : KeywordName:='DIV';
  KW_DO        : KeywordName:='DO';
  KW_ELSE      : KeywordName:='ELSE';
  KW_ELSIF     : KeywordName:='ELSIF';
  KW_END       : KeywordName:='END';
  KW_EVAL      : KeywordName:='EVAL';
  KW_EXCEPT    : KeywordName:='EXCEPT';
  KW_EXCEPTION : KeywordName:='EXCEPTION';
  KW_EXIT      : KeywordName:='EXIT';
  KW_EXPORTS   : KeywordName:='EXPORTS';
  KW_EXTENDS   : KeywordName:='EXTENDS';
  KW_FINALLY   : KeywordName:='FINALLY';
  KW_FOR       : KeywordName:='FOR';
  KW_FROM      : KeywordName:='FROM';
  KW_GENERIC   : KeywordName:='GENERIC';
  KW_IF        : KeywordName:='IF';
  KW_IMPORT    : KeywordName:='IMPORT';
  KW_IN        : KeywordName:='IN';
  KW_INTERFACE : KeywordName:='INTERFACE';
  KW_LOCK      : KeywordName:='LOCK';
  KW_LOOP      : KeywordName:='LOOP';
  KW_METHODS   : KeywordName:='METHODS';
  KW_MOD       : KeywordName:='MOD';
  KW_MODULE    : KeywordName:='MODULE';
  KW_NOT       : KeywordName:='NOT';
  KW_OBJECT    : KeywordName:='OBJECT';
  KW_OF        : KeywordName:='OF';
  KW_OR        : KeywordName:='OR';
  KW_OVERRIDES : KeywordName:='OVERRIDES';
  KW_PROCEDURE : KeywordName:='PROCEDURE';
  KW_RAISE     : KeywordName:='RAISE';
  KW_RAISES    : KeywordName:='RAISES';
  KW_READONLY  : KeywordName:='READONLY';
  KW_RECORD    : KeywordName:='RECORD';
  KW_REF       : KeywordName:='REF';
  KW_REPEAT    : KeywordName:='REPEAT';
  KW_RETURN    : KeywordName:='RETURN';
  KW_REVEAL    : KeywordName:='REVEAL';
  KW_SET       : KeywordName:='SET';
  KW_THEN      : KeywordName:='THEN';
  KW_TO        : KeywordName:='TO';
  KW_TRY       : KeywordName:='TRY';
  KW_TYPE      : KeywordName:='TYPE';
  KW_TYPECASE  : KeywordName:='TYPECASE';
  KW_UNSAFE    : KeywordName:='UNSAFE';
  KW_UNTIL     : KeywordName:='UNTIL';
  KW_UNTRACED  : KeywordName:='UNTRACED';
  KW_VALUE     : KeywordName:='VALUE';
  KW_VAR       : KeywordName:='VAR';
  KW_WHILE     : KeywordName:='WHILE';
  KW_WITH      : KeywordName:='WITH';
  Else KeywordName:='';
 End;
End;

Function FindKeyword(S:String):TKeyword;
Begin
 S:=UpperStr(S);
 If S='AND' Then FindKeyword:=KW_AND
 Else If S='ANY' Then FindKeyword:=KW_ANY
 Else If S='ARRAY' Then FindKeyword:=KW_ARRAY
 Else If S='AS' Then FindKeyword:=KW_AS
 Else If S='BEGIN' Then FindKeyword:=KW_BEGIN
 Else If S='BITS' Then FindKeyword:=KW_BITS
 Else If S='BRANDED' Then FindKeyword:=KW_BRANDED
 Else If S='BY' Then FindKeyword:=KW_BY
 Else If S='CASE' Then FindKeyword:=KW_CASE
 Else If S='CONST' Then FindKeyword:=KW_CONST
 Else If S='DIV' Then FindKeyword:=KW_DIV
 Else If S='DO' Then FindKeyword:=KW_DO
 Else If S='ELSE' Then FindKeyword:=KW_ELSE
 Else If S='ELSIF' Then FindKeyword:=KW_ELSIF
 Else If S='END' Then FindKeyword:=KW_END
 Else If S='EVAL' Then FindKeyword:=KW_EVAL
 Else If S='EXCEPT' Then FindKeyword:=KW_EXCEPT
 Else If S='EXCEPTION' Then FindKeyword:=KW_EXCEPTION
 Else If S='EXIT' Then FindKeyword:=KW_EXIT
 Else If S='EXPORTS' Then FindKeyword:=KW_EXPORTS
 Else If S='EXTENDS' Then FindKeyword:=KW_EXTENDS
 Else If S='FINALLY' Then FindKeyword:=KW_FINALLY
 Else If S='FOR' Then FindKeyword:=KW_FOR
 Else If S='FROM' Then FindKeyword:=KW_FROM
 Else If S='GENERIC' Then FindKeyword:=KW_GENERIC
 Else If S='IF' Then FindKeyword:=KW_IF
 Else If S='IMPORT' Then FindKeyword:=KW_IMPORT
 Else If S='IN' Then FindKeyword:=KW_IN
 Else If S='INTERFACE' Then FindKeyword:=KW_INTERFACE
 Else If S='LOCK' Then FindKeyword:=KW_LOCK
 Else If S='LOOP' Then FindKeyword:=KW_LOOP
 Else If S='METHODS' Then FindKeyword:=KW_METHODS
 Else If S='MOD' Then FindKeyword:=KW_MOD
 Else If S='MODULE' Then FindKeyword:=KW_MODULE
 Else If S='NOT' Then FindKeyword:=KW_NOT
 Else If S='OBJECT' Then FindKeyword:=KW_OBJECT
 Else If S='OF' Then FindKeyword:=KW_OF
 Else If S='OR' Then FindKeyword:=KW_OR
 Else If S='OVERRIDES' Then FindKeyword:=KW_OVERRIDES
 Else If S='PROCEDURE' Then FindKeyword:=KW_PROCEDURE
 Else If S='RAISE' Then FindKeyword:=KW_RAISE
 Else If S='RAISES' Then FindKeyword:=KW_RAISES
 Else If S='READONLY' Then FindKeyword:=KW_READONLY
 Else If S='RECORD' Then FindKeyword:=KW_RECORD
 Else If S='REF' Then FindKeyword:=KW_REF
 Else If S='REPEAT' Then FindKeyword:=KW_REPEAT
 Else If S='RETURN' Then FindKeyword:=KW_RETURN
 Else If S='REVEAL' Then FindKeyword:=KW_REVEAL
 Else If S='SET' Then FindKeyword:=KW_SET
 Else If S='THEN' Then FindKeyword:=KW_THEN
 Else If S='TO' Then FindKeyword:=KW_TO
 Else If S='TRY' Then FindKeyword:=KW_TRY
 Else If S='TYPE' Then FindKeyword:=KW_TYPE
 Else If S='TYPECASE' Then FindKeyword:=KW_TYPECASE
 Else If S='UNSAFE' Then FindKeyword:=KW_UNSAFE
 Else If S='UNTIL' Then FindKeyword:=KW_UNTIL
 Else If S='UNTRACED' Then FindKeyword:=KW_UNTRACED
 Else If S='VALUE' Then FindKeyword:=KW_VALUE
 Else If S='VAR' Then FindKeyword:=KW_VAR
 Else If S='WHILE' Then FindKeyword:=KW_WHILE
 Else If S='WITH' Then FindKeyword:=KW_WITH
 Else FindKeyword:=KW_NONE;
End;

Function StripExtension(FileName:String):String;
Var
 I:Integer;
Begin
 StripExtension:=FileName;
 For I:=Length(FileName) DownTo 1 Do Begin
  If FileName[I]='.' Then Begin
   StripExtension:=Copy(FileName,1,I-1);
   Exit;
  End;
  If (FileName[I]='\') Or (FileName[I]='/') Then Exit;
 End;
End;

Function FileBaseName(FileName:String):String;
Var
 I:Integer;
 NoDir:String;
Begin
 NoDir:=FileName;
 For I:=Length(FileName) DownTo 1 Do
  If (FileName[I]='\') Or (FileName[I]='/') Then Begin
   NoDir:=Copy(FileName,I+1,Length(FileName)-I);
   Break;
  End;
 FileBaseName:=StripExtension(NoDir);
End;

Function ChangeExtension(FileName,NewExt:String):String;
Begin
 ChangeExtension:=StripExtension(FileName)+NewExt;
End;

Function EnsureExtension(FileName,DefaultExt:String):String;
Var
 I:Integer;
 HasExt:Boolean;
Begin
 HasExt:=False;
 For I:=Length(FileName) DownTo 1 Do Begin
  If FileName[I]='.' Then Begin
   HasExt:=True;
   Break;
  End;
  If (FileName[I]='\') Or (FileName[I]='/') Then Break;
 End;
 If HasExt Then EnsureExtension:=FileName
 Else EnsureExtension:=FileName+DefaultExt;
End;

Procedure InitPipeline(SourceName:String);
Var
 OutputBase:String;
Begin
 FillChar(Pipeline,SizeOf(Pipeline),0);
 Pipeline.SourceName:=SourceName;
 Pipeline.ModuleName:=StripExtension(SourceName);
 If Options.OutputName<>'' Then OutputBase:=Options.OutputName
 Else OutputBase:=StripExtension(SourceName);
 If Options.OutputKind=OK_OBJ_COFF Then Begin
  Pipeline.ObjName:=EnsureExtension(OutputBase,MOD3_OBJ_EXT);
  Pipeline.ExeName:=ChangeExtension(Pipeline.ObjName,MOD3_EXE_EXT);
  Pipeline.AsmName:=ChangeExtension(Pipeline.ObjName,MOD3_ASM_EXT);
 End
 Else Begin
  Pipeline.ExeName:=EnsureExtension(OutputBase,MOD3_EXE_EXT);
  Pipeline.ObjName:=ChangeExtension(Pipeline.ExeName,MOD3_OBJ_EXT);
  Pipeline.AsmName:=ChangeExtension(Pipeline.ExeName,MOD3_ASM_EXT);
 End;
 Pipeline.CurrentStage:=CS_LOAD_SOURCE;
 Pipeline.LastCompleted:=CS_LOAD_SOURCE;
 Pipeline.OutputKind:=Options.OutputKind;
 Pipeline.EmitAsm:=Options.EmitAsm;
 Pipeline.StopAfterObj:=Options.OutputKind=OK_OBJ_COFF;
 Pipeline.ErrorCount:=0;
 InitTargetModel(Pipeline.Target);
End;

Procedure TracePipelineLayout;
Begin
 WriteLn('MOD3CW32 ',MOD3CW32_VERSION,' pipeline:');
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
 If Options.Verbose Then WriteLn('Etape: ',StageName(Stage));
End;

Procedure FinishStage(Stage:TCompileStage);
Begin
 Pipeline.LastCompleted:=Stage;
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
 R:String;
Begin
 If ColumnNo<1 Then ColumnNo:=1;
 R:='';
 For I:=1 To ColumnNo-1 Do R:=R+' ';
 R:=R+'^';
 CaretLine:=R;
End;

Procedure PrintDiagnostic;
Begin
 If QuietDiagnostics Then Exit;
 WriteLn('MOD3CW32: erreur ',ErrorKindName(Pipeline.ErrorKind),
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
 R:String;
Begin
 R:='';
 For I:=1 To Length(S) Do Begin
  C:=S[I];
  If IsAsmNameChar(C) Then R:=R+C
   Else R:=R+'_';
 End;
 If R='' Then R:='NONAME';
 If (R[1]>='0') And (R[1]<='9') Then R:='_'+R;
 SanitizeAsmName:=R;
End;

Function MakeAsmLabel(Prefix,Name:String):String;
Begin
 MakeAsmLabel:=Prefix+SanitizeAsmName(Name);
End;

Function MakeInternalLabel(Name:String):String;
Begin
 MakeInternalLabel:=MakeAsmLabel(MOD3_INTERNAL_PREFIX,Name);
End;

Function MakeDataLabel(Name:String):String;
Begin
 MakeDataLabel:=MakeAsmLabel(MOD3_DATA_PREFIX,Name);
End;

Function AsmByteList(S:String;ZeroTerminated:Boolean):String;
Var
 I:Integer;
 R:String;
Begin
 R:='';
 For I:=1 To Length(S) Do Begin
  If R<>'' Then R:=R+',';
  R:=R+IntToString(Ord(S[I]));
 End;
 If ZeroTerminated Then Begin
  If R<>'' Then R:=R+',';
  R:=R+'0';
 End;
 If R='' Then R:='0';
 AsmByteList:=R;
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

Function TypeStorageSize(TypeIndex:Integer):Integer; Forward;
Function TypeStorageAlign(TypeIndex:Integer):Integer; Forward;
Function CanonicalType(TypeIndex:Integer):Integer; Forward;
Function IRKindName(Kind:TIRKind):String; Forward;
Function StatementKindName(Kind:TStatementKind):String; Forward;

Function AsmReal(Value:Extended;Decimals:Integer):String;
Var
 S:String;
Begin
 Str(Value:0:Decimals,S);
 AsmReal:=S;
End;

Procedure EmitAsmAlignment(Var T:Text;Alignment:Integer);
Begin
 If Alignment>1 Then EmitAsmLine(T,'  align '+IntToString(Alignment));
End;

Procedure EmitAsmConstStrings(Var T:Text);
Var
 I:Integer;
 LabelName:String;
Begin
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_CONST) And
     SemanticSymbols[I].ConstValue.Valid And
     (SemanticSymbols[I].ConstValue.Kind=CONST_TEXT) Then Begin
   LabelName:=MakeDataLabel(Pipeline.ModuleName+'_CONST_'+
                            SemanticSymbols[I].Name);
   EmitAsmLabel(T,LabelName);
   EmitAsmLine(T,'  db '+
    AsmByteList(SemanticSymbols[I].ConstValue.TextVal,True));
  End;
End;

Procedure EmitAsmInitializedGlobal(Var T:Text;SymbolIndex:Integer);
Var
 TypeIndex:Integer;
 Kind:TTypeKind;
 V:TConstValue;
 ConstLabel:String;
Begin
 TypeIndex:=CanonicalType(SemanticSymbols[SymbolIndex].TypeIndex);
 Kind:=SemanticTypes[TypeIndex].Kind;
 V:=SemanticSymbols[SymbolIndex].ConstValue;
 EmitAsmAlignment(T,TypeStorageAlign(TypeIndex));
 EmitAsmLabel(T,SemanticSymbols[SymbolIndex].AsmLabel);
 If Kind=TYPE_REAL Then
  EmitAsmLine(T,'  dd __float32__('+AsmReal(V.RealVal,8)+')')
 Else If Kind=TYPE_LONGREAL Then
  EmitAsmLine(T,'  dq __float64__('+AsmReal(V.RealVal,12)+')')
 Else If Kind=TYPE_TEXT Then Begin
  ConstLabel:=MakeDataLabel(Pipeline.ModuleName+'_VARINIT_'+
                            SemanticSymbols[SymbolIndex].Name);
  EmitAsmLine(T,'  dd '+ConstLabel);
  EmitAsmLabel(T,ConstLabel);
  EmitAsmLine(T,'  db '+AsmByteList(V.TextVal,True));
 End
 Else If (Kind=TYPE_BOOLEAN) Or (Kind=TYPE_CHAR) Then
  EmitAsmLine(T,'  db '+IntToString(V.IntegerVal))
 Else
  EmitAsmLine(T,'  dd '+IntToString(V.IntegerVal));
End;

Procedure EmitAsmGlobals(Var T:Text;Storage:TStorageKind);
Var
 I:Integer;
Begin
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_VAR) And
     (SemanticSymbols[I].Storage=Storage) Then Begin
   If Storage=STORAGE_GLOBAL_DATA Then
    EmitAsmInitializedGlobal(T,I)
   Else Begin
    EmitAsmAlignment(T,TypeStorageAlign(SemanticSymbols[I].TypeIndex));
    EmitAsmLabel(T,SemanticSymbols[I].AsmLabel);
    EmitAsmLine(T,'  resb '+IntToString(SemanticSymbols[I].Size));
   End;
  End;
End;

Function ProcedureLabelForScope(ScopeIndex:Integer):String;Forward;
Function ObjectTypeLabel(TypeIndex:Integer):String;Forward;
Function ObjectVTableLabel(TypeIndex:Integer):String;Forward;
Function ObjectMethodForSlot(TypeIndex,Slot:Integer):Integer;Forward;

Function FindProcedureByName(Name:String):Integer;
Var
 I:Integer;
Begin
 FindProcedureByName:=0;
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_PROCEDURE) And
     (UpperStr(SemanticSymbols[I].Name)=UpperStr(Name)) And
     (SemanticSymbols[I].ProcScope<>0) Then Begin
   FindProcedureByName:=I;
   Exit;
  End;
End;

Procedure EmitObjectDescriptors(Var T:Text);
Var
 TypeIndex,Slot,MethodSymbol,ProcSymbol,BaseType:Integer;
 Entry:String;
Begin
 For TypeIndex:=1 To SemanticTypeCount Do
  If SemanticTypes[TypeIndex].Kind=TYPE_OBJECT Then Begin
   EmitAsmAlignment(T,4);
   EmitAsmLabel(T,ObjectVTableLabel(TypeIndex));
   For Slot:=0 To SemanticTypes[TypeIndex].MethodCount-1 Do Begin
    MethodSymbol:=ObjectMethodForSlot(TypeIndex,Slot);
    Entry:='0';
    If MethodSymbol<>0 Then Begin
     ProcSymbol:=SemanticSymbols[MethodSymbol].MethodImpl;
     If (ProcSymbol=0) And (SemanticSymbols[MethodSymbol].AsmLabel<>'') Then
      ProcSymbol:=FindProcedureByName(SemanticSymbols[MethodSymbol].AsmLabel);
     If ProcSymbol<>0 Then
      Entry:=ProcedureLabelForScope(SemanticSymbols[ProcSymbol].ProcScope);
    End;
    EmitAsmLine(T,'  dd '+Entry);
   End;
   EmitAsmLabel(T,ObjectTypeLabel(TypeIndex));
   EmitAsmLine(T,'  dd '+ObjectVTableLabel(TypeIndex));
   BaseType:=CanonicalType(SemanticTypes[TypeIndex].BaseType);
   If BaseType<>0 Then EmitAsmLine(T,'  dd '+ObjectTypeLabel(BaseType))
   Else EmitAsmLine(T,'  dd 0');
   EmitAsmLine(T,'  dd '+IntToString(SemanticTypes[TypeIndex].TypeCode));
   EmitAsmLine(T,'  dd '+IntToString(SemanticTypes[TypeIndex].InstanceSize));
  End;
End;

Procedure EmitStatementIR386(Var T:Text;OnlyScope:Integer);Forward;

Function ProcedureLabelForScope(ScopeIndex:Integer):String;
Begin
 ProcedureLabelForScope:=MakeInternalLabel(Pipeline.ModuleName+'_PROC_'+
  SemanticScopes[ScopeIndex].OwnerName+'_S'+IntToString(ScopeIndex));
End;

Function ScopeExitLabel(ScopeIndex:Integer):String;
Begin
 ScopeExitLabel:=MakeInternalLabel(Pipeline.ModuleName+'_EXIT');
 If (ScopeIndex>=1) And (ScopeIndex<=SemanticScopeCount) And
    (SemanticScopes[ScopeIndex].Kind=SCOPE_PROCEDURE) Then
  ScopeExitLabel:=ProcedureLabelForScope(ScopeIndex)+'_EXIT';
End;

Procedure EmitAsmProcedureFrames(Var T:Text);
Var
 ScopeIndex,I:Integer;
 ProcLabel:String;
Begin
 For ScopeIndex:=1 To SemanticScopeCount Do
  If SemanticScopes[ScopeIndex].Kind=SCOPE_PROCEDURE Then Begin
   ProcLabel:=ProcedureLabelForScope(ScopeIndex);
   EmitAsmBlank(T);
   EmitAsmLabel(T,ProcLabel);
   Emit386Prologue(T,SemanticScopes[ScopeIndex].FrameSize);
   For I:=1 To SemanticSymbolCount Do
    If (SemanticSymbols[I].ScopeIndex=ScopeIndex) And
       (SemanticSymbols[I].Storage=STORAGE_LOCAL) Then Begin
     If SemanticSymbols[I].Size=1 Then
      EmitAsmInstr(T,'mov','byte '+LocalVarRef(-SemanticSymbols[I].Offset)+', 0')
     Else If SemanticSymbols[I].Size=2 Then
      EmitAsmInstr(T,'mov','word '+LocalVarRef(-SemanticSymbols[I].Offset)+', 0')
     Else If SemanticSymbols[I].Size=4 Then
      EmitAsmInstr(T,'mov','dword '+LocalVarRef(-SemanticSymbols[I].Offset)+', 0')
     Else Begin
      Emit386Push(T,RegName(R_EDI));
      Emit386Push(T,RegName(R_ECX));
      EmitAsmInstr(T,'lea',RegName(R_EDI)+', '+
                   LocalVarRef(-SemanticSymbols[I].Offset));
      EmitAsmInstr(T,'xor',RegName(R_EAX)+', '+RegName(R_EAX));
      Emit386Mov(T,RegName(R_ECX),IntToString(SemanticSymbols[I].Size));
      EmitAsmInstr(T,'rep stosb','');
      Emit386Pop(T,RegName(R_ECX));
      Emit386Pop(T,RegName(R_EDI));
     End;
    End;
   For I:=1 To SemanticSymbolCount Do
    If SemanticSymbols[I].ScopeIndex=ScopeIndex Then
     If SemanticSymbols[I].Storage=STORAGE_LOCAL Then
      EmitAsmComment(T,'local '+SemanticSymbols[I].Name+' = '+
       LocalVarRef(-SemanticSymbols[I].Offset)+' ('+
       IntToString(SemanticSymbols[I].Size)+' octets)')
     Else If SemanticSymbols[I].Storage=STORAGE_PARAMETER Then
     EmitAsmComment(T,'param '+SemanticSymbols[I].Name+' = '+
       StackRef(R_EBP,SemanticSymbols[I].Offset));
   EmitStatementIR386(T,ScopeIndex);
   EmitAsmLabel(T,ScopeExitLabel(ScopeIndex));
   Emit386Epilogue(T);
 End;
End;

Function ControlLabel(LabelIndex:Integer):String;
Begin
 ControlLabel:=MakeInternalLabel(Pipeline.ModuleName+'_CTRL_'+
                                 IntToString(LabelIndex));
End;

Function ObjectTypeLabel(TypeIndex:Integer):String;
Begin
 ObjectTypeLabel:=MakeDataLabel(Pipeline.ModuleName+'_TYPE_'+
  SemanticTypes[TypeIndex].Name);
End;

Function ObjectVTableLabel(TypeIndex:Integer):String;
Begin
 ObjectVTableLabel:=MakeDataLabel(Pipeline.ModuleName+'_VT_'+
  SemanticTypes[TypeIndex].Name);
End;

Function ObjectMethodForSlot(TypeIndex,Slot:Integer):Integer;
Var
 I:Integer;
Begin
 ObjectMethodForSlot:=0;
 TypeIndex:=CanonicalType(TypeIndex);
 If (TypeIndex<1) Or (TypeIndex>SemanticTypeCount) Then Exit;
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].ScopeIndex=SemanticTypes[TypeIndex].FieldScope) And
     (SemanticSymbols[I].Kind=SYM_METHOD) And
     (SemanticSymbols[I].Offset=Slot) Then Begin
   ObjectMethodForSlot:=I;
   Exit;
  End;
 If SemanticTypes[TypeIndex].BaseType<>0 Then
  ObjectMethodForSlot:=ObjectMethodForSlot(
   SemanticTypes[TypeIndex].BaseType,Slot);
End;

Function SymbolMemoryOperand(SymbolIndex:Integer):String;
Begin
 SymbolMemoryOperand:='';
 If (SymbolIndex<1) Or (SymbolIndex>SemanticSymbolCount) Then Exit;
 Case SemanticSymbols[SymbolIndex].Storage Of
  STORAGE_GLOBAL_DATA,STORAGE_GLOBAL_BSS:
   SymbolMemoryOperand:='['+SemanticSymbols[SymbolIndex].AsmLabel+']';
  STORAGE_LOCAL:
   SymbolMemoryOperand:=LocalVarRef(-SemanticSymbols[SymbolIndex].Offset);
  STORAGE_PARAMETER:
   SymbolMemoryOperand:=StackRef(R_EBP,SemanticSymbols[SymbolIndex].Offset);
 End;
End;

Function NthFormalParameter(ProcedureSymbol,Number:Integer):Integer;
Var
 I,Count,ScopeIndex:Integer;
Begin
 NthFormalParameter:=0;
 If (ProcedureSymbol<1) Or (ProcedureSymbol>SemanticSymbolCount) Then Exit;
 ScopeIndex:=SemanticSymbols[ProcedureSymbol].ProcScope;
 Count:=0;
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].ScopeIndex=ScopeIndex) And
     (SemanticSymbols[I].Kind=SYM_PARAM) Then Begin
   Inc(Count);
   If Count=Number Then Begin
    NthFormalParameter:=I;
    Exit;
   End;
  End;
End;

Procedure EmitIRExpression386(Var T:Text;NodeIndex:Integer);Forward;

Procedure EmitIRAddress386(Var T:Text;NodeIndex:Integer);
Var
 SymbolIndex:Integer;
Begin
 If (NodeIndex<1) Or (NodeIndex>IRNodeCount) Then Begin
  Emit386Mov(T,'eax','0');
  Exit;
 End;
 If IRNodes[NodeIndex].Kind=IR_FIELD Then Begin
  EmitIRExpression386(T,IRNodes[NodeIndex].Left);
  SymbolIndex:=IRNodes[NodeIndex].SymbolIndex;
  If SymbolIndex>0 Then
   EmitAsmInstr(T,'add','eax, '+IntToString(SemanticSymbols[SymbolIndex].Offset));
 End
 Else If IRNodes[NodeIndex].Kind=IR_SYMBOL Then Begin
  SymbolIndex:=IRNodes[NodeIndex].SymbolIndex;
  If (SymbolIndex>0) And
     (SemanticSymbols[SymbolIndex].Storage=STORAGE_PARAMETER) And
     (SemanticSymbols[SymbolIndex].ParamMode=PARAM_VAR) Then
   Emit386Mov(T,'eax','dword '+
    StackRef(R_EBP,SemanticSymbols[SymbolIndex].Offset))
  Else If (SymbolIndex>0) And
          (SemanticSymbols[SymbolIndex].Storage In
           [STORAGE_GLOBAL_DATA,STORAGE_GLOBAL_BSS]) Then
   EmitAsmInstr(T,'lea','eax, ['+SemanticSymbols[SymbolIndex].AsmLabel+']')
  Else If (SymbolIndex>0) And
          (SemanticSymbols[SymbolIndex].Storage=STORAGE_LOCAL) Then
   EmitAsmInstr(T,'lea','eax, '+
    LocalVarRef(-SemanticSymbols[SymbolIndex].Offset))
  Else If (SymbolIndex>0) And
          (SemanticSymbols[SymbolIndex].Storage=STORAGE_PARAMETER) Then
   EmitAsmInstr(T,'lea','eax, '+
    StackRef(R_EBP,SemanticSymbols[SymbolIndex].Offset))
  Else Emit386Mov(T,'eax','0');
 End
 Else Begin
  EmitAsmComment(T,'adresse de designateur complexe differee');
  Emit386Mov(T,'eax','0');
 End;
End;

Procedure EmitIRExpression386(Var T:Text;NodeIndex:Integer);
Var
 Node:TIRNode;
 Operand,TrueName,FalseName,DoneName:String;
 BeginLabel,EndLabel,I,FormalIndex,TypeIndex:Integer;
Begin
 If (NodeIndex<1) Or (NodeIndex>IRNodeCount) Then Exit;
 Node:=IRNodes[NodeIndex];
 Case Node.Kind Of
  IR_LITERAL:Begin
   If CanonicalType(Node.TypeIndex)=CanonicalType(TypeBoolean) Then
    Emit386Mov(T,RegName(R_EAX),IntToString(Node.IntegerVal))
   Else If CanonicalType(Node.TypeIndex)=CanonicalType(TypeText) Then
    EmitAsmComment(T,'adresse litteral TEXT "'+Node.Text+'"')
   Else Emit386Mov(T,RegName(R_EAX),IntToString(Node.IntegerVal));
  End;
  IR_SYMBOL:Begin
   Operand:=SymbolMemoryOperand(Node.SymbolIndex);
   If Operand<>'' Then Begin
    If (Node.SymbolIndex<>0) And
       (SemanticSymbols[Node.SymbolIndex].Storage=STORAGE_PARAMETER) And
       (SemanticSymbols[Node.SymbolIndex].ParamMode=PARAM_VAR) Then Begin
     Emit386Mov(T,'eax','dword '+Operand);
     If TypeStorageSize(SemanticSymbols[Node.SymbolIndex].TypeIndex)=1 Then
      EmitAsmInstr(T,'movzx','eax, byte [eax]')
     Else Emit386Mov(T,'eax','dword [eax]');
    End
    Else If (Node.SymbolIndex<>0) And
       (SemanticSymbols[Node.SymbolIndex].Size=1) Then
     EmitAsmInstr(T,'movzx','eax, byte '+Operand)
    Else Emit386Mov(T,RegName(R_EAX),'dword '+Operand);
   End
   Else If (Node.SymbolIndex<>0) And
           (SemanticSymbols[Node.SymbolIndex].Kind=SYM_CONST) Then
    Emit386Mov(T,RegName(R_EAX),
     IntToString(SemanticSymbols[Node.SymbolIndex].ConstValue.IntegerVal));
  End;
  IR_FIELD:Begin
   EmitIRAddress386(T,NodeIndex);
   If (Node.SymbolIndex<>0) And
      (TypeStorageSize(SemanticSymbols[Node.SymbolIndex].TypeIndex)=1) Then
    EmitAsmInstr(T,'movzx','eax, byte [eax]')
   Else Emit386Mov(T,'eax','dword [eax]');
  End;
  IR_UNARY:Begin
   EmitIRExpression386(T,Node.Left);
   If Node.OperatorText='-' Then EmitAsmInstr(T,'neg',RegName(R_EAX))
   Else If Node.OperatorText='NOT' Then Begin
    EmitAsmInstr(T,'cmp',RegName(R_EAX)+', 0');
    EmitAsmInstr(T,'sete','al');
    EmitAsmInstr(T,'movzx',RegName(R_EAX)+', al');
   End;
  End;
  IR_BINARY:Begin
   EmitIRExpression386(T,Node.Left);
   Emit386Push(T,RegName(R_EAX));
   EmitIRExpression386(T,Node.Right);
   Emit386Mov(T,RegName(R_ECX),RegName(R_EAX));
   Emit386Pop(T,RegName(R_EAX));
   If Node.OperatorText='+' Then EmitAsmInstr(T,'add','eax, ecx')
   Else If Node.OperatorText='-' Then EmitAsmInstr(T,'sub','eax, ecx')
   Else If Node.OperatorText='*' Then EmitAsmInstr(T,'imul','eax, ecx')
   Else If (Node.OperatorText='DIV') Or (Node.OperatorText='MOD') Then Begin
    EmitAsmInstr(T,'cdq','');
    EmitAsmInstr(T,'idiv','ecx');
    If Node.OperatorText='MOD' Then Emit386Mov(T,'eax','edx');
   End
   Else If Node.OperatorText='/' Then Begin
    EmitAsmComment(T,'division reelle differee au backend flottant');
   End
   Else If Node.OperatorText='&' Then
    EmitAsmComment(T,'concatenation TEXT differee au runtime');
  End;
  IR_COMPARE:Begin
   EmitIRExpression386(T,Node.Left);
   Emit386Push(T,RegName(R_EAX));
   EmitIRExpression386(T,Node.Right);
   Emit386Mov(T,RegName(R_ECX),RegName(R_EAX));
   Emit386Pop(T,RegName(R_EAX));
   EmitAsmInstr(T,'cmp','eax, ecx');
   If Node.OperatorText='=' Then EmitAsmInstr(T,'sete','al')
   Else If Node.OperatorText='#' Then EmitAsmInstr(T,'setne','al')
   Else If Node.OperatorText='<' Then EmitAsmInstr(T,'setl','al')
   Else If Node.OperatorText='<=' Then EmitAsmInstr(T,'setle','al')
   Else If Node.OperatorText='>' Then EmitAsmInstr(T,'setg','al')
   Else If Node.OperatorText='>=' Then EmitAsmInstr(T,'setge','al');
   EmitAsmInstr(T,'movzx','eax, al');
  End;
  IR_AND_SHORT:Begin
   BeginLabel:=Node.FalseLabel;
   Inc(IRLabelCounter);
   EndLabel:=IRLabelCounter;
   FalseName:=ControlLabel(BeginLabel);
   DoneName:=ControlLabel(EndLabel);
   EmitIRExpression386(T,Node.Left);
   EmitAsmInstr(T,'test','eax, eax');
   EmitAsmInstr(T,'jz',FalseName);
   EmitIRExpression386(T,Node.Right);
   EmitAsmInstr(T,'jmp',DoneName);
   EmitAsmLabel(T,FalseName);
   Emit386Mov(T,'eax','0');
   EmitAsmLabel(T,DoneName);
  End;
  IR_OR_SHORT:Begin
   BeginLabel:=Node.TrueLabel;
   Inc(IRLabelCounter);
   EndLabel:=IRLabelCounter;
   TrueName:=ControlLabel(BeginLabel);
   DoneName:=ControlLabel(EndLabel);
   EmitIRExpression386(T,Node.Left);
   EmitAsmInstr(T,'test','eax, eax');
   EmitAsmInstr(T,'jnz',TrueName);
   EmitIRExpression386(T,Node.Right);
   EmitAsmInstr(T,'jmp',DoneName);
   EmitAsmLabel(T,TrueName);
   Emit386Mov(T,'eax','1');
   EmitAsmLabel(T,DoneName);
  End;
  IR_CALL:Begin
   If Node.Receiver<>0 Then Begin
    For I:=Node.ArgCount DownTo 1 Do Begin
     EmitIRExpression386(T,IRArguments[Node.FirstArg+I-1]);
     Emit386Push(T,'eax');
    End;
    EmitIRExpression386(T,Node.Receiver);
    Emit386Push(T,'eax');
    Emit386Mov(T,'ecx','dword [eax]');
    EmitAsmInstr(T,'call','dword [ecx+'+IntToString(Node.VirtualSlot*4)+']');
    EmitAsmInstr(T,'add','esp, '+IntToString((Node.ArgCount+1)*4));
   End
   Else If UpperStr(Node.Text)='NEW' Then Begin
    TypeIndex:=CanonicalType(Node.TypeIndex);
    If (TypeIndex<>0) And (SemanticTypes[TypeIndex].Kind=TYPE_OBJECT) Then Begin
     Emit386Push(T,IntToString(SemanticTypes[TypeIndex].InstanceSize));
     Emit386Push(T,ObjectTypeLabel(TypeIndex));
     EmitAsmInstr(T,'call',MakeAsmLabel(MOD3_RUNTIME_PREFIX,'OBJNEW'));
     EmitAsmInstr(T,'add','esp, 8');
    End
    Else EmitAsmComment(T,'NEW non objet differe au runtime');
   End
   Else If UpperStr(Node.Text)='TYPECODE' Then Begin
    TypeIndex:=0;
    If Node.ArgCount=1 Then
     TypeIndex:=CanonicalType(IRNodes[
      IRArguments[Node.FirstArg]].TypeIndex);
    If TypeIndex<>0 Then Emit386Mov(T,'eax',
     IntToString(SemanticTypes[TypeIndex].TypeCode))
    Else Emit386Mov(T,'eax','0');
   End
   Else If (UpperStr(Node.Text)='ISTYPE') Or
           (UpperStr(Node.Text)='NARROW') Then Begin
    TypeIndex:=0;
    If Node.ArgCount>1 Then
     TypeIndex:=CanonicalType(IRNodes[
      IRArguments[Node.FirstArg+1]].TypeIndex);
    If Node.ArgCount>0 Then EmitIRExpression386(T,
     IRArguments[Node.FirstArg]);
    Emit386Push(T,'eax');
    If TypeIndex<>0 Then Emit386Push(T,ObjectTypeLabel(TypeIndex))
    Else Emit386Push(T,'0');
    If UpperStr(Node.Text)='ISTYPE' Then
     EmitAsmInstr(T,'call',MakeAsmLabel(MOD3_RUNTIME_PREFIX,'ISTYPE'))
    Else
     EmitAsmInstr(T,'call',MakeAsmLabel(MOD3_RUNTIME_PREFIX,'NARROW'));
    EmitAsmInstr(T,'add','esp, 8');
   End
   Else If (Node.SymbolIndex<>0) And
      (SemanticSymbols[Node.SymbolIndex].Kind=SYM_PROCEDURE) And
      (SemanticSymbols[Node.SymbolIndex].ProcScope<>0) Then
   Begin
    For I:=Node.ArgCount DownTo 1 Do Begin
     FormalIndex:=NthFormalParameter(Node.SymbolIndex,I);
     If (FormalIndex<>0) And
        (SemanticSymbols[FormalIndex].ParamMode=PARAM_VAR) Then
      EmitIRAddress386(T,IRArguments[Node.FirstArg+I-1])
     Else
      EmitIRExpression386(T,IRArguments[Node.FirstArg+I-1]);
     Emit386Push(T,'eax');
    End;
    EmitAsmInstr(T,'call',ProcedureLabelForScope(
      SemanticSymbols[Node.SymbolIndex].ProcScope));
    If Node.ArgCount>0 Then
     EmitAsmInstr(T,'add','esp, '+IntToString(Node.ArgCount*4));
   End
   Else EmitAsmComment(T,'appel externe '+Node.Text);
  End;
  Else EmitAsmComment(T,'expression '+IRKindName(Node.Kind)+
                      ' conservee dans l''IR');
 End;
End;

Procedure EmitStatementIR386(Var T:Text;OnlyScope:Integer);
Var
 I,TargetSymbol,Parent:Integer;
 S:TStatementIR;
 Operand:String;
 LastIfBranch:Array[1..MOD3_MAX_STATEMENTS] Of Integer;
 IfHasElse:Array[1..MOD3_MAX_STATEMENTS] Of Boolean;
 LastCaseArm:Array[1..MOD3_MAX_STATEMENTS] Of Integer;
 CaseHasElse:Array[1..MOD3_MAX_STATEMENTS] Of Boolean;
Begin
 FillChar(LastIfBranch,SizeOf(LastIfBranch),0);
 FillChar(IfHasElse,SizeOf(IfHasElse),0);
 FillChar(LastCaseArm,SizeOf(LastCaseArm),0);
 FillChar(CaseHasElse,SizeOf(CaseHasElse),0);
 EmitAsmBlank(T);
 EmitAsmComment(T,'IR des instructions TODO 18/19/20/21');
 For I:=1 To StatementCount Do Begin
  S:=StatementIR[I];
  If S.ScopeIndex<>OnlyScope Then Continue;
  Case S.Kind Of
   ST_WHILE:Begin
    EmitAsmLabel(T,ControlLabel(S.StartLabel));
    EmitIRExpression386(T,S.ExpressionNode);
    EmitAsmInstr(T,'test','eax, eax');
    EmitAsmInstr(T,'jz',ControlLabel(S.EndLabel));
   End;
   ST_LOOP,ST_REPEAT:
    EmitAsmLabel(T,ControlLabel(S.StartLabel));
   ST_FOR:Begin
    TargetSymbol:=0;
    If (S.TargetNode>0) And (IRNodes[S.TargetNode].Kind=IR_SYMBOL) Then
     TargetSymbol:=IRNodes[S.TargetNode].SymbolIndex;
    Operand:=SymbolMemoryOperand(TargetSymbol);
    EmitIRExpression386(T,S.ExpressionNode);
    If Operand<>'' Then Emit386Mov(T,'dword '+Operand,'eax');
    EmitIRExpression386(T,S.BoundNode);
    Emit386Push(T,'eax');
    If S.StepNode<>0 Then EmitIRExpression386(T,S.StepNode)
    Else Emit386Mov(T,'eax','1');
    Emit386Push(T,'eax');
    EmitAsmLabel(T,ControlLabel(S.StartLabel));
    Emit386Mov(T,'ecx','dword [esp]');
    EmitAsmInstr(T,'test','ecx, ecx');
    EmitAsmInstr(T,'jz',ControlLabel(S.EndLabel));
    If Operand<>'' Then Emit386Mov(T,'eax','dword '+Operand);
    EmitAsmInstr(T,'cmp','ecx, 0');
    EmitAsmInstr(T,'jl',ControlLabel(S.FalseLabel));
    EmitAsmInstr(T,'cmp','eax, dword [esp+4]');
    EmitAsmInstr(T,'jg',ControlLabel(S.EndLabel));
    EmitAsmInstr(T,'jmp',ControlLabel(S.ContinueLabel));
    EmitAsmLabel(T,ControlLabel(S.FalseLabel));
    EmitAsmInstr(T,'cmp','eax, dword [esp+4]');
    EmitAsmInstr(T,'jl',ControlLabel(S.EndLabel));
    EmitAsmLabel(T,ControlLabel(S.ContinueLabel));
   End;
   ST_UNTIL:Begin
    EmitIRExpression386(T,S.ExpressionNode);
    EmitAsmInstr(T,'test','eax, eax');
    If S.ParentIndex>0 Then Begin
     EmitAsmInstr(T,'jz',ControlLabel(
      StatementIR[S.ParentIndex].StartLabel));
     EmitAsmLabel(T,ControlLabel(StatementIR[S.ParentIndex].EndLabel));
    End;
   End;
   ST_EXIT:If S.ParentIndex>0 Then Begin
    EmitAsmInstr(T,'jmp',ControlLabel(StatementIR[S.ParentIndex].EndLabel));
   End;
   ST_ASSIGN:Begin
    EmitIRExpression386(T,S.ExpressionNode);
    If (S.TargetNode>0) And (IRNodes[S.TargetNode].Kind=IR_SYMBOL) Then Begin
     TargetSymbol:=IRNodes[S.TargetNode].SymbolIndex;
     Operand:=SymbolMemoryOperand(TargetSymbol);
     If Operand<>'' Then Begin
      If (SemanticSymbols[TargetSymbol].Storage=STORAGE_PARAMETER) And
         (SemanticSymbols[TargetSymbol].ParamMode=PARAM_VAR) Then Begin
       Emit386Push(T,'eax');
       Emit386Mov(T,'ecx','dword '+Operand);
       Emit386Pop(T,'eax');
       If TypeStorageSize(SemanticSymbols[TargetSymbol].TypeIndex)=1 Then
        Emit386Mov(T,'byte [ecx]','al')
       Else Emit386Mov(T,'dword [ecx]','eax');
      End
      Else If SemanticSymbols[TargetSymbol].Size=1 Then
       Emit386Mov(T,'byte '+Operand,'al')
      Else Emit386Mov(T,'dword '+Operand,'eax');
     End;
    End
    Else If (S.TargetNode>0) And
            (IRNodes[S.TargetNode].Kind=IR_FIELD) Then Begin
     Emit386Push(T,'eax');
     EmitIRAddress386(T,S.TargetNode);
     Emit386Mov(T,'ecx','eax');
     Emit386Pop(T,'eax');
     TargetSymbol:=IRNodes[S.TargetNode].SymbolIndex;
     If (TargetSymbol<>0) And
        (TypeStorageSize(SemanticSymbols[TargetSymbol].TypeIndex)=1) Then
      Emit386Mov(T,'byte [ecx]','al')
     Else Emit386Mov(T,'dword [ecx]','eax');
    End
    Else EmitAsmComment(T,'stockage complexe conserve dans l''IR');
   End;
   ST_CALL:EmitIRExpression386(T,S.ExpressionNode);
   ST_IF,ST_ELSIF:Begin
    If S.Kind=ST_ELSIF Then Begin
     Parent:=S.ParentIndex;
     If (Parent>0) And (LastIfBranch[Parent]>0) Then Begin
      EmitAsmInstr(T,'jmp',ControlLabel(StatementIR[Parent].EndLabel));
      EmitAsmLabel(T,ControlLabel(
       StatementIR[LastIfBranch[Parent]].FalseLabel));
     End;
    End
    Else Parent:=I;
    EmitIRExpression386(T,S.ExpressionNode);
    EmitAsmInstr(T,'test','eax, eax');
    EmitAsmInstr(T,'jz',ControlLabel(S.FalseLabel));
    If S.Kind=ST_IF Then LastIfBranch[I]:=I
    Else If Parent>0 Then LastIfBranch[Parent]:=I;
   End;
   ST_ELSE:Begin
    Parent:=S.ParentIndex;
    If (Parent>0) And (LastIfBranch[Parent]>0) Then Begin
     EmitAsmInstr(T,'jmp',ControlLabel(StatementIR[Parent].EndLabel));
     EmitAsmLabel(T,ControlLabel(
      StatementIR[LastIfBranch[Parent]].FalseLabel));
     IfHasElse[Parent]:=True;
    End;
   End;
   ST_CASE_ELSE:Begin
    Parent:=S.ParentIndex;
    If (Parent>0) And (LastCaseArm[Parent]>0) Then Begin
     EmitAsmInstr(T,'jmp',ControlLabel(StatementIR[Parent].EndLabel));
     EmitAsmLabel(T,ControlLabel(
      StatementIR[LastCaseArm[Parent]].FalseLabel));
     CaseHasElse[Parent]:=True;
    End;
   End;
   ST_CASE:Begin
    EmitIRExpression386(T,S.ExpressionNode);
    Emit386Mov(T,'ebx','eax');
   End;
   ST_CASE_ARM:Begin
    Parent:=S.ParentIndex;
    If (Parent>0) And (LastCaseArm[Parent]>0) Then Begin
     EmitAsmInstr(T,'jmp',ControlLabel(StatementIR[Parent].EndLabel));
     EmitAsmLabel(T,ControlLabel(
      StatementIR[LastCaseArm[Parent]].FalseLabel));
    End;
    EmitAsmInstr(T,'cmp','ebx, '+IntToString(S.CaseLow));
    If S.HasCaseRange Then Begin
     EmitAsmInstr(T,'jl',ControlLabel(S.FalseLabel));
     EmitAsmInstr(T,'cmp','ebx, '+IntToString(S.CaseHigh));
     EmitAsmInstr(T,'jg',ControlLabel(S.FalseLabel));
    End
    Else EmitAsmInstr(T,'jne',ControlLabel(S.FalseLabel));
    EmitAsmLabel(T,ControlLabel(S.StartLabel));
    If Parent>0 Then LastCaseArm[Parent]:=I;
   End;
   ST_RETURN:Begin
    EmitIRExpression386(T,S.ExpressionNode);
    EmitAsmInstr(T,'jmp',ScopeExitLabel(OnlyScope));
   End;
   ST_BLOCK_END:Begin
    If S.ParentIndex>0 Then Begin
     Parent:=S.ParentIndex;
     If StatementIR[Parent].Kind=ST_IF Then Begin
      If (LastIfBranch[Parent]>0) And Not IfHasElse[Parent] Then
       EmitAsmLabel(T,ControlLabel(
        StatementIR[LastIfBranch[Parent]].FalseLabel));
      EmitAsmLabel(T,ControlLabel(StatementIR[Parent].EndLabel));
     End
     Else If StatementIR[Parent].Kind=ST_CASE Then Begin
      If (LastCaseArm[Parent]>0) And Not CaseHasElse[Parent] Then
       EmitAsmLabel(T,ControlLabel(
        StatementIR[LastCaseArm[Parent]].FalseLabel));
      EmitAsmLabel(T,ControlLabel(StatementIR[Parent].EndLabel));
     End
     Else If StatementIR[Parent].Kind=ST_WHILE Then Begin
      EmitAsmInstr(T,'jmp',ControlLabel(StatementIR[Parent].StartLabel));
      EmitAsmLabel(T,ControlLabel(StatementIR[Parent].EndLabel));
     End
     Else If StatementIR[Parent].Kind=ST_LOOP Then Begin
      EmitAsmInstr(T,'jmp',ControlLabel(StatementIR[Parent].StartLabel));
      EmitAsmLabel(T,ControlLabel(StatementIR[Parent].EndLabel));
     End
     Else If StatementIR[Parent].Kind=ST_FOR Then Begin
      TargetSymbol:=0;
      If (StatementIR[Parent].TargetNode>0) And
         (IRNodes[StatementIR[Parent].TargetNode].Kind=IR_SYMBOL) Then
       TargetSymbol:=IRNodes[StatementIR[Parent].TargetNode].SymbolIndex;
      Operand:=SymbolMemoryOperand(TargetSymbol);
      If Operand<>'' Then Begin
       Emit386Mov(T,'eax','dword '+Operand);
       EmitAsmInstr(T,'add','eax, dword [esp]');
       Emit386Mov(T,'dword '+Operand,'eax');
      End;
      EmitAsmInstr(T,'jmp',ControlLabel(StatementIR[Parent].StartLabel));
      EmitAsmLabel(T,ControlLabel(StatementIR[Parent].EndLabel));
      EmitAsmInstr(T,'add','esp, 8');
     End;
    End;
   End;
  End;
 End;
End;

Function WriteAsm80386File(FileName:String):Boolean;
Var
 T:Text;
 I,ModuleScope:Integer;
Begin
 WriteAsm80386File:=False;
 Assign(T,FileName);
 Rewrite(T);
 If IOResult<>0 Then Begin
  PipelineError('impossible d''ecrire '+FileName);
  Exit;
 End;
 EmitAsmComment(T,'MOD3CW32 - ASM 80386 genere');
 EmitAsmComment(T,'source: '+Pipeline.SourceName);
 EmitAsmComment(T,'module: '+Pipeline.ModuleName);
 EmitAsmComment(T,'target: '+Pipeline.Target.CpuName+' '+Pipeline.Target.OsName+
                  ' '+IntToString(Pipeline.Target.Bits)+' bits');
 EmitAsmComment(T,'objet: '+Pipeline.ObjName);
 EmitAsmComment(T,'exe: '+Pipeline.ExeName);
 EmitAsmLine(T,'bits 32');
 EmitAsmBlank(T);
 EmitAsmSection(T,Pipeline.Target.CodeSection);
 EmitAsmLine(T,'global '+Pipeline.Target.EntryLabel);
 EmitAsmLabel(T,Pipeline.Target.EntryLabel);
 EmitAsmComment(T,'prologue standard Win32 80386 (corps reel: TODOs 08 a 24)');
 Emit386Prologue(T,0);
 ModuleScope:=0;
 For I:=1 To SemanticScopeCount Do
  If SemanticScopes[I].Kind=SCOPE_MODULE Then ModuleScope:=I;
 If ModuleScope<>0 Then EmitStatementIR386(T,ModuleScope);
 Emit386Mov(T,RegName(R_EAX),'0');
 EmitAsmLabel(T,ScopeExitLabel(ModuleScope));
 Emit386Epilogue(T);
 EmitAsmProcedureFrames(T);
 EmitAsmBlank(T);
 EmitAsmSection(T,Pipeline.Target.DataSection);
 EmitAsmLabel(T,MakeDataLabel(Pipeline.ModuleName+'_SOURCE'));
 EmitAsmLine(T,'  db '+AsmByteList(Pipeline.SourceName,True));
 EmitAsmLabel(T,MakeDataLabel(Pipeline.ModuleName+'_MODULE'));
 EmitAsmLine(T,'  db '+AsmByteList(Pipeline.ModuleName,True));
 EmitAsmLabel(T,MakeAsmLabel(MOD3_RUNTIME_PREFIX,'CRLF'));
 EmitAsmLine(T,'  db 13,10,0');
 EmitObjectDescriptors(T);
 EmitAsmConstStrings(T);
 EmitAsmGlobals(T,STORAGE_GLOBAL_DATA);
 EmitAsmBlank(T);
 EmitAsmSection(T,Pipeline.Target.BssSection);
 EmitAsmGlobals(T,STORAGE_GLOBAL_BSS);
 If Pipeline.VarDeclCount=0 Then Begin
  EmitAsmLabel(T,MakeDataLabel(Pipeline.ModuleName+'_BSS_ANCHOR'));
  EmitAsmLine(T,'  resd 1');
 End;
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
 SectionNumber:Integer;StorageClass:Byte;LongNameOffset:LongInt);
Begin
 If Length(Name)<=8 Then WriteFixedName8(F,Name)
 Else Begin
  WriteRawDWordLE(F,0);
  WriteRawDWordLE(F,LongNameOffset);
 End;
 WriteRawDWordLE(F,Value);
 WriteRawWordLE(F,SectionNumber);
 WriteRawWordLE(F,0);
 WriteRawByte(F,StorageClass);
 WriteRawByte(F,0);
End;

Function CoffLongNameOffset(Name,EntryName,SourceLabel,
 ModuleLabel:String):LongInt;
Var
 Offset:LongInt;
 FoundOffset:LongInt;
 I:Integer;

 Procedure Consider(Candidate:String);
 Begin
  If (FoundOffset=0) And (Candidate=Name) And
     (Length(Candidate)>8) Then FoundOffset:=Offset;
  If Length(Candidate)>8 Then Inc(Offset,Length(Candidate)+1);
 End;

Begin
 FoundOffset:=0;
 Offset:=4;
 Consider(SectionName(AS_TEXT));
 Consider(SectionName(AS_DATA));
 Consider(SectionName(AS_BSS));
 Consider(EntryName);
 Consider(SourceLabel);
 Consider(ModuleLabel);
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_VAR) And
     ((SemanticSymbols[I].Storage=STORAGE_GLOBAL_DATA) Or
      (SemanticSymbols[I].Storage=STORAGE_GLOBAL_BSS)) Then
   Consider(SemanticSymbols[I].AsmLabel);
 CoffLongNameOffset:=FoundOffset;
End;

Procedure WriteCoffStringTable(Var F:File;EntryName,SourceLabel,
 ModuleLabel:String);
Var
 TotalSize:LongInt;
 I:Integer;

 Procedure CountName(Name:String);
 Begin
  If Length(Name)>8 Then Inc(TotalSize,Length(Name)+1);
 End;

 Procedure WriteName(Name:String);
 Begin
  If Length(Name)>8 Then WriteRawBytesFromString(F,Name,True);
 End;

Begin
 TotalSize:=4;
 CountName(SectionName(AS_TEXT));
 CountName(SectionName(AS_DATA));
 CountName(SectionName(AS_BSS));
 CountName(EntryName);
 CountName(SourceLabel);
 CountName(ModuleLabel);
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_VAR) And
     ((SemanticSymbols[I].Storage=STORAGE_GLOBAL_DATA) Or
      (SemanticSymbols[I].Storage=STORAGE_GLOBAL_BSS)) Then
   CountName(SemanticSymbols[I].AsmLabel);
 WriteRawDWordLE(F,TotalSize);
 WriteName(SectionName(AS_TEXT));
 WriteName(SectionName(AS_DATA));
 WriteName(SectionName(AS_BSS));
 WriteName(EntryName);
 WriteName(SourceLabel);
 WriteName(ModuleLabel);
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_VAR) And
     ((SemanticSymbols[I].Storage=STORAGE_GLOBAL_DATA) Or
      (SemanticSymbols[I].Storage=STORAGE_GLOBAL_BSS)) Then
   WriteName(SemanticSymbols[I].AsmLabel);
End;

Procedure WriteCoffRelocation(Var F:File;Reloc:TCoffReloc);
Begin
 WriteRawDWordLE(F,Reloc.Offset);
 WriteRawDWordLE(F,Reloc.SymbolIndex);
 WriteRawWordLE(F,CoffRelocType(Reloc.Kind));
End;

Procedure PadToFilePos(Var F:File;TargetPos:LongInt); Forward;

Function GlobalStorageSize(Storage:TStorageKind):LongInt;
Var
 I:Integer;
 EndOffset:LongInt;
 BestSize:LongInt;
Begin
 BestSize:=0;
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_VAR) And
     (SemanticSymbols[I].Storage=Storage) Then Begin
   EndOffset:=SemanticSymbols[I].Offset+SemanticSymbols[I].Size;
   If EndOffset>BestSize Then BestSize:=EndOffset;
  End;
 GlobalStorageSize:=BestSize;
End;

Procedure WriteCoffInitializer(Var F:File;SymbolIndex:Integer);
Var
 TypeIndex:Integer;
 Kind:TTypeKind;
 SingleValue:Single;
 DoubleValue:Double;
 Bits32:LongInt;
 Bits64:Array[0..1] Of LongInt;
 Written:Integer;
Begin
 TypeIndex:=CanonicalType(SemanticSymbols[SymbolIndex].TypeIndex);
 Kind:=SemanticTypes[TypeIndex].Kind;
 Written:=0;
 If Kind=TYPE_REAL Then Begin
  SingleValue:=SemanticSymbols[SymbolIndex].ConstValue.RealVal;
  Move(SingleValue,Bits32,SizeOf(Bits32));
  WriteRawDWordLE(F,Bits32);
  Written:=4;
 End
 Else If Kind=TYPE_LONGREAL Then Begin
  DoubleValue:=SemanticSymbols[SymbolIndex].ConstValue.RealVal;
  Move(DoubleValue,Bits64,SizeOf(Bits64));
  WriteRawDWordLE(F,Bits64[0]);
  WriteRawDWordLE(F,Bits64[1]);
  Written:=8;
 End
 Else If (Kind=TYPE_BOOLEAN) Or (Kind=TYPE_CHAR) Then Begin
  WriteRawByte(F,SemanticSymbols[SymbolIndex].ConstValue.IntegerVal And $FF);
  Written:=1;
 End
 Else Begin
  WriteRawDWordLE(F,SemanticSymbols[SymbolIndex].ConstValue.IntegerVal);
  Written:=4;
 End;
 While Written<SemanticSymbols[SymbolIndex].Size Do Begin
  WriteRawByte(F,0);
  Inc(Written);
 End;
End;

Function WriteCoffI386File(FileName:String):Boolean;
Const
 SectionCount = 3;
 TextSize     = 8;
Var
 F:File;
 SymbolCount:LongInt;
 TextPtr:LongInt;
 DataPtr:LongInt;
 BssPtr:LongInt;
 SymbolPtr:LongInt;
 DataSize:LongInt;
 BssSize:LongInt;
 EntryName:String;
 SourceLabel:String;
 ModuleLabel:String;
 MetaDataSize:LongInt;
 GlobalDataBase:LongInt;
 GlobalDataSize:LongInt;
 I:Integer;
Begin
 WriteCoffI386File:=False;
 SymbolCount:=6;
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_VAR) And
     ((SemanticSymbols[I].Storage=STORAGE_GLOBAL_DATA) Or
      (SemanticSymbols[I].Storage=STORAGE_GLOBAL_BSS)) Then Inc(SymbolCount);
 EntryName:=Pipeline.Target.EntryLabel;
 SourceLabel:=MakeDataLabel(Pipeline.ModuleName+'_SOURCE');
 ModuleLabel:=MakeDataLabel(Pipeline.ModuleName+'_MODULE');
 MetaDataSize:=Length(Pipeline.SourceName)+1+Length(Pipeline.ModuleName)+1;
 GlobalDataBase:=((MetaDataSize+3) Div 4)*4;
 GlobalDataSize:=GlobalStorageSize(STORAGE_GLOBAL_DATA);
 DataSize:=GlobalDataBase+GlobalDataSize;
 BssSize:=GlobalStorageSize(STORAGE_GLOBAL_BSS);
 If BssSize=0 Then BssSize:=4;
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
 WriteRawByte(F,$55);                      (* push ebp *)
 WriteRawByte(F,$8B); WriteRawByte(F,$EC); (* mov ebp, esp *)
 WriteRawByte(F,$33); WriteRawByte(F,$C0); (* xor eax, eax *)
 WriteRawByte(F,$5D);                      (* pop ebp *)
 WriteRawByte(F,$C3);                      (* ret *)
 WriteRawByte(F,$90);                      (* nop d'alignement *)
 WriteRawBytesFromString(F,Pipeline.SourceName,True);
 WriteRawBytesFromString(F,Pipeline.ModuleName,True);
 PadToFilePos(F,DataPtr+GlobalDataBase);
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_VAR) And
     (SemanticSymbols[I].Storage=STORAGE_GLOBAL_DATA) Then Begin
   PadToFilePos(F,DataPtr+GlobalDataBase+SemanticSymbols[I].Offset);
   WriteCoffInitializer(F,I);
  End;
 WriteCoffSymbol(F,SectionName(AS_TEXT),0,CoffSectionNumber(AS_TEXT),
                 COFF_SYM_CLASS_STATIC,0);
 WriteCoffSymbol(F,SectionName(AS_DATA),0,CoffSectionNumber(AS_DATA),
                 COFF_SYM_CLASS_STATIC,0);
 WriteCoffSymbol(F,SectionName(AS_BSS),0,CoffSectionNumber(AS_BSS),
                 COFF_SYM_CLASS_STATIC,0);
 WriteCoffSymbol(F,EntryName,0,CoffSectionNumber(AS_TEXT),
                 COFF_SYM_CLASS_EXTERNAL,
                 CoffLongNameOffset(EntryName,EntryName,SourceLabel,ModuleLabel));
 WriteCoffSymbol(F,SourceLabel,0,CoffSectionNumber(AS_DATA),
                 COFF_SYM_CLASS_STATIC,
                 CoffLongNameOffset(SourceLabel,EntryName,SourceLabel,ModuleLabel));
 WriteCoffSymbol(F,ModuleLabel,Length(Pipeline.SourceName)+1,
                 CoffSectionNumber(AS_DATA),COFF_SYM_CLASS_STATIC,
                 CoffLongNameOffset(ModuleLabel,EntryName,SourceLabel,ModuleLabel));
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_VAR) And
     (SemanticSymbols[I].Storage=STORAGE_GLOBAL_DATA) Then
   WriteCoffSymbol(F,SemanticSymbols[I].AsmLabel,
                   GlobalDataBase+SemanticSymbols[I].Offset,
                   CoffSectionNumber(AS_DATA),COFF_SYM_CLASS_STATIC,
                   CoffLongNameOffset(SemanticSymbols[I].AsmLabel,
                    EntryName,SourceLabel,ModuleLabel))
  Else If (SemanticSymbols[I].Kind=SYM_VAR) And
          (SemanticSymbols[I].Storage=STORAGE_GLOBAL_BSS) Then
   WriteCoffSymbol(F,SemanticSymbols[I].AsmLabel,
                   SemanticSymbols[I].Offset,
                   CoffSectionNumber(AS_BSS),COFF_SYM_CLASS_STATIC,
                   CoffLongNameOffset(SemanticSymbols[I].AsmLabel,
                    EntryName,SourceLabel,ModuleLabel));
 WriteCoffStringTable(F,EntryName,SourceLabel,ModuleLabel);
 Close(F);
 If IOResult<>0 Then Begin
  PipelineError('ecriture incomplete de '+FileName);
  Exit;
 End;
 WriteCoffI386File:=True;
End;

Procedure WriteRawZeroBytes(Var F:File;Count:LongInt);
Var
 I:LongInt;
Begin
 For I:=1 To Count Do WriteRawByte(F,0);
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

Type
 TFlowControl = (FC_NORMAL, FC_RETURN, FC_EXIT);

 TRuntimeValue = Record
  Kind           : TConstKind;
  IntValue       : LongInt;
  RealValue      : Extended;
  TextValue      : String[255];
  RefSymbolIndex : Integer;
 End;

 TStackFrame = Record
  ScopeIndex : Integer;
  LocalValues: Array[1..MOD3_MAX_SYMBOLS] Of TRuntimeValue;
 End;

Var
 GlobalValues  : Array[1..MOD3_MAX_SYMBOLS] Of TRuntimeValue;
 CallStack     : Array[1..256] Of TStackFrame;
 StackTop      : Integer;
 OutputText    : String;
 FlowControl   : TFlowControl;
 ReturnVal     : TRuntimeValue;
 NextRefIdx    : Integer;
 StoreKeys     : Array[1..4096] Of String[127];
 StoreValues   : Array[1..4096] Of TRuntimeValue;
 StoreCount    : Integer;

Procedure AppendRuntimeOutput(Var Output:String;Text:String;LineNo,ColumnNo:Integer);
Begin
 If Length(Output)+Length(Text)>255 Then Begin
  If Length(Output)<255 Then
   Output:=Output+Copy(Text,1,255-Length(Output));
  Exit;
 End;
 Output:=Output+Text;
End;

Function ConstToRuntime(CV: TConstValue): TRuntimeValue;
Var
 RV: TRuntimeValue;
Begin
 RV.Kind := CV.Kind;
 RV.IntValue := CV.IntegerVal;
 RV.RealValue := CV.RealVal;
 RV.TextValue := CV.TextVal;
 RV.RefSymbolIndex := 0;
 ConstToRuntime := RV;
End;

Function LiteralToRuntime(Node: TIRNode): TRuntimeValue;
Var
 RV: TRuntimeValue;
 TK: TTypeKind;
Begin
 FillChar(RV, SizeOf(RV), 0);
 If Node.TypeIndex <> 0 Then TK := SemanticTypes[Node.TypeIndex].Kind
 Else TK := TYPE_INTEGER;
 
 Case TK Of
  TYPE_REAL, TYPE_LONGREAL: Begin
   RV.Kind := CONST_REAL;
   RV.RealValue := Node.RealVal;
  End;
  TYPE_BOOLEAN: Begin
   RV.Kind := CONST_BOOLEAN;
   RV.IntValue := Node.IntegerVal;
  End;
  TYPE_CHAR: Begin
   RV.Kind := CONST_CHAR;
   RV.IntValue := Node.IntegerVal;
  End;
  TYPE_TEXT: Begin
   RV.Kind := CONST_TEXT;
   RV.TextValue := Node.Text;
  End;
  TYPE_NIL: Begin
   RV.Kind := CONST_NIL;
   RV.IntValue := 0;
  End;
  Else Begin
   RV.Kind := CONST_INTEGER;
   RV.IntValue := Node.IntegerVal;
  End;
 End;
 LiteralToRuntime := RV;
End;

Function GetSymbolScopeFrame(SymbolIndex: Integer): Integer;
Var
 S: Integer;
 TargetScope: Integer;
Begin
 GetSymbolScopeFrame := 0;
 If (SymbolIndex < 1) Or (SymbolIndex > SemanticSymbolCount) Then Exit;
 TargetScope := SemanticSymbols[SymbolIndex].ScopeIndex;
 For S := StackTop DownTo 1 Do Begin
  If CallStack[S].ScopeIndex = TargetScope Then Begin
   GetSymbolScopeFrame := S;
   Exit;
  End;
 End;
End;

Function GetPathValue(Path: String): TRuntimeValue;
Var
 I: Integer;
 RV: TRuntimeValue;
Begin
 For I := 1 To StoreCount Do Begin
  If StoreKeys[I] = Path Then Begin
   GetPathValue := StoreValues[I];
   Exit;
  End;
 End;
 FillChar(RV, SizeOf(RV), 0);
 RV.Kind := CONST_INTEGER;
 GetPathValue := RV;
End;

Procedure SetPathValue(Path: String; Val: TRuntimeValue);
Var
 I: Integer;
Begin
 For I := 1 To StoreCount Do Begin
  If StoreKeys[I] = Path Then Begin
   StoreValues[I] := Val;
   Exit;
  End;
 End;
 If StoreCount < 4096 Then Begin
  Inc(StoreCount);
  StoreKeys[StoreCount] := Path;
  StoreValues[StoreCount] := Val;
 End Else Begin
  WriteLn('Erreur: debordement du dictionnaire de l''interpreteur.');
  Halt(1);
 End;
End;

Function EvalPath(NodeIndex: Integer): String; Forward;
Function EvalIR(NodeIndex: Integer): TRuntimeValue; Forward;
Procedure ExecuteScope(ScopeIndex: Integer); Forward;
Procedure ExecuteStatement(Var PC: Integer); Forward;
Procedure ExecuteBlock(ParentIdx: Integer; Var PC: Integer); Forward;
Procedure SkipToNextBranch(ParentIdx: Integer; Var PC: Integer); Forward;
Procedure SkipToBlockEnd(ParentIdx: Integer; Var PC: Integer); Forward;
Procedure ExecuteBlockUntil(ParentIdx: Integer; Var PC: Integer); Forward;
Procedure SkipToUntilEnd(ParentIdx: Integer; Var PC: Integer); Forward;

Procedure SetValueForNode(NodeIndex: Integer; Val: TRuntimeValue);
Var
 P: String;
Begin
 P := EvalPath(NodeIndex);
 If P <> '' Then SetPathValue(P, Val);
End;

Function EvalPath(NodeIndex: Integer): String;
Var
 Node: TIRNode;
 BasePath: String;
 IndexVal: TRuntimeValue;
 FrameIdx: Integer;
 RefSym: Integer;
Begin
 EvalPath := '';
 If (NodeIndex < 1) Or (NodeIndex > IRNodeCount) Then Exit;
 Node := IRNodes[NodeIndex];
 
 Case Node.Kind Of
  IR_SYMBOL: Begin
   If (Node.SymbolIndex < 1) Or (Node.SymbolIndex > SemanticSymbolCount) Then Exit;
   If SemanticSymbols[Node.SymbolIndex].ParamMode = PARAM_VAR Then Begin
    FrameIdx := GetSymbolScopeFrame(Node.SymbolIndex);
    If FrameIdx > 0 Then Begin
     RefSym := CallStack[FrameIdx].LocalValues[Node.SymbolIndex].RefSymbolIndex;
     If RefSym > 0 Then Begin
      If (SemanticSymbols[RefSym].Storage = STORAGE_GLOBAL_DATA) Or
         (SemanticSymbols[RefSym].Storage = STORAGE_GLOBAL_BSS) Then
       EvalPath := 'G_S' + IntToString(RefSym)
      Else Begin
       FrameIdx := GetSymbolScopeFrame(RefSym);
       EvalPath := 'F' + IntToString(FrameIdx) + '_S' + IntToString(RefSym);
      End;
     End;
    End;
   End Else If (SemanticSymbols[Node.SymbolIndex].Storage = STORAGE_GLOBAL_DATA) Or
              (SemanticSymbols[Node.SymbolIndex].Storage = STORAGE_GLOBAL_BSS) Then Begin
    EvalPath := 'G_S' + IntToString(Node.SymbolIndex);
   End Else Begin
    FrameIdx := GetSymbolScopeFrame(Node.SymbolIndex);
    EvalPath := 'F' + IntToString(FrameIdx) + '_S' + IntToString(Node.SymbolIndex);
   End;
  End;
  
  IR_INDEX: Begin
   BasePath := EvalPath(Node.Left);
   IndexVal := EvalIR(Node.Right);
   EvalPath := BasePath + '[' + IntToString(IndexVal.IntValue) + ']';
  End;
  
  IR_FIELD: Begin
   BasePath := EvalPath(Node.Left);
   EvalPath := BasePath + '.' + IntToString(Node.SymbolIndex);
  End;
  
  IR_DEREF: Begin
   IndexVal := EvalIR(Node.Left);
   If IndexVal.IntValue > 0 Then
    EvalPath := 'REF_' + IntToString(IndexVal.IntValue) + '^'
   Else
    EvalPath := 'NIL^';
  End;
 End;
End;

Function FindProcedureByAsmLabel(ALabel: String): Integer;
Var
 I: Integer;
Begin
 FindProcedureByAsmLabel := 0;
 For I := 1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind = SYM_PROCEDURE) And (SemanticSymbols[I].AsmLabel = ALabel) Then Begin
   FindProcedureByAsmLabel := I;
   Exit;
  End;
End;

Function CallUserProcedure(ProcSymbol: Integer; ArgsNode: Integer; ArgCount: Integer): TRuntimeValue;
Var
 I, FormalIndex, ScopeIdx: Integer;
 Actuals: Array[1..64] Of TRuntimeValue;
 SavedFlow: TFlowControl;
 Res: TRuntimeValue;
 ArgNodeIdx: Integer;
Begin
 FillChar(Res, SizeOf(Res), 0);
 Res.Kind := CONST_NIL;
 CallUserProcedure := Res;
 ScopeIdx := SemanticSymbols[ProcSymbol].ProcScope;
 If ScopeIdx = 0 Then Exit;

 For I := 1 To ArgCount Do Begin
  FormalIndex := NthFormalParameter(ProcSymbol, I);
  If (FormalIndex <> 0) And (SemanticSymbols[FormalIndex].ParamMode = PARAM_VAR) Then Begin
   Actuals[I].Kind := CONST_INTEGER;
   Actuals[I].IntValue := 0;
   Actuals[I].RefSymbolIndex := 0;
   
   ArgNodeIdx := IRArguments[IRNodes[ArgsNode].FirstArg + I - 1];
   If IRNodes[ArgNodeIdx].Kind = IR_SYMBOL Then
    Actuals[I].RefSymbolIndex := IRNodes[ArgNodeIdx].SymbolIndex;
  End Else Begin
   Actuals[I] := EvalIR(IRArguments[IRNodes[ArgsNode].FirstArg + I - 1]);
  End;
 End;

 Inc(StackTop);
 If StackTop > 256 Then Begin
  WriteLn('Erreur: debordement de pile lors de l''interpretation.');
  Halt(1);
 End;
 CallStack[StackTop].ScopeIndex := ScopeIdx;
 FillChar(CallStack[StackTop].LocalValues, SizeOf(CallStack[StackTop].LocalValues), 0);

 For I := 1 To ArgCount Do Begin
  FormalIndex := NthFormalParameter(ProcSymbol, I);
  If FormalIndex <> 0 Then
   CallStack[StackTop].LocalValues[FormalIndex] := Actuals[I];
 End;

 SavedFlow := FlowControl;
 FlowControl := FC_NORMAL;
 ExecuteScope(ScopeIdx);
 
 If FlowControl = FC_RETURN Then
  Res := ReturnVal;

 FlowControl := SavedFlow;
 Dec(StackTop);
 CallUserProcedure := Res;
End;

Function CallMethod(ReceiverNode, VirtualSlot, ArgsNode, ArgCount, Line, Column: Integer): TRuntimeValue;
Var
 ObjVal: TRuntimeValue;
 ObjID, DynType, MethodSymbol, ProcSymbol, FormalIndex, ScopeIdx, I: Integer;
 Actuals: Array[1..64] Of TRuntimeValue;
 SavedFlow: TFlowControl;
 Res: TRuntimeValue;
 ArgNodeIdx: Integer;
Begin
 FillChar(Res, SizeOf(Res), 0);
 Res.Kind := CONST_NIL;
 CallMethod := Res;
 
 ObjVal := EvalIR(ReceiverNode);
 ObjID := ObjVal.IntValue;
 If ObjID = 0 Then Begin
  SemanticError('Derez de pointeur NIL dans l''appel de methode', Line, Column);
  Halt(1);
 End;
 
 DynType := GetPathValue('REF_' + IntToString(ObjID) + '.TYPE').IntValue;
 If DynType = 0 Then Begin
  SemanticError('Objet non initialise ou type inconnu', Line, Column);
  Halt(1);
 End;
 
 MethodSymbol := ObjectMethodForSlot(DynType, VirtualSlot);
 If MethodSymbol = 0 Then Begin
  SemanticError('Methode non trouvee pour le slot ' + IntToString(VirtualSlot), Line, Column);
  Halt(1);
 End;
 
 ProcSymbol := SemanticSymbols[MethodSymbol].MethodImpl;
 If ProcSymbol = 0 Then Begin
  If SemanticSymbols[MethodSymbol].AsmLabel <> '' Then Begin
   ProcSymbol := FindProcedureByAsmLabel(SemanticSymbols[MethodSymbol].AsmLabel);
  End;
 End;
 
 If ProcSymbol = 0 Then Begin
  SemanticError('Implementation de methode non trouvee pour ' + SemanticSymbols[MethodSymbol].Name, Line, Column);
  Halt(1);
 End;
 
 ScopeIdx := SemanticSymbols[ProcSymbol].ProcScope;
 If ScopeIdx = 0 Then Exit;

 For I := 1 To ArgCount Do Begin
  FormalIndex := NthFormalParameter(ProcSymbol, I + 1);
  If (FormalIndex <> 0) And (SemanticSymbols[FormalIndex].ParamMode = PARAM_VAR) Then Begin
   Actuals[I].Kind := CONST_INTEGER;
   Actuals[I].IntValue := 0;
   Actuals[I].RefSymbolIndex := 0;
   
   ArgNodeIdx := IRArguments[IRNodes[ArgsNode].FirstArg + I - 1];
   If IRNodes[ArgNodeIdx].Kind = IR_SYMBOL Then
    Actuals[I].RefSymbolIndex := IRNodes[ArgNodeIdx].SymbolIndex;
  End Else Begin
   Actuals[I] := EvalIR(IRArguments[IRNodes[ArgsNode].FirstArg + I - 1]);
  End;
 End;

 Inc(StackTop);
 If StackTop > 256 Then Begin
  WriteLn('Erreur: debordement de pile lors de l''interpretation.');
  Halt(1);
 End;
 CallStack[StackTop].ScopeIndex := ScopeIdx;
 FillChar(CallStack[StackTop].LocalValues, SizeOf(CallStack[StackTop].LocalValues), 0);

 FormalIndex := NthFormalParameter(ProcSymbol, 1);
 If FormalIndex <> 0 Then
  CallStack[StackTop].LocalValues[FormalIndex] := ObjVal;

 For I := 1 To ArgCount Do Begin
  FormalIndex := NthFormalParameter(ProcSymbol, I + 1);
  If FormalIndex <> 0 Then
   CallStack[StackTop].LocalValues[FormalIndex] := Actuals[I];
 End;

 SavedFlow := FlowControl;
 FlowControl := FC_NORMAL;
 ExecuteScope(ScopeIdx);
 
 If FlowControl = FC_RETURN Then
  Res := ReturnVal;

 FlowControl := SavedFlow;
 Dec(StackTop);
 CallMethod := Res;
End;

Function EvalIR(NodeIndex: Integer): TRuntimeValue;
Var
 Node: TIRNode;
 RV, LeftVal, RightVal, Res: TRuntimeValue;
 TK: TTypeKind;
 P, TextStr: String;
 ValReal: Extended;
 TypeIndex, ObjID, DynType, MethodSymbol, ProcSymbol, FormalIndex, ScopeIdx, I: Integer;
 SavedFlow: TFlowControl;
 Name: String;
 ArgVal, ArgVal2, ArgVal3: TRuntimeValue;
 LReal, RReal: Extended;
 ArgNodeIdx, ArgType: Integer;
 TypeVal: TRuntimeValue;
 DefVal: TRuntimeValue;
Begin
 FillChar(RV, SizeOf(RV), 0);
 EvalIR := RV;
 If (NodeIndex < 1) Or (NodeIndex > IRNodeCount) Then Exit;
 Node := IRNodes[NodeIndex];
 
 Case Node.Kind Of
  IR_LITERAL: Begin
   EvalIR := LiteralToRuntime(Node);
  End;
  
  IR_SYMBOL: Begin
   If SemanticSymbols[Node.SymbolIndex].Kind = SYM_CONST Then
    EvalIR := ConstToRuntime(SemanticSymbols[Node.SymbolIndex].ConstValue)
   Else Begin
    P := EvalPath(NodeIndex);
    EvalIR := GetPathValue(P);
   End;
  End;
  
  IR_INDEX, IR_FIELD, IR_DEREF: Begin
   P := EvalPath(NodeIndex);
   EvalIR := GetPathValue(P);
  End;
  
  IR_UNARY: Begin
   LeftVal := EvalIR(Node.Left);
   Res := LeftVal;
   If Node.OperatorText = '-' Then Begin
    If Res.Kind = CONST_REAL Then Res.RealValue := -Res.RealValue
    Else Res.IntValue := -Res.IntValue;
   End Else If (UpperStr(Node.OperatorText) = 'NOT') Then Begin
    If Res.IntValue = 0 Then Res.IntValue := 1 Else Res.IntValue := 0;
   End;
   EvalIR := Res;
  End;
  
  IR_BINARY: Begin
   LeftVal := EvalIR(Node.Left);
   RightVal := EvalIR(Node.Right);
   FillChar(Res, SizeOf(Res), 0);
   If (LeftVal.Kind = CONST_REAL) Or (RightVal.Kind = CONST_REAL) Then Begin
    If LeftVal.Kind = CONST_REAL Then LReal := LeftVal.RealValue Else LReal := LeftVal.IntValue;
    If RightVal.Kind = CONST_REAL Then RReal := RightVal.RealValue Else RReal := RightVal.IntValue;
    Res.Kind := CONST_REAL;
    If Node.OperatorText = '+' Then Res.RealValue := LReal + RReal
    Else If Node.OperatorText = '-' Then Res.RealValue := LReal - RReal
    Else If Node.OperatorText = '*' Then Res.RealValue := LReal * RReal
    Else If (Node.OperatorText = '/') Or (UpperStr(Node.OperatorText) = 'DIV') Then Begin
     If RReal <> 0.0 Then Res.RealValue := LReal / RReal Else Res.RealValue := 0.0;
    End;
   End Else If (LeftVal.Kind = CONST_TEXT) Or (RightVal.Kind = CONST_TEXT) Or (Node.OperatorText = '&') Then Begin
    Res.Kind := CONST_TEXT;
    Res.TextValue := LeftVal.TextValue + RightVal.TextValue;
   End Else Begin
    Res.Kind := CONST_INTEGER;
    If Node.OperatorText = '+' Then Res.IntValue := LeftVal.IntValue + RightVal.IntValue
    Else If Node.OperatorText = '-' Then Res.IntValue := LeftVal.IntValue - RightVal.IntValue
    Else If Node.OperatorText = '*' Then Res.IntValue := LeftVal.IntValue * RightVal.IntValue
    Else If UpperStr(Node.OperatorText) = 'DIV' Then Begin
     If RightVal.IntValue <> 0 Then Res.IntValue := LeftVal.IntValue Div RightVal.IntValue Else Res.IntValue := 0;
    End Else If UpperStr(Node.OperatorText) = 'MOD' Then Begin
     If RightVal.IntValue <> 0 Then Res.IntValue := LeftVal.IntValue Mod RightVal.IntValue Else Res.IntValue := 0;
    End;
   End;
   EvalIR := Res;
  End;
  
  IR_COMPARE: Begin
   LeftVal := EvalIR(Node.Left);
   RightVal := EvalIR(Node.Right);
   FillChar(Res, SizeOf(Res), 0);
   Res.Kind := CONST_BOOLEAN;
   Res.IntValue := 0;
   If (LeftVal.Kind = CONST_REAL) Or (RightVal.Kind = CONST_REAL) Then Begin
    If LeftVal.Kind = CONST_REAL Then LReal := LeftVal.RealValue Else LReal := LeftVal.IntValue;
    If RightVal.Kind = CONST_REAL Then RReal := RightVal.RealValue Else RReal := RightVal.IntValue;
    If Node.OperatorText = '=' Then Begin If LReal = RReal Then Res.IntValue := 1; End
    Else If Node.OperatorText = '<>' Then Begin If LReal <> RReal Then Res.IntValue := 1; End
    Else If Node.OperatorText = '<' Then Begin If LReal < RReal Then Res.IntValue := 1; End
    Else If Node.OperatorText = '<=' Then Begin If LReal <= RReal Then Res.IntValue := 1; End
    Else If Node.OperatorText = '>' Then Begin If LReal > RReal Then Res.IntValue := 1; End
    Else If Node.OperatorText = '>=' Then Begin If LReal >= RReal Then Res.IntValue := 1; End;
   End Else If (LeftVal.Kind = CONST_TEXT) Or (RightVal.Kind = CONST_TEXT) Then Begin
    If Node.OperatorText = '=' Then Begin If LeftVal.TextValue = RightVal.TextValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '<>' Then Begin If LeftVal.TextValue <> RightVal.TextValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '<' Then Begin If LeftVal.TextValue < RightVal.TextValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '<=' Then Begin If LeftVal.TextValue <= RightVal.TextValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '>' Then Begin If LeftVal.TextValue > RightVal.TextValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '>=' Then Begin If LeftVal.TextValue >= RightVal.TextValue Then Res.IntValue := 1; End;
   End Else Begin
    If Node.OperatorText = '=' Then Begin If LeftVal.IntValue = RightVal.IntValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '<>' Then Begin If LeftVal.IntValue <> RightVal.IntValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '<' Then Begin If LeftVal.IntValue < RightVal.IntValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '<=' Then Begin If LeftVal.IntValue <= RightVal.IntValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '>' Then Begin If LeftVal.IntValue > RightVal.IntValue Then Res.IntValue := 1; End
    Else If Node.OperatorText = '>=' Then Begin If LeftVal.IntValue >= RightVal.IntValue Then Res.IntValue := 1; End;
   End;
   EvalIR := Res;
  End;
  
  IR_AND_SHORT: Begin
   LeftVal := EvalIR(Node.Left);
   FillChar(Res, SizeOf(Res), 0);
   Res.Kind := CONST_BOOLEAN;
   If LeftVal.IntValue = 0 Then Res.IntValue := 0
   Else Begin
    RightVal := EvalIR(Node.Right);
    Res.IntValue := RightVal.IntValue;
   End;
   EvalIR := Res;
  End;
  
  IR_OR_SHORT: Begin
   LeftVal := EvalIR(Node.Left);
   FillChar(Res, SizeOf(Res), 0);
   Res.Kind := CONST_BOOLEAN;
   If LeftVal.IntValue <> 0 Then Res.IntValue := 1
   Else Begin
    RightVal := EvalIR(Node.Right);
    Res.IntValue := RightVal.IntValue;
   End;
   EvalIR := Res;
  End;
  
  IR_CALL: Begin
   Name := UpperStr(Node.Text);
   FillChar(Res, SizeOf(Res), 0);
   Res.Kind := CONST_NIL;
   
   If (Name = 'NEW') Then Begin
    TypeIndex := CanonicalType(Node.TypeIndex);
    Inc(NextRefIdx);
    Res.Kind := CONST_INTEGER;
    Res.IntValue := NextRefIdx;
    
    If (TypeIndex <> 0) And (SemanticTypes[TypeIndex].Kind = TYPE_OBJECT) Then Begin
     TypeVal.Kind := CONST_INTEGER;
     TypeVal.IntValue := TypeIndex;
     SetPathValue('REF_' + IntToString(NextRefIdx) + '.TYPE', TypeVal);
    End;
    
    FillChar(DefVal, SizeOf(DefVal), 0);
    DefVal.Kind := CONST_INTEGER;
    SetPathValue('REF_' + IntToString(NextRefIdx) + '^', DefVal);
    EvalIR := Res;
   End Else If (Name = 'DISPOSE') Then Begin
    EvalIR := Res;
   End Else If (Name = 'WR.PUTTEXT') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    AppendRuntimeOutput(OutputText, ArgVal.TextValue, Node.Line, Node.Column);
    EvalIR := Res;
   End Else If (Name = 'WR.NL') Then Begin
    AppendRuntimeOutput(OutputText, #13#10, Node.Line, Node.Column);
    EvalIR := Res;
   End Else If (Name = 'WR.PUTINT') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    Str(ArgVal.IntValue, TextStr);
    AppendRuntimeOutput(OutputText, TextStr, Node.Line, Node.Column);
    EvalIR := Res;
   End Else If (Name = 'WR.PUTCHAR') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    TextStr := Chr(ArgVal.IntValue And $FF);
    AppendRuntimeOutput(OutputText, TextStr, Node.Line, Node.Column);
    EvalIR := Res;
   End Else If (Name = 'WR.PUTBOOL') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    If ArgVal.IntValue <> 0 Then TextStr := 'TRUE' Else TextStr := 'FALSE';
    AppendRuntimeOutput(OutputText, TextStr, Node.Line, Node.Column);
    EvalIR := Res;
   End Else If (Name = 'WR.PUTREAL') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    If ArgVal.Kind = CONST_REAL Then ValReal := ArgVal.RealValue Else ValReal := ArgVal.IntValue;
    Str(ValReal:0:0, TextStr);
    AppendRuntimeOutput(OutputText, TextStr, Node.Line, Node.Column);
    EvalIR := Res;
   End Else If (Name = 'FMT.INT') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    Str(ArgVal.IntValue, TextStr);
    Res.Kind := CONST_TEXT;
    Res.TextValue := TextStr;
    EvalIR := Res;
   End Else If (Name = 'FMT.CHAR') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    Res.Kind := CONST_TEXT;
    Res.TextValue := Chr(ArgVal.IntValue And $FF);
    EvalIR := Res;
   End Else If (Name = 'FMT.BOOL') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    Res.Kind := CONST_TEXT;
    If ArgVal.IntValue <> 0 Then Res.TextValue := 'TRUE' Else Res.TextValue := 'FALSE';
    EvalIR := Res;
   End Else If (Name = 'TEXT.LENGTH') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    Res.Kind := CONST_INTEGER;
    Res.IntValue := Length(ArgVal.TextValue);
    EvalIR := Res;
   End Else If (Name = 'TEXT.GETCHAR') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    ArgVal2 := EvalIR(IRArguments[Node.FirstArg+1]);
    Res.Kind := CONST_CHAR;
    If (ArgVal2.IntValue >= 0) And (ArgVal2.IntValue < Length(ArgVal.TextValue)) Then
     Res.IntValue := Ord(ArgVal.TextValue[ArgVal2.IntValue + 1])
    Else Res.IntValue := 0;
    EvalIR := Res;
   End Else If (Name = 'TEXT.CAT') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    ArgVal2 := EvalIR(IRArguments[Node.FirstArg+1]);
    Res.Kind := CONST_TEXT;
    Res.TextValue := ArgVal.TextValue + ArgVal2.TextValue;
    EvalIR := Res;
   End Else If (Name = 'TEXT.EQUAL') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    ArgVal2 := EvalIR(IRArguments[Node.FirstArg+1]);
    Res.Kind := CONST_BOOLEAN;
    If ArgVal.TextValue = ArgVal2.TextValue Then Res.IntValue := 1 Else Res.IntValue := 0;
    EvalIR := Res;
   End Else If (Name = 'TEXT.SUB') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    ArgVal2 := EvalIR(IRArguments[Node.FirstArg+1]);
    ArgVal3 := EvalIR(IRArguments[Node.FirstArg+2]);
    Res.Kind := CONST_TEXT;
    Res.TextValue := Copy(ArgVal.TextValue, ArgVal2.IntValue + 1, ArgVal3.IntValue);
    EvalIR := Res;
   End Else If (Name = 'ABS') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    Res := ArgVal;
    If Res.Kind = CONST_REAL Then Begin
     If Res.RealValue < 0.0 Then Res.RealValue := -Res.RealValue;
    End Else Begin
     If Res.IntValue < 0 Then Res.IntValue := -Res.IntValue;
    End;
    EvalIR := Res;
   End Else If (Name = 'MAX') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    ArgVal2 := EvalIR(IRArguments[Node.FirstArg+1]);
    If (ArgVal.Kind = CONST_REAL) Or (ArgVal2.Kind = CONST_REAL) Then Begin
     If ArgVal.Kind = CONST_REAL Then LReal := ArgVal.RealValue Else LReal := ArgVal.IntValue;
     If ArgVal2.Kind = CONST_REAL Then RReal := ArgVal2.RealValue Else RReal := ArgVal2.IntValue;
     Res.Kind := CONST_REAL;
     If LReal > RReal Then Res.RealValue := LReal Else Res.RealValue := RReal;
    End Else Begin
     Res.Kind := CONST_INTEGER;
     If ArgVal.IntValue > ArgVal2.IntValue Then Res.IntValue := ArgVal.IntValue Else Res.IntValue := ArgVal2.IntValue;
    End;
    EvalIR := Res;
   End Else If (Name = 'MIN') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    ArgVal2 := EvalIR(IRArguments[Node.FirstArg+1]);
    If (ArgVal.Kind = CONST_REAL) Or (ArgVal2.Kind = CONST_REAL) Then Begin
     If ArgVal.Kind = CONST_REAL Then LReal := ArgVal.RealValue Else LReal := ArgVal.IntValue;
     If ArgVal2.Kind = CONST_REAL Then RReal := ArgVal2.RealValue Else RReal := ArgVal2.IntValue;
     Res.Kind := CONST_REAL;
     If LReal < RReal Then Res.RealValue := LReal Else Res.RealValue := RReal;
    End Else Begin
     Res.Kind := CONST_INTEGER;
     If ArgVal.IntValue < ArgVal2.IntValue Then Res.IntValue := ArgVal.IntValue Else Res.IntValue := ArgVal2.IntValue;
    End;
    EvalIR := Res;
   End Else If (Name = 'TYPECODE') Then Begin
    TypeIndex := 0;
    If Node.ArgCount = 1 Then
     TypeIndex := CanonicalType(IRNodes[IRArguments[Node.FirstArg]].TypeIndex);
    Res.Kind := CONST_INTEGER;
    If TypeIndex <> 0 Then Res.IntValue := SemanticTypes[TypeIndex].TypeCode Else Res.IntValue := 0;
    EvalIR := Res;
   End Else If (Name = 'NUMBER') Then Begin
    ArgNodeIdx := IRArguments[Node.FirstArg];
    ArgType := CanonicalType(IRNodes[ArgNodeIdx].TypeIndex);
    Res.Kind := CONST_INTEGER;
    If (ArgType <> 0) And (SemanticTypes[ArgType].Kind = TYPE_ARRAY) Then Begin
     Res.IntValue := SemanticTypes[ArgType].HighBound - SemanticTypes[ArgType].LowBound + 1;
    End Else Begin
     Res.IntValue := 0;
    End;
    EvalIR := Res;
   End Else If (Name = 'FIRST') Then Begin
    ArgNodeIdx := IRArguments[Node.FirstArg];
    ArgType := CanonicalType(IRNodes[ArgNodeIdx].TypeIndex);
    Res.Kind := CONST_INTEGER;
    If (ArgType <> 0) And (SemanticTypes[ArgType].Kind = TYPE_ARRAY) Then Begin
     Res.IntValue := SemanticTypes[ArgType].LowBound;
    End Else Begin
     Res.IntValue := 0;
    End;
    EvalIR := Res;
   End Else If (Name = 'LAST') Then Begin
    ArgNodeIdx := IRArguments[Node.FirstArg];
    ArgType := CanonicalType(IRNodes[ArgNodeIdx].TypeIndex);
    Res.Kind := CONST_INTEGER;
    If (ArgType <> 0) And (SemanticTypes[ArgType].Kind = TYPE_ARRAY) Then Begin
     Res.IntValue := SemanticTypes[ArgType].HighBound;
    End Else Begin
     Res.IntValue := 0;
    End;
    EvalIR := Res;
   End Else If (Name = 'FLOAT') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    Res.Kind := CONST_REAL;
    If ArgVal.Kind = CONST_REAL Then Res.RealValue := ArgVal.RealValue
    Else Res.RealValue := ArgVal.IntValue;
    EvalIR := Res;
   End Else If (Name = 'ORD') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    Res.Kind := CONST_INTEGER;
    Res.IntValue := ArgVal.IntValue;
    EvalIR := Res;
   End Else If (Name = 'TRUNC') Then Begin
    ArgVal := EvalIR(IRArguments[Node.FirstArg]);
    Res.Kind := CONST_INTEGER;
    If ArgVal.Kind = CONST_REAL Then Res.IntValue := Trunc(ArgVal.RealValue)
    Else Res.IntValue := ArgVal.IntValue;
    EvalIR := Res;
   End Else If Node.Receiver <> 0 Then Begin
    EvalIR := CallMethod(Node.Receiver, Node.VirtualSlot, NodeIndex, Node.ArgCount, Node.Line, Node.Column);
   End Else If (Node.SymbolIndex <> 0) And
              (SemanticSymbols[Node.SymbolIndex].Kind = SYM_PROCEDURE) And
              (SemanticSymbols[Node.SymbolIndex].ProcScope <> 0) Then Begin
    EvalIR := CallUserProcedure(Node.SymbolIndex, NodeIndex, Node.ArgCount);
   End Else Begin
    SemanticError('appel a une procedure inconnue: ' + Node.Text, Node.Line, Node.Column);
   End;
  End;
 End;
End;

Procedure ExecuteScope(ScopeIndex: Integer);
Var
 PC: Integer;
Begin
 PC := 1;
 While (PC <= StatementCount) And (FlowControl = FC_NORMAL) Do Begin
  If (StatementIR[PC].ScopeIndex = ScopeIndex) And (StatementIR[PC].ParentIndex = 0) Then Begin
   ExecuteStatement(PC);
  End Else Begin
   Inc(PC);
  End;
 End;
End;

Procedure ExecuteBlock(ParentIdx: Integer; Var PC: Integer);
Var
 S: TStatementIR;
Begin
 While (PC <= StatementCount) And (FlowControl = FC_NORMAL) Do Begin
  S := StatementIR[PC];
  If (S.ScopeIndex <> CallStack[StackTop].ScopeIndex) Or (S.ParentIndex <> ParentIdx) Then
   Exit;
  If (S.Kind = ST_ELSIF) Or (S.Kind = ST_ELSE) Or (S.Kind = ST_BLOCK_END) Or
     (S.Kind = ST_CASE_ARM) Or (S.Kind = ST_CASE_ELSE) Then
   Exit;
  ExecuteStatement(PC);
 End;
End;

Procedure SkipToNextBranch(ParentIdx: Integer; Var PC: Integer);
Var
 Depth: Integer;
 S: TStatementIR;
Begin
 Depth := 0;
 While PC <= StatementCount Do Begin
  S := StatementIR[PC];
  If S.ScopeIndex = CallStack[StackTop].ScopeIndex Then Begin
   If (S.ParentIndex = ParentIdx) And (Depth = 0) Then Begin
    If (S.Kind = ST_ELSIF) Or (S.Kind = ST_ELSE) Or (S.Kind = ST_BLOCK_END) Then
     Exit;
   End;
   If S.Kind In [ST_IF, ST_WHILE, ST_FOR, ST_LOOP, ST_REPEAT, ST_CASE] Then
    Inc(Depth)
   Else If S.Kind = ST_BLOCK_END Then
    Dec(Depth);
  End;
  Inc(PC);
 End;
End;

Procedure SkipToBlockEnd(ParentIdx: Integer; Var PC: Integer);
Var
 Depth: Integer;
 S: TStatementIR;
Begin
 Depth := 0;
 While PC <= StatementCount Do Begin
  S := StatementIR[PC];
  If S.ScopeIndex = CallStack[StackTop].ScopeIndex Then Begin
   If (S.ParentIndex = ParentIdx) And (S.Kind = ST_BLOCK_END) And (Depth = 0) Then Begin
    Inc(PC);
    Exit;
   End;
   If S.Kind In [ST_IF, ST_WHILE, ST_FOR, ST_LOOP, ST_REPEAT, ST_CASE] Then
    Inc(Depth)
   Else If S.Kind = ST_BLOCK_END Then
    Dec(Depth);
  End;
  Inc(PC);
 End;
End;

Procedure ExecuteBlockUntil(ParentIdx: Integer; Var PC: Integer);
Var
 S: TStatementIR;
Begin
 While (PC <= StatementCount) And (FlowControl = FC_NORMAL) Do Begin
  S := StatementIR[PC];
  If (S.ScopeIndex <> CallStack[StackTop].ScopeIndex) Or (S.ParentIndex <> ParentIdx) Then
   Exit;
  If S.Kind = ST_UNTIL Then
   Exit;
  ExecuteStatement(PC);
 End;
End;

Procedure SkipToUntilEnd(ParentIdx: Integer; Var PC: Integer);
Var
 Depth: Integer;
 S: TStatementIR;
Begin
 Depth := 0;
 While PC <= StatementCount Do Begin
  S := StatementIR[PC];
  If S.ScopeIndex = CallStack[StackTop].ScopeIndex Then Begin
   If (S.ParentIndex = ParentIdx) And (S.Kind = ST_UNTIL) And (Depth = 0) Then Begin
    Inc(PC);
    Exit;
   End;
   If S.Kind In [ST_IF, ST_WHILE, ST_FOR, ST_LOOP, ST_REPEAT, ST_CASE] Then
    Inc(Depth)
   Else If S.Kind = ST_BLOCK_END Then
    Dec(Depth);
  End;
  Inc(PC);
 End;
End;

Procedure ExecuteStatement(Var PC: Integer);
Var
 S: TStatementIR;
 IfStmtIdx: Integer;
 CondVal: TRuntimeValue;
 ElsifStmtIdx, Parent: Integer;
 WhileStmtIdx: Integer;
 LoopEnded: Boolean;
 LoopStmtIdx: Integer;
 RepeatStmtIdx: Integer;
 ForStmtIdx: Integer;
 VarPath: String;
 LowVal, BoundVal, StepVal: LongInt;
 IterVal: TRuntimeValue;
 BodyPC: Integer;
 CurVal: LongInt;
 CaseStmtIdx: Integer;
 SelectorVal: LongInt;
 FoundArm: Boolean;
 ArmPC, ElsePC: Integer;
 Arm: TStatementIR;
Begin
 S := StatementIR[PC];
 Case S.Kind Of
  ST_EMPTY: Inc(PC);
  ST_ASSIGN: Begin
   SetValueForNode(S.TargetNode, EvalIR(S.ExpressionNode));
   Inc(PC);
  End;
  ST_CALL: Begin
   EvalIR(S.ExpressionNode);
   Inc(PC);
  End;
  ST_RETURN: Begin
   If S.ExpressionNode <> 0 Then
    ReturnVal := EvalIR(S.ExpressionNode);
   FlowControl := FC_RETURN;
   Inc(PC);
  End;
  ST_EXIT: Begin
   FlowControl := FC_EXIT;
   Inc(PC);
  End;
  ST_BLOCK_BEGIN: Begin
   Inc(PC);
  End;
  ST_BLOCK_END: Begin
   Inc(PC);
  End;
  
  ST_IF: Begin
   IfStmtIdx := PC;
   Inc(PC);
   CondVal := EvalIR(StatementIR[IfStmtIdx].ExpressionNode);
   If CondVal.IntValue <> 0 Then Begin
    ExecuteBlock(IfStmtIdx, PC);
    SkipToBlockEnd(IfStmtIdx, PC);
   End Else Begin
    SkipToNextBranch(IfStmtIdx, PC);
   End;
  End;
  
  ST_ELSIF: Begin
   ElsifStmtIdx := PC;
   Parent := S.ParentIndex;
   Inc(PC);
   CondVal := EvalIR(StatementIR[ElsifStmtIdx].ExpressionNode);
   If CondVal.IntValue <> 0 Then Begin
    ExecuteBlock(Parent, PC);
    SkipToBlockEnd(Parent, PC);
   End Else Begin
    SkipToNextBranch(Parent, PC);
   End;
  End;
  
  ST_ELSE: Begin
   Parent := S.ParentIndex;
   Inc(PC);
   ExecuteBlock(Parent, PC);
   SkipToBlockEnd(Parent, PC);
  End;
  
  ST_WHILE: Begin
   WhileStmtIdx := PC;
   Inc(PC);
   LoopEnded := False;
   While (FlowControl = FC_NORMAL) And Not LoopEnded Do Begin
    CondVal := EvalIR(StatementIR[WhileStmtIdx].ExpressionNode);
    If CondVal.IntValue <> 0 Then Begin
     BodyPC := PC;
     ExecuteBlock(WhileStmtIdx, BodyPC);
     If FlowControl = FC_EXIT Then Begin
      FlowControl := FC_NORMAL;
      LoopEnded := True;
     End;
    End Else Begin
     LoopEnded := True;
    End;
   End;
   SkipToBlockEnd(WhileStmtIdx, PC);
  End;
  
  ST_LOOP: Begin
   LoopStmtIdx := PC;
   Inc(PC);
   LoopEnded := False;
   While (FlowControl = FC_NORMAL) And Not LoopEnded Do Begin
    BodyPC := PC;
    ExecuteBlock(LoopStmtIdx, BodyPC);
    If FlowControl = FC_EXIT Then Begin
     FlowControl := FC_NORMAL;
     LoopEnded := True;
    End;
   End;
   SkipToBlockEnd(LoopStmtIdx, PC);
  End;
  
  ST_REPEAT: Begin
   RepeatStmtIdx := PC;
   Inc(PC);
   LoopEnded := False;
   While (FlowControl = FC_NORMAL) And Not LoopEnded Do Begin
    BodyPC := PC;
    ExecuteBlockUntil(RepeatStmtIdx, BodyPC);
    CondVal := EvalIR(StatementIR[BodyPC].ExpressionNode);
    If CondVal.IntValue <> 0 Then
     LoopEnded := True;
    If FlowControl = FC_EXIT Then Begin
     FlowControl := FC_NORMAL;
     LoopEnded := True;
    End;
   End;
   SkipToUntilEnd(RepeatStmtIdx, PC);
  End;
  
  ST_FOR: Begin
   ForStmtIdx := PC;
   Inc(PC);
   VarPath := EvalPath(S.TargetNode);
   
   LowVal := EvalIR(S.ExpressionNode).IntValue;
   BoundVal := EvalIR(S.BoundNode).IntValue;
   If S.StepNode <> 0 Then
    StepVal := EvalIR(S.StepNode).IntValue
   Else
    StepVal := 1;
   
   IterVal.Kind := CONST_INTEGER;
   IterVal.IntValue := LowVal;
   SetPathValue(VarPath, IterVal);
   
   LoopEnded := False;
   While (FlowControl = FC_NORMAL) And Not LoopEnded Do Begin
    CurVal := GetPathValue(VarPath).IntValue;
    If ((StepVal > 0) And (CurVal > BoundVal)) Or
       ((StepVal < 0) And (CurVal < BoundVal)) Then Begin
     LoopEnded := True;
    End Else Begin
     BodyPC := PC;
     ExecuteBlock(ForStmtIdx, BodyPC);
     If FlowControl = FC_EXIT Then Begin
      FlowControl := FC_NORMAL;
      LoopEnded := True;
     End;
     If (FlowControl = FC_NORMAL) And Not LoopEnded Then Begin
      IterVal.IntValue := GetPathValue(VarPath).IntValue + StepVal;
      SetPathValue(VarPath, IterVal);
     End;
    End;
   End;
   SkipToBlockEnd(ForStmtIdx, PC);
  End;
  
  ST_CASE: Begin
   CaseStmtIdx := PC;
   Inc(PC);
   SelectorVal := EvalIR(S.ExpressionNode).IntValue;
   FoundArm := False;
   
   ArmPC := PC;
   While (ArmPC <= StatementCount) And (StatementIR[ArmPC].ParentIndex = CaseStmtIdx) And Not FoundArm Do Begin
    Arm := StatementIR[ArmPC];
    If Arm.Kind = ST_CASE_ARM Then Begin
     If (SelectorVal >= Arm.CaseLow) And (SelectorVal <= Arm.CaseHigh) Then Begin
      FoundArm := True;
      PC := ArmPC + 1;
      ExecuteBlock(CaseStmtIdx, PC);
     End;
    End;
    Inc(ArmPC);
   End;
   
   If Not FoundArm Then Begin
    ElsePC := PC;
    While (ElsePC <= StatementCount) And (StatementIR[ElsePC].ParentIndex = CaseStmtIdx) And Not FoundArm Do Begin
     If StatementIR[ElsePC].Kind = ST_CASE_ELSE Then Begin
      FoundArm := True;
      PC := ElsePC + 1;
      ExecuteBlock(CaseStmtIdx, PC);
     End;
     Inc(ElsePC);
    End;
   End;
   
   SkipToBlockEnd(CaseStmtIdx, PC);
  End;
  
  Else Inc(PC);
 End;
End;

Function BuildRuntimeOutput:String;
Var
 ModuleScope, I: Integer;
Begin
 BuildRuntimeOutput := '';
 OutputText := '';
 StoreCount := 0;
 FillChar(StoreKeys, SizeOf(StoreKeys), 0);
 StackTop := 0;
 FlowControl := FC_NORMAL;
 NextRefIdx := 0;
 
 ModuleScope:=0;
 For I:=1 To SemanticScopeCount Do
  If SemanticScopes[I].Kind=SCOPE_MODULE Then ModuleScope:=I;
  
 If ModuleScope<>0 Then Begin
  ExecuteScope(ModuleScope);
 End;
 
 BuildRuntimeOutput := OutputText;
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
 OutputText:=BuildRuntimeOutput;
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

Function ParseDigitsInBase(Text:String;Base:Integer;LineNo,ColumnNo:Integer;
 Var Value:LongInt):Boolean;
Var
 I,D:Integer;
Begin
 ParseDigitsInBase:=False;
 Value:=0;
 If Text='' Then Begin
  LexicalError('chiffres attendus',LineNo,ColumnNo);
  Exit;
 End;
 For I:=1 To Length(Text) Do Begin
  D:=DigitValue(Text[I]);
  If (D<0) Or (D>=Base) Then Begin
   LexicalError('chiffre invalide pour la base '+IntToString(Base)+': '+Text,
                LineNo,ColumnNo);
   Exit;
  End;
  If Value>(2147483647-D) Div Base Then Begin
   LexicalError('constante entiere hors limite 32 bits',LineNo,ColumnNo);
   Exit;
  End;
  Value:=(Value*Base)+D;
 End;
 ParseDigitsInBase:=True;
End;

Function AddToken(Kind:TTokenKind;Keyword:TKeyword;Text:String;
 Value:LongInt;LineNo,ColumnNo:Integer):Boolean;
Begin
 AddToken:=False;
 If Pipeline.TokenCount>=MOD3_MAX_TOKENS Then Begin
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
 Pipeline.Tokens[Pipeline.TokenCount].RealVal:=0;
 Pipeline.Tokens[Pipeline.TokenCount].Line:=LineNo;
 Pipeline.Tokens[Pipeline.TokenCount].Column:=ColumnNo;
 AddToken:=True;
End;

Function AddRealToken(Text:String;Value:Extended;LineNo,ColumnNo:Integer):Boolean;
Begin
 AddRealToken:=False;
 If Not AddToken(TK_REAL,KW_NONE,Text,0,LineNo,ColumnNo) Then Exit;
 Pipeline.Tokens[Pipeline.TokenCount].RealVal:=Value;
 AddRealToken:=True;
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

Function ScanNumber:Boolean;
Var
 IntText:String;
 FracText:String;
 ExpText:String;
 LineNo,ColumnNo:Integer;
 BaseValue:LongInt;
 Value:LongInt;
 RealValue:Extended;
 Scale:Extended;
 ExpSign:Integer;
 ExpValue:LongInt;
 I:Integer;
 IsReal:Boolean;
Begin
 ScanNumber:=False;
 LineNo:=Pipeline.LexerLine;
 ColumnNo:=Pipeline.LexerColumn;
 IntText:='';
 While (LexerCurrentChar>='0') And (LexerCurrentChar<='9') Do Begin
  IntText:=IntText+LexerCurrentChar;
  LexerAdvance;
 End;
 If LexerCurrentChar='_' Then Begin
  (* entier en base N : N_chiffres, N decimal de 2 a 16 *)
  If Not ParseDigitsInBase(IntText,10,LineNo,ColumnNo,BaseValue) Then Exit;
  If (BaseValue<2) Or (BaseValue>16) Then Begin
   LexicalError('base numerique invalide (2 a 16 attendu): '+IntText,
                LineNo,ColumnNo);
   Exit;
  End;
  LexerAdvance;
  IntText:='';
  While IsHexChar(LexerCurrentChar) Do Begin
   IntText:=IntText+LexerCurrentChar;
   LexerAdvance;
  End;
  If Not ParseDigitsInBase(IntText,BaseValue,LineNo,ColumnNo,Value) Then Exit;
  ScanNumber:=AddToken(TK_INTEGER,KW_NONE,IntText,Value,LineNo,ColumnNo);
  Exit;
 End;
 IsReal:=False;
 FracText:='';
 If (LexerCurrentChar='.') And (LexerPeekChar>='0') And (LexerPeekChar<='9') Then Begin
  IsReal:=True;
  LexerAdvance;
  While (LexerCurrentChar>='0') And (LexerCurrentChar<='9') Do Begin
   FracText:=FracText+LexerCurrentChar;
   LexerAdvance;
  End;
 End;
 ExpText:='';
 ExpSign:=1;
 If IsReal And ((UpCase(LexerCurrentChar)='E') Or (UpCase(LexerCurrentChar)='D') Or
    (UpCase(LexerCurrentChar)='X')) Then Begin
  LexerAdvance;
  If LexerCurrentChar='+' Then LexerAdvance
  Else If LexerCurrentChar='-' Then Begin
   ExpSign:=-1;
   LexerAdvance;
  End;
  While (LexerCurrentChar>='0') And (LexerCurrentChar<='9') Do Begin
   ExpText:=ExpText+LexerCurrentChar;
   LexerAdvance;
  End;
  If ExpText='' Then Begin
   LexicalError('exposant numerique attendu',LineNo,ColumnNo);
   Exit;
  End;
 End;
 If Not IsReal Then Begin
  If Not ParseDigitsInBase(IntText,10,LineNo,ColumnNo,Value) Then Exit;
  ScanNumber:=AddToken(TK_INTEGER,KW_NONE,IntText,Value,LineNo,ColumnNo);
  Exit;
 End;
 RealValue:=0;
 For I:=1 To Length(IntText) Do
  RealValue:=(RealValue*10)+DigitValue(IntText[I]);
 Scale:=1;
 For I:=1 To Length(FracText) Do Begin
  Scale:=Scale/10;
  RealValue:=RealValue+(DigitValue(FracText[I])*Scale);
 End;
 If ExpText<>'' Then Begin
  ExpValue:=0;
  For I:=1 To Length(ExpText) Do ExpValue:=(ExpValue*10)+DigitValue(ExpText[I]);
  If ExpSign>0 Then
   For I:=1 To ExpValue Do RealValue:=RealValue*10
  Else
   For I:=1 To ExpValue Do RealValue:=RealValue/10;
 End;
 ScanNumber:=AddRealToken(IntText+'.'+FracText,RealValue,LineNo,ColumnNo);
End;

Function ScanEscapeChar(LineNo,ColumnNo:Integer;Var Ch:Char):Boolean;
Var
 C:Char;
 HexText:String;
 OctText:String;
 I:Integer;
 Value:Integer;
Begin
 ScanEscapeChar:=False;
 C:=LexerCurrentChar;
 Case UpCase(C) Of
  'N': Begin Ch:=#10; LexerAdvance; End;
  'T': Begin Ch:=#9; LexerAdvance; End;
  'R': Begin Ch:=#13; LexerAdvance; End;
  'F': Begin Ch:=#12; LexerAdvance; End;
  '\': Begin Ch:='\'; LexerAdvance; End;
  '''': Begin Ch:=''''; LexerAdvance; End;
  '"': Begin Ch:='"'; LexerAdvance; End;
  'X': Begin
   LexerAdvance;
   HexText:='';
   For I:=1 To 2 Do Begin
    If Not IsHexChar(LexerCurrentChar) Then Begin
     LexicalError('echappement \x incomplet',LineNo,ColumnNo);
     Exit;
    End;
    HexText:=HexText+LexerCurrentChar;
    LexerAdvance;
   End;
   Value:=(DigitValue(HexText[1])*16)+DigitValue(HexText[2]);
   Ch:=Chr(Value);
  End;
  Else Begin
   If (C>='0') And (C<='7') Then Begin
    OctText:='';
    For I:=1 To 3 Do Begin
     If (LexerCurrentChar<'0') Or (LexerCurrentChar>'7') Then Break;
     OctText:=OctText+LexerCurrentChar;
     LexerAdvance;
    End;
    Value:=0;
    For I:=1 To Length(OctText) Do Value:=(Value*8)+DigitValue(OctText[I]);
    If Value>255 Then Begin
     LexicalError('echappement octal hors limite',LineNo,ColumnNo);
     Exit;
    End;
    Ch:=Chr(Value);
   End
   Else Begin
    LexicalError('sequence d''echappement inconnue: \'+C,LineNo,ColumnNo);
    Exit;
   End;
  End;
 End;
 ScanEscapeChar:=True;
End;

Function ScanStringLiteral:Boolean;
Var
 Text:String;
 LineNo,ColumnNo:Integer;
 Ch:Char;
Begin
 ScanStringLiteral:=False;
 Text:='';
 LineNo:=Pipeline.LexerLine;
 ColumnNo:=Pipeline.LexerColumn;
 LexerAdvance;
 While True Do Begin
  If LexerAtEnd Or (LexerCurrentChar=#10) Then Begin
   LexicalError('chaine non terminee',LineNo,ColumnNo);
   Exit;
  End;
  If LexerCurrentChar='"' Then Begin
   LexerAdvance;
   Break;
  End
  Else If LexerCurrentChar='\' Then Begin
   LexerAdvance;
   If Not ScanEscapeChar(LineNo,ColumnNo,Ch) Then Exit;
   If Length(Text)>=127 Then Begin
    LexicalError('chaine trop longue',LineNo,ColumnNo);
    Exit;
   End;
   Text:=Text+Ch;
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

Function ScanCharLiteral:Boolean;
Var
 LineNo,ColumnNo:Integer;
 Ch:Char;
Begin
 ScanCharLiteral:=False;
 LineNo:=Pipeline.LexerLine;
 ColumnNo:=Pipeline.LexerColumn;
 LexerAdvance;
 If LexerAtEnd Or (LexerCurrentChar=#10) Then Begin
  LexicalError('caractere non termine',LineNo,ColumnNo);
  Exit;
 End;
 If LexerCurrentChar='\' Then Begin
  LexerAdvance;
  If Not ScanEscapeChar(LineNo,ColumnNo,Ch) Then Exit;
 End
 Else Begin
  Ch:=LexerCurrentChar;
  LexerAdvance;
 End;
 If LexerCurrentChar<>'''' Then Begin
  LexicalError('guillemet simple fermant attendu',LineNo,ColumnNo);
  Exit;
 End;
 LexerAdvance;
 ScanCharLiteral:=AddToken(TK_CHAR,KW_NONE,Ch,Ord(Ch),LineNo,ColumnNo);
End;

Function ScanSymbol:Boolean;
Var
 Text:String;
 C:Char;
 P:Char;
 LineNo,ColumnNo:Integer;
Begin
 ScanSymbol:=False;
 C:=LexerCurrentChar;
 P:=LexerPeekChar;
 LineNo:=Pipeline.LexerLine;
 ColumnNo:=Pipeline.LexerColumn;
 If ((C=':') And (P='=')) Or
    ((C='<') And (P=':')) Or
    ((C='.') And (P='.')) Or
    ((C='=') And (P='>')) Or
    ((C='<') And (P='=')) Or
    ((C='>') And (P='=')) Then Begin
  Text:=C+P;
  LexerAdvance;
  LexerAdvance;
 End
 Else If Pos(C,'+-*/=#<>()[]{};,.:^|&')>0 Then Begin
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
  If (Pipeline.Tokens[I].Kind=TK_INTEGER) Or (Pipeline.Tokens[I].Kind=TK_CHAR) Then
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
   If Not ScanNumber Then Exit;
  End
  Else If C='"' Then Begin
   If Not ScanStringLiteral Then Exit;
  End
  Else If C='''' Then Begin
   If Not ScanCharLiteral Then Exit;
  End
  Else If Not ScanSymbol Then Exit;
 End;
 If Not AddToken(TK_EOF,KW_NONE,'',0,Pipeline.StoredLineCount+1,1) Then Exit;
 TokenizeSource:=True;
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
Var
 Matched:Boolean;
Begin
 Matched:=TokenIsKeyword(Keyword);
 If Matched Then ParserAdvance;
 AcceptKeyword:=Matched;
End;

Function AcceptSymbol(SymbolText:String):Boolean;
Var
 Matched:Boolean;
Begin
 Matched:=TokenIsSymbol(SymbolText);
 If Matched Then ParserAdvance;
 AcceptSymbol:=Matched;
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
  Else If AllowRecord And (TokenIsKeyword(KW_RECORD) Or TokenIsKeyword(KW_OBJECT)) Then
   Inc(RecordDepth)
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

Function AddImportName(Name:String;FromImportFlag:Boolean;LineNo,ColumnNo:Integer;
 Var ImportIndex:Integer):Boolean;
Var
 I:Integer;
Begin
 AddImportName:=False;
 ImportIndex:=0;
 For I:=1 To Pipeline.ImportCount Do
  If UpperStr(Pipeline.Imports[I].Name)=UpperStr(Name) Then Begin
   SemanticError('module importe plusieurs fois: '+Name,LineNo,ColumnNo);
   Exit;
  End;
 If Pipeline.ImportCount>=MOD3_MAX_IMPORTS Then Begin
  SemanticError('trop de modules importes',LineNo,ColumnNo);
  Exit;
 End;
 Inc(Pipeline.ImportCount);
 ImportIndex:=Pipeline.ImportCount;
 Pipeline.Imports[ImportIndex].Name:=Name;
 Pipeline.Imports[ImportIndex].FromImport:=FromImportFlag;
 Pipeline.Imports[ImportIndex].SelectedNames:='';
 Pipeline.Imports[ImportIndex].Line:=LineNo;
 Pipeline.Imports[ImportIndex].Column:=ColumnNo;
 AddImportName:=True;
End;

Procedure AddSelectedName(ImportIndex:Integer;Name:String);
Begin
 If (ImportIndex<1) Or (ImportIndex>Pipeline.ImportCount) Then Exit;
 If Pipeline.Imports[ImportIndex].SelectedNames='' Then
  Pipeline.Imports[ImportIndex].SelectedNames:=Name
 Else
  Pipeline.Imports[ImportIndex].SelectedNames:=
   Pipeline.Imports[ImportIndex].SelectedNames+','+Name;
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
  If Not AddImportName(ModuleName,True,LineNo,ColumnNo,ImportIndex) Then Exit;
  If Not ExpectKeyword(KW_IMPORT) Then Exit;
  Repeat
   If Not ExpectIdentifier(ImportedName) Then Exit;
   AddSelectedName(ImportIndex,ImportedName);
  Until Not AcceptSymbol(',');
 End
 Else Begin
  If Not ExpectKeyword(KW_IMPORT) Then Exit;
  Repeat
   LineNo:=CurrentToken.Line;
   ColumnNo:=CurrentToken.Column;
   If Not ExpectIdentifier(ModuleName) Then Exit;
   If Not AddImportName(ModuleName,False,LineNo,ColumnNo,ImportIndex) Then Exit;
  Until Not AcceptSymbol(',');
 End;
 If Not ExpectSymbol(';') Then Exit;
 ParseImportClause:=True;
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
  If Not (AcceptSymbol('=') Or AcceptSymbol('<:')) Then Begin
   ParserFail('symbole "=" ou "<:" attendu');
   Exit;
  End;
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

Function ParseInterfaceProcedureDecl:Boolean;
Var
 ProcName:String;
Begin
 ParseInterfaceProcedureDecl:=False;
 If Not ExpectKeyword(KW_PROCEDURE) Then Exit;
 If Not ExpectIdentifier(ProcName) Then Exit;
 If Not SkipUntilSemicolon(False) Then Exit;
 Inc(Pipeline.ProcedureCount);
 ParseInterfaceProcedureDecl:=True;
End;

Function ParseInterfaceDeclarations:Boolean;
Begin
 ParseInterfaceDeclarations:=False;
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
   If Not ParseInterfaceProcedureDecl Then Exit;
  End
  Else Break;
 End;
 ParseInterfaceDeclarations:=True;
End;

Function ParseInterfaceUnit:Boolean;
Var
 HeaderName:String;
 EndName:String;
Begin
 ParseInterfaceUnit:=False;
 Pipeline.ParserIndex:=1;
 Pipeline.ImportCount:=0;
 Pipeline.ConstDeclCount:=0;
 Pipeline.TypeDeclCount:=0;
 Pipeline.VarDeclCount:=0;
 Pipeline.ProcedureCount:=0;
 If Not ExpectKeyword(KW_INTERFACE) Then Exit;
 If Not ExpectIdentifier(HeaderName) Then Exit;
 Pipeline.ModuleName:=HeaderName;
 If Not ExpectSymbol(';') Then Exit;
 While TokenIsKeyword(KW_IMPORT) Or TokenIsKeyword(KW_FROM) Do
  If Not ParseImportClause Then Exit;
 If Not ParseInterfaceDeclarations Then Exit;
 If Not ExpectKeyword(KW_END) Then Exit;
 If Not ExpectIdentifier(EndName) Then Exit;
 If EndName<>HeaderName Then Begin
  ParserFail('nom final "'+EndName+'" different de INTERFACE "'+HeaderName+'"');
  Exit;
 End;
 If Not ExpectSymbol('.') Then Exit;
 If CurrentToken.Kind<>TK_EOF Then Begin
  ParserFail('tokens inattendus apres la fin de l''interface');
  Exit;
 End;
 ParseInterfaceUnit:=True;
End;

Procedure TraceParser;
Var
 I:Integer;
 Detail:String;
Begin
 If Options.Verbose Then
  WriteLn('Parser : INTERFACE ',Pipeline.ModuleName,
          ', imports ',Pipeline.ImportCount,
          ', CONST ',Pipeline.ConstDeclCount,
          ', TYPE ',Pipeline.TypeDeclCount,
          ', VAR ',Pipeline.VarDeclCount,
          ', PROCEDURE ',Pipeline.ProcedureCount)
 Else
  WriteLn('Parser : INTERFACE ',Pipeline.ModuleName);
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

(* Les corps ci-dessous sont des jalons d'etapes; leur contenu reel
   sera fourni par les TODOs 10 a 24 (module, tables, IR, etc.). *)
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
  If Pipeline.StoredLineCount>=MOD3_MAX_SOURCE_LINES Then Begin
   Close(F);
   PipelineErrorKind(EK_IO,'source trop long: maximum '+
                     IntToString(MOD3_MAX_SOURCE_LINES)+' lignes');
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

Function DirectoryOf(FileName:String):String;
Var
 I:Integer;
Begin
 DirectoryOf:='';
 For I:=Length(FileName) DownTo 1 Do
  If (FileName[I]='\') Or (FileName[I]='/') Then Begin
   DirectoryOf:=Copy(FileName,1,I);
   Exit;
  End;
End;

Function FileExistsOnDisk(FileName:String):Boolean;
Var
 F:File;
Begin
 Assign(F,FileName);
 Reset(F,1);
 If IOResult<>0 Then Begin
  FileExistsOnDisk:=False;
  Exit;
 End;
 Close(F);
 FileExistsOnDisk:=True;
End;

Procedure AddExportName(Name:String;LineNo,ColumnNo:Integer);
Begin
 If Pipeline.ExportCount>=MOD3_MAX_EXPORTS Then Begin
  SemanticError('trop de noms EXPORTS',LineNo,ColumnNo);
  Exit;
 End;
 Inc(Pipeline.ExportCount);
 Pipeline.ExportItems[Pipeline.ExportCount].Name:=Name;
 Pipeline.ExportItems[Pipeline.ExportCount].Line:=LineNo;
 Pipeline.ExportItems[Pipeline.ExportCount].Column:=ColumnNo;
End;

Function CheckExportedInterfaceCoherence(InterfaceName:String;
 LineNo,ColumnNo:Integer):Boolean;
Var
 Candidate:String;
 SavedPipeline:TPipelineState;
 OK:Boolean;
 SubErrors:Integer;
 DeclaredName:String;
Begin
 CheckExportedInterfaceCoherence:=True;
 If UpperStr(InterfaceName)='MAIN' Then Exit;
 Candidate:=DirectoryOf(Pipeline.SourceName)+InterfaceName+MOD3_INTERFACE_EXT;
 If Not FileExistsOnDisk(Candidate) Then Exit;
 SavedPipeline:=Pipeline;
 FillChar(Pipeline,SizeOf(Pipeline),0);
 Pipeline.SourceName:=Candidate;
 Pipeline.ModuleName:=StripExtension(Candidate);
 LoadSource;
 OK:=Pipeline.ErrorCount=0;
 If OK Then OK:=TokenizeSource;
 If OK Then OK:=ParseInterfaceUnit;
 DeclaredName:=Pipeline.ModuleName;
 SubErrors:=Pipeline.ErrorCount;
 Pipeline:=SavedPipeline;
 Inc(Pipeline.ErrorCount,SubErrors);
 If Not OK Then Begin
  CheckExportedInterfaceCoherence:=False;
  Exit;
 End;
 If UpperStr(DeclaredName)<>UpperStr(InterfaceName) Then Begin
  SemanticError('le module exporte "'+InterfaceName+'" mais '+Candidate+
                ' declare INTERFACE '+DeclaredName,LineNo,ColumnNo);
  CheckExportedInterfaceCoherence:=False;
  Exit;
 End;
End;

Function CheckExportsCoherence:Boolean;
Var
 I:Integer;
Begin
 CheckExportsCoherence:=True;
 For I:=1 To Pipeline.ExportCount Do
  If Not CheckExportedInterfaceCoherence(Pipeline.ExportItems[I].Name,
   Pipeline.ExportItems[I].Line,Pipeline.ExportItems[I].Column) Then
   CheckExportsCoherence:=False;
End;

Function ParseRevealSection:Boolean;
Var
 Name:String;
Begin
 ParseRevealSection:=False;
 If Not ExpectKeyword(KW_REVEAL) Then Exit;
 If CurrentToken.Kind<>TK_IDENTIFIER Then Begin
  ParserFail('declaration REVEAL attendue');
  Exit;
 End;
 While CurrentToken.Kind=TK_IDENTIFIER Do Begin
  If Not ExpectIdentifier(Name) Then Exit;
  If Not ExpectSymbol('=') Then Exit;
  If Not SkipUntilSemicolon(True) Then Exit;
  Inc(Pipeline.TypeDeclCount);
 End;
 ParseRevealSection:=True;
End;

Function ParseExceptionSection:Boolean;
Var
 Name:String;
Begin
 ParseExceptionSection:=False;
 If Not ExpectKeyword(KW_EXCEPTION) Then Exit;
 If CurrentToken.Kind<>TK_IDENTIFIER Then Begin
  ParserFail('declaration d''exception attendue apres EXCEPTION');
  Exit;
 End;
 While CurrentToken.Kind=TK_IDENTIFIER Do Begin
  If Not ExpectIdentifier(Name) Then Exit;
  If Not SkipUntilSemicolon(False) Then Exit;
  Inc(Pipeline.ExceptionDeclCount);
 End;
 ParseExceptionSection:=True;
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
       (Keyword=KW_BEGIN) Or (Keyword=KW_TRY) Or
       (Keyword=KW_TYPECASE) Or (Keyword=KW_LOCK) Then Inc(EndDepth)
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

Function ParseModuleDeclarations:Boolean; Forward;

Function SkipProcedureHeader:Boolean;
Var
 ParenDepth:Integer;
 BracketDepth:Integer;
Begin
 SkipProcedureHeader:=False;
 ParenDepth:=0;
 BracketDepth:=0;
 While CurrentToken.Kind<>TK_EOF Do Begin
  If TokenIsSymbol('(') Then Inc(ParenDepth)
  Else If TokenIsSymbol(')') Then Begin
   If ParenDepth=0 Then Begin
    ParserFail('parenthese fermante inattendue dans PROCEDURE');
    Exit;
   End;
   Dec(ParenDepth);
  End
  Else If TokenIsSymbol('[') Then Inc(BracketDepth)
  Else If TokenIsSymbol(']') Then Begin
   If BracketDepth=0 Then Begin
    ParserFail('crochet fermant inattendu dans PROCEDURE');
    Exit;
   End;
   Dec(BracketDepth);
  End
  Else If (ParenDepth=0) And (BracketDepth=0) And
          (TokenIsSymbol(';') Or TokenIsSymbol('=')) Then Begin
   ParserAdvance;
   SkipProcedureHeader:=True;
   Exit;
  End;
  ParserAdvance;
 End;
 ParserFail('fin de fichier dans l''entete de PROCEDURE');
End;

Function ParseModuleProcedureDecl:Boolean;
Var
 ProcName:String;
 EndName:String;
Begin
 ParseModuleProcedureDecl:=False;
 If Not ExpectKeyword(KW_PROCEDURE) Then Exit;
 If Not ExpectIdentifier(ProcName) Then Exit;
 If Not SkipProcedureHeader Then Exit;
 Inc(Pipeline.ProcedureCount);
 If Not ParseModuleDeclarations Then Exit;
 If Not ExpectKeyword(KW_BEGIN) Then Exit;
 If Not ParseStatementSequence Then Exit;
 If Not ExpectKeyword(KW_END) Then Exit;
 If CurrentToken.Kind=TK_IDENTIFIER Then Begin
  EndName:=CurrentToken.Text;
  If EndName<>ProcName Then Begin
   ParserFail('nom final "'+EndName+'" different de PROCEDURE "'+ProcName+'"');
   Exit;
  End;
  ParserAdvance;
 End;
 If Not ExpectSymbol(';') Then Exit;
 ParseModuleProcedureDecl:=True;
End;

Function ParseModuleDeclarations:Boolean;
Begin
 ParseModuleDeclarations:=False;
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
  Else If TokenIsKeyword(KW_REVEAL) Then Begin
   If Not ParseRevealSection Then Exit;
  End
  Else If TokenIsKeyword(KW_EXCEPTION) Then Begin
   If Not ParseExceptionSection Then Exit;
  End
  Else If TokenIsKeyword(KW_PROCEDURE) Then Begin
   If Not ParseModuleProcedureDecl Then Exit;
  End
  Else Break;
 End;
 ParseModuleDeclarations:=True;
End;

Function ParseModuleUnit:Boolean;
Var
 HeaderName:String;
 EndName:String;
 ExportName:String;
 ExportLine,ExportColumn:Integer;
Begin
 ParseModuleUnit:=False;
 Pipeline.ParserIndex:=1;
 Pipeline.ImportCount:=0;
 Pipeline.ConstDeclCount:=0;
 Pipeline.TypeDeclCount:=0;
 Pipeline.VarDeclCount:=0;
 Pipeline.ProcedureCount:=0;
 Pipeline.ExceptionDeclCount:=0;
 Pipeline.StatementCount:=0;
 Pipeline.ExportCount:=0;
 If Not ExpectKeyword(KW_MODULE) Then Exit;
 If Not ExpectIdentifier(HeaderName) Then Exit;
 Pipeline.ModuleName:=HeaderName;
 If AcceptKeyword(KW_EXPORTS) Then Begin
  ExportLine:=CurrentToken.Line;
  ExportColumn:=CurrentToken.Column;
  If Not ExpectIdentifier(ExportName) Then Exit;
  AddExportName(ExportName,ExportLine,ExportColumn);
  While AcceptSymbol(',') Do Begin
   ExportLine:=CurrentToken.Line;
   ExportColumn:=CurrentToken.Column;
   If Not ExpectIdentifier(ExportName) Then Exit;
   AddExportName(ExportName,ExportLine,ExportColumn);
  End;
 End;
 If Not ExpectSymbol(';') Then Exit;
 While TokenIsKeyword(KW_IMPORT) Or TokenIsKeyword(KW_FROM) Do
  If Not ParseImportClause Then Exit;
 If Not ParseModuleDeclarations Then Exit;
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
 If Not CheckExportsCoherence Then Exit;
 ParseModuleUnit:=True;
End;

Procedure TraceModuleParser;
Var
 I:Integer;
 Detail:String;
Begin
 If Options.Verbose Then
  WriteLn('Parser : MODULE ',Pipeline.ModuleName,
          ', imports ',Pipeline.ImportCount,
          ', CONST ',Pipeline.ConstDeclCount,
          ', TYPE ',Pipeline.TypeDeclCount,
          ', VAR ',Pipeline.VarDeclCount,
          ', EXCEPTION ',Pipeline.ExceptionDeclCount,
          ', PROCEDURE ',Pipeline.ProcedureCount,
          ', instructions ',Pipeline.StatementCount)
 Else
  WriteLn('Parser : MODULE ',Pipeline.ModuleName);
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

Function IsGenericUnit:Boolean;
Begin
 IsGenericUnit:=TokenIsKeyword(KW_GENERIC);
End;

Procedure RunParser;
Begin
 EnterStage(CS_PARSER);
 If IsInterfaceFile(Pipeline.SourceName) Then Begin
  If ParseInterfaceUnit Then Begin
   Pipeline.Parsed:=True;
   FinishStage(CS_PARSER);
   TraceParser;
  End;
 End
 Else If IsGenericUnit Then Begin
  (* GENERIC INTERFACE/MODULE et instanciation generique: TODO 23. *)
  Pipeline.Parsed:=True;
  FinishStage(CS_PARSER);
  If Options.Verbose Then
   WriteLn('Parser : unite generique - analyse complete fournie par la TODO 23');
 End
 Else Begin
  If ParseModuleUnit Then Begin
   Pipeline.Parsed:=True;
   FinishStage(CS_PARSER);
   TraceModuleParser;
  End;
 End;
End;

Procedure ReportPreScanError(Msg:String);
Begin
 WriteLn('Erreur: ',Msg);
 Inc(PreScanErrorCount);
End;

Procedure BuildUnitTable;
Var
 I:Integer;
Begin
 UnitCount:=0;
 For I:=1 To Options.SourceCount Do Begin
  Inc(UnitCount);
  Units[UnitCount].SourceName:=Options.SourceNames[I];
  Units[UnitCount].Name:=FileBaseName(Options.SourceNames[I]);
  If IsInterfaceFile(Options.SourceNames[I]) Then
   Units[UnitCount].Kind:=UK_INTERFACE
  Else
   Units[UnitCount].Kind:=UK_MODULE;
  Units[UnitCount].DepCount:=0;
  Units[UnitCount].Visiting:=False;
  Units[UnitCount].Visited:=False;
 End;
End;

Procedure ScanUnitImports(UnitIndex:Integer);
Var
 OK:Boolean;
 I,J:Integer;
 ImportName:String;
Begin
 FillChar(Pipeline,SizeOf(Pipeline),0);
 Pipeline.SourceName:=Units[UnitIndex].SourceName;
 Pipeline.ModuleName:=Units[UnitIndex].Name;
 QuietDiagnostics:=True;
 LoadSource;
 OK:=Pipeline.ErrorCount=0;
 If OK Then OK:=TokenizeSource;
 If OK Then Begin
  Pipeline.ParserIndex:=1;
  If Units[UnitIndex].Kind=UK_INTERFACE Then OK:=ParseInterfaceUnit
  Else If TokenIsKeyword(KW_GENERIC) Then OK:=False
  Else OK:=ParseModuleUnit;
 End;
 QuietDiagnostics:=False;
 Units[UnitIndex].DepCount:=0;
 If Not OK Then Exit;
 For I:=1 To Pipeline.ImportCount Do Begin
  ImportName:=Pipeline.Imports[I].Name;
  If IsRuntimeInterface(ImportName) Then Continue;
  For J:=1 To UnitCount Do
   If (J<>UnitIndex) And (UpperStr(Units[J].Name)=UpperStr(ImportName)) Then Begin
    If Units[UnitIndex].DepCount<MOD3_MAX_IMPORTS Then Begin
     Inc(Units[UnitIndex].DepCount);
     Units[UnitIndex].DepUnit[Units[UnitIndex].DepCount]:=J;
    End;
    Break;
   End;
 End;
End;

Procedure CheckUnresolvedImports(UnitIndex:Integer);
Var
 I,J:Integer;
 ImportName:String;
 Found:Boolean;
 Candidate:String;
Begin
 For I:=1 To Pipeline.ImportCount Do Begin
  ImportName:=Pipeline.Imports[I].Name;
  If IsRuntimeInterface(ImportName) Then Continue;
  Found:=False;
  For J:=1 To UnitCount Do
   If UpperStr(Units[J].Name)=UpperStr(ImportName) Then Begin
    Found:=True;
    Break;
   End;
  If Not Found Then Begin
   Candidate:=DirectoryOf(Units[UnitIndex].SourceName)+ImportName+MOD3_INTERFACE_EXT;
   Found:=FileExistsOnDisk(Candidate);
  End;
  If Not Found Then
   SemanticError('interface importee introuvable: '+ImportName,
                 Pipeline.Imports[I].Line,Pipeline.Imports[I].Column);
 End;
End;

Procedure VisitUnitForOrder(UnitIndex:Integer;Var HasCycle:Boolean);
Var
 I:Integer;
Begin
 If HasCycle Then Exit;
 If Units[UnitIndex].Visited Then Exit;
 If Units[UnitIndex].Visiting Then Begin
  ReportPreScanError('cycle d''importation detecte impliquant '+
                      Units[UnitIndex].Name);
  HasCycle:=True;
  Exit;
 End;
 Units[UnitIndex].Visiting:=True;
 For I:=1 To Units[UnitIndex].DepCount Do Begin
  VisitUnitForOrder(Units[UnitIndex].DepUnit[I],HasCycle);
  If HasCycle Then Exit;
 End;
 Units[UnitIndex].Visiting:=False;
 Units[UnitIndex].Visited:=True;
 Inc(CompileOrderCount);
 CompileOrder[CompileOrderCount]:=UnitIndex;
End;

Procedure ComputeCompileOrder(Var HasCycle:Boolean);
Var
 I:Integer;
Begin
 CompileOrderCount:=0;
 HasCycle:=False;
 For I:=1 To UnitCount Do
  VisitUnitForOrder(I,HasCycle);
End;

Procedure ResolveUnits;
Var
 I:Integer;
Begin
 BuildUnitTable;
 PreScanErrorCount:=0;
 For I:=1 To UnitCount Do Begin
  ScanUnitImports(I);
  CheckUnresolvedImports(I);
  Inc(PreScanErrorCount,Pipeline.ErrorCount);
 End;
 ComputeCompileOrder(HasImportCycle);
End;

Function ScopeKindName(Kind:TScopeKind):String;
Begin
 Case Kind Of
  SCOPE_UNIVERSE :ScopeKindName:='universelle';
  SCOPE_INTERFACE:ScopeKindName:='interface';
  SCOPE_MODULE   :ScopeKindName:='module';
  SCOPE_PROCEDURE:ScopeKindName:='procedure';
  SCOPE_OBJECT   :ScopeKindName:='objet';
  SCOPE_GENERIC  :ScopeKindName:='generique';
  Else ScopeKindName:='inconnue';
 End;
End;

Function SymbolKindName(Kind:TSymbolKind):String;
Begin
 Case Kind Of
  SYM_IMPORT       :SymbolKindName:='import';
  SYM_CONST        :SymbolKindName:='constante';
  SYM_TYPE         :SymbolKindName:='type';
  SYM_VAR          :SymbolKindName:='variable';
  SYM_PARAM        :SymbolKindName:='parametre';
  SYM_PROCEDURE    :SymbolKindName:='procedure';
  SYM_FIELD        :SymbolKindName:='champ';
  SYM_METHOD       :SymbolKindName:='methode';
  SYM_EXCEPTION    :SymbolKindName:='exception';
  SYM_GENERIC_PARAM:SymbolKindName:='parametre generique';
  Else SymbolKindName:='symbole';
 End;
End;

Function NewSemanticScope(AKind:TScopeKind;AParent:Integer;
 AOwnerName:String;LineNo,ColumnNo:Integer):Integer;
Begin
 NewSemanticScope:=0;
 If SemanticScopeCount>=MOD3_MAX_SCOPES Then Begin
  SemanticError('trop de portees semantiques',LineNo,ColumnNo);
  Exit;
 End;
 Inc(SemanticScopeCount);
 With SemanticScopes[SemanticScopeCount] Do Begin
  Kind:=AKind;
  Parent:=AParent;
  If Parent=0 Then Level:=0
  Else Level:=SemanticScopes[Parent].Level+1;
  OwnerName:=AOwnerName;
  FirstSymbol:=0;
  SymbolCount:=0;
  StartToken:=SemanticIndex;
  EndToken:=Pipeline.TokenCount;
  FrameSize:=0;
 End;
 NewSemanticScope:=SemanticScopeCount;
End;

Function FindSymbolInScope(Name:String;ScopeIndex:Integer):Integer;
Var
 I:Integer;
Begin
 FindSymbolInScope:=0;
 If (ScopeIndex<1) Or (ScopeIndex>SemanticScopeCount) Then Exit;
 I:=SemanticScopes[ScopeIndex].FirstSymbol;
 While I<>0 Do Begin
  If SemanticSymbols[I].Name=Name Then Begin
   FindSymbolInScope:=I;
   Exit;
  End;
  I:=SemanticSymbols[I].NextSymbol;
 End;
End;

Function FindVisibleSymbol(Name:String;ScopeIndex:Integer):Integer;
Var
 Found:Integer;
Begin
 Found:=0;
 While ScopeIndex<>0 Do Begin
  Found:=FindSymbolInScope(Name,ScopeIndex);
  If Found<>0 Then Begin
   FindVisibleSymbol:=Found;
   Exit;
  End;
  ScopeIndex:=SemanticScopes[ScopeIndex].Parent;
 End;
 FindVisibleSymbol:=Found;
End;

Function AddSemanticSymbol(AName:String;AKind:TSymbolKind;AScopeIndex:Integer;
 LineNo,ColumnNo:Integer):Boolean;
Var
 Existing:Integer;
Begin
 AddSemanticSymbol:=False;
 Existing:=FindSymbolInScope(AName,AScopeIndex);
 If Existing<>0 Then Begin
  SemanticError('identificateur "'+AName+'" deja declare dans cette portee ('+
   SymbolKindName(SemanticSymbols[Existing].Kind)+' ligne '+
   IntToString(SemanticSymbols[Existing].Line)+')',LineNo,ColumnNo);
  Exit;
 End;
 If SemanticSymbolCount>=MOD3_MAX_SYMBOLS Then Begin
  SemanticError('table des symboles pleine',LineNo,ColumnNo);
  Exit;
 End;
 Inc(SemanticSymbolCount);
 With SemanticSymbols[SemanticSymbolCount] Do Begin
  Name:=AName;
  Kind:=AKind;
  ScopeIndex:=AScopeIndex;
  Line:=LineNo;
  Column:=ColumnNo;
  TypeIndex:=0;
  Offset:=0;
  Size:=0;
  Storage:=STORAGE_NONE;
  AsmLabel:='';
  HasInitializer:=False;
  ParamMode:=PARAM_VALUE;
  ProcScope:=0;
  MethodImpl:=0;
  ConstValue.Kind:=CONST_INVALID;
  ConstValue.TypeIndex:=0;
  ConstValue.IntegerVal:=0;
  ConstValue.RealVal:=0;
  ConstValue.TextVal:='';
  ConstValue.Valid:=False;
  NextSymbol:=SemanticScopes[AScopeIndex].FirstSymbol;
 End;
 SemanticScopes[AScopeIndex].FirstSymbol:=SemanticSymbolCount;
 Inc(SemanticScopes[AScopeIndex].SymbolCount);
 AddSemanticSymbol:=True;
End;

Function AddTypedSemanticSymbol(AName:String;AKind:TSymbolKind;
 AScopeIndex,TypeIndex:Integer;LineNo,ColumnNo:Integer):Boolean;
Var
 OK:Boolean;
Begin
 OK:=AddSemanticSymbol(AName,AKind,AScopeIndex,LineNo,ColumnNo);
 If OK Then
  SemanticSymbols[SemanticSymbolCount].TypeIndex:=TypeIndex;
 AddTypedSemanticSymbol:=OK;
End;

Function AddSemanticType(AName:String;AKind:TTypeKind;ASize,AAlign,
 ABaseType,LineNo,ColumnNo:Integer):Integer;
Begin
 AddSemanticType:=0;
 If SemanticTypeCount>=MOD3_MAX_TYPES Then Begin
  SemanticError('table des types pleine',LineNo,ColumnNo);
  Exit;
 End;
 Inc(SemanticTypeCount);
 With SemanticTypes[SemanticTypeCount] Do Begin
  Name:=AName;
  Kind:=AKind;
  Size:=ASize;
  Align:=AAlign;
  BaseType:=ABaseType;
  ElementType:=0;
  LowBound:=0;
  HighBound:=-1;
  OpenArray:=False;
  FieldScope:=0;
  Branded:=False;
  Untraced:=False;
  Revealed:=False;
  InstanceSize:=0;
  TypeCode:=SemanticTypeCount;
  MethodCount:=0;
  Line:=LineNo;
  Column:=ColumnNo;
 End;
 AddSemanticType:=SemanticTypeCount;
End;

Function CanonicalType(TypeIndex:Integer):Integer;
Var
 Guard:Integer;
Begin
 Guard:=0;
 While (TypeIndex>0) And (TypeIndex<=SemanticTypeCount) And
       (SemanticTypes[TypeIndex].Kind=TYPE_ALIAS) And
       (SemanticTypes[TypeIndex].BaseType<>0) And
       (Guard<MOD3_MAX_TYPES) Do Begin
  TypeIndex:=SemanticTypes[TypeIndex].BaseType;
  Inc(Guard);
 End;
 CanonicalType:=TypeIndex;
End;

Function TypeKindName(Kind:TTypeKind):String;
Begin
 Case Kind Of
  TYPE_INTEGER :TypeKindName:='INTEGER';
  TYPE_CARDINAL:TypeKindName:='CARDINAL';
  TYPE_BOOLEAN :TypeKindName:='BOOLEAN';
  TYPE_CHAR    :TypeKindName:='CHAR';
  TYPE_REAL    :TypeKindName:='REAL';
  TYPE_LONGREAL:TypeKindName:='LONGREAL';
  TYPE_TEXT    :TypeKindName:='TEXT';
  TYPE_NIL     :TypeKindName:='NIL';
  TYPE_ALIAS   :TypeKindName:='alias';
  TYPE_SUBRANGE:TypeKindName:='sous-intervalle';
  TYPE_ARRAY   :TypeKindName:='ARRAY';
  TYPE_RECORD  :TypeKindName:='RECORD';
  TYPE_REF     :TypeKindName:='REF';
  TYPE_OPAQUE  :TypeKindName:='opaque';
  TYPE_OBJECT  :TypeKindName:='OBJECT';
  TYPE_COMPOSITE:TypeKindName:='compose';
  Else TypeKindName:='erreur';
 End;
End;

Function TypeName(TypeIndex:Integer):String;
Begin
 If (TypeIndex<1) Or (TypeIndex>SemanticTypeCount) Then
  TypeName:='<type inconnu>'
 Else If SemanticTypes[TypeIndex].Name<>'' Then
  TypeName:=SemanticTypes[TypeIndex].Name
 Else TypeName:=TypeKindName(SemanticTypes[TypeIndex].Kind);
End;

Function TypeIsInteger(TypeIndex:Integer):Boolean;
Var
 Kind:TTypeKind;
Begin
 TypeIndex:=CanonicalType(TypeIndex);
 If TypeIndex=0 Then Begin
  TypeIsInteger:=False;
  Exit;
 End;
 Kind:=SemanticTypes[TypeIndex].Kind;
 TypeIsInteger:=(Kind=TYPE_INTEGER) Or (Kind=TYPE_CARDINAL);
End;

Function TypeIsNumeric(TypeIndex:Integer):Boolean;
Var
 Kind:TTypeKind;
Begin
 TypeIndex:=CanonicalType(TypeIndex);
 If TypeIndex=0 Then Begin
  TypeIsNumeric:=False;
  Exit;
 End;
 Kind:=SemanticTypes[TypeIndex].Kind;
 TypeIsNumeric:=(Kind=TYPE_INTEGER) Or (Kind=TYPE_CARDINAL) Or
                (Kind=TYPE_REAL) Or (Kind=TYPE_LONGREAL);
End;

Function TypeIsOrdinal(TypeIndex:Integer):Boolean;
Var
 Kind:TTypeKind;
Begin
 TypeIndex:=CanonicalType(TypeIndex);
 If TypeIndex=0 Then Begin
  TypeIsOrdinal:=False;
  Exit;
 End;
 Kind:=SemanticTypes[TypeIndex].Kind;
 TypeIsOrdinal:=(Kind=TYPE_INTEGER) Or (Kind=TYPE_CARDINAL) Or
                (Kind=TYPE_BOOLEAN) Or (Kind=TYPE_CHAR);
End;

Function ObjectIsSubtype(SourceType,DestType:Integer):Boolean;
Var
 Guard:Integer;
Begin
 ObjectIsSubtype:=False;
 SourceType:=CanonicalType(SourceType);
 DestType:=CanonicalType(DestType);
 Guard:=0;
 While (SourceType<>0) And (Guard<MOD3_MAX_TYPES) Do Begin
  If SourceType=DestType Then Begin ObjectIsSubtype:=True; Exit; End;
  If SemanticTypes[SourceType].Kind<>TYPE_OBJECT Then Exit;
  SourceType:=CanonicalType(SemanticTypes[SourceType].BaseType);
  Inc(Guard);
 End;
End;

Function TypeCompatible(DestType,SourceType:Integer):Boolean;
Var
 DestKind,SourceKind:TTypeKind;
Begin
 DestType:=CanonicalType(DestType);
 SourceType:=CanonicalType(SourceType);
 If (DestType=0) Or (SourceType=0) Then Begin
  TypeCompatible:=True;
  Exit;
 End;
 If DestType=SourceType Then Begin
  TypeCompatible:=True;
  Exit;
 End;
 DestKind:=SemanticTypes[DestType].Kind;
 SourceKind:=SemanticTypes[SourceType].Kind;
 TypeCompatible:=
  ((DestKind=TYPE_INTEGER) And (SourceKind=TYPE_CARDINAL)) Or
  ((DestKind=TYPE_CARDINAL) And (SourceKind=TYPE_INTEGER)) Or
  ((DestKind=TYPE_REAL) And
   ((SourceKind=TYPE_INTEGER) Or (SourceKind=TYPE_CARDINAL))) Or
  ((DestKind=TYPE_LONGREAL) And
   ((SourceKind=TYPE_INTEGER) Or (SourceKind=TYPE_CARDINAL) Or
    (SourceKind=TYPE_REAL))) Or
 ((DestKind=TYPE_TEXT) And (SourceKind=TYPE_NIL)) Or
 ((DestKind=TYPE_OBJECT) And (SourceKind=TYPE_OBJECT) And
  ObjectIsSubtype(SourceType,DestType)) Or
  (((DestKind=TYPE_OPAQUE) Or (DestKind=TYPE_SUBRANGE)) And
   (SemanticTypes[DestType].BaseType<>0) And
   TypeCompatible(SemanticTypes[DestType].BaseType,SourceType)) Or
  ((SourceKind=TYPE_SUBRANGE) And
   (SemanticTypes[SourceType].BaseType<>0) And
   TypeCompatible(DestType,SemanticTypes[SourceType].BaseType)) Or
  (((DestKind=TYPE_REF) Or (DestKind=TYPE_OPAQUE) Or
    (DestKind=TYPE_OBJECT) Or (DestKind=TYPE_TEXT)) And
   (SourceKind=TYPE_NIL));
End;

Function TypeConvertible(DestType,SourceType:Integer):Boolean;
Var
 DestKind,SourceKind:TTypeKind;
Begin
 If TypeCompatible(DestType,SourceType) Then Begin
  TypeConvertible:=True;
  Exit;
 End;
 DestType:=CanonicalType(DestType);
 SourceType:=CanonicalType(SourceType);
 If (DestType=0) Or (SourceType=0) Then Begin
  TypeConvertible:=False;
  Exit;
 End;
 DestKind:=SemanticTypes[DestType].Kind;
 SourceKind:=SemanticTypes[SourceType].Kind;
 TypeConvertible:=
  (TypeIsNumeric(DestType) And TypeIsNumeric(SourceType)) Or
  ((DestKind=TYPE_INTEGER) And
   ((SourceKind=TYPE_CHAR) Or (SourceKind=TYPE_BOOLEAN))) Or
  ((DestKind=TYPE_CHAR) And TypeIsInteger(SourceType)) Or
  ((DestKind=TYPE_BOOLEAN) And TypeIsInteger(SourceType));
End;

Function FindTypeByName(Name:String;ScopeIndex:Integer):Integer;
Var
 SymbolIndex:Integer;
Begin
 FindTypeByName:=0;
 SymbolIndex:=FindVisibleSymbol(Name,ScopeIndex);
 If (SymbolIndex<>0) And (SemanticSymbols[SymbolIndex].Kind=SYM_TYPE) Then
  FindTypeByName:=SemanticSymbols[SymbolIndex].TypeIndex;
End;

Function LiteralType(Token:TToken):Integer;
Var
 U:String;
Begin
 Case Token.Kind Of
  TK_INTEGER:LiteralType:=TypeInteger;
  TK_REAL   :LiteralType:=TypeReal;
  TK_CHAR   :LiteralType:=TypeChar;
  TK_STRING :LiteralType:=TypeText;
  TK_IDENTIFIER:Begin
   U:=UpperStr(Token.Text);
   If (U='TRUE') Or (U='FALSE') Then LiteralType:=TypeBoolean
   Else If U='NIL' Then LiteralType:=TypeNil
   Else LiteralType:=0;
  End;
 Else LiteralType:=0;
 End;
End;

Function InvalidConst:TConstValue;
Var
 V:TConstValue;
Begin
 FillChar(V,SizeOf(V),0);
 V.Kind:=CONST_INVALID;
 V.Valid:=False;
 InvalidConst:=V;
End;

Function IntegerConst(Value:LongInt):TConstValue;
Var
 V:TConstValue;
Begin
 V:=InvalidConst;
 V.Kind:=CONST_INTEGER;
 V.TypeIndex:=TypeInteger;
 V.IntegerVal:=Value;
 V.RealVal:=Value;
 V.Valid:=True;
 IntegerConst:=V;
End;

Function RealConst(Value:Extended):TConstValue;
Var
 V:TConstValue;
Begin
 V:=InvalidConst;
 V.Kind:=CONST_REAL;
 V.TypeIndex:=TypeReal;
 V.RealVal:=Value;
 V.Valid:=True;
 RealConst:=V;
End;

Function BooleanConst(Value:Boolean):TConstValue;
Var
 V:TConstValue;
Begin
 V:=InvalidConst;
 V.Kind:=CONST_BOOLEAN;
 V.TypeIndex:=TypeBoolean;
 If Value Then V.IntegerVal:=1 Else V.IntegerVal:=0;
 V.Valid:=True;
 BooleanConst:=V;
End;

Function CharConst(Value:Char):TConstValue;
Var
 V:TConstValue;
Begin
 V:=InvalidConst;
 V.Kind:=CONST_CHAR;
 V.TypeIndex:=TypeChar;
 V.IntegerVal:=Ord(Value);
 V.TextVal:=Value;
 V.Valid:=True;
 CharConst:=V;
End;

Function TextConst(Value:String):TConstValue;
Var
 V:TConstValue;
Begin
 V:=InvalidConst;
 V.Kind:=CONST_TEXT;
 V.TypeIndex:=TypeText;
 V.TextVal:=Value;
 V.Valid:=True;
 TextConst:=V;
End;

Function NilConst:TConstValue;
Var
 V:TConstValue;
Begin
 V:=InvalidConst;
 V.Kind:=CONST_NIL;
 V.TypeIndex:=TypeNil;
 V.Valid:=True;
 NilConst:=V;
End;

Function ConstKindName(Kind:TConstKind):String;
Begin
 Case Kind Of
  CONST_INTEGER:ConstKindName:='entier';
  CONST_REAL   :ConstKindName:='reel';
  CONST_BOOLEAN:ConstKindName:='booleen';
  CONST_CHAR   :ConstKindName:='caractere';
  CONST_TEXT   :ConstKindName:='texte';
  CONST_NIL    :ConstKindName:='NIL';
  Else ConstKindName:='invalide';
 End;
End;

Function SemanticToken:TToken; Forward;

Function ResolveTypeToken(ScopeIndex:Integer;ReportUnknown:Boolean):Integer;
Var
 Tok:TToken;
 Found:Integer;
Begin
 Found:=0;
 Tok:=SemanticToken;
 If Tok.Kind=TK_IDENTIFIER Then Begin
  Found:=FindTypeByName(Tok.Text,ScopeIndex);
  If (Found=0) And ReportUnknown Then
   SemanticError('type inconnu: '+Tok.Text,Tok.Line,Tok.Column);
 End;
 ResolveTypeToken:=Found;
End;

Function SemanticToken:TToken;
Begin
 If SemanticIndex<1 Then SemanticIndex:=1;
 If SemanticIndex>Pipeline.TokenCount Then
  SemanticToken:=Pipeline.Tokens[Pipeline.TokenCount]
 Else SemanticToken:=Pipeline.Tokens[SemanticIndex];
End;

Procedure SemanticAdvance;
Begin
 If SemanticIndex<Pipeline.TokenCount Then Inc(SemanticIndex);
End;

Function SemanticIsKeyword(Keyword:TKeyword):Boolean;
Begin
 SemanticIsKeyword:=(SemanticToken.Kind=TK_KEYWORD) And
                    (SemanticToken.Keyword=Keyword);
End;

Function SemanticIsSymbol(S:String):Boolean;
Begin
 SemanticIsSymbol:=(SemanticToken.Kind=TK_SYMBOL) And
                   (SemanticToken.Text=S);
End;

Procedure SemanticSkipToSemicolon;
Var
 ParenDepth,BracketDepth,TypeDepth:Integer;
Begin
 ParenDepth:=0;
 BracketDepth:=0;
 TypeDepth:=0;
 While SemanticToken.Kind<>TK_EOF Do Begin
  If SemanticIsSymbol('(') Then Inc(ParenDepth)
  Else If SemanticIsSymbol(')') And (ParenDepth>0) Then Dec(ParenDepth)
  Else If SemanticIsSymbol('[') Then Inc(BracketDepth)
  Else If SemanticIsSymbol(']') And (BracketDepth>0) Then Dec(BracketDepth)
  Else If SemanticIsKeyword(KW_RECORD) Or SemanticIsKeyword(KW_OBJECT) Then
   Inc(TypeDepth)
  Else If SemanticIsKeyword(KW_END) And (TypeDepth>0) Then Dec(TypeDepth)
  Else If SemanticIsSymbol(';') And (ParenDepth=0) And
          (BracketDepth=0) And (TypeDepth=0) Then Begin
   SemanticAdvance;
   Exit;
  End;
  SemanticAdvance;
 End;
End;

Procedure AddPredefinedTypes(UniverseScope:Integer);
Var
 TypeIndex:Integer;
Begin
 TypeInteger:=AddSemanticType('INTEGER',TYPE_INTEGER,4,4,0,0,0);
 TypeCardinal:=AddSemanticType('CARDINAL',TYPE_CARDINAL,4,4,0,0,0);
 TypeBoolean:=AddSemanticType('BOOLEAN',TYPE_BOOLEAN,1,1,0,0,0);
 TypeChar:=AddSemanticType('CHAR',TYPE_CHAR,1,1,0,0,0);
 TypeReal:=AddSemanticType('REAL',TYPE_REAL,4,4,0,0,0);
 TypeLongReal:=AddSemanticType('LONGREAL',TYPE_LONGREAL,8,4,0,0,0);
 TypeText:=AddSemanticType('TEXT',TYPE_TEXT,4,4,0,0,0);
 TypeNil:=AddSemanticType('NIL',TYPE_NIL,4,4,0,0,0);
 AddTypedSemanticSymbol('INTEGER',SYM_TYPE,UniverseScope,TypeInteger,0,0);
 AddTypedSemanticSymbol('CARDINAL',SYM_TYPE,UniverseScope,TypeCardinal,0,0);
 AddTypedSemanticSymbol('BOOLEAN',SYM_TYPE,UniverseScope,TypeBoolean,0,0);
 AddTypedSemanticSymbol('CHAR',SYM_TYPE,UniverseScope,TypeChar,0,0);
 AddTypedSemanticSymbol('REAL',SYM_TYPE,UniverseScope,TypeReal,0,0);
 AddTypedSemanticSymbol('LONGREAL',SYM_TYPE,UniverseScope,TypeLongReal,0,0);
 AddTypedSemanticSymbol('TEXT',SYM_TYPE,UniverseScope,TypeText,0,0);
 TypeIndex:=AddSemanticType('REFANY',TYPE_REF,4,4,0,0,0);
 AddTypedSemanticSymbol('REFANY',SYM_TYPE,UniverseScope,TypeIndex,0,0);
 TypeRoot:=AddSemanticType('ROOT',TYPE_OBJECT,4,4,0,0,0);
 SemanticTypes[TypeRoot].InstanceSize:=4;
 AddTypedSemanticSymbol('ROOT',SYM_TYPE,UniverseScope,TypeRoot,0,0);
 TypeIndex:=AddSemanticType('ADDRESS',TYPE_REF,4,4,0,0,0);
 AddTypedSemanticSymbol('ADDRESS',SYM_TYPE,UniverseScope,TypeIndex,0,0);
 TypeIndex:=AddSemanticType('NULL',TYPE_REF,4,4,0,0,0);
 AddTypedSemanticSymbol('NULL',SYM_TYPE,UniverseScope,TypeIndex,0,0);
 TypeIndex:=AddSemanticType('MUTEX',TYPE_REF,4,4,0,0,0);
 AddTypedSemanticSymbol('MUTEX',SYM_TYPE,UniverseScope,TypeIndex,0,0);
End;

Procedure AddPredefinedSymbols(UniverseScope:Integer);
Const
 PredefProcCount = 18;
 PredefProcs:Array[1..PredefProcCount] Of String[8] =
  ('ABS','DEC','DISPOSE','FIRST','FLOAT','INC','ISTYPE',
   'LAST','MAX','MIN','NEW','ORD','TRUNC','VAL','BITSIZE',
   'NARROW','TYPECODE','NUMBER');
Var
 I,SymbolIndex:Integer;
Begin
 AddTypedSemanticSymbol('TRUE',SYM_CONST,UniverseScope,TypeBoolean,0,0);
 SymbolIndex:=FindSymbolInScope('TRUE',UniverseScope);
 SemanticSymbols[SymbolIndex].ConstValue:=BooleanConst(True);
 AddTypedSemanticSymbol('FALSE',SYM_CONST,UniverseScope,TypeBoolean,0,0);
 SymbolIndex:=FindSymbolInScope('FALSE',UniverseScope);
 SemanticSymbols[SymbolIndex].ConstValue:=BooleanConst(False);
 AddTypedSemanticSymbol('NIL',SYM_CONST,UniverseScope,TypeNil,0,0);
 SymbolIndex:=FindSymbolInScope('NIL',UniverseScope);
 SemanticSymbols[SymbolIndex].ConstValue:=NilConst;
 For I:=1 To PredefProcCount Do
  AddSemanticSymbol(PredefProcs[I],SYM_PROCEDURE,UniverseScope,0,0);
End;

Function AlignTo(Value,Alignment:Integer):Integer;
Begin
 If Alignment<=1 Then AlignTo:=Value
 Else AlignTo:=((Value+Alignment-1) Div Alignment)*Alignment;
End;

Function ParseSemanticType(ScopeIndex:Integer;SuggestedName:String):Integer;
 Forward;

Function FindObjectMember(TypeIndex:Integer;Name:String):Integer;
Var
 Found:Integer;
Begin
 Found:=0;
 TypeIndex:=CanonicalType(TypeIndex);
 If (TypeIndex<1) Or (TypeIndex>SemanticTypeCount) Then Begin
  FindObjectMember:=Found;
  Exit;
 End;
 If SemanticTypes[TypeIndex].FieldScope<>0 Then
  Found:=FindSymbolInScope(Name,SemanticTypes[TypeIndex].FieldScope);
 If (Found=0) And (SemanticTypes[TypeIndex].BaseType<>0) Then
  Found:=FindObjectMember(SemanticTypes[TypeIndex].BaseType,Name);
 FindObjectMember:=Found;
End;

Procedure ParseRecordFields(TypeIndex,FieldScope:Integer);
Var
 Names:Array[1..64] Of TToken;
 NameCount,I,FieldType,SymbolIndex:Integer;
 FieldOffset,FieldAlign,FieldSize:Integer;
 MemberKind:TSymbolKind;
 SectionKind,BaseMember,ParenDepth:Integer;
Begin
 FieldOffset:=0;
 SectionKind:=0;
 If (SemanticTypes[TypeIndex].Kind=TYPE_OBJECT) Then Begin
  FieldOffset:=4;
  If SemanticTypes[TypeIndex].BaseType<>0 Then Begin
   FieldOffset:=SemanticTypes[CanonicalType(
    SemanticTypes[TypeIndex].BaseType)].InstanceSize;
   SemanticTypes[TypeIndex].MethodCount:=SemanticTypes[CanonicalType(
    SemanticTypes[TypeIndex].BaseType)].MethodCount;
  End;
 End;
 While (SemanticToken.Kind<>TK_EOF) And Not SemanticIsKeyword(KW_END) Do Begin
  If SemanticIsKeyword(KW_METHODS) Then Begin
   SectionKind:=1;
   SemanticAdvance;
   Continue;
  End;
  If SemanticIsKeyword(KW_OVERRIDES) Then Begin
   SectionKind:=2;
   SemanticAdvance;
   Continue;
  End;
  If SemanticToken.Kind<>TK_IDENTIFIER Then Begin
   SemanticAdvance;
   Continue;
  End;
  NameCount:=0;
  Repeat
   If NameCount<64 Then Begin
    Inc(NameCount);
    Names[NameCount]:=SemanticToken;
   End;
   SemanticAdvance;
   If SemanticIsSymbol(',') Then SemanticAdvance Else Break;
  Until False;
  If (SectionKind=0) And SemanticIsSymbol(':') Then MemberKind:=SYM_FIELD
  Else If SemanticIsSymbol('(') Or SemanticIsSymbol(':=') Then
   MemberKind:=SYM_METHOD
  Else Begin
   While (SemanticToken.Kind<>TK_EOF) And Not SemanticIsSymbol(';') And
         Not SemanticIsKeyword(KW_END) Do SemanticAdvance;
   If SemanticIsSymbol(';') Then SemanticAdvance;
   Continue;
  End;
  If MemberKind=SYM_FIELD Then Begin
   SemanticAdvance;
   FieldType:=ParseSemanticType(FieldScope,'');
   If FieldType=0 Then Begin
    FieldAlign:=1;
    FieldSize:=0;
   End
   Else Begin
    FieldAlign:=SemanticTypes[CanonicalType(FieldType)].Align;
    FieldSize:=SemanticTypes[CanonicalType(FieldType)].Size;
   End;
   FieldOffset:=AlignTo(FieldOffset,FieldAlign);
   For I:=1 To NameCount Do Begin
    AddTypedSemanticSymbol(Names[I].Text,SYM_FIELD,FieldScope,FieldType,
                           Names[I].Line,Names[I].Column);
    SymbolIndex:=FindSymbolInScope(Names[I].Text,FieldScope);
    If SymbolIndex<>0 Then SemanticSymbols[SymbolIndex].Offset:=FieldOffset;
    Inc(FieldOffset,FieldSize);
   End;
   If FieldAlign>SemanticTypes[TypeIndex].Align Then
    SemanticTypes[TypeIndex].Align:=FieldAlign;
  End
  Else Begin
   For I:=1 To NameCount Do Begin
    AddSemanticSymbol(Names[I].Text,SYM_METHOD,FieldScope,
                      Names[I].Line,Names[I].Column);
    SymbolIndex:=FindSymbolInScope(Names[I].Text,FieldScope);
    If SectionKind=2 Then Begin
     BaseMember:=FindObjectMember(SemanticTypes[TypeIndex].BaseType,
                                  Names[I].Text);
     If BaseMember=0 Then
      SemanticError('methode surchargee inconnue: '+Names[I].Text,
                    Names[I].Line,Names[I].Column)
     Else If SymbolIndex<>0 Then
     Begin
      SemanticSymbols[SymbolIndex].Offset:=SemanticSymbols[BaseMember].Offset;
      SemanticSymbols[SymbolIndex].TypeIndex:=
       SemanticSymbols[BaseMember].TypeIndex;
     End;
    End
    Else If SymbolIndex<>0 Then Begin
     SemanticSymbols[SymbolIndex].Offset:=SemanticTypes[TypeIndex].MethodCount;
     Inc(SemanticTypes[TypeIndex].MethodCount);
    End;
   End;
   If SemanticIsSymbol(':=') Then Begin
    SemanticAdvance;
    If SemanticToken.Kind=TK_IDENTIFIER Then Begin
     For I:=1 To NameCount Do Begin
      SymbolIndex:=FindSymbolInScope(Names[I].Text,FieldScope);
      If SymbolIndex<>0 Then SemanticSymbols[SymbolIndex].AsmLabel:=
       SemanticToken.Text;
     End;
     SemanticAdvance;
    End;
   End
   Else If SemanticIsSymbol('(') Then Begin
    ParenDepth:=0;
    Repeat
     If SemanticIsSymbol('(') Then Inc(ParenDepth)
     Else If SemanticIsSymbol(')') Then Dec(ParenDepth);
     SemanticAdvance;
    Until (SemanticToken.Kind=TK_EOF) Or (ParenDepth=0);
    If SemanticIsSymbol(':') Then Begin
     SemanticAdvance;
     FieldType:=ParseSemanticType(FieldScope,'');
     For I:=1 To NameCount Do Begin
      SymbolIndex:=FindSymbolInScope(Names[I].Text,FieldScope);
      If SymbolIndex<>0 Then SemanticSymbols[SymbolIndex].TypeIndex:=FieldType;
     End;
    End;
   End;
  End;
  While (SemanticToken.Kind<>TK_EOF) And Not SemanticIsSymbol(';') And
        Not SemanticIsKeyword(KW_END) Do SemanticAdvance;
  If SemanticIsSymbol(';') Then SemanticAdvance;
 End;
 SemanticTypes[TypeIndex].Size:=
  AlignTo(FieldOffset,SemanticTypes[TypeIndex].Align);
 If SemanticTypes[TypeIndex].Kind=TYPE_OBJECT Then Begin
  SemanticTypes[TypeIndex].InstanceSize:=SemanticTypes[TypeIndex].Size;
  SemanticTypes[TypeIndex].Size:=4;
 End;
End;

Procedure FillSemanticType(TypeIndex,ScopeIndex:Integer);
Var
 Tok:TToken;
 ElementType,FieldScope,BaseType:Integer;
 LowValue,HighValue,Count:LongInt;
 Negative:Boolean;
Begin
 If TypeIndex=0 Then Exit;
 While SemanticIsKeyword(KW_BRANDED) Or SemanticIsKeyword(KW_UNTRACED) Do Begin
  If SemanticIsKeyword(KW_BRANDED) Then Begin
   SemanticTypes[TypeIndex].Branded:=True;
   SemanticAdvance;
   If SemanticToken.Kind=TK_STRING Then SemanticAdvance;
  End
  Else Begin
   SemanticTypes[TypeIndex].Untraced:=True;
   SemanticAdvance;
  End;
 End;
 If SemanticIsKeyword(KW_REF) Then Begin
  SemanticAdvance;
  SemanticTypes[TypeIndex].Kind:=TYPE_REF;
  SemanticTypes[TypeIndex].Size:=4;
  SemanticTypes[TypeIndex].Align:=4;
  ElementType:=ParseSemanticType(ScopeIndex,'');
  SemanticTypes[TypeIndex].ElementType:=ElementType;
  Exit;
 End;
 If SemanticIsKeyword(KW_ARRAY) Then Begin
  SemanticAdvance;
  SemanticTypes[TypeIndex].Kind:=TYPE_ARRAY;
  SemanticTypes[TypeIndex].Align:=1;
  If SemanticIsSymbol('[') Then Begin
   SemanticAdvance;
   Negative:=SemanticIsSymbol('-');
   If Negative Then SemanticAdvance;
   If SemanticToken.Kind=TK_INTEGER Then Begin
    LowValue:=SemanticToken.IntegerVal;
    If Negative Then LowValue:=-LowValue;
    SemanticAdvance;
   End
   Else LowValue:=0;
   If SemanticIsSymbol('..') Then SemanticAdvance;
   Negative:=SemanticIsSymbol('-');
   If Negative Then SemanticAdvance;
   If SemanticToken.Kind=TK_INTEGER Then Begin
    HighValue:=SemanticToken.IntegerVal;
    If Negative Then HighValue:=-HighValue;
    SemanticAdvance;
   End
   Else HighValue:=LowValue-1;
   If SemanticIsSymbol(']') Then SemanticAdvance;
  End
  Else Begin
   LowValue:=0;
   HighValue:=-1;
   SemanticTypes[TypeIndex].OpenArray:=True;
  End;
  If SemanticIsKeyword(KW_OF) Then SemanticAdvance;
  ElementType:=ParseSemanticType(ScopeIndex,'');
  SemanticTypes[TypeIndex].ElementType:=ElementType;
  SemanticTypes[TypeIndex].LowBound:=LowValue;
  SemanticTypes[TypeIndex].HighBound:=HighValue;
  If ElementType<>0 Then Begin
   SemanticTypes[TypeIndex].Align:=
    SemanticTypes[CanonicalType(ElementType)].Align;
   If SemanticTypes[TypeIndex].OpenArray Then
    SemanticTypes[TypeIndex].Size:=8
   Else Begin
    Count:=HighValue-LowValue+1;
    If Count<0 Then Count:=0;
    SemanticTypes[TypeIndex].Size:=
     Count*SemanticTypes[CanonicalType(ElementType)].Size;
   End;
  End;
  Exit;
 End;
 If SemanticIsKeyword(KW_RECORD) Or SemanticIsKeyword(KW_OBJECT) Then Begin
  Tok:=SemanticToken;
  If SemanticIsKeyword(KW_RECORD) Then
   SemanticTypes[TypeIndex].Kind:=TYPE_RECORD
  Else Begin
   SemanticTypes[TypeIndex].Kind:=TYPE_OBJECT;
   SemanticTypes[TypeIndex].BaseType:=TypeRoot;
   SemanticTypes[TypeIndex].Size:=4;
   SemanticTypes[TypeIndex].Align:=4;
  End;
  SemanticAdvance;
  FieldScope:=NewSemanticScope(SCOPE_OBJECT,ScopeIndex,
                               SemanticTypes[TypeIndex].Name,
                               Tok.Line,Tok.Column);
  SemanticTypes[TypeIndex].FieldScope:=FieldScope;
  If FieldScope<>0 Then Begin
   ParseRecordFields(TypeIndex,FieldScope);
   SemanticScopes[FieldScope].EndToken:=SemanticIndex;
  End;
  If SemanticIsKeyword(KW_END) Then SemanticAdvance;
  If SemanticTypes[TypeIndex].Kind=TYPE_OBJECT Then
   SemanticTypes[TypeIndex].Size:=4;
  Exit;
 End;
 If SemanticIsSymbol('[') Then Begin
  SemanticTypes[TypeIndex].Kind:=TYPE_SUBRANGE;
  SemanticTypes[TypeIndex].BaseType:=TypeInteger;
  SemanticTypes[TypeIndex].Size:=4;
  SemanticTypes[TypeIndex].Align:=4;
  SemanticAdvance;
  If SemanticToken.Kind=TK_INTEGER Then Begin
   SemanticTypes[TypeIndex].LowBound:=SemanticToken.IntegerVal;
   SemanticAdvance;
  End;
  If SemanticIsSymbol('..') Then SemanticAdvance;
  If SemanticToken.Kind=TK_INTEGER Then Begin
   SemanticTypes[TypeIndex].HighBound:=SemanticToken.IntegerVal;
   SemanticAdvance;
  End;
  If SemanticIsSymbol(']') Then SemanticAdvance;
  Exit;
 End;
 If SemanticToken.Kind=TK_IDENTIFIER Then Begin
  BaseType:=FindTypeByName(SemanticToken.Text,ScopeIndex);
  If BaseType=0 Then
   SemanticError('type inconnu: '+SemanticToken.Text,
                 SemanticToken.Line,SemanticToken.Column)
  Else If (SemanticIndex<Pipeline.TokenCount) And
          (Pipeline.Tokens[SemanticIndex+1].Kind=TK_KEYWORD) And
          (Pipeline.Tokens[SemanticIndex+1].Keyword=KW_OBJECT) Then Begin
   SemanticTypes[TypeIndex].Kind:=TYPE_OBJECT;
   SemanticTypes[TypeIndex].BaseType:=BaseType;
   SemanticTypes[TypeIndex].Size:=4;
   SemanticTypes[TypeIndex].Align:=4;
   SemanticAdvance;
   Tok:=SemanticToken;
   SemanticAdvance;
   FieldScope:=NewSemanticScope(SCOPE_OBJECT,ScopeIndex,
                                SemanticTypes[TypeIndex].Name,
                                Tok.Line,Tok.Column);
   SemanticTypes[TypeIndex].FieldScope:=FieldScope;
   If FieldScope<>0 Then Begin
    ParseRecordFields(TypeIndex,FieldScope);
    SemanticScopes[FieldScope].EndToken:=SemanticIndex;
   End;
   If SemanticIsKeyword(KW_END) Then SemanticAdvance;
   Exit;
  End
  Else Begin
   SemanticTypes[TypeIndex].Kind:=TYPE_ALIAS;
   SemanticTypes[TypeIndex].BaseType:=BaseType;
   SemanticTypes[TypeIndex].Size:=SemanticTypes[CanonicalType(BaseType)].Size;
   SemanticTypes[TypeIndex].Align:=SemanticTypes[CanonicalType(BaseType)].Align;
  End;
  SemanticAdvance;
  Exit;
 End;
 { Les ensembles, sous-intervalles et signatures PROCEDURE restent
   nominaux jusqu'aux etapes specialisees suivantes. }
 SemanticTypes[TypeIndex].Kind:=TYPE_COMPOSITE;
 While (SemanticToken.Kind<>TK_EOF) And Not SemanticIsSymbol(';') Do
  SemanticAdvance;
End;

Function ParseSemanticType(ScopeIndex:Integer;SuggestedName:String):Integer;
Var
 Tok:TToken;
 ResultType:Integer;
Begin
 Tok:=SemanticToken;
 If Tok.Kind=TK_IDENTIFIER Then Begin
  ResultType:=FindTypeByName(Tok.Text,ScopeIndex);
  If ResultType=0 Then
   SemanticError('type inconnu: '+Tok.Text,Tok.Line,Tok.Column);
  SemanticAdvance;
  ParseSemanticType:=ResultType;
  Exit;
 End;
 If SuggestedName='' Then
  SuggestedName:='$anon'+IntToString(SemanticTypeCount+1);
 ResultType:=AddSemanticType(SuggestedName,TYPE_COMPOSITE,0,1,0,
                             Tok.Line,Tok.Column);
 FillSemanticType(ResultType,ScopeIndex);
 ParseSemanticType:=ResultType;
End;

Procedure ScanFormalParameters(ProcedureScope:Integer);
Var
 Names:Array[1..64] Of TToken;
 NameCount,I,ParenDepth,ParamType,SymbolIndex:Integer;
 Mode:TParameterMode;
Begin
 If Not SemanticIsSymbol('(') Then Exit;
 SemanticAdvance;
 ParenDepth:=1;
 While (SemanticToken.Kind<>TK_EOF) And (ParenDepth>0) Do Begin
  If SemanticIsSymbol('(') Then Begin
   Inc(ParenDepth);
   SemanticAdvance;
  End
  Else If SemanticIsSymbol(')') Then Begin
   Dec(ParenDepth);
   SemanticAdvance;
  End
  Else If (ParenDepth=1) Then Begin
   Mode:=PARAM_VALUE;
   If SemanticIsKeyword(KW_VAR) Then Begin
    Mode:=PARAM_VAR;
    SemanticAdvance;
   End
   Else If SemanticIsKeyword(KW_READONLY) Then Begin
    Mode:=PARAM_READONLY;
    SemanticAdvance;
   End
   Else If SemanticIsKeyword(KW_VALUE) Then SemanticAdvance;
   NameCount:=0;
   While SemanticToken.Kind=TK_IDENTIFIER Do Begin
    If NameCount<64 Then Begin
     Inc(NameCount);
     Names[NameCount]:=SemanticToken;
    End;
    SemanticAdvance;
    If SemanticIsSymbol(',') Then SemanticAdvance
    Else Break;
   End;
   If (NameCount>0) And SemanticIsSymbol(':') Then Begin
    SemanticAdvance;
    ParamType:=ParseSemanticType(ProcedureScope,'');
    For I:=1 To NameCount Do Begin
     AddTypedSemanticSymbol(Names[I].Text,SYM_PARAM,ProcedureScope,
                            ParamType,Names[I].Line,Names[I].Column);
     SymbolIndex:=FindSymbolInScope(Names[I].Text,ProcedureScope);
     If SymbolIndex<>0 Then Begin
      SemanticSymbols[SymbolIndex].TypeIndex:=ParamType;
      SemanticSymbols[SymbolIndex].ParamMode:=Mode;
     End;
    End;
    While (SemanticToken.Kind<>TK_EOF) And
          Not SemanticIsSymbol(';') And Not SemanticIsSymbol(')') Do
     SemanticAdvance;
    If SemanticIsSymbol(';') Then SemanticAdvance;
   End
   Else SemanticAdvance;
  End
  Else SemanticAdvance;
 End;
End;

Procedure DeclareIfAbsent(AName:String;ATypeIndex,ALine,AColumn,
 AScopeIndex:Integer);
Begin
 If FindVisibleSymbol(AName,AScopeIndex)=0 Then
  AddTypedSemanticSymbol(AName,SYM_VAR,AScopeIndex,ATypeIndex,ALine,AColumn);
End;

Procedure SkipProcedureStatements(ScopeIndex:Integer);
Var
 EndDepth,RepeatDepth:Integer;
 K:TKeyword;
 J,BoundSymbol,AliasType,ExcSymbol:Integer;
Begin
 EndDepth:=0;
 RepeatDepth:=0;
 While SemanticToken.Kind<>TK_EOF Do Begin
  If SemanticIsKeyword(KW_END) Then Begin
   If EndDepth=0 Then Exit;
   Dec(EndDepth);
  End
  Else If SemanticIsKeyword(KW_UNTIL) And (RepeatDepth>0) Then
   Dec(RepeatDepth)
  Else If SemanticToken.Kind=TK_KEYWORD Then Begin
   K:=SemanticToken.Keyword;
   If K=KW_FOR Then Begin
    Inc(EndDepth);
    If (SemanticIndex+2<=Pipeline.TokenCount) And
       (Pipeline.Tokens[SemanticIndex+1].Kind=TK_IDENTIFIER) And
       (Pipeline.Tokens[SemanticIndex+2].Kind=TK_SYMBOL) And
       (Pipeline.Tokens[SemanticIndex+2].Text=':=') Then
     DeclareIfAbsent(Pipeline.Tokens[SemanticIndex+1].Text,TypeInteger,
      Pipeline.Tokens[SemanticIndex+1].Line,
      Pipeline.Tokens[SemanticIndex+1].Column,ScopeIndex);
   End
   Else If K=KW_WITH Then Begin
    Inc(EndDepth);
    J:=SemanticIndex+1;
    While (J+1<=Pipeline.TokenCount) And
          (Pipeline.Tokens[J].Kind=TK_IDENTIFIER) And
          (Pipeline.Tokens[J+1].Kind=TK_SYMBOL) And
          (Pipeline.Tokens[J+1].Text='=') Do Begin
     AliasType:=TypeInteger;
     If (J+2<=Pipeline.TokenCount) And
        (Pipeline.Tokens[J+2].Kind=TK_IDENTIFIER) Then Begin
      BoundSymbol:=FindVisibleSymbol(Pipeline.Tokens[J+2].Text,ScopeIndex);
      If BoundSymbol<>0 Then AliasType:=SemanticSymbols[BoundSymbol].TypeIndex;
     End;
     DeclareIfAbsent(Pipeline.Tokens[J].Text,AliasType,
      Pipeline.Tokens[J].Line,Pipeline.Tokens[J].Column,ScopeIndex);
     J:=J+2;
     While (J<=Pipeline.TokenCount) And
           Not ((Pipeline.Tokens[J].Kind=TK_SYMBOL) And
                (Pipeline.Tokens[J].Text=',')) And
           Not ((Pipeline.Tokens[J].Kind=TK_KEYWORD) And
                (Pipeline.Tokens[J].Keyword=KW_DO)) Do Inc(J);
     If (J<=Pipeline.TokenCount) And (Pipeline.Tokens[J].Kind=TK_SYMBOL) And
        (Pipeline.Tokens[J].Text=',') Then Inc(J)
     Else Break;
    End;
   End
   Else If (K=KW_IF) Or (K=KW_WHILE) Or (K=KW_LOOP) Or
      (K=KW_CASE) Or (K=KW_BEGIN) Or (K=KW_TRY) Or
      (K=KW_TYPECASE) Or (K=KW_LOCK) Then Inc(EndDepth)
   Else If K=KW_REPEAT Then Inc(RepeatDepth);
  End
  Else If SemanticIsSymbol('|') And
          (SemanticIndex+5<=Pipeline.TokenCount) And
          (Pipeline.Tokens[SemanticIndex+1].Kind=TK_IDENTIFIER) And
          (Pipeline.Tokens[SemanticIndex+2].Kind=TK_SYMBOL) And
          (Pipeline.Tokens[SemanticIndex+2].Text='(') And
          (Pipeline.Tokens[SemanticIndex+3].Kind=TK_IDENTIFIER) And
          (Pipeline.Tokens[SemanticIndex+4].Kind=TK_SYMBOL) And
          (Pipeline.Tokens[SemanticIndex+4].Text=')') And
          (Pipeline.Tokens[SemanticIndex+5].Kind=TK_SYMBOL) And
          (Pipeline.Tokens[SemanticIndex+5].Text='=>') Then Begin
   ExcSymbol:=FindVisibleSymbol(Pipeline.Tokens[SemanticIndex+1].Text,ScopeIndex);
   AliasType:=TypeInteger;
   If (ExcSymbol<>0) And (SemanticSymbols[ExcSymbol].TypeIndex<>0) Then
    AliasType:=SemanticSymbols[ExcSymbol].TypeIndex;
   DeclareIfAbsent(Pipeline.Tokens[SemanticIndex+3].Text,AliasType,
    Pipeline.Tokens[SemanticIndex+3].Line,
    Pipeline.Tokens[SemanticIndex+3].Column,ScopeIndex);
  End;
  SemanticAdvance;
 End;
End;

Procedure ScanSemanticDeclarations(ScopeIndex:Integer); Forward;

Procedure ScanProcedureDeclaration(ParentScope:Integer);
Var
 ProcToken:TToken;
 ProcScope,ProcSymbol,ReturnType:Integer;
Begin
 SemanticAdvance;
 If SemanticToken.Kind<>TK_IDENTIFIER Then Exit;
 ProcToken:=SemanticToken;
 AddSemanticSymbol(ProcToken.Text,SYM_PROCEDURE,ParentScope,
                   ProcToken.Line,ProcToken.Column);
 ProcSymbol:=FindSymbolInScope(ProcToken.Text,ParentScope);
 SemanticAdvance;
 ProcScope:=NewSemanticScope(SCOPE_PROCEDURE,ParentScope,ProcToken.Text,
                             ProcToken.Line,ProcToken.Column);
 If ProcScope=0 Then Exit;
 If ProcSymbol<>0 Then SemanticSymbols[ProcSymbol].ProcScope:=ProcScope;
 ScanFormalParameters(ProcScope);
 If SemanticIsSymbol(':') Then Begin
  SemanticAdvance;
  ReturnType:=ParseSemanticType(ParentScope,'');
  If ProcSymbol<>0 Then SemanticSymbols[ProcSymbol].TypeIndex:=ReturnType;
 End;
 While (SemanticToken.Kind<>TK_EOF) And
       Not SemanticIsSymbol(';') And Not SemanticIsSymbol('=') Do
  SemanticAdvance;
 If SemanticIsSymbol(';') Then Begin
  SemanticAdvance;
  If (SemanticScopes[ParentScope].Kind=SCOPE_INTERFACE) Or
     ((SemanticScopes[ParentScope].Kind=SCOPE_GENERIC) And
      (SemanticScopes[ParentScope].TemplateKind=UK_INTERFACE)) Then Begin
   SemanticScopes[ProcScope].EndToken:=SemanticIndex;
   Exit;
  End;
 End;
 If SemanticIsSymbol('=') Then SemanticAdvance;
 ScanSemanticDeclarations(ProcScope);
 If SemanticIsKeyword(KW_BEGIN) Then Begin
  SemanticAdvance;
  SkipProcedureStatements(ProcScope);
  If SemanticIsKeyword(KW_END) Then SemanticAdvance;
  If SemanticToken.Kind=TK_IDENTIFIER Then SemanticAdvance;
  If SemanticIsSymbol(';') Then SemanticAdvance;
 End;
 SemanticScopes[ProcScope].EndToken:=SemanticIndex;
End;

Function ConstIsNumeric(V:TConstValue):Boolean;
Begin
 ConstIsNumeric:=V.Valid And
  ((V.Kind=CONST_INTEGER) Or (V.Kind=CONST_REAL) Or (V.Kind=CONST_CHAR));
End;

Function ConstAsReal(V:TConstValue):Extended;
Begin
 If V.Kind=CONST_REAL Then ConstAsReal:=V.RealVal
 Else ConstAsReal:=V.IntegerVal;
End;

Function EvalConstExpression(ScopeIndex:Integer):TConstValue; Forward;

Function EvalConstPrimary(ScopeIndex:Integer):TConstValue;
Var
 Tok:TToken;
 SymbolIndex:Integer;
 V:TConstValue;
Begin
 Tok:=SemanticToken;
 Case Tok.Kind Of
  TK_INTEGER:Begin
   EvalConstPrimary:=IntegerConst(Tok.IntegerVal);
   SemanticAdvance;
  End;
  TK_REAL:Begin
   EvalConstPrimary:=RealConst(Tok.RealVal);
   SemanticAdvance;
  End;
  TK_CHAR:Begin
   EvalConstPrimary:=CharConst(Chr(Tok.IntegerVal));
   SemanticAdvance;
  End;
  TK_STRING:Begin
   EvalConstPrimary:=TextConst(Tok.Text);
   SemanticAdvance;
  End;
  TK_IDENTIFIER:Begin
   SymbolIndex:=FindVisibleSymbol(Tok.Text,ScopeIndex);
   If (SymbolIndex=0) Or
      (SemanticSymbols[SymbolIndex].Kind<>SYM_CONST) Then Begin
    SemanticError('constante inconnue: '+Tok.Text,Tok.Line,Tok.Column);
    EvalConstPrimary:=InvalidConst;
   End
   Else If Not SemanticSymbols[SymbolIndex].ConstValue.Valid Then Begin
    SemanticError('reference a une constante non evaluable: '+Tok.Text,
                  Tok.Line,Tok.Column);
    EvalConstPrimary:=InvalidConst;
   End
   Else EvalConstPrimary:=SemanticSymbols[SymbolIndex].ConstValue;
   SemanticAdvance;
  End;
  TK_SYMBOL:Begin
   If Tok.Text='(' Then Begin
    SemanticAdvance;
    V:=EvalConstExpression(ScopeIndex);
    If SemanticIsSymbol(')') Then SemanticAdvance
    Else SemanticError('parenthese fermante attendue dans la constante',
                       SemanticToken.Line,SemanticToken.Column);
    EvalConstPrimary:=V;
   End
   Else Begin
    SemanticError('litteral ou constante attendu',Tok.Line,Tok.Column);
    EvalConstPrimary:=InvalidConst;
    SemanticAdvance;
   End;
  End;
  Else Begin
   SemanticError('expression constante attendue',Tok.Line,Tok.Column);
   EvalConstPrimary:=InvalidConst;
   SemanticAdvance;
  End;
 End;
End;

Function EvalConstUnary(ScopeIndex:Integer):TConstValue;
Var
 Tok:TToken;
 V:TConstValue;
Begin
 Tok:=SemanticToken;
 If SemanticIsSymbol('+') Then Begin
  SemanticAdvance;
  V:=EvalConstUnary(ScopeIndex);
  If Not ConstIsNumeric(V) Then
   SemanticError('operateur unaire + exige une valeur numerique',
                 Tok.Line,Tok.Column);
  EvalConstUnary:=V;
 End
 Else If SemanticIsSymbol('-') Then Begin
  SemanticAdvance;
  V:=EvalConstUnary(ScopeIndex);
  If Not ConstIsNumeric(V) Then Begin
   SemanticError('operateur unaire - exige une valeur numerique',
                 Tok.Line,Tok.Column);
   EvalConstUnary:=InvalidConst;
  End
  Else If V.Kind=CONST_REAL Then EvalConstUnary:=RealConst(-V.RealVal)
  Else EvalConstUnary:=IntegerConst(-V.IntegerVal);
 End
 Else If SemanticIsKeyword(KW_NOT) Then Begin
  SemanticAdvance;
  V:=EvalConstUnary(ScopeIndex);
  If V.Kind<>CONST_BOOLEAN Then Begin
   SemanticError('NOT exige une constante booleenne',Tok.Line,Tok.Column);
   EvalConstUnary:=InvalidConst;
  End
  Else EvalConstUnary:=BooleanConst(V.IntegerVal=0);
 End
 Else EvalConstUnary:=EvalConstPrimary(ScopeIndex);
End;

Function EvalConstProduct(ScopeIndex:Integer):TConstValue;
Var
 Left,Right:TConstValue;
 Tok:TToken;
 Op:String;
 IsDiv,IsMod:Boolean;
Begin
 Left:=EvalConstUnary(ScopeIndex);
 While SemanticIsSymbol('*') Or SemanticIsSymbol('/') Or
       SemanticIsKeyword(KW_DIV) Or SemanticIsKeyword(KW_MOD) Do Begin
  Tok:=SemanticToken;
  Op:=Tok.Text;
  IsDiv:=SemanticIsKeyword(KW_DIV);
  IsMod:=SemanticIsKeyword(KW_MOD);
  SemanticAdvance;
  Right:=EvalConstUnary(ScopeIndex);
  If Not ConstIsNumeric(Left) Or Not ConstIsNumeric(Right) Then Begin
   SemanticError('operateur multiplicatif exige des constantes numeriques',
                 Tok.Line,Tok.Column);
   Left:=InvalidConst;
  End
  Else If (IsDiv Or IsMod) And
          ((Left.Kind=CONST_REAL) Or (Right.Kind=CONST_REAL)) Then Begin
   SemanticError('DIV et MOD exigent des constantes entieres',
                 Tok.Line,Tok.Column);
   Left:=InvalidConst;
  End
  Else If ((IsDiv Or IsMod Or (Op='/')) And
           (ConstAsReal(Right)=0)) Then Begin
   SemanticError('division par zero dans une constante',Tok.Line,Tok.Column);
   Left:=InvalidConst;
  End
  Else If IsDiv Then Left:=IntegerConst(Left.IntegerVal Div Right.IntegerVal)
  Else If IsMod Then Left:=IntegerConst(Left.IntegerVal Mod Right.IntegerVal)
  Else If Op='/' Then Left:=RealConst(ConstAsReal(Left)/ConstAsReal(Right))
  Else If (Left.Kind=CONST_REAL) Or (Right.Kind=CONST_REAL) Then
   Left:=RealConst(ConstAsReal(Left)*ConstAsReal(Right))
  Else Left:=IntegerConst(Left.IntegerVal*Right.IntegerVal);
 End;
 EvalConstProduct:=Left;
End;

Function EvalConstSum(ScopeIndex:Integer):TConstValue;
Var
 Left,Right:TConstValue;
 Tok:TToken;
 Op:String;
Begin
 Left:=EvalConstProduct(ScopeIndex);
 While SemanticIsSymbol('+') Or SemanticIsSymbol('-') Or
       SemanticIsSymbol('&') Do Begin
  Tok:=SemanticToken;
  Op:=Tok.Text;
  SemanticAdvance;
  Right:=EvalConstProduct(ScopeIndex);
  If Op='&' Then Begin
   If (Left.Kind<>CONST_TEXT) Or (Right.Kind<>CONST_TEXT) Then Begin
    SemanticError('concatenation & exige deux constantes TEXT',
                  Tok.Line,Tok.Column);
    Left:=InvalidConst;
   End
   Else If Length(Left.TextVal)+Length(Right.TextVal)>255 Then Begin
    SemanticError('chaine constante concatenee trop longue',
                  Tok.Line,Tok.Column);
    Left:=InvalidConst;
   End
   Else Left:=TextConst(Left.TextVal+Right.TextVal);
  End
  Else If Not ConstIsNumeric(Left) Or Not ConstIsNumeric(Right) Then Begin
   SemanticError('operateur additif exige des constantes numeriques',
                 Tok.Line,Tok.Column);
   Left:=InvalidConst;
  End
  Else If (Left.Kind=CONST_REAL) Or (Right.Kind=CONST_REAL) Then Begin
   If Op='+' Then Left:=RealConst(ConstAsReal(Left)+ConstAsReal(Right))
   Else Left:=RealConst(ConstAsReal(Left)-ConstAsReal(Right));
  End
  Else If Op='+' Then Left:=IntegerConst(Left.IntegerVal+Right.IntegerVal)
  Else Left:=IntegerConst(Left.IntegerVal-Right.IntegerVal);
 End;
 EvalConstSum:=Left;
End;

Function EvalConstCompare(ScopeIndex:Integer):TConstValue;
Var
 Left,Right:TConstValue;
 Tok:TToken;
 Op:String;
 ResultValue:Boolean;
Begin
 Left:=EvalConstSum(ScopeIndex);
 If SemanticIsSymbol('=') Or SemanticIsSymbol('#') Or
    SemanticIsSymbol('<') Or SemanticIsSymbol('<=') Or
    SemanticIsSymbol('>') Or SemanticIsSymbol('>=') Then Begin
  Tok:=SemanticToken;
  Op:=Tok.Text;
  SemanticAdvance;
  Right:=EvalConstSum(ScopeIndex);
  If ConstIsNumeric(Left) And ConstIsNumeric(Right) Then Begin
   If Op='=' Then ResultValue:=ConstAsReal(Left)=ConstAsReal(Right)
   Else If Op='#' Then ResultValue:=ConstAsReal(Left)<>ConstAsReal(Right)
   Else If Op='<' Then ResultValue:=ConstAsReal(Left)<ConstAsReal(Right)
   Else If Op='<=' Then ResultValue:=ConstAsReal(Left)<=ConstAsReal(Right)
   Else If Op='>' Then ResultValue:=ConstAsReal(Left)>ConstAsReal(Right)
   Else ResultValue:=ConstAsReal(Left)>=ConstAsReal(Right);
   Left:=BooleanConst(ResultValue);
  End
  Else If Left.Kind=Right.Kind Then Begin
   If (Left.Kind=CONST_TEXT) Or (Left.Kind=CONST_CHAR) Then Begin
    If Op='=' Then ResultValue:=Left.TextVal=Right.TextVal
    Else If Op='#' Then ResultValue:=Left.TextVal<>Right.TextVal
    Else If Op='<' Then ResultValue:=Left.TextVal<Right.TextVal
    Else If Op='<=' Then ResultValue:=Left.TextVal<=Right.TextVal
    Else If Op='>' Then ResultValue:=Left.TextVal>Right.TextVal
    Else ResultValue:=Left.TextVal>=Right.TextVal;
    Left:=BooleanConst(ResultValue);
   End
   Else If Left.Kind=CONST_BOOLEAN Then Begin
    If Op='=' Then ResultValue:=Left.IntegerVal=Right.IntegerVal
    Else If Op='#' Then ResultValue:=Left.IntegerVal<>Right.IntegerVal
    Else Begin
     SemanticError('comparaison ordonnee invalide pour BOOLEAN',
                   Tok.Line,Tok.Column);
     Left:=InvalidConst;
     ResultValue:=False;
    End;
    If Left.Valid Then Left:=BooleanConst(ResultValue);
   End
   Else If Left.Kind=CONST_NIL Then
    Left:=BooleanConst(Op='=')
   Else Left:=InvalidConst;
  End
  Else Begin
   SemanticError('constantes incompatibles dans la comparaison',
                 Tok.Line,Tok.Column);
   Left:=InvalidConst;
  End;
 End;
 EvalConstCompare:=Left;
End;

Function EvalConstAnd(ScopeIndex:Integer):TConstValue;
Var
 Left,Right:TConstValue;
 Tok:TToken;
Begin
 Left:=EvalConstCompare(ScopeIndex);
 While SemanticIsKeyword(KW_AND) Do Begin
  Tok:=SemanticToken;
  SemanticAdvance;
  Right:=EvalConstCompare(ScopeIndex);
  If (Left.Kind<>CONST_BOOLEAN) Or (Right.Kind<>CONST_BOOLEAN) Then Begin
   SemanticError('AND exige deux constantes booleennes',Tok.Line,Tok.Column);
   Left:=InvalidConst;
  End
  Else Left:=BooleanConst((Left.IntegerVal<>0) And (Right.IntegerVal<>0));
 End;
 EvalConstAnd:=Left;
End;

Function EvalConstExpression(ScopeIndex:Integer):TConstValue;
Var
 Left,Right:TConstValue;
 Tok:TToken;
Begin
 Left:=EvalConstAnd(ScopeIndex);
 While SemanticIsKeyword(KW_OR) Do Begin
  Tok:=SemanticToken;
  SemanticAdvance;
  Right:=EvalConstAnd(ScopeIndex);
  If (Left.Kind<>CONST_BOOLEAN) Or (Right.Kind<>CONST_BOOLEAN) Then Begin
   SemanticError('OR exige deux constantes booleennes',Tok.Line,Tok.Column);
   Left:=InvalidConst;
  End
  Else Left:=BooleanConst((Left.IntegerVal<>0) Or (Right.IntegerVal<>0));
 End;
 EvalConstExpression:=Left;
End;

Procedure ScanConstSection(ScopeIndex:Integer);
Var
 Tok:TToken;
 ConstType,SymbolIndex:Integer;
 Value:TConstValue;
Begin
 SemanticAdvance;
 While SemanticToken.Kind=TK_IDENTIFIER Do Begin
  Tok:=SemanticToken;
  SemanticAdvance;
  If SemanticIsSymbol('=') Then SemanticAdvance;
  Value:=EvalConstExpression(ScopeIndex);
  ConstType:=Value.TypeIndex;
  AddTypedSemanticSymbol(Tok.Text,SYM_CONST,ScopeIndex,ConstType,
                         Tok.Line,Tok.Column);
  SymbolIndex:=FindSymbolInScope(Tok.Text,ScopeIndex);
  If SymbolIndex<>0 Then Begin
   SemanticSymbols[SymbolIndex].TypeIndex:=ConstType;
   SemanticSymbols[SymbolIndex].ConstValue:=Value;
  End;
  If Not SemanticIsSymbol(';') Then Begin
   SemanticError('fin d''expression constante attendue',
                 SemanticToken.Line,SemanticToken.Column);
   SemanticSkipToSemicolon;
  End
  Else SemanticAdvance;
 End;
End;

Procedure ScanTypeSection(ScopeIndex:Integer);
Var
 Tok:TToken;
 NewType,BaseType:Integer;
 IsSubtype:Boolean;
Begin
 SemanticAdvance;
 While SemanticToken.Kind=TK_IDENTIFIER Do Begin
  Tok:=SemanticToken;
  SemanticAdvance;
  IsSubtype:=SemanticIsSymbol('<:');
  If SemanticIsSymbol('=') Or IsSubtype Then SemanticAdvance;
  If IsSubtype Then
   NewType:=AddSemanticType(Tok.Text,TYPE_OPAQUE,4,4,0,
                            Tok.Line,Tok.Column)
  Else
   NewType:=AddSemanticType(Tok.Text,TYPE_COMPOSITE,0,1,0,
                            Tok.Line,Tok.Column);
  AddTypedSemanticSymbol(Tok.Text,SYM_TYPE,ScopeIndex,NewType,
                         Tok.Line,Tok.Column);
  If IsSubtype Then Begin
   BaseType:=ParseSemanticType(ScopeIndex,'');
   SemanticTypes[NewType].BaseType:=BaseType;
   SemanticTypes[NewType].Revealed:=False;
  End
  Else FillSemanticType(NewType,ScopeIndex);
  While (SemanticToken.Kind<>TK_EOF) And Not SemanticIsSymbol(';') Do
   SemanticAdvance;
  If SemanticIsSymbol(';') Then SemanticAdvance;
 End;
End;

Procedure ScanVarSection(ScopeIndex:Integer);
Var
 Names:Array[1..64] Of TToken;
 NameCount,I,VarType,SymbolIndex:Integer;
 InitialValue:TConstValue;
 HasInitializer:Boolean;
Begin
 SemanticAdvance;
 While SemanticToken.Kind=TK_IDENTIFIER Do Begin
  NameCount:=0;
  Repeat
   If NameCount<64 Then Begin
    Inc(NameCount);
    Names[NameCount]:=SemanticToken;
   End;
   SemanticAdvance;
   If SemanticIsSymbol(',') Then SemanticAdvance
   Else Break;
  Until False;
  If SemanticIsSymbol(':') Then SemanticAdvance;
  VarType:=ParseSemanticType(ScopeIndex,'');
  HasInitializer:=SemanticIsSymbol(':=');
  InitialValue:=InvalidConst;
  If HasInitializer Then Begin
   SemanticAdvance;
   InitialValue:=EvalConstExpression(ScopeIndex);
   If InitialValue.Valid And Not TypeCompatible(VarType,InitialValue.TypeIndex) Then
    SemanticError('initialisation incompatible: '+TypeName(InitialValue.TypeIndex)+
                  ' vers '+TypeName(VarType),
                  Names[1].Line,Names[1].Column);
  End;
  For I:=1 To NameCount Do Begin
   AddTypedSemanticSymbol(Names[I].Text,SYM_VAR,ScopeIndex,VarType,
                          Names[I].Line,Names[I].Column);
   SymbolIndex:=FindSymbolInScope(Names[I].Text,ScopeIndex);
   If SymbolIndex<>0 Then Begin
    SemanticSymbols[SymbolIndex].HasInitializer:=HasInitializer;
    If HasInitializer Then
     SemanticSymbols[SymbolIndex].ConstValue:=InitialValue;
   End;
  End;
  SemanticSkipToSemicolon;
 End;
End;

Procedure ScanExceptionSection(ScopeIndex:Integer);
Var
 Tok:TToken;
 SymbolIndex,ArgType:Integer;
Begin
 SemanticAdvance;
 While SemanticToken.Kind=TK_IDENTIFIER Do Begin
  Tok:=SemanticToken;
  AddSemanticSymbol(Tok.Text,SYM_EXCEPTION,ScopeIndex,Tok.Line,Tok.Column);
  SymbolIndex:=FindSymbolInScope(Tok.Text,ScopeIndex);
  SemanticAdvance;
  If SemanticIsSymbol('(') Then Begin
   SemanticAdvance;
   ArgType:=ParseSemanticType(ScopeIndex,'');
   If (SymbolIndex<>0) And (ArgType<>0) Then
    SemanticSymbols[SymbolIndex].TypeIndex:=ArgType;
   If SemanticIsSymbol(')') Then SemanticAdvance;
  End;
  SemanticSkipToSemicolon;
 End;
End;

Procedure ScanRevealSection(ScopeIndex:Integer);
Var
 Tok:TToken;
 SymbolIndex,TypeIndex,BaseType:Integer;
Begin
 SemanticAdvance;
 While SemanticToken.Kind=TK_IDENTIFIER Do Begin
  Tok:=SemanticToken;
  SymbolIndex:=FindVisibleSymbol(Tok.Text,ScopeIndex);
  If SymbolIndex=0 Then Begin
   TypeIndex:=AddSemanticType(Tok.Text,TYPE_OPAQUE,4,4,0,
                              Tok.Line,Tok.Column);
   AddTypedSemanticSymbol(Tok.Text,SYM_TYPE,ScopeIndex,TypeIndex,
                          Tok.Line,Tok.Column);
   SymbolIndex:=FindSymbolInScope(Tok.Text,ScopeIndex);
  End
  Else If SemanticSymbols[SymbolIndex].Kind<>SYM_TYPE Then Begin
   SemanticError('identificateur non type dans REVEAL: '+Tok.Text,
                 Tok.Line,Tok.Column);
   SemanticSkipToSemicolon;
   Continue;
  End;
  TypeIndex:=SemanticSymbols[SymbolIndex].TypeIndex;
  If SemanticTypes[TypeIndex].Kind<>TYPE_OPAQUE Then
   SemanticError('REVEAL applique a un type non opaque: '+Tok.Text,
                 Tok.Line,Tok.Column);
  SemanticAdvance;
  If SemanticIsSymbol('=') Then SemanticAdvance;
  BaseType:=0;
  If SemanticToken.Kind=TK_IDENTIFIER Then Begin
   BaseType:=FindTypeByName(SemanticToken.Text,ScopeIndex);
   If BaseType=0 Then
    SemanticError('supertype inconnu dans REVEAL: '+SemanticToken.Text,
                  SemanticToken.Line,SemanticToken.Column);
   SemanticAdvance;
  End;
  If BaseType<>0 Then SemanticTypes[TypeIndex].BaseType:=BaseType;
  If SemanticIsKeyword(KW_BRANDED) Or SemanticIsKeyword(KW_UNTRACED) Or
     SemanticIsKeyword(KW_OBJECT) Or SemanticIsKeyword(KW_RECORD) Or
     SemanticIsKeyword(KW_REF) Or SemanticIsKeyword(KW_ARRAY) Then
   FillSemanticType(TypeIndex,ScopeIndex)
  Else If BaseType<>0 Then Begin
   SemanticTypes[TypeIndex].Kind:=TYPE_ALIAS;
   SemanticTypes[TypeIndex].Size:=SemanticTypes[CanonicalType(BaseType)].Size;
   SemanticTypes[TypeIndex].Align:=SemanticTypes[CanonicalType(BaseType)].Align;
  End;
  SemanticTypes[TypeIndex].Revealed:=True;
  While (SemanticToken.Kind<>TK_EOF) And Not SemanticIsSymbol(';') Do
   SemanticAdvance;
  If SemanticIsSymbol(';') Then SemanticAdvance;
 End;
End;

Procedure ScanSemanticDeclarations(ScopeIndex:Integer);
Begin
 While SemanticToken.Kind<>TK_EOF Do Begin
  If SemanticIsKeyword(KW_CONST) Then ScanConstSection(ScopeIndex)
  Else If SemanticIsKeyword(KW_TYPE) Then ScanTypeSection(ScopeIndex)
  Else If SemanticIsKeyword(KW_VAR) Then ScanVarSection(ScopeIndex)
  Else If SemanticIsKeyword(KW_EXCEPTION) Then ScanExceptionSection(ScopeIndex)
  Else If SemanticIsKeyword(KW_REVEAL) Then ScanRevealSection(ScopeIndex)
  Else If SemanticIsKeyword(KW_PROCEDURE) Then
   ScanProcedureDeclaration(ScopeIndex)
  Else Break;
 End;
End;

Procedure ScanImportsIntoScope(ScopeIndex:Integer);
Var
 Tok:TToken;
Begin
 While SemanticIsKeyword(KW_IMPORT) Or SemanticIsKeyword(KW_FROM) Do Begin
  If SemanticIsKeyword(KW_FROM) Then Begin
   SemanticAdvance;
   If SemanticToken.Kind=TK_IDENTIFIER Then SemanticAdvance;
   If SemanticIsKeyword(KW_IMPORT) Then SemanticAdvance;
   While SemanticToken.Kind=TK_IDENTIFIER Do Begin
    Tok:=SemanticToken;
    AddSemanticSymbol(Tok.Text,SYM_IMPORT,ScopeIndex,Tok.Line,Tok.Column);
    SemanticAdvance;
    If SemanticIsSymbol(',') Then SemanticAdvance Else Break;
   End;
  End
  Else Begin
   SemanticAdvance;
   While SemanticToken.Kind=TK_IDENTIFIER Do Begin
    Tok:=SemanticToken;
    AddSemanticSymbol(Tok.Text,SYM_IMPORT,ScopeIndex,Tok.Line,Tok.Column);
    SemanticAdvance;
    If SemanticIsSymbol(',') Then SemanticAdvance Else Break;
   End;
  End;
  If SemanticIsSymbol(';') Then SemanticAdvance;
 End;
End;

Function StorageKindName(Kind:TStorageKind):String;
Begin
 Case Kind Of
  STORAGE_GLOBAL_DATA:StorageKindName:='data';
  STORAGE_GLOBAL_BSS :StorageKindName:='bss';
  STORAGE_LOCAL      :StorageKindName:='pile';
  STORAGE_PARAMETER  :StorageKindName:='parametre';
  STORAGE_FIELD      :StorageKindName:='champ';
  Else StorageKindName:='aucun';
 End;
End;

Function TypeStorageSize(TypeIndex:Integer):Integer;
Var
 ResultSize:Integer;
Begin
 TypeIndex:=CanonicalType(TypeIndex);
 If (TypeIndex<1) Or (TypeIndex>SemanticTypeCount) Then
  ResultSize:=I386_STACK_SLOT_SIZE
 Else Begin
  ResultSize:=SemanticTypes[TypeIndex].Size;
  If ResultSize<1 Then ResultSize:=I386_STACK_SLOT_SIZE;
 End;
 TypeStorageSize:=ResultSize;
End;

Function TypeStorageAlign(TypeIndex:Integer):Integer;
Var
 ResultAlign:Integer;
Begin
 TypeIndex:=CanonicalType(TypeIndex);
 If (TypeIndex<1) Or (TypeIndex>SemanticTypeCount) Then
  ResultAlign:=I386_STACK_ALIGN
 Else Begin
  ResultAlign:=SemanticTypes[TypeIndex].Align;
  If ResultAlign<1 Then ResultAlign:=1;
  If ResultAlign>I386_STACK_ALIGN Then
   ResultAlign:=I386_STACK_ALIGN;
 End;
 TypeStorageAlign:=ResultAlign;
End;

Procedure LayoutSemanticStorage(UnitScope:Integer);
Var
 I,ScopeIndex,LocalSize,ParamOffset,DataOffset,BssOffset:Integer;
 Size,Alignment:Integer;
Begin
 DataOffset:=0;
 BssOffset:=0;
 For I:=1 To SemanticSymbolCount Do
  If SemanticSymbols[I].Kind=SYM_FIELD Then Begin
   SemanticSymbols[I].Storage:=STORAGE_FIELD;
   SemanticSymbols[I].Size:=TypeStorageSize(SemanticSymbols[I].TypeIndex);
  End;

 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_VAR) And
     (SemanticSymbols[I].ScopeIndex=UnitScope) Then Begin
   Size:=TypeStorageSize(SemanticSymbols[I].TypeIndex);
   Alignment:=TypeStorageAlign(SemanticSymbols[I].TypeIndex);
   SemanticSymbols[I].Size:=Size;
   SemanticSymbols[I].AsmLabel:=
    MakeDataLabel(Pipeline.ModuleName+'_'+SemanticSymbols[I].Name);
   If SemanticSymbols[I].HasInitializer And
      SemanticSymbols[I].ConstValue.Valid Then Begin
    DataOffset:=AlignTo(DataOffset,Alignment);
    SemanticSymbols[I].Storage:=STORAGE_GLOBAL_DATA;
    SemanticSymbols[I].Offset:=DataOffset;
    Inc(DataOffset,Size);
   End
   Else Begin
    BssOffset:=AlignTo(BssOffset,Alignment);
    SemanticSymbols[I].Storage:=STORAGE_GLOBAL_BSS;
    SemanticSymbols[I].Offset:=BssOffset;
    Inc(BssOffset,Size);
   End;
  End;

 For ScopeIndex:=1 To SemanticScopeCount Do
  If SemanticScopes[ScopeIndex].Kind=SCOPE_PROCEDURE Then Begin
   LocalSize:=0;
   ParamOffset:=I386_ARG_BASE_OFFSET;
   For I:=1 To SemanticSymbolCount Do
    If SemanticSymbols[I].ScopeIndex=ScopeIndex Then Begin
     If SemanticSymbols[I].Kind=SYM_PARAM Then Begin
      SemanticSymbols[I].Storage:=STORAGE_PARAMETER;
      SemanticSymbols[I].Size:=I386_STACK_SLOT_SIZE;
      SemanticSymbols[I].Offset:=ParamOffset;
      Inc(ParamOffset,I386_STACK_SLOT_SIZE);
     End
     Else If SemanticSymbols[I].Kind=SYM_VAR Then Begin
      Size:=TypeStorageSize(SemanticSymbols[I].TypeIndex);
      Alignment:=TypeStorageAlign(SemanticSymbols[I].TypeIndex);
      LocalSize:=AlignTo(LocalSize,Alignment);
      Inc(LocalSize,Size);
      SemanticSymbols[I].Storage:=STORAGE_LOCAL;
      SemanticSymbols[I].Size:=Size;
      SemanticSymbols[I].Offset:=-LocalSize;
     End;
    End;
   SemanticScopes[ScopeIndex].FrameSize:=
    AlignTo(LocalSize,I386_STACK_ALIGN);
  End;
End;

Function ScopeForToken(TokenIndex,UnitScope:Integer):Integer;
Var
 I,BestLevel:Integer;
Begin
 ScopeForToken:=UnitScope;
 BestLevel:=SemanticScopes[UnitScope].Level;
 For I:=1 To SemanticScopeCount Do
  If (SemanticScopes[I].Kind<>SCOPE_OBJECT) And
     (TokenIndex>=SemanticScopes[I].StartToken) And
     (TokenIndex<=SemanticScopes[I].EndToken) And
     (SemanticScopes[I].Level>=BestLevel) Then Begin
   ScopeForToken:=I;
   BestLevel:=SemanticScopes[I].Level;
  End;
End;

Function DesignatorTypeAt(TokenIndex,ScopeIndex:Integer):Integer;
Var
 SymbolIndex,TypeIndex,FieldSymbol,I,Depth:Integer;
 Kind:TTypeKind;
Begin
 DesignatorTypeAt:=0;
 If (TokenIndex<1) Or (TokenIndex>Pipeline.TokenCount) Or
    (Pipeline.Tokens[TokenIndex].Kind<>TK_IDENTIFIER) Then Exit;
 SymbolIndex:=FindVisibleSymbol(Pipeline.Tokens[TokenIndex].Text,ScopeIndex);
 If SymbolIndex=0 Then Exit;
 If (SemanticSymbols[SymbolIndex].Kind=SYM_PROCEDURE) And
    Not ((TokenIndex<Pipeline.TokenCount) And
         (Pipeline.Tokens[TokenIndex+1].Kind=TK_SYMBOL) And
         (Pipeline.Tokens[TokenIndex+1].Text='(')) Then Exit;
 TypeIndex:=SemanticSymbols[SymbolIndex].TypeIndex;
 I:=TokenIndex+1;
 While (TypeIndex<>0) And (I<=Pipeline.TokenCount) Do Begin
  TypeIndex:=CanonicalType(TypeIndex);
  Kind:=SemanticTypes[TypeIndex].Kind;
  If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
     (Pipeline.Tokens[I].Text='[') Then Begin
   If Kind<>TYPE_ARRAY Then Break;
   Depth:=1;
   Inc(I);
   While (I<=Pipeline.TokenCount) And (Depth>0) Do Begin
    If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
       (Pipeline.Tokens[I].Text='[') Then Inc(Depth)
    Else If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
            (Pipeline.Tokens[I].Text=']') Then Dec(Depth);
    Inc(I);
   End;
   TypeIndex:=SemanticTypes[TypeIndex].ElementType;
  End
  Else If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
          (Pipeline.Tokens[I].Text='^') Then Begin
   If Kind<>TYPE_REF Then Break;
   TypeIndex:=SemanticTypes[TypeIndex].ElementType;
   Inc(I);
  End
  Else If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
          (Pipeline.Tokens[I].Text='.') And
          (I<Pipeline.TokenCount) And
          (Pipeline.Tokens[I+1].Kind=TK_IDENTIFIER) Then Begin
   If Kind=TYPE_REF Then Begin
    TypeIndex:=CanonicalType(SemanticTypes[TypeIndex].ElementType);
    Kind:=SemanticTypes[TypeIndex].Kind;
   End;
   If (Kind<>TYPE_RECORD) And (Kind<>TYPE_OBJECT) Then Break;
   FieldSymbol:=FindSymbolInScope(Pipeline.Tokens[I+1].Text,
                                  SemanticTypes[TypeIndex].FieldScope);
   If FieldSymbol=0 Then Begin
    TypeIndex:=0;
    Break;
   End;
   TypeIndex:=SemanticSymbols[FieldSymbol].TypeIndex;
   Inc(I,2);
  End
  Else Break;
 End;
 DesignatorTypeAt:=TypeIndex;
End;

Function ExpressionTypeAt(TokenIndex,ScopeIndex:Integer):Integer;
Var
 Tok:TToken;
 SymbolIndex,I,ParenDepth,BracketDepth:Integer;
 U:String;
 ResultType:Integer;
Begin
 ResultType:=0;
 If (TokenIndex<1) Or (TokenIndex>Pipeline.TokenCount) Then Begin
  ExpressionTypeAt:=ResultType;
  Exit;
 End;
 Tok:=Pipeline.Tokens[TokenIndex];
 ResultType:=LiteralType(Tok);
 If (ResultType=0) And (Tok.Kind=TK_IDENTIFIER) Then Begin
  ResultType:=DesignatorTypeAt(TokenIndex,ScopeIndex);
  If ResultType=0 Then Begin
   SymbolIndex:=FindVisibleSymbol(Tok.Text,ScopeIndex);
   If SymbolIndex<>0 Then Begin
    If SemanticSymbols[SymbolIndex].Kind=SYM_PROCEDURE Then Begin
     If (TokenIndex<Pipeline.TokenCount) And
        (Pipeline.Tokens[TokenIndex+1].Kind=TK_SYMBOL) And
        (Pipeline.Tokens[TokenIndex+1].Text='(') Then
      ResultType:=SemanticSymbols[SymbolIndex].TypeIndex;
    End
    Else ResultType:=SemanticSymbols[SymbolIndex].TypeIndex;
   End;
  End;
  If (TokenIndex<Pipeline.TokenCount) And
     (Pipeline.Tokens[TokenIndex+1].Kind=TK_SYMBOL) And
     (Pipeline.Tokens[TokenIndex+1].Text='(') Then Begin
   U:=UpperStr(Tok.Text);
   If (U='ORD') Or (U='TRUNC') Then ResultType:=TypeInteger
   Else If U='FLOAT' Then ResultType:=TypeReal;
  End;
 End;
 If ResultType=0 Then Begin
  ExpressionTypeAt:=ResultType;
  Exit;
 End;
 ParenDepth:=0;
 BracketDepth:=0;
 I:=TokenIndex+1;
 While I<=Pipeline.TokenCount Do Begin
  If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
     (Pipeline.Tokens[I].Text='(') Then Inc(ParenDepth)
  Else If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
          (Pipeline.Tokens[I].Text=')') And (ParenDepth>0) Then Dec(ParenDepth)
  Else If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
          (Pipeline.Tokens[I].Text='[') Then Inc(BracketDepth)
  Else If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
          (Pipeline.Tokens[I].Text=']') And (BracketDepth>0) Then Dec(BracketDepth)
  Else If (ParenDepth=0) And (BracketDepth=0) Then Begin
   If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
      ((Pipeline.Tokens[I].Text='=') Or (Pipeline.Tokens[I].Text='#') Or
       (Pipeline.Tokens[I].Text='<') Or (Pipeline.Tokens[I].Text='<=') Or
       (Pipeline.Tokens[I].Text='>') Or (Pipeline.Tokens[I].Text='>=')) Then Begin
    ExpressionTypeAt:=TypeBoolean;
    Exit;
   End;
   If (Pipeline.Tokens[I].Kind=TK_KEYWORD) And
      ((Pipeline.Tokens[I].Keyword=KW_AND) Or
       (Pipeline.Tokens[I].Keyword=KW_OR)) Then Begin
    ExpressionTypeAt:=TypeBoolean;
    Exit;
   End;
   If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
      (Pipeline.Tokens[I].Text='&') Then Begin
    ExpressionTypeAt:=TypeText;
    Exit;
   End;
   If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
      (Pipeline.Tokens[I].Text=';') Then Begin
    ExpressionTypeAt:=ResultType;
    Exit;
   End;
  End;
  Inc(I);
 End;
 ExpressionTypeAt:=ResultType;
End;

Procedure ValidateSimpleAssignments(UnitScope:Integer);
Var
 I,ScopeIndex,DestSymbol,DestType,SourceType:Integer;
 DestToken,SourceToken:TToken;
Begin
 For I:=1 To Pipeline.TokenCount-2 Do
  If (Pipeline.Tokens[I].Kind=TK_IDENTIFIER) And
     (Pipeline.Tokens[I+1].Kind=TK_SYMBOL) And
     (Pipeline.Tokens[I+1].Text=':=') Then Begin
   DestToken:=Pipeline.Tokens[I];
   SourceToken:=Pipeline.Tokens[I+2];
   ScopeIndex:=ScopeForToken(I,UnitScope);
   DestSymbol:=FindVisibleSymbol(DestToken.Text,ScopeIndex);
   If (DestSymbol<>0) And
      ((SemanticSymbols[DestSymbol].Kind=SYM_VAR) Or
       (SemanticSymbols[DestSymbol].Kind=SYM_PARAM) Or
       (SemanticSymbols[DestSymbol].Kind=SYM_FIELD)) Then Begin
    DestType:=SemanticSymbols[DestSymbol].TypeIndex;
    SourceType:=ExpressionTypeAt(I+2,ScopeIndex);
    If (DestType<>0) And (SourceType<>0) And
       Not TypeCompatible(DestType,SourceType) Then
     SemanticError('affectation incompatible: '+TypeName(SourceType)+
                   ' vers '+TypeName(DestType),
                   SourceToken.Line,SourceToken.Column);
   End;
  End;
End;

Function ConstValueText(V:TConstValue):String;
Var
 S:String;
Begin
 If Not V.Valid Then ConstValueText:='<invalide>'
 Else Case V.Kind Of
  CONST_INTEGER:ConstValueText:=IntToString(V.IntegerVal);
  CONST_REAL:Begin
   Str(V.RealVal:0:8,S);
   ConstValueText:=S;
  End;
  CONST_BOOLEAN:
   If V.IntegerVal<>0 Then ConstValueText:='TRUE'
   Else ConstValueText:='FALSE';
  CONST_CHAR:ConstValueText:='#'+IntToString(V.IntegerVal);
  CONST_TEXT:ConstValueText:='"'+V.TextVal+'"';
  CONST_NIL:ConstValueText:='NIL';
  Else ConstValueText:='<invalide>';
 End;
End;

Procedure TraceSemanticTables;
Var
 I,J:Integer;
 TypeDetail,LayoutDetail:String;
Begin
 WriteLn('Symboles: ',SemanticSymbolCount,' symboles, ',
         SemanticScopeCount,' portees, ',SemanticTypeCount,' types');
 If Not Options.Verbose Then Exit;
 For I:=1 To SemanticScopeCount Do Begin
  WriteLn('Portee ',I,' [',ScopeKindName(SemanticScopes[I].Kind),
          '] ',SemanticScopes[I].OwnerName,
          ', niveau ',SemanticScopes[I].Level,
          ', symboles ',SemanticScopes[I].SymbolCount,
          ', frame ',SemanticScopes[I].FrameSize);
  J:=SemanticScopes[I].FirstSymbol;
  While J<>0 Do Begin
   TypeDetail:='';
   If SemanticSymbols[J].TypeIndex<>0 Then
    TypeDetail:=' : '+TypeName(SemanticSymbols[J].TypeIndex);
   If (SemanticSymbols[J].Kind=SYM_CONST) And
      SemanticSymbols[J].ConstValue.Valid Then
    TypeDetail:=TypeDetail+' = '+
     ConstValueText(SemanticSymbols[J].ConstValue);
   If SemanticSymbols[J].Storage<>STORAGE_NONE Then Begin
    TypeDetail:=TypeDetail+' ['+
     StorageKindName(SemanticSymbols[J].Storage);
    If SemanticSymbols[J].AsmLabel<>'' Then
     TypeDetail:=TypeDetail+' '+SemanticSymbols[J].AsmLabel
    Else TypeDetail:=TypeDetail+' offset '+IntToString(SemanticSymbols[J].Offset);
    TypeDetail:=TypeDetail+', '+IntToString(SemanticSymbols[J].Size)+' octets]';
   End;
   WriteLn('  ',SemanticSymbols[J].Name,' : ',
           SymbolKindName(SemanticSymbols[J].Kind),
           TypeDetail,
           ' @ ',SemanticSymbols[J].Line,':',SemanticSymbols[J].Column);
   J:=SemanticSymbols[J].NextSymbol;
  End;
 End;
 WriteLn('Types:');
 For I:=1 To SemanticTypeCount Do Begin
  LayoutDetail:='';
  If SemanticTypes[I].Kind=TYPE_ARRAY Then Begin
   If SemanticTypes[I].OpenArray Then LayoutDetail:=' ouvert'
   Else LayoutDetail:=' ['+IntToString(SemanticTypes[I].LowBound)+'..'+
                       IntToString(SemanticTypes[I].HighBound)+']';
   LayoutDetail:=LayoutDetail+' OF '+
    TypeName(SemanticTypes[I].ElementType);
  End
  Else If SemanticTypes[I].Kind=TYPE_REF Then
   LayoutDetail:=' TO '+TypeName(SemanticTypes[I].ElementType)
  Else If SemanticTypes[I].FieldScope<>0 Then
   LayoutDetail:=' champs='+
    IntToString(SemanticScopes[SemanticTypes[I].FieldScope].SymbolCount);
  WriteLn('  ',TypeName(I),' [',TypeKindName(SemanticTypes[I].Kind),
          '] taille=',SemanticTypes[I].Size,
          ' align=',SemanticTypes[I].Align,LayoutDetail);
 End;
End;

Function ProcessSemanticUnit(UniverseScope:Integer):Boolean;
Var
 UnitScope,I,ImplSymbol,TemplateScope,J,NewSym:Integer;
 UnitName,EndName,GenName:String;
 UnitToken:TToken;
 GenericUnit,IsInstantiation:Boolean;
 ScopeKind:TScopeKind;
 OrigFlavor:TUnitKind;
Begin
 ProcessSemanticUnit:=False;
 GenericUnit:=SemanticIsKeyword(KW_GENERIC);
 If GenericUnit Then SemanticAdvance;
 If SemanticIsKeyword(KW_INTERFACE) Then Begin
  ScopeKind:=SCOPE_INTERFACE;
  OrigFlavor:=UK_INTERFACE;
 End
 Else Begin
  ScopeKind:=SCOPE_MODULE;
  OrigFlavor:=UK_MODULE;
 End;
 If (SemanticIsKeyword(KW_INTERFACE)) Or (SemanticIsKeyword(KW_MODULE)) Then
  SemanticAdvance;
 If SemanticToken.Kind<>TK_IDENTIFIER Then Begin
  SemanticError('nom d''unite absent pour la table des symboles',
                SemanticToken.Line,SemanticToken.Column);
  Exit;
 End;
 UnitToken:=SemanticToken;
 UnitName:=UnitToken.Text;
 SemanticAdvance;
 (* Instanciation generique : INTERFACE/MODULE Nom = Generique(Params) END Nom. *)
 IsInstantiation:=(Not GenericUnit) And SemanticIsSymbol('=');
 If IsInstantiation Then Begin
  SemanticAdvance;
  If SemanticToken.Kind<>TK_IDENTIFIER Then Begin
   SemanticError('nom de generique attendu apres "="',
                 SemanticToken.Line,SemanticToken.Column);
   Exit;
  End;
  GenName:=SemanticToken.Text;
  SemanticAdvance;
  If SemanticIsSymbol('(') Then Begin
   SemanticAdvance;
   While Not SemanticIsSymbol(')') And (SemanticToken.Kind<>TK_EOF) Do
    SemanticAdvance;
   If SemanticIsSymbol(')') Then SemanticAdvance;
  End;
  TemplateScope:=0;
  For I:=1 To SemanticScopeCount Do
   If (UpperStr(SemanticScopes[I].OwnerName)=UpperStr(GenName)) And
      (SemanticScopes[I].Kind=SCOPE_GENERIC) And
      (SemanticScopes[I].TemplateKind=OrigFlavor) Then Begin
    TemplateScope:=I;
    Break;
   End;
  If TemplateScope=0 Then Begin
   SemanticError('generique inconnu ou incompatible: '+GenName,
                 UnitToken.Line,UnitToken.Column);
   Exit;
  End;
  UnitScope:=NewSemanticScope(ScopeKind,UniverseScope,UnitName,
                              UnitToken.Line,UnitToken.Column);
  If UnitScope=0 Then Exit;
  For J:=1 To SemanticSymbolCount Do
   If (SemanticSymbols[J].ScopeIndex=TemplateScope) And
      (SemanticSymbols[J].Kind<>SYM_GENERIC_PARAM) Then Begin
    AddSemanticSymbol(SemanticSymbols[J].Name,SemanticSymbols[J].Kind,
                      UnitScope,SemanticSymbols[J].Line,SemanticSymbols[J].Column);
    NewSym:=FindSymbolInScope(SemanticSymbols[J].Name,UnitScope);
    If NewSym<>0 Then Begin
     SemanticSymbols[NewSym].TypeIndex:=SemanticSymbols[J].TypeIndex;
     SemanticSymbols[NewSym].AsmLabel:=SemanticSymbols[J].AsmLabel;
     SemanticSymbols[NewSym].ProcScope:=SemanticSymbols[J].ProcScope;
     SemanticSymbols[NewSym].Storage:=SemanticSymbols[J].Storage;
    End;
   End;
  If Not SemanticIsKeyword(KW_END) Then Begin
   SemanticError('END attendu pour fermer l''instanciation '+UnitName,
                 SemanticToken.Line,SemanticToken.Column);
   Exit;
  End;
  SemanticScopes[UnitScope].EndToken:=SemanticIndex;
  SemanticAdvance;
  If SemanticToken.Kind=TK_IDENTIFIER Then Begin
   EndName:=SemanticToken.Text;
   If UpperStr(EndName)<>UpperStr(UnitName) Then
    SemanticError('nom final "'+EndName+'" different de "'+UnitName+'"',
                  SemanticToken.Line,SemanticToken.Column);
   SemanticAdvance;
  End;
  If SemanticIsSymbol('.') Then SemanticAdvance;
  ProcessSemanticUnit:=Pipeline.ErrorCount=0;
  Exit;
 End;
 (* unite normale, ou modele generique (GENERIC INTERFACE/MODULE) *)
 If GenericUnit Then ScopeKind:=SCOPE_GENERIC;
 UnitScope:=NewSemanticScope(ScopeKind,UniverseScope,UnitName,
                             UnitToken.Line,UnitToken.Column);
 If UnitScope=0 Then Exit;
 SemanticScopes[UnitScope].TemplateKind:=OrigFlavor;
 If GenericUnit And SemanticIsSymbol('(') Then Begin
  SemanticAdvance;
  While SemanticToken.Kind=TK_IDENTIFIER Do Begin
   UnitToken:=SemanticToken;
   AddSemanticSymbol(UnitToken.Text,SYM_GENERIC_PARAM,UnitScope,
                     UnitToken.Line,UnitToken.Column);
   SemanticAdvance;
   If SemanticIsSymbol(',') Then SemanticAdvance Else Break;
  End;
  If SemanticIsSymbol(')') Then SemanticAdvance;
 End;
 While Not SemanticIsSymbol(';') And
       (SemanticToken.Kind<>TK_EOF) Do SemanticAdvance;
 If SemanticIsSymbol(';') Then SemanticAdvance;
 ScanImportsIntoScope(UnitScope);
 ScanSemanticDeclarations(UnitScope);
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].Kind=SYM_METHOD) And
     (SemanticSymbols[I].AsmLabel<>'') Then Begin
   ImplSymbol:=FindVisibleSymbol(SemanticSymbols[I].AsmLabel,
                                 SemanticSymbols[I].ScopeIndex);
   If (ImplSymbol=0) Or
      (SemanticSymbols[ImplSymbol].Kind<>SYM_PROCEDURE) Then
    SemanticError('implementation de methode inconnue: '+
                  SemanticSymbols[I].AsmLabel,
                  SemanticSymbols[I].Line,SemanticSymbols[I].Column)
   Else SemanticSymbols[I].MethodImpl:=ImplSymbol;
  End;
 If SemanticIsKeyword(KW_BEGIN) Then Begin
  SemanticAdvance;
  SkipProcedureStatements(UnitScope);
  If SemanticIsKeyword(KW_END) Then SemanticAdvance;
 End
 Else If SemanticIsKeyword(KW_END) Then SemanticAdvance;
 SemanticScopes[UnitScope].EndToken:=SemanticIndex;
 If SemanticToken.Kind=TK_IDENTIFIER Then Begin
  EndName:=SemanticToken.Text;
  If UpperStr(EndName)<>UpperStr(UnitName) Then
   SemanticError('nom final "'+EndName+'" different de "'+UnitName+'"',
                 SemanticToken.Line,SemanticToken.Column);
  SemanticAdvance;
 End;
 If SemanticIsSymbol('.') Then SemanticAdvance;
 LayoutSemanticStorage(UnitScope);
 ProcessSemanticUnit:=Pipeline.ErrorCount=0;
End;

Procedure BuildSemanticTables;
Var
 UniverseScope:Integer;
Begin
 EnterStage(CS_SEMANTIC_TABLES);
 SemanticScopeCount:=0;
 SemanticSymbolCount:=0;
 SemanticTypeCount:=0;
 SemanticIndex:=1;
 UniverseScope:=NewSemanticScope(SCOPE_UNIVERSE,0,'',0,0);
 If UniverseScope=0 Then Exit;
 AddPredefinedTypes(UniverseScope);
 AddPredefinedSymbols(UniverseScope);
 While (SemanticToken.Kind<>TK_EOF) And (Pipeline.ErrorCount=0) Do
  If Not ProcessSemanticUnit(UniverseScope) Then Break;
 If Pipeline.ErrorCount<>0 Then Exit;
 FinishStage(CS_SEMANTIC_TABLES);
 TraceSemanticTables;
End;

Function IRKindName(Kind:TIRKind):String;
Begin
 Case Kind Of
  IR_LITERAL  :IRKindName:='literal';
  IR_SYMBOL   :IRKindName:='symbole';
  IR_CALL     :IRKindName:='appel';
  IR_INDEX    :IRKindName:='index';
  IR_FIELD    :IRKindName:='champ';
  IR_DEREF    :IRKindName:='deref';
  IR_UNARY    :IRKindName:='unaire';
  IR_BINARY   :IRKindName:='binaire';
  IR_COMPARE  :IRKindName:='comparaison';
  IR_AND_SHORT:IRKindName:='and-court';
  IR_OR_SHORT :IRKindName:='or-court';
  Else IRKindName:='invalide';
 End;
End;

Function NewIRNode(AKind:TIRKind;ATypeIndex,ALeft,ARight:Integer;
 AOperatorText,AText:String;LineNo,ColumnNo:Integer):Integer;
Begin
 NewIRNode:=0;
 If IRNodeCount>=MOD3_MAX_IR_NODES Then Begin
  SemanticError('IR d''expressions trop grand',LineNo,ColumnNo);
  Exit;
 End;
 Inc(IRNodeCount);
 With IRNodes[IRNodeCount] Do Begin
  Kind:=AKind;
  TypeIndex:=ATypeIndex;
  Left:=ALeft;
  Right:=ARight;
  SymbolIndex:=0;
  OperatorText:=AOperatorText;
  Text:=AText;
  IntegerVal:=0;
  RealVal:=0;
  Line:=LineNo;
  Column:=ColumnNo;
  TrueLabel:=0;
  FalseLabel:=0;
  FirstArg:=0;
  ArgCount:=0;
  Receiver:=0;
  VirtualSlot:=-1;
 End;
 NewIRNode:=IRNodeCount;
End;

Procedure AddIRRoot(AKind:TIRRootKind;ANodeIndex,AScopeIndex,ATargetType:Integer;
 LineNo,ColumnNo:Integer);
Begin
 If ANodeIndex=0 Then Exit;
 If IRRootCount>=MOD3_MAX_IR_ROOTS Then Begin
  SemanticError('trop d''expressions racines dans l''IR',LineNo,ColumnNo);
  Exit;
 End;
 Inc(IRRootCount);
 With IRRoots[IRRootCount] Do Begin
  Kind:=AKind;
  NodeIndex:=ANodeIndex;
  ScopeIndex:=AScopeIndex;
  TargetType:=ATargetType;
  Line:=LineNo;
  Column:=ColumnNo;
 End;
End;

Function IRToken:TToken;
Begin
 If IRTokenIndex<1 Then IRTokenIndex:=1;
 If IRTokenIndex>Pipeline.TokenCount Then
  IRToken:=Pipeline.Tokens[Pipeline.TokenCount]
 Else IRToken:=Pipeline.Tokens[IRTokenIndex];
End;

Procedure IRAdvance;
Begin
 If IRTokenIndex<Pipeline.TokenCount Then Inc(IRTokenIndex);
End;

Function IRIsSymbol(S:String):Boolean;
Begin
 IRIsSymbol:=(IRToken.Kind=TK_SYMBOL) And (IRToken.Text=S);
End;

Function IRIsKeyword(K:TKeyword):Boolean;
Begin
 IRIsKeyword:=(IRToken.Kind=TK_KEYWORD) And (IRToken.Keyword=K);
End;

Function IRExpressionStop:Boolean;
Begin
 IRExpressionStop:=(IRToken.Kind=TK_EOF) Or IRIsSymbol(';') Or
  IRIsSymbol(',') Or IRIsSymbol(')') Or IRIsSymbol(']') Or
  IRIsKeyword(KW_THEN) Or IRIsKeyword(KW_DO) Or IRIsKeyword(KW_TO) Or
  IRIsKeyword(KW_BY) Or IRIsKeyword(KW_ELSE) Or IRIsKeyword(KW_ELSIF) Or
  IRIsKeyword(KW_END) Or IRIsKeyword(KW_UNTIL);
End;

Function IRNumericResult(LeftType,RightType:Integer;ForceReal:Boolean):Integer;
Var
 LK,RK:TTypeKind;
Begin
 LeftType:=CanonicalType(LeftType);
 RightType:=CanonicalType(RightType);
 If (LeftType=0) Or (RightType=0) Then Begin
  IRNumericResult:=0;
  Exit;
 End;
 LK:=SemanticTypes[LeftType].Kind;
 RK:=SemanticTypes[RightType].Kind;
 If (LK=TYPE_LONGREAL) Or (RK=TYPE_LONGREAL) Then
  IRNumericResult:=TypeLongReal
 Else If ForceReal Or (LK=TYPE_REAL) Or (RK=TYPE_REAL) Then
  IRNumericResult:=TypeReal
 Else If (LK=TYPE_CARDINAL) And (RK=TYPE_CARDINAL) Then
  IRNumericResult:=TypeCardinal
 Else IRNumericResult:=TypeInteger;
End;

Function ParseIRExpression:Boolean; Forward;
Function ParseIROr(Var NodeIndex:Integer):Boolean; Forward;

Function BuiltinReturnType(Name:String):Integer;
Begin
 Name:=UpperStr(Name);
 If (Name='ORD') Or (Name='TRUNC') Or (Name='ABS') Or
    (Name='MAX') Or (Name='MIN') Or (Name='FIRST') Or
    (Name='LAST') Or (Name='NUMBER') Or (Name='BITSIZE') Then
  BuiltinReturnType:=TypeInteger
 Else If Name='FLOAT' Then BuiltinReturnType:=TypeReal
 Else If Name='ISTYPE' Then BuiltinReturnType:=TypeBoolean
 Else If Name='TYPECODE' Then BuiltinReturnType:=TypeInteger
 Else BuiltinReturnType:=0;
End;

Function IsIRDesignator(NodeIndex:Integer):Boolean;
Begin
 IsIRDesignator:=(NodeIndex>0) And (NodeIndex<=IRNodeCount) And
  (IRNodes[NodeIndex].Kind In [IR_SYMBOL,IR_INDEX,IR_FIELD,IR_DEREF]);
End;

Function IsIRWritableDesignator(NodeIndex:Integer):Boolean;
Var
 SymbolIndex:Integer;
 Writable:Boolean;
Begin
 Writable:=IsIRDesignator(NodeIndex);
 If Writable And (IRNodes[NodeIndex].Kind=IR_SYMBOL) Then Begin
  SymbolIndex:=IRNodes[NodeIndex].SymbolIndex;
  If (SymbolIndex=0) Or
     Not (SemanticSymbols[SymbolIndex].Kind In [SYM_VAR,SYM_PARAM]) Then
   Writable:=False
  Else If (SemanticSymbols[SymbolIndex].Kind=SYM_PARAM) And
          (SemanticSymbols[SymbolIndex].ParamMode=PARAM_READONLY) Then
   Writable:=False;
 End;
 IsIRWritableDesignator:=Writable;
End;

Procedure AttachCallArguments(CallNode:Integer;Var Args:TIRArgumentList;
 ArgCount:Integer);
Var
 I:Integer;
Begin
 If (CallNode=0) Or (ArgCount=0) Then Exit;
 If IRArgumentCount+ArgCount>MOD3_MAX_IR_ARGUMENTS Then Begin
  SemanticError('trop d''arguments dans l''IR',
                IRNodes[CallNode].Line,IRNodes[CallNode].Column);
  Exit;
 End;
 IRNodes[CallNode].FirstArg:=IRArgumentCount+1;
 IRNodes[CallNode].ArgCount:=ArgCount;
 For I:=0 To ArgCount-1 Do Begin
  Inc(IRArgumentCount);
  IRArguments[IRArgumentCount]:=Args[I];
 End;
End;

Procedure ValidateProcedureCall(CallNode,ProcedureSymbol:Integer);
Var
 ScopeIndex,FormalIndex,ActualIndex,FormalCount,I:Integer;
Begin
 If (ProcedureSymbol<1) Or (ProcedureSymbol>SemanticSymbolCount) Then Exit;
 If SemanticSymbols[ProcedureSymbol].Kind<>SYM_PROCEDURE Then Exit;
 ScopeIndex:=SemanticSymbols[ProcedureSymbol].ProcScope;
 If ScopeIndex=0 Then Exit;
 FormalCount:=0;
 For I:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[I].ScopeIndex=ScopeIndex) And
     (SemanticSymbols[I].Kind=SYM_PARAM) Then Inc(FormalCount);
 If IRNodes[CallNode].ArgCount<>FormalCount Then Begin
  SemanticError('appel de '+SemanticSymbols[ProcedureSymbol].Name+': '+
   IntToString(FormalCount)+' argument(s) attendu(s), '+
   IntToString(IRNodes[CallNode].ArgCount)+' recu(s)',
   IRNodes[CallNode].Line,IRNodes[CallNode].Column);
  Exit;
 End;
 ActualIndex:=0;
 For FormalIndex:=1 To SemanticSymbolCount Do
  If (SemanticSymbols[FormalIndex].ScopeIndex=ScopeIndex) And
     (SemanticSymbols[FormalIndex].Kind=SYM_PARAM) Then Begin
   Inc(ActualIndex);
   I:=IRArguments[IRNodes[CallNode].FirstArg+ActualIndex-1];
   If (SemanticSymbols[FormalIndex].ParamMode=PARAM_VAR) And
      Not IsIRWritableDesignator(I) Then
    SemanticError('le parametre VAR '+SemanticSymbols[FormalIndex].Name+
                  ' exige une variable',IRNodes[I].Line,IRNodes[I].Column)
   Else If (IRNodes[I].TypeIndex<>0) And
           Not TypeCompatible(SemanticSymbols[FormalIndex].TypeIndex,
                              IRNodes[I].TypeIndex) Then
    SemanticError('type incompatible pour le parametre '+
     SemanticSymbols[FormalIndex].Name+' de '+
     SemanticSymbols[ProcedureSymbol].Name,
     IRNodes[I].Line,IRNodes[I].Column);
  End;
End;

Function ParseIRPrimary(Var NodeIndex:Integer):Boolean;
Var
 Tok,NameTok:TToken;
 SymbolIndex,TypeIndex,BaseNode,SelectorNode,ArgNode,FieldSymbol:Integer;
 Args:TIRArgumentList;
 ArgCount:Integer;
 Name:String;
 Kind:TTypeKind;
Begin
 ParseIRPrimary:=False;
 NodeIndex:=0;
 Tok:=IRToken;
 Case Tok.Kind Of
  TK_INTEGER,TK_REAL,TK_STRING,TK_CHAR:Begin
   TypeIndex:=LiteralType(Tok);
   NodeIndex:=NewIRNode(IR_LITERAL,TypeIndex,0,0,'',Tok.Text,
                        Tok.Line,Tok.Column);
   If Tok.Kind=TK_INTEGER Then IRNodes[NodeIndex].IntegerVal:=Tok.IntegerVal
   Else If Tok.Kind=TK_REAL Then IRNodes[NodeIndex].RealVal:=Tok.RealVal
   Else If Tok.Kind=TK_CHAR Then IRNodes[NodeIndex].IntegerVal:=Tok.IntegerVal;
   IRAdvance;
   ParseIRPrimary:=True;
  End;
  TK_IDENTIFIER:Begin
   NameTok:=Tok;
   Name:=Tok.Text;
   SymbolIndex:=FindVisibleSymbol(Name,IRCurrentScope);
   TypeIndex:=LiteralType(Tok);
   IRAdvance;
   If IRIsSymbol('.') And (IRTokenIndex+2<=Pipeline.TokenCount) And
      (Pipeline.Tokens[IRTokenIndex+1].Kind=TK_IDENTIFIER) And
      (Pipeline.Tokens[IRTokenIndex+2].Kind=TK_SYMBOL) And
      (Pipeline.Tokens[IRTokenIndex+2].Text='(') And
      ((SymbolIndex=0) Or
       (SemanticSymbols[SymbolIndex].Kind=SYM_IMPORT)) Then Begin
    IRAdvance;
    If IRToken.Kind=TK_IDENTIFIER Then Begin
     Name:=Name+'.'+IRToken.Text;
     IRAdvance;
    End;
   End;
   If IRIsSymbol('(') Then Begin
    If SymbolIndex<>0 Then TypeIndex:=SemanticSymbols[SymbolIndex].TypeIndex;
    If TypeIndex=0 Then TypeIndex:=BuiltinReturnType(NameTok.Text);
   NodeIndex:=NewIRNode(IR_CALL,TypeIndex,0,0,'',Name,
                         NameTok.Line,NameTok.Column);
    IRNodes[NodeIndex].SymbolIndex:=SymbolIndex;
    ArgCount:=0;
    IRAdvance;
    If Not IRIsSymbol(')') Then Begin
     If Not ParseIROr(ArgNode) Then Exit;
     If ArgCount<64 Then Begin Args[ArgCount]:=ArgNode; Inc(ArgCount); End;
     While IRIsSymbol(',') Do Begin
      IRAdvance;
      If Not ParseIROr(ArgNode) Then Exit;
      If ArgCount<64 Then Begin Args[ArgCount]:=ArgNode; Inc(ArgCount); End;
     End;
    End;
    If IRIsSymbol(')') Then IRAdvance
    Else Begin
     SemanticError('parenthese fermante attendue dans l''appel',
                   IRToken.Line,IRToken.Column);
     Exit;
    End;
    AttachCallArguments(NodeIndex,Args,ArgCount);
    If ArgCount>0 Then Begin
     IRNodes[NodeIndex].Left:=Args[0];
     IRNodes[NodeIndex].Right:=Args[ArgCount-1];
    End;
    Name:=UpperStr(NameTok.Text);
    If ((Name='NEW') Or (Name='NARROW')) And (ArgCount>0) And
       (IRNodes[Args[ArgCount-1]].Kind=IR_SYMBOL) And
       (IRNodes[Args[ArgCount-1]].SymbolIndex<>0) And
       (SemanticSymbols[IRNodes[Args[ArgCount-1]].SymbolIndex].Kind=SYM_TYPE) Then
     IRNodes[NodeIndex].TypeIndex:=
      SemanticSymbols[IRNodes[Args[ArgCount-1]].SymbolIndex].TypeIndex;
    If (Name='ISTYPE') And (ArgCount=2) Then
     IRNodes[NodeIndex].TypeIndex:=TypeBoolean;
    If (Name='TYPECODE') And (ArgCount=1) Then
     IRNodes[NodeIndex].TypeIndex:=TypeInteger;
   End
   Else Begin
    If SymbolIndex=0 Then Begin
     SemanticError('identificateur inconnu dans l''expression: '+Name,
                   NameTok.Line,NameTok.Column);
     TypeIndex:=0;
    End
    Else If SemanticSymbols[SymbolIndex].Kind=SYM_PROCEDURE Then
     TypeIndex:=0
    Else TypeIndex:=SemanticSymbols[SymbolIndex].TypeIndex;
    NodeIndex:=NewIRNode(IR_SYMBOL,TypeIndex,0,0,'',Name,
                         NameTok.Line,NameTok.Column);
    IRNodes[NodeIndex].SymbolIndex:=SymbolIndex;
   End;
   BaseNode:=NodeIndex;
   While (NodeIndex<>0) And
         (IRIsSymbol('[') Or IRIsSymbol('^') Or IRIsSymbol('.')) Do Begin
    TypeIndex:=CanonicalType(IRNodes[NodeIndex].TypeIndex);
    If IRIsSymbol('[') Then Begin
     IRAdvance;
     If Not ParseIROr(SelectorNode) Then Exit;
     If Not IRIsSymbol(']') Then Begin
      SemanticError('crochet fermant attendu',IRToken.Line,IRToken.Column);
      Exit;
     End;
     IRAdvance;
     If (TypeIndex=0) Or
        (SemanticTypes[TypeIndex].Kind<>TYPE_ARRAY) Then Begin
      SemanticError('indexation d''une valeur non ARRAY',
                    NameTok.Line,NameTok.Column);
      TypeIndex:=0;
     End
     Else TypeIndex:=SemanticTypes[TypeIndex].ElementType;
     NodeIndex:=NewIRNode(IR_INDEX,TypeIndex,NodeIndex,SelectorNode,'[]','',
                          NameTok.Line,NameTok.Column);
    End
    Else If IRIsSymbol('^') Then Begin
     IRAdvance;
     If (TypeIndex=0) Or (SemanticTypes[TypeIndex].Kind<>TYPE_REF) Then Begin
      SemanticError('dereferencement d''une valeur non REF',
                    NameTok.Line,NameTok.Column);
      TypeIndex:=0;
     End
     Else TypeIndex:=SemanticTypes[TypeIndex].ElementType;
     NodeIndex:=NewIRNode(IR_DEREF,TypeIndex,NodeIndex,0,'^','',
                          NameTok.Line,NameTok.Column);
    End
    Else Begin
     IRAdvance;
     If IRToken.Kind<>TK_IDENTIFIER Then Exit;
     Tok:=IRToken;
     IRAdvance;
     If (IRNodes[NodeIndex].Kind=IR_SYMBOL) And
        (UpperStr(IRNodes[NodeIndex].Text)='STDIO') And
        ((UpperStr(Tok.Text)='STDOUT') Or (UpperStr(Tok.Text)='STDERR') Or
         (UpperStr(Tok.Text)='STDIN')) Then Begin
      NodeIndex:=NewIRNode(IR_LITERAL,TypeInteger,0,0,'',Tok.Text,
                           Tok.Line,Tok.Column);
      If UpperStr(Tok.Text)='STDOUT' Then IRNodes[NodeIndex].IntegerVal:=1
      Else If UpperStr(Tok.Text)='STDERR' Then IRNodes[NodeIndex].IntegerVal:=2
      Else IRNodes[NodeIndex].IntegerVal:=0;
      Continue;
     End;
     FieldSymbol:=0;
     If TypeIndex<>0 Then Begin
      Kind:=SemanticTypes[TypeIndex].Kind;
      If Kind=TYPE_REF Then Begin
       TypeIndex:=SemanticTypes[TypeIndex].ElementType;
       If TypeIndex<>0 Then Kind:=SemanticTypes[TypeIndex].Kind;
      End;
      If Kind=TYPE_RECORD Then
       FieldSymbol:=FindSymbolInScope(Tok.Text,
        SemanticTypes[TypeIndex].FieldScope)
      Else If Kind=TYPE_OBJECT Then
       FieldSymbol:=FindObjectMember(TypeIndex,Tok.Text);
     End;
     If FieldSymbol=0 Then Begin
      If (IRNodes[NodeIndex].Kind=IR_SYMBOL) And
         (IRNodes[NodeIndex].SymbolIndex<>0) And
         (SemanticSymbols[IRNodes[NodeIndex].SymbolIndex].Kind=SYM_TYPE) Then
       FieldSymbol:=-1
      Else Begin
       SemanticError('champ inconnu: '+Tok.Text,Tok.Line,Tok.Column);
       TypeIndex:=0;
      End;
     End
     Else TypeIndex:=SemanticSymbols[FieldSymbol].TypeIndex;
     BaseNode:=NodeIndex;
     If (FieldSymbol>0) And
        (SemanticSymbols[FieldSymbol].Kind=SYM_METHOD) And
        IRIsSymbol('(') Then Begin
      NodeIndex:=NewIRNode(IR_CALL,TypeIndex,0,0,'',Tok.Text,
                           Tok.Line,Tok.Column);
      IRNodes[NodeIndex].SymbolIndex:=FieldSymbol;
      IRNodes[NodeIndex].Receiver:=BaseNode;
      IRNodes[NodeIndex].VirtualSlot:=SemanticSymbols[FieldSymbol].Offset;
      ArgCount:=0;
      IRAdvance;
      If Not IRIsSymbol(')') Then Begin
       If Not ParseIROr(ArgNode) Then Exit;
       If ArgCount<64 Then Begin Args[ArgCount]:=ArgNode; Inc(ArgCount); End;
       While IRIsSymbol(',') Do Begin
        IRAdvance;
        If Not ParseIROr(ArgNode) Then Exit;
        If ArgCount<64 Then Begin Args[ArgCount]:=ArgNode; Inc(ArgCount); End;
       End;
      End;
      If IRIsSymbol(')') Then IRAdvance
      Else SemanticError('parenthese fermante attendue dans l''appel de methode',
                         IRToken.Line,IRToken.Column);
      AttachCallArguments(NodeIndex,Args,ArgCount);
     End
     Else Begin
      NodeIndex:=NewIRNode(IR_FIELD,TypeIndex,NodeIndex,0,'.',Tok.Text,
                           Tok.Line,Tok.Column);
      If FieldSymbol>0 Then IRNodes[NodeIndex].SymbolIndex:=FieldSymbol;
     End;
    End;
   End;
   ParseIRPrimary:=BaseNode<>0;
  End;
  TK_SYMBOL:Begin
   If Tok.Text='(' Then Begin
    IRAdvance;
    If Not ParseIROr(NodeIndex) Then Exit;
    If IRIsSymbol(')') Then IRAdvance
    Else Begin
     SemanticError('parenthese fermante attendue',
                   IRToken.Line,IRToken.Column);
     Exit;
    End;
    ParseIRPrimary:=True;
   End;
  End;
 End;
End;

Function ParseIRUnary(Var NodeIndex:Integer):Boolean;
Var
 Tok:TToken;
 Operand,ResultType:Integer;
 Op:String;
Begin
 Tok:=IRToken;
 If IRIsSymbol('+') Or IRIsSymbol('-') Or IRIsKeyword(KW_NOT) Then Begin
  If IRIsKeyword(KW_NOT) Then Op:='NOT' Else Op:=Tok.Text;
  IRAdvance;
  If Not ParseIRUnary(Operand) Then Begin
   ParseIRUnary:=False;
   Exit;
  End;
  ResultType:=IRNodes[Operand].TypeIndex;
  If Op='NOT' Then Begin
   If CanonicalType(ResultType)<>CanonicalType(TypeBoolean) Then
    SemanticError('NOT exige une expression BOOLEAN',Tok.Line,Tok.Column);
   ResultType:=TypeBoolean;
  End
  Else If Not TypeIsNumeric(ResultType) Then
   SemanticError('operateur unaire '+Op+' exige une expression numerique',
                 Tok.Line,Tok.Column);
  NodeIndex:=NewIRNode(IR_UNARY,ResultType,Operand,0,Op,'',
                       Tok.Line,Tok.Column);
  ParseIRUnary:=NodeIndex<>0;
 End
 Else ParseIRUnary:=ParseIRPrimary(NodeIndex);
End;

Function ParseIRProduct(Var NodeIndex:Integer):Boolean;
Var
 Left,Right,ResultType:Integer;
 Tok:TToken;
 Op:String;
Begin
 If Not ParseIRUnary(Left) Then Begin ParseIRProduct:=False; Exit; End;
 While IRIsSymbol('*') Or IRIsSymbol('/') Or
       IRIsKeyword(KW_DIV) Or IRIsKeyword(KW_MOD) Do Begin
  Tok:=IRToken;
  If Tok.Kind=TK_KEYWORD Then Op:=KeywordName(Tok.Keyword) Else Op:=Tok.Text;
  IRAdvance;
  If Not ParseIRUnary(Right) Then Begin ParseIRProduct:=False; Exit; End;
  If Not TypeIsNumeric(IRNodes[Left].TypeIndex) Or
     Not TypeIsNumeric(IRNodes[Right].TypeIndex) Then
   SemanticError(Op+' exige deux operandes numeriques',Tok.Line,Tok.Column);
  If ((Op='DIV') Or (Op='MOD')) And
     (Not TypeIsInteger(IRNodes[Left].TypeIndex) Or
      Not TypeIsInteger(IRNodes[Right].TypeIndex)) Then
   SemanticError(Op+' exige deux operandes entiers',Tok.Line,Tok.Column);
  ResultType:=IRNumericResult(IRNodes[Left].TypeIndex,
                              IRNodes[Right].TypeIndex,Op='/');
  Left:=NewIRNode(IR_BINARY,ResultType,Left,Right,Op,'',
                  Tok.Line,Tok.Column);
 End;
 NodeIndex:=Left;
 ParseIRProduct:=True;
End;

Function ParseIRSum(Var NodeIndex:Integer):Boolean;
Var
 Left,Right,ResultType:Integer;
 Tok:TToken;
 Op:String;
Begin
 If Not ParseIRProduct(Left) Then Begin ParseIRSum:=False; Exit; End;
 While IRIsSymbol('+') Or IRIsSymbol('-') Or IRIsSymbol('&') Do Begin
  Tok:=IRToken;
  Op:=Tok.Text;
  IRAdvance;
  If Not ParseIRProduct(Right) Then Begin ParseIRSum:=False; Exit; End;
  If Op='&' Then Begin
   If (CanonicalType(IRNodes[Left].TypeIndex)<>CanonicalType(TypeText)) Or
      (CanonicalType(IRNodes[Right].TypeIndex)<>CanonicalType(TypeText)) Then
    SemanticError('& exige deux operandes TEXT',Tok.Line,Tok.Column);
   ResultType:=TypeText;
  End
  Else Begin
   If Not TypeIsNumeric(IRNodes[Left].TypeIndex) Or
      Not TypeIsNumeric(IRNodes[Right].TypeIndex) Then
    SemanticError(Op+' exige deux operandes numeriques',Tok.Line,Tok.Column);
   ResultType:=IRNumericResult(IRNodes[Left].TypeIndex,
                               IRNodes[Right].TypeIndex,False);
  End;
  Left:=NewIRNode(IR_BINARY,ResultType,Left,Right,Op,'',
                  Tok.Line,Tok.Column);
 End;
 NodeIndex:=Left;
 ParseIRSum:=True;
End;

Function ParseIRCompare(Var NodeIndex:Integer):Boolean;
Var
 Left,Right:Integer;
 Tok:TToken;
 Op:String;
Begin
 If Not ParseIRSum(Left) Then Begin ParseIRCompare:=False; Exit; End;
 If IRIsSymbol('=') Or IRIsSymbol('#') Or IRIsSymbol('<') Or
    IRIsSymbol('<=') Or IRIsSymbol('>') Or IRIsSymbol('>=') Or
    IRIsKeyword(KW_IN) Then Begin
  Tok:=IRToken;
  If Tok.Kind=TK_KEYWORD Then Op:=KeywordName(Tok.Keyword) Else Op:=Tok.Text;
  IRAdvance;
  If Not ParseIRSum(Right) Then Begin ParseIRCompare:=False; Exit; End;
  If (Op<>'IN') And
     Not TypeCompatible(IRNodes[Left].TypeIndex,IRNodes[Right].TypeIndex) And
     Not TypeCompatible(IRNodes[Right].TypeIndex,IRNodes[Left].TypeIndex) Then
   SemanticError('operandes incompatibles pour '+Op,Tok.Line,Tok.Column);
  Left:=NewIRNode(IR_COMPARE,TypeBoolean,Left,Right,Op,'',
                  Tok.Line,Tok.Column);
 End;
 NodeIndex:=Left;
 ParseIRCompare:=True;
End;

Function ParseIRAnd(Var NodeIndex:Integer):Boolean;
Var
 Left,Right,LabelFalse:Integer;
 Tok:TToken;
Begin
 If Not ParseIRCompare(Left) Then Begin ParseIRAnd:=False; Exit; End;
 While IRIsKeyword(KW_AND) Do Begin
  Tok:=IRToken;
  IRAdvance;
  If Not ParseIRCompare(Right) Then Begin ParseIRAnd:=False; Exit; End;
  If (CanonicalType(IRNodes[Left].TypeIndex)<>CanonicalType(TypeBoolean)) Or
     (CanonicalType(IRNodes[Right].TypeIndex)<>CanonicalType(TypeBoolean)) Then
   SemanticError('AND exige deux operandes BOOLEAN',Tok.Line,Tok.Column);
  Inc(IRLabelCounter);
  LabelFalse:=IRLabelCounter;
  Left:=NewIRNode(IR_AND_SHORT,TypeBoolean,Left,Right,'AND','',
                  Tok.Line,Tok.Column);
  IRNodes[Left].FalseLabel:=LabelFalse;
 End;
 NodeIndex:=Left;
 ParseIRAnd:=True;
End;

Function ParseIROr(Var NodeIndex:Integer):Boolean;
Var
 Left,Right,LabelTrue:Integer;
 Tok:TToken;
Begin
 If Not ParseIRAnd(Left) Then Begin ParseIROr:=False; Exit; End;
 While IRIsKeyword(KW_OR) Do Begin
  Tok:=IRToken;
  IRAdvance;
  If Not ParseIRAnd(Right) Then Begin ParseIROr:=False; Exit; End;
  If (CanonicalType(IRNodes[Left].TypeIndex)<>CanonicalType(TypeBoolean)) Or
     (CanonicalType(IRNodes[Right].TypeIndex)<>CanonicalType(TypeBoolean)) Then
   SemanticError('OR exige deux operandes BOOLEAN',Tok.Line,Tok.Column);
  Inc(IRLabelCounter);
  LabelTrue:=IRLabelCounter;
  Left:=NewIRNode(IR_OR_SHORT,TypeBoolean,Left,Right,'OR','',
                  Tok.Line,Tok.Column);
  IRNodes[Left].TrueLabel:=LabelTrue;
 End;
 NodeIndex:=Left;
 ParseIROr:=True;
End;

Function ParseIRExpression:Boolean;
Var
 NodeIndex:Integer;
Begin
 ParseIRExpression:=ParseIROr(NodeIndex);
End;

Function FindAssignmentTarget(TokenIndex,ScopeIndex:Integer):Integer;
Var
 I,StartIndex:Integer;
Begin
 FindAssignmentTarget:=0;
 StartIndex:=TokenIndex-1;
 While StartIndex>1 Do Begin
  If (Pipeline.Tokens[StartIndex-1].Kind=TK_SYMBOL) And
     (Pipeline.Tokens[StartIndex-1].Text=';') Then Break;
  If (Pipeline.Tokens[StartIndex-1].Kind=TK_KEYWORD) And
     ((Pipeline.Tokens[StartIndex-1].Keyword=KW_BEGIN) Or
      (Pipeline.Tokens[StartIndex-1].Keyword=KW_DO) Or
      (Pipeline.Tokens[StartIndex-1].Keyword=KW_THEN) Or
      (Pipeline.Tokens[StartIndex-1].Keyword=KW_ELSE)) Then Break;
  Dec(StartIndex);
 End;
 For I:=StartIndex To TokenIndex-1 Do
  If Pipeline.Tokens[I].Kind=TK_IDENTIFIER Then Begin
   FindAssignmentTarget:=DesignatorTypeAt(I,ScopeIndex);
   Exit;
  End;
End;

Function ProcedureReturnType(ScopeIndex:Integer):Integer;
Var
 ParentScope,SymbolIndex:Integer;
Begin
 ProcedureReturnType:=0;
 If (ScopeIndex<1) Or (ScopeIndex>SemanticScopeCount) Then Exit;
 If SemanticScopes[ScopeIndex].Kind<>SCOPE_PROCEDURE Then Exit;
 ParentScope:=SemanticScopes[ScopeIndex].Parent;
 SymbolIndex:=FindSymbolInScope(SemanticScopes[ScopeIndex].OwnerName,
                                ParentScope);
 If (SymbolIndex<>0) And
    (SemanticSymbols[SymbolIndex].Kind=SYM_PROCEDURE) Then
  ProcedureReturnType:=SemanticSymbols[SymbolIndex].TypeIndex;
End;

Function StatementKindName(Kind:TStatementKind):String;
Begin
 Case Kind Of
  ST_EMPTY      :StatementKindName:='vide';
  ST_ASSIGN     :StatementKindName:='affectation';
  ST_CALL       :StatementKindName:='appel';
  ST_BLOCK_BEGIN:StatementKindName:='debut-bloc';
  ST_BLOCK_END  :StatementKindName:='fin-bloc';
  ST_IF         :StatementKindName:='if';
  ST_ELSIF      :StatementKindName:='elsif';
  ST_ELSE       :StatementKindName:='else';
  ST_CASE       :StatementKindName:='case';
  ST_CASE_ARM   :StatementKindName:='branche-case';
  ST_CASE_ELSE  :StatementKindName:='else-case';
  ST_RETURN     :StatementKindName:='return';
  ST_WHILE      :StatementKindName:='while';
  ST_FOR        :StatementKindName:='for';
  ST_LOOP       :StatementKindName:='loop';
  ST_REPEAT     :StatementKindName:='repeat';
  ST_UNTIL      :StatementKindName:='until';
  ST_EXIT       :StatementKindName:='exit';
  Else StatementKindName:='inconnue';
 End;
End;

Function NewStatementIR(AKind:TStatementKind;AScopeIndex,AExpressionNode,
 ATargetNode,AParentIndex:Integer;LineNo,ColumnNo:Integer):Integer;
Begin
 NewStatementIR:=0;
 If StatementCount>=MOD3_MAX_STATEMENTS Then Begin
  SemanticError('trop d''instructions dans l''IR',LineNo,ColumnNo);
  Exit;
 End;
 Inc(StatementCount);
 With StatementIR[StatementCount] Do Begin
  Kind:=AKind;
  ScopeIndex:=AScopeIndex;
  ExpressionNode:=AExpressionNode;
  BoundNode:=0;
  StepNode:=0;
  TargetNode:=ATargetNode;
  ParentIndex:=AParentIndex;
  StartLabel:=0;
  FalseLabel:=0;
  ContinueLabel:=0;
  EndLabel:=0;
  CaseLow:=0;
  CaseHigh:=0;
  HasCaseRange:=False;
  Line:=LineNo;
  Column:=ColumnNo;
 End;
 NewStatementIR:=StatementCount;
End;

Function TokenStartsStatement(Index:Integer):Boolean;
Var
 Prev:TToken;
Begin
 If Index<=1 Then Begin TokenStartsStatement:=True; Exit; End;
 Prev:=Pipeline.Tokens[Index-1];
 TokenStartsStatement:=
  ((Prev.Kind=TK_SYMBOL) And
   ((Prev.Text=';') Or (Prev.Text='=>') Or (Prev.Text='|'))) Or
  ((Prev.Kind=TK_KEYWORD) And
   ((Prev.Keyword=KW_BEGIN) Or (Prev.Keyword=KW_THEN) Or
    (Prev.Keyword=KW_ELSE) Or (Prev.Keyword=KW_DO) Or
    (Prev.Keyword=KW_LOOP) Or (Prev.Keyword=KW_REPEAT)));
End;

Function ParseIRAt(StartIndex,ScopeIndex:Integer;Var EndIndex:Integer):Integer;
Var
 RootNode:Integer;
Begin
 IRTokenIndex:=StartIndex;
 IRCurrentScope:=ScopeIndex;
 RootNode:=0;
 If Not IRExpressionStop Then ParseIROr(RootNode);
 EndIndex:=IRTokenIndex;
 ParseIRAt:=RootNode;
End;

Function FindDesignatorStart(AssignIndex:Integer):Integer;
Var
 I:Integer;
Begin
 FindDesignatorStart:=0;
 I:=AssignIndex-1;
 While I>=1 Do Begin
  If Pipeline.Tokens[I].Kind=TK_IDENTIFIER Then
   FindDesignatorStart:=I;
  If (Pipeline.Tokens[I].Kind=TK_SYMBOL) And
     ((Pipeline.Tokens[I].Text=';') Or (Pipeline.Tokens[I].Text='=>') Or
      (Pipeline.Tokens[I].Text='|')) Then Break;
  If (Pipeline.Tokens[I].Kind=TK_KEYWORD) And
     ((Pipeline.Tokens[I].Keyword=KW_BEGIN) Or
      (Pipeline.Tokens[I].Keyword=KW_THEN) Or
      (Pipeline.Tokens[I].Keyword=KW_ELSE) Or
      (Pipeline.Tokens[I].Keyword=KW_DO)) Then Break;
  Dec(I);
 End;
End;

Function IsObjectOverrideAssignment(AssignIndex:Integer):Boolean;
Var
 I:Integer;
Begin
 IsObjectOverrideAssignment:=False;
 I:=AssignIndex-1;
 While I>=1 Do Begin
  If (Pipeline.Tokens[I].Kind=TK_KEYWORD) Then Begin
   If Pipeline.Tokens[I].Keyword=KW_OVERRIDES Then Begin
    IsObjectOverrideAssignment:=True;
    Exit;
   End;
   If (Pipeline.Tokens[I].Keyword=KW_BEGIN) Or
      (Pipeline.Tokens[I].Keyword=KW_END) Or
      (Pipeline.Tokens[I].Keyword=KW_TYPE) Then Exit;
  End;
  Dec(I);
 End;
End;

Function BuildTargetNode(StartIndex,AssignIndex,ScopeIndex:Integer):Integer;
Var
 SavedIndex,EndIndex:Integer;
Begin
 SavedIndex:=IRTokenIndex;
 BuildTargetNode:=ParseIRAt(StartIndex,ScopeIndex,EndIndex);
 IRTokenIndex:=SavedIndex;
 If EndIndex<>AssignIndex Then BuildTargetNode:=0;
End;

Function CaseLiteralAt(Index:Integer;Var Value:LongInt;
 Var ValueType:Integer):Boolean;
Var
 Tok:TToken;
 SymbolIndex:Integer;
 V:TConstValue;
Begin
 CaseLiteralAt:=False;
 Tok:=Pipeline.Tokens[Index];
 V:=InvalidConst;
 If Tok.Kind=TK_INTEGER Then V:=IntegerConst(Tok.IntegerVal)
 Else If Tok.Kind=TK_CHAR Then V:=CharConst(Chr(Tok.IntegerVal))
 Else If Tok.Kind=TK_IDENTIFIER Then Begin
  SymbolIndex:=FindVisibleSymbol(Tok.Text,ScopeForToken(Index,2));
  If (SymbolIndex<>0) And (SemanticSymbols[SymbolIndex].Kind=SYM_CONST) Then
   V:=SemanticSymbols[SymbolIndex].ConstValue;
 End;
 If V.Valid And ((V.Kind=CONST_INTEGER) Or (V.Kind=CONST_CHAR)) Then Begin
  Value:=V.IntegerVal;
  ValueType:=V.TypeIndex;
  CaseLiteralAt:=True;
 End;
End;

Function IsLoopStatement(Kind:TStatementKind):Boolean;
Begin
 IsLoopStatement:=Kind In [ST_WHILE,ST_FOR,ST_LOOP,ST_REPEAT];
End;

Function ConstantIntegerNode(NodeIndex:Integer;Var Value:LongInt):Boolean;
Begin
 ConstantIntegerNode:=False;
 If (NodeIndex<1) Or (NodeIndex>IRNodeCount) Then Exit;
 If IRNodes[NodeIndex].Kind=IR_LITERAL Then Begin
  Value:=IRNodes[NodeIndex].IntegerVal;
  ConstantIntegerNode:=True;
 End
 Else If (IRNodes[NodeIndex].Kind=IR_UNARY) And
         (IRNodes[NodeIndex].OperatorText='-') And
         ConstantIntegerNode(IRNodes[NodeIndex].Left,Value) Then Begin
  Value:=-Value;
  ConstantIntegerNode:=True;
 End;
End;

Procedure BuildStatementIR;
Var
 I,ScopeIndex,ExprNode,TargetNode,EndIndex,StartIndex:Integer;
 StmtIndex,ParentIndex,IfParent,CaseParent,LoopParent:Integer;
 BoundNode,StepNode,HeaderEnd:Integer;
 ControlStack:Array[1..256] Of Integer;
 ControlKind:Array[1..256] Of TStatementKind;
 StackDepth:Integer;
 Tok:TToken;
 LowValue,HighValue,StepValue:LongInt;
 LowType,HighType:Integer;
Begin
 StatementCount:=0;
 StackDepth:=0;
 FillChar(ControlStack,SizeOf(ControlStack),0);
 FillChar(ControlKind,SizeOf(ControlKind),0);
 I:=1;
 While I<=Pipeline.TokenCount Do Begin
  Tok:=Pipeline.Tokens[I];
  ScopeIndex:=ScopeForToken(I,2);
  If StackDepth>0 Then ParentIndex:=ControlStack[StackDepth]
  Else ParentIndex:=0;

  If (Tok.Kind=TK_SYMBOL) And (Tok.Text=';') Then Begin
   If TokenStartsStatement(I) Then
    NewStatementIR(ST_EMPTY,ScopeIndex,0,0,ParentIndex,Tok.Line,Tok.Column);
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_BEGIN) Then
   NewStatementIR(ST_BLOCK_BEGIN,ScopeIndex,0,0,ParentIndex,
                  Tok.Line,Tok.Column)
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_WHILE) Then Begin
   ExprNode:=ParseIRAt(I+1,ScopeIndex,EndIndex);
   StmtIndex:=NewStatementIR(ST_WHILE,ScopeIndex,ExprNode,0,ParentIndex,
                            Tok.Line,Tok.Column);
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].StartLabel:=IRLabelCounter;
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].EndLabel:=IRLabelCounter;
   If StackDepth<256 Then Begin
    Inc(StackDepth);
    ControlStack[StackDepth]:=StmtIndex;
    ControlKind[StackDepth]:=ST_WHILE;
   End;
   I:=EndIndex;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_FOR) Then Begin
   TargetNode:=0;
   ExprNode:=0;
   BoundNode:=0;
   StepNode:=0;
   HeaderEnd:=I;
   If (I+2<=Pipeline.TokenCount) And
      (Pipeline.Tokens[I+1].Kind=TK_IDENTIFIER) And
      (Pipeline.Tokens[I+2].Kind=TK_SYMBOL) And
      (Pipeline.Tokens[I+2].Text=':=') Then Begin
    TargetNode:=BuildTargetNode(I+1,I+2,ScopeIndex);
    ExprNode:=ParseIRAt(I+3,ScopeIndex,EndIndex);
    If (EndIndex<=Pipeline.TokenCount) And
       (Pipeline.Tokens[EndIndex].Kind=TK_KEYWORD) And
       (Pipeline.Tokens[EndIndex].Keyword=KW_TO) Then Begin
     BoundNode:=ParseIRAt(EndIndex+1,ScopeIndex,HeaderEnd);
     If (HeaderEnd<=Pipeline.TokenCount) And
        (Pipeline.Tokens[HeaderEnd].Kind=TK_KEYWORD) And
        (Pipeline.Tokens[HeaderEnd].Keyword=KW_BY) Then
      StepNode:=ParseIRAt(HeaderEnd+1,ScopeIndex,HeaderEnd);
    End;
   End;
   StmtIndex:=NewStatementIR(ST_FOR,ScopeIndex,ExprNode,TargetNode,
                            ParentIndex,Tok.Line,Tok.Column);
   StatementIR[StmtIndex].BoundNode:=BoundNode;
   StatementIR[StmtIndex].StepNode:=StepNode;
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].StartLabel:=IRLabelCounter;
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].FalseLabel:=IRLabelCounter;
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].ContinueLabel:=IRLabelCounter;
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].EndLabel:=IRLabelCounter;
   If (TargetNode=0) Or (IRNodes[TargetNode].Kind<>IR_SYMBOL) Or
      (IRNodes[TargetNode].SymbolIndex=0) Or
      (SemanticSymbols[IRNodes[TargetNode].SymbolIndex].Kind<>SYM_VAR) Then
    SemanticError('variable de controle FOR invalide',Tok.Line,Tok.Column)
   Else If CanonicalType(IRNodes[TargetNode].TypeIndex)<>
           CanonicalType(TypeInteger) Then
    SemanticError('variable de controle FOR non entiere',Tok.Line,Tok.Column);
   If (ExprNode=0) Or (BoundNode=0) Then
    SemanticError('bornes FOR invalides',Tok.Line,Tok.Column)
   Else Begin
    If CanonicalType(IRNodes[ExprNode].TypeIndex)<>CanonicalType(TypeInteger) Then
     SemanticError('borne initiale FOR non entiere',Tok.Line,Tok.Column);
    If CanonicalType(IRNodes[BoundNode].TypeIndex)<>CanonicalType(TypeInteger) Then
     SemanticError('borne finale FOR non entiere',Tok.Line,Tok.Column);
   End;
   If (StepNode<>0) And
      (CanonicalType(IRNodes[StepNode].TypeIndex)<>CanonicalType(TypeInteger)) Then
    SemanticError('pas FOR non entier',Tok.Line,Tok.Column);
   If (StepNode<>0) And ConstantIntegerNode(StepNode,StepValue) And
      (StepValue=0) Then
    SemanticError('le pas BY d''une boucle FOR ne peut pas etre nul',
                  Tok.Line,Tok.Column);
   If StackDepth<256 Then Begin
    Inc(StackDepth);
    ControlStack[StackDepth]:=StmtIndex;
    ControlKind[StackDepth]:=ST_FOR;
   End;
   I:=HeaderEnd;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_LOOP) Then Begin
   StmtIndex:=NewStatementIR(ST_LOOP,ScopeIndex,0,0,ParentIndex,
                            Tok.Line,Tok.Column);
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].StartLabel:=IRLabelCounter;
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].EndLabel:=IRLabelCounter;
   If StackDepth<256 Then Begin
    Inc(StackDepth);
    ControlStack[StackDepth]:=StmtIndex;
    ControlKind[StackDepth]:=ST_LOOP;
   End;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_REPEAT) Then Begin
   StmtIndex:=NewStatementIR(ST_REPEAT,ScopeIndex,0,0,ParentIndex,
                            Tok.Line,Tok.Column);
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].StartLabel:=IRLabelCounter;
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].EndLabel:=IRLabelCounter;
   If StackDepth<256 Then Begin
    Inc(StackDepth);
    ControlStack[StackDepth]:=StmtIndex;
    ControlKind[StackDepth]:=ST_REPEAT;
   End;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_UNTIL) Then Begin
   LoopParent:=0;
   If (StackDepth>0) And (ControlKind[StackDepth]=ST_REPEAT) Then
    LoopParent:=ControlStack[StackDepth];
   ExprNode:=ParseIRAt(I+1,ScopeIndex,EndIndex);
   NewStatementIR(ST_UNTIL,ScopeIndex,ExprNode,0,LoopParent,
                  Tok.Line,Tok.Column);
   If LoopParent=0 Then
    SemanticError('UNTIL sans REPEAT',Tok.Line,Tok.Column)
   Else Dec(StackDepth);
   I:=EndIndex-1;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_EXIT) Then Begin
   LoopParent:=0;
   StartIndex:=StackDepth;
   While StartIndex>0 Do Begin
    If IsLoopStatement(ControlKind[StartIndex]) Then Begin
     LoopParent:=ControlStack[StartIndex];
     Break;
    End;
    Dec(StartIndex);
   End;
   NewStatementIR(ST_EXIT,ScopeIndex,0,0,LoopParent,Tok.Line,Tok.Column);
   If LoopParent=0 Then
    SemanticError('EXIT utilise hors d''une boucle',Tok.Line,Tok.Column);
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_IF) Then Begin
   ExprNode:=ParseIRAt(I+1,ScopeIndex,EndIndex);
   StmtIndex:=NewStatementIR(ST_IF,ScopeIndex,ExprNode,0,ParentIndex,
                            Tok.Line,Tok.Column);
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].FalseLabel:=IRLabelCounter;
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].EndLabel:=IRLabelCounter;
   If StackDepth<256 Then Begin
    Inc(StackDepth);
    ControlStack[StackDepth]:=StmtIndex;
    ControlKind[StackDepth]:=ST_IF;
   End;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_ELSIF) Then Begin
   IfParent:=0;
   If StackDepth>0 Then IfParent:=ControlStack[StackDepth];
   ExprNode:=ParseIRAt(I+1,ScopeIndex,EndIndex);
   StmtIndex:=NewStatementIR(ST_ELSIF,ScopeIndex,ExprNode,0,IfParent,
                            Tok.Line,Tok.Column);
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].FalseLabel:=IRLabelCounter;
   If IfParent<>0 Then StatementIR[StmtIndex].EndLabel:=
    StatementIR[IfParent].EndLabel;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_ELSE) Then Begin
   If (StackDepth>0) And (ControlKind[StackDepth]=ST_CASE) Then
    NewStatementIR(ST_CASE_ELSE,ScopeIndex,0,0,
                   ControlStack[StackDepth],Tok.Line,Tok.Column)
   Else Begin
    IfParent:=0;
    If StackDepth>0 Then IfParent:=ControlStack[StackDepth];
    NewStatementIR(ST_ELSE,ScopeIndex,0,0,IfParent,Tok.Line,Tok.Column);
   End;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_CASE) Then Begin
   ExprNode:=ParseIRAt(I+1,ScopeIndex,EndIndex);
   StmtIndex:=NewStatementIR(ST_CASE,ScopeIndex,ExprNode,0,ParentIndex,
                            Tok.Line,Tok.Column);
   Inc(IRLabelCounter);
   StatementIR[StmtIndex].EndLabel:=IRLabelCounter;
   If StackDepth<256 Then Begin
    Inc(StackDepth);
    ControlStack[StackDepth]:=StmtIndex;
    ControlKind[StackDepth]:=ST_CASE;
   End;
  End
  Else If (Tok.Kind=TK_SYMBOL) And (Tok.Text='|') And
          (StackDepth>0) And (ControlKind[StackDepth]=ST_CASE) Then Begin
   CaseParent:=ControlStack[StackDepth];
   StartIndex:=I+1;
   While StartIndex<=Pipeline.TokenCount Do Begin
    If CaseLiteralAt(StartIndex,LowValue,LowType) Then Begin
     HighValue:=LowValue;
     HighType:=LowType;
     If (StartIndex+2<=Pipeline.TokenCount) And
        (Pipeline.Tokens[StartIndex+1].Kind=TK_SYMBOL) And
        (Pipeline.Tokens[StartIndex+1].Text='..') And
        CaseLiteralAt(StartIndex+2,HighValue,HighType) Then Inc(StartIndex,2);
     StmtIndex:=NewStatementIR(ST_CASE_ARM,ScopeIndex,0,0,CaseParent,
                              Tok.Line,Tok.Column);
     StatementIR[StmtIndex].CaseLow:=LowValue;
     StatementIR[StmtIndex].CaseHigh:=HighValue;
     StatementIR[StmtIndex].HasCaseRange:=HighValue<>LowValue;
     Inc(IRLabelCounter);
     StatementIR[StmtIndex].StartLabel:=IRLabelCounter;
     Inc(IRLabelCounter);
     StatementIR[StmtIndex].FalseLabel:=IRLabelCounter;
    End;
    Inc(StartIndex);
    If (StartIndex>Pipeline.TokenCount) Or
       ((Pipeline.Tokens[StartIndex].Kind=TK_SYMBOL) And
        (Pipeline.Tokens[StartIndex].Text='=>')) Then Break;
    If Not ((Pipeline.Tokens[StartIndex].Kind=TK_SYMBOL) And
            (Pipeline.Tokens[StartIndex].Text=',')) Then Break;
    Inc(StartIndex);
   End;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_END) Then Begin
   NewStatementIR(ST_BLOCK_END,ScopeIndex,0,0,ParentIndex,
                  Tok.Line,Tok.Column);
   If StackDepth>0 Then Dec(StackDepth);
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_RETURN) Then Begin
   ExprNode:=ParseIRAt(I+1,ScopeIndex,EndIndex);
   NewStatementIR(ST_RETURN,ScopeIndex,ExprNode,0,ParentIndex,
                  Tok.Line,Tok.Column);
   If (ScopeIndex<1) Or (ScopeIndex>SemanticScopeCount) Or
      (SemanticScopes[ScopeIndex].Kind<>SCOPE_PROCEDURE) Then
    SemanticError('RETURN utilise hors d''une procedure',
                  Tok.Line,Tok.Column)
   Else If (ProcedureReturnType(ScopeIndex)=0) And (ExprNode<>0) Then
    SemanticError('une procedure sans resultat ne peut pas retourner de valeur',
                  Tok.Line,Tok.Column)
   Else If (ProcedureReturnType(ScopeIndex)<>0) And (ExprNode=0) Then
    SemanticError('valeur RETURN attendue',Tok.Line,Tok.Column);
  End
  Else If (Tok.Kind=TK_SYMBOL) And (Tok.Text=':=') Then Begin
   If IsObjectOverrideAssignment(I) Then Begin
    Inc(I);
    Continue;
   End;
   StartIndex:=FindDesignatorStart(I);
   TargetNode:=BuildTargetNode(StartIndex,I,ScopeIndex);
   ExprNode:=ParseIRAt(I+1,ScopeIndex,EndIndex);
   StmtIndex:=NewStatementIR(ST_ASSIGN,ScopeIndex,ExprNode,TargetNode,
                            ParentIndex,Tok.Line,Tok.Column);
   If (TargetNode=0) Or
      Not (IRNodes[TargetNode].Kind In
       [IR_SYMBOL,IR_INDEX,IR_FIELD,IR_DEREF]) Then
    SemanticError('destination d''affectation invalide',Tok.Line,Tok.Column)
   Else If Not IsIRWritableDesignator(TargetNode) Then
    SemanticError('destination d''affectation en lecture seule',
                  Tok.Line,Tok.Column);
  End
  Else If (Tok.Kind=TK_IDENTIFIER) And TokenStartsStatement(I) Then Begin
   StartIndex:=I;
   If (I+1<=Pipeline.TokenCount) And
      (Pipeline.Tokens[I+1].Kind=TK_SYMBOL) And
      ((Pipeline.Tokens[I+1].Text='(') Or
       (Pipeline.Tokens[I+1].Text='.')) Then Begin
    ExprNode:=ParseIRAt(StartIndex,ScopeIndex,EndIndex);
    If (ExprNode<>0) And (IRNodes[ExprNode].Kind=IR_CALL) Then
     NewStatementIR(ST_CALL,ScopeIndex,ExprNode,0,ParentIndex,
                    Tok.Line,Tok.Column);
   End;
  End;
  Inc(I);
 End;
End;

Procedure BuildExpressionRoots;
Var
 I,NodeIndex,ScopeIndex,TargetType:Integer;
 Tok:TToken;
 RootKind:TIRRootKind;
 BeginIndex:Integer;
Begin
 I:=1;
 While I<=Pipeline.TokenCount Do Begin
  Tok:=Pipeline.Tokens[I];
  BeginIndex:=0;
  TargetType:=0;
  RootKind:=IR_ROOT_EXPRESSION;
  If (Tok.Kind=TK_SYMBOL) And (Tok.Text=':=') Then Begin
   If IsObjectOverrideAssignment(I) Then Begin
    Inc(I);
    Continue;
   End;
   ScopeIndex:=ScopeForToken(I,2);
   TargetType:=FindAssignmentTarget(I,ScopeIndex);
   BeginIndex:=I+1;
   RootKind:=IR_ROOT_ASSIGN;
  End
  Else If (Tok.Kind=TK_KEYWORD) And (Tok.Keyword=KW_RETURN) Then Begin
   ScopeIndex:=ScopeForToken(I,2);
   BeginIndex:=I+1;
   TargetType:=ProcedureReturnType(ScopeIndex);
   RootKind:=IR_ROOT_RETURN;
  End
  Else If (Tok.Kind=TK_KEYWORD) And
          ((Tok.Keyword=KW_IF) Or (Tok.Keyword=KW_ELSIF) Or
           (Tok.Keyword=KW_WHILE) Or (Tok.Keyword=KW_UNTIL)) Then Begin
   ScopeIndex:=ScopeForToken(I,2);
   BeginIndex:=I+1;
   TargetType:=TypeBoolean;
   RootKind:=IR_ROOT_CONDITION;
  End;

  If BeginIndex<>0 Then Begin
   IRTokenIndex:=BeginIndex;
   IRCurrentScope:=ScopeIndex;
   If Not IRExpressionStop And ParseIROr(NodeIndex) Then Begin
    AddIRRoot(RootKind,NodeIndex,ScopeIndex,TargetType,
              Pipeline.Tokens[BeginIndex].Line,
              Pipeline.Tokens[BeginIndex].Column);
    If (TargetType<>0) And (IRNodes[NodeIndex].TypeIndex<>0) And
       Not TypeCompatible(TargetType,IRNodes[NodeIndex].TypeIndex) Then
     SemanticError('expression '+TypeName(IRNodes[NodeIndex].TypeIndex)+
                   ' incompatible avec '+TypeName(TargetType),
                   Pipeline.Tokens[BeginIndex].Line,
                   Pipeline.Tokens[BeginIndex].Column);
   End;
  End;
  Inc(I);
 End;
End;

Procedure ValidateIRCalls;
Var
 I,J:Integer;
 Duplicate:Boolean;
Begin
 For I:=1 To IRNodeCount Do
  If IRNodes[I].Kind=IR_CALL Then Begin
   Duplicate:=False;
   For J:=1 To I-1 Do
    If (IRNodes[J].Kind=IR_CALL) And
       (IRNodes[J].Line=IRNodes[I].Line) And
       (IRNodes[J].Column=IRNodes[I].Column) And
       (IRNodes[J].Text=IRNodes[I].Text) Then Begin
     Duplicate:=True;
     Break;
    End;
   If Not Duplicate Then
    ValidateProcedureCall(I,IRNodes[I].SymbolIndex);
  End;
End;

Procedure TraceExpressionIR;
Var
 I:Integer;
Begin
 If Options.Verbose Then Begin
  WriteLn('IR expr: ',IRNodeCount,' noeuds, ',IRRootCount,' racines');
  For I:=1 To IRNodeCount Do
   WriteLn('IR ',I,': ',IRKindName(IRNodes[I].Kind),
           ' type=',TypeName(IRNodes[I].TypeIndex),
           ' op=',IRNodes[I].OperatorText,
           ' left=',IRNodes[I].Left,' right=',IRNodes[I].Right,
           ' labels=',IRNodes[I].TrueLabel,'/',IRNodes[I].FalseLabel,
           ' @ ',IRNodes[I].Line,':',IRNodes[I].Column);
  For I:=1 To IRRootCount Do
   WriteLn('IR root ',I,': kind=',Ord(IRRoots[I].Kind),
           ' node=',IRRoots[I].NodeIndex,
           ' scope=',IRRoots[I].ScopeIndex,
           ' cible=',TypeName(IRRoots[I].TargetType));
 End
 Else WriteLn('IR     : ',IRNodeCount,' noeuds d''expression');
End;

Procedure TraceStatementIR;
Var
 I:Integer;
 RangeText:String;
Begin
 If Options.Verbose Then Begin
  WriteLn('IR stmt: ',StatementCount,' instructions');
  For I:=1 To StatementCount Do Begin
   RangeText:='';
   If StatementIR[I].Kind=ST_CASE_ARM Then Begin
    RangeText:=' valeur='+IntToString(StatementIR[I].CaseLow);
    If StatementIR[I].HasCaseRange Then
     RangeText:=RangeText+'..'+IntToString(StatementIR[I].CaseHigh);
   End;
   WriteLn('ST ',I,': ',StatementKindName(StatementIR[I].Kind),
           ' expr=',StatementIR[I].ExpressionNode,
           ' cible=',StatementIR[I].TargetNode,
           ' parent=',StatementIR[I].ParentIndex,
           ' labels=',StatementIR[I].StartLabel,'/',
           StatementIR[I].FalseLabel,'/',StatementIR[I].EndLabel,
           RangeText,' @ ',StatementIR[I].Line,':',
           StatementIR[I].Column);
  End;
 End
 Else WriteLn('Stmt   : ',StatementCount,' instructions IR');
End;

Procedure BuildSimpleIR;
Begin
 EnterStage(CS_IR);
 IRNodeCount:=0;
 IRArgumentCount:=0;
 IRRootCount:=0;
 IRTokenIndex:=1;
 IRCurrentScope:=2;
 IRLabelCounter:=0;
 BuildExpressionRoots;
 BuildStatementIR;
 ValidateIRCalls;
 If Pipeline.ErrorCount<>0 Then Exit;
 FinishStage(CS_IR);
 TraceExpressionIR;
 TraceStatementIR;
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
 InitPipeline(SourceName);
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

Procedure PrintUsage;Begin
 WriteLn('MOD3CW32 - Cette commande permet de ',
         'lancer le compilateur Modula-3 pour l''assembleur du microprocesseur ',
         '80386 pour Windows 32 bits.');
 WriteLn;
 WriteLn('Syntaxe : MOD3CW32 <source1.i3|.m3> [source2.i3|.m3 ...] [options]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -c, --obj-only     : produire seulement un fichier objet COFF i386 .OBJ');
 WriteLn('  -S, --asm          : produire/conserver aussi le fichier assembleur .ASM');
 WriteLn('  -o <fichier>       : specifier le nom du fichier de sortie (un seul source)');
 WriteLn('  -v, --verbose      : afficher le pipeline selectionne');
 WriteLn('  -h, --help         : afficher cette aide');
 WriteLn('  --version          : afficher la version');
End;

Procedure PrintVersion;
Begin
 WriteLn('MOD3CW32 ',MOD3CW32_VERSION);
End;

Procedure InitOptions;
Begin
 Options.SourceCount:=0;
 Options.OutputName:='';
 Options.OutputKind:=OK_EXE_PE32;
 Options.EmitAsm:=False;
 Options.Verbose:=False;
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

Procedure AddSourceName(S:String);
Begin
 If Not IsModula3Source(S) Then Begin
  WriteLn('Erreur: extension de fichier source non reconnue (.i3 ou .m3 attendu): ',S);
  Halt(1);
 End;
 If Options.SourceCount>=MOD3_MAX_SOURCES Then Begin
  WriteLn('Erreur: trop de fichiers sources (maximum ',MOD3_MAX_SOURCES,').');
  Halt(1);
 End;
 Inc(Options.SourceCount);
 Options.SourceNames[Options.SourceCount]:=S;
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
  Else AddSourceName(S);
  Inc(I);
 End;
 If Options.SourceCount=0 Then Begin
  PrintUsage;
  Halt(1);
 End;
 If (Options.SourceCount>1) And (Options.OutputName<>'') Then Begin
  WriteLn('Erreur: -o n''est pas compatible avec plusieurs fichiers sources.');
  Halt(1);
 End;
 For I:=1 To Options.SourceCount Do
  ValidatePathLength(Options.SourceNames[I],'le chemin source');
 If Options.OutputName<>'' Then
  ValidatePathLength(Options.OutputName,'le chemin de sortie');
End;

BEGIN
 ParseCommandLine;
 QuietDiagnostics:=False;
 ResolveUnits;
 If (PreScanErrorCount<>0) Or HasImportCycle Then Begin
  WriteLn('Erreur: resolution des unites/imports echouee, compilation annulee.');
  Halt(1);
 End;
 TotalErrors:=0;
 For SourceIndex:=1 To CompileOrderCount Do Begin
  CompilePipeline(Units[CompileOrder[SourceIndex]].SourceName);
  Inc(TotalErrors,Pipeline.ErrorCount);
 End;
 If TotalErrors<>0 Then Halt(1);
END.
