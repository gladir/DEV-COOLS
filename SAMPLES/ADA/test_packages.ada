-- test_packages.ada
-- Test du TODO 14 : PACKAGE SPEC ET BODY
-- Ce fichier teste la reconnaissance des packages Ada

with Ada.Text_IO; use Ada.Text_IO;

-- 1. Package spec simple
package Math_Utils is
   function Square(X : Integer) return Integer;
   function Double(X : Integer) return Integer;
end Math_Utils;

-- 2. Package body simple
package body Math_Utils is
   function Square(X : Integer) return Integer is
   begin
      return X * X;
   end Square;

   function Double(X : Integer) return Integer is
   begin
      return X + X;
   end Double;
end Math_Utils;

-- 3. Package spec avec section PRIVATE
package My_Stack is
   procedure Push(Val : Integer);
   procedure Pop(Val : out Integer);
   function Is_Empty return Boolean;
private
   Max_Size : constant Integer := 100;
   Top      : Integer := 0;
end My_Stack;

-- 4. Package body avec bloc d initialisation
package body My_Stack is
   Top_Idx : Integer := 0;

   procedure Push(Val : Integer) is
   begin
      Top_Idx := Top_Idx + 1;
   end Push;

   procedure Pop(Val : out Integer) is
   begin
      Top_Idx := Top_Idx - 1;
   end Pop;

   function Is_Empty return Boolean is
   begin
      return Top_Idx = 0;
   end Is_Empty;

begin
   -- Initialisation du package
   Top_Idx := 0;
end My_Stack;

-- 5. Package spec avec types et constantes
package Constants is
   type Direction is (North, South, East, West);
   Max_Items : constant Integer := 256;
end Constants;

-- 6. Package spec avec sous-types
package Bounded is
   subtype Small_Int is Integer range 0 .. 255;
   subtype Positive_Int is Integer range 1 .. 2147483647;
   procedure Process(X : Small_Int);
end Bounded;

-- 7. Package body minimal
package body Bounded is
   procedure Process(X : Small_Int) is
   begin
      null;
   end Process;
end Bounded;

-- 8. Package spec vide (juste END)
package Empty_Pkg is
end Empty_Pkg;

-- 9. Package body vide (sans bloc BEGIN)
package body Empty_Pkg is
end Empty_Pkg;

-- 10. Package avec procedure et function melangees
package Mixed is
   procedure Do_Something;
   function Get_Value return Integer;
   type Color is (Red, Green, Blue);
end Mixed;

-- Programme principal
procedure Test_Packages is
begin
   null;
end Test_Packages;
