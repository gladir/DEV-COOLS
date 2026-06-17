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

  TODO 08 - Implementer le lexer Modula-2:
            identificateurs, mots reserves, entiers, chaines quote/simple quote,
            commentaires imbriques (* *), ponctuation, operateurs et EOF.

  TODO 09 - Implementer le parser des unites:
            MODULE nom; declarations IMPORT/CONST/TYPE/VAR/PROCEDURE,
            bloc BEGIN...END nom. et verification du nom final.

  TODO 10 - Implementer IMPORT et table des modules:
            resolution de InOut pour les exemples, controle des noms importes,
            preparation pour ajouter d'autres modules standards plus tard.

  TODO 11 - Definir la table des symboles et les portees:
            portee module, portees de procedures, constantes, variables,
            procedures, parametres, imports et detection des doublons.

  TODO 12 - Implementer les types scalaires de base:
            INTEGER 32 bits, CARDINAL 32 bits non signe, BOOLEAN, CHAR,
            chaines constantes et compatibilite avec les appels InOut.

  TODO 13 - Implementer CONST:
            constantes entieres, booleennes, caracteres, chaines,
            evaluation constante simple et references dans les expressions.

  TODO 14 - Implementer VAR:
            allocation globale et locale, offsets EBP, initialisation implicite
            a zero pour les donnees statiques et acces 32 bits.

  TODO 15 - Implementer les expressions:
            priorites Modula-2, +, -, *, DIV, MOD, parentheses, unaire -,
            constantes, variables et conversion en IR typee.

  TODO 16 - Implementer les comparaisons et booleens:
            =, #, <, <=, >, >=, NOT, AND, OR, evaluation court-circuit
            si necessaire et emission Jcc 80386.

  TODO 17 - Implementer les instructions de base:
            affectation :=, appels de procedures, instructions separees par ;
            blocs BEGIN...END imbriques et instruction vide.

  TODO 18 - Implementer IF:
            IF condition THEN suite [ELSIF condition THEN suite] [ELSE suite]
            END, avec labels et branchements corrects.

  TODO 19 - Implementer WHILE et REPEAT:
            WHILE condition DO suite END et REPEAT suite UNTIL condition,
            avec gestion correcte des sorties de boucle.

  TODO 20 - Implementer FOR:
            FOR i := debut TO fin [BY pas] DO suite END,
            entiers 32 bits, bornes evaluees correctement et support de INC.

  TODO 21 - Implementer procedures et parametres:
            PROCEDURE locale/exportable, appels, parametres valeur et VAR,
            pile 32 bits, retour, recursion simple et verification d'arite.

  TODO 22 - Implementer les procedures predefinies minimales:
            INC, DEC, ORD, CHR, ODD, ABS si utile, avec controle de type et
            emission directe quand possible.

  TODO 23 - Implementer le module InOut:
            WriteString, WriteLn, WriteInt au minimum pour hello_m2.mod et
            arith_m2.mod, via runtime Win32 console ou imports C.

  TODO 24 - Ajouter une suite de validation SAMPLES\MODULA2:
            compiler tous les .mod en .EXE par defaut, verifier -c et -S,
            executer hello_m2.mod et arith_m2.mod et comparer les sorties.

  TODO 25 - Stabiliser la compatibilite Turbo Pascal/Free Pascal:
            types Pascal portables, aucune dependance non TP7 si possible,
            chemins Windows, E/S binaires, endianess et documentation d'usage.
}

Program MOD2CW32;

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

Function IntToString(N:LongInt):String;
Var
 S:String;
Begin
 Str(N,S);
 IntToString:=S;
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

Procedure PipelineError(Msg:String); Forward;
Procedure PipelineErrorAt(Kind:TErrorKind;Msg:String;LineNo,ColumnNo:LongInt);
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
 EmitAsmLine(T,'global '+Pipeline.Target.EntryLabel);
 EmitAsmLabel(T,Pipeline.Target.EntryLabel);
 EmitAsmComment(T,'prologue standard Win32 80386');
 Emit386Prologue(T,0);
 EmitAsmComment(T,'IR Modula-2 pas encore emis; valeur de retour provisoire');
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
 SymbolCount  = 6;
 TextSize     = 8;
 BssSize      = 4;
Var
 F:File;
 TextPtr:LongInt;
 DataPtr:LongInt;
 BssPtr:LongInt;
 SymbolPtr:LongInt;
 DataSize:LongInt;
 EntryName:String;
 SourceLabel:String;
 ModuleLabel:String;
Begin
 WriteCoffI386File:=False;
 EntryName:=Pipeline.Target.EntryLabel;
 SourceLabel:=MakeDataLabel(Pipeline.ModuleName+'_SOURCE');
 ModuleLabel:=MakeDataLabel(Pipeline.ModuleName+'_MODULE');
 DataSize:=Length(Pipeline.SourceName)+1+Length(Pipeline.ModuleName)+1;
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
 OutputText:='MOD2CW32: executable PE32 minimal'+Chr(13)+Chr(10);
 MsgVa:=WIN32_IMAGE_BASE+PE_TEXT_RVA+MsgOff;
 WrittenVa:=WIN32_IMAGE_BASE+PE_IDATA_RVA+WrittenOff;
 PadToFilePos(F,PE_TEXT_RAW_PTR);
 WriteRawByte(F,$6A); WriteRawByte(F,$F5);
 WriteRawByte(F,$FF); WriteRawByte(F,$15); WriteRawDWordLE(F,IatGetStdHandleVa);
 WriteRawByte(F,$6A); WriteRawByte(F,$00);
 WriteRawByte(F,$68); WriteRawDWordLE(F,WrittenVa);
 WriteRawByte(F,$68); WriteRawDWordLE(F,Length(OutputText));
 WriteRawByte(F,$68); WriteRawDWordLE(F,MsgVa);
 WriteRawByte(F,$50);
 WriteRawByte(F,$FF); WriteRawByte(F,$15); WriteRawDWordLE(F,IatWriteFileVa);
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
 LexicalError('lexer Modula-2 pas encore implemente',1,1);
End;

Procedure RunParser;
Begin
 EnterStage(CS_PARSER);
 SyntaxError('parser Modula-2 pas encore implemente',1,1);
End;

Procedure BuildSemanticTables;
Begin
 EnterStage(CS_SEMANTIC_TABLES);
 SemanticError('tables semantiques pas encore implementees',1,1);
End;

Procedure BuildSimpleIR;
Begin
 EnterStage(CS_IR);
 CodegenError('IR simple pas encore implemente');
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
 ParseCommandLine;
 CompilePipeline(Options.SourceName);
 If Pipeline.ErrorCount<>0 Then Halt(1);
END.
