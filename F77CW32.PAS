{ @author: Sylvain Maltais
  @created: 2026-06-17
  @version: 2.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Fortran 77 vers assembleur 80386 / Windows 32 bits
  @output: Win32 PE .EXE par defaut, COFF i386 .OBJ sur demande,
           .ASM 80386 optionnel sur demande explicite
  @license: MIT
}

{ TODO F77CW32 - Compilateur Fortran 77 vers 80386/Win32

  DONE 01 - Cible F77CW32 renomme et isolee, avec metadata d'en-tete indiquant
            Fortran 77 -> assembleur 80386 / Windows 32 bits.

  DONE 02 - Modes de sortie definis:
            par defaut produire un .EXE Windows 32 bits;
            avec option -c produire seulement un .OBJ;
            avec option -S produire un .ASM uniquement sur demande explicite.

  DONE 03 - Pipeline complet concu:
            source .F -> lexer -> parser -> tables semantiques -> IR simple
            -> ASM 80386 optionnel -> OBJ COFF -> EXE PE32.

  DONE 04 - Conventions d'appel 80386 definies:
            pile 32 bits, registres EAX/EBX/ECX/EDX/ESI/EDI/EBP/ESP,
            prologue/epilogue Win32, arguments passes par adresse Fortran.

  DONE 05 - Modele memoire SMALL/segments 8086 remplace par un modele plat
            32 bits: .text, .data, .bss, alignements et labels compatibles Win32.

  DONE 06 - Format objet cible choisi et documente:
            COFF i386 pour linker Windows, avec table de symboles, relocations
            et sections minimales.

  DONE 07 - Writer OBJ COFF minimal implemente, capable de contenir code,
            donnees statiques, chaines, COMMON et relocations.

  DONE 08 - Etape de linkage .OBJ -> .EXE ajoutee par defaut:
            generation PE32 minimale autonome, sans dependance a un linker
            externe.

  DONE 09 - Options ligne de commande ajoutees:
            -c pour .OBJ seulement, -S pour conserver/generer .ASM,
            -o nom_sortie, --version version, -h aide, et mode diagnostic.

  DONE 10 - Emission assembleur 80386 adaptee:
            MOV/PUSH/CALL/RET/JMP/CMP/Jcc/IMUL/IDIV 32 bits,
            labels internes, labels Fortran numeriques et appels runtime.

  DONE 11 - Tailles Win32 des types Fortran definies au depart:
            INTEGER en 32 bits, LOGICAL en 32 bits, CHARACTER fixe,
            REAL/DOUBLE prepares pour une phase ulterieure.

  DONE 12 - Lexer Fortran 77 fixe valide:
            colonnes 1-5 labels, colonne 6 continuation,
            commentaires C/* en colonne 1, lignes jusqu'a 72 colonnes utiles.

  DONE 13 - Parser des unites de programme valide:
            PROGRAM, SUBROUTINE, END, RETURN, declarations INTEGER,
            appels CALL et portees separees par unite.

  DONE 14 - Implementer le typage implicite Fortran 77:
            I-N INTEGER par defaut, autres REAL si non declare,
            tout en permettant INTEGER explicite pour les samples actuels.

  DONE 15 - Finaliser la table des symboles 32 bits:
            variables locales, variables statiques si necessaire,
            parametres dummy passes par adresse, procedures et labels.

  DONE 16 - Implementer les affectations scalaires INTEGER:
            constantes entieres, variables, copies par adresse pour parametres,
            et stockage correct dans les variables locales.

  DONE 17 - Implementer les expressions INTEGER minimales:
            +, -, *, parentheses, variables, constantes,
            evaluation avec pile ou registres 80386.

  DONE 18 - Implementer les comparaisons relationnelles Fortran:
            .EQ., .NE., .LT., .LE., .GT., .GE.,
            necessaires notamment pour IF (N .LE. 1) GOTO label.

  DONE 19 - Implementer GOTO numerique et resolution des labels:
            labels definis/references, erreurs sur label inconnu,
            emission JMP/Jcc vers labels ASM stables.

  TODO 20 - Implementer IF arithmetique/logique minimal:
            au minimum IF (expr relationnelle) GOTO label
            pour couvrir fibo.f, puis etendre vers IF complet F77.

  TODO 21 - Implementer DO label var = debut, fin[, pas]:
            compteur INTEGER 32 bits, borne finale, increment,
            branchement vers label de fin, compatibilite avec CONTINUE.

  TODO 22 - Implementer CONTINUE comme label/emission no-op,
            utilisable comme terminaison de boucle DO numerique.

  TODO 23 - Implementer CALL SUBROUTINE avec arguments par reference:
            ordre d'empilement documente, nettoyage de pile,
            liaison interne PROGRAM/SUBROUTINE dans le meme fichier.

  TODO 24 - Implementer le runtime console minimal Win32:
            PRINT *, chaine litterale;
            PRINT *, variable INTEGER;
            conversion entier -> texte;
            sortie via API Win32 ou runtime C selon strategie de linkage.

  TODO 25 - Creer la batterie de validation SAMPLES\F77:
            hello.f, arith.f, do_test.f, sub_test.f, fibo.f;
            compiler en .EXE par defaut, tester option .OBJ seul,
            tester option .ASM explicite, comparer sorties attendues.
}

Program F77CW32;

{$I-}

Const
 F77CW32_VERSION = '2.0';
 I386_STACK_SLOT_SIZE = 4;
 I386_ARG_BASE_OFFSET = 8;
 I386_STACK_ALIGN     = 4;
 WIN32_SECTION_ALIGN  = 4096;
 WIN32_FILE_ALIGN     = 512;
 I386_CODE_ALIGN      = 16;
 I386_DATA_ALIGN      = 4;
 I386_BSS_ALIGN       = 4;
 FLAT_TEXT_SECTION    = '.text';
 FLAT_DATA_SECTION    = '.data';
 FLAT_BSS_SECTION     = '.bss';
 USER_PROC_PREFIX     = '_FP_';
 USER_VAR_PREFIX      = '_FV_';
 USER_CONST_PREFIX    = '_FK_';
 USER_LABEL_PREFIX    = '_FL_';
 FRT_PFX              = '_FRT_';
 INTERNAL_LABEL_PREFIX= '_FB_';
 COFF_MACHINE_I386    = $014C;
 COFF_FILE_HEADER_SIZE= 20;
 COFF_SECTION_HDR_SIZE= 40;
 COFF_SYMBOL_SIZE     = 18;
 COFF_RELOC_SIZE      = 10;
 COFF_SCN_CNT_CODE    = $00000020;
 COFF_SCN_CNT_INITDATA= $00000040;
 COFF_SCN_CNT_UNINIT  = $00000080;
 COFF_SCN_MEM_EXECUTE = $20000000;
 COFF_SCN_MEM_READ    = $40000000;
 COFF_SCN_MEM_WRITE   = $80000000;
 COFF_SCN_ALIGN_16BYTES = $00500000;
 COFF_SCN_ALIGN_4BYTES  = $00300000;
 COFF_REL_I386_DIR32  = $0006;
 COFF_REL_I386_REL32  = $0014;
 COFF_SYM_CLASS_EXTERNAL = 2;
 COFF_SYM_CLASS_STATIC   = 3;
 COFF_TEXT_FLAGS_LO      = $0020;
 COFF_TEXT_FLAGS_HI      = $6050;
 COFF_DATA_FLAGS_LO      = $0040;
 COFF_DATA_FLAGS_HI      = $C030;
 COFF_BSS_FLAGS_LO       = $0080;
 COFF_BSS_FLAGS_HI       = $C030;
 PE_DOS_LFANEW           = $0080;
 PE_TEXT_RVA             = $1000;
 PE_IDATA_RVA            = $2000;
 PE_TEXT_RAW_PTR         = $0200;
 PE_IDATA_RAW_PTR        = $0400;
 PE_TEXT_RAW_SIZE        = $0200;
 PE_IDATA_RAW_SIZE       = $0200;
 PE_SIZE_OF_HEADERS      = $0200;
 PE_SIZE_OF_IMAGE        = $3000;
 PE_IMAGE_BASE           = $00400000;
 PE_OPT_HEADER_SIZE      = 224;
 PE_SUBSYSTEM_CONSOLE    = 3;
 PE_FILE_CHAR_LO         = $0102;
 PE_FILE_CHAR_HI         = $0000;
 PE_IDATA_FLAGS_LO       = $0040;
 PE_IDATA_FLAGS_HI       = $C000;
 F77_FIXED_LABEL_END     = 5;
 F77_FIXED_CONT_COL      = 6;
 F77_FIXED_TEXT_START    = 7;
 F77_FIXED_TEXT_END      = 72;
 F77_MAX_LINE_LEN        = 255;
 F77_MAX_SYMBOLS         = 256;
 F77_MAX_ASSIGNMENTS     = 256;
 F77_MAX_COMPARISONS     = 256;
 F77_MAX_BRANCHES        = 256;

Type
 TOutputMode = (OM_EXE, OM_OBJ);

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

 T386Condition = (
  CC_E,
  CC_NE,
  CC_L,
  CC_LE,
  CC_G,
  CC_GE
 );

 TFixedLineKind = (
  FLK_COMMENT,
  FLK_INITIAL,
  FLK_CONTINUATION,
  FLK_BLANK
 );

 TF77DataType = (
  FT_NONE,
  FT_INTEGER,
  FT_LOGICAL,
  FT_CHARACTER,
  FT_REAL,
  FT_DOUBLE
 );

 TF77TypeInfo = Record
  DType     : TF77DataType;
  Name      : String[16];
  SizeBytes : Integer;
  AlignBytes: Integer;
  Supported : Boolean;
 End;

 TF77SymbolKind = (
  SK_LOCAL,
  SK_STATIC,
  SK_PARAM,
  SK_PROC,
  SK_LABEL
 );

 TF77Symbol = Record
  UnitName    : String[32];
  Name        : String[32];
  Kind        : TF77SymbolKind;
  DType       : TF77DataType;
  ExplicitType: Boolean;
  AsmName     : String[64];
  SizeBytes   : Integer;
  Offset      : Integer;
  ParamIndex  : Integer;
  LabelValue  : LongInt;
  LineNo      : Integer;
 End;

 TF77AssignRhsKind = (
  ARK_CONST_INT,
  ARK_VAR,
  ARK_EXPR
 );

 TF77Assignment = Record
  UnitName : String[32];
  LineNo   : Integer;
  DestName : String[32];
  DestIndex: Integer;
  RhsKind  : TF77AssignRhsKind;
  ConstVal : LongInt;
  SrcName  : String[32];
  SrcIndex : Integer;
  ExprText : String[96];
 End;

 TF77Comparison = Record
  UnitName : String[32];
  LineNo   : Integer;
  LeftExpr : String[96];
  RelCond  : T386Condition;
  RightExpr: String[96];
  BranchIndex: Integer;
 End;

 TF77BranchKind = (
  BK_GOTO,
  BK_IF_GOTO
 );

 TF77Branch = Record
  UnitName       : String[32];
  LineNo         : Integer;
  Kind           : TF77BranchKind;
  LabelValue     : LongInt;
  LabelIndex     : Integer;
  ComparisonIndex: Integer;
 End;

 TCoffRelocKind = (
  CR_DIR32,
  CR_REL32
 );

 TCoffSectionRec = Record
  AsmSection  : TAsmSection;
  Name        : String[8];
  FlagsText   : String[40];
  AlignBytes  : Integer;
  FlagsLo     : Word;
  FlagsHi     : Word;
 End;

 TCoffFormat = Record
  Machine       : Word;
  HeaderSize    : Integer;
  SectionHdrSize: Integer;
  SymbolSize    : Integer;
  RelocSize     : Integer;
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

 TCompilerOptions = Record
  SourceName : String;
  OutputName : String;
 OutputMode : TOutputMode;
 EmitAsm    : Boolean;
 Verbose    : Boolean;
 Diagnostic : Boolean;
End;

 TPipelineState = Record
  SourceName : String;
  AsmName    : String;
  ObjName    : String;
  ExeName    : String;
  CodeSection: TAsmSection;
  DataSection: TAsmSection;
  BssSection : TAsmSection;
  CoffFormat : TCoffFormat;
  SourceLines: Integer;
  CommentLines: Integer;
  BlankLines: Integer;
  InitialLines: Integer;
  ContinuationLines: Integer;
  LabelCount: Integer;
  LogicalLines: Integer;
  ProgramCount: Integer;
  SubroutineCount: Integer;
  EndCount: Integer;
  ReturnCount: Integer;
  IntegerDeclCount: Integer;
  CallCount: Integer;
  ParserErrors: Integer;
  SymbolCount: Integer;
  ExplicitTypeCount: Integer;
  ImplicitIntegerCount: Integer;
  ImplicitRealCount: Integer;
  LocalVarCount: Integer;
  StaticVarCount: Integer;
  ParamCount: Integer;
  ProcCount: Integer;
  SymbolLabelCount: Integer;
  Symbols: Array[1..F77_MAX_SYMBOLS] Of TF77Symbol;
  AssignmentCount: Integer;
  SkippedAssignmentCount: Integer;
  Assignments: Array[1..F77_MAX_ASSIGNMENTS] Of TF77Assignment;
  ComparisonCount: Integer;
  SkippedComparisonCount: Integer;
  Comparisons: Array[1..F77_MAX_COMPARISONS] Of TF77Comparison;
  BranchCount: Integer;
  SkippedBranchCount: Integer;
  Branches: Array[1..F77_MAX_BRANCHES] Of TF77Branch;
 End;

Var
 Options : TCompilerOptions;
 Pipeline : TPipelineState;

Function UpperStr(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 To Length(S)Do S[I]:=UpCase(S[I]);
 UpperStr:=S;
End;

Function IntToString(N:LongInt):String;
Var
 S:String;
Begin
 Str(N,S);
 IntToString:=S;
End;

Function WordHex(W:Word):String;
Const
 HexDigits : String[16] = '0123456789ABCDEF';
Begin
 WordHex:=HexDigits[(W Shr 12)and$F+1]+
          HexDigits[(W Shr 8)and$F+1]+
          HexDigits[(W Shr 4)and$F+1]+
          HexDigits[W and$F+1];
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
  AS_BSS:SectionName:=FLAT_BSS_SECTION;
  Else SectionName:=FLAT_TEXT_SECTION;
 End;
End;

Function SectionAlign(Section:TAsmSection):Integer;
Begin
 Case Section Of
  AS_TEXT:SectionAlign:=I386_CODE_ALIGN;
  AS_DATA:SectionAlign:=I386_DATA_ALIGN;
  AS_BSS:SectionAlign:=I386_BSS_ALIGN;
  Else SectionAlign:=I386_DATA_ALIGN;
 End;
End;

Function F77TypeName(DType:TF77DataType):String;
Begin
 Case DType Of
  FT_INTEGER:F77TypeName:='INTEGER';
  FT_LOGICAL:F77TypeName:='LOGICAL';
  FT_CHARACTER:F77TypeName:='CHARACTER';
  FT_REAL:F77TypeName:='REAL';
  FT_DOUBLE:F77TypeName:='DOUBLE PRECISION';
  Else F77TypeName:='NONE';
 End;
End;

Function F77TypeSize(DType:TF77DataType;CharLen:Integer):Integer;
Begin
 Case DType Of
  FT_INTEGER:F77TypeSize:=4;
  FT_LOGICAL:F77TypeSize:=4;
  FT_CHARACTER:Begin
   If CharLen<1 Then CharLen:=1;
   F77TypeSize:=CharLen;
  End;
  FT_REAL:F77TypeSize:=4;
  FT_DOUBLE:F77TypeSize:=8;
  Else F77TypeSize:=0;
 End;
End;

Function F77TypeAlign(DType:TF77DataType):Integer;
Begin
 Case DType Of
  FT_INTEGER:F77TypeAlign:=4;
  FT_LOGICAL:F77TypeAlign:=4;
  FT_CHARACTER:F77TypeAlign:=1;
  FT_REAL:F77TypeAlign:=4;
  FT_DOUBLE:F77TypeAlign:=8;
  Else F77TypeAlign:=1;
 End;
End;

Function F77TypeSupportedNow(DType:TF77DataType):Boolean;
Begin
 F77TypeSupportedNow:=(DType=FT_INTEGER)or(DType=FT_LOGICAL)or
                      (DType=FT_CHARACTER);
End;

Function F77MakeTypeInfo(DType:TF77DataType;CharLen:Integer):TF77TypeInfo;
Begin
 F77MakeTypeInfo.DType:=DType;
 F77MakeTypeInfo.Name:=F77TypeName(DType);
 F77MakeTypeInfo.SizeBytes:=F77TypeSize(DType,CharLen);
 F77MakeTypeInfo.AlignBytes:=F77TypeAlign(DType);
 F77MakeTypeInfo.Supported:=F77TypeSupportedNow(DType);
End;

Function F77TypeAsmReserve(DType:TF77DataType;CharLen:Integer):String;
Begin
 Case DType Of
  FT_INTEGER:F77TypeAsmReserve:='resd 1';
  FT_LOGICAL:F77TypeAsmReserve:='resd 1';
  FT_CHARACTER:F77TypeAsmReserve:='resb '+IntToString(F77TypeSize(DType,CharLen));
  FT_REAL:F77TypeAsmReserve:='resd 1';
  FT_DOUBLE:F77TypeAsmReserve:='resq 1';
  Else F77TypeAsmReserve:='resb 0';
 End;
End;

Function SymbolKindName(Kind:TF77SymbolKind):String;
Begin
 Case Kind Of
  SK_LOCAL:SymbolKindName:='LOCAL';
  SK_STATIC:SymbolKindName:='STATIC';
  SK_PARAM:SymbolKindName:='PARAM';
  SK_PROC:SymbolKindName:='PROC';
  SK_LABEL:SymbolKindName:='LABEL';
  Else SymbolKindName:='?';
 End;
End;

Procedure TraceTypeInfo(DType:TF77DataType;CharLen:Integer);
Var
 Info:TF77TypeInfo;
 Status:String;
Begin
 If Not(Options.Verbose or Options.Diagnostic)Then Exit;
 Info:=F77MakeTypeInfo(DType,CharLen);
 If Info.Supported Then Status:='actif'
  Else Status:='prepare';
 WriteLn('Type   : ',Info.Name,' size ',Info.SizeBytes,
         ' align ',Info.AlignBytes,' ',Status);
End;

Procedure TraceSymbolTable;
Var
 I:Integer;
 Source:String;
Begin
 If Not(Options.Verbose or Options.Diagnostic)Then Exit;
 WriteLn('Symbol : total ',Pipeline.SymbolCount,
         ', explicites ',Pipeline.ExplicitTypeCount,
         ', implicites INTEGER ',Pipeline.ImplicitIntegerCount,
         ', implicites REAL ',Pipeline.ImplicitRealCount);
 WriteLn('Symbol : locaux ',Pipeline.LocalVarCount,
         ', statiques ',Pipeline.StaticVarCount,
         ', params ',Pipeline.ParamCount,
         ', procedures ',Pipeline.ProcCount,
         ', labels ',Pipeline.SymbolLabelCount);
 For I:=1 To Pipeline.SymbolCount Do Begin
  If Pipeline.Symbols[I].ExplicitType Then Source:='explicite'
   Else Source:='implicite';
  WriteLn('Symbol : ',Pipeline.Symbols[I].UnitName,'.',
          Pipeline.Symbols[I].Name,' ',SymbolKindName(Pipeline.Symbols[I].Kind),
          ' ',F77TypeName(Pipeline.Symbols[I].DType),' ',Source,
          ' asm=',Pipeline.Symbols[I].AsmName,
          ' size=',Pipeline.Symbols[I].SizeBytes,
          ' off=',Pipeline.Symbols[I].Offset,
          ' arg=',Pipeline.Symbols[I].ParamIndex,
          ' label=',Pipeline.Symbols[I].LabelValue,
          ' ligne=',Pipeline.Symbols[I].LineNo);
 End;
End;

Function AssignmentRhsKindName(Kind:TF77AssignRhsKind):String;
Begin
 Case Kind Of
  ARK_CONST_INT:AssignmentRhsKindName:='CONST';
  ARK_VAR:AssignmentRhsKindName:='VAR';
  ARK_EXPR:AssignmentRhsKindName:='EXPR';
  Else AssignmentRhsKindName:='?';
 End;
End;

Function FortranRelName(Cond:T386Condition):String;
Begin
 Case Cond Of
  CC_E:FortranRelName:='.EQ.';
  CC_NE:FortranRelName:='.NE.';
  CC_L:FortranRelName:='.LT.';
  CC_LE:FortranRelName:='.LE.';
  CC_G:FortranRelName:='.GT.';
  CC_GE:FortranRelName:='.GE.';
 Else FortranRelName:='.EQ.';
 End;
End;

Function BranchKindName(Kind:TF77BranchKind):String;
Begin
 Case Kind Of
  BK_GOTO:BranchKindName:='GOTO';
  BK_IF_GOTO:BranchKindName:='IF-GOTO';
  Else BranchKindName:='?';
 End;
End;

Procedure TraceAssignments;
Var
 I:Integer;
 Rhs:String;
Begin
 If Not(Options.Verbose or Options.Diagnostic)Then Exit;
 WriteLn('IR     : affectations INTEGER ',Pipeline.AssignmentCount,
         ', ignorees ',Pipeline.SkippedAssignmentCount);
 For I:=1 To Pipeline.AssignmentCount Do Begin
 If Pipeline.Assignments[I].RhsKind=ARK_CONST_INT Then
   Rhs:=IntToString(Pipeline.Assignments[I].ConstVal)
  Else If Pipeline.Assignments[I].RhsKind=ARK_VAR Then
   Rhs:=Pipeline.Assignments[I].SrcName
  Else
   Rhs:=Pipeline.Assignments[I].ExprText;
  WriteLn('IR     : ',Pipeline.Assignments[I].UnitName,'.',
          Pipeline.Assignments[I].DestName,' = ',Rhs,
          ' ',AssignmentRhsKindName(Pipeline.Assignments[I].RhsKind),
          ' ligne ',Pipeline.Assignments[I].LineNo);
 End;
End;

Procedure TraceComparisons;
Var
 I:Integer;
Begin
 If Not(Options.Verbose or Options.Diagnostic)Then Exit;
 WriteLn('IR     : comparaisons INTEGER ',Pipeline.ComparisonCount,
         ', ignorees ',Pipeline.SkippedComparisonCount);
 For I:=1 To Pipeline.ComparisonCount Do
  WriteLn('IR     : ',Pipeline.Comparisons[I].UnitName,' IF ',
          Pipeline.Comparisons[I].LeftExpr,' ',
          FortranRelName(Pipeline.Comparisons[I].RelCond),' ',
          Pipeline.Comparisons[I].RightExpr,
          ' ligne ',Pipeline.Comparisons[I].LineNo);
End;

Procedure TraceBranches;
Var
 I:Integer;
 Target:String;
Begin
 If Not(Options.Verbose or Options.Diagnostic)Then Exit;
 WriteLn('IR     : branchements ',Pipeline.BranchCount,
         ', ignores ',Pipeline.SkippedBranchCount);
 For I:=1 To Pipeline.BranchCount Do Begin
  If Pipeline.Branches[I].LabelIndex>0 Then
   Target:=Pipeline.Symbols[Pipeline.Branches[I].LabelIndex].AsmName
  Else
   Target:='?';
  WriteLn('IR     : ',Pipeline.Branches[I].UnitName,' ',
          BranchKindName(Pipeline.Branches[I].Kind),' ',
          Pipeline.Branches[I].LabelValue,' -> ',Target,
          ' ligne ',Pipeline.Branches[I].LineNo);
 End;
End;

Function CoffSectionFlagsText(Section:TAsmSection):String;
Begin
 Case Section Of
  AS_TEXT:CoffSectionFlagsText:='code/read/execute';
  AS_DATA:CoffSectionFlagsText:='init-data/read/write';
  AS_BSS:CoffSectionFlagsText:='uninit/read/write';
  Else CoffSectionFlagsText:='aucun';
 End;
End;

Function CoffSectionFlagsLo(Section:TAsmSection):Word;
Begin
 Case Section Of
  AS_TEXT:CoffSectionFlagsLo:=COFF_TEXT_FLAGS_LO;
  AS_DATA:CoffSectionFlagsLo:=COFF_DATA_FLAGS_LO;
  AS_BSS:CoffSectionFlagsLo:=COFF_BSS_FLAGS_LO;
  Else CoffSectionFlagsLo:=0;
 End;
End;

Function CoffSectionFlagsHi(Section:TAsmSection):Word;
Begin
 Case Section Of
  AS_TEXT:CoffSectionFlagsHi:=COFF_TEXT_FLAGS_HI;
  AS_DATA:CoffSectionFlagsHi:=COFF_DATA_FLAGS_HI;
  AS_BSS:CoffSectionFlagsHi:=COFF_BSS_FLAGS_HI;
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

Function CoffRelocName(RelocKind:TCoffRelocKind):String;
Begin
 Case RelocKind Of
  CR_DIR32:CoffRelocName:='DIR32 adresse absolue 32 bits';
  CR_REL32:CoffRelocName:='REL32 deplacement relatif 32 bits';
  Else CoffRelocName:='relocation inconnue';
 End;
End;

Function CoffSectionRec(Section:TAsmSection):TCoffSectionRec;
Begin
 CoffSectionRec.AsmSection:=Section;
 CoffSectionRec.Name:=SectionName(Section);
 CoffSectionRec.FlagsText:=CoffSectionFlagsText(Section);
 CoffSectionRec.AlignBytes:=SectionAlign(Section);
 CoffSectionRec.FlagsLo:=CoffSectionFlagsLo(Section);
 CoffSectionRec.FlagsHi:=CoffSectionFlagsHi(Section);
End;

Function SanitizeAsmName(S:String):String;
Var
 I:Integer;
 C:Char;
Begin
 SanitizeAsmName:='';
 For I:=1 To Length(S)Do Begin
  C:=UpCase(S[I]);
  If((C>='A')and(C<='Z'))or((C>='0')and(C<='9'))or(C='_')Then
   SanitizeAsmName:=SanitizeAsmName+C
  Else
   SanitizeAsmName:=SanitizeAsmName+'_';
 End;
 If SanitizeAsmName='' Then SanitizeAsmName:='NONAME';
 If(SanitizeAsmName[1]>='0')and(SanitizeAsmName[1]<='9')Then
  SanitizeAsmName:='_'+SanitizeAsmName;
End;

Function MakeWin32Label(Prefix,Name:String):String;
Begin
 MakeWin32Label:=Prefix+SanitizeAsmName(Name);
End;

Function MakeFortranLabel(LabelNum:LongInt):String;
Begin
 MakeFortranLabel:=USER_LABEL_PREFIX+IntToString(LabelNum);
End;

Function MakeInternalLabel(Index:LongInt):String;
Begin
 MakeInternalLabel:=INTERNAL_LABEL_PREFIX+IntToString(Index);
End;

Function CondName(Cond:T386Condition):String;
Begin
 Case Cond Of
  CC_E:CondName:='e';
  CC_NE:CondName:='ne';
  CC_L:CondName:='l';
  CC_LE:CondName:='le';
  CC_G:CondName:='g';
  CC_GE:CondName:='ge';
  Else CondName:='e';
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

Function FortranArgAddressRef(ParamIndex:Integer):String;
Begin
 If ParamIndex<1 Then ParamIndex:=1;
 FortranArgAddressRef:=StackRef(R_EBP,
  I386_ARG_BASE_OFFSET+((ParamIndex-1)*I386_STACK_SLOT_SIZE));
End;

Function LocalVarRef(LocalOffset:Integer):String;
Begin
 If LocalOffset>0 Then LocalOffset:=-LocalOffset;
 LocalVarRef:=StackRef(R_EBP,LocalOffset);
End;

Function DefaultOutputExt:String;
Begin
 If Options.OutputMode=OM_OBJ Then DefaultOutputExt:='.obj'
  Else DefaultOutputExt:='.exe';
End;

Function HasExtension(S:String):Boolean;
Var
 I:Integer;
Begin
 HasExtension:=False;
 For I:=Length(S) DownTo 1 Do Begin
  If S[I]='.' Then Begin
   HasExtension:=True;
   Exit;
  End;
  If(S[I]='\')or(S[I]='/')or(S[I]=':')Then Exit;
 End;
End;

Function DefaultOutputName(SourceName:String):String;
Var
 I,LastDot:Integer;
Begin
 LastDot:=0;
 For I:=Length(SourceName) DownTo 1 Do Begin
  If SourceName[I]='.' Then Begin
   LastDot:=I;
   Break;
  End;
  If(SourceName[I]='\')or(SourceName[I]='/')or(SourceName[I]=':')Then Break;
 End;
 If LastDot>0 Then DefaultOutputName:=Copy(SourceName,1,LastDot-1)+DefaultOutputExt
  Else DefaultOutputName:=SourceName+DefaultOutputExt;
End;

Function ChangeExtension(FileName,NewExt:String):String;
Var
 I,LastDot:Integer;
Begin
 LastDot:=0;
 For I:=Length(FileName) DownTo 1 Do Begin
  If FileName[I]='.' Then Begin
   LastDot:=I;
   Break;
  End;
  If(FileName[I]='\')or(FileName[I]='/')or(FileName[I]=':')Then Break;
 End;
 If LastDot>0 Then ChangeExtension:=Copy(FileName,1,LastDot-1)+NewExt
  Else ChangeExtension:=FileName+NewExt;
End;

Function FileExistsName(FileName:String):Boolean;
Var
 F:File;
Begin
 Assign(F,FileName);
 Reset(F,1);
 FileExistsName:=IOResult=0;
 If FileExistsName Then Close(F);
 IOResult;
End;

Function FileExtension(FileName:String):String;
Var
 I:Integer;
Begin
 FileExtension:='';
 For I:=Length(FileName) DownTo 1 Do Begin
  If FileName[I]='.' Then Begin
   FileExtension:=UpperStr(Copy(FileName,I,Length(FileName)-I+1));
   Exit;
  End;
  If(FileName[I]='\')or(FileName[I]='/')or(FileName[I]=':')Then Exit;
 End;
End;

Function PadRight(S:String;MinLen:Integer):String;
Begin
 PadRight:=S;
 While Length(PadRight)<MinLen Do PadRight:=PadRight+' ';
End;

Function TrimRightStr(S:String):String;
Begin
 While(Length(S)>0)and(S[Length(S)]=' ')Do Delete(S,Length(S),1);
 TrimRightStr:=S;
End;

Function TrimStr(S:String):String;
Begin
 While(Length(S)>0)and(S[1]=' ')Do Delete(S,1,1);
 TrimStr:=TrimRightStr(S);
End;

Function IsBlankStr(S:String):Boolean;
Begin
 IsBlankStr:=TrimStr(S)='';
End;

Function FixedCommentLine(S:String):Boolean;
Var
 C:Char;
Begin
 If Length(S)=0 Then Begin
  FixedCommentLine:=False;
  Exit;
 End;
 C:=UpCase(S[1]);
 FixedCommentLine:=(C='C')or(C='*');
End;

Function FixedLabelValue(S:String;Var LabelValue:Integer):Boolean;
Var
 I:Integer;
 C:Char;
 SawDigit:Boolean;
Begin
 FixedLabelValue:=False;
 LabelValue:=0;
 SawDigit:=False;
 S:=PadRight(S,F77_FIXED_LABEL_END);
 For I:=1 To F77_FIXED_LABEL_END Do Begin
  C:=S[I];
  If C=' ' Then Begin
  End
  Else If(C>='0')and(C<='9')Then Begin
   SawDigit:=True;
   LabelValue:=(LabelValue*10)+(Ord(C)-Ord('0'));
  End
  Else Exit;
 End;
 FixedLabelValue:=SawDigit;
End;

Function FixedLineKindOf(S:String):TFixedLineKind;
Begin
 If IsBlankStr(S)Then FixedLineKindOf:=FLK_BLANK
  Else If FixedCommentLine(S)Then FixedLineKindOf:=FLK_COMMENT
  Else Begin
   S:=PadRight(S,F77_FIXED_CONT_COL);
   If(S[F77_FIXED_CONT_COL]<>' ')and(S[F77_FIXED_CONT_COL]<>'0')Then
    FixedLineKindOf:=FLK_CONTINUATION
   Else
    FixedLineKindOf:=FLK_INITIAL;
  End;
End;

Function FixedStmtText(S:String):String;
Begin
 S:=PadRight(S,F77_FIXED_TEXT_START-1);
 If Length(S)>F77_FIXED_TEXT_END Then S:=Copy(S,1,F77_FIXED_TEXT_END);
 If Length(S)>=F77_FIXED_TEXT_START Then
  FixedStmtText:=TrimRightStr(Copy(S,F77_FIXED_TEXT_START,
   F77_FIXED_TEXT_END-F77_FIXED_TEXT_START+1))
 Else
  FixedStmtText:='';
End;

Function FixedLineKindName(Kind:TFixedLineKind):String;
Begin
 Case Kind Of
  FLK_COMMENT:FixedLineKindName:='commentaire';
  FLK_INITIAL:FixedLineKindName:='initiale';
  FLK_CONTINUATION:FixedLineKindName:='continuation';
  FLK_BLANK:FixedLineKindName:='blanche';
  Else FixedLineKindName:='inconnue';
 End;
End;

Function StmtKeyword(Stmt:String):String;
Var
 I:Integer;
Begin
 Stmt:=TrimStr(UpperStr(Stmt));
 I:=1;
 While(I<=Length(Stmt))and(Stmt[I]>' ')and(Stmt[I]<>'(')and
      (Stmt[I]<>',')and(Stmt[I]<>'=')Do Inc(I);
 StmtKeyword:=Copy(Stmt,1,I-1);
End;

Function StmtStartsWith(Stmt,Keyword:String):Boolean;
Var
 S:String;
 K:String;
 NextChar:Char;
Begin
 S:=TrimStr(UpperStr(Stmt));
 K:=UpperStr(Keyword);
 StmtStartsWith:=False;
 If Copy(S,1,Length(K))<>K Then Exit;
 If Length(S)=Length(K)Then Begin
  StmtStartsWith:=True;
  Exit;
 End;
 NextChar:=S[Length(K)+1];
 StmtStartsWith:=(NextChar=' ')or(NextChar='(')or(NextChar=',')or
                 (NextChar='=')or(NextChar='*');
End;

Function ParserError(Msg:String;LineNo:Integer):Boolean;Forward;

Function IsIdentStart(C:Char):Boolean;
Begin
 IsIdentStart:=((C>='A')and(C<='Z'))or((C>='a')and(C<='z'))or(C='_');
End;

Function IsIdentChar(C:Char):Boolean;
Begin
 IsIdentChar:=IsIdentStart(C)or((C>='0')and(C<='9'));
End;

Function F77ImplicitType(Name:String):TF77DataType;
Var
 C:Char;
Begin
 Name:=UpperStr(TrimStr(Name));
 If Name='' Then Begin
  F77ImplicitType:=FT_NONE;
  Exit;
 End;
 C:=Name[1];
 If(C>='I')and(C<='N')Then F77ImplicitType:=FT_INTEGER
  Else F77ImplicitType:=FT_REAL;
End;

Function FirstIdentAfterKeyword(Stmt,Keyword:String):String;
Var
 S:String;
 I:Integer;
 Start:Integer;
Begin
 S:=TrimStr(Stmt);
 I:=Length(Keyword)+1;
 While(I<=Length(S))and(S[I]<=' ')Do Inc(I);
 Start:=I;
 If(Start<=Length(S))and IsIdentStart(S[Start])Then Begin
  Inc(I);
  While(I<=Length(S))and IsIdentChar(S[I])Do Inc(I);
  FirstIdentAfterKeyword:=UpperStr(Copy(S,Start,I-Start));
 End
 Else FirstIdentAfterKeyword:='';
End;

Function FindSymbol(UnitName,Name:String):Integer;
Var
 I:Integer;
 U:String;
 N:String;
Begin
 U:=UpperStr(UnitName);
 N:=UpperStr(Name);
 FindSymbol:=0;
 For I:=1 To Pipeline.SymbolCount Do
  If(Pipeline.Symbols[I].UnitName=U)and(Pipeline.Symbols[I].Name=N)Then Begin
   FindSymbol:=I;
   Exit;
  End;
End;

Function FindVarSymbol(UnitName,Name:String):Integer;
Var
 Idx:Integer;
Begin
 Idx:=FindSymbol(UnitName,Name);
 If(Idx>0)and((Pipeline.Symbols[Idx].Kind=SK_LOCAL)or
   (Pipeline.Symbols[Idx].Kind=SK_PARAM))Then
  FindVarSymbol:=Idx
 Else
  FindVarSymbol:=0;
End;

Function IsIntegerLiteral(S:String;Var Value:LongInt):Boolean;
Var
 I:Integer;
 Code:Integer;
Begin
 S:=TrimStr(S);
 IsIntegerLiteral:=False;
 If S='' Then Exit;
 I:=1;
 If(S[I]='+')or(S[I]='-')Then Inc(I);
 If I>Length(S)Then Exit;
 While I<=Length(S)Do Begin
  If(S[I]<'0')or(S[I]>'9')Then Exit;
  Inc(I);
 End;
 Val(S,Value,Code);
 IsIntegerLiteral:=Code=0;
End;

Function IsPlainIdentifier(S:String):Boolean;
Var
 I:Integer;
Begin
 S:=TrimStr(S);
 IsPlainIdentifier:=False;
 If(S='')or Not IsIdentStart(S[1])Then Exit;
 For I:=2 To Length(S)Do
  If Not IsIdentChar(S[I])Then Exit;
 IsPlainIdentifier:=True;
End;

Function IsIntegerExprText(UnitName,Expr:String):Boolean;
Var
 I:Integer;
 Start:Integer;
 Depth:Integer;
 Name:String;
 Idx:Integer;
 LastWasOperand:Boolean;
 SawOperand:Boolean;
Begin
 IsIntegerExprText:=False;
 Expr:=UpperStr(TrimStr(Expr));
 If Expr='' Then Exit;
 I:=1;
 Depth:=0;
 LastWasOperand:=False;
 SawOperand:=False;
 While I<=Length(Expr) Do Begin
  If Expr[I]<=' 'Then Inc(I)
  Else If Expr[I]='('Then Begin
   Inc(Depth);
   LastWasOperand:=False;
   Inc(I);
  End
  Else If Expr[I]=')'Then Begin
   Dec(Depth);
   If Depth<0 Then Exit;
   LastWasOperand:=True;
   Inc(I);
  End
  Else If(Expr[I]='+')or(Expr[I]='-')Then Begin
   If LastWasOperand Then LastWasOperand:=False;
   Inc(I);
  End
  Else If Expr[I]='*'Then Begin
   If Not LastWasOperand Then Exit;
   LastWasOperand:=False;
   Inc(I);
  End
  Else If(Expr[I]>='0')and(Expr[I]<='9')Then Begin
   While(I<=Length(Expr))and(Expr[I]>='0')and(Expr[I]<='9')Do Inc(I);
   LastWasOperand:=True;
   SawOperand:=True;
  End
  Else If IsIdentStart(Expr[I])Then Begin
   Start:=I;
   Inc(I);
   While(I<=Length(Expr))and IsIdentChar(Expr[I])Do Inc(I);
   Name:=Copy(Expr,Start,I-Start);
   Idx:=FindVarSymbol(UnitName,Name);
   If(Idx=0)or(Pipeline.Symbols[Idx].DType<>FT_INTEGER)Then Exit;
   LastWasOperand:=True;
   SawOperand:=True;
  End
  Else Exit;
 End;
 IsIntegerExprText:=(Depth=0)and SawOperand and LastWasOperand;
End;

Function LocalBytesUsed(UnitName:String):Integer;
Var
 I:Integer;
 Sum:Integer;
Begin
 UnitName:=UpperStr(UnitName);
 Sum:=0;
 For I:=1 To Pipeline.SymbolCount Do
  If(Pipeline.Symbols[I].UnitName=UnitName)and
    (Pipeline.Symbols[I].Kind=SK_LOCAL)Then
   Sum:=Sum+Pipeline.Symbols[I].SizeBytes;
 LocalBytesUsed:=Sum;
End;

Function SymbolAsmName(UnitName,Name:String;Kind:TF77SymbolKind;
                       LabelValue:LongInt):String;
Begin
 Case Kind Of
  SK_PROC:SymbolAsmName:=MakeWin32Label(USER_PROC_PREFIX,Name);
  SK_LABEL:SymbolAsmName:=MakeWin32Label(USER_LABEL_PREFIX,
   UnitName+'_'+IntToString(LabelValue));
  SK_STATIC:SymbolAsmName:=MakeWin32Label(USER_VAR_PREFIX,UnitName+'_'+Name);
  Else SymbolAsmName:=MakeWin32Label(USER_VAR_PREFIX,UnitName+'_'+Name);
 End;
End;

Procedure CountNewSymbolKind(Kind:TF77SymbolKind);
Begin
 Case Kind Of
  SK_LOCAL:Inc(Pipeline.LocalVarCount);
  SK_STATIC:Inc(Pipeline.StaticVarCount);
  SK_PARAM:Inc(Pipeline.ParamCount);
  SK_PROC:Inc(Pipeline.ProcCount);
  SK_LABEL:Inc(Pipeline.SymbolLabelCount);
 End;
End;

Function SetSymbolKind(Idx:Integer;Kind:TF77SymbolKind;
                       ParamIndex:Integer;LabelValue:LongInt):Boolean;
Begin
 SetSymbolKind:=True;
 If(Idx<1)or(Idx>Pipeline.SymbolCount)Then Exit;
 If Pipeline.Symbols[Idx].Kind=Kind Then Begin
  If Kind=SK_PARAM Then Begin
   Pipeline.Symbols[Idx].ParamIndex:=ParamIndex;
   Pipeline.Symbols[Idx].Offset:=I386_ARG_BASE_OFFSET+
    ((ParamIndex-1)*I386_STACK_SLOT_SIZE);
  End;
  Exit;
 End;
 Case Pipeline.Symbols[Idx].Kind Of
  SK_LOCAL:Dec(Pipeline.LocalVarCount);
  SK_STATIC:Dec(Pipeline.StaticVarCount);
  SK_PARAM:Dec(Pipeline.ParamCount);
  SK_PROC:Dec(Pipeline.ProcCount);
  SK_LABEL:Dec(Pipeline.SymbolLabelCount);
 End;
 Pipeline.Symbols[Idx].Kind:=Kind;
 CountNewSymbolKind(Kind);
 Pipeline.Symbols[Idx].ParamIndex:=ParamIndex;
 Pipeline.Symbols[Idx].LabelValue:=LabelValue;
 Pipeline.Symbols[Idx].AsmName:=SymbolAsmName(Pipeline.Symbols[Idx].UnitName,
  Pipeline.Symbols[Idx].Name,Kind,LabelValue);
 If Kind=SK_PARAM Then
  Pipeline.Symbols[Idx].Offset:=I386_ARG_BASE_OFFSET+
   ((ParamIndex-1)*I386_STACK_SLOT_SIZE)
 Else If Kind=SK_LOCAL Then
  Pipeline.Symbols[Idx].Offset:=-(LocalBytesUsed(Pipeline.Symbols[Idx].UnitName))
 Else
  Pipeline.Symbols[Idx].Offset:=0;
End;

Function DeclareSymbolKind(UnitName,Name:String;Kind:TF77SymbolKind;
                           DType:TF77DataType;ExplicitType:Boolean;
                           ParamIndex:Integer;LabelValue:LongInt;
                           LineNo:Integer):Boolean;
Var
 Idx:Integer;
 Size:Integer;
Begin
 DeclareSymbolKind:=True;
 UnitName:=UpperStr(TrimStr(UnitName));
 Name:=UpperStr(TrimStr(Name));
 If(Name='')or(UnitName='')Then Exit;
 If(DType=FT_NONE)and((Kind=SK_LOCAL)or(Kind=SK_PARAM))Then
  DType:=F77ImplicitType(Name);
 Size:=F77TypeSize(DType,0);
 If(Size=0)and((Kind=SK_LOCAL)or(Kind=SK_PARAM))Then
  Size:=I386_STACK_SLOT_SIZE;
 Idx:=FindSymbol(UnitName,Name);
 If Idx=0 Then Begin
  If Pipeline.SymbolCount>=F77_MAX_SYMBOLS Then Begin
   DeclareSymbolKind:=ParserError('table des symboles pleine',LineNo);
   Exit;
  End;
  Inc(Pipeline.SymbolCount);
  Idx:=Pipeline.SymbolCount;
  Pipeline.Symbols[Idx].UnitName:=UnitName;
  Pipeline.Symbols[Idx].Name:=Name;
  Pipeline.Symbols[Idx].Kind:=Kind;
  Pipeline.Symbols[Idx].DType:=DType;
  Pipeline.Symbols[Idx].ExplicitType:=ExplicitType;
  Pipeline.Symbols[Idx].AsmName:=SymbolAsmName(UnitName,Name,Kind,LabelValue);
  Pipeline.Symbols[Idx].SizeBytes:=Size;
  Pipeline.Symbols[Idx].ParamIndex:=ParamIndex;
  Pipeline.Symbols[Idx].LabelValue:=LabelValue;
  Pipeline.Symbols[Idx].LineNo:=LineNo;
  If Kind=SK_PARAM Then
   Pipeline.Symbols[Idx].Offset:=I386_ARG_BASE_OFFSET+
    ((ParamIndex-1)*I386_STACK_SLOT_SIZE)
  Else If Kind=SK_LOCAL Then
   Pipeline.Symbols[Idx].Offset:=-LocalBytesUsed(UnitName)
  Else
   Pipeline.Symbols[Idx].Offset:=0;
  CountNewSymbolKind(Kind);
  If(Kind=SK_LOCAL)or(Kind=SK_PARAM)Then Begin
   If ExplicitType Then Inc(Pipeline.ExplicitTypeCount)
   Else If DType=FT_INTEGER Then Inc(Pipeline.ImplicitIntegerCount)
   Else If DType=FT_REAL Then Inc(Pipeline.ImplicitRealCount);
  End;
 End
 Else Begin
  If(Kind=SK_PARAM)or(Kind=SK_PROC)or(Kind=SK_LABEL)Then
   SetSymbolKind(Idx,Kind,ParamIndex,LabelValue);
  If ExplicitType and((Pipeline.Symbols[Idx].Kind=SK_LOCAL)or
     (Pipeline.Symbols[Idx].Kind=SK_PARAM))Then Begin
   If Not Pipeline.Symbols[Idx].ExplicitType Then Begin
    If Pipeline.Symbols[Idx].DType=FT_INTEGER Then Dec(Pipeline.ImplicitIntegerCount)
    Else If Pipeline.Symbols[Idx].DType=FT_REAL Then Dec(Pipeline.ImplicitRealCount);
   End;
   If Pipeline.Symbols[Idx].DType<>DType Then Begin
    Pipeline.Symbols[Idx].DType:=DType;
    Pipeline.Symbols[Idx].SizeBytes:=F77TypeSize(DType,0);
   End;
   If Not Pipeline.Symbols[Idx].ExplicitType Then Begin
    Pipeline.Symbols[Idx].ExplicitType:=True;
    Inc(Pipeline.ExplicitTypeCount);
   End;
  End;
 End;
End;

Function DeclareSymbol(UnitName,Name:String;DType:TF77DataType;
                       ExplicitType:Boolean;LineNo:Integer):Boolean;
Begin
 DeclareSymbol:=DeclareSymbolKind(UnitName,Name,SK_LOCAL,DType,
  ExplicitType,0,0,LineNo);
End;

Function DeclareParamSymbol(UnitName,Name:String;ParamIndex:Integer;
                            LineNo:Integer):Boolean;
Begin
 DeclareParamSymbol:=DeclareSymbolKind(UnitName,Name,SK_PARAM,FT_NONE,
  False,ParamIndex,0,LineNo);
End;

Function DeclareProcedureSymbol(Name:String;LineNo:Integer):Boolean;
Begin
 DeclareProcedureSymbol:=DeclareSymbolKind('$GLOBAL',Name,SK_PROC,FT_NONE,
  True,0,0,LineNo);
End;

Function DeclareLabelSymbol(UnitName:String;LabelValue:LongInt;
                            LineNo:Integer):Boolean;
Begin
 DeclareLabelSymbol:=DeclareSymbolKind(UnitName,IntToString(LabelValue),
  SK_LABEL,FT_NONE,True,0,LabelValue,LineNo);
End;

Function IsReservedIdent(Name:String):Boolean;
Begin
 Name:=UpperStr(Name);
 IsReservedIdent:=(Name='PROGRAM')or(Name='SUBROUTINE')or(Name='END')or
                  (Name='RETURN')or(Name='INTEGER')or(Name='CALL')or
                  (Name='PRINT')or(Name='DO')or(Name='CONTINUE')or
                  (Name='IF')or(Name='THEN')or(Name='GOTO')or
                  (Name='GO')or(Name='TO');
End;

Function AddIdentifiersFromText(UnitName,Text:String;LineNo:Integer):Boolean;
Var
 I:Integer;
 Start:Integer;
 Name:String;
 InString:Boolean;
Begin
 AddIdentifiersFromText:=True;
 Text:=UpperStr(Text);
 I:=1;
 InString:=False;
 While I<=Length(Text) Do Begin
  If Text[I]=''''Then Begin
   InString:=Not InString;
   Inc(I);
  End
  Else If InString Then Inc(I)
  Else If Text[I]='.'Then Begin
   Inc(I);
   While(I<=Length(Text))and(Text[I]<>'.')Do Inc(I);
   If(I<=Length(Text))and(Text[I]='.')Then Inc(I);
  End
  Else If IsIdentStart(Text[I])Then Begin
   Start:=I;
   Inc(I);
   While(I<=Length(Text))and IsIdentChar(Text[I])Do Inc(I);
   Name:=Copy(Text,Start,I-Start);
   If Not IsReservedIdent(Name)Then
    If Not DeclareSymbol(UnitName,Name,FT_NONE,False,LineNo)Then Begin
     AddIdentifiersFromText:=False;
     Exit;
    End;
  End
  Else Inc(I);
 End;
End;

Function TextBetweenParens(S:String):String;
Var
 P1:Integer;
 P2:Integer;
Begin
 P1:=Pos('(',S);
 P2:=Length(S);
 While(P2>P1)and(S[P2]<>')')Do Dec(P2);
 If(P1>0)and(P2>P1)Then TextBetweenParens:=Copy(S,P1+1,P2-P1-1)
  Else TextBetweenParens:='';
End;

Function AddExplicitIntegerDecl(UnitName,StmtText:String;LineNo:Integer):Boolean;
Var
 S:String;
 I:Integer;
 Start:Integer;
 Name:String;
Begin
 AddExplicitIntegerDecl:=True;
 S:=TrimStr(StmtText);
 I:=Length('INTEGER')+1;
 If(I<=Length(S))and(S[I]='*')Then Begin
  Inc(I);
  While(I<=Length(S))and(S[I]>='0')and(S[I]<='9')Do Inc(I);
 End;
 While I<=Length(S) Do Begin
  If IsIdentStart(S[I])Then Begin
   Start:=I;
   Inc(I);
   While(I<=Length(S))and IsIdentChar(S[I])Do Inc(I);
   Name:=Copy(S,Start,I-Start);
   If Not DeclareSymbol(UnitName,Name,FT_INTEGER,True,LineNo)Then Begin
    AddExplicitIntegerDecl:=False;
    Exit;
   End;
  End
  Else Inc(I);
 End;
End;

Function AddDummyParams(UnitName,ArgText:String;LineNo:Integer):Boolean;
Var
 I:Integer;
 Start:Integer;
 Name:String;
 ParamIndex:Integer;
Begin
 AddDummyParams:=True;
 I:=1;
 ParamIndex:=0;
 ArgText:=UpperStr(ArgText);
 While I<=Length(ArgText) Do Begin
  If IsIdentStart(ArgText[I])Then Begin
   Start:=I;
   Inc(I);
   While(I<=Length(ArgText))and IsIdentChar(ArgText[I])Do Inc(I);
   Name:=Copy(ArgText,Start,I-Start);
   Inc(ParamIndex);
   If Not DeclareParamSymbol(UnitName,Name,ParamIndex,LineNo)Then Begin
    AddDummyParams:=False;
    Exit;
   End;
  End
  Else Inc(I);
 End;
End;

Function AddIntegerAssignment(UnitName,StmtText:String;LineNo:Integer):Boolean;
Var
 EqPos:Integer;
 Lhs:String;
 Rhs:String;
 DestIdx:Integer;
 SrcIdx:Integer;
 ConstVal:LongInt;
Begin
 AddIntegerAssignment:=True;
 EqPos:=Pos('=',StmtText);
 If EqPos=0 Then Exit;
 Lhs:=UpperStr(TrimStr(Copy(StmtText,1,EqPos-1)));
 Rhs:=UpperStr(TrimStr(Copy(StmtText,EqPos+1,Length(StmtText)-EqPos)));
 If Not IsPlainIdentifier(Lhs)Then Begin
  Inc(Pipeline.SkippedAssignmentCount);
  Exit;
 End;
 DestIdx:=FindVarSymbol(UnitName,Lhs);
 If DestIdx=0 Then Begin
  Inc(Pipeline.SkippedAssignmentCount);
  Exit;
 End;
 If Pipeline.Symbols[DestIdx].DType<>FT_INTEGER Then Begin
  Inc(Pipeline.SkippedAssignmentCount);
  Exit;
 End;
 If Pipeline.AssignmentCount>=F77_MAX_ASSIGNMENTS Then Begin
  AddIntegerAssignment:=ParserError('trop d''affectations INTEGER',LineNo);
  Exit;
 End;
 If IsIntegerLiteral(Rhs,ConstVal)Then Begin
  Inc(Pipeline.AssignmentCount);
  Pipeline.Assignments[Pipeline.AssignmentCount].UnitName:=UpperStr(UnitName);
  Pipeline.Assignments[Pipeline.AssignmentCount].LineNo:=LineNo;
  Pipeline.Assignments[Pipeline.AssignmentCount].DestName:=Lhs;
  Pipeline.Assignments[Pipeline.AssignmentCount].DestIndex:=DestIdx;
  Pipeline.Assignments[Pipeline.AssignmentCount].RhsKind:=ARK_CONST_INT;
  Pipeline.Assignments[Pipeline.AssignmentCount].ConstVal:=ConstVal;
  Pipeline.Assignments[Pipeline.AssignmentCount].SrcName:='';
  Pipeline.Assignments[Pipeline.AssignmentCount].SrcIndex:=0;
  Pipeline.Assignments[Pipeline.AssignmentCount].ExprText:=Rhs;
 End
 Else If IsPlainIdentifier(Rhs)Then Begin
  SrcIdx:=FindVarSymbol(UnitName,Rhs);
  If(SrcIdx=0)or(Pipeline.Symbols[SrcIdx].DType<>FT_INTEGER)Then Begin
   Inc(Pipeline.SkippedAssignmentCount);
   Exit;
  End;
  Inc(Pipeline.AssignmentCount);
  Pipeline.Assignments[Pipeline.AssignmentCount].UnitName:=UpperStr(UnitName);
  Pipeline.Assignments[Pipeline.AssignmentCount].LineNo:=LineNo;
  Pipeline.Assignments[Pipeline.AssignmentCount].DestName:=Lhs;
  Pipeline.Assignments[Pipeline.AssignmentCount].DestIndex:=DestIdx;
  Pipeline.Assignments[Pipeline.AssignmentCount].RhsKind:=ARK_VAR;
  Pipeline.Assignments[Pipeline.AssignmentCount].ConstVal:=0;
  Pipeline.Assignments[Pipeline.AssignmentCount].SrcName:=Rhs;
  Pipeline.Assignments[Pipeline.AssignmentCount].SrcIndex:=SrcIdx;
  Pipeline.Assignments[Pipeline.AssignmentCount].ExprText:=Rhs;
 End
 Else If IsIntegerExprText(UnitName,Rhs)Then Begin
  Inc(Pipeline.AssignmentCount);
  Pipeline.Assignments[Pipeline.AssignmentCount].UnitName:=UpperStr(UnitName);
  Pipeline.Assignments[Pipeline.AssignmentCount].LineNo:=LineNo;
  Pipeline.Assignments[Pipeline.AssignmentCount].DestName:=Lhs;
  Pipeline.Assignments[Pipeline.AssignmentCount].DestIndex:=DestIdx;
  Pipeline.Assignments[Pipeline.AssignmentCount].RhsKind:=ARK_EXPR;
  Pipeline.Assignments[Pipeline.AssignmentCount].ConstVal:=0;
  Pipeline.Assignments[Pipeline.AssignmentCount].SrcName:='';
  Pipeline.Assignments[Pipeline.AssignmentCount].SrcIndex:=0;
  Pipeline.Assignments[Pipeline.AssignmentCount].ExprText:=Rhs;
 End
 Else Inc(Pipeline.SkippedAssignmentCount);
End;

Function RelOpFromText(OpText:String;Var Cond:T386Condition):Boolean;
Begin
 OpText:=UpperStr(OpText);
 RelOpFromText:=True;
 If OpText='.EQ.'Then Cond:=CC_E
 Else If OpText='.NE.'Then Cond:=CC_NE
 Else If OpText='.LT.'Then Cond:=CC_L
 Else If OpText='.LE.'Then Cond:=CC_LE
 Else If OpText='.GT.'Then Cond:=CC_G
 Else If OpText='.GE.'Then Cond:=CC_GE
 Else RelOpFromText:=False;
End;

Function FindFortranRelOp(S:String;Var OpPos,OpLen:Integer;
                          Var Cond:T386Condition):Boolean;
Const
 RelOps : Array[1..6] Of String[4] =
  ('.EQ.','.NE.','.LT.','.LE.','.GT.','.GE.');
Var
 I:Integer;
 P:Integer;
Begin
 FindFortranRelOp:=False;
 S:=UpperStr(S);
 For I:=1 To 6 Do Begin
  P:=Pos(RelOps[I],S);
  If P>0 Then Begin
   OpPos:=P;
   OpLen:=Length(RelOps[I]);
   RelOpFromText(RelOps[I],Cond);
   FindFortranRelOp:=True;
   Exit;
  End;
 End;
End;

Function IfConditionText(StmtText:String):String;
Begin
 IfConditionText:=TextBetweenParens(StmtText);
End;

Function TextAfterIfCondition(StmtText:String):String;
Var
 P1:Integer;
 P2:Integer;
Begin
 TextAfterIfCondition:='';
 P1:=Pos('(',StmtText);
 P2:=Length(StmtText);
 While(P2>P1)and(StmtText[P2]<>')')Do Dec(P2);
 If(P1>0)and(P2>P1)and(P2<Length(StmtText))Then
  TextAfterIfCondition:=TrimStr(Copy(StmtText,P2+1,Length(StmtText)-P2));
End;

Function ParseGotoLabelFromText(Text:String;Var LabelValue:LongInt):Boolean;
Var
 S:String;
 Rest:String;
 I:Integer;
 Code:Integer;
Begin
 ParseGotoLabelFromText:=False;
 S:=TrimStr(UpperStr(Text));
 If StmtStartsWith(S,'GOTO')Then
  Rest:=TrimStr(Copy(S,5,Length(S)-4))
 Else If StmtStartsWith(S,'GO')Then Begin
  Rest:=TrimStr(Copy(S,3,Length(S)-2));
  If Not StmtStartsWith(Rest,'TO')Then Exit;
  Rest:=TrimStr(Copy(Rest,3,Length(Rest)-2));
 End
 Else Exit;
 If Rest=''Then Exit;
 I:=1;
 While(I<=Length(Rest))and(Rest[I]>='0')and(Rest[I]<='9')Do Inc(I);
 If I=1 Then Exit;
 Rest:=Copy(Rest,1,I-1);
 Val(Rest,LabelValue,Code);
 ParseGotoLabelFromText:=Code=0;
End;

Function ParseGotoLabel(StmtText:String;Var LabelValue:LongInt):Boolean;
Begin
 ParseGotoLabel:=ParseGotoLabelFromText(StmtText,LabelValue);
End;

Function ParseIfGotoLabel(StmtText:String;Var LabelValue:LongInt):Boolean;
Begin
 ParseIfGotoLabel:=ParseGotoLabelFromText(TextAfterIfCondition(StmtText),
  LabelValue);
End;

Function AddIntegerComparison(UnitName,StmtText:String;LineNo:Integer;
                              Var ComparisonIndex:Integer):Boolean;
Var
 CondText:String;
 LeftExpr:String;
 RightExpr:String;
 OpPos:Integer;
 OpLen:Integer;
 Cond:T386Condition;
Begin
 AddIntegerComparison:=True;
 ComparisonIndex:=0;
 CondText:=IfConditionText(StmtText);
 If CondText=''Then Begin
  Inc(Pipeline.SkippedComparisonCount);
  Exit;
 End;
 If Not FindFortranRelOp(CondText,OpPos,OpLen,Cond)Then Begin
  Inc(Pipeline.SkippedComparisonCount);
  Exit;
 End;
 LeftExpr:=TrimStr(Copy(CondText,1,OpPos-1));
 RightExpr:=TrimStr(Copy(CondText,OpPos+OpLen,Length(CondText)-(OpPos+OpLen)+1));
 If(Not IsIntegerExprText(UnitName,LeftExpr))or
   (Not IsIntegerExprText(UnitName,RightExpr))Then Begin
  Inc(Pipeline.SkippedComparisonCount);
  Exit;
 End;
 If Pipeline.ComparisonCount>=F77_MAX_COMPARISONS Then Begin
  AddIntegerComparison:=ParserError('trop de comparaisons INTEGER',LineNo);
  Exit;
 End;
 Inc(Pipeline.ComparisonCount);
 Pipeline.Comparisons[Pipeline.ComparisonCount].UnitName:=UpperStr(UnitName);
 Pipeline.Comparisons[Pipeline.ComparisonCount].LineNo:=LineNo;
 Pipeline.Comparisons[Pipeline.ComparisonCount].LeftExpr:=UpperStr(LeftExpr);
 Pipeline.Comparisons[Pipeline.ComparisonCount].RelCond:=Cond;
 Pipeline.Comparisons[Pipeline.ComparisonCount].RightExpr:=UpperStr(RightExpr);
 Pipeline.Comparisons[Pipeline.ComparisonCount].BranchIndex:=0;
 ComparisonIndex:=Pipeline.ComparisonCount;
End;

Function AddBranch(UnitName:String;LineNo:Integer;Kind:TF77BranchKind;
                   LabelValue:LongInt;ComparisonIndex:Integer):Boolean;
Begin
 AddBranch:=True;
 If Pipeline.BranchCount>=F77_MAX_BRANCHES Then Begin
  AddBranch:=ParserError('trop de branchements GOTO',LineNo);
  Exit;
 End;
 Inc(Pipeline.BranchCount);
 Pipeline.Branches[Pipeline.BranchCount].UnitName:=UpperStr(UnitName);
 Pipeline.Branches[Pipeline.BranchCount].LineNo:=LineNo;
 Pipeline.Branches[Pipeline.BranchCount].Kind:=Kind;
 Pipeline.Branches[Pipeline.BranchCount].LabelValue:=LabelValue;
 Pipeline.Branches[Pipeline.BranchCount].LabelIndex:=0;
 Pipeline.Branches[Pipeline.BranchCount].ComparisonIndex:=ComparisonIndex;
 If(ComparisonIndex>0)and(ComparisonIndex<=Pipeline.ComparisonCount)Then
  Pipeline.Comparisons[ComparisonIndex].BranchIndex:=Pipeline.BranchCount;
End;

Function AddGotoBranch(UnitName,StmtText:String;LineNo:Integer):Boolean;
Var
 LabelValue:LongInt;
Begin
 AddGotoBranch:=True;
 If Not ParseGotoLabel(StmtText,LabelValue)Then Begin
  Inc(Pipeline.SkippedBranchCount);
  AddGotoBranch:=ParserError('GOTO numerique attendu',LineNo);
  Exit;
 End;
 AddGotoBranch:=AddBranch(UnitName,LineNo,BK_GOTO,LabelValue,0);
End;

Function AddIfGotoBranch(UnitName,StmtText:String;LineNo:Integer;
                         ComparisonIndex:Integer):Boolean;
Var
 LabelValue:LongInt;
Begin
 AddIfGotoBranch:=True;
 If Not ParseIfGotoLabel(StmtText,LabelValue)Then Begin
  Inc(Pipeline.SkippedBranchCount);
  Exit;
 End;
 If ComparisonIndex=0 Then Begin
  AddIfGotoBranch:=ParserError('IF GOTO sans comparaison relationnelle INTEGER',
   LineNo);
  Exit;
 End;
 AddIfGotoBranch:=AddBranch(UnitName,LineNo,BK_IF_GOTO,LabelValue,
 ComparisonIndex);
End;

Function ResolveBranchLabels:Boolean;
Var
 I:Integer;
 SymIdx:Integer;
Begin
 ResolveBranchLabels:=True;
 For I:=1 To Pipeline.BranchCount Do Begin
  SymIdx:=FindSymbol(Pipeline.Branches[I].UnitName,
   IntToString(Pipeline.Branches[I].LabelValue));
  If(SymIdx=0)or(Pipeline.Symbols[SymIdx].Kind<>SK_LABEL)Then Begin
   ResolveBranchLabels:=ParserError('label '+
    IntToString(Pipeline.Branches[I].LabelValue)+
    ' reference mais non defini',Pipeline.Branches[I].LineNo);
   Exit;
  End;
  Pipeline.Branches[I].LabelIndex:=SymIdx;
 End;
End;

Function ParserError(Msg:String;LineNo:Integer):Boolean;
Begin
 Inc(Pipeline.ParserErrors);
 WriteLn('Erreur parser ligne ',LineNo,': ',Msg);
 ParserError:=False;
End;

Function IsFortranSourceName(FileName:String):Boolean;
Var
 Ext:String;
Begin
 Ext:=FileExtension(FileName);
 IsFortranSourceName:=(Ext='.F')or(Ext='.FOR')or(Ext='.F77');
End;

Function TraceEnabled:Boolean;
Begin
 TraceEnabled:=Options.Verbose or Options.Diagnostic;
End;

Procedure PrintUsage;Begin
 WriteLn('F77CW32 - Cette commande permet de ',
         'lancer le compilateur Fortran 77 pour l''assembleur du microprocesseur ',
         '80386 pour Windows 32 bits.');
 WriteLn;
 WriteLn('Syntaxe : F77CW32 <source.f|source.for|source.f77> [options]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -c, --obj-only     : produire seulement un fichier objet COFF i386 .OBJ');
 WriteLn('  -S, --asm          : produire/conserver aussi le fichier assembleur .ASM');
 WriteLn('  -o <fichier>       : specifier le nom du fichier de sortie');
 WriteLn('  -v, --verbose      : mode verbeux');
 WriteLn('  -d, --diag         : afficher le diagnostic de configuration');
 WriteLn('  -h, --help         : afficher cette aide');
 WriteLn('  --version          : afficher la version');
End;

Procedure PrintVersion;Begin
 WriteLn('F77CW32 ',F77CW32_VERSION);
End;

Procedure InitOptions;Begin
 Options.SourceName:='';
 Options.OutputName:='';
 Options.OutputMode:=OM_EXE;
 Options.EmitAsm:=False;
 Options.Verbose:=False;
 Options.Diagnostic:=False;
End;

Function IsHelpSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsHelpSwitch:=(S='/?')or(S='--HELP')or(S='-H')or(S='/H');
End;

Function IsVersionSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsVersionSwitch:=(S='--VERSION')or(S='-VERSION');
End;

Function IsObjOnlySwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsObjOnlySwitch:=(S='-C')or(S='--OBJ-ONLY')or(S='/C');
End;

Function IsAsmSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsAsmSwitch:=(S='-S')or(S='--ASM')or(S='/S');
End;

Function IsVerboseSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsVerboseSwitch:=(S='-V')or(S='--VERBOSE');
End;

Function IsDiagnosticSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsDiagnosticSwitch:=(S='-D')or(S='--DIAG')or(S='--DIAGNOSTIC');
End;

Function IsOutputSwitch(S:String):Boolean;
Begin
 S:=UpperStr(S);
 IsOutputSwitch:=(S='-O')or(S='--OUTPUT')or(S='/O');
End;

Procedure ValidateCommandLine;
Begin
 If Options.SourceName='' Then Begin
  PrintUsage;
  Halt(1);
 End;
 If Not IsFortranSourceName(Options.SourceName)Then Begin
  WriteLn('Erreur: extension source non supportee: ',Options.SourceName);
  WriteLn('        extensions acceptees: .f, .for, .f77');
  Halt(1);
 End;
 If Not FileExistsName(Options.SourceName)Then Begin
  WriteLn('Erreur: fichier source introuvable: ',Options.SourceName);
  Halt(1);
 End;
 If Options.OutputName='' Then Options.OutputName:=DefaultOutputName(Options.SourceName)
  Else If Not HasExtension(Options.OutputName)Then
   Options.OutputName:=Options.OutputName+DefaultOutputExt;
End;

Procedure PrintDiagnostics;
Begin
 If Not Options.Diagnostic Then Exit;
 WriteLn('Diagnostic F77CW32');
 WriteLn('  Version      : ',F77CW32_VERSION);
 WriteLn('  Source       : ',Options.SourceName);
 WriteLn('  Sortie       : ',Options.OutputName);
 If Options.OutputMode=OM_OBJ Then WriteLn('  Mode sortie  : OBJ seulement')
  Else WriteLn('  Mode sortie  : EXE Win32');
 If Options.EmitAsm Then WriteLn('  ASM explicite: oui')
  Else WriteLn('  ASM explicite: non');
 If Options.Verbose Then WriteLn('  Verbeux      : oui')
  Else WriteLn('  Verbeux      : non');
End;

Procedure ParseCommandLine;
Var
 I:Integer;
 S:String;
Begin
 I:=1;
 While I<=ParamCount Do Begin
  S:=ParamStr(I);
  If IsHelpSwitch(S)Then Begin
   PrintUsage;
   Halt;
  End
  Else If IsVersionSwitch(S)Then Begin
   PrintVersion;
   Halt;
  End
  Else If IsObjOnlySwitch(S) Then Options.OutputMode:=OM_OBJ
  Else If IsAsmSwitch(S) Then Options.EmitAsm:=True
  Else If IsVerboseSwitch(S) Then Options.Verbose:=True
  Else If IsDiagnosticSwitch(S) Then Options.Diagnostic:=True
  Else If IsOutputSwitch(S) Then Begin
   Inc(I);
   If I>ParamCount Then Begin
    WriteLn('Erreur: option ',S,' sans nom de fichier.');
    Halt(1);
   End;
   Options.OutputName:=ParamStr(I);
  End
  Else If(Length(S)>0)and(S[1]='-')Then Begin
   WriteLn('Erreur: option inconnue: ',S);
   Halt(1);
  End
  Else If Options.SourceName='' Then Options.SourceName:=S
  Else Begin
   WriteLn('Erreur: fichier source en trop: ',S);
   Halt(1);
  End;
  Inc(I);
 End;

 ValidateCommandLine;
End;

Procedure PrintSelectedOutputs;
Begin
 If Not TraceEnabled Then Exit;
 WriteLn('Source : ',Options.SourceName);
 If Options.OutputMode=OM_OBJ Then WriteLn('Mode   : OBJ seulement')
  Else WriteLn('Mode   : EXE Win32 par defaut');
 WriteLn('Sortie : ',Options.OutputName);
 If Options.EmitAsm Then WriteLn('ASM    : oui')
  Else WriteLn('ASM    : non');
 If Options.Diagnostic Then WriteLn('Diag   : oui');
End;

Function StageName(Stage:TCompileStage):String;
Begin
 Case Stage Of
  CS_LOAD_SOURCE:StageName:='source .F';
  CS_LEXER:StageName:='lexer';
  CS_PARSER:StageName:='parser';
  CS_SEMANTIC_TABLES:StageName:='tables semantiques';
  CS_IR:StageName:='IR simple';
  CS_ASM_80386:StageName:='ASM 80386';
  CS_OBJ_COFF:StageName:='OBJ COFF i386';
  CS_EXE_PE32:StageName:='EXE PE32';
  Else StageName:='etape inconnue';
 End;
End;

Procedure TraceStage(Stage:TCompileStage);
Begin
 If TraceEnabled Then WriteLn('Pipeline: ',StageName(Stage));
End;

Procedure InitPipeline;
Begin
 Pipeline.SourceName:=Options.SourceName;
 Pipeline.AsmName:=ChangeExtension(Options.OutputName,'.asm');
 Pipeline.CodeSection:=AS_TEXT;
 Pipeline.DataSection:=AS_DATA;
 Pipeline.BssSection:=AS_BSS;
 Pipeline.CoffFormat.Machine:=COFF_MACHINE_I386;
 Pipeline.CoffFormat.HeaderSize:=COFF_FILE_HEADER_SIZE;
 Pipeline.CoffFormat.SectionHdrSize:=COFF_SECTION_HDR_SIZE;
 Pipeline.CoffFormat.SymbolSize:=COFF_SYMBOL_SIZE;
 Pipeline.CoffFormat.RelocSize:=COFF_RELOC_SIZE;
 Pipeline.SourceLines:=0;
 Pipeline.CommentLines:=0;
 Pipeline.BlankLines:=0;
 Pipeline.InitialLines:=0;
 Pipeline.ContinuationLines:=0;
 Pipeline.LabelCount:=0;
 Pipeline.LogicalLines:=0;
 Pipeline.ProgramCount:=0;
 Pipeline.SubroutineCount:=0;
 Pipeline.EndCount:=0;
 Pipeline.ReturnCount:=0;
 Pipeline.IntegerDeclCount:=0;
 Pipeline.CallCount:=0;
 Pipeline.ParserErrors:=0;
 Pipeline.SymbolCount:=0;
 Pipeline.ExplicitTypeCount:=0;
 Pipeline.ImplicitIntegerCount:=0;
 Pipeline.ImplicitRealCount:=0;
 Pipeline.LocalVarCount:=0;
 Pipeline.StaticVarCount:=0;
 Pipeline.ParamCount:=0;
 Pipeline.ProcCount:=0;
 Pipeline.SymbolLabelCount:=0;
 Pipeline.AssignmentCount:=0;
 Pipeline.SkippedAssignmentCount:=0;
 Pipeline.ComparisonCount:=0;
 Pipeline.SkippedComparisonCount:=0;
 Pipeline.BranchCount:=0;
 Pipeline.SkippedBranchCount:=0;
 If Options.OutputMode=OM_OBJ Then Begin
  Pipeline.ObjName:=Options.OutputName;
  Pipeline.ExeName:='';
 End
 Else Begin
  Pipeline.ObjName:=ChangeExtension(Options.OutputName,'.obj');
  Pipeline.ExeName:=Options.OutputName;
 End;
End;

Function LoadSource:Boolean;
Var
 T:Text;
 Line:String;
 Kind:TFixedLineKind;
 LabelValue:Integer;
Begin
 TraceStage(CS_LOAD_SOURCE);
 LoadSource:=False;
 Assign(T,Pipeline.SourceName);
 Reset(T);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: impossible de lire ',Pipeline.SourceName);
  Exit;
 End;
 While Not Eof(T) Do Begin
  ReadLn(T,Line);
  If IOResult<>0 Then Begin
   WriteLn('Erreur: lecture interrompue dans ',Pipeline.SourceName);
   Close(T);
   Exit;
  End;
  Inc(Pipeline.SourceLines);
  Kind:=FixedLineKindOf(Line);
  Case Kind Of
   FLK_COMMENT:Inc(Pipeline.CommentLines);
   FLK_BLANK:Inc(Pipeline.BlankLines);
   FLK_INITIAL:Begin
    Inc(Pipeline.InitialLines);
    Inc(Pipeline.LogicalLines);
    If FixedLabelValue(Line,LabelValue)Then Inc(Pipeline.LabelCount);
   End;
   FLK_CONTINUATION:Inc(Pipeline.ContinuationLines);
  End;
 End;
 Close(T);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: fermeture impossible de ',Pipeline.SourceName);
  Exit;
 End;
 LoadSource:=True;
End;

Function RunLexer:Boolean;
Begin
 TraceStage(CS_LEXER);
 If TraceEnabled Then Begin
  WriteLn('Lexer  : lignes physiques ',Pipeline.SourceLines);
  WriteLn('Lexer  : initiales ',Pipeline.InitialLines,
          ', continuations ',Pipeline.ContinuationLines,
          ', commentaires ',Pipeline.CommentLines,
          ', blanches ',Pipeline.BlankLines);
  WriteLn('Lexer  : lignes logiques ',Pipeline.LogicalLines,
          ', labels numeriques ',Pipeline.LabelCount);
  WriteLn('Lexer  : format fixe colonnes 1-5 labels, 6 continuation, 7-72 texte');
 End;
 RunLexer:=True;
End;

Function RunParser:Boolean;
Var
 T:Text;
 Line:String;
 LogicalStmt:String;
 Stmt:String;
 Kind:TFixedLineKind;
 LineNo:Integer;
 LabelValue:Integer;
 LogicalLabel:Integer;
 UnitOpen:Boolean;
 CurrentUnit:String;
 CurrentScope:String;

 Function ParseStatement(StmtText:String;StmtLine,StmtLabel:Integer):Boolean;
 Var
  Key:String;
  UnitName:String;
  ArgText:String;
  EqPos:Integer;
  CompIndex:Integer;
 Begin
  ParseStatement:=True;
  StmtText:=TrimStr(StmtText);
  If StmtText='' Then Exit;
  Key:=StmtKeyword(StmtText);
  If(StmtLabel>=0)and UnitOpen Then
   If Not DeclareLabelSymbol(CurrentScope,StmtLabel,StmtLine)Then Begin
    ParseStatement:=False;
    Exit;
   End;
  If Key='PROGRAM'Then Begin
   If UnitOpen Then Begin
    ParseStatement:=ParserError('PROGRAM rencontre avant END de '+CurrentUnit,StmtLine);
    Exit;
   End;
   UnitOpen:=True;
   CurrentUnit:='PROGRAM';
   UnitName:=FirstIdentAfterKeyword(StmtText,'PROGRAM');
   If UnitName='' Then UnitName:='MAIN';
   CurrentScope:=UnitName;
   If Not DeclareProcedureSymbol(CurrentScope,StmtLine)Then Begin
    ParseStatement:=False;
    Exit;
   End;
   Inc(Pipeline.ProgramCount);
  End
  Else If Key='SUBROUTINE'Then Begin
   If UnitOpen Then Begin
    ParseStatement:=ParserError('SUBROUTINE rencontre avant END de '+CurrentUnit,StmtLine);
    Exit;
   End;
   UnitOpen:=True;
   CurrentUnit:='SUBROUTINE';
   UnitName:=FirstIdentAfterKeyword(StmtText,'SUBROUTINE');
   If UnitName='' Then UnitName:='SUBROUTINE';
   CurrentScope:=UnitName;
   If Not DeclareProcedureSymbol(CurrentScope,StmtLine)Then Begin
    ParseStatement:=False;
    Exit;
   End;
   ArgText:=TextBetweenParens(StmtText);
   If ArgText<>'' Then
    If Not AddDummyParams(CurrentScope,ArgText,StmtLine)Then Begin
     ParseStatement:=False;
     Exit;
    End;
   Inc(Pipeline.SubroutineCount);
  End
  Else If Key='END'Then Begin
   If Not UnitOpen Then Begin
    ParseStatement:=ParserError('END sans unite ouverte',StmtLine);
    Exit;
   End;
   UnitOpen:=False;
   CurrentUnit:='';
   CurrentScope:='';
   Inc(Pipeline.EndCount);
  End
  Else If Key='RETURN'Then Begin
   If Not UnitOpen Then Begin
    ParseStatement:=ParserError('RETURN hors unite',StmtLine);
    Exit;
   End;
   Inc(Pipeline.ReturnCount);
  End
  Else If StmtStartsWith(StmtText,'INTEGER')Then Begin
   If Not UnitOpen Then Begin
    ParseStatement:=ParserError('declaration INTEGER hors unite',StmtLine);
    Exit;
   End;
   Inc(Pipeline.IntegerDeclCount);
   If Not AddExplicitIntegerDecl(CurrentScope,StmtText,StmtLine)Then Begin
    ParseStatement:=False;
    Exit;
   End;
  End
  Else If Key='CALL'Then Begin
   If Not UnitOpen Then Begin
    ParseStatement:=ParserError('CALL hors unite',StmtLine);
    Exit;
   End;
   Inc(Pipeline.CallCount);
   ArgText:=TextBetweenParens(StmtText);
   If ArgText<>'' Then
    If Not AddIdentifiersFromText(CurrentScope,ArgText,StmtLine)Then Begin
     ParseStatement:=False;
     Exit;
    End;
  End
  Else Begin
   If Not UnitOpen Then Begin
    ParseStatement:=ParserError('instruction hors unite: '+Key,StmtLine);
    Exit;
   End;
   EqPos:=Pos('=',StmtText);
   If(EqPos>0)and(Key<>'DO')and(Key<>'IF')Then Begin
    If Not AddIdentifiersFromText(CurrentScope,StmtText,StmtLine)Then Begin
     ParseStatement:=False;
     Exit;
    End;
    If Not AddIntegerAssignment(CurrentScope,StmtText,StmtLine)Then Begin
     ParseStatement:=False;
     Exit;
    End;
   End
   Else If(Key='DO')or(Key='IF')or(Key='PRINT')or
          (Key='GOTO')or(Key='GO')Then Begin
   If Not AddIdentifiersFromText(CurrentScope,StmtText,StmtLine)Then Begin
     ParseStatement:=False;
     Exit;
    End;
    If Key='IF'Then Begin
     If Not AddIntegerComparison(CurrentScope,StmtText,StmtLine,
      CompIndex)Then Begin
      ParseStatement:=False;
      Exit;
     End;
     If Not AddIfGotoBranch(CurrentScope,StmtText,StmtLine,
      CompIndex)Then Begin
      ParseStatement:=False;
      Exit;
     End;
    End
    Else If(Key='GOTO')or(Key='GO')Then
     If Not AddGotoBranch(CurrentScope,StmtText,StmtLine)Then Begin
      ParseStatement:=False;
      Exit;
     End;
   End;
  End;
 End;

Begin
 TraceStage(CS_PARSER);
 RunParser:=False;
 LogicalStmt:='';
 LogicalLabel:=-1;
 UnitOpen:=False;
 CurrentUnit:='';
 CurrentScope:='';
 LineNo:=0;

 Assign(T,Pipeline.SourceName);
 Reset(T);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: impossible de relire ',Pipeline.SourceName);
  Exit;
 End;

 While Not Eof(T) Do Begin
  ReadLn(T,Line);
  If IOResult<>0 Then Begin
   WriteLn('Erreur: lecture parser interrompue dans ',Pipeline.SourceName);
   Close(T);
   Exit;
  End;
  Inc(LineNo);
  Kind:=FixedLineKindOf(Line);
  If(Kind=FLK_COMMENT)or(Kind=FLK_BLANK)Then Continue;
  Stmt:=FixedStmtText(Line);
  If Kind=FLK_CONTINUATION Then Begin
   If LogicalStmt='' Then Begin
    ParserError('continuation sans instruction initiale',LineNo);
   End
   Else LogicalStmt:=LogicalStmt+' '+TrimStr(Stmt);
  End
  Else Begin
   If LogicalStmt<>'' Then
    If Not ParseStatement(LogicalStmt,LineNo-1,LogicalLabel)Then Begin
     Close(T);
     Exit;
    End;
   LogicalStmt:=Stmt;
   If FixedLabelValue(Line,LabelValue)Then LogicalLabel:=LabelValue
    Else LogicalLabel:=-1;
  End;
 End;

 If LogicalStmt<>'' Then
  If Not ParseStatement(LogicalStmt,LineNo,LogicalLabel)Then Begin
   Close(T);
   Exit;
  End;
 Close(T);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: fermeture parser impossible de ',Pipeline.SourceName);
  Exit;
 End;
 If UnitOpen Then Begin
  ParserError('unite '+CurrentUnit+' sans END final',LineNo);
  Exit;
 End;
 If Pipeline.ProgramCount=0 Then Begin
  ParserError('aucun PROGRAM trouve',LineNo);
  Exit;
 End;
 If Pipeline.ProgramCount>1 Then Begin
  ParserError('plusieurs PROGRAM dans le meme fichier',LineNo);
  Exit;
 End;
 If Pipeline.EndCount<>(Pipeline.ProgramCount+Pipeline.SubroutineCount)Then Begin
  ParserError('nombre de END incoherent avec les unites',LineNo);
  Exit;
 End;
 If Not ResolveBranchLabels Then Exit;
 If TraceEnabled Then Begin
  WriteLn('Parser : PROGRAM ',Pipeline.ProgramCount,
          ', SUBROUTINE ',Pipeline.SubroutineCount,
          ', END ',Pipeline.EndCount,
          ', RETURN ',Pipeline.ReturnCount);
  WriteLn('Parser : INTEGER ',Pipeline.IntegerDeclCount,
          ', CALL ',Pipeline.CallCount,
          ', erreurs ',Pipeline.ParserErrors);
 End;
 RunParser:=Pipeline.ParserErrors=0;
End;

Function BuildSemanticTables:Boolean;
Begin
 TraceStage(CS_SEMANTIC_TABLES);
 TraceTypeInfo(FT_INTEGER,0);
 TraceTypeInfo(FT_LOGICAL,0);
 TraceTypeInfo(FT_CHARACTER,16);
 TraceTypeInfo(FT_REAL,0);
 TraceTypeInfo(FT_DOUBLE,0);
 TraceSymbolTable;
 BuildSemanticTables:=True;
End;

Function BuildIR:Boolean;
Begin
 TraceStage(CS_IR);
 TraceAssignments;
 TraceComparisons;
 TraceBranches;
 BuildIR:=True;
End;

Procedure TraceCallingConvention80386;
Begin
 If Not TraceEnabled Then Exit;
 WriteLn('Call   : Win32 80386, pile 32 bits, alignement ',I386_STACK_ALIGN);
 WriteLn('Regs   : eax ebx ecx edx esi edi ebp esp');
 WriteLn('Frame  : push ebp / mov ebp, esp / sub esp, locals');
 WriteLn('Return : mov esp, ebp / pop ebp / ret');
 WriteLn('Arg #1 : ',FortranArgAddressRef(1),' contient l''adresse Fortran');
 WriteLn('Local  : ',LocalVarRef(4),' pour le premier entier local 32 bits');
End;

Procedure TraceFlatMemoryModel;
Begin
 If Not TraceEnabled Then Exit;
 WriteLn('Memory : modele plat Win32 32 bits');
 WriteLn('PE     : section align ',WIN32_SECTION_ALIGN,
         ', file align ',WIN32_FILE_ALIGN);
 WriteLn('Section: ',SectionName(Pipeline.CodeSection),
         ' align ',SectionAlign(Pipeline.CodeSection),' code');
 WriteLn('Section: ',SectionName(Pipeline.DataSection),
         ' align ',SectionAlign(Pipeline.DataSection),' donnees initialisees');
 WriteLn('Section: ',SectionName(Pipeline.BssSection),
         ' align ',SectionAlign(Pipeline.BssSection),' donnees non initialisees');
 WriteLn('Labels : ',MakeWin32Label(USER_PROC_PREFIX,'MAIN'),' ',
         MakeWin32Label(USER_VAR_PREFIX,'I'),' ',
         MakeWin32Label(USER_CONST_PREFIX,'HELLO'),' ',
         MakeFortranLabel(10));
End;

Procedure EmitAsmLine(Var T:Text;S:String);
Begin
 WriteLn(T,S);
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

Procedure Emit386Call(Var T:Text;Target:String);
Begin
 EmitAsmInstr(T,'call',Target);
End;

Procedure Emit386Ret(Var T:Text);
Begin
 EmitAsmInstr(T,'ret','');
End;

Procedure Emit386Jmp(Var T:Text;Target:String);
Begin
 EmitAsmInstr(T,'jmp',Target);
End;

Procedure Emit386Cmp(Var T:Text;LeftOp,RightOp:String);
Begin
 EmitAsmInstr(T,'cmp',LeftOp+', '+RightOp);
End;

Procedure Emit386Jcc(Var T:Text;Cond:T386Condition;Target:String);
Begin
 EmitAsmInstr(T,'j'+CondName(Cond),Target);
End;

Procedure Emit386Imul(Var T:Text;Dst,Src:String);
Begin
 EmitAsmInstr(T,'imul',Dst+', '+Src);
End;

Procedure Emit386Idiv(Var T:Text;Src:String);
Begin
 EmitAsmInstr(T,'idiv',Src);
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
 EmitAsmInstr(T,'pop',RegName(R_EBP));
 Emit386Ret(T);
End;

Function UnitLocalBytes(UnitName:String):Integer;
Var
 I:Integer;
 Bytes:Integer;
Begin
 UnitName:=UpperStr(UnitName);
 Bytes:=0;
 For I:=1 To Pipeline.SymbolCount Do
  If(Pipeline.Symbols[I].UnitName=UnitName)and
    (Pipeline.Symbols[I].Kind=SK_LOCAL)Then
   Bytes:=Bytes+Pipeline.Symbols[I].SizeBytes;
 UnitLocalBytes:=Bytes;
End;

Function SymbolValueRef(SymbolIndex:Integer):String;
Begin
 If(SymbolIndex<1)or(SymbolIndex>Pipeline.SymbolCount)Then Begin
  SymbolValueRef:='[ebp]';
  Exit;
 End;
 Case Pipeline.Symbols[SymbolIndex].Kind Of
  SK_LOCAL:SymbolValueRef:=StackRef(R_EBP,Pipeline.Symbols[SymbolIndex].Offset);
  SK_PARAM:SymbolValueRef:=StackRef(R_EBP,Pipeline.Symbols[SymbolIndex].Offset);
  Else SymbolValueRef:=Pipeline.Symbols[SymbolIndex].AsmName;
 End;
End;

Procedure EmitLoadIntegerSymbol(Var T:Text;SymbolIndex:Integer);
Begin
 If(SymbolIndex<1)or(SymbolIndex>Pipeline.SymbolCount)Then Exit;
 If Pipeline.Symbols[SymbolIndex].Kind=SK_PARAM Then Begin
  Emit386Mov(T,RegName(R_EDX),SymbolValueRef(SymbolIndex));
  Emit386Mov(T,RegName(R_EAX),StackRef(R_EDX,0));
 End
 Else
  Emit386Mov(T,RegName(R_EAX),SymbolValueRef(SymbolIndex));
End;

Procedure EmitStoreIntegerSymbol(Var T:Text;SymbolIndex:Integer);
Begin
 If(SymbolIndex<1)or(SymbolIndex>Pipeline.SymbolCount)Then Exit;
 If Pipeline.Symbols[SymbolIndex].Kind=SK_PARAM Then Begin
  Emit386Mov(T,RegName(R_EDX),SymbolValueRef(SymbolIndex));
  Emit386Mov(T,StackRef(R_EDX,0),RegName(R_EAX));
 End
 Else
  Emit386Mov(T,SymbolValueRef(SymbolIndex),RegName(R_EAX));
End;

Function StripOuterParens(S:String):String;
Var
 Depth:Integer;
 I:Integer;
Begin
 S:=TrimStr(S);
 While(Length(S)>=2)and(S[1]='(')and(S[Length(S)]=')')Do Begin
  Depth:=0;
  StripOuterParens:=S;
  For I:=1 To Length(S)Do Begin
   If S[I]='('Then Inc(Depth)
   Else If S[I]=')'Then Begin
    Dec(Depth);
    If(Depth=0)and(I<Length(S))Then Exit;
   End;
  End;
  S:=TrimStr(Copy(S,2,Length(S)-2));
 End;
 StripOuterParens:=S;
End;

Function FindExprOperator(S:String;Ops:String):Integer;
Var
 I:Integer;
 Depth:Integer;
Begin
 FindExprOperator:=0;
 Depth:=0;
 For I:=Length(S) DownTo 1 Do Begin
  If S[I]=')'Then Inc(Depth)
  Else If S[I]='('Then Dec(Depth)
  Else If(Depth=0)and(Pos(S[I],Ops)>0)Then Begin
   If(I=1)or(S[I-1]='+')or(S[I-1]='-')or(S[I-1]='*')or(S[I-1]='(')Then
    Continue;
   FindExprOperator:=I;
   Exit;
  End;
 End;
End;

Procedure EmitIntegerExpression(Var T:Text;UnitName,Expr:String);
Var
 OpPos:Integer;
 LeftExpr:String;
 RightExpr:String;
 Value:LongInt;
 SymIdx:Integer;
 Op:Char;
Begin
 Expr:=StripOuterParens(UpperStr(TrimStr(Expr)));
 OpPos:=FindExprOperator(Expr,'+-');
 If OpPos=0 Then OpPos:=FindExprOperator(Expr,'*');
 If OpPos>0 Then Begin
  Op:=Expr[OpPos];
  LeftExpr:=Copy(Expr,1,OpPos-1);
  RightExpr:=Copy(Expr,OpPos+1,Length(Expr)-OpPos);
  EmitIntegerExpression(T,UnitName,LeftExpr);
  Emit386Push(T,RegName(R_EAX));
  EmitIntegerExpression(T,UnitName,RightExpr);
  EmitAsmInstr(T,'pop',RegName(R_EBX));
  If Op='+'Then EmitAsmInstr(T,'add',RegName(R_EAX)+', '+RegName(R_EBX))
  Else If Op='-'Then Begin
   EmitAsmInstr(T,'sub',RegName(R_EBX)+', '+RegName(R_EAX));
   Emit386Mov(T,RegName(R_EAX),RegName(R_EBX));
  End
  Else If Op='*'Then Emit386Imul(T,RegName(R_EAX),RegName(R_EBX));
  Exit;
 End;
 If IsIntegerLiteral(Expr,Value)Then Begin
  Emit386Mov(T,RegName(R_EAX),IntToString(Value));
  Exit;
 End;
 If(Length(Expr)>1)and(Expr[1]='-')Then Begin
  EmitIntegerExpression(T,UnitName,Copy(Expr,2,Length(Expr)-1));
  EmitAsmInstr(T,'neg',RegName(R_EAX));
  Exit;
 End;
 If(Length(Expr)>1)and(Expr[1]='+')Then Begin
  EmitIntegerExpression(T,UnitName,Copy(Expr,2,Length(Expr)-1));
  Exit;
 End;
 SymIdx:=FindVarSymbol(UnitName,Expr);
 EmitLoadIntegerSymbol(T,SymIdx);
End;

Procedure EmitIntegerComparison(Var T:Text;CompIndex:Integer);
Begin
 If(CompIndex<1)or(CompIndex>Pipeline.ComparisonCount)Then Exit;
 EmitAsmLine(T,'  ; ligne '+IntToString(Pipeline.Comparisons[CompIndex].LineNo)+
  ': IF '+Pipeline.Comparisons[CompIndex].LeftExpr+' '+
  FortranRelName(Pipeline.Comparisons[CompIndex].RelCond)+' '+
  Pipeline.Comparisons[CompIndex].RightExpr);
 EmitIntegerExpression(T,Pipeline.Comparisons[CompIndex].UnitName,
  Pipeline.Comparisons[CompIndex].LeftExpr);
 Emit386Push(T,RegName(R_EAX));
 EmitIntegerExpression(T,Pipeline.Comparisons[CompIndex].UnitName,
  Pipeline.Comparisons[CompIndex].RightExpr);
 EmitAsmInstr(T,'pop',RegName(R_EBX));
 Emit386Cmp(T,RegName(R_EBX),RegName(R_EAX));
 EmitAsmLine(T,'  ; flags prets pour j'+
 CondName(Pipeline.Comparisons[CompIndex].RelCond));
End;

Procedure EmitFortranLabel(Var T:Text;SymbolIndex:Integer);
Begin
 If(SymbolIndex<1)or(SymbolIndex>Pipeline.SymbolCount)Then Exit;
 EmitAsmLine(T,'  ; ligne '+IntToString(Pipeline.Symbols[SymbolIndex].LineNo)+
  ': label '+IntToString(Pipeline.Symbols[SymbolIndex].LabelValue));
 EmitAsmLabel(T,Pipeline.Symbols[SymbolIndex].AsmName);
End;

Procedure EmitIntegerBranch(Var T:Text;BranchIndex:Integer);
Var
 Target:String;
 CompIndex:Integer;
Begin
 If(BranchIndex<1)or(BranchIndex>Pipeline.BranchCount)Then Exit;
 If Pipeline.Branches[BranchIndex].LabelIndex=0 Then Exit;
 Target:=Pipeline.Symbols[Pipeline.Branches[BranchIndex].LabelIndex].AsmName;
 If Pipeline.Branches[BranchIndex].Kind=BK_IF_GOTO Then Begin
  CompIndex:=Pipeline.Branches[BranchIndex].ComparisonIndex;
  EmitIntegerComparison(T,CompIndex);
  Emit386Jcc(T,Pipeline.Comparisons[CompIndex].RelCond,Target);
 End
 Else Begin
  EmitAsmLine(T,'  ; ligne '+IntToString(Pipeline.Branches[BranchIndex].LineNo)+
   ': GOTO '+IntToString(Pipeline.Branches[BranchIndex].LabelValue));
  Emit386Jmp(T,Target);
 End;
End;

Procedure EmitIntegerAssignment(Var T:Text;AssignIndex:Integer);
Var
 RhsText:String;
Begin
 If(AssignIndex<1)or(AssignIndex>Pipeline.AssignmentCount)Then Exit;
 If Pipeline.Assignments[AssignIndex].RhsKind=ARK_CONST_INT Then
 RhsText:=IntToString(Pipeline.Assignments[AssignIndex].ConstVal)
Else If Pipeline.Assignments[AssignIndex].RhsKind=ARK_VAR Then
 RhsText:=Pipeline.Assignments[AssignIndex].SrcName
Else
 RhsText:=Pipeline.Assignments[AssignIndex].ExprText;
 EmitAsmLine(T,'  ; ligne '+IntToString(Pipeline.Assignments[AssignIndex].LineNo)+
  ': '+Pipeline.Assignments[AssignIndex].DestName+' = '+
  RhsText);
 If Pipeline.Assignments[AssignIndex].RhsKind=ARK_CONST_INT Then
 Emit386Mov(T,RegName(R_EAX),IntToString(Pipeline.Assignments[AssignIndex].ConstVal))
Else If Pipeline.Assignments[AssignIndex].RhsKind=ARK_VAR Then
 EmitLoadIntegerSymbol(T,Pipeline.Assignments[AssignIndex].SrcIndex)
Else
 EmitIntegerExpression(T,Pipeline.Assignments[AssignIndex].UnitName,
   Pipeline.Assignments[AssignIndex].ExprText);
 EmitStoreIntegerSymbol(T,Pipeline.Assignments[AssignIndex].DestIndex);
End;

Procedure EmitProcedureAssignments(Var T:Text;UnitName:String);
Var
 I:Integer;
Begin
 UnitName:=UpperStr(UnitName);
 For I:=1 To Pipeline.AssignmentCount Do
 If Pipeline.Assignments[I].UnitName=UnitName Then
   EmitIntegerAssignment(T,I);
End;

Procedure EmitProcedureComparisons(Var T:Text;UnitName:String);
Var
 I:Integer;
Begin
 UnitName:=UpperStr(UnitName);
 For I:=1 To Pipeline.ComparisonCount Do
  If Pipeline.Comparisons[I].UnitName=UnitName Then
   EmitIntegerComparison(T,I);
End;

Procedure EmitProcedureIntegerOps(Var T:Text;UnitName:String);
Var
 NextAssign:Integer;
 NextComp:Integer;
 NextLabel:Integer;
 NextBranch:Integer;
 BestAssign:Integer;
 BestComp:Integer;
 BestLabel:Integer;
 BestBranch:Integer;
 BestLine:Integer;
 BestKind:Integer;
 I:Integer;
Begin
 UnitName:=UpperStr(UnitName);
 NextAssign:=0;
 NextComp:=0;
 NextLabel:=0;
 NextBranch:=0;
 Repeat
  BestAssign:=0;
  BestComp:=0;
  BestLabel:=0;
  BestBranch:=0;
  BestLine:=MaxInt;
  BestKind:=MaxInt;
  For I:=1 To Pipeline.SymbolCount Do
   If(Pipeline.Symbols[I].UnitName=UnitName)and
     (Pipeline.Symbols[I].Kind=SK_LABEL)and(I>NextLabel)and
     ((Pipeline.Symbols[I].LineNo<BestLine)or
      ((Pipeline.Symbols[I].LineNo=BestLine)and(1<BestKind)))Then Begin
    BestLine:=Pipeline.Symbols[I].LineNo;
    BestKind:=1;
    BestLabel:=I;
    BestAssign:=0;
    BestComp:=0;
    BestBranch:=0;
   End;
  For I:=1 To Pipeline.AssignmentCount Do
   If(Pipeline.Assignments[I].UnitName=UnitName)and(I>NextAssign)and
     ((Pipeline.Assignments[I].LineNo<BestLine)or
      ((Pipeline.Assignments[I].LineNo=BestLine)and(2<BestKind)))Then Begin
    BestLine:=Pipeline.Assignments[I].LineNo;
    BestKind:=2;
    BestLabel:=0;
    BestAssign:=I;
    BestComp:=0;
    BestBranch:=0;
   End;
  For I:=1 To Pipeline.ComparisonCount Do
   If(Pipeline.Comparisons[I].UnitName=UnitName)and(I>NextComp)and
     (Pipeline.Comparisons[I].BranchIndex=0)and
     ((Pipeline.Comparisons[I].LineNo<BestLine)or
      ((Pipeline.Comparisons[I].LineNo=BestLine)and(3<BestKind)))Then Begin
    BestLine:=Pipeline.Comparisons[I].LineNo;
    BestKind:=3;
    BestLabel:=0;
    BestAssign:=0;
    BestComp:=I;
    BestBranch:=0;
   End;
  For I:=1 To Pipeline.BranchCount Do
   If(Pipeline.Branches[I].UnitName=UnitName)and(I>NextBranch)and
     ((Pipeline.Branches[I].LineNo<BestLine)or
      ((Pipeline.Branches[I].LineNo=BestLine)and(4<BestKind)))Then Begin
    BestLine:=Pipeline.Branches[I].LineNo;
    BestKind:=4;
    BestLabel:=0;
    BestAssign:=0;
    BestComp:=0;
    BestBranch:=I;
   End;
  If BestLabel>0 Then Begin
   EmitFortranLabel(T,BestLabel);
   NextLabel:=BestLabel;
  End
  Else If BestAssign>0 Then Begin
   EmitIntegerAssignment(T,BestAssign);
   NextAssign:=BestAssign;
  End
  Else If BestComp>0 Then Begin
   EmitIntegerComparison(T,BestComp);
   NextComp:=BestComp;
  End
  Else If BestBranch>0 Then Begin
   EmitIntegerBranch(T,BestBranch);
   NextBranch:=BestBranch;
  End;
 Until(BestLabel=0)and(BestAssign=0)and(BestComp=0)and(BestBranch=0);
End;

Function WriteAsm80386File(FileName:String):Boolean;
Var
 T:Text;
 I:Integer;
 UnitName:String;
Begin
 WriteAsm80386File:=False;
 Assign(T,FileName);
 Rewrite(T);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: impossible de creer ',FileName);
  Exit;
 End;

 EmitAsmLine(T,'; F77CW32 - ASM 80386 genere');
 EmitAsmLine(T,'; source: '+Pipeline.SourceName);
 EmitAsmLine(T,'bits 32');
 EmitAsmLine(T,'');
 EmitAsmSection(T,AS_TEXT);
 For I:=1 To Pipeline.SymbolCount Do
  If Pipeline.Symbols[I].Kind=SK_PROC Then
   EmitAsmLine(T,'global '+Pipeline.Symbols[I].AsmName);
 EmitAsmLine(T,'');
 For I:=1 To Pipeline.SymbolCount Do
  If Pipeline.Symbols[I].Kind=SK_PROC Then Begin
   UnitName:=Pipeline.Symbols[I].Name;
   EmitAsmLabel(T,Pipeline.Symbols[I].AsmName);
   Emit386Prologue(T,UnitLocalBytes(UnitName));
   EmitProcedureIntegerOps(T,UnitName);
   Emit386Epilogue(T);
   EmitAsmLine(T,'');
  End;
 EmitAsmSection(T,AS_DATA);
 EmitAsmLabel(T,MakeWin32Label(USER_CONST_PREFIX,'HELLO'));
 EmitAsmLine(T,'  db ''HELLO'',0');
 EmitAsmLine(T,'');
 EmitAsmSection(T,AS_BSS);
 EmitAsmLine(T,'  ; variables locales allouees dans les frames 80386');

 Close(T);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: ecriture incomplete de ',FileName);
  Exit;
 End;
 WriteAsm80386File:=True;
End;

Function GenerateAsm80386:Boolean;
Begin
 TraceStage(CS_ASM_80386);
 TraceCallingConvention80386;
 TraceFlatMemoryModel;
 If Options.EmitAsm Then Begin
  GenerateAsm80386:=WriteAsm80386File(Pipeline.AsmName);
  If TraceEnabled and GenerateAsm80386 Then
   WriteLn('ASM    : fichier ecrit ',Pipeline.AsmName);
 End
 Else GenerateAsm80386:=True;
End;

Procedure TraceCoffFormat;
Var
 Sec:TCoffSectionRec;
Begin
 If Not TraceEnabled Then Exit;
 WriteLn('COFF   : i386 Windows, machine 0x',WordHex(Pipeline.CoffFormat.Machine));
 WriteLn('COFF   : file header ',Pipeline.CoffFormat.HeaderSize,
         ', section header ',Pipeline.CoffFormat.SectionHdrSize,
         ', symbol ',Pipeline.CoffFormat.SymbolSize,
         ', reloc ',Pipeline.CoffFormat.RelocSize);
 Sec:=CoffSectionRec(Pipeline.CodeSection);
 WriteLn('COFF   : section ',Sec.Name,' align ',Sec.AlignBytes,
         ' flags ',Sec.FlagsText);
 Sec:=CoffSectionRec(Pipeline.DataSection);
 WriteLn('COFF   : section ',Sec.Name,' align ',Sec.AlignBytes,
         ' flags ',Sec.FlagsText);
 Sec:=CoffSectionRec(Pipeline.BssSection);
 WriteLn('COFF   : section ',Sec.Name,' align ',Sec.AlignBytes,
         ' flags ',Sec.FlagsText);
 WriteLn('COFF   : symbols actifs pour sections, procedures, variables et externes');
 WriteLn('COFF   : reloc ',WordHex(CoffRelocType(CR_DIR32)),' ',
         CoffRelocName(CR_DIR32));
 WriteLn('COFF   : reloc ',WordHex(CoffRelocType(CR_REL32)),' ',
         CoffRelocName(CR_REL32));
End;

Function CoffSectionNumber(Section:TAsmSection):Integer;
Begin
 Case Section Of
  AS_TEXT:CoffSectionNumber:=1;
  AS_DATA:CoffSectionNumber:=2;
  AS_BSS:CoffSectionNumber:=3;
  Else CoffSectionNumber:=0;
 End;
End;

Procedure WriteByte(Var F:File;B:Byte);
Begin
 BlockWrite(F,B,1);
End;

Procedure WriteWordLE(Var F:File;W:Word);
Begin
 WriteByte(F,W and $FF);
 WriteByte(F,(W Shr 8)and $FF);
End;

Procedure WriteDWordLE(Var F:File;Value:LongInt);
Begin
 WriteWordLE(F,Value and $FFFF);
 WriteWordLE(F,(Value Shr 16)and $FFFF);
End;

Procedure WriteDWordWordsLE(Var F:File;LoWord,HiWord:Word);
Begin
 WriteWordLE(F,LoWord);
 WriteWordLE(F,HiWord);
End;

Procedure WriteZeroBytes(Var F:File;Count:Integer);
Var
 I:Integer;
Begin
 For I:=1 To Count Do WriteByte(F,0);
End;

Procedure WriteFixedName8(Var F:File;S:String);
Var
 I:Integer;
Begin
 For I:=1 To 8 Do Begin
  If I<=Length(S) Then WriteByte(F,Ord(S[I]))
   Else WriteByte(F,0);
 End;
End;

Function AlignValue(Value,Alignment:LongInt):LongInt;
Begin
 If Alignment<=0 Then AlignValue:=Value
  Else If(Value mod Alignment)=0 Then AlignValue:=Value
  Else AlignValue:=Value+(Alignment-(Value mod Alignment));
End;

Procedure PadToFilePos(Var F:File;TargetPos:LongInt);
Begin
 While FilePos(F)<TargetPos Do WriteByte(F,0);
End;

Procedure WriteAscii(Var F:File;S:String);
Var
 I:Integer;
Begin
 For I:=1 To Length(S)Do WriteByte(F,Ord(S[I]));
End;

Procedure WriteAsciiZ(Var F:File;S:String);
Begin
 WriteAscii(F,S);
 WriteByte(F,0);
End;

Procedure WriteCoffSectionHeader(Var F:File;Section:TAsmSection;
                                 RawSize,RawPtr,RelocPtr:LongInt);
Var
 Sec:TCoffSectionRec;
Begin
 Sec:=CoffSectionRec(Section);
 WriteFixedName8(F,Sec.Name);
 WriteDWordLE(F,0);       { VirtualSize / PhysicalAddress }
 WriteDWordLE(F,0);       { VirtualAddress }
 WriteDWordLE(F,RawSize);
 If RawSize=0 Then WriteDWordLE(F,0)
  Else WriteDWordLE(F,RawPtr);
 WriteDWordLE(F,RelocPtr);
 WriteDWordLE(F,0);       { PointerToLinenumbers }
 WriteWordLE(F,0);        { NumberOfRelocations }
 WriteWordLE(F,0);        { NumberOfLinenumbers }
 WriteDWordWordsLE(F,Sec.FlagsLo,Sec.FlagsHi);
End;

Procedure WriteCoffSymbol(Var F:File;Name:String;Value:LongInt;
                          SectionNumber:Integer;StorageClass:Byte);
Begin
 WriteFixedName8(F,Name);
 WriteDWordLE(F,Value);
 WriteWordLE(F,SectionNumber);
 WriteWordLE(F,0);        { Type }
 WriteByte(F,StorageClass);
 WriteByte(F,0);          { NumberOfAuxSymbols }
End;

Function WriteMinimalCoffObj(FileName:String):Boolean;
Const
 TextSize = 1;
 DataSize = 0;
 BssSize  = 0;
 SectionCount = 3;
 SymbolCount = 4;
Var
 F:File;
 HeaderSize:LongInt;
 TextPtr:LongInt;
 DataPtr:LongInt;
 BssPtr:LongInt;
 SymbolPtr:LongInt;
 RetOp:Byte;
Begin
 WriteMinimalCoffObj:=False;
 HeaderSize:=COFF_FILE_HEADER_SIZE+(SectionCount*COFF_SECTION_HDR_SIZE);
 TextPtr:=HeaderSize;
 DataPtr:=0;
 BssPtr:=0;
 SymbolPtr:=TextPtr+TextSize+DataSize+BssSize;

 Assign(F,FileName);
 Rewrite(F,1);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: impossible de creer ',FileName);
  Exit;
 End;

 WriteWordLE(F,COFF_MACHINE_I386);
 WriteWordLE(F,SectionCount);
 WriteDWordLE(F,0);               { TimeDateStamp }
 WriteDWordLE(F,SymbolPtr);
 WriteDWordLE(F,SymbolCount);
 WriteWordLE(F,0);                { SizeOfOptionalHeader }
 WriteWordLE(F,0);                { Characteristics }

 WriteCoffSectionHeader(F,AS_TEXT,TextSize,TextPtr,0);
 WriteCoffSectionHeader(F,AS_DATA,DataSize,DataPtr,0);
 WriteCoffSectionHeader(F,AS_BSS,BssSize,BssPtr,0);

 RetOp:=$C3;
 WriteByte(F,RetOp);

 WriteCoffSymbol(F,FLAT_TEXT_SECTION,0,CoffSectionNumber(AS_TEXT),
                 COFF_SYM_CLASS_STATIC);
 WriteCoffSymbol(F,FLAT_DATA_SECTION,0,CoffSectionNumber(AS_DATA),
                 COFF_SYM_CLASS_STATIC);
 WriteCoffSymbol(F,FLAT_BSS_SECTION,0,CoffSectionNumber(AS_BSS),
                 COFF_SYM_CLASS_STATIC);
 WriteCoffSymbol(F,MakeWin32Label(USER_PROC_PREFIX,'MAIN'),0,
                 CoffSectionNumber(AS_TEXT),COFF_SYM_CLASS_EXTERNAL);

 WriteDWordLE(F,4);               { String table vide }

 Close(F);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: ecriture incomplete de ',FileName);
  Exit;
 End;
 WriteMinimalCoffObj:=True;
End;

Function WriteObjCOFF:Boolean;
Begin
 TraceStage(CS_OBJ_COFF);
 TraceCoffFormat;
 WriteObjCOFF:=WriteMinimalCoffObj(Pipeline.ObjName);
 If TraceEnabled and WriteObjCOFF Then
  WriteLn('COFF   : fichier ecrit ',Pipeline.ObjName);
End;

Procedure WritePESectionHeader(Var F:File;Name:String;VirtualSize,VirtualAddress,
                               RawSize,RawPtr:LongInt;FlagsLo,FlagsHi:Word);
Begin
 WriteFixedName8(F,Name);
 WriteDWordLE(F,VirtualSize);
 WriteDWordLE(F,VirtualAddress);
 WriteDWordLE(F,RawSize);
 WriteDWordLE(F,RawPtr);
 WriteDWordLE(F,0);       { PointerToRelocations }
 WriteDWordLE(F,0);       { PointerToLinenumbers }
 WriteWordLE(F,0);        { NumberOfRelocations }
 WriteWordLE(F,0);        { NumberOfLinenumbers }
 WriteDWordWordsLE(F,FlagsLo,FlagsHi);
End;

Procedure WritePEOptionalHeader(Var F:File);
Const
 ImportDirRva = PE_IDATA_RVA;
 ImportDirSize = $80;
 IatRva = PE_IDATA_RVA+$30;
 IatSize = 8;
Var
 I:Integer;
Begin
 WriteWordLE(F,$010B);               { PE32 }
 WriteByte(F,0);                     { MajorLinkerVersion }
 WriteByte(F,0);                     { MinorLinkerVersion }
 WriteDWordLE(F,PE_TEXT_RAW_SIZE);   { SizeOfCode }
 WriteDWordLE(F,PE_IDATA_RAW_SIZE);  { SizeOfInitializedData }
 WriteDWordLE(F,0);                  { SizeOfUninitializedData }
 WriteDWordLE(F,PE_TEXT_RVA);        { AddressOfEntryPoint }
 WriteDWordLE(F,PE_TEXT_RVA);        { BaseOfCode }
 WriteDWordLE(F,PE_IDATA_RVA);       { BaseOfData }
 WriteDWordLE(F,PE_IMAGE_BASE);
 WriteDWordLE(F,WIN32_SECTION_ALIGN);
 WriteDWordLE(F,WIN32_FILE_ALIGN);
 WriteWordLE(F,4); WriteWordLE(F,0); { OS version }
 WriteWordLE(F,0); WriteWordLE(F,0); { Image version }
 WriteWordLE(F,4); WriteWordLE(F,0); { Subsystem version }
 WriteDWordLE(F,0);                  { Win32VersionValue }
 WriteDWordLE(F,PE_SIZE_OF_IMAGE);
 WriteDWordLE(F,PE_SIZE_OF_HEADERS);
 WriteDWordLE(F,0);                  { CheckSum }
 WriteWordLE(F,PE_SUBSYSTEM_CONSOLE);
 WriteWordLE(F,0);                   { DllCharacteristics }
 WriteDWordLE(F,$00100000);          { SizeOfStackReserve }
 WriteDWordLE(F,$00001000);          { SizeOfStackCommit }
 WriteDWordLE(F,$00100000);          { SizeOfHeapReserve }
 WriteDWordLE(F,$00001000);          { SizeOfHeapCommit }
 WriteDWordLE(F,0);                  { LoaderFlags }
 WriteDWordLE(F,16);                 { NumberOfRvaAndSizes }
 For I:=0 To 15 Do Begin
  If I=1 Then Begin
   WriteDWordLE(F,ImportDirRva);
   WriteDWordLE(F,ImportDirSize);
  End
  Else If I=12 Then Begin
   WriteDWordLE(F,IatRva);
   WriteDWordLE(F,IatSize);
  End
  Else Begin
   WriteDWordLE(F,0);
   WriteDWordLE(F,0);
  End;
 End;
End;

Procedure WritePETextSection(Var F:File);
Const
 IatVa = PE_IMAGE_BASE+PE_IDATA_RVA+$30;
Begin
 PadToFilePos(F,PE_TEXT_RAW_PTR);
 WriteByte(F,$6A);                  { push 0 }
 WriteByte(F,$00);
 WriteByte(F,$FF);                  { call dword ptr [IAT] }
 WriteByte(F,$15);
 WriteDWordLE(F,IatVa);
 WriteByte(F,$CC);                  { garde-fou si ExitProcess revient }
 PadToFilePos(F,PE_TEXT_RAW_PTR+PE_TEXT_RAW_SIZE);
End;

Procedure WritePEImportSection(Var F:File);
Const
 DescOff = 0;
 OftOff = $28;
 IatOff = $30;
 DllOff = $38;
 HintOff = $48;
 HintRva = PE_IDATA_RVA+HintOff;
Begin
 PadToFilePos(F,PE_IDATA_RAW_PTR+DescOff);
 WriteDWordLE(F,PE_IDATA_RVA+OftOff);  { OriginalFirstThunk }
 WriteDWordLE(F,0);                    { TimeDateStamp }
 WriteDWordLE(F,0);                    { ForwarderChain }
 WriteDWordLE(F,PE_IDATA_RVA+DllOff);  { Name }
 WriteDWordLE(F,PE_IDATA_RVA+IatOff);  { FirstThunk }
 WriteZeroBytes(F,20);                 { Null descriptor }

 PadToFilePos(F,PE_IDATA_RAW_PTR+OftOff);
 WriteDWordLE(F,HintRva);
 WriteDWordLE(F,0);

 PadToFilePos(F,PE_IDATA_RAW_PTR+IatOff);
 WriteDWordLE(F,HintRva);
 WriteDWordLE(F,0);

 PadToFilePos(F,PE_IDATA_RAW_PTR+DllOff);
 WriteAsciiZ(F,'KERNEL32.dll');

 PadToFilePos(F,PE_IDATA_RAW_PTR+HintOff);
 WriteWordLE(F,0);                     { Hint }
 WriteAsciiZ(F,'ExitProcess');
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
  WriteLn('Erreur: impossible de creer ',FileName);
  Exit;
 End;

 WriteByte(F,Ord('M'));
 WriteByte(F,Ord('Z'));
 PadToFilePos(F,$3C);
 WriteDWordLE(F,PE_DOS_LFANEW);
 PadToFilePos(F,PE_DOS_LFANEW);

 WriteByte(F,Ord('P'));
 WriteByte(F,Ord('E'));
 WriteByte(F,0);
 WriteByte(F,0);
 WriteWordLE(F,COFF_MACHINE_I386);
 WriteWordLE(F,2);                    { .text + .idata }
 WriteDWordLE(F,0);                   { TimeDateStamp }
 WriteDWordLE(F,0);                   { PointerToSymbolTable }
 WriteDWordLE(F,0);                   { NumberOfSymbols }
 WriteWordLE(F,PE_OPT_HEADER_SIZE);
 WriteWordLE(F,PE_FILE_CHAR_LO);

 WritePEOptionalHeader(F);
 WritePESectionHeader(F,'.text',PE_TEXT_RAW_SIZE,PE_TEXT_RVA,
                      PE_TEXT_RAW_SIZE,PE_TEXT_RAW_PTR,
                      COFF_TEXT_FLAGS_LO,COFF_TEXT_FLAGS_HI);
 WritePESectionHeader(F,'.idata',PE_IDATA_RAW_SIZE,PE_IDATA_RVA,
                      PE_IDATA_RAW_SIZE,PE_IDATA_RAW_PTR,
                      PE_IDATA_FLAGS_LO,PE_IDATA_FLAGS_HI);
 PadToFilePos(F,PE_SIZE_OF_HEADERS);

 WritePETextSection(F);
 WritePEImportSection(F);

 Close(F);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: ecriture incomplete de ',FileName);
  Exit;
 End;
 WriteMinimalPE32Exe:=True;
End;

Function LinkExePE32:Boolean;
Begin
 If Options.OutputMode=OM_OBJ Then Begin
  LinkExePE32:=True;
  Exit;
 End;
 TraceStage(CS_EXE_PE32);
 If TraceEnabled Then
  WriteLn('PE32   : generation autonome depuis ',Pipeline.ObjName);
 LinkExePE32:=WriteMinimalPE32Exe(Pipeline.ExeName);
 If TraceEnabled and LinkExePE32 Then
  WriteLn('PE32   : fichier ecrit ',Pipeline.ExeName);
End;

Procedure PrintPipelineOutputs;
Begin
 If Not TraceEnabled Then Exit;
 If Options.EmitAsm Then WriteLn('ASM out: ',Pipeline.AsmName);
 WriteLn('OBJ out: ',Pipeline.ObjName);
 If Options.OutputMode=OM_EXE Then WriteLn('EXE out: ',Pipeline.ExeName);
End;

Function RunCompilerPipeline:Boolean;
Begin
 InitPipeline;
 PrintPipelineOutputs;
 RunCompilerPipeline:=LoadSource and
                      RunLexer and
                      RunParser and
                      BuildSemanticTables and
                      BuildIR and
                      GenerateAsm80386 and
                      WriteObjCOFF and
                      LinkExePE32;
End;

BEGIN
 InitOptions;
 ParseCommandLine;
 PrintDiagnostics;
 PrintSelectedOutputs;
 If Not RunCompilerPipeline Then Halt(1);
END.
