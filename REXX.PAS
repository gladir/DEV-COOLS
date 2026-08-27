{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2023
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2, Turbo Pascal 7)
}

Program REXX;

Uses Crt,DOS;

Const
 CommandList:Array[0..149]of String[20]=(
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
  'X2B','X2C','X2D'
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

Function RunLine:Boolean;
Var
 R1:Real;
 UnknownCommand:Boolean;
 NoImplementation:Boolean;
Begin
 RunLine:=False;
 CurrPos:=1;
 NoImplementation:=False;
 UnknownCommand:=False;
 Case ExtractCommand of
  0:NoImplementation:=True;{ABBREV}
  1:NoImplementation:=True;{ABS}
  2:NoImplementation:=True;{ADDRESS}
  3:NoImplementation:=True;{ARG}
  4:NoImplementation:=True;{B2X}
  5:NoImplementation:=True;{BEEP}
  6:NoImplementation:=True;{BITAND}
  7:NoImplementation:=True;{BITOR}
  8:NoImplementation:=True;{BITXOR}
  9:NoImplementation:=True;{CALL}
  10:NoImplementation:=True;{CENTER}
  11:NoImplementation:=True;{CHANGESTR}
  12:NoImplementation:=True;{CHARIN}
  13:NoImplementation:=True;{CHAROUT}
  14:NoImplementation:=True;{CHARS}
  15:NoImplementation:=True;{COMPARE}
  16:NoImplementation:=True;{CONDITION}
  17:NoImplementation:=True;{COPIES}
  18:NoImplementation:=True;{COUNTSTR}
  19:NoImplementation:=True;{C2D}
  20:NoImplementation:=True;{C2X}
  21:NoImplementation:=True;{DATATYPE}
  22:NoImplementation:=True;{DATE}
  23:NoImplementation:=True;{DELSTR}
  24:NoImplementation:=True;{DELWORD}
  25:NoImplementation:=True;{DIGITS}
  26:NoImplementation:=True;{DIRECTORY}
  27:NoImplementation:=True;{D2C}
  28:NoImplementation:=True;{D2X}
  29:NoImplementation:=True;{ENDLOCAL}
  30:NoImplementation:=True;{ERRORTEXT}
  31:Begin {EXIT}
   Terminated:=True;
   Exit;
  End;
  32:NoImplementation:=True;{FILESPEC}
  33:NoImplementation:=True;{FORM}
  34:NoImplementation:=True;{FORMAT}
  35:NoImplementation:=True;{FUZZ}
  36:NoImplementation:=True;{IF}
  37:NoImplementation:=True;{INSERT}
  38:NoImplementation:=True;{LASTPOS}
  39:NoImplementation:=True;{LEFT}
  40:NoImplementation:=True;{LENGTH}
  41:NoImplementation:=True;{LINEIN}
  42:NoImplementation:=True;{LINEOUT}
  43:NoImplementation:=True;{LINES}
  44:NoImplementation:=True;{MAX}
  45:NoImplementation:=True;{MIN}
  46:NoImplementation:=True;{OPTIONS}
  47:NoImplementation:=True;{OVERLAY}
  48:NoImplementation:=True;{PARSE}
  49:NoImplementation:=True;{PROCEDURE}
  50:NoImplementation:=True;{POS}
  51:NoImplementation:=True;{PULL}
  52:NoImplementation:=True;{PUSH}
  53:NoImplementation:=True;{QUEUE}
  54:NoImplementation:=True;{QUEUED}
  55:NoImplementation:=True;{RANDOM}
  56:NoImplementation:=True;{RETURN}
  57:NoImplementation:=True;{REVERSE}
  58:NoImplementation:=True;{RIGHT}
  59:NoImplementation:=True;{RXFUNCADD}
  60:NoImplementation:=True;{RXFUNCDROP}
  61:NoImplementation:=True;{RXFUNCQUERY}
  62:NoImplementation:=True;{RXMESSAGEBOX}
  63:NoImplementation:=True;{RXQUEUE}
  64:NoImplementation:=True;{RXWINEXEC}
  65:SayCommand;{SAY}
  66:NoImplementation:=True;{SELECT}
  67:NoImplementation:=True;{SETLOCAL}
  68:NoImplementation:=True;{SIGN}
  69:NoImplementation:=True;{SOURCELINE}
  70:NoImplementation:=True;{SPACE}
  71:NoImplementation:=True;{STREAM}
  72:NoImplementation:=True;{STRIP}
  73:NoImplementation:=True;{SUBSTR}
  74:NoImplementation:=True;{SUBWORD}
  75:NoImplementation:=True;{SYMBOL}
  76:NoImplementation:=True;{SYSADDREXXMACRO}
  77:NoImplementation:=True;{SYSBOOTDRIVE}
  78:NoImplementation:=True;{SYSCLEARREXXMACROSPACE}
  79:NoImplementation:=True;{SYSCLOSEEVENTSEM}
  80:NoImplementation:=True;{SYSCLOSEMUTEXSEM}
  81:NoImplementation:=True;{SYSCLS}
  82:NoImplementation:=True;{SYSCREATEEVENTSEM}
  83:NoImplementation:=True;{SYSCREATEMUTEXSEM}
  84:NoImplementation:=True;{SYSCREATEOBJECT}
  85:NoImplementation:=True;{SYSCURPOS}
  86:NoImplementation:=True;{SYSCURSTATE}
  87:NoImplementation:=True;{SYSDEREGISTEROBJECTCLASS}
  88:NoImplementation:=True;{SYSDESTROYOBJECT}
  89:NoImplementation:=True;{SYSDRIVEINFO}
  90:NoImplementation:=True;{SYSDRIVEMAP}
  91:NoImplementation:=True;{SYSDROPFUNCS}
  92:NoImplementation:=True;{SYSDROPREXXMACRO}
  93:NoImplementation:=True;{SYSFILEDELETE}
  94:NoImplementation:=True;{SYSFILETREE}
  95:NoImplementation:=True;{SYSFILESEARCH}
  96:NoImplementation:=True;{SYSFILESYSTEMTYPE}
  97:NoImplementation:=True;{SYSGETEA}
  98:NoImplementation:=True;{SYSGETKEY}
  99:NoImplementation:=True;{SYSGETMESSAGE}
  100:NoImplementation:=True;{SYSINI}
  101:NoImplementation:=True;{SYSLOADFUNCS}
  102:NoImplementation:=True;{SYSLOADREXXMACROSPACE}
  103:NoImplementation:=True;{SYSMKDIR}
  104:NoImplementation:=True;{SYSOPENEVENTSEM}
  105:NoImplementation:=True;{SYSOPENMUTEXSEM}
  106:NoImplementation:=True;{SYSOS2VER}
  107:NoImplementation:=True;{SYSPOSTEVENTSEM}
  108:NoImplementation:=True;{SYSPULSEEVENTSEM}
  109:NoImplementation:=True;{SYSPUTEA}
  110:NoImplementation:=True;{SYSQUERYCLASSLIST}
  111:NoImplementation:=True;{SYSQUERYREXXMACRO}
  112:NoImplementation:=True;{SYSREGISTEROBJECTCLASS}
  113:NoImplementation:=True;{SYSRELEASEMUTEXSEM}
  114:NoImplementation:=True;{SYSREORDERREXXMACRO}
  115:NoImplementation:=True;{SYSREQUESTMUTEXSEM}
  116:NoImplementation:=True;{SYSRESETEVENTSEM}
  117:NoImplementation:=True;{SYSRMDIR}
  118:NoImplementation:=True;{SYSSAVEREXXMACROSPACE}
  119:NoImplementation:=True;{SYSSEARCHPATH}
  120:NoImplementation:=True;{SYSSETICON}
  121:NoImplementation:=True;{SYSSETOBJECTDATA}
  122:NoImplementation:=True;{SYSSETPRIORITY}
  123:NoImplementation:=True;{SYSSLEEP}
  124:NoImplementation:=True;{SYSSWITCHSESSION}
  125:NoImplementation:=True;{SYSSYSTEMDIRECTORY}
  126:NoImplementation:=True;{SYSTEMPFILENAME}
  127:NoImplementation:=True;{SYSTEXTSCREENREAD}
  128:NoImplementation:=True;{SYSTEXTSCREENSIZE}
  129:NoImplementation:=True;{SYSVOLUMELABEL}
  130:NoImplementation:=True;{SYSWAITEVENTSEM}
  131:NoImplementation:=True;{SYSWAITNAMEDPIPE}
  132:NoImplementation:=True;{SYSWINVER}
  133:NoImplementation:=True;{THEN}
  134:NoImplementation:=True;{TIME}
  135:NoImplementation:=True;{TRACE}
  136:NoImplementation:=True;{TRANSLATE}
  137:NoImplementation:=True;{TRUNC}
  138:NoImplementation:=True;{VALUE}
  139:NoImplementation:=True;{VAR}
  140:NoImplementation:=True;{VERIFY}
  141:NoImplementation:=True;{WORD}
  142:NoImplementation:=True;{WORDINDEX}
  143:NoImplementation:=True;{WORDLENGTH}
  144:NoImplementation:=True;{WORDPOS}
  145:NoImplementation:=True;{WORDS}
  146:NoImplementation:=True;{XRANGE}
  147:NoImplementation:=True;{X2B}
  148:NoImplementation:=True;{X2C}
  149:NoImplementation:=True;{X2D}
  Else UnknownCommand:=True;
 End;
 If(UnknownCommand)Then Begin
  WriteLn('Commande non reconnu');
  Exit;
 End
  Else
 If(NoImplementation)Then Begin
  WriteLn('Cette commande n''a pas ‚t‚ impl‚ment‚');
  Exit;
 End;
 RunLine:=True;
End;

Procedure LegacyExecuteCommand;
Var
 J:Integer;
 Err:Integer;
 S1:String;
Begin
 If NumberLine>0Then Begin
  CurrLinePtr:=1;
  While(CurrLinePtr<=NumberLine) do Begin
   CurrLine:=PA[CurrLinePtr]^;
   CurrNumberLine:=0;
   J:=1;
   While(J<Length(CurrLine))do Begin
    If Not(CurrLine[J]in['0'..'9'])Then Begin
     Val(Copy(CurrLine,1,J-1),CurrNumberLine,Err);
     Break;
    End;
    Inc(J);
   End;
   While J<=Length(CurrLine)do Begin
    If CurrLine[J]in[' ',#9]Then Inc(J)
                            Else Break;
   End;
   CurrPos:=J;
   If Not(RunLine)Then Break;
   Inc(CurrLinePtr);
  End;
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

Function EPrimary:RexxValue;
Var Q:Char;S,Nm:String;N:Real;C,J:Integer;A,B:RexxValue;
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
  Nm:=StrToUpper(Nm);
  If Nm='ABS'Then EPrimary:=RVNum(Abs(A.Number))
  Else If Nm='SIGN'Then Begin If A.Number<0 Then N:=-1 Else If A.Number>0 Then N:=1 Else N:=0;EPrimary:=RVNum(N);End
  Else If Nm='MAX'Then Begin If A.Number>B.Number Then N:=A.Number Else N:=B.Number;EPrimary:=RVNum(N);End
  Else If Nm='MIN'Then Begin If A.Number<B.Number Then N:=A.Number Else N:=B.Number;EPrimary:=RVNum(N);End
  Else If Nm='TRUNC'Then EPrimary:=RVNum(System.Trunc(A.Number))
  Else If Nm='LENGTH'Then EPrimary:=RVNum(Length(A.Text))
  Else If Nm='LEFT'Then EPrimary:=RVText(Copy(A.Text,1,System.Trunc(B.Number)))
  Else If Nm='RIGHT'Then Begin J:=Length(A.Text)-System.Trunc(B.Number)+1;If J<1Then J:=1;EPrimary:=RVText(Copy(A.Text,J,255));End
  Else If FindRoutineLabel(Nm)>0Then EPrimary:=RVText(CallRoutine(Nm))
  Else EPrimary:=RVText(Nm);
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
Function WordStart(S,W:String):Boolean;
Var
 U:String;
Begin
 U:=StrToUpper(Clean(S));
 W:=StrToUpper(W);
 WordStart:=(Copy(U,1,Length(W))=W)and((Length(U)=Length(W))or(U[Length(W)+1]in[' ',#9]));
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

Procedure ExecOne(S:String);
Var P,J:Integer;V:RexxValue;Name,Rest,ArgName:String;
Begin
 S:=Clean(S);If S=''Then Exit;
 If WordStart(S,'SAY')Then Begin V:=Eval(Copy(S,4,255));WriteLn(V.Text);End
 Else If WordStart(S,'CALL')Then Begin
  Rest:=Clean(Copy(S,5,255));P:=System.Pos(' ',Rest);
  If P>0Then Begin Name:=Copy(Rest,1,P-1);Rest:=Clean(Copy(Rest,P+1,255));End Else Begin Name:=Rest;Rest:='';End;
  InvokeArgCount:=0;
  While(Rest<>'')and(InvokeArgCount<MaxRoutineArgs)do Begin
   P:=System.Pos(',',Rest);If P>0Then Begin V:=Eval(Copy(Rest,1,P-1));Delete(Rest,1,P);Rest:=Clean(Rest);End Else Begin V:=Eval(Rest);Rest:='';End;
   Inc(InvokeArgCount);InvokeArgs[InvokeArgCount]:=V.Text;
  End;
  VarSet('RESULT',CallRoutine(Name));
 End
 Else If WordStart(S,'PARSE ARG')Then Begin
  Rest:=Clean(Copy(S,10,255));J:=1;
  While(Rest<>'')do Begin
   P:=System.Pos(',',Rest);If P>0Then Begin ArgName:=Clean(Copy(Rest,1,P-1));Delete(Rest,1,P);Rest:=Clean(Rest);End Else Begin ArgName:=Clean(Rest);Rest:='';End;
   If J<=CurrentArgCount Then VarSet(ArgName,CurrentArgs[J])Else VarSet(ArgName,'');Inc(J);
  End;
 End
 Else If WordStart(S,'RETURN')Then Begin
  Rest:=Clean(Copy(S,7,255));If Rest<>''Then RoutineResult:=Eval(Rest).Text Else RoutineResult:='';RoutineReturning:=True;
 End
 Else If WordStart(S,'PROCEDURE')Then
 Else If WordStart(S,'NOP')Then
 Else If WordStart(S,'LEAVE')Then LoopSignal:=1
 Else If WordStart(S,'ITERATE')Then LoopSignal:=2
 Else If WordStart(S,'EXIT')Then Terminated:=True
 Else If S[Length(S)]=':'Then
 Else Begin P:=System.Pos('=',S);If P>1Then Begin V:=Eval(Copy(S,P+1,255));VarSet(Copy(S,1,P-1),V.Text);End Else WriteLn('Commande non reconnue: ',S);End;
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
