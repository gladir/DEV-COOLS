{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Clone autonome de Microsoft Console Based Script Host)
  @target(Free Pascal 3.2 et Turbo Pascal 7)
}
Program CSCRIPT;

{$M 16384,0,655360}

Uses Crt,Dos;

Const
 MaxArguments=128;
 VersionText='5.812';
 FunctionList:Array[0..33]of String[24]=(
  'ABS','ARRAY','ASC','ATN','CBOOL','CBYTE','CDATE','CDBL','CHR','CINT',
  'CLNG','COS','CSNG','CSTR','CVERR','DATE','DATESERIAL','DATEVALUE','DAY',
  'EXP','FIX','HEX','HOUR','INPUTBOX','INSTR','INT','LCASE','LEFT','LEN',
  'RIGHT','RND','TRIM','UCASE','WSCRIPT.ARGUMENTS');

Type
 PScriptLine=^TScriptLine;
 TScriptLine=Record
  Number:LongInt;
  Text:String;
  Previous,Next:PScriptLine;
 End;
 PVariable=^TVariable;
 TVariable=Record
  Name:String[63];
  Value:String;
  Next:PVariable;
 End;
 TValue=Record
  Text:String;
  Number:Real;
  IsNumber:Boolean;
 End;

Var
 FirstScriptLine,LastScriptLine:PScriptLine;
 LineCount,CurrentLine:LongInt;
 Variables:PVariable;
 ScriptArguments:Array[0..MaxArguments-1]of String;
 ScriptArgumentCount:Integer;
 ScriptName,EngineName,JobName:String;
 BatchMode,DebugMode,InteractiveMode,ShowLogo,UnicodeMode:Boolean;
 TimeLimit:LongInt;
 StartHour,StartMinute,StartSecond,StartHundredth:Word;
 ExprText:String;
 ExprPos:Integer;
 Terminated:Boolean;
 ExitCode:Integer;
 ArrayCounter:LongInt;

Function Upper(S:String):String;
Var I:Integer;
Begin For I:=1To Length(S)Do If S[I]in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);Upper:=S;End;

Function FunctionIndex(Name:String):Byte;
Var FirstIndex,LastIndex,MiddleIndex:Integer;
Begin
 Name:=Upper(Name);FunctionIndex:=255;
 FirstIndex:=Low(FunctionList);LastIndex:=High(FunctionList);
 While FirstIndex<=LastIndex Do Begin
  MiddleIndex:=(FirstIndex+LastIndex)div 2;
  If Name=FunctionList[MiddleIndex]Then Begin FunctionIndex:=MiddleIndex;Exit;End;
  If Name<FunctionList[MiddleIndex]Then LastIndex:=MiddleIndex-1
  Else FirstIndex:=MiddleIndex+1;
 End;
End;

Function Trim(S:String):String;
Begin
 While(Length(S)>0)and(S[1]in[' ',#9])Do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[' ',#9,#13,#10])Do Delete(S,Length(S),1);
 Trim:=S;
End;

Function StartsWith(S,Prefix:String):Boolean;
Begin StartsWith:=Copy(Upper(Trim(S)),1,Length(Prefix))=Upper(Prefix);End;

Procedure AddScriptLine(S:String);
Var Line:PScriptLine;
Begin
 New(Line);Inc(LineCount);Line^.Number:=LineCount;Line^.Text:=S;
 Line^.Previous:=LastScriptLine;Line^.Next:=Nil;
 If LastScriptLine<>Nil Then LastScriptLine^.Next:=Line
 Else FirstScriptLine:=Line;
 LastScriptLine:=Line;
End;

Function ScriptLineText(LineNumber:LongInt):String;
Var Line:PScriptLine;
Begin
 If(LineNumber<1)or(LineNumber>LineCount)Then Begin ScriptLineText:='';Exit;End;
 If LineNumber<=(LineCount div 2)Then Begin
  Line:=FirstScriptLine;While(Line<>Nil)and(Line^.Number<LineNumber)Do Line:=Line^.Next;
 End Else Begin
  Line:=LastScriptLine;While(Line<>Nil)and(Line^.Number>LineNumber)Do Line:=Line^.Previous;
 End;
 If Line=Nil Then ScriptLineText:=''Else ScriptLineText:=Line^.Text;
End;

Procedure MakeText(S:String;Var V:TValue);
Var Code:Integer;N:Real;
Begin V.Text:=S;Val(S,N,Code);V.IsNumber:=Code=0;If V.IsNumber Then V.Number:=N Else V.Number:=0;End;

Procedure MakeNumber(N:Real;Var V:TValue);
Var S:String;
Begin
 If Frac(N)=0Then Str(Trunc(N),S)Else Str(N:0:8,S);
 V.Text:=Trim(S);V.Number:=N;V.IsNumber:=True;
End;

Procedure MakeSingleNumber(N:Real;Var V:TValue);
Var Scale,ScaledValue:Real;
Begin
 If N=0Then Begin MakeNumber(0,V);Exit;End;
 Scale:=1;ScaledValue:=Abs(N);
 While ScaledValue>=10Do Begin ScaledValue:=ScaledValue/10;Scale:=Scale*10;End;
 While ScaledValue<1Do Begin ScaledValue:=ScaledValue*10;Scale:=Scale/10;End;
 ScaledValue:=Round(ScaledValue*1000000)/1000000;
 If N<0Then ScaledValue:=-ScaledValue;
 MakeNumber(ScaledValue*Scale,V);
End;

Function LeapYear(Year:Integer):Boolean;
Begin LeapYear:=(Year mod 4=0)and((Year mod 100<>0)or(Year mod 400=0));End;

Function MonthDays(Year,Month:Integer):Integer;
Const Days:Array[1..12]of Byte=(31,28,31,30,31,30,31,31,30,31,30,31);
Begin
 If(Month=2)and LeapYear(Year)Then MonthDays:=29 Else MonthDays:=Days[Month];
End;

Procedure MakeDateValue(Year,Month,Day:Integer;Var V:TValue);
Var SYear,SMonth,SDay:String;
Begin
 If(Year>=0)and(Year<=29)Then Inc(Year,2000)
 Else If(Year>=30)and(Year<=99)Then Inc(Year,1900);
 While Month<1 Do Begin Dec(Year);Inc(Month,12);End;
 While Month>12 Do Begin Inc(Year);Dec(Month,12);End;
 While Day<1 Do Begin Dec(Month);If Month<1Then Begin Month:=12;Dec(Year);End;
  Inc(Day,MonthDays(Year,Month));End;
 While Day>MonthDays(Year,Month)Do Begin Dec(Day,MonthDays(Year,Month));Inc(Month);
  If Month>12Then Begin Month:=1;Inc(Year);End;End;
 Str(Year,SYear);Str(Month,SMonth);Str(Day,SDay);
 If Length(SMonth)<2Then SMonth:='0'+SMonth;If Length(SDay)<2Then SDay:='0'+SDay;
 MakeText(SDay+'/'+SMonth+'/'+Trim(SYear),V);
End;

Procedure ParseDateValue(SourceText:String;Var V:TValue);
Var FirstPart,SecondPart,ThirdPart:String;P,Code,Year,Month,Day:Integer;
Begin
 SourceText:=Trim(SourceText);P:=Pos(' ',SourceText);
 If P>0Then SourceText:=Copy(SourceText,1,P-1);
 FirstPart:='';SecondPart:='';ThirdPart:='';
 P:=Pos('/',SourceText);If P=0Then P:=Pos('-',SourceText);
 If P=0Then Begin MakeText('',V);Exit;End;
 FirstPart:=Copy(SourceText,1,P-1);Delete(SourceText,1,P);
 P:=Pos('/',SourceText);If P=0Then P:=Pos('-',SourceText);
 If P=0Then Begin MakeText('',V);Exit;End;
 SecondPart:=Copy(SourceText,1,P-1);ThirdPart:=Copy(SourceText,P+1,255);
 If Length(Trim(FirstPart))=4Then Begin
  Val(FirstPart,Year,Code);If Code<>0Then Begin MakeText('',V);Exit;End;
  Val(SecondPart,Month,Code);If Code<>0Then Begin MakeText('',V);Exit;End;
  Val(ThirdPart,Day,Code);
 End Else Begin
  Val(FirstPart,Day,Code);If Code<>0Then Begin MakeText('',V);Exit;End;
  Val(SecondPart,Month,Code);If Code<>0Then Begin MakeText('',V);Exit;End;
  Val(ThirdPart,Year,Code);
 End;
 If Code<>0Then MakeText('',V)Else MakeDateValue(Year,Month,Day,V);
End;

Procedure DateDayValue(SourceText:String;Var V:TValue);
Var DateValue:TValue;Day,Code:Integer;
Begin
 ParseDateValue(SourceText,DateValue);
 If DateValue.Text=''Then Begin MakeText('',V);Exit;End;
 Val(Copy(DateValue.Text,1,2),Day,Code);
 If Code=0Then MakeNumber(Day,V)Else MakeText('',V);
End;

Procedure DateHourValue(SourceText:String;Var V:TValue);
Var P,HourValue,Code:Integer;TimeText:String;
Begin
 SourceText:=Trim(SourceText);P:=Pos(' ',SourceText);
 If P>0Then TimeText:=Trim(Copy(SourceText,P+1,255))Else TimeText:=SourceText;
 P:=Pos(':',TimeText);If P=0Then Begin MakeNumber(0,V);Exit;End;
 Val(Copy(TimeText,1,P-1),HourValue,Code);
 If(Code=0)and(HourValue>=0)and(HourValue<=23)Then MakeNumber(HourValue,V)
 Else MakeText('',V);
End;

Procedure HexValue(NumberValue:LongInt;Var V:TValue);
Const Digits:Array[0..15] of Char='0123456789ABCDEF';
Var ResultText:String;Digit,Count:Integer;Negative:Boolean;
Begin
 ResultText:='';Negative:=NumberValue<0;Count:=0;
 Repeat
  Digit:=NumberValue and 15;ResultText:=Digits[Digit+1]+ResultText;
  NumberValue:=NumberValue shr 4;Inc(Count);
 Until((Not Negative)and(NumberValue=0))or(Negative and(Count=8));
 MakeText(ResultText,V);
End;

Procedure InputBoxValue(PromptText,TitleText,DefaultText:String;Var V:TValue);
Var Answer:String;
Begin
 If TitleText<>''Then WriteLn('[',TitleText,']');Write(PromptText);
 If PromptText<>''Then Write(' ');ReadLn(Answer);
 If Answer=''Then Answer:=DefaultText;MakeText(Answer,V);
End;

Procedure InStrValue(A,B,C,D:TValue;ArgumentCount:Integer;Var V:TValue);
Var StartPosition,FoundPosition:Integer;SourceText,SearchText:String;
Begin
 If ArgumentCount<3Then Begin StartPosition:=1;SourceText:=A.Text;SearchText:=B.Text;End
 Else Begin StartPosition:=Trunc(A.Number);SourceText:=B.Text;SearchText:=C.Text;End;
 If StartPosition<1Then StartPosition:=1;
 If(ArgumentCount>=4)and(Trunc(D.Number)=1)Then Begin
  SourceText:=Upper(SourceText);SearchText:=Upper(SearchText);
 End;
 If SearchText=''Then FoundPosition:=StartPosition
 Else FoundPosition:=Pos(SearchText,Copy(SourceText,StartPosition,255));
 If FoundPosition>0Then Inc(FoundPosition,StartPosition-1);
 MakeNumber(FoundPosition,V);
End;

Function Truth(V:TValue):Boolean;
Begin Truth:=Not((V.Text='')or(V.Text='0')or(Upper(V.Text)='FALSE'));End;

Function FindVariable(Name:String):PVariable;
Var P:PVariable;
Begin
 Name:=Upper(Trim(Name));P:=Variables;
 While P<>Nil Do Begin If P^.Name=Name Then Begin FindVariable:=P;Exit;End;P:=P^.Next;End;
 FindVariable:=Nil;
End;

Procedure SetVariable(Name,Value:String);
Var P:PVariable;
Begin
 Name:=Upper(Trim(Name));If Name=''Then Exit;P:=FindVariable(Name);
 If P=Nil Then Begin New(P);P^.Name:=Name;P^.Next:=Variables;Variables:=P;End;
 P^.Value:=Value;
End;

Procedure GetVariable(Name:String;Var V:TValue);
Var P:PVariable;
Begin
 P:=FindVariable(Name);If P=Nil Then MakeText('',V)Else MakeText(P^.Value,V);
End;

Procedure SkipSpace;
Begin While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in[' ',#9])Do Inc(ExprPos);End;

Function ReadWord:String;
Var S:String;
Begin
 SkipSpace;S:='';
 While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['A'..'Z','a'..'z','0'..'9','_','.'])Do Begin
  S:=S+ExprText[ExprPos];Inc(ExprPos);
 End;
 ReadWord:=S;
End;

Procedure ParseExpression(Var V:TValue);Forward;

Procedure ParsePrimary(Var V:TValue);
Var Q:Char;S,Name,U,ArrayReference,IndexText:String;N:Real;
 Code,I,ElementIndex,ArgumentCount:Integer;FunctionByte:Byte;A,B,C,D:TValue;VariableEntry:PVariable;
 DateYear,DateMonth,DateDay,DateDayOfWeek:Word;
Begin
 SkipSpace;If ExprPos>Length(ExprText)Then Begin MakeText('',V);Exit;End;
 If ExprText[ExprPos]in['"','''']Then Begin
  Q:=ExprText[ExprPos];Inc(ExprPos);S:='';
  While ExprPos<=Length(ExprText)Do Begin
   If ExprText[ExprPos]=Q Then Begin
    If(ExprPos<Length(ExprText))and(ExprText[ExprPos+1]=Q)Then Begin S:=S+Q;Inc(ExprPos,2);End
    Else Begin Inc(ExprPos);Break;End;
   End Else Begin S:=S+ExprText[ExprPos];Inc(ExprPos);End;
  End;
  MakeText(S,V);Exit;
 End;
 If ExprText[ExprPos]='('Then Begin Inc(ExprPos);ParseExpression(V);SkipSpace;
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=')')Then Inc(ExprPos);Exit;End;
 If ExprText[ExprPos]in['0'..'9']Then Begin
  S:='';While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0'..'9','.'])Do Begin S:=S+ExprText[ExprPos];Inc(ExprPos);End;
  Val(S,N,Code);If Code=0Then MakeNumber(N,V)Else MakeText(S,V);Exit;
 End;
 Name:=ReadWord;U:=Upper(Name);
 If U='TRUE'Then Begin MakeNumber(-1,V);Exit;End;
 If(U='FALSE')or(U='EMPTY')Then Begin MakeNumber(0,V);Exit;End;
 If U='NOTHING'Then Begin MakeText('',V);Exit;End;
 SkipSpace;
 FunctionByte:=FunctionIndex(U);
 If(FunctionByte=15)and((ExprPos>Length(ExprText))or(ExprText[ExprPos]<>'('))Then Begin
  GetDate(DateYear,DateMonth,DateDay,DateDayOfWeek);
  MakeDateValue(DateYear,DateMonth,DateDay,V);Exit;
 End;
 VariableEntry:=FindVariable(Name);
 If(VariableEntry<>Nil)and(Copy(VariableEntry^.Value,1,8)='@VBARRAY')and
   (ExprPos<=Length(ExprText))and(ExprText[ExprPos]='(')Then Begin
  Inc(ExprPos);ParseExpression(A);SkipSpace;
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=')')Then Inc(ExprPos);
  Str(Trunc(A.Number),IndexText);
  GetVariable(VariableEntry^.Value+'.'+Trim(IndexText),V);Exit;
 End;
 If(U='ARRAY')and(ExprPos<=Length(ExprText))and(ExprText[ExprPos]='(')Then Begin
  Inc(ArrayCounter);Str(ArrayCounter,IndexText);
  ArrayReference:='@VBARRAY'+Trim(IndexText);ElementIndex:=0;Inc(ExprPos);SkipSpace;
  While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]<>')')Do Begin
   ParseExpression(A);Str(ElementIndex,IndexText);
   SetVariable(ArrayReference+'.'+Trim(IndexText),A.Text);Inc(ElementIndex);SkipSpace;
   If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=',')Then Begin Inc(ExprPos);SkipSpace;End
   Else Break;
  End;
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=')')Then Inc(ExprPos);
  Str(ElementIndex,IndexText);SetVariable(ArrayReference+'.COUNT',Trim(IndexText));
  MakeText(ArrayReference,V);Exit;
 End;
 If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]='(')Then Begin
  Inc(ExprPos);SkipSpace;ArgumentCount:=0;
  MakeText('',A);MakeText('',B);MakeText('',C);MakeText('',D);
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]<>')')Then Begin
   ParseExpression(A);Inc(ArgumentCount);SkipSpace;
  End;
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=',')Then Begin
   Inc(ExprPos);
   ParseExpression(B);Inc(ArgumentCount);
   SkipSpace;
  End;
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=',')Then Begin
   Inc(ExprPos);ParseExpression(C);
   Inc(ArgumentCount);
   SkipSpace;
  End;
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=',')Then Begin
   Inc(ExprPos);
   ParseExpression(D);
   Inc(ArgumentCount);
   SkipSpace;
  End;
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=')')Then Inc(ExprPos);
  Case FunctionByte of
   0:MakeNumber(Abs(A.Number),V);                         { ABS }
   1:MakeText('',V);                                      { ARRAY: analyse variadique ci-dessus }
   2:Begin If A.Text=''Then MakeNumber(0,V)
      Else MakeNumber(Ord(A.Text[1]),V);End;              { ASC }
   3:MakeNumber(ArcTan(A.Number),V);                      { ATN }
   4:If Truth(A)Then MakeText('True',V)Else MakeText('False',V); { CBOOL }
   5:Begin                                                { CBYTE }
      N:=Round(A.Number);
      If(N<0)or(N>255)Then MakeText('',V)Else MakeNumber(N,V);
     End;
   6:If A.IsNumber Then MakeText(A.Text,V)Else ParseDateValue(A.Text,V); { CDATE }
   7:MakeNumber(A.Number,V);                              { CDBL }
   8:MakeText(Chr(Trunc(A.Number)and 255),V);             { CHR }
   9:MakeNumber(Round(A.Number),V);                       { CINT }
   10:MakeNumber(Trunc(A.Number),V);                      { CLNG }
   11:MakeNumber(Cos(A.Number),V);                        { COS }
   12:MakeSingleNumber(A.Number,V);                       { CSNG }
   13:MakeText(A.Text,V);                                 { CSTR }
   14:Begin MakeText('Error '+A.Text,V);V.Number:=A.Number;End; { CVERR }
   15:Begin GetDate(DateYear,DateMonth,DateDay,DateDayOfWeek);
      MakeDateValue(DateYear,DateMonth,DateDay,V);End;    { DATE }
   16:MakeDateValue(Trunc(A.Number),Trunc(B.Number),Trunc(C.Number),V); { DATESERIAL }
   17:ParseDateValue(A.Text,V);                           { DATEVALUE }
   18:DateDayValue(A.Text,V);                             { DAY }
   19:MakeNumber(Exp(A.Number),V);                        { EXP }
   20:MakeNumber(Trunc(A.Number),V);                      { FIX }
   21:HexValue(Trunc(A.Number),V);                        { HEX }
   22:DateHourValue(A.Text,V);                            { HOUR }
   23:InputBoxValue(A.Text,B.Text,C.Text,V);              { INPUTBOX }
   24:InStrValue(A,B,C,D,ArgumentCount,V);                { INSTR }
   25:MakeNumber(Trunc(A.Number),V);                      { INT }
   26:Begin                                               { LCASE }
      S:=A.Text;
      For I:=1To Length(S)Do If S[I]in['A'..'Z']Then S[I]:=Chr(Ord(S[I])+32);
      MakeText(S,V);
     End;
   27:MakeText(Copy(A.Text,1,Trunc(B.Number)),V);         { LEFT }
   28:MakeNumber(Length(A.Text),V);                       { LEN }
   29:MakeText(Copy(A.Text,Length(A.Text)-Trunc(B.Number)+1,255),V); { RIGHT }
   30:MakeNumber(Random,V);                               { RND }
   31:MakeText(Trim(A.Text),V);                           { TRIM }
   32:MakeText(Upper(A.Text),V);                          { UCASE }
   33:If(Trunc(A.Number)>=0)and(Trunc(A.Number)<ScriptArgumentCount)Then
       MakeText(ScriptArguments[Trunc(A.Number)],V)
      Else MakeText('',V);                               { WSCRIPT.ARGUMENTS }
   Else MakeText('',V);
  End;
  Exit;
 End;
 If U='WSCRIPT.ARGUMENTS.COUNT'Then MakeNumber(ScriptArgumentCount,V)
 Else If U='WSCRIPT.SCRIPTNAME'Then MakeText(ScriptName,V)
 Else If U='WSCRIPT.FULLNAME'Then MakeText(ParamStr(0),V)
 Else GetVariable(Name,V);
End;

Procedure ParseUnary(Var V:TValue);
Begin
 SkipSpace;
 If Copy(Upper(Copy(ExprText,ExprPos,4)),1,4)='NOT 'Then Begin
  Inc(ExprPos,4);ParseUnary(V);
  If Truth(V)Then MakeNumber(0,V)
             Else MakeNumber(-1,V);
 End
  Else
 If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]='-')Then Begin
  Inc(ExprPos);
  ParseUnary(V);
  MakeNumber(-V.Number,V);
 End
  Else
 ParsePrimary(V);
End;

Procedure ParseMul(Var V:TValue);
Var R:TValue;Op:String;
Begin
 ParseUnary(V);
 While True Do Begin SkipSpace;Op:='';
  If Copy(Upper(Copy(ExprText,ExprPos,4)),1,4)=' MOD'Then Begin Op:='MOD';Inc(ExprPos,4);End
  Else If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['*','/','\'])Then Begin Op:=ExprText[ExprPos];Inc(ExprPos);End;
  If Op=''Then Exit;ParseUnary(R);
  If Op='*'Then MakeNumber(V.Number*R.Number,V)
  Else If Op='/'Then Begin If R.Number=0Then MakeText('',V)Else MakeNumber(V.Number/R.Number,V);End
  Else If Op='\'Then Begin If Trunc(R.Number)=0Then MakeText('',V)Else MakeNumber(Trunc(V.Number)div Trunc(R.Number),V);End
  Else If Trunc(R.Number)=0Then MakeText('',V)Else MakeNumber(Trunc(V.Number)mod Trunc(R.Number),V);
 End;
End;

Procedure ParseAdd(Var V:TValue);
Var R:TValue;Op:Char;
Begin
 ParseMul(V);
 While True Do Begin SkipSpace;
  If(ExprPos>Length(ExprText))or Not(ExprText[ExprPos]in['+','-','&'])Then Exit;
  Op:=ExprText[ExprPos];Inc(ExprPos);ParseMul(R);
  If Op='&'Then MakeText(V.Text+R.Text,V)
  Else If Op='+'Then Begin If V.IsNumber and R.IsNumber Then MakeNumber(V.Number+R.Number,V)Else MakeText(V.Text+R.Text,V);End
  Else MakeNumber(V.Number-R.Number,V);
 End;
End;

Procedure ParseExpression(Var V:TValue);
Var R:TValue;Op:String;Result:Boolean;
Begin
 ParseAdd(V);SkipSpace;Op:='';
 If Copy(ExprText,ExprPos,2)='<>'Then Begin Op:='<>';Inc(ExprPos,2);End
 Else If Copy(ExprText,ExprPos,2)='<='Then Begin Op:='<=';Inc(ExprPos,2);End
 Else If Copy(ExprText,ExprPos,2)='>='Then Begin Op:='>=';Inc(ExprPos,2);End
 Else If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['=','<','>'])Then Begin Op:=ExprText[ExprPos];Inc(ExprPos);End;
 If Op<>''Then Begin ParseAdd(R);
  If V.IsNumber and R.IsNumber Then Begin
   If Op='='Then Result:=V.Number=R.Number Else If Op='<>'Then Result:=V.Number<>R.Number
   Else If Op='<'Then Result:=V.Number<R.Number Else If Op='>'Then Result:=V.Number>R.Number
   Else If Op='<='Then Result:=V.Number<=R.Number Else Result:=V.Number>=R.Number;
  End Else Begin
   If Op='='Then Result:=Upper(V.Text)=Upper(R.Text)Else If Op='<>'Then Result:=Upper(V.Text)<>Upper(R.Text)
   Else If Op='<'Then Result:=Upper(V.Text)<Upper(R.Text)Else If Op='>'Then Result:=Upper(V.Text)>Upper(R.Text)
   Else If Op='<='Then Result:=Upper(V.Text)<=Upper(R.Text)Else Result:=Upper(V.Text)>=Upper(R.Text);
  End;
  If Result Then MakeNumber(-1,V)Else MakeNumber(0,V);
 End;
End;

Procedure Evaluate(S:String;Var V:TValue);
Begin ExprText:=Trim(S);ExprPos:=1;ParseExpression(V);End;

Function FindAssignment(S:String):Integer;
Var I:Integer;Q:Char;
Begin
 Q:=#0;For I:=1To Length(S)Do Begin
  If Q<>#0Then Begin If S[I]=Q Then Q:=#0;End Else If S[I]in['"','''']Then Q:=S[I]
  Else If(S[I]='=')and((I=1)or Not(S[I-1]in['<','>']))Then Begin FindAssignment:=I;Exit;End;
 End;FindAssignment:=0;
End;

Procedure CheckTimeout;
Var H,M,S,HS:Word;Elapsed:LongInt;
Begin
 If TimeLimit<=0Then Exit;GetTime(H,M,S,HS);
 Elapsed:=(LongInt(H)*3600+LongInt(M)*60+S)-(LongInt(StartHour)*3600+LongInt(StartMinute)*60+StartSecond);
 If Elapsed<0Then Inc(Elapsed,86400);
 If Elapsed>=TimeLimit Then Begin WriteLn('CSCRIPT: Delai d''execution depasse.');Terminated:=True;ExitCode:=1;End;
End;

Function FindBlock(StartLine:LongInt;OpenWord,CloseWord:String):LongInt;
Var I:LongInt;Depth:Integer;S:String;
Begin
 Depth:=1;For I:=StartLine+1To LineCount Do Begin S:=Upper(Trim(ScriptLineText(I)));
  If StartsWith(S,OpenWord)Then Inc(Depth);If StartsWith(S,CloseWord)Then Dec(Depth);
  If Depth=0Then Begin FindBlock:=I;Exit;End;
 End;FindBlock:=LineCount;
End;

Procedure ExecuteRange(FirstLine,LastLine:LongInt);Forward;

Procedure ExecuteStatement(S:String);
Var U,Name,RightSide:String;P,I:Integer;V:TValue;
Begin
 S:=Trim(S);If(S='')or(S[1]='''')or StartsWith(S,'REM ')Then Exit;U:=Upper(S);
 If StartsWith(S,'DIM ')Then Begin
  Delete(S,1,4);Repeat P:=Pos(',',S);If P=0Then Begin Name:=Trim(S);S:='';End
   Else Begin Name:=Trim(Copy(S,1,P-1));Delete(S,1,P);End;SetVariable(Name,'');Until S='';Exit;End;
 If StartsWith(S,'WScript.Echo')Then Delete(S,1,Length('WScript.Echo'))
 Else If StartsWith(S,'Echo ')Then Delete(S,1,5)
 Else If StartsWith(S,'WScript.Quit')Then Begin
  Delete(S,1,Length('WScript.Quit'));
  Evaluate(S,V);ExitCode:=Trunc(V.Number);
  Terminated:=True;
  Exit;
 End
  Else
 If StartsWith(S,'Randomize')Then Begin
  Randomize;
  Exit;
 End
  Else
 Begin
  If StartsWith(S,'SET ')Then Delete(S,1,4);
  If StartsWith(S,'LET ')Then Delete(S,1,4);
  P:=FindAssignment(S);If P>0Then Begin
   Name:=Trim(Copy(S,1,P-1));
   RightSide:=Copy(S,P+1,255);
   Evaluate(RightSide,V);
   SetVariable(Name,V.Text);
   Exit;
  End;
  If Not BatchMode Then WriteLn('Erreur VBScript: instruction non reconnue: ',S);
  ExitCode:=1;
  Exit;
 End;
 { La branche Echo arrive ici. }
 I:=1;While I<=Length(S)Do Begin P:=Pos(',',Copy(S,I,255));
  If P=0Then Begin Evaluate(Copy(S,I,255),V);Write(V.Text);I:=Length(S)+1;End
  Else Begin Evaluate(Copy(S,I,P-1),V);Write(V.Text,' ');Inc(I,P);End;
 End;WriteLn;
End;

Procedure ExecuteRange(FirstLine,LastLine:LongInt);
Var S,U,Condition,Name,Rest:String;P,ThenPos,ElsePos:Integer;
 EndLine,BodyStart,I,ScanLine,ElseLine:LongInt;
 V,StartValue,EndValue,StepValue,Counter:TValue;
Begin
 I:=FirstLine;
 While(I<=LastLine)and Not Terminated Do Begin
  CheckTimeout;If Terminated Then Exit;CurrentLine:=I;S:=Trim(ScriptLineText(I));U:=Upper(S);
  If StartsWith(S,'IF ')Then Begin
   ThenPos:=Pos(' THEN',U);If ThenPos>0Then Begin Condition:=Copy(S,4,ThenPos-4);Evaluate(Condition,V);
    Rest:=Trim(Copy(S,ThenPos+5,255));
    If Rest<>''Then Begin ElsePos:=Pos(' ELSE ',Upper(Rest));
     If Truth(V)Then Begin If ElsePos>0Then ExecuteStatement(Copy(Rest,1,ElsePos-1))Else ExecuteStatement(Rest);End
     Else If ElsePos>0Then ExecuteStatement(Copy(Rest,ElsePos+6,255));
    End Else Begin EndLine:=FindBlock(I,'IF ','END IF');BodyStart:=I+1;ElseLine:=0;
     For ScanLine:=I+1To EndLine-1Do If Upper(Trim(ScriptLineText(ScanLine)))='ELSE'Then Begin ElseLine:=ScanLine;Break;End;
     If Truth(V)Then Begin If ElseLine=0Then ExecuteRange(BodyStart,EndLine-1)Else ExecuteRange(BodyStart,ElseLine-1);End
     Else If ElseLine>0Then ExecuteRange(ElseLine+1,EndLine-1);I:=EndLine;
    End;
   End;
  End Else If StartsWith(S,'FOR ')Then Begin
   Rest:=Trim(Copy(S,5,255));P:=FindAssignment(Rest);Name:=Trim(Copy(Rest,1,P-1));Delete(Rest,1,P);
   ThenPos:=Pos(' TO ',Upper(Rest));Evaluate(Copy(Rest,1,ThenPos-1),StartValue);Delete(Rest,1,ThenPos+3);
   ElsePos:=Pos(' STEP ',Upper(Rest));If ElsePos>0Then Begin
    Evaluate(Copy(Rest,1,ElsePos-1),EndValue);
    Evaluate(Copy(Rest,ElsePos+6,255),StepValue);
   End
    Else
   Begin
    Evaluate(Rest,EndValue);
    MakeNumber(1,StepValue);
   End;
   EndLine:=FindBlock(I,'FOR ','NEXT');
   Counter:=StartValue;
   While(((StepValue.Number>=0)and(Counter.Number<=EndValue.Number))or((StepValue.Number<0)and
        (Counter.Number>=EndValue.Number)))and Not Terminated Do Begin
    SetVariable(Name,Counter.Text);
    ExecuteRange(I+1,EndLine-1);MakeNumber(Counter.Number+StepValue.Number,Counter);
   End;
   I:=EndLine;
  End
   Else
  If StartsWith(S,'WHILE ')Then Begin
   EndLine:=FindBlock(I,'WHILE ','WEND');
   Condition:=Copy(S,7,255);Evaluate(Condition,V);
   While Truth(V)and Not Terminated Do Begin
    ExecuteRange(I+1,EndLine-1);
    Evaluate(Condition,V);CheckTimeout;
   End;
   I:=EndLine;
  End
   Else
  If(U='ELSE')or(U='END IF')or StartsWith(U,'NEXT')or(U='WEND')Then Exit
                                                               Else ExecuteStatement(S);
  Inc(I);
 End;
End;

Procedure ShowHelp;Begin
 WriteLn('CSCRIPT - Cette commande permet de lancer l''interpr'+#130,
         'teur de VBScript console.');
 WriteLn('Windows Script Host Version ',VersionText,' - clone Pascal');
 WriteLn('Syntaxe : CSCRIPT [options] script.vbs [arguments]');WriteLn;
 WriteLn('//B  Mode batch                 //I  Mode interactif');
 WriteLn('//D  Debogage actif             //X  Demarrer dans le debogueur');
 WriteLn('//E:moteur  Moteur de script    //Job:id  Travail WSF');
 WriteLn('//H:CScript|WScript  Hote par defaut');
 WriteLn('//Logo | //Nologo               //S  Sauver les options');
 WriteLn('//T:secondes  Delai maximal     //U  Sortie Unicode');
 WriteLn('//? ou /?  Cette aide');
End;

Procedure ParseOptions;
Var I,P:Integer;A,U:String;Code:Integer;SeenScript:Boolean;
Begin
 EngineName:='VBScript';BatchMode:=False;DebugMode:=False;InteractiveMode:=True;
 ShowLogo:=True;UnicodeMode:=False;TimeLimit:=0;ScriptName:='';JobName:='';SeenScript:=False;
 For I:=1To ParamCount Do Begin A:=ParamStr(I);U:=Upper(A);
  If Not SeenScript and((Copy(A,1,2)='//')or(A='/?')or(A='-?'))Then Begin
   If(U='//?')or(U='/?')or(U='-?')Then Begin ShowHelp;Terminated:=True;Exit;End
   Else If U='//B'Then Begin BatchMode:=True;InteractiveMode:=False;End
   Else If U='//D'Then DebugMode:=True Else If U='//I'Then InteractiveMode:=True
   Else If U='//LOGO'Then ShowLogo:=True Else If U='//NOLOGO'Then ShowLogo:=False
   Else If U='//U'Then UnicodeMode:=True Else If U='//X'Then DebugMode:=True
   Else If Copy(U,1,4)='//E:'Then EngineName:=Copy(A,5,255)
   Else If Copy(U,1,6)='//JOB:'Then JobName:=Copy(A,7,255)
   Else If Copy(U,1,4)='//T:'Then Begin Val(Copy(A,5,255),TimeLimit,Code);If Code<>0Then TimeLimit:=0;End
   Else If Copy(U,1,4)='//H:'Then Begin { option acceptee; ce clone reste l'hote console } End
   Else If U='//S'Then Begin { les options courantes sont deja celles de cette invocation } End
   Else Begin WriteLn('Option CSCRIPT non reconnue: ',A);ExitCode:=1;Terminated:=True;Exit;End;
  End Else If Not SeenScript Then Begin ScriptName:=A;SeenScript:=True;End
  Else If ScriptArgumentCount<MaxArguments Then Begin ScriptArguments[ScriptArgumentCount]:=A;Inc(ScriptArgumentCount);End;
 End;
 If ScriptName=''Then Begin ShowHelp;Terminated:=True;End;
End;

Procedure LoadScript;
Var F:Text;S:String;ErrorCode:Integer;
Begin
 {$I-}Assign(F,ScriptName);Reset(F);{$I+}ErrorCode:=IoResult;
 If ErrorCode<>0Then Begin
  WriteLn('Erreur d''entree: fichier introuvable "',ScriptName,'".');
  ExitCode:=1;
  Terminated:=True;
  Exit;
 End;
 While Not Eof(F)Do Begin
  ReadLn(F,S);
  AddScriptLine(S);
 End;
 Close(F);
End;

BEGIN
 Randomize;Variables:=Nil;FirstScriptLine:=Nil;LastScriptLine:=Nil;
 LineCount:=0;ArrayCounter:=0;ScriptArgumentCount:=0;Terminated:=False;ExitCode:=0;
 ParseOptions;
 If Not Terminated Then Begin
  If Upper(EngineName)<>'VBSCRIPT'Then Begin WriteLn('Moteur de script inconnu: ',EngineName);ExitCode:=1;End
   Else
  Begin
   If ShowLogo Then WriteLn('Windows Script Host Version ',VersionText,' - clone Pascal');
   LoadScript;
   If Not Terminated Then Begin
    GetTime(StartHour,StartMinute,StartSecond,StartHundredth);
    ExecuteRange(1,LineCount);
   End;
  End;
 End;
 Halt(ExitCode);
END.
