{ test_msgraph_draw_w.pas - Test MSGraph _w variant draw functions }
{ Compile avec : TPCW32 --quickpascal test_msgraph_draw_w.pas     }
{ Teste : _MoveTo_w, _LineTo_w, _Rectangle_w, _Rectangle_wxy,    }
{         _Ellipse_w, _Ellipse_wxy, _Arc, _Arc_wxy, _Pie,        }
{         _Pie_wxy, _FloodFill_w, _SetPixel_w                     }

Program TestMSGraphDrawW;

Uses MSGraph;

Begin
  { _MoveTo_w(wx, wy) }
  _MoveTo_w(100, 200);
  WriteLn('_MoveTo_w done');

  { _LineTo_w(wx, wy) }
  _LineTo_w(300, 400);
  WriteLn('_LineTo_w done');

  { _Rectangle_w(control, x1, y1, x2, y2) }
  _Rectangle_w(_GBorder, 10, 10, 200, 100);
  WriteLn('_Rectangle_w done');

  { _Rectangle_wxy(control, x1, y1, x2, y2) }
  _Rectangle_wxy(_GFillInterior, 20, 20, 180, 90);
  WriteLn('_Rectangle_wxy done');

  { _Ellipse_w(control, x1, y1, x2, y2) }
  _Ellipse_w(_GBorder, 50, 50, 150, 100);
  WriteLn('_Ellipse_w done');

  { _Ellipse_wxy(control, x1, y1, x2, y2) }
  _Ellipse_wxy(_GFillInterior, 60, 60, 140, 90);
  WriteLn('_Ellipse_wxy done');

  { _Arc(x1,y1,x2,y2,x3,y3,x4,y4) }
  _Arc(100, 100, 200, 200, 150, 100, 200, 150);
  WriteLn('_Arc done');

  { _Arc_wxy - stub with varargs }
  _Arc_wxy(100, 100, 200, 200, 150, 100, 200, 150);
  WriteLn('_Arc_wxy done');

  { _Pie(control, x1,y1,x2,y2,x3,y3,x4,y4) }
  _Pie(_GFillInterior, 100, 50, 300, 200, 200, 50, 300, 125);
  WriteLn('_Pie done');

  { _Pie_wxy - stub with varargs }
  _Pie_wxy(_GFillInterior, 100, 50, 300, 200, 200, 50, 300, 125);
  WriteLn('_Pie_wxy done');

  { _FloodFill_w(wx, wy, boundary) }
  _FloodFill_w(100, 100, 15);
  WriteLn('_FloodFill_w done');

  { _SetPixel_w(wx, wy) }
  _SetPixel_w(50, 50);
  WriteLn('_SetPixel_w done');

  WriteLn('OK');
End.
