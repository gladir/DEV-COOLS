program test_case_else;
var
  n: integer;
begin
  case n of
    1: writeln('Un');
  else
    writeln('Autre');
  end;
end.
