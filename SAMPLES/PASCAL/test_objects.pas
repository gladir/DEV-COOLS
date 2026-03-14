{ test_objects.pas - Test de l unite Objects pour TPCW32 }
{ Unite Objects : TObject, TStream, TDosStream, NewStr   }
Program TestObjects;
Var
  P: Pointer;
  S: String;
Begin
  WriteLn('=== Test unite Objects (TODO 21) ===');

  { Test NewStr : allouer une copie de chaine }
  S := 'Hello Objects';
  P := NewStr(S);
  WriteLn('NewStr OK');

  { Test DisposeStr : liberer la chaine }
  DisposeStr(P);
  WriteLn('DisposeStr OK');

  { Test RegisterType (stub) }
  RegisterType(NIL);
  WriteLn('RegisterType OK');

  { Test TObject stubs }
  TObject_Init;
  WriteLn('TObject.Init OK');
  TObject_Done;
  WriteLn('TObject.Done OK');
  TObject_Free;
  WriteLn('TObject.Free OK');

  WriteLn('Done.');
End.
