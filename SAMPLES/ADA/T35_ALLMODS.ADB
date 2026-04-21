-- T35_ALLMODS.ADB : recapitulatif multi-modules de la bibliotheque standard
-- Illustre l'usage combine de Text_IO, Characters.Handling, Characters.Latin_1,
-- Numerics.Elementary_Functions, Strings, et Strings.Maps dans un seul programme.

WITH Ada.Text_IO;                           USE Ada.Text_IO;
WITH Ada.Characters.Handling;               USE Ada.Characters.Handling;
WITH Ada.Characters.Latin_1;                USE Ada.Characters.Latin_1;
WITH Ada.Numerics.Elementary_Functions;     USE Ada.Numerics.Elementary_Functions;
WITH Ada.Strings;                           USE Ada.Strings;
WITH Ada.Strings.Maps;                      USE Ada.Strings.Maps;

PROCEDURE T35_ALLMODS IS
   X : Float;
BEGIN
   Put_Line("=== Recapitulatif modules standard Ada ===");

   Put_Line("-- Text_IO --");
   Put_Line("Hello from Text_IO!");

   Put_Line("-- Characters.Handling --");
   Put("To_Upper('h') = '");  Put(To_Upper('h'));  Put_Line("'");
   Put("To_Lower('Z') = '");  Put(To_Lower('Z'));  Put_Line("'");
   Put("Is_Digit('7') = ");   Put(Is_Digit('7'));  New_Line;

   Put_Line("-- Characters.Latin_1 --");
   Put("Code de LC_A  = "); Put(Character'Pos(LC_A));  New_Line;
   Put("Code de UC_Z  = "); Put(Character'Pos(UC_Z));  New_Line;
   Put("Code de Space = "); Put(Character'Pos(Space)); New_Line;

   Put_Line("-- Numerics.Elementary_Functions --");
   X := Sqrt(144.0);   Put("Sqrt(144.0) = "); Put(X); New_Line;
   X := Exp(0.0);      Put("Exp(0.0)    = "); Put(X); New_Line;
   X := Cos(0.0);      Put("Cos(0.0)    = "); Put(X); New_Line;

   Put_Line("-- Strings --");
   Put("Length(""Ada 2025"")        = "); Put(Length("Ada 2025"));         New_Line;
   Put("Index(""Ada 2025"", ""20"") = "); Put(Index("Ada 2025", "20"));    New_Line;
   Put("Count(""mississippi"", ""s"") = "); Put(Count("mississippi", "s")); New_Line;

   Put_Line("-- Strings.Maps --");
   Put("Is_In('A', ""ABCDE"") = "); Put(Is_In('A', "ABCDE"));  New_Line;
   Put("Is_In('X', ""ABCDE"") = "); Put(Is_In('X', "ABCDE"));  New_Line;

   Put_Line("=== FIN ===");
END T35_ALLMODS;
