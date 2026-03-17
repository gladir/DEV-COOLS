-- test_assign.ada : Test des affectations et appels de procedure (TODO 16)
--
-- Ce fichier teste :
--   1. Assignation simple (Integer)
--   2. Assignation Boolean
--   3. Assignation Character
--   4. Assignation avec expression arithmetique
--   5. Assignation avec expression relationnelle
--   6. Assignation multiple (deux variables)
--   7. Appel de procedure sans arguments
--   8. Appel de procedure avec un argument
--   9. Appel de procedure avec plusieurs arguments
--  10. Appel qualifie (pkg.proc)
--  11. Assignation dans procedure avec parametre IN
--  12. Appel avec parametre OUT
--  13. Appel avec expression complexe
--  14. Assignation chaine/constante

WITH Ada.Text_IO;
USE Ada.Text_IO;

-- 1. Assignation simple Integer
PROCEDURE Test_Assign_Int IS
   X : Integer;
BEGIN
   X := 42;
END Test_Assign_Int;

-- 2. Assignation Boolean
PROCEDURE Test_Assign_Bool IS
   B : Boolean;
BEGIN
   B := TRUE;
END Test_Assign_Bool;

-- 3. Assignation Character
PROCEDURE Test_Assign_Char IS
   C : Character;
BEGIN
   C := 'A';
END Test_Assign_Char;

-- 4. Assignation avec expression arithmetique
PROCEDURE Test_Assign_Expr IS
   X : Integer;
   Y : Integer;
BEGIN
   X := 10;
   Y := X + 5;
END Test_Assign_Expr;

-- 5. Assignation avec expression relationnelle
PROCEDURE Test_Assign_Rel IS
   X : Integer;
   B : Boolean;
BEGIN
   X := 42;
   B := X > 0;
END Test_Assign_Rel;

-- 6. Assignation multiple
PROCEDURE Test_Assign_Multi IS
   A : Integer;
   B : Integer;
   C : Integer;
BEGIN
   A := 1;
   B := 2;
   C := A + B;
END Test_Assign_Multi;

-- Helper procedure for call tests
PROCEDURE Do_Nothing IS
BEGIN
   NULL;
END Do_Nothing;

-- Helper with one param
PROCEDURE Set_Value (X : IN Integer) IS
BEGIN
   NULL;
END Set_Value;

-- Helper with two params
PROCEDURE Add_Values (A : IN Integer; B : IN Integer) IS
BEGIN
   NULL;
END Add_Values;

-- Helper with OUT param
PROCEDURE Get_Value (X : OUT Integer) IS
BEGIN
   NULL;
END Get_Value;

-- 7. Appel de procedure sans arguments
PROCEDURE Test_Call_No_Args IS
BEGIN
   Do_Nothing;
END Test_Call_No_Args;

-- 8. Appel de procedure avec un argument
PROCEDURE Test_Call_One_Arg IS
BEGIN
   Set_Value (42);
END Test_Call_One_Arg;

-- 9. Appel de procedure avec plusieurs arguments
PROCEDURE Test_Call_Multi_Args IS
BEGIN
   Add_Values (10, 20);
END Test_Call_Multi_Args;

-- 10. Appel qualifie
PROCEDURE Test_Call_Qualified IS
BEGIN
   Ada.Text_IO.Put_Line ("Hello");
END Test_Call_Qualified;

-- 11. Assignation dans procedure avec parametre
PROCEDURE Test_Assign_Param (N : IN Integer) IS
   Result : Integer;
BEGIN
   Result := N + 1;
END Test_Assign_Param;

-- 12. Appel avec parametre OUT
PROCEDURE Test_Call_Out IS
   V : Integer;
BEGIN
   Get_Value (V);
END Test_Call_Out;

-- 13. Appel avec expression complexe
PROCEDURE Test_Call_Complex_Arg IS
   A : Integer;
   B : Integer;
BEGIN
   A := 5;
   B := 10;
   Set_Value (A + B * 2);
END Test_Call_Complex_Arg;

-- 14. Assignation avec constante
PROCEDURE Test_Assign_Const IS
   X : CONSTANT Integer := 100;
   Y : Integer;
BEGIN
   Y := X;
END Test_Assign_Const;
