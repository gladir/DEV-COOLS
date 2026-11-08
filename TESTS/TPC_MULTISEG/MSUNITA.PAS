Unit MSUNITA;
Interface
Var Counter:Integer;
Procedure Bump(N:Integer);
Function Twice(N:Integer):Integer;
Procedure Report(S:String);
Implementation
Procedure Hidden(N:Integer);
Begin
 Counter:=Counter+N*10;
End;
Procedure Bump(N:Integer);
Begin
 Hidden(N); Counter:=Counter+1;
End;
Function Twice(N:Integer):Integer;
Begin
 Twice:=N*2;
End;
Procedure Report(S:String);
Begin
 WriteLn('MSUNITA.Report: ',S,' counter=',Counter);
End;
Begin
 Counter:=1000;
 WriteLn('init MSUNITA');
End.
