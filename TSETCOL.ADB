WITH Ada.Text_IO;
USE Ada.Text_IO;
PROCEDURE TSetCol IS
BEGIN
   Put("Nom");
   Set_Col(15);
   Put("Age");
   Set_Col(25);
   Put_Line("Ville");

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

   -- Si deja au dela, Set_Col passe a la ligne suivante
   Put("1234567890123456789");
   Set_Col(5);
   Put_Line("<- replie");

   -- Set_Col au debut de ligne
   Set_Col(10);
   Put_Line("indente a 10");
END TSetCol;
