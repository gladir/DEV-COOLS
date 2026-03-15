{ Test TODO 13 : FOR / WHILE / REPEAT / LOOP / BREAK / CONTINUE }
program test_loops(output);

var
  I : Integer;
  S : Integer;

begin
  { --- FOR / TO --- }
  S := 0;
  for I := 1 to 5 do
    S := S + I;
  WriteLn('FOR TO sum 1..5 = ');
  WriteLn(S);

  { --- FOR / DOWNTO --- }
  S := 0;
  for I := 5 downto 1 do
    S := S + I;
  WriteLn('FOR DOWNTO sum 5..1 = ');
  WriteLn(S);

  { --- FOR avec bloc BEGIN..END --- }
  S := 0;
  for I := 1 to 3 do
  begin
    S := S + I;
    S := S + 1
  end;
  WriteLn('FOR block sum = ');
  WriteLn(S);

  { --- FOR avec BY (extension VAX) --- }
  S := 0;
  for I := 0 to 10 by 2 do
    S := S + 1;
  WriteLn('FOR BY 2 count = ');
  WriteLn(S);

  { --- WHILE --- }
  I := 0;
  S := 0;
  while I < 5 do
  begin
    I := I + 1;
    S := S + I
  end;
  WriteLn('WHILE sum = ');
  WriteLn(S);

  { --- REPEAT / UNTIL --- }
  I := 0;
  S := 0;
  repeat
    I := I + 1;
    S := S + I
  until I >= 5;
  WriteLn('REPEAT sum = ');
  WriteLn(S);

  { --- LOOP / EXIT IF (extension VAX) --- }
  I := 0;
  S := 0;
  loop
    I := I + 1;
    S := S + I;
    exit if I >= 5;
  end;
  WriteLn('LOOP sum = ');
  WriteLn(S);

  { --- BREAK dans FOR --- }
  S := 0;
  for I := 1 to 100 do
  begin
    if I > 3 then
      break;
    S := S + I
  end;
  WriteLn('FOR+BREAK sum 1..3 = ');
  WriteLn(S);

  { --- CONTINUE dans FOR --- }
  S := 0;
  for I := 1 to 5 do
  begin
    if I = 3 then
      continue;
    S := S + I
  end;
  WriteLn('FOR+CONTINUE skip 3 = ');
  WriteLn(S);

  WriteLn('Tous les tests TODO 13 OK')
end.
