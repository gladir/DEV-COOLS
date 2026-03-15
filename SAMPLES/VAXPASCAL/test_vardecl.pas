(* test_vardecl.pas - Test TODO 09 : declarations de variables et affectations *)
(* VAX Pascal variable declarations, attributes, assignments *)

program test_vardecl(output);

const
  MAX_SIZE = 100;
  PI_APPROX := 314;

var
  x : Integer;
  y, z : Integer;
  c : Char;
  b : Boolean;
  s : VARYING [80] OF CHAR;
  arr : ARRAY[1..10] OF Integer;
  p : ^Integer;

[GLOBAL] var
  shared_count : Integer;

[VOLATILE] var
  io_flag : Integer;

value
  x := 42;

begin
  x := 10;
  y := x;
  z := x + y;
  c := 'A';
  b := true;
end.
