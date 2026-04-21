-- T09_FILEIO.ADB : lecture et ecriture de fichiers texte
-- Demontre le sous-ensemble de Ada.Text_IO supporte par ADACW32 :
-- Create, Open, Close, Put_Line (fichier), Get_Line (fichier).
-- Le nombre de lignes ecrites etant connu, on relit exactement le
-- meme nombre de lignes sans dependre de End_Of_File.
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T09_FileIO IS
   TYPE Buffer IS ARRAY (1 .. 256) OF Character;

   Nb_Lignes : CONSTANT Integer := 8;   -- 3 en-tete + 5 valeurs
   F         : File_Type;
   Ligne     : Buffer;
   Taille    : Integer;
BEGIN
   -- Ecriture du fichier
   Create (F, Out_File, "t09_data.txt");
   Put_Line (F, "Ligne numero 1");
   Put_Line (F, "Ligne numero 2");
   Put_Line (F, "Ligne numero 3");
   FOR I IN 1 .. 5 LOOP
      Put_Line (F, "Valeur =" & Integer'Image (I));
   END LOOP;
   Close (F);
   Put_Line ("Fichier t09_data.txt ecrit (" &
             Integer'Image (Nb_Lignes) & " lignes).");

   -- Lecture du fichier (nombre de lignes connu d'avance)
   Put_Line ("Contenu relu :");
   Open (F, In_File, "t09_data.txt");
   FOR I IN 1 .. 8 LOOP
      Get_Line (F, Ligne, Taille);
      Put (" ");
      Put (Integer'Image (I));
      Put (" :");
      FOR K IN 1 .. Taille LOOP
         Put (Ligne (K));
      END LOOP;
      New_Line;
   END LOOP;
   Close (F);

   Put_Line ("Fin de T09_FileIO.");
END T09_FileIO;
