with Ada.Text_IO;
use Ada.Text_IO;

type Color is (Red, Green, Blue);
type Small_Int is range 1 .. 100;
type Vec3 is array (1 .. 3) of Integer;
type Point is record
  X : Integer;
  Y : Integer;
end record;

-- Simple integer variables
A : Integer;
B : Integer;

-- Multiple names
C, D, E : Integer;

-- Constants
Max : constant Integer := 100;
Pi_Approx : constant Integer := 3;

-- Boolean and Character
Flag : Boolean;
Ch : Character;

-- Initialized variables
Count : Integer := 42;
Ready : Boolean := True;
Init_Char : Character := 'A';

-- User-defined types
Color_Var : Color;
Small : Small_Int;

-- Array variable
Coords : Vec3;

-- Record variable
Origin : Point;

-- Float variable
Ratio : Float;

-- Multiple with init
X, Y, Z : Integer := 0;

-- Constant boolean
Debug : constant Boolean := False;

procedure Test_Objects is
begin
  null;
end Test_Objects;
