-- T16_PARAMS.ADB : passage des parametres (IN, OUT, IN OUT)
-- Demontre que ParseStatement / ParseAssignment / ParseProcedureCall
-- gerent correctement :
--   * les assignations simples (`X := ...`)
--   * les appels de procedure avec parametres IN (par valeur)
--   * les appels avec parametres OUT et IN OUT (par adresse)
--   * les appels de fonction avec valeur de retour
--
-- Sans la propagation correcte du mode du parametre depuis le SubTab
-- vers la table des symboles locaux du corps, Swap et Increment ne
-- modifiaient pas les variables de l'appelant.

WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T16_Params IS

   A, B   : Integer;
   Result : Integer;
   Ch     : Character;

   -- IN OUT : echange les deux valeurs via adresse
   PROCEDURE Swap(X, Y : IN OUT Integer) IS
      Tmp : Integer;
   BEGIN
      Tmp := X;
      X   := Y;
      Y   := Tmp;
   END Swap;

   -- IN OUT sur un seul parametre
   PROCEDURE Increment(N : IN OUT Integer) IS
   BEGIN
      N := N + 1;
   END Increment;

   -- IN (valeur) + OUT (adresse)
   PROCEDURE Double_Value(V : IN Integer; R : OUT Integer) IS
   BEGIN
      R := V * 2;
   END Double_Value;

   -- IN OUT sur un Character
   PROCEDURE Upper(C : IN OUT Character) IS
   BEGIN
      IF C >= 'a' AND C <= 'z' THEN
         C := Character'Val(Character'Pos(C) - 32);
      END IF;
   END Upper;

   -- Fonction classique : tout IN par valeur
   FUNCTION Sum(X, Y : Integer) RETURN Integer IS
   BEGIN
      RETURN X + Y;
   END Sum;

BEGIN
   -- Assignations simples
   A := 10;
   B := 20;
   Put("Depart     : A="); Put(A, 0);
   Put(" B=");             Put(B, 0); New_Line;

   -- Appel IN OUT : Swap doit inverser A et B
   Swap(A, B);
   Put("Apres Swap : A="); Put(A, 0);
   Put(" B=");             Put(B, 0); New_Line;

   -- Appel IN OUT a un seul argument
   Increment(A);
   Put("Apres Inc  : A="); Put(A, 0); New_Line;

   -- Appel IN + OUT
   Double_Value(A, Result);
   Put("Double(A)  = ");   Put(Result, 0); New_Line;

   -- Appel de fonction (IN par valeur) dans une affectation
   Result := Sum(A, B);
   Put("Sum(A,B)   = ");   Put(Result, 0); New_Line;

   -- IN OUT sur un Character
   Ch := 'z';
   Upper(Ch);
   Put("Upper(z)   = ");   Put(Ch); New_Line;

   Put_Line("Fin du test parametres.");
END T16_Params;
