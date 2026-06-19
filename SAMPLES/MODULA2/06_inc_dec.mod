MODULE IncrementDecrement;

IMPORT InOut;

VAR
  counter : INTEGER;

BEGIN
  counter := 10;
  INC(counter);
  INC(counter, 5);
  DEC(counter, 3);
  InOut.WriteString('Compteur = ');
  InOut.WriteInt(counter, 0);
  InOut.WriteLn
END IncrementDecrement.
