program TestSetPixelDiag;
uses MSGraph;
var Gd, Gm : Integer;
begin
  Gd := 0; Gm := 0;
  _SetVideoMode(_MaxResMode);
  WriteLn('SETVIDEOMODE OK');
  _SetColor(15);
  _SetPixel(100, 100);
  _SetPixel(200, 200);
  _SetPixel(300, 300);
  WriteLn('Done');
end.
