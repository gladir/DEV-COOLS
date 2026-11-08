Unit MSUNITB;
Interface
Uses MSUNITA;
Function Total:Integer;
Procedure Hello;
Implementation
Function Total:Integer;
Begin
 Bump(1);
 Total:=Counter+Twice(21);
End;
Procedure Hello;
Begin
 Report('depuis MSUNITB');
End;
Begin
 WriteLn('init MSUNITB');
End.
