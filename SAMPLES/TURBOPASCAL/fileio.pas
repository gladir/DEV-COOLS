{ fileio.pas - Assign, Reset, Rewrite, Read, Write, Close (TODO 25) }
program FileIODemo;

var
  F: Text;
  S: String;
  I: Integer;

begin
  { Ecriture dans un fichier }
  Assign(F, 'test_output.txt');
  Rewrite(F);
  WriteLn(F, 'Ligne 1: Hello from TP2JS');
  WriteLn(F, 'Ligne 2: Deuxieme ligne');
  WriteLn(F, 'Ligne 3: Nombre = ', 42);
  Close(F);
  WriteLn('Fichier ecrit: test_output.txt');

  { Lecture du fichier }
  Assign(F, 'test_output.txt');
  Reset(F);
  I := 0;
  while not EOF(F) do
  begin
    ReadLn(F, S);
    Inc(I);
    WriteLn('Lu ligne ', I, ': ', S);
  end;
  Close(F);

  WriteLn('Total lignes lues: ', I);

  { Verification IOResult }
  Assign(F, 'fichier_inexistant.xyz');
  {$I-}
  Reset(F);
  {$I+}
  if IOResult <> 0 then
    WriteLn('Erreur: fichier inexistant non trouve (attendu)')
  else
  begin
    Close(F);
    WriteLn('Fichier inexistant ouvert (inattendu)');
  end;

  WriteLn('Done.');
end.
