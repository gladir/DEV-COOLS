-- test lexeur Ada
with Ada.Text_IO; use Ada.Text_IO;
procedure Test is
   X : Integer := 42;
   Pi : constant Float := 3.14159;
   C : Character := 'A';
begin
   X := X + 16#FF# + 2#1010#;
end Test;
