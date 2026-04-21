-- T36_ASMINLINE.ADB : insertion d'assembleur 80386 inline via
-- System.Machine_Code.Asm (style GNAT).
--
-- Trois formes acceptees par ADACW32 :
--   1. Asm ("instruction")                    -- apres USE System.Machine_Code
--   2. Machine_Code.Asm ("instruction")
--   3. System.Machine_Code.Asm ("instruction")
--
-- La chaine peut contenir plusieurs instructions separees par ';'.
-- Chaque instruction est emise telle quelle dans le flux assembleur
-- et donc encodee par le back-end x86 de ADACW32.

WITH Ada.Text_IO;          USE Ada.Text_IO;
WITH System.Machine_Code;  USE System.Machine_Code;

PROCEDURE T36_ASMINLINE IS
BEGIN
   Put_Line("=== Asm inline (System.Machine_Code) ===");

   -- Forme 1 : nom court apres USE
   Put_Line("Forme 1 : Asm(""NOP"")");
   Asm("NOP");
   Put_Line("  OK");

   -- Forme 2 : nom partiellement qualifie
   Put_Line("Forme 2 : Machine_Code.Asm(""NOP"")");
   Machine_Code.Asm("NOP");
   Put_Line("  OK");

   -- Forme 3 : nom totalement qualifie
   Put_Line("Forme 3 : System.Machine_Code.Asm(""NOP"")");
   System.Machine_Code.Asm("NOP");
   Put_Line("  OK");

   -- Plusieurs instructions dans une seule chaine, separees par ';'
   Put_Line("Multi : Asm(""NOP; NOP; XOR EAX, EAX"")");
   Asm("NOP; NOP; XOR EAX, EAX");
   Put_Line("  OK");

   -- Chaque instruction est assemblee par le back-end x86
   Put_Line("Divers : MOV / INC / DEC");
   Asm("MOV  EAX, 1");
   Asm("INC  EAX");
   Asm("DEC  EAX");
   Put_Line("  OK");

   Put_Line("=== FIN ===");
END T36_ASMINLINE;
