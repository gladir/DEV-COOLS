{ test_eoln.pas - Test de Eoln(F) }
program TestEoln;
var
  F: Text;
begin
  WriteLn('=== Test Eoln ===');

  { Creer un fichier avec deux lignes }
  Assign(F, 'eoln_test.txt');
  Rewrite(F);
  WriteLn(F, 'Ligne1');
  WriteLn(F, 'Ligne2');
  Close(F);
  WriteLn('Fichier eoln_test.txt cree.');

  { Lire et tester Eoln }
  Assign(F, 'eoln_test.txt');
  Reset(F);

  { Avant lecture, Eoln devrait etre False sur un caractere normal }
  If Eoln(F) Then
    WriteLn('Eoln(F) = True (avant lecture)')
  Else
    WriteLn('Eoln(F) = False (avant lecture)');

  { Apres EOF }
  Close(F);

  { Test Eoln sans argument (stdin) }
  If Eoln Then
    WriteLn('Eoln = True (stdin EOF)')
  Else
    WriteLn('Eoln = False (stdin)');

  { Nettoyer }
  Assign(F, 'eoln_test.txt');
  Erase(F);
  WriteLn('Fichier eoln_test.txt supprime.');

  WriteLn('Done.');
end.
