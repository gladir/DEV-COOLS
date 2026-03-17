-- test_textio.ada : tests pour TODO 22 - stubs Ada.Text_IO (sortie console Win32)
-- Teste : Put type-dispatched, Put_Line, New_Line, Set_Col, Get, Get_Line

with Ada.Text_IO; use Ada.Text_IO;

-- Test 1 : Put_Line avec chaine litterale
procedure Test_Put_Line_String is
begin
   Put_Line("Hello, World!");
end Test_Put_Line_String;

-- Test 2 : Put avec chaine litterale
procedure Test_Put_String is
begin
   Put("Bonjour ");
   Put("Ada");
   New_Line;
end Test_Put_String;

-- Test 3 : Put avec entier (variable)
procedure Test_Put_Integer is
   X : Integer;
begin
   X := 42;
   Put(X);
   New_Line;
end Test_Put_Integer;

-- Test 4 : Put_Line avec variable entier
procedure Test_Put_Line_Int_Var is
   N : Integer;
begin
   N := 100;
   Put_Line(N);
end Test_Put_Line_Int_Var;

-- Test 5 : Put avec caractere (variable)
procedure Test_Put_Char is
   C : Character;
begin
   C := 'A';
   Put(C);
   New_Line;
end Test_Put_Char;

-- Test 6 : New_Line sans argument (defaut 1)
procedure Test_New_Line_Default is
begin
   Put("Ligne 1");
   New_Line;
   Put("Ligne 2");
   New_Line;
end Test_New_Line_Default;

-- Test 7 : New_Line avec argument
procedure Test_New_Line_Count is
begin
   Put("Avant");
   New_Line(3);
   Put("Apres");
   New_Line;
end Test_New_Line_Count;

-- Test 8 : Set_Col (stub avec avertissement)
procedure Test_Set_Col is
begin
   Set_Col(10);
   Put("Colonne 10");
   New_Line;
end Test_Set_Col;

-- Test 9 : Put avec boolean True
procedure Test_Put_Boolean is
   B : Boolean;
begin
   B := True;
   Put(B);
   New_Line;
end Test_Put_Boolean;

-- Test 10 : Put avec expression entiere
procedure Test_Put_Expr is
   X : Integer;
   Y : Integer;
begin
   X := 10;
   Y := 20;
   Put(X);
   New_Line;
end Test_Put_Expr;

-- Test 11 : Put_Line avec entier litteral
procedure Test_Put_Line_Int_Lit is
begin
   Put_Line(123);
end Test_Put_Line_Int_Lit;

-- Test 12 : forme qualifiee Ada.Text_IO.Put_Line
procedure Test_Qualified_Name is
begin
   Ada.Text_IO.Put_Line("Qualified call");
   Ada.Text_IO.New_Line;
end Test_Qualified_Name;

-- Test 13 : Get avec variable char (lecture console)
procedure Test_Get_Char is
   C : Character;
begin
   Get(C);
   Put(C);
   New_Line;
end Test_Get_Char;

-- Test 14 : Put_Line sans argument (juste new line)
procedure Test_Put_Line_Empty is
begin
   Put("Before");
   Put_Line("");
   Put("After");
   New_Line;
end Test_Put_Line_Empty;
