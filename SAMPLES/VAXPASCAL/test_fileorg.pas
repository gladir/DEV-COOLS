{ test_fileorg.pas - FILE OF, SEQUENTIAL, RELATIVE, acces direct }
program test_fileorg;
type
  StudentRec = record
    name : varying [30] of char;
    age  : integer;
    grade : char;
  end;
var
  f   : file of StudentRec;
  rec : StudentRec;
begin
  { Ecriture de records }
  open(f, 'students.dat', new);
  rec.name := 'Alice';
  rec.age := 20;
  rec.grade := 'A';
  write(f, rec);

  rec.name := 'Bob';
  rec.age := 22;
  rec.grade := 'B';
  write(f, rec);

  rec.name := 'Charlie';
  rec.age := 21;
  rec.grade := 'A';
  write(f, rec);
  close(f);

  { Relecture }
  open(f, 'students.dat', old);
  while not eof(f) do
  begin
    read(f, rec);
    writeln(rec.name, ' - age ', rec.age, ' - note ', rec.grade);
  end;
  close(f);

  writeln('Test file org termine.');
end.
