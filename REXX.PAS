{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2, Turbo Pascal 7)
}

Program REXX;

Uses Crt,DOS;

Const
 CommandList:Array[0..161]of String[20]=(
  'ABBREV','ABS','ADDRESS','ARG','B2X','BEEP','BITAND','BITOR',
  'BITXOR','CALL','CENTER','CHANGESTR','CHARIN','CHAROUT',
  'CHARS','COMPARE','CONDITION','COPIES','COUNTSTR','C2D',
  'C2X','DATATYPE','DATE','DELSTR','DELWORD','DIGITS',
  'DIRECTORY','D2C','D2X','ENDLOCAL','ERRORTEXT','EXIT','FILESPEC',
  'FORM','FORMAT','FUZZ','IF','INSERT','LASTPOS','LEFT',
  'LENGTH','LINEIN','LINEOUT','LINES','MAX','MIN',
  'OPTIONS','OVERLAY','PARSE','PROCEDURE','POS','PULL',
  'PUSH','QUEUE','QUEUED','RANDOM','RETURN','REVERSE',
  'RIGHT','RXFUNCADD','RXFUNCDROP','RXFUNCQUERY','RXMESSAGEBOX',
  'RXQUEUE','RXWINEXEC','SAY','SELECT','SETLOCAL','SIGN',
  'SOURCELINE','SPACE','STREAM','STRIP','SUBSTR','SUBWORD',
  'SYMBOL','SYSADDREXXMACRO','SYSBOOTDRIVE','SYSCLEARREXXMACROSPACE',
  'SYSCLOSEEVENTSEM','SYSCLOSEMUTEXSEM','SYSCLS','SYSCREATEEVENTSEM',
  'SYSCREATEMUTEXSEM','SYSCREATEOBJECT','SYSCURPOS','SYSCURSTATE',
  'SYSDEREGISTEROBJECTCLASS','SYSDESTROYOBJECT','SYSDRIVEINFO',
  'SYSDRIVEMAP','SYSDROPFUNCS','SYSDROPREXXMACRO','SYSFILEDELETE',
  'SYSFILETREE','SYSFILESEARCH','SYSFILESYSTEMTYPE',
  'SYSGETEA','SYSGETKEY','SYSGETMESSAGE','SYSINI','SYSLOADFUNCS',
  'SYSLOADREXXMACROSPACE','SYSMKDIR','SYSOPENEVENTSEM',
  'SYSOPENMUTEXSEM','SYSOS2VER','SYSPOSTEVENTSEM','SYSPULSEEVENTSEM',
  'SYSPUTEA','SYSQUERYCLASSLIST','SYSQUERYREXXMACRO',
  'SYSREGISTEROBJECTCLASS','SYSRELEASEMUTEXSEM',
  'SYSREORDERREXXMACRO','SYSREQUESTMUTEXSEM','SYSRESETEVENTSEM',
  'SYSRMDIR','SYSSAVEREXXMACROSPACE','SYSSEARCHPATH','SYSSETICON',
  'SYSSETOBJECTDATA','SYSSETPRIORITY','SYSSLEEP','SYSSWITCHSESSION',
  'SYSSYSTEMDIRECTORY','SYSTEMPFILENAME','SYSTEXTSCREENREAD',
  'SYSTEXTSCREENSIZE','SYSVOLUMELABEL','SYSWAITEVENTSEM',
  'SYSWAITNAMEDPIPE','SYSWINVER','THEN','TIME','TRACE',
  'TRANSLATE','TRUNC','VALUE','VAR','VERIFY','WORD',
  'WORDINDEX','WORDLENGTH','WORDPOS','WORDS','XRANGE',
  'X2B','X2C','X2D',
  { Instructions de controle ajoutees apres la table historique afin de ne
    pas modifier les numeros encore utilises par l'ancien moteur. }
  'DO','ELSE','END','EXPOSE','ITERATE','LEAVE','NAME','NOP','NUMERIC',
  'OTHERWISE','SIGNAL','WHEN'
 );

 MaxLine=1024;

Type
 StrPointer=^String;

Var
 Terminated:Boolean;
 CurrCommand:String;
 FileName,CurrLine:String;
 PA:Array[1..MaxLine] of StrPointer;
 CurrLinePtr,NumberLine:Integer;
 CurrNumberLine:Integer;
 I:Integer;
 CurrPos:Byte;

Type
 RexxValue=Record
  Text:String;
  Number:Real;
  IsNumber:Boolean;
 End;
 PRexxVariable=^RexxVariable;
 RexxVariable=Record
  Name:String[64];
  Value:String;
  Next:PRexxVariable;
 End;

Var
 Variables:PRexxVariable;
 ExprText:String;
 ExprPos:Integer;

Const
 MaxRoutineArgs=16;

Var
 InvokeArgs:Array[1..MaxRoutineArgs]of String;
 InvokeArgCount:Integer;
 CurrentArgs:Array[1..MaxRoutineArgs]of String;
 CurrentArgCount:Integer;
 InitialArgs:Array[1..MaxRoutineArgs]of String;
 InitialArgCount:Integer;
 RoutineReturning:Boolean;
 RoutineResult:String;
 NumericDigitsValue:Integer;
 NumericFuzzValue:Integer;
 NumericFormValue:String[16];
 SignalTargetLine:Integer;
 SignalHalt,SignalNoValue,SignalError,SignalSyntax:Boolean;
 SignalHaltName,SignalNoValueName,SignalErrorName,SignalSyntaxName:String[64];
 CurrentAddress,PreviousAddress:String[64];
 CharInNames:Array[1..MaxRoutineArgs]of String;
 CharInPositions:Array[1..MaxRoutineArgs]of LongInt;
 CharInStreamCount:Integer;

Function LTrim(S:String):String;
Var
 I:Integer;
Begin
 I:=1;
 While(I<=Length(s)) and (S[I] in [#9,' ']) do Inc(I);
 Delete(S,1,I-1);
 LTrim:=S;
End;

Function StrToUpper(S:String):String;
Var
 I:Byte;
Begin
 For I:=1 to Length(S)do Begin
  If S[I] in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);
 End;
 StrToUpper:=S;
End;

 { Traitement de la liste }
Function AddLine(S:String):Boolean;
Var
 P:StrPointer;
Begin
 If NumberLine>=MaxLine Then Begin
  AddLine:=False;
  Exit;
 End;
 Inc(NumberLine);
 GetMem(P,Length(S)+1);
 P^:=S;
 PA[NumberLine]:=P;
 AddLine:=True;
End;

Function IsStringValue:Boolean;Begin
 IsStringValue:=False;
 If CurrLine[CurrPos]in['''','"']Then Begin
  IsStringValue:=True;
 End;
End;

Function ExtractCommand:Byte;
Var
 I:Byte;
Begin
 ExtractCommand:=255;
 CurrCommand:='';
 For I:=CurrPos to Length(CurrLine)do Begin
  If Not(CurrLine[I]in['A'..'Z','a'..'z','_'])Then Begin
   CurrCommand:=StrToUpper(Copy(CurrLine,CurrPos,I-CurrPos));
   CurrPos:=I;
   Break;
  End;
 End;
 If CurrCommand=''Then Begin
  CurrCommand:=StrToUpper(Copy(CurrLine,CurrPos,255));
  CurrPos:=Length(CurrLine)+1;
 End;
 For I:=Low(CommandList)to High(CommandList)do Begin
  If CurrCommand=CommandList[I]Then Begin
   ExtractCommand:=I;
   Exit;
  End;
 End;
End;

Function GetStringValue:String;
Var
 J:Integer;
 _Result:Real;
 FunctionFound:Boolean;
 S,VarName:String;
Begin
 GetStringValue:='';
 S:='';
 If CurrLine[CurrPos]=''''Then Begin
  Inc(CurrPos);
  While(CurrLine[CurrPos]<>'''')and(CurrPos<=Length(CurrLine))do Begin
   S:=S+CurrLine[CurrPos];
   Inc(CurrPos);
  End;
  If CurrLine[CurrPos]=''''Then Inc(CurrPos);
 End
  Else
 If CurrLine[CurrPos]='"'Then Begin
  Inc(CurrPos);
  While(CurrLine[CurrPos]<>'"')and(CurrPos<=Length(CurrLine))do Begin
   S:=S+CurrLine[CurrPos];
   Inc(CurrPos);
  End;
  If CurrLine[CurrPos]='"'Then Inc(CurrPos);
 End;
 GetStringValue:=S;
End;

Procedure SkipSpace;Begin
 While(CurrLine[CurrPos]in[' '])and(CurrPos<Length(CurrLine))do Inc(CurrPos);
End;

Procedure LoadCommand;
Var
 FileLoad:Text;
 S:String;
Begin
 If FileName<>''Then Begin
  {$I-}Assign(FileLoad,FileName);
  Reset(FileLoad);{$I+}
  If IoResult<>0Then Begin
   WriteLn('Fichier introuvable');
   Exit;
  End;
  {NewCommand;}
  While Not EOF(FileLoad) do Begin
   ReadLn(FileLoad,S);
   If Not AddLine(LTrim(S))Then Begin
    WriteLn('Manque de m‚moire');
    Break;
   End;
  End;
  Close(FileLoad);
 End
  Else
 WriteLn('Nom du fichier absent');
End;

Procedure SayCommand;Begin
 SkipSpace;
 If IsStringValue Then Begin
  WriteLn(GetStringValue);
 End;
End;

{ -----------------------------------------------------------------
  Noyau REXX executable. L'ancien RunLine ci-dessus est conserve pour
  documenter la table historique, mais ce moteur prend en charge les
  expressions, variables et structures de controle reelles. }

Function RTrim(S:String):String;
Begin
 While(Length(S)>0)and(S[Length(S)]in[' ',#9])do Delete(S,Length(S),1);
 RTrim:=S;
End;

Function Clean(S:String):String;Begin Clean:=RTrim(LTrim(S));End;

Function NumToText(N:Real):String;
Var S:String;
Begin
 If Abs(N-Round(N))<0.000000001Then Str(Round(N),S)
 Else Begin Str(N:0:8,S);While(System.Pos('.',S)>0)and(S[Length(S)]='0')do Delete(S,Length(S),1);End;
 NumToText:=Clean(S);
End;

Procedure RVText(S:String;Var V:RexxValue);
Var C:Integer;
Begin V.Text:=S;Val(Clean(S),V.Number,C);V.IsNumber:=C=0;If Not V.IsNumber Then V.Number:=0;End;
Procedure RVNum(N:Real;Var V:RexxValue);
Begin V.Number:=N;V.IsNumber:=True;V.Text:=NumToText(N);End;

Function VarFind(Head:PRexxVariable;N:String):PRexxVariable;
Var P:PRexxVariable;
Begin
 N:=StrToUpper(N);
 P:=Head;
 While P<>Nil Do Begin
  If P^.Name=N Then Begin VarFind:=P;Exit;End;
  P:=P^.Next;
 End;
 VarFind:=Nil;
End;

Procedure VarGet(N:String;Var ResultValue:RexxValue);
Var P:PRexxVariable;
Begin
 P:=VarFind(Variables,N);
 If P=Nil Then RVText(StrToUpper(N),ResultValue)
        Else RVText(P^.Value,ResultValue);
End;

Procedure VarSet(N,S:String);
Var P:PRexxVariable;
Begin
 N:=StrToUpper(Clean(N));
 P:=VarFind(Variables,N);
 If P=Nil Then Begin
  New(P);P^.Name:=N;P^.Value:='';P^.Next:=Variables;Variables:=P;
 End;
 P^.Value:=S;
End;

Procedure FreeVariables(Var Head:PRexxVariable);
Var P:PRexxVariable;
Begin
 While Head<>Nil Do Begin P:=Head;Head:=Head^.Next;Dispose(P);End;
End;

Procedure ESkip;Begin
 While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in[' ',#9])do Inc(ExprPos);
End;

Procedure ECompare(Var ResultValue:RexxValue);Forward;
Function FindRoutineLabel(Name:String):Integer;Forward;
Function CallRoutine(Name:String):String;Forward;
Function CommandIndex(N:String):Integer;Forward;

Procedure FunctionNotImplemented(FunctionByte:Byte;Var ResultValue:RexxValue);
Begin
 WriteLn('Fonction non implementee: ',CommandList[FunctionByte]);
 RVText(CommandList[FunctionByte],ResultValue);
End;

Function BinaryToHex(BinaryText:String):String;
Const HexDigits:Array[0..15]of Char='0123456789ABCDEF';
Var
 Bits,ResultText:String;J,DigitValue,BitCount:Integer;
Begin
 Bits:='';
 For J:=1 To Length(BinaryText)Do Begin
  If BinaryText[J]in['0','1']Then Bits:=Bits+BinaryText[J]
  Else If Not(BinaryText[J]in[' ',#9])Then Begin
   WriteLn('B2X: caractere binaire invalide: ',BinaryText[J]);BinaryToHex:='';Exit;
  End;
 End;
 If Bits=''Then Begin BinaryToHex:='';Exit;End;
 While(Length(Bits)mod 4)<>0Do Bits:='0'+Bits;
 ResultText:='';J:=1;
 While J<=Length(Bits)Do Begin
  DigitValue:=0;
  For BitCount:=0 To 3 Do Begin
   DigitValue:=DigitValue*2;
   If Bits[J+BitCount]='1'Then Inc(DigitValue);
  End;
  ResultText:=ResultText+HexDigits[DigitValue+1];Inc(J,4);
 End;
 BinaryToHex:=ResultText;
End;

Procedure BeepSound(Frequency,Duration:LongInt;Var ResultValue:RexxValue);
Begin
 If Frequency<37Then Frequency:=37;
 If Frequency>32767Then Frequency:=32767;
 If Duration<0Then Duration:=0;
 If Duration>32767Then Duration:=32767;
 If Duration>0Then Begin
  Sound(Frequency);Delay(Duration);NoSound;
 End;
 RVNum(0,ResultValue);
End;

Function BitAndText(LeftText,RightText,PadText:String;UsePad:Boolean):String;
Var J,ResultLength:Integer;LeftByte,RightByte,PadByte:Byte;ResultText:String;
Begin
 If UsePad Then Begin
  If PadText=''Then PadByte:=0 Else PadByte:=Ord(PadText[1]);
  If Length(LeftText)>Length(RightText)Then ResultLength:=Length(LeftText) Else ResultLength:=Length(RightText);
 End Else Begin
  PadByte:=0;
  If Length(LeftText)<Length(RightText)Then ResultLength:=Length(LeftText) Else ResultLength:=Length(RightText);
 End;
 ResultText:='';
 For J:=1 To ResultLength Do Begin
  If J<=Length(LeftText)Then LeftByte:=Ord(LeftText[J]) Else LeftByte:=PadByte;
  If J<=Length(RightText)Then RightByte:=Ord(RightText[J]) Else RightByte:=PadByte;
  ResultText:=ResultText+Chr(LeftByte and RightByte);
 End;
 BitAndText:=ResultText;
End;

Function BitOrText(LeftText,RightText,PadText:String;UsePad:Boolean):String;
Var J,ResultLength:Integer;LeftByte,RightByte,PadByte:Byte;ResultText:String;
Begin
 If UsePad Then Begin
  If PadText=''Then PadByte:=0 Else PadByte:=Ord(PadText[1]);
  If Length(LeftText)>Length(RightText)Then ResultLength:=Length(LeftText) Else ResultLength:=Length(RightText);
 End Else Begin
  PadByte:=0;
  If Length(LeftText)<Length(RightText)Then ResultLength:=Length(LeftText) Else ResultLength:=Length(RightText);
 End;
 ResultText:='';
 For J:=1 To ResultLength Do Begin
  If J<=Length(LeftText)Then LeftByte:=Ord(LeftText[J]) Else LeftByte:=PadByte;
  If J<=Length(RightText)Then RightByte:=Ord(RightText[J]) Else RightByte:=PadByte;
  ResultText:=ResultText+Chr(LeftByte or RightByte);
 End;
 BitOrText:=ResultText;
End;

Function BitXorText(LeftText,RightText,PadText:String;UsePad:Boolean):String;
Var J,ResultLength:Integer;LeftByte,RightByte,PadByte:Byte;ResultText:String;
Begin
 If UsePad Then Begin
  If PadText=''Then PadByte:=0 Else PadByte:=Ord(PadText[1]);
  If Length(LeftText)>Length(RightText)Then ResultLength:=Length(LeftText) Else ResultLength:=Length(RightText);
 End Else Begin
  PadByte:=0;
  If Length(LeftText)<Length(RightText)Then ResultLength:=Length(LeftText) Else ResultLength:=Length(RightText);
 End;
 ResultText:='';
 For J:=1 To ResultLength Do Begin
  If J<=Length(LeftText)Then LeftByte:=Ord(LeftText[J]) Else LeftByte:=PadByte;
  If J<=Length(RightText)Then RightByte:=Ord(RightText[J]) Else RightByte:=PadByte;
  ResultText:=ResultText+Chr(LeftByte xor RightByte);
 End;
 BitXorText:=ResultText;
End;

Function RepeatCharacter(C:Char;Count:Integer):String;
Var J:Integer;S:String;
Begin
 S:='';For J:=1 To Count Do S:=S+C;RepeatCharacter:=S;
End;

Function ChangeString(Needle,SourceText,Replacement:String):String;
Var P:Integer;ResultText,RemainingText:String;
Begin
 If Needle=''Then Begin ChangeString:=SourceText;Exit;End;
 ResultText:='';RemainingText:=SourceText;
 P:=System.Pos(Needle,RemainingText);
 While P>0Do Begin
  ResultText:=ResultText+Copy(RemainingText,1,P-1)+Replacement;
  Delete(RemainingText,1,P+Length(Needle)-1);
  P:=System.Pos(Needle,RemainingText);
 End;
 ChangeString:=ResultText+RemainingText;
End;

Procedure CharInValue(StreamName:String;StartPosition,RequestedCount:LongInt;
 UseStart,UseCount:Boolean;Var ResultValue:RexxValue);
Var F:File;Buffer:Array[1..255]of Byte;J,StreamIndex,ReadCount,Count:Integer;
 Position:LongInt;ResultText:String;
Begin
 If Not UseCount Then RequestedCount:=1;
 If RequestedCount<0Then RequestedCount:=0;
 If RequestedCount>255Then RequestedCount:=255;
 Count:=RequestedCount;ResultText:='';
 If StreamName=''Then Begin
  For J:=1 To Count Do ResultText:=ResultText+ReadKey;
  RVText(ResultText,ResultValue);Exit;
 End;
 StreamIndex:=0;
 For J:=1 To CharInStreamCount Do If CharInNames[J]=StreamName Then StreamIndex:=J;
 If StreamIndex=0Then Begin
  If CharInStreamCount<MaxRoutineArgs Then Begin
   Inc(CharInStreamCount);StreamIndex:=CharInStreamCount;
   CharInNames[StreamIndex]:=StreamName;CharInPositions[StreamIndex]:=1;
  End Else StreamIndex:=1;
 End;
 If UseStart Then Position:=StartPosition Else Position:=CharInPositions[StreamIndex];
 If Position<1Then Position:=1;
 {$I-}Assign(F,StreamName);Reset(F,1);{$I+}
 If IoResult<>0Then Begin RVText('',ResultValue);Exit;End;
 If Position-1<FileSize(F)Then Begin
  Seek(F,Position-1);BlockRead(F,Buffer,Count,ReadCount);
  For J:=1 To ReadCount Do ResultText:=ResultText+Chr(Buffer[J]);
 End Else ReadCount:=0;
 Close(F);CharInPositions[StreamIndex]:=Position+ReadCount;
 RVText(ResultText,ResultValue);
End;

Function CenterText(SourceText:String;TargetLength:Integer;PadText:String):String;
Var LeftCount,RightCount,StartPosition:Integer;PadChar:Char;
Begin
 If TargetLength<=0Then Begin CenterText:='';Exit;End;
 If PadText=''Then PadChar:=' ' Else PadChar:=PadText[1];
 If Length(SourceText)>TargetLength Then Begin
  StartPosition:=((Length(SourceText)-TargetLength)div 2)+1;
  CenterText:=Copy(SourceText,StartPosition,TargetLength);Exit;
 End;
 LeftCount:=(TargetLength-Length(SourceText))div 2;
 RightCount:=TargetLength-Length(SourceText)-LeftCount;
 CenterText:=RepeatCharacter(PadChar,LeftCount)+SourceText+RepeatCharacter(PadChar,RightCount);
End;

Procedure EPrimary(Var ResultValue:RexxValue);
Var Q:Char;S,Nm:String;N:Real;C,J,MinimumLength:Integer;FunctionByte:Byte;A,B,D:RexxValue;
Begin
 ESkip;
 If ExprPos>Length(ExprText)Then Begin
  RVText('',ResultValue);
  Exit;
 End;
 If ExprText[ExprPos]in['''','"']Then Begin
  Q:=ExprText[ExprPos];
  Inc(ExprPos);S:='';
  While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]<>Q)do Begin
   S:=S+ExprText[ExprPos];
   Inc(ExprPos);
  End;
  If ExprPos<=Length(ExprText)Then Inc(ExprPos);
  RVText(S,ResultValue);
  Exit;
 End;
 If ExprText[ExprPos]='('Then Begin
  Inc(ExprPos);
  ECompare(ResultValue);
  ESkip;
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=')')Then Inc(ExprPos);
  Exit;
 End;
 If ExprText[ExprPos]='-'Then Begin Inc(ExprPos);EPrimary(A);RVNum(-A.Number,ResultValue);Exit;End;
 If ExprText[ExprPos]in['0'..'9','.']Then Begin
  S:='';
  While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0'..'9','.'])do Begin
   S:=S+ExprText[ExprPos];
   Inc(ExprPos);
  End;
  Val(S,N,C);
  If C<>0Then N:=0;
  RVNum(N,ResultValue);
  Exit;
 End;
 Nm:='';
 While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['A'..'Z','a'..'z','0'..'9','_','.'])do Begin
  Nm:=Nm+ExprText[ExprPos];
  Inc(ExprPos);
 End;
 ESkip;
 If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]='(')Then Begin
  Inc(ExprPos);InvokeArgCount:=0;ESkip;
  While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]<>')')and(InvokeArgCount<MaxRoutineArgs)do Begin
   ECompare(A);Inc(InvokeArgCount);InvokeArgs[InvokeArgCount]:=A.Text;ESkip;
   If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=',')Then Begin Inc(ExprPos);ESkip;End Else Break;
  End;
  If ExprPos<=Length(ExprText)Then If ExprText[ExprPos]=')'Then Inc(ExprPos);
  If InvokeArgCount>0Then RVText(InvokeArgs[1],A)Else RVText('',A);
  If InvokeArgCount>1Then RVText(InvokeArgs[2],B)Else RVText('',B);
  If InvokeArgCount>2Then RVText(InvokeArgs[3],D)Else RVText('',D);
  Nm:=StrToUpper(Nm);
  C:=CommandIndex(Nm);If C<0Then FunctionByte:=255 Else FunctionByte:=Byte(C);
  Case FunctionByte Of
   0:Begin { ABBREV }
    If InvokeArgCount>2Then MinimumLength:=System.Trunc(D.Number)
     Else MinimumLength:=Length(B.Text);
    If MinimumLength<0Then MinimumLength:=0;
    If(Length(B.Text)>=MinimumLength)and(Length(B.Text)<=Length(A.Text))and
      (Copy(A.Text,1,Length(B.Text))=B.Text)Then RVNum(1,ResultValue)
     Else RVNum(0,ResultValue);
   End;
   1:RVNum(Abs(A.Number),ResultValue); { ABS }
   2:RVText(CurrentAddress,ResultValue); { ADDRESS }
   3:Begin { ARG }
    If InvokeArgCount=0Then RVNum(CurrentArgCount,ResultValue)
    Else Begin
     J:=System.Trunc(A.Number);
     If InvokeArgCount=1Then Begin
      If(J>=1)and(J<=CurrentArgCount)Then RVText(CurrentArgs[J],ResultValue)Else RVText('',ResultValue);
     End Else Begin
      S:=StrToUpper(B.Text);
      If S='E'Then Begin If(J>=1)and(J<=CurrentArgCount)Then RVNum(1,ResultValue)Else RVNum(0,ResultValue);End
      Else If S='O'Then Begin If(J<1)or(J>CurrentArgCount)Then RVNum(1,ResultValue)Else RVNum(0,ResultValue);End
      Else RVText('',ResultValue);
     End;
    End;
   End;
   4:RVText(BinaryToHex(A.Text),ResultValue); { B2X }
   5:Begin { BEEP }
    If InvokeArgCount=0Then BeepSound(800,200,ResultValue)
    Else If InvokeArgCount=1Then BeepSound(System.Trunc(A.Number),200,ResultValue)
    Else BeepSound(System.Trunc(A.Number),System.Trunc(B.Number),ResultValue);
   End;
   6:RVText(BitAndText(A.Text,B.Text,D.Text,InvokeArgCount>2),ResultValue); { BITAND }
   7:RVText(BitOrText(A.Text,B.Text,D.Text,InvokeArgCount>2),ResultValue); { BITOR }
   8:RVText(BitXorText(A.Text,B.Text,D.Text,InvokeArgCount>2),ResultValue); { BITXOR }
   9:Begin { CALL }
    { Forme fonctionnelle pratique: CALL('routine',arg1,...). Le premier
      argument est le nom et les suivants deviennent les arguments REXX. }
    S:=A.Text;
    If InvokeArgCount>0Then Begin
     For J:=1 To InvokeArgCount-1 Do InvokeArgs[J]:=InvokeArgs[J+1];
     Dec(InvokeArgCount);
    End;
    RVText(CallRoutine(S),ResultValue);
   End;
   10:RVText(CenterText(A.Text,System.Trunc(B.Number),D.Text),ResultValue); { CENTER }
   11:RVText(ChangeString(A.Text,B.Text,D.Text),ResultValue); { CHANGESTR }
   12:CharInValue(A.Text,System.Trunc(B.Number),System.Trunc(D.Number),
    InvokeArgCount>1,InvokeArgCount>2,ResultValue); { CHARIN }
   13:FunctionNotImplemented(FunctionByte,ResultValue); { CHAROUT }
   14:FunctionNotImplemented(FunctionByte,ResultValue); { CHARS }
   15:FunctionNotImplemented(FunctionByte,ResultValue); { COMPARE }
   16:FunctionNotImplemented(FunctionByte,ResultValue); { CONDITION }
   17:FunctionNotImplemented(FunctionByte,ResultValue); { COPIES }
   18:FunctionNotImplemented(FunctionByte,ResultValue); { COUNTSTR }
   19:FunctionNotImplemented(FunctionByte,ResultValue); { C2D }
   20:FunctionNotImplemented(FunctionByte,ResultValue); { C2X }
   21:FunctionNotImplemented(FunctionByte,ResultValue); { DATATYPE }
   22:FunctionNotImplemented(FunctionByte,ResultValue); { DATE }
   23:FunctionNotImplemented(FunctionByte,ResultValue); { DELSTR }
   24:FunctionNotImplemented(FunctionByte,ResultValue); { DELWORD }
   25:RVNum(NumericDigitsValue,ResultValue); { DIGITS }
   26:FunctionNotImplemented(FunctionByte,ResultValue); { DIRECTORY }
   27:FunctionNotImplemented(FunctionByte,ResultValue); { D2C }
   28:FunctionNotImplemented(FunctionByte,ResultValue); { D2X }
   29:FunctionNotImplemented(FunctionByte,ResultValue); { ENDLOCAL }
   30:FunctionNotImplemented(FunctionByte,ResultValue); { ERRORTEXT }
   31:FunctionNotImplemented(FunctionByte,ResultValue); { EXIT }
   32:FunctionNotImplemented(FunctionByte,ResultValue); { FILESPEC }
   33:RVText(NumericFormValue,ResultValue); { FORM }
   34:FunctionNotImplemented(FunctionByte,ResultValue); { FORMAT }
   35:RVNum(NumericFuzzValue,ResultValue); { FUZZ }
   36:FunctionNotImplemented(FunctionByte,ResultValue); { IF }
   37:FunctionNotImplemented(FunctionByte,ResultValue); { INSERT }
   38:FunctionNotImplemented(FunctionByte,ResultValue); { LASTPOS }
   39:RVText(Copy(A.Text,1,System.Trunc(B.Number)),ResultValue); { LEFT }
   40:RVNum(Length(A.Text),ResultValue); { LENGTH }
   41:FunctionNotImplemented(FunctionByte,ResultValue); { LINEIN }
   42:FunctionNotImplemented(FunctionByte,ResultValue); { LINEOUT }
   43:FunctionNotImplemented(FunctionByte,ResultValue); { LINES }
   44:Begin { MAX }
    If A.Number>B.Number Then N:=A.Number Else N:=B.Number;RVNum(N,ResultValue);
   End;
   45:Begin { MIN }
    If A.Number<B.Number Then N:=A.Number Else N:=B.Number;RVNum(N,ResultValue);
   End;
   46:FunctionNotImplemented(FunctionByte,ResultValue); { OPTIONS }
   47:FunctionNotImplemented(FunctionByte,ResultValue); { OVERLAY }
   48:FunctionNotImplemented(FunctionByte,ResultValue); { PARSE }
   49:FunctionNotImplemented(FunctionByte,ResultValue); { PROCEDURE }
   50:FunctionNotImplemented(FunctionByte,ResultValue); { POS }
   51:FunctionNotImplemented(FunctionByte,ResultValue); { PULL }
   52:FunctionNotImplemented(FunctionByte,ResultValue); { PUSH }
   53:FunctionNotImplemented(FunctionByte,ResultValue); { QUEUE }
   54:FunctionNotImplemented(FunctionByte,ResultValue); { QUEUED }
   55:FunctionNotImplemented(FunctionByte,ResultValue); { RANDOM }
   56:FunctionNotImplemented(FunctionByte,ResultValue); { RETURN }
   57:FunctionNotImplemented(FunctionByte,ResultValue); { REVERSE }
   58:Begin { RIGHT }
    J:=Length(A.Text)-System.Trunc(B.Number)+1;If J<1Then J:=1;RVText(Copy(A.Text,J,255),ResultValue);
   End;
   59:FunctionNotImplemented(FunctionByte,ResultValue); { RXFUNCADD }
   60:FunctionNotImplemented(FunctionByte,ResultValue); { RXFUNCDROP }
   61:FunctionNotImplemented(FunctionByte,ResultValue); { RXFUNCQUERY }
   62:FunctionNotImplemented(FunctionByte,ResultValue); { RXMESSAGEBOX }
   63:FunctionNotImplemented(FunctionByte,ResultValue); { RXQUEUE }
   64:FunctionNotImplemented(FunctionByte,ResultValue); { RXWINEXEC }
   65:FunctionNotImplemented(FunctionByte,ResultValue); { SAY }
   66:FunctionNotImplemented(FunctionByte,ResultValue); { SELECT }
   67:FunctionNotImplemented(FunctionByte,ResultValue); { SETLOCAL }
   68:Begin { SIGN }
    If A.Number<0Then N:=-1 Else If A.Number>0Then N:=1 Else N:=0;RVNum(N,ResultValue);
   End;
   69:FunctionNotImplemented(FunctionByte,ResultValue); { SOURCELINE }
   70:FunctionNotImplemented(FunctionByte,ResultValue); { SPACE }
   71:FunctionNotImplemented(FunctionByte,ResultValue); { STREAM }
   72:FunctionNotImplemented(FunctionByte,ResultValue); { STRIP }
   73:FunctionNotImplemented(FunctionByte,ResultValue); { SUBSTR }
   74:FunctionNotImplemented(FunctionByte,ResultValue); { SUBWORD }
   75:FunctionNotImplemented(FunctionByte,ResultValue); { SYMBOL }
   76:FunctionNotImplemented(FunctionByte,ResultValue); { SYSADDREXXMACRO }
   77:FunctionNotImplemented(FunctionByte,ResultValue); { SYSBOOTDRIVE }
   78:FunctionNotImplemented(FunctionByte,ResultValue); { SYSCLEARREXXMACROSPACE }
   79:FunctionNotImplemented(FunctionByte,ResultValue); { SYSCLOSEEVENTSEM }
   80:FunctionNotImplemented(FunctionByte,ResultValue); { SYSCLOSEMUTEXSEM }
   81:FunctionNotImplemented(FunctionByte,ResultValue); { SYSCLS }
   82:FunctionNotImplemented(FunctionByte,ResultValue); { SYSCREATEEVENTSEM }
   83:FunctionNotImplemented(FunctionByte,ResultValue); { SYSCREATEMUTEXSEM }
   84:FunctionNotImplemented(FunctionByte,ResultValue); { SYSCREATEOBJECT }
   85:FunctionNotImplemented(FunctionByte,ResultValue); { SYSCURPOS }
   86:FunctionNotImplemented(FunctionByte,ResultValue); { SYSCURSTATE }
   87:FunctionNotImplemented(FunctionByte,ResultValue); { SYSDEREGISTEROBJECTCLASS }
   88:FunctionNotImplemented(FunctionByte,ResultValue); { SYSDESTROYOBJECT }
   89:FunctionNotImplemented(FunctionByte,ResultValue); { SYSDRIVEINFO }
   90:FunctionNotImplemented(FunctionByte,ResultValue); { SYSDRIVEMAP }
   91:FunctionNotImplemented(FunctionByte,ResultValue); { SYSDROPFUNCS }
   92:FunctionNotImplemented(FunctionByte,ResultValue); { SYSDROPREXXMACRO }
   93:FunctionNotImplemented(FunctionByte,ResultValue); { SYSFILEDELETE }
   94:FunctionNotImplemented(FunctionByte,ResultValue); { SYSFILETREE }
   95:FunctionNotImplemented(FunctionByte,ResultValue); { SYSFILESEARCH }
   96:FunctionNotImplemented(FunctionByte,ResultValue); { SYSFILESYSTEMTYPE }
   97:FunctionNotImplemented(FunctionByte,ResultValue); { SYSGETEA }
   98:FunctionNotImplemented(FunctionByte,ResultValue); { SYSGETKEY }
   99:FunctionNotImplemented(FunctionByte,ResultValue); { SYSGETMESSAGE }
   100:FunctionNotImplemented(FunctionByte,ResultValue); { SYSINI }
   101:FunctionNotImplemented(FunctionByte,ResultValue); { SYSLOADFUNCS }
   102:FunctionNotImplemented(FunctionByte,ResultValue); { SYSLOADREXXMACROSPACE }
   103:FunctionNotImplemented(FunctionByte,ResultValue); { SYSMKDIR }
   104:FunctionNotImplemented(FunctionByte,ResultValue); { SYSOPENEVENTSEM }
   105:FunctionNotImplemented(FunctionByte,ResultValue); { SYSOPENMUTEXSEM }
   106:FunctionNotImplemented(FunctionByte,ResultValue); { SYSOS2VER }
   107:FunctionNotImplemented(FunctionByte,ResultValue); { SYSPOSTEVENTSEM }
   108:FunctionNotImplemented(FunctionByte,ResultValue); { SYSPULSEEVENTSEM }
   109:FunctionNotImplemented(FunctionByte,ResultValue); { SYSPUTEA }
   110:FunctionNotImplemented(FunctionByte,ResultValue); { SYSQUERYCLASSLIST }
   111:FunctionNotImplemented(FunctionByte,ResultValue); { SYSQUERYREXXMACRO }
   112:FunctionNotImplemented(FunctionByte,ResultValue); { SYSREGISTEROBJECTCLASS }
   113:FunctionNotImplemented(FunctionByte,ResultValue); { SYSRELEASEMUTEXSEM }
   114:FunctionNotImplemented(FunctionByte,ResultValue); { SYSREORDERREXXMACRO }
   115:FunctionNotImplemented(FunctionByte,ResultValue); { SYSREQUESTMUTEXSEM }
   116:FunctionNotImplemented(FunctionByte,ResultValue); { SYSRESETEVENTSEM }
   117:FunctionNotImplemented(FunctionByte,ResultValue); { SYSRMDIR }
   118:FunctionNotImplemented(FunctionByte,ResultValue); { SYSSAVEREXXMACROSPACE }
   119:FunctionNotImplemented(FunctionByte,ResultValue); { SYSSEARCHPATH }
   120:FunctionNotImplemented(FunctionByte,ResultValue); { SYSSETICON }
   121:FunctionNotImplemented(FunctionByte,ResultValue); { SYSSETOBJECTDATA }
   122:FunctionNotImplemented(FunctionByte,ResultValue); { SYSSETPRIORITY }
   123:FunctionNotImplemented(FunctionByte,ResultValue); { SYSSLEEP }
   124:FunctionNotImplemented(FunctionByte,ResultValue); { SYSSWITCHSESSION }
   125:FunctionNotImplemented(FunctionByte,ResultValue); { SYSSYSTEMDIRECTORY }
   126:FunctionNotImplemented(FunctionByte,ResultValue); { SYSTEMPFILENAME }
   127:FunctionNotImplemented(FunctionByte,ResultValue); { SYSTEXTSCREENREAD }
   128:FunctionNotImplemented(FunctionByte,ResultValue); { SYSTEXTSCREENSIZE }
   129:FunctionNotImplemented(FunctionByte,ResultValue); { SYSVOLUMELABEL }
   130:FunctionNotImplemented(FunctionByte,ResultValue); { SYSWAITEVENTSEM }
   131:FunctionNotImplemented(FunctionByte,ResultValue); { SYSWAITNAMEDPIPE }
   132:FunctionNotImplemented(FunctionByte,ResultValue); { SYSWINVER }
   133:FunctionNotImplemented(FunctionByte,ResultValue); { THEN }
   134:FunctionNotImplemented(FunctionByte,ResultValue); { TIME }
   135:FunctionNotImplemented(FunctionByte,ResultValue); { TRACE }
   136:FunctionNotImplemented(FunctionByte,ResultValue); { TRANSLATE }
   137:RVNum(System.Trunc(A.Number),ResultValue); { TRUNC }
   138:FunctionNotImplemented(FunctionByte,ResultValue); { VALUE }
   139:FunctionNotImplemented(FunctionByte,ResultValue); { VAR }
   140:FunctionNotImplemented(FunctionByte,ResultValue); { VERIFY }
   141:FunctionNotImplemented(FunctionByte,ResultValue); { WORD }
   142:FunctionNotImplemented(FunctionByte,ResultValue); { WORDINDEX }
   143:FunctionNotImplemented(FunctionByte,ResultValue); { WORDLENGTH }
   144:FunctionNotImplemented(FunctionByte,ResultValue); { WORDPOS }
   145:FunctionNotImplemented(FunctionByte,ResultValue); { WORDS }
   146:FunctionNotImplemented(FunctionByte,ResultValue); { XRANGE }
   147:FunctionNotImplemented(FunctionByte,ResultValue); { X2B }
   148:FunctionNotImplemented(FunctionByte,ResultValue); { X2C }
   149:FunctionNotImplemented(FunctionByte,ResultValue); { X2D }
   150:FunctionNotImplemented(FunctionByte,ResultValue); { DO }
   151:FunctionNotImplemented(FunctionByte,ResultValue); { ELSE }
   152:FunctionNotImplemented(FunctionByte,ResultValue); { END }
   153:FunctionNotImplemented(FunctionByte,ResultValue); { EXPOSE }
   154:FunctionNotImplemented(FunctionByte,ResultValue); { ITERATE }
   155:FunctionNotImplemented(FunctionByte,ResultValue); { LEAVE }
   156:FunctionNotImplemented(FunctionByte,ResultValue); { NAME }
   157:FunctionNotImplemented(FunctionByte,ResultValue); { NOP }
   158:FunctionNotImplemented(FunctionByte,ResultValue); { NUMERIC }
   159:FunctionNotImplemented(FunctionByte,ResultValue); { OTHERWISE }
   160:FunctionNotImplemented(FunctionByte,ResultValue); { SIGNAL }
   161:FunctionNotImplemented(FunctionByte,ResultValue); { WHEN }
   Else If FindRoutineLabel(Nm)>0Then RVText(CallRoutine(Nm),ResultValue)
    Else RVText(Nm,ResultValue);
  End;
  Exit;
 End;
 VarGet(Nm,ResultValue);
End;

Procedure EPower(Var ResultValue:RexxValue);
Var
 A,B:RexxValue;
 J:Integer;
 N:Real;
Begin
 EPrimary(A);
 ESkip;
 While Copy(ExprText,ExprPos,2)='**'do Begin
  Inc(ExprPos,2);
  EPrimary(B);N:=1;
  For J:=1To System.Trunc(B.Number)do N:=N*A.Number;RVNum(N,A);
  ESkip;
 End;
 ResultValue:=A;
End;

Procedure EMul(Var ResultValue:RexxValue);
Var A,B:RexxValue;Op:String[2];
Begin
 EPower(A);
 While True Do Begin
  ESkip;Op:='';
  If Copy(ExprText,ExprPos,2)='//'Then Begin
   Op:='//';
   Inc(ExprPos,2);
  End
   Else
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['*','/','%'])Then Begin
   Op:=ExprText[ExprPos];
   Inc(ExprPos);
  End;
  If Op=''Then Break;
  EPower(B);
  If Op='*'Then RVNum(A.Number*B.Number,A)Else
  If(Op='/')and(B.Number<>0)Then RVNum(A.Number/B.Number,A)Else
  If(Op='%')and(B.Number<>0)Then RVNum(System.Trunc(A.Number/B.Number),A)Else
  If(Op='//')and(B.Number<>0)Then RVNum(System.Trunc(A.Number)mod
System.Trunc(B.Number),A)Else RVNum(0,A);
 End;
 ResultValue:=A;
End;

Procedure EAdd(Var ResultValue:RexxValue);
Var A,B:RexxValue;O:Char;
Begin
 EMul(A);
 While True Do Begin
  ESkip;
  If(ExprPos>Length(ExprText))or Not(ExprText[ExprPos]in['+','-'])Then Break;
  O:=ExprText[ExprPos];Inc(ExprPos);
  EMul(B);
  If O='+'Then RVNum(A.Number+B.Number,A)
          Else RVNum(A.Number-B.Number,A);
 End;
 ResultValue:=A;
End;

Procedure ECompare(Var ResultValue:RexxValue);
Var A,B:RexxValue;O:String[2];T:Boolean;
Begin
 EAdd(A);ESkip;O:='';If Copy(ExprText,ExprPos,2)='>='Then O:='>=' Else
 If Copy(ExprText,ExprPos,2)='<='Then O:='<='Else
 If Copy(ExprText,ExprPos,2)='<>'Then O:='<>'Else
 If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['=','>','<'])Then O:=ExprText[ExprPos];
 If O<>''Then Begin
  Inc(ExprPos,Length(O));EAdd(B);
  If A.IsNumber and B.IsNumber Then Begin
   If O='='Then T:=A.Number=B.Number Else
   If O='<>'Then T:=A.Number<>B.Number Else
   If O='>'Then T:=A.Number>B.Number Else
   If O='<'Then T:=A.Number<B.Number Else
   If O='>='Then T:=A.Number>=B.Number
            Else T:=A.Number<=B.Number;
  End
   Else
  Begin
   If O='='Then T:=StrToUpper(A.Text)=StrToUpper(B.Text) Else
   If O='<>'Then T:=StrToUpper(A.Text)<>StrToUpper(B.Text) Else
   If O='>'Then T:=StrToUpper(A.Text)>StrToUpper(B.Text)Else
   If O='<'Then T:=StrToUpper(A.Text)<StrToUpper(B.Text)Else
   If O='>='Then T:=StrToUpper(A.Text)>=StrToUpper(B.Text)
            Else T:=StrToUpper(A.Text)<=StrToUpper(B.Text);
  End;
  If T Then RVNum(1,A)Else
            RVNum(0,A);
  End;
  ResultValue:=A;
End;

Procedure Eval(S:String;Var ResultValue:RexxValue);
Var A,B:RexxValue;Tight:Boolean;
Begin
 ExprText:=S;ExprPos:=1;ECompare(A);
 While ExprPos<=Length(ExprText)do Begin
  ESkip;
  If ExprPos>Length(ExprText)Then Break;
  Tight:=Copy(ExprText,ExprPos,2)='||';
  If Tight Then Inc(ExprPos,2);
  ECompare(B);
  If Tight Then RVText(A.Text+B.Text,A)
           Else RVText(A.Text+' '+B.Text,A);
 End;
 ResultValue:=A;
End;

Function Truth(V:RexxValue):Boolean;Begin If V.IsNumber Then Truth:=V.Number<>0 Else Truth:=(V.Text<>'')and(V.Text<>'0');End;
Function CommandIndex(N:String):Integer;
Var J:Integer;
Begin
 CommandIndex:=-1;N:=StrToUpper(Clean(N));
 For J:=Low(CommandList)To High(CommandList)Do
  If N=CommandList[J]Then Begin CommandIndex:=J;Exit;End;
End;

Function WordStart(S,W:String):Boolean;
Var
 U,FirstWord:String;P:Integer;
Begin
 U:=StrToUpper(Clean(S));
 W:=StrToUpper(W);
 P:=System.Pos(' ',W);If P=0Then FirstWord:=W Else FirstWord:=Copy(W,1,P-1);
 { Toute reconnaissance d'instruction passe par CommandList. Les mots qui
   n'y figurent pas ne peuvent donc pas etre pris accidentellement pour une
   commande REXX. }
 WordStart:=(CommandIndex(FirstWord)>=0)and(Copy(U,1,Length(W))=W)and
  ((Length(U)=Length(W))or(U[Length(W)+1]in[' ',#9]));
End;

Function FindWord(S,W:String):Integer;
Var
 J,D:Integer;
 Q:Char;
 U:String;
Begin
 U:=StrToUpper(S);
 W:=StrToUpper(W);
 J:=1;D:=0;Q:=#0;FindWord:=0;
 While J<=Length(S)-Length(W)+1 Do Begin
  If Q<>#0 Then Begin
   If S[J]=Q Then Q:=#0;Inc(J);
  End
   Else
  If S[J]in['''','"']Then Begin
   Q:=S[J];Inc(J);
  End
   Else
  Begin
   If S[J]='('Then Inc(D)Else
   If S[J]=')'Then Dec(D);
   If(D=0)and(Copy(U,J,Length(W))=W)and((J=1)or(S[J-1]in[' ',#9]))and
     ((J+Length(W)>Length(S))or(S[J+Length(W)]in[' ',#9]))Then Begin
    FindWord:=J;
    Exit;
   End;
   Inc(J);
  End;
 End;
End;

Function BlockEnd(A,Z:Integer):Integer;
Var
 J,D:Integer;U:String;
Begin
 D:=1;J:=A;
 While J<=Z Do Begin
  U:=StrToUpper(Clean(PA[J]^));
  If WordStart(U,'DO')or WordStart(U,'SELECT')or(System.Pos(' THEN DO',U)>0)or WordStart(U,'ELSE DO')Then Inc(D);
  If WordStart(U,'END')Then Begin
   Dec(D);
   If D=0Then Begin
    BlockEnd:=J;
    Exit;
   End;
  End;
  Inc(J);
 End;
 BlockEnd:=Z;
End;

Var
 LoopSignal:Byte;

Procedure ExecRange(A,Z:Integer);Forward;

Procedure ParseTemplate(Value,Template:String;MakeUpper:Boolean);
Const MaxParseTokens=64;
Var
 Tokens:Array[1..MaxParseTokens]of String;
 LiteralToken:Array[1..MaxParseTokens]of Boolean;
 TokenCount,J,K,P,CursorPos,EndPos,Code,AbsolutePos:Integer;
 Q:Char;Token,Piece:String;IsNumber:Boolean;
Begin
 If MakeUpper Then Value:=StrToUpper(Value);
 TokenCount:=0;J:=1;
 While(J<=Length(Template))and(TokenCount<MaxParseTokens)Do Begin
  While(J<=Length(Template))and(Template[J]in[' ',#9])Do Inc(J);
  If J>Length(Template)Then Break;
  Inc(TokenCount);LiteralToken[TokenCount]:=False;Token:='';
  If Template[J]in['''','"']Then Begin
   Q:=Template[J];Inc(J);LiteralToken[TokenCount]:=True;
   While(J<=Length(Template))and(Template[J]<>Q)Do Begin Token:=Token+Template[J];Inc(J);End;
   If(J<=Length(Template))and(Template[J]=Q)Then Inc(J);
  End Else
   While(J<=Length(Template))and Not(Template[J]in[' ',#9])Do Begin Token:=Token+Template[J];Inc(J);End;
  Tokens[TokenCount]:=Token;
 End;

 CursorPos:=1;J:=1;
 While J<=TokenCount Do Begin
  Token:=Tokens[J];IsNumber:=Token<>'';
  For K:=1 To Length(Token)Do If Not(Token[K]in['0'..'9'])Then IsNumber:=False;
  If LiteralToken[J] Then Begin
   P:=System.Pos(Token,Copy(Value,CursorPos,255));
   If P>0Then CursorPos:=CursorPos+P-1+Length(Token)Else CursorPos:=Length(Value)+1;
   Inc(J);Continue;
  End;
  If IsNumber Then Begin Val(Token,AbsolutePos,Code);CursorPos:=AbsolutePos;Inc(J);Continue;End;

  { Une variable est delimitee par le prochain litteral ou la prochaine
    position. Entre deux variables, elle recoit un mot; la derniere recoit
    tout le reste, conformement aux modeles PARSE de REXX. }
  If J=TokenCount Then Begin Piece:=Clean(Copy(Value,CursorPos,255));CursorPos:=Length(Value)+1;End
  Else If LiteralToken[J+1]Then Begin
   P:=System.Pos(Tokens[J+1],Copy(Value,CursorPos,255));
   If P>0Then Begin Piece:=Clean(Copy(Value,CursorPos,P-1));CursorPos:=CursorPos+P-1+Length(Tokens[J+1]);End
    Else Begin Piece:=Clean(Copy(Value,CursorPos,255));CursorPos:=Length(Value)+1;End;
   Inc(J);
  End Else Begin
   IsNumber:=Tokens[J+1]<>'';
   For K:=1 To Length(Tokens[J+1])Do If Not(Tokens[J+1][K]in['0'..'9'])Then IsNumber:=False;
   If IsNumber Then Begin
    Val(Tokens[J+1],AbsolutePos,Code);EndPos:=AbsolutePos-1;
    If EndPos<CursorPos Then Piece:=''Else Piece:=Clean(Copy(Value,CursorPos,EndPos-CursorPos+1));
    CursorPos:=AbsolutePos;Inc(J);
   End Else Begin
    While(CursorPos<=Length(Value))and(Value[CursorPos]in[' ',#9])Do Inc(CursorPos);
    EndPos:=CursorPos;While(EndPos<=Length(Value))and Not(Value[EndPos]in[' ',#9])Do Inc(EndPos);
    Piece:=Copy(Value,CursorPos,EndPos-CursorPos);CursorPos:=EndPos;
   End;
  End;
  If Token<>'.'Then VarSet(Token,Piece);
  Inc(J);
 End;
End;

Procedure RunAddressCommand(EnvironmentName,CommandText:String);
Var CommandProcessor:String;
Begin
 If CommandText=''Then Exit;
 EnvironmentName:=StrToUpper(Clean(EnvironmentName));
 If(EnvironmentName='SYSTEM')or(EnvironmentName='COMMAND')or(EnvironmentName='CMD')Then Begin
  CommandProcessor:=GetEnv('COMSPEC');If CommandProcessor=''Then CommandProcessor:='CMD.EXE';
  Exec(CommandProcessor,'/C '+CommandText);
  If DosError<>0Then WriteLn('Erreur ADDRESS ',EnvironmentName,': ',DosError);
 End Else WriteLn('Environnement ADDRESS non supporte: ',EnvironmentName);
End;

Procedure ExecOne(S:String);
Var P,J:Integer;V:RexxValue;Name,Rest,ArgName,FirstWord,CommandText,OldAddress:String;CommandByte:Byte;
Begin
 S:=Clean(S);If S=''Then Exit;
 P:=1;While(P<=Length(S))and(S[P]in['A'..'Z','a'..'z','_'])Do Inc(P);
 FirstWord:=Copy(S,1,P-1);J:=CommandIndex(FirstWord);
 If J<0Then CommandByte:=255 Else CommandByte:=Byte(J);
 Case CommandByte Of
  2:Begin { ADDRESS }
   Rest:=Clean(Copy(S,8,255));
   If Rest=''Then Begin
    OldAddress:=CurrentAddress;CurrentAddress:=PreviousAddress;PreviousAddress:=OldAddress;
   End Else If WordStart(Rest,'VALUE')Then Begin
    Eval(Clean(Copy(Rest,6,255)),V);Name:=StrToUpper(V.Text);
    PreviousAddress:=CurrentAddress;CurrentAddress:=Name;
   End Else Begin
    P:=System.Pos(' ',Rest);
    If P=0Then Begin Name:=Rest;CommandText:='';End
     Else Begin Name:=Copy(Rest,1,P-1);CommandText:=Clean(Copy(Rest,P+1,255));End;
    Name:=StrToUpper(Name);PreviousAddress:=CurrentAddress;CurrentAddress:=Name;
    If CommandText<>''Then Begin Eval(CommandText,V);RunAddressCommand(CurrentAddress,V.Text);End;
   End;
  End;
  65:Begin { SAY }
   Eval(Copy(S,4,255),V);WriteLn(V.Text);
  End;
  9:Begin { CALL }
   Rest:=Clean(Copy(S,5,255));P:=System.Pos(' ',Rest);
   If P>0Then Begin Name:=Copy(Rest,1,P-1);Rest:=Clean(Copy(Rest,P+1,255));End Else Begin Name:=Rest;Rest:='';End;
   InvokeArgCount:=0;
   While(Rest<>'')and(InvokeArgCount<MaxRoutineArgs)do Begin
    P:=System.Pos(',',Rest);If P>0Then Begin
     Eval(Copy(Rest,1,P-1),V);
     Delete(Rest,1,P);
     Rest:=Clean(Rest);
    End
     Else
    Begin
     Eval(Rest,V);
     Rest:='';
    End;
    Inc(InvokeArgCount);InvokeArgs[InvokeArgCount]:=V.Text;
   End;
   VarSet('RESULT',CallRoutine(Name));
  End;
  48:Begin { PARSE }
   If WordStart(S,'PARSE ARG')Then Begin
    Rest:=Clean(Copy(S,10,255));J:=1;
    While(Rest<>'')do Begin
     P:=System.Pos(',',Rest);If P>0Then Begin
      ArgName:=Clean(Copy(Rest,1,P-1));
      Delete(Rest,1,P);
      Rest:=Clean(Rest);
     End
      Else
     Begin
      ArgName:=Clean(Rest);
      Rest:='';
     End;
     If J<=CurrentArgCount Then VarSet(ArgName,CurrentArgs[J])
                           Else VarSet(ArgName,'');
     Inc(J);
    End;
   End
    Else
   If WordStart(S,'PARSE UPPER VAR')Then Begin
    Rest:=Clean(Copy(S,16,255));P:=System.Pos(' ',Rest);
    If P>0Then Begin
     Name:=Copy(Rest,1,P-1);
     VarGet(Name,V);ParseTemplate(V.Text,Clean(Copy(Rest,P+1,255)),True);
    End;
   End
    Else
   If WordStart(S,'PARSE VAR')Then Begin
    Rest:=Clean(Copy(S,10,255));P:=System.Pos(' ',Rest);
    If P>0Then Begin
     Name:=Copy(Rest,1,P-1);VarGet(Name,V);
     ParseTemplate(V.Text,Clean(Copy(Rest,P+1,255)),False);
    End;
   End
    Else
   If WordStart(S,'PARSE VERSION')Then
    ParseTemplate('REXX-DEVCOOLS 1.0',Clean(Copy(S,14,255)),False)
    Else
   If WordStart(S,'PARSE SOURCE')Then
    ParseTemplate('WINDOWS COMMAND '+FileName,Clean(Copy(S,13,255)),False);
  End;
  56:Begin { RETURN }
   Rest:=Clean(Copy(S,7,255));If Rest<>''Then Begin
    Eval(Rest,V);
    RoutineResult:=V.Text;
   End
    Else
   RoutineResult:='';RoutineReturning:=True;
  End;
  49:; { PROCEDURE est traite lors de l'entree dans CallRoutine }
  158:Begin { NUMERIC }
   If WordStart(S,'NUMERIC DIGITS')Then Begin
    Rest:=Clean(Copy(S,15,255));If Rest=''Then NumericDigitsValue:=9
     Else Begin Eval(Rest,V);J:=System.Trunc(V.Number);If J>0Then NumericDigitsValue:=J;End;
    If NumericFuzzValue>=NumericDigitsValue Then NumericFuzzValue:=NumericDigitsValue-1;
   End Else If WordStart(S,'NUMERIC FUZZ')Then Begin
    Rest:=Clean(Copy(S,13,255));If Rest=''Then NumericFuzzValue:=0
     Else Begin Eval(Rest,V);J:=System.Trunc(V.Number);If(J>=0)and(J<NumericDigitsValue)Then NumericFuzzValue:=J;End;
   End Else If WordStart(S,'NUMERIC FORM')Then Begin
    Rest:=StrToUpper(Clean(Copy(S,13,255)));If Rest=''Then NumericFormValue:='SCIENTIFIC'
     Else If(Rest='SCIENTIFIC')or(Rest='ENGINEERING')Then NumericFormValue:=Rest;
   End;
  End;
  160:Begin { SIGNAL }
   If WordStart(S,'SIGNAL ON')Then Begin
    Rest:=Clean(Copy(S,10,255));P:=FindWord(Rest,'NAME');
    If P>0Then Begin Name:=StrToUpper(Clean(Copy(Rest,P+4,255)));Rest:=StrToUpper(Clean(Copy(Rest,1,P-1)));End
     Else Begin Rest:=StrToUpper(Rest);Name:=Rest;End;
    If Rest='HALT'Then Begin SignalHalt:=True;SignalHaltName:=Name;End
    Else If Rest='NOVALUE'Then Begin SignalNoValue:=True;SignalNoValueName:=Name;End
    Else If Rest='ERROR'Then Begin SignalError:=True;SignalErrorName:=Name;End
    Else If Rest='SYNTAX'Then Begin SignalSyntax:=True;SignalSyntaxName:=Name;End;
   End Else If WordStart(S,'SIGNAL OFF')Then Begin
    Rest:=StrToUpper(Clean(Copy(S,11,255)));If Rest='HALT'Then SignalHalt:=False
    Else If Rest='NOVALUE'Then SignalNoValue:=False Else If Rest='ERROR'Then SignalError:=False
    Else If Rest='SYNTAX'Then SignalSyntax:=False;
   End Else If WordStart(S,'SIGNAL VALUE')Then Begin
    Eval(Clean(Copy(S,13,255)),V);Name:=V.Text;SignalTargetLine:=FindRoutineLabel(Name);
   End Else Begin Name:=Clean(Copy(S,7,255));SignalTargetLine:=FindRoutineLabel(Name);End;
  End;
  157:; { NOP }
  155:LoopSignal:=1; { LEAVE }
  154:LoopSignal:=2; { ITERATE }
  31:Terminated:=True; { EXIT }
  Else Begin
   If S[Length(S)]=':'Then Exit;
   P:=System.Pos('=',S);If P>1Then Begin Eval(Copy(S,P+1,255),V);VarSet(Copy(S,1,P-1),V.Text);End
    Else WriteLn('Commande non reconnue: ',S);
  End;
 End;
End;

Procedure ExecRange(A,Z:Integer);
Var
 J,P,E,K,ToPos,ByPos,EqPos,RepeatCount:Integer;
 S,C,Act,LoopVar:String;
 V:RexxValue;Done:Boolean;
 LoopValue,LoopEnd,LoopStep:Real;
Begin
 J:=A;
 While(J<=Z)and Not Terminated and Not RoutineReturning and(LoopSignal=0)do Begin
  S:=Clean(PA[J]^);
  If(S='')or(Copy(S,1,2)='/*')Then Inc(J) Else
  If WordStart(S,'IF')Then Begin
   P:=FindWord(S,'THEN');
   If P=0Then Begin
    WriteLn('THEN manquant ligne ',J);
    Inc(J);
   End
    Else
   Begin
    C:=Copy(S,3,P-3);
    Act:=Clean(Copy(S,P+4,255));
    Eval(C,V);
    If StrToUpper(Act)='DO'Then Begin
     E:=BlockEnd(J+1,Z);
     If Truth(V)Then ExecRange(J+1,E-1);J:=E+1;If(J<=Z)and WordStart(PA[J]^,'ELSE')Then Begin
      Act:=Clean(Copy(Clean(PA[J]^),5,255));If StrToUpper(Act)='DO'Then Begin
      E:=BlockEnd(J+1,Z);
      If Not Truth(V)Then ExecRange(J+1,E-1);
      J:=E+1;
     End
      Else
     Begin
      If Not Truth(V)Then ExecOne(Act);
      Inc(J);
     End;
    End;
   End
    Else
   Begin
    If Truth(V)Then ExecOne(Act);
    Inc(J);
    If(J<=Z)and WordStart(PA[J]^,'ELSE')Then Begin
     If Not Truth(V)Then ExecOne(Copy(Clean(PA[J]^),5,255));
     Inc(J);
    End;
   End;
  End;
 End
  Else
 If WordStart(S,'SELECT')Then Begin
  E:=BlockEnd(J+1,Z);Done:=False;K:=J+1;
  While K<E Do Begin
   Act:=Clean(PA[K]^);
   If WordStart(Act,'WHEN')Then Begin
    P:=FindWord(Act,'THEN');
    If(P>0)and Not Done Then Begin
     Eval(Copy(Act,5,P-5),V);
     If Truth(V)Then Begin
      ExecOne(Copy(Act,P+4,255));
      Done:=True;
     End;
    End;
   End
    Else
   If WordStart(Act,'OTHERWISE')and Not Done Then Begin
    ExecOne(Copy(Act,10,255));
    Done:=True;
   End;
   Inc(K);
  End;
  J:=E+1;
 End
  Else
 If WordStart(S,'DO WHILE')or WordStart(S,'DO UNTIL')Then Begin
  E:=BlockEnd(J+1,Z);
  C:=Copy(S,9,255);
  Repeat
   Eval(C,V);
   If WordStart(S,'DO WHILE')Then Begin
    If Not Truth(V)Then Break;
   End
    Else
   If Truth(V)Then Break;
   LoopSignal:=0;ExecRange(J+1,E-1);
   If LoopSignal=1Then Begin
    LoopSignal:=0;
    Break;
   End;
   If LoopSignal=2Then LoopSignal:=0;
  Until Terminated;J:=E+1;
 End
  Else
 If WordStart(S,'DO FOREVER')Then Begin
  E:=BlockEnd(J+1,Z);
  Repeat
   LoopSignal:=0;ExecRange(J+1,E-1);
   If LoopSignal=1Then Begin
    LoopSignal:=0;
    Break;
   End;
   If LoopSignal=2Then LoopSignal:=0;
   Until Terminated;
   J:=E+1;
  End
   Else
  If WordStart(S,'DO')and(System.Pos('=',S)>0)and(FindWord(S,'TO')>0)Then Begin
   E:=BlockEnd(J+1,Z);
   EqPos:=System.Pos('=',S);
   ToPos:=FindWord(S,'TO');
   ByPos:=FindWord(S,'BY');
   LoopVar:=Clean(Copy(S,3,EqPos-3));
   Eval(Copy(S,EqPos+1,ToPos-EqPos-1),V);LoopValue:=V.Number;
   If ByPos>0Then Begin
    Eval(Copy(S,ToPos+2,ByPos-ToPos-2),V);LoopEnd:=V.Number;
    Eval(Copy(S,ByPos+2,255),V);LoopStep:=V.Number;
   End
    Else
   Begin
    Eval(Copy(S,ToPos+2,255),V);LoopEnd:=V.Number;
    LoopStep:=1;
   End;
   If LoopStep=0Then LoopStep:=1;
   While (((LoopStep>0)and(LoopValue<=LoopEnd))or((LoopStep<0)and(LoopValue>=LoopEnd)))and Not Terminated Do Begin
    VarSet(LoopVar,NumToText(LoopValue));LoopSignal:=0;ExecRange(J+1,E-1);
    If LoopSignal=1Then Begin LoopSignal:=0;Break;End;
    If LoopSignal=2Then LoopSignal:=0;
    LoopValue:=LoopValue+LoopStep;
   End;
   J:=E+1;
  End
   Else
  If WordStart(S,'DO')and(Clean(Copy(S,3,255))<>'')Then Begin
   E:=BlockEnd(J+1,Z);
   Eval(Copy(S,3,255),V);RepeatCount:=System.Trunc(V.Number);
   For K:=1 To RepeatCount Do Begin
    LoopSignal:=0;
    ExecRange(J+1,E-1);
    If LoopSignal=1Then Begin
     LoopSignal:=0;
     Break;
    End;
    If LoopSignal=2Then LoopSignal:=0;
    If Terminated Then Break;
   End;
   J:=E+1;
  End
  Else
  If WordStart(S,'DO')Then Begin
   E:=BlockEnd(J+1,Z);
   ExecRange(J+1,E-1);
   J:=E+1;
  End
   Else
  If WordStart(S,'END')or WordStart(S,'ELSE')Then Inc(J)
   Else
  Begin
   ExecOne(S);
   Inc(J);
  End;
  If SignalTargetLine>0Then Begin
   If(SignalTargetLine>=A)and(SignalTargetLine<=Z)Then Begin J:=SignalTargetLine+1;SignalTargetLine:=0;End
    Else Exit;
  End;
 End;
End;

Function FindRoutineLabel(Name:String):Integer;
Var J:Integer;S:String;
Begin
 FindRoutineLabel:=0;Name:=StrToUpper(Clean(Name));
 For J:=1 To NumberLine Do Begin
  S:=Clean(PA[J]^);
  If(Length(S)>1)and(S[Length(S)]=':')Then
   If StrToUpper(Clean(Copy(S,1,Length(S)-1)))=Name Then Begin FindRoutineLabel:=J;Exit;End;
 End;
End;

Function CallRoutine(Name:String):String;
Var
 LabelLine,EndLine,J,K,SavedArgCount,SavedExprPos,
  SavedInvokeCount,ExposeCount:Integer;
 S,ProcedureText,ExposeName:String;
 SavedReturning,HasProcedure:Boolean;
 SavedResult,SavedExprText:String;
 SavedVariables:PRexxVariable;
 ExposedVariable:PRexxVariable;
 SavedArgs,SavedInvokeArgs:Array[1..MaxRoutineArgs]of String;
 ExposeNames,ExposeValues:Array[1..MaxRoutineArgs]of String;
Begin
 Name:=StrToUpper(Clean(Name));LabelLine:=FindRoutineLabel(Name);
 If LabelLine=0Then Begin CallRoutine:=Name;Exit;End;

 { Sauvegarder tout l'etat que l'evaluation recursive peut modifier. }
 SavedExprText:=ExprText;SavedExprPos:=ExprPos;
 SavedReturning:=RoutineReturning;SavedResult:=RoutineResult;
 SavedArgCount:=CurrentArgCount;
 For J:=1 To MaxRoutineArgs Do Begin
  SavedArgs[J]:=CurrentArgs[J];
  SavedInvokeArgs[J]:=InvokeArgs[J];
  If J<=InvokeArgCount Then CurrentArgs[J]:=InvokeArgs[J]Else CurrentArgs[J]:='';
 End;
 CurrentArgCount:=InvokeArgCount;SavedInvokeCount:=InvokeArgCount;

 EndLine:=NumberLine;
 For J:=LabelLine+1 To NumberLine Do Begin
  S:=Clean(PA[J]^);
  If(Length(S)>1)and(S[Length(S)]=':')Then Begin EndLine:=J-1;Break;End;
 End;

 J:=LabelLine+1;
 While(J<=EndLine)and(Clean(PA[J]^)='')Do Inc(J);
 ProcedureText:='';HasProcedure:=False;ExposeCount:=0;
 If(J<=EndLine)and WordStart(Clean(PA[J]^),'PROCEDURE')Then Begin
  HasProcedure:=True;ProcedureText:=Clean(Copy(Clean(PA[J]^),10,255));
  If WordStart(ProcedureText,'EXPOSE')Then Begin
   ProcedureText:=Clean(Copy(ProcedureText,7,255));
   While(ProcedureText<>'')and(ExposeCount<MaxRoutineArgs)Do Begin
    K:=System.Pos(' ',ProcedureText);
    If K=0Then Begin ExposeName:=ProcedureText;ProcedureText:='';End
     Else Begin ExposeName:=Copy(ProcedureText,1,K-1);Delete(ProcedureText,1,K);ProcedureText:=Clean(ProcedureText);End;
    Inc(ExposeCount);ExposeNames[ExposeCount]:=StrToUpper(Clean(ExposeName));
   End;
  End;
 End;

 If HasProcedure Then Begin
  SavedVariables:=Variables;Variables:=Nil;
  For K:=1 To ExposeCount Do Begin
   ExposeValues[K]:='';
   ExposedVariable:=VarFind(SavedVariables,ExposeNames[K]);
   If ExposedVariable<>Nil Then ExposeValues[K]:=ExposedVariable^.Value;
   VarSet(ExposeNames[K],ExposeValues[K]);
  End;
 End;

 RoutineReturning:=False;RoutineResult:='';
 ExecRange(LabelLine+1,EndLine);
 CallRoutine:=RoutineResult;

 If HasProcedure Then Begin
  For K:=1 To ExposeCount Do Begin
   ExposedVariable:=VarFind(Variables,ExposeNames[K]);
   If ExposedVariable<>Nil Then ExposeValues[K]:=ExposedVariable^.Value Else ExposeValues[K]:='';
  End;
  FreeVariables(Variables);Variables:=SavedVariables;
  For K:=1 To ExposeCount Do VarSet(ExposeNames[K],ExposeValues[K]);
 End;

 CurrentArgCount:=SavedArgCount;InvokeArgCount:=SavedInvokeCount;
 For J:=1 To MaxRoutineArgs Do Begin CurrentArgs[J]:=SavedArgs[J];InvokeArgs[J]:=SavedInvokeArgs[J];End;
 RoutineReturning:=SavedReturning;RoutineResult:=SavedResult;
 ExprText:=SavedExprText;ExprPos:=SavedExprPos;
End;

Procedure ExecuteCommand;Begin
 Variables:=Nil;
 Terminated:=False;
 LoopSignal:=0;
 CurrentArgCount:=InitialArgCount;
 For I:=1 To MaxRoutineArgs Do CurrentArgs[I]:=InitialArgs[I];
 InvokeArgCount:=0;RoutineReturning:=False;RoutineResult:='';
 NumericDigitsValue:=9;NumericFuzzValue:=0;NumericFormValue:='SCIENTIFIC';
 SignalTargetLine:=0;SignalHalt:=False;SignalNoValue:=False;SignalError:=False;SignalSyntax:=False;
 SignalHaltName:='HALT';SignalNoValueName:='NOVALUE';SignalErrorName:='ERROR';SignalSyntaxName:='SYNTAX';
 CurrentAddress:='SYSTEM';PreviousAddress:='SYSTEM';
 CharInStreamCount:=0;
 If NumberLine>0Then ExecRange(1,NumberLine);
 FreeVariables(Variables);
End;

BEGIN
 {$IFDEF FPC}
  {$IFDEF WINDOWS}
   SetUseACP(False);
  {$ENDIF}
 {$ENDIF}
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')Then Begin
  WriteLn('REXX : Cette commande permet de lancer le langage de programmation REXX');
  WriteLn;
  WriteLn('Syntaxe : REXX [fichier.REX]');
 End
  Else
 Begin
 FileName:='';
  InitialArgCount:=0;
  NumberLine:=0;CurrNumberLine:=0;
  If ParamCount>0 Then Begin
   FileName:=ParamStr(1);
   If ParamCount>1Then Begin
    InitialArgCount:=1;InitialArgs[1]:='';
    For I:=2 to ParamCount do Begin
     If InitialArgs[1]<>''Then InitialArgs[1]:=InitialArgs[1]+' ';
     InitialArgs[1]:=InitialArgs[1]+ParamStr(I);
    End;
   End;
   LoadCommand;
   ExecuteCommand;
  End
 End;
END.
