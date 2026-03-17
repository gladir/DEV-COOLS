-- test_filewrite.ada : Exemple d ecriture de fichier avec Put et Put_Line
-- Teste Ada.Text_IO : Create, Put, Put_Line avec handle fichier, Close
with Ada.Text_IO; use Ada.Text_IO;

procedure Test_FileWrite is
   F : Integer;
   N : Integer;
begin
   -- Ecriture de lignes de texte dans un fichier
   Put_Line ("Creation du fichier resultat.txt ...");
   Create (F, Out_File, "resultat.txt");

   Put_Line (F, "=== Rapport de test ADACW32 ===");
   Put_Line (F, "");
   Put_Line (F, "Ligne 1 : Texte simple");
   Put_Line (F, "Ligne 2 : Caracteres speciaux !@#$");
   Put (F, "Ligne 3 : Valeur = ");
   N := 42;
   Put (F, N);
   Put_Line (F, "");
   Put_Line (F, "");
   Put_Line (F, "=== Fin du rapport ===");

   Close (F);
   Put_Line ("Fichier resultat.txt cree avec succes !");
   Put_Line ("Verifiez le contenu du fichier.");
end Test_FileWrite;
