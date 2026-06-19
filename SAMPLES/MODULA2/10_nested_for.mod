MODULE NestedFor;

IMPORT InOut;

VAR
  row   : INTEGER;
  col   : INTEGER;
  total : INTEGER;

BEGIN
  total := 0;
  FOR row := 1 TO 3 DO
    FOR col := 1 TO 4 DO
      INC(total)
    END
  END;
  InOut.WriteString('Cases 3 x 4 = ');
  InOut.WriteInt(total, 0);
  InOut.WriteLn
END NestedFor.
