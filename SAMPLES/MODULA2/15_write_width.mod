MODULE WriteWidth;

IMPORT InOut;

VAR
  value : INTEGER;

BEGIN
  value := 42;
  InOut.WriteString('Largeur 6: >');
  InOut.WriteInt(value, 6);
  InOut.WriteChar('<');
  InOut.WriteLn
END WriteWidth.
