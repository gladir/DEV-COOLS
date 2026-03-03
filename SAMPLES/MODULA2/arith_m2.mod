MODULE Arithmetique;

IMPORT InOut;

CONST
  N = 10;

VAR
  i  : INTEGER;
  s  : INTEGER;

BEGIN
  s := 0;
  FOR i := 1 TO N DO
    INC(s, i)
  END;
  InOut.WriteString('Somme 1..10 = ');
  InOut.WriteInt(s, 0);
  InOut.WriteLn;
END Arithmetique.
