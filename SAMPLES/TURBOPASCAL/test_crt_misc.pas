{ test_crt_misc.pas - Test procedures CRT diverses }
program TestCrtMisc;

uses Crt;

begin
  { Test Delay }
  WriteLn('Before Delay');
  Delay(10);
  WriteLn('After Delay(10)');

  { Test TextMode }
  TextMode(CO80);
  WriteLn('TextMode(CO80) OK');

  { Test InsLine }
  GotoXY(1, 3);
  WriteLn('Line A');
  WriteLn('Line B');
  WriteLn('Line C');
  GotoXY(1, 4);
  InsLine;
  GotoXY(1, 8);
  WriteLn('InsLine OK');

  { Test DelLine }
  GotoXY(1, 9);
  WriteLn('To delete');
  GotoXY(1, 9);
  DelLine;
  GotoXY(1, 9);
  WriteLn('DelLine OK');

  { Test Sound / NoSound }
  Sound(440);
  NoSound;
  WriteLn('Sound/NoSound OK');

  WriteLn('Done.');
end.
