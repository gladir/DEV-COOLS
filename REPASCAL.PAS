Program REPASCAL;
{ REPASCAL - Reformateur Pascal compatible Turbo Pascal / Free Pascal. }

Uses Dos;

{$I-}
Const
 MaxLineLength = 255;
 MaxFormattedWidth = 90;

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
 BeginTotal,EndTotal,BeginNumber,EndNumber,IndentLevel,MainBeginNumber,
 MainEndNumber:LongInt;
 BlockTop:Integer;
 BlockKind:Array[1..255]of Char;
 BlockBegin:Array[1..255]of LongInt;
 CommentState:TCommentState;
 OutLine:TSourceString;
 PreserveCommentIndent,AwaitingThenBegin,AwaitingDoBegin:Boolean;
 RoutineHeader,AwaitingRoutineBegin,RoutineNeedsBlank,DeclarationSection,
 DeclarationIsLocal,UsesSection,AfterUsesBlank:Boolean;
 ParenthesisLevel,ConditionalLevel:Integer;
 MetadataComment,MetadataCandidate:TSourceString;
 MetadataFound,MetadataCapture,MetadataSkipped,SuppressMetadata:Boolean;

Function UpperString(Const S:String):String;
Var
 R:String;
 I:Integer;
Begin
 R:=S;
 For I:=1 to Length(R)do R[I]:=UpCase(R[I]);UpperString:=R;
End;

Function CollapseSpaces(Const S:TSourceString):TSourceString;
Var R:TSourceString;I:LongInt;PendingSpace:Boolean;
Begin
 R:='';PendingSpace:=False;For I:=1 to Length(S)do
  If S[I]in[' ',#9,#13,#10]Then PendingSpace:=Length(R)>0
  Else Begin If PendingSpace Then R:=R+' ';R:=R+S[I];PendingSpace:=False;End;
 CollapseSpaces:=R;
End;

Function FormatMetadataComment(Const S:TSourceString):TSourceString;
Var Flat,R:TSourceString;I:LongInt;SeenTag:Boolean;
Begin
 Flat:=CollapseSpaces(S);R:='';SeenTag:=False;I:=1;
 While I<=Length(Flat)do Begin
  If Flat[I]='@'Then Begin
   If SeenTag and(I>1)and(Flat[I-1]=' ')Then Begin
    While(Length(R)>0)and(R[Length(R)]=' ')do Delete(R,Length(R),1);
    R:=R+#13#10+' ';
   End;SeenTag:=True;
  End;R:=R+Flat[I];Inc(I);
 End;FormatMetadataComment:=R;
End;

Procedure CaptureMetadataLine(Const L:TSourceString);
Var I,J:LongInt;Piece:TSourceString;
Begin
 If MetadataFound Then Exit;I:=1;
 If not MetadataCapture Then Begin While(I<=Length(L))and(L[I]<>'{')do Inc(I);
  If I>Length(L)Then Exit;MetadataCandidate:='';MetadataCapture:=True;
 End;
 J:=I;While(I<=Length(L))and(L[I]<>'}')do Inc(I);If I<=Length(L)Then Inc(I);
 Piece:=Copy(L,J,I-J);If MetadataCandidate<>''Then MetadataCandidate:=MetadataCandidate+' ';
 MetadataCandidate:=MetadataCandidate+Piece;
 If Pos('}',Piece)<>0 Then Begin MetadataCapture:=False;
  If Pos('@',MetadataCandidate)<>0 Then Begin
   MetadataComment:=FormatMetadataComment(MetadataCandidate);MetadataFound:=True;
  End
  Else MetadataCandidate:='';
 End;
End;

Function IsIdentStart(C:Char):Boolean;Begin
 IsIdentStart:=C in ['A'..'Z','a'..'z','_'];
End;

Function IsIdentChar(C:Char):Boolean;Begin
 IsIdentChar:=C in ['A'..'Z','a'..'z','_','0'..'9'];
End;

Function SameText(Const A,B:String):Boolean;Begin
 SameText:=UpperString(A)=UpperString(B);
End;

Function FileBase(Const S:String):String;
Var
 I,First,Dot:Integer;
Begin
 First:=1;Dot:=0;
 For I:=1 to Length(S)do If S[I]in['\','/',':']Then Begin
  First:=I+1;Dot:=0;
 End Else If S[I]='.'Then Dot:=I;
 If Dot=0 Then Dot:=Length(S)+1;FileBase:=Copy(S,First,Dot-First);
End;

Function ReplaceExtension(Const S,Ext:String):String;
Var
 I,Dot:Integer;
Begin
 Dot:=0;
 For I:=Length(S)downto 1 do Begin
  If S[I]='.'Then Begin
   Dot:=I;Break;
  End;If S[I]in['\','/',':']Then Break;
 End;
 If Dot=0 Then ReplaceExtension:=S+Ext Else ReplaceExtension:=Copy(S,1,Dot-1)+Ext;
End;

Procedure Error(Const S:String);Begin
 WriteLn('REPASCAL: ',S);HadError:=True;
End;

Procedure Usage;Begin
 WriteLn('REPASCAL - Reformate un fichier source Pascal.');WriteLn;
 WriteLn('Syntaxe : REPASCAL fichier.pas');
End;
Function ReadSourceLine(Var T:Text;Var L:TSourceString):Boolean;
{$IFDEF FPC}
 Begin
  ReadSourceLine:=False;If Eof(T)Then Exit;ReadLn(T,L);
  If IOResult<>0 Then Begin
   Error('erreur de lecture');Exit;
  End;ReadSourceLine:=True;
 End;
{$ELSE}

 Var
  C:Char;
  TooLong:Boolean;
 Begin
  ReadSourceLine:=False;If Eof(T)Then Exit;L:='';TooLong:=False;
  While not Eoln(T)do Begin
   Read(T,C);If IOResult<>0 Then Begin
    Error('erreur de lecture');Exit;
   End;
   If Length(L)<255 Then L:=L+C Else TooLong:=True;
  End;ReadLn(T);If IOResult<>0 Then Begin
   Error('erreur de lecture');Exit;
  End;
  If TooLong Then Begin
   Error(
   'ligne de plus de 255 caracteres: Turbo Pascal ne peut pas la reformater sans perte');
   Exit;
  End;
  ReadSourceLine:=True;
 End;
{$ENDIF}

Procedure CountLine(Const L:TSourceString;Var State:TCommentState;Var FirstFound:Boolean);
Var
 I,J:Integer;
 W:String;
 C:Char;
Begin
 I:=1;
 While I<=Length(L)do Begin
  C:=L[I];
  If State=csBrace Then Begin
   If C='}'Then State:=csNone;Inc(I);Continue;
  End;
  If State=csParen Then Begin
   If(C='*')and(I<Length(L))and(L[I+1]=')')Then Begin
    State:=csNone;Inc(I,2);
   End Else Inc(I);Continue;
  End;
  If C='{'Then Begin
   State:=csBrace;Inc(I);Continue;
  End;
  If(C='(')and(I<Length(L))and(L[I+1]='*')Then Begin
   State:=csParen;Inc(I,2);Continue;
  End;
  If(C='/')and(I<Length(L))and(L[I+1]='/')Then Exit;
  If C=''''Then Begin
   Inc(I);
   While I<=Length(L)do Begin
    If L[I]=''''Then Begin
     If(I<Length(L))and(L[I+1]='''')Then Inc(I,2)Else
     Begin
      Inc(I);Break;
     End;
    End Else Inc(I);
   End;Continue;
  End;
  If IsIdentStart(C)Then Begin
   J:=I;
   While(I<=Length(L))and IsIdentChar(L[I])do Inc(I);W:=Copy(L,J,I-J);
   If not FirstFound Then Begin
    FirstFound:=True;HasProgram:=SameText(W,'PROGRAM');IsUnit:=SameText(W,'UNIT');
   End;
   If SameText(W,'BEGIN')Then Begin
    Inc(BeginTotal);If BlockTop=255 Then Begin
     Error('imbrication Pascal trop profonde');Exit;
    End;Inc(BlockTop);BlockKind[BlockTop]:='B';BlockBegin[BlockTop]:=BeginTotal;
   End
   Else If SameText(W,'CASE')or SameText(W,'RECORD')or SameText(W,'TRY')or SameText(W,
   'ASM')or SameText(W,'OBJECT')Then Begin
    If BlockTop=255 Then Begin
     Error('imbrication Pascal trop profonde');Exit;
    End;Inc(BlockTop);BlockKind[BlockTop]:='X';BlockBegin[BlockTop]:=0;
   End
   Else If SameText(W,'END')Then Begin
    Inc(EndTotal);If BlockTop>0 Then Begin
     If BlockKind[BlockTop]='B'Then Begin
      MainBeginNumber:=BlockBegin[BlockTop];MainEndNumber:=EndTotal;
     End;Dec(BlockTop);
    End;
   End;Continue;
  End;Inc(I);
 End;
End;

Procedure FirstPass;
Var
 L:TSourceString;
 FirstFound:Boolean;
Begin
 BeginTotal:=0;EndTotal:=0;MainBeginNumber:=0;MainEndNumber:=0;BlockTop:=0;IsUnit:=False;
 HasProgram:=False;CommentState:=csNone;FirstFound:=False;MetadataFound:=False;
 MetadataCapture:=False;MetadataComment:='';MetadataCandidate:='';
 Assign(InputFile,SourceName);Reset(InputFile);If IOResult<>0 Then Begin
  Error('impossible d''ouvrir '+SourceName);Exit;
 End;
 While ReadSourceLine(InputFile,L)do Begin
  CaptureMetadataLine(L);CountLine(L,CommentState,FirstFound);
 End;
 Close(InputFile);If IOResult<>0 Then Error('erreur de fermeture du fichier source');
End;

Function TrimLine(Const S:TSourceString):TSourceString;
Var
 A,B:LongInt;
Begin
 A:=1;
 While(A<=Length(S))and(S[A]=' ')do Inc(A);B:=Length(S);
 While(B>=A)and(S[B]=' ')do Dec(B);TrimLine:=Copy(S,A,B-A+1);
End;

Procedure AppendText(Const S:TSourceString);
Var
 T:TSourceString;
 I:LongInt;
Begin
 T:=S;
 For I:=1 to Length(T)do If T[I]=#9 Then T[I]:=' ';
 {$IFNDEF FPC}
  If Length(OutLine)+Length(T)>MaxLineLength Then Begin
   Error('ligne produite trop longue');Exit;
  End;OutLine:=OutLine+T;
 {$ELSE}
  OutLine:=OutLine+T;
 {$ENDIF}
End;

Procedure AppendComment(Const S:TSourceString);Begin
 {$IFNDEF FPC}
  If Length(OutLine)+Length(S)>MaxLineLength Then Begin
   Error('ligne de commentaire trop longue');Exit;
  End;OutLine:=OutLine+S;
 {$ELSE}
  OutLine:=OutLine+S;
 {$ENDIF}
End;

Procedure EnsureOneTrailingSpace;Begin
 While(Length(OutLine)>0)and(OutLine[Length(OutLine)]in[' ',#9])do  Delete(OutLine,Length(
 OutLine),1);
 OutLine:=OutLine+' ';
End;

Function LeftTrim(Const S:TSourceString):TSourceString;
Var
 I:LongInt;
Begin
 I:=1;
 While(I<=Length(S))and(S[I]in[' ',#9])do Inc(I);LeftTrim:=Copy(S,I,Length(S)-I+1);
End;

Function FindLineBreak(Const S:TSourceString;Limit:LongInt):LongInt;
Var
 I,LastSemi,LastOperator:LongInt;
 InString,InBrace,InParenComment:Boolean;
 C:Char;
Begin
 LastSemi:=0;LastOperator:=0;InString:=False;InBrace:=False;InParenComment:=False;I:=1;
 While(I<=Length(S))and(I<=Limit)do Begin
  C:=S[I];
  If InString Then Begin
   If C=''''Then If(I<Length(S))and(S[I+1]='''')Then Inc(I)Else InString:=False;
  End
  Else If InBrace Then Begin
   If C='}'Then InBrace:=False;
  End
  Else If InParenComment Then Begin
   If(C='*')and(I<Length(S))and(S[I+1]=')')Then Begin
    InParenComment:=False;Inc(I);
   End;
  End
  Else If C=''''Then InString:=True
  Else If C='{'Then InBrace:=True
  Else If(C='(')and(I<Length(S))and(S[I+1]='*')Then Begin
   InParenComment:=True;Inc(I);
  End
  Else If(C='/')and(I<Length(S))and(S[I+1]='/')Then Break
  Else If C=';'Then Begin
   If UpperString(Copy(S,I+1,5))<>'BEGIN'Then LastSemi:=I;
  End
  Else If C in['(',')','+','-','/','*','=','<','>',',']Then LastOperator:=I;
  Inc(I);
 End;
 If LastSemi<>0 Then FindLineBreak:=LastSemi Else FindLineBreak:=LastOperator;
End;
Procedure EmitPending;Forward;

Function ConditionalDirectiveKind(Const S:TSourceString):Integer;
Var
 U:TSourceString;
Begin
 U:=UpperString(TrimLine(S));ConditionalDirectiveKind:=0;
 If(Copy(U,1,7)='{$IFDEF')or(Copy(U,1,8)='{$IFNDEF')or
 (Copy(U,1,4)='{$IF')or(Copy(U,1,7)='{$IFOPT')Then ConditionalDirectiveKind:=1
 Else If(Copy(U,1,6)='{$ELSE')or(Copy(U,1,8)='{$ELSEIF')Then ConditionalDirectiveKind:=2
 Else If(Copy(U,1,7)='{$ENDIF')or(Copy(U,1,7)='{$IFEND')Then ConditionalDirectiveKind:=3;
End;

Procedure EmitConditionalDirective(Const S:TSourceString;Kind:Integer);
Var
 I,Level:Integer;
Begin
 EmitPending;If Kind in[2,3]Then If ConditionalLevel>0 Then Dec(ConditionalLevel);
 Level:=IndentLevel+ConditionalLevel;
 For I:=1 to Level do Write(OutputFile,' ');
 WriteLn(OutputFile,TrimLine(S));If Kind in[1,2]Then Inc(ConditionalLevel);
 If IOResult<>0 Then Error('erreur d''ecriture de directive conditionnelle');
End;

Procedure WriteFormattedLine(Const Source:TSourceString;Level:LongInt);
Var
 S,Part:TSourceString;
 Available,BreakPos,I:LongInt;
Begin
 S:=Source;
 If Level>=MaxFormattedWidth Then Available:=1 Else Available:=MaxFormattedWidth-Level;
 While Length(S)>Available do Begin
  BreakPos:=FindLineBreak(S,Available);
  If BreakPos=0 Then Break;
  Part:=TrimLine(Copy(S,1,BreakPos));
  For I:=1 to Level do Write(OutputFile,' ');
  WriteLn(OutputFile,Part);
  If IOResult<>0 Then Begin
   Error('erreur d''ecriture');Exit;
  End;S:=LeftTrim(Copy(S,BreakPos+1,Length(S)-BreakPos));
 End;
 For I:=1 to Level do Write(OutputFile,' ');WriteLn(OutputFile,S);
End;

Procedure EmitLine;
Var
 S:TSourceString;
Begin
 If PreserveCommentIndent Then S:=OutLine Else S:=TrimLine(OutLine);OutLine:='';
 If S=''Then Begin
  WriteLn(OutputFile);PreserveCommentIndent:=False;Exit;
 End;
 If PreserveCommentIndent Then WriteLn(OutputFile,S)
 Else WriteFormattedLine(S,IndentLevel+ConditionalLevel);
 PreserveCommentIndent:=False;AwaitingThenBegin:=False;AwaitingDoBegin:=False;
 If IOResult<>0 Then Error('erreur d''ecriture');
End;

Procedure EmitPending;Begin
 If TrimLine(OutLine)<>''Then EmitLine Else OutLine:='';
End;
Procedure FormatLine(Const L:TSourceString;Var State:TCommentState;

Var SkipProgram:Boolean);
Var
 I,J:LongInt;
 DirectiveKind:Integer;
 W,U,S:String;
 C:Char;
 ThisDeclarationIsLocal,SkipThisComment:Boolean;
Begin
 I:=1;PreserveCommentIndent:=State<>csNone;
 While(I<=Length(L))and not HadError do Begin
  C:=L[I];
  If State=csBrace Then Begin
   SkipThisComment:=SuppressMetadata;AwaitingThenBegin:=False;AwaitingDoBegin:=False;
   AwaitingRoutineBegin:=False;J:=I;
   While(I<=Length(L))and(L[I]<>'}')do Inc(I);If I<=Length(L)Then Begin
    Inc(I);State:=csNone;If SuppressMetadata Then Begin MetadataSkipped:=True;SuppressMetadata:=False;End;
   End;If not SkipThisComment Then AppendComment(Copy(L,J,I-J));Continue;
  End;
  If State=csParen Then Begin
   AwaitingThenBegin:=False;AwaitingDoBegin:=False;AwaitingRoutineBegin:=False;J:=I;
   While I<=Length(L)do Begin
    If(L[I]='*')and(I<Length(L))and(L[I+1]=')')Then Begin
     Inc(I,2);State:=csNone;Break;
    End;Inc(I);
   End;AppendComment(Copy(L,J,I-J));Continue;
  End;
  If(C='{')and(I<Length(L))and(L[I+1]='$')Then Begin
   J:=I;
   While(I<=Length(L))and(L[I]<>'}')do Inc(I);
   If I<=Length(L)Then Inc(I);DirectiveKind:=ConditionalDirectiveKind(Copy(L,J,I-J));
   If DirectiveKind<>0 Then Begin
    PreserveCommentIndent:=False;AwaitingThenBegin:=False;AwaitingDoBegin:=False;
    AwaitingRoutineBegin:=False;
    EmitConditionalDirective(Copy(L,J,I-J),DirectiveKind);Continue;
   End;I:=J;
  End;
  If C='{'Then Begin
   AwaitingThenBegin:=False;AwaitingDoBegin:=False;AwaitingRoutineBegin:=False;
   If MetadataFound and not MetadataSkipped and(Pos('@',Copy(L,I,Length(L)-I+1))<>0)Then SuppressMetadata:=True;
   SkipThisComment:=SuppressMetadata;
   If TrimLine(OutLine)=''Then PreserveCommentIndent:=True;State:=csBrace;J:=I;Inc(I);
   While(I<=Length(L))and(L[I]<>'}')do Inc(I);If I<=Length(L)Then Begin
    Inc(I);State:=csNone;If SuppressMetadata Then Begin MetadataSkipped:=True;SuppressMetadata:=False;End;
   End;If not SkipThisComment Then AppendComment(Copy(L,J,I-J));Continue;
  End;
  If(C='(')and(I<Length(L))and(L[I+1]='*')Then Begin
   AwaitingThenBegin:=False;AwaitingDoBegin:=False;AwaitingRoutineBegin:=False;
   If TrimLine(OutLine)=''Then PreserveCommentIndent:=True;State:=csParen;J:=I;Inc(I,2);
   While I<=Length(L)do Begin
    If(L[I]='*')and(I<Length(L))and(L[I+1]=')')Then Begin
     Inc(I,2);State:=csNone;Break;
    End;Inc(I);
   End;AppendComment(Copy(L,J,I-J));Continue;
  End;
  If(C='/')and(I<Length(L))and(L[I+1]='/')Then Begin
   AwaitingThenBegin:=False;AwaitingDoBegin:=False;AwaitingRoutineBegin:=False;
   If TrimLine(OutLine)=''Then PreserveCommentIndent:=True;
   AppendComment(Copy(L,I,Length(L)-I+1));Break;
  End;
  If C=''''Then Begin
   J:=I;Inc(I);
   While I<=Length(L)do Begin
    If L[I]=''''Then Begin
     If(I<Length(L))and(L[I+1]='''')Then Inc(I,2)Else
     Begin
      Inc(I);Break;
     End;
    End Else Inc(I);
   End;If not SkipProgram Then AppendText(Copy(L,J,I-J));Continue;
  End;
  If IsIdentStart(C)Then Begin
   J:=I;
   While(I<=Length(L))and IsIdentChar(L[I])do Inc(I);W:=Copy(L,J,I-J);
   U:=UpperString(W);
   If SkipProgram Then Continue;
   If(U='PROCEDURE')or(U='FUNCTION')Then Begin
    If AwaitingRoutineBegin Then Begin
     If RoutineNeedsBlank Then WriteLn(OutputFile);EmitPending;
     AwaitingRoutineBegin:=False;
     RoutineNeedsBlank:=False;
    End;
    If DeclarationSection Then Begin
     If IndentLevel>0 Then Dec(IndentLevel);DeclarationSection:=False;
    End;
    EmitPending;If U='PROCEDURE'Then AppendText('Procedure')Else AppendText('Function');
    RoutineHeader:=True;AwaitingRoutineBegin:=False;ParenthesisLevel:=0;
    AwaitingThenBegin:=False;AwaitingDoBegin:=False;RoutineNeedsBlank:=True;
   End
   Else If U='USES'Then Begin
    EmitPending;WriteLn(OutputFile);AppendText('Uses');UsesSection:=True;
    AwaitingThenBegin:=False;AwaitingDoBegin:=False;AwaitingRoutineBegin:=False;
   End
   Else If(U='CONST')or(U='TYPE')or(U='VAR')Then Begin
    If(ParenthesisLevel=0)and((TrimLine(OutLine)='')or AwaitingRoutineBegin)Then Begin
     ThisDeclarationIsLocal:=AwaitingRoutineBegin;
     If DeclarationSection Then ThisDeclarationIsLocal:=DeclarationIsLocal;
     If AwaitingRoutineBegin Then Begin
      If RoutineNeedsBlank Then WriteLn(OutputFile);EmitPending;
      AwaitingRoutineBegin:=False;
      RoutineNeedsBlank:=False;
     End;
     If DeclarationSection Then Begin
      If IndentLevel>0 Then Dec(IndentLevel);DeclarationSection:=False;
     End;
     EmitPending;
     If not ThisDeclarationIsLocal and not AfterUsesBlank Then WriteLn(OutputFile);
     AfterUsesBlank:=False;
     If U='CONST'Then AppendText('Const')Else If U='TYPE'Then AppendText('Type')
     Else AppendText('Var');EmitLine;Inc(IndentLevel);DeclarationSection:=True;
     DeclarationIsLocal:=ThisDeclarationIsLocal;
    End Else
    Begin
     AppendText(W);AwaitingThenBegin:=False;AwaitingDoBegin:=False;
    End;
   End
   Else If U='BEGIN'Then Begin
    Inc(BeginNumber);If DeclarationSection Then Begin
     If IndentLevel>0 Then Dec(IndentLevel);DeclarationSection:=False;
    End;
    If AwaitingRoutineBegin and RoutineNeedsBlank Then WriteLn(OutputFile);
    If not(AwaitingThenBegin or AwaitingDoBegin or AwaitingRoutineBegin)Then EmitPending;
    If AwaitingThenBegin or AwaitingDoBegin Then EnsureOneTrailingSpace;
    If(not IsUnit)and(BeginNumber=MainBeginNumber)Then WriteLn(OutputFile);
    If(not IsUnit)and(BeginNumber=MainBeginNumber)Then S:='BEGIN'Else S:='Begin';
    AppendText(S);AwaitingRoutineBegin:=False;RoutineNeedsBlank:=False;
    RoutineHeader:=False;EmitLine;
    Inc(IndentLevel);
   End
   Else If U='END'Then Begin
    Inc(EndNumber);EmitPending;If IndentLevel>0 Then Dec(IndentLevel);
    If(not IsUnit)and(EndNumber=MainEndNumber)Then S:='END'Else S:='End';AppendText(S);
   End
   Else If U='THEN'Then Begin
    AppendText('Then');AwaitingThenBegin:=True;
   End
   Else If U='DO'Then Begin
    AppendText(W);AwaitingDoBegin:=True;AwaitingThenBegin:=False;
   End
   Else If(U='FOR')or(U='WHILE')Then Begin
    EmitPending;If U='FOR'Then AppendText('For')Else AppendText('While');
    AwaitingThenBegin:=False;AwaitingDoBegin:=False;
   End
   Else If U='FORWARD'Then Begin
    AppendText('Forward');AwaitingRoutineBegin:=False;RoutineNeedsBlank:=False;
    AwaitingThenBegin:=False;AwaitingDoBegin:=False;
   End
   Else
   Begin
    If AwaitingRoutineBegin Then Begin
     If RoutineNeedsBlank Then WriteLn(OutputFile);EmitPending;
     AwaitingRoutineBegin:=False;RoutineNeedsBlank:=False;
    End;
    AppendText(W);AwaitingThenBegin:=False;AwaitingDoBegin:=False;
   End;Continue;
  End;
  If SkipProgram Then Begin
   If C=';'Then SkipProgram:=False;Inc(I);Continue;
  End;
  If RoutineHeader Then Begin
   If C='('Then Inc(ParenthesisLevel)Else If(C=')')and(ParenthesisLevel>0)Then Dec(
   ParenthesisLevel);
  End;
  If RoutineHeader and(C=';')and(ParenthesisLevel=0)Then Begin
   AppendText(C);RoutineHeader:=False;AwaitingRoutineBegin:=True;Inc(I);Continue;
  End;
  If UsesSection and(C=';')Then Begin
   AppendText(C);EmitLine;WriteLn(OutputFile);UsesSection:=False;AfterUsesBlank:=True;
   Inc(I);Continue;
  End;
  If DeclarationSection and(C=';')Then Begin
   AppendText(C);EmitLine;Inc(I);Continue;
  End;
  If AwaitingRoutineBegin and(C in[' ',#9])Then Begin
   Inc(I);Continue;
  End;
  AppendText(C);If not(C in[' ',#9])Then Begin
   AwaitingThenBegin:=False;AwaitingDoBegin:=False;
   If AwaitingRoutineBegin Then AwaitingRoutineBegin:=False;
  End;Inc(I);
 End;
 If(TrimLine(OutLine)<>'')and not(
 AwaitingThenBegin or AwaitingDoBegin or AwaitingRoutineBegin)
 Then EmitLine Else If(TrimLine(OutLine)='')and not SkipProgram Then OutLine:='';
End;

Procedure SecondPass;
Var
 L:TSourceString;
 SkipProgram:Boolean;
Begin
 Assign(InputFile,SourceName);Reset(InputFile);If IOResult<>0 Then Begin
  Error('impossible de relire le fichier');Exit;
 End;
 Assign(OutputFile,TempName);Rewrite(OutputFile);If IOResult<>0 Then Begin
  Close(InputFile);Error('impossible de creer le fichier temporaire');Exit;
 End;
 OutLine:='';PreserveCommentIndent:=False;AwaitingThenBegin:=False;
 AwaitingDoBegin:=False;RoutineHeader:=False;
 AwaitingRoutineBegin:=False;RoutineNeedsBlank:=False;DeclarationSection:=False;
 DeclarationIsLocal:=False;AfterUsesBlank:=False;
 UsesSection:=False;
 ParenthesisLevel:=0;ConditionalLevel:=0;
 MetadataSkipped:=False;SuppressMetadata:=False;
 IndentLevel:=0;BeginNumber:=0;EndNumber:=0;CommentState:=csNone;
 SkipProgram:=HasProgram and not IsUnit;
 If not IsUnit Then Begin
  If MetadataFound Then Begin WriteLn(OutputFile,MetadataComment);WriteLn(OutputFile);End;
  WriteLn(OutputFile,'Program ',ProgramName,';');
  If MetadataFound Then WriteLn(OutputFile);
 End;
 While not HadError and ReadSourceLine(InputFile,L)do FormatLine(L,CommentState,
 SkipProgram);
 Close(InputFile);Close(OutputFile);
 If IOResult<>0 Then Error('erreur de fermeture du fichier temporaire');
End;

Procedure InstallResult;
Var
 OldFile,NewFile,BakFile:File;
Begin
 Assign(BakFile,BackupName);Erase(BakFile);If IOResult<>0 Then Begin
 End;
 Assign(OldFile,SourceName);Rename(OldFile,BackupName);If IOResult<>0 Then Begin
  Error('impossible de creer la sauvegarde '+BackupName);Exit;
 End;
 Assign(NewFile,TempName);Rename(NewFile,SourceName);If IOResult<>0 Then Begin
  Assign(BakFile,BackupName);Rename(BakFile,SourceName);If IOResult<>0 Then Begin
  End;Error('impossible d''installer le fichier reformate');Exit;
 End;
End;

BEGIN
 HadError:=False;
 If ParamCount<>1 Then Begin
  Usage;Halt(1);
 End;
 SourceName:=ParamStr(1);TempName:=ReplaceExtension(SourceName,'.$$$');
 BackupName:=ReplaceExtension(SourceName,'.BAK');
 ProgramName:=UpperString(FileBase(SourceName));If ProgramName=''Then Begin
  Error('nom de fichier invalide');Halt(1);
 End;
 If ProgramName[1]in['0'..'9']Then ProgramName:='_'+ProgramName;
 FirstPass;If HadError Then Halt(1);SecondPass;If HadError Then Halt(1);InstallResult;
 If HadError Then Halt(1);WriteLn('Fichier reformate. Sauvegarde: ',BackupName);
END.
