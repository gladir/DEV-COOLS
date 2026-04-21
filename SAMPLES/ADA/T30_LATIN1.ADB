-- T30_LATIN1.ADB : Demonstration des constantes Ada.Characters.Latin_1
-- Teste ~30 constantes de caracteres (NUL, LF, CR, Space, Chiffres, ...).
-- Compile avec ADACW32 et execute sous Wine.

WITH Ada.Text_IO;               USE Ada.Text_IO;
WITH Ada.Characters.Latin_1;    USE Ada.Characters.Latin_1;

PROCEDURE T30_LATIN1 IS
BEGIN
   Put_Line("=== Ada.Characters.Latin_1 ===");
   Put("NUL code = "); Put(Character'Pos(NUL));  New_Line;
   Put("LF code  = "); Put(Character'Pos(LF));   New_Line;
   Put("CR code  = "); Put(Character'Pos(CR));   New_Line;
   Put("HT code  = "); Put(Character'Pos(HT));   New_Line;
   Put("BS code  = "); Put(Character'Pos(BS));   New_Line;
   Put("Space    = "); Put(Character'Pos(Space));  New_Line;
   Put("Exclamation = "); Put(Character'Pos(Exclamation)); New_Line;
   Put("Quotation   = "); Put(Character'Pos(Quotation));   New_Line;
   Put("Number_Sign = "); Put(Character'Pos(Number_Sign)); New_Line;
   Put("Dollar_Sign = "); Put(Character'Pos(Dollar_Sign)); New_Line;
   Put("Percent     = "); Put(Character'Pos(Percent_Sign));New_Line;
   Put("Ampersand   = "); Put(Character'Pos(Ampersand));   New_Line;
   Put("Left_Parenthesis  = "); Put(Character'Pos(Left_Parenthesis));  New_Line;
   Put("Right_Parenthesis = "); Put(Character'Pos(Right_Parenthesis)); New_Line;
   Put("Asterisk    = "); Put(Character'Pos(Asterisk));  New_Line;
   Put("Plus_Sign   = "); Put(Character'Pos(Plus_Sign)); New_Line;
   Put("Comma       = "); Put(Character'Pos(Comma));     New_Line;
   Put("Hyphen      = "); Put(Character'Pos(Hyphen));    New_Line;
   Put("Full_Stop   = "); Put(Character'Pos(Full_Stop)); New_Line;
   Put("Solidus     = "); Put(Character'Pos(Solidus));   New_Line;
   Put("Colon       = "); Put(Character'Pos(Colon));     New_Line;
   Put("Semicolon   = "); Put(Character'Pos(Semicolon)); New_Line;
   Put("Question    = "); Put(Character'Pos(Question));  New_Line;
   Put("Commercial_At = "); Put(Character'Pos(Commercial_At)); New_Line;
   Put("LC_A = "); Put(Character'Pos(LC_A)); New_Line;
   Put("LC_Z = "); Put(Character'Pos(LC_Z)); New_Line;
   Put("UC_A = "); Put(Character'Pos(UC_A)); New_Line;
   Put("UC_Z = "); Put(Character'Pos(UC_Z)); New_Line;
   Put_Line("=== FIN ===");
END T30_LATIN1;
