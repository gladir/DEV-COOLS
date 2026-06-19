MODULE ForSum;

IMPORT InOut;

VAR
  i   : INTEGER;
  sum : INTEGER;

BEGIN
  sum := 0;
  FOR i := 1 TO 20 DO
    INC(sum, i)
  END;
  InOut.WriteString('Somme 1..20 = ');
  InOut.WriteInt(sum, 0);
  InOut.WriteLn
END ForSum.
