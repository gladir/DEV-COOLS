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

  TODO 05 - Implementer un writer OBJ COFF i386 minimal:
            sections, table de symboles, relocations REL32/DIR32 et donnees
            necessaires au linkage Windows 32 bits.

  TODO 06 - Implementer le linkage .OBJ -> .EXE par defaut:
            generation PE32 console minimale autonome, point d'entree,
            imports kernel32/msvcrt ou runtime interne selon le choix retenu.

  TODO 07 - Ajouter une gestion d'erreurs robuste:
            fichier, ligne, colonne, extrait fautif, erreurs lexicales,
            syntaxiques, semantiques et messages compatibles avec les samples.

  TODO 08 - Implementer le lexer Modula-3:
            identificateurs, mots reserves, entiers, reels, chaines et
            caracteres quotes, commentaires imbriques (* *), operateurs
            (:=, <:, .., etc.), ponctuation et EOF.

  TODO 09 - Implementer le parser des interfaces (.i3):
            INTERFACE nom; IMPORT, declarations exportees, END nom.,
            distinction entre fichier .i3 (interface) et .m3 (module).

  TODO 10 - Implementer le parser des modules (.m3):
            MODULE nom EXPORTS interfaces; IMPORT, declarations,
            bloc BEGIN...END nom. et verification de coherence
            entre une interface et son module d'implementation.

  TODO 11 - Implementer IMPORT / FROM...IMPORT et la table des unites:
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
  ErrorCount    : Integer;
 End;

Var
 Options     : TCompilerOptions;
 Pipeline    : TPipelineState;
 TotalErrors : Integer;
 SourceIndex : Integer;

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

Procedure PipelineError(Msg:String);
Begin
 Inc(Pipeline.ErrorCount);
 WriteLn('Erreur: ',Msg,' dans ',StageName(Pipeline.CurrentStage));
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

(* Les corps ci-dessous sont des jalons d'etapes; leur contenu reel
   sera fourni par les TODOs 05 a 24 (writers, lexer, parser, etc.). *)
Procedure LoadSource;
Begin
 EnterStage(CS_LOAD_SOURCE);
 FinishStage(CS_LOAD_SOURCE);
End;

Procedure RunLexer;
Begin
 EnterStage(CS_LEXER);
 FinishStage(CS_LEXER);
End;

Procedure RunParser;
Begin
 EnterStage(CS_PARSER);
 FinishStage(CS_PARSER);
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
 FinishStage(CS_OBJ_COFF);
End;

Procedure WriteExePe32;
Begin
 EnterStage(CS_EXE_PE32);
 FinishStage(CS_EXE_PE32);
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
 TotalErrors:=0;
 For SourceIndex:=1 To Options.SourceCount Do Begin
  CompilePipeline(Options.SourceNames[SourceIndex]);
  Inc(TotalErrors,Pipeline.ErrorCount);
 End;
 If TotalErrors<>0 Then Halt(1);
END.
