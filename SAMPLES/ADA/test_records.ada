-- test_records.ada : tests pour TODO 21 - operations sur records (32 bits)
-- Teste : acces champ, assignation champ, agregat, imbrique, attributs

with Ada.Text_IO; use Ada.Text_IO;

-- Test 1 : declaration et assignation de champs simples
procedure Test_Simple_Record is
   type Point is record
      X : Integer;
      Y : Integer;
   end record;
   P : Point;
begin
   P.X := 10;
   P.Y := 20;
   null;
end Test_Simple_Record;

-- Test 2 : lecture de champs record
procedure Test_Read_Fields is
   type Pair is record
      A : Integer;
      B : Integer;
   end record;
   R : Pair;
   X : Integer;
begin
   R.A := 100;
   R.B := 200;
   X := R.A;
   X := R.B;
   null;
end Test_Read_Fields;

-- Test 3 : record avec types mixtes (Integer, Boolean, Character)
procedure Test_Mixed_Types is
   type Person is record
      Age    : Integer;
      Active : Boolean;
      Init   : Character;
   end record;
   P : Person;
begin
   P.Age    := 25;
   P.Active := True;
   P.Init   := 'J';
   null;
end Test_Mixed_Types;

-- Test 4 : copie de champ a champ
procedure Test_Copy_Fields is
   type Vec2 is record
      X : Integer;
      Y : Integer;
   end record;
   A, B : Vec2;
begin
   A.X := 1;
   A.Y := 2;
   B.X := A.X;
   B.Y := A.Y;
   null;
end Test_Copy_Fields;

-- Test 5 : record avec 4 champs
procedure Test_Four_Fields is
   type Rect is record
      X1 : Integer;
      Y1 : Integer;
      X2 : Integer;
      Y2 : Integer;
   end record;
   R : Rect;
begin
   R.X1 := 0;
   R.Y1 := 0;
   R.X2 := 100;
   R.Y2 := 50;
   null;
end Test_Four_Fields;

-- Test 6 : affectation agregat record
procedure Test_Aggregate is
   type Color is record
      R : Integer;
      G : Integer;
      B : Integer;
   end record;
   C : Color;
begin
   C := (R => 255, G => 128, B => 0);
   null;
end Test_Aggregate;

-- Test 7 : attribut SIZE sur type record
procedure Test_Size_Attr is
   type Small is record
      X : Integer;
      Y : Integer;
   end record;
   S : Integer;
begin
   S := Small'SIZE;
   null;
end Test_Size_Attr;

-- Test 8 : champ record dans expression
procedure Test_Field_Expr is
   type Coord is record
      X : Integer;
      Y : Integer;
   end record;
   P : Coord;
   Sum : Integer;
begin
   P.X := 3;
   P.Y := 4;
   Sum := P.X + P.Y;
   null;
end Test_Field_Expr;

-- Test 9 : record imbrique (nested record)
procedure Test_Nested_Record is
   type Inner is record
      Val : Integer;
   end record;
   type Outer is record
      Tag  : Integer;
      Data : Inner;
   end record;
   O : Outer;
begin
   O.Tag := 42;
   O.Data.Val := 99;
   null;
end Test_Nested_Record;

-- Test 10 : lecture champ imbrique
procedure Test_Read_Nested is
   type Sub is record
      N : Integer;
   end record;
   type Main is record
      Id  : Integer;
      Rec : Sub;
   end record;
   M : Main;
   X : Integer;
begin
   M.Id := 1;
   M.Rec.N := 77;
   X := M.Rec.N;
   null;
end Test_Read_Nested;

-- Test 11 : record avec champ Boolean
procedure Test_Bool_Field is
   type Flags is record
      Visible : Boolean;
      Enabled : Boolean;
      Count   : Integer;
   end record;
   F : Flags;
begin
   F.Visible := True;
   F.Enabled := False;
   F.Count   := 5;
   null;
end Test_Bool_Field;

-- Test 12 : multiple records du meme type
procedure Test_Multi_Records is
   type Vec is record
      X : Integer;
      Y : Integer;
   end record;
   V1, V2, V3 : Vec;
begin
   V1.X := 1; V1.Y := 2;
   V2.X := 3; V2.Y := 4;
   V3.X := V1.X + V2.X;
   V3.Y := V1.Y + V2.Y;
   null;
end Test_Multi_Records;

-- Test 13 : record avec champ Character
procedure Test_Char_Field is
   type Entry is record
      Code : Character;
      Val  : Integer;
   end record;
   E : Entry;
begin
   E.Code := 'A';
   E.Val  := 65;
   null;
end Test_Char_Field;

-- Test 14 : assignation champ avec expression complexe
procedure Test_Complex_Assign is
   type Data is record
      A : Integer;
      B : Integer;
      C : Integer;
   end record;
   D : Data;
begin
   D.A := 10;
   D.B := D.A * 2;
   D.C := D.A + D.B;
   null;
end Test_Complex_Assign;
