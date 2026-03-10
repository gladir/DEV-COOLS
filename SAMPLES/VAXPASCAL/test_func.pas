{ test_func.pas - Functions, procedures, RETURN }
program test_func;
var
  result : integer;

function double_val(n : integer) : integer;
begin
  double_val := n * 2;
end;

function add_vals(a, b : integer) : integer;
begin
  add_vals := a + b;
end;

procedure show_val(x : integer);
begin
  writeln('val = ', x);
end;

begin
  result := double_val(21);
  writeln('double_val(21) = ', result);

  result := add_vals(10, 32);
  writeln('add_vals(10, 32) = ', result);

  show_val(result);

  writeln('Test fonctions termine.');
end.
