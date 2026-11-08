Program MULTISEG2;
Uses MSUNITA,MSUNITB;
Procedure Local;
Begin
 Bump(2); Report('local');
End;
Begin
 WriteLn('MULTISEG2 debut');
 Hello;
 Local;
 WriteLn(Total);
 WriteLn(Twice(Total));
End.
