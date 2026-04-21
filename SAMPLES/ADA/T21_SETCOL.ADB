-----------------------------------------------------------------
-- T21_SETCOL.ADB : test de Ada.Text_IO.Set_Col                  --
-- Couvre :                                                      --
--   - Set_Col pour aligner des colonnes (tableau)               --
--   - Set_Col deja depasse : passe a la ligne suivante          --
--   - Set_Col en debut de ligne (indentation)                   --
--   - Interaction avec Put_Line (reset a la colonne 1)          --
-----------------------------------------------------------------
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T21_SetCol IS
BEGIN
   -- En-tete d un tableau aligne sur les colonnes 1, 15 et 25
   Put("Nom");
   Set_Col(15);
   Put("Age");
   Set_Col(25);
   Put_Line("Ville");

   -- Lignes de donnees
   Put("Alice");
   Set_Col(15);
   Put("30");
   Set_Col(25);
   Put_Line("Paris");

   Put("Bob");
   Set_Col(15);
   Put("25");
   Set_Col(25);
   Put_Line("Lyon");

   -- Si deja au-dela de la colonne cible, Set_Col passe a la ligne suivante
   Put("1234567890123456789");
   Set_Col(5);
   Put_Line("<- replie");

   -- Set_Col en debut de ligne equivaut a une indentation
   Set_Col(10);
   Put_Line("indente a 10");
END T21_SetCol;
