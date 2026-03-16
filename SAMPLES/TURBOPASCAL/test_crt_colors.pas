{ test_crt_colors.pas - Test des constantes et procedures couleur CRT }
program TestCrtColors;

uses Crt;

begin
  { Test des constantes de couleur }
  WriteLn('Black=', Black);
  WriteLn('Blue=', Blue);
  WriteLn('Green=', Green);
  WriteLn('Cyan=', Cyan);
  WriteLn('Red=', Red);
  WriteLn('Magenta=', Magenta);
  WriteLn('Brown=', Brown);
  WriteLn('LightGray=', LightGray);
  WriteLn('DarkGray=', DarkGray);
  WriteLn('LightBlue=', LightBlue);
  WriteLn('LightGreen=', LightGreen);
  WriteLn('LightCyan=', LightCyan);
  WriteLn('LightRed=', LightRed);
  WriteLn('LightMagenta=', LightMagenta);
  WriteLn('Yellow=', Yellow);
  WriteLn('White=', White);
  WriteLn('Blink=', Blink);

  { Test des constantes de mode }
  WriteLn('BW40=', BW40);
  WriteLn('CO40=', CO40);
  WriteLn('BW80=', BW80);
  WriteLn('CO80=', CO80);
  WriteLn('Mono=', Mono);
  WriteLn('Font8x8=', Font8x8);
  WriteLn('C40=', C40);
  WriteLn('C80=', C80);

  { Test TextColor / TextBackground }
  TextColor(Yellow);
  TextBackground(Blue);
  WriteLn('Yellow on Blue');
  TextColor(LightGray);
  TextBackground(Black);
  WriteLn('Normal');

  { Test HighVideo / LowVideo / NormVideo }
  HighVideo;
  WriteLn('HighVideo');
  LowVideo;
  WriteLn('LowVideo');
  NormVideo;
  WriteLn('NormVideo');

  WriteLn('Done.');
end.
