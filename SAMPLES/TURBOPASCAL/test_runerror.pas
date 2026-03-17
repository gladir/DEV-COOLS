{ test_runerror.pas - Test de RunError }
program TestRunError;
begin
  WriteLn('=== Test RunError ===');
  WriteLn('Avant RunError');
  WriteLn('Done.');
  RunError(0);
  WriteLn('Apres RunError - NE DEVRAIT PAS AFFICHER');
end.
