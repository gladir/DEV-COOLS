-- T04_TYPES.ADB : types enumeres, record, tableau, subtype
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE T04_Types IS
   TYPE Jour IS (Lundi, Mardi, Mercredi, Jeudi, Vendredi);
   SUBTYPE JourTravail IS Jour RANGE Lundi .. Vendredi;

   TYPE Point IS RECORD
      X : Integer;
      Y : Integer;
   END RECORD;

   TYPE Tab IS ARRAY (1 .. 5) OF Integer;

   J   : Jour;
   P   : Point;
   T   : Tab;
   I   : Integer;
   Som : Integer;
BEGIN
   -- Enumere
   J := Mercredi;
   Put (J);   New_Line;

   -- Record
   P.X := 3;
   P.Y := 4;
   Put (P.X);   New_Line;
   Put (P.Y);   New_Line;

   -- Tableau : remplir + sommer
   FOR I IN 1 .. 5 LOOP
      T (I) := I * 10;
   END LOOP;
   Som := 0;
   FOR I IN 1 .. 5 LOOP
      Som := Som + T (I);
   END LOOP;
   Put (Som);   New_Line;
END T04_Types;
