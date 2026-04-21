-- T15_TEXTIO.ADB : interaction complete Ada.Text_IO
-- Demontre Put / Put_Line / Get / New_Line via les helpers
-- runtime Win32 _ADART_PRINT, _ADART_PRINTCHR, _ADART_PRINTINT,
-- _ADART_CRLF, _ADART_GET et _ADART_GETINT.
--
-- Exemple d'utilisation (pipe d'entree) :
--   echo -e "A\n42" | wine T15_TEXTIO.exe
--
WITH Ada.Text_IO;
WITH Ada.Integer_Text_IO;
USE Ada.Text_IO;
USE Ada.Integer_Text_IO;

PROCEDURE T15_TextIO IS

   C : Character;
   N : Integer;
   M : Integer;

BEGIN
   -- Lecture et echo d'un caractere
   Put("Entrez une lettre puis Enter : ");
   Get(C);
   Put("Vous avez tape : ");
   Put(C);
   New_Line;

   -- Lecture d'un entier et operations arithmetiques
   Put("Entrez un entier : ");
   Get(N);
   Put("N         = ");
   Put(N, 0);
   New_Line;
   Put("N * 2     = ");
   Put(N * 2, 0);
   New_Line;
   Put("N + 100   = ");
   Put(N + 100, 0);
   New_Line;

   -- Lecture d'un second entier et somme
   Put("Entrez un autre entier : ");
   Get(M);
   Put("N + M     = ");
   Put(N + M, 0);
   New_Line;

   -- Dernier message complet via Put_Line
   Put_Line("Fin du test Ada.Text_IO.");
END T15_TextIO;
