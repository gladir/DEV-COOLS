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
 ValueEmpty=0;ValueString=1;ValueNumber=2;ValueDate=3;
 ValueArray=4;ValueError=5;ValueNull=6;ValueObject=7;
 FunctionList:Array[0..66]of String[24]=(
  'ABS','ARRAY','ASC','ATN','CBOOL','CBYTE','CDATE','CDBL','CHR','CINT',
  'CLNG','COS','CSNG','CSTR','CVERR','DATE','DATESERIAL','DATEVALUE','DAY',
  'EXP','FIX','HEX','HOUR','INPUTBOX','INSTR','INT','ISARRAY','ISDATE',
  'ISEMPTY','ISERROR','ISNULL','ISNUMERIC','ISOBJECT','LBOUND','LCASE',
  'LEFT','LEN','LOG','LTRIM','MID','MINUTE','MONTH','MSGBOX','NOW','OCT',
  'RIGHT','RND','RTRIM','SECOND','SGN','SIN','SQR','STR','STRCOMP','STRING',
  'TAN','TIME','TIMESERIAL','TIMEVALUE','TRIM','UBOUND','UCASE','VAL','VARTYPE',
  'WEEKDAY','WSCRIPT.ARGUMENTS','YEAR');

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
  ValueKind:Byte;
  Next:PVariable;
 End;
 PCallBinding=^TCallBinding;
 TCallBinding=Record
  Name:String[63];
  ActualName:String[63];
  Existed:Boolean;
  CopyBack:Boolean;
  OldValue:String;
  OldKind:Byte;
  Next:PCallBinding;
 End;
 TValue=Record
  Text:String;
  Number:Real;
  IsNumber:Boolean;
  ValueKind:Byte;
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
 Terminated,ExitDoRequested,ExitForRequested,ExitSubRequested,ExitFunctionRequested:Boolean;
 OnErrorResumeNext:Boolean;
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
Begin
 V.Text:=S;Val(S,N,Code);V.IsNumber:=Code=0;
 If V.IsNumber Then Begin V.Number:=N;V.ValueKind:=ValueNumber;End
 Else Begin V.Number:=0;If S=''Then V.ValueKind:=ValueEmpty Else V.ValueKind:=ValueString;End;
End;

Procedure MakeNumber(N:Real;Var V:TValue);
Var S:String;
Begin
 If Frac(N)=0Then Str(Trunc(N),S)Else Str(N:0:8,S);
 V.Text:=Trim(S);V.Number:=N;V.IsNumber:=True;V.ValueKind:=ValueNumber;
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
 MakeText(SDay+'/'+SMonth+'/'+Trim(SYear),V);V.ValueKind:=ValueDate;
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

Procedure DateMinuteValue(SourceText:String;Var V:TValue);
Var P,P2,MinuteValue,Code:Integer;TimeText:String;
Begin
 SourceText:=Trim(SourceText);P:=Pos(' ',SourceText);
 If P>0Then TimeText:=Trim(Copy(SourceText,P+1,255))Else TimeText:=SourceText;
 P:=Pos(':',TimeText);If P=0Then Begin MakeNumber(0,V);Exit;End;
 Delete(TimeText,1,P);P2:=Pos(':',TimeText);
 If P2>0Then TimeText:=Copy(TimeText,1,P2-1);
 Val(Trim(TimeText),MinuteValue,Code);
 If(Code=0)and(MinuteValue>=0)and(MinuteValue<=59)Then MakeNumber(MinuteValue,V)
 Else MakeText('',V);
End;

Procedure DateSecondValue(SourceText:String;Var V:TValue);
Var P,SecondValue,Code:Integer;TimeText:String;
Begin
 SourceText:=Trim(SourceText);P:=Pos(' ',SourceText);
 If P>0Then TimeText:=Trim(Copy(SourceText,P+1,255))Else TimeText:=SourceText;
 P:=Pos(':',TimeText);If P=0Then Begin MakeNumber(0,V);Exit;End;
 Delete(TimeText,1,P);P:=Pos(':',TimeText);
 If P=0Then Begin MakeNumber(0,V);Exit;End;Delete(TimeText,1,P);
 P:=1;While(P<=Length(TimeText))and(TimeText[P]in['0'..'9'])Do Inc(P);
 Val(Copy(TimeText,1,P-1),SecondValue,Code);
 If(Code=0)and(SecondValue>=0)and(SecondValue<=59)Then MakeNumber(SecondValue,V)
 Else MakeText('',V);
End;

Procedure DateMonthValue(SourceText:String;Var V:TValue);
Var DateValue:TValue;MonthValue,Code:Integer;
Begin
 ParseDateValue(SourceText,DateValue);
 If DateValue.Text=''Then Begin MakeText('',V);Exit;End;
 Val(Copy(DateValue.Text,4,2),MonthValue,Code);
 If Code=0Then MakeNumber(MonthValue,V)Else MakeText('',V);
End;

Procedure NowValue(Var V:TValue);
Var Year,Month,Day,DayOfWeek,HourValue,MinuteValue,Second,Hundredth:Word;
 DatePart,HourText,MinuteText,SecondText:String;DateValue:TValue;
Begin
 GetDate(Year,Month,Day,DayOfWeek);GetTime(HourValue,MinuteValue,Second,Hundredth);
 MakeDateValue(Year,Month,Day,DateValue);Str(HourValue,HourText);
 Str(MinuteValue,MinuteText);Str(Second,SecondText);
 If Length(HourText)<2Then HourText:='0'+HourText;
 If Length(MinuteText)<2Then MinuteText:='0'+MinuteText;
 If Length(SecondText)<2Then SecondText:='0'+SecondText;
 DatePart:=DateValue.Text+' '+HourText+':'+MinuteText+':'+SecondText;
 MakeText(DatePart,V);V.ValueKind:=ValueDate;
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

Procedure OctValue(NumberValue:LongInt;Var V:TValue);
Const Digits:Array[0..7]of Char='01234567';
Var ResultText:String;Digit,Count:Integer;Negative:Boolean;
Begin
 ResultText:='';Negative:=NumberValue<0;Count:=0;
 Repeat
  Digit:=NumberValue and 7;ResultText:=Digits[Digit+1]+ResultText;
  NumberValue:=NumberValue shr 3;Inc(Count);
 Until((Not Negative)and(NumberValue=0))or(Negative and(Count=11));
 MakeText(ResultText,V);
End;

Procedure StrValue(NumberValue:Real;Var V:TValue);
Var Number:TValue;
Begin
 MakeNumber(NumberValue,Number);
 If NumberValue>=0Then MakeText(' '+Number.Text,V)Else MakeText(Number.Text,V);
End;

Procedure MakeTimeValue(HourValue,MinuteValue,SecondValue:LongInt;Var V:TValue);
Var TotalSeconds:LongInt;HourText,MinuteText,SecondText:String;
Begin
 TotalSeconds:=HourValue*3600+MinuteValue*60+SecondValue;
 TotalSeconds:=TotalSeconds mod 86400;If TotalSeconds<0Then Inc(TotalSeconds,86400);
 HourValue:=TotalSeconds div 3600;MinuteValue:=(TotalSeconds mod 3600)div 60;
 SecondValue:=TotalSeconds mod 60;Str(HourValue,HourText);Str(MinuteValue,MinuteText);
 Str(SecondValue,SecondText);If Length(HourText)<2Then HourText:='0'+HourText;
 If Length(MinuteText)<2Then MinuteText:='0'+MinuteText;
 If Length(SecondText)<2Then SecondText:='0'+SecondText;
 MakeText(HourText+':'+MinuteText+':'+SecondText,V);V.ValueKind:=ValueDate;
End;

Procedure CurrentTimeValue(Var V:TValue);
Var HourValue,MinuteValue,SecondValue,Hundredth:Word;
Begin GetTime(HourValue,MinuteValue,SecondValue,Hundredth);
 MakeTimeValue(HourValue,MinuteValue,SecondValue,V);End;

Procedure ParseTimeValue(SourceText:String;Var V:TValue);
Var P,Code,HourValue,MinuteValue,SecondValue:Integer;UpperText,Part:String;
 IsPM,IsAM:Boolean;
Begin
 SourceText:=Trim(SourceText);P:=Pos(' ',SourceText);
 If(P>0)and(Pos(':',Copy(SourceText,P+1,255))>0)Then SourceText:=Trim(Copy(SourceText,P+1,255));
 UpperText:=Upper(SourceText);IsPM:=Pos('PM',UpperText)>0;IsAM:=Pos('AM',UpperText)>0;
 P:=Pos(':',SourceText);If P=0Then Begin MakeText('',V);Exit;End;
 Part:=Copy(SourceText,1,P-1);Val(Trim(Part),HourValue,Code);
 If Code<>0Then Begin MakeText('',V);Exit;End;Delete(SourceText,1,P);
 P:=Pos(':',SourceText);
 If P>0Then Begin Part:=Copy(SourceText,1,P-1);Delete(SourceText,1,P);End
 Else Begin Part:=SourceText;SourceText:='0';End;
 Val(Trim(Part),MinuteValue,Code);If Code<>0Then Begin MakeText('',V);Exit;End;
 P:=1;While(P<=Length(SourceText))and(SourceText[P]in['0'..'9'])Do Inc(P);
 If P=1Then SecondValue:=0 Else Begin Val(Copy(SourceText,1,P-1),SecondValue,Code);
  If Code<>0Then Begin MakeText('',V);Exit;End;End;
 If IsPM and(HourValue<12)Then Inc(HourValue,12);
 If IsAM and(HourValue=12)Then HourValue:=0;
 If(HourValue<0)or(HourValue>23)or(MinuteValue<0)or(MinuteValue>59)or
   (SecondValue<0)or(SecondValue>59)Then MakeText('',V)
 Else MakeTimeValue(HourValue,MinuteValue,SecondValue,V);
End;

Procedure StrCompValue(A,B,C:TValue;ArgumentCount:Integer;Var V:TValue);
Var LeftText,RightText:String;
Begin
 If(A.ValueKind=ValueNull)or(B.ValueKind=ValueNull)Then Begin MakeText('',V);V.ValueKind:=ValueNull;Exit;End;
 LeftText:=A.Text;RightText:=B.Text;
 If(ArgumentCount>=3)and(Trunc(C.Number)=1)Then Begin LeftText:=Upper(LeftText);RightText:=Upper(RightText);End;
 If LeftText<RightText Then MakeNumber(-1,V)Else If LeftText>RightText Then MakeNumber(1,V)Else MakeNumber(0,V);
End;

Procedure StringValue(Count:Integer;CharacterValue:TValue;Var V:TValue);
Var ResultText:String;Character:Char;
Begin
 If Count<0Then Begin MakeText('',V);Exit;End;If Count>255Then Count:=255;
 If CharacterValue.IsNumber Then Character:=Chr(Trunc(CharacterValue.Number)and 255)
 Else If CharacterValue.Text=''Then Character:=#0Else Character:=CharacterValue.Text[1];
 ResultText:='';While Length(ResultText)<Count Do ResultText:=ResultText+Character;
 MakeText(ResultText,V);V.ValueKind:=ValueString;
End;

Procedure MsgBoxValue(MessageText:String;StyleValue:Integer;TitleText:String;Var V:TValue);
Var Choice:Char;ButtonStyle,ResultCode:Integer;
Begin
 If TitleText<>''Then WriteLn('[',TitleText,']');WriteLn(MessageText);
 ButtonStyle:=StyleValue and 15;ResultCode:=1;
 If BatchMode Then Begin MakeNumber(ResultCode,V);Exit;End;
 Case ButtonStyle of
  1:Begin Write('[O]K/[A]nnuler ? ');Choice:=ReadKey;WriteLn;
     If UpCase(Choice)='A'Then ResultCode:=2;End;
  2:Begin Write('[A]bandonner/[R]eessayer/[I]gnorer ? ');Choice:=ReadKey;WriteLn;
     Case UpCase(Choice)of'A':ResultCode:=3;'R':ResultCode:=4;Else ResultCode:=5;End;End;
  3:Begin Write('[O]ui/[N]on/[A]nnuler ? ');Choice:=ReadKey;WriteLn;
     If UpCase(Choice)='O'Then ResultCode:=6 Else If UpCase(Choice)='N'Then ResultCode:=7 Else ResultCode:=2;End;
  4:Begin Write('[O]ui/[N]on ? ');Choice:=ReadKey;WriteLn;
     If UpCase(Choice)='O'Then ResultCode:=6 Else ResultCode:=7;End;
  5:Begin Write('[R]eessayer/[A]nnuler ? ');Choice:=ReadKey;WriteLn;
     If UpCase(Choice)='R'Then ResultCode:=4 Else ResultCode:=2;End;
 End;
 MakeNumber(ResultCode,V);
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

Procedure BooleanValue(State:Boolean;Var V:TValue);
Begin
 If State Then Begin MakeText('True',V);V.Number:=-1;End
 Else Begin MakeText('False',V);V.Number:=0;End;
End;

Procedure IsDateValue(A:TValue;Var V:TValue);
Var Converted:TValue;
Begin
 If A.ValueKind=ValueDate Then BooleanValue(True,V)
 Else Begin ParseDateValue(A.Text,Converted);BooleanValue(Converted.Text<>'',V);End;
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
Var P:PVariable;V:TValue;
Begin
 Name:=Upper(Trim(Name));If Name=''Then Exit;P:=FindVariable(Name);
 If P=Nil Then Begin New(P);P^.Name:=Name;P^.Next:=Variables;Variables:=P;End;
 MakeText(Value,V);P^.Value:=Value;P^.ValueKind:=V.ValueKind;
 If Copy(Value,1,8)='@VBARRAY'Then P^.ValueKind:=ValueArray;
 If Copy(Value,1,6)='Error 'Then P^.ValueKind:=ValueError;
End;

Procedure SetVariableValue(Name:String;V:TValue);
Var P:PVariable;
Begin
 Name:=Upper(Trim(Name));If Name=''Then Exit;P:=FindVariable(Name);
 If P=Nil Then Begin New(P);P^.Name:=Name;P^.Next:=Variables;Variables:=P;End;
 P^.Value:=V.Text;P^.ValueKind:=V.ValueKind;
End;

Procedure GetVariable(Name:String;Var V:TValue);
Var P:PVariable;
Begin
 P:=FindVariable(Name);If P=Nil Then MakeText('',V)Else Begin
 MakeText(P^.Value,V);V.ValueKind:=P^.ValueKind;
 End;
End;

Procedure RemoveVariable(Name:String);
Var P,Previous:PVariable;
Begin
 Name:=Upper(Trim(Name));P:=Variables;Previous:=Nil;
 While P<>Nil Do Begin
  If P^.Name=Name Then Begin
   If Previous=Nil Then Variables:=P^.Next Else Previous^.Next:=P^.Next;
   Dispose(P);Exit;
  End;
  Previous:=P;P:=P^.Next;
 End;
End;

Procedure RemoveVariablesWithPrefix(Prefix:String);
Var P,Previous,NextVariable:PVariable;
Begin
 Prefix:=Upper(Prefix);P:=Variables;Previous:=Nil;
 While P<>Nil Do Begin
  NextVariable:=P^.Next;
  If Copy(P^.Name,1,Length(Prefix))=Prefix Then Begin
   If Previous=Nil Then Variables:=NextVariable Else Previous^.Next:=NextVariable;
   Dispose(P);
  End Else Previous:=P;
  P:=NextVariable;
 End;
End;

Procedure EraseVariable(Name:String);
Var VariableEntry:PVariable;Reference,CountText,DynamicText:String;Stored:TValue;
Begin
 Name:=Trim(Name);VariableEntry:=FindVariable(Name);
 If VariableEntry=Nil Then Exit;
 If VariableEntry^.ValueKind=ValueArray Then Begin
  Reference:=VariableEntry^.Value;GetVariable(Reference+'.COUNT',Stored);CountText:=Stored.Text;
  GetVariable(Reference+'.DYNAMIC',Stored);DynamicText:=Stored.Text;
  RemoveVariablesWithPrefix(Reference+'.');
  If DynamicText<>'1'Then Begin
   SetVariable(Reference+'.COUNT',CountText);SetVariable(Reference+'.DYNAMIC','0');Exit;
  End;
 End;
 RemoveVariable(Name);
End;

Procedure UBoundValue(A,B:TValue;ArgumentCount:Integer;Var V:TValue);
Var CountValue:TValue;
Begin
 If(A.ValueKind<>ValueArray)and(Copy(A.Text,1,8)<>'@VBARRAY')Then Begin MakeText('',V);Exit;End;
 If(ArgumentCount>1)and(Trunc(B.Number)<>1)Then Begin MakeText('',V);Exit;End;
 GetVariable(A.Text+'.COUNT',CountValue);MakeNumber(Trunc(CountValue.Number)-1,V);
End;

Procedure ValValue(SourceText:String;Var V:TValue);
Var NumberText,UpperText:String;Position,Code,Base,Digit:Integer;
 NumberValue:Real;IntegerValue:LongInt;HasDigit:Boolean;
Begin
 SourceText:=Trim(SourceText);UpperText:=Upper(SourceText);
 If(Copy(UpperText,1,2)='&H')or(Copy(UpperText,1,2)='&O')Then Begin
  If UpperText[2]='H'Then Base:=16 Else Base:=8;
  Position:=3;IntegerValue:=0;HasDigit:=False;
  While Position<=Length(UpperText)Do Begin
   If UpperText[Position]in['0'..'9']Then Digit:=Ord(UpperText[Position])-Ord('0')
   Else If UpperText[Position]in['A'..'F']Then Digit:=Ord(UpperText[Position])-Ord('A')+10
   Else Break;
   If Digit>=Base Then Break;
   IntegerValue:=IntegerValue*Base+Digit;HasDigit:=True;Inc(Position);
  End;
  If HasDigit Then MakeNumber(IntegerValue,V)Else MakeNumber(0,V);Exit;
 End;
 NumberText:='';Position:=1;HasDigit:=False;
 If(Position<=Length(SourceText))and(SourceText[Position]in['+','-'])Then Begin
  NumberText:=SourceText[Position];Inc(Position);End;
 While(Position<=Length(SourceText))and(SourceText[Position]in['0'..'9'])Do Begin
  NumberText:=NumberText+SourceText[Position];Inc(Position);HasDigit:=True;End;
 If(Position<=Length(SourceText))and(SourceText[Position]='.')Then Begin
  NumberText:=NumberText+'.';Inc(Position);
  While(Position<=Length(SourceText))and(SourceText[Position]in['0'..'9'])Do Begin
   NumberText:=NumberText+SourceText[Position];Inc(Position);HasDigit:=True;End;
 End;
 If HasDigit and(Position<=Length(SourceText))and(SourceText[Position]in['E','e'])Then Begin
  NumberText:=NumberText+'E';Inc(Position);
  If(Position<=Length(SourceText))and(SourceText[Position]in['+','-'])Then Begin
   NumberText:=NumberText+SourceText[Position];Inc(Position);End;
  While(Position<=Length(SourceText))and(SourceText[Position]in['0'..'9'])Do Begin
   NumberText:=NumberText+SourceText[Position];Inc(Position);End;
 End;
 If Not HasDigit Then MakeNumber(0,V)Else Begin
  Val(NumberText,NumberValue,Code);If Code=0Then MakeNumber(NumberValue,V)Else MakeNumber(0,V);
 End;
End;

Procedure VarTypeValue(A:TValue;Var V:TValue);
Var TypeNumber:Integer;
Begin
 Case A.ValueKind of
  ValueEmpty:TypeNumber:=0;
  ValueString:TypeNumber:=8;
  ValueNumber:TypeNumber:=5;
  ValueDate:TypeNumber:=7;
  ValueArray:TypeNumber:=8204; { vbArray + vbVariant }
  ValueError:TypeNumber:=10;
  ValueNull:TypeNumber:=1;
  ValueObject:TypeNumber:=9;
 Else TypeNumber:=12;
 End;
 MakeNumber(TypeNumber,V);
End;

Procedure DateParts(SourceText:String;Var YearValue,MonthValue,DayValue:Integer;
 Var Valid:Boolean);
Var Converted:TValue;Code:Integer;
Begin
 ParseDateValue(SourceText,Converted);Valid:=Converted.Text<>'';
 If Not Valid Then Exit;
 Val(Copy(Converted.Text,1,2),DayValue,Code);If Code<>0Then Valid:=False;
 Val(Copy(Converted.Text,4,2),MonthValue,Code);If Code<>0Then Valid:=False;
 Val(Copy(Converted.Text,7,4),YearValue,Code);If Code<>0Then Valid:=False;
End;

Procedure WeekdayValue(A,B:TValue;ArgumentCount:Integer;Var V:TValue);
Var YearValue,MonthValue,DayValue,FirstDay,H,ResultDay:Integer;Valid:Boolean;
Begin
 DateParts(A.Text,YearValue,MonthValue,DayValue,Valid);
 If Not Valid Then Begin MakeText('',V);Exit;End;
 If ArgumentCount>1Then FirstDay:=Trunc(B.Number)Else FirstDay:=1;
 If FirstDay=0Then FirstDay:=1;
 If(FirstDay<1)or(FirstDay>7)Then Begin MakeText('',V);Exit;End;
 If MonthValue<3Then Begin Inc(MonthValue,12);Dec(YearValue);End;
 H:=(DayValue+(13*(MonthValue+1))div 5+YearValue+(YearValue div 4)-
     (YearValue div 100)+(YearValue div 400))mod 7;
 ResultDay:=((H+6)mod 7)+1;
 ResultDay:=((ResultDay-FirstDay+7)mod 7)+1;MakeNumber(ResultDay,V);
End;

Procedure YearValue(SourceText:String;Var V:TValue);
Var YearNumber,MonthNumber,DayNumber:Integer;Valid:Boolean;
Begin
 DateParts(SourceText,YearNumber,MonthNumber,DayNumber,Valid);
 If Valid Then MakeNumber(YearNumber,V)Else MakeText('',V);
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
Procedure CallUserFunction(FunctionName:String;A,B,C,D:TValue;
 ArgumentCount:Integer;Var V:TValue);Forward;

Function UserFunctionExists(FunctionName:String):Boolean;
Var I,P:Integer;Declaration,DeclarationName:String;
Begin
 UserFunctionExists:=False;
 For I:=1To LineCount Do Begin
  Declaration:=Trim(ScriptLineText(I));
  If StartsWith(Declaration,'PUBLIC FUNCTION ')Then Delete(Declaration,1,7)
  Else If StartsWith(Declaration,'PRIVATE FUNCTION ')Then Delete(Declaration,1,8);
  If StartsWith(Declaration,'FUNCTION ')Then Begin
   Delete(Declaration,1,9);P:=Pos('(',Declaration);
   If P=0Then P:=Pos(' ',Declaration);
   If P=0Then DeclarationName:=Trim(Declaration)
   Else DeclarationName:=Trim(Copy(Declaration,1,P-1));
   If Upper(DeclarationName)=Upper(FunctionName)Then Begin UserFunctionExists:=True;Exit;End;
  End;
 End;
End;

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
  MakeText(S,V);V.ValueKind:=ValueString;Exit;
 End;
 If ExprText[ExprPos]='('Then Begin Inc(ExprPos);ParseExpression(V);SkipSpace;
  If(ExprPos<=Length(ExprText))and(ExprText[ExprPos]=')')Then Inc(ExprPos);Exit;End;
 If ExprText[ExprPos]in['0'..'9']Then Begin
  S:='';While(ExprPos<=Length(ExprText))and(ExprText[ExprPos]in['0'..'9','.'])Do Begin S:=S+ExprText[ExprPos];Inc(ExprPos);End;
  Val(S,N,Code);If Code=0Then MakeNumber(N,V)Else MakeText(S,V);Exit;
 End;
 Name:=ReadWord;U:=Upper(Name);
 If U='TRUE'Then Begin MakeNumber(-1,V);Exit;End;
 If U='FALSE'Then Begin MakeNumber(0,V);Exit;End;
 If U='EMPTY'Then Begin MakeText('',V);Exit;End;
 If U='NULL'Then Begin MakeText('',V);V.ValueKind:=ValueNull;Exit;End;
 If U='NOTHING'Then Begin MakeText('',V);V.ValueKind:=ValueObject;Exit;End;
 SkipSpace;
 FunctionByte:=FunctionIndex(U);
 If((FunctionByte=15)or(FunctionByte=43)or(FunctionByte=56))and
   ((ExprPos>Length(ExprText))or(ExprText[ExprPos]<>'('))Then Begin
  If FunctionByte=15Then Begin GetDate(DateYear,DateMonth,DateDay,DateDayOfWeek);
   MakeDateValue(DateYear,DateMonth,DateDay,V);End
  Else If FunctionByte=43Then NowValue(V)Else CurrentTimeValue(V);Exit;
 End;
 If(FunctionByte=255)and UserFunctionExists(Name)and
   ((ExprPos>Length(ExprText))or(ExprText[ExprPos]<>'('))Then Begin
  MakeText('',A);MakeText('',B);MakeText('',C);MakeText('',D);
  CallUserFunction(Name,A,B,C,D,0,V);Exit;
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
  MakeText(ArrayReference,V);V.ValueKind:=ValueArray;Exit;
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
  If(FunctionByte=255)and UserFunctionExists(Name)Then Begin
   CallUserFunction(Name,A,B,C,D,ArgumentCount,V);Exit;
  End;
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
   13:Begin MakeText(A.Text,V);V.ValueKind:=ValueString;End; { CSTR }
   14:Begin MakeText('Error '+A.Text,V);V.Number:=A.Number;V.ValueKind:=ValueError;End; { CVERR }
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
   26:BooleanValue((A.ValueKind=ValueArray)or(Copy(A.Text,1,8)='@VBARRAY'),V); { ISARRAY }
   27:IsDateValue(A,V);                                   { ISDATE }
   28:BooleanValue(A.ValueKind=ValueEmpty,V);              { ISEMPTY }
   29:BooleanValue(A.ValueKind=ValueError,V);              { ISERROR }
   30:BooleanValue(A.ValueKind=ValueNull,V);               { ISNULL }
   31:BooleanValue(A.IsNumber,V);                          { ISNUMERIC }
   32:BooleanValue(A.ValueKind=ValueObject,V);             { ISOBJECT }
   33:If((A.ValueKind=ValueArray)or(Copy(A.Text,1,8)='@VBARRAY'))and
        ((ArgumentCount<2)or(Trunc(B.Number)=1))Then
       MakeNumber(0,V)Else MakeText('',V);                { LBOUND }
   34:Begin                                               { LCASE }
      S:=A.Text;
      For I:=1To Length(S)Do If S[I]in['A'..'Z']Then S[I]:=Chr(Ord(S[I])+32);
      MakeText(S,V);
     End;
   35:MakeText(Copy(A.Text,1,Trunc(B.Number)),V);         { LEFT }
   36:MakeNumber(Length(A.Text),V);                       { LEN }
   37:If A.Number>0Then MakeNumber(Ln(A.Number),V)Else MakeText('',V); { LOG }
   38:Begin S:=A.Text;While(Length(S)>0)and(S[1]=' ')Do Delete(S,1,1);
      MakeText(S,V);End;                                  { LTRIM }
   39:Begin                                               { MID }
      I:=Trunc(B.Number);If I<1Then MakeText('',V)
      Else If ArgumentCount<3Then MakeText(Copy(A.Text,I,255),V)
      Else If C.Number<0Then MakeText('',V)
      Else MakeText(Copy(A.Text,I,Trunc(C.Number)),V);
     End;
   40:DateMinuteValue(A.Text,V);                          { MINUTE }
   41:DateMonthValue(A.Text,V);                           { MONTH }
   42:MsgBoxValue(A.Text,Trunc(B.Number),C.Text,V);       { MSGBOX }
   43:NowValue(V);                                        { NOW }
   44:OctValue(Trunc(A.Number),V);                        { OCT }
   45:MakeText(Copy(A.Text,Length(A.Text)-Trunc(B.Number)+1,255),V); { RIGHT }
   46:MakeNumber(Random,V);                               { RND }
   47:Begin                                               { RTRIM }
      If A.ValueKind=ValueNull Then V:=A Else Begin S:=A.Text;
       While(Length(S)>0)and(S[Length(S)]=' ')Do Delete(S,Length(S),1);
       MakeText(S,V);End;
     End;
   48:DateSecondValue(A.Text,V);                          { SECOND }
   49:If A.Number<0Then MakeNumber(-1,V)
      Else If A.Number>0Then MakeNumber(1,V)Else MakeNumber(0,V); { SGN }
   50:MakeNumber(Sin(A.Number),V);                        { SIN }
   51:If A.Number<0Then MakeText('',V)Else MakeNumber(Sqrt(A.Number),V); { SQR }
   52:StrValue(A.Number,V);                               { STR }
   53:StrCompValue(A,B,C,ArgumentCount,V);                { STRCOMP }
   54:StringValue(Trunc(A.Number),B,V);                   { STRING }
   55:If Cos(A.Number)=0Then MakeText('',V)Else MakeNumber(Sin(A.Number)/Cos(A.Number),V); { TAN }
   56:CurrentTimeValue(V);                                { TIME }
   57:MakeTimeValue(Trunc(A.Number),Trunc(B.Number),Trunc(C.Number),V); { TIMESERIAL }
   58:ParseTimeValue(A.Text,V);                           { TIMEVALUE }
   59:MakeText(Trim(A.Text),V);                           { TRIM }
   60:UBoundValue(A,B,ArgumentCount,V);                   { UBOUND }
   61:MakeText(Upper(A.Text),V);                          { UCASE }
   62:ValValue(A.Text,V);                                 { VAL }
   63:VarTypeValue(A,V);                                 { VARTYPE }
   64:WeekdayValue(A,B,ArgumentCount,V);                  { WEEKDAY }
   65:If(Trunc(A.Number)>=0)and(Trunc(A.Number)<ScriptArgumentCount)Then
       MakeText(ScriptArguments[Trunc(A.Number)],V)
      Else MakeText('',V);                               { WSCRIPT.ARGUMENTS }
   66:YearValue(A.Text,V);                               { YEAR }
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

Function FindElseLine(StartLine,EndLine:LongInt):LongInt;
Var I:LongInt;Depth:Integer;S:String;
Begin
 Depth:=0;FindElseLine:=0;
 For I:=StartLine+1To EndLine-1Do Begin
  S:=Upper(Trim(ScriptLineText(I)));
  If StartsWith(S,'IF ')and(Pos(' THEN',S)>0)and
    (Trim(Copy(S,Pos(' THEN',S)+5,255))='')Then Inc(Depth)
  Else If S='END IF'Then Begin If Depth>0Then Dec(Depth);End
  Else If(Depth=0)and((S='ELSE')or StartsWith(S,'ELSEIF '))Then Begin
   FindElseLine:=I;Exit;
  End;
 End;
End;

Function FindLoopEnd(StartLine:LongInt):LongInt;
Var I:LongInt;Depth:Integer;S:String;
Begin
 Depth:=1;
 For I:=StartLine+1To LineCount Do Begin
  S:=Upper(Trim(ScriptLineText(I)));
  If(S='DO')or StartsWith(S,'DO WHILE ')or StartsWith(S,'DO UNTIL ')Then Inc(Depth)
  Else If StartsWith(S,'LOOP')Then Dec(Depth);
  If Depth=0Then Begin FindLoopEnd:=I;Exit;End;
 End;
 FindLoopEnd:=LineCount;
End;

Function KeywordOutsideQuotes(Source,Keyword:String):Integer;
Var I:Integer;Quote:Char;
Begin
 KeywordOutsideQuotes:=0;Quote:=#0;I:=1;
 While I<=Length(Source)-Length(Keyword)+1Do Begin
  If Quote<>#0Then Begin
   If Source[I]=Quote Then Begin
    If(I<Length(Source))and(Source[I+1]=Quote)Then Inc(I)Else Quote:=#0;
   End;
  End Else If Source[I]in['''','"']Then Quote:=Source[I]
  Else If Upper(Copy(Source,I,Length(Keyword)))=Upper(Keyword)Then Begin
   KeywordOutsideQuotes:=I;Exit;
  End;
  Inc(I);
 End;
End;

Procedure ExecuteRange(FirstLine,LastLine:LongInt);Forward;
Procedure CallSub(CallText:String);Forward;
Function ListItem(Var Source:String):String;Forward;
Function SimpleIdentifier(Source:String):Boolean;Forward;
Procedure ExecuteStatementList(Source:String);Forward;

Procedure ScriptError(MessageText:String;StopScript:Boolean);
Begin
 If OnErrorResumeNext Then Exit;
 If Not BatchMode Then WriteLn('Erreur VBScript: ',MessageText);
 ExitCode:=1;If StopScript Then Terminated:=True;
End;

Procedure DeclareVariable(Declaration:String);
Var Name,Bounds,Reference,NumberText:String;P:Integer;UpperBound:TValue;ArrayValue:TValue;
 IsDynamic:Boolean;
Begin
 Declaration:=Trim(Declaration);P:=Pos('(',Declaration);
 If P=0Then Begin SetVariable(Declaration,'');Exit;End;
 Name:=Trim(Copy(Declaration,1,P-1));Bounds:=Copy(Declaration,P+1,255);
 If(Length(Bounds)>0)and(Bounds[Length(Bounds)]=')')Then Delete(Bounds,Length(Bounds),1);
 Inc(ArrayCounter);Str(ArrayCounter,NumberText);Reference:='@VBARRAY'+Trim(NumberText);
 IsDynamic:=Trim(Bounds)='';
 If IsDynamic Then MakeNumber(0,UpperBound)Else Evaluate(Bounds,UpperBound);
 If UpperBound.Number<0Then MakeNumber(0,UpperBound);
 If IsDynamic Then NumberText:='0'Else Str(Trunc(UpperBound.Number)+1,NumberText);
 SetVariable(Reference+'.COUNT',Trim(NumberText));
 If IsDynamic Then SetVariable(Reference+'.DYNAMIC','1')Else SetVariable(Reference+'.DYNAMIC','0');
 MakeText(Reference,ArrayValue);ArrayValue.ValueKind:=ValueArray;SetVariableValue(Name,ArrayValue);
End;

Procedure RemoveArrayElementsFrom(Reference:String;FirstRemoved:LongInt);
Var P,Previous,NextVariable:PVariable;Suffix:String;ElementNumber:LongInt;Code:Integer;
 Removed:Boolean;
Begin
 Reference:=Upper(Reference)+'.';P:=Variables;Previous:=Nil;
 While P<>Nil Do Begin
  NextVariable:=P^.Next;Removed:=False;
  If Copy(P^.Name,1,Length(Reference))=Reference Then Begin
   Suffix:=Copy(P^.Name,Length(Reference)+1,255);Val(Suffix,ElementNumber,Code);
   If(Code=0)and(ElementNumber>=FirstRemoved)Then Begin
    If Previous=Nil Then Variables:=NextVariable Else Previous^.Next:=NextVariable;
    Dispose(P);Removed:=True;
   End;
  End;
  If Not Removed Then Previous:=P;P:=NextVariable;
 End;
End;

Procedure ResizeArray(Declaration:String;PreserveValues:Boolean);
Var Name,Bounds,Reference,NumberText:String;P:Integer;UpperBound,Stored,ArrayValue:TValue;
 VariableEntry:PVariable;NewCount:LongInt;
Begin
 Declaration:=Trim(Declaration);P:=Pos('(',Declaration);
 If(P=0)or(Declaration[Length(Declaration)]<>')')Then Begin
  ScriptError('REDIM exige une borne de tableau.',True);Exit;
 End;
 Name:=Trim(Copy(Declaration,1,P-1));Bounds:=Copy(Declaration,P+1,Length(Declaration)-P-1);
 If Pos(',',Bounds)>0Then Begin ScriptError('REDIM multidimensionnel non supporte.',True);Exit;End;
 Evaluate(Bounds,UpperBound);
 If(Not UpperBound.IsNumber)or(UpperBound.Number<0)Then Begin
  ScriptError('borne REDIM invalide.',True);Exit;
 End;
 NewCount:=Trunc(UpperBound.Number)+1;VariableEntry:=FindVariable(Name);
 If(VariableEntry<>Nil)and(VariableEntry^.ValueKind=ValueArray)Then Begin
  Reference:=VariableEntry^.Value;GetVariable(Reference+'.DYNAMIC',Stored);
  If Stored.Text<>'1'Then Begin ScriptError('REDIM exige un tableau dynamique.',True);Exit;End;
 End Else Begin
  If PreserveValues Then Begin ScriptError('REDIM PRESERVE exige un tableau existant.',True);Exit;End;
  Inc(ArrayCounter);Str(ArrayCounter,NumberText);Reference:='@VBARRAY'+Trim(NumberText);
 End;
 If PreserveValues Then RemoveArrayElementsFrom(Reference,NewCount)
 Else RemoveVariablesWithPrefix(Reference+'.');
 Str(NewCount,NumberText);SetVariable(Reference+'.COUNT',Trim(NumberText));
 SetVariable(Reference+'.DYNAMIC','1');MakeText(Reference,ArrayValue);
 ArrayValue.ValueKind:=ValueArray;SetVariableValue(Name,ArrayValue);
End;

Procedure DeclareStaticVariable(Declaration:String);
Var Name:String;P:Integer;
Begin
 Declaration:=Trim(Declaration);P:=Pos('(',Declaration);
 If P=0Then Name:=Declaration Else Name:=Trim(Copy(Declaration,1,P-1));
 If FindVariable(Name)=Nil Then DeclareVariable(Declaration);
End;

Function UserSubExists(CallText:String):Boolean;
Var I,P:Integer;CallName,Declaration,DeclarationName:String;
Begin
 CallText:=Trim(CallText);P:=Pos('(',CallText);If P=0Then P:=Pos(' ',CallText);
 If P=0Then CallName:=CallText Else CallName:=Copy(CallText,1,P-1);
 UserSubExists:=False;
 For I:=1To LineCount Do Begin
  Declaration:=Trim(ScriptLineText(I));
  If StartsWith(Declaration,'PUBLIC SUB ')Then Delete(Declaration,1,7)
  Else If StartsWith(Declaration,'PRIVATE SUB ')Then Delete(Declaration,1,8);
  If StartsWith(Declaration,'SUB ')Then Begin
   Delete(Declaration,1,4);P:=Pos('(',Declaration);If P=0Then P:=Pos(' ',Declaration);
   If P=0Then DeclarationName:=Trim(Declaration)
   Else DeclarationName:=Trim(Copy(Declaration,1,P-1));
   If Upper(DeclarationName)=Upper(CallName)Then Begin UserSubExists:=True;Exit;End;
  End;
 End;
End;

Procedure AlignStringAssignment(StatementText:String;AlignRight:Boolean);
Var Name,SourceText,ResultText:String;P,TargetLength:Integer;Value,OldValue:TValue;
Begin
 P:=FindAssignment(StatementText);
 If P=0Then Begin
  If AlignRight Then ScriptError('RSET exige une affectation.',True)
  Else ScriptError('LSET exige une affectation.',True);Exit;
 End;
 Name:=Trim(Copy(StatementText,1,P-1));SourceText:=Copy(StatementText,P+1,255);
 Evaluate(SourceText,Value);GetVariable(Name,OldValue);TargetLength:=Length(OldValue.Text);
 If TargetLength=0Then TargetLength:=Length(Value.Text);
 If Length(Value.Text)>TargetLength Then ResultText:=Copy(Value.Text,1,TargetLength)
 Else Begin ResultText:=Value.Text;
  If AlignRight Then While Length(ResultText)<TargetLength Do ResultText:=' '+ResultText
  Else While Length(ResultText)<TargetLength Do ResultText:=ResultText+' ';
 End;
 MakeText(ResultText,Value);Value.ValueKind:=ValueString;SetVariableValue(Name,Value);
End;

Procedure ExecuteStatement(S:String);
Var U,Name,RightSide,BaseName,IndexText:String;P,I:Integer;
 V,IndexValue:TValue;ArrayVariable:PVariable;WasLet,WasSet:Boolean;
Begin
 S:=Trim(S);If(S='')or(S[1]='''')or(Upper(S)='REM')or StartsWith(S,'REM ')Then Exit;
 U:=Upper(S);WasLet:=False;WasSet:=False;
 If StartsWith(S,'DIM ')Then Begin
  Delete(S,1,4);Repeat Name:=ListItem(S);DeclareVariable(Name);Until S='';Exit;End;
 If StartsWith(S,'PRIVATE ')Then Begin
  Delete(S,1,8);Repeat Name:=ListItem(S);DeclareVariable(Name);Until S='';Exit;End;
 If StartsWith(S,'PUBLIC ')Then Begin
  Delete(S,1,7);Repeat Name:=ListItem(S);DeclareVariable(Name);Until S='';Exit;End;
 If StartsWith(S,'STATIC ')Then Begin
  Delete(S,1,7);Repeat Name:=ListItem(S);DeclareStaticVariable(Name);Until S='';Exit;End;
 If StartsWith(S,'ERASE ')Then Begin
  Delete(S,1,6);Repeat Name:=ListItem(S);EraseVariable(Name);Until S='';Exit;End;
 If StartsWith(S,'REDIM ')Then Begin
  Delete(S,1,6);WasLet:=False;
  If StartsWith(S,'PRESERVE ')Then Begin Delete(S,1,9);WasLet:=True;End;
  Repeat Name:=ListItem(S);ResizeArray(Name,WasLet);Until(S='')or Terminated;Exit;
 End;
 If U='ON ERROR RESUME NEXT'Then Begin OnErrorResumeNext:=True;Exit;End;
 If(U='ON ERROR GOTO 0')or(U='ON ERROR GO TO 0')Then Begin OnErrorResumeNext:=False;Exit;End;
 If StartsWith(U,'ON ERROR ')Then Begin ScriptError('forme ON ERROR non supportee: '+S,False);Exit;End;
 If StartsWith(S,'LSET ')Then Begin
  Delete(S,1,5);AlignStringAssignment(S,False);Exit;
 End;
 If StartsWith(S,'RSET ')Then Begin Delete(S,1,5);AlignStringAssignment(S,True);Exit;End;
 If U='EXIT DO'Then Begin ExitDoRequested:=True;Exit;End;
 If U='EXIT FOR'Then Begin ExitForRequested:=True;Exit;End;
 If U='EXIT SUB'Then Begin ExitSubRequested:=True;Exit;End;
 If U='EXIT FUNCTION'Then Begin ExitFunctionRequested:=True;Exit;End;
 If StartsWith(S,'CALL ')Then Begin CallSub(Trim(Copy(S,6,255)));Exit;End;
 If StartsWith(S,'WScript.Echo')Then Delete(S,1,Length('WScript.Echo'))
 Else If StartsWith(S,'Echo ')Then Delete(S,1,5)
 Else If StartsWith(S,'WScript.Quit')Then Begin
  Delete(S,1,Length('WScript.Quit'));
  Evaluate(S,V);ExitCode:=Trunc(V.Number);
  Terminated:=True;
  Exit;
 End
  Else
 If StartsWith(S,'MSGBOX')Then Begin
  If(Length(S)>6)and(S[7]='(')Then Evaluate(S,V)
  Else Evaluate('MsgBox('+Trim(Copy(S,7,255))+')',V);
  Exit;
 End
  Else
 If StartsWith(S,'Randomize')Then Begin
  RightSide:=Trim(Copy(S,10,255));
  If RightSide=''Then Randomize Else Begin Evaluate(RightSide,V);RandSeed:=Trunc(V.Number);End;
  Exit;
 End
 Else
 Begin
  If StartsWith(S,'SET ')Then Begin Delete(S,1,4);WasSet:=True;End;
  If StartsWith(S,'LET ')Then Begin Delete(S,1,4);WasLet:=True;End;
  P:=FindAssignment(S);If P>0Then Begin
   Name:=Trim(Copy(S,1,P-1));
   RightSide:=Copy(S,P+1,255);
   Evaluate(RightSide,V);
   I:=Pos('(',Name);
   If(I>0)and(Name[Length(Name)]=')')Then Begin
    BaseName:=Trim(Copy(Name,1,I-1));ArrayVariable:=FindVariable(BaseName);
    If(ArrayVariable<>Nil)and(ArrayVariable^.ValueKind=ValueArray)Then Begin
     Evaluate(Copy(Name,I+1,Length(Name)-I-1),IndexValue);Str(Trunc(IndexValue.Number),IndexText);
     SetVariableValue(ArrayVariable^.Value+'.'+Trim(IndexText),V);
    End Else SetVariableValue(Name,V);
   End Else SetVariableValue(Name,V);
   Exit;
  End;
  If WasLet Then Begin
   ScriptError('LET exige une affectation.',True);Exit;
  End;
  If WasSet Then Begin ScriptError('SET exige une affectation.',True);Exit;End;
  If UserSubExists(S)Then Begin CallSub(S);Exit;End;
  ScriptError('instruction non reconnue: '+S,False);
  Exit;
 End;
 { La branche Echo arrive ici. }
 I:=1;While I<=Length(S)Do Begin P:=Pos(',',Copy(S,I,255));
  If P=0Then Begin Evaluate(Copy(S,I,255),V);Write(V.Text);I:=Length(S)+1;End
  Else Begin Evaluate(Copy(S,I,P-1),V);Write(V.Text,' ');Inc(I,P);End;
 End;WriteLn;
End;

Procedure ExecuteStatementList(Source:String);
Var I,StartPosition:Integer;Quote:Char;StatementText:String;
Begin
 I:=1;StartPosition:=1;Quote:=#0;
 While I<=Length(Source)Do Begin
  If Quote<>#0Then Begin
   If Source[I]=Quote Then Begin
    If(I<Length(Source))and(Source[I+1]=Quote)Then Inc(I)Else Quote:=#0;
   End;
  End Else If Source[I]in['''','"']Then Quote:=Source[I]
  Else If Source[I]=':'Then Begin
   StatementText:=Trim(Copy(Source,StartPosition,I-StartPosition));
   If StatementText<>''Then ExecuteStatement(StatementText);StartPosition:=I+1;
   If Terminated or ExitDoRequested or ExitForRequested or ExitSubRequested or
     ExitFunctionRequested Then Exit;
  End;
  Inc(I);
 End;
 StatementText:=Trim(Copy(Source,StartPosition,255));
 If StatementText<>''Then ExecuteStatement(StatementText);
End;

Procedure ExecuteRange(FirstLine,LastLine:LongInt);
Var S,U,Condition,Name,Rest:String;P,ThenPos,ElsePos:Integer;
 EndLine,BodyStart,I,ElseLine,ElementIndex,ElementCount:LongInt;
 V,StartValue,EndValue,StepValue,Counter,Collection,CountValue:TValue;
 LoopAgain,UntilMode:Boolean;IndexText,NextName:String;
Begin
 I:=FirstLine;
 While(I<=LastLine)and Not Terminated and Not ExitDoRequested and
   Not ExitForRequested and Not ExitSubRequested and Not ExitFunctionRequested Do Begin
  CheckTimeout;If Terminated Then Exit;CurrentLine:=I;S:=Trim(ScriptLineText(I));U:=Upper(S);
  If StartsWith(S,'ELSEIF ')Then Begin S:='IF '+Trim(Copy(S,8,255));U:=Upper(S);End;
  If StartsWith(S,'SUB ')or StartsWith(S,'PUBLIC SUB ')or
    StartsWith(S,'PRIVATE SUB ')Then Begin
   While(I<=LastLine)and(Upper(Trim(ScriptLineText(I)))<>'END SUB')Do Inc(I);
  End
  Else If StartsWith(S,'FUNCTION ')or StartsWith(S,'PUBLIC FUNCTION ')or
    StartsWith(S,'PRIVATE FUNCTION ')Then Begin
   While(I<=LastLine)and(Upper(Trim(ScriptLineText(I)))<>'END FUNCTION')Do Inc(I);
  End
  Else If U='END SUB'Then Exit
  Else If U='END FUNCTION'Then Exit
  Else If StartsWith(S,'IF ')Then Begin
   ThenPos:=Pos(' THEN',U);If ThenPos>0Then Begin Condition:=Copy(S,4,ThenPos-4);Evaluate(Condition,V);
    Rest:=Trim(Copy(S,ThenPos+5,255));
    If Rest<>''Then Begin ElsePos:=KeywordOutsideQuotes(Rest,' ELSE ');
     If Truth(V)Then Begin
      If ElsePos>0Then ExecuteStatementList(Copy(Rest,1,ElsePos-1))Else ExecuteStatementList(Rest);End
     Else If ElsePos>0Then ExecuteStatementList(Copy(Rest,ElsePos+6,255));
    End Else Begin EndLine:=FindBlock(I,'IF ','END IF');BodyStart:=I+1;
     ElseLine:=FindElseLine(I,EndLine);
     If Truth(V)Then Begin If ElseLine=0Then ExecuteRange(BodyStart,EndLine-1)Else ExecuteRange(BodyStart,ElseLine-1);End
     Else If ElseLine>0Then Begin
      If StartsWith(Trim(ScriptLineText(ElseLine)),'ELSEIF ')Then ExecuteRange(ElseLine,EndLine-1)
      Else ExecuteRange(ElseLine+1,EndLine-1);
     End;I:=EndLine;
    End;
   End;
  End Else If StartsWith(S,'FOR EACH ')Then Begin
   Rest:=Trim(Copy(S,10,255));P:=Pos(' IN ',Upper(Rest));
   If P=0Then Begin If Not BatchMode Then WriteLn('Erreur VBScript: FOR EACH sans IN.');ExitCode:=1;Exit;End;
   Name:=Trim(Copy(Rest,1,P-1));Evaluate(Copy(Rest,P+4,255),Collection);
   EndLine:=FindBlock(I,'FOR ','NEXT');ElementCount:=0;
   If(Collection.ValueKind=ValueArray)or(Copy(Collection.Text,1,8)='@VBARRAY')Then Begin
    GetVariable(Collection.Text+'.COUNT',CountValue);ElementCount:=Trunc(CountValue.Number);
   End;
   For ElementIndex:=0To ElementCount-1Do Begin
    Str(ElementIndex,IndexText);GetVariable(Collection.Text+'.'+Trim(IndexText),V);
    SetVariableValue(Name,V);ExecuteRange(I+1,EndLine-1);
    If ExitForRequested Then Begin ExitForRequested:=False;Break;End;
    If Terminated or ExitSubRequested or ExitFunctionRequested or ExitDoRequested Then Break;
   End;
   I:=EndLine;
  End Else If StartsWith(S,'FOR ')Then Begin
   Rest:=Trim(Copy(S,5,255));P:=FindAssignment(Rest);
   If P=0Then Begin WriteLn('Erreur VBScript: FOR sans signe =.');ExitCode:=1;Terminated:=True;Exit;End;
   Name:=Trim(Copy(Rest,1,P-1));Delete(Rest,1,P);
   If Not SimpleIdentifier(Name)Then Begin WriteLn('Erreur VBScript: compteur FOR invalide.');
    ExitCode:=1;Terminated:=True;Exit;End;
   ThenPos:=Pos(' TO ',Upper(Rest));
   If ThenPos=0Then Begin WriteLn('Erreur VBScript: FOR sans TO.');ExitCode:=1;Terminated:=True;Exit;End;
   Evaluate(Copy(Rest,1,ThenPos-1),StartValue);Delete(Rest,1,ThenPos+3);
   ElsePos:=Pos(' STEP ',Upper(Rest));If ElsePos>0Then Begin
    Evaluate(Copy(Rest,1,ElsePos-1),EndValue);
    Evaluate(Copy(Rest,ElsePos+6,255),StepValue);
   End
    Else
   Begin
    Evaluate(Rest,EndValue);
    MakeNumber(1,StepValue);
   End;
   If Not StartValue.IsNumber or Not EndValue.IsNumber or Not StepValue.IsNumber Then Begin
    WriteLn('Erreur VBScript: bornes FOR non numeriques.');ExitCode:=1;Terminated:=True;Exit;End;
   If StepValue.Number=0Then Begin WriteLn('Erreur VBScript: STEP ne peut pas etre nul.');
    ExitCode:=1;Terminated:=True;Exit;End;
   EndLine:=FindBlock(I,'FOR ','NEXT');
   NextName:=Trim(Copy(Trim(ScriptLineText(EndLine)),5,255));
   If(NextName<>'')and(Upper(NextName)<>Upper(Name))Then Begin
    WriteLn('Erreur VBScript: NEXT ',NextName,' ne correspond pas a FOR ',Name,'.');
    ExitCode:=1;Terminated:=True;Exit;
   End;
   Counter:=StartValue;
   While(((StepValue.Number>=0)and(Counter.Number<=EndValue.Number))or((StepValue.Number<0)and
        (Counter.Number>=EndValue.Number)))and Not Terminated and Not ExitSubRequested and
        Not ExitDoRequested and Not ExitFunctionRequested Do Begin
    SetVariableValue(Name,Counter);
    ExecuteRange(I+1,EndLine-1);
    If ExitForRequested Then Begin ExitForRequested:=False;Break;End;
    MakeNumber(Counter.Number+StepValue.Number,Counter);
   End;
   I:=EndLine;
  End
   Else
  If(U='DO')or StartsWith(U,'DO WHILE ')or StartsWith(U,'DO UNTIL ')Then Begin
   EndLine:=FindLoopEnd(I);Condition:='';UntilMode:=False;
   If StartsWith(U,'DO WHILE ')Then Condition:=Trim(Copy(S,10,255))
   Else If StartsWith(U,'DO UNTIL ')Then Begin Condition:=Trim(Copy(S,10,255));UntilMode:=True;End;
   Repeat
    LoopAgain:=True;
    If Condition<>''Then Begin Evaluate(Condition,V);
     If UntilMode Then LoopAgain:=Not Truth(V)Else LoopAgain:=Truth(V);End;
    If LoopAgain Then ExecuteRange(I+1,EndLine-1);
    If ExitDoRequested Then Begin ExitDoRequested:=False;LoopAgain:=False;End;
    If LoopAgain and Not Terminated and(Condition='')Then Begin
     Rest:=Trim(ScriptLineText(EndLine));
     If StartsWith(Rest,'LOOP WHILE ')Then Begin Evaluate(Trim(Copy(Rest,12,255)),V);LoopAgain:=Truth(V);End
     Else If StartsWith(Rest,'LOOP UNTIL ')Then Begin Evaluate(Trim(Copy(Rest,12,255)),V);LoopAgain:=Not Truth(V);End;
    End;
    CheckTimeout;
   Until(Not LoopAgain)or Terminated or ExitSubRequested or ExitFunctionRequested or ExitForRequested;
   I:=EndLine;
  End Else
  If StartsWith(S,'WHILE ')Then Begin
   EndLine:=FindBlock(I,'WHILE ','WEND');
   Condition:=Copy(S,7,255);Evaluate(Condition,V);
   While Truth(V)and Not Terminated and Not ExitSubRequested and
     Not ExitForRequested and Not ExitDoRequested and Not ExitFunctionRequested Do Begin
    ExecuteRange(I+1,EndLine-1);
    Evaluate(Condition,V);CheckTimeout;
   End;
   I:=EndLine;
  End
   Else
  If StartsWith(U,'NEXT')Then Begin ScriptError('NEXT sans FOR correspondant.',False);Exit;End
  Else If(U='ELSE')or(U='END IF')or(U='WEND')or StartsWith(U,'LOOP')Then Exit
  Else ExecuteStatementList(S);
  Inc(I);
 End;
End;

Function ListItem(Var Source:String):String;
Var I,Depth:Integer;Quote:Char;InQuote:Boolean;
Begin
 I:=1;Depth:=0;Quote:=#0;InQuote:=False;
 While I<=Length(Source)Do Begin
  If InQuote Then Begin
   If Source[I]=Quote Then Begin
    If(I<Length(Source))and(Source[I+1]=Quote)Then Inc(I)Else InQuote:=False;
   End;
  End Else If Source[I]in['''','"']Then Begin InQuote:=True;Quote:=Source[I];End
  Else If Source[I]='('Then Inc(Depth)
  Else If Source[I]=')'Then Begin If Depth>0Then Dec(Depth);End
  Else If(Source[I]=',')and(Depth=0)Then Begin
   ListItem:=Trim(Copy(Source,1,I-1));Delete(Source,1,I);Exit;
  End;
  Inc(I);
 End;
 ListItem:=Trim(Source);Source:='';
End;

Function SimpleIdentifier(Source:String):Boolean;
Var I:Integer;
Begin
 Source:=Trim(Source);SimpleIdentifier:=False;If Source=''Then Exit;
 If Not(Source[1]in['A'..'Z','a'..'z','_'])Then Exit;
 For I:=2To Length(Source)Do If Not(Source[I]in['A'..'Z','a'..'z','0'..'9','_'])Then Exit;
 SimpleIdentifier:=True;
End;

Procedure CallSub(CallText:String);
Var CallName,ArgumentText,Declaration,DeclarationName,ParameterText:String;
 ParameterName,ArgumentExpression,UpperDeclaration:String;
 I,P,NameEnd:Integer;StartLine,EndLine:LongInt;Binding,NextBinding:PCallBinding;
 Existing:PVariable;ArgumentValue,CopyValue:TValue;ByReference:Boolean;
Begin
 CallText:=Trim(CallText);P:=Pos('(',CallText);
 If P>0Then Begin
  CallName:=Trim(Copy(CallText,1,P-1));ArgumentText:=Copy(CallText,P+1,255);
  If(Length(ArgumentText)>0)and(ArgumentText[Length(ArgumentText)]=')')Then
   Delete(ArgumentText,Length(ArgumentText),1);
 End Else Begin
  P:=Pos(' ',CallText);
  If P>0Then Begin CallName:=Copy(CallText,1,P-1);ArgumentText:=Trim(Copy(CallText,P+1,255));End
  Else Begin CallName:=CallText;ArgumentText:='';End;
 End;
 StartLine:=0;EndLine:=0;ParameterText:='';
 For I:=1To LineCount Do Begin
  Declaration:=Trim(ScriptLineText(I));UpperDeclaration:=Upper(Declaration);
  If StartsWith(Declaration,'PUBLIC SUB ')Then Delete(Declaration,1,7)
  Else If StartsWith(Declaration,'PRIVATE SUB ')Then Delete(Declaration,1,8);
  If StartsWith(Declaration,'SUB ')Then Begin
   Delete(Declaration,1,4);P:=Pos('(',Declaration);NameEnd:=Pos(' ',Declaration);
   If(P=0)or((NameEnd>0)and(NameEnd<P))Then P:=NameEnd;
   If P=0Then DeclarationName:=Trim(Declaration)
   Else DeclarationName:=Trim(Copy(Declaration,1,P-1));
   If Upper(DeclarationName)=Upper(CallName)Then Begin
    StartLine:=I;P:=Pos('(',Declaration);
    If P>0Then Begin ParameterText:=Copy(Declaration,P+1,255);
     If(Length(ParameterText)>0)and(ParameterText[Length(ParameterText)]=')')Then
      Delete(ParameterText,Length(ParameterText),1);End;
    Break;
   End;
  End;
 End;
 If StartLine=0Then Begin
  If Not BatchMode Then WriteLn('Erreur VBScript: procedure introuvable: ',CallName);
  ExitCode:=1;Exit;
 End;
 EndLine:=StartLine+1;
 While(EndLine<=LineCount)and(Upper(Trim(ScriptLineText(EndLine)))<>'END SUB')Do Inc(EndLine);
 Binding:=Nil;
 While ParameterText<>''Do Begin
  ParameterName:=ListItem(ParameterText);ByReference:=True;
  If StartsWith(ParameterName,'BYVAL ')Then Begin Delete(ParameterName,1,6);ByReference:=False;End
  Else If StartsWith(ParameterName,'BYREF ')Then Delete(ParameterName,1,6);
  P:=Pos(' ',ParameterName);If P>0Then ParameterName:=Copy(ParameterName,1,P-1);
  ArgumentExpression:=ListItem(ArgumentText);Evaluate(ArgumentExpression,ArgumentValue);
  New(NextBinding);NextBinding^.Name:=Upper(ParameterName);
  NextBinding^.ActualName:=Upper(Trim(ArgumentExpression));
  NextBinding^.CopyBack:=ByReference and SimpleIdentifier(ArgumentExpression);
  Existing:=FindVariable(ParameterName);NextBinding^.Existed:=Existing<>Nil;
  If Existing<>Nil Then Begin NextBinding^.OldValue:=Existing^.Value;
   NextBinding^.OldKind:=Existing^.ValueKind;End
  Else Begin NextBinding^.OldValue:='';NextBinding^.OldKind:=ValueEmpty;End;
  NextBinding^.Next:=Binding;Binding:=NextBinding;SetVariableValue(ParameterName,ArgumentValue);
 End;
 ExecuteRange(StartLine+1,EndLine-1);ExitSubRequested:=False;
 NextBinding:=Binding;
 While NextBinding<>Nil Do Begin
  If NextBinding^.CopyBack Then Begin GetVariable(NextBinding^.Name,CopyValue);
   SetVariableValue(NextBinding^.ActualName,CopyValue);End;
  NextBinding:=NextBinding^.Next;
 End;
 While Binding<>Nil Do Begin
  NextBinding:=Binding^.Next;
  If Binding^.Existed Then Begin MakeText(Binding^.OldValue,CopyValue);
   CopyValue.ValueKind:=Binding^.OldKind;SetVariableValue(Binding^.Name,CopyValue);End
  Else RemoveVariable(Binding^.Name);
  Dispose(Binding);Binding:=NextBinding;
 End;
End;

Procedure FunctionArgument(Index:Integer;A,B,C,D:TValue;Var V:TValue);
Begin
 Case Index of
  0:V:=A;
  1:V:=B;
  2:V:=C;
  3:V:=D;
 Else MakeText('',V);
 End;
End;

Procedure SaveFunctionBinding(Name:String;Value:TValue;Var Bindings:PCallBinding);
Var Binding:PCallBinding;Existing:PVariable;
Begin
 New(Binding);Binding^.Name:=Upper(Trim(Name));Binding^.ActualName:='';
 Binding^.CopyBack:=False;Existing:=FindVariable(Name);Binding^.Existed:=Existing<>Nil;
 If Existing<>Nil Then Begin Binding^.OldValue:=Existing^.Value;
  Binding^.OldKind:=Existing^.ValueKind;End
 Else Begin Binding^.OldValue:='';Binding^.OldKind:=ValueEmpty;End;
 Binding^.Next:=Bindings;Bindings:=Binding;SetVariableValue(Name,Value);
End;

Procedure RestoreFunctionBindings(Var Bindings:PCallBinding);
Var Binding:PCallBinding;OldValue:TValue;
Begin
 While Bindings<>Nil Do Begin Binding:=Bindings^.Next;
  If Bindings^.Existed Then Begin MakeText(Bindings^.OldValue,OldValue);
   OldValue.ValueKind:=Bindings^.OldKind;SetVariableValue(Bindings^.Name,OldValue);End
  Else RemoveVariable(Bindings^.Name);
  Dispose(Bindings);Bindings:=Binding;
 End;
End;

Procedure CallUserFunction(FunctionName:String;A,B,C,D:TValue;
 ArgumentCount:Integer;Var V:TValue);
Var I,P,ParameterIndex:Integer;StartLine,EndLine:LongInt;
 Declaration,DeclarationName,ParameterText,ParameterName:String;
 SavedExpression:String;SavedPosition:Integer;
 Bindings:PCallBinding;ArgumentValue,EmptyValue:TValue;
Begin
 SavedExpression:=ExprText;SavedPosition:=ExprPos;
 StartLine:=0;EndLine:=0;ParameterText:='';
 For I:=1To LineCount Do Begin
  Declaration:=Trim(ScriptLineText(I));
  If StartsWith(Declaration,'PUBLIC FUNCTION ')Then Delete(Declaration,1,7)
  Else If StartsWith(Declaration,'PRIVATE FUNCTION ')Then Delete(Declaration,1,8);
  If StartsWith(Declaration,'FUNCTION ')Then Begin
   Delete(Declaration,1,9);P:=Pos('(',Declaration);
   If P=0Then DeclarationName:=Trim(Declaration)
   Else DeclarationName:=Trim(Copy(Declaration,1,P-1));
   If Upper(DeclarationName)=Upper(FunctionName)Then Begin
    StartLine:=I;
    If P>0Then Begin ParameterText:=Copy(Declaration,P+1,255);
     If(Length(ParameterText)>0)and(ParameterText[Length(ParameterText)]=')')Then
      Delete(ParameterText,Length(ParameterText),1);End;
    Break;
   End;
  End;
 End;
 If StartLine=0Then Begin MakeText('',V);ExprText:=SavedExpression;ExprPos:=SavedPosition;Exit;End;
 EndLine:=StartLine+1;
 While(EndLine<=LineCount)and(Upper(Trim(ScriptLineText(EndLine)))<>'END FUNCTION')Do Inc(EndLine);
 Bindings:=Nil;MakeText('',EmptyValue);SaveFunctionBinding(FunctionName,EmptyValue,Bindings);
 ParameterIndex:=0;
 While ParameterText<>''Do Begin
  ParameterName:=ListItem(ParameterText);
  If StartsWith(ParameterName,'BYVAL ')Then Delete(ParameterName,1,6)
  Else If StartsWith(ParameterName,'BYREF ')Then Delete(ParameterName,1,6);
  P:=Pos(' ',ParameterName);If P>0Then ParameterName:=Copy(ParameterName,1,P-1);
  If ParameterIndex<ArgumentCount Then FunctionArgument(ParameterIndex,A,B,C,D,ArgumentValue)
  Else MakeText('',ArgumentValue);
  SaveFunctionBinding(ParameterName,ArgumentValue,Bindings);Inc(ParameterIndex);
 End;
 ExecuteRange(StartLine+1,EndLine-1);ExitFunctionRequested:=False;
 GetVariable(FunctionName,V);RestoreFunctionBindings(Bindings);
 ExprText:=SavedExpression;ExprPos:=SavedPosition;
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
 LineCount:=0;ArrayCounter:=0;ScriptArgumentCount:=0;Terminated:=False;
 ExitDoRequested:=False;ExitForRequested:=False;ExitSubRequested:=False;
 ExitFunctionRequested:=False;OnErrorResumeNext:=False;ExitCode:=0;
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
