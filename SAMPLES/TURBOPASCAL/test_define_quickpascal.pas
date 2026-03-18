{$DEFINE QUICKPASCAL}
program test_define_quickpascal;
{ Test: {$DEFINE QUICKPASCAL} active le mode QuickPascal }
{ Compile sans --quickpascal en ligne de commande }
{ CString est disponible uniquement en mode QuickPascal }
Var
  S : CString;
Begin
  WriteLn('QuickPascal via DEFINE');
End.
