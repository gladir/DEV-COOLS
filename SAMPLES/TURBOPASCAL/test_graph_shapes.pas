{ test_graph_shapes.pas - Test Graph shape drawing procedures }
program test_graph_shapes;
uses Graph;
begin
  { Test all shape drawing calls compile and parse correctly }

  { Line }
  Line(0, 0, 100, 100);
  WriteLn('Line(0,0,100,100) done');

  { LineTo }
  MoveTo(10, 10);
  LineTo(50, 50);
  WriteLn('LineTo(50,50) done');

  { LineRel }
  LineRel(20, 20);
  WriteLn('LineRel(20,20) done');

  { Rectangle }
  Rectangle(10, 10, 200, 150);
  WriteLn('Rectangle(10,10,200,150) done');

  { Bar }
  Bar(50, 50, 150, 100);
  WriteLn('Bar(50,50,150,100) done');

  { Bar3D }
  Bar3D(50, 50, 150, 100, 10, True);
  WriteLn('Bar3D done');

  { Circle }
  Circle(320, 240, 80);
  WriteLn('Circle(320,240,80) done');

  { Arc }
  Arc(200, 200, 0, 180, 50);
  WriteLn('Arc(200,200,0,180,50) done');

  { Ellipse }
  Ellipse(300, 300, 0, 360, 80, 40);
  WriteLn('Ellipse done');

  { FillEllipse }
  FillEllipse(400, 300, 60, 30);
  WriteLn('FillEllipse done');

  { PieSlice }
  PieSlice(100, 100, 0, 90, 60);
  WriteLn('PieSlice done');

  { Sector }
  Sector(200, 200, 0, 90, 80, 40);
  WriteLn('Sector done');

  { FloodFill }
  FloodFill(100, 100, 15);
  WriteLn('FloodFill done');

  { PutPixel }
  PutPixel(50, 50, 14);
  WriteLn('PutPixel done');

  WriteLn('OK');
end.
