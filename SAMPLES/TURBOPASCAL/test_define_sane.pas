{$DEFINE SANE}
program test_define_sane;
{ Test: {$DEFINE SANE} active le mode SANE }
{ Compile sans --sane en ligne de commande }
Uses SANE;
Begin
  WriteLn('DecStrLen = ', DecStrLen);
  WriteLn('SANE via DEFINE');
End.
