{ test_truncate.pas - Test de Truncate(F) }
program TestTruncate;
var
  F: Text;
  S: LongInt;
  Line: String;
begin
  WriteLn('=== Test Truncate ===');

  { Creer un fichier }
  Assign(F, 'trunc_test.dat');
  Rewrite(F);
  Write(F, '01234567890123456789');
  S := FileSize(F);
  WriteLn('FileSize apres ecriture = ', S);

  { Seek et Truncate (fichier ouvert en ecriture) }
  Seek(F, 10);
  Truncate(F);
  S := FileSize(F);
  WriteLn('FileSize apres Truncate(10) = ', S);
  Close(F);

  { Relire pour verifier }
  Assign(F, 'trunc_test.dat');
  Reset(F);
  S := FileSize(F);
  WriteLn('FileSize a la relecture = ', S);

  If S = 10 Then
    WriteLn('OK: taille correcte (10 octets)')
  Else
    WriteLn('Taille = ', S, ' (attendu 10)');

  Close(F);

  { Nettoyer }
  Assign(F, 'trunc_test.dat');
  Erase(F);
  WriteLn('Fichier trunc_test.dat supprime.');

  WriteLn('Done.');
end.
