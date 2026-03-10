PROGRAM test_enum(OUTPUT);

{ Test enumerations and subranges (TODO 17) }

TYPE
  Color = (Red, Green, Blue, Yellow, White);
  Direction = (North, South, East, West);
  SmallInt = 0..255;
  SignedRange = -10..10;
  DayOfWeek = (Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday);

VAR
  c : Color;
  d : Direction;
  n : SmallInt;
  r : SignedRange;
  day : DayOfWeek;
  i : INTEGER;

BEGIN
  c := Red;
  WRITELN('Red = ', ORD(c));
  c := Blue;
  WRITELN('Blue = ', ORD(c));
  c := SUCC(c);
  WRITELN('After Blue = ', ORD(c));
  c := PRED(c);
  WRITELN('Back to Blue = ', ORD(c));

  d := North;
  WRITELN('North = ', ORD(d));
  d := West;
  WRITELN('West = ', ORD(d));

  n := 42;
  WRITELN('n = ', n);

  r := 5;
  WRITELN('r = ', r);

  i := FIRST(Color);
  WRITELN('FIRST(Color) = ', i);
  i := LAST(Color);
  WRITELN('LAST(Color) = ', i);

  i := FIRST(SmallInt);
  WRITELN('FIRST(SmallInt) = ', i);
  i := LAST(SmallInt);
  WRITELN('LAST(SmallInt) = ', i);

  i := FIRST(SignedRange);
  WRITELN('FIRST(SignedRange) = ', i);
  i := LAST(SignedRange);
  WRITELN('LAST(SignedRange) = ', i);

  day := Monday;
  WRITELN('Monday = ', ORD(day));
  day := Sunday;
  WRITELN('Sunday = ', ORD(day))
END.
