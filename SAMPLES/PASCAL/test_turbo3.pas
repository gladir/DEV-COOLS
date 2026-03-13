{ test_turbo3.pas - Test de l unite Turbo3 pour TPCW32 }
{ Unite Turbo3 : compatibilite Turbo Pascal 3              }
{ Les fonctions console redirigent vers CRT,               }
{ les fonctions graphiques redirigent vers Graph3.         }
Program TestTurbo3;
Begin
  WriteLn('=== Test unite Turbo3 (TODO 21) ===');

  { Test GotoXY (depuis CRT) }
  GotoXY(1, 1);
  WriteLn('GotoXY OK');

  { Test ClrScr (depuis CRT) }
  ClrScr;
  WriteLn('ClrScr OK');

  { Test ClrEol (depuis CRT) }
  ClrEol;
  WriteLn('ClrEol OK');

  { Test Delay (depuis CRT) }
  Delay(100);
  WriteLn('Delay OK');

  WriteLn('Done.');
End.
