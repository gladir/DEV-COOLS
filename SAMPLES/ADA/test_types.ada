with Ada.Text_IO;
use Ada.Text_IO;

type Color is (Red, Green, Blue, Yellow, White, Black);
type Day is (Mon, Tue, Wed, Thu, Fri, Sat, Sun);
type Small_Int is range 1 .. 100;
type Offset is range -128 .. 127;
type Vect is array (1 .. 10) of Integer;
type Matrix_Row is array (1 .. 5) of Float;
type Point is record
  X : Integer;
  Y : Integer;
end record;
type Pixel is record
  Pos : Point;
  Col : Color;
end record;
type Int_Ptr is access Integer;
type New_Int is new Integer;
subtype Percent is Integer range 0 .. 100;
subtype Weekday is Day range Mon .. Fri;
subtype My_Float is Float;

procedure Test_Types is
begin
  null;
end Test_Types;
