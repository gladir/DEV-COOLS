{ test_io.pas - I/O, TTY, TTYOUTPUT, OPEN/CLOSE, status }
program test_io(input, output);
var
  f      : text;
  line   : varying [256] of char;
  status : integer;
begin
  { Ecriture simple sur sortie standard }
  writeln('Test I/O');
  write('Valeur : ');
  writeln(42);

  { Ouverture d un fichier en ecriture }
  open(f, 'test_output.txt', new);
  writeln(f, 'Ligne 1');
  writeln(f, 'Ligne 2');
  writeln(f, 'Ligne 3');
  close(f);
  writeln('Fichier ecrit.');

  { Reopening en lecture }
  open(f, 'test_output.txt', old);
  while not eof(f) do
  begin
    readln(f, line);
    writeln('Lu : ', line);
  end;
  close(f);

  writeln('Test I/O termine.');
end.
