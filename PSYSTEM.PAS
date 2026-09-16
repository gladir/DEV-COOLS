{ @author: Sylvain Maltais (support@gladir.com)
 @created: 2026
 @website(https://www.gladir.com/dev-cools)
 @abstract(Target: Turbo Pascal 7 / Free Pascal 3.2)
 @abstract: Environnement de commandes inspire du UCSD p-System.
 @license: MIT }

Program PSYSTEM;

{$A-,B-,I-,R-,S-}

Uses Dos;

Const
 Version='1.0';

Type
 TPSYSTEMTarget=(ptAppleHeath,ptUCSDPascalII,ptUCSDPSystemIII,ptUCSDPSystemIV);
 TSingleBits=Record Case Boolean of False:(S:Single);
 True:(L:LongInt)
End;

Var
 WorkFile,ProgramFile,WorkTitle:String;
 Finished:Boolean;
 CurrentTarget:TPSYSTEMTarget;
 OriginalErrors:Boolean;
 CheckCodeRequested:Boolean;

Function TrimString(S:String):String;Begin
 While(Length(S)>0)and(S[1]in[' ',#9])do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[' ',#9])do Delete(S,Length(S),1);
 TrimString:=S
End;

Function UpperString(S:String):String;
Var
 I:Integer;
Begin
 For I:=1 to Length(S)do S[I]:=UpCase(S[I]);UpperString:=S
End;

Function QuoteName(S:String):String;Begin
 if Pos(' ',S)<>0 Then QuoteName:='"'+S+'"'else QuoteName:=S
End;

Function ReplaceExtension(S,Ext:String):String;
Var
 I,P:Integer;
Begin
 P:=0;
 For I:=Length(S)downto 1 do Begin
  if S[I]='.'Then Begin
   P:=I;Break
  End;
  if S[I]in['\','/',':']Then Break
 End;
 if P<>0 Then S:=Copy(S,1,P-1);ReplaceExtension:=S+Ext
End;

Function ToolName(VariableName,DefaultName:String):String;
Var
 R:String;
Begin
 R:=GetEnv(VariableName);if R=''Then R:=DefaultName;ToolName:=R
End;

Function RunShell(CommandLine:String):Integer;
Var
 ShellName,Parameters:String;
 ResultCode:Word;
Begin
 ShellName:=GetEnv('COMSPEC');
 if ShellName=''Then ShellName:='COMMAND.COM';
 Parameters:='/C '+CommandLine;SwapVectors;Exec(ShellName,Parameters);SwapVectors;
 if DosError<>0 Then Begin
  WriteLn('Unable to start command processor (error ',DosError,').');RunShell:=DosError
 End else
 Begin
  ResultCode:=DosExitCode;RunShell:=Lo(ResultCode)
 End
End;

Procedure AskFile(Prompt:String;Var Name:String);
Var
 S:String;
Begin
 if Name<>''Then Write(Prompt,' [',Name,']: ')else Write(Prompt,': ');
 ReadLn(S);S:=TrimString(S);if S<>''Then Name:=S
End;

Function FileExists(Name:String):Boolean;
Var
 F:File;
 Exists:Boolean;
Begin
 Assign(F,Name);Reset(F,1);Exists:=IOResult=0;
 if Exists Then Begin
  Close(F);if IOResult<>0 Then Exists:=False
 End;
 FileExists:=Exists
End;

Function AssociatedCodeName(Const Name:String):String;
Begin
 if UpperString(Name)='SYSTEM.WRK.TEXT'Then AssociatedCodeName:='SYSTEM.WRK.CODE'
 else AssociatedCodeName:=ReplaceExtension(Name,'.CODE')
End;

Function WorkTextName(Name:String):String;
Var I:Integer;HasDot:Boolean;
Begin
 Name:=TrimString(Name);HasDot:=False;
 For I:=Length(Name)downto 1 do Begin
  if Name[I]='.'Then Begin HasDot:=True;Break End;
  if Name[I]in['\','/',':']Then Break
 End;
 if not HasDot Then Name:=Name+'.TEXT';WorkTextName:=Name
End;

Function CopyHostFile(Const Source,Target:String):Boolean;
Var A,B:File;Buffer:Array[1..8192]of Byte;N,W:Word;OK:Boolean;
Begin
 CopyHostFile:=False;
 if UpperString(FExpand(Source))=UpperString(FExpand(Target))Then Begin
  CopyHostFile:=FileExists(Source);Exit
 End;
 Assign(A,Source);Reset(A,1);if IOResult<>0 Then Exit;
 Assign(B,Target);Rewrite(B,1);if IOResult<>0 Then Begin Close(A);if IOResult<>0 Then Begin End;Exit End;
 OK:=True;
 Repeat
  BlockRead(A,Buffer,SizeOf(Buffer),N);if IOResult<>0 Then Begin OK:=False;Break End;
  if N<>0 Then Begin BlockWrite(B,Buffer,N,W);if(IOResult<>0)or(W<>N)Then OK:=False End
 Until(N=0)or not OK;
 Close(A);if IOResult<>0 Then OK:=False;Close(B);if IOResult<>0 Then OK:=False;
 CopyHostFile:=OK
End;

Procedure RemoveHostFile(Const Name:String);
Var F:File;
Begin
 if not FileExists(Name)Then Exit;Assign(F,Name);Erase(F);if IOResult<>0 Then
  WriteLn('Impossible de supprimer ',Name,'.')
End;

Procedure EditCommand;
Type
 PEditLine=^TEditLine;
 TEditLine=Record Text:String;Next:PEditLine End;
Var
 Head,Tail,P,Q,N:PEditLine;
 F:Text;
 S,Cmd,Arg,Answer:String;
 LineNo,Count,Code,I:Integer;
 Dirty,Done,Loaded:Boolean;

Function LineAt(N:Integer):PEditLine;
Var X:PEditLine;K:Integer;
Begin X:=Head;K:=1;While(X<>Nil)and(K<N)do Begin X:=X^.Next;Inc(K) End;LineAt:=X End;

Function LeftTrim(S:String):String;
Begin While(S<>'')and(S[1]in[' ',#9])do Delete(S,1,1);LeftTrim:=S End;

Procedure SplitCommand(Const Input:String;Var C,A:String);
Var K:Integer;
Begin
 K:=1;While(K<=Length(Input))and not(Input[K]in[' ',#9])do Inc(K);
 if K>Length(Input)Then Begin C:=UpperString(Input);A:='' End
 else Begin C:=UpperString(Copy(Input,1,K-1));A:=Copy(Input,K+1,255) End
End;

Function ReadNumber(Var A:String;Default:Integer):Integer;
Var T:String;K,E,V:Integer;
Begin
 A:=LeftTrim(A);K:=1;While(K<=Length(A))and not(A[K]in[' ',#9])do Inc(K);
 if K>Length(A)Then Begin T:=A;A:='' End
 else Begin T:=Copy(A,1,K-1);Delete(A,1,K) End;
 if T=''Then V:=Default else Begin Val(T,V,E);if E<>0 Then V:=-1 End;ReadNumber:=V
End;

Procedure ShowLines(First,HowMany:Integer);
Var X:PEditLine;K:Integer;
Begin
 if First<1 Then First:=1;if HowMany<1 Then HowMany:=20;X:=LineAt(First);K:=First;
 While(X<>Nil)and(HowMany>0)do Begin WriteLn(K:5,'  ',X^.Text);X:=X^.Next;
  Inc(K);Dec(HowMany) End
End;

Procedure InsertLine(AtLine:Integer;Const V:String);
Var X,Prev:PEditLine;
Begin
 New(X);X^.Text:=V;X^.Next:=Nil;
 if(Head=Nil)or(AtLine<=1)Then Begin X^.Next:=Head;Head:=X;if Tail=Nil Then Tail:=X End
 else Begin Prev:=LineAt(AtLine-1);if Prev=Nil Then Begin Tail^.Next:=X;Tail:=X End
  else Begin X^.Next:=Prev^.Next;Prev^.Next:=X;if X^.Next=Nil Then Tail:=X End End;
 Inc(LineNo);Dirty:=True
End;

Procedure DeleteLines(AtLine,HowMany:Integer);
Var Prev,X:PEditLine;
Begin
 if(AtLine<1)or(HowMany<1)Then Exit;
 if AtLine=1 Then Prev:=Nil else Prev:=LineAt(AtLine-1);
 if Prev=Nil Then X:=Head else X:=Prev^.Next;
 While(X<>Nil)and(HowMany>0)do Begin Q:=X^.Next;Dispose(X);X:=Q;Dec(HowMany);Dec(LineNo) End;
 if Prev=Nil Then Head:=X else Prev^.Next:=X;
 Tail:=Head;if Tail<>Nil Then While Tail^.Next<>Nil do Tail:=Tail^.Next;Dirty:=True
End;

Function SaveFile:Boolean;
Var X:PEditLine;E:Integer;HadCode:Boolean;
Begin
 SaveFile:=False;
 if(UpperString(WorkFile)='SYSTEM.WRK.TEXT')and FileExists(WorkFile)Then
  if not CopyHostFile(WorkFile,'SYSTEM.WRK.BACK')Then
   WriteLn('Avertissement: impossible de creer SYSTEM.WRK.BACK.');
 HadCode:=FileExists(AssociatedCodeName(WorkFile));
 Assign(F,WorkFile);Rewrite(F);E:=IOResult;if E<>0 Then Begin
  WriteLn('Impossible de creer ',WorkFile,' (erreur ',E,').');Exit
 End;
 X:=Head;While X<>Nil do Begin WriteLn(F,X^.Text);E:=IOResult;if E<>0 Then Break;X:=X^.Next End;
 Close(F);if E=0 Then E:=IOResult;
 if E<>0 Then WriteLn('Erreur d''ecriture ',E,'.')else Begin
  ProgramFile:=AssociatedCodeName(WorkFile);if HadCode Then RemoveHostFile(ProgramFile);
  Dirty:=False;SaveFile:=True;WriteLn(LineNo,' ligne(s) sauvegardee(s).');
  if HadCode Then WriteLn('La partie CODE devenue obsolete a ete supprimee.')
 End
End;

Procedure EditorHelp;
Begin
 WriteLn('L [ligne] [nombre]  Lister le texte');
 WriteLn('I ligne texte        Inserer avant une ligne');
 WriteLn('A texte              Ajouter une ligne a la fin');
 WriteLn('R ligne texte        Remplacer une ligne');
 WriteLn('D ligne [nombre]     Supprimer une ou plusieurs lignes');
 WriteLn('F texte              Rechercher du texte');
 WriteLn('W                    Sauvegarder');
 WriteLn('Q                    Quitter (Q! abandonne les changements)');
 WriteLn('?                    Afficher cette aide')
End;
Begin
 if WorkFile=''Then AskFile('Fichier a editer',WorkFile);if WorkFile=''Then Exit;
 Head:=Nil;Tail:=Nil;LineNo:=0;Dirty:=False;Loaded:=False;
 Assign(F,WorkFile);Reset(F);
 if IOResult=0 Then Begin
  Loaded:=True;
  While not Eof(F)do Begin ReadLn(F,S);Code:=IOResult;if Code<>0 Then Break;
   New(P);P^.Text:=S;P^.Next:=Nil;if Head=Nil Then Head:=P else Tail^.Next:=P;
   Tail:=P;Inc(LineNo)
  End;Close(F);Code:=IOResult;
  if Code<>0 Then WriteLn('Avertissement: lecture incomplete du fichier.')
 End;
 if Loaded Then WriteLn(LineNo,' ligne(s) chargee(s).')
 else WriteLn('Nouveau fichier: ',WorkFile);
 EditorHelp;Done:=False;
 Repeat
  Write('Edit> ');ReadLn(S);S:=LeftTrim(S);if S=''Then Continue;
  SplitCommand(S,Cmd,Arg);
  if(Cmd='?')or(Cmd='H')Then EditorHelp
  else if Cmd='L'Then Begin
   I:=ReadNumber(Arg,1);Count:=ReadNumber(Arg,20);
   if I<1 Then WriteLn('Numero de ligne incorrect.')else ShowLines(I,Count)
  End
  else if Cmd='I'Then Begin
   I:=ReadNumber(Arg,-1);if I<1 Then WriteLn('Syntaxe: I ligne texte')
   else InsertLine(I,Arg)
  End
  else if Cmd='A'Then InsertLine(LineNo+1,Arg)
  else if Cmd='R'Then Begin
   I:=ReadNumber(Arg,-1);P:=LineAt(I);if P=Nil Then WriteLn('Ligne inexistante.')
   else Begin P^.Text:=Arg;Dirty:=True End
  End
  else if Cmd='D'Then Begin
   I:=ReadNumber(Arg,-1);Count:=ReadNumber(Arg,1);
   if(I<1)or(LineAt(I)=Nil)Then WriteLn('Ligne inexistante.')else DeleteLines(I,Count)
  End
  else if Cmd='F'Then Begin
   P:=Head;I:=1;Count:=0;
   While P<>Nil do Begin if Pos(UpperString(Arg),UpperString(P^.Text))<>0 Then Begin
    WriteLn(I:5,'  ',P^.Text);Inc(Count) End;P:=P^.Next;Inc(I) End;
   WriteLn(Count,' occurrence(s).')
  End
  else if Cmd='W'Then Begin if SaveFile Then ProgramFile:=AssociatedCodeName(WorkFile) End
  else if Cmd='Q!'Then Done:=True
  else if Cmd='Q'Then Begin
   if Dirty Then Begin Write('Sauvegarder les changements (O/N/Annuler) ? ');ReadLn(Answer);
    Answer:=UpperString(TrimString(Answer));if(Answer='O')or(Answer='OUI')Then Done:=SaveFile
    else if(Answer='N')or(Answer='NON')Then Done:=True End else Done:=True
  End else WriteLn('Commande inconnue. Tapez ? pour l''aide.')
 Until Done;
 P:=Head;While P<>Nil do Begin N:=P^.Next;Dispose(P);P:=N End
End;
Function CompilePascalPCode(SourceName,CodeName:String):Integer;Forward;
Function ExecutePCodeFile(Const FileName:String):Integer;Forward;

Function CompileWork(AskName:Boolean):Boolean;
Var
 Code:Integer;
Begin
 CompileWork:=False;if AskName or(WorkFile='')Then AskFile('Fichier source',WorkFile);
 if WorkFile=''Then Exit;
 if not FileExists(WorkFile)Then Begin
  WriteLn('Fichier de travail introuvable: ',WorkFile);Exit
 End;
 ProgramFile:=AssociatedCodeName(WorkFile);
 WriteLn('Compilation UCSD de ',WorkFile,' ...');
 Code:=CompilePascalPCode(WorkFile,ProgramFile);
 if Code<>0 Then Begin
  WriteLn('Compile failed (status ',Code,').');Exit
 End;
 CompileWork:=True;
 WriteLn('Compilation complete.')
End;

Procedure RunCommand;
Var Code:Integer;
Begin
 if WorkFile=''Then AskFile('Source file',WorkFile);
 if WorkFile=''Then Exit;
 if(ProgramFile='')or not FileExists(ProgramFile)Then  if not CompileWork(False)Then Exit;
 WriteLn('Execution de ',ProgramFile,' avec la machine virtuelle integree ...');
 Code:=ExecutePCodeFile(ProgramFile);
 WriteLn;WriteLn('Fin du programme p-Code (code ',Code,').')
End;

Type
 TPCodeMemory=Array[0..65534]of Byte;
 PPCodeMemory=^TPCodeMemory;
 TPCodeData=Array[0..8191]of LongInt;
 PPCodeData=^TPCodeData;
 TPCodeRuntimeFile=Record
 Used,Opened,TextMode,Writing:Boolean;
 Name:String[127];
 T:Text;
 F:File;
 Buffer,BufferAddress:LongInt;
 RecordWords:Integer;
 LastError:Integer
End;

Var
 PCode_Mem:PPCodeMemory;
 PCode_Data:PPCodeData;
 PCode_CodeSize,PCode_PC,PCode_SP,PCode_MP,PCode_Cycles:LongInt;
 PCode_SegmentSize,PCode_ProcDict,PCode_Base:LongInt;
 PCode_ProcCount,PCode_CurrentProc:Integer;
 PCode_StringHeap:LongInt;
 PCode_Files:Array[1..16]of TPCodeRuntimeFile;
 PCode_LastIOError:Integer;
 PCode_IOChecking:Boolean;
 PCode_FreeStart,PCode_FreeSize:Array[1..64]of LongInt;
 PCode_FreeCount:Integer;
 PCode_ExternalData:Array[0..15,0..1023]of LongInt;
 PCode_IsIVSegment,PCode_HasProcDictionary:Boolean;
 PCode_Halted:Boolean;
 PCode_ExitCode:Integer;

Function PCode_IntToStr(V:LongInt):String;
Var
 S:String;
Begin
 Str(V,S);PCode_IntToStr:=S
End;

Procedure PCode_Write(S:String);Begin
 Write(S)
End;

Procedure PCode_PutChar(C:Char);Begin
 Write(C)
End;
Function PCode_DataAt(A:LongInt):LongInt;Forward;
Procedure PCode_DataSet(A:LongInt;V:LongInt);Forward;
Procedure PCode_RuntimeError(Code:Integer;Const Msg:String);Forward;
Function PCode_Fetch(Ofs:LongInt):Byte;Forward;

Function PCode_StringLength(A:LongInt):Integer;
Var
 N:LongInt;
Begin
 if A>=30000 Then N:=PCode_Fetch(A-30000-1)else N:=PCode_DataAt(A);
 if N<0 Then N:=0;if N>255 Then N:=255;PCode_StringLength:=N
End;

Function PCode_StringChar(A:LongInt;I:Integer):Byte;Begin
 if(I<1)or(I>PCode_StringLength(A))Then PCode_StringChar:=0
 else if A>=30000 Then PCode_StringChar:=PCode_Fetch(A-30000+I-1)
 else PCode_StringChar:=Byte(PCode_DataAt(A+I))
End;

Function PCode_NewString(A,B:LongInt;StartA,CountA,StartB,CountB:Integer):LongInt;
Var
 D,I,N:LongInt;
Begin
 D:=PCode_StringHeap;N:=0;
 For I:=0 to CountA-1 do if(StartA+I>=1)and(StartA+I<=PCode_StringLength(A))Then Begin
  Inc(N);PCode_DataSet(D+N,PCode_StringChar(A,StartA+I))
 End;
 For I:=0 to CountB-1 do if(StartB+I>=1)and(StartB+I<=PCode_StringLength(B))and(N<255)
 Then Begin
  Inc(N);PCode_DataSet(D+N,PCode_StringChar(B,StartB+I))
 End;PCode_DataSet(D,N);Inc(PCode_StringHeap,N+1);PCode_NewString:=D
End;

Procedure PCode_AssignString(D,S:LongInt;MaxLen:Integer);
Var
 I,N:Integer;
Begin
 N:=PCode_StringLength(S);if N>MaxLen Then N:=MaxLen;PCode_DataSet(D,N);
 For I:=1 to N do PCode_DataSet(D+I,PCode_StringChar(S,I))
End;

Function PCode_CharString(C:LongInt):LongInt;
Var
 D:LongInt;
Begin
 D:=PCode_StringHeap;PCode_DataSet(D,1);PCode_DataSet(D+1,Byte(C));
 Inc(PCode_StringHeap,2);
 PCode_CharString:=D
End;
Procedure PCode_IOError(H,E:Integer);Forward;

Function PCode_Allocate(Words:Integer):LongInt;
Var
A,I,J:LongInt;
Begin
 if Words<1 Then Begin PCode_RuntimeError(303,'taille d''allocation invalide');PCode_Allocate:=0;Exit End;
 For I:=1 to PCode_FreeCount do if PCode_FreeSize[I]>=Words Then Begin
  A:=PCode_FreeStart[I];Inc(PCode_FreeStart[I],Words);Dec(PCode_FreeSize[I],Words);
  if PCode_FreeSize[I]=0 Then Begin
   PCode_FreeStart[I]:=PCode_FreeStart[PCode_FreeCount];
   PCode_FreeSize[I]:=PCode_FreeSize[PCode_FreeCount];Dec(PCode_FreeCount)
  End;
  For J:=0 to Words-1 do PCode_DataSet(A+J,0);PCode_Allocate:=A;Exit
 End;A:=PCode_StringHeap;
 if(PCode_HasProcDictionary and(A+Words>=PCode_SP-32))or
  ((not PCode_HasProcDictionary)and(A+Words>High(PCode_Data^)))Then Begin
  PCode_RuntimeError(303,'tas p-code plein');PCode_Allocate:=0;Exit
 End;
 For I:=0 to Words-1 do PCode_DataSet(A+I,0);Inc(PCode_StringHeap,Words);PCode_Allocate:=A
End;

Procedure PCode_Release(A:LongInt;Words:Integer);
Var I,J:Integer;Changed:Boolean;
Begin
 if(A<=0)or(Words<=0)or(A+Words>PCode_StringHeap)Then Begin
  PCode_RuntimeError(303,'liberation de tas invalide');Exit
 End;
 For I:=1 to PCode_FreeCount do
  if(A<PCode_FreeStart[I]+PCode_FreeSize[I])and(PCode_FreeStart[I]<A+Words)Then Begin
   PCode_RuntimeError(303,'bloc de tas deja libere');Exit
  End;
 if PCode_FreeCount>=64 Then Begin PCode_RuntimeError(303,'table des blocs libres pleine');Exit End;
 Inc(PCode_FreeCount);PCode_FreeStart[PCode_FreeCount]:=A;PCode_FreeSize[PCode_FreeCount]:=Words;
 Repeat
  Changed:=False;I:=1;
  While I<=PCode_FreeCount do Begin J:=I+1;
   While J<=PCode_FreeCount do Begin
    if PCode_FreeStart[I]+PCode_FreeSize[I]=PCode_FreeStart[J]Then Begin
     Inc(PCode_FreeSize[I],PCode_FreeSize[J]);
     PCode_FreeStart[J]:=PCode_FreeStart[PCode_FreeCount];
     PCode_FreeSize[J]:=PCode_FreeSize[PCode_FreeCount];Dec(PCode_FreeCount);Changed:=True
    End else if PCode_FreeStart[J]+PCode_FreeSize[J]=PCode_FreeStart[I]Then Begin
     PCode_FreeStart[I]:=PCode_FreeStart[J];Inc(PCode_FreeSize[I],PCode_FreeSize[J]);
     PCode_FreeStart[J]:=PCode_FreeStart[PCode_FreeCount];
     PCode_FreeSize[J]:=PCode_FreeSize[PCode_FreeCount];Dec(PCode_FreeCount);Changed:=True
    End else Inc(J)
   End;Inc(I)
  End
 Until not Changed;
 For I:=1 to PCode_FreeCount do if PCode_FreeStart[I]+PCode_FreeSize[I]=PCode_StringHeap Then Begin
  PCode_StringHeap:=PCode_FreeStart[I];PCode_FreeStart[I]:=PCode_FreeStart[PCode_FreeCount];
  PCode_FreeSize[I]:=PCode_FreeSize[PCode_FreeCount];Dec(PCode_FreeCount);Break
 End
End;

Procedure PCode_InitFiles;
Var
 I:Integer;
Begin
 For I:=1 to 16 do Begin
  PCode_Files[I].Used:=False;PCode_Files[I].Opened:=False
 End;
 PCode_LastIOError:=0;PCode_IOChecking:=True;PCode_FreeCount:=0
End;

Function PCode_MapFileName(S:String):String;
Var
 P:Integer;
 U:String;
Begin
 U:=UpperString(S);
 if(U='PRINTER:')or(U='PRINTER')Then S:='PRN'
 else if(U='CONSOLE:')or(U='CONSOLE')or(U='KEYBOARD:')or(U='KEYBOARD')Then S:='CON'
 else
 Begin
  P:=Pos(':',S);
  if(P>1)and not((P=2)and(UpCase(S[1])in['A'..'Z']))Then S:=Copy(S,P+1,255)
 End;PCode_MapFileName:=S
End;

Procedure PCode_CloseFiles;
Var
 I,E:Integer;
Begin
 For I:=1 to 16 do if PCode_Files[I].Used and PCode_Files[I].Opened Then Begin
  if PCode_Files[I].TextMode Then Close(PCode_Files[I].T)else Close(PCode_Files[I].F);
  E:=IOResult;PCode_Files[I].LastError:=E;PCode_Files[I].Opened:=False
 End
End;

Function PCode_FileHandle(FileAddress:LongInt;CreateIt:Boolean):Integer;
Var
 H,I:Integer;
Begin
 H:=PCode_DataAt(FileAddress);
 if(H<1)or(H>16)or not PCode_Files[H].Used Then Begin
  H:=0;
  if CreateIt Then
  For I:=1 to 16 do if not PCode_Files[I].Used Then Begin
   H:=I;PCode_Files[I].Used:=True;PCode_Files[I].Opened:=False;
   PCode_Files[I].Name:='';PCode_Files[I].BufferAddress:=0;
   PCode_DataSet(FileAddress,H);Break
  End
 End;PCode_FileHandle:=H
End;

Procedure PCode_IOError(H,E:Integer);Begin
 PCode_LastIOError:=E;if(H>=1)and(H<=16)Then PCode_Files[H].LastError:=E;
 if(E<>0)and PCode_IOChecking Then Begin
  PCode_Write('[erreur E/S '+PCode_IntToStr(E)+']');
  PCode_Halted:=True;PCode_ExitCode:=E
 End
End;

Procedure PCode_OpenFile(FileAddress:LongInt;ForWriting:Boolean;RecordKind:Integer);
Var
 H,E:Integer;
Begin
 H:=PCode_FileHandle(FileAddress,True);if H=0 Then Begin
  PCode_IOError(0,4);Exit
 End;
 if PCode_Files[H].Opened Then Begin
  if PCode_Files[H].TextMode Then Close(PCode_Files[H].T)else Close(PCode_Files[H].F);
  E:=IOResult
 End;
 PCode_Files[H].TextMode:=RecordKind<0;PCode_Files[H].Writing:=ForWriting;
 if RecordKind<0 Then PCode_Files[H].RecordWords:=1
 else Begin PCode_Files[H].RecordWords:=RecordKind;if PCode_Files[H].RecordWords<1 Then
  PCode_Files[H].RecordWords:=1 End;
 if PCode_Files[H].BufferAddress=0 Then
  PCode_Files[H].BufferAddress:=PCode_Allocate(PCode_Files[H].RecordWords);
 if PCode_Files[H].TextMode Then Begin
  Assign(PCode_Files[H].T,PCode_Files[H].Name);
  if ForWriting Then Rewrite(PCode_Files[H].T)else Reset(PCode_Files[H].T)
 End else
 Begin
  Assign(PCode_Files[H].F,PCode_Files[H].Name);
  if ForWriting Then Rewrite(PCode_Files[H].F,1)else Reset(PCode_Files[H].F,1)
 End;E:=IOResult;PCode_Files[H].Opened:=E=0;PCode_IOError(H,E)
End;

{ Verificateur independant: ne confond pas les pointeurs auto-relatifs II
  avec les offsets absolus en mots du dictionnaire prive du clone.
  Champs II verifies contre segment_builder_code::procedure_end,
  ucsd-psystem-xc (description du format, pas reutilisation de son code). }
Function CheckUCSDCodeFile(FileName:String):Boolean;
Type
 THeader=Array[0..511]of Byte;
Var
 F:File;
 Header:THeader;
 Image:PPCodeMemory;
 Size,Start,LengthBytes,Slot,Attr,Entry,ExitAddress,DictStart:LongInt;
 Starts,Lengths:Array[0..15]of LongInt;
 I,J,P,Count,LexLevel,Kind,Seen:Integer;
 DataBytes,ParamBytes:LongInt;
 N:Word;
 BigEndian,PrivateFormat,OK,Readable:Boolean;
 SegmentName:String;

Function HW(Ofs:Integer):Word;Begin
 if BigEndian Then HW:=Word(Header[Ofs])*256+Header[Ofs+1]
 else HW:=Word(Header[Ofs+1])*256+Header[Ofs]
End;

Function IW(Ofs:LongInt):Word;Begin
 if BigEndian Then IW:=Word(Image^[Ofs])*256+Image^[Ofs+1]
 else IW:=Word(Image^[Ofs+1])*256+Image^[Ofs]
End;

Procedure Bad(S:String);Begin
 WriteLn('CODE invalide: ',S);OK:=False
End;

Function PlausibleHeader:Boolean;
Var K:Integer;A,L:LongInt;Found:Boolean;
Begin
 Found:=False;PlausibleHeader:=False;
 For K:=0 to 15 do Begin
  A:=LongInt(HW(K*4))*512;L:=HW(K*4+2);
  if(A<>0)and(L<>0)Then Begin
   if(A<512)or(A>Size)or(L>Size-A)Then Exit;Found:=True
  End
 End;PlausibleHeader:=Found
End;

Begin
 CheckUCSDCodeFile:=False;Image:=Nil;OK:=True;Seen:=0;
 Assign(F,FileName);Reset(F,1);
 if IOResult<>0 Then Begin WriteLn('Lecture CODE impossible: ',FileName);Exit End;
 Size:=FileSize(F);
 if(IOResult<>0)or(Size<512)Then Begin
  Close(F);if IOResult<>0 Then Begin End;
  WriteLn('Un fichier CODE segmente avec en-tete de 512 octets est requis.');Exit
 End;
 BlockRead(F,Header,512,N);Readable:=(IOResult=0)and(N=512);
 if not Readable Then Begin Close(F);if IOResult<>0 Then Begin End;Exit End;
 BigEndian:=False;
 if not PlausibleHeader Then Begin
  BigEndian:=True;
  if not PlausibleHeader Then Begin
   Close(F);if IOResult<>0 Then Begin End;Bad('en-tete ou bornes des segments');Exit
  End
 End;
 PrivateFormat:=(Header[288]=Ord('P'))and(Header[289]=Ord('S'))and
  (Header[290]=Ord('V'))and(Header[291]=Ord('M'));
 if PrivateFormat Then WriteLn('ABI prive PSYSTEM/PSVM (non certifie UCSD).')
 else WriteLn('Verification structurelle des attributs UCSD II.0/II.1.');
 if BigEndian Then WriteLn('Mots: grand-boutiste.')else WriteLn('Mots: petit-boutiste.');
 FillChar(Starts,SizeOf(Starts),0);FillChar(Lengths,SizeOf(Lengths),0);
 GetMem(Image,SizeOf(TPCodeMemory));
 For I:=0 to 15 do Begin
  Start:=LongInt(HW(I*4))*512;LengthBytes:=HW(I*4+2);
  if(Start=0)or(LengthBytes=0)Then Continue;
  Inc(Seen);SegmentName:='';
  For J:=64+I*8 to 71+I*8 do SegmentName:=SegmentName+Chr(Header[J]);
  Kind:=HW(192+I*2);
  WriteLn('Segment ',I,': ',TrimString(SegmentName),'  octets=',LengthBytes,
   '  bloc=',Start div 512,'  type=',Kind);
  For J:=0 to I-1 do
   if(Lengths[J]>0)and(Start<Starts[J]+Lengths[J])and
    (Starts[J]<Start+LengthBytes)Then Bad('segments de code superposes');
  Starts[I]:=Start;Lengths[I]:=LengthBytes;
  if Odd(LengthBytes)or(LengthBytes>SizeOf(TPCodeMemory))Then Begin
   Bad('taille de segment non alignee ou excessive');Continue
  End;
  Seek(F,Start);if IOResult<>0 Then Begin Bad('positionnement du segment');Continue End;
  BlockRead(F,Image^,LengthBytes,N);
  if(IOResult<>0)or(N<>LengthBytes)Then Begin Bad('lecture incomplete du segment');Continue End;
  if PrivateFormat Then Begin
   if LengthBytes<24 Then Begin Bad('segment prive trop court');Continue End;
   Slot:=LongInt(IW(0))*2;
   if(Slot<22)or(Slot+2>LengthBytes)Then Begin Bad('dictionnaire prive hors segment');Continue End;
   Count:=IW(Slot);DictStart:=Slot-LongInt(Count)*2;
   if(Count<1)or(Count>255)or(DictStart<22)Then Begin Bad('nombre de procedures prive');Continue End;
   For P:=1 to Count do Begin
    Attr:=LongInt(IW(Slot-P*2))*2;
    if(Attr<22)or(Attr+2>DictStart)Then Bad('attribut prive hors zone')
    else WriteLn(' Procedure ',P,': entree=',Attr+2,' locaux=',IW(Attr))
   End;Continue
  End;
  { IV a un format distinct: ne jamais le certifier avec les regles II. }
  if CurrentTarget=ptUCSDPSystemIV Then Begin
   Bad('validation du format IV historique non encore implementee');Continue
  End;
  if Kind=7 Then Begin WriteLn(' Segment de donnees, sans dictionnaire de procedures.');Continue End;
  if LengthBytes<4 Then Begin Bad('segment II trop court');Continue End;
  Count:=Image^[LengthBytes-1];DictStart:=LengthBytes-2-LongInt(Count)*2;
  if(Count=0)or(DictStart<0)Then Begin Bad('dictionnaire II hors segment');Continue End;
  WriteLn(' Numero de segment=',Image^[LengthBytes-2],' procedures=',Count);
  For P:=1 to Count do Begin
   Slot:=LengthBytes-2-P*2;
   if IW(Slot)=0 Then Begin WriteLn(' Procedure ',P,': entree absente.');Continue End;
   Attr:=Slot-IW(Slot);
   if(Attr<2)or(Attr+2>DictStart)or Odd(Attr)Then Begin
    Bad('pointeur auto-relatif de procedure hors zone');Continue
   End;
   if Image^[Attr]=0 Then Begin
    WriteLn(' Procedure ',P,': code natif; relogements non verifies.');
    Bad('verification complete du code natif non implementee');Continue
   End;
   if(Attr<8)or(Image^[Attr]<>P)Then Begin Bad('numero ou attributs de procedure II');Continue End;
   Entry:=Attr-2-IW(Attr-2);ExitAddress:=Attr-4-IW(Attr-4);
   DataBytes:=IW(Attr-8);ParamBytes:=IW(Attr-6);LexLevel:=Image^[Attr+1];
   if LexLevel>127 Then LexLevel:=LexLevel-256;
   if(Entry<0)or(Entry>ExitAddress)or(ExitAddress>=Attr-8)or Odd(Entry)
    or Odd(DataBytes)or Odd(ParamBytes)Then Begin
    Bad('entree, sortie ou tailles de cadre II invalides');Continue
   End;
   WriteLn(' Procedure ',P,': entree=',Entry,' sortie=',ExitAddress,
    ' locaux(octets)=',DataBytes,' parametres(octets)=',ParamBytes,' niveau=',LexLevel)
  End
 End;
 FreeMem(Image,SizeOf(TPCodeMemory));Close(F);
 if IOResult<>0 Then Bad('fermeture du fichier');
 if Seen=0 Then Bad('aucun segment de code');
 if OK Then WriteLn('Structure verifiee. ABI et execution non certifiees.');
 CheckUCSDCodeFile:=OK
End;

Function PCode_LoadRaw(Const FileName:String):Boolean;
Var
 F:File;
 Sz,SegmentSize,SegmentPos,AttrPos,LoadedSize:LongInt;
 ReadCount:Word;
 Header:Array[0..511]of Byte;
 ProcCount:Byte;
 I:Integer;
 Entry:LongInt;
 TargetInfo:Word;
Begin
 PCode_LoadRaw:=False;Assign(F,FileName);Reset(F,1);if IOResult<>0 Then Exit;
 Sz:=FileSize(F);
 if Sz<0 Then Begin
  Close(F);if IOResult<>0 Then Begin
  End;WriteLn('Fichier p-Code trop grand.');Exit
 End;
 FillChar(PCode_Mem^,SizeOf(TPCodeMemory),0);ReadCount:=0;
 LoadedSize:=Sz;
 if Sz>=512 Then Begin
  BlockRead(F,Header,512,ReadCount);SegmentPos:=(Header[0]or(Header[1]shl 8))*512;
  SegmentSize:=Header[2]or(Header[3]shl 8);
  if ReadCount=512 Then Begin
   TargetInfo:=Header[256]or(Header[257]shl 8);
   Case TargetInfo of
   $0101:CurrentTarget:=ptAppleHeath;
   $0201:CurrentTarget:=ptUCSDPascalII;
   $0301:CurrentTarget:=ptUCSDPSystemIII;
   $0401:CurrentTarget:=ptUCSDPSystemIV
  End
 End;
 if(ReadCount=512)and(SegmentPos>=512)and(SegmentSize>=14)and
 (SegmentPos+SegmentSize<=Sz)and(SegmentSize<=SizeOf(TPCodeMemory))Then Begin
  if not((Header[288]=Ord('P'))and(Header[289]=Ord('S'))and
   (Header[290]=Ord('V'))and(Header[291]=Ord('M')))Then Begin
   Close(F);if IOResult<>0 Then Begin End;
   WriteLn('Format CODE historique ou inconnu: ABI non prise en charge par cette VM.');
   WriteLn('Utilisez PSYSTEM fichier.CODE /CHECKCODE pour verifier sa structure.');Exit
  End;
  Seek(F,SegmentPos);ReadCount:=0;BlockRead(F,PCode_Mem^,SegmentSize,ReadCount);
  LoadedSize:=SegmentSize;
  AttrPos:=(PCode_Mem^[0]or(PCode_Mem^[1]shl 8))*2;
  if(CurrentTarget=ptUCSDPSystemIV)or
  ((AttrPos>=22)and(AttrPos+1<SegmentSize)and
  ((PCode_Mem^[AttrPos]or(PCode_Mem^[AttrPos+1]shl 8))>0))Then    PCode_CodeSize:=
  SegmentSize
  else
  Begin
   ProcCount:=PCode_Mem^[SegmentSize-2];
   AttrPos:=PCode_Mem^[SegmentSize-4]or(PCode_Mem^[SegmentSize-3]shl 8);
   if(ProcCount<1)or(AttrPos<0)or(AttrPos>SegmentSize-14)Then Begin
    Close(F);if IOResult<>0 Then Begin
    End;
    WriteLn('Dictionnaire de procedures invalide.');Exit
   End;PCode_CodeSize:=AttrPos
  End
 End else
 Begin
  if Sz>SizeOf(TPCodeMemory)Then Begin
   Close(F);if IOResult<>0 Then Begin
   End;Exit
  End;
  Seek(F,0);ReadCount:=0;if Sz>0 Then BlockRead(F,PCode_Mem^,Sz,ReadCount);
  LoadedSize:=Sz;PCode_CodeSize:=Sz
 End
End else
Begin
 if Sz>SizeOf(TPCodeMemory)Then Begin
  Close(F);if IOResult<>0 Then Begin
  End;Exit
 End;
 if Sz>0 Then BlockRead(F,PCode_Mem^,Sz,ReadCount);PCode_CodeSize:=Sz
End;
if(IOResult<>0)or(ReadCount<>LoadedSize)Then Begin
 Close(F);if IOResult<>0 Then Begin
 End;Exit
End;
Close(F);if IOResult<>0 Then Exit;
PCode_SegmentSize:=LoadedSize;PCode_ProcDict:=0;PCode_ProcCount:=0;
PCode_IsIVSegment:=False;PCode_HasProcDictionary:=False;
 { Un segment IV commence par l'offset, exprime en mots, de son
   dictionnaire de procedures. Le dictionnaire contient ensuite son compte. }
if LoadedSize>=24 Then Begin
 PCode_ProcDict:=(PCode_Mem^[0]or(PCode_Mem^[1]shl 8))*2;
 if(PCode_ProcDict>=22)and(PCode_ProcDict+1<LoadedSize)Then Begin
  PCode_ProcCount:=PCode_Mem^[PCode_ProcDict]or
  (PCode_Mem^[PCode_ProcDict+1]shl 8);
  PCode_IsIVSegment:=(PCode_ProcCount>0)and
  (PCode_ProcCount<=255)and(PCode_ProcDict-PCode_ProcCount*2>=22);
  if PCode_IsIVSegment Then
  For I:=1 to PCode_ProcCount do Begin
   Entry:=(PCode_Mem^[PCode_ProcDict-I*2]or
   (PCode_Mem^[PCode_ProcDict-I*2+1]shl 8))*2;
   if(Entry<22)or(Entry+1>=PCode_ProcDict-PCode_ProcCount*2)Then      PCode_IsIVSegment:=
   False
  End;
  PCode_HasProcDictionary:=PCode_IsIVSegment;
  if CurrentTarget<>ptUCSDPSystemIV Then PCode_IsIVSegment:=False
 End
End;
PCode_LoadRaw:=True
End;

Function TargetName:String;Begin
 Case CurrentTarget of
 ptAppleHeath:TargetName:='APPLEHEATH';
 ptUCSDPascalII:TargetName:='UCSDPASCALII';
 ptUCSDPSystemIII:TargetName:='UCSDPSYSTEMIII';
 else TargetName:='UCSDPSYSTEMIV'
End
End;

Function SelectTarget(S:String):Boolean;Begin
 S:=UpperString(S);SelectTarget:=True;
 if(S='APPLEHEALT')or(S='APPLEHEATH')or(S='APPLE')or(S='HEATH')Then  CurrentTarget:=
 ptAppleHeath
 else if(S='UCSDPASCALII')or(S='PASCALII')or(S='II')Then CurrentTarget:=ptUCSDPascalII
 else if(S='UCSDPSYSTEMIII')or(S='PSYSTEMIII')or(S='III')Then CurrentTarget:=
 ptUCSDPSystemIII
 else if(S='UCSDPSYSTEMIV')or(S='PSYSTEMIV')or(S='IV')Then CurrentTarget:=ptUCSDPSystemIV
 else SelectTarget:=False
End;

Function PCode_Fetch(Ofs: LongInt): Byte;Begin
 If (Ofs >= 0) And (Ofs < PCode_CodeSize) Then PCode_Fetch := PCode_Mem^[Ofs]
 Else PCode_Fetch := 0;
End;
{ BIG : MSB=0 => 1 octet (0..127) ; MSB=1 => 14 bits sur 2 octets (grand-boutiste). }

Function PCode_ReadBig(Ofs: LongInt; Var Used: Integer): Integer;
Var
 B1, B2: Byte;
Begin
 B1 := PCode_Fetch(Ofs);
 If B1 < 128 Then Begin
  Used := 1; PCode_ReadBig := B1;
 End
 Else
 Begin
  B2 := PCode_Fetch(Ofs + 1);
  Used := 2;
  PCode_ReadBig := (Integer(B1 And $7F) * 256) + B2;
 End;
End;

Procedure PCode_Push(V: LongInt);Begin
 If PCode_Halted Then Exit;
 If PCode_HasProcDictionary Then Begin
  If PCode_SP>0 Then Begin
   Dec(PCode_SP);PCode_Data^[PCode_SP]:=V
  End
  Else
  Begin
   PCode_Write('[depassement de pile p-code]');PCode_Halted:=True;PCode_ExitCode:=1
  End
 End Else If PCode_SP < 4064 Then Begin
  PCode_Data^[PCode_SP] := V;Inc(PCode_SP);
 End Else
 Begin
  PCode_Write('[depassement de pile p-code]');
  PCode_Halted := True;
  PCode_ExitCode := 1;
 End;
End;

Function PCode_Pop: LongInt;Begin
 If PCode_HasProcDictionary Then Begin
  If PCode_SP<=High(PCode_Data^)Then Begin
   PCode_Pop:=PCode_Data^[PCode_SP];Inc(PCode_SP)
  End Else
  Begin
   If Not PCode_Halted Then PCode_Write('[pile p-code vide]');
   PCode_Halted:=True;PCode_ExitCode:=1;PCode_Pop:=0
  End
 End Else If PCode_SP > 0 Then Begin
  Dec(PCode_SP);
  PCode_Pop := PCode_Data^[PCode_SP];
 End Else
 Begin
  If Not PCode_Halted Then   PCode_Write('[pile p-code vide]');
  PCode_Halted := True;
  PCode_ExitCode := 1;
  PCode_Pop := 0;
 End;
End;

Function PCode_DataAt(A: LongInt): LongInt;Begin
 If (A>=100000)and(A<116384)Then  PCode_DataAt:=PCode_ExternalData[(A-100000)div 1024,(A-
 100000)mod 1024]
 Else If (A >= 0) And (A <= High(PCode_Data^)) Then PCode_DataAt := PCode_Data^[A]
 Else
 Begin
  PCode_DataAt := 0;
 End;
End;

Procedure PCode_DataSet(A: LongInt; V: LongInt);Begin
 If (A>=100000)and(A<116384)Then  PCode_ExternalData[(A-100000)div 1024,(A-100000)
 mod 1024]:=V
 Else If (A >= 0) And (A <= High(PCode_Data^)) Then PCode_Data^[A] := V;
End;
{ Resout la base de cadre a Lvl chainons statiques (mot 0 du cadre = lien   }
{ statique) en amont du cadre courant (PCode_MP). Lvl=0 => cadre courant.   }

Function PCode_StaticBase(Lvl: Integer): LongInt;
Var
 FB: LongInt;
 I: Integer;
Begin
 FB := PCode_MP;
 For I := 1 To Lvl Do FB := PCode_DataAt(FB);
 PCode_StaticBase := FB;
End;
{ Appel d unite externe (CXP) 0 = runtime hote (E/S console, adapte de la  }
{ numerotation SYSTEM.PASCAL documentee par DISPCODE/PDECODE, mais avec une }
{ convention de parametrage SIMPLIFIEE de mon fait : valeurs directement    }
{ sur la pile, sans descripteur de fichier - voir memoire projet).          }

Procedure PCode_CallUnit0(ProcNum: Byte);
Var
 V, Addr, N, I: Integer;
 S: String;
Begin
 Case ProcNum Of
 2:
 Begin
 { execerror : arret avec code d erreur } N := PCode_Pop;
  PCode_Write('[EXECERROR ' + PCode_IntToStr(N) + ']');
  PCode_Halted := True; PCode_ExitCode := N;
 End;
 12:
 Begin
  Read(V);if IOResult<>0 Then PCode_IOError(0,106)else PCode_Push(V)
 End;
 13:
 Begin
 { write integer } V := PCode_Pop; Str(V, S); PCode_Write(S); 
 End;
 16:
 Begin
  if Eof(Input)Then Begin PCode_IOError(0,100);PCode_Push(0) End
  else Begin Read(S);if IOResult<>0 Then PCode_IOError(0,106)
   else if S=''Then PCode_Push(0)else PCode_Push(Ord(S[1])) End
 End;
 17:
 Begin
 { write char } PCode_PutChar(Chr(Byte(PCode_Pop And $FF))); 
 End;
 19:
 Begin
 { write string : pile = [..., adresse, longueur] (longueur au sommet) }
  N := PCode_Pop; Addr := PCode_Pop;
  For I := 0 To N - 1 Do Begin
   If Addr >= 30000 Then         PCode_PutChar(Chr(PCode_Fetch(Addr - 30000 + I)))
   Else
   PCode_PutChar(Chr(Byte(PCode_DataAt(Addr + I) And $FF)));
  End;
 End;
 21:
 Begin
  ReadLn;if IOResult<>0 Then PCode_IOError(0,106)
 End;
 22:
 Begin
 { writeln } PCode_PutChar(#13); PCode_PutChar(#10); 
 End;
 Else
 PCode_RuntimeError(305,'procedure SYSTEM '+PCode_IntToStr(ProcNum)+' inconnue');
End;
End;
{ Appel de procedure standard (CSP). Table de numeros reprise de           }
{ DISPCODE.PAS (CSPName) - seules EXIT (4) et les no-op mathematiques sur   }
{ entiers (18=TRC, 19=RND, pas de reel donc identite) sont implementees.    }

Procedure PCode_CallCSP(CspNum: Byte);
Var
 N,I,P,H,E,Wid,Prec,Kind: Integer;
 Hour,Minute,Second,Hundredth:Word;
 A,B,D,V:LongInt;
 Cmp:Integer;
 S:String;
 RB:TSingleBits;
Begin
 Case CspNum Of
 0:
 Begin
  PCode_IOChecking:=PCode_Pop<>0
 End;
 1:
 Begin
  N:=PCode_Pop;D:=PCode_Pop;PCode_DataSet(D,PCode_Allocate(N))
 End;
 2:
 Begin
  N:=PCode_Pop;D:=PCode_Pop;A:=PCode_Pop;
  For I:=0 to N-1 do PCode_DataSet(D+I,PCode_DataAt(A+I))
 End;
 3:
 Begin
  N:=PCode_Pop;D:=PCode_Pop;A:=PCode_Pop;
  For I:=N-1 downto 0 do PCode_DataSet(D+I,PCode_DataAt(A+I))
 End;
 4:
 Begin
 { exit } N := PCode_Pop; PCode_Halted := True; PCode_ExitCode := N; 
 End;
 18:
 Begin
  RB.L:=PCode_Pop;PCode_Push(Trunc(RB.S))
 End;
 19:
 Begin
  RB.L:=PCode_Pop;if RB.S>=0 Then PCode_Push(Trunc(RB.S+0.5))
  else PCode_Push(Trunc(RB.S-0.5))
 End;
 9:
 Begin
  GetTime(Hour,Minute,Second,Hundredth);
  PCode_Push(LongInt(Hour)*360000+LongInt(Minute)*6000+LongInt(Second)*100+Hundredth)
 End;
 10:
 Begin
  V:=PCode_Pop;N:=PCode_Pop;D:=PCode_Pop;
  For I:=0 to N-1 do PCode_DataSet(D+I,Byte(V))
 End;
 20,21,22,23,24,25,26:
 Begin
  RB.L:=PCode_Pop;
  Case CspNum of
  20:RB.S:=Sin(RB.S);21:RB.S:=Cos(RB.S);22:Begin
   if Cos(RB.S)=0 Then Begin PCode_RuntimeError(306,'tangente hors domaine');Exit End;
   RB.S:=Sin(RB.S)/Cos(RB.S)
  End;
  23:RB.S:=ArcTan(RB.S);
  24:Begin if RB.S<=0 Then Begin PCode_RuntimeError(306,'logarithme hors domaine');Exit End;
   RB.S:=Ln(RB.S) End;
  25:RB.S:=Exp(RB.S);
  26:Begin if RB.S<0 Then Begin PCode_RuntimeError(306,'racine hors domaine');Exit End;
   RB.S:=Sqrt(RB.S) End
  End;PCode_Push(RB.L)
 End;
 27:
 Begin
  D:=PCode_Pop;PCode_DataSet(D,PCode_StringHeap)
 End;
 28:
 Begin
  A:=PCode_Pop;
  if(A<4096)or(A>PCode_StringHeap)Then PCode_RuntimeError(303,'marque de tas invalide')
  else Begin PCode_StringHeap:=A;PCode_FreeCount:=0 End
 End;
 29,37:
 Begin
  PCode_Push(PCode_LastIOError);PCode_LastIOError:=0
 End;
 40:
 Begin
  A:=PCode_Pop;PCode_Push(PCode_StringLength(A))
 End;
 41:
 Begin
  B:=PCode_Pop;A:=PCode_Pop;
  PCode_Push(PCode_NewString(A,B,1,PCode_StringLength(A),1,PCode_StringLength(B)))
 End;
 42:
 Begin
  B:=PCode_Pop;A:=PCode_Pop;Cmp:=0;N:=PCode_StringLength(A);
  if PCode_StringLength(B)<N Then N:=PCode_StringLength(B);I:=1;
  While(I<=N)and(Cmp=0)do Begin
   Cmp:=Integer(PCode_StringChar(A,I))-Integer(PCode_StringChar(B,I));Inc(I)
  End;
  if Cmp=0 Then Cmp:=PCode_StringLength(A)-PCode_StringLength(B);PCode_Push(Cmp)
 End;
 43:
 Begin
  N:=PCode_Pop;P:=PCode_Pop;A:=PCode_Pop;PCode_Push(PCode_NewString(A,0,P,N,1,0))
 End;
 44:
 Begin
  B:=PCode_Pop;A:=PCode_Pop;P:=0;
  For I:=1 to PCode_StringLength(B)-PCode_StringLength(A)+1 do Begin
   N:=1;
   While(N<=PCode_StringLength(A))and(PCode_StringChar(B,I+N-1)=PCode_StringChar(A,N))
   do Inc(N);
   if N>PCode_StringLength(A)Then Begin
    P:=I;Break
   End
  End;PCode_Push(P)
 End;
 45:
 Begin
  N:=PCode_Pop;A:=PCode_Pop;D:=PCode_Pop;PCode_AssignString(D,A,N)
 End;
 46:
 Begin
  I:=PCode_Pop;A:=PCode_Pop;PCode_Push(PCode_StringChar(A,I))
 End;
 47:
 Begin
  N:=PCode_Pop;P:=PCode_Pop;D:=PCode_Pop;A:=PCode_Pop;
  B:=PCode_NewString(D,0,1,P-1,1,0);
  B:=PCode_NewString(B,A,1,PCode_StringLength(B),1,PCode_StringLength(A));
  B:=PCode_NewString(B,D,1,PCode_StringLength(B),P,PCode_StringLength(D)-P+1);
  PCode_AssignString(D,B,N)
 End;
 48:
 Begin
  N:=PCode_Pop;P:=PCode_Pop;D:=PCode_Pop;
  B:=PCode_NewString(D,D,1,P-1,P+N,PCode_StringLength(D)-P-N+1);
  PCode_AssignString(D,B,255)
 End;
 49:
 Begin
  A:=PCode_Pop;
  For I:=1 to PCode_StringLength(A)do PCode_PutChar(Chr(PCode_StringChar(A,I)))
 End;
 50:
 Begin
  A:=PCode_Pop;PCode_Push(PCode_CharString(A))
 End;
 51:
 Begin
  N:=PCode_Pop;B:=PCode_Pop;A:=PCode_Pop;
  if(N and 1)<>0 Then A:=PCode_CharString(A);if(N and 2)<>0 Then B:=PCode_CharString(B);
  PCode_Push(PCode_NewString(A,B,1,PCode_StringLength(A),1,PCode_StringLength(B)))
 End;
 53:
 Begin
  B:=PCode_Pop;A:=PCode_Pop;H:=PCode_FileHandle(A,False);
  if A=0 Then
  For I:=1 to PCode_StringLength(B)do PCode_PutChar(Chr(PCode_StringChar(B,I)))
  else if(H=0)
  or not PCode_Files[H].Opened or not PCode_Files[H].TextMode Then PCode_IOError(H,103)
  else
  Begin
   For I:=1 to PCode_StringLength(B)do Write(PCode_Files[H].T,Chr(PCode_StringChar(B,I)));
   PCode_IOError(H,IOResult)
  End
 End;
 54:
 Begin
  Wid:=PCode_Pop;B:=PCode_Pop;A:=PCode_Pop;N:=PCode_StringLength(B);
  if Wid>N Then Begin
   S:='';
   For I:=1 to Wid-N do S:=S+' '
  End else S:='';
  For I:=1 to N do S:=S+Chr(PCode_StringChar(B,I));H:=PCode_FileHandle(A,False);
  if A=0 Then Write(S)else if(H=0)
  or not PCode_Files[H].Opened or not PCode_Files[H].TextMode Then   PCode_IOError(H,103)
  else
  Begin
   Write(PCode_Files[H].T,S);PCode_IOError(H,IOResult)
  End
 End;
 55:
 Begin
  A:=PCode_Pop;H:=PCode_FileHandle(A,False);if A=0 Then WriteLn
  else if(H=0)
  or not PCode_Files[H].Opened or not PCode_Files[H].TextMode Then PCode_IOError(H,103)
  else
  Begin
   WriteLn(PCode_Files[H].T);PCode_IOError(H,IOResult)
  End
 End;
 60:
 Begin
  A:=PCode_Pop;D:=PCode_Pop;H:=PCode_FileHandle(D,True);
  if H=0 Then PCode_IOError(0,4)else
  Begin
   S:='';
   For I:=1 to PCode_StringLength(A)do S:=S+Chr(PCode_StringChar(A,I));
   PCode_Files[H].Name:=PCode_MapFileName(S)
  End
 End;
 61,62:
 Begin
  Kind:=PCode_Pop;D:=PCode_Pop;PCode_OpenFile(D,CspNum=62,Kind)
 End;
 63:
 Begin
  D:=PCode_Pop;H:=PCode_FileHandle(D,False);if(H>0)and PCode_Files[H].Opened Then Begin
   if PCode_Files[H].TextMode Then Close(PCode_Files[H].T)else Close(PCode_Files[H].F);
   E:=IOResult;PCode_Files[H].Opened:=False;PCode_IOError(H,E)
  End
 End;
 64:
 Begin
  D:=PCode_Pop;if D=0 Then PCode_Push(Ord(Eof(Input)))else
  Begin
   H:=PCode_FileHandle(D,False);if(H=0)or not PCode_Files[H].Opened Then Begin
    PCode_IOError(H,103);PCode_Push(1)
   End
   else if PCode_Files[H].TextMode Then PCode_Push(Ord(Eof(PCode_Files[H].T)))
   else PCode_Push(Ord(Eof(PCode_Files[H].F)))
  End
 End;
 65:
 Begin
  D:=PCode_Pop;if D=0 Then PCode_Push(Ord(Eoln(Input)))else
  Begin
   H:=PCode_FileHandle(D,False);
   if(H=0)or not PCode_Files[H].Opened or not PCode_Files[H].TextMode Then Begin
    PCode_IOError(H,103);PCode_Push(1)
   End else PCode_Push(Ord(Eoln(PCode_Files[H].T)))
  End
 End;
 66,67:
 Begin
  D:=PCode_Pop;A:=PCode_Pop;H:=PCode_FileHandle(A,False);
  if A=0 Then Begin
   if CspNum=66 Then Read(V)else
   Begin
    Read(S);if S=''Then V:=0 else V:=Ord(S[1])
   End;E:=IOResult
  End
  else if(H=0)or not PCode_Files[H].Opened or not PCode_Files[H].TextMode Then E:=103
  else
  Begin
   if CspNum=66 Then Read(PCode_Files[H].T,V)else
   Begin
    Read(PCode_Files[H].T,S);
    if S=''Then V:=0 else V:=Ord(S[1])
   End;E:=IOResult
  End;
  if E=0 Then PCode_DataSet(D,V);PCode_IOError(H,E)
 End;
 68:
 Begin
  N:=PCode_Pop;D:=PCode_Pop;A:=PCode_Pop;H:=PCode_FileHandle(A,False);S:='';
  if A=0 Then Begin
   Read(S);E:=IOResult
  End
  else if(H=0)or not PCode_Files[H].Opened or not PCode_Files[H].TextMode Then E:=103
  else
  Begin
   Read(PCode_Files[H].T,S);E:=IOResult
  End;
  if E=0 Then Begin
   B:=PCode_StringHeap;PCode_DataSet(B,Length(S));
   For I:=1 to Length(S)do PCode_DataSet(B+I,Ord(S[I]));
   Inc(PCode_StringHeap,Length(S)+1);PCode_AssignString(D,B,N)
  End;PCode_IOError(H,E)
 End;
 69:
 Begin
  A:=PCode_Pop;H:=PCode_FileHandle(A,False);
  if A=0 Then Begin
   ReadLn;E:=IOResult
  End else if(H=0)or not PCode_Files[H].Opened or
  not PCode_Files[H].TextMode Then E:=103 else
  Begin
   ReadLn(PCode_Files[H].T);E:=IOResult
  End;
  PCode_IOError(H,E)
 End;
 70:
 Begin
  Prec:=PCode_Pop;Wid:=PCode_Pop;Kind:=PCode_Pop;V:=PCode_Pop;A:=PCode_Pop;
  H:=PCode_FileHandle(A,False);S:='';
  Case Kind of 0:Str(V:Wid,S);1:
  Begin
   S:=Chr(Byte(V));
   While Length(S)<Wid do S:=' '+S
  End;
  2:
  Begin
   if V=0 Then S:='FALSE'else S:='TRUE';
   While Length(S)<Wid do S:=' '+S
  End;
  3:
  Begin
   RB.L:=V;if Prec>=0 Then Str(RB.S:Wid:Prec,S)else Str(RB.S:Wid,S)
  End
 End;
 if A=0 Then Write(S)else if(H=0)
 or not PCode_Files[H].Opened or not PCode_Files[H].TextMode Then    PCode_IOError(H,103)
 else
 Begin
  Write(PCode_Files[H].T,S);PCode_IOError(H,IOResult)
 End
End;
71:
Begin
 D:=PCode_Pop;H:=PCode_FileHandle(D,False);if(H=0)or not PCode_Files[H].Opened or
 PCode_Files[H].TextMode Then PCode_IOError(H,103)else
 Begin
  N:=0;
  For I:=0 to PCode_Files[H].RecordWords-1 do Begin
   BlockRead(PCode_Files[H].F,V,SizeOf(LongInt),N);E:=IOResult;
   if(E<>0)or(N<>SizeOf(LongInt))Then Begin if E=0 Then E:=100;Break End;
   PCode_DataSet(PCode_Files[H].BufferAddress+I,V)
  End;PCode_IOError(H,E)
 End
End;
72:
Begin
 D:=PCode_Pop;H:=PCode_FileHandle(D,False);if(H=0)or not PCode_Files[H].Opened or
 PCode_Files[H].TextMode Then PCode_IOError(H,103)else
 Begin
  E:=0;
  For I:=0 to PCode_Files[H].RecordWords-1 do Begin
   V:=PCode_DataAt(PCode_Files[H].BufferAddress+I);
   BlockWrite(PCode_Files[H].F,V,SizeOf(LongInt),N);E:=IOResult;
   if(E<>0)or(N<>SizeOf(LongInt))Then Begin if E=0 Then E:=101;Break End
  End;PCode_IOError(H,E)
 End
End;
73:
Begin
 D:=PCode_Pop;H:=PCode_FileHandle(D,True);
 if H=0 Then Begin
  PCode_IOError(0,4);PCode_Push(0)
 End
 else PCode_Push(PCode_Files[H].BufferAddress)
End;
74:
Begin
 PCode_IOChecking:=PCode_Pop<>0
End;
75:
Begin
 PCode_Push(PCode_LastIOError);PCode_LastIOError:=0
End;
76:
Begin
 D:=PCode_Pop;A:=PCode_Pop;H:=PCode_FileHandle(A,False);RB.S:=0;
 if A=0 Then Begin
  Read(RB.S);E:=IOResult
 End
 else if(H=0)or not PCode_Files[H].Opened or not PCode_Files[H].TextMode Then E:=103
 else
 Begin
  Read(PCode_Files[H].T,RB.S);E:=IOResult
 End;
 if E=0 Then PCode_DataSet(D,RB.L);PCode_IOError(H,E)
End;
77:
Begin
 D:=PCode_Pop;A:=PCode_Pop;H:=PCode_FileHandle(A,False);S:='';
 if A=0 Then Begin
  Read(S);E:=IOResult
 End
 else if(H=0)or not PCode_Files[H].Opened or not PCode_Files[H].TextMode Then E:=103
 else
 Begin
  Read(PCode_Files[H].T,S);E:=IOResult
 End;
 S:=UpperString(S);if(S='TRUE')or(S='1')Then V:=1 else V:=0;
 if E=0 Then PCode_DataSet(D,V);PCode_IOError(H,E)
End;
80:
Begin
 N:=PCode_Pop;D:=PCode_Pop;PCode_DataSet(D,PCode_Allocate(N))
End;
81:
Begin
 N:=PCode_Pop;D:=PCode_Pop;A:=PCode_DataAt(D);PCode_Release(A,N);PCode_DataSet(D,0)
End;
82:
Begin
 N:=PCode_Pop;D:=PCode_Pop;A:=PCode_Pop;
 For I:=0 to N-1 do PCode_DataSet(D+I,PCode_DataAt(A+I))
End;
83:
Begin
 N:=PCode_Pop;D:=PCode_Pop;A:=PCode_Pop;
 For I:=N-1 downto 0 do PCode_DataSet(D+I,PCode_DataAt(A+I))
End;
84:
Begin
 V:=PCode_Pop;N:=PCode_Pop;D:=PCode_Pop;
 For I:=0 to N-1 do PCode_DataSet(D+I,Byte(V))
End;
90,91,92,93,94,95:
Begin
 RB.L:=PCode_Pop;
 Case CspNum of 90:RB.S:=Sin(RB.S);91:RB.S:=Cos(RB.S);92:RB.S:=ArcTan(RB.S);
 93:RB.S:=Exp(RB.S);94:
 Begin
  if RB.S<=0 Then Begin
   PCode_RuntimeError(306,'logarithme hors domaine');Exit
  End;
  RB.S:=Ln(RB.S)
 End;95:
 Begin
  if RB.S<0 Then Begin
   PCode_RuntimeError(306,'racine hors domaine');Exit
  End;
  RB.S:=Sqrt(RB.S)
 End
End;PCode_Push(RB.L)
End;
100:
Begin
 N:=PCode_Pop;D:=PCode_Allocate(16);
 For I:=0 to 15 do PCode_DataSet(D+I,0);
 While N>0 do Begin
  B:=PCode_Pop;A:=PCode_Pop;
  if A<0 Then A:=0;if B>255 Then B:=255;
  While A<=B do Begin
   I:=A div 16;V:=PCode_DataAt(D+I)or(LongInt(1)shl(A mod 16));
   PCode_DataSet(D+I,V);Inc(A)
  End;Dec(N)
 End;PCode_Push(D)
End;
101:
Begin
 Kind:=PCode_Pop;B:=PCode_Pop;A:=PCode_Pop;D:=PCode_Allocate(16);
 For I:=0 to 15 do Begin
  Case Kind of
  1:V:=PCode_DataAt(A+I)and not PCode_DataAt(B+I);
  2:V:=PCode_DataAt(A+I)and PCode_DataAt(B+I);
  else V:=PCode_DataAt(A+I)or PCode_DataAt(B+I)
  End;PCode_DataSet(D+I,V and $FFFF)
 End;PCode_Push(D)
End;
102:
Begin
 A:=PCode_Pop;V:=PCode_Pop;
 if(V<0)or(V>255)Then PCode_Push(0)
 else PCode_Push(Ord((PCode_DataAt(A+V div 16)and(LongInt(1)shl(V mod 16)))<>0))
End;
103:
Begin
 Kind:=PCode_Pop;B:=PCode_Pop;A:=PCode_Pop;Cmp:=0;
 For I:=0 to 15 do if(PCode_DataAt(A+I)and $FFFF)<>
  (PCode_DataAt(B+I)and $FFFF)Then Cmp:=1;
 if Kind=0 Then PCode_Push(Ord(Cmp=0))else PCode_Push(Ord(Cmp<>0))
End;
104:
Begin
 Kind:=PCode_Pop;N:=PCode_Pop;B:=PCode_Pop;A:=PCode_Pop;Cmp:=0;
 For I:=0 to N-1 do if PCode_DataAt(A+I)<>PCode_DataAt(B+I)Then Cmp:=1;
 if Kind=0 Then PCode_Push(Ord(Cmp=0))else PCode_Push(Ord(Cmp<>0))
End;
105:
Begin
 N:=PCode_Pop;A:=PCode_Pop;D:=PCode_Allocate(N);
 For I:=0 to N-1 do PCode_DataSet(D+I,PCode_DataAt(A+I));PCode_Push(D)
End;
106:
Begin
 N:=PCode_Pop;D:=PCode_Pop;V:=PCode_Pop;A:=PCode_DataAt(D);
 if A<>0 Then PCode_DataSet(A+N,V)
End;
Else
PCode_RuntimeError(305,'CSP '+PCode_IntToStr(CspNum)+' inconnue');
End;
End;

Procedure PCode_RuntimeError(Code:Integer;Const Msg:String);Begin
 if not PCode_Halted Then Begin
  PCode_Write('[erreur execution '+PCode_IntToStr(Code)+': '+Msg+']');
  PCode_Halted:=True;PCode_ExitCode:=Code
 End
End;
{ ------------------------------------------------------------------------ }
{ UCSD p-System IV.0/IV.2                                                  }
{ Adresses de donnees en mots; adresses de code en octets. Un MSCW occupe }
{ cinq mots: MSSTAT, MSDYN, IPC, MSENV et MPROC.                           }

Function PCode_IVWord(Ofs:LongInt):Integer;Begin
 PCode_IVWord:=PCode_Fetch(Ofs)or(PCode_Fetch(Ofs+1)shl 8)
End;

Function PCode_IVSignedWord(Ofs:LongInt):Integer;
Var
 V:LongInt;
Begin
 V:=PCode_IVWord(Ofs);if V>32767 Then V:=V-65536;PCode_IVSignedWord:=V
End;

Function PCode_IVProcAddress(ProcNum:Integer;Var Locals:Integer):LongInt;
Var
 P,A:LongInt;
Begin
 PCode_IVProcAddress:=-1;Locals:=0;
 if not PCode_HasProcDictionary or(ProcNum<1)or(ProcNum>PCode_ProcCount)Then Exit;
 P:=PCode_ProcDict-ProcNum*2;
 if(P<22)or(P+1>=PCode_SegmentSize)Then Exit;
 A:=PCode_IVWord(P)*2;
 if(A<2)or(A+1>=PCode_SegmentSize)Then Exit;
 Locals:=PCode_IVWord(A);
 if Locals=-1 Then Exit;
 PCode_IVProcAddress:=A+2
End;

Procedure PCode_IVCall(ProcNum,LexLevel:Integer;GlobalCall:Boolean);
Var
 Entry,StaticLink:LongInt;
 Locals,I:Integer;
Begin
 Entry:=PCode_IVProcAddress(ProcNum,Locals);
 if Entry<0 Then Begin
  PCode_RuntimeError(301,'procedure p-System IV invalide');Exit
 End;
 if GlobalCall Then StaticLink:=PCode_Base
 else if LexLevel=0 Then StaticLink:=PCode_MP
 else StaticLink:=PCode_StaticBase(LexLevel);
 if PCode_SP<Locals+5 Then Begin
  PCode_RuntimeError(303,'cadre p-System IV trop grand');Exit
 End;
 Dec(PCode_SP,Locals);
 For I:=0 to Locals-1 do PCode_DataSet(PCode_SP+I,0);
 PCode_Push(PCode_CurrentProc);PCode_Push(0);PCode_Push(PCode_PC);
 PCode_Push(PCode_MP);PCode_Push(StaticLink);PCode_MP:=PCode_SP;
 PCode_CurrentProc:=ProcNum;PCode_PC:=Entry
End;

Procedure PCode_IVReturn(Count:Integer);
Var
 OldMP,ReturnPC,CallerMP:LongInt;
 CallerProc:Integer;
Begin
 OldMP:=PCode_MP;ReturnPC:=PCode_DataAt(OldMP+2);
 CallerMP:=PCode_DataAt(OldMP+1);CallerProc:=PCode_DataAt(OldMP+4);
 if(CallerProc=0)and(ReturnPC=0)Then Begin
  PCode_Halted:=True;PCode_ExitCode:=0;Exit
 End;
 PCode_SP:=OldMP+5+Count;
 if PCode_SP>High(PCode_Data^)+1 Then PCode_SP:=High(PCode_Data^)+1;
 PCode_MP:=CallerMP;PCode_CurrentProc:=CallerProc;PCode_PC:=ReturnPC
End;

Procedure PCode_StepIV;
Var
 Op,B:Byte;
 SB:ShortInt;
 A,V1,V2,FB:LongInt;
 N,Used,Lvl:Integer;
 R1,R2:TSingleBits;
Begin
 if PCode_Halted Then Exit;
 if(PCode_PC<0)or(PCode_PC>=PCode_CodeSize)Then Begin
  PCode_RuntimeError(304,'adresse p-System IV hors segment');Exit
 End;
 Op:=PCode_Fetch(PCode_PC);Inc(PCode_PC);
 if Op<=$1F Then Begin
  PCode_Push(Op);Exit
 End;
 if(Op>=$20)and(Op<=$2F)Then Begin
  PCode_Push(PCode_DataAt(PCode_MP+5+(Op-$20)+1));Exit
 End;
 if(Op>=$30)and(Op<=$3F)Then Begin
  PCode_Push(PCode_DataAt(PCode_Base+5+(Op-$30)+1));Exit
 End;
 if(Op>=$60)and(Op<=$67)Then Begin
  PCode_Push(PCode_MP+5+(Op-$60)+1);Exit
 End;
 if(Op>=$68)and(Op<=$6F)Then Begin
  PCode_DataSet(PCode_MP+5+(Op-$68)+1,PCode_Pop);Exit
 End;
 if(Op>=$78)and(Op<=$7F)Then Begin
  A:=PCode_Pop;PCode_Push(PCode_DataAt(A+Op-$78));Exit
 End;
 Case Op of
 $80:
 Begin
  PCode_Push(PCode_Fetch(PCode_PC));Inc(PCode_PC)
 End; { LDCB }
 $81:
 Begin
  PCode_Push(PCode_IVSignedWord(PCode_PC));Inc(PCode_PC,2)
 End;
 $84:
 Begin
  A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);PCode_Push(PCode_MP+5+A)
 End;
 $85:
 Begin
  A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);
  PCode_Push(PCode_DataAt(PCode_Base+5+A))
 End;
 $86:
 Begin
  A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);PCode_Push(PCode_Base+5+A)
 End;
 $87:
 Begin
  A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);
  PCode_Push(PCode_DataAt(PCode_MP+5+A))
 End;
 $88,$89:
 Begin
  Lvl:=PCode_Fetch(PCode_PC);Inc(PCode_PC);A:=PCode_ReadBig(PCode_PC,Used);
  Inc(PCode_PC,Used);
  FB:=PCode_StaticBase(Lvl);
  if Op=$88 Then PCode_Push(FB+5+A)else PCode_Push(PCode_DataAt(FB+5+A))
 End;
 $8A:
 Begin
  SB:=ShortInt(PCode_Fetch(PCode_PC));Inc(PCode_PC);Inc(PCode_PC,SB)
 End;
 $8B:
 Begin
  A:=PCode_IVSignedWord(PCode_PC);Inc(PCode_PC,2);Inc(PCode_PC,A)
 End;
 $8C:
 Begin
  V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1*V2)
 End;
 $8D:
 Begin
  V2:=PCode_Pop;V1:=PCode_Pop;
  if V2=0 Then PCode_RuntimeError(300,'division par zero')else PCode_Push(V1 div V2)
 End;
 $8E:
 Begin
  N:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);V2:=PCode_Pop;V1:=PCode_Pop;
  For Lvl:=0 to N-1 do PCode_DataSet(V1+Lvl,PCode_DataAt(V2+Lvl))
 End;
 $8F:
 Begin
  V2:=PCode_Pop;V1:=PCode_Pop;if V2=0 Then PCode_RuntimeError(300,'division par zero')else
  Begin
   A:=V1 mod V2;if A<0 Then A:=A+V2;PCode_Push(A)
  End
 End;
 $90:
 Begin
  N:=PCode_Fetch(PCode_PC);Inc(PCode_PC);PCode_IVCall(N,0,False)
 End;
 $91:
 Begin
  N:=PCode_Fetch(PCode_PC);Inc(PCode_PC);PCode_IVCall(N,0,True)
 End;
 $92:
 Begin
  Lvl:=PCode_Fetch(PCode_PC);N:=PCode_Fetch(PCode_PC+1);Inc(PCode_PC,2);
  PCode_IVCall(N,Lvl,False)
 End;
 $93,$94:
 Begin
  B:=PCode_Fetch(PCode_PC);N:=PCode_Fetch(PCode_PC+1);Inc(PCode_PC,2);
  if B=0 Then PCode_CallUnit0(N)
  else if B<=15 Then PCode_CallCSP(N)else PCode_RuntimeError(304,
  'segment externe invalide')
 End;
 $95:
 Begin
  B:=PCode_Fetch(PCode_PC);N:=PCode_Fetch(PCode_PC+1);Inc(PCode_PC,2);
  if B<=15 Then PCode_CallCSP(N)else PCode_RuntimeError(304,
  'segment intermediaire invalide')
 End;
 $96:
 Begin
  A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);PCode_IVReturn(A)
 End;
 $98: PCode_Push(0);
 $99:
 Begin
  Lvl:=PCode_Fetch(PCode_PC);Inc(PCode_PC);PCode_Push(PCode_StaticBase(Lvl))
 End;
 $9C:
 Begin
 End;
 $9E:
 Begin
  PCode_RuntimeError(310,'point d''arret p-System IV')
 End;
 $9F:
 Begin
  V1:=PCode_Pop;PCode_Push(Ord((V1 and 1)=0))
 End;
 $A0:
 Begin
  V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1 or V2)
 End;
 $A1:
 Begin
  V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1 and V2)
 End;
 $A2:
 Begin
  V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1+V2)
 End;
 $A3:
 Begin
  V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1-V2)
 End;
 $A4:
 Begin
  A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);PCode_DataSet(PCode_MP+5+A,PCode_Pop)
 End;
 $A5:
 Begin
  A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);
  PCode_DataSet(PCode_Base+5+A,PCode_Pop)
 End;
 $A6:
 Begin
  Lvl:=PCode_Fetch(PCode_PC);Inc(PCode_PC);A:=PCode_ReadBig(PCode_PC,Used);
  Inc(PCode_PC,Used);PCode_DataSet(PCode_StaticBase(Lvl)+5+A,PCode_Pop)
 End;
 $AC:
 Begin
  B:=PCode_Fetch(PCode_PC);Inc(PCode_PC);PCode_CallCSP(B)
 End;
 $B0..$B3,$B4,$B5:
 Begin
  V2:=PCode_Pop;V1:=PCode_Pop;
  Case Op of $B0:PCode_Push(Ord(V1=V2));$B1:PCode_Push(Ord(V1<>V2));
  $B2,$B4:PCode_Push(Ord(V1<=V2));$B3,$B5:PCode_Push(Ord(V1>=V2))
 End
End;
$B6:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;
 if(V1<0)or(V1>15)Then PCode_Push(0)else PCode_Push(Ord((V2 and(1 shl V1))<>0))
End;
$B7:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1 or V2)
End;
$B8:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1 and V2)
End;
$B9:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1 and not V2)
End;
$BA:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1 shl V2)
End;
$BB:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1 shr V2)
End;
$BC:
Begin
 A:=PCode_Fetch(PCode_PC)or(PCode_Fetch(PCode_PC+1)shl 8)or
 (LongInt(PCode_Fetch(PCode_PC+2))shl 16)or(LongInt(PCode_Fetch(PCode_PC+3))shl 24);
 Inc(PCode_PC,4);PCode_Push(A)
End;
$BE:
Begin
 R1.S:=PCode_Pop;PCode_Push(R1.L)
End;
$BF:
Begin
 R1.L:=PCode_Pop;PCode_Push(Trunc(R1.S))
End;
$CD:
Begin
 R1.L:=PCode_Pop;R1.S:=-R1.S;PCode_Push(R1.L)
End;
$CE:
Begin
 B:=PCode_Fetch(PCode_PC);Inc(PCode_PC);R2.L:=PCode_Pop;R1.L:=PCode_Pop;
 Case B of 0:PCode_Push(Ord(R1.S=R2.S));1:PCode_Push(Ord(R1.S<>R2.S));
 2:PCode_Push(Ord(R1.S<R2.S));3:PCode_Push(Ord(R1.S<=R2.S));
 4:PCode_Push(Ord(R1.S>R2.S));5:PCode_Push(Ord(R1.S>=R2.S))
End
End;
$BD:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V2);PCode_Push(V1)
End;
$C4:
Begin
 V2:=PCode_Pop;A:=PCode_Pop;PCode_DataSet(A,V2)
End;
$C8,$C9,$CA,$CC:
Begin
 R2.L:=PCode_Pop;R1.L:=PCode_Pop;
 if Op=$C8 Then R1.S:=R1.S+R2.S else if Op=$C9 Then R1.S:=R1.S-R2.S
 else if Op=$CA Then R1.S:=R1.S*R2.S else if R2.S=0 Then Begin
  PCode_RuntimeError(300,'division reelle par zero');Exit
 End else R1.S:=R1.S/R2.S;
 PCode_Push(R1.L)
End;
$CB:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;A:=PCode_Pop;
 if(A<V1)or(A>V2)Then PCode_RuntimeError(302,'indice hors limites')else PCode_Push(A)
End;
$D2,$D3,$D4:
Begin
 SB:=ShortInt(PCode_Fetch(PCode_PC));Inc(PCode_PC);
 if Op=$D4 Then Begin
  V1:=PCode_Pop;if(V1 and 1)=0 Then Inc(PCode_PC,SB)
 End
 else
 Begin
  V2:=PCode_Pop;V1:=PCode_Pop;
  if((Op=$D2)and(V1<>V2))or((Op=$D3)and(V1=V2))Then Inc(PCode_PC,SB)
 End
End;
$D5:
Begin
 A:=PCode_IVSignedWord(PCode_PC);Inc(PCode_PC,2);V1:=PCode_Pop;
 if(V1 and 1)=0 Then Inc(PCode_PC,A)
End;
$D6:
Begin
 V1:=PCode_Pop;V2:=PCode_IVSignedWord(PCode_PC);A:=PCode_IVSignedWord(PCode_PC+2);
 if(V1<V2)or(V1>A)Then Inc(PCode_PC,4+2*(A-V2+1))
 else
 Begin
  FB:=PCode_PC+4+2*(V1-V2);Inc(PCode_PC,4+2*(A-V2+1)+PCode_IVSignedWord(FB))
 End
End;
$D7:
Begin
 A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);V2:=PCode_Pop;V1:=PCode_Pop;
 PCode_Push(V1+V2*A)
End;
$D8:
Begin
 R1.L:=PCode_Pop;if R1.S<0 Then R1.S:=-R1.S;PCode_Push(R1.L)
End;
$D9:
Begin
 R1.L:=PCode_Pop;R1.S:=R1.S*R1.S;PCode_Push(R1.L)
End;
$DA:
Begin
 V1:=PCode_Pop;PCode_Push(V1*V1)
End;
$E0:
Begin
 V1:=PCode_Pop;if V1<0 Then V1:=-V1;PCode_Push(V1)
End;
$E1:
Begin
 PCode_Push(-PCode_Pop)
End;
$E2:
Begin
 V1:=PCode_Pop;PCode_Push(V1);PCode_Push(V1)
End;
$E5:
Begin
 PCode_Push(not PCode_Pop)
End;
$E6:
Begin
 A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);PCode_Push(PCode_DataAt(PCode_Pop+A))
End;
$E7:
Begin
 A:=PCode_ReadBig(PCode_PC,Used);Inc(PCode_PC,Used);PCode_Push(PCode_Pop+A)
End;
$ED:
Begin
 PCode_Push(PCode_Pop+1)
End;
$EE:
Begin
 PCode_Push(PCode_Pop-1)
End;
$EF,$F0:
Begin
 N:=PCode_Fetch(PCode_PC);Inc(PCode_PC);PCode_IVCall(N,Op-$EE,False)
End;
$F1:
Begin
 SB:=ShortInt(PCode_Fetch(PCode_PC));Inc(PCode_PC);V1:=PCode_Pop;
 if(V1 and 1)<>0 Then Inc(PCode_PC,SB)
End;
else PCode_RuntimeError(301,'opcode p-System IV $'+PCode_IntToStr(Op))
End
End;
{ Execute UNE instruction p-code a partir de PCode_PC. }

Function PCode_CompareTyped(TypeCode:Byte;A,B:LongInt):Integer;
Var I,N,C:Integer;R1,R2:TSingleBits;
Begin
 C:=0;
 Case TypeCode of
  2:Begin R1.L:=A;R2.L:=B;if R1.S<R2.S Then C:=-1 else if R1.S>R2.S Then C:=1 End;
  4:Begin
   N:=PCode_StringLength(A);if PCode_StringLength(B)<N Then N:=PCode_StringLength(B);
   I:=1;While(I<=N)and(C=0)do Begin
    C:=Integer(PCode_StringChar(A,I))-Integer(PCode_StringChar(B,I));Inc(I)
   End;
   if C=0 Then C:=PCode_StringLength(A)-PCode_StringLength(B)
  End;
  else if A<B Then C:=-1 else if A>B Then C:=1
 End;
 if C<0 Then PCode_CompareTyped:=-1 else if C>0 Then PCode_CompareTyped:=1
 else PCode_CompareTyped:=0
End;

Function PCode_SetRelation(A,B:LongInt):Integer;
Var I,R:Integer;WA,WB:LongInt;
Begin
 R:=1+2+4;
 For I:=0 to 15 do Begin
  WA:=PCode_DataAt(A+I)and $FFFF;WB:=PCode_DataAt(B+I)and $FFFF;
  if WA<>WB Then R:=R and not 1;
  if(WA and not WB)<>0 Then R:=R and not 2;
  if(WB and not WA)<>0 Then R:=R and not 4
 End;PCode_SetRelation:=R
End;

Procedure PCode_Step;
Var
 Op: Byte;
 B: Byte;
 SB: ShortInt;
 W, Used, N, I, Lvl, Cmp: Integer;
 A, V1, V2, Addr, FB: LongInt;
 R1,R2:TSingleBits;
 Temp: Array[0..255] Of Integer;
Begin
 If CurrentTarget=ptUCSDPSystemIV Then Begin
  PCode_StepIV;Exit
 End;
 If PCode_Halted Then Exit;
 If (PCode_PC < 0) Or (PCode_PC >= PCode_CodeSize) Then Begin
  PCode_Halted := True; PCode_ExitCode := 1; Exit;
 End;
 Op := PCode_Fetch(PCode_PC);
 If Op < 128 Then Begin
 { SLDC n : charge court la constante n (0..127) }
  PCode_Push(Op);
  Inc(PCode_PC);
  Exit;
 End;
 Case Op Of
 128, 129:
 Begin
  V1 := PCode_Pop; If V1 < 0 Then V1 := -V1; PCode_Push(V1); Inc(PCode_PC);
 End; { ABI/ABR }
 130:
 Begin
  V2 := PCode_Pop; V1 := PCode_Pop; PCode_Push(V1 + V2); Inc(PCode_PC);
 End;
 131:
 Begin
  R2.L:=PCode_Pop;R1.L:=PCode_Pop;R1.S:=R1.S+R2.S;
  PCode_Push(R1.L);Inc(PCode_PC)
 End;
 132:
 Begin
 { LAND } V2 := PCode_Pop; V1 := PCode_Pop;
  PCode_Push(Ord((V1 <> 0) And (V2 <> 0))); Inc(PCode_PC);
 End;
 133:
 Begin
  PCode_Push(1);PCode_CallCSP(101);Inc(PCode_PC)
 End;
 134:
 Begin
 { DVI/DVR } V2 := PCode_Pop; V1 := PCode_Pop;
  If V2 = 0 Then Begin
   PCode_Write('[erreur 300 : division par zero]');
   PCode_Halted := True; PCode_ExitCode := 300;
  End Else PCode_Push(V1 Div V2);
  Inc(PCode_PC);
 End;
 135:
 Begin
  R2.L:=PCode_Pop;R1.L:=PCode_Pop;
  if R2.S=0 Then PCode_RuntimeError(300,'division reelle par zero')
  else
  Begin
   R1.S:=R1.S/R2.S;PCode_Push(R1.L)
  End;Inc(PCode_PC)
 End;
 136:
 Begin
 { CHK : verifie bornes [min,max] sur la valeur au sommet (non depilee) }
  V2 := PCode_Pop; { max }
  V1 := PCode_Pop; { min }
  W := PCode_DataAt(PCode_SP - 1); { valeur, laissee sur la pile }
  If (W < V1) Or (W > V2) Then Begin
   PCode_Write('[erreur 302 : hors bornes]');
   PCode_Halted := True; PCode_ExitCode := 302;
  End;
  Inc(PCode_PC);
 End;
 137:
 Begin
  R1.S:=PCode_Pop;PCode_Push(R1.L);Inc(PCode_PC)
 End;
 138:
 Begin
  R1.L:=PCode_Pop;PCode_Push(Trunc(R1.S));Inc(PCode_PC)
 End;
 139:
 Begin
  PCode_CallCSP(102);Inc(PCode_PC)
 End;
 140:
 Begin
  PCode_Push(2);PCode_CallCSP(101);Inc(PCode_PC)
 End;
 141:
 Begin
 { IOR : OU booleen } V2 := PCode_Pop; V1 := PCode_Pop;
  PCode_Push(Ord((V1 <> 0) Or (V2 <> 0))); Inc(PCode_PC);
 End;
 142:
 Begin
 { MODI } V2 := PCode_Pop; V1 := PCode_Pop;
  If V2 = 0 Then Begin
   PCode_Write('[erreur 300 : division par zero]');
   PCode_Halted := True; PCode_ExitCode := 300;
  End Else PCode_Push(V1 Mod V2);
  Inc(PCode_PC);
 End;
 143:
 Begin
  V2 := PCode_Pop; V1 := PCode_Pop; PCode_Push(V1 * V2); Inc(PCode_PC);
 End; { MPI }
 144:
 Begin
  R2.L:=PCode_Pop;R1.L:=PCode_Pop;R1.S:=R1.S*R2.S;
  PCode_Push(R1.L);Inc(PCode_PC)
 End;
 145:
 Begin
  V1 := PCode_Pop; PCode_Push(-V1); Inc(PCode_PC);
 End; { NGI }
 146:
 Begin
  R1.L:=PCode_Pop;R1.S:=-R1.S;PCode_Push(R1.L);Inc(PCode_PC)
 End;
 147:
 Begin
  V1 := PCode_Pop; PCode_Push(Ord(V1 = 0)); Inc(PCode_PC);
 End; { LNOT }
 148:
 Begin
 { SRS: construit un ensemble UCSD de 256 bits. }
  PCode_Push(1);PCode_CallCSP(100);Inc(PCode_PC)
 End;
 149:
 Begin
  V2 := PCode_Pop; V1 := PCode_Pop; PCode_Push(V1 - V2); Inc(PCode_PC);
 End; { SBI }
 150:
 Begin
  R2.L:=PCode_Pop;R1.L:=PCode_Pop;R1.S:=R1.S-R2.S;
  PCode_Push(R1.L);Inc(PCode_PC)
 End;
 151:
 Begin
  V1:=PCode_Pop;PCode_Push(V1);PCode_Push(V1);PCode_Push(1);
  PCode_CallCSP(100);Inc(PCode_PC)
 End;
 152:
 Begin
  V1 := PCode_Pop; PCode_Push(V1 * V1); Inc(PCode_PC);
 End; { SQI }
 153:
 Begin
  R1.L:=PCode_Pop;R1.S:=R1.S*R1.S;PCode_Push(R1.L);Inc(PCode_PC)
 End;
 154:
 Begin
 { STO : pile = [..., adresse, valeur] } V1 := PCode_Pop; Addr := PCode_Pop;
  PCode_DataSet(Addr, V1); Inc(PCode_PC);
 End;
 155:
 Begin
  V1:=PCode_Pop;Addr:=PCode_Pop;
  PCode_Push(PCode_StringChar(Addr,V1));Inc(PCode_PC)
 End;
 156:
 Begin
  PCode_Push(0);PCode_CallCSP(101);Inc(PCode_PC)
 End;
 157:
 Begin
  B:=PCode_Fetch(PCode_PC+1);A:=PCode_ReadBig(PCode_PC+2,Used);
  if(B>15)or(A>1023)Then PCode_RuntimeError(304,'adresse externe invalide')
  else PCode_Push(PCode_ExternalData[B,A]);PCode_PC:=PCode_PC+2+Used
 End;
 158:
 Begin
 { CSP n } B := PCode_Fetch(PCode_PC + 1); PCode_PC := PCode_PC + 2;
  PCode_CallCSP(B);
 End;
 159:
 Begin
  PCode_Push(0); Inc(PCode_PC);
 End; { LDCN : NIL }
 160:
 Begin
 { ADJ normalise les bits au-dela de la cardinalite demandee. }
  A:=PCode_ReadBig(PCode_PC+1,Used);V1:=PCode_Pop;
  if A<256 Then Begin
   For I:=(A+15)div 16 to 15 do PCode_DataSet(V1+I,0);
   if(A mod 16)<>0 Then PCode_DataSet(V1+A div 16,PCode_DataAt(V1+A div 16)and
    ((LongInt(1)shl(A mod 16))-1))
  End;PCode_Push(V1);
  PCode_PC:=PCode_PC+1+Used
 End;
 161:
 Begin
 { FJP dep : saut si faux }
  SB := ShortInt(PCode_Fetch(PCode_PC + 1));
  V1 := PCode_Pop;
  If V1 = 0 Then PCode_PC := PCode_PC + 2 + SB
  Else PCode_PC := PCode_PC + 2;
 End;
 162:
 Begin
 { INC n } A := PCode_ReadBig(PCode_PC + 1, Used); V1 := PCode_Pop;
  PCode_Push(V1 + A); PCode_PC := PCode_PC + 1 + Used;
 End;
 163:
 Begin
 { IND n : *(pop()+n) }
  A := PCode_ReadBig(PCode_PC + 1, Used); Addr := PCode_Pop;
  PCode_Push(PCode_DataAt(Addr + A)); PCode_PC := PCode_PC + 1 + Used;
 End;
 164:
 Begin
 { IXA n : indexation tableau, taille element n mots }
  A := PCode_ReadBig(PCode_PC + 1, Used); V1 := PCode_Pop; Addr := PCode_Pop;
  PCode_Push(Addr + V1 * A); PCode_PC := PCode_PC + 1 + Used;
 End;
 165:
 Begin
 { LAO n : adresse globale }
  A := PCode_ReadBig(PCode_PC + 1, Used); PCode_Push(A);
  PCode_PC := PCode_PC + 1 + Used;
 End;
 166:
 Begin
 { LSA n,"texte" : adresse (taguee espace code) de la chaine litterale }
  N := PCode_Fetch(PCode_PC + 1);
  PCode_Push(30000 + (PCode_PC + 2));
  PCode_PC := PCode_PC + 2 + N;
 End;
 167:
 Begin
  B:=PCode_Fetch(PCode_PC+1);A:=PCode_ReadBig(PCode_PC+2,Used);
  if(B>15)or(A>1023)Then PCode_RuntimeError(304,'adresse externe invalide')
  else PCode_Push(100000+LongInt(B)*1024+A);PCode_PC:=PCode_PC+2+Used
 End;
 168:
 Begin
 { MOV n : pile = [..., dest, src], copie n mots src->dest }
  A := PCode_ReadBig(PCode_PC + 1, Used);
  V2 := PCode_Pop; { src }
  V1 := PCode_Pop; { dest }
  For I := 0 To A - 1 Do PCode_DataSet(V1 + I, PCode_DataAt(V2 + I));
  PCode_PC := PCode_PC + 1 + Used;
 End;
 169:
 Begin
 { LDO n }
  A := PCode_ReadBig(PCode_PC + 1, Used); PCode_Push(PCode_DataAt(A));
  PCode_PC := PCode_PC + 1 + Used;
 End;
 170:
 Begin
  N:=PCode_Fetch(PCode_PC+1);V1:=PCode_Pop;Addr:=PCode_Pop;
  PCode_AssignString(Addr,V1,N);Inc(PCode_PC,2)
 End;
 171:
 Begin
 { SRO n }
  A := PCode_ReadBig(PCode_PC + 1, Used); V1 := PCode_Pop;
  PCode_DataSet(A, V1); PCode_PC := PCode_PC + 1 + Used;
 End;
 172:
 Begin
 { selecteur, minimum, maximum, puis deplacements signes }
  V1:=PCode_Pop;V2:=PCode_IVSignedWord(PCode_PC+1);A:=PCode_IVSignedWord(PCode_PC+3);
  if(V1<V2)or(V1>A)Then PCode_PC:=PCode_PC+5+2*(A-V2+1)
  else
  Begin
   Addr:=PCode_PC+5+2*(V1-V2);PCode_PC:=PCode_PC+5+
   2*(A-V2+1)+PCode_IVSignedWord(Addr)
  End
 End;
 173:
 Begin
  N := PCode_Fetch(PCode_PC + 1);
  if PCode_HasProcDictionary Then PCode_IVReturn(N)else
  Begin
   Addr:=PCode_DataAt(PCode_MP+2);FB:=PCode_DataAt(PCode_MP+1);
   PCode_SP:=PCode_MP-N;PCode_MP:=FB;PCode_PC:=Addr
  End
 End;
 174:
 Begin
  Lvl:=PCode_Fetch(PCode_PC+1);N:=PCode_Fetch(PCode_PC+2);
  Inc(PCode_PC,3);PCode_IVCall(N,Lvl,False)
 End;
175, 176, 177, 180, 181, 183:
Begin
 { EQU/GEQ/GRT/LEQ/LES/NEQ : discriminants UCSD 2=reel, 4=chaine,
   6=ensemble multi-mots; les autres types sont des ordinaux/pointeurs. }
 Inc(PCode_PC);B := PCode_Fetch(PCode_PC); Inc(PCode_PC);
  V2 := PCode_Pop; V1 := PCode_Pop;
 if B=6 Then Begin
  Cmp:=PCode_SetRelation(V1,V2);
  Case Op of
  175:PCode_Push(Ord((Cmp and 1)<>0));
  176:PCode_Push(Ord((Cmp and 4)<>0));
  177:PCode_Push(Ord(((Cmp and 4)<>0)and((Cmp and 1)=0)));
  180:PCode_Push(Ord((Cmp and 2)<>0));
  181:PCode_Push(Ord(((Cmp and 2)<>0)and((Cmp and 1)=0)));
  183:PCode_Push(Ord((Cmp and 1)=0))
  End
 End else Begin
  Cmp:=PCode_CompareTyped(B,V1,V2);
  Case Op Of
  175:PCode_Push(Ord(Cmp=0));176:PCode_Push(Ord(Cmp>=0));
  177:PCode_Push(Ord(Cmp>0));180:PCode_Push(Ord(Cmp<=0));
  181:PCode_Push(Ord(Cmp<0));183:PCode_Push(Ord(Cmp<>0))
  End
 End
End;
178:
Begin
 { LDA Lvl,Off : adresse via chainage statique }
 Lvl := PCode_Fetch(PCode_PC + 1);
 A := PCode_ReadBig(PCode_PC + 2, Used);
 FB := PCode_StaticBase(Lvl);if PCode_HasProcDictionary Then Inc(FB,5);
 PCode_Push(FB + A);
 PCode_PC := PCode_PC + 2 + Used;
End;
179:
Begin
 { LDC n,$w1,... : charge n constantes 16 bits }
 N := PCode_Fetch(PCode_PC + 1);
 For I := 0 To N - 1 Do Begin
  W := PCode_Fetch(PCode_PC + 2 + I*2) Or (PCode_Fetch(PCode_PC + 3 + I*2) Shl 8);
  PCode_Push(W);
 End;
 PCode_PC := PCode_PC + 2 + N*2;
End;
182:
Begin
 { LOD Lvl,Off : charge via chainage statique }
 Lvl := PCode_Fetch(PCode_PC + 1);
 A := PCode_ReadBig(PCode_PC + 2, Used);
 FB := PCode_StaticBase(Lvl);if PCode_HasProcDictionary Then Inc(FB,5);
 PCode_Push(PCode_DataAt(FB + A));
 PCode_PC := PCode_PC + 2 + Used;
End;
184:
Begin
 { STR Lvl,Off : stocke via chainage statique }
 Lvl := PCode_Fetch(PCode_PC + 1);
 A := PCode_ReadBig(PCode_PC + 2, Used);
 FB := PCode_StaticBase(Lvl);if PCode_HasProcDictionary Then Inc(FB,5);
 V1 := PCode_Pop;
 PCode_DataSet(FB + A, V1);
 PCode_PC := PCode_PC + 2 + Used;
End;
185:
Begin
 { UJP dep }
 SB := ShortInt(PCode_Fetch(PCode_PC + 1));
 PCode_PC := PCode_PC + 2 + SB;
End;
186,187:
Begin
 { fenetre du fichier pointe par l'adresse de variable fichier }
 Addr:=PCode_Pop;N:=PCode_FileHandle(Addr,False);
 if(N<1)or(N>16)Then PCode_RuntimeError(320,'fichier non initialise')
 else if Op=186 Then PCode_Push(PCode_DataAt(PCode_Files[N].BufferAddress))
 else PCode_DataSet(PCode_Files[N].BufferAddress,PCode_Pop);Inc(PCode_PC)
End;
188:
Begin
 { LDM n : empile n mots depuis l adresse au sommet }
 N := PCode_Fetch(PCode_PC + 1); Addr := PCode_Pop;
 For I := 0 To N - 1 Do PCode_Push(PCode_DataAt(Addr + I));
 PCode_PC := PCode_PC + 2;
End;
189:
Begin
 { STM n : pile = [..., dest, mot1..motN], depile n mots puis dest }
 N := PCode_Fetch(PCode_PC + 1);
 For I := N - 1 Downto 0 Do Temp[I] := PCode_Pop;
 Addr := PCode_Pop;
 For I := 0 To N - 1 Do PCode_DataSet(Addr + I, Temp[I]);
 PCode_PC := PCode_PC + 2;
End;
190:
Begin
 A:=PCode_ReadBig(PCode_PC+1,Used);Addr:=PCode_Pop;
 PCode_Push(PCode_DataAt(Addr+A)and $FF);PCode_PC:=PCode_PC+1+Used
End;
191:
Begin
 A:=PCode_ReadBig(PCode_PC+1,Used);V1:=PCode_Pop;Addr:=PCode_Pop;
 PCode_DataSet(Addr+A,(PCode_DataAt(Addr+A)and not $FF)or(V1 and $FF));
 PCode_PC:=PCode_PC+1+Used
End;
192:
Begin
 { IXP: taille du champ en bits, index et adresse }
 B:=PCode_Fetch(PCode_PC+1);V1:=PCode_Pop;Addr:=PCode_Pop;
 if(B=0)or(B>16)Then PCode_RuntimeError(302,'largeur packed invalide')else
 Begin
  A:=V1*B;V2:=PCode_DataAt(Addr+A div 16);PCode_Push((V2 shr(A mod 16))and
  ((LongInt(1)shl B)-1))
 End;Inc(PCode_PC,2)
End;
193:
Begin
 { RBP n : retour de bloc = fin de programme }
 PCode_Halted := True; PCode_ExitCode := 0;
End;
194:
Begin
 N:=PCode_Fetch(PCode_PC+1);Inc(PCode_PC,2);PCode_IVCall(N,0,True)
End;
195, 196, 197, 200, 201, 203:
Begin
 { EQUI/GEQI/GRTI/LEQI/LESI/NEQI }
 V2 := PCode_Pop; V1 := PCode_Pop;
 Case Op Of
 195: PCode_Push(Ord(V1 = V2));
 196: PCode_Push(Ord(V1 >= V2));
 197: PCode_Push(Ord(V1 > V2));
 200: PCode_Push(Ord(V1 <= V2));
 201: PCode_Push(Ord(V1 < V2));
 203: PCode_Push(Ord(V1 <> V2));
End;
Inc(PCode_PC);
End;
198:
Begin
 { LLA n : adresse locale MP+n }
 A := PCode_ReadBig(PCode_PC + 1, Used);
 if PCode_HasProcDictionary Then PCode_Push(PCode_MP+5+A)else PCode_Push(PCode_MP+A);
 PCode_PC := PCode_PC + 1 + Used;
End;
199:
Begin
 { LDCI w : constante entiere 16 bits (Integer 16 bits signe -}
        { la troncature d affectation fait deja l extension de signe).   }
 W := PCode_Fetch(PCode_PC + 1) Or (PCode_Fetch(PCode_PC + 2) Shl 8);
 PCode_Push(W); PCode_PC := PCode_PC + 3;
End;
202:
Begin
 { LDL n : charge local MP+n }
 A := PCode_ReadBig(PCode_PC + 1, Used);
 if PCode_HasProcDictionary Then PCode_Push(PCode_DataAt(PCode_MP+5+A))
 else PCode_Push(PCode_DataAt(PCode_MP+A));
 PCode_PC := PCode_PC + 1 + Used;
End;
204:
Begin
 { STL n : stocke local MP+n }
 A := PCode_ReadBig(PCode_PC + 1, Used); V1 := PCode_Pop;
 if PCode_HasProcDictionary Then PCode_DataSet(PCode_MP+5+A,V1)
 else PCode_DataSet(PCode_MP+A,V1);PCode_PC:=PCode_PC+1+Used;
End;
205:
Begin
 { CXP unite,proc }
 B := PCode_Fetch(PCode_PC + 1); N := PCode_Fetch(PCode_PC + 2);
 PCode_PC := PCode_PC + 3;
 If B = 0 Then PCode_CallUnit0(N)
 Else if B<=15 Then PCode_CallCSP(N)
 Else PCode_RuntimeError(304,'segment externe invalide');
End;
206:
Begin
 N:=PCode_Fetch(PCode_PC+1);Inc(PCode_PC,2);PCode_IVCall(N,0,False)
End;
207:
Begin
 N:=PCode_Fetch(PCode_PC+1);Inc(PCode_PC,2);PCode_IVCall(N,0,True)
End;
208:
Begin
 { adresse du mot contenant l'element packed }
 B:=PCode_Fetch(PCode_PC+1);V1:=PCode_Pop;Addr:=PCode_Pop;
 if(B=0)or(B>16)Then PCode_RuntimeError(302,'largeur packed invalide')
 else PCode_Push(Addr+(V1*B)div 16);Inc(PCode_PC,2)
End;
209:
Begin
 B:=PCode_Fetch(PCode_PC+1);A:=PCode_ReadBig(PCode_PC+2,Used);V1:=PCode_Pop;
 if(B>15)or(A>1023)Then PCode_RuntimeError(304,'adresse externe invalide')
 else PCode_ExternalData[B,A]:=V1;PCode_PC:=PCode_PC+2+Used
End;
210:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1 shl V2);Inc(PCode_PC)
End;
211:
Begin
 V2:=PCode_Pop;V1:=PCode_Pop;PCode_Push(V1 shr V2);Inc(PCode_PC)
End;
212:
Begin
 V1:=PCode_Fetch(PCode_PC+1)or(PCode_Fetch(PCode_PC+2)shl 8)or
 (LongInt(PCode_Fetch(PCode_PC+3))shl 16)or(LongInt(PCode_Fetch(PCode_PC+4))shl 24);
 PCode_Push(V1);Inc(PCode_PC,5)
End;
213:
Begin
 B:=PCode_Fetch(PCode_PC+1);R2.L:=PCode_Pop;R1.L:=PCode_Pop;
 Case B of 0:PCode_Push(Ord(R1.S=R2.S));1:PCode_Push(Ord(R1.S<>R2.S));
 2:PCode_Push(Ord(R1.S<R2.S));3:PCode_Push(Ord(R1.S<=R2.S));
 4:PCode_Push(Ord(R1.S>R2.S));5:PCode_Push(Ord(R1.S>=R2.S))
End;Inc(PCode_PC,2)
End;
214:
Begin
 PCode_Halted := True; PCode_ExitCode := 0;
End; { XIT }
215: Inc(PCode_PC); { NOP }
216..231:
Begin
 { SLDL1..16 }
 if PCode_HasProcDictionary Then PCode_Push(PCode_DataAt(PCode_MP+5+(Op-215)))
 else PCode_Push(PCode_DataAt(PCode_MP+(Op-215)));Inc(PCode_PC);
End;
232..247:
Begin
 { SLDO1..16 }
 PCode_Push(PCode_DataAt(Op - 231)); Inc(PCode_PC);
End;
248..255:
Begin
 { SIND0..7 }
 Addr := PCode_Pop; PCode_Push(PCode_DataAt(Addr + (Op - 248))); Inc(PCode_PC);
End;
End;
End;

Function ExecutePCodeFile(Const FileName:String):Integer;
Const
 MaxCycles=10000000;
Begin
 ExecutePCodeFile:=1;GetMem(PCode_Mem,SizeOf(TPCodeMemory));
 GetMem(PCode_Data,SizeOf(TPCodeData));
 if not PCode_LoadRaw(FileName)Then Begin
  WriteLn('Impossible de charger le fichier p-Code: ',FileName);
  FreeMem(PCode_Data,SizeOf(TPCodeData));FreeMem(PCode_Mem,SizeOf(TPCodeMemory));Exit
 End;
 FillChar(PCode_Data^,SizeOf(TPCodeData),0);
 FillChar(PCode_ExternalData,SizeOf(PCode_ExternalData),0);
 PCode_InitFiles;PCode_StringHeap:=4096;PCode_PC:=0;PCode_SP:=0;PCode_MP:=0;
 if PCode_HasProcDictionary Then PCode_SP:=High(PCode_Data^)+1;
 PCode_Base:=0;PCode_CurrentProc:=0;
 PCode_Cycles:=0;PCode_Halted:=False;PCode_ExitCode:=0;
 if PCode_HasProcDictionary Then Begin
  if PCode_ProcCount<1 Then Begin
   WriteLn('Le fichier ne contient pas un dictionnaire de procedures valide.');
   PCode_Halted:=True;PCode_ExitCode:=1
  End else PCode_IVCall(1,0,True)
 End;
 While not PCode_Halted and(PCode_Cycles<MaxCycles)do Begin
  PCode_Step;Inc(PCode_Cycles)
 End;
 if not PCode_Halted Then Begin
  WriteLn('[limite d''instructions p-Code atteinte]');PCode_ExitCode:=1
 End;
 PCode_CloseFiles;FreeMem(PCode_Data,SizeOf(TPCodeData));
 FreeMem(PCode_Mem,SizeOf(TPCodeMemory));
 ExecutePCodeFile:=PCode_ExitCode
End;

Procedure ExecuteCommand;
Var
 Name:String;
 Code:Integer;
Begin
 Name:=ProgramFile;AskFile('Programme p-Code',Name);if Name=''Then Exit;
 if not FileExists(Name)and FileExists(Name+'.CODE')Then Name:=Name+'.CODE';
 if not FileExists(Name)Then Begin
  WriteLn('Fichier introuvable: ',Name);Exit
 End;
 ProgramFile:=Name;WriteLn('Execution de ',Name,' ...');Code:=ExecutePCodeFile(Name);
 WriteLn;WriteLn('Fin du programme p-Code (code ',Code,').')
End;

Procedure LinkCommand;
Type
 PLinkSymbol=^TLinkSymbol;
 TLinkSymbol=Record Name:String[8];SegmentNumber,ProcedureNumber:Integer;
 Next:PLinkSymbol End;
Var
 Modules,OutputName,S,Name:String;
 Inputs:Array[1..16]of String;
 SegPos,SegLen:Array[1..16]of LongInt;
 SegName:Array[1..16]of String[8];
 Src:Array[1..16]of File;
 Header:Array[0..511]of Byte;
 InHeader:Array[1..16,0..511]of Byte;
 Buffer:Array[0..4095]of Byte;
 OutF:File;
 Count,I,J,K,P,E,EC,IC,HPos,PatchPos,TargetSeg,TargetProc:Integer;
 N,W:Word;
 OutPos,Want,Remaining,LinkPos:LongInt;
 OK:Boolean;
 ImportName,ExportName:String;
 Symbols,Sym,NextSym:PLinkSymbol;
 LinkRec,RefRec:Array[0..15]of Byte;
 LinkType,LinkRefs,LinkProc,RefNo:Integer;

Procedure PutWord(Ofs:Integer;V:Word);Begin
 Header[Ofs]:=Byte(V);Header[Ofs+1]:=Byte(V shr 8)
End;

Function RecWord(Var B:Array of Byte;Ofs:Integer):Word;Begin
 RecWord:=B[Ofs]or(B[Ofs+1]shl 8)
End;

Function RecName(Var B:Array of Byte):String;
Var X:Integer;T:String;
Begin
 T:='';For X:=0 to 7 do if B[X]<>0 Then T:=T+Chr(B[X]);RecName:=UpperString(T)
End;

Function FindLinkSymbol(S:String):PLinkSymbol;
Var X:PLinkSymbol;
Begin
 X:=Symbols;S:=UpperString(S);While(X<>Nil)and(X^.Name<>S)do X:=X^.Next;
 FindLinkSymbol:=X
End;

Procedure ScanHistoricalLinks(ModuleNo:Integer;Definitions:Boolean);
Var Present:Boolean;LocalName:String;X:PLinkSymbol;ReadWords:Word;Slot:Integer;
Begin
 LinkPos:=SegPos[ModuleNo]+SegLen[ModuleNo];
 if(LinkPos mod 512)<>0 Then LinkPos:=((LinkPos+511)div 512)*512;
 Repeat
  Present:=False;Seek(Src[ModuleNo],LinkPos);E:=IOResult;
  if E=0 Then Begin BlockRead(Src[ModuleNo],LinkRec,16,ReadWords);
   Present:=(IOResult=0)and(ReadWords=16) End;
  if not Present Then Begin
   WriteLn('Informations de liaison tronquees: ',Inputs[ModuleNo]);OK:=False;Exit
  End;Inc(LinkPos,16);LinkType:=RecWord(LinkRec,8);LocalName:=RecName(LinkRec);
  if LinkType=0 Then Exit;
  if LinkType=11 Then Begin
   if Definitions Then Begin
    LinkProc:=RecWord(LinkRec,10);X:=FindLinkSymbol(LocalName);
    if X<>Nil Then Begin WriteLn('Symbole defini plusieurs fois: ',LocalName);OK:=False End
    else Begin New(X);X^.Name:=LocalName;X^.SegmentNumber:=ModuleNo;
     X^.ProcedureNumber:=LinkProc;X^.Next:=Symbols;Symbols:=X End
   End
  End else if(LinkType in[1,2,3,4,5,13,14])Then Begin
   LinkRefs:=RecWord(LinkRec,12);RefNo:=0;
   While RefNo<LinkRefs do Begin
    Seek(Src[ModuleNo],LinkPos);E:=IOResult;
    if E=0 Then BlockRead(Src[ModuleNo],RefRec,16,ReadWords)else ReadWords:=0;
    if(IOResult<>0)or(ReadWords<>16)Then Begin
     WriteLn('Liste de references tronquee: ',LocalName);OK:=False;Exit
    End;Inc(LinkPos,16);
    For Slot:=0 to 7 do if RefNo<LinkRefs Then Begin
     if not Definitions Then Begin
      X:=FindLinkSymbol(LocalName);
      if X=Nil Then Begin WriteLn('Symbole externe non resolu: ',LocalName);OK:=False End
      else Begin
       PatchPos:=RecWord(RefRec,Slot*2);
       if PatchPos+1>=SegLen[ModuleNo]Then Begin
        WriteLn('Reference hors segment: ',LocalName);OK:=False
       End else Begin
        Want:=(Header[(ModuleNo-1)*4]or(Header[(ModuleNo-1)*4+1]shl 8))*512+PatchPos;
        Seek(OutF,Want);E:=IOResult;if E=0 Then Begin
         Buffer[0]:=X^.SegmentNumber;Buffer[1]:=X^.ProcedureNumber;
         BlockWrite(OutF,Buffer,2,W);OK:=OK and(IOResult=0)and(W=2)
        End else OK:=False
       End
      End
     End;Inc(RefNo)
    End
   End
  End
 Until not OK
End;
Begin
 Write('Modules .CODE (separes par virgule): ');ReadLn(Modules);
 Modules:=TrimString(Modules);
 if Modules=''Then Exit;OutputName:=ProgramFile;
 AskFile('Programme .CODE produit',OutputName);
 if OutputName=''Then Exit;if Pos('.',OutputName)=0 Then OutputName:=OutputName+'.CODE';
 Count:=0;P:=1;Symbols:=Nil;
 While P<=Length(Modules)do Begin
  While(P<=Length(Modules))and(Modules[P]in[' ',#9,','])do Inc(P);S:='';
  While(P<=Length(Modules))and not(Modules[P]in[' ',#9,','])do Begin
   S:=S+Modules[P];Inc(P)
  End;
  if S<>''Then Begin
   Inc(Count);if Count>16 Then Begin
    WriteLn('Le dictionnaire UCSD CODE ne peut contenir que 16 segments.');Exit
   End;
   if Pos('.',S)=0 Then S:=S+'.CODE';Inputs[Count]:=S
  End
 End;
 FillChar(Header,SizeOf(Header),0);OK:=True;
 For I:=1 to Count do Begin
  Assign(Src[I],Inputs[I]);Reset(Src[I],1);E:=IOResult;
  if E<>0 Then Begin
   WriteLn('Impossible d''ouvrir ',Inputs[I]);OK:=False;Break
  End;
  BlockRead(Src[I],InHeader[I],512,N);if(IOResult<>0)or(N<>512)Then Begin
   WriteLn('En-tete .CODE invalide: ',Inputs[I]);OK:=False;Break
  End;
  SegPos[I]:=(InHeader[I,0]or(InHeader[I,1]shl 8))*512;
  SegLen[I]:=InHeader[I,2]or(InHeader[I,3]shl 8);
  if(SegPos[I]<512)or(SegLen[I]<2)Then Begin
   WriteLn('Segment invalide: ',Inputs[I]);OK:=False;Break
  End;
  SegName[I]:='';
  For J:=64 to 71 do if InHeader[I,J]<>0 Then SegName[I]:=SegName[I]+Chr(InHeader[I,J]);
  if SegName[I]=''Then Begin
   Name:=UpperString(ReplaceExtension(Inputs[I],''));
   if Length(Name)>8 Then Name:=Copy(Name,1,8);SegName[I]:=Name
  End;
  Header[256]:=InHeader[I,256];Header[257]:=InHeader[I,257]
 End;
 Header[288]:=Ord('P');Header[289]:=Ord('S');Header[290]:=Ord('V');Header[291]:=Ord('M');
 if not OK Then Begin
  For J:=1 to I do Begin
   Close(Src[J]);E:=IOResult
  End;Exit
 End;
 Assign(OutF,OutputName);Rewrite(OutF,1);if IOResult<>0 Then Begin
  WriteLn('Impossible de creer ',OutputName);
  For I:=1 to Count do Begin
   Close(Src[I]);E:=IOResult
  End;Exit
 End;
 OutPos:=512;
 For I:=1 to Count do Begin
  if Odd(OutPos div 512)Then Begin
  End;
  Want:=(OutPos+511)div 512;PutWord((I-1)*4,Want);PutWord((I-1)*4+2,SegLen[I]);
  For J:=1 to Length(SegName[I])do Header[63+(I-1)*8+J]:=Ord(SegName[I][J]);
  OutPos:=Want*512+SegLen[I]
 End;
 BlockWrite(OutF,Header,512,W);OK:=(IOResult=0)and(W=512);OutPos:=512;
 For I:=1 to Count do Begin
  Want:=(Header[(I-1)*4]or(Header[(I-1)*4+1]shl 8))*512;
  FillChar(Buffer,SizeOf(Buffer),0);
  While OK and(OutPos<Want)do Begin
   N:=Want-OutPos;if N>SizeOf(Buffer)Then N:=SizeOf(Buffer);
   BlockWrite(OutF,Buffer,N,W);OK:=(IOResult=0)and(W=N);Inc(OutPos,N)
  End;
  Seek(Src[I],SegPos[I]);E:=IOResult;N:=SizeOf(Buffer);Remaining:=SegLen[I];
  While OK and(Remaining>0)do Begin
   if Remaining<N Then N:=Remaining;
   BlockRead(Src[I],Buffer,N,W);OK:=(IOResult=0)and(W=N);
   if OK Then Begin
    BlockWrite(OutF,Buffer,N,W);OK:=(IOResult=0)and(W=N)
   End;
   Dec(Remaining,N);Inc(OutPos,N)
  End
 End;
 For I:=1 to Count do if(InHeader[I,288]=Ord('P'))and
  (InHeader[I,289]=Ord('S'))and(InHeader[I,290]=Ord('V'))and
  (InHeader[I,291]=Ord('M'))Then ScanHistoricalLinks(I,True);
 For I:=1 to Count do if OK and(InHeader[I,288]=Ord('P'))and
  (InHeader[I,289]=Ord('S'))and(InHeader[I,290]=Ord('V'))and
  (InHeader[I,291]=Ord('M'))Then ScanHistoricalLinks(I,False);
 { Compatibilite avec les anciens objets PSLK du clone. Les nouveaux objets
   emploient les enregistrements historiques de liaison apres le segment. }
 For I:=1 to Count do if(InHeader[I,288]=Ord('P'))and(InHeader[I,289]=Ord('S'))and
 (InHeader[I,290]=Ord('L'))and(InHeader[I,291]=Ord('K'))Then Begin
  EC:=InHeader[I,292];IC:=InHeader[I,293];HPos:=294+EC*9;
  For J:=0 to IC-1 do Begin
   ImportName:='';
   For K:=0 to 7 do if InHeader[I,HPos+J*10+K]<>0 Then    ImportName:=ImportName+Chr(
   InHeader[I,HPos+J*10+K]);
   PatchPos:=InHeader[I,HPos+J*10+8]or(InHeader[I,HPos+J*10+9]shl 8);
   TargetSeg:=0;TargetProc:=0;
   For K:=1 to Count do if(InHeader[K,288]=Ord('P'))and(TargetSeg=0)Then Begin
    EC:=InHeader[K,292];P:=0;
    While(P<EC)and(TargetSeg=0)do Begin
     ExportName:='';
     For E:=0 to 7 do if InHeader[K,294+P*9+E]<>0 Then      ExportName:=ExportName+Chr(
     InHeader[K,294+P*9+E]);
     if ExportName=ImportName Then Begin
      TargetSeg:=K;TargetProc:=InHeader[K,294+P*9+8]
     End;Inc(P)
    End
   End;
   if TargetSeg=0 Then Begin
    WriteLn('Symbole externe non resolu: ',ImportName);OK:=False
   End
   else
   Begin
    Want:=(Header[(I-1)*4]or(Header[(I-1)*4+1]shl 8))*512+PatchPos;
    Seek(OutF,Want);E:=IOResult;if E=0 Then Begin
     Buffer[0]:=TargetSeg;Buffer[1]:=TargetProc;
     BlockWrite(OutF,Buffer,2,W);OK:=OK and(IOResult=0)and(W=2)
    End else OK:=False
   End
  End
 End;
 For I:=1 to Count do Begin
  Close(Src[I]);E:=IOResult
 End;Close(OutF);if IOResult<>0 Then OK:=False;
 Sym:=Symbols;While Sym<>Nil do Begin NextSym:=Sym^.Next;Dispose(Sym);Sym:=NextSym End;
 if OK Then Begin
  ProgramFile:=OutputName;
  WriteLn('Liaison UCSD terminee: ',Count,' segment(s), ',OutputName)
 End
 else
 Begin
  WriteLn('Echec de la liaison UCSD.');Assign(OutF,OutputName);Erase(OutF);E:=IOResult
 End
End;

Const
 OPK_NONE  = 0;
 OPK_UB    = 1;
 OPK_SB    = 2;
 OPK_W     = 3;
 OPK_BIG   = 4;
 OPK_UBUB  = 5;
 OPK_UBBIG = 6;
 OPK_DBBIG = 7;
 OPK_LSA   = 8;
 OPK_LDC   = 9;
 OPK_XJP   = 10;
 OPK_SLDC  = 200;
 OPK_DB    = 201;

Type
 TMnem=String[6];

Const
 Mnem128:Array[128..255]Of TMnem = (
 'ABI','ABR','ADI','ADR','LAND','DIF','DVI','DVR',         { 128..135 }
 'CHK','FLO','FLT','INN','INT','IOR','MODI','MPI',         { 136..143 }
 'MPR','NGI','NGR','LNOT','SRS','SBI','SBR','SGS',         { 144..151 }
 'SQI','SQR','STO','IXS','UNI','LDE','CSP','LDCN',         { 152..159 }
 'ADJ','FJP','INC','IND','IXA','LAO','LSA','LAE',          { 160..167 }
 'MOV','LDO','SAS','SRO','XJP','RNP','CIP','EQU',          { 168..175 }
 'GEQ','GRT','LDA','LDC','LEQ','LES','LOD','NEQ',          { 176..183 }
 'STR','UJP','LDP','STP','LDM','STM','LDB','STB',          { 184..191 }
 'IXP','RBP','CBP','EQUI','GEQI','GRTI','LLA','LDCI',      { 192..199 }
 'LEQI','LESI','LDL','NEQI','STL','CXP','CLP','CGP',       { 200..207 }
 'LPA','STE','???','EFJ','NFJ','BPT','XIT','NOP',          { 208..215 }
 'SLDL1','SLDL2','SLDL3','SLDL4','SLDL5','SLDL6','SLDL7','SLDL8',
 'SLDL9','SLDL10','SLDL11','SLDL12','SLDL13','SLDL14','SLDL15','SLDL16',
 'SLDO1','SLDO2','SLDO3','SLDO4','SLDO5','SLDO6','SLDO7','SLDO8',
 'SLDO9','SLDO10','SLDO11','SLDO12','SLDO13','SLDO14','SLDO15','SLDO16',
 'SIND0','SIND1','SIND2','SIND3','SIND4','SIND5','SIND6','SIND7'
 );
 Kind128:Array[128..255]Of Byte = (
 OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
 OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
 OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
 OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_UBBIG,OPK_UB,OPK_NONE,
 OPK_UB,OPK_SB,OPK_BIG,OPK_BIG,OPK_BIG,OPK_BIG,OPK_LSA,OPK_UBBIG,
 OPK_BIG,OPK_BIG,OPK_UB,OPK_BIG,OPK_XJP,OPK_UB,OPK_UB,OPK_UB,
 OPK_UB,OPK_UB,OPK_DBBIG,OPK_LDC,OPK_UB,OPK_UB,OPK_DBBIG,OPK_UB,
 OPK_DBBIG,OPK_SB,OPK_NONE,OPK_NONE,OPK_UB,OPK_UB,OPK_NONE,OPK_NONE,
 OPK_UBUB,OPK_UB,OPK_UB,OPK_NONE,OPK_NONE,OPK_NONE,OPK_BIG,OPK_W,
 OPK_NONE,OPK_NONE,OPK_BIG,OPK_NONE,OPK_BIG,OPK_UBUB,OPK_UB,OPK_UB,
 OPK_UBUB,OPK_UBBIG,OPK_NONE,OPK_SB,OPK_SB,OPK_NONE,OPK_NONE,OPK_NONE,
 OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
 OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
 OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
 OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,
 OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE,OPK_NONE
 );

Var
 InFile:Text;
 OutFile:File;
 BBuf:Array[0..4095]Of Byte;
 BLen:Integer;
 OutPos:LongInt;
 LineNum:LongInt;
 ErrCount:Integer;
 InName,OutName:String;

Procedure FlushBuf;
Var
 Wr:Word;
Begin
 If BLen>0 Then Begin
  BlockWrite(OutFile,BBuf,BLen,Wr); BLen:=0;
 End;
End;

Procedure Emit(B:Byte);Begin
 BBuf[BLen]:=B; Inc(BLen); Inc(OutPos);
 If BLen>=SizeOf(BBuf) Then FlushBuf;
End;

Procedure Err(Msg:String);Begin
 WriteLn('Ligne ',LineNum,': ',Msg); Inc(ErrCount);
End;

Procedure EmitUB(V:LongInt);Begin
 If (V<0) Or (V>255) Then Begin
  Err('UB hors limite'); V:=0;
 End;
 Emit(Byte(V));
End;

Procedure EmitSB(V:LongInt);Begin
 If (V<-128) Or (V>127) Then Begin
  Err('SB hors limite'); V:=0;
 End;
 If V<0 Then V:=V+256;
 Emit(Byte(V));
End;

Procedure EmitW(V:LongInt);Begin
 If V<0 Then V:=V+65536;
 Emit(Byte(V And $FF));
 Emit(Byte((V Shr 8) And $FF));
End;

Procedure EmitBig(V:LongInt);Begin
 If (V<0) Or (V>32767) Then Begin
  Err('BIG hors limite'); V:=0;
 End;
 If V<128 Then Emit(Byte(V))
 Else
 Begin
  Emit(Byte($80 Or ((V Shr 8) And $7F)));
  Emit(Byte(V And $FF));
 End;
End;

Function IsDigit(C:Char):Boolean;Begin
 IsDigit:=(C>='0')And(C<='9');
End;

Function IsHexDigit(C:Char):Boolean;Begin
 IsHexDigit:=IsDigit(C) Or ((C>='A')And(C<='F')) Or ((C>='a')And(C<='f'));
End;

Function IsAlpha(C:Char):Boolean;Begin
 IsAlpha:=((C>='A')And(C<='Z')) Or ((C>='a')And(C<='z'));
End;

Procedure SkipSp(Var P:Integer; S:String);Begin
 While (P<=Length(S)) And ((S[P]=' ') Or (S[P]=#9)) Do Inc(P);
End;

Function ParseNum(Var P:Integer; S:String; Var V:LongInt):Boolean;
Var
 Sign:Integer;
 HasH,Got:Boolean;
 D:Integer;
 C:Char;
Begin
 SkipSp(P,S);
 ParseNum:=False; V:=0; Sign:=1; Got:=False; HasH:=False;
 If P>Length(S) Then Exit;
 If S[P]='+' Then Inc(P)
 Else If S[P]='-' Then Begin
  Sign:=-1; Inc(P);
 End;
 If (P<=Length(S)) And (S[P]='$') Then Begin
  HasH:=True; Inc(P);
 End;
 While P<=Length(S) Do Begin
  C:=S[P];
  If HasH Then Begin
   If Not IsHexDigit(C) Then Break;
   If IsDigit(C) Then D:=Ord(C)-Ord('0')
   Else D:=Ord(UpCase(C))-Ord('A')+10;
   V:=V*16+D; Got:=True;
  End
  Else
  Begin
   If Not IsDigit(C) Then Break;
   V:=V*10+(Ord(C)-Ord('0')); Got:=True;
  End;
  Inc(P);
 End;
 V:=V*Sign;
 ParseNum:=Got;
End;

Function ParseId(Var P:Integer; S:String; Var Id:String):Boolean;Begin
 SkipSp(P,S); Id:='';
 If (P>Length(S)) Or (Not IsAlpha(S[P])) Then Begin
  ParseId:=False; Exit;
 End;
 While (P<=Length(S)) And (IsAlpha(S[P]) Or IsDigit(S[P])) Do Begin
  Id:=Id+UpCase(S[P]); Inc(P);
 End;
 ParseId:=True;
End;

Function ParseQStr(Var P:Integer; S:String; Var Q:String):Boolean;Begin
 SkipSp(P,S); Q:='';
 If (P>Length(S)) Or (S[P]<>'"') Then Begin
  ParseQStr:=False; Exit;
 End;
 Inc(P);
 While (P<=Length(S)) And (S[P]<>'"') Do Begin
  Q:=Q+S[P]; Inc(P);
 End;
 If P>Length(S) Then Err('cha'+#238+'ne non termin'+#130+'e')
 Else Inc(P);
 ParseQStr:=True;
End;

Function ExpectComma(Var P:Integer; S:String):Boolean;Begin
 SkipSp(P,S);
 If (P>Length(S)) Or (S[P]<>',') Then Begin
  ExpectComma:=False; Exit;
 End;
 Inc(P); ExpectComma:=True;
End;

Function LookupMn(Mn:String; Var Code:Byte; Var Kind:Byte):Boolean;
Var
 I,P:Integer;
 N:LongInt;
Begin
 LookupMn:=False;
 If Mn='SLDC' Then Begin
  Code:=0; Kind:=OPK_SLDC; LookupMn:=True; Exit;
 End;
 If Mn='DB' Then Begin
  Code:=0; Kind:=OPK_DB; LookupMn:=True; Exit;
 End;
 If (Copy(Mn,1,4)='SLDL') And (Length(Mn)>=5) Then Begin
  P:=5;
  If ParseNum(P,Mn,N) And (N>=1) And (N<=16) Then Begin
   Code:=Byte(215+N); Kind:=OPK_NONE; LookupMn:=True; Exit;
  End;
 End;
 If (Copy(Mn,1,4)='SLDO') And (Length(Mn)>=5) Then Begin
  P:=5;
  If ParseNum(P,Mn,N) And (N>=1) And (N<=16) Then Begin
   Code:=Byte(231+N); Kind:=OPK_NONE; LookupMn:=True; Exit;
  End;
 End;
 If (Copy(Mn,1,4)='SIND') And (Length(Mn)>=5) Then Begin
  P:=5;
  If ParseNum(P,Mn,N) And (N>=0) And (N<=7) Then Begin
   Code:=Byte(248+N); Kind:=OPK_NONE; LookupMn:=True; Exit;
  End;
 End;
 For I:=128 To 255 Do  If Mnem128[I]=Mn Then Begin
  Code:=Byte(I); Kind:=Kind128[I]; LookupMn:=True; Exit;
 End;
End;

Function IsPrefixTok(S:String):Boolean;
Var
 I:Integer;
Begin
 IsPrefixTok:=False;
 If S='..' Then Begin
  IsPrefixTok:=True; Exit;
 End;
 If (Length(S)<>2) And (Length(S)<>6) Then Exit;
 For I:=1 To Length(S) Do  If Not IsHexDigit(S[I]) Then Exit;
 IsPrefixTok:=True;
End;

Function FindMn(S:String):Integer;
Var
 P,Q:Integer;
 Tok:String;
Begin
 FindMn:=0; P:=1;
 While P<=Length(S) Do Begin
  While (P<=Length(S)) And (S[P]=' ') Do Inc(P);
  If P>Length(S) Then Exit;
  Q:=P;
  While (Q<=Length(S)) And (S[Q]<>' ') Do Inc(Q);
  Tok:=Copy(S,P,Q-P);
  If Not IsPrefixTok(Tok) Then Begin
   FindMn:=P; Exit;
  End;
  P:=Q;
 End;
End;

Procedure ProcessLine(S:String);
Var
 I,P:Integer;
 Mn,Q:String;
 Code,Kind:Byte;
 V,V2:LongInt;
Begin
 I:=Pos(';',S); If I>0 Then S:=Copy(S,1,I-1);
 While (Length(S)>0) And ((S[Length(S)]=' ')Or(S[Length(S)]=#9)Or(S[Length(S)]=#13))
 Do  S:=Copy(S,1,Length(S)-1);
 If S='' Then Exit;
 If (Pos('Addr',S)=1) Or (Pos('------',S)>=1) Or (Pos('Fichier',S)=1)
 Or (Pos('D'+#130+'but',S)=1) Or (Pos('Debut',S)=1)
 Or (Pos('Total',S)=1) Then Exit;
 P:=FindMn(S); If P=0 Then Exit;
 If Not ParseId(P,S,Mn) Then Exit;
 If Not LookupMn(Mn,Code,Kind) Then Begin
  Err('mn'+#130+'monique inconnu: '+Mn); Exit;
 End;
 Case Kind Of
 OPK_SLDC:
 Begin
  If Not ParseNum(P,S,V) Then Begin
   Err('SLDC: nombre attendu'); Exit;
  End;
  If (V<0) Or (V>127) Then Begin
   Err('SLDC hors limite (0..127)'); Exit;
  End;
  Emit(Byte(V));
 End;
 OPK_DB:
 Begin
  While ParseNum(P,S,V) Do Begin
   EmitUB(V);
   If Not ExpectComma(P,S) Then Break;
  End;
 End;
 OPK_NONE: Emit(Code);
 OPK_UB:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Err('UB attendu') Else EmitUB(V);
 End;
 OPK_SB:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Err('SB attendu') Else EmitSB(V);
 End;
 OPK_W:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Err('W attendu') Else EmitW(V);
 End;
 OPK_BIG:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Err('BIG attendu') Else EmitBig(V);
 End;
 OPK_UBUB:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Begin
   Err('UB,UB attendu'); Exit;
  End;
  If Not ExpectComma(P,S) Then Begin
   Err('virgule attendue'); Exit;
  End;
  If Not ParseNum(P,S,V2) Then Begin
   Err('2e UB attendu'); Exit;
  End;
  EmitUB(V); EmitUB(V2);
 End;
 OPK_UBBIG:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Begin
   Err('UB,BIG attendu'); Exit;
  End;
  If Not ExpectComma(P,S) Then Begin
   Err('virgule attendue'); Exit;
  End;
  If Not ParseNum(P,S,V2) Then Begin
   Err('BIG attendu'); Exit;
  End;
  EmitUB(V); EmitBig(V2);
 End;
 OPK_DBBIG:
 Begin
  Emit(Code);
  SkipSp(P,S);
  If (P<=Length(S)) And (UpCase(S[P])='L') Then Inc(P);
  If Not ParseNum(P,S,V) Then Begin
   Err('DB level attendu'); Exit;
  End;
  If Not ExpectComma(P,S) Then Begin
   Err('virgule attendue'); Exit;
  End;
  If Not ParseNum(P,S,V2) Then Begin
   Err('BIG attendu'); Exit;
  End;
  EmitUB(V); EmitBig(V2);
 End;
 OPK_LSA:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Begin
   Err('LSA: len attendu'); Exit;
  End;
  If Not ExpectComma(P,S) Then Begin
   Err('virgule attendue'); Exit;
  End;
  If Not ParseQStr(P,S,Q) Then Begin
   Err('"..." attendu'); Exit;
  End;
  If Length(Q)<>V Then Err('LSA: longueur ne correspond pas');
  EmitUB(V);
  For I:=1 To Length(Q) Do Emit(Byte(Q[I]));
 End;
 OPK_LDC:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Begin
   Err('LDC: count attendu'); Exit;
  End;
  EmitUB(V);
  For I:=1 To V Do Begin
   If Not ExpectComma(P,S) Then Begin
    Err('virgule attendue'); Exit;
   End;
   If Not ParseNum(P,S,V2) Then Begin
    Err('mot attendu'); Exit;
   End;
   EmitW(V2);
  End;
 End;
 OPK_XJP:
 Begin
  Emit(Code);
  If Not ParseNum(P,S,V) Then Begin
   Err('XJP: borne basse attendue');Exit
  End;
  If Not ExpectComma(P,S)or not ParseNum(P,S,V2)Then Begin
   Err('XJP: borne haute attendue');Exit
  End;
  if(V2<V)or(V2-V>255)Then Begin
   Err('XJP: intervalle invalide');Exit
  End;
  EmitW(V);EmitW(V2);
  For I:=V to V2 do Begin
   if not ExpectComma(P,S)or not ParseNum(P,S,V)Then Begin
    Err('XJP: deplacement de branche attendu');Exit
   End;EmitW(V)
  End
 End;
End;
End;

Function AssemblePCode(InputName,OutputName:String):Integer;
Var
 Line:String;
 ReadCode,CloseCode:Integer;
Begin
 AssemblePCode:=2;InName:=InputName;OutName:=OutputName;
 If UpperString(OutName)=UpperString(InName) Then Begin
  WriteLn('Erreur: source et destination identiques');Exit
 End;
 Assign(InFile,InName);Reset(InFile);
 If IOResult<>0 Then Begin
  WriteLn('Erreur: ouverture ',InName);Exit
 End;
 Assign(OutFile,OutName);Rewrite(OutFile,1);
 If IOResult<>0 Then Begin
  Close(InFile);ReadCode:=IOResult;
  WriteLn('Erreur: creation ',OutName);Exit
 End;
 OutPos:=0;BLen:=0;LineNum:=0;ErrCount:=0;ReadCode:=0;
 While not Eof(InFile)do Begin
  ReadLn(InFile,Line);ReadCode:=IOResult;
  If ReadCode<>0 Then Begin
   Err('erreur de lecture');Break
  End;
  Inc(LineNum);ProcessLine(Line)
 End;
 FlushBuf;Close(InFile);CloseCode:=IOResult;
 Close(OutFile);if CloseCode=0 Then CloseCode:=IOResult else ReadCode:=IOResult;
 If(ReadCode<>0)or(CloseCode<>0)Then Inc(ErrCount);
 WriteLn('Assemble : ',OutPos,' octet(s), ',ErrCount,' erreur(s)');
 If ErrCount=0 Then AssemblePCode:=0 else AssemblePCode:=1
End;

Type
 PPasType=^TPasType;
 PPasField=^TPasField;
 PPasRoutine=^TPasRoutine;
 PPasParameter=^TPasParameter;
 TPasTypeKind=(ptkInteger,ptkBoolean,ptkChar,ptkReal,ptkEnumeration,
 ptkSubrange,ptkArray,ptkRecord,ptkVariantRecord,ptkPointer,ptkFile,
 ptkSet,ptkString,ptkProcedure,ptkFunction,ptkAlias);
 TPasField=Record
 Name:String[31];
 FieldType:PPasType;
 OffsetWords:Word;
 VariantValue:Integer;
 IsVariant:Boolean;
 Next:PPasField
End;
TPasType=Record
Name:String[31];
Kind:TPasTypeKind;
SizeWords,AlignWords:Word;
PackedType:Boolean;
LowBound,HighBound:LongInt;
ElementType,IndexType,ResultType:PPasType;
VariantTagType:PPasType;
VariantTagOffset:Word;
ElementCount:LongInt;
Fields:PPasField;
Parameters:PPasParameter;
Scope:PPasRoutine;
Next:PPasType
End;
TPasParameter=Record
Name:String[31];
ParamType:PPasType;
ByReference,Structured:Boolean;
Offset:Integer;
Next:PPasParameter
End;
TPasRoutine=Record
Name:String[31];
ProcNumber,LexicalLevel,ParameterWords,LocalWords:Integer;
DeclarationLine:Integer;
IsFunction,IsForward,IsExternal,IsSeparate,IsDefined:Boolean;
ExternalSegment,ExternalProcedure:Integer;
ResultType:PPasType;
Parameters:PPasParameter;
Parent,Next:PPasRoutine;
SourcePosition,EndPosition,CodeStart,CodeLength:LongInt
End;
PPasSymbol=^TPasSymbol;
TPasSymbol=Record Name:String[31];
Address,Value:Integer;
IsConst,Used:Boolean;
DeclarationLine:Integer;
ConstText:String[255];
ConstReal:Real;
IsStringConst,IsRealConst:Boolean;
SymbolType:PPasType;
Scope:PPasRoutine;
LexicalLevel:Integer;
IsParameter,ByReference:Boolean;
BaseSymbol:PPasSymbol;
FieldOffset:Integer;
Next:PPasSymbol
End;
TConstKind=(ckInteger,ckCharacter,ckString,ckReal);
TConstValue=Record Kind:TConstKind;
I:LongInt;
R:Real;
S:String[255]
End;
PPasLabelFixup=^TPasLabelFixup;
TPasLabelFixup=Record Position:LongInt;
Next:PPasLabelFixup
End;
PPasLabel=^TPasLabel;
TPasLabel=Record Name:String[31];
Scope:PPasRoutine;
Address:LongInt;
Defined,Declared:Boolean;
Fixups:PPasLabelFixup;
Next:PPasLabel
End;
PPasRelocation=^TPasRelocation;
TPasRelocation=Record Name:String[31];
Owner:PPasRoutine;
CodePosition,FinalPosition:LongInt;
Next:PPasRelocation
End;
PPasSource=^TPCodeMemory;

Var
 CPSource:PPasSource;
 CPSize,CPPos,CPTokenPos,CPLine,CPCodePos,CPVarCount:LongInt;
 CPMainStart,CPMainLength:LongInt;
 CPToken,CPText:String;
 CPNumber:LongInt;
 CPRealNumber:Real;
 CPError,CPHadErrors:Boolean;
 CPDiagnosticCount,CPFirstErrorCode:Integer;
 CPSymbols:PPasSymbol;
 CPTypes:PPasType;
 CPRoutines:PPasRoutine;
 CPLabels:PPasLabel;
 CPRelocations:PPasRelocation;
 CPWithSymbol:PPasSymbol;
 CPWithType:PPasType;
 CPWithField:TPasSymbol;
 CPLastExpressionType:PPasType;
 CPCurrentRoutine:PPasRoutine;
 CPPass,CPNextProcedure:Integer;
 CPTempNumber:Integer;
 CPRangeChecks,CPIOChecks,CPOverflowChecks:Boolean;
 CPListing:Boolean;
 CPDiagnosticFile:String;
 CPCompilationIsUnit:Boolean;
 CPCompilationName:String[8];
 CPInterfaceSource:PPasSource;
 CPInterfaceLength:LongInt;

Function CPAddType(S:String;K:TPasTypeKind;Words:Word):PPasType;
Var
 T:PPasType;
Begin
 New(T);FillChar(T^,SizeOf(TPasType),0);T^.Name:=S;T^.Kind:=K;
 T^.SizeWords:=Words;T^.AlignWords:=1;T^.Scope:=CPCurrentRoutine;
 T^.Next:=CPTypes;CPTypes:=T;CPAddType:=T
End;

Function CPAlignedSize(Size,Alignment:LongInt):LongInt;Begin
 if Alignment<1 Then Alignment:=1;
 CPAlignedSize:=((Size+Alignment-1)div Alignment)*Alignment
End;

Function CPTypeEquivalent(A,B:PPasType):Boolean;Begin
 if A=B Then Begin
  CPTypeEquivalent:=True;Exit
 End;
 if(A=Nil)or(B=Nil)Then Begin
  CPTypeEquivalent:=False;Exit
 End;
 While(A^.Kind=ptkAlias)and(A^.ElementType<>Nil)do A:=A^.ElementType;
 While(B^.Kind=ptkAlias)and(B^.ElementType<>Nil)do B:=B^.ElementType;
 if A=B Then Begin
  CPTypeEquivalent:=True;Exit
 End;
 if(A^.Kind<>B^.Kind)or(A^.SizeWords<>B^.SizeWords)Then Begin
  CPTypeEquivalent:=False;Exit
 End;
 Case A^.Kind of
 ptkSubrange:CPTypeEquivalent:=CPTypeEquivalent(A^.ElementType,B^.ElementType)and
 (A^.LowBound=B^.LowBound)and(A^.HighBound=B^.HighBound);
 ptkArray:CPTypeEquivalent:=(A^.ElementCount=B^.ElementCount)and
 CPTypeEquivalent(A^.IndexType,B^.IndexType)and
 CPTypeEquivalent(A^.ElementType,B^.ElementType)and(A^.PackedType=B^.PackedType);
 ptkPointer,ptkFile,ptkSet:CPTypeEquivalent:=CPTypeEquivalent(A^.ElementType,
 B^.ElementType);
 ptkString:CPTypeEquivalent:=A^.HighBound=B^.HighBound;
 ptkRecord,ptkVariantRecord,ptkEnumeration,ptkProcedure,ptkFunction:
 CPTypeEquivalent:=False;
 else CPTypeEquivalent:=A^.Name=B^.Name
End
End;

Function CPAssignmentCompatible(Dest,Source:PPasType):Boolean;Begin
 if CPTypeEquivalent(Dest,Source)Then Begin
  CPAssignmentCompatible:=True;Exit
 End;
 While(Dest<>Nil)and(Dest^.Kind=ptkAlias)do Dest:=Dest^.ElementType;
 While(Source<>Nil)and(Source^.Kind=ptkAlias)do Source:=Source^.ElementType;
 if(Dest=Nil)or(Source=Nil)Then CPAssignmentCompatible:=False
 else if Dest^.Kind=ptkSubrange Then CPAssignmentCompatible:=CPAssignmentCompatible(
 Dest^.ElementType,Source)
 else if Source^.Kind=ptkSubrange Then CPAssignmentCompatible:=CPAssignmentCompatible(
 Dest,Source^.ElementType)
 else if(Dest^.Kind=ptkString)and(Source^.Kind in[ptkString,ptkChar])
 Then  CPAssignmentCompatible:=True
 else if(Dest^.Kind=Source^.Kind)and(Dest^.Kind in[ptkInteger,ptkBoolean,
 ptkChar,ptkReal,ptkEnumeration,ptkPointer])Then CPAssignmentCompatible:=True
 else if(Dest^.Kind=ptkSet)and(Source^.Kind=ptkSet)and
 (CPAssignmentCompatible(Dest^.ElementType,Source^.ElementType)or
  CPAssignmentCompatible(Source^.ElementType,Dest^.ElementType))Then CPAssignmentCompatible:=True
 else CPAssignmentCompatible:=False
End;

Function CPBaseType(T:PPasType):PPasType;Begin
 While(T<>Nil)and(T^.Kind=ptkAlias)do T:=T^.ElementType;CPBaseType:=T
End;

Function CPIsOrdinalType(T:PPasType):Boolean;
Begin
 T:=CPBaseType(T);CPIsOrdinalType:=(T<>Nil)and
  (T^.Kind in[ptkInteger,ptkBoolean,ptkChar,ptkEnumeration,ptkSubrange])
End;

Function CPIsTextType(T:PPasType):Boolean;Begin
 T:=CPBaseType(T);CPIsTextType:=(T<>Nil)and(T^.Kind=ptkFile)and
 (CPBaseType(T^.ElementType)<>Nil)and(CPBaseType(T^.ElementType)^.Kind=ptkChar)
End;

Function CPFindType(S:String):PPasType;
Var
 T:PPasType;
 R:PPasRoutine;
Begin
 R:=CPCurrentRoutine;
 Repeat
 T:=CPTypes;
 While(T<>Nil)and((T^.Name<>S)or(T^.Scope<>R))do T:=T^.Next;
 if T<>Nil Then Begin
  CPFindType:=T;Exit
 End;
 if R<>Nil Then R:=R^.Parent else Break
 Until False;CPFindType:=Nil
End;

Function CPFindRoutine(S:String;Parent:PPasRoutine):PPasRoutine;
Var
 R:PPasRoutine;
Begin
 R:=CPRoutines;
 While(R<>Nil)and((R^.Name<>S)or(R^.Parent<>Parent))do R:=R^.Next;
 CPFindRoutine:=R
End;

Function CPVisibleRoutine(S:String):PPasRoutine;
Var
 R,Scope:PPasRoutine;
Begin
 Scope:=CPCurrentRoutine;
 Repeat
 R:=CPFindRoutine(S,Scope);if R<>Nil Then Begin
  CPVisibleRoutine:=R;Exit
 End;
 if Scope<>Nil Then Scope:=Scope^.Parent else Break
 Until False;
 CPVisibleRoutine:=Nil
End;

Function CPAddRoutine(S:String;Parent:PPasRoutine;IsFunc:Boolean):PPasRoutine;
Var
 R:PPasRoutine;
Begin
 R:=CPFindRoutine(S,Parent);
 if R<>Nil Then Begin
  CPAddRoutine:=R;Exit
 End;
 New(R);FillChar(R^,SizeOf(TPasRoutine),0);R^.Name:=S;R^.Parent:=Parent;
 R^.IsFunction:=IsFunc;Inc(CPNextProcedure);R^.ProcNumber:=CPNextProcedure;
 if Parent=Nil Then R^.LexicalLevel:=1 else R^.LexicalLevel:=Parent^.LexicalLevel+1;
 R^.Next:=CPRoutines;CPRoutines:=R;CPAddRoutine:=R
End;

Procedure CPFreeTables;
Var
 S,SN:PPasSymbol;
 T,TN:PPasType;
 R,RN:PPasRoutine;
 P,PN:PPasParameter;
 F,FN:PPasField;
 L,LN:PPasLabel;
 X,XN:PPasLabelFixup;
 Q,QN:PPasRelocation;
Begin
 S:=CPSymbols;
 While S<>Nil do Begin
  SN:=S^.Next;Dispose(S);S:=SN
 End;
 R:=CPRoutines;
 While R<>Nil do Begin
  P:=R^.Parameters;
  While P<>Nil do Begin
   PN:=P^.Next;Dispose(P);P:=PN
  End;
  RN:=R^.Next;Dispose(R);R:=RN
 End;
 T:=CPTypes;
 While T<>Nil do Begin
  F:=T^.Fields;
  While F<>Nil do Begin
   FN:=F^.Next;Dispose(F);F:=FN
  End;
  TN:=T^.Next;Dispose(T);T:=TN
 End;
 L:=CPLabels;
 While L<>Nil do Begin
  X:=L^.Fixups;
  While X<>Nil do Begin
   XN:=X^.Next;Dispose(X);X:=XN
  End;
  LN:=L^.Next;Dispose(L);L:=LN
 End;
 Q:=CPRelocations;
 While Q<>Nil do Begin
  QN:=Q^.Next;Dispose(Q);Q:=QN
 End;
 CPSymbols:=Nil;CPRoutines:=Nil;CPTypes:=Nil;CPLabels:=Nil;CPRelocations:=Nil
End;

Procedure CPReportUnused;
Var
 P:PPasSymbol;
Begin
 P:=CPSymbols;
 While P<>Nil do Begin
  if not P^.Used and(P^.Name<>'')and(P<>@CPWithField)Then   WriteLn(
  'Avertissement UCSD semantique ',P^.DeclarationLine,
  ': identificateur inutilise: ',P^.Name);
  P:=P^.Next
 End
End;

Function CPUCSDErrorText(Code:Integer):String;
Begin
 if not OriginalErrors Then Begin
  Case Code of
   1:CPUCSDErrorText:='Erreur dans un type simple';
   2:CPUCSDErrorText:='Identificateur attendu';
   3:CPUCSDErrorText:='Fonctionnalite non implementee';
   4:CPUCSDErrorText:=''')'' attendu';
   5:CPUCSDErrorText:=''':'' attendu';
   6:CPUCSDErrorText:='Symbole illegal (terminateur attendu)';
   7:CPUCSDErrorText:='Erreur dans la liste des parametres';
   8:CPUCSDErrorText:='''OF'' attendu';
   9:CPUCSDErrorText:='''('' attendu';
   10:CPUCSDErrorText:='Erreur dans un type';
   11:CPUCSDErrorText:='Apostrophe attendue';
   13:CPUCSDErrorText:='''END'' attendu';
   14:CPUCSDErrorText:=''';'' attendu';
   15:CPUCSDErrorText:='Entier attendu';
   16:CPUCSDErrorText:='''='' attendu';
   17:CPUCSDErrorText:='''BEGIN'' attendu';
   18:CPUCSDErrorText:='Erreur dans la partie declarations';
   19:CPUCSDErrorText:='Erreur dans la liste des champs';
   20:CPUCSDErrorText:=''','' attendu';
   21:CPUCSDErrorText:='''*'' attendu';
   22:CPUCSDErrorText:='''INTERFACE'' attendu';
   23:CPUCSDErrorText:='''IMPLEMENTATION'' attendu';
   24:CPUCSDErrorText:='''UNIT'' attendu';
   50:CPUCSDErrorText:='Erreur dans une constante';
   51:CPUCSDErrorText:=''':='' attendu';
   52:CPUCSDErrorText:='''THEN'' attendu';
   53:CPUCSDErrorText:='''UNTIL'' attendu';
   54:CPUCSDErrorText:='''DO'' attendu';
   55:CPUCSDErrorText:='''TO'' ou ''DOWNTO'' attendu dans FOR';
   56:CPUCSDErrorText:='''IF'' attendu';
   57:CPUCSDErrorText:='''FILE'' attendu';
   58:CPUCSDErrorText:='Erreur dans un facteur (expression incorrecte)';
   59:CPUCSDErrorText:='Erreur dans une variable';
   60:CPUCSDErrorText:='Le type doit etre SEMAPHORE';
   61:CPUCSDErrorText:='Le type doit etre PROCESSID';
   62:CPUCSDErrorText:='Processus interdit a ce niveau d''imbrication';
   63:CPUCSDErrorText:='Seule la tache principale peut demarrer des processus';
   101:CPUCSDErrorText:='Identificateur declare deux fois';
   102:CPUCSDErrorText:='La borne inferieure depasse la borne superieure';
   103:CPUCSDErrorText:='Identificateur de classe incorrecte';
   104:CPUCSDErrorText:='Identificateur non declare';
   105:CPUCSDErrorText:='Signe interdit';
   106:CPUCSDErrorText:='Nombre attendu';
   107:CPUCSDErrorText:='Types de sous-intervalles incompatibles';
   108:CPUCSDErrorText:='Fichier interdit ici';
   109:CPUCSDErrorText:='Le type ne doit pas etre reel';
   110:CPUCSDErrorText:='Le discriminant doit etre scalaire ou sous-intervalle';
   111:CPUCSDErrorText:='Incompatibilite avec le discriminant';
   112:CPUCSDErrorText:='Le type d''index ne doit pas etre reel';
   113:CPUCSDErrorText:='Le type d''index doit etre scalaire ou sous-intervalle';
   114:CPUCSDErrorText:='Le type de base ne doit pas etre reel';
   115:CPUCSDErrorText:='Le type de base doit etre scalaire ou sous-intervalle';
   116,125:CPUCSDErrorText:='Type incorrect du parametre d''une procedure standard';
   117:CPUCSDErrorText:='Reference FORWARD non satisfaite';
   118:CPUCSDErrorText:='Type FORWARD dans une declaration de variable';
   119:CPUCSDErrorText:='Parametres redefinis pour une procedure FORWARD';
   120:CPUCSDErrorText:='Le resultat doit etre scalaire, sous-intervalle ou pointeur';
   121:CPUCSDErrorText:='Parametre fichier par valeur interdit';
   122:CPUCSDErrorText:='Type de resultat redefini pour une fonction FORWARD';
   123:CPUCSDErrorText:='Type de resultat absent dans la declaration de fonction';
   124:CPUCSDErrorText:='Format F reserve aux reels';
   126:CPUCSDErrorText:='Nombre de parametres different de la declaration';
   127:CPUCSDErrorText:='Substitution de parametre illegale';
   128:CPUCSDErrorText:='Type de resultat different de la declaration';
   129:CPUCSDErrorText:='Conflit de types entre operandes';
   130:CPUCSDErrorText:='L''expression n''est pas un ensemble';
   131:CPUCSDErrorText:='Seuls les tests d''egalite sont autorises';
   132:CPUCSDErrorText:='Inclusion stricte interdite';
   133:CPUCSDErrorText:='Comparaison de fichiers interdite';
   134:CPUCSDErrorText:='Type d''operande illegal';
   135:CPUCSDErrorText:='L''operande doit etre Boolean';
   136:CPUCSDErrorText:='L''element d''ensemble doit etre scalaire ou sous-intervalle';
   137:CPUCSDErrorText:='Types d''elements d''ensemble incompatibles';
   138:CPUCSDErrorText:='La variable n''est pas un tableau';
   139:CPUCSDErrorText:='Type d''index incompatible avec la declaration';
   140:CPUCSDErrorText:='La variable n''est pas un enregistrement';
   141:CPUCSDErrorText:='La variable doit etre un fichier ou un pointeur';
   142:CPUCSDErrorText:='Resolution de parametre illegale';
   143:CPUCSDErrorText:='Type illegal de variable de controle de boucle';
   144:CPUCSDErrorText:='Type d''expression illegal';
   145:CPUCSDErrorText:='Conflit de types';
   146:CPUCSDErrorText:='Affectation de fichiers interdite';
   147:CPUCSDErrorText:='Type d''etiquette incompatible avec l''expression CASE';
   148:CPUCSDErrorText:='Les bornes du sous-intervalle doivent etre scalaires';
   149:CPUCSDErrorText:='Le type d''index doit etre entier';
   150:CPUCSDErrorText:='Affectation a une fonction standard interdite';
   151:CPUCSDErrorText:='Affectation a une fonction formelle interdite';
   152:CPUCSDErrorText:='Champ absent de cet enregistrement';
   153:CPUCSDErrorText:='Erreur de type dans READ';
   154:CPUCSDErrorText:='Le parametre effectif doit etre une variable';
   155:CPUCSDErrorText:='Variable de controle formelle ou non locale interdite';
   156:CPUCSDErrorText:='Etiquette CASE definie plusieurs fois';
   157:CPUCSDErrorText:='Trop de cas dans l''instruction CASE';
   158:CPUCSDErrorText:='Variante absente de cet enregistrement';
   159:CPUCSDErrorText:='Discriminants reels ou chaines interdits';
   160:CPUCSDErrorText:='La declaration precedente n''etait pas FORWARD';
   161:CPUCSDErrorText:='Nouvelle declaration FORWARD';
   162:CPUCSDErrorText:='La taille du parametre doit etre constante';
   163:CPUCSDErrorText:='Variante manquante dans la declaration';
   164:CPUCSDErrorText:='Substitution d''une procedure ou fonction standard interdite';
   165:CPUCSDErrorText:='Etiquette definie plusieurs fois';
   166:CPUCSDErrorText:='Etiquette declaree plusieurs fois';
   167:CPUCSDErrorText:='Etiquette non declaree';
   168:CPUCSDErrorText:='Etiquette non definie';
   169:CPUCSDErrorText:='Erreur dans le type de base de l''ensemble';
   170:CPUCSDErrorText:='Parametre par valeur attendu';
   171:CPUCSDErrorText:='Fichier standard redeclare';
   172:CPUCSDErrorText:='Fichier externe non declare';
   173:CPUCSDErrorText:='Procedure ou fonction FORTRAN attendue';
   174:CPUCSDErrorText:='Fonction Pascal attendue';
   175:CPUCSDErrorText:='Parametre semaphore par valeur interdit';
   182:CPUCSDErrorText:='Unites imbriquees interdites';
   183:CPUCSDErrorText:='Declaration EXTERNAL interdite a ce niveau';
   184:CPUCSDErrorText:='Declaration EXTERNAL interdite dans INTERFACE';
   185:CPUCSDErrorText:='Declaration de segment interdite dans INTERFACE';
   186:CPUCSDErrorText:='Etiquettes interdites dans INTERFACE';
   187:CPUCSDErrorText:='Ouverture de bibliotheque dans INTERFACE interdite';
   188:CPUCSDErrorText:='Unite absente de la declaration USES precedente';
   189:CPUCSDErrorText:='USES interdit a ce niveau d''imbrication';
   190:CPUCSDErrorText:='Unite absente de la bibliotheque';
   191:CPUCSDErrorText:='La declaration FORWARD n''etait pas un segment';
   192:CPUCSDErrorText:='La declaration FORWARD etait un segment';
   193:CPUCSDErrorText:='Espace insuffisant pour cette operation';
   194:CPUCSDErrorText:='Le drapeau doit etre declare au debut du programme';
   195:CPUCSDErrorText:='Unite non importable';
   201:CPUCSDErrorText:='Erreur dans un nombre reel : chiffre attendu';
   202:CPUCSDErrorText:='La constante chaine ne doit pas depasser la ligne source';
   203:CPUCSDErrorText:='Constante entiere hors limites';
   204:CPUCSDErrorText:='8 ou 9 dans un nombre octal';
   250:CPUCSDErrorText:='Trop de portees imbriquees d''identificateurs';
   251:CPUCSDErrorText:='Trop de procedures ou fonctions imbriquees';
   252:CPUCSDErrorText:='Trop de references FORWARD d''entrees de procedures';
   253:CPUCSDErrorText:='Procedure trop longue';
   254:CPUCSDErrorText:='Trop de constantes longues dans cette procedure';
   256:CPUCSDErrorText:='Trop de references externes';
   257:CPUCSDErrorText:='Trop d''elements externes';
   259:CPUCSDErrorText:='Expression trop compliquee';
   300:CPUCSDErrorText:='Division par zero';
   301:CPUCSDErrorText:='Aucun cas prevu pour cette valeur';
   302:CPUCSDErrorText:='Expression d''index hors limites';
   303:CPUCSDErrorText:='Valeur a affecter hors limites';
   304:CPUCSDErrorText:='Expression d''element hors limites';
   398,399:CPUCSDErrorText:='Restriction d''implementation';
   400:CPUCSDErrorText:='Caractere illegal dans le texte';
   401:CPUCSDErrorText:='Fin d''entree inattendue';
   402:CPUCSDErrorText:='Erreur d''ecriture du fichier CODE : espace insuffisant';
   403:CPUCSDErrorText:='Erreur de lecture du fichier inclus';
   404:CPUCSDErrorText:='Erreur d''ecriture du listing : espace insuffisant';
   405:CPUCSDErrorText:='''PROGRAM'' ou ''UNIT'' attendu';
   406:CPUCSDErrorText:='Fichier inclus illegal';
   407:CPUCSDErrorText:='Limite d''imbrication des fichiers inclus depassee';
   408:CPUCSDErrorText:='La section INTERFACE doit tenir dans un seul fichier';
   409:CPUCSDErrorText:='Nom d''unite reserve au systeme';
   410:CPUCSDErrorText:='Erreur disque';
   500:CPUCSDErrorText:='Erreur de l''assembleur';
   else CPUCSDErrorText:='Erreur du compilateur'
  End;Exit
 End;
 Case Code of
  1:CPUCSDErrorText:='Error in simple type';2:CPUCSDErrorText:='Identifier expected';
  3:CPUCSDErrorText:='Unimplemented error';4:CPUCSDErrorText:=''')'' expected';
  5:CPUCSDErrorText:=''':'' expected';6:CPUCSDErrorText:='Illegal symbol (terminator expected)';
  7:CPUCSDErrorText:='Error in parameter list';8:CPUCSDErrorText:='''OF'' expected';
  9:CPUCSDErrorText:='''('' expected';10:CPUCSDErrorText:='Error in type';
 11:CPUCSDErrorText:=''''' expected';13:CPUCSDErrorText:='''END'' expected';
 14:CPUCSDErrorText:=''';'' expected';15:CPUCSDErrorText:='Integer expected';
 16:CPUCSDErrorText:='''='' expected';17:CPUCSDErrorText:='''BEGIN'' expected';
 18:CPUCSDErrorText:='Error in declaration part';
 19:CPUCSDErrorText:='Error in <field-list>';20:CPUCSDErrorText:=''','' expected';
 21:CPUCSDErrorText:='''*'' expected';22:CPUCSDErrorText:='''INTERFACE'' expected';
 23:CPUCSDErrorText:='''IMPLEMENTATION'' expected';24:CPUCSDErrorText:='''UNIT'' expected';
 50:CPUCSDErrorText:='Error in constant';51:CPUCSDErrorText:=''':='' expected';
 52:CPUCSDErrorText:='''THEN'' expected';53:CPUCSDErrorText:='''UNTIL'' expected';
  54:CPUCSDErrorText:='''DO'' expected';
  55:CPUCSDErrorText:='''TO'' or ''DOWNTO'' expected in for statement';
 56:CPUCSDErrorText:='''IF'' expected';57:CPUCSDErrorText:='''FILE'' expected';
 58:CPUCSDErrorText:='Error in <factor> (bad expression)';
 59:CPUCSDErrorText:='Error in variable';60:CPUCSDErrorText:='Must be of type ''SEMAPHORE''';
 61:CPUCSDErrorText:='Must be of type ''PROCESSID''';
 62:CPUCSDErrorText:='Process not allowed at this nesting level';
 63:CPUCSDErrorText:='Only main task may start processes';
 101:CPUCSDErrorText:='Identifier declared twice';
 102:CPUCSDErrorText:='Low bound exceeds high bound';
 103:CPUCSDErrorText:='Identifier is not of the appropriate class';
 104:CPUCSDErrorText:='Undeclared identifier';105:CPUCSDErrorText:='Sign not allowed';
 106:CPUCSDErrorText:='Number expected';107:CPUCSDErrorText:='Incompatible subrange types';
 108:CPUCSDErrorText:='File not allowed here';109:CPUCSDErrorText:='Type must not be real';
 110:CPUCSDErrorText:='<tagfield> type must be scalar or subrange';
 111:CPUCSDErrorText:='Incompatible with <tagfield> part';
  112:CPUCSDErrorText:='Index type must not be real';
 113:CPUCSDErrorText:='Index type must be a scalar or a subrange';
 114:CPUCSDErrorText:='Base type must not be real';
 115:CPUCSDErrorText:='Base type must be a scalar or a subrange';
 116:CPUCSDErrorText:='Error in type of standard procedure parameter';
 117:CPUCSDErrorText:='Unsatisfied forward reference';
 118:CPUCSDErrorText:='Forward reference type identifier in var declaration';
 119:CPUCSDErrorText:='Re-specified params not OK for a forward procedure';
 120:CPUCSDErrorText:='Function result type must be scalar, subrange or pointer';
 121:CPUCSDErrorText:='File value parameter not allowed';
 122:CPUCSDErrorText:='A forward function''s result type can''t be re-specified';
 123:CPUCSDErrorText:='Missing result type in function declaration';
 124:CPUCSDErrorText:='F-format for reals only';
 125:CPUCSDErrorText:='Error in type of standard procedure parameter';
 126:CPUCSDErrorText:='Number of parameters does not agree with declaration';
 127:CPUCSDErrorText:='Illegal parameter substitution';
 128:CPUCSDErrorText:='Result type does not agree with declaration';
 129:CPUCSDErrorText:='Type conflict of operands';
 130:CPUCSDErrorText:='Expression is not of set type';
  131:CPUCSDErrorText:='Tests on equality allowed only';
 132:CPUCSDErrorText:='Strict inclusion not allowed';
 133:CPUCSDErrorText:='File comparison not allowed';
 134:CPUCSDErrorText:='Illegal type of operand(s)';
 135:CPUCSDErrorText:='Type of operand must be Boolean';
 136:CPUCSDErrorText:='Set element type must be scalar or subrange';
 137:CPUCSDErrorText:='Set element types must be compatible';
 138:CPUCSDErrorText:='Type of variable is not array';
 139:CPUCSDErrorText:='Index type is not compatible with the declaration';
 140:CPUCSDErrorText:='Type of variable is not record';
 141:CPUCSDErrorText:='Type of variable must be file or pointer';
 142:CPUCSDErrorText:='Illegal parameter solution';
 143:CPUCSDErrorText:='Illegal type of loop control variable';
 144:CPUCSDErrorText:='Illegal type of expression';
 145:CPUCSDErrorText:='Type conflict';
 146:CPUCSDErrorText:='Assignment of files not allowed';
 147:CPUCSDErrorText:='Label type incompatible with selecting expression';
 148:CPUCSDErrorText:='Subrange bounds must be scalar';
 149:CPUCSDErrorText:='Index type must be integer';
 150:CPUCSDErrorText:='Assignment to standard function is not allowed';
 151:CPUCSDErrorText:='Assignment to formal function is not allowed';
 152:CPUCSDErrorText:='No such field in this record';
 153:CPUCSDErrorText:='Type error in read';
 154:CPUCSDErrorText:='Actual parameter must be a variable';
 155:CPUCSDErrorText:='Control variable cannot be formal or non-local';
 156:CPUCSDErrorText:='Multidefined case label';
 157:CPUCSDErrorText:='Too many cases in case statement';
 158:CPUCSDErrorText:='No such variant in this record';
 159:CPUCSDErrorText:='Real or string tagfields not allowed';
 160:CPUCSDErrorText:='Previous declaration was not forward';
 161:CPUCSDErrorText:='Again forward declared';
 162:CPUCSDErrorText:='Parameter size must be constant';
 163:CPUCSDErrorText:='Missing variant in declaration';
 164:CPUCSDErrorText:='Substitution of standard proc/func not allowed';
 165:CPUCSDErrorText:='Multidefined label';
 166:CPUCSDErrorText:='Multideclared label';
 167:CPUCSDErrorText:='Undeclared label';
 168:CPUCSDErrorText:='Undefined label';
 169:CPUCSDErrorText:='Error in base set';
 170:CPUCSDErrorText:='Value parameter expected';
 171:CPUCSDErrorText:='Standard file was re-declared';
 172:CPUCSDErrorText:='Undeclared external file';
 173:CPUCSDErrorText:='FORTRAN procedure or function expected';
 174:CPUCSDErrorText:='Pascal function or function expected';
 175:CPUCSDErrorText:='Semaphore value parameter not allowed';
 182:CPUCSDErrorText:='Nested UNITs not allowed';
 183:CPUCSDErrorText:='External declaration not allowed at this nesting level';
 184:CPUCSDErrorText:='External declaration not allowed in INTERFACE section';
 185:CPUCSDErrorText:='Segment declaration not allowed in INTERFACE section';
 186:CPUCSDErrorText:='Labels not allowed in INTERFACE section';
 187:CPUCSDErrorText:='Attempt to open library in INTERFACE section';
 188:CPUCSDErrorText:='UNIT not declared in previous uses declaration';
 189:CPUCSDErrorText:='''USES'' not allowed at this nesting level';
 190:CPUCSDErrorText:='UNIT not in library';
 191:CPUCSDErrorText:='Forward declaration was not segment';
 192:CPUCSDErrorText:='Forward declaration was segment';
 193:CPUCSDErrorText:='Not enough room for this operation';
 194:CPUCSDErrorText:='Flag must be declared at top of program';
 195:CPUCSDErrorText:='Unit not importable';
 201:CPUCSDErrorText:='Error in real number - digit expected';
 202:CPUCSDErrorText:='String constant must not exceed source line';
 203:CPUCSDErrorText:='Integer constant exceeds range';
 204:CPUCSDErrorText:='8 or 9 in octal number';
 250:CPUCSDErrorText:='Too many scopes of nested identifiers';
 251:CPUCSDErrorText:='Too many nested procedures or functions';
 252:CPUCSDErrorText:='Too many forward references of procedures entries';
 253:CPUCSDErrorText:='Procedure too long';
 254:CPUCSDErrorText:='Too many long constants in this procedure';
 256:CPUCSDErrorText:='Too many external references';
 257:CPUCSDErrorText:='Too many externals';
 259:CPUCSDErrorText:='Expression too complicated';
 300:CPUCSDErrorText:='Division by zero';
 301:CPUCSDErrorText:='No case provided for this value';
 302:CPUCSDErrorText:='Index expression out of bounds';
 303:CPUCSDErrorText:='Value to be assigned is out of bounds';
 304:CPUCSDErrorText:='Element expression out of range';
 398:CPUCSDErrorText:='Implementation restriction';
 399:CPUCSDErrorText:='Implementation restriction';
 400:CPUCSDErrorText:='Illegal character in text';
 401:CPUCSDErrorText:='Unexpected end of input';
 402:CPUCSDErrorText:='Error in writing code file, not enough room';
 403:CPUCSDErrorText:='Error in reading include file';
 404:CPUCSDErrorText:='Error in writing list file, not enough room';
 405:CPUCSDErrorText:='''PROGRAM'' or ''UNIT'' expected';
 406:CPUCSDErrorText:='Include file not legal';
 407:CPUCSDErrorText:='Include file nesting limit exceeded';
 408:CPUCSDErrorText:='INTERFACE section not contained in one file';
 409:CPUCSDErrorText:='Unit name reserved for system';
 410:CPUCSDErrorText:='Disk error';
 500:CPUCSDErrorText:='Assembler error';
 else CPUCSDErrorText:='Compiler error'
 End
End;

Function CPInferErrorCode(S:String):Integer;
Var U:String;
Begin
 U:=UpperString(S);CPInferErrorCode:=6;
 if(Pos('BEGIN',U)<>0)and(Pos('ATTENDU',U)<>0)Then CPInferErrorCode:=17
 else if(Pos('PARTIE DECLAR',U)<>0)or(Pos('ERREUR DE DECLAR',U)<>0)or
  (Pos('DECLARATION',U)<>0)Then CPInferErrorCode:=18
 else if(Pos('LISTE DE CHAMP',U)<>0)or(Pos('NOM DE CHAMP ATTENDU',U)<>0)Then CPInferErrorCode:=19
 else if U='VIRGULE ATTENDUE'Then CPInferErrorCode:=20
 else if U='INTERFACE ATTENDU'Then CPInferErrorCode:=22
 else if U='IMPLEMENTATION ATTENDU'Then CPInferErrorCode:=23
 else if U='UNIT ATTENDU'Then CPInferErrorCode:=24
 else if Pos('CONSTANTE',U)<>0 Then CPInferErrorCode:=50
 else if U='THEN ATTENDU'Then CPInferErrorCode:=52
 else if U='UNTIL ATTENDU'Then CPInferErrorCode:=53
 else if U='DO ATTENDU'Then CPInferErrorCode:=54
 else if Pos('TO OU DOWNTO ATTENDU',U)<>0 Then CPInferErrorCode:=55
 else if U='IF ATTENDU'Then CPInferErrorCode:=56
 else if U='FILE ATTENDU'Then CPInferErrorCode:=57
 else if(Pos('FACTEUR',U)<>0)or(Pos('MAUVAISE EXPRESSION',U)<>0)Then CPInferErrorCode:=58
 else if(Pos('VARIABLE',U)<>0)and(Pos('ATTENDU',U)<>0)Then CPInferErrorCode:=59
 else if Pos('SEMAPHORE',U)<>0 Then CPInferErrorCode:=60
 else if Pos('PROCESSID',U)<>0 Then CPInferErrorCode:=61
 else if Pos('NIVEAU D''IMBRICATION',U)<>0 Then CPInferErrorCode:=62
 else if Pos('TACHE PRINCIPALE',U)<>0 Then CPInferErrorCode:=63
 else if(Pos('DEJA DEFINI',U)<>0)or(Pos('DECLARE DEUX FOIS',U)<>0)Then CPInferErrorCode:=101
 else if(Pos('SOUS-INTERVALLE INVERSE',U)<>0)or(Pos('BORNE INFERIEURE',U)<>0)Then CPInferErrorCode:=102
 else if(Pos('INVALIDE',U)<>0)and(Pos('IDENTIFICATEUR',U)<>0)Then CPInferErrorCode:=103
 else if(Pos('IDENTIFICATEUR INCONNU',U)<>0)or(Pos('TYPE INCONNU',U)<>0)or
  (Pos('CONSTANTE INCONNUE',U)<>0)Then CPInferErrorCode:=104
 else if(Pos('SIGNE INTERDIT',U)<>0)or(Pos('SIGNE NON AUTORISE',U)<>0)Then CPInferErrorCode:=105
 else if Pos('NOMBRE ATTENDU',U)<>0 Then CPInferErrorCode:=106
 else if Pos('BORNES DE TYPES INCOMPATIBLES',U)<>0 Then CPInferErrorCode:=107
 else if Pos('FICHIER INTERDIT',U)<>0 Then CPInferErrorCode:=108
 else if Pos('TYPE NE DOIT PAS ETRE REEL',U)<>0 Then CPInferErrorCode:=109
 else if Pos('INDEX NE DOIT PAS ETRE REEL',U)<>0 Then CPInferErrorCode:=112
 else if U='OF ATTENDU'Then CPInferErrorCode:=8
 else if(U='END ATTENDU')or(Pos('END D''',U)=1)Then CPInferErrorCode:=13
 else if(Pos('NON IMPLEMENT',U)<>0)or(Pos('NON DISPONIBLE',U)<>0)Then CPInferErrorCode:=3
 else if Pos('PARAMETRE',U)<>0 Then CPInferErrorCode:=7
 else if((Pos('IDENTIFICATEUR',U)<>0)or(Pos('NOM DE ',U)<>0))and
  (Pos('ATTENDU',U)<>0)Then CPInferErrorCode:=2
 else if(Pos('TYPE SIMPLE',U)<>0)or(Pos('BORNE',U)<>0)Then CPInferErrorCode:=1
 else if Pos('TYPE',U)<>0 Then CPInferErrorCode:=10
 else if(Pos('ENTIER',U)<>0)or(Pos('NOMBRE ATTENDU',U)<>0)Then CPInferErrorCode:=15
 else if Pos('POINT-VIRGULE',U)<>0 Then CPInferErrorCode:=14
 else if(Pos('APOSTROPHE',U)<>0)or(Pos('FIN DE FICHIER DANS UNE CHAINE',U)<>0)Then CPInferErrorCode:=11
End;

Procedure CPFailCode(ErrorCode:Integer;S:String);
Var
 StartPos,EndPos,Col,I:LongInt;
 LineText,Category:String;
Begin
 CPError:=True;CPHadErrors:=True;if CPFirstErrorCode=0 Then CPFirstErrorCode:=ErrorCode;
 if CPDiagnosticCount>=50 Then Exit;
 Inc(CPDiagnosticCount);
 Category:='syntaxe';
 if(Pos('TYPE',UpperString(S))<>0)or(Pos('IDENTIFICATEUR',UpperString(S))<>0)or
 (Pos('BORNE',UpperString(S))<>0)Then Category:='semantique';
 if(Pos('COMMENTAIRE',UpperString(S))<>0)or(Pos('CHAINE',UpperString(S))<>0)or
 (Pos('CARACTERE',UpperString(S))<>0)or(Pos('HEXADECIMAL',UpperString(S))<>0)or
 (Pos('EXPOSANT',UpperString(S))<>0)Then Category:='lexicale';
 StartPos:=CPTokenPos;if StartPos>CPSize Then StartPos:=CPSize;
 While(StartPos>0)and(CPSource^[StartPos-1]<>10)do Dec(StartPos);
 EndPos:=StartPos;LineText:='';
 While(EndPos<CPSize)and not(CPSource^[EndPos]in[10,13])do Begin
  if Length(LineText)<255 Then LineText:=LineText+Chr(CPSource^[EndPos]);Inc(EndPos)
 End;Col:=CPTokenPos-StartPos+1;if Col<1 Then Col:=1;
 if OriginalErrors Then
  WriteLn('UCSD error ',ErrorCode,' (',CPUCSDErrorText(ErrorCode),') ',
   CPDiagnosticFile,':',CPLine,':',Col)
 else WriteLn('Erreur UCSD ',ErrorCode,' (',CPUCSDErrorText(ErrorCode),') ',Category,
  ' ',CPDiagnosticFile,':',CPLine,':',Col,': ',S);
 if LineText<>''Then Begin
  WriteLn(LineText);
  For I:=2 to Col do Write(' ');WriteLn('^')
 End
End;

Procedure CPFail(S:String);
Begin CPFailCode(CPInferErrorCode(S),S)End;

Procedure CPNext;
Var
 C,Close2:Char;
 D,NumText:String;
 Code,Depth,Digits:Integer;
 Closed:Boolean;

Procedure ApplyDirective(S:String);
Var P,Code:Integer;N,Raw:String;
Begin
 Raw:=TrimString(S);if(Raw<>'')and(Raw[1]='$')Then Delete(Raw,1,1);
 Raw:=TrimString(Raw);S:=UpperString(Raw);
 if S='R+'Then CPRangeChecks:=True else if S='R-'Then CPRangeChecks:=False
 else if S='I+'Then CPIOChecks:=True else if S='I-'Then CPIOChecks:=False
 else if S='Q+'Then CPOverflowChecks:=True else if S='Q-'Then CPOverflowChecks:=False
 else if(S='L+')or(S='L')Then CPListing:=True
 else if S='L-'Then CPListing:=False
 else if Copy(S,1,7)='SOURCE 'Then Begin
  Delete(Raw,1,7);P:=Pos('|',Raw);
  if P>0 Then Begin
   CPDiagnosticFile:=Copy(Raw,1,P-1);N:=Copy(Raw,P+1,255);Val(N,CPLine,Code);
   if Code<>0 Then CPLine:=0 else Dec(CPLine)
  End
 End
 else if(S='B+')or(S='B-')or(S='C+')or(S='C-')or(S='D+')or(S='D-')or
  (S='G+')or(S='G-')or(S='P+')or(S='P-')or(S='S+')or(S='S-')or
  (S='U+')or(S='U-')or(S='X+')or(S='X-')Then Begin End
 else if Copy(S,1,7)='TARGET 'Then   if not SelectTarget(TrimString(Copy(S,8,255)))
 Then CPFail('cible de directive inconnue')
 else if(Copy(S,1,2)<>'I ')and(Copy(S,1,8)<>'INCLUDE ')Then
  CPFailCode(398,'directive UCSD inconnue: '+S)
End;

Procedure SkipComment(ParenForm:Boolean);
Var
 A,B:Char;
 Directive:Boolean;
Begin
 D:='';Depth:=1;if ParenForm Then Begin
  Inc(CPPos,2);Close2:=')'
 End
 else
 Begin
  Inc(CPPos);Close2:=#0
 End;
 Directive:=(CPPos<CPSize)and(CPSource^[CPPos]=Ord('$'));
 While(CPPos<CPSize)and(Depth>0)do Begin
  A:=Chr(CPSource^[CPPos]);B:=#0;if CPPos+1<CPSize Then B:=Chr(CPSource^[CPPos+1]);
  if(A='{')and(Close2=#0)Then Begin
   Inc(Depth);if Length(D)<255 Then D:=D+A;Inc(CPPos);Continue
  End;
  if(A='(')and(B='*')and(Close2=')')Then Begin
   Inc(Depth);if Length(D)<254 Then D:=D+'(*';Inc(CPPos,2);Continue
  End;
  if(A='}')and(Close2=#0)Then Begin
   Dec(Depth);Inc(CPPos);if Depth=0 Then Break;
   if Length(D)<255 Then D:=D+'}';Continue
  End;
  if(A='*')and(B=')')and(Close2=')')Then Begin
   Dec(Depth);Inc(CPPos,2);if Depth=0 Then Break;
   if Length(D)<253 Then D:=D+'*)';Continue
  End;
  if A=#10 Then Inc(CPLine);
  if Length(D)<255 Then D:=D+A;Inc(CPPos)
 End;
 if Depth<>0 Then CPFailCode(401,'fin de fichier dans un commentaire')
 else if Directive Then ApplyDirective(D)
End;
Begin
 CPToken:='';CPText:='';CPNumber:=0;CPRealNumber:=0;
 Repeat
 While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in[' ',#9,#10,#13])do Begin
  if CPSource^[CPPos]=10 Then Inc(CPLine);Inc(CPPos)
 End;
 if CPPos>=CPSize Then Begin
  CPTokenPos:=CPPos;CPToken:='EOF';Exit
 End;
 CPTokenPos:=CPPos;
 C:=Chr(CPSource^[CPPos]);
 if C='{'Then SkipComment(False)
 else if(C='(')and(CPPos+1<CPSize)and(CPSource^[CPPos+1]=Ord('*'))Then SkipComment(True)
 else Break
 Until False;
 CPTokenPos:=CPPos;
 C:=Chr(CPSource^[CPPos]);
 if C in['A'..'Z','a'..'z','_']Then Begin
  CPText:='';Digits:=0;
  While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['A'..'Z','a'..'z','_','0'..'9'])do Begin
   Inc(Digits);if Length(CPText)<31 Then CPText:=CPText+UpCase(Chr(CPSource^[CPPos]));
   Inc(CPPos)
  End;if Digits>31 Then CPFail('identificateur de plus de 31 caracteres');CPToken:='ID';
  Exit
 End;
 if C in['0'..'9']Then Begin
  NumText:='';Digits:=0;
  While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['0'..'9'])do Begin
   if CPNumber>(High(LongInt)-(CPSource^[CPPos]-Ord('0')))div 10 Then CPFailCode(203,
   'constante entiere trop grande')else CPNumber:=CPNumber*10+CPSource^[CPPos]-Ord('0');
   NumText:=NumText+Chr(CPSource^[CPPos]);Inc(Digits);Inc(CPPos)
  End;
  if(CPPos<CPSize)and(CPSource^[CPPos]=Ord('.'))and
  ((CPPos+1>=CPSize)or(CPSource^[CPPos+1]<>Ord('.')))Then Begin
   CPText:=NumText+'.';Inc(CPPos);
   if(CPPos>=CPSize)or not(Chr(CPSource^[CPPos])in['0'..'9'])Then
    CPFailCode(201,'chiffre attendu apres le point decimal');
   While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['0'..'9'])do Begin
    CPText:=CPText+Chr(CPSource^[CPPos]);Inc(CPPos)
   End;
   if(CPPos<CPSize)and(UpCase(Chr(CPSource^[CPPos]))in['E','D'])Then Begin
    CPText:=CPText+'E';Inc(CPPos);
    if(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['+','-'])Then Begin
     CPText:=CPText+Chr(CPSource^[CPPos]);Inc(CPPos)
    End;
    Digits:=0;
    While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['0'..'9'])do Begin
     CPText:=CPText+Chr(CPSource^[CPPos]);Inc(CPPos);Inc(Digits)
    End;
    if Digits=0 Then CPFailCode(201,'exposant reel incomplet')
   End;Val(CPText,CPRealNumber,Code);if Code<>0 Then CPFailCode(201,'constante reelle invalide');
   CPToken:='REALNUM';Exit
  End;
  if(CPPos<CPSize)and(UpCase(Chr(CPSource^[CPPos]))in['E','D'])Then Begin
   CPText:=NumText+'E';Inc(CPPos);
   if(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['+','-'])Then Begin
    CPText:=CPText+Chr(CPSource^[CPPos]);Inc(CPPos)
   End;
   Digits:=0;
   While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['0'..'9'])do Begin
    CPText:=CPText+Chr(CPSource^[CPPos]);Inc(CPPos);Inc(Digits)
   End;
   if Digits=0 Then CPFailCode(201,'exposant reel incomplet');Val(CPText,CPRealNumber,Code);
   if Code<>0 Then CPFailCode(201,'constante reelle invalide');CPToken:='REALNUM';Exit
  End;if CPNumber>65535 Then CPFailCode(203,'constante entiere hors limites UCSD');
  CPToken:='NUM';Exit
 End;
 if C='$'Then Begin
  Inc(CPPos);CPNumber:=0;Digits:=0;
  While(CPPos<CPSize)and(UpCase(Chr(CPSource^[CPPos]))in['0'..'9','A'..'F'])do Begin
   if CPNumber>4095 Then Begin
    CPFailCode(203,'constante hexadecimale hors limites UCSD');
    While(CPPos<CPSize)and(UpCase(Chr(CPSource^[CPPos]))in['0'..'9','A'..'F'])do Inc(CPPos);
    Break
   End;
   C:=UpCase(Chr(CPSource^[CPPos]));if C<='9'Then CPNumber:=CPNumber*16+Ord(C)-Ord('0')
   else CPNumber:=CPNumber*16+Ord(C)-Ord('A')+10;Inc(CPPos);Inc(Digits);
   if CPNumber>65535 Then CPFailCode(203,'constante hexadecimale hors limites UCSD')
  End;if Digits=0 Then CPFail('chiffre hexadecimal attendu');CPToken:='NUM';Exit
 End;
 if C='&'Then Begin
  Inc(CPPos);CPNumber:=0;Digits:=0;
  While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['0'..'9'])do Begin
   C:=Chr(CPSource^[CPPos]);
   if C in['8','9']Then CPFailCode(204,'8 ou 9 dans un nombre octal')
   else if CPNumber>(65535-(Ord(C)-Ord('0')))div 8 Then
    CPFailCode(203,'constante octale hors limites UCSD')
   else CPNumber:=CPNumber*8+Ord(C)-Ord('0');Inc(CPPos);Inc(Digits)
  End;
  if Digits=0 Then CPFailCode(106,'chiffre octal attendu');CPToken:='NUM';Exit
 End;
 if C='#'Then Begin
  Inc(CPPos);CPNumber:=0;Digits:=0;
  While(CPPos<CPSize)and(Chr(CPSource^[CPPos])in['0'..'9'])do Begin
   CPNumber:=CPNumber*10+CPSource^[CPPos]-Ord('0');Inc(CPPos);Inc(Digits)
  End;if Digits=0 Then CPFail('code de caractere attendu')else
  if CPNumber>255 Then CPFail('caractere de controle hors limites');
  CPToken:='CTRL';Exit
 End;
 if C=''''Then Begin
  Inc(CPPos);Closed:=False;
  While(CPPos<CPSize)do Begin
   C:=Chr(CPSource^[CPPos]);Inc(CPPos);
   if C=''''Then Begin
    if(CPPos<CPSize)and(CPSource^[CPPos]=Ord(''''))Then Begin
     CPText:=CPText+'''';Inc(CPPos)
    End else
    Begin
     Closed:=True;Break
    End
   End else if C in[#10,#13]Then Begin
    CPFailCode(202,'fin de ligne dans une chaine');
    if C=#10 Then Inc(CPLine);Break
   End
   else if Length(CPText)<255 Then CPText:=CPText+C
   else
   Begin
    CPFail('chaine de plus de 255 caracteres');Break
   End
  End;
  if not Closed and not CPError Then CPFailCode(401,'fin de fichier dans une chaine');
  CPToken:='STR';Exit
 End;
 if not(C in['+', '-', '*', '/', '=', '<', '>', '(', ')', '[', ']',
  '.', ',', ':', ';', '^', '@'])Then Begin
  CPFailCode(400,'caractere invalide dans le source');Inc(CPPos);
  CPToken:='INVALID';Exit
 End;
 CPToken:=C;Inc(CPPos);
 if(C='.')and(CPPos<CPSize)and(CPSource^[CPPos]=Ord('.'))Then Begin
  CPToken:='..';Inc(CPPos);Exit
 End;
 if(C in[':', '<','>'])and(CPPos<CPSize)Then Begin
  C:=Chr(CPSource^[CPPos]);
  if((CPToken=':')and(C='='))or((CPToken='<')and(C in['=','>']))or
  ((CPToken='>')and(C='='))Then Begin
   CPToken:=CPToken+C;Inc(CPPos)
  End
 End
End;

Function CPIs(S:String):Boolean;Begin
 CPIs:=(CPToken='ID')and(CPText=S)
End;

Procedure CPNeed(S:String);Begin
 if CPToken<>S Then Begin
  if CPToken='EOF'Then CPFailCode(401,'fin de source avant "'+S+'"')
  else if S=')'Then CPFailCode(4,''')'' attendu')
  else if S=':'Then CPFailCode(5,''':'' attendu')
  else if S='OF'Then CPFailCode(8,'''OF'' attendu')
  else if S='('Then CPFailCode(9,'''('' attendu')
  else if S='END'Then CPFailCode(13,'''END'' attendu')
  else if S=';'Then CPFailCode(14,''';'' attendu')
  else if S='='Then CPFailCode(16,'''='' attendu')
  else if S='BEGIN'Then CPFailCode(17,'''BEGIN'' attendu')
  else if S=','Then CPFailCode(20,''','' attendu')
  else if S='*'Then CPFailCode(21,'''*'' attendu')
  else if S='INTERFACE'Then CPFailCode(22,'''INTERFACE'' attendu')
  else if S='IMPLEMENTATION'Then CPFailCode(23,'''IMPLEMENTATION'' attendu')
  else if S='UNIT'Then CPFailCode(24,'''UNIT'' attendu')
  else if S=':='Then CPFailCode(51,''':='' attendu')
  else if S='THEN'Then CPFailCode(52,'''THEN'' attendu')
  else if S='UNTIL'Then CPFailCode(53,'''UNTIL'' attendu')
  else if S='DO'Then CPFailCode(54,'''DO'' attendu')
  else if S='IF'Then CPFailCode(56,'''IF'' attendu')
  else if S='FILE'Then CPFailCode(57,'''FILE'' attendu')
  else CPFailCode(6,'symbole "'+S+'" attendu')
 End else CPNext
End;

Function CPExpandIncludeFiles(Const RootName:String):Boolean;
Var OutBuf:PPasSource;OutSize:LongInt;

Function DirOf(Const S:String):String;
Var I:Integer;
Begin I:=Length(S);While(I>0)and not(S[I]in['/','\',':'])do Dec(I);DirOf:=Copy(S,1,I) End;

Procedure PutText(Const S:String);
Var I:Integer;
Begin
 if OutSize+Length(S)>65534 Then Begin CPFailCode(193,'sources incluses trop grandes');Exit End;
 For I:=1 to Length(S)do Begin OutBuf^[OutSize]:=Ord(S[I]);Inc(OutSize) End
End;

Procedure Expand(B:PPasSource;L:LongInt;Const FileName,Chain:String;Depth:Integer);
Var I,J,LineNo:LongInt;D,U,N,Path,Marker:String;Paren:Boolean;F:File;Sz:LongInt;
 Count:Word;Child:PPasSource;
Begin
 if Depth>8 Then Begin CPFailCode(407,'limite d''imbrication des fichiers inclus depassee');Exit End;
 I:=0;LineNo:=1;PutText('{$SOURCE '+FileName+'|1}'+#10);
 While(I<L)and not CPError do Begin
  Paren:=False;J:=I;
  if(B^[I]=Ord('{'))and(I+2<L)and(B^[I+1]=Ord('$'))Then J:=I+2
  else if(B^[I]=Ord('('))and(I+3<L)and(B^[I+1]=Ord('*'))and
   (B^[I+2]=Ord('$'))Then Begin J:=I+3;Paren:=True End
  else Begin
   OutBuf^[OutSize]:=B^[I];Inc(OutSize);if B^[I]=10 Then Inc(LineNo);Inc(I);Continue
  End;
  D:='';
  While(J<L)and(Length(D)<255)and
   ((not Paren and(B^[J]<>Ord('}')))or(Paren and not((B^[J]=Ord('*'))and
    (J+1<L)and(B^[J+1]=Ord(')')))))do Begin D:=D+Chr(B^[J]);Inc(J) End;
  if J>=L Then Begin CPFailCode(401,'fin de fichier dans une directive');Exit End;
  U:=UpperString(TrimString(D));N:='';
  if(Copy(U,1,8)='INCLUDE ')Then N:=TrimString(Copy(D,9,255))
  else if(Copy(U,1,2)='I ')Then N:=TrimString(Copy(D,3,255));
  if N=''Then Begin
   if(U='L')or(U='L+')Then CPListing:=True else if U='L-'Then CPListing:=False;
   While I<=J+Ord(Paren)do Begin
    OutBuf^[OutSize]:=B^[I];Inc(OutSize);if B^[I]=10 Then Inc(LineNo);Inc(I)
   End;Continue
  End;
  if(N[1]='''')and(N[Length(N)]='''')and(Length(N)>=2)Then N:=Copy(N,2,Length(N)-2);
  Path:=DirOf(FileName)+N;if not FileExists(Path)Then Path:=N;
  if Pos('|'+UpperString(Path)+'|',UpperString(Chain))<>0 Then Begin
   CPFailCode(406,'inclusion cyclique: '+Path);Exit
  End;
  Assign(F,Path);Reset(F,1);if IOResult<>0 Then Begin
   CPFailCode(403,'lecture du fichier inclus impossible: '+Path);Exit
  End;Sz:=FileSize(F);
  if(Sz<0)or(Sz>65534)Then Begin Close(F);if IOResult<>0 Then Begin End;
   CPFailCode(406,'fichier inclus illegal: '+Path);Exit
  End;
  GetMem(Child,SizeOf(TPCodeMemory));Count:=0;if Sz>0 Then BlockRead(F,Child^,Sz,Count);
  if(IOResult<>0)or(Count<>Sz)Then CPFailCode(403,'lecture incomplete du fichier inclus: '+Path);
  Close(F);if IOResult<>0 Then CPFailCode(403,'fermeture du fichier inclus impossible: '+Path);
  if not CPError Then Expand(Child,Sz,Path,Chain+UpperString(Path)+'|',Depth+1);
  FreeMem(Child,SizeOf(TPCodeMemory));
  if Paren Then I:=J+2 else I:=J+1;
  Str(LineNo,Marker);PutText(#10+'{$SOURCE '+FileName+'|'+Marker+'}'+#10)
 End
End;

Procedure CPPrintSourceListing;
Var I,LineNo:LongInt;S:String;
Begin
 WriteLn('Listing de compilation:');I:=0;LineNo:=1;S:='';
 While I<CPSize do Begin
  if CPSource^[I]=10 Then Begin
   WriteLn(LineNo:5,'  ',S);S:='';Inc(LineNo)
  End else if CPSource^[I]<>13 Then Begin
   if Length(S)<240 Then S:=S+Chr(CPSource^[I])
  End;Inc(I)
 End;
 if S<>''Then WriteLn(LineNo:5,'  ',S);WriteLn
End;

Begin
 CPExpandIncludeFiles:=False;GetMem(OutBuf,SizeOf(TPCodeMemory));OutSize:=0;
 Expand(CPSource,CPSize,RootName,'|'+UpperString(RootName)+'|',0);
 if not CPError Then Begin Move(OutBuf^,CPSource^,OutSize);CPSize:=OutSize;
  CPExpandIncludeFiles:=True;if CPListing Then CPPrintSourceListing End;
 FreeMem(OutBuf,SizeOf(TPCodeMemory));CPPos:=0;CPTokenPos:=0;CPLine:=1;
 CPDiagnosticFile:=RootName
End;
Function CPFind(S:String):PPasSymbol;Forward;
Procedure CPAdd(S:String;V:Integer;K:Boolean);Forward;

Function CPNewAnonymousType(K:TPasTypeKind):PPasType;
Var
 T:PPasType;
Begin
 New(T);FillChar(T^,SizeOf(TPasType),0);T^.Kind:=K;T^.AlignWords:=1;
 T^.Scope:=CPCurrentRoutine;
 T^.Next:=CPTypes;CPTypes:=T;CPNewAnonymousType:=T
End;

Function CPRecomputeSize(T:PPasType):LongInt;
Var
 N:LongInt;
Begin
 if T=Nil Then Begin
  CPRecomputeSize:=0;Exit
 End;
 if T^.Kind=ptkArray Then Begin
  N:=CPRecomputeSize(T^.ElementType)*T^.ElementCount;
  if N>65535 Then Begin
   CPFail('type tableau trop grand');N:=65535
  End;
  T^.SizeWords:=N
 End;CPRecomputeSize:=T^.SizeWords
End;

Function CPBoundValue(Var V:LongInt;Var Base:PPasType):Boolean;
Var
 S:PPasSymbol;
 Neg:Boolean;
Begin
 Neg:=False;if CPToken='-'Then Begin
  Neg:=True;CPNext
 End else
 if CPToken='+'Then CPNext;
 if CPToken='NUM'Then Begin
  V:=CPNumber;Base:=CPFindType('INTEGER');CPNext
 End
 else if CPToken='CTRL'Then Begin
  V:=CPNumber;Base:=CPFindType('CHAR');CPNext
 End
 else if CPToken='STR'Then Begin
  if Length(CPText)<>1 Then Begin
   CPFail('borne caractere invalide');CPBoundValue:=False;Exit
  End;
  V:=Ord(CPText[1]);Base:=CPFindType('CHAR');CPNext
 End else if CPToken='ID'Then Begin
  S:=CPFind(CPText);if(S=Nil)or not S^.IsConst Then Begin
   CPFail('constante de borne inconnue: '+CPText);CPBoundValue:=False;Exit
  End;V:=S^.Value;Base:=S^.SymbolType;if Base=Nil Then Base:=CPFindType('INTEGER');CPNext
 End else
 Begin
  CPFail('borne attendue');CPBoundValue:=False;Exit
 End;
 if Neg Then V:=-V;CPBoundValue:=True
End;
Function CPParseType:PPasType;Forward;

Function CPParseFormalType(K:TPasTypeKind):PPasType;
Var
 T:PPasType;
 Depth:Integer;
Begin
 T:=CPNewAnonymousType(K);T^.SizeWords:=1;CPNext;
 if CPToken='('Then Begin
  Depth:=1;CPNext;
  While(Depth>0)and(CPToken<>'EOF')do Begin
   if CPToken='('Then Inc(Depth)else if CPToken=')'Then Dec(Depth);
   if Depth>0 Then CPNext
  End;if CPToken=')'Then CPNext
 End;
 if(K=ptkFunction)and(CPToken=':')Then Begin
  CPNext;T^.ResultType:=CPParseType
 End;
 CPParseFormalType:=T
End;

Function CPParseRecord(PackedFlag:Boolean):PPasType;
Var
 T,FT:PPasType;
 F,Tail:PPasField;
 Names:Array[1..64]of String;
 TagName:String;
 N,I:Integer;
 Offset,MaxOffset:LongInt;
 HasTagName:Boolean;
Begin
 T:=CPNewAnonymousType(ptkRecord);T^.PackedType:=PackedFlag;CPNext;Offset:=0;MaxOffset:=0;
 Tail:=Nil;
 While(CPToken<>'EOF')and not CPIs('END')and not CPError do Begin
  if CPIs('CASE')Then Begin
   T^.Kind:=ptkVariantRecord;
   { Le discriminant et les variantes partagent la meme zone; leur syntaxe est
     parcourue tout en conservant la taille maximale rencontree. }
   CPNext;FT:=Nil;HasTagName:=False;
   if CPToken='ID'Then Begin TagName:=CPText;CPNext;
    if CPToken=':'Then Begin HasTagName:=True;CPNext;FT:=CPParseType End
    else FT:=CPFindType(TagName)
   End;
   FT:=CPBaseType(FT);
   if(FT<>Nil)and(FT^.Kind in[ptkReal,ptkString])Then
    CPFailCode(159,'champ de balise reel ou chaine interdit')
   else
   if(FT=Nil)or not(FT^.Kind in[ptkInteger,ptkBoolean,ptkChar,ptkEnumeration,ptkSubrange])Then
    CPFailCode(110,'le type du champ de balise doit etre scalaire ou sous-intervalle');
   T^.VariantTagType:=FT;
   if HasTagName and(FT<>Nil)Then Begin
    Offset:=CPAlignedSize(Offset,FT^.AlignWords);T^.VariantTagOffset:=Offset;
    New(F);FillChar(F^,SizeOf(TPasField),0);F^.Name:=TagName;F^.FieldType:=FT;
    F^.OffsetWords:=Offset;if Tail=Nil Then T^.Fields:=F else Tail^.Next:=F;Tail:=F;
    Inc(Offset,FT^.SizeWords);if Offset>MaxOffset Then MaxOffset:=Offset
   End;
   if CPIs('OF')Then CPNext else CPFailCode(8,'''OF'' attendu');
   While(CPToken<>'EOF')and not CPIs('END')do Begin
    if CPToken='('Then Begin
     CPNext;Continue
    End;
    if CPToken=')'Then Begin
     CPNext;if CPToken=';'Then CPNext;Continue
    End;
    CPNext
   End
  End else if CPToken='ID'Then Begin
   N:=0;Repeat Inc(N);Names[N]:=CPText;CPNext;
   if CPToken=','Then CPNext else Break Until N=64;
   CPNeed(':');FT:=CPParseType;
   Offset:=CPAlignedSize(Offset,FT^.AlignWords);
   For I:=1 to N do Begin
    New(F);FillChar(F^,SizeOf(TPasField),0);F^.Name:=Names[I];F^.FieldType:=FT;
    F^.OffsetWords:=Offset;if Tail=Nil Then T^.Fields:=F else Tail^.Next:=F;Tail:=F;
    Inc(Offset,FT^.SizeWords)
   End;if Offset>MaxOffset Then MaxOffset:=Offset;
   if CPToken=';'Then CPNext
  End else CPNext
 End;
 if CPIs('END')Then CPNext else CPFail('END d''enregistrement attendu');
 T^.SizeWords:=MaxOffset;if T^.SizeWords=0 Then T^.SizeWords:=1;CPParseRecord:=T
End;

Function CPParseType:PPasType;
Var
 T,Base,Idx,Elem,Outer,TailType:PPasType;
 PackedFlag:Boolean;
 Lo,Hi,Count:LongInt;
 Name:String;
 N:Integer;
Begin
 PackedFlag:=False;if CPIs('PACKED')Then Begin
  PackedFlag:=True;CPNext
 End;
 if CPIs('ARRAY')Then Begin
  CPNext;CPNeed('[');Outer:=Nil;TailType:=Nil;
  Repeat
  Idx:=CPParseType;
  if(CPBaseType(Idx)<>Nil)and(CPBaseType(Idx)^.Kind=ptkReal)Then
   CPFailCode(112,'le type d''index ne doit pas etre reel')
  else if not CPIsOrdinalType(Idx)Then
   CPFailCode(113,'le type d''index doit etre scalaire ou sous-intervalle');
  Elem:=CPNewAnonymousType(ptkArray);Elem^.IndexType:=Idx;
  Count:=Idx^.HighBound-Idx^.LowBound+1;if Count<0 Then Count:=0;
  Elem^.ElementCount:=Count;
  Elem^.PackedType:=PackedFlag;
  if Outer=Nil Then Outer:=Elem else TailType^.ElementType:=Elem;TailType:=Elem;
  if CPToken=','Then CPNext else Break
  Until False;CPNeed(']');if not CPIs('OF')Then CPFail('OF attendu')else CPNext;
  Base:=CPParseType;
  { Les dimensions ont ete lues de gauche a droite: applique le type elementaire
    au maillon le plus interieur puis calcule les tailles vers l'exterieur. }
  TailType^.ElementType:=Base;
  if(CPBaseType(Base)<>Nil)and(CPBaseType(Base)^.Kind=ptkFile)Then
   CPFailCode(108,'fichier interdit comme element de tableau');
  CPRecomputeSize(Outer);CPParseType:=Outer;Exit
 End;
 if CPIs('RECORD')Then Begin
  CPParseType:=CPParseRecord(PackedFlag);Exit
 End;
 if CPIs('SET')Then Begin
  CPNext;if CPIs('OF')Then CPNext else CPFail('OF attendu');
  T:=CPNewAnonymousType(ptkSet);T^.ElementType:=CPParseType;
  if(CPBaseType(T^.ElementType)<>Nil)and(CPBaseType(T^.ElementType)^.Kind=ptkReal)Then
   CPFailCode(114,'le type de base ne doit pas etre reel')
  else if not CPIsOrdinalType(T^.ElementType)Then
   CPFailCode(115,'le type de base doit etre scalaire ou sous-intervalle');
  Count:=T^.ElementType^.HighBound-T^.ElementType^.LowBound+1;
  if(Count<1)or(Count>256)or(T^.ElementType^.LowBound<0)or
   (T^.ElementType^.HighBound>255)Then
   CPFailCode(169,'bornes du type de base de l''ensemble hors de 0..255');
  if Count<1 Then Count:=256;
  T^.SizeWords:=16;T^.PackedType:=PackedFlag;CPParseType:=T;Exit
 End;
 if CPIs('FILE')Then Begin
  CPNext;T:=CPNewAnonymousType(ptkFile);T^.SizeWords:=1;
  if CPIs('OF')Then Begin
   CPNext;T^.ElementType:=CPParseType
  End;
  CPParseType:=T;Exit
 End;
 if CPIs('PROCEDURE')Then Begin
  CPParseType:=CPParseFormalType(ptkProcedure);Exit
 End;
 if CPIs('FUNCTION')Then Begin
  CPParseType:=CPParseFormalType(ptkFunction);Exit
 End;
 if CPToken='^'Then Begin
  CPNext;T:=CPNewAnonymousType(ptkPointer);T^.SizeWords:=1;
  if CPToken='ID'Then Begin
   T^.ElementType:=CPFindType(CPText);
   if T^.ElementType=Nil Then Begin
    T^.ElementType:=CPAddType(CPText,ptkAlias,0)
   End;CPNext
  End else CPFail('type pointe attendu');CPParseType:=T;Exit
 End;
 if CPIs('STRING')Then Begin
  CPNext;Hi:=255;if CPToken='['Then Begin
   CPNext;
   if CPToken='NUM'Then Begin
    Hi:=CPNumber;CPNext
   End else CPFail('longueur de chaine attendue');CPNeed(']')
  End;if Hi>255 Then Begin
   CPFail('chaine UCSD limitee a 255 caracteres');Hi:=255
  End;
  T:=CPNewAnonymousType(ptkString);T^.HighBound:=Hi;T^.SizeWords:=Hi+1;
  T^.PackedType:=True;CPParseType:=T;Exit
 End;
 if CPToken='('Then Begin
  T:=CPNewAnonymousType(ptkEnumeration);T^.LowBound:=0;N:=0;CPNext;
  While(CPToken='ID')and not CPError do Begin
   Name:=CPText;CPNext;
   if CPFind(Name)=Nil Then CPAdd(Name,N,True);
   if CPFind(Name)<>Nil Then CPFind(Name)^.SymbolType:=T;
   Inc(N);if CPToken=','Then CPNext else Break
  End;CPNeed(')');T^.HighBound:=N-1;T^.SizeWords:=1;CPParseType:=T;Exit
 End;
 if(CPToken='NUM')or(CPToken='STR')or(CPToken='-')or(CPToken='+')Then Begin
  if not CPBoundValue(Lo,Base)Then Begin
   CPParseType:=CPFindType('INTEGER');Exit
  End;
  CPNeed('..');if not CPBoundValue(Hi,Idx)Then Begin
   CPParseType:=Base;Exit
  End;
  if not CPTypeEquivalent(Base,Idx)Then CPFailCode(107,'bornes de types incompatibles');
  if Lo>Hi Then CPFailCode(102,'la borne inferieure depasse la borne superieure');T:=CPNewAnonymousType(ptkSubrange);
  T^.ElementType:=Base;T^.LowBound:=Lo;T^.HighBound:=Hi;T^.SizeWords:=1;CPParseType:=T;
  Exit
 End;
 if CPToken='ID'Then Begin
  Name:=CPText;T:=CPFindType(Name);CPNext;
  if(CPToken='..')Then Begin
   Lo:=0;if T<>Nil Then Begin
    CPFail('borne constante attendue');CPParseType:=T;Exit
   End
  End;
  if T=Nil Then Begin
   CPFailCode(104,'type non declare: '+Name);T:=CPFindType('INTEGER')
  End;
  CPParseType:=T;Exit
 End;
 CPFail('type attendu');CPParseType:=CPFindType('INTEGER')
End;

Procedure CPParseTypeSection;
Var
 Name:String;
 T,Named:PPasType;
Begin
 if not CPIs('TYPE')Then Exit;CPNext;
 While(CPToken='ID')and not CPIs('VAR')and not CPIs('CONST')and
 not CPIs('BEGIN')and not CPIs('PROCEDURE')and not CPIs('FUNCTION')and
 not CPError do Begin
  Name:=CPText;CPNext;CPNeed('=');T:=CPParseType;
  Named:=CPFindType(Name);
  if(Named<>Nil)and(Named^.Scope<>CPCurrentRoutine)Then Named:=Nil;
  if Named=Nil Then Named:=CPAddType(Name,ptkAlias,T^.SizeWords);
  Named^.Kind:=ptkAlias;Named^.SizeWords:=T^.SizeWords;Named^.ElementType:=T;
  Named^.AlignWords:=T^.AlignWords;Named^.LowBound:=T^.LowBound;
  Named^.HighBound:=T^.HighBound;
  CPNeed(';')
 End
End;

Function CPFind(S:String):PPasSymbol;
Var
 P,Best:PPasSymbol;
 R:PPasRoutine;
 T:PPasType;
 F:PPasField;
Begin
 Best:=Nil;R:=CPCurrentRoutine;
 Repeat
 P:=CPSymbols;
 While P<>Nil do Begin
  if(P^.Name=S)and(P^.Scope=R)Then Begin
   Best:=P;Break
  End;
  P:=P^.Next
 End;
 if Best<>Nil Then Break;
 if R<>Nil Then R:=R^.Parent else Break
 Until False;
 if(Best=Nil)and(CPWithSymbol<>Nil)Then Begin
  T:=CPWithType;
  While(T<>Nil)and(T^.Kind=ptkAlias)do T:=T^.ElementType;
  if(T<>Nil)and(T^.Kind in[ptkRecord,ptkVariantRecord])Then Begin
   F:=T^.Fields;
   While(F<>Nil)and(F^.Name<>S)do F:=F^.Next;
   if F<>Nil Then Begin
    FillChar(CPWithField,SizeOf(CPWithField),0);
    CPWithField.Name:=S;CPWithField.SymbolType:=F^.FieldType;
    CPWithField.BaseSymbol:=CPWithSymbol;CPWithField.FieldOffset:=F^.OffsetWords;
    Best:=@CPWithField
   End
  End
 End;if(Best<>Nil)and(Best<>@CPWithField)Then Best^.Used:=True;CPFind:=Best
End;

Procedure CPAdd(S:String;V:Integer;K:Boolean);
Var
 P:PPasSymbol;
Begin
 P:=CPSymbols;
 While(P<>Nil)and((P^.Name<>S)or(P^.Scope<>CPCurrentRoutine))do P:=P^.Next;
 if P<>Nil Then Begin
  CPFailCode(101,'identificateur declare deux fois: '+S);Exit
 End;
 New(P);FillChar(P^,SizeOf(TPasSymbol),0);P^.Name:=S;P^.Value:=V;
 P^.Address:=V;P^.IsConst:=K;P^.Scope:=CPCurrentRoutine;P^.DeclarationLine:=CPLine;
 if CPCurrentRoutine<>Nil Then P^.LexicalLevel:=CPCurrentRoutine^.LexicalLevel;
 P^.Next:=CPSymbols;CPSymbols:=P
End;

Procedure CPAddTyped(S:String;V:Integer;K:Boolean;T:PPasType);
Var
 P:PPasSymbol;
Begin
 if(CPCurrentRoutine=Nil)and((S='INPUT')or(S='OUTPUT'))Then Begin
  CPFailCode(171,'fichier standard redeclare: '+S);Exit
 End;
 CPAdd(S,V,K);P:=CPFind(S);if P<>Nil Then Begin
  P^.SymbolType:=T;P^.Used:=False
 End
End;
Function CPEvalConstExpression: TConstValue;Forward;

Procedure CPCheckConstRange(V:LongInt);Begin
 if(V<-32768)or(V>65535)Then CPFailCode(203,'debordement d''expression constante 16 bits')
End;

Function CPEvalConstFactor:TConstValue;
Var
 V:TConstValue;
 P:PPasSymbol;
 Neg:Boolean;
Begin
 FillChar(V,SizeOf(V),0);V.Kind:=ckInteger;Neg:=False;
 if CPIs('NOT')Then Begin
  CPNext;V:=CPEvalConstFactor;V.I:=not V.I;
  CPEvalConstFactor:=V;Exit
 End;
 if CPToken='-'Then Begin
  Neg:=True;CPNext
 End else if CPToken='+'Then CPNext;
 if CPToken='NUM'Then Begin
  V.I:=CPNumber;CPNext
 End
 else if CPToken='CTRL'Then Begin
  V.Kind:=ckCharacter;V.I:=CPNumber;CPNext
 End
 else if CPToken='REALNUM'Then Begin
  V.Kind:=ckReal;V.R:=CPRealNumber;CPNext
 End
 else if CPToken='STR'Then Begin
  V.S:=CPText;
  if Length(V.S)=1 Then Begin
   V.Kind:=ckCharacter;V.I:=Ord(V.S[1])
  End
  else V.Kind:=ckString;CPNext
 End else if CPToken='('Then Begin
  CPNext;V:=CPEvalConstExpression;CPNeed(')')
 End
 else if CPToken='ID'Then Begin
  P:=CPFind(CPText);if P=Nil Then CPFailCode(104,'constante non declaree: '+CPText)
  else if not P^.IsConst Then CPFailCode(103,'identificateur de classe constante attendu: '+CPText)
  else if P^.IsStringConst Then Begin
   V.Kind:=ckString;V.S:=P^.ConstText
  End
  else if P^.IsRealConst Then Begin
   V.Kind:=ckReal;V.R:=P^.ConstReal
  End
  else
  Begin
   V.I:=P^.Value;V.Kind:=ckInteger;
   if(P^.SymbolType<>Nil)and(P^.SymbolType^.Kind=ptkChar)Then V.Kind:=ckCharacter
  End;CPNext
 End else
 Begin
  CPFail('constante attendue');CPNext
 End;
 if Neg Then Begin
  if V.Kind=ckReal Then V.R:=-V.R else if V.Kind in[ckInteger,ckCharacter]Then V.I:=-V.I
  else CPFailCode(105,'signe non autorise devant une chaine')
 End;CPEvalConstFactor:=V
End;

Function CPEvalConstTerm:TConstValue;
Var
 A,B:TConstValue;
 O:String;
Begin
 A:=CPEvalConstFactor;
 While(CPToken='*')or(CPToken='/')or CPIs('DIV')or CPIs('MOD')or CPIs('AND')or
 CPIs('SHL')or CPIs('SHR')do Begin
  O:=CPToken;if CPToken='ID'Then O:=CPText;CPNext;B:=CPEvalConstFactor;
  if(A.Kind=ckReal)or(B.Kind=ckReal)or(O='/')Then Begin
   if A.Kind<>ckReal Then A.R:=A.I;if B.Kind<>ckReal Then B.R:=B.I;A.Kind:=ckReal;
   if O='*'Then A.R:=A.R*B.R else if B.R=0 Then CPFailCode(300,'division par zero')else A.R:=A.R/
   B.R
  End else if O='SHL'Then A.I:=A.I shl B.I
  else if O='SHR'Then A.I:=A.I shr B.I
  else if O='*'Then A.I:=A.I*B.I
  else if O='DIV'Then Begin
   if B.I=0 Then CPFailCode(300,'division par zero')else A.I:=A.I div B.I
  End
  else if O='MOD'Then Begin
   if B.I=0 Then CPFailCode(300,'division par zero')else A.I:=A.I mod B.I
  End
  else A.I:=A.I and B.I;
  if A.Kind<>ckReal Then CPCheckConstRange(A.I)
 End;CPEvalConstTerm:=A
End;

Function CPEvalConstExpression:TConstValue;
Var
 A,B:TConstValue;
 O:String;
Begin
 A:=CPEvalConstTerm;
 While(CPToken='+')or(CPToken='-')or CPIs('OR')do Begin
  O:=CPToken;if CPToken='ID'Then O:=CPText;CPNext;B:=CPEvalConstTerm;
  if(A.Kind=ckString)or(B.Kind=ckString)Then Begin
   if O<>'+'Then CPFail('operateur interdit sur une chaine')else
   Begin
    if A.Kind<>ckString Then A.S:=Chr(A.I);if B.Kind<>ckString Then B.S:=Chr(B.I);
    A.S:=A.S+B.S;A.Kind:=ckString
   End
  End else if(A.Kind=ckReal)or(B.Kind=ckReal)Then Begin
   if A.Kind<>ckReal Then A.R:=A.I;if B.Kind<>ckReal Then B.R:=B.I;A.Kind:=ckReal;
   if O='+'Then A.R:=A.R+B.R else A.R:=A.R-B.R
  End else if O='+'Then A.I:=A.I+B.I else if O='-'Then A.I:=A.I-B.I else A.I:=A.I or B.I;
  if not(A.Kind in[ckReal,ckString])Then CPCheckConstRange(A.I)
 End;
 if(CPToken='=')or(CPToken='<>')or(CPToken='<')or(CPToken='<=')or
 (CPToken='>')or(CPToken='>=')Then Begin
  O:=CPToken;CPNext;B:=CPEvalConstExpression;
  if(A.Kind=ckString)or(B.Kind=ckString)Then Begin
   if A.Kind<>ckString Then A.S:=Chr(A.I);if B.Kind<>ckString Then B.S:=Chr(B.I);
   if O='='Then A.I:=Ord(A.S=B.S)else if O='<>'Then A.I:=Ord(A.S<>B.S)
   else if O='<'Then A.I:=Ord(A.S<B.S)else if O='<='Then A.I:=Ord(A.S<=B.S)
   else if O='>'Then A.I:=Ord(A.S>B.S)else A.I:=Ord(A.S>=B.S)
  End else
  Begin
   if A.Kind=ckReal Then Begin
    if B.Kind<>ckReal Then B.R:=B.I
   End
   else if B.Kind=ckReal Then A.R:=A.I;
   if(A.Kind=ckReal)or(B.Kind=ckReal)Then Begin
    if O='='Then A.I:=Ord(A.R=B.R)else if O='<>'Then A.I:=Ord(A.R<>B.R)
    else if O='<'Then A.I:=Ord(A.R<B.R)else if O='<='Then A.I:=Ord(A.R<=B.R)
    else if O='>'Then A.I:=Ord(A.R>B.R)else A.I:=Ord(A.R>=B.R)
   End else if O='='Then A.I:=Ord(A.I=B.I)else if O='<>'Then A.I:=Ord(A.I<>B.I)
   else if O='<'Then A.I:=Ord(A.I<B.I)else if O='<='Then A.I:=Ord(A.I<=B.I)
   else if O='>'Then A.I:=Ord(A.I>B.I)else A.I:=Ord(A.I>=B.I)
  End;A.Kind:=ckInteger
 End;CPEvalConstExpression:=A
End;

Procedure CPParseConstSection;
Var
 Name:String;
 V:TConstValue;
 P:PPasSymbol;
 T:PPasType;
Begin
 if not CPIs('CONST')Then Exit;CPNext;
 While(CPToken='ID')and not CPIs('TYPE')and not CPIs('VAR')and not CPIs('LABEL')and
 not CPIs('BEGIN')and not CPIs('PROCEDURE')and not CPIs('FUNCTION')
 and not CPError do Begin
  Name:=CPText;CPNext;CPNeed('=');V:=CPEvalConstExpression;
  P:=CPFind(Name);if(P=Nil)or(P^.Scope<>CPCurrentRoutine)Then Begin
   Case V.Kind of
   ckCharacter:T:=CPFindType('CHAR');ckReal:T:=CPFindType('REAL');
   ckString:T:=CPFindType('STRING');else T:=CPFindType('INTEGER')
  End;CPAddTyped(Name,V.I,True,T);P:=CPFind(Name);
  if V.Kind=ckString Then Begin
   P^.IsStringConst:=True;P^.ConstText:=V.S
  End;
  if V.Kind=ckReal Then Begin
   P^.IsRealConst:=True;P^.ConstReal:=V.R
  End
  else if(V.Kind in[ckInteger,ckCharacter])and((V.I<-32768)or(V.I>65535))Then    CPFail(
  'debordement d''une constante 16 bits')
 End else
 Begin
  P^.Value:=V.I;P^.ConstText:=V.S;P^.ConstReal:=V.R;
  P^.IsStringConst:=V.Kind=ckString;P^.IsRealConst:=V.Kind=ckReal
 End;if P<>Nil Then P^.Used:=False;CPNeed(';')
End
End;

Procedure CPE(B:Byte);Begin
 if CPPass=1 Then Exit;
 if CPCodePos>=65535 Then CPFailCode(193,'programme trop grand')else
 Begin
  PCode_Mem^[CPCodePos]:=B;Inc(CPCodePos)
 End
End;
Procedure CPOp(OpcodeII,OpcodeIV:Byte);Forward;

Procedure CPWriteBranchWord(P:LongInt;D:LongInt);Begin
 if(P<0)or(P+1>=CPCodePos)Then Begin
  CPFail('correctif de branchement invalide');Exit
 End;
 if(D<-32768)or(D>32767)Then Begin
  CPFail('deplacement de branchement 16 bits hors limites');Exit
 End;
 PCode_Mem^[P]:=Byte(D);PCode_Mem^[P+1]:=Byte(D shr 8)
End;
{ Produit un saut conditionnel avant dont le correctif est toujours 16 bits.
  IV dispose de UJPW. II utilise XJP sur un selecteur constant comme
  trampoline long; le chemin vrai contourne le trampoline. }

Function CPForwardFalse:LongInt;Begin
 CPOp(161,$D4);CPE(2);
 if CurrentTarget=ptUCSDPSystemIV Then Begin
  CPE($8A);CPE(3);CPE($8B);
  CPForwardFalse:=CPCodePos;CPE(0);CPE(0)
 End else
 Begin
  CPE(185);CPE(8);CPE(0);CPE(172);CPE(0);CPE(0);CPE(0);CPE(0);
  CPForwardFalse:=CPCodePos;CPE(0);CPE(0)
 End
End;

Function CPForwardJump:LongInt;Begin
 if CurrentTarget=ptUCSDPSystemIV Then Begin
  CPE($8B);CPForwardJump:=CPCodePos;CPE(0);CPE(0)
 End
 else
 Begin
  CPE(0);CPE(172);CPE(0);CPE(0);CPE(0);CPE(0);
  CPForwardJump:=CPCodePos;CPE(0);CPE(0)
 End
End;

Procedure CPPatchForward(P,Target:LongInt);Begin
 CPWriteBranchWord(P,Target-(P+2))
End;

Procedure CPJumpBack(Target:LongInt);
Var
 D:LongInt;
Begin
 D:=Target-(CPCodePos+2);
 if(D>=-128)and(D<=127)Then Begin
  CPOp(185,$8A);CPE(Byte(D))
 End
 else if CurrentTarget=ptUCSDPSystemIV Then Begin
  CPE($8B);D:=Target-(CPCodePos+2);
  if(D<-32768)or(D>32767)Then CPFail('branche arriere hors limites')else
  Begin
   CPE(Byte(D));CPE(Byte(D shr 8))
  End
 End else
 Begin
  CPE(0);CPE(172);CPE(0);CPE(0);CPE(0);CPE(0);D:=Target-(CPCodePos+2);
  if(D<-32768)or(D>32767)Then CPFail('branche arriere hors limites')else
  Begin
   CPE(Byte(D));CPE(Byte(D shr 8))
  End
 End
End;

Function CPFindLabel(S:String;CreateIt:Boolean):PPasLabel;
Var
 L:PPasLabel;
Begin
 L:=CPLabels;
 While(L<>Nil)and((L^.Name<>S)or(L^.Scope<>CPCurrentRoutine))do L:=L^.Next;
 if(L=Nil)and CreateIt Then Begin
  New(L);FillChar(L^,SizeOf(TPasLabel),0);
  L^.Name:=S;L^.Scope:=CPCurrentRoutine;L^.Next:=CPLabels;CPLabels:=L
 End;CPFindLabel:=L
End;

Procedure CPPatchLabel(L:PPasLabel);
Var
 X:PPasLabelFixup;
 D:LongInt;
Begin
 X:=L^.Fixups;
 While X<>Nil do Begin
  D:=L^.Address-(X^.Position+2);
  CPWriteBranchWord(X^.Position,D);X:=X^.Next
 End
End;

Procedure CPDefineLabel(S:String);
Var
 L:PPasLabel;
Begin
 L:=CPFindLabel(S,True);
 if not L^.Declared Then Begin CPFailCode(167,'etiquette non declaree: '+S);Exit End;
 if L^.Defined Then CPFailCode(165,'etiquette definie deux fois: '+S)
 else
 Begin
  L^.Defined:=True;L^.Address:=CPCodePos;CPPatchLabel(L)
 End
End;

Procedure CPEmitGoto(S:String);
Var
 L:PPasLabel;
 X:PPasLabelFixup;
Begin
 L:=CPFindLabel(S,True);
 if not L^.Declared Then Begin CPFailCode(167,'etiquette non declaree: '+S);Exit End;
 if L^.Defined Then CPJumpBack(L^.Address)
 else
 Begin
  New(X);X^.Position:=CPForwardJump;X^.Next:=L^.Fixups;L^.Fixups:=X
 End
End;

Procedure CPCheckLabels(R:PPasRoutine);
Var
 L:PPasLabel;
Begin
 L:=CPLabels;
 While L<>Nil do Begin
  if(L^.Scope=R)and L^.Declared and not L^.Defined Then
   CPFailCode(168,'etiquette non definie: '+L^.Name);
  L:=L^.Next
 End
End;

Procedure CPParseLabelSection;
Var
 S:String;
 L:PPasLabel;
Begin
 if not CPIs('LABEL')Then Exit;CPNext;
 Repeat
 if CPToken='NUM'Then Begin
  Str(CPNumber,S);CPNext
 End
 else if CPToken='ID'Then Begin
  S:=CPText;CPNext
 End
 else
 Begin
  CPFail('etiquette attendue');Exit
 End;
 L:=CPFindLabel(S,True);
 if L^.Declared Then CPFailCode(166,'etiquette declaree deux fois: '+S);
 L^.Declared:=True;if CPToken=','Then CPNext else Break
 Until False;CPNeed(';')
End;

Procedure CPDropScope(R:PPasRoutine);
Var
 P,Prev,N:PPasSymbol;
Begin
 Prev:=Nil;P:=CPSymbols;
 While P<>Nil do Begin
  N:=P^.Next;
  if P^.Scope=R Then Begin
   if Prev=Nil Then CPSymbols:=N else Prev^.Next:=N;Dispose(P)
  End else Prev:=P;
  P:=N
 End
End;
Procedure CPScanRoutine(Parent:PPasRoutine);Forward;

Procedure CPScanRoutine(Parent:PPasRoutine);
Var
 R,Old:PPasRoutine;
 P,Tail:PPasParameter;
 Typ,NewResult:PPasType;
 Name,PN:String;
 Depth:Integer;
 IsFunc,ByRef,WasForward,HadParamSpec,HadResultSpec:Boolean;
Begin
 IsFunc:=CPIs('FUNCTION');CPNext;
 if CPToken<>'ID'Then Begin
  CPFail('nom de routine attendu');Exit
 End;
 Name:=CPText;R:=CPFindRoutine(Name,Parent);
 WasForward:=(R<>Nil)and R^.IsForward;HadParamSpec:=False;HadResultSpec:=False;
 if R=Nil Then R:=CPAddRoutine(Name,Parent,IsFunc);
 if R^.DeclarationLine=0 Then R^.DeclarationLine:=CPLine;
 CPNext;
 Tail:=R^.Parameters;
 While(Tail<>Nil)and(Tail^.Next<>Nil)do Tail:=Tail^.Next;
 if CPToken='('Then Begin
  HadParamSpec:=True;
  CPNext;
  While(CPToken<>')')and(CPToken<>'EOF')and not CPError do Begin
   ByRef:=CPIs('VAR');if ByRef Then CPNext;
   if CPToken<>'ID'Then Begin
    CPFail('nom de parametre attendu');Break
   End;
   PN:=CPText;CPNext;CPNeed(':');
   if CPToken<>'ID'Then Begin
    CPFail('type de parametre attendu');Break
   End;
   Typ:=CPFindType(CPText);if Typ=Nil Then Typ:=CPFindType('INTEGER');CPNext;
   if(CPBaseType(Typ)<>Nil)and(CPBaseType(Typ)^.Kind=ptkFile)and not ByRef Then
    CPFailCode(121,'un fichier ne peut pas etre passe par valeur');
   if not WasForward Then Begin
    New(P);FillChar(P^,SizeOf(TPasParameter),0);P^.Name:=PN;P^.ParamType:=Typ;
    P^.ByReference:=ByRef;P^.Structured:=Typ^.SizeWords>1;
    if P^.ByReference or P^.Structured Then Inc(R^.ParameterWords)
    else Inc(R^.ParameterWords,Typ^.SizeWords);
    P^.Next:=Nil;if Tail=Nil Then R^.Parameters:=P else Tail^.Next:=P;Tail:=P
   End;
   if CPToken=';'Then CPNext else Break
  End;CPNeed(')')
 End;
 if WasForward and HadParamSpec Then
  CPFailCode(119,'les parametres d''une procedure FORWARD ne peuvent pas etre redefinis');
 if IsFunc and(CPToken=':')Then Begin
  HadResultSpec:=True;CPNext;if CPToken='ID'Then Begin
   NewResult:=CPFindType(CPText);CPNext;
   if WasForward Then CPFailCode(122,'le resultat d''une fonction FORWARD ne peut pas etre redefini')
   else R^.ResultType:=NewResult;
   NewResult:=CPBaseType(NewResult);
   if(NewResult=Nil)or not(NewResult^.Kind in[ptkInteger,ptkBoolean,ptkChar,
    ptkEnumeration,ptkSubrange,ptkPointer,ptkReal])Then
    CPFailCode(120,'le resultat d''une fonction doit etre scalaire, sous-intervalle ou pointeur')
  End
  else CPFail('type de resultat attendu')
 End;
 if IsFunc and not HadResultSpec and not WasForward Then
  CPFailCode(123,'type de resultat absent dans la declaration de fonction');
 While(CPToken<>';')and(CPToken<>'EOF')do CPNext;
 if CPToken=';'Then CPNext;
 if CPIs('EXTERNAL')or CPIs('SEPARATE')Then Begin
  if CPIs('EXTERNAL')and(Parent<>Nil)Then
   CPFailCode(183,'declaration EXTERNAL dans une routine imbriquee');
  R^.IsExternal:=CPIs('EXTERNAL');R^.IsSeparate:=CPIs('SEPARATE');R^.IsDefined:=True;
  CPNext;
  if CPToken='NUM'Then Begin
   R^.ExternalSegment:=CPNumber;CPNext;
   if CPToken=','Then Begin
    CPNext;if CPToken='NUM'Then Begin
     R^.ExternalProcedure:=CPNumber;CPNext
    End
   End
  End;
  if CPToken=';'Then CPNext;R^.EndPosition:=CPTokenPos;Exit
 End;
 if CPIs('FORWARD')Then Begin
 if R^.IsDefined Then CPFailCode(160,'declaration precedente non FORWARD: '+Name);
 if WasForward Then CPFailCode(161,'nouvelle declaration FORWARD: '+Name);
  R^.IsForward:=True;CPNext;if CPToken=';'Then CPNext;R^.EndPosition:=CPTokenPos;Exit
 End;
 if R^.IsDefined Then Begin
 CPFailCode(160,'declaration precedente non FORWARD: '+Name);Exit
 End;
 R^.IsDefined:=True;R^.IsForward:=False;R^.SourcePosition:=CPTokenPos;
 Old:=CPCurrentRoutine;CPCurrentRoutine:=R;
 { Les declarations imbriquees precedent le BEGIN du corps. }
 While(CPToken<>'EOF')and not CPIs('BEGIN')do Begin
  if CPIs('UNIT')Then CPFailCode(182,'unite imbriquee interdite');
  if CPIs('USES')Then CPFailCode(189,'USES interdit dans une routine');
  if CPIs('CONST')Then CPParseConstSection else
  if CPIs('TYPE')Then CPParseTypeSection else
  if CPIs('PROCEDURE')or CPIs('FUNCTION')Then CPScanRoutine(R)else CPNext
 End;
 if CPIs('BEGIN')Then Begin
  Depth:=1;CPNext;
  While(Depth>0)and(CPToken<>'EOF')do Begin
   if CPIs('BEGIN')Then Inc(Depth)else if CPIs('END')Then Dec(Depth);
   CPNext
  End;
  if CPToken=';'Then CPNext
 End else CPFail('BEGIN de routine attendu: '+Name);
 R^.EndPosition:=CPTokenPos;
 CPCurrentRoutine:=Old
End;

Procedure CPDeclarationPass;
Var
 R:PPasRoutine;
Begin
 CPPass:=1;CPCurrentRoutine:=Nil;CPPos:=0;CPLine:=1;CPNext;
 if not CPIs('PROGRAM')and not CPIs('UNIT')Then Begin
  CPFailCode(405,'''PROGRAM'' ou ''UNIT'' attendu');Exit
 End;
 if CPIs('UNIT')Then Begin
  CPFailCode(398,'compilation autonome des UNIT non implementee');Exit
 End;
 While(CPToken<>'EOF')do Begin
  CPError:=False;
  if CPIs('CONST')Then CPParseConstSection else
  if CPIs('TYPE')Then CPParseTypeSection else
  if CPIs('PROCEDURE')or CPIs('FUNCTION')Then CPScanRoutine(Nil)else CPNext;
  if CPError Then Begin
   While(CPToken<>'EOF')and(CPToken<>';')and not CPIs('CONST')and not CPIs('TYPE')and
   not CPIs('VAR')and not CPIs('PROCEDURE')and not CPIs('FUNCTION')and not CPIs('BEGIN')
   do CPNext;
   if CPToken=';'Then CPNext
  End
 End;
 R:=CPRoutines;
 While R<>Nil do Begin
  if R^.IsForward and not R^.IsDefined Then
   CPFailCode(117,'reference FORWARD non satisfaite: '+R^.Name);
  R:=R^.Next
 End;CPError:=CPHadErrors
End;

Procedure CPOp(OpcodeII,OpcodeIV:Byte);Begin
 if CurrentTarget=ptUCSDPSystemIV Then CPE(OpcodeIV)else CPE(OpcodeII)
End;

Procedure CPBig(V:LongInt);Begin
 if V<128 Then CPE(V)else
 Begin
  CPE($80 or(V shr 8));CPE(V)
 End
End;

Procedure CPConst(V:LongInt);Begin
 if(V>=0)and(V<128)and(CurrentTarget<>ptUCSDPSystemIV)Then CPE(V)
 else if(V>=0)and(V<32)Then CPE(V)else
 Begin
  CPOp(199,$81);CPE(V);CPE(V shr 8)
 End
End;

Procedure CPRealConst(V:Real);
Var
 B:TSingleBits;
Begin
 B.S:=V;if CurrentTarget=ptUCSDPSystemIV Then CPE($BC)else CPE(212);
 CPE(Byte(B.L));CPE(Byte(B.L shr 8));CPE(Byte(B.L shr 16));CPE(Byte(B.L shr 24))
End;

Procedure CPEmitCSP(N:Byte);Begin
 CPOp(158,$AC);CPE(N)
End;

Procedure CPEmitIOCSP(N:Byte);Begin
 CPConst(Ord(CPIOChecks));CPEmitCSP(0);CPEmitCSP(N)
End;

Procedure CPEmitRoutineCall(R:PPasRoutine);
Var
 Delta:Integer;
 Q:PPasRelocation;
Begin
 if R=Nil Then Begin
  CPFail('routine inconnue');Exit
 End;
 if R^.IsExternal or R^.IsSeparate Then Begin
  New(Q);FillChar(Q^,SizeOf(TPasRelocation),0);Q^.Name:=R^.Name;
  Q^.Owner:=CPCurrentRoutine;Q^.CodePosition:=CPCodePos+1;Q^.FinalPosition:=-1;
  Q^.Next:=CPRelocations;CPRelocations:=Q;
  if CurrentTarget=ptUCSDPSystemIV Then Begin
   CPE($93);CPE(R^.ExternalSegment);CPE(R^.ExternalProcedure)
  End
  else
  Begin
   CPE(205);CPE(R^.ExternalSegment);CPE(R^.ExternalProcedure)
  End;
  Exit
 End;
 if CurrentTarget=ptUCSDPSystemIV Then Begin
  if(CPCurrentRoutine=Nil)or(R^.Parent=CPCurrentRoutine)Then Begin
   CPE($90);CPE(R^.ProcNumber)                         { CLP }
  End else if R^.Parent=Nil Then Begin
   CPE($91);CPE(R^.ProcNumber)                         { CGP }
  End else
  Begin
   Delta:=CPCurrentRoutine^.LexicalLevel-R^.Parent^.LexicalLevel;
   if Delta<0 Then Delta:=0;CPE($92);CPE(Delta);CPE(R^.ProcNumber) { CIP }
  End
 End else
 Begin
  { Table II.0/II.1: CLP=$CE, CGP=$CF et CIP=$AE. }
  if R^.Parent=Nil Then Begin
   CPE(207);CPE(R^.ProcNumber)
  End
  else if(CPCurrentRoutine<>Nil)and(R^.Parent=CPCurrentRoutine)Then Begin
   CPE(206);CPE(R^.ProcNumber)
  End
  else
  Begin
   if CPCurrentRoutine=Nil Then Delta:=0 else
   Delta:=CPCurrentRoutine^.LexicalLevel-R^.Parent^.LexicalLevel;
   if Delta<0 Then Delta:=0;CPE(174);CPE(Delta);CPE(R^.ProcNumber)
  End
 End
End;

Procedure CPEmitRoutineReturn(R:PPasRoutine);Begin
 if CurrentTarget=ptUCSDPSystemIV Then Begin
  CPE($96);CPBig(R^.ParameterWords)
 End
 else
 Begin
  CPE(173);CPE(R^.ParameterWords)
 End
End;
Procedure CPExpression;Forward;
Procedure CPDesignator(P:PPasSymbol;LoadValue:Boolean;Var T:PPasType);Forward;

Procedure CPEmitActualParameters(R:PPasRoutine);
Var
A:PPasParameter;
S:PPasSymbol;
T:PPasType;
Begin
 if R^.IsFunction Then CPConst(0); { cellule resultat conservee par RPU/RNP }
 A:=R^.Parameters;
 if A<>Nil Then CPNeed('(')else if CPToken='('Then Begin
  CPNext;CPNeed(')');Exit
 End;
 While(A<>Nil)and not CPError do Begin
  if CPToken=')'Then Begin CPFailCode(126,'nombre de parametres incorrect');Break End;
  if A^.ByReference or A^.Structured Then Begin
 if CPToken<>'ID'Then CPFailCode(154,'variable attendue pour parametre VAR')else
   Begin
    S:=CPFind(CPText);if(S=Nil)or S^.IsConst Then
 CPFailCode(154,'le parametre actuel doit etre une variable')
    else
    Begin
     if not CPTypeEquivalent(A^.ParamType,S^.SymbolType)Then
      CPFailCode(127,'substitution de parametre incompatible');
     CPDesignator(S,False,T);
     if A^.Structured and not A^.ByReference Then Begin
      CPConst(A^.ParamType^.SizeWords);CPEmitCSP(105)
     End
    End;CPNext
   End
  End else
  Begin
   CPExpression;
   if not CPAssignmentCompatible(A^.ParamType,CPLastExpressionType)Then
    CPFailCode(127,'substitution de parametre incompatible')
  End;
  A:=A^.Next;
  if A<>Nil Then Begin
   if CPToken<>','Then CPFailCode(126,'nombre de parametres incorrect')else CPNext
  End else if CPToken=','Then CPFailCode(126,'trop de parametres effectifs')
 End;
 if R^.Parameters<>Nil Then CPNeed(')')
End;

Procedure CPLoadSymbol(P:PPasSymbol);
Var
 D:Integer;
Begin
 if(CPCurrentRoutine<>Nil)and(P^.Scope=CPCurrentRoutine)and(CurrentTarget=ptUCSDPSystemIV)
 and
 (P^.Address>=1)and(P^.Address<=16)Then CPE($20+P^.Address-1)
 else if P^.Scope=Nil Then Begin
  CPOp(169,$85);CPBig(P^.Address)
 End
 else if P^.Scope=CPCurrentRoutine Then Begin
  CPOp(202,$87);CPBig(P^.Address)
 End
 else
 Begin
  D:=CPCurrentRoutine^.LexicalLevel-P^.LexicalLevel;
  CPOp(182,$89);CPE(D);CPBig(P^.Address)
 End;
 if P^.ByReference Then Begin
  CPOp(163,$E6);CPBig(0)
 End
End;

Procedure CPStoreSymbol(P:PPasSymbol);
Var
 D:Integer;
Begin
 if(CPCurrentRoutine<>Nil)and(P^.Scope=CPCurrentRoutine)and(CurrentTarget=ptUCSDPSystemIV)
 and
 (P^.Address>=1)and(P^.Address<=8)Then CPE($68+P^.Address-1)
 else if P^.Scope=Nil Then Begin
  CPOp(171,$A5);CPBig(P^.Address)
 End
 else if P^.Scope=CPCurrentRoutine Then Begin
  CPOp(204,$A4);CPBig(P^.Address)
 End
 else
 Begin
  D:=CPCurrentRoutine^.LexicalLevel-P^.LexicalLevel;
  CPOp(184,$A6);CPE(D);CPBig(P^.Address)
 End
End;

Function CPAllocateTemp:PPasSymbol;
Var
 S:String;
Begin
 Inc(CPTempNumber);Str(CPTempNumber,S);S:='$TEMP'+S;
 if CPCurrentRoutine=Nil Then Begin
  Inc(CPVarCount);CPAddTyped(S,CPVarCount,False,CPFindType('INTEGER'))
 End
 else
 Begin
  Inc(CPCurrentRoutine^.LocalWords);
  CPAddTyped(S,CPCurrentRoutine^.LocalWords,False,CPFindType('INTEGER'))
 End;CPAllocateTemp:=CPFind(S)
End;

Function CPFindField(T:PPasType;S:String):PPasField;
Var
 F:PPasField;
Begin
 While(T<>Nil)and(T^.Kind=ptkAlias)do T:=T^.ElementType;
 if(T=Nil)or not(T^.Kind in[ptkRecord,ptkVariantRecord])Then Begin
  CPFindField:=Nil;Exit
 End;
 F:=T^.Fields;
 While(F<>Nil)and(F^.Name<>S)do F:=F^.Next;CPFindField:=F
End;

Procedure CPAddressSymbol(P:PPasSymbol);
Var
 D:Integer;
Begin
 if P^.BaseSymbol<>Nil Then Begin
  CPAddressSymbol(P^.BaseSymbol);
  if P^.FieldOffset<>0 Then Begin
   CPOp(162,$E7);CPBig(P^.FieldOffset)
  End;Exit
 End;
 if P^.ByReference Then Begin
  P^.ByReference:=False;CPLoadSymbol(P);P^.ByReference:=True;Exit
 End;
 if(CPCurrentRoutine<>Nil)and(P^.Scope=CPCurrentRoutine)and(CurrentTarget=ptUCSDPSystemIV)
 and
 (P^.Address>=1)and(P^.Address<=16)Then CPE($60+P^.Address-1)
 else if P^.Scope=Nil Then Begin
  CPOp(165,$86);CPBig(P^.Address)
 End
 else if P^.Scope=CPCurrentRoutine Then Begin
  CPOp(198,$84);CPBig(P^.Address)
 End
 else
 Begin
  D:=CPCurrentRoutine^.LexicalLevel-P^.LexicalLevel;
  CPOp(181,$88);CPE(D);CPBig(P^.Address)
 End
End;

Procedure CPDesignator(P:PPasSymbol;LoadValue:Boolean;Var T:PPasType);
Var
 F:PPasField;
 Idx:PPasType;
Begin
 T:=P^.SymbolType;if T=Nil Then T:=CPFindType('INTEGER');CPAddressSymbol(P);
 While not CPError do Begin
  While(T<>Nil)and(T^.Kind=ptkAlias)do T:=T^.ElementType;
  if CPToken='['Then Begin
   if(T<>Nil)and(T^.Kind=ptkString)Then Begin
    CPNext;CPExpression;
    if(CPBaseType(CPLastExpressionType)=Nil)or
     (CPBaseType(CPLastExpressionType)^.Kind<>ptkInteger)Then
     CPFailCode(149,'l''index d''une chaine doit etre entier');
    if CPRangeChecks Then Begin
     CPConst(1);CPConst(T^.HighBound);CPOp(136,$CB)
    End;
    CPOp(164,$D7);CPBig(1);T:=CPFindType('CHAR');CPNeed(']');Continue
   End;
   if(T=Nil)or(T^.Kind<>ptkArray)Then Begin
    CPFailCode(138,'le type de la variable n''est pas un tableau');Exit
   End;
   CPNext;Repeat
   Idx:=T^.IndexType;CPExpression;
   if not CPAssignmentCompatible(Idx,CPLastExpressionType)Then
    CPFailCode(139,'type d''index incompatible avec la declaration');
   if CPRangeChecks Then Begin
    CPConst(Idx^.LowBound);CPConst(Idx^.HighBound);CPOp(136,$CB)
   End;
   if Idx^.LowBound<>0 Then Begin
    CPConst(Idx^.LowBound);CPOp(149,$A3)
   End;
   CPOp(164,$D7);CPBig(T^.ElementType^.SizeWords);T:=T^.ElementType;
   if CPToken=','Then Begin
    CPNext;
    While(T<>Nil)and(T^.Kind=ptkAlias)do T:=T^.ElementType;
    if(T=Nil)or(T^.Kind<>ptkArray)Then Begin
     CPFail('trop d''indices');Break
    End
   End else Break
   Until False;CPNeed(']')
  End else if CPToken='.'Then Begin
   if(T=Nil)or not(T^.Kind in[ptkRecord,ptkVariantRecord])Then Begin
    CPFailCode(140,'le type de la variable n''est pas un enregistrement');Exit
   End;
   CPNext;if CPToken<>'ID'Then Begin
    CPFail('nom de champ attendu');Exit
   End;
   F:=CPFindField(T,CPText);if F=Nil Then Begin
 CPFailCode(152,'champ inconnu: '+CPText);Exit
   End;
   if F^.OffsetWords<>0 Then Begin
    CPOp(162,$E7);CPBig(F^.OffsetWords)
   End;
   T:=F^.FieldType;CPNext
  End else if CPToken='^'Then Begin
   if(T<>Nil)and(T^.Kind=ptkFile)Then Begin
    CPEmitCSP(73);T:=T^.ElementType;CPNext
   End
   else
   Begin
    if(T=Nil)or(T^.Kind<>ptkPointer)Then Begin
     CPFailCode(141,'le type de la variable doit etre fichier ou pointeur');Exit
    End;
    CPOp(163,$E6);CPBig(0);T:=T^.ElementType;CPNext
   End
  End else Break
 End;
 if LoadValue Then Begin
  While(T<>Nil)and(T^.Kind=ptkAlias)do T:=T^.ElementType;
  if(T<>Nil)and(T^.Kind=ptkString)Then Begin
  End
  else if(T<>Nil)and(T^.SizeWords>1)Then Begin
   { Les valeurs structurees circulent par adresse dans l'ABI privee. }
  End
  else
  Begin
   CPOp(163,$E6);CPBig(0)
  End
 End
End;

Procedure CPFactor;
Var
 P:PPasSymbol;
 R:PPasRoutine;
 T,CastType,SourceType,LeftType:PPasType;
 Ident:String;
 Flags:Integer;
 Neg:Boolean;
 CV,CV2:TConstValue;
 Lo,Hi,K:LongInt;
 SetLow,SetHigh:Array[1..64]of LongInt;
 SetCount,I:Integer;
Begin
 CPLastExpressionType:=CPFindType('INTEGER');Neg:=False;
 if CPIs('NOT')Then Begin
  CPNext;CPFactor;
  if(CPBaseType(CPLastExpressionType)=Nil)or
   (CPBaseType(CPLastExpressionType)^.Kind<>ptkBoolean)Then
   CPFailCode(135,'l''operande de NOT doit etre Boolean');
  CPOp(147,$E5);CPLastExpressionType:=CPFindType('BOOLEAN');Exit
 End;
 if CPToken='-'Then Begin
  Neg:=True;CPNext
 End;
 if CPToken='NUM'Then Begin
  CPConst(CPNumber);CPNext
 End
 else if CPToken='CTRL'Then Begin
  CPConst(CPNumber);CPLastExpressionType:=CPFindType('CHAR');CPNext
 End
 else if CPToken='REALNUM'Then Begin
  CPRealConst(CPRealNumber);CPLastExpressionType:=CPFindType('REAL');CPNext
 End
 else if CPToken='STR'Then Begin
  if Length(CPText)=1 Then Begin
   CPConst(Ord(CPText[1]));CPLastExpressionType:=CPFindType('CHAR')
  End
  else
  Begin
   CPE(166);CPE(Length(CPText));
   For K:=1 to Length(CPText)do CPE(Ord(CPText[K]));
   CPLastExpressionType:=CPFindType('STRING')
  End;CPNext
 End
 else if CPToken='('Then Begin
  CPNext;CPExpression;CPNeed(')')
 End
 else if CPToken='['Then Begin
  CPNext;SetCount:=0;
  While(CPToken<>']')and(CPToken<>'EOF')and not CPError do Begin
   CV:=CPEvalConstExpression;CV2:=CV;if CV.Kind in[ckReal,ckString]Then Begin
    CPFailCode(136,'le type d''element d''ensemble doit etre scalaire ou sous-intervalle');Break
   End;
   Lo:=CV.I;Hi:=Lo;if CPToken='..'Then Begin
    CPNext;CV:=CPEvalConstExpression;Hi:=CV.I;
    if(CV.Kind=ckCharacter)<>(CV2.Kind=ckCharacter)Then
     CPFailCode(137,'types d''elements d''ensemble incompatibles')
   End;
   if(Lo<0)or(Hi>255)or(Lo>Hi)Then CPFailCode(304,'element d''ensemble hors de 0..255')
   else if SetCount=64 Then CPFailCode(193,'constante ensemble trop complexe')
   else Begin Inc(SetCount);SetLow[SetCount]:=Lo;SetHigh[SetCount]:=Hi End;
   if CPToken=','Then CPNext else Break
  End;CPNeed(']');
  For I:=1 to SetCount do Begin CPConst(SetLow[I]);CPConst(SetHigh[I]) End;
  CPConst(SetCount);CPEmitCSP(100);CPLastExpressionType:=CPNewAnonymousType(ptkSet);
  CPLastExpressionType^.ElementType:=CPFindType('INTEGER');
  CPLastExpressionType^.SizeWords:=16
 End
 else if CPIs('ABS')or CPIs('SQR')or CPIs('ODD')or CPIs('SUCC')or CPIs('PRED')or
 CPIs('ORD')or CPIs('CHR')or CPIs('ROUND')or CPIs('TRUNC')or CPIs('SIN')or
 CPIs('COS')or CPIs('ARCTAN')or CPIs('EXP')or CPIs('LN')or CPIs('SQRT')Then Begin
  Ident:=CPText;CPNext;CPNeed('(');CPExpression;
  SourceType:=CPBaseType(CPLastExpressionType);CPNeed(')');
  if Ident='ABS'Then Begin
   if(SourceType<>Nil)and(SourceType^.Kind=ptkReal)Then CPOp(129,$D8)
   else CPOp(128,$E0)
  End else if Ident='SQR'Then Begin
   if(SourceType<>Nil)and(SourceType^.Kind=ptkReal)Then CPOp(153,$D9)
   else CPOp(152,$DA)
  End else if Ident='ODD'Then Begin
   CPConst(2);CPOp(142,$8F);CPConst(1);CPOp(195,$B0);
   CPLastExpressionType:=CPFindType('BOOLEAN')
  End else if Ident='SUCC'Then Begin
   CPConst(1);CPOp(130,$A2)
  End
  else if Ident='PRED'Then Begin
   CPConst(1);CPOp(149,$A3)
  End
  else if Ident='ORD'Then CPLastExpressionType:=CPFindType('INTEGER')
  else if Ident='CHR'Then CPLastExpressionType:=CPFindType('CHAR')
  else if Ident='ROUND'Then Begin
   CPEmitCSP(19);CPLastExpressionType:=CPFindType('INTEGER')
  End
  else if Ident='TRUNC'Then Begin
   CPEmitCSP(18);CPLastExpressionType:=CPFindType('INTEGER')
  End
  else
  Begin
   if(SourceType=Nil)or(SourceType^.Kind<>ptkReal)Then
    CPFailCode(125,'type incorrect du parametre de '+Ident);
   if Ident='SIN'Then Flags:=20 else if Ident='COS'Then Flags:=21 else if Ident=
   'ARCTAN'Then Flags:=23
   else if Ident='EXP'Then Flags:=25 else if Ident='LN'Then Flags:=24 else Flags:=26;
   CPEmitCSP(Flags);CPLastExpressionType:=CPFindType('REAL')
  End
 End
 else if CPIs('IORESULT')Then Begin
  CPNext;if CPToken='('Then Begin
   CPNext;CPNeed(')')
  End;
  CPEmitCSP(37);CPLastExpressionType:=CPFindType('INTEGER')
 End
 else if CPIs('EOF')or CPIs('EOLN')Then Begin
  Ident:=CPText;CPNext;
  if CPToken='('Then Begin
   CPNext;
   if CPToken<>'ID'Then CPFail('fichier attendu')else
   Begin
    P:=CPFind(CPText);
    if(P=Nil)or(CPBaseType(P^.SymbolType)=Nil)or(CPBaseType(P^.SymbolType)^.Kind<>ptkFile)
    Then     CPFail('variable fichier attendue')else CPAddressSymbol(P);CPNext
   End;CPNeed(')')
  End else CPConst(0);
  if Ident='EOF'Then CPEmitIOCSP(64)else CPEmitIOCSP(65);
  CPLastExpressionType:=CPFindType('BOOLEAN')
 End
 else if CPIs('LENGTH')Then Begin
  CPNext;CPNeed('(');CPExpression;CPNeed(')');CPEmitCSP(40);
  CPLastExpressionType:=CPFindType('INTEGER')
 End
 else if CPIs('CONCAT')Then Begin
  CPNext;CPNeed('(');CPExpression;LeftType:=CPLastExpressionType;CPNeed(',');CPExpression;
  Flags:=0;if(LeftType<>Nil)and(LeftType^.Kind=ptkChar)Then Flags:=1;
  if(CPLastExpressionType<>Nil)and(CPLastExpressionType^.Kind=ptkChar)Then Inc(Flags,2);
  CPConst(Flags);CPEmitCSP(51);
  While CPToken=','do Begin
   CPNext;CPExpression;Flags:=0;
   if(CPLastExpressionType<>Nil)and(CPLastExpressionType^.Kind=ptkChar)Then Flags:=2;
   CPConst(Flags);CPEmitCSP(51)
  End;
  CPNeed(')');CPLastExpressionType:=CPFindType('STRING')
 End
 else if CPIs('COPY')Then Begin
  CPNext;CPNeed('(');CPExpression;CPNeed(',');CPExpression;CPNeed(',');CPExpression;
  CPNeed(')');CPEmitCSP(43);CPLastExpressionType:=CPFindType('STRING')
 End
 else if CPIs('POS')Then Begin
  CPNext;CPNeed('(');CPExpression;CPNeed(',');CPExpression;CPNeed(')');
  { La VM attend chaine puis sous-chaine. }
  CPEmitCSP(44);CPLastExpressionType:=CPFindType('INTEGER')
 End
 else if CPIs('TRUE')Then Begin
  CPConst(1);CPLastExpressionType:=CPFindType('BOOLEAN');CPNext
 End else if CPIs('FALSE')Then Begin
  CPConst(0);CPLastExpressionType:=CPFindType('BOOLEAN');CPNext
 End
 else if CPToken='ID'Then Begin
  Ident:=CPText;P:=CPFind(Ident);R:=CPVisibleRoutine(Ident);CastType:=CPFindType(Ident);
  CPNext;
  if(CastType<>Nil)and(CPToken='(')Then Begin
   CPNext;CPExpression;SourceType:=CPLastExpressionType;CPNeed(')');
   While(CastType^.Kind=ptkAlias)do CastType:=CastType^.ElementType;
   While(SourceType<>Nil)and(SourceType^.Kind=ptkAlias)do SourceType:=
   SourceType^.ElementType;
   if(CastType^.Kind=ptkReal)and(SourceType<>Nil)and(SourceType^.Kind<>ptkReal)Then CPOp(
   137,$BE)
   else if(CastType^.Kind<>ptkReal)and(SourceType<>Nil)and(SourceType^.Kind=ptkReal)
   Then CPOp(138,$BF);
   CPLastExpressionType:=CastType
  End else if(R<>Nil)and R^.IsFunction and((CPToken='(')or(R^.Parameters=Nil))Then Begin
   CPEmitActualParameters(R);CPEmitRoutineCall(R);CPLastExpressionType:=R^.ResultType
 End else if P=Nil Then CPFailCode(104,'identificateur non declare: '+Ident)
  else if P^.IsConst Then Begin
   if P^.IsRealConst Then Begin
    CPRealConst(P^.ConstReal);CPLastExpressionType:=CPFindType('REAL')
   End
   else if P^.IsStringConst Then Begin
    CPE(166);CPE(Length(P^.ConstText));
    For K:=1 to Length(P^.ConstText)do CPE(Ord(P^.ConstText[K]));
    CPLastExpressionType:=CPFindType('STRING')
   End else
   Begin
    CPConst(P^.Value);CPLastExpressionType:=P^.SymbolType
   End
  End else
  Begin
   CPDesignator(P,True,T);CPLastExpressionType:=T
  End
 End else
 Begin
  CPFailCode(58,'erreur dans le facteur (expression incorrecte)');CPNext
 End;if Neg Then Begin
  if(CPLastExpressionType<>Nil)and(CPLastExpressionType^.Kind=ptkReal)Then CPOp(146,$CD)
  else CPOp(145,$E1)
 End
End;

Procedure CPTerm;
Var
 O:String;
 LT,RT:PPasType;
Begin
 CPFactor;LT:=CPLastExpressionType;
 While(CPToken='*')or(CPToken='/')or CPIs('DIV')or CPIs('MOD')or CPIs('AND')or
 CPIs('SHL')or CPIs('SHR')do Begin
  O:=CPToken;if CPToken='ID'Then O:=CPText;CPNext;CPFactor;RT:=CPLastExpressionType;
  if(O='SHL')or(O='SHR')Then Begin
   if(O='SHL')Then CPOp(210,$BA)else CPOp(211,$BB);LT:=CPFindType('INTEGER')
  End else if(O='*')and(((LT<>Nil)and(LT^.Kind=ptkSet))or((RT<>Nil)and(RT^.Kind=ptkSet)))
  Then Begin
   if(LT=Nil)or(RT=Nil)or(LT^.Kind<>ptkSet)or(RT^.Kind<>ptkSet)Then
    CPFailCode(134,'type illegal des operandes')
   else if not(CPAssignmentCompatible(LT^.ElementType,RT^.ElementType)or
    CPAssignmentCompatible(RT^.ElementType,LT^.ElementType))Then
    CPFailCode(137,'types d''elements d''ensembles incompatibles');
   CPConst(2);CPEmitCSP(101)
  End
  else if((LT<>Nil)and(LT^.Kind=ptkReal))or((RT<>Nil)and(RT^.Kind=ptkReal))Then Begin
   if(LT=Nil)or(RT=Nil)or(LT^.Kind<>ptkReal)or(RT^.Kind<>ptkReal)Then    CPFail(
   'conversion explicite requise pour une operation reelle')
   else if O='*'Then CPOp(144,$CA)else if O='/'Then CPOp(135,$CC)
   else CPFail('DIV, MOD et AND interdits sur les reels');LT:=CPFindType('REAL')
  End else if O='*'Then CPOp(143,$8C)else if(O='/')or(O='DIV')Then CPOp(134,$8D)
  else if O='MOD'Then CPOp(142,$8F)else Begin
   if(CPBaseType(LT)=Nil)or(CPBaseType(RT)=Nil)or
    (CPBaseType(LT)^.Kind<>ptkBoolean)or(CPBaseType(RT)^.Kind<>ptkBoolean)Then
    CPFailCode(135,'les operandes de AND doivent etre Boolean');CPOp(132,$A1)
  End
  ;if(O<>'SHL')and(O<>'SHR')and not((LT<>Nil)and(LT^.Kind=ptkReal))Then LT:=RT
 End;CPLastExpressionType:=LT
End;

Procedure CPSimple;
Var
 O:String;
 LT,RT:PPasType;
 I:Integer;
Begin
 CPTerm;LT:=CPLastExpressionType;
 While(CPToken='+')or(CPToken='-')or CPIs('OR')do Begin
  O:=CPToken;
  if CPToken='ID'Then O:=CPText;CPNext;CPTerm;RT:=CPLastExpressionType;
  if((LT<>Nil)and(LT^.Kind in[ptkString,ptkChar]))and
  ((RT<>Nil)and(RT^.Kind in[ptkString,ptkChar]))and
  ((LT^.Kind=ptkString)or(RT^.Kind=ptkString))Then Begin
   if O<>'+'Then CPFail('operateur de chaine invalide')else
   Begin
    I:=0;if LT^.Kind=ptkChar Then I:=1;if RT^.Kind=ptkChar Then Inc(I,2);
    CPConst(I);CPEmitCSP(51)
   End;LT:=CPFindType('STRING')
  End else if((LT<>Nil)and(LT^.Kind=ptkSet))or((RT<>Nil)and(RT^.Kind=ptkSet))Then Begin
   if(LT=Nil)or(RT=Nil)or(LT^.Kind<>ptkSet)or(RT^.Kind<>ptkSet)Then
    CPFailCode(134,'type illegal des operandes')
   else if not(CPAssignmentCompatible(LT^.ElementType,RT^.ElementType)or
    CPAssignmentCompatible(RT^.ElementType,LT^.ElementType))Then
    CPFailCode(137,'types d''elements d''ensembles incompatibles');
   if O='-'Then CPConst(1)else CPConst(0);CPEmitCSP(101)
  End else if((LT<>Nil)and(LT^.Kind=ptkReal))or((RT<>Nil)and(RT^.Kind=ptkReal))Then Begin
   if(LT=Nil)or(RT=Nil)or(LT^.Kind<>ptkReal)or(RT^.Kind<>ptkReal)Then    CPFail(
   'conversion explicite requise pour une operation reelle')
   else if O='+'Then CPOp(131,$C8)else if O='-'Then CPOp(150,$C9)
   else CPFail('OR interdit sur les reels');LT:=CPFindType('REAL')
  End else if O='+'Then CPOp(130,$A2)else if O='-'Then CPOp(149,$A3)else Begin
   if(CPBaseType(LT)=Nil)or(CPBaseType(RT)=Nil)or
    (CPBaseType(LT)^.Kind<>ptkBoolean)or(CPBaseType(RT)^.Kind<>ptkBoolean)Then
    CPFailCode(135,'les operandes de OR doivent etre Boolean');CPOp(141,$A0)
  End;
  if(LT=Nil)or(LT^.Kind<>ptkReal)Then LT:=RT
 End;CPLastExpressionType:=LT
End;

Procedure CPExpression;
Var
 O:String;
 LT,RT:PPasType;
 Cmp:Byte;
Begin
 CPSimple;LT:=CPLastExpressionType;if CPIs('IN')Then Begin
  CPNext;CPSimple;
  if(CPLastExpressionType=Nil)or(CPLastExpressionType^.Kind<>ptkSet)Then
   CPFailCode(130,'l''expression apres IN n''est pas un ensemble');
  CPEmitCSP(102);CPLastExpressionType:=CPFindType('BOOLEAN');Exit
 End;
 if(CPToken='=')or(CPToken='<>')or(CPToken='<')or(CPToken='<=')or
 (CPToken='>')or(CPToken='>=')Then Begin
 O:=CPToken;CPNext;CPSimple;RT:=CPLastExpressionType;
  if(LT<>Nil)and(RT<>Nil)and((LT^.Kind=ptkSet)or(RT^.Kind=ptkSet))Then Begin
   if(LT^.Kind<>ptkSet)or(RT^.Kind<>ptkSet)Then
    CPFailCode(129,'conflit de types des operandes')
   else if(O<>'=')and(O<>'<>')Then
    CPFailCode(131,'seuls les tests d''egalite sont autorises sur les ensembles');
   if O='='Then CPConst(0)else CPConst(1);CPEmitCSP(103)
  End else if(LT<>Nil)and(RT<>Nil)and(LT^.SizeWords>1)Then Begin
   if not CPTypeEquivalent(LT,RT)Then CPFailCode(129,'types structures incompatibles')
   else if(O<>'=')and(O<>'<>')Then
    CPFailCode(131,'seuls les tests d''egalite sont autorises sur les structures');
   CPConst(LT^.SizeWords);if O='='Then CPConst(0)else CPConst(1);CPEmitCSP(104)
  End else if(LT<>Nil)and(RT<>Nil)and((LT^.Kind=ptkString)or(RT^.Kind=ptkString))Then Begin
   if(LT^.Kind<>ptkString)or(RT^.Kind<>ptkString)Then
    CPFailCode(129,'conflit de types des operandes chaine');
   CPEmitCSP(42);CPConst(0);
   if O='='Then CPOp(195,$B0)else if O='<>'Then CPOp(203,$B1)
   else if O='<'Then Begin
    CPOp(196,$B3);CPOp(147,$9F)
   End else if O='<='Then CPOp(200,$B2)
   else if O='>'Then Begin
    CPOp(200,$B2);CPOp(147,$9F)
   End else CPOp(196,$B3)
  End
  else if(LT<>Nil)and(RT<>Nil)and((LT^.Kind=ptkReal)or(RT^.Kind=ptkReal))Then Begin
   if(LT^.Kind<>ptkReal)or(RT^.Kind<>ptkReal)Then CPFail(
   'conversion reelle explicite requise');
   if O='='Then Cmp:=0 else if O='<>'Then Cmp:=1 else if O='<'Then Cmp:=2
   else if O='<='Then Cmp:=3 else if O='>'Then Cmp:=4 else Cmp:=5;
   if CurrentTarget=ptUCSDPSystemIV Then Begin
    CPE($CE);CPE(Cmp)
   End
   else
   Begin
    CPE(213);CPE(Cmp)
   End
  End else if O='='Then CPOp(195,$B0)else if O='<>'Then CPOp(203,$B1)
  else if O='<'Then Begin
   CPOp(196,$B3);CPOp(147,$9F)
  End
  else if O='<='Then CPOp(200,$B2)
  else if O='>'Then Begin
   CPOp(200,$B2);CPOp(147,$9F)
  End
  else CPOp(196,$B3);CPLastExpressionType:=CPFindType('BOOLEAN')
 End
End;
Procedure CPStatement;Forward;

Procedure CPCompound;Begin
 if not CPIs('BEGIN')Then Begin
  CPFail('BEGIN attendu');Exit
 End;CPNext;
 While not CPIs('END')and(CPToken<>'EOF')and not CPError do Begin
  CPStatement;
  if CPToken=';'Then CPNext else if CPToken='EOF'Then
   CPFailCode(401,'fin de source avant END')
  else if not CPIs('END')Then CPFail('point-virgule attendu')
 End;
 if CPIs('END')Then CPNext else if(CPToken='EOF')and not CPError Then
  CPFailCode(401,'fin de source avant END')
End;

Procedure CPStatement;
Type
 PCaseRange=^TCaseRange;
 TCaseRange=Record LowValue,HighValue:LongInt;Next:PCaseRange End;
Var
 P,Tmp:PPasSymbol;
 R:PPasRoutine;
 T,RT:PPasType;
 Name:String;
 J,Patch,LoopStart:LongInt;
 Down,More:Boolean;
 CV,CV2:TConstValue;
 EndPatch:Array[1..64]of LongInt;
 EndCount,I:Integer;
 SavedWith:PPasSymbol;
 SavedWithType:PPasType;
 CaseRanges,CaseRange,CaseScan:PCaseRange;
 CaseHigh:LongInt;
Begin
 if CPIs('BEGIN')Then CPCompound
 else if CPIs('GOTO')Then Begin
  CPNext;if CPToken='NUM'Then Begin
   Str(CPNumber,Name);CPNext
  End
  else if CPToken='ID'Then Begin
   Name:=CPText;CPNext
  End
  else
  Begin
   CPFail('etiquette attendue apres GOTO');Exit
  End;
  CPEmitGoto(Name)
 End
 else if CPToken='NUM'Then Begin
  Str(CPNumber,Name);CPNext;CPNeed(':');CPDefineLabel(Name);CPStatement
 End
 else if CPIs('IF')Then Begin
  CPNext;CPExpression;
  if(CPBaseType(CPLastExpressionType)=Nil)or
   (CPBaseType(CPLastExpressionType)^.Kind<>ptkBoolean)Then
   CPFailCode(135,'l''operande de IF doit etre Boolean');
  if not CPIs('THEN')Then CPFail('THEN attendu')else CPNext;
  Patch:=CPForwardFalse;CPStatement;
  if CPIs('ELSE')Then Begin
   J:=CPForwardJump;CPPatchForward(Patch,CPCodePos);
   CPNext;CPStatement;CPPatchForward(J,CPCodePos)
  End else CPPatchForward(Patch,CPCodePos)
 End
 else if CPIs('WHILE')Then Begin
  J:=CPCodePos;CPNext;CPExpression;
  if(CPBaseType(CPLastExpressionType)=Nil)or
   (CPBaseType(CPLastExpressionType)^.Kind<>ptkBoolean)Then
   CPFailCode(135,'l''operande de WHILE doit etre Boolean');
  if not CPIs('DO')Then CPFail('DO attendu')else CPNext;
  Patch:=CPForwardFalse;CPStatement;CPJumpBack(J);CPPatchForward(Patch,CPCodePos)
 End
 else if CPIs('REPEAT')Then Begin
  LoopStart:=CPCodePos;CPNext;
  While not CPIs('UNTIL')and(CPToken<>'EOF')and not CPError do Begin
   CPStatement;
   if CPToken=';'Then CPNext else if not CPIs('UNTIL')Then CPFail('point-virgule attendu')
  End;
  if CPIs('UNTIL')Then CPNext else CPFail('UNTIL attendu');CPExpression;
  if(CPBaseType(CPLastExpressionType)=Nil)or
   (CPBaseType(CPLastExpressionType)^.Kind<>ptkBoolean)Then
   CPFailCode(135,'l''operande de UNTIL doit etre Boolean');
  Patch:=CPForwardFalse;CPPatchForward(Patch,LoopStart)
 End
 else if CPIs('FOR')Then Begin
  CPNext;if CPToken<>'ID'Then Begin
   CPFailCode(59,'erreur dans la variable de controle');Exit
  End;
  P:=CPFind(CPText);if(P=Nil)or P^.IsConst Then Begin
   CPFailCode(103,'identificateur de classe variable attendu');Exit
  End;
  if not CPIsOrdinalType(P^.SymbolType)Then Begin
   CPFailCode(143,'type illegal de variable de controle de boucle');Exit
  End;
  if P^.IsParameter or(P^.Scope<>CPCurrentRoutine)Then Begin
   CPFailCode(155,'variable de controle formelle ou non locale');Exit
  End;
  CPNext;CPNeed(':=');CPExpression;CPStoreSymbol(P);
  Down:=CPIs('DOWNTO');if not Down and not CPIs('TO')Then Begin
   CPFail('TO ou DOWNTO attendu');Exit
  End;
  CPNext;Tmp:=CPAllocateTemp;CPExpression;CPStoreSymbol(Tmp);
  if not CPIs('DO')Then CPFail('DO attendu')else CPNext;LoopStart:=CPCodePos;
  CPLoadSymbol(P);CPLoadSymbol(Tmp);
  if Down Then CPOp(196,$B3)else CPOp(200,$B2);
  Patch:=CPForwardFalse;CPStatement;
  CPLoadSymbol(P);CPConst(1);if Down Then CPOp(149,$A3)else CPOp(130,$A2);
  CPStoreSymbol(P);
  CPJumpBack(LoopStart);CPPatchForward(Patch,CPCodePos)
 End
 else if CPIs('CASE')Then Begin
  CPNext;Tmp:=CPAllocateTemp;CPExpression;T:=CPBaseType(CPLastExpressionType);
  if not CPIsOrdinalType(T)Then CPFailCode(144,'type illegal d''expression CASE');
  CPStoreSymbol(Tmp);
  if not CPIs('OF')Then CPFail('OF attendu')else CPNext;EndCount:=0;
  CaseRanges:=Nil;
  While not CPIs('END')and not CPIs('ELSE')and(CPToken<>'EOF')and not CPError do Begin
   More:=False;
   Repeat
   CV:=CPEvalConstExpression;
   CaseHigh:=CV.I;
   if((T<>Nil)and(T^.Kind=ptkChar)and(CV.Kind<>ckCharacter))or
    ((T<>Nil)and(T^.Kind<>ptkChar)and(CV.Kind=ckCharacter))Then
    CPFailCode(147,'type d''etiquette incompatible avec l''expression CASE');
   CPLoadSymbol(Tmp);CPConst(CV.I);
   if CPToken='..'Then Begin
    CPNext;CV2:=CPEvalConstExpression;
    CaseHigh:=CV2.I;
    CPOp(196,$B3);CPLoadSymbol(Tmp);CPConst(CV2.I);CPOp(200,$B2);CPOp(132,$A1)
   End else CPOp(195,$B0);
   CaseScan:=CaseRanges;
   While CaseScan<>Nil do Begin
    if(CV.I<=CaseScan^.HighValue)and(CaseHigh>=CaseScan^.LowValue)Then
     CPFailCode(156,'etiquette CASE definie plusieurs fois');
    CaseScan:=CaseScan^.Next
   End;
   New(CaseRange);CaseRange^.LowValue:=CV.I;CaseRange^.HighValue:=CaseHigh;
   CaseRange^.Next:=CaseRanges;CaseRanges:=CaseRange;
   if More Then CPOp(141,$A0);More:=True;
   if CPToken=','Then CPNext else Break
   Until False;
   CPNeed(':');Patch:=CPForwardFalse;CPStatement;
   Inc(EndCount);if EndCount>64 Then Begin
    CPFailCode(157,'trop de branches CASE');EndCount:=64;Break
   End;
   EndPatch[EndCount]:=CPForwardJump;CPPatchForward(Patch,CPCodePos);
   if CPToken=';'Then CPNext
  End;
  if CPIs('ELSE')Then Begin
   CPNext;
   While not CPIs('END')and(CPToken<>'EOF')and not CPError do Begin
    CPStatement;if CPToken=';'Then CPNext else Break
   End
  End;
  if CPIs('END')Then CPNext else CPFail('END de CASE attendu');
  For I:=1 to EndCount do CPPatchForward(EndPatch[I],CPCodePos);
  While CaseRanges<>Nil do Begin
   CaseRange:=CaseRanges;CaseRanges:=CaseRange^.Next;Dispose(CaseRange)
  End
 End
 else if CPIs('WITH')Then Begin
  CPNext;if CPToken<>'ID'Then Begin
   CPFail('variable attendue apres WITH');Exit
  End;
  P:=CPFind(CPText);if(P=Nil)or(P^.IsConst)Then Begin
   CPFail('variable WITH invalide');Exit
  End;
  T:=P^.SymbolType;
  While(T<>Nil)and(T^.Kind=ptkAlias)do T:=T^.ElementType;
  if(T=Nil)or not(T^.Kind in[ptkRecord,ptkVariantRecord])Then Begin
   CPFail('WITH exige un enregistrement');Exit
  End;
  SavedWith:=CPWithSymbol;SavedWithType:=CPWithType;CPWithSymbol:=P;CPWithType:=T;CPNext;
  if not CPIs('DO')Then CPFail('DO attendu')else
  Begin
   CPNext;CPStatement
  End;
  CPWithSymbol:=SavedWith;CPWithType:=SavedWithType
 End
 else if CPIs('NEW')or CPIs('DISPOSE')Then Begin
  Name:=CPText;CPNext;CPNeed('(');
  if CPToken<>'ID'Then CPFail('variable pointeur attendue')else
  Begin
   P:=CPFind(CPText);T:=Nil;if P<>Nil Then T:=CPBaseType(P^.SymbolType);
   if(P=Nil)or(T=Nil)or(T^.Kind<>ptkPointer)Then
    CPFailCode(141,'le type de la variable doit etre fichier ou pointeur')
   else
   Begin
    CPAddressSymbol(P);if Name='NEW'Then Begin
     if T^.ElementType=Nil Then CPConst(1)else CPConst(T^.ElementType^.SizeWords);
     CPEmitCSP(1)
    End else
    Begin
     if T^.ElementType=Nil Then CPConst(1)else CPConst(T^.ElementType^.SizeWords);
     CPEmitCSP(81)
    End
   End;CPNext
  End;
  I:=0;
  While CPToken=','do Begin
   Inc(I);CPNext;CPExpression;
   RT:=Nil;if(T<>Nil)and(T^.Kind=ptkPointer)Then RT:=CPBaseType(T^.ElementType);
   if(I>1)or(RT=Nil)or(RT^.Kind<>ptkVariantRecord)or
    (RT^.VariantTagType=Nil)Then CPFailCode(158,'aucune variante correspondante')
   else Begin
    if not CPAssignmentCompatible(RT^.VariantTagType,CPLastExpressionType)Then
     CPFailCode(111,'selecteur incompatible avec le champ de balise');
    CPAddressSymbol(P);CPConst(RT^.VariantTagOffset);CPEmitCSP(106)
   End
  End;CPNeed(')')
 End
 else if CPIs('MOVELEFT')or CPIs('MOVERIGHT')Then Begin
  Name:=CPText;CPNext;CPNeed('(');
  if CPToken<>'ID'Then CPFail('source attendue')else
  Begin
   P:=CPFind(CPText);CPNext;CPDesignator(P,False,T)
  End;
  CPNeed(',');if CPToken<>'ID'Then CPFail('destination attendue')else
  Begin
   P:=CPFind(CPText);CPNext;CPDesignator(P,False,T)
  End;
  CPNeed(',');CPExpression;CPNeed(')');
  if Name='MOVELEFT'Then CPEmitCSP(2)else CPEmitCSP(3)
 End
 else if CPIs('FILLCHAR')Then Begin
  CPNext;CPNeed('(');if CPToken<>'ID'Then CPFail('destination attendue')else
  Begin
   P:=CPFind(CPText);CPNext;CPDesignator(P,False,T)
  End;CPNeed(',');CPExpression;CPNeed(',');CPExpression;CPNeed(')');CPEmitCSP(10)
 End
 else if CPIs('PACK')or CPIs('UNPACK')Then Begin
  Name:=CPText;CPNext;CPNeed('(');
  if CPToken<>'ID'Then CPFail('tableau source attendu')else
  Begin
   P:=CPFind(CPText);CPNext;CPDesignator(P,False,T)
  End;
  CPNeed(',');
  if Name='PACK'Then Begin
   CPExpression;
   T:=CPBaseType(T);if(T<>Nil)and(T^.Kind=ptkArray)Then Begin
    if T^.IndexType^.LowBound<>0 Then Begin
     CPConst(T^.IndexType^.LowBound);CPOp(149,$A3)
    End;
    CPOp(164,$D7);CPBig(T^.ElementType^.SizeWords)
   End;CPNeed(',');if CPToken<>'ID'Then CPFail('tableau tasse attendu')else
   Begin
    P:=CPFind(CPText);RT:=CPBaseType(P^.SymbolType);CPNext;CPDesignator(P,False,T);
    if RT=Nil Then CPConst(1)else CPConst(RT^.SizeWords)
   End
  End else
  Begin
   if CPToken<>'ID'Then CPFail('tableau destination attendu')else
   Begin
    P:=CPFind(CPText);CPNext;CPDesignator(P,False,RT)
   End;
   CPNeed(',');CPExpression;if CPBaseType(RT)<>Nil Then Begin
    CPOp(164,$D7);CPBig(CPBaseType(RT)^.ElementType^.SizeWords)
   End;
   if CPBaseType(T)=Nil Then CPConst(1)else CPConst(CPBaseType(T)^.SizeWords)
  End;CPNeed(')');CPEmitCSP(82)
 End
 else if CPIs('HALT')Then Begin
  CPNext;if CPToken='('Then Begin
   CPNext;CPExpression;CPNeed(')')
  End else CPConst(0);
  if CurrentTarget=ptUCSDPSystemIV Then Begin
   CPE($93);CPE(0);CPE(2)
  End
  else
  Begin
   CPE(205);CPE(0);CPE(2)
  End
 End
 else if CPIs('EXIT')Then Begin
  CPNext;
  if CPCurrentRoutine<>Nil Then CPEmitRoutineReturn(CPCurrentRoutine)
  else if CurrentTarget=ptUCSDPSystemIV Then Begin
   CPE($96);CPBig(0)
  End else CPE(214)
 End
 else if CPIs('ASSIGN')Then Begin
  CPNext;CPNeed('(');if CPToken<>'ID'Then CPFail('variable fichier attendue')else
  Begin
   P:=CPFind(CPText);if(P=Nil)or(CPBaseType(P^.SymbolType)=Nil)or
   (CPBaseType(P^.SymbolType)^.Kind<>ptkFile)Then
    CPFailCode(116,'type incorrect du parametre fichier')
   else CPAddressSymbol(P);CPNext
  End;CPNeed(',');CPExpression;CPNeed(')');CPEmitIOCSP(60)
 End
 else if CPIs('RESET')or CPIs('REWRITE')or CPIs('CLOSE')or CPIs('GET')or CPIs('PUT')
 Then Begin
  Name:=CPText;CPNext;CPNeed('(');
  if CPToken<>'ID'Then CPFail('variable fichier attendue')else
  Begin
   P:=CPFind(CPText);T:=Nil;if P<>Nil Then T:=CPBaseType(P^.SymbolType);
   if(P=Nil)or(T=Nil)or(T^.Kind<>ptkFile)Then
    CPFailCode(116,'type incorrect du parametre fichier')
   else CPAddressSymbol(P);CPNext
  End;CPNeed(')');
  if Name='RESET'Then Begin
   if P=Nil Then CPConst(1)else if CPIsTextType(P^.SymbolType)Then CPConst(-1)
   else Begin T:=CPBaseType(P^.SymbolType);if(T=nil)or(T^.ElementType=nil)Then CPConst(1)
    else CPConst(T^.ElementType^.SizeWords) End;CPEmitIOCSP(61)
  End
  else if Name='REWRITE'Then Begin
   if P=Nil Then CPConst(1)else if CPIsTextType(P^.SymbolType)Then CPConst(-1)
   else Begin T:=CPBaseType(P^.SymbolType);if(T=nil)or(T^.ElementType=nil)Then CPConst(1)
    else CPConst(T^.ElementType^.SizeWords) End;CPEmitIOCSP(62)
  End
  else if Name='CLOSE'Then CPEmitIOCSP(63)else if Name='GET'Then CPEmitIOCSP(71)
  else CPEmitIOCSP(72)
 End
 else if CPIs('READ')or CPIs('READLN')Then Begin
  Name:=CPText;CPNext;P:=Nil;
  if CPToken='('Then Begin
   CPNext;
   if CPToken='ID'Then Begin
    Tmp:=CPFind(CPText);
    if(Tmp<>Nil)and(CPBaseType(Tmp^.SymbolType)<>Nil)and(CPBaseType(Tmp^.SymbolType)
    ^.Kind=ptkFile)Then Begin
     P:=Tmp;CPNext;if CPToken=','Then CPNext
    End
   End;
   While(CPToken<>')')and not CPError do Begin
    if CPToken<>'ID'Then Begin
     CPFailCode(154,'variable attendue par READ');Break
    End;
    Tmp:=CPFind(CPText);if(Tmp=Nil)or Tmp^.IsConst Then Begin
     CPFailCode(153,'type incorrect du parametre de READ');Break
    End;
    T:=CPBaseType(Tmp^.SymbolType);
    if(T=Nil)or not(T^.Kind in[ptkInteger,ptkSubrange,ptkChar,ptkReal,
     ptkBoolean,ptkString])Then Begin
     CPFailCode(153,'type incorrect du parametre de READ');Break
    End;
    if P=Nil Then CPConst(0)else CPAddressSymbol(P);CPAddressSymbol(Tmp);
    T:=CPBaseType(Tmp^.SymbolType);CPNext;
    if(T<>Nil)and(T^.Kind=ptkString)Then Begin
     CPConst(T^.HighBound);CPEmitIOCSP(68)
    End
    else if(T<>Nil)and(T^.Kind=ptkChar)Then CPEmitIOCSP(67)
    else if(T<>Nil)and(T^.Kind=ptkReal)Then CPEmitIOCSP(76)
    else if(T<>Nil)and(T^.Kind=ptkBoolean)Then CPEmitIOCSP(77)
    else CPEmitIOCSP(66);
    if CPToken=','Then CPNext else Break
   End;CPNeed(')')
  End;
  if Name='READLN'Then Begin
   if P=Nil Then CPConst(0)else CPAddressSymbol(P);CPEmitIOCSP(69)
  End
 End
 else if CPIs('INSERT')Then Begin
  CPNext;CPNeed('(');CPExpression;if(CPLastExpressionType<>Nil)and
  (CPLastExpressionType^.Kind=ptkChar)Then CPEmitCSP(50);
  CPNeed(',');CPExpression;RT:=CPLastExpressionType;
  CPNeed(',');CPExpression;CPNeed(')');
  if(RT<>Nil)and(RT^.Kind=ptkString)Then CPConst(RT^.HighBound)else CPConst(255);
  CPEmitCSP(47)
 End
 else if CPIs('DELETE')Then Begin
  CPNext;CPNeed('(');CPExpression;CPNeed(',');CPExpression;CPNeed(',');CPExpression;
  CPNeed(')');CPEmitCSP(48)
 End
 else if CPIs('WRITE')or CPIs('WRITELN')Then Begin
  Name:=CPText;CPNext;P:=Nil;
  if CPToken='('Then Begin
   CPNext;
   if CPToken='ID'Then Begin
    Tmp:=CPFind(CPText);
    if(Tmp<>Nil)and(CPBaseType(Tmp^.SymbolType)<>Nil)and
    (CPBaseType(Tmp^.SymbolType)^.Kind=ptkFile)Then Begin
     P:=Tmp;CPNext;if CPToken=','Then CPNext
    End
   End;
   While CPToken<>')'do Begin
    if P=Nil Then CPConst(0)else CPAddressSymbol(P);CPExpression;
    T:=CPBaseType(CPLastExpressionType);
    if(T<>Nil)and(T^.Kind=ptkString)Then Begin
     if CPToken=':'Then Begin
      CPNext;CPExpression
     End else CPConst(0);CPEmitIOCSP(54)
    End else
    Begin
     I:=0;if(T<>Nil)and(T^.Kind=ptkChar)Then I:=1 else
     if(T<>Nil)and(T^.Kind=ptkBoolean)Then I:=2 else if(T<>Nil)and(T^.Kind=ptkReal)
     Then I:=3;
     CPConst(I);if CPToken=':'Then Begin
      CPNext;CPExpression
     End else CPConst(0);
     if CPToken=':'Then Begin
      if(T=Nil)or(T^.Kind<>ptkReal)Then
       CPFailCode(124,'le format F est reserve aux reels');
      CPNext;CPExpression
     End else CPConst(-1);CPEmitIOCSP(70)
    End;
    if CPToken=','Then CPNext else Break
   End;CPNeed(')')
  End;
  if Name='WRITELN'Then Begin
   if P=Nil Then CPConst(0)else CPAddressSymbol(P);CPEmitIOCSP(55)
  End
 End
 else if CPToken='ID'Then Begin
  P:=CPFind(CPText);R:=CPVisibleRoutine(CPText);Name:=CPText;CPNext;
  if CPToken=':'Then Begin
   CPNext;CPDefineLabel(Name);CPStatement;Exit
  End;
  if(P=Nil)and(R<>Nil)Then Begin
   CPEmitActualParameters(R);CPEmitRoutineCall(R)
  End else if(P=Nil)and((Name='ABS')or(Name='SQR')or(Name='ODD')or
   (Name='SUCC')or(Name='PRED')or(Name='ORD')or(Name='CHR'))Then
   CPFailCode(150,'affectation a une fonction standard interdite')
  else if P=Nil Then CPFailCode(104,'identificateur non declare: '+Name)
  else if P^.IsConst Then CPFailCode(103,'identificateur de classe variable attendu: '+Name)else
  Begin
   CPDesignator(P,False,T);CPNeed(':=');
   While(T<>Nil)and(T^.Kind=ptkAlias)do T:=T^.ElementType;
   if(T<>Nil)and(T^.Kind=ptkFile)Then
    CPFailCode(146,'affectation de fichiers interdite');
   if(T<>Nil)and(T^.Kind=ptkString)Then Begin
    CPExpression;
    if(CPLastExpressionType<>Nil)and(CPLastExpressionType^.Kind=ptkChar)Then Begin
     CPEmitCSP(50);CPLastExpressionType:=CPFindType('STRING')
    End;
    if(CPLastExpressionType=Nil)or(CPLastExpressionType^.Kind<>ptkString)Then     CPFail(
    'chaine attendue dans l''affectation')else
    Begin
     CPConst(T^.HighBound);CPEmitCSP(45)
    End
   End else if(T<>Nil)and(T^.SizeWords>1)Then Begin
    CPExpression;RT:=CPLastExpressionType;
    if not CPAssignmentCompatible(T,RT)Then CPFailCode(129,'types structures incompatibles')
    else Begin CPOp(168,$8E);CPBig(T^.SizeWords) End
   End else
   Begin
    CPExpression;
    if not CPAssignmentCompatible(T,CPLastExpressionType)Then
     CPFailCode(129,'types incompatibles dans l''affectation');
    CPOp(154,$C4)
   End
  End
 End
End;

Procedure CPGenerateRoutine(R:PPasRoutine);
Var
 Child:PPasRoutine;
 Par:PPasParameter;
 Sym:PPasSymbol;
 Typ:PPasType;
 Names:Array[1..64]of String;
 N,I,Remain,Words:Integer;
Begin
 if(R=Nil)or not R^.IsDefined Then Exit;
 if R^.IsExternal or R^.IsSeparate Then Begin
  CPCurrentRoutine:=R;R^.CodeStart:=CPCodePos;CPEmitRoutineReturn(R);
  R^.CodeLength:=CPCodePos-R^.CodeStart;CPCurrentRoutine:=Nil;Exit
 End;
 CPCurrentRoutine:=R;CPPos:=R^.SourcePosition;CPNext;
 While(CPToken<>'EOF')and not CPIs('BEGIN')and not CPError do Begin
  if CPIs('PROCEDURE')or CPIs('FUNCTION')Then Begin
   CPNext;
   if CPToken<>'ID'Then Begin
    CPFail('nom de routine imbriquee attendu');Exit
   End;
   Child:=CPFindRoutine(CPText,R);
   if Child=Nil Then Begin
    CPFail('routine imbriquee absente de la passe 1');Exit
   End;
   CPPos:=Child^.EndPosition;CPNext
  End else if CPIs('CONST')Then CPParseConstSection
  else if CPIs('TYPE')Then CPParseTypeSection
  else if CPIs('LABEL')Then CPParseLabelSection
  else if CPIs('VAR')Then Begin
   CPNext;
   While(CPToken='ID')and not CPIs('BEGIN')and not CPIs('PROCEDURE')and
   not CPIs('FUNCTION')and not CPIs('CONST')and not CPIs('TYPE')and
   not CPError do Begin
    N:=0;
    Repeat Inc(N);Names[N]:=CPText;CPNext;
    if CPToken=','Then CPNext else Break
    Until N=64;
    CPNeed(':');Typ:=CPParseType;
    if(Typ<>Nil)and(Typ^.Kind=ptkAlias)and(Typ^.SizeWords=0)Then
     CPFailCode(118,'type FORWARD dans une declaration de variable');
    CPNeed(';');
    For I:=1 to N do Begin
     R^.LocalWords:=CPAlignedSize(R^.LocalWords,Typ^.AlignWords);
     CPAddTyped(Names[I],R^.LocalWords+1,False,Typ);Inc(R^.LocalWords,Typ^.SizeWords)
    End
   End
  End else CPNext
 End;
 Remain:=R^.ParameterWords;Par:=R^.Parameters;
 While Par<>Nil do Begin
  if Par^.ByReference or Par^.Structured Then Words:=1 else Words:=
  Par^.ParamType^.SizeWords;
  Dec(Remain,Words);CPAdd(Par^.Name,R^.LocalWords+Remain,False);
  Sym:=CPFind(Par^.Name);if Sym<>Nil Then Begin
   Sym^.IsParameter:=True;
   Sym^.ByReference:=Par^.ByReference or Par^.Structured;Sym^.SymbolType:=Par^.ParamType
  End;
  Par^.Offset:=R^.LocalWords+Remain;Par:=Par^.Next
 End;
 if R^.IsFunction Then Begin
  CPAdd(R^.Name,R^.LocalWords+R^.ParameterWords,False);
  Sym:=CPFind(R^.Name);if Sym<>Nil Then Sym^.SymbolType:=R^.ResultType
 End;
 if(LongInt(R^.LocalWords)+R^.ParameterWords+5>32767)Then Begin
  CPFailCode(193,'cadre local depasse 32767 mots: '+R^.Name);CPCurrentRoutine:=Nil;Exit
 End;
 R^.CodeStart:=CPCodePos;CPCompound;CPEmitRoutineReturn(R);
 CPCheckLabels(R);R^.CodeLength:=CPCodePos-R^.CodeStart;CPCurrentRoutine:=Nil
End;

Procedure CPGenerateAllRoutines;
Var
 R:PPasRoutine;
 Level,MaxLevel:Integer;
Begin
 CPPass:=2;MaxLevel:=0;R:=CPRoutines;
 While R<>Nil do Begin
  if R^.LexicalLevel>MaxLevel Then MaxLevel:=R^.LexicalLevel;R:=R^.Next
 End;
 For Level:=1 to MaxLevel do Begin
  R:=CPRoutines;
  While(R<>Nil)and not CPError do Begin
   if R^.LexicalLevel=Level Then CPGenerateRoutine(R);R:=R^.Next
  End
 End
End;
Function WriteUCSDCodeFile(CodeName,SegmentName:String;CodeLength:LongInt;

DataWords:Integer):Boolean;
Var
 F:File;
 Header:Array[0..511]of Byte;
 SegmentLength:Word;
 N,W:Word;
 I:Integer;
 ProcEntry,ProcDict,Posi,Src,Len:LongInt;
 ProcNo,ProcTotal,J:Integer;
 Tmp:PPCodeMemory;
 R,Owner:PPasRoutine;
 Q:PPasRelocation;
 Attr:Array[1..255]of Word;
 ImportCount:Integer;
 LinkRecord,PointerRecord,ZeroBlock:Array[0..511]of Byte;
 RefCount,RefIndex,LinkSize,InterfaceBlock,EndPosition:LongInt;
 PrevQ:PPasRelocation;
 DebugFile:Text;
 DebugName:String;
 Sym:PPasSymbol;
 ParentNo,TypeKind:Integer;

Procedure HW(Offset:Integer;Value:Word);Begin
 Header[Offset]:=Byte(Value);Header[Offset+1]:=Byte(Value shr 8)
End;

Procedure EW(Value:Word);Begin
 CPE(Byte(Value));CPE(Byte(Value shr 8))
End;

Procedure LinkWord(Var B:Array of Byte;Ofs:Integer;Value:Word);Begin
 B[Ofs]:=Byte(Value);B[Ofs+1]:=Byte(Value shr 8)
End;

Procedure LinkName(Var B:Array of Byte;S:String);
Var X:Integer;
Begin
 S:=UpperString(S);if Length(S)>8 Then S:=Copy(S,1,8);
 For X:=1 to Length(S)do B[X-1]:=Ord(S[X])
End;

Procedure WriteLinkBlock(Var B:Array of Byte;Count:Word);
Var Written:Word;
Begin
 if CPError Then Exit;BlockWrite(F,B[0],Count,Written);
 if(IOResult<>0)or(Written<>Count)Then
  CPFailCode(402,'erreur d''ecriture des informations de liaison')
End;

Function IsFirstRelocation(X:PPasRelocation):Boolean;
Var Y:PPasRelocation;
Begin
 Y:=CPRelocations;
 While(Y<>Nil)and(Y<>X)do Begin
  if Y^.Name=X^.Name Then Begin IsFirstRelocation:=False;Exit End;Y:=Y^.Next
 End;IsFirstRelocation:=True
End;
Begin
 WriteUCSDCodeFile:=False;if CodeLength>65520 Then Begin
  CPFailCode(193,'segment trop grand');Exit
 End;
 if(LongInt(DataWords)+5>32767)Then Begin
  CPFailCode(193,'cadre global depasse 32767 mots');Exit
 End;
 { Le dictionnaire est aussi employe pour un programme II a une seule
   procedure: il separe la pile descendante des variables globales. }
 if CPNextProcedure>=1 Then Begin
  ProcTotal:=CPNextProcedure;
  if ProcTotal>255 Then Begin
   CPFail('plus de 255 procedures');Exit
  End;
  GetMem(Tmp,SizeOf(TPCodeMemory));FillChar(Tmp^,SizeOf(TPCodeMemory),0);
  Posi:=22;
  For ProcNo:=1 to ProcTotal do Begin
   if ProcNo=1 Then Begin
    Src:=CPMainStart;Len:=CPMainLength;N:=DataWords
   End
   else
   Begin
    R:=CPRoutines;
    While(R<>Nil)and(R^.ProcNumber<>ProcNo)do R:=R^.Next;
    if R=Nil Then Begin
     CPFail('procedure absente du dictionnaire');Break
    End;
    Src:=R^.CodeStart;Len:=R^.CodeLength;N:=R^.LocalWords
   End;
   if(Src<0)or(Len<=0)or(Src+Len>CodeLength)or(Posi+Len+520>65534)Then Begin
    CPFail('plage de procedure invalide');Break
   End;
   Attr[ProcNo]:=Posi div 2;
   Tmp^[Posi-2]:=Byte((Posi+2+Len)div 2);
   Tmp^[Posi-1]:=Byte(((Posi+2+Len)div 2)shr 8);
   Tmp^[Posi]:=Byte(N);Tmp^[Posi+1]:=Byte(N shr 8);Inc(Posi,2);
   if ProcNo=1 Then Owner:=Nil else Owner:=R;
   Q:=CPRelocations;
   While Q<>Nil do Begin
    if(Q^.Owner=Owner)and(Q^.CodePosition>=Src)and(Q^.CodePosition<Src+Len)
    Then     Q^.FinalPosition:=Posi+(Q^.CodePosition-Src);Q:=Q^.Next
   End;
   For J:=0 to Len-1 do Tmp^[Posi+J]:=PCode_Mem^[Src+J];Inc(Posi,Len);
   if Odd(Posi)Then Begin
    Tmp^[Posi]:=$9C;Inc(Posi)
   End;
   if ProcNo<ProcTotal Then Inc(Posi,2) { end-pointer suivant }
  End;
  if CPError Then Begin
   FreeMem(Tmp,SizeOf(TPCodeMemory));Exit
  End;
  ProcDict:=Posi+ProcTotal*2;
  For ProcNo:=1 to ProcTotal do Begin
   ProcEntry:=ProcDict-ProcNo*2;Tmp^[ProcEntry]:=Byte(Attr[ProcNo]);
   Tmp^[ProcEntry+1]:=Byte(Attr[ProcNo]shr 8)
  End;
  Tmp^[ProcDict]:=Byte(ProcTotal);Tmp^[ProcDict+1]:=0;
  Tmp^[0]:=Byte(ProcDict div 2);Tmp^[1]:=Byte((ProcDict div 2)shr 8);
  Tmp^[12]:=1;Tmp^[13]:=0;CPCodePos:=ProcDict+2;
  Move(Tmp^,PCode_Mem^,CPCodePos);FreeMem(Tmp,SizeOf(TPCodeMemory));
  SegmentLength:=CPCodePos
 End else
 Begin
  EW(DataWords*2);EW(0);EW(CodeLength-1);EW(0);CPE(1);CPE(0);
  EW(CodeLength);CPE(1);CPE(1);SegmentLength:=CPCodePos
 End;
 if Odd(SegmentLength)Then Begin
  PCode_Mem^[SegmentLength]:=$9C;Inc(SegmentLength);CPCodePos:=SegmentLength
 End;
 FillChar(Header,SizeOf(Header),0);HW(0,1);HW(2,SegmentLength);
 SegmentName:=UpperString(SegmentName);
 if Length(SegmentName)>8 Then SegmentName:=Copy(SegmentName,1,8);
 For I:=1 to Length(SegmentName)do Header[63+I]:=Ord(SegmentName[I]);
 if CPNextProcedure>=1 Then
 For I:=1 to Length(SegmentName)do PCode_Mem^[3+I]:=Ord(SegmentName[I]);
 ImportCount:=0;Q:=CPRelocations;
 While Q<>Nil do Begin
  if Q^.FinalPosition>=0 Then Inc(ImportCount);Q:=Q^.Next
 End;
 if CPCompilationIsUnit Then HW(192,4)
 else if ImportCount>0 Then HW(192,1)else HW(192,0);
 HW(224,0);
 Case CurrentTarget of
 ptAppleHeath:HW(256,$0101);
 ptUCSDPascalII:HW(256,$0201);
 ptUCSDPSystemIII:HW(256,$0301);
 ptUCSDPSystemIV:HW(256,$0401)
End;
 { PSVM identifie seulement le dictionnaire et l'ABI internes. Les symboles
   ne sont plus tronques dans l'en-tete: ils sont ecrits comme LIENTRY UCSD. }
Header[288]:=Ord('P');Header[289]:=Ord('S');Header[290]:=Ord('V');Header[291]:=Ord('M');
Header[292]:=0;Header[293]:=0;
Assign(F,CodeName);Rewrite(F,1);if IOResult<>0 Then Begin
 CPFailCode(402,'creation du fichier CODE impossible');Exit
End;
BlockWrite(F,Header,512,W);if(IOResult<>0)or(W<>512)Then
 CPFailCode(402,'erreur d''ecriture du fichier CODE');
if not CPError Then Begin
 BlockWrite(F,PCode_Mem^,SegmentLength,N);
 if(IOResult<>0)or(N<>SegmentLength)Then CPFailCode(402,'erreur d''ecriture du fichier CODE')
End;
{ Les LIENTRY commencent au bloc suivant. Chaque en-tete occupe huit mots;
  les SEPPREF sont suivis de blocs de huit offsets absolus dans le segment. }
if not CPError Then Begin
 FillChar(ZeroBlock,SizeOf(ZeroBlock),0);LinkSize:=512+SegmentLength;
 if(LinkSize mod 512)<>0 Then WriteLinkBlock(ZeroBlock,512-(LinkSize mod 512));
 R:=CPRoutines;
 While(R<>Nil)and not CPError do Begin
  if(R^.Parent=Nil)and not R^.IsExternal and not R^.IsSeparate Then Begin
   FillChar(LinkRecord,16,0);LinkName(LinkRecord,R^.Name);
   LinkWord(LinkRecord,8,11); { SEPPROC }
   LinkWord(LinkRecord,10,R^.ProcNumber);LinkWord(LinkRecord,12,R^.ParameterWords*2);
   WriteLinkBlock(LinkRecord,16)
  End;R:=R^.Next
 End;
 Q:=CPRelocations;
 While(Q<>Nil)and not CPError do Begin
  if(Q^.FinalPosition>=0)and IsFirstRelocation(Q)Then Begin
   RefCount:=0;PrevQ:=CPRelocations;
   While PrevQ<>Nil do Begin
    if(PrevQ^.Name=Q^.Name)and(PrevQ^.FinalPosition>=0)Then Inc(RefCount);
    PrevQ:=PrevQ^.Next
   End;
   FillChar(LinkRecord,16,0);LinkName(LinkRecord,Q^.Name);
   LinkWord(LinkRecord,8,13); { SEPPREF }
   LinkWord(LinkRecord,10,1); { BYTE: segment/procedure dans CXP }
   LinkWord(LinkRecord,12,RefCount);WriteLinkBlock(LinkRecord,16);
   RefIndex:=0;FillChar(PointerRecord,16,0);PrevQ:=CPRelocations;
   While PrevQ<>Nil do Begin
    if(PrevQ^.Name=Q^.Name)and(PrevQ^.FinalPosition>=0)Then Begin
     LinkWord(PointerRecord,(RefIndex mod 8)*2,PrevQ^.FinalPosition);
     Inc(RefIndex);if(RefIndex mod 8)=0 Then Begin
      WriteLinkBlock(PointerRecord,16);FillChar(PointerRecord,16,0)
     End
    End;PrevQ:=PrevQ^.Next
   End;
   if(RefIndex mod 8)<>0 Then WriteLinkBlock(PointerRecord,16)
  End;Q:=Q^.Next
 End;
 FillChar(LinkRecord,16,0);LinkWord(LinkRecord,8,0); { EOFMARK }
 LinkWord(LinkRecord,10,DataWords+1);WriteLinkBlock(LinkRecord,16)
End;
if not CPError and CPCompilationIsUnit and(CPInterfaceLength>0)Then Begin
 EndPosition:=FilePos(F);
 if(EndPosition mod 512)<>0 Then WriteLinkBlock(ZeroBlock,512-(EndPosition mod 512));
 InterfaceBlock:=FilePos(F)div 512;
 LinkRecord[0]:=Byte(CPInterfaceLength);LinkRecord[1]:=Byte(CPInterfaceLength shr 8);
 WriteLinkBlock(LinkRecord,2);
 BlockWrite(F,CPInterfaceSource^,CPInterfaceLength,N);
 if(IOResult<>0)or(N<>CPInterfaceLength)Then
  CPFailCode(402,'erreur d''ecriture de l''interface d''unite');
 EndPosition:=FilePos(F);Seek(F,224);LinkRecord[0]:=Byte(InterfaceBlock);
 LinkRecord[1]:=Byte(InterfaceBlock shr 8);WriteLinkBlock(LinkRecord,2);Seek(F,EndPosition)
End;
Close(F);if IOResult<>0 Then CPFailCode(402,'erreur de fermeture du fichier CODE');
if CPError Then Begin Erase(F);if IOResult<>0 Then
 WriteLn('Impossible de supprimer le fichier CODE incomplet: ',CodeName) End;
if not CPError Then Begin
 DebugName:=ReplaceExtension(CodeName,'.DBG');Assign(DebugFile,DebugName);Rewrite(DebugFile);
 if IOResult=0 Then Begin
  WriteLn(DebugFile,'PSDBG1 ',Ord(CurrentTarget),' ',SegmentName);
  WriteLn(DebugFile,'R 1 0 0 ',LongInt(Attr[1])*2+2,' ',CPMainLength,' ',DataWords,
   ' 0 1 ',SegmentName);
  R:=CPRoutines;
  While R<>Nil do Begin
   ParentNo:=1;if R^.Parent<>Nil Then ParentNo:=R^.Parent^.ProcNumber;
   if(R^.ProcNumber>=1)and(R^.ProcNumber<=ProcTotal)Then
    WriteLn(DebugFile,'R ',R^.ProcNumber,' ',R^.LexicalLevel,' ',ParentNo,' ',
     LongInt(Attr[R^.ProcNumber])*2+2,' ',R^.CodeLength,' ',R^.LocalWords,' ',
     R^.ParameterWords,' ',R^.DeclarationLine,' ',R^.Name);
   R:=R^.Next
  End;
  Sym:=CPSymbols;
  While Sym<>Nil do Begin
   if not Sym^.IsConst Then Begin
    ParentNo:=1;if Sym^.Scope<>Nil Then ParentNo:=Sym^.Scope^.ProcNumber;
    TypeKind:=-1;if Sym^.SymbolType<>Nil Then TypeKind:=Ord(CPBaseType(Sym^.SymbolType)^.Kind);
    WriteLn(DebugFile,'S ',ParentNo,' ',Sym^.Address,' ',Sym^.LexicalLevel,' ',
     Ord(Sym^.IsParameter),' ',Ord(Sym^.ByReference),' ',TypeKind,' ',
     Sym^.DeclarationLine,' ',Sym^.Name)
   End;Sym:=Sym^.Next
  End;
  Close(DebugFile);if IOResult<>0 Then WriteLn('Avertissement: fermeture ',DebugName)
 End else WriteLn('Avertissement: creation impossible de ',DebugName)
End;
WriteUCSDCodeFile:=not CPError
End;

{ Liaison des sources UNIT: les noms propres a chaque unite sont qualifies
  avant les passes du compilateur. Aucune interface binaire historique n'est
  supposee dans cette premiere implementation. }
Function CPExpandUnits(SourceName:String):Boolean;
Type
 PTrivia=^TTrivia;
 TTrivia=Record Text:String;Next:PTrivia End;
 PToken=^TToken;
 TToken=Record Text,Kind:String;Next,AllocatedNext:PToken;Trivia:PTrivia End;
 PName=^TName;
 TName=Record Name,Replacement,Signature:String;
  PublicName,OwnName,UnitAlias:Boolean;BinaryProc:Integer;Next:PName End;
 PUnitSource=^TUnitSource;
 TUnitSource=Record Name,Path,Prefix:String;
  Tokens,Constants,Types,Variables,Routines,Init:PToken;
  Names:PName;Loading,Loaded,FromCode:Boolean;Next,OrderNext:PUnitSource End;
Var
 Units,Root,U:PUnitSource;
 AllTokens,AllocatedTokens:PToken;
 Ordered,OrderTail:PUnitSource;
 Counter:Integer;
 Output:PPasSource;
 OutputSize:LongInt;
 TriviaTail:PTrivia;

Function IsWord(T:PToken;S:String):Boolean;Begin
 IsWord:=(T<>Nil);if T<>Nil Then IsWord:=(T^.Kind='ID')and(T^.Text=S)
End;

Procedure Error(Code:Integer;S:String);Begin CPFailCode(Code,S)End;

Function NewToken:PToken;
Var T:PToken;
Begin
 New(T);T^.Text:='';T^.Kind:='';T^.Next:=Nil;
 T^.Trivia:=Nil;
 T^.AllocatedNext:=AllocatedTokens;AllocatedTokens:=T;NewToken:=T
End;

Function Tokenize:PToken;
Var T,Head,Tail:PToken;I,L,PreviousEnd:LongInt;V:PTrivia;
Begin
 Head:=Nil;Tail:=Nil;PreviousEnd:=0;CPPos:=0;CPLine:=1;CPNext;
 While(CPToken<>'EOF')and not CPError do Begin
  T:=NewToken;T^.Kind:=CPToken;
  I:=PreviousEnd;
  While I<CPTokenPos do Begin
   New(V);V^.Text:='';V^.Next:=Nil;
   While(I<CPTokenPos)and(Length(V^.Text)<255)do Begin
    V^.Text:=V^.Text+Chr(CPSource^[I]);Inc(I)
   End;
   if T^.Trivia=Nil Then T^.Trivia:=V else TriviaTail^.Next:=V;
   TriviaTail:=V
  End;
  L:=CPPos-CPTokenPos;
  if L>255 Then Error(398,'token trop long pour la liaison des unites')
  else For I:=CPTokenPos to CPPos-1 do T^.Text:=T^.Text+Chr(CPSource^[I]);
  if T^.Kind='ID'Then T^.Text:=CPText;
  if Head=Nil Then Head:=T else Tail^.Next:=T;Tail:=T;
  PreviousEnd:=CPPos;
  { Liste distincte pour liberer aussi les listes decoupees. }
  CPNext
 End;Tokenize:=Head
End;

Procedure AddName(A:PUnitSource;S:String;Pub:Boolean);
Var N:PName;
Begin
 N:=A^.Names;While(N<>Nil)and(N^.Name<>S)do N:=N^.Next;
 if(N<>Nil)and N^.OwnName Then Begin if Pub Then N^.PublicName:=True;Exit End;
 if N=Nil Then Begin New(N);N^.Next:=A^.Names;A^.Names:=N End;
 N^.Name:=S;N^.Replacement:=A^.Prefix+S;N^.PublicName:=Pub;
 N^.OwnName:=True;N^.UnitAlias:=False;N^.Signature:='';
 if Length(N^.Replacement)>31 Then Error(398,'nom qualifie d''unite trop long: '+S);
End;

Function Signature(T,Last:PToken):String;
Var S:String;
Begin
 S:='';
 While T<>Nil do Begin
  if Length(S)+Length(T^.Text)+1>255 Then Begin
   Error(398,'signature d''interface trop longue');Break
  End;
  S:=S+T^.Text+' ';if T=Last Then Break;T:=T^.Next
 End;Signature:=S
End;

Function HeaderEnd(T:PToken):PToken;
Var Depth:Integer;
Begin
 Depth:=0;
 While T<>Nil do Begin
  if T^.Text='('Then Inc(Depth)else if T^.Text=')'Then Dec(Depth);
  if(T^.Text=';')and(Depth=0)Then Begin HeaderEnd:=T;Exit End;
  T:=T^.Next
 End;Error(401,'fin de source dans un en-tete de routine');HeaderEnd:=Nil
End;

Function RoutineEnd(T:PToken):PToken;
Var H:PToken;Depth:Integer;
Begin
 RoutineEnd:=Nil;H:=HeaderEnd(T);if H=Nil Then Exit;T:=H^.Next;
 if IsWord(T,'FORWARD')or IsWord(T,'EXTERNAL')or IsWord(T,'SEPARATE')Then Begin
  RoutineEnd:=HeaderEnd(T);Exit
 End;
 While(T<>Nil)and not IsWord(T,'BEGIN')and not CPError do Begin
  if IsWord(T,'PROCEDURE')or IsWord(T,'FUNCTION')Then Begin
   H:=RoutineEnd(T);if H=Nil Then Exit;T:=H^.Next
  End else T:=T^.Next
 End;
 Depth:=0;
 While T<>Nil do Begin
  if IsWord(T,'BEGIN')or IsWord(T,'CASE')Then Inc(Depth)
  else if IsWord(T,'END')Then Begin
   Dec(Depth);if Depth=0 Then Begin
    T:=T^.Next;if(T=Nil)or(T^.Text<>';')Then Error(14,'point-virgule apres routine attendu');
    RoutineEnd:=T;Exit
   End
  End;T:=T^.Next
 End;Error(401,'fin de source dans le corps d''une routine')
End;

Procedure Append(Var Head:PToken;First,Last:PToken);
Var T:PToken;
Begin
 if(First=Nil)or(Last=Nil)Then Exit;
 if Head=Nil Then Head:=First else Begin
  T:=Head;While T^.Next<>Nil do T:=T^.Next;T^.Next:=First
 End;Last^.Next:=Nil
End;

Function DirectoryOf(S:String):String;
Var I:Integer;
Begin
 I:=Length(S);While(I>0)and not(S[I]in['/', '\', ':'])do Dec(I);
 DirectoryOf:=Copy(S,1,I)
End;

Function LoadUnit(S,Caller:String):PUnitSource;Forward;

Procedure ParseUses(A:PUnitSource;Var T:PToken);
Var B:PUnitSource;N,M:PName;S:String;
Begin
 T:=T^.Next;
 While(T<>Nil)and not CPError do Begin
  if T^.Kind<>'ID'Then Begin Error(2,'nom d''unite attendu');Exit End;
  S:=T^.Text;B:=LoadUnit(S,A^.Path);if B=Nil Then Exit;
  New(M);M^.Name:=S;M^.Replacement:='';M^.Signature:='';
  M^.PublicName:=False;M^.OwnName:=False;M^.UnitAlias:=True;
  M^.Next:=A^.Names;A^.Names:=M;
  N:=B^.Names;
  While N<>Nil do Begin
   if N^.PublicName Then Begin
    M:=A^.Names;While(M<>Nil)and(M^.Name<>N^.Name)do M:=M^.Next;
    if(M<>Nil)and(M^.Replacement<>N^.Replacement)Then
     Error(101,'export ambigu dans USES: '+N^.Name)
    else if M=Nil Then Begin
     New(M);M^:=N^;M^.PublicName:=False;M^.OwnName:=False;
     M^.Next:=A^.Names;A^.Names:=M
    End
   End;N:=N^.Next
  End;
  T:=T^.Next;if(T<>Nil)and(T^.Text=',')Then T:=T^.Next else Break
 End;
 if(T=Nil)or(T^.Text<>';')Then Error(14,'point-virgule apres USES attendu')
 else T:=T^.Next
End;

Procedure ParseSource(A:PUnitSource;IsUnit:Boolean);
Var T,H,First,Last,NextToken,NameToken:PToken;
 Pub:Boolean;Section,Depth:Integer;AtName:Boolean;
 N:PName;
Begin
 T:=A^.Tokens;Pub:=IsUnit;
 if not IsWord(T,'UNIT')and not IsWord(T,'PROGRAM')Then Begin
  Error(405,'''PROGRAM'' ou ''UNIT'' attendu');Exit
 End;
 if IsUnit and not IsWord(T,'UNIT')Then Begin Error(24,'UNIT attendu dans le fichier d''unite');Exit End;
 T:=T^.Next;if(T=Nil)or(T^.Kind<>'ID')Then Begin Error(2,'nom attendu');Exit End;
 if IsUnit and(T^.Text<>A^.Name)Then Begin Error(188,'nom UNIT different du fichier demande');Exit End;
 H:=HeaderEnd(T);if H=Nil Then Exit;T:=H^.Next;
 if IsUnit Then Begin
  if not IsWord(T,'INTERFACE')Then Begin Error(22,'INTERFACE attendu');Exit End;
  T:=T^.Next
 End;
 While(T<>Nil)and not CPError do Begin
  if IsWord(T,'USES')Then ParseUses(A,T)
  else if IsWord(T,'IMPLEMENTATION')Then Begin
   if not IsUnit or not Pub Then Begin Error(18,'IMPLEMENTATION inattendu');Exit End;
   Pub:=False;T:=T^.Next
  End
  else if IsWord(T,'CONST')or IsWord(T,'TYPE')or IsWord(T,'VAR')Then Begin
   if IsWord(T,'CONST')Then Section:=1 else if IsWord(T,'TYPE')Then Section:=2 else Section:=3;
   T:=T^.Next;First:=T;Last:=Nil;Depth:=0;AtName:=True;
   While(T<>Nil)and not CPError do Begin
    if(Depth=0)and(T^.Kind='ID')and
     ((T^.Text='CONST')or(T^.Text='TYPE')or(T^.Text='VAR')or
      (T^.Text='PROCEDURE')or(T^.Text='FUNCTION')or(T^.Text='IMPLEMENTATION')or
      (T^.Text='USES')or(T^.Text='BEGIN')or(T^.Text='END'))Then Break;
    if AtName and(T^.Kind='ID')Then Begin
     AddName(A,T^.Text,Pub);if Section<>3 Then AtName:=False
    End;
    if(Section=3)and(T^.Text=':')Then AtName:=False;
    if IsWord(T,'RECORD')Then Inc(Depth)else if IsWord(T,'END')Then Dec(Depth);
    if(T^.Text=';')and(Depth=0)Then AtName:=True;
    Last:=T;T:=T^.Next
   End;
   if Last<>Nil Then Begin
    if Section=1 Then Append(A^.Constants,First,Last)
    else if Section=2 Then Append(A^.Types,First,Last)
    else Append(A^.Variables,First,Last)
   End
  End
  else if IsWord(T,'PROCEDURE')or IsWord(T,'FUNCTION')Then Begin
   First:=T;NameToken:=T^.Next;
   if(NameToken=Nil)or(NameToken^.Kind<>'ID')Then Begin Error(2,'nom de routine attendu');Exit End;
   if Pub Then Begin
    AddName(A,NameToken^.Text,True);H:=HeaderEnd(T);if H=Nil Then Exit;
    N:=A^.Names;While(N<>Nil)and(N^.Name<>NameToken^.Text)do N:=N^.Next;
    if N<>Nil Then N^.Signature:=Signature(First,H);
    NextToken:=H^.Next;
    if IsWord(NextToken,'EXTERNAL')Then Begin Error(184,'EXTERNAL interdit dans INTERFACE');Exit End;
    Last:=NewToken;H^.Next:=Last;
    if A^.FromCode Then Begin
     Last^.Text:='EXTERNAL';Last^.Kind:='ID';Last^.Next:=NewToken;
     Last:=Last^.Next;Str(N^.BinaryProc,Last^.Text);Last^.Kind:='NUM';
     Last^.Next:=NewToken;Last:=Last^.Next;Last^.Text:=';';Last^.Kind:=';'
    End else Begin
     Last^.Text:='FORWARD';Last^.Kind:='ID';Last^.Next:=NewToken;
     Last:=Last^.Next;Last^.Text:=';';Last^.Kind:=';'
    End;
    Last^.Next:=Nil;Append(A^.Routines,First,Last);T:=NextToken
   End else Begin
    H:=HeaderEnd(T);Last:=RoutineEnd(T);if(H=Nil)or(Last=Nil)Then Exit;
    NextToken:=Last^.Next;N:=A^.Names;
    While(N<>Nil)and(N^.Name<>NameToken^.Text)do N:=N^.Next;
    if(N<>Nil)and N^.PublicName and(N^.Signature<>'')Then Begin
     if(NameToken^.Next<>H)and(Signature(First,H)<>N^.Signature)Then Begin
      Error(128,'signature IMPLEMENTATION incompatible avec INTERFACE: '+NameToken^.Text);Exit
     End;
     { Le contrat de l'interface fournit deja les parametres et le resultat. }
     NameToken^.Next:=H
    End else AddName(A,NameToken^.Text,False);
    Append(A^.Routines,First,Last);T:=NextToken
   End
  End
  else if IsWord(T,'BEGIN')or IsWord(T,'END')Then Begin
   if IsUnit and Pub Then Begin Error(23,'IMPLEMENTATION attendu');Exit End;
   A^.Init:=T;Break
  End else Begin Error(18,'declaration inattendue: '+T^.Text);Exit End
 End;
 if not CPError Then Begin
  T:=A^.Init;Last:=Nil;H:=Nil;
  While T<>Nil do Begin H:=Last;Last:=T;T:=T^.Next End;
  if(Last=Nil)or(Last^.Text<>'.')or not IsWord(H,'END')Then
   Error(401,'END. attendu a la fin du fichier')
 End;
 if IsUnit and Pub Then Error(23,'IMPLEMENTATION attendu');
 if A^.Init=Nil Then Error(401,'fin de source avant le corps final')
End;

Function LoadUnit(S,Caller:String):PUnitSource;
Var A:PUnitSource;F:File;Sz,TextPos,LinkAt,CodeAt,CodeLen:LongInt;Count:Word;
 SavedSource:PPasSource;SavedSize:LongInt;Path:String;
 SavedDiagnostic:String;
 LibPath:String;
 H:Array[0..511]of Byte;LR:Array[0..15]of Byte;RN:String;
 LT,PN:Integer;NM:PName;CodeInput:Boolean;
Begin
 LoadUnit:=Nil;A:=Units;
 While(A<>Nil)and(A^.Name<>S)do A:=A^.Next;
 if A<>Nil Then Begin
  if A^.Loading Then Error(195,'cycle de dependances USES: '+S)
  else LoadUnit:=A;Exit
 End;
 Path:=DirectoryOf(Caller)+S+'.PAS';
 if not FileExists(Path)Then Path:=S+'.PAS';
 CodeInput:=False;
 if not FileExists(Path)Then Begin
  Path:=DirectoryOf(Caller)+S+'.CODE';if not FileExists(Path)Then Path:=S+'.CODE';
  CodeInput:=FileExists(Path)
 End;
 if not FileExists(Path)Then Begin
  LibPath:=GetEnv('PSYSTEM_LIBRARY');
  if LibPath<>''Then Begin
   if not(LibPath[Length(LibPath)]in['/','\',':'])Then LibPath:=LibPath+'\';
   Path:=LibPath+S+'.CODE';CodeInput:=FileExists(Path)
  End
 End;
 if not FileExists(Path)Then Begin Error(190,'source ou CODE d''unite introuvable: '+S);Exit End;
 New(A);FillChar(A^,SizeOf(TUnitSource),0);A^.Name:=S;A^.Path:=Path;
 Inc(Counter);Str(Counter,A^.Prefix);A^.Prefix:='U'+A^.Prefix+'_';
 A^.Loading:=True;A^.Next:=Units;Units:=A;
 SavedSource:=CPSource;SavedSize:=CPSize;SavedDiagnostic:=CPDiagnosticFile;
 GetMem(CPSource,SizeOf(TPCodeMemory));CPSize:=0;
 Assign(F,Path);Reset(F,1);
 if IOResult<>0 Then Error(410,'lecture de l''unite impossible: '+Path)
 else Begin
  Sz:=FileSize(F);
  if CodeInput Then Begin
   if Sz<514 Then Error(190,'CODE d''unite invalide: '+Path)
   else Begin
    BlockRead(F,H,512,Count);
    if(IOResult<>0)or(Count<>512)or(H[288]<>Ord('P'))or(H[289]<>Ord('S'))or
     (H[290]<>Ord('V'))or(H[291]<>Ord('M'))Then
     Error(195,'CODE d''unite incompatible: '+Path)
    else Begin
     A^.FromCode:=True;TextPos:=(H[224]or(H[225]shl 8))*512;
     CodeAt:=(H[0]or(H[1]shl 8))*512;CodeLen:=H[2]or(H[3]shl 8);
     if(TextPos<512)or(TextPos+2>Sz)Then Error(190,'interface absente du CODE: '+Path)
     else Begin
      Seek(F,TextPos);BlockRead(F,LR,2,Count);CPSize:=LR[0]or(LR[1]shl 8);
      if(CPSize<1)or(TextPos+2+CPSize>Sz)Then Error(190,'interface CODE invalide')
      else Begin
       BlockRead(F,CPSource^,CPSize,Count);
       if(IOResult<>0)or(Count<>CPSize)Then Error(410,'lecture interface CODE incomplete')
      End
     End;
     LinkAt:=CodeAt+CodeLen;if(LinkAt mod 512)<>0 Then LinkAt:=((LinkAt+511)div 512)*512;
     While not CPError and(LinkAt+16<=Sz)do Begin
      Seek(F,LinkAt);BlockRead(F,LR,16,Count);if(IOResult<>0)or(Count<>16)Then Break;
      LT:=LR[8]or(LR[9]shl 8);if LT=0 Then Break;
      if LT=11 Then Begin
       RN:='';For PN:=0 to 7 do if LR[PN]<>0 Then RN:=RN+Chr(LR[PN]);
       New(NM);FillChar(NM^,SizeOf(TName),0);NM^.Name:=RN;NM^.Replacement:=RN;
       NM^.PublicName:=True;NM^.OwnName:=True;NM^.BinaryProc:=LR[10]or(LR[11]shl 8);
       NM^.Next:=A^.Names;A^.Names:=NM
      End;
      Inc(LinkAt,16);
      if LT in[1,2,3,4,5,13,14]Then
       Inc(LinkAt,(((LR[12]or(LR[13]shl 8))+7)div 8)*16)
     End;
     if not CPError Then Begin A^.Tokens:=Tokenize;ParseSource(A,True) End
    End
   End
  End else if(Sz<0)or(Sz>65534)Then Error(193,'source d''unite trop grand')
  else Begin
   BlockRead(F,CPSource^,Sz,Count);if(IOResult<>0)or(Count<>Sz)Then
    Error(410,'lecture incomplete de l''unite: '+Path)
   else Begin
    CPSize:=Sz;
    if CPExpandIncludeFiles(Path)Then Begin A^.Tokens:=Tokenize;ParseSource(A,True) End
   End
  End;Close(F);if IOResult<>0 Then Error(410,'fermeture de l''unite impossible')
 End;
 FreeMem(CPSource,SizeOf(TPCodeMemory));CPSource:=SavedSource;CPSize:=SavedSize;
 CPDiagnosticFile:=SavedDiagnostic;
 A^.Loading:=False;A^.Loaded:=not CPError;if not CPError Then Begin
  if Ordered=Nil Then Ordered:=A else OrderTail^.OrderNext:=A;
  OrderTail:=A;LoadUnit:=A
 End
End;

Procedure Emit(S:String);
Var I:Integer;
Begin
 if OutputSize+Length(S)+1>65534 Then Begin Error(193,'programme et unites trop grands');Exit End;
 For I:=1 to Length(S)do Begin Output^[OutputSize]:=Ord(S[I]);Inc(OutputSize) End;
 Output^[OutputSize]:=10;Inc(OutputSize)
End;

Procedure EmitTokens(A:PUnitSource;T:PToken;StopAtEnd:Boolean);
Var N:PName;B:PUnitSource;S:String;Depth,RecordDepth:Integer;V:PTrivia;
 FieldName,AfterDot:Boolean;
Begin
 Depth:=0;RecordDepth:=0;FieldName:=False;AfterDot:=False;
 While(T<>Nil)and not CPError do Begin
  if StopAtEnd and IsWord(T,'END')and(Depth=0)Then Break;
  if IsWord(T,'BEGIN')or IsWord(T,'CASE')Then Inc(Depth)
  else if IsWord(T,'END')Then Dec(Depth);
  S:=T^.Text;
  if T^.Kind='ID'Then Begin
   B:=Units;While(B<>Nil)and(B^.Name<>S)do B:=B^.Next;
   if(B<>Nil)and(T^.Next<>Nil)and(T^.Next^.Text='.')Then Begin
    N:=A^.Names;While(N<>Nil)and not((N^.Name=S)and N^.UnitAlias)do N:=N^.Next;
    if(N=Nil)and(A^.Name<>S)Then Begin
     Error(188,'unite absente de USES: '+S);Exit
    End;
    T:=T^.Next^.Next;if T=Nil Then Begin Error(2,'identificateur apres unite attendu');Exit End;
    N:=B^.Names;While(N<>Nil)and(N^.Name<>T^.Text)do N:=N^.Next;
    if(N=Nil)or not N^.PublicName Then Begin Error(104,'export d''unite inconnu: '+T^.Text);Exit End;
    S:=N^.Replacement
   End else if not AfterDot and not((RecordDepth>0)and FieldName)Then Begin
    N:=A^.Names;While(N<>Nil)and(N^.Name<>S)do N:=N^.Next;
    if(N<>Nil)and not N^.UnitAlias Then S:=N^.Replacement
   End
  End;
  V:=T^.Trivia;While(V<>Nil)and not CPError do Begin
   { Ne pas introduire de saut au milieu d'un commentaire decoupe. }
   if OutputSize+Length(V^.Text)>65534 Then Begin
    Error(193,'commentaires et unites trop grands');Break
   End;
   Move(V^.Text[1],Output^[OutputSize],Length(V^.Text));Inc(OutputSize,Length(V^.Text));
   V:=V^.Next
  End;
  Emit(S);
  if IsWord(T,'RECORD')Then Begin Inc(RecordDepth);FieldName:=True End
  else if(RecordDepth>0)and IsWord(T,'END')Then Dec(RecordDepth)
  else if RecordDepth>0 Then Begin
   if T^.Text=':'Then FieldName:=False
   else if T^.Text=';'Then FieldName:=True
  End;
  AfterDot:=T^.Text='.';T:=T^.Next
 End
End;

Procedure EmitSection(Section:Integer);
Var A:PUnitSource;T:PToken;
Begin
 A:=Ordered;
 { Les dependances sont ajoutees en tete: leur declarations precedent celles
   des unites qui les utilisent. }
 While A<>Nil do Begin
  if Section=1 Then T:=A^.Constants else if Section=2 Then T:=A^.Types
  else if Section=3 Then T:=A^.Variables else T:=A^.Routines;
  EmitTokens(A,T,False);A:=A^.OrderNext
 End;
 if Section=1 Then T:=Root^.Constants else if Section=2 Then T:=Root^.Types
 else if Section=3 Then T:=Root^.Variables else T:=Root^.Routines;
 EmitTokens(Root,T,False)
End;

Procedure FreeTokens(T:PToken);
Var N:PToken;V,W:PTrivia;
Begin While T<>Nil do Begin
 N:=T^.AllocatedNext;V:=T^.Trivia;
 While V<>Nil do Begin W:=V^.Next;Dispose(V);V:=W End;
 Dispose(T);T:=N
End End;

Procedure FreeUnit(A:PUnitSource);
Var N,M:PName;
Begin
 N:=A^.Names;While N<>Nil do Begin M:=N^.Next;Dispose(N);N:=M End;Dispose(A)
End;

Procedure CaptureInterface(T:PToken);
Var S:String;I:Integer;
Begin
 CPInterfaceLength:=0;
 While(T<>Nil)and not IsWord(T,'IMPLEMENTATION')do Begin
  S:=T^.Text+' ';
  if CPInterfaceLength+Length(S)>65500 Then Begin
   Error(398,'interface d''unite trop grande');Exit
  End;
  For I:=1 to Length(S)do Begin
   CPInterfaceSource^[CPInterfaceLength]:=Ord(S[I]);Inc(CPInterfaceLength)
  End;T:=T^.Next
 End;
 S:='IMPLEMENTATION END. ';
 For I:=1 to Length(S)do Begin
  CPInterfaceSource^[CPInterfaceLength]:=Ord(S[I]);Inc(CPInterfaceLength)
 End
End;

Begin
 CPExpandUnits:=False;Units:=Nil;Ordered:=Nil;OrderTail:=Nil;
 CPCompilationIsUnit:=False;CPCompilationName:='PROGRAM';
 AllocatedTokens:=Nil;Counter:=0;OutputSize:=0;
 New(Root);FillChar(Root^,SizeOf(TUnitSource),0);Root^.Path:=SourceName;
 Root^.Tokens:=Tokenize;
 { Sans UNIT ni USES, conserve la source et ses commentaires/diagnostics. }
 U:=Nil;AllTokens:=Root^.Tokens;
 While(AllTokens<>Nil)and not IsWord(AllTokens,'USES')do AllTokens:=AllTokens^.Next;
 if(AllTokens=Nil)and not IsWord(Root^.Tokens,'UNIT')Then Begin
  FreeTokens(AllocatedTokens);Dispose(Root);CPExpandUnits:=not CPError;Exit
 End;
 if IsWord(Root^.Tokens,'UNIT')Then Begin
  if Root^.Tokens^.Next<>Nil Then Root^.Name:=Root^.Tokens^.Next^.Text;
  CPCompilationIsUnit:=True;CPCompilationName:=Root^.Name;
  if Length(CPCompilationName)>8 Then CPCompilationName:=Copy(CPCompilationName,1,8);
  CaptureInterface(Root^.Tokens);
  Root^.Prefix:='';ParseSource(Root,True)
 End else ParseSource(Root,False);
 GetMem(Output,SizeOf(TPCodeMemory));
 if not CPError Then Begin
  Emit('PROGRAM LINKED;');Emit('CONST');EmitSection(1);
  Emit('TYPE');EmitSection(2);Emit('VAR');EmitSection(3);EmitSection(4);
  Emit('BEGIN');U:=Ordered;
  While U<>Nil do Begin
   if IsWord(U^.Init,'BEGIN')Then Begin EmitTokens(U,U^.Init^.Next,True);Emit(';') End;
   U:=U^.OrderNext
  End;
  if IsWord(Root^.Init,'BEGIN')Then EmitTokens(Root,Root^.Init^.Next,True);
  Emit('END.');
  if not CPError Then Begin Move(Output^,CPSource^,OutputSize);CPSize:=OutputSize End
 End;
 FreeMem(Output,SizeOf(TPCodeMemory));
 { Le registre d'allocation libere aussi les en-tetes et signatures detaches. }
 FreeUnit(Root);U:=Units;While U<>Nil do Begin Units:=U^.Next;FreeUnit(U);U:=Units End;
 FreeTokens(AllocatedTokens);
 CPPos:=0;CPTokenPos:=0;CPLine:=1;CPExpandUnits:=not CPError
End;

Function CompilePascalPCode(SourceName,CodeName:String):Integer;
Label 99;

Var
 F:File;
 R:PPasRoutine;
 Sz:LongInt;
 N:Word;
 Names:Array[1..64]of String;
 NC,I:Integer;
 V,SavedPos,SavedLine:LongInt;
 Typ,TextType:PPasType;
Begin
 CompilePascalPCode:=1;CPSymbols:=Nil;CPTypes:=Nil;CPRoutines:=Nil;CPLabels:=Nil;
 CPRelocations:=Nil;
 CPCurrentRoutine:=Nil;CPPass:=1;CPNextProcedure:=1;
 CPTempNumber:=0;CPWithSymbol:=Nil;CPWithType:=Nil;CPDiagnosticFile:=SourceName;
 CPRangeChecks:=False;CPIOChecks:=True;CPOverflowChecks:=False;
 Typ:=CPAddType('INTEGER',ptkInteger,1);Typ^.LowBound:=-32768;Typ^.HighBound:=32767;
 Typ:=CPAddType('BOOLEAN',ptkBoolean,1);Typ^.LowBound:=0;Typ^.HighBound:=1;
 Typ:=CPAddType('CHAR',ptkChar,1);Typ^.LowBound:=0;Typ^.HighBound:=255;
 { Une cellule TPCodeData contient 32 bits: un REAL IEEE simple occupe donc
   une cellule VM, tout en restant serialise comme valeur 32 bits. }
 CPAddType('REAL',ptkReal,1);
 TextType:=CPAddType('STRING',ptkString,256);TextType^.HighBound:=255;
 TextType^.PackedType:=True;
 TextType:=CPAddType('TEXT',ptkFile,1);TextType^.ElementType:=CPFindType('CHAR');
 CPError:=False;CPHadErrors:=False;CPDiagnosticCount:=0;CPFirstErrorCode:=0;
 CPLine:=1;CPVarCount:=0;
 CPSize:=0;CPTokenPos:=0;
 GetMem(CPSource,SizeOf(TPCodeMemory));GetMem(PCode_Mem,SizeOf(TPCodeMemory));
 GetMem(CPInterfaceSource,SizeOf(TPCodeMemory));CPInterfaceLength:=0;
 Assign(F,SourceName);Reset(F,1);if IOResult<>0 Then Begin
  CPFailCode(410,'ouverture du source impossible');Goto 99
 End;
 Sz:=FileSize(F);if Sz>65534 Then Begin
  Close(F);CPFailCode(193,'source trop grand');Goto 99
 End;
 BlockRead(F,CPSource^,Sz,N);if(IOResult<>0)or(N<>Sz)Then
  CPFailCode(410,'erreur de lecture du source');
 Close(F);
 if IOResult<>0 Then CPFailCode(410,'erreur de fermeture du source');
 if CPError Then Goto 99;
 CPSize:=Sz;if not CPExpandIncludeFiles(SourceName)Then Goto 99;
 if not CPExpandUnits(SourceName)Then Goto 99;
 CPDeclarationPass;
 if CPError Then Goto 99;
 CPPass:=2;CPCurrentRoutine:=Nil;CPCodePos:=0;
 CPPos:=0;CPLine:=1;CPNext;
 if CPIs('PROGRAM')Then Begin
  CPNext;if CPToken='ID'Then CPNext;
  While(CPToken<>';')and(CPToken<>'EOF')do CPNext;CPNeed(';')
 End;
 if CPIs('LABEL')Then CPParseLabelSection;
 if CPIs('CONST')Then CPParseConstSection;
 if CPIs('TYPE')Then CPParseTypeSection;
 if CPIs('VAR')Then Begin
  CPNext;
  While(CPToken='ID')and not CPIs('BEGIN')and
  not CPIs('PROCEDURE')and not CPIs('FUNCTION')and not CPError do Begin
   NC:=0;
   Repeat Inc(NC);Names[NC]:=CPText;CPNext;
   if CPToken=','Then CPNext else Break Until NC=64;
   CPNeed(':');Typ:=CPParseType;
   if(Typ<>Nil)and(Typ^.Kind=ptkAlias)and(Typ^.SizeWords=0)Then
    CPFailCode(118,'type FORWARD dans une declaration de variable');
   CPNeed(';');
   For I:=1 to NC do Begin
    CPVarCount:=CPAlignedSize(CPVarCount,Typ^.AlignWords);
    CPAddTyped(Names[I],CPVarCount+1,False,Typ);Inc(CPVarCount,Typ^.SizeWords)
   End
  End
 End;
 SavedPos:=CPTokenPos;SavedLine:=CPLine;CPGenerateAllRoutines;
 if CPError Then Goto 99;
 CPCurrentRoutine:=Nil;CPPos:=SavedPos;CPLine:=SavedLine;CPNext;
 While CPIs('PROCEDURE')or CPIs('FUNCTION')do Begin
  CPNext;
  if CPToken<>'ID'Then Begin
   CPFail('nom de routine attendu');Break
  End;
  R:=CPFindRoutine(CPText,Nil);
  if R=Nil Then Begin
   CPFail('routine absente de la passe 1');Break
  End;
  CPPos:=R^.EndPosition;CPNext
 End;
 CPMainStart:=CPCodePos;CPCompound;
 if CPError Then Goto 99;
 CPCheckLabels(Nil);
 if CPToken='.'Then CPNext else CPFail('point final attendu');
 if CurrentTarget=ptUCSDPSystemIV Then Begin
  CPE($96);CPBig(0)
 End else CPE(214);
 CPMainLength:=CPCodePos-CPMainStart;
 if not CPError Then WriteUCSDCodeFile(CodeName,CPCompilationName,CPCodePos,CPVarCount);
 99:if not CPHadErrors Then CPReportUnused;CPFreeTables;
 FreeMem(CPInterfaceSource,SizeOf(TPCodeMemory));
 FreeMem(PCode_Mem,SizeOf(TPCodeMemory));FreeMem(CPSource,SizeOf(TPCodeMemory));
 if not CPError Then Begin
  WriteLn(CPCodePos,' octet(s) de p-Code.');CompilePascalPCode:=0
 End else if CPFirstErrorCode<>0 Then CompilePascalPCode:=CPFirstErrorCode
End;

Procedure AssembleCommand;
Var
 Name,OutputName:String;
 Code:Integer;
Begin
 Name:='';AskFile('Source assembleur p-Code',Name);if Name=''Then Exit;
 if not FileExists(Name)and FileExists(Name+'.ASM')Then Name:=Name+'.ASM';
 OutputName:=ReplaceExtension(Name,'.CODE');AskFile('Fichier p-Code produit',OutputName);
 if OutputName=''Then Exit;Code:=AssemblePCode(Name,OutputName);
 if Code=0 Then Begin
  ProgramFile:=OutputName;WriteLn('Assemblage termine.')
 End
 else if OriginalErrors Then WriteLn('UCSD error 500 (',CPUCSDErrorText(500),'): ',Code)
 else WriteLn('Erreur UCSD 500 (',CPUCSDErrorText(500),'): echec de l''assemblage (code ',Code,').')
End;

Function DebugHex(V:LongInt;N:Integer):String;
Const
 Digits:Array[0..15]of Char='0123456789ABCDEF';
Var
 S:String;
Begin
 S:='';
 While N>0 do Begin
  S:=Digits[V and 15]+S;V:=V shr 4;Dec(N)
 End;DebugHex:=S
End;

Function DebugNumber(S:String;Var V:LongInt):Boolean;
Var
 P:Integer;
 OK:Boolean;
Begin
 P:=1;OK:=ParseNum(P,S,V);SkipSp(P,S);
 DebugNumber:=OK and(P>Length(S))
End;

Function PCodeIVInstruction(Address:LongInt;Var NextAddress:LongInt):String;
Var
 Op,B,N:Byte;
 V,Used:Integer;
 S:String;
Begin
 Op:=PCode_Fetch(Address);NextAddress:=Address+1;S:='';
 if Op<=$1F Then S:='SLDC '+PCode_IntToStr(Op)
 else if(Op>=$20)and(Op<=$2F)Then S:='SLDL '+PCode_IntToStr(Op-$1F)
 else if(Op>=$30)and(Op<=$3F)Then S:='SLDO '+PCode_IntToStr(Op-$2F)
 else if(Op>=$60)and(Op<=$67)Then S:='SLLA '+PCode_IntToStr(Op-$5F)
 else if(Op>=$68)and(Op<=$6F)Then S:='SSTL '+PCode_IntToStr(Op-$67)
 else if(Op>=$78)and(Op<=$7F)Then S:='SIND '+PCode_IntToStr(Op-$78)
 else Case Op of
 $80:
 Begin
  S:='LDCB '+PCode_IntToStr(PCode_Fetch(Address+1));NextAddress:=Address+2
 End;
 $81:
 Begin
  S:='LDCI '+PCode_IntToStr(PCode_IVSignedWord(Address+1));NextAddress:=Address+3
 End;
 $84,$85,$86,$87,$96,$E6,$E7:
 Begin
  V:=PCode_ReadBig(Address+1,Used);NextAddress:=Address+1+Used;
  Case Op of $84:S:='LLA ';$85:S:='LDO ';$86:S:='LAO ';$87:S:='LDL ';
  $96:S:='RPU ';$E6:S:='IND ';else S:='INC '
 End;S:=S+PCode_IntToStr(V)
End;
$88,$89,$92:
Begin
 B:=PCode_Fetch(Address+1);
 if Op=$92 Then Begin
  N:=PCode_Fetch(Address+2);NextAddress:=Address+3;
  S:='CIP '+PCode_IntToStr(B)+','+PCode_IntToStr(N)
 End else
 Begin
  V:=PCode_ReadBig(Address+2,Used);NextAddress:=Address+2+Used;
  if Op=$88 Then S:='LDA 'else S:='LOD ';
  S:=S+PCode_IntToStr(B)+','+PCode_IntToStr(V)
 End
End;
$8A,$D2,$D3,$D4,$F1:
Begin
 Case Op of $8A:S:='UJP ';$D2:S:='EFJ ';$D3:S:='NFJ ';$D4:S:='FJP ';else S:='TJP '
End;
S:=S+PCode_IntToStr(ShortInt(PCode_Fetch(Address+1)));NextAddress:=Address+2
End;
$90,$91,$AC,$EF,$F0:
Begin
 B:=PCode_Fetch(Address+1);NextAddress:=Address+2;
 Case Op of $90:S:='CLP ';$91:S:='CGP ';$AC:S:='CSP ';$EF:S:='SCIP1 ';else S:='SCIP2 '
End;
S:=S+PCode_IntToStr(B)
End;
$93,$94:
Begin
 B:=PCode_Fetch(Address+1);N:=PCode_Fetch(Address+2);NextAddress:=Address+3;
 if Op=$93 Then S:='CXL 'else S:='CXG ';S:=S+PCode_IntToStr(B)+','+PCode_IntToStr(N)
End;
$8C:S:='MPI';$8D:S:='DVI';$8F:S:='MODI';$98:S:='LDCN';$9C:S:='NOP';
$9F:S:='BNOT';$A0:S:='LOR';$A1:S:='LAND';$A2:S:='ADI';$A3:S:='SBI';
$B0:S:='EQUI';$B1:S:='NEQI';$B2:S:='LEQI';$B3:S:='GEQI';$BD:S:='SWAP';
$C4:S:='STO';$CB:S:='CHK';$E0:S:='ABI';$E1:S:='NGI';$E2:S:='DUP1';
$E5:S:='LNOT';$ED:S:='INCI';$EE:S:='DECI';
else S:='DB $'+DebugHex(Op,2)
End;PCodeIVInstruction:=S
End;

Function PCodeInstruction(Address:LongInt;Var NextAddress:LongInt):String;
Var
 Op,Kind,B,N:Byte;
 Used,I:Integer;
 V:LongInt;
 S,T:String;
Begin
 NextAddress:=Address+1;
 if(Address<0)or(Address>=PCode_CodeSize)Then Begin
  PCodeInstruction:='<hors code>';Exit
 End;
 if CurrentTarget=ptUCSDPSystemIV Then Begin
  PCodeInstruction:=PCodeIVInstruction(Address,NextAddress);Exit
 End;
 Op:=PCode_Fetch(Address);
 if Op<128 Then Begin
  Str(Op,T);PCodeInstruction:='SLDC '+T;Exit
 End;
 S:=Mnem128[Op];Kind:=Kind128[Op];
 Case Kind of
 OPK_NONE:;
 OPK_UB:
 Begin
  B:=PCode_Fetch(Address+1);Str(B,T);S:=S+' '+T;NextAddress:=Address+2
 End;
 OPK_SB:
 Begin
  Str(ShortInt(PCode_Fetch(Address+1)),T);S:=S+' '+T;NextAddress:=Address+2
 End;
 OPK_W:
 Begin
  V:=PCode_Fetch(Address+1)or(PCode_Fetch(Address+2)shl 8);
  Str(V,T);S:=S+' '+T;NextAddress:=Address+3
 End;
 OPK_BIG:
 Begin
  V:=PCode_ReadBig(Address+1,Used);Str(V,T);S:=S+' '+T;NextAddress:=Address+1+Used
 End;
 OPK_UBUB:
 Begin
  Str(PCode_Fetch(Address+1),T);S:=S+' '+T+',';
  Str(PCode_Fetch(Address+2),T);S:=S+T;NextAddress:=Address+3
 End;
 OPK_UBBIG,OPK_DBBIG:
 Begin
  B:=PCode_Fetch(Address+1);V:=PCode_ReadBig(Address+2,Used);
  Str(B,T);S:=S+' ';if Kind=OPK_DBBIG Then S:=S+'L';S:=S+T+',';Str(V,T);S:=S+T;
  NextAddress:=Address+2+Used
 End;
 OPK_LSA:
 Begin
  N:=PCode_Fetch(Address+1);S:=S+' '+PCode_IntToStr(N)+',"';
  For I:=0 to N-1 do Begin
   B:=PCode_Fetch(Address+2+I);
   if B in[32..126]Then S:=S+Chr(B)else S:=S+'.'
  End;
  S:=S+'"';NextAddress:=Address+2+N
 End;
 OPK_LDC:
 Begin
  N:=PCode_Fetch(Address+1);S:=S+' '+PCode_IntToStr(N);
  For I:=0 to N-1 do Begin
   V:=PCode_Fetch(Address+2+I*2)or
   (PCode_Fetch(Address+3+I*2)shl 8);S:=S+',$'+DebugHex(V,4)
  End;
  NextAddress:=Address+2+N*2
 End;
 OPK_XJP:
 Begin
  V:=PCode_IVSignedWord(Address+1);N:=PCode_IVSignedWord(Address+3);
  S:=S+' '+PCode_IntToStr(V)+','+PCode_IntToStr(N);NextAddress:=Address+5;
  For I:=V to N do Begin
   S:=S+','+PCode_IntToStr(PCode_IVSignedWord(NextAddress));Inc(NextAddress,2)
  End
 End;
End;PCodeInstruction:=S
End;

Procedure DebugCommand;
Const
 MaxBreakpoints=16;
 MaxRunCycles=10000000;
Type
 PDebugRoutine=^TDebugRoutine;
 TDebugRoutine=Record ProcNo,Level,ParentNo:Integer;Start,Length:LongInt;
  Locals,Params,SourceLine:Integer;Name:String[31];Next:PDebugRoutine End;
 PDebugSymbol=^TDebugSymbol;
 TDebugSymbol=Record ProcNo,Address,Level:Integer;IsParam,ByRef:Boolean;
  TypeKind,SourceLine:Integer;Name:String[31];Next:PDebugSymbol End;
Var
 Name,Line,Command,Args,S:String;
 Breakpoint:Array[1..MaxBreakpoints]of LongInt;
 BreakCount,I,N:Integer;
 Address,V,NextAddress,RunCount:LongInt;
 Done,Hit:Boolean;
 DebugRoutines:PDebugRoutine;
 DebugSymbols:PDebugSymbol;

Function TakeField(Var X:String):String;
Var P:Integer;T:String;
Begin
 X:=TrimString(X);P:=Pos(' ',X);
 if P=0 Then Begin TakeField:=X;X:='' End
 else Begin T:=Copy(X,1,P-1);Delete(X,1,P);TakeField:=TrimString(T) End
End;

Function FieldInt(Var X:String):LongInt;
Var T:String;V:LongInt;C:Integer;
Begin T:=TakeField(X);Val(T,V,C);if C<>0 Then V:=0;FieldInt:=V End;

Procedure LoadDebugInfo;
Var F:Text;L,K:String;R:PDebugRoutine;Y:PDebugSymbol;
Begin
 DebugRoutines:=Nil;DebugSymbols:=Nil;Assign(F,ReplaceExtension(Name,'.DBG'));Reset(F);
 if IOResult<>0 Then Exit;
 While not Eof(F)do Begin
  ReadLn(F,L);if IOResult<>0 Then Break;K:=TakeField(L);
  if K='R'Then Begin
   New(R);FillChar(R^,SizeOf(TDebugRoutine),0);R^.ProcNo:=FieldInt(L);
   R^.Level:=FieldInt(L);R^.ParentNo:=FieldInt(L);R^.Start:=FieldInt(L);
   R^.Length:=FieldInt(L);R^.Locals:=FieldInt(L);R^.Params:=FieldInt(L);
   R^.SourceLine:=FieldInt(L);R^.Name:=TakeField(L);R^.Next:=DebugRoutines;DebugRoutines:=R
  End else if K='S'Then Begin
   New(Y);FillChar(Y^,SizeOf(TDebugSymbol),0);Y^.ProcNo:=FieldInt(L);
   Y^.Address:=FieldInt(L);Y^.Level:=FieldInt(L);Y^.IsParam:=FieldInt(L)<>0;
   Y^.ByRef:=FieldInt(L)<>0;Y^.TypeKind:=FieldInt(L);Y^.SourceLine:=FieldInt(L);
   Y^.Name:=TakeField(L);Y^.Next:=DebugSymbols;DebugSymbols:=Y
  End
 End;Close(F);if IOResult<>0 Then Begin End
End;

Procedure FreeDebugInfo;
Var R,Q:PDebugRoutine;S,T:PDebugSymbol;
Begin R:=DebugRoutines;While R<>Nil do Begin Q:=R^.Next;Dispose(R);R:=Q End;
 S:=DebugSymbols;While S<>Nil do Begin T:=S^.Next;Dispose(S);S:=T End
End;

Function CurrentDebugRoutine:PDebugRoutine;
Var R:PDebugRoutine;
Begin
 CurrentDebugRoutine:=Nil;R:=DebugRoutines;
 While R<>Nil do Begin
  if(PCode_PC>=R^.Start)and(PCode_PC<R^.Start+R^.Length)Then Begin
   CurrentDebugRoutine:=R;Exit
  End;R:=R^.Next
 End
End;

Procedure ShowSource;
Var R:PDebugRoutine;
Begin R:=CurrentDebugRoutine;if R=Nil Then WriteLn('Aucune information source pour cette adresse.')
 else WriteLn(R^.Name,' : ligne de declaration ',R^.SourceLine,
  ', niveau lexical ',R^.Level,', plage $',DebugHex(R^.Start,4),'..$',
  DebugHex(R^.Start+R^.Length-1,4))
End;

Procedure ShowFrames;
Var M:LongInt;R:PDebugRoutine;Depth,ProcNo:Integer;
Begin
 if not PCode_HasProcDictionary Then Begin WriteLn('Cadres structures indisponibles.');Exit End;
 M:=PCode_MP;Depth:=0;ProcNo:=PCode_CurrentProc;
 While(M>0)and(M<=High(PCode_Data^)-4)and(Depth<64)do Begin
  R:=DebugRoutines;While(R<>Nil)and(R^.ProcNo<>ProcNo)do R:=R^.Next;
  Write('#',Depth:2,' MP=',M,' PROC=',ProcNo);
  if R<>Nil Then Write(' ',R^.Name,' ligne ',R^.SourceLine);WriteLn;
  ProcNo:=PCode_DataAt(M+4);if PCode_DataAt(M+1)=M Then Break;
  M:=PCode_DataAt(M+1);Inc(Depth)
 End
End;

Procedure ShowSymbols(Const Filter:String);
Var Y:PDebugSymbol;R:PDebugRoutine;A,V:LongInt;Found:Boolean;
Begin
 R:=CurrentDebugRoutine;Y:=DebugSymbols;Found:=False;
 While Y<>Nil do Begin
  if((R<>Nil)and((Y^.ProcNo=R^.ProcNo)or(Y^.ProcNo=1))or
    ((R=Nil)and(Y^.ProcNo=1)))and
   ((Filter='')or(UpperString(Y^.Name)=UpperString(Filter)))Then Begin
   if Y^.ProcNo=1 Then A:=Y^.Address
   else if PCode_HasProcDictionary Then A:=PCode_MP+5+Y^.Address else A:=PCode_MP+Y^.Address;
   if Y^.ByRef Then A:=PCode_DataAt(A);V:=PCode_DataAt(A);Found:=True;
   WriteLn(Y^.Name:20,' @',A:5,' = ',V,'  type=',Y^.TypeKind,
    ' ligne=',Y^.SourceLine)
  End;Y:=Y^.Next
 End;if not Found Then WriteLn('Aucun symbole visible correspondant.')
End;

Function IsBreakpoint(A:LongInt):Boolean;
Var
 J:Integer;
Begin
 IsBreakpoint:=False;
 For J:=1 to BreakCount do if Breakpoint[J]=A Then Begin
  IsBreakpoint:=True;Exit
 End
End;

Procedure Registers;Begin
 WriteLn('PC=$',DebugHex(PCode_PC,4),'  SP=',PCode_SP,'  MP=',PCode_MP,
 '  PROC=',PCode_CurrentProc,'  cycles=',PCode_Cycles,'  sortie=',PCode_ExitCode);
 if not PCode_Halted Then WriteLn(DebugHex(PCode_PC,4),': ',
 PCodeInstruction(PCode_PC,NextAddress))else WriteLn('Machine arretee.')
End;

Procedure ResetMachine;Begin
 FillChar(PCode_Data^,SizeOf(TPCodeData),0);
 FillChar(PCode_ExternalData,SizeOf(PCode_ExternalData),0);
 PCode_InitFiles;PCode_StringHeap:=4096;PCode_PC:=0;PCode_SP:=0;PCode_MP:=0;
 PCode_Base:=0;PCode_CurrentProc:=0;PCode_Cycles:=0;
 PCode_Halted:=False;PCode_ExitCode:=0;
 if PCode_HasProcDictionary Then Begin
  PCode_SP:=High(PCode_Data^)+1;
  if PCode_ProcCount>0 Then PCode_IVCall(1,0,True)
  else
  Begin
   PCode_Halted:=True;PCode_ExitCode:=1
  End
 End
End;

Procedure DebugHelp;Begin
 WriteLn('S [n]       Executer une ou plusieurs instructions');
 WriteLn('G [adresse] Continuer jusqu''a un point d''arret');
 WriteLn('B [adresse] Poser ou afficher les points d''arret');
 WriteLn('BC adresse  Supprimer un point d''arret (BC ALL: tous)');
 WriteLn('U [a] [n]   Desassembler (10 instructions par defaut)');
 WriteLn('R            Afficher les registres de la VM');
 WriteLn('K [n]        Afficher la pile');
 WriteLn('M a [n]      Afficher la memoire de donnees');
 WriteLn('E a valeur   Modifier un mot de donnees');
 WriteLn('P adresse    Modifier le compteur programme');
 WriteLn('PROC [n]     Lister les procedures ou ouvrir la procedure n');
 WriteLn('V [nom]      Afficher les variables visibles et leur valeur');
 WriteLn('F            Afficher les cadres et la chaine dynamique');
 WriteLn('L            Afficher la position source symbolique');
 WriteLn('I            Reinitialiser le programme');
 WriteLn('Q            Quitter le debogueur')
End;
Begin
 Name:=ProgramFile;AskFile('Programme p-Code a deboguer',Name);if Name=''Then Exit;
 if not FileExists(Name)and FileExists(Name+'.CODE')Then Name:=Name+'.CODE';
 if not FileExists(Name)Then Begin
  WriteLn('Fichier introuvable: ',Name);Exit
 End;
 GetMem(PCode_Mem,SizeOf(TPCodeMemory));GetMem(PCode_Data,SizeOf(TPCodeData));
 if not PCode_LoadRaw(Name)Then Begin
  WriteLn('Chargement impossible.');
  FreeMem(PCode_Data,SizeOf(TPCodeData));FreeMem(PCode_Mem,SizeOf(TPCodeMemory));Exit
 End;
 ProgramFile:=Name;BreakCount:=0;FillChar(Breakpoint,SizeOf(Breakpoint),0);LoadDebugInfo;
 Done:=False;ResetMachine;
 WriteLn('Debogueur p-System interne - ',PCode_CodeSize,
 ' octet(s). Tapez ? pour l''aide.');
 Registers;
 Repeat
 Write('Debug> ');ReadLn(Line);Line:=TrimString(Line);if Line=''Then Command:='S'else
 Begin
  I:=Pos(' ',Line);if I=0 Then Begin
   Command:=UpperString(Line);Args:=''
  End
  else
  Begin
   Command:=UpperString(Copy(Line,1,I-1));Args:=TrimString(Copy(Line,I+1,255))
  End
 End;
 if(Command='?')or(Command='H')or(Command='HELP')Then DebugHelp
 else if Command='R'Then Registers
 else if Command='V'Then ShowSymbols(Args)
 else if Command='F'Then ShowFrames
 else if Command='L'Then ShowSource
 else if Command='I'Then Begin
  ResetMachine;Registers
 End
 else if Command='Q'Then Done:=True
 else if Command='PROC'Then Begin
  if not PCode_IsIVSegment Then WriteLn('Dictionnaire IV indisponible.')
  else if Args=''Then Begin
   For I:=1 to PCode_ProcCount do Begin
    Address:=(PCode_Fetch(PCode_ProcDict-I*2)or
    (PCode_Fetch(PCode_ProcDict-I*2+1)shl 8))*2;
    WriteLn('Procedure ',I:3,'  attribut=$',DebugHex(Address,4),
    '  entree=$',DebugHex(Address+2,4),'  locaux=',PCode_IVWord(Address))
   End
  End else if DebugNumber(Args,V)and(V>=1)and(V<=PCode_ProcCount)Then Begin
   Address:=(PCode_Fetch(PCode_ProcDict-V*2)or
   (PCode_Fetch(PCode_ProcDict-V*2+1)shl 8))*2;
   PCode_PC:=Address+2;WriteLn('Procedure ',V,' selectionnee.');Registers
  End else WriteLn('Numero de procedure incorrect.')
 End
 else if Command='P'Then Begin
  if DebugNumber(Args,Address)and(Address>=0)and(Address<PCode_CodeSize)Then Begin
   PCode_PC:=Address;PCode_Halted:=False;Registers
  End else WriteLn('Adresse incorrecte.')
 End
 else if Command='S'Then Begin
  if Args=''Then N:=1 else if DebugNumber(Args,V)Then N:=V else N:=0;
  if N<1 Then WriteLn('Nombre de pas incorrect.')else
  Begin
   For I:=1 to N do if not PCode_Halted Then Begin
    PCode_Step;Inc(PCode_Cycles)
   End;
   Registers
  End
 End
 else if Command='G'Then Begin
  if Args<>''Then if DebugNumber(Args,Address)and(Address>=0)and(Address<PCode_CodeSize)
  Then Begin
   PCode_PC:=Address;PCode_Halted:=False
  End else
  Begin
   WriteLn('Adresse incorrecte.');Continue
  End;
  RunCount:=0;Hit:=False;
  Repeat
  if IsBreakpoint(PCode_PC)Then Begin
   Hit:=True;Break
  End;
  if PCode_Fetch(PCode_PC)=213 Then Begin
   Hit:=True;WriteLn('Point BPT atteint.');Break
  End;
  PCode_Step;Inc(PCode_Cycles);Inc(RunCount)
  Until PCode_Halted or(RunCount>=MaxRunCycles);
  if Hit Then WriteLn('Point d''arret a $',DebugHex(PCode_PC,4));
  if RunCount>=MaxRunCycles Then WriteLn('Limite d''execution atteinte.');Registers
 End
 else if Command='B'Then Begin
  if Args=''Then Begin
   if BreakCount=0 Then WriteLn('Aucun point d''arret.');
   For I:=1 to BreakCount do WriteLn(I:2,': $',DebugHex(Breakpoint[I],4))
  End else if not DebugNumber(Args,Address)or(Address<0)or(Address>=PCode_CodeSize)
  Then    WriteLn('Adresse incorrecte.')
  else if IsBreakpoint(Address)Then WriteLn('Point d''arret deja present.')
  else if BreakCount=MaxBreakpoints Then WriteLn('Table des points d''arret pleine.')
  else
  Begin
   Inc(BreakCount);Breakpoint[BreakCount]:=Address;
   WriteLn('Point d''arret pose a $',DebugHex(Address,4))
  End
 End
 else if Command='BC'Then Begin
  if UpperString(Args)='ALL'Then BreakCount:=0
  else if DebugNumber(Args,Address)Then Begin
   I:=1;
   While(I<=BreakCount)and(Breakpoint[I]<>Address)do Inc(I);
   if I>BreakCount Then WriteLn('Point d''arret introuvable.')else
   Begin
    For N:=I to BreakCount-1 do Breakpoint[N]:=Breakpoint[N+1];Dec(BreakCount)
   End
  End else WriteLn('Adresse incorrecte.')
 End
 else if Command='U'Then Begin
  Address:=PCode_PC;N:=10;if Args<>''Then Begin
   I:=Pos(' ',Args);if I=0 Then Begin
    if not DebugNumber(Args,Address)Then N:=0
   End
   else
   Begin
    S:=Copy(Args,1,I-1);Delete(Args,1,I);Args:=TrimString(Args);
    if not DebugNumber(S,Address)or not DebugNumber(Args,V)Then N:=0 else N:=V
   End
  End;
  if(N<1)or(Address<0)or(Address>=PCode_CodeSize)Then WriteLn('Parametres incorrects.')
  else
  For I:=1 to N do if Address<PCode_CodeSize Then Begin
   S:=PCodeInstruction(Address,NextAddress);WriteLn(DebugHex(Address,4),': ',S);
   if NextAddress<=Address Then Address:=Address+1 else Address:=NextAddress
  End
 End
 else if Command='K'Then Begin
  if Args=''Then N:=16 else if DebugNumber(Args,V)Then N:=V else N:=0;
  if N<0 Then N:=0;
  if CurrentTarget=ptUCSDPSystemIV Then Begin
   if PCode_SP+N>High(PCode_Data^)+1 Then N:=High(PCode_Data^)+1-PCode_SP;
   For I:=PCode_SP to PCode_SP+N-1 do WriteLn(I:5,': ',PCode_Data^[I])
  End else
  Begin
   if N>PCode_SP Then N:=PCode_SP;
   For I:=PCode_SP-N to PCode_SP-1 do WriteLn(I:5,': ',PCode_Data^[I])
  End
 End
 else if Command='M'Then Begin
  I:=Pos(' ',Args);if I=0 Then Begin
   S:=Args;N:=16
  End else
  Begin
   S:=Copy(Args,1,I-1);Delete(Args,1,I);if not DebugNumber(TrimString(Args),V)Then V:=0;
   N:=V
  End;
  if not DebugNumber(S,Address)or(Address<0)or(Address>High(PCode_Data^))or(N<1)
  Then    WriteLn('Parametres incorrects.')else
  Begin
   if Address+N-1>High(PCode_Data^)Then N:=High(PCode_Data^)-Address+1;
   For I:=0 to N-1 do WriteLn(Address+I:5,': ',PCode_Data^[Address+I])
  End
 End
 else if Command='E'Then Begin
  I:=Pos(' ',Args);if I=0 Then WriteLn('Syntaxe: E adresse valeur')else
  Begin
   S:=Copy(Args,1,I-1);Delete(Args,1,I);
   if DebugNumber(S,Address)and DebugNumber(TrimString(Args),V)and
   (Address>=0)and(Address<=High(PCode_Data^))Then PCode_Data^[Address]:=V
   else WriteLn('Parametres incorrects.')
  End
 End else WriteLn('Commande inconnue. Tapez ? pour l''aide.')
 Until Done;
 FreeDebugInfo;FreeMem(PCode_Data,SizeOf(TPCodeData));FreeMem(PCode_Mem,SizeOf(TPCodeMemory))
End;

Procedure ListFiles;
Var
 Mask:String;
 Info:SearchRec;
Begin
 Mask:='*.*';AskFile('File mask',Mask);FindFirst(Mask,AnyFile,Info);
 if DosError<>0 Then Begin
  WriteLn('No files.');Exit
 End;
 While DosError=0 do Begin
  if(Info.Name<>'.')and(Info.Name<>'..')Then Begin
   Write(Info.Name:20);
   if(Info.Attr and Directory)<>0 Then WriteLn('   <DIR>')else WriteLn(Info.Size:10)
  End;FindNext(Info)
 End
End;

Procedure CopyFileCommand;
Var
 Source,Target:String;
 A,B:File;
 Buffer:Array[1..8192]of Byte;
 N,W:Word;
 OK:Boolean;
Begin
 Source:='';Target:='';AskFile('Copy from',Source);if Source=''Then Exit;
 AskFile('Copy to',Target);if Target=''Then Exit;
 if UpperString(FExpand(Source))=UpperString(FExpand(Target))Then Begin
  WriteLn('Source and destination are the same file.');Exit
 End;
 Assign(A,Source);Reset(A,1);if IOResult<>0 Then Begin
  WriteLn('Cannot open ',Source);Exit
 End;
 Assign(B,Target);Rewrite(B,1);if IOResult<>0 Then Begin
  Close(A);WriteLn('Cannot create ',Target);Exit
 End;
 OK:=True;
 Repeat
 BlockRead(A,Buffer,SizeOf(Buffer),N);if IOResult<>0 Then Begin
  OK:=False;Break
 End;
 if N<>0 Then Begin
  BlockWrite(B,Buffer,N,W);if(IOResult<>0)or(W<>N)Then OK:=False
 End
 Until(N=0)or not OK;
 Close(A);if IOResult<>0 Then OK:=False;Close(B);if IOResult<>0 Then OK:=False;
 if OK Then WriteLn('Copy complete.')else WriteLn('Copy failed.')
End;

Procedure RenameFileCommand;
Var
 OldName,NewName:String;
 F:File;
Begin
 OldName:='';NewName:='';AskFile('Rename file',OldName);if OldName=''Then Exit;
 AskFile('New name',NewName);if NewName=''Then Exit;
 Assign(F,OldName);Rename(F,NewName);
 if IOResult<>0 Then WriteLn('Rename failed.')else WriteLn('Rename complete.')
End;

Procedure DeleteFileCommand;
Var
 Name,Answer:String;
 F:File;
Begin
 Name:='';AskFile('Delete file',Name);if Name=''Then Exit;
 Write('Delete ',Name,' (Y/N)? ');ReadLn(Answer);
 if(Answer='')or not(UpCase(Answer[1])='Y')Then Exit;
 Assign(F,Name);Erase(F);
 if IOResult<>0 Then WriteLn('Delete failed.')else WriteLn('Deleted.')
End;

Procedure VolumeCommand;
Var
 DirectoryName:String;
Begin
 GetDir(0,DirectoryName);WriteLn('Current volume and directory: ',DirectoryName);
 WriteLn('Free bytes: ',DiskFree(0));WriteLn('Total bytes: ',DiskSize(0))
End;

Procedure WhatWorkFile;
Var F:File;N:LongInt;
Begin
 WriteLn('Nom du fichier de travail: ',WorkTitle);
 Write('  Texte: ',WorkFile);
 if FileExists(WorkFile)Then Begin
  Assign(F,WorkFile);Reset(F,1);if IOResult=0 Then Begin N:=FileSize(F);Close(F);
   if IOResult<>0 Then Begin End;WriteLn(' (',N,' octets)') End
  else WriteLn(' (illisible)')
 End else WriteLn(' (absent)');
 Write('  Code : ',ProgramFile);
 if FileExists(ProgramFile)Then Begin
  Assign(F,ProgramFile);Reset(F,1);if IOResult=0 Then Begin N:=FileSize(F);Close(F);
   if IOResult<>0 Then Begin End;WriteLn(' (',N,' octets)') End
  else WriteLn(' (illisible)')
 End else WriteLn(' (absent)');
 if FileExists('SYSTEM.WRK.BACK')Then WriteLn('  Sauvegarde precedente: SYSTEM.WRK.BACK')
End;

Procedure GetWorkFile;
Var Name,CodeName,Answer:String;
Begin
 Name:='';AskFile('Fichier a charger comme travail',Name);if Name=''Then Exit;
 Name:=WorkTextName(Name);if not FileExists(Name)Then Begin
  WriteLn('Fichier introuvable: ',Name);Exit
 End;
 if FileExists('SYSTEM.WRK.TEXT')Then Begin
  Write('Remplacer le fichier de travail courant (O/N) ? ');ReadLn(Answer);
  Answer:=UpperString(TrimString(Answer));if(Answer<>'O')and(Answer<>'OUI')Then Exit
 End;
 if not CopyHostFile(Name,'SYSTEM.WRK.TEXT')Then Begin WriteLn('Chargement impossible.');Exit End;
 CodeName:=AssociatedCodeName(Name);RemoveHostFile('SYSTEM.WRK.CODE');
 if FileExists(CodeName)Then if not CopyHostFile(CodeName,'SYSTEM.WRK.CODE')Then
  WriteLn('Avertissement: la partie CODE n''a pas pu etre chargee.');
 WorkFile:='SYSTEM.WRK.TEXT';ProgramFile:='SYSTEM.WRK.CODE';WorkTitle:=Name;
 WriteLn('Fichier de travail charge.');WhatWorkFile
End;

Procedure NewWorkFile;
Var Answer:String;
Begin
 Write('Abandonner le fichier de travail courant (O/N) ? ');ReadLn(Answer);
 Answer:=UpperString(TrimString(Answer));if(Answer<>'O')and(Answer<>'OUI')Then Exit;
 RemoveHostFile('SYSTEM.WRK.TEXT');RemoveHostFile('SYSTEM.WRK.CODE');
 RemoveHostFile('SYSTEM.WRK.BACK');WorkFile:='SYSTEM.WRK.TEXT';
 ProgramFile:='SYSTEM.WRK.CODE';WorkTitle:='SANS NOM';
 WriteLn('Nouveau fichier de travail vide.')
End;

Procedure SaveWorkFile;
Var Name,CodeName:String;
Begin
 if not FileExists(WorkFile)Then Begin WriteLn('Aucune partie TEXT a sauvegarder.');Exit End;
 Name:='';if(WorkTitle<>'')and(UpperString(WorkTitle)<>'SANS NOM')Then Name:=WorkTitle;
 AskFile('Nom de sauvegarde',Name);if Name=''Then Exit;Name:=WorkTextName(Name);
 if not CopyHostFile(WorkFile,Name)Then Begin WriteLn('Sauvegarde TEXT impossible.');Exit End;
 CodeName:=AssociatedCodeName(Name);
 if FileExists(ProgramFile)Then Begin
  if not CopyHostFile(ProgramFile,CodeName)Then Begin WriteLn('Sauvegarde CODE impossible.');Exit End
 End;
 WorkTitle:=Name;WriteLn('Fichier de travail sauvegarde sous ',Name,'.')
End;

Procedure FileCommand;
Var
 S:String;
 Done:Boolean;
Begin
 Done:=False;Repeat
 Write('Fichier: G(et, N(ouveau, S(auver, W(hat, L(iste, T(ransfert, ');
 Write('R(enommer, D(effacer, V(olume, Q(uit ? ');ReadLn(S);
 S:=UpperString(TrimString(S));if S=''Then Continue;
 Case S[1]of
 'G':GetWorkFile;
 'N':NewWorkFile;
 'S':SaveWorkFile;
 'W':WhatWorkFile;
 'L':ListFiles;
 'T','C':CopyFileCommand;
 'R':RenameFileCommand;
 'D':DeleteFileCommand;
 'V':VolumeCommand;
 'Q':Done:=True;
 '?':Begin
  WriteLn('Get charge un fichier dans SYSTEM.WRK.TEXT et sa partie CODE.');
  WriteLn('Nouveau efface SYSTEM.WRK.TEXT, SYSTEM.WRK.CODE et SYSTEM.WRK.BACK.');
  WriteLn('Sauver copie les parties TEXT et CODE sous le nom indique.');
  WriteLn('What affiche l''etat du fichier de travail courant.');
  WriteLn('Liste, Transfert, Renommage, Effacement, Volume et Quitter gerent les fichiers.')
 End;
 else WriteLn('Commande de fichier inconnue.')
End
Until Done
End;

Procedure Help;Begin
 WriteLn('E  Editer le fichier source de travail');
 WriteLn('R  Compiler si necessaire, puis executer le programme de travail');
 WriteLn('F  Ouvrir le gestionnaire de fichiers');
 WriteLn('C  Compiler le fichier source Pascal courant');
 WriteLn('L  Lier des fichiers objets');
 WriteLn('X  Executer un fichier p-Code .CODE avec la machine virtuelle integree');
 WriteLn('A  Assembler un fichier source');
 WriteLn('D  Lancer le debogueur p-Code integre');
 WriteLn('Q  Quitter PSYSTEM');
 WriteLn('/TARGET:nom  Choisir la version du p-System cible');
 WriteLn('  APPLEHEALT, UCSDPASCALII, UCSDPSYSTEMIII ou UCSDPSYSTEMIV');
 WriteLn('/ORGINALERR  Afficher les messages d''erreur UCSD originaux en anglais');
 WriteLn('/LIST         Afficher le listing du source compile');
 WriteLn('/CHECKCODE   Verifier les segments et dictionnaires sans executer');
 WriteLn('PSYSTEM_LIBRARY indique le repertoire des unites SYSTEM et bibliotheques .CODE.');
 WriteLn('Sans nom de fichier, le travail courant est SYSTEM.WRK.TEXT / SYSTEM.WRK.CODE.');
 WriteLn('Le gestionnaire F fournit G(et, N(ouveau, S(auver et W(hat.');
 WriteLn('Cible courante: ',TargetName);
 WriteLn;
 WriteLn('L''editeur de lignes est integre a la commande E.');
 WriteLn(
 'Le compilateur, l''assembleur, le linker, l''executeur et le debogueur p-Code sont integres.')
End;

Procedure Prompt;
Var
 S:String;
Begin
 WriteLn;
 Write('Command: E(dit, R(un, F(ile, C(omp, L(ink, ');
 Write('X(ecute, A(ssem, D(ebug, Q)uit ? ');ReadLn(S);S:=UpperString(TrimString(S));
 if S=''Then Exit;
 Case S[1]of
 'E':EditCommand;
 'R':RunCommand;
 'F':FileCommand;
 'C':if CompileWork(False)Then Begin
 End;
 'L':LinkCommand;
 'X':ExecuteCommand;
 'A':AssembleCommand;
 'D':DebugCommand;
 'Q':Finished:=True;
 '?':Help;
 else WriteLn('Unknown command. Type ? for help.')
End
End;

Procedure CommandLine;
Var
 I:Integer;
 S:String;
Begin
 { Le jeu d'opcodes de la machine virtuelle et de l'assembleur integres
   correspond par defaut a UCSD Pascal II.0/II.1. }
 WorkFile:='';ProgramFile:='';WorkTitle:='';CurrentTarget:=ptUCSDPascalII;
 OriginalErrors:=False;CPListing:=False;
 CheckCodeRequested:=False;
 For I:=1 to ParamCount do Begin
  S:=ParamStr(I);
  if(S='/?')or(S='-?')or(UpperString(S)='HELP')Then Begin
   WriteLn('PSYSTEM ',Version,' - Cette commande permet lancer ',
   'l''environnement de commande UCSD p-System.');
   Help;
   Halt(0)
  End else if UpperString(S)='/CHECKCODE'Then CheckCodeRequested:=True
  else if(UpperString(S)='/LIST')or(UpperString(S)='-LIST')Then CPListing:=True
  else if(UpperString(S)='/ORGINALERR')or(UpperString(S)='/ORIGINALERR')Then
   OriginalErrors:=True
  else if(Copy(UpperString(S),1,8)='/TARGET:')or
  (Copy(UpperString(S),1,8)='-TARGET:')Then Begin
   if not SelectTarget(Copy(S,9,255))Then Begin
    WriteLn('Cible p-System inconnue: ',Copy(S,9,255));Halt(1)
   End
  End else if WorkFile=''Then WorkFile:=S
  else
  Begin
   WriteLn('Syntaxe : PSYSTEM [fichier] [/TARGET:cible] [/ORGINALERR] [/LIST] [/CHECKCODE]');
   Halt(1)
  End
 End;
 if CheckCodeRequested Then Begin
  if WorkFile=''Then Begin WriteLn('/CHECKCODE exige un fichier CODE.');Halt(1) End;
  if CheckUCSDCodeFile(WorkFile)Then Halt(0)else Halt(1)
 End;
 if WorkFile=''Then Begin
  WorkFile:='SYSTEM.WRK.TEXT';ProgramFile:='SYSTEM.WRK.CODE';WorkTitle:='SYSTEM.WRK'
 End else Begin
  ProgramFile:=AssociatedCodeName(WorkFile);WorkTitle:=WorkFile
 End
End;

Procedure RunStartupFile;
Var Code:Integer;
Begin
 if not FileExists('SYSTEM.STARTUP')Then Exit;
 WriteLn('Execution de SYSTEM.STARTUP ...');Code:=ExecutePCodeFile('SYSTEM.STARTUP');
 if Code<>0 Then WriteLn('SYSTEM.STARTUP s''est termine avec le code ',Code,'.')
End;

BEGIN
 CommandLine;Finished:=False;
 WriteLn('UCSD p-System compatible command environment ',Version);
 WriteLn('Cible: ',TargetName);
 WriteLn('Fichier de travail: ',WorkTitle);
 WriteLn('  TEXT: ',WorkFile,'   CODE: ',ProgramFile);
 RunStartupFile;
 Repeat Prompt Until Finished;
 WriteLn('System halted.')
END.
