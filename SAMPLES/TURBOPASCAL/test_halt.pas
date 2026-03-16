{ test_halt.pas - Test de Halt }
program TestHalt;
begin
  WriteLn('=== Test Halt ===');
  WriteLn('Avant Halt');
  WriteLn('Done.');
  Halt(0);
  WriteLn('Apres Halt - NE DEVRAIT PAS AFFICHER');
end.
