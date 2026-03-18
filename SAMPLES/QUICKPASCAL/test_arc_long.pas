program TestArcLong;
uses MSGraph;
var Gd, Gm : Integer;
begin
  Gd := 0; Gm := 0;
  _SetVideoMode(_MaxResMode);
  _SetColor(15);
  _Arc(100, 100, 500, 400, 500, 250, 100, 250);
  _MoveTo(0, 240);
  _LineTo(639, 240);
  _Rectangle(_GBorder, 50, 50, 590, 430);
  _SetColor(14);
  _Arc(200, 150, 440, 350, 440, 250, 200, 250);
  _SetColor(12);
  _SetPixel(320, 240);
  _SetPixel(321, 240);
  _SetPixel(322, 240);
  _SetPixel(320, 241);
  _SetPixel(320, 242);
  Delay(15000);
end.
