-- test_arrays.ada : tests pour TODO 20 - operations sur tableaux (32 bits)
-- Teste : acces indexe, assignation element, attributs, types variés

with Ada.Text_IO; use Ada.Text_IO;

-- Test 1 : declaration et acces tableau simple d entiers
procedure Test_Int_Array is
   type Int_Array is array (1 .. 5) of Integer;
   A : Int_Array;
begin
   A(1) := 10;
   A(2) := 20;
   A(3) := 30;
   A(4) := 40;
   A(5) := 50;
   null;
end Test_Int_Array;

-- Test 2 : lecture d elements de tableau
procedure Test_Read_Array is
   type Tab5 is array (1 .. 5) of Integer;
   T : Tab5;
   X : Integer;
begin
   T(1) := 100;
   T(2) := 200;
   X := T(1);
   X := T(2);
   null;
end Test_Read_Array;

-- Test 3 : tableau avec bornes non-1
procedure Test_Offset_Bounds is
   type Tab_Off is array (10 .. 15) of Integer;
   B : Tab_Off;
begin
   B(10) := 1;
   B(11) := 2;
   B(15) := 6;
   null;
end Test_Offset_Bounds;

-- Test 4 : tableau de booleens (elements 1 octet)
procedure Test_Bool_Array is
   type Bool_Tab is array (1 .. 4) of Boolean;
   F : Bool_Tab;
begin
   F(1) := True;
   F(2) := False;
   F(3) := True;
   F(4) := False;
   null;
end Test_Bool_Array;

-- Test 5 : tableau de caracteres (elements 1 octet)
procedure Test_Char_Array is
   type Char_Tab is array (0 .. 3) of Character;
   C : Char_Tab;
begin
   C(0) := 'A';
   C(1) := 'B';
   C(2) := 'C';
   C(3) := 'D';
   null;
end Test_Char_Array;

-- Test 6 : attributs tableau ('FIRST, 'LAST, 'LENGTH)
procedure Test_Attributes is
   type My_Array is array (5 .. 10) of Integer;
   A : My_Array;
   Lo, Hi, Len : Integer;
begin
   Lo  := My_Array'FIRST;
   Hi  := My_Array'LAST;
   Len := My_Array'LENGTH;
   null;
end Test_Attributes;

-- Test 7 : attributs sur variable tableau
procedure Test_Var_Attributes is
   type Idx_Tab is array (1 .. 8) of Integer;
   T : Idx_Tab;
   F, L, N : Integer;
begin
   F := T'FIRST;
   L := T'LAST;
   N := T'LENGTH;
   null;
end Test_Var_Attributes;

-- Test 8 : copie element a element
procedure Test_Copy_Elements is
   type Tab3 is array (1 .. 3) of Integer;
   Src, Dst : Tab3;
begin
   Src(1) := 11;
   Src(2) := 22;
   Src(3) := 33;
   Dst(1) := Src(1);
   Dst(2) := Src(2);
   Dst(3) := Src(3);
   null;
end Test_Copy_Elements;

-- Test 9 : acces avec index variable
procedure Test_Variable_Index is
   type Tab5 is array (1 .. 5) of Integer;
   A : Tab5;
   I : Integer;
begin
   I := 3;
   A(I) := 42;
   I := A(I);
   null;
end Test_Variable_Index;

-- Test 10 : acces avec expression comme index
procedure Test_Expr_Index is
   type Tab10 is array (1 .. 10) of Integer;
   T : Tab10;
   I : Integer;
begin
   I := 2;
   T(I + 1) := 99;
   T(I * 2) := 88;
   null;
end Test_Expr_Index;

-- Test 11 : tableau dans boucle for
procedure Test_Array_Loop is
   type Tab5 is array (1 .. 5) of Integer;
   A : Tab5;
begin
   for I in 1 .. 5 loop
      A(I) := I * 10;
   end loop;
   null;
end Test_Array_Loop;

-- Test 12 : attribut SIZE
procedure Test_Size_Attr is
   type Tab4 is array (1 .. 4) of Integer;
   S : Integer;
begin
   S := Tab4'SIZE;
   null;
end Test_Size_Attr;

-- Test 13 : tableau avec borne 0
procedure Test_Zero_Based is
   type ZTab is array (0 .. 4) of Integer;
   Z : ZTab;
begin
   Z(0) := 100;
   Z(1) := 200;
   Z(4) := 500;
   null;
end Test_Zero_Based;

-- Test 14 : affectation entre elements du meme tableau
procedure Test_Self_Copy is
   type Tab3 is array (1 .. 3) of Integer;
   T : Tab3;
begin
   T(1) := 10;
   T(2) := T(1);
   T(3) := T(2);
   null;
end Test_Self_Copy;
