program test_bytestream;
{ Test des types ByteStream et WordStream (Apple Pascal SYSTEM) }
Var
  B: ByteStream;
  W: WordStream;
  I: Integer;
Begin
  WriteLn('--- Test ByteStream ---');
  For I := 0 To 9 Do
    B[I] := Chr(65 + I);
  For I := 0 To 9 Do
    Write(B[I]);
  WriteLn;

  WriteLn('--- Test WordStream ---');
  For I := 0 To 9 Do
    W[I] := I * 10;
  For I := 0 To 9 Do
    Write(W[I], ' ');
  WriteLn;

  WriteLn('Done.');
End.
