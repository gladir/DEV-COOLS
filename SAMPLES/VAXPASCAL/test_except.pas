{ test_except.pas - EXCEPTION, ON, CONDITION, RESIGNAL }
program test_except;

condition user_error value 200;
condition overflow_err value 201;

var
  x, y, z : integer;

begin
  { Test 1 : Division par zero }
  x := 10;
  y := 0;
  begin
    z := x div y;
    writeln('z = ', z);
  exception
    on ss$_intdiv do
    begin
      writeln('Erreur : division par zero interceptee');
      x := 99;
    end;
  end;
  writeln('Apres exception : x = ', x);

  { Test 2 : SIGNAL utilisateur }
  begin
    signal(user_error);
    writeln('Ceci ne devrait pas s''afficher');
  exception
    on user_error do
      writeln('Signal user_error intercepte');
    anyother
      writeln('Autre erreur');
  end;

  { Test 3 : Bloc sans exception }
  begin
    x := 42;
    writeln('Bloc normal : x = ', x);
  end;

  writeln('Programme termine normalement.');
end.
