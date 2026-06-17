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

  TODO 02 - Ajouter les options de ligne de commande:
            -c pour produire seulement un .OBJ, -S pour produire/conserver
            le .ASM sur demande explicite, -o nom_sortie, --version et -h.

  TODO 03 - Definir le modele cible Win32:
            mode plat 32 bits, sections .text/.data/.bss, alignements,
            conventions d'appel internes, prologues/epilogues et pile 80386.

  TODO 04 - Implementer un writer ASM 80386 optionnel:
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

Type
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
  SourceLines     : LongInt;
  SourceBytes     : LongInt;
  ErrorCount      : Integer;
  ErrorMessage    : String;
 End;

Var
 Pipeline : TPipelineState;

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

Function LowerStr(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 To Length(S) Do
  If (S[I]>='A') And (S[I]<='Z') Then
   S[I]:=Chr(Ord(S[I])+32);
 LowerStr:=S;
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

Procedure PipelineError(Msg:String);
Begin
 Inc(Pipeline.ErrorCount);
 Pipeline.ErrorMessage:=Msg;
 WriteLn('MOD2CW32: ',Msg);
End;

Procedure InitPipeline(SourceName:String);
Begin
 FillChar(Pipeline,SizeOf(Pipeline),0);
 Pipeline.SourceName:=SourceName;
 Pipeline.ModuleName:=FileBaseName(SourceName);
 Pipeline.AsmName:=ChangeExtension(SourceName,MOD2_ASM_EXT);
 Pipeline.ObjName:=ChangeExtension(SourceName,MOD2_OBJ_EXT);
 Pipeline.ExeName:=ChangeExtension(SourceName,MOD2_EXE_EXT);
 Pipeline.CurrentStage:=CS_LOAD_SOURCE;
 Pipeline.LastCompleted:=CS_LOAD_SOURCE;
 Pipeline.OutputKind:=OK_EXE_PE32;
 Pipeline.EmitAsm:=False;
 Pipeline.StopAfterObj:=False;
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
  PipelineError('impossible de lire '+Pipeline.SourceName);
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
 PipelineError('lexer Modula-2 pas encore implemente');
End;

Procedure RunParser;
Begin
 EnterStage(CS_PARSER);
 PipelineError('parser Modula-2 pas encore implemente');
End;

Procedure BuildSemanticTables;
Begin
 EnterStage(CS_SEMANTIC_TABLES);
 PipelineError('tables semantiques pas encore implementees');
End;

Procedure BuildSimpleIR;
Begin
 EnterStage(CS_IR);
 PipelineError('IR simple pas encore implemente');
End;

Procedure EmitOptionalAsm;
Begin
 EnterStage(CS_ASM_80386);
 PipelineError('emission ASM 80386 pas encore implementee');
End;

Procedure WriteObjCoff;
Begin
 EnterStage(CS_OBJ_COFF);
 PipelineError('emission OBJ COFF i386 pas encore implementee');
End;

Procedure WriteExePe32;
Begin
 EnterStage(CS_EXE_PE32);
 PipelineError('emission EXE PE32 pas encore implementee');
End;

Procedure CompilePipeline(SourceName:String);
Begin
 InitPipeline(SourceName);
 TracePipelineLayout;
 WriteLn('Entree : ',Pipeline.SourceName);
 WriteLn('ASM    : ',Pipeline.AsmName,' (sur demande)');
 WriteLn('OBJ    : ',Pipeline.ObjName);
 WriteLn('EXE    : ',Pipeline.ExeName,' (defaut)');
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
 WriteLn('MOD2CW32 - Cette commande permet de ',
         'lancer le compilateur Modula-2 pour l''assembleur du microprocesseur ',
         '80386 pour Windows 32 bits.');
 WriteLn;
 WriteLn('Syntaxe : MOD2CW32 <source.mod> [options]');
 WriteLn;
 WriteLn('Options :');
 WriteLn('  -o <fichier>  : specifier le nom du fichier de sortie');
 WriteLn('  -v            : mode verbeux');
 WriteLn('  -h, --help    : afficher cette aide');
 WriteLn('  --version     : afficher la version');
End;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  PrintUsage;
  Halt;
 End;
 If ParamCount=0 Then Begin
  InitPipeline('programme'+MOD2_DEFAULT_EXT);
  TracePipelineLayout;
  WriteLn('Syntaxe: MOD2CW32 fichier.mod');
  Halt(1);
 End;
 CompilePipeline(ParamStr(1));
 If Pipeline.ErrorCount<>0 Then Halt(1);
END.
