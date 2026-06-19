MODULE DivMod;

IMPORT InOut;

VAR
  quotient  : INTEGER;
  remainder : INTEGER;

BEGIN
  quotient := 29 DIV 5;
  remainder := 29 MOD 5;
  InOut.WriteString('29 DIV 5 = ');
  InOut.WriteInt(quotient, 0);
  InOut.WriteString(', reste ');
  InOut.WriteInt(remainder, 0);
  InOut.WriteLn
END DivMod.
