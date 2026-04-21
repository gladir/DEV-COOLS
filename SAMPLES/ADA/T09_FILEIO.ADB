-- T09_FILEIO.ADB : lecture et ecriture de fichiers texte
WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T09_FileIO IS
   Nom_Fichier : CONSTANT String := "t09_data.txt";
   F           : File_Type;
   Ligne       : String (1 .. 256);
   Taille      : Natural;
   Compte      : Natural := 0;
BEGIN
   -- Ecriture du fichier
   Create (F, Out_File, Nom_Fichier);
   Put_Line (F, "Ligne numero 1");
   Put_Line (F, "Ligne numero 2");
   Put_Line (F, "Ligne numero 3");
   FOR I IN 1 .. 5 LOOP
      Put (F, "Valeur = ");
      Put (F, I, 0);
      New_Line (F);
   END LOOP;
   Close (F);
   Put_Line ("Fichier " & Nom_Fichier & " ecrit.");

   -- Lecture du fichier
   Put_Line ("Contenu relu :");
   Open (F, In_File, Nom_Fichier);
   WHILE NOT End_Of_File (F) LOOP
      Get_Line (F, Ligne, Taille);
      Compte := Compte + 1;
      Put (Compte, 3);
      Put (": ");
      Put_Line (Ligne (1 .. Taille));
   END LOOP;
   Close (F);

   Put ("Nombre total de lignes : ");
   Put (Compte, 0);
   New_Line;
END T09_FileIO;
