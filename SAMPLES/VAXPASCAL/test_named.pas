{ test_named.pas - Parametres nommes, SMG$ stubs }
program test_named;

procedure display(x : integer; y : integer; label_id : integer);
begin
  writeln('Point : (', x, ', ', y, ') id=', label_id);
end;

begin
  { Appel avec parametres nommes }
  display(x := 10, y := 20, label_id := 1);
  display(y := 50, x := 30, label_id := 2);

  writeln('Test parametres nommes termine.');
end.
