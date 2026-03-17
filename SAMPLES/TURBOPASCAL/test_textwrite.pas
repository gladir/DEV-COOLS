{ test_textwrite.pas - Ecriture de fichier texte avec WriteLn(F, ...) }
{ Cree un fichier texte avec differents types de donnees              }
program TestTextWrite;

var
  F: Text;
  S: String;
  I: Integer;

begin
  WriteLn('=== Test ecriture fichier texte ===');

  { Creer et ecrire un fichier texte }
  Assign(F, 'textwrite_out.txt');
  Rewrite(F);

  WriteLn(F, 'Bonjour le monde');
  WriteLn(F, 'Nombre entier: ', 42);
  WriteLn(F, 'Nombre negatif: ', -10);
  WriteLn(F, 'Zero: ', 0);
  WriteLn(F, 'Grand nombre: ', 999999);

  { Ecrire une serie de lignes avec boucle }
  For I := 1 To 5 Do
    WriteLn(F, 'Ligne numero ', I);

  Close(F);

  WriteLn('Fichier textwrite_out.txt ecrit avec succes.');

  { Verification : relire le fichier et compter les lignes }
  Assign(F, 'textwrite_out.txt');
  Reset(F);
  I := 0;
  while not EOF(F) do
  begin
    ReadLn(F, S);
    I := I + 1;
  end;
  Close(F);

  WriteLn('Lignes ecrites: ', I);
  WriteLn('Done.');
end.
