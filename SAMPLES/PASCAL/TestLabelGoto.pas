program TestLabelGoto;

label
  StartLoop, EndProgram, ErrorHandler;

var
  counter: integer;

begin
  counter := 0;
  writeln('Test LABEL et GOTO');

StartLoop:
  writeln('Counter: ', counter);
  counter := counter + 1;
  
  if counter < 3 then
    goto StartLoop;
  
  if counter > 5 then
    goto ErrorHandler;
    
  writeln('Fin normale');
  goto EndProgram;

ErrorHandler:
  writeln('Erreur: compteur trop élevé');

EndProgram:
  writeln('Programme terminé');
end.