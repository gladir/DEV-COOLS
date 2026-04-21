-- T33_STRINGS.ADB : Ada.Strings / Ada.Strings.Fixed / Ada.Strings.Maps
-- Teste Length, Index, Count, Head, Tail, Trim, Is_In

WITH Ada.Text_IO;         USE Ada.Text_IO;
WITH Ada.Strings;         USE Ada.Strings;
WITH Ada.Strings.Maps;    USE Ada.Strings.Maps;

PROCEDURE T33_STRINGS IS
BEGIN
   Put_Line("=== Ada.Strings ===");

   -- Length
   Put("Length(""Hello"")     = "); Put(Length("Hello"));        New_Line;
   Put("Length("""")          = "); Put(Length(""));             New_Line;
   Put("Length(""abcdefghij"")= "); Put(Length("abcdefghij"));   New_Line;

   -- Index (recherche de sous-chaine, 1-based, 0 si non trouvee)
   Put("Index(""Hello, World!"", ""World"") = ");
   Put(Index("Hello, World!", "World"));  New_Line;
   Put("Index(""abcabc"",     ""bc"")      = ");
   Put(Index("abcabc",     "bc"));         New_Line;
   Put("Index(""abcdef"",     ""xyz"")     = ");
   Put(Index("abcdef",     "xyz"));        New_Line;

   -- Count (occurrences non-chevauchantes)
   Put("Count(""Hello, World!"", ""l"")    = ");
   Put(Count("Hello, World!", "l"));       New_Line;
   Put("Count(""abcabcabc"",   ""abc"")    = ");
   Put(Count("abcabcabc",   "abc"));       New_Line;
   Put("Count(""aaaa"",       ""aa"")      = ");
   Put(Count("aaaa",       "aa"));         New_Line;

   -- Head / Tail
   Put("Head(""abc"", 5) = ["); Put(Head("abc", 5)); Put_Line("]");
   Put("Head(""Hello!"", 3) = ["); Put(Head("Hello!", 3)); Put_Line("]");
   Put("Tail(""xyz"", 5) = ["); Put(Tail("xyz", 5)); Put_Line("]");
   Put("Tail(""Hello!"", 3) = ["); Put(Tail("Hello!", 3)); Put_Line("]");

   -- Trim (Side : 0=Left, 1=Right, 2=Both)
   Put("Trim(""   hi   "", 2) = ["); Put(Trim("   hi   ", 2)); Put_Line("]");
   Put("Trim(""aaa"",       2) = ["); Put(Trim("aaa",       2)); Put_Line("]");

   -- Is_In (appartenance d'un caractere a un ensemble)
   Put("Is_In('a', ""abcdef"") = "); Put(Is_In('a', "abcdef")); New_Line;
   Put("Is_In('z', ""abcdef"") = "); Put(Is_In('z', "abcdef")); New_Line;
   Put("Is_In('5', ""01234567"") = "); Put(Is_In('5', "01234567")); New_Line;

   Put_Line("=== FIN ===");
END T33_STRINGS;
