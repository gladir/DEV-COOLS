Program TestFillChar;
Var
  Buf: Array[1..10] Of Byte;
Begin
  FillChar(Buf, 10, 65);
  WriteLn('FillChar OK');
End.
