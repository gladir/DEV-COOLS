{ test_filesize.pas - Test de FileSize(F) }
program TestFileSize;
var
  F: Text;
  S: LongInt;
begin
  WriteLn('=== Test FileSize ===');

  { Creer un fichier avec contenu connu }
  Assign(F, 'filesize_test.dat');
  Rewrite(F);
  Write(F, 'Hello World');
  Close(F);
  WriteLn('Fichier filesize_test.dat cree.');

  { Ouvrir et tester FileSize }
  Assign(F, 'filesize_test.dat');
  Reset(F);

  S := FileSize(F);
  WriteLn('FileSize = ', S);

  If S = 11 Then
    WriteLn('OK: taille correcte (11 octets)')
  Else
    WriteLn('Taille = ', S, ' (attendu 11)');

  Close(F);

  { Nettoyer }
  Assign(F, 'filesize_test.dat');
  Erase(F);
  WriteLn('Fichier filesize_test.dat supprime.');

  WriteLn('Done.');
end.
