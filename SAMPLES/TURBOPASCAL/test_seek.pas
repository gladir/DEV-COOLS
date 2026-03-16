{ test_seek.pas - Test de Seek(F, Pos) }
program TestSeek;
var
  F: Text;
  Buf: array[1..20] of Byte;
  I: Integer;
begin
  WriteLn('=== Test Seek ===');

  { Creer un fichier binaire de 20 octets }
  Assign(F, 'seek_test.dat');
  Rewrite(F);
  For I := 1 To 20 Do
    Buf[I] := I;
  BlockWrite(F, Buf, 20);
  Close(F);
  WriteLn('Fichier seek_test.dat cree (20 octets).');

  { Rouvrir, Seek a position 10, lire 5 octets }
  Assign(F, 'seek_test.dat');
  Reset(F);
  Seek(F, 10);
  BlockRead(F, Buf, 5);
  Close(F);

  WriteLn('Octets a partir de pos 10:');
  For I := 1 To 5 Do
    WriteLn('  Buf[', I, '] = ', Buf[I]);

  { Nettoyer }
  Assign(F, 'seek_test.dat');
  Erase(F);
  WriteLn('Fichier seek_test.dat supprime.');

  WriteLn('Done.');
end.
