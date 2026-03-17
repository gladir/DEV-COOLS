{ test_rename.pas - Test de Rename(F, NewName) }
program TestRename;
var
  F: Text;
  S: String;
begin
  WriteLn('=== Test Rename ===');

  { Creer un fichier initial }
  Assign(F, 'rename_src.txt');
  Rewrite(F);
  WriteLn(F, 'Contenu du fichier original');
  Close(F);
  WriteLn('Fichier rename_src.txt cree.');

  { Renommer le fichier }
  Assign(F, 'rename_src.txt');
  Rename(F, 'rename_dst.txt');
  WriteLn('Fichier renomme en rename_dst.txt.');

  { Verifier en lisant le fichier renomme }
  Assign(F, 'rename_dst.txt');
  Reset(F);
  ReadLn(F, S);
  Close(F);
  WriteLn('Lu: ', S);

  { Nettoyer }
  Assign(F, 'rename_dst.txt');
  Erase(F);
  WriteLn('Fichier rename_dst.txt supprime.');

  WriteLn('Done.');
end.
