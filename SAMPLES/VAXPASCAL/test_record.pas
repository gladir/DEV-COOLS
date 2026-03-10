{ test_record.pas - Records, WITH, variant, POS, ALIGNED }
program test_record;
type
  Point = record
    x, y : integer;
  end;
  Person = record
    name : varying [40] of char;
    age  : integer;
  end;
  Shape = record
    kind : integer;
    case integer of
      1 : (radius : integer);
      2 : (width, height : integer);
  end;
var
  p     : Point;
  pers  : Person;
  s     : Shape;
begin
  p.x := 10;
  p.y := 20;
  writeln('Point : (', p.x, ', ', p.y, ')');

  with pers do
  begin
    name := 'Alice';
    age := 30;
  end;
  writeln('Person : ', pers.name, ', age ', pers.age);

  s.kind := 2;
  s.width := 100;
  s.height := 50;
  writeln('Shape : ', s.width, ' x ', s.height);
end.
