-- test_linker.ada
-- Test de la generation PE/COFF (TODO 25) pour ADACW32
-- Ce fichier teste la generation de fichiers EXE et OBJ
-- ainsi que le listing ASM

-- Cas 01 : Programme minimal avec procedure principale
-- Cas 02 : Declaration de variables entieres
-- Cas 03 : Affectation de valeurs
-- Cas 04 : Appels Put_Line (generation CALL + fixups)
-- Cas 05 : Boucle for (instructions JMP + labels)
-- Cas 06 : Condition if/then/else (Jcc + fixups)
-- Cas 07 : Appel de sous-programme (CALL + RET)
-- Cas 08 : Expressions arithmetiques (ADD/SUB/IMUL)
-- Cas 09 : Variables locales (stack frame EBP)
-- Cas 10 : Chaines litterales (segment .DATA)
-- Cas 11 : Constantes immediates (PUSH imm)
-- Cas 12 : Comparaisons (CMP + SETcc)
-- Cas 13 : Affectation composee (INC/DEC)
-- Cas 14 : Boucle while (JMP conditionnel)
-- Cas 15 : Plusieurs procedures (multiples labels)

with Ada.Text_IO; use Ada.Text_IO;

procedure Test_Linker is
   -- Cas 02 : declarations
   X : Integer := 0;
   Y : Integer := 10;
   Z : Integer;

   -- Cas 07 : sous-programme
   procedure Afficher_Resultat(Val : Integer) is
   begin
      Put_Line("Resultat:");
      -- Cas 08 : expression
      Z := Val + 1;
   end Afficher_Resultat;

   -- Cas 15 : deuxieme procedure
   procedure Init_Valeurs is
   begin
      X := 5;
      Y := 20;
   end Init_Valeurs;

begin
   -- Cas 04 : appel Put_Line
   Put_Line("Test TODO 25 - Linker PE");

   -- Cas 03 : affectation
   X := 42;
   Y := X;

   -- Cas 05 : boucle for
   for I in 1 .. 5 loop
      X := X + I;
   end loop;

   -- Cas 06 : condition
   if X > 50 then
      Put_Line("X > 50");
   else
      Put_Line("X <= 50");
   end if;

   -- Cas 14 : boucle while
   while Y > 0 loop
      Y := Y - 1;
   end loop;

   -- Cas 07 : appel procedure
   Init_Valeurs;
   Afficher_Resultat(X);

   -- Cas 13 : increment
   X := X + 1;
   Y := Y - 1;

   Put_Line("Fin du test.");
end Test_Linker;
