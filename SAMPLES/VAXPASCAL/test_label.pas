{ test_label.pas - LABEL, GOTO, GOTO non-local }
program test_label;
label 100, 200, done;
var
  i : integer;
begin
  i := 0;

100:
  i := i + 1;
  if i < 5 then
    goto 100;
  writeln('Boucle goto : i = ', i);

  goto 200;
  writeln('Ceci ne s''affiche pas');

200:
  writeln('Apres goto 200');

  goto done;
  writeln('Ceci non plus');

done:
  writeln('Programme termine.');
end.
