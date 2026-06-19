MODULE OddBoolean;

IMPORT InOut;

VAR
  oddValue : BOOLEAN;
  numeric  : INTEGER;

BEGIN
  oddValue := ODD(17);
  numeric := ORD(oddValue);
  InOut.WriteString('ODD(17) = ');
  InOut.WriteInt(numeric, 0);
  InOut.WriteLn
END OddBoolean.
