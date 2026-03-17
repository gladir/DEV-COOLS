-- test_emitter.ada : tests pour TODO 23 - generation en-tete ASM et segment .DATA
-- Teste : EmitHeader, EmitDataSeg (variables globales, tableaux, records,
--         chaines litterales, tampons runtime)

with Ada.Text_IO; use Ada.Text_IO;

-- Test 1 : variable globale Integer
procedure Test_Global_Int is
   G : Integer;
begin
   G := 42;
   Put(G);
   New_Line;
end Test_Global_Int;

-- Test 2 : variable globale Boolean
procedure Test_Global_Bool is
   B : Boolean;
begin
   B := True;
   Put(B);
   New_Line;
end Test_Global_Bool;

-- Test 3 : variable globale Character
procedure Test_Global_Char is
   C : Character;
begin
   C := 'Z';
   Put(C);
   New_Line;
end Test_Global_Char;

-- Test 4 : constante entiere
procedure Test_Const_Int is
   Max : constant Integer := 100;
begin
   Put(Max);
   New_Line;
end Test_Const_Int;

-- Test 5 : chaines litterales multiples
procedure Test_String_Lits is
begin
   Put_Line("Alpha");
   Put_Line("Beta");
   Put_Line("Gamma");
end Test_String_Lits;

-- Test 6 : tableau local
procedure Test_Array_Local is
   type Arr5 is array(1..5) of Integer;
   T : Arr5;
begin
   T(1) := 10;
   T(5) := 50;
   Put(T(1));
   New_Line;
end Test_Array_Local;

-- Test 7 : record local
procedure Test_Record_Local is
   type Point is record
      X : Integer;
      Y : Integer;
   end record;
   P : Point;
begin
   P.X := 100;
   P.Y := 200;
   Put(P.X);
   New_Line;
end Test_Record_Local;

-- Test 8 : chaine vide
procedure Test_Empty_String is
begin
   Put_Line("");
end Test_Empty_String;

-- Test 9 : procedure sans variable (code minimal)
procedure Test_Minimal is
begin
   null;
end Test_Minimal;

-- Test 10 : deux variables locales + affichage
procedure Test_Two_Vars is
   A : Integer;
   B : Integer;
begin
   A := 1;
   B := 2;
   Put(A);
   Put(B);
   New_Line;
end Test_Two_Vars;

-- Test 11 : variable initialisee
procedure Test_Init_Var is
   N : Integer := 99;
begin
   Put(N);
   New_Line;
end Test_Init_Var;

-- Test 12 : Put_Line avec entier litteral
procedure Test_Put_Int_Lit is
begin
   Put_Line(777);
end Test_Put_Int_Lit;

-- Test 13 : multiple New_Line
procedure Test_Multi_Newline is
begin
   Put("Debut");
   New_Line(2);
   Put("Fin");
   New_Line;
end Test_Multi_Newline;

-- Test 14 : procedure avec parametre
procedure Test_With_Param(X : Integer) is
begin
   Put(X);
   New_Line;
end Test_With_Param;
