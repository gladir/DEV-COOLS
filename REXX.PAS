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

Const
 MaxVariables=256;

Type
 RexxValue=Record
  Text:String;
  Number:Real;
  IsNumber:Boolean;
 End;
 RexxVariable=Record
  Name:String[64];
  Value:String;
 End;

Var
 Variables:Array[1..MaxVariables]of RexxVariable;
 VariableCount:Integer;
 ExprText:String;
 ExprPos:Integer;

Const
 MaxRoutineArgs=16;

Var
 InvokeArgs:Array[1..MaxRoutineArgs]of String;
 InvokeArgCount:Integer;
 CurrentArgs:Array[1..MaxRoutineArgs]of String;
 CurrentArgCount:Integer;
 RoutineReturning:Boolean;
 RoutineResult:String;
 NumericDigitsValue:Integer;
 NumericFuzzValue:Integer;
 NumericFormValue:String[16];
 SignalTargetLine:Integer;
 SignalHalt,SignalNoValue,SignalError,SignalSyntax:Boolean;
 SignalHaltName,SignalNoValueName,SignalErrorName,SignalSyntaxName:String[64];

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

Function RVText(S:String):RexxValue;
Var V:RexxValue;C:Integer;
Begin V.Text:=S;Val(Clean(S),V.Number,C);V.IsNumber:=C=0;If Not V.IsNumber Then V.Number:=0;RVText:=V;End;
Function RVNum(N:Real):RexxValue;
Var V:RexxValue;Begin V.Number:=N;V.IsNumber:=True;V.Text:=NumToText(N);RVNum:=V;End;

Function VarIndex(N:String):Integer;
Var J:Integer;
Begin N:=StrToUpper(N);VarIndex:=0;For J:=1 To VariableCount Do If Variables[J].Name=N Then Begin VarIndex:=J;Exit;End;End;
Function VarGet(N:String):RexxValue;
Var J:Integer;
Begin J:=VarIndex(N);If J=0Then VarGet:=RVText(StrToUpper(N))Else VarGet:=RVText(Variables[J].Value);End;
Procedure VarSet(N,S:String);
Var J:Integer;
Begin N:=StrToUpper(Clean(N));J:=VarIndex(N);If(J=0)and(VariableCount<MaxVariables)Then Begin Inc(VariableCount);J:=VariableCount;Variables[J].Name:=N;End;If J>0Then Variables[J].Value:=S;End;

Procedure ESkip;Begin While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in[' ',#9])do Inc(ExprPos);End;
Function ECompare:RexxValue;Forward;
Function FindRoutineLabel(Name:String):Integer;Forward;
Function CallRoutine(Name:String):String;Forward;
Function CommandIndex(N:String):Integer;Forward;

Function FunctionNotImplemented(FunctionByte:Byte):RexxValue;
Begin
 WriteLn('Fonction non implementee: ',CommandList[FunctionByte]);
 FunctionNotImplemented:=RVText(CommandList[FunctionByte]);
End;

Function EPrimary:RexxValue;
Var Q:Char;S,Nm:String;N:Real;C,J,MinimumLength:Integer;FunctionByte:Byte;A,B,D:RexxValue;
Begin
 ESkip;If ExprPos>Length(ExprText)Then Begin EPrimary:=RVText('');Exit;End;
 If ExprText[ExprPos]in['''','"']Then Begin Q:=ExprText[ExprPos];Inc(ExprPos);S:='';While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]<>Q)do Begin S:=S+ExprText[ExprPos];Inc(ExprPos);End;If ExprPos<=Length(ExprText)Then Inc(ExprPos);EPrimary:=RVText(S)
;Exit;End;
 If ExprText[ExprPos]='('Then Begin Inc(ExprPos);EPrimary:=ECompare;ESkip;If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=')')Then Inc(ExprPos);Exit;End;
 If ExprText[ExprPos]='-'Then Begin Inc(ExprPos);A:=EPrimary();EPrimary:=RVNum(-A.Number);Exit;End;
 If ExprText[ExprPos]in['0'..'9','.']Then Begin S:='';While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0'..'9','.'])do Begin S:=S+ExprText[ExprPos];Inc(ExprPos);End;Val(S,N,C);If C<>0Then N:=0;EPrimary:=RVNum(N);Exit;End;
 Nm:='';While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['A'..'Z','a'..'z','0'..'9','_','.'])do Begin Nm:=Nm+ExprText[ExprPos];Inc(ExprPos);End;
 ESkip;
 If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]='(')Then Begin
  Inc(ExprPos);InvokeArgCount:=0;ESkip;
  While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]<>')')and(InvokeArgCount<MaxRoutineArgs)do Begin
   A:=ECompare;Inc(InvokeArgCount);InvokeArgs[InvokeArgCount]:=A.Text;ESkip;
   If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=',')Then Begin Inc(ExprPos);ESkip;End Else Break;
  End;
  If ExprPos<=Length(ExprText)Then If ExprText[ExprPos]=')'Then Inc(ExprPos);
  If InvokeArgCount>0Then A:=RVText(InvokeArgs[1])Else A:=RVText('');
  If InvokeArgCount>1Then B:=RVText(InvokeArgs[2])Else B:=RVText('');
  If InvokeArgCount>2Then D:=RVText(InvokeArgs[3])Else D:=RVText('');
  Nm:=StrToUpper(Nm);
  C:=CommandIndex(Nm);If C<0Then FunctionByte:=255 Else FunctionByte:=Byte(C);
  Case FunctionByte Of
   0:Begin { ABBREV }
    If InvokeArgCount>2Then MinimumLength:=System.Trunc(D.Number)
     Else MinimumLength:=Length(B.Text);
    If MinimumLength<0Then MinimumLength:=0;
    If(Length(B.Text)>=MinimumLength)and(Length(B.Text)<=Length(A.Text))and
      (Copy(A.Text,1,Length(B.Text))=B.Text)Then EPrimary:=RVNum(1)
     Else EPrimary:=RVNum(0);
   End;
   1:EPrimary:=RVNum(Abs(A.Number)); { ABS }
   2:EPrimary:=FunctionNotImplemented(FunctionByte); { ADDRESS }
   3:EPrimary:=FunctionNotImplemented(FunctionByte); { ARG }
   4:EPrimary:=FunctionNotImplemented(FunctionByte); { B2X }
   5:EPrimary:=FunctionNotImplemented(FunctionByte); { BEEP }
   6:EPrimary:=FunctionNotImplemented(FunctionByte); { BITAND }
   7:EPrimary:=FunctionNotImplemented(FunctionByte); { BITOR }
   8:EPrimary:=FunctionNotImplemented(FunctionByte); { BITXOR }
   9:EPrimary:=FunctionNotImplemented(FunctionByte); { CALL }
   10:EPrimary:=FunctionNotImplemented(FunctionByte); { CENTER }
   11:EPrimary:=FunctionNotImplemented(FunctionByte); { CHANGESTR }
   12:EPrimary:=FunctionNotImplemented(FunctionByte); { CHARIN }
   13:EPrimary:=FunctionNotImplemented(FunctionByte); { CHAROUT }
   14:EPrimary:=FunctionNotImplemented(FunctionByte); { CHARS }
   15:EPrimary:=FunctionNotImplemented(FunctionByte); { COMPARE }
   16:EPrimary:=FunctionNotImplemented(FunctionByte); { CONDITION }
   17:EPrimary:=FunctionNotImplemented(FunctionByte); { COPIES }
   18:EPrimary:=FunctionNotImplemented(FunctionByte); { COUNTSTR }
   19:EPrimary:=FunctionNotImplemented(FunctionByte); { C2D }
   20:EPrimary:=FunctionNotImplemented(FunctionByte); { C2X }
   21:EPrimary:=FunctionNotImplemented(FunctionByte); { DATATYPE }
   22:EPrimary:=FunctionNotImplemented(FunctionByte); { DATE }
   23:EPrimary:=FunctionNotImplemented(FunctionByte); { DELSTR }
   24:EPrimary:=FunctionNotImplemented(FunctionByte); { DELWORD }
   25:EPrimary:=RVNum(NumericDigitsValue); { DIGITS }
   26:EPrimary:=FunctionNotImplemented(FunctionByte); { DIRECTORY }
   27:EPrimary:=FunctionNotImplemented(FunctionByte); { D2C }
   28:EPrimary:=FunctionNotImplemented(FunctionByte); { D2X }
   29:EPrimary:=FunctionNotImplemented(FunctionByte); { ENDLOCAL }
   30:EPrimary:=FunctionNotImplemented(FunctionByte); { ERRORTEXT }
   31:EPrimary:=FunctionNotImplemented(FunctionByte); { EXIT }
   32:EPrimary:=FunctionNotImplemented(FunctionByte); { FILESPEC }
   33:EPrimary:=RVText(NumericFormValue); { FORM }
   34:EPrimary:=FunctionNotImplemented(FunctionByte); { FORMAT }
   35:EPrimary:=RVNum(NumericFuzzValue); { FUZZ }
   36:EPrimary:=FunctionNotImplemented(FunctionByte); { IF }
   37:EPrimary:=FunctionNotImplemented(FunctionByte); { INSERT }
   38:EPrimary:=FunctionNotImplemented(FunctionByte); { LASTPOS }
   39:EPrimary:=RVText(Copy(A.Text,1,System.Trunc(B.Number))); { LEFT }
   40:EPrimary:=RVNum(Length(A.Text)); { LENGTH }
   41:EPrimary:=FunctionNotImplemented(FunctionByte); { LINEIN }
   42:EPrimary:=FunctionNotImplemented(FunctionByte); { LINEOUT }
   43:EPrimary:=FunctionNotImplemented(FunctionByte); { LINES }
   44:Begin { MAX }
    If A.Number>B.Number Then N:=A.Number Else N:=B.Number;EPrimary:=RVNum(N);
   End;
   45:Begin { MIN }
    If A.Number<B.Number Then N:=A.Number Else N:=B.Number;EPrimary:=RVNum(N);
   End;
   46:EPrimary:=FunctionNotImplemented(FunctionByte); { OPTIONS }
   47:EPrimary:=FunctionNotImplemented(FunctionByte); { OVERLAY }
   48:EPrimary:=FunctionNotImplemented(FunctionByte); { PARSE }
   49:EPrimary:=FunctionNotImplemented(FunctionByte); { PROCEDURE }
   50:EPrimary:=FunctionNotImplemented(FunctionByte); { POS }
   51:EPrimary:=FunctionNotImplemented(FunctionByte); { PULL }
   52:EPrimary:=FunctionNotImplemented(FunctionByte); { PUSH }
   53:EPrimary:=FunctionNotImplemented(FunctionByte); { QUEUE }
   54:EPrimary:=FunctionNotImplemented(FunctionByte); { QUEUED }
   55:EPrimary:=FunctionNotImplemented(FunctionByte); { RANDOM }
   56:EPrimary:=FunctionNotImplemented(FunctionByte); { RETURN }
   57:EPrimary:=FunctionNotImplemented(FunctionByte); { REVERSE }
   58:Begin { RIGHT }
    J:=Length(A.Text)-System.Trunc(B.Number)+1;If J<1Then J:=1;EPrimary:=RVText(Copy(A.Text,J,255));
   End;
   59:EPrimary:=FunctionNotImplemented(FunctionByte); { RXFUNCADD }
   60:EPrimary:=FunctionNotImplemented(FunctionByte); { RXFUNCDROP }
   61:EPrimary:=FunctionNotImplemented(FunctionByte); { RXFUNCQUERY }
   62:EPrimary:=FunctionNotImplemented(FunctionByte); { RXMESSAGEBOX }
   63:EPrimary:=FunctionNotImplemented(FunctionByte); { RXQUEUE }
   64:EPrimary:=FunctionNotImplemented(FunctionByte); { RXWINEXEC }
   65:EPrimary:=FunctionNotImplemented(FunctionByte); { SAY }
   66:EPrimary:=FunctionNotImplemented(FunctionByte); { SELECT }
   67:EPrimary:=FunctionNotImplemented(FunctionByte); { SETLOCAL }
   68:Begin { SIGN }
    If A.Number<0Then N:=-1 Else If A.Number>0Then N:=1 Else N:=0;EPrimary:=RVNum(N);
   End;
   69:EPrimary:=FunctionNotImplemented(FunctionByte); { SOURCELINE }
   70:EPrimary:=FunctionNotImplemented(FunctionByte); { SPACE }
   71:EPrimary:=FunctionNotImplemented(FunctionByte); { STREAM }
   72:EPrimary:=FunctionNotImplemented(FunctionByte); { STRIP }
   73:EPrimary:=FunctionNotImplemented(FunctionByte); { SUBSTR }
   74:EPrimary:=FunctionNotImplemented(FunctionByte); { SUBWORD }
   75:EPrimary:=FunctionNotImplemented(FunctionByte); { SYMBOL }
   76:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSADDREXXMACRO }
   77:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSBOOTDRIVE }
   78:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSCLEARREXXMACROSPACE }
   79:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSCLOSEEVENTSEM }
   80:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSCLOSEMUTEXSEM }
   81:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSCLS }
   82:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSCREATEEVENTSEM }
   83:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSCREATEMUTEXSEM }
   84:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSCREATEOBJECT }
   85:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSCURPOS }
   86:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSCURSTATE }
   87:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSDEREGISTEROBJECTCLASS }
   88:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSDESTROYOBJECT }
   89:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSDRIVEINFO }
   90:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSDRIVEMAP }
   91:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSDROPFUNCS }
   92:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSDROPREXXMACRO }
   93:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSFILEDELETE }
   94:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSFILETREE }
   95:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSFILESEARCH }
   96:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSFILESYSTEMTYPE }
   97:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSGETEA }
   98:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSGETKEY }
   99:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSGETMESSAGE }
   100:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSINI }
   101:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSLOADFUNCS }
   102:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSLOADREXXMACROSPACE }
   103:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSMKDIR }
   104:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSOPENEVENTSEM }
   105:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSOPENMUTEXSEM }
   106:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSOS2VER }
   107:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSPOSTEVENTSEM }
   108:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSPULSEEVENTSEM }
   109:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSPUTEA }
   110:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSQUERYCLASSLIST }
   111:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSQUERYREXXMACRO }
   112:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSREGISTEROBJECTCLASS }
   113:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSRELEASEMUTEXSEM }
   114:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSREORDERREXXMACRO }
   115:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSREQUESTMUTEXSEM }
   116:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSRESETEVENTSEM }
   117:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSRMDIR }
   118:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSSAVEREXXMACROSPACE }
   119:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSSEARCHPATH }
   120:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSSETICON }
   121:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSSETOBJECTDATA }
   122:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSSETPRIORITY }
   123:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSSLEEP }
   124:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSSWITCHSESSION }
   125:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSSYSTEMDIRECTORY }
   126:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSTEMPFILENAME }
   127:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSTEXTSCREENREAD }
   128:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSTEXTSCREENSIZE }
   129:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSVOLUMELABEL }
   130:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSWAITEVENTSEM }
   131:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSWAITNAMEDPIPE }
   132:EPrimary:=FunctionNotImplemented(FunctionByte); { SYSWINVER }
   133:EPrimary:=FunctionNotImplemented(FunctionByte); { THEN }
   134:EPrimary:=FunctionNotImplemented(FunctionByte); { TIME }
   135:EPrimary:=FunctionNotImplemented(FunctionByte); { TRACE }
   136:EPrimary:=FunctionNotImplemented(FunctionByte); { TRANSLATE }
   137:EPrimary:=RVNum(System.Trunc(A.Number)); { TRUNC }
   138:EPrimary:=FunctionNotImplemented(FunctionByte); { VALUE }
   139:EPrimary:=FunctionNotImplemented(FunctionByte); { VAR }
   140:EPrimary:=FunctionNotImplemented(FunctionByte); { VERIFY }
   141:EPrimary:=FunctionNotImplemented(FunctionByte); { WORD }
   142:EPrimary:=FunctionNotImplemented(FunctionByte); { WORDINDEX }
   143:EPrimary:=FunctionNotImplemented(FunctionByte); { WORDLENGTH }
   144:EPrimary:=FunctionNotImplemented(FunctionByte); { WORDPOS }
   145:EPrimary:=FunctionNotImplemented(FunctionByte); { WORDS }
   146:EPrimary:=FunctionNotImplemented(FunctionByte); { XRANGE }
   147:EPrimary:=FunctionNotImplemented(FunctionByte); { X2B }
   148:EPrimary:=FunctionNotImplemented(FunctionByte); { X2C }
   149:EPrimary:=FunctionNotImplemented(FunctionByte); { X2D }
   150:EPrimary:=FunctionNotImplemented(FunctionByte); { DO }
   151:EPrimary:=FunctionNotImplemented(FunctionByte); { ELSE }
   152:EPrimary:=FunctionNotImplemented(FunctionByte); { END }
   153:EPrimary:=FunctionNotImplemented(FunctionByte); { EXPOSE }
   154:EPrimary:=FunctionNotImplemented(FunctionByte); { ITERATE }
   155:EPrimary:=FunctionNotImplemented(FunctionByte); { LEAVE }
   156:EPrimary:=FunctionNotImplemented(FunctionByte); { NAME }
   157:EPrimary:=FunctionNotImplemented(FunctionByte); { NOP }
   158:EPrimary:=FunctionNotImplemented(FunctionByte); { NUMERIC }
   159:EPrimary:=FunctionNotImplemented(FunctionByte); { OTHERWISE }
   160:EPrimary:=FunctionNotImplemented(FunctionByte); { SIGNAL }
   161:EPrimary:=FunctionNotImplemented(FunctionByte); { WHEN }
   Else If FindRoutineLabel(Nm)>0Then EPrimary:=RVText(CallRoutine(Nm))
    Else EPrimary:=RVText(Nm);
  End;
  Exit;
 End;
 EPrimary:=VarGet(Nm);
End;

Function EPower:RexxValue;
Var A,B:RexxValue;J:Integer;N:Real;
Begin A:=EPrimary;ESkip;While Copy(ExprText,ExprPos,2)='**'do Begin Inc(ExprPos,2);B:=EPrimary;N:=1;For J:=1To System.Trunc(B.Number)do N:=N*A.Number;A:=RVNum(N);ESkip;End;EPower:=A;End;

Function EMul:RexxValue;
Var A,B:RexxValue;Op:String[2];
Begin
 A:=EPower;
 While True Do Begin ESkip;Op:='';If Copy(ExprText,ExprPos,2)='//'Then Begin Op:='//';Inc(ExprPos,2);End Else If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['*','/','%'])Then Begin Op:=ExprText[ExprPos];Inc(ExprPos);End;If Op=''Then Break;B:=EPower;
  If Op='*'Then A:=RVNum(A.Number*B.Number)Else If(Op='/')and(B.Number<>0)Then A:=RVNum(A.Number/B.Number)Else If(Op='%')and(B.Number<>0)Then A:=RVNum(System.Trunc(A.Number/B.Number))Else If(Op='//')and(B.Number<>0)Then A:=RVNum(System.Trunc(A.Number)mod
System.Trunc(B.Number))Else A:=RVNum(0);
 End;EMul:=A;
End;

Function EAdd:RexxValue;
Var A,B:RexxValue;O:Char;
Begin A:=EMul;While True Do Begin ESkip;If(ExprPos>Length(ExprText))or Not(ExprText[ExprPos]in['+','-'])Then Break;O:=ExprText[ExprPos];Inc(ExprPos);B:=EMul;If O='+'Then A:=RVNum(A.Number+B.Number)Else A:=RVNum(A.Number-B.Number);End;EAdd:=A;End;

Function ECompare:RexxValue;
Var A,B:RexxValue;O:String[2];T:Boolean;
Begin
 A:=EAdd;ESkip;O:='';If Copy(ExprText,ExprPos,2)='>='Then O:='>=' Else
 If Copy(ExprText,ExprPos,2)='<='Then O:='<='Else
 If Copy(ExprText,ExprPos,2)='<>'Then O:='<>'Else
 If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['=','>','<'])Then O:=ExprText[ExprPos];
 If O<>''Then Begin
  Inc(ExprPos,Length(O));B:=EAdd;
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
  If T Then A:=RVNum(1)Else
            A:=RVNum(0);
  End;
  ECompare:=A;
End;

Function Eval(S:String):RexxValue;
Var A,B:RexxValue;Tight:Boolean;
Begin
 ExprText:=S;ExprPos:=1;A:=ECompare;
 While ExprPos<=Length(ExprText)do Begin ESkip;If ExprPos>Length(ExprText)Then Break;Tight:=Copy(ExprText,ExprPos,2)='||';If Tight Then Inc(ExprPos,2);B:=ECompare;If Tight Then A:=RVText(A.Text+B.Text)Else A:=RVText(A.Text+' '+B.Text);End;Eval:=A;
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
   If(D=0)and(Copy(U,J,Length(W))=W)and((J=1)or(S[J-1]in[' ',#9]))and((J+Length(W)>Length(S))or(S[J+Length(W)]in[' ',#9]))Then Begin
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

Procedure ExecOne(S:String);
Var P,J:Integer;V:RexxValue;Name,Rest,ArgName,FirstWord:String;CommandByte:Byte;
Begin
 S:=Clean(S);If S=''Then Exit;
 P:=1;While(P<=Length(S))and(S[P]in['A'..'Z','a'..'z','_'])Do Inc(P);
 FirstWord:=Copy(S,1,P-1);J:=CommandIndex(FirstWord);
 If J<0Then CommandByte:=255 Else CommandByte:=Byte(J);
 Case CommandByte Of
  65:Begin { SAY }
   V:=Eval(Copy(S,4,255));WriteLn(V.Text);
  End;
  9:Begin { CALL }
   Rest:=Clean(Copy(S,5,255));P:=System.Pos(' ',Rest);
   If P>0Then Begin Name:=Copy(Rest,1,P-1);Rest:=Clean(Copy(Rest,P+1,255));End Else Begin Name:=Rest;Rest:='';End;
   InvokeArgCount:=0;
   While(Rest<>'')and(InvokeArgCount<MaxRoutineArgs)do Begin
    P:=System.Pos(',',Rest);If P>0Then Begin V:=Eval(Copy(Rest,1,P-1));Delete(Rest,1,P);Rest:=Clean(Rest);End Else Begin V:=Eval(Rest);Rest:='';End;
    Inc(InvokeArgCount);InvokeArgs[InvokeArgCount]:=V.Text;
   End;
   VarSet('RESULT',CallRoutine(Name));
  End;
  48:Begin { PARSE }
   If WordStart(S,'PARSE ARG')Then Begin
    Rest:=Clean(Copy(S,10,255));J:=1;
    While(Rest<>'')do Begin
     P:=System.Pos(',',Rest);If P>0Then Begin ArgName:=Clean(Copy(Rest,1,P-1));Delete(Rest,1,P);Rest:=Clean(Rest);End Else Begin ArgName:=Clean(Rest);Rest:='';End;
     If J<=CurrentArgCount Then VarSet(ArgName,CurrentArgs[J])Else VarSet(ArgName,'');Inc(J);
    End;
   End Else If WordStart(S,'PARSE UPPER VAR')Then Begin
    Rest:=Clean(Copy(S,16,255));P:=System.Pos(' ',Rest);
    If P>0Then Begin Name:=Copy(Rest,1,P-1);ParseTemplate(VarGet(Name).Text,Clean(Copy(Rest,P+1,255)),True);End;
   End Else If WordStart(S,'PARSE VAR')Then Begin
    Rest:=Clean(Copy(S,10,255));P:=System.Pos(' ',Rest);
    If P>0Then Begin Name:=Copy(Rest,1,P-1);ParseTemplate(VarGet(Name).Text,Clean(Copy(Rest,P+1,255)),False);End;
   End Else If WordStart(S,'PARSE VERSION')Then
    ParseTemplate('REXX-DEVCOOLS 1.0',Clean(Copy(S,14,255)),False)
   Else If WordStart(S,'PARSE SOURCE')Then
    ParseTemplate('WINDOWS COMMAND '+FileName,Clean(Copy(S,13,255)),False);
  End;
  56:Begin { RETURN }
   Rest:=Clean(Copy(S,7,255));If Rest<>''Then RoutineResult:=Eval(Rest).Text Else RoutineResult:='';RoutineReturning:=True;
  End;
  49:; { PROCEDURE est traite lors de l'entree dans CallRoutine }
  158:Begin { NUMERIC }
   If WordStart(S,'NUMERIC DIGITS')Then Begin
    Rest:=Clean(Copy(S,15,255));If Rest=''Then NumericDigitsValue:=9
     Else Begin J:=System.Trunc(Eval(Rest).Number);If J>0Then NumericDigitsValue:=J;End;
    If NumericFuzzValue>=NumericDigitsValue Then NumericFuzzValue:=NumericDigitsValue-1;
   End Else If WordStart(S,'NUMERIC FUZZ')Then Begin
    Rest:=Clean(Copy(S,13,255));If Rest=''Then NumericFuzzValue:=0
     Else Begin J:=System.Trunc(Eval(Rest).Number);If(J>=0)and(J<NumericDigitsValue)Then NumericFuzzValue:=J;End;
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
    Name:=Eval(Clean(Copy(S,13,255))).Text;SignalTargetLine:=FindRoutineLabel(Name);
   End Else Begin Name:=Clean(Copy(S,7,255));SignalTargetLine:=FindRoutineLabel(Name);End;
  End;
  157:; { NOP }
  155:LoopSignal:=1; { LEAVE }
  154:LoopSignal:=2; { ITERATE }
  31:Terminated:=True; { EXIT }
  Else Begin
   If S[Length(S)]=':'Then Exit;
   P:=System.Pos('=',S);If P>1Then Begin V:=Eval(Copy(S,P+1,255));VarSet(Copy(S,1,P-1),V.Text);End
    Else WriteLn('Commande non reconnue: ',S);
  End;
 End;
End;

Procedure ExecRange(A,Z:Integer);
Var J,P,E,K,ToPos,ByPos,EqPos,RepeatCount:Integer;S,C,Act,LoopVar:String;V:RexxValue;Done:Boolean;LoopValue,LoopEnd,LoopStep:Real;
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
    V:=Eval(C);
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
     V:=Eval(Copy(Act,5,P-5));
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
   V:=Eval(C);
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
   LoopValue:=Eval(Copy(S,EqPos+1,ToPos-EqPos-1)).Number;
   If ByPos>0Then Begin
    LoopEnd:=Eval(Copy(S,ToPos+2,ByPos-ToPos-2)).Number;
    LoopStep:=Eval(Copy(S,ByPos+2,255)).Number;
   End
    Else
   Begin
    LoopEnd:=Eval(Copy(S,ToPos+2,255)).Number;
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
   RepeatCount:=System.Trunc(Eval(Copy(S,3,255)).Number);
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
 LabelLine,EndLine,J,K,SavedVariableCount,SavedArgCount,SavedExprPos,
  SavedInvokeCount,ExposeCount:Integer;
 S,ProcedureText,ExposeName:String;
 SavedReturning,HasProcedure:Boolean;
 SavedResult,SavedExprText:String;
 SavedVariables:Array[1..MaxVariables]of RexxVariable;
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
  SavedVariableCount:=VariableCount;
  For K:=1 To VariableCount Do SavedVariables[K]:=Variables[K];
  VariableCount:=0;
  For K:=1 To ExposeCount Do Begin
   ExposeValues[K]:='';
   For J:=1 To SavedVariableCount Do
    If SavedVariables[J].Name=ExposeNames[K]Then ExposeValues[K]:=SavedVariables[J].Value;
   VarSet(ExposeNames[K],ExposeValues[K]);
  End;
 End;

 RoutineReturning:=False;RoutineResult:='';
 ExecRange(LabelLine+1,EndLine);
 CallRoutine:=RoutineResult;

 If HasProcedure Then Begin
  For K:=1 To ExposeCount Do Begin
   J:=VarIndex(ExposeNames[K]);If J>0Then ExposeValues[K]:=Variables[J].Value Else ExposeValues[K]:='';
  End;
  VariableCount:=SavedVariableCount;
  For K:=1 To SavedVariableCount Do Variables[K]:=SavedVariables[K];
  For K:=1 To ExposeCount Do VarSet(ExposeNames[K],ExposeValues[K]);
 End;

 CurrentArgCount:=SavedArgCount;InvokeArgCount:=SavedInvokeCount;
 For J:=1 To MaxRoutineArgs Do Begin CurrentArgs[J]:=SavedArgs[J];InvokeArgs[J]:=SavedInvokeArgs[J];End;
 RoutineReturning:=SavedReturning;RoutineResult:=SavedResult;
 ExprText:=SavedExprText;ExprPos:=SavedExprPos;
End;

Procedure ExecuteCommand;Begin
 VariableCount:=0;
 Terminated:=False;
 LoopSignal:=0;
 CurrentArgCount:=0;InvokeArgCount:=0;RoutineReturning:=False;RoutineResult:='';
 NumericDigitsValue:=9;NumericFuzzValue:=0;NumericFormValue:='SCIENTIFIC';
 SignalTargetLine:=0;SignalHalt:=False;SignalNoValue:=False;SignalError:=False;SignalSyntax:=False;
 SignalHaltName:='HALT';SignalNoValueName:='NOVALUE';SignalErrorName:='ERROR';SignalSyntaxName:='SYNTAX';
 If NumberLine>0Then ExecRange(1,NumberLine);
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
  NumberLine:=0;CurrNumberLine:=0;
  If ParamCount>0 Then Begin
   For I:=1 to ParamCount do Begin
    FileName:=ParamStr(I);
   End;
   LoadCommand;
   ExecuteCommand;
  End
 End;
END.
