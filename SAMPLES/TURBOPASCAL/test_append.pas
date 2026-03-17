{ test_append.pas - Test de la procedure Append pour fichiers texte }
{ Cree un fichier, le ferme, puis ajoute des lignes avec Append     }
program TestAppend;

var
  F: Text;
  S: String;
  Count: Integer;

begin
  WriteLn('=== Test Append fichier texte ===');

  { Ecrire fichier initial }
  Assign(F, 'append_data.txt');
  Rewrite(F);
  WriteLn(F, 'Ligne originale 1');
  WriteLn(F, 'Ligne originale 2');
  Close(F);
  WriteLn('Fichier initial ecrit (2 lignes).');

  { Ajouter au fichier avec Append }
  Assign(F, 'append_data.txt');
  Append(F);
  WriteLn(F, 'Ligne ajoutee 3');
  WriteLn(F, 'Ligne ajoutee 4');
  Close(F);
  WriteLn('Lignes ajoutees avec Append.');

  { Relire tout le fichier }
  Assign(F, 'append_data.txt');
  Reset(F);
  Count := 0;
  while not EOF(F) do
  begin
    ReadLn(F, S);
    Count := Count + 1;
    WriteLn('Lu: ', S);
  end;
  Close(F);

  WriteLn('Total lignes: ', Count);
  WriteLn('Done.');
end.
