{ test_fillchar.pas - Test de FillChar et Move }
program TestFillChar;
var
  Buf1: array[1..10] of Byte;
  Buf2: array[1..10] of Byte;
  I: Integer;
begin
  WriteLn('=== Test FillChar/Move ===');

  { Test FillChar }
  FillChar(Buf1, 10, 65);  { remplir de 'A' }
  WriteLn('FillChar(Buf1, 10, 65) ok');
  If Buf1[1] = 65 Then
    WriteLn('Buf1[1] = 65: OK')
  Else
    WriteLn('Buf1[1] <> 65: FAIL');
  If Buf1[10] = 65 Then
    WriteLn('Buf1[10] = 65: OK')
  Else
    WriteLn('Buf1[10] <> 65: FAIL');

  { Test Move }
  FillChar(Buf2, 10, 0);
  Move(Buf1, Buf2, 10);
  WriteLn('Move(Buf1, Buf2, 10) ok');
  If Buf2[1] = 65 Then
    WriteLn('Buf2[1] = 65: OK')
  Else
    WriteLn('Buf2[1] <> 65: FAIL');
  If Buf2[10] = 65 Then
    WriteLn('Buf2[10] = 65: OK')
  Else
    WriteLn('Buf2[10] <> 65: FAIL');

  WriteLn('Done.');
end.
