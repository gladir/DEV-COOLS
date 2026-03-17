-- test_loops.ada : tests pour TODO 18 - LOOP/WHILE/FOR et EXIT
-- Fichier de test pour le compilateur ADACW32

with Ada.Text_IO; use Ada.Text_IO;

-- Test 1 : LOOP simple avec EXIT
procedure Test_Loop_Simple is
   I : Integer := 0;
begin
   loop
      I := I + 1;
      exit when I > 5;
   end loop;
end Test_Loop_Simple;

-- Test 2 : WHILE LOOP simple
procedure Test_While_Simple is
   X : Integer := 10;
begin
   while X > 0 loop
      X := X - 1;
   end loop;
end Test_While_Simple;

-- Test 3 : FOR loop forward
procedure Test_For_Forward is
   S : Integer := 0;
begin
   for I in 1 .. 10 loop
      S := S + I;
   end loop;
end Test_For_Forward;

-- Test 4 : FOR loop REVERSE
procedure Test_For_Reverse is
   S : Integer := 0;
begin
   for I in reverse 1 .. 5 loop
      S := S + I;
   end loop;
end Test_For_Reverse;

-- Test 5 : EXIT sans condition
procedure Test_Exit_Unconditional is
   N : Integer := 0;
begin
   loop
      N := N + 1;
      if N > 10 then
         exit;
      end if;
   end loop;
end Test_Exit_Unconditional;

-- Test 6 : EXIT WHEN condition
procedure Test_Exit_When is
   K : Integer := 100;
begin
   loop
      K := K - 7;
      exit when K < 0;
   end loop;
end Test_Exit_When;

-- Test 7 : Boucles imbriquees
procedure Test_Nested_Loops is
   Total : Integer := 0;
begin
   for I in 1 .. 3 loop
      for J in 1 .. 4 loop
         Total := Total + 1;
      end loop;
   end loop;
end Test_Nested_Loops;

-- Test 8 : WHILE avec condition complexe
procedure Test_While_Complex is
   A : Integer := 1;
   B : Integer := 100;
begin
   while A < B loop
      A := A + A;
   end loop;
end Test_While_Complex;

-- Test 9 : LOOP dans un IF
procedure Test_Loop_In_If is
   X : Integer := 5;
   S : Integer := 0;
begin
   if X > 0 then
      for I in 1 .. X loop
         S := S + I;
      end loop;
   else
      S := 0;
   end if;
end Test_Loop_In_If;

-- Test 10 : IF dans une LOOP
procedure Test_If_In_Loop is
   N : Integer := 0;
   Odd_Count : Integer := 0;
begin
   while N < 20 loop
      if N > 10 then
         Odd_Count := Odd_Count + 1;
      end if;
      N := N + 1;
   end loop;
end Test_If_In_Loop;

-- Test 11 : RETURN dans une fonction
function Test_Return_Value return Integer is
begin
   return 42;
end Test_Return_Value;

-- Test 12 : RETURN expression dans une fonction
function Test_Return_Expr(X : Integer) return Integer is
begin
   if X > 0 then
      return X + 1;
   else
      return 0;
   end if;
end Test_Return_Expr;

-- Test 13 : FOR avec une seule iteration
procedure Test_For_Single is
   V : Integer := 0;
begin
   for I in 5 .. 5 loop
      V := I;
   end loop;
end Test_For_Single;

-- Test 14 : CASE dans un WHILE
procedure Test_Case_In_While is
   N : Integer := 0;
   R : Integer := 0;
begin
   while N < 5 loop
      case N is
         when 0 => R := R + 10;
         when 1 => R := R + 20;
         when others => R := R + 1;
      end case;
      N := N + 1;
   end loop;
end Test_Case_In_While;
