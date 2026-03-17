{ test_textread.pas - Lecture de fichier texte avec ReadLn(F, S) }
{ Lit un fichier texte cree par test_textwrite et affiche son contenu }
program TestTextRead;

var
  F: Text;
  S: String;
  Count: Integer;

begin
  WriteLn('=== Test lecture fichier texte ===');

  { Creer d abord un fichier de test }
  Assign(F, 'textread_data.txt');
  Rewrite(F);
  WriteLn(F, 'Premiere ligne');
  WriteLn(F, 'Deuxieme ligne');
  WriteLn(F, 'Troisieme ligne');
  WriteLn(F, 'Derniere ligne');
  Close(F);
  WriteLn('Fichier de test cree.');

  { Lire le fichier ligne par ligne }
  Assign(F, 'textread_data.txt');
  Reset(F);

  Count := 0;
  while not EOF(F) do
  begin
    ReadLn(F, S);
    Count := Count + 1;
    WriteLn('Ligne ', Count, ': ', S);
  end;
  Close(F);

  WriteLn('Total lignes lues: ', Count);
  WriteLn('Done.');
end.
