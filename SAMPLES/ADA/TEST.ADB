-- TEST.ADB : programme de test complet ADA86 (TODO 25)
WITH Ada.Text_IO;
USE Ada.Text_IO;

PROCEDURE Test IS

   -- Types utilisateur
   TYPE Couleur IS (Rouge, Vert, Bleu);

   SUBTYPE Petit IS Integer RANGE 1 .. 100;

   TYPE Point IS RECORD
      X : Integer;
      Y : Integer;
   END RECORD;

   TYPE Vecteur IS ARRAY (1 .. 10) OF Integer;

   -- Constantes
   Pi : CONSTANT Float := 3.14159;
   Max : CONSTANT Integer := 100;

   -- Variables globales au corps du programme
   N : Integer;
   Somme : Integer;
   P : Point;
   V : Vecteur;
   C : Couleur;
   Valeur : Petit;

   -- Procedure locale
   PROCEDURE AfficherEntier (N : Integer) IS
   BEGIN
      Put (N);
      New_Line;
   END AfficherEntier;

   -- Fonction locale
   FUNCTION Carre (N : Integer) RETURN Integer IS
   BEGIN
      RETURN N * N;
   END Carre;

   -- Procedure avec RAISE
   PROCEDURE VerifierBorne (N : Integer) IS
   BEGIN
      IF N < 1 OR N > 100 THEN
         RAISE Constraint_Error;
      END IF;
      Put_Line ("Valeur correcte");
   EXCEPTION
      WHEN Constraint_Error =>
         Put_Line ("Erreur : valeur hors bornes");
   END VerifierBorne;

BEGIN
   -- Test IF / ELSIF / ELSE
   Put_Line ("=== Test IF ===");
   N := 42;
   IF N > 50 THEN
      Put_Line ("Grand");
   ELSIF N > 20 THEN
      Put_Line ("Moyen");
   ELSE
      Put_Line ("Petit");
   END IF;

   -- Test CASE / WHEN / OTHERS
   Put_Line ("=== Test CASE ===");
   N := 2;
   CASE N IS
      WHEN 1 =>
         Put_Line ("Un");
      WHEN 2 =>
         Put_Line ("Deux");
      WHEN 3 =>
         Put_Line ("Trois");
      WHEN OTHERS =>
         Put_Line ("Autre");
   END CASE;

   -- Test LOOP / EXIT WHEN
   Put_Line ("=== Test LOOP ===");
   N := 0;
   LOOP
      N := N + 1;
      EXIT WHEN N >= 3;
   END LOOP;
   AfficherEntier (N);

   -- Test WHILE
   Put_Line ("=== Test WHILE ===");
   N := 5;
   Somme := 0;
   WHILE N > 0 LOOP
      Somme := Somme + N;
      N := N - 1;
   END LOOP;
   AfficherEntier (Somme);

   -- Test FOR
   Put_Line ("=== Test FOR ===");
   Somme := 0;
   FOR I IN 1 .. 5 LOOP
      Somme := Somme + I;
   END LOOP;
   AfficherEntier (Somme);

   -- Test FUNCTION
   Put_Line ("=== Test FUNCTION ===");
   N := Carre (7);
   AfficherEntier (N);

   -- Test RECORD
   Put_Line ("=== Test RECORD ===");
   P.X := 10;
   P.Y := 20;
   AfficherEntier (P.X);
   AfficherEntier (P.Y);

   -- Test ARRAY
   Put_Line ("=== Test ARRAY ===");
   V (1) := 100;
   V (2) := 200;
   AfficherEntier (V (1));
   AfficherEntier (V (2));

   -- Test RAISE / EXCEPTION
   Put_Line ("=== Test RAISE ===");
   VerifierBorne (50);
   VerifierBorne (200);

   Put_Line ("=== Fin des tests ADA86 ===");

END Test;
