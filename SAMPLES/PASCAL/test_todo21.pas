{ test_todo21.pas - Test des unites Strings, Printer, Overlay pour TPCW32 }
Program TestTodo21;
Uses Strings;
Var
  Buf1, Buf2: Array[0..255] of Char;
  P: PChar;
  N: Integer;
Begin
  WriteLn('=== Test unite Strings (TODO 21) ===');

  { Test StrCopy }
  StrCopy(Buf1, 'Hello World');
  WriteLn('StrCopy: ', Buf1);

  { Test StrLen }
  N := StrLen(Buf1);
  WriteLn('StrLen: ', N);

  { Test StrCat }
  StrCopy(Buf2, 'Hello');
  StrCat(Buf2, ' World');
  WriteLn('StrCat: ', Buf2);

  { Test StrComp }
  N := StrComp(Buf1, Buf2);
  WriteLn('StrComp(equal): ', N);

  { Test StrUpper }
  StrCopy(Buf1, 'hello');
  StrUpper(Buf1);
  WriteLn('StrUpper: ', Buf1);

  { Test StrLower }
  StrCopy(Buf1, 'HELLO');
  StrLower(Buf1);
  WriteLn('StrLower: ', Buf1);

  WriteLn('Done.');
End.
