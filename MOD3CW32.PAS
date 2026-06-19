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

  TODO 12 - Definir la table des symboles et les portees:
            portee interface, module, procedure, objet, generique,
            constantes, variables, parametres et detection des doublons.

  TODO 13 - Implementer les types scalaires de base:
            INTEGER, CARDINAL, BOOLEAN, CHAR, REAL/LONGREAL si vise, TEXT,
            compatibilite et conversions implicites/explicites.

  TODO 14 - Implementer les types composes:
            ARRAY (bornes fixes et ouvertes), RECORD, REF (pointeurs, NEW,
            allocation) et types opaques (revelation partielle/complete).

  TODO 15 - Implementer CONST et les litteraux:
            constantes entieres, reelles, booleennes, caracteres, chaines,
            evaluation constante simple et references dans les expressions.

  TODO 16 - Implementer VAR et l'allocation des donnees:
            allocation globale (.data/.bss) et locale (offsets EBP),
            initialisation implicite a zero et segment de donnees statiques.

  TODO 17 - Implementer les expressions et operateurs:
            priorites Modula-3, arithmetique, comparaisons, booleens
            (AND/OR/NOT court-circuit) et evaluation en IR typee.

  TODO 18 - Implementer les instructions de base et le controle:
            affectation :=, appel de procedure, IF/ELSIF/ELSE, CASE,
            blocs imbriques et instruction vide.

  TODO 19 - Implementer les boucles:
            LOOP...EXIT...END, WHILE, REPEAT, FOR, avec gestion correcte
            de EXIT et des bornes.

  TODO 20 - Implementer les procedures et leurs parametres:
            PROCEDURE, parametres VALUE/VAR/READONLY, valeurs de retour,
            recursion et verification d'arite et de types.

  TODO 21 - Implementer les objets:
            OBJECT types, heritage, champs et methodes, OVERRIDE, NEW,
            et appels de methodes virtuelles via table de methodes.

  TODO 22 - Implementer les exceptions:
            EXCEPTION, RAISE, TRY...EXCEPT...FINALLY, propagation et
            nettoyage de pile lors du deroulement.

  TODO 23 - Implementer les generiques:
            GENERIC INTERFACE/MODULE, parametres generiques, instanciation
            (nom AS generic(params)) et generation du code instancie.

  TODO 24 - Implementer le runtime et les E/S minimales:
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

Function WriteAsm80386File(FileName:String):Boolean;
Var
 T:Text;
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
 Emit386Mov(T,RegName(R_EAX),'0');
 EmitAsmLabel(T,MakeInternalLabel(Pipeline.ModuleName+'_EXIT'));
 Emit386Epilogue(T);
 EmitAsmBlank(T);
 EmitAsmSection(T,Pipeline.Target.DataSection);
 EmitAsmLabel(T,MakeDataLabel(Pipeline.ModuleName+'_SOURCE'));
 EmitAsmLine(T,'  db '+AsmByteList(Pipeline.SourceName,True));
 EmitAsmLabel(T,MakeDataLabel(Pipeline.ModuleName+'_MODULE'));
 EmitAsmLine(T,'  db '+AsmByteList(Pipeline.ModuleName,True));
 EmitAsmLabel(T,MakeAsmLabel(MOD3_RUNTIME_PREFIX,'CRLF'));
 EmitAsmLine(T,'  db 13,10,0');
 EmitAsmBlank(T);
 EmitAsmSection(T,Pipeline.Target.BssSection);
 EmitAsmLabel(T,MakeDataLabel(Pipeline.ModuleName+'_BSS_ANCHOR'));
 EmitAsmLine(T,'  resd 1');
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
Begin
 WriteCoffI386File:=False;
 SymbolCount:=6;
 EntryName:=Pipeline.Target.EntryLabel;
 SourceLabel:=MakeDataLabel(Pipeline.ModuleName+'_SOURCE');
 ModuleLabel:=MakeDataLabel(Pipeline.ModuleName+'_MODULE');
 DataSize:=Length(Pipeline.SourceName)+1+Length(Pipeline.ModuleName)+1;
 BssSize:=4; (* anchor minimal; remplace par la taille BSS reelle en TODO 16 *)
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

Function BuildRuntimeOutput:String;
Begin
 BuildRuntimeOutput:=''; (* sera alimente par la TODO 24 via l'execution de l'IR InOut *)
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

Procedure BuildSemanticTables;
Begin
 EnterStage(CS_SEMANTIC_TABLES);
 FinishStage(CS_SEMANTIC_TABLES);
End;

Procedure BuildSimpleIR;
Begin
 EnterStage(CS_IR);
 FinishStage(CS_IR);
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
