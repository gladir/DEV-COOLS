program test_case_otherwise;
var
  n: integer;
begin
  case n of
    1: writeln('Un');
  otherwise
    writeln('Autre');
  end;
end.
