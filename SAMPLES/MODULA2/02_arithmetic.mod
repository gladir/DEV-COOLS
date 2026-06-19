MODULE Arithmetic;

IMPORT InOut;

VAR
  result : INTEGER;

BEGIN
  result := 12 + 8 * 3;
  InOut.WriteString('12 + 8 * 3 = ');
  InOut.WriteInt(result, 0);
  InOut.WriteLn
END Arithmetic.
