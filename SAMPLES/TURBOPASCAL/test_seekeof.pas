{ test_seekeof.pas - Test de SeekEof et SeekEoln }
program TestSeekEof;
var
  F: Text;
begin
  WriteLn('=== Test SeekEof / SeekEoln ===');

  { Creer un fichier avec du texte et des espaces }
  Assign(F, 'seekeof_test.txt');
  Rewrite(F);
  WriteLn(F, 'Ligne1');
  WriteLn(F, '  ');
  Close(F);
  WriteLn('Fichier seekeof_test.txt cree.');

  { Tester SeekEof }
  Assign(F, 'seekeof_test.txt');
  Reset(F);

  If SeekEof(F) Then
    WriteLn('SeekEof(F) = True')
  Else
    WriteLn('SeekEof(F) = False');

  Close(F);

  { Tester SeekEoln }
  Assign(F, 'seekeof_test.txt');
  Reset(F);

  If SeekEoln(F) Then
    WriteLn('SeekEoln(F) = True')
  Else
    WriteLn('SeekEoln(F) = False');

  Close(F);

  { Test sans argument }
  If SeekEof Then
    WriteLn('SeekEof = True (stdin)')
  Else
    WriteLn('SeekEof = False (stdin)');

  { Nettoyer }
  Assign(F, 'seekeof_test.txt');
  Erase(F);
  WriteLn('Fichier seekeof_test.txt supprime.');

  WriteLn('Done.');
end.
