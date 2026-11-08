{ Regression TPC : "If cond Then;" (corps vide) suivi de "If B Then ... Else"
  (la fin de la premiere condition coincidait avec celle de la seconde, dont le
  test etait supprime). Doit afficher OK. }
Program IFEMPTY;
Var
 F:File;
 H:Boolean;
 Args:String;
Begin
 H:=False;
 Assign(F,'IFEMPTY.TMP');
 {$I-}Erase(F);{$I+}
 If IOResult<>0 Then;
 If H Then Begin
  Args:='hard';
 End
 Else Begin
  Args:='floppy';
 End;
 If Args='floppy' Then WriteLn('OK') Else WriteLn('ERREUR: [',Args,']');
End.
