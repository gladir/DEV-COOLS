program TestGraphFinal;
uses MSGraph;
var Gd, Gm : Integer;
begin
  Gd := 0; Gm := 0;
  _SetVideoMode(_MaxResMode);
  
  { Rectangle blanc }
  _SetColor(15);
  _Rectangle(_GBorder, 10, 10, 630, 470);
  
  { Arc blanc (demi-cercle haut) }
  _Arc(100, 100, 540, 380, 540, 240, 100, 240);
  
  { Arc jaune (demi-cercle bas) }
  _SetColor(14);
  _Arc(100, 100, 540, 380, 100, 240, 540, 240);
  
  { Lignes croisees }
  _SetColor(12);
  _MoveTo(10, 10);
  _LineTo(630, 470);
  _MoveTo(630, 10);
  _LineTo(10, 470);
  
  { Cercle - TP Graph style }
  _SetColor(10);
  _SetPixel(320, 240);
  _SetPixel(319, 240);
  _SetPixel(321, 240);
  _SetPixel(320, 239);
  _SetPixel(320, 241);
  
  Delay(8000);
end.
