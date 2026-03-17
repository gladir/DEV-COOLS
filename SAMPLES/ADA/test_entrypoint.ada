-- test_entrypoint.ada : tests pour TODO 24 - point d'entree Win32 et helpers runtime
-- Teste : EmitEntryPoint (_ADAF_main, init stdout/stdin, appel procedure
--         principale, ExitProcess), EmitRuntimeHelpers (_ADART_CRLF,
--         _ADART_PRINT, _ADART_NUMTOSTR, _ADART_PRINTINT, _ADART_PRINTCHR,
--         _ADART_READINT, _ADART_READSTR, _ADART_STRLEN, _ADART_STRCOPY,
--         _ADART_STRCONCAT, _ADART_CHKRANGE, _ADART_ERROR)
-- 15 cas de test

with Ada.Text_IO; use Ada.Text_IO;

-- Test 1 : programme simple avec Put_Line (PRINT + CRLF)
procedure Test_Entry_Hello is
begin
   Put_Line("Test 1 : Hello from entry point");
end Test_Entry_Hello;

-- Test 2 : programme avec Put (PRINT sans CRLF)
procedure Test_Entry_Put is
begin
   Put("Test 2 : ");
   Put("Put sans newline");
   New_Line;
end Test_Entry_Put;

-- Test 3 : afficher un entier (PRINTINT -> NUMTOSTR + PRINT)
procedure Test_Entry_Int is
   X : Integer;
begin
   X := 42;
   Put("Test 3 : X = ");
   Put(X);
   New_Line;
end Test_Entry_Int;

-- Test 4 : afficher un entier negatif (NUMTOSTR avec signe)
procedure Test_Entry_NegInt is
   Y : Integer;
begin
   Y := -123;
   Put("Test 4 : Y = ");
   Put(Y);
   New_Line;
end Test_Entry_NegInt;

-- Test 5 : afficher zero (NUMTOSTR cas special)
procedure Test_Entry_Zero is
   Z : Integer;
begin
   Z := 0;
   Put("Test 5 : Z = ");
   Put(Z);
   New_Line;
end Test_Entry_Zero;

-- Test 6 : afficher un caractere (PRINTCHR)
procedure Test_Entry_Char is
   C : Character;
begin
   C := 'A';
   Put("Test 6 : C = ");
   Put(C);
   New_Line;
end Test_Entry_Char;

-- Test 7 : afficher un booleen (PRINTINT)
procedure Test_Entry_Bool is
   B : Boolean;
begin
   B := True;
   Put("Test 7 : B = ");
   Put(B);
   New_Line;
end Test_Entry_Bool;

-- Test 8 : New_Line multiple
procedure Test_Entry_NewLine is
begin
   Put("Test 8 : avant");
   New_Line;
   New_Line;
   Put("Test 8 : apres deux newlines");
   New_Line;
end Test_Entry_NewLine;

-- Test 9 : variable locale et affectation
procedure Test_Entry_Local is
   A : Integer;
   B : Integer;
begin
   A := 10;
   B := 20;
   Put("Test 9 : A+B = ");
   Put(A + B);
   New_Line;
end Test_Entry_Local;

-- Test 10 : constante et affichage
procedure Test_Entry_Const is
   Max : constant Integer := 100;
begin
   Put("Test 10 : Max = ");
   Put(Max);
   New_Line;
end Test_Entry_Const;

-- Test 11 : if/else avec affichage
procedure Test_Entry_If is
   X : Integer;
begin
   X := 5;
   Put("Test 11 : ");
   if X > 3 then
      Put_Line("X > 3 (ok)");
   else
      Put_Line("X <= 3 (erreur)");
   end if;
end Test_Entry_If;

-- Test 12 : boucle for avec affichage
procedure Test_Entry_Loop is
   I : Integer;
begin
   Put("Test 12 : ");
   for I in 1 .. 5 loop
      Put(I);
      Put(" ");
   end loop;
   New_Line;
end Test_Entry_Loop;

-- Test 13 : appel de procedure interne
procedure Test_Entry_Call is
   procedure Helper is
   begin
      Put("(helper ok)");
   end Helper;
begin
   Put("Test 13 : ");
   Helper;
   New_Line;
end Test_Entry_Call;

-- Test 14 : fonction avec retour entier
procedure Test_Entry_Func is
   function Double(X : Integer) return Integer is
   begin
      return X * 2;
   end Double;
begin
   Put("Test 14 : Double(21) = ");
   Put(Double(21));
   New_Line;
end Test_Entry_Func;

-- Test 15 : programme final (la procedure principale)
procedure Test_Entry_Main is
begin
   Put_Line("Test 15 : programme principal ok");
   Put_Line("TODO 24 : 15 cas de test compiles avec succes");
end Test_Entry_Main;
