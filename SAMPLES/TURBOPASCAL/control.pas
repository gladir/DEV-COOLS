{ control.pas - IF/CASE, WHILE, FOR, REPEAT, GOTO (TODO 25) }
program ControlDemo;

var
  I: Integer;
  X: Integer;
  Ch: Char;

label
  Done;

begin
  { IF / ELSE }
  X := 42;
  if X > 50 then
    WriteLn('X > 50')
  else if X > 30 then
    WriteLn('X > 30')
  else
    WriteLn('X <= 30');

  { CASE }
  X := 2;
  case X of
    1: WriteLn('Un');
    2: WriteLn('Deux');
    3: WriteLn('Trois');
  else
    WriteLn('Autre');
  end;

  { FOR loop }
  WriteLn('FOR 1 to 5:');
  for I := 1 to 5 do
    Write(I, ' ');
  WriteLn;

  { FOR DOWNTO }
  WriteLn('FOR 5 downto 1:');
  for I := 5 downto 1 do
    Write(I, ' ');
  WriteLn;

  { WHILE loop }
  WriteLn('WHILE:');
  I := 1;
  while I <= 5 do
  begin
    Write(I, ' ');
    I := I + 1;
  end;
  WriteLn;

  { REPEAT..UNTIL }
  WriteLn('REPEAT:');
  I := 1;
  repeat
    Write(I, ' ');
    I := I + 1;
  until I > 5;
  WriteLn;

  { GOTO }
  WriteLn('Before GOTO');
  goto Done;
  WriteLn('This should not appear');
Done:
  WriteLn('After GOTO label');
  WriteLn('Done.');
end.
