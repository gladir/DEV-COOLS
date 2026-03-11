program test_crt;
uses Crt;
var
  i: Integer;
  ch: Char;
begin
  ClrScr;
  TextColor(Yellow);
  WriteLn('=== Test CRT Unit ===');
  NormVideo;

  { Test couleurs }
  for i := 0 to 15 do
  begin
    TextColor(i);
    Write('Color ', i, ' ');
  end;
  NormVideo;
  WriteLn;

  { Test fond }
  for i := 0 to 7 do
  begin
    TextBackground(i);
    Write(' Bg', i, ' ');
  end;
  NormVideo;
  WriteLn;

  { Test positionnement }
  GotoXY(10, 5);
  WriteLn('Position (10,5)');

  { Test video }
  HighVideo;
  WriteLn('HighVideo');
  LowVideo;
  WriteLn('LowVideo');
  NormVideo;
  WriteLn('NormVideo');

  { Test lignes }
  InsLine;
  DelLine;
  ClrEol;

  { Test constantes couleur }
  TextColor(Red);
  WriteLn('Rouge');
  TextColor(Green);
  WriteLn('Vert');
  TextColor(LightCyan);
  WriteLn('Cyan clair');
  TextBackground(Blue);
  WriteLn('Fond bleu');
  NormVideo;

  { Test constantes mode }
  WriteLn('CO80 = ', CO80);
  WriteLn('BW80 = ', BW80);

  { Test stubs }
  Delay(100);
  Sound(440);
  NoSound;
  Window(1, 1, 80, 25);
  TextMode(CO80);

  WriteLn('=== Fin test CRT ===');
end.
