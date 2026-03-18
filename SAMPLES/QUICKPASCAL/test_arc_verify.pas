program TestArcVerify;
uses MSGraph;
var 
  Gd, Gm : Integer;
  C : LongInt;
begin
  Gd := 0; Gm := 0;
  _SetVideoMode(_MaxResMode);
  
  { Test 1: SetPixel then GetPixel }
  _SetColor(15);
  _SetPixel(100, 100);
  C := _GetPixel(100, 100);
  WriteLn('SetPixel(100,100) white, GetPixel=', C);
  
  { Test 2: LineTo then check pixel on line }
  _MoveTo(0, 200);
  _LineTo(639, 200);
  C := _GetPixel(320, 200);
  WriteLn('Line y=200, GetPixel(320,200)=', C);
  
  { Test 3: Rectangle border }
  _Rectangle(_GBorder, 50, 50, 590, 430);
  C := _GetPixel(50, 240);
  WriteLn('Rect border, GetPixel(50,240)=', C);
  
  { Test 4: Arc }
  _Arc(100, 100, 500, 400, 500, 250, 100, 250);
  C := _GetPixel(500, 250);
  WriteLn('Arc right, GetPixel(500,250)=', C);
  C := _GetPixel(300, 100);
  WriteLn('Arc top, GetPixel(300,100)=', C);
  
  WriteLn('All tests done');
end.
