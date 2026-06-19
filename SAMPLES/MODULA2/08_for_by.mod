MODULE ForBy;

IMPORT InOut;

VAR
  i   : INTEGER;
  sum : INTEGER;

BEGIN
  sum := 0;
  FOR i := 2 TO 10 BY 2 DO
    INC(sum, i)
  END;
  InOut.WriteString('Somme des pairs 2..10 = ');
  InOut.WriteInt(sum, 0);
  InOut.WriteLn
END ForBy.
