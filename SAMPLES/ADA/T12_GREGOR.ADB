-- T12_GREGOR.ADB : calendrier gregorien (an bissextile, jour de la semaine, nb jours)
WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T12_Gregor IS

   TYPE Jour_Nom IS (Dimanche, Lundi, Mardi, Mercredi, Jeudi, Vendredi, Samedi);

   FUNCTION Est_Bissextile (An : Integer) RETURN Boolean IS
   BEGIN
      IF An MOD 400 = 0 THEN
         RETURN True;
      ELSIF An MOD 100 = 0 THEN
         RETURN False;
      ELSIF An MOD 4 = 0 THEN
         RETURN True;
      ELSE
         RETURN False;
      END IF;
   END Est_Bissextile;

   FUNCTION Nb_Jours (Mois, An : Integer) RETURN Integer IS
   BEGIN
      CASE Mois IS
         WHEN 1 | 3 | 5 | 7 | 8 | 10 | 12 => RETURN 31;
         WHEN 4 | 6 | 9 | 11              => RETURN 30;
         WHEN 2 =>
            IF Est_Bissextile (An) THEN
               RETURN 29;
            ELSE
               RETURN 28;
            END IF;
         WHEN OTHERS => RETURN 0;
      END CASE;
   END Nb_Jours;

   -- Algorithme de Zeller pour le calendrier gregorien
   FUNCTION Jour_Semaine (J, M, A : Integer) RETURN Jour_Nom IS
      Q  : Integer := J;
      Mz : Integer := M;
      Az : Integer := A;
      K  : Integer;
      J2 : Integer;
      H  : Integer;
      Idx : Integer;
   BEGIN
      IF Mz < 3 THEN
         Mz := Mz + 12;
         Az := Az - 1;
      END IF;
      K  := Az MOD 100;
      J2 := Az / 100;
      H  := (Q + (13 * (Mz + 1)) / 5 + K + K / 4 + J2 / 4 + 5 * J2) MOD 7;
      -- Zeller : 0 = samedi, 1 = dimanche, ... 6 = vendredi
      -- Conversion vers Dimanche=0 .. Samedi=6
      Idx := (H + 6) MOD 7;
      RETURN Jour_Nom'Val (Idx);
   END Jour_Semaine;

   Annee : Integer;
BEGIN
   Put_Line ("Annees bissextiles de 2000 a 2030 :");
   FOR A IN 2000 .. 2030 LOOP
      IF Est_Bissextile (A) THEN
         Put (A, 5);
      END IF;
   END LOOP;
   New_Line;

   Annee := 2024;
   Put ("Nombre de jours par mois en ");
   Put (Annee, 0);
   Put_Line (" :");
   FOR M IN 1 .. 12 LOOP
      Put ("Mois "); Put (M, 2); Put (" : ");
      Put (Nb_Jours (M, Annee), 0); New_Line;
   END LOOP;

   Put_Line ("Jour de la semaine pour quelques dates :");
   Put ("2024-01-01 : ");
   Put_Line (Jour_Nom'Image (Jour_Semaine (1, 1, 2024)));
   Put ("2000-02-29 : ");
   Put_Line (Jour_Nom'Image (Jour_Semaine (29, 2, 2000)));
   Put ("1969-07-20 : ");
   Put_Line (Jour_Nom'Image (Jour_Semaine (20, 7, 1969)));
   Put ("2026-04-21 : ");
   Put_Line (Jour_Nom'Image (Jour_Semaine (21, 4, 2026)));
END T12_Gregor;
