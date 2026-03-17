{ test_ioresult.pas - Test de IoResult }
program TestIoResult;
var
  F: Text;
  Err: Word;
begin
  WriteLn('=== Test IoResult ===');

  { IoResult devrait retourner 0 au debut }
  Err := IoResult;
  WriteLn('IoResult initial = ', Err);

  { Operation reussie : creer un fichier }
  Assign(F, 'ioresult_test.txt');
  Rewrite(F);
  WriteLn(F, 'Test IoResult');
  Close(F);

  Err := IoResult;
  WriteLn('IoResult apres creation = ', Err);

  { Nettoyer }
  Assign(F, 'ioresult_test.txt');
  Erase(F);
  WriteLn('Fichier ioresult_test.txt supprime.');

  WriteLn('Done.');
end.
