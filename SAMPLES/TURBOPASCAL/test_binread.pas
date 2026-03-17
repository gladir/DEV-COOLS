{ test_binread.pas - Lecture de fichier binaire avec BlockRead }
{ Ecrit puis relit des donnees binaires structurees            }
program TestBinRead;

var
  F: Text;
  Buf: array[1..256] of Byte;
  I: Integer;

begin
  WriteLn('=== Test lecture fichier binaire ===');

  { Creer un fichier binaire de test : 256 octets (0..255) }
  For I := 1 To 256 Do
    Buf[I] := I - 1;

  Assign(F, 'binread_data.dat');
  Rewrite(F);
  BlockWrite(F, Buf, 256);
  Close(F);
  WriteLn('Fichier binaire cree: 256 octets');

  { Effacer le buffer }
  For I := 1 To 256 Do
    Buf[I] := 0;

  { Relire le fichier }
  Assign(F, 'binread_data.dat');
  Reset(F);
  BlockRead(F, Buf, 256);
  Close(F);

  { Verifier les 10 premieres et 10 dernieres valeurs }
  WriteLn('Premiers 10 octets:');
  For I := 1 To 10 Do
    WriteLn('  Buf[', I, '] = ', Buf[I]);

  WriteLn('Derniers 10 octets:');
  For I := 247 To 256 Do
    WriteLn('  Buf[', I, '] = ', Buf[I]);

  WriteLn('Done.');
end.
