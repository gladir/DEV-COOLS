{ REPASCAL - Reformateur Pascal compatible Turbo Pascal / Free Pascal. }
Program REPASCAL;

Uses Dos;

{$I-}

Const MaxLineLength = 255;

Type
 TCommentState = (csNone,csBrace,csParen);
 {$IFDEF FPC}
 TSourceString = AnsiString;
 {$ELSE}
 TSourceString = String;
 {$ENDIF}

Var
 SourceName,TempName,BackupName,ProgramName:String;
 InputFile,OutputFile:Text;
 IsUnit,HasProgram,HadError:Boolean;
 BeginTotal,EndTotal,BeginNumber,EndNumber,IndentLevel,MainBeginNumber,MainEndNumber:LongInt;
 BlockTop:Integer;BlockKind:Array[1..255]of Char;BlockBegin:Array[1..255]of LongInt;
 CommentState:TCommentState;
 OutLine:TSourceString;PreserveCommentIndent,AwaitingThenBegin:Boolean;

Function UpperString(Const S:String):String;
Var R:String;I:Integer;
Begin R:=S;For I:=1 to Length(R)do R[I]:=UpCase(R[I]);UpperString:=R;End;

Function IsIdentStart(C:Char):Boolean;
Begin IsIdentStart:=C in ['A'..'Z','a'..'z','_'];End;

Function IsIdentChar(C:Char):Boolean;
Begin IsIdentChar:=C in ['A'..'Z','a'..'z','_','0'..'9'];End;

Function SameText(Const A,B:String):Boolean;
Begin SameText:=UpperString(A)=UpperString(B);End;

Function FileBase(Const S:String):String;
Var I,First,Dot:Integer;
Begin
 First:=1;Dot:=0;For I:=1 to Length(S)do
  If S[I]in['\','/',':']Then Begin First:=I+1;Dot:=0;End Else If S[I]='.'Then Dot:=I;
 If Dot=0 Then Dot:=Length(S)+1;FileBase:=Copy(S,First,Dot-First);
End;

Function ReplaceExtension(Const S,Ext:String):String;
Var I,Dot:Integer;
Begin Dot:=0;For I:=Length(S)downto 1 do Begin If S[I]='.'Then Begin Dot:=I;Break;End;If S[I]in['\','/',':']Then Break;End;
 If Dot=0 Then ReplaceExtension:=S+Ext Else ReplaceExtension:=Copy(S,1,Dot-1)+Ext;
End;

Procedure Error(Const S:String);
Begin WriteLn('REPASCAL: ',S);HadError:=True;End;

Procedure Usage;
Begin
 WriteLn('REPASCAL - Reformate un fichier source Pascal.');WriteLn;
 WriteLn('Syntaxe : REPASCAL fichier.pas');
End;

Function ReadSourceLine(Var T:Text;Var L:TSourceString):Boolean;
{$IFDEF FPC}
Begin
 ReadSourceLine:=False;If Eof(T)Then Exit;ReadLn(T,L);
 If IOResult<>0 Then Begin Error('erreur de lecture');Exit;End;ReadSourceLine:=True;
End;
{$ELSE}
Var C:Char;TooLong:Boolean;
Begin
 ReadSourceLine:=False;If Eof(T)Then Exit;L:='';TooLong:=False;
 While not Eoln(T)do Begin Read(T,C);If IOResult<>0 Then Begin Error('erreur de lecture');Exit;End;
  If Length(L)<255 Then L:=L+C Else TooLong:=True;
 End;ReadLn(T);If IOResult<>0 Then Begin Error('erreur de lecture');Exit;End;
 If TooLong Then Begin Error('ligne de plus de 255 caracteres: Turbo Pascal ne peut pas la reformater sans perte');Exit;End;
 ReadSourceLine:=True;
End;
{$ENDIF}

Procedure CountLine(Const L:TSourceString;Var State:TCommentState;Var FirstFound:Boolean);
Var I,J:Integer;W:String;C:Char;
Begin I:=1;While I<=Length(L)do Begin C:=L[I];
 If State=csBrace Then Begin If C='}'Then State:=csNone;Inc(I);Continue;End;
 If State=csParen Then Begin If(C='*')and(I<Length(L))and(L[I+1]=')')Then Begin State:=csNone;Inc(I,2);End Else Inc(I);Continue;End;
 If C='{'Then Begin State:=csBrace;Inc(I);Continue;End;
 If(C='(')and(I<Length(L))and(L[I+1]='*')Then Begin State:=csParen;Inc(I,2);Continue;End;
 If(C='/')and(I<Length(L))and(L[I+1]='/')Then Exit;
 If C=''''Then Begin Inc(I);While I<=Length(L)do Begin If L[I]=''''Then Begin If(I<Length(L))and(L[I+1]='''')Then Inc(I,2)Else Begin Inc(I);Break;End;End Else Inc(I);End;Continue;End;
 If IsIdentStart(C)Then Begin J:=I;While(I<=Length(L))and IsIdentChar(L[I])do Inc(I);W:=Copy(L,J,I-J);
  If not FirstFound Then Begin FirstFound:=True;HasProgram:=SameText(W,'PROGRAM');IsUnit:=SameText(W,'UNIT');End;
  If SameText(W,'BEGIN')Then Begin Inc(BeginTotal);If BlockTop=255 Then Begin Error('imbrication Pascal trop profonde');Exit;End;Inc(BlockTop);BlockKind[BlockTop]:='B';BlockBegin[BlockTop]:=BeginTotal;End
  Else If SameText(W,'CASE')or SameText(W,'RECORD')or SameText(W,'TRY')or SameText(W,'ASM')or SameText(W,'OBJECT')Then Begin If BlockTop=255 Then Begin Error('imbrication Pascal trop profonde');Exit;End;Inc(BlockTop);BlockKind[BlockTop]:='X';BlockBegin[BlockTop]:=0;End
  Else If SameText(W,'END')Then Begin Inc(EndTotal);If BlockTop>0 Then Begin If BlockKind[BlockTop]='B'Then Begin MainBeginNumber:=BlockBegin[BlockTop];MainEndNumber:=EndTotal;End;Dec(BlockTop);End;End;Continue;
 End;Inc(I);End;
End;

Procedure FirstPass;
Var L:TSourceString;FirstFound:Boolean;
Begin
 BeginTotal:=0;EndTotal:=0;MainBeginNumber:=0;MainEndNumber:=0;BlockTop:=0;IsUnit:=False;HasProgram:=False;CommentState:=csNone;FirstFound:=False;
 Assign(InputFile,SourceName);Reset(InputFile);If IOResult<>0 Then Begin Error('impossible d''ouvrir '+SourceName);Exit;End;
 While ReadSourceLine(InputFile,L)do CountLine(L,CommentState,FirstFound);
 Close(InputFile);If IOResult<>0 Then Error('erreur de fermeture du fichier source');
End;

Function TrimLine(Const S:TSourceString):TSourceString;
Var A,B:LongInt;
Begin A:=1;While(A<=Length(S))and(S[A]=' ')do Inc(A);B:=Length(S);While(B>=A)and(S[B]=' ')do Dec(B);TrimLine:=Copy(S,A,B-A+1);End;

Procedure AppendText(Const S:TSourceString);
Var T:TSourceString;I:LongInt;
Begin T:=S;For I:=1 to Length(T)do If T[I]=#9 Then T[I]:=' ';
 {$IFNDEF FPC}
 If Length(OutLine)+Length(T)>MaxLineLength Then Begin Error('ligne produite trop longue');Exit;End;OutLine:=OutLine+T;
 {$ELSE}
 OutLine:=OutLine+T;
 {$ENDIF}
End;

Procedure AppendComment(Const S:TSourceString);
Begin
 {$IFNDEF FPC}
 If Length(OutLine)+Length(S)>MaxLineLength Then Begin Error('ligne de commentaire trop longue');Exit;End;OutLine:=OutLine+S;
 {$ELSE}
 OutLine:=OutLine+S;
 {$ENDIF}
End;

Procedure EmitLine;
Var S:TSourceString;I:LongInt;
Begin
 If PreserveCommentIndent Then S:=OutLine Else S:=TrimLine(OutLine);OutLine:='';
 If S=''Then Begin WriteLn(OutputFile);PreserveCommentIndent:=False;Exit;End;
 If not PreserveCommentIndent Then For I:=1 to IndentLevel do Write(OutputFile,' ');WriteLn(OutputFile,S);PreserveCommentIndent:=False;AwaitingThenBegin:=False;
 If IOResult<>0 Then Error('erreur d''ecriture');
End;

Procedure EmitPending;
Begin If TrimLine(OutLine)<>''Then EmitLine Else OutLine:='';End;

Procedure FormatLine(Const L:TSourceString;Var State:TCommentState;Var SkipProgram:Boolean);
Var I,J:LongInt;W,U,S:String;C:Char;
Begin I:=1;PreserveCommentIndent:=State<>csNone;While(I<=Length(L))and not HadError do Begin C:=L[I];
 If State=csBrace Then Begin AwaitingThenBegin:=False;J:=I;While(I<=Length(L))and(L[I]<>'}')do Inc(I);If I<=Length(L)Then Begin Inc(I);State:=csNone;End;AppendComment(Copy(L,J,I-J));Continue;End;
 If State=csParen Then Begin AwaitingThenBegin:=False;J:=I;While I<=Length(L)do Begin If(L[I]='*')and(I<Length(L))and(L[I+1]=')')Then Begin Inc(I,2);State:=csNone;Break;End;Inc(I);End;AppendComment(Copy(L,J,I-J));Continue;End;
 If C='{'Then Begin AwaitingThenBegin:=False;If TrimLine(OutLine)=''Then PreserveCommentIndent:=True;State:=csBrace;J:=I;Inc(I);While(I<=Length(L))and(L[I]<>'}')do Inc(I);If I<=Length(L)Then Begin Inc(I);State:=csNone;End;AppendComment(Copy(L,J,I-J));Continue;End;
 If(C='(')and(I<Length(L))and(L[I+1]='*')Then Begin AwaitingThenBegin:=False;If TrimLine(OutLine)=''Then PreserveCommentIndent:=True;State:=csParen;J:=I;Inc(I,2);While I<=Length(L)do Begin If(L[I]='*')and(I<Length(L))and(L[I+1]=')')Then Begin Inc(I,2);State:=csNone;Break;End;Inc(I);End;AppendComment(Copy(L,J,I-J));Continue;End;
 If(C='/')and(I<Length(L))and(L[I+1]='/')Then Begin AwaitingThenBegin:=False;If TrimLine(OutLine)=''Then PreserveCommentIndent:=True;AppendComment(Copy(L,I,Length(L)-I+1));Break;End;
 If C=''''Then Begin J:=I;Inc(I);While I<=Length(L)do Begin If L[I]=''''Then Begin If(I<Length(L))and(L[I+1]='''')Then Inc(I,2)Else Begin Inc(I);Break;End;End Else Inc(I);End;If not SkipProgram Then AppendText(Copy(L,J,I-J));Continue;End;
 If IsIdentStart(C)Then Begin J:=I;While(I<=Length(L))and IsIdentChar(L[I])do Inc(I);W:=Copy(L,J,I-J);U:=UpperString(W);
  If SkipProgram Then Continue;
  If U='BEGIN'Then Begin Inc(BeginNumber);If not AwaitingThenBegin Then EmitPending;If(not IsUnit)and(BeginNumber=MainBeginNumber)Then S:='BEGIN'Else S:='Begin';AppendText(S);EmitLine;Inc(IndentLevel);End
  Else If U='END'Then Begin Inc(EndNumber);EmitPending;If IndentLevel>0 Then Dec(IndentLevel);If(not IsUnit)and(EndNumber=MainEndNumber)Then S:='END'Else S:='End';AppendText(S);End
  Else If U='THEN'Then Begin AppendText('Then');AwaitingThenBegin:=True;End
  Else Begin AppendText(W);AwaitingThenBegin:=False;End;Continue;
 End;
 If SkipProgram Then Begin If C=';'Then SkipProgram:=False;Inc(I);Continue;End;
 AppendText(C);If not(C in[' ',#9])Then AwaitingThenBegin:=False;Inc(I);
 End;
 If(TrimLine(OutLine)<>'')and not AwaitingThenBegin Then EmitLine Else If(TrimLine(OutLine)='')and not SkipProgram Then OutLine:='';
End;

Procedure SecondPass;
Var L:TSourceString;SkipProgram:Boolean;
Begin
 Assign(InputFile,SourceName);Reset(InputFile);If IOResult<>0 Then Begin Error('impossible de relire le fichier');Exit;End;
 Assign(OutputFile,TempName);Rewrite(OutputFile);If IOResult<>0 Then Begin Close(InputFile);Error('impossible de creer le fichier temporaire');Exit;End;
 OutLine:='';PreserveCommentIndent:=False;AwaitingThenBegin:=False;IndentLevel:=0;BeginNumber:=0;EndNumber:=0;CommentState:=csNone;SkipProgram:=HasProgram and not IsUnit;
 If not IsUnit Then WriteLn(OutputFile,'Program ',ProgramName,';');
 While not HadError and ReadSourceLine(InputFile,L)do FormatLine(L,CommentState,SkipProgram);
 Close(InputFile);Close(OutputFile);If IOResult<>0 Then Error('erreur de fermeture du fichier temporaire');
End;

Procedure InstallResult;
Var OldFile,NewFile,BakFile:File;
Begin
 Assign(BakFile,BackupName);Erase(BakFile);If IOResult<>0 Then Begin End;
 Assign(OldFile,SourceName);Rename(OldFile,BackupName);If IOResult<>0 Then Begin Error('impossible de creer la sauvegarde '+BackupName);Exit;End;
 Assign(NewFile,TempName);Rename(NewFile,SourceName);If IOResult<>0 Then Begin
  Assign(BakFile,BackupName);Rename(BakFile,SourceName);If IOResult<>0 Then Begin End;Error('impossible d''installer le fichier reformate');Exit;
 End;
End;

Begin
 HadError:=False;
 If ParamCount<>1 Then Begin Usage;Halt(1);End;
 SourceName:=ParamStr(1);TempName:=ReplaceExtension(SourceName,'.$$$');BackupName:=ReplaceExtension(SourceName,'.BAK');
 ProgramName:=UpperString(FileBase(SourceName));If ProgramName=''Then Begin Error('nom de fichier invalide');Halt(1);End;
 If ProgramName[1]in['0'..'9']Then ProgramName:='_'+ProgramName;
 FirstPass;If HadError Then Halt(1);SecondPass;If HadError Then Halt(1);InstallResult;
 If HadError Then Halt(1);WriteLn('Fichier reformate. Sauvegarde: ',BackupName);
End.
