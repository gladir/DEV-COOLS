MODULE Constants;

IMPORT InOut;

CONST
  Width = 7;
  Height = 4;

VAR
  area : INTEGER;

BEGIN
  area := Width * Height;
  InOut.WriteString('Aire du rectangle = ');
  InOut.WriteInt(area, 0);
  InOut.WriteLn
END Constants.
