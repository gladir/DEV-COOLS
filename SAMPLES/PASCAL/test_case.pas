program test_case;
var
  n: integer;
begin
  n := 2;
  case n of
    1: writeln('Un');
    2: writeln('Deux');
    3: writeln('Trois');
  else
    writeln('Autre');
  end;
end.
