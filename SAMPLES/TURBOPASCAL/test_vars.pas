{ test_vars.pas - Test des variables et affectations (TODO 09) }
program TestVars;

var
  counter: Integer;
  name: String;
  flag: Boolean;
  value: Real;
  ch: Char;
  w: Word;
  b: Byte;
  si: ShortInt;
  li: LongInt;
  sg: Single;
  db: Double;
  p: Pointer;
  items: Array[1..10] of Integer;
  grades: Array[0..4] of Real;
  colors: Set of Byte;
  msg: String[80];

const
  MaxVal: Integer = 100;
  MinVal: Integer = 0;
  Greeting: String = 'Hello';

begin
  { Affectations simples }
  counter := 42;
  name := 'World';
  flag := True;
  value := 3.14;
  ch := 'A';
  w := 1000;
  b := 255;
  si := -50;
  li := 100000;

  WriteLn('counter = ', counter);
  WriteLn('name = ', name);

  { Affectation avec expression }
  counter := counter + 1;
  value := value * 2;
  name := 'Hello ' + name;

  WriteLn('counter+1 = ', counter);
  WriteLn('value*2 = ', value);
  WriteLn(name);

  { Boucle FOR TO }
  for counter := 1 to 5 do
    WriteLn('i = ', counter);

  { Boucle FOR DOWNTO }
  for counter := 3 downto 1 do
    WriteLn('down i = ', counter);

  { Boucle WHILE }
  counter := 0;
  while counter < 3 do
  begin
    WriteLn('while ', counter);
    counter := counter + 1;
  end;

  { Boucle REPEAT UNTIL }
  counter := 0;
  repeat
    WriteLn('repeat ', counter);
    counter := counter + 1;
  until counter >= 3;

  { CASE }
  counter := 2;
  case counter of
    1: WriteLn('one');
    2: WriteLn('two');
    3: WriteLn('three');
  else
    WriteLn('other');
  end;

  WriteLn('Done.');
end.
