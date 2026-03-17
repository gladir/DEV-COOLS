{ test_msgraph_pixel.pas - Test MSGraph pixel/fill/arc info functions }
{ Compile avec : TPCW32 --quickpascal test_msgraph_pixel.pas          }
{ Teste : _GetPixel, _GetPixel_w, _GetFillMask, _GetArcInfo           }

Program TestMSGraphPixel;

Uses MSGraph;

Var
  R : Integer;
  A, B, C : Integer;

Begin
  { _GetPixel(x, y) }
  R := _GetPixel(100, 100);
  WriteLn('_GetPixel(100,100)=', R);

  { _GetPixel_w(wx, wy) }
  R := _GetPixel_w(100, 100);
  WriteLn('_GetPixel_w(100,100)=', R);

  { _GetFillMask(var mask) }
  R := _GetFillMask(A);
  WriteLn('_GetFillMask=', R);

  { _GetArcInfo(var SP, EP, FP) }
  R := _GetArcInfo(A, B, C);
  WriteLn('_GetArcInfo=', R);

  WriteLn('OK');
End.
