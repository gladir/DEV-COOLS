{$DEFINE APPLEPASCAL}
program test_define_applepascal;
{ Test: {$DEFINE APPLEPASCAL} active le mode Apple Pascal }
{ Compile sans --applepascal en ligne de commande }
Uses SANE;
Begin
  WriteLn('DecStrLen = ', DecStrLen);
  WriteLn('ApplePascal via DEFINE');
End.
