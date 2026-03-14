Program TestCrt;
Uses Crt;
Var
  Ch : Char;
Begin
  ClrScr;
  TextColor(14);
  TextBackground(1);
  GotoXY(10, 5);
  WriteLn('Hello CRT!');
  HighVideo;
  WriteLn('Bright text');
  LowVideo;
  WriteLn('Dim text');
  NormVideo;
  WriteLn('Normal text');
  ClrEol;
  Window(1, 1, 80, 25);
  WriteLn('WhereX=', WhereX, ' WhereY=', WhereY);
  Delay(100);
  Sound(440);
  NoSound;
  If KeyPressed Then
    Ch := ReadKey;
  WriteLn('Done.');
End.
