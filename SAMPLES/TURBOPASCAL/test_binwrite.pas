{ test_binwrite.pas - Ecriture de fichier binaire avec BlockWrite }
{ Ecrit des donnees binaires (octets) dans un fichier             }
program TestBinWrite;

var
  F: Text;
  Buf: array[1..10] of Byte;
  I: Integer;

begin
  WriteLn('=== Test ecriture fichier binaire ===');

  { Preparer les donnees binaires }
  For I := 1 To 10 Do
    Buf[I] := I * 10;

  { Ecrire le fichier binaire }
  Assign(F, 'binwrite_out.dat');
  Rewrite(F);
  BlockWrite(F, Buf, 10);
  Close(F);
  WriteLn('Fichier binaire ecrit: 10 octets');

  { Verifier en relisant }
  For I := 1 To 10 Do
    Buf[I] := 0;
  Assign(F, 'binwrite_out.dat');
  Reset(F);
  BlockRead(F, Buf, 10);
  Close(F);

  WriteLn('Donnees relues:');
  For I := 1 To 10 Do
    WriteLn('  Buf[', I, '] = ', Buf[I]);

  WriteLn('Done.');
end.
