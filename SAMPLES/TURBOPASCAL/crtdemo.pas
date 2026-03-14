{ crtdemo.pas - uses Crt: ClrScr, GotoXY, TextColor, ReadKey (TODO 25) }
program CrtDemo;

uses Crt;

var
  Ch: Char;
  I: Integer;

begin
  ClrScr;
  TextColor(Yellow);
  WriteLn('=== CRT Demo ===');
  TextColor(LightGray);
  WriteLn;

  { Couleurs }
  for I := 0 to 15 do
  begin
    TextColor(I);
    Write('Color ', I:2, ' ');
  end;
  TextColor(LightGray);
  WriteLn;
  WriteLn;

  { Positionnement du curseur }
  GotoXY(10, 8);
  Write('Texte a la position (10, 8)');
  GotoXY(1, 10);

  { Fond colore }
  TextBackground(Blue);
  TextColor(White);
  WriteLn(' Fond bleu, texte blanc ');
  TextBackground(Black);
  TextColor(LightGray);
  WriteLn;

  WriteLn('Appuyez sur une touche...');
  Ch := ReadKey;
  WriteLn('Touche pressee: ', Ch);

  { Delai }
  WriteLn('Pause de 500ms...');
  Delay(500);

  NormVideo;
  WriteLn('Done.');
end.
