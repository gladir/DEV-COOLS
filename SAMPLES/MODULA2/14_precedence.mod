MODULE Precedence;

IMPORT InOut;

VAR
  withoutParens : INTEGER;
  withParens    : INTEGER;

BEGIN
  withoutParens := 2 + 3 * 4;
  withParens := (2 + 3) * 4;
  InOut.WriteString('Priorites: ');
  InOut.WriteInt(withoutParens, 0);
  InOut.WriteString(' et ');
  InOut.WriteInt(withParens, 0);
  InOut.WriteLn
END Precedence.
