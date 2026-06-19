MODULE Comparisons;

IMPORT InOut;

VAR
  first  : INTEGER;
  second : INTEGER;

BEGIN
  first := ORD(7 < 10);
  second := ORD(7 = 10);
  InOut.WriteString('7 < 10: ');
  InOut.WriteInt(first, 0);
  InOut.WriteString(', 7 = 10: ');
  InOut.WriteInt(second, 0);
  InOut.WriteLn
END Comparisons.
