{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @website(https://www.gladir.com/dev-cools)
  @abstract(Interpreteur autonome PascalScript console)
  @target(Free Pascal 3.2 et Turbo Pascal 7)
}

Program PSCRIPT;

{$M 16384,0,655360}

Uses Dos;

Type
 PLine=^TLine;TLine=Record
  N:LongInt;
  S:String;
  Next,Prev:PLine;
 End;
 PVar=^TVar;TVar=Record
  Name:String[80];
  Text:String;
  Num:Real;
  Numeric:Boolean;
  Next:PVar;
 End;
 TValue=Record
  Text:String;
  Num:Real;
  Numeric:Boolean;
 End;
 PBind=^TBind;TBind=Record
  Name,Actual:String[80];
  Had,ByRef:Boolean;
  Old:TValue;
  Next:PBind;
End;

Var
 FirstLine,LastLine:PLine;LineCount:LongInt;
 Vars:PVar;SourceName:String;
 Args:Array[0..127]of String;
 ArgCount:Integer;Expr:String;EP:Integer;
 StopRoutine,RuntimeError:Boolean;
 ExitCode:Integer;

Function Up(S:String):String;
Var
 I:Integer;
Begin
  For I:=1To Length(S)Do If S[I]in['a'..'z']Then S[I]:=Chr(Ord(S[I])-32);Up:=S;
End;

Function TrimS(S:String):String;Begin
 While(Length(S)>0)and(S[1]in[' ',#9])Do Delete(S,1,1);
 While(Length(S)>0)and(S[Length(S)]in[' ',#9,#13,#10])Do Delete(S,Length(S),1);
 TrimS:=S;
End;

Function Starts(S,P:String):Boolean;Begin
 Starts:=Copy(Up(TrimS(S)),1,Length(P))=Up(P);
End;

Function Clean(S:String):String;Begin
 S:=TrimS(S);
 If(Length(S)>0)and(S[Length(S)]=';')Then Delete(S,Length(S),1);
 Clean:=TrimS(S);
End;

Procedure AddLine(S:String);
Var
 P:PLine;
Begin
 New(P);
 Inc(LineCount);
 P^.N:=LineCount;
 P^.S:=S;P^.Next:=Nil;
 P^.Prev:=LastLine;
 If LastLine=Nil Then FirstLine:=P
                 Else LastLine^.Next:=P;LastLine:=P;
End;

Function LS(N:LongInt):String;
Var
 P:PLine;
Begin
 If N<1Then Begin
  LS:='';
  Exit;
 End;
 If N<=LineCount div 2Then Begin
  P:=FirstLine;
  While(P<>Nil)and(P^.N<N)Do P:=P^.Next;
 End
  Else
 Begin
  P:=LastLine;
  While(P<>Nil)and(P^.N>N)Do P:=P^.Prev;
 End;
 If P=Nil Then LS:=''Else LS:=P^.S;
End;

Procedure VText(S:String;Var V:TValue);
Var
 C:Integer;N:Real;
Begin
 V.Text:=S;Val(S,N,C);
 V.Numeric:=(C=0)and(S<>'');
 If V.Numeric Then V.Num:=N
              Else V.Num:=0;
End;

Procedure VNum(N:Real;Var V:TValue);
Var
 S:String;
Begin
 Str(N:0:8,S);
 While(Length(S)>0)and(S[Length(S)]='0')Do Delete(S,Length(S),1);
 If(Length(S)>0)and(S[Length(S)]='.')Then Delete(S,Length(S),1);
 If S='-0'Then S:='0';
 V.Text:=S;
 V.Num:=N;
 V.Numeric:=True;
End;

Function FindVar(N:String):PVar;
Var
 P:PVar;
Begin
 N:=Up(TrimS(N));P:=Vars;
 While P<>Nil Do Begin
  If P^.Name=N Then Begin
   FindVar:=P;
   Exit;
  End;
  P:=P^.Next;
 End;
 FindVar:=Nil;
End;

Procedure GetV(N:String;Var V:TValue);
Var
 P:PVar;
Begin
 P:=FindVar(N);
 If P=Nil Then VText(Up(N),V)
  Else
 Begin
  V.Text:=P^.Text;
  V.Num:=P^.Num;
  V.Numeric:=P^.Numeric;
 End;
End;

Procedure SetV(N:String;V:TValue);
Var
 P:PVar;
Begin
 N:=Up(TrimS(N));
 P:=FindVar(N);
 If P=Nil Then Begin
  New(P);P^.Name:=N;
  P^.Next:=Vars;
  Vars:=P;
 End;
 P^.Text:=V.Text;
 P^.Num:=V.Num;
 P^.Numeric:=V.Numeric;
End;

Procedure DelV(N:String);
Var
 P,Q:PVar;
Begin
 N:=Up(N);
 P:=Vars;
 Q:=Nil;
 While P<>Nil Do Begin
  If P^.Name=N Then Begin
   If Q=Nil Then Vars:=P^.Next
            Else Q^.Next:=P^.Next;
   Dispose(P);
   Exit;
  End;
  Q:=P;
  P:=P^.Next;
 End;
End;

Function Truth(V:TValue):Boolean;Begin
 Truth:=Not((V.Text='')or(V.Text='0')or(Up(V.Text)='FALSE'));
End;

Procedure Skip;Begin
 While(EP<=Length(Expr))and(Expr[EP]in[' ',#9])Do Inc(EP);
End;

Function Word:String;
Var
 S:String;
Begin
 Skip;
 S:='';
 While(EP<=Length(Expr))and(Expr[EP]in['A'..'Z','a'..'z','0'..'9','_','.'])Do Begin
  S:=S+Expr[EP];
  Inc(EP);
 End;
 Word:=S;
End;

Procedure EvalE(Var V:TValue);Forward;
Procedure EvalText(S:String;Var V:TValue);Forward;
Procedure CallRoutine(Name,ArgText:String;WantResult:Boolean;Var V:TValue);Forward;

Procedure Primary(Var V:TValue);
Var
 Q:Char;
 S,Nm,U,Idx:String;
 N:Real;
 C,I,Start:Integer;
 A,B,D:TValue;
Begin
 Skip;
 If EP>Length(Expr)Then Begin
  VText('',V);
  Exit;
 End;
 If Expr[EP]=''''Then Begin
  Q:='''';
  Inc(EP);
  S:='';
  While EP<=Length(Expr)Do Begin
   If Expr[EP]=Q Then Begin
    If(EP<Length(Expr))and(Expr[EP+1]=Q)Then Begin
     S:=S+Q;Inc(EP,2);
    End
     Else
    Begin
     Inc(EP);
     Break;
    End;
   End
    Else
   Begin
    S:=S+Expr[EP];
    Inc(EP);
   End;
  End;
  VText(S,V);
  Exit;
 End;
 If Expr[EP]='('Then Begin
  Inc(EP);
  EvalE(V);Skip;
  If(EP<=Length(Expr))and(Expr[EP]=')')Then Inc(EP);
  Exit;
 End;
 If Expr[EP]in['0'..'9']Then Begin
  S:='';
  While(EP<=Length(Expr))and(Expr[EP]in['0'..'9','.'])Do Begin
   S:=S+Expr[EP];Inc(EP);
  End;
  Val(S,N,C);
  If C=0 Then VNum(N,V)
         Else VText(S,V);
  Exit;
 End;
 Nm:=Word;
 U:=Up(Nm);
 If U='TRUE'Then Begin
  VText('True',V);
  V.Num:=-1;
  Exit;
 End;
 If U='FALSE'Then Begin
  VText('False',V);
  V.Num:=0;
  Exit;
 End;
 Skip;
 If(EP<=Length(Expr))and(Expr[EP]='[')Then Begin
  Inc(EP);
  Start:=EP;
  EvalE(A);
  Skip;
  If(EP<=Length(Expr))and(Expr[EP]=']')Then Inc(EP);
  Str(Trunc(A.Num),Idx);GetV(Nm+'['+TrimS(Idx)+']',V);
  Exit;
 End;
 If(EP<=Length(Expr))and(Expr[EP]='(')Then Begin
  Inc(EP);Start:=EP;I:=0;Q:=#0;
  While EP<=Length(Expr)Do Begin
   If Q<>#0Then Begin
    If Expr[EP]=Q Then Q:=#0;
   End
    Else
   If Expr[EP]=''''Then Q:='''' Else
   If Expr[EP]='('Then Inc(I)Else
   If Expr[EP]=')'Then Begin
    If I=0 Then Break
           Else Dec(I);
   End;
   Inc(EP);
  End;
  S:=Copy(Expr,Start,EP-Start);
  If(EP<=Length(Expr))and(Expr[EP]=')')Then Inc(EP);
  If U='INTTOSTR'Then Begin
   EvalText(S,A);
   VText(A.Text,V);
   Exit;
  End;
  If U='FLOATTOSTR'Then Begin
   EvalText(S,A);
   VText(A.Text,V);
   Exit;
  End;
  If U='VARTOSTR'Then Begin
   EvalText(S,A);
   VText(A.Text,V);
   Exit;
  End;
  If U='LENGTH'Then Begin
   EvalText(S,A);
   GetV(A.Text+'$HIGH',B);
   If B.Numeric Then VNum(B.Num+1,V)
                Else VNum(Length(A.Text),V);
   Exit;
  End;
  If U='LOW'Then Begin
   EvalText(S,A);
   GetV(A.Text+'$LOW',V);
   If Not V.Numeric Then VNum(0,V);
   Exit;
  End;
  If U='HIGH'Then Begin
   EvalText(S,A);
   GetV(A.Text+'$HIGH',V);
   Exit;
  End;
  If U='UPPERCASE'Then Begin
   EvalText(S,A);
   VText(Up(A.Text),V);
   Exit;
  End;
  If U='LOWERCASE'Then Begin
   EvalText(S,A);
   For I:=1To Length(A.Text)Do If A.Text[I]in['A'..'Z']Then A.Text[I]:=Chr(Ord(A.Text[I])+32);
   VText(A.Text,V);
   Exit;
  End;
  If U='COPY'Then Begin
   I:=Pos(',',S);
   EvalText(Copy(S,1,I-1),A);
   Delete(S,1,I);
   I:=Pos(',',S);
   EvalText(Copy(S,1,I-1),B);
   EvalText(Copy(S,I+1,255),D);
   VText(Copy(A.Text,Trunc(B.Num),Trunc(D.Num)),V);
   Exit;
  End;
  If U='POS'Then Begin
   I:=Pos(',',S);
   EvalText(Copy(S,1,I-1),A);
   EvalText(Copy(S,I+1,255),B);
   VNum(Pos(A.Text,B.Text),V);
   Exit;
  End;
  If U='WSCRIPT.ARGUMENTS.ITEM'Then Begin
   EvalText(S,A);
   I:=Trunc(A.Num);
   If(I>=0)and(I<ArgCount)Then VText(Args[I],V)
                          Else VText('',V);
   Exit;
  End;
  CallRoutine(Nm,S,True,V);
  Exit;
 End;
 If U='WSCRIPT.SCRIPTNAME'Then VText(SourceName,V) Else
 If U='WSCRIPT.FULLNAME'Then VText(ParamStr(0),V) Else
 If U='WSCRIPT.ARGUMENTS.COUNT'Then VNum(ArgCount,V)
                               Else GetV(Nm,V);
End;

Procedure Unary(Var V:TValue);Begin
 Skip;
 If(EP<=Length(Expr))and(Expr[EP]='-')Then Begin
  Inc(EP);
  Unary(V);
  VNum(-V.Num,V);
 End
  Else
 Primary(V);
End;

Procedure Mul(Var V:TValue);
Var
 R:TValue;O:String;
Begin
 Unary(V);
 While True Do Begin
  Skip;O:='';
  If Copy(Up(Expr),EP,3)='DIV'Then Begin
   O:='D';
   Inc(EP,3);
  End
   Else
  If Copy(Up(Expr),EP,3)='MOD'Then Begin
   O:='M';
   Inc(EP,3);
  End
   Else
  If(EP<=Length(Expr))and(Expr[EP]in['*','/'])Then Begin
   O:=Expr[EP];
   Inc(EP);
  End;
  If O=''Then Exit;
  Unary(R);
  If(O='/')or(O='D')or(O='M')Then If R.Num=0Then Begin
   RuntimeError:=True;VNum(0,V);
   Exit;
  End;
  If O='*'Then VNum(V.Num*R.Num,V)Else
  If O='/'Then VNum(V.Num/R.Num,V)Else
  If O='D'Then VNum(Trunc(V.Num)div Trunc(R.Num),V)
          Else VNum(Trunc(V.Num)mod Trunc(R.Num),V);
 End;
End;

Procedure Add(Var V:TValue);
Var
 R:TValue;
 O:Char;
Begin
 Mul(V);
 While True Do Begin
  Skip;
  If(EP>Length(Expr))or Not(Expr[EP]in['+','-'])Then Exit;O:=Expr[EP];Inc(EP);Mul(R);
  If O='-'Then VNum(V.Num-R.Num,V)Else
  If V.Numeric and R.Numeric Then VNum(V.Num+R.Num,V)
                    Else VText(V.Text+R.Text,V);
 End;
End;

Procedure EvalE(Var V:TValue);
Var
 R:TValue;
 O,T:String;
 B:Boolean;
Begin
 Add(V);
 Skip;
 O:='';
 T:=Copy(Expr,EP,2);
 If(T='>=')or(T='<=')or(T='<>')Then Begin
  O:=T;
  Inc(EP,2);
 End
  Else
 If(EP<=Length(Expr))and(Expr[EP]in['=','<','>'])Then Begin
  O:=Expr[EP];
  Inc(EP);
 End;
 If O<>''Then Begin
  Add(R);
  If V.Numeric and R.Numeric Then Begin
   If O='='Then B:=V.Num=R.Num Else
   If O='<>'Then B:=V.Num<>R.Num Else
   If O='<'Then B:=V.Num<R.Num Else
   If O='>'Then B:=V.Num>R.Num Else
   If O='<='Then B:=V.Num<=R.Num Else B:=V.Num>=R.Num;
  End
   Else
  Begin
   If O='='Then B:=Up(V.Text)=Up(R.Text)Else
   If O='<>'Then B:=Up(V.Text)<>Up(R.Text)Else
   If O='<'Then B:=V.Text<R.Text Else
   If O='>'Then B:=V.Text>R.Text Else
   If O='<='Then B:=V.Text<=R.Text
            Else B:=V.Text>=R.Text;
  End;
  If B Then VText('True',V)
       Else VText('False',V);
 End;
End;

Procedure EvalText(S:String;Var V:TValue);
Var
 SaveE:String;
 SaveP:Integer;
Begin
 SaveE:=Expr;
 SaveP:=EP;
 Expr:=TrimS(S);
 EP:=1;EvalE(V);
 Expr:=SaveE;
 EP:=SaveP;
End;

Function MatchEnd(B:LongInt):LongInt;
Var
 I:LongInt;
 D:Integer;
 S:String;
Begin
 D:=1;
 For I:=B+1 To LineCount Do Begin
  S:=Up(Clean(LS(I)));
  If S='BEGIN'Then Inc(D)Else
  If Starts(S,'CASE ')or(S='TRY')Then Inc(D)Else
  If(S='END')or(S='END.')Then Dec(D);
  If D=0 Then Begin
   MatchEnd:=I;
   Exit;
  End;
 End;
 MatchEnd:=LineCount;
End;

Procedure ExecRange(A,B:LongInt);Forward;

Function BodyEnd(Control:LongInt;Var BS,BE:LongInt):LongInt;
Var
 N:LongInt;
Begin
 N:=Control+1;
 While(N<=LineCount)and(Clean(LS(N))='')Do Inc(N);If Up(Clean(LS(N)))='BEGIN'Then Begin
  BS:=N+1;
  BE:=MatchEnd(N)-1;
  BodyEnd:=BE+1;
 End
  Else
 Begin
  BS:=N;BE:=N;BodyEnd:=N;
 End;
End;

Procedure SaveBind(N,Actual:String;ByR:Boolean;V:TValue;Var H:PBind);
Var
 P:PBind;
 X:PVar;
Begin
 New(P);P^.Name:=Up(N);P^.Actual:=Up(Actual);P^.ByRef:=ByR;X:=FindVar(N);P^.Had:=X<>Nil;
 If X<>Nil Then Begin
  P^.Old.Text:=X^.Text;P^.Old.Num:=X^.Num;P^.Old.Numeric:=X^.Numeric;
 End;
 P^.Next:=H;H:=P;SetV(N,V);
End;

Procedure Restore(Var H:PBind);
Var
 P:PBind;V:TValue;
Begin
 While H<>Nil Do Begin
  P:=H^.Next;
  GetV(H^.Name,V);
  If H^.ByRef and(H^.Actual<>'')Then SetV(H^.Actual,V);
  If H^.Had Then SetV(H^.Name,H^.Old)
            Else DelV(H^.Name);
  Dispose(H);
  H:=P;
 End;
End;

Function NextItem(Var S:String;Sep:Char):String;
Var
 I,D:Integer;
 Q:Char;
Begin
 I:=1;D:=0;Q:=#0;
 While I<=Length(S)Do Begin
  If Q<>#0Then Begin
   If S[I]=Q Then Q:=#0;
  End
   Else
  If S[I]=''''Then Q:='''' Else
  If S[I]='('Then Inc(D)Else
  If S[I]=')'Then Dec(D)Else
  If(S[I]=Sep)and(D=0)Then Begin
   NextItem:=TrimS(Copy(S,1,I-1));
   Delete(S,1,I);Exit;
  End;
  Inc(I);
 End;
 NextItem:=TrimS(S);
 S:='';
End;

Procedure CallRoutine(Name,ArgText:String;WantResult:Boolean;Var V:TValue);
Var
 I,P,BS,BE:LongInt;
 S,U,DN,Params,One,PN,AE:String;
 IsFunc,ByR:Boolean;
 H:PBind;
 AV,Empty:
 TValue;
 Found:Boolean;
Begin
 Found:=False;IsFunc:=False;BS:=0;
 For I:=1 To LineCount Do Begin
  S:=Clean(LS(I));U:=Up(S);
  If Starts(U,'PROCEDURE ')or Starts(U,'FUNCTION ')Then Begin
   IsFunc:=Starts(U,'FUNCTION ');
   If IsFunc Then Delete(S,1,9)
             Else Delete(S,1,10);
   P:=Pos('(',S);
   If P=0 Then DN:=TrimS(S)
          Else DN:=TrimS(Copy(S,1,P-1));
   If Up(DN)=Up(Name)Then Begin
    Found:=True;
    If P>0Then Begin
     Params:=Copy(S,P+1,255);
     P:=Pos(')',Params);
     If P>0Then Params:=Copy(Params,1,P-1);
    End
     Else
    Params:='';BS:=I+1;
    While Up(Clean(LS(BS)))<>'BEGIN'Do Inc(BS);
    BE:=MatchEnd(BS);
    Break;
    End;
  End;
 End;
 If Not Found Then Begin
  VText('',V);
  RuntimeError:=True;
  Exit;
 End;
 H:=Nil;
 VText('',Empty);
 If IsFunc Then SaveBind('RESULT','',False,Empty,H);
 While Params<>''Do Begin
  One:=NextItem(Params,';');
  ByR:=Starts(One,'VAR ');
  If ByR Then Delete(One,1,4)Else
  If Starts(One,'CONST ')Then Delete(One,1,6);
  P:=Pos(':',One);
  If P>0Then One:=Copy(One,1,P-1);While One<>''Do Begin
   PN:=NextItem(One,',');
   AE:=NextItem(ArgText,',');
   EvalText(AE,AV);
   SaveBind(PN,AE,ByR,AV,H);
  End;
 End;
 StopRoutine:=False;
 ExecRange(BS+1,BE-1);
 StopRoutine:=False;
 If WantResult Then GetV('RESULT',V);Restore(H);
End;

Procedure AssignStmt(S:String);
Var
 P,I:Integer;
 N,E,Idx:String;
 V,X:TValue;
Begin
 P:=Pos(':=',S);
 If P=0Then Exit;
 N:=TrimS(Copy(S,1,P-1));
 E:=Copy(S,P+2,255);
 EvalText(E,V);
 I:=Pos('[',N);
 If(I>0)and(N[Length(N)]=']')Then Begin
  EvalText(Copy(N,I+1,Length(N)-I-1),X);
  Str(Trunc(X.Num),Idx);N:=Copy(N,1,I-1)+'['+TrimS(Idx)+']';
 End;
 SetV(N,V);
End;

Procedure ExecSimple(S:String);
Var
 P,I:Integer;
 N,A:String;
 V,X:TValue;
Begin
 S:=Clean(S);
 If S=''Then Exit;
 If Up(S)='EXIT'Then Begin
  StopRoutine:=True;
  Exit;
 End;
 If Starts(S,'WSCRIPT.ECHO(')Then Begin
  A:=Copy(S,14,Length(S)-14);
  If(Length(A)>0)and(A[Length(A)]=')')Then Delete(A,Length(A),1);
  EvalText(A,V);WriteLn(V.Text);
  Exit;
 End;
 If Starts(S,'SETLENGTH(')Then Begin
  A:=Copy(S,11,Length(S)-11);
  If A[Length(A)]=')'Then Delete(A,Length(A),1);
  P:=Pos(',',A);
  N:=TrimS(Copy(A,1,P-1));
  EvalText(Copy(A,P+1,255),V);
  VNum(0,X);
  SetV(N+'$LOW',X);
  VNum(Trunc(V.Num)-1,X);
  SetV(N+'$HIGH',X);
  Exit;
 End;
 If Pos(':=',S)>0Then Begin
  AssignStmt(S);
  Exit;
 End;
 P:=Pos('(',S);If P>0Then Begin
  N:=TrimS(Copy(S,1,P-1));
  A:=Copy(S,P+1,255);
  If A[Length(A)]=')'Then Delete(A,Length(A),1);
  CallRoutine(N,A,False,V);
  Exit;
 End;
 CallRoutine(S,'',False,V);
End;

Procedure ExecIf(L,Limit:LongInt;Var Used:LongInt);
Var
 S,C:String;
 P:Integer;
 V:TValue;
 BS,BE,N,Cur,Last:LongInt;
 Taken:Boolean;
Begin
 Cur:=L;Taken:=False;Last:=L;
 While Cur<=Limit Do Begin
  S:=Clean(LS(Cur));If Starts(S,'ELSE IF ')Then Delete(S,1,5);Delete(S,1,3);
  P:=Pos(' THEN',Up(S));C:=Copy(S,1,P-1);EvalText(C,V);
  Last:=BodyEnd(Cur,BS,BE);If(Not Taken)and Truth(V)Then Begin ExecRange(BS,BE);Taken:=True;End;
  N:=Last+1;While(N<=Limit)and(Clean(LS(N))='')Do Inc(N);
  If Starts(Clean(LS(N)),'ELSE IF ')Then Cur:=N
  Else Begin
   If Up(Clean(LS(N)))='ELSE'Then Begin Last:=BodyEnd(N,BS,BE);If Not Taken Then ExecRange(BS,BE);End;
   Used:=Last;Exit;
  End;
 End;
 Used:=Last;
End;

Procedure ExecRange(A,B:LongInt);
Var
 I,J,BS,BE,After,P,K:LongInt;
 S,U,C,Nm,Rest,Item:String;
 V,SV,EV,Step:TValue;Down,Chosen:Boolean;
Begin
 I:=A;
 While(I<=B)and Not StopRoutine and Not RuntimeError Do Begin
  S:=Clean(LS(I));
  U:=Up(S);
  If(S='')or(S[1]='{')or(U='BEGIN')or(U='END')Then Begin
   Inc(I);
   Continue;
  End;
  If Starts(U,'PROCEDURE ')or Starts(U,'FUNCTION ')Then Begin
   J:=I+1;
   While Up(Clean(LS(J)))<>'BEGIN'Do Inc(J);
   I:=MatchEnd(J)+1;
   Continue;
  End;
 If Starts(U,'IF ')Then Begin ExecIf(I,B,J);I:=J+1;Continue;End;
 If Starts(U,'FOR ')Then Begin
  Rest:=Copy(S,5,255);
  P:=Pos(':=',Rest);
  Nm:=TrimS(Copy(Rest,1,P-1));
  Delete(Rest,1,P+1);
  Down:=Pos(' DOWNTO ',Up(Rest))>0;
  If Down Then P:=Pos(' DOWNTO ',Up(Rest))
          Else P:=Pos(' TO ',Up(Rest));
  EvalText(Copy(Rest,1,P-1),SV);
  If Down Then Delete(Rest,1,P+7)
          Else Delete(Rest,1,P+3);
  P:=Pos(' DO',Up(Rest));
  EvalText(Copy(Rest,1,P-1),EV);
  After:=BodyEnd(I,BS,BE);
  If Down Then VNum(-1,Step)
          Else VNum(1,Step);
  V:=SV;
  While((Not Down)and(V.Num<=EV.Num))or(Down and(V.Num>=EV.Num))Do Begin
   SetV(Nm,V);
   ExecRange(BS,BE);
   VNum(V.Num+Step.Num,V);
  End;
  I:=After+1;
  Continue;
 End;
 If Starts(U,'WHILE ')Then Begin
  P:=Pos(' DO',U);
  C:=Copy(S,7,P-7);
  After:=BodyEnd(I,BS,BE);
  EvalText(C,V);
  While Truth(V)Do Begin
   ExecRange(BS,BE);
   EvalText(C,V);
  End;
  I:=After+1;
  Continue;
 End;
 If U='REPEAT'Then Begin
  J:=I+1;
  While Not Starts(Clean(LS(J)),'UNTIL ')Do Inc(J);
  C:=Copy(Clean(LS(J)),7,255);
  Repeat
   ExecRange(I+1,J-1);
   EvalText(C,V);
  Until Truth(V);I:=J+1;
  Continue;
 End;
 If Starts(U,'CASE ')Then Begin
  P:=Pos(' OF',U);
  EvalText(Copy(S,6,P-6),V);
  J:=I+1;
  Chosen:=False;
  While(J<=B)and(Up(Clean(LS(J)))<>'END')Do Begin
   Rest:=Clean(LS(J));
   If Up(Rest)='ELSE'Then Begin
    If Not Chosen Then Begin
     Inc(J);
     ExecSimple(LS(J));
     Chosen:=True;
    End;
   End
    Else
   Begin
    P:=Pos(':',Rest);
    If(P>0)and Not Chosen Then Begin
     C:=Copy(Rest,1,P-1);
     While C<>''Do Begin
      Item:=NextItem(C,',');
      EvalText(Item,SV);
      If(V.Numeric and SV.Numeric and(SV.Num=V.Num))or
        ((Not V.Numeric or Not SV.Numeric)and
        (Up(SV.Text)=Up(V.Text)))Then Chosen:=True;
     End;
     If Chosen Then ExecSimple(Copy(Rest,P+1,255));
    End;
   End;
   Inc(J);
   End;
   I:=J+1;
   Continue;
  End;
  If U='TRY'Then Begin
   J:=I+1;
   While Up(Clean(LS(J)))<>'EXCEPT'Do Inc(J);
   K:=J+1;
   While Up(Clean(LS(K)))<>'END'Do Inc(K);
   RuntimeError:=False;
   ExecRange(I+1,J-1);
   If RuntimeError Then Begin
    RuntimeError:=False;
    ExecRange(J+1,K-1);
   End;
   I:=K+1;
   Continue;
  End;
  If(U='VAR')or(U='TYPE')or Starts(U,'ARRAY')or((Pos(':',S)>0)and
    (Pos(':=',S)=0)and(Pos('(',S)=0))Then Begin
   Inc(I);
   Continue;
  End;
  ExecSimple(S);Inc(I);
 End;
End;

Function MainBegin:LongInt;
Var
 I,J:LongInt;
 S:String;
Begin
 I:=1;
 While I<=LineCount Do Begin
  S:=Up(Clean(LS(I)));
  If Starts(S,'PROCEDURE ')or Starts(S,'FUNCTION ')Then Begin
   J:=I+1;
   While Up(Clean(LS(J)))<>'BEGIN'Do Inc(J);
   I:=MatchEnd(J)+1;
  End
   Else
  If S='BEGIN'Then Begin
   MainBegin:=I;
   Exit;
  End
   Else
  Inc(I);
 End;
 MainBegin:=0;
End;

Procedure Load;
Var
 F:Text;
 S:String;
 C:Integer;
Begin
 {$I-}Assign(F,SourceName);
 Reset(F);{$I+}
 C:=IoResult;
 If C<>0Then Begin
  WriteLn('PSCRIPT: fichier introuvable: ',SourceName);
  Halt(1);
 End;
 While Not Eof(F)Do Begin
  ReadLn(F,S);
  AddLine(S);
 End;
 Close(F);
End;

Procedure InitDeclarations;
Var
 I,P,Q,R,C:Integer;
 S,N,L,H:String;
 X:Real;
 V:TValue;
Begin
 For I:=1 To LineCount Do Begin
  S:=Clean(LS(I));
  P:=Pos(':',S);
  Q:=Pos('ARRAY[',Up(S));
  If(P>0)and(Q>P)Then Begin
   N:=TrimS(Copy(S,1,P-1));
   R:=Pos('..',S);
   If R>Q Then Begin
    L:=TrimS(Copy(S,Q+6,R-Q-6));Q:=Pos(']',S);
    H:=TrimS(Copy(S,R+2,Q-R-2));Val(L,X,C);
    If C=0Then Begin
     VNum(X,V);
     SetV(N+'$LOW',V);
    End;
    Val(H,X,C);
    If C=0Then Begin
     VNum(X,V);
     SetV(N+'$HIGH',V);
    End;
   End;
  End;
 End;
End;

Procedure Usage;Begin
 WriteLn('PSCRIPT - Interpreteur PascalScript console');
 WriteLn('Syntaxe: PSCRIPT script.psc [arguments]');
End;

Var
 M:LongInt;
 I:Integer;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('PSCRIPT : Cette commande permet de lancer l''interpreteur ',
                     'de PascalScript.');
  WriteLn;
  WriteLn('Syntaxe : PSCRIPT script.psc [arguments]');
  WriteLn;
  WriteLn(' script.psc  Ce paramätre permet d''indiquer le fichier PascalScript');
  Halt;
 End;
 FirstLine:=Nil;
 LastLine:=Nil;
 Vars:=Nil;
 LineCount:=0;
 ArgCount:=0;
 StopRoutine:=False;
 RuntimeError:=False;
 ExitCode:=0;
 If ParamCount<1Then Begin
  Usage;
  Halt(1);
 End;
 SourceName:=ParamStr(1);
 For I:=2 To ParamCount Do If ArgCount<128 Then Begin
  Args[ArgCount]:=ParamStr(I);Inc(ArgCount);
 End;
 Load;
 InitDeclarations;
 M:=MainBegin;
 If M=0Then Begin
  WriteLn('PSCRIPT: bloc principal BEGIN introuvable.');
  Halt(1);
 End;
 ExecRange(M+1,MatchEnd(M)-1);
 If RuntimeError Then Begin
  WriteLn('PSCRIPT: erreur d''execution.');
  ExitCode:=1;
 End;
 Halt(ExitCode);
END.
