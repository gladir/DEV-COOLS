{ test_flush.pas - Test de Flush(F) }
program TestFlush;
var
  F: Text;
  S: String;
begin
  WriteLn('=== Test Flush ===');

  { Creer un fichier, ecrire, flush, puis fermer }
  Assign(F, 'flush_test.txt');
  Rewrite(F);
  WriteLn(F, 'Ligne 1 ecrite');
  Flush(F);
  WriteLn('Flush appele apres ecriture.');
  WriteLn(F, 'Ligne 2 apres flush');
  Close(F);
  WriteLn('Fichier ferme.');

  { Relire pour verifier }
  Assign(F, 'flush_test.txt');
  Reset(F);
  ReadLn(F, S);
  WriteLn('Lu: ', S);
  ReadLn(F, S);
  WriteLn('Lu: ', S);
  Close(F);

  { Nettoyer }
  Assign(F, 'flush_test.txt');
  Erase(F);
  WriteLn('Fichier flush_test.txt supprime.');

  WriteLn('Done.');
end.
