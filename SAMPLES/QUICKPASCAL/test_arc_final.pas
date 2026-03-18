program TestArcFinal;
uses MSGraph;
var Gd, Gm : Integer;
begin
  Gd := 0; Gm := 0;
  _SetVideoMode(_MaxResMode);
  _SetColor(15);
  { Dessiner un arc : bounding rect (100,100)-(500,400), start (500,250), end (100,250) }
  _Arc(100, 100, 500, 400, 500, 250, 100, 250);
  { Dessiner une ligne }
  _MoveTo(0, 240);
  _LineTo(639, 240);
  { Dessiner un rectangle }
  _Rectangle(_GBorder, 50, 50, 590, 430);
  { Attendre }
  Delay(5000);
end.
