MODULE Countdown;

IMPORT InOut;

VAR
  i : INTEGER;

BEGIN
  FOR i := 5 TO 1 BY -1 DO
    InOut.WriteInt(i, 0);
    InOut.WriteChar(' ')
  END;
  InOut.WriteLn
END Countdown.
