MODULE AbsoluteValue;

IMPORT InOut;

VAR
  value : INTEGER;

BEGIN
  value := ABS(-42);
  InOut.WriteString('ABS(-42) = ');
  InOut.WriteInt(value, 0);
  InOut.WriteLn
END AbsoluteValue.
