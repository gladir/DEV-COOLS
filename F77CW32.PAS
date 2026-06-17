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

  TODO 09 - Prevoir les options ligne de commande:
            -c pour .OBJ seulement, -S pour conserver/generer .ASM,
            -o nom_sortie, -v version, -h aide, et mode diagnostic.

  TODO 10 - Adapter l'emission assembleur 80386:
            MOV/PUSH/CALL/RET/JMP/CMP/Jcc/IMUL/IDIV 32 bits,
            labels internes, labels Fortran numeriques et appels runtime.

  TODO 11 - Definir les tailles Win32 des types Fortran supportes au depart:
            INTEGER en 32 bits, LOGICAL en 32 bits, CHARACTER fixe,
            puis preparer REAL/DOUBLE pour une phase ulterieure.

  TODO 12 - Valider le lexer Fortran 77 fixe:
            colonnes 1-5 labels, colonne 6 continuation,
            commentaires C/* en colonne 1, lignes jusqu'a 72 colonnes utiles.

  TODO 13 - Valider le parser des unites de programme:
            PROGRAM, SUBROUTINE, END, RETURN, declarations INTEGER,
            appels CALL et portees separees par unite.

  TODO 14 - Implementer le typage implicite Fortran 77:
            I-N INTEGER par defaut, autres REAL si non declare,
            tout en permettant INTEGER explicite pour les samples actuels.

  TODO 15 - Finaliser la table des symboles 32 bits:
            variables locales, variables statiques si necessaire,
            parametres dummy passes par adresse, procedures et labels.

  TODO 16 - Implementer les affectations scalaires INTEGER:
            constantes entieres, variables, copies par adresse pour parametres,
            et stockage correct dans les variables locales.

  TODO 17 - Implementer les expressions INTEGER minimales:
            +, -, *, parentheses, variables, constantes,
            evaluation avec pile ou registres 80386.

  TODO 18 - Implementer les comparaisons relationnelles Fortran:
            .EQ., .NE., .LT., .LE., .GT., .GE.,
            necessaires notamment pour IF (N .LE. 1) GOTO label.

  TODO 19 - Implementer GOTO numerique et resolution des labels:
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

Procedure PrintUsage;Begin
 WriteLn('F77CW32 - Cette commande permet de ',
         'lancer le compilateur Fortran 77 pour l''assembleur du microprocesseur ',
         '80386 pour Windows 32 bits.');
 WriteLn;
 WriteLn('Syntaxe : F77CW32 <source.f77> [options]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -c            : produire seulement un fichier objet COFF i386 .OBJ');
 WriteLn('  -S            : produire/conserver aussi le fichier assembleur .ASM');
 WriteLn('  -o <fichier>  : specifier le nom du fichier de sortie');
 WriteLn('  -v            : mode verbeux');
 WriteLn('  -h, --help    : afficher cette aide');
 WriteLn('  --version     : afficher la version');
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
  Else If UpperStr(S)='-C' Then Options.OutputMode:=OM_OBJ
  Else If UpperStr(S)='-S' Then Options.EmitAsm:=True
  Else If UpperStr(S)='-V' Then Options.Verbose:=True
  Else If UpperStr(S)='-O' Then Begin
   Inc(I);
   If I>ParamCount Then Begin
    WriteLn('Erreur: option -o sans nom de fichier.');
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

 If Options.SourceName='' Then Begin
  PrintUsage;
  Halt(1);
 End;

 If Options.OutputName='' Then Options.OutputName:=DefaultOutputName(Options.SourceName)
  Else If Not HasExtension(Options.OutputName)Then
   Options.OutputName:=Options.OutputName+DefaultOutputExt;
End;

Procedure PrintSelectedOutputs;
Begin
 If Not Options.Verbose Then Exit;
 WriteLn('Source : ',Options.SourceName);
 If Options.OutputMode=OM_OBJ Then WriteLn('Mode   : OBJ seulement')
  Else WriteLn('Mode   : EXE Win32 par defaut');
 WriteLn('Sortie : ',Options.OutputName);
 If Options.EmitAsm Then WriteLn('ASM    : oui')
  Else WriteLn('ASM    : non');
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
 If Options.Verbose Then WriteLn('Pipeline: ',StageName(Stage));
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
Begin
 TraceStage(CS_LOAD_SOURCE);
 LoadSource:=True;
End;

Function RunLexer:Boolean;
Begin
 TraceStage(CS_LEXER);
 RunLexer:=True;
End;

Function RunParser:Boolean;
Begin
 TraceStage(CS_PARSER);
 RunParser:=True;
End;

Function BuildSemanticTables:Boolean;
Begin
 TraceStage(CS_SEMANTIC_TABLES);
 BuildSemanticTables:=True;
End;

Function BuildIR:Boolean;
Begin
 TraceStage(CS_IR);
 BuildIR:=True;
End;

Procedure TraceCallingConvention80386;
Begin
 If Not Options.Verbose Then Exit;
 WriteLn('Call   : Win32 80386, pile 32 bits, alignement ',I386_STACK_ALIGN);
 WriteLn('Regs   : eax ebx ecx edx esi edi ebp esp');
 WriteLn('Frame  : push ebp / mov ebp, esp / sub esp, locals');
 WriteLn('Return : mov esp, ebp / pop ebp / ret');
 WriteLn('Arg #1 : ',FortranArgAddressRef(1),' contient l''adresse Fortran');
 WriteLn('Local  : ',LocalVarRef(4),' pour le premier entier local 32 bits');
End;

Procedure TraceFlatMemoryModel;
Begin
 If Not Options.Verbose Then Exit;
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

Function GenerateAsm80386:Boolean;
Begin
 TraceStage(CS_ASM_80386);
 TraceCallingConvention80386;
 TraceFlatMemoryModel;
 GenerateAsm80386:=True;
End;

Procedure TraceCoffFormat;
Var
 Sec:TCoffSectionRec;
Begin
 If Not Options.Verbose Then Exit;
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
 If Options.Verbose and WriteObjCOFF Then
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
 If Options.Verbose Then
  WriteLn('PE32   : generation autonome depuis ',Pipeline.ObjName);
 LinkExePE32:=WriteMinimalPE32Exe(Pipeline.ExeName);
 If Options.Verbose and LinkExePE32 Then
  WriteLn('PE32   : fichier ecrit ',Pipeline.ExeName);
End;

Procedure PrintPipelineOutputs;
Begin
 If Not Options.Verbose Then Exit;
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
 PrintSelectedOutputs;
 If Not RunCompilerPipeline Then Halt(1);
END.
