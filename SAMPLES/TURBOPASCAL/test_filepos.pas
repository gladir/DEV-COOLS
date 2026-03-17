{ test_filepos.pas - Test de FilePos(F) }
program TestFilePos;
var
  F: Text;
  P: LongInt;
begin
  WriteLn('=== Test FilePos ===');

  { Creer un fichier de 20 octets }
  Assign(F, 'filepos_test.dat');
  Rewrite(F);
  Write(F, '01234567890123456789');
  Close(F);
  WriteLn('Fichier filepos_test.dat cree.');

  { Ouvrir et tester FilePos }
  Assign(F, 'filepos_test.dat');
  Reset(F);

  P := FilePos(F);
  WriteLn('FilePos au debut = ', P);

  { Avancer avec Seek }
  Seek(F, 10);
  P := FilePos(F);
  WriteLn('FilePos apres Seek(10) = ', P);

  Close(F);

  { Nettoyer }
  Assign(F, 'filepos_test.dat');
  Erase(F);
  WriteLn('Fichier filepos_test.dat supprime.');

  WriteLn('Done.');
end.
