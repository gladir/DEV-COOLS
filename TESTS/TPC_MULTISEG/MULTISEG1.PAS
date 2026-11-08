Program MULTISEG1;
Uses Dos;
Type
 TRec=Record A:Integer; B:Byte; S:String[12]; R:Real; L:LongInt End;
 PRec=^TRec;
 TArr=Array[1..10] Of Integer;
 TSet=Set Of Byte;
Const
 Names:Array[1..3] Of String[6]=('un','deux','trois');
 Primes:Array[1..5] Of Word=(2,3,5,7,11);
Var
 G,GI:Integer;
 GL:LongInt;
 GR:Real;
 GS:String;
 Rec:TRec;
 P:PRec;
 Arr:TArr;
 St:TSet;
 F:File Of Integer;
 T:Text;
 Ptr:Pointer;
 Hits:Integer; GW:Word;

Procedure Trace(S:String);
Begin
 WriteLn('[',S,']');
End;

Function Fib(N:Integer):LongInt;
Begin
 If N<2 Then Fib:=N Else Fib:=Fib(N-1)+Fib(N-2);
End;

Function Sq(X:Real):Real;
Begin
 Sq:=X*X;
End;

Function Cat(A,B:String):String;
Begin
 Cat:=A+'-'+B;
End;

Function IsOdd(N:Integer):Boolean; Forward;
Function IsEven(N:Integer):Boolean;
Begin
 If N=0 Then IsEven:=True Else IsEven:=IsOdd(N-1);
End;
Function IsOdd(N:Integer):Boolean;
Begin
 If N=0 Then IsOdd:=False Else IsOdd:=IsEven(N-1);
End;

Procedure Swap(Var A,B:Integer);
Var T:Integer;
Begin
 T:=A; A:=B; B:=T;
End;

Procedure FillArr(Var A:TArr; V:Integer);
Var I:Integer;
Begin
 For I:=1 To 10 Do A[I]:=V*I;
End;

Function SumArr(Const A:TArr):LongInt;
Var I:Integer; S:LongInt;
Begin
 S:=0; For I:=1 To 10 Do S:=S+A[I]; SumArr:=S;
End;

Procedure NestA(N:Integer);
Var Local:Integer;
 Procedure NestB(M:Integer);
 Var Q:Integer;
  Procedure NestC;
  Begin
   Inc(Local,N+M+Q); Write('C',Local,' ');
  End;
 Begin
  Q:=M*2; NestC; NestC;
 End;
Begin
 Local:=100; NestB(1); NestB(2); WriteLn;
End;

Function Add3(A:Byte;B:Word;C:LongInt):LongInt;
Begin
 Add3:=A+B+C;
End;

Function Cmp(A,B:Char):ShortInt;
Begin
 If A<B Then Cmp:=-1 Else If A>B Then Cmp:=1 Else Cmp:=0;
End;

Procedure ByAsm(Var X:Word); Assembler;
ASM
 LES DI,X
 MOV AX,ES:[DI]
 ADD AX,5
 MOV ES:[DI],AX
End;

Function AsmFn(A:Word):Word; Assembler;
ASM
 MOV AX,A
 SHL AX,1
End;

Procedure Hit; Far;
Begin
 Inc(Hits);
End;

Procedure CallThrough(P:Pointer);
Begin
 { appel d'une routine par pointeur far }
 ASM
  CALL DWORD PTR P
 End;
End;

Procedure Handler; Interrupt;
Begin
 Inc(Hits,10);
End;

Procedure UseFiles;
Var I,V:Integer;
Begin
 Assign(F,'MS1.DAT'); Rewrite(F);
 For I:=1 To 5 Do Begin V:=I*I; Write(F,V) End;
 Close(F);
 Reset(F);
 Seek(F,2); Read(F,V); WriteLn('rec3=',V,' taille=',FileSize(F));
 Close(F);
 Assign(T,'MS1.TXT'); Rewrite(T);
 WriteLn(T,'ligne un'); WriteLn(T,'ligne ',2,' ',3.5:0:1);
 Close(T);
 Reset(T);
 While Not Eof(T) Do Begin ReadLn(T,GS); WriteLn('lu: ',GS) End;
 Close(T);
 Erase(T); Erase(F);
End;

Procedure Heap;
Var Q:PRec; I:Integer;
Begin
 New(P); P^.A:=77; P^.S:='heap'; P^.R:=1.5;
 For I:=1 To 3 Do Begin New(Q); Q^.A:=I; Dispose(Q) End;
 WriteLn(P^.A,' ',P^.S,' ',P^.R:0:1);
 Dispose(P);
End;

Procedure CaseTest(N:Integer);
Begin
 Case N Of
  1:Write('un ');
  2,3:Write('deux-trois ');
  4..9:Write('quatre-neuf ');
 Else Write('autre ');
 End;
End;

Procedure RealTest;
Var X,Y:Real;
Begin
 X:=2.5; Y:=Sq(X)+Sqrt(16.0);
 WriteLn(Y:0:3,' ',Trunc(Y),' ',Round(Y),' ',Int(3.7):0:1);
 WriteLn(Sin(0.0):0:2,' ',Exp(0.0):0:2,' ',Ln(1.0):0:2);
End;

Procedure StringTest;
Var S:String; I:Integer;
Begin
 S:=Cat('ab','cd'); WriteLn(S,' ',Length(S),' ',Pos('c',S),' ',Copy(S,2,3),' ',UpCase(S[1]));
 Insert('XY',S,3); WriteLn(S); Delete(S,1,2); WriteLn(S);
 Str(12345,S); WriteLn(S); Val('789',I,G); WriteLn(I,' ',G);
 WriteLn(Names[2],' ',Names[3]:8,' ',Primes[5]);
End;

Procedure ErrHalt(N:Integer);
Begin
 If N=3 Then Begin WriteLn('halt 3'); Halt(3) End;
 If N=4 Then RunError(150);
 If N=5 Then Begin G:=0; G:=10 Div G End;
End;

Begin
 WriteLn('MULTISEG1');
 Trace('fib'); WriteLn(Fib(15));
 Trace('real'); RealTest;
 Trace('str'); StringTest;
 Trace('par'); G:=1; GI:=2; Swap(G,GI); WriteLn(G,GI);
 FillArr(Arr,3); WriteLn(SumArr(Arr));
 Trace('odd'); WriteLn(IsEven(10),IsOdd(7),IsEven(7));
 Trace('nest'); NestA(1);
 Trace('args'); WriteLn(Add3(200,60000,100000), Cmp('a','b'), Cmp('b','a'));
 Trace('asm'); GW:=10; ByAsm(GW); WriteLn(GW, ' ', AsmFn(21));
 Trace('ptr'); Hits:=0; CallThrough(@Hit); CallThrough(@Hit); WriteLn(Hits);
 Trace('case'); For G:=0 To 10 Do CaseTest(G); WriteLn;
 Trace('files'); UseFiles;
 Trace('heap'); Heap;
 Trace('set'); St:=[1,5,9]; Include(St,200); WriteLn(Ord(5 In St),Ord(6 In St),Ord(200 In St));
 Trace('env'); WriteLn(ParamCount, '/', ParamStr(1));
 Trace('rec'); Rec.A:=-5; Rec.B:=200; Rec.S:='champ'; Rec.R:=-0.125; Rec.L:=-70000;
 WriteLn(Rec.A,' ',Rec.B,' ',Rec.S,' ',Rec.R:0:3,' ',Rec.L);
 Trace('int'); SetIntVec($60,@Handler); Hits:=0; Inline($CD/$60); WriteLn(Hits);
 If ParamCount>=1 Then Begin GS:=ParamStr(1); ErrHalt(Ord(GS[1])-48) End;
 WriteLn('fin');
End.
