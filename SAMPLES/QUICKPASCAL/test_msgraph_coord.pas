{ test_msgraph_coord.pas - Test MSGraph coordinate functions }
{ Compile avec : TPCW32 --quickpascal test_msgraph_coord.pas }
{ Teste : _SetViewOrg, _SetWindow, _GetViewCoord,            }
{         _GetViewCoord_W, _GetViewCoord_WXY, _GetPhysCoord,  }
{         _GetWindowCoord, _GetCurrentPosition,                }
{         _GetCurrentPosition_WXY                              }

Program TestMSGraphCoord;

Uses MSGraph;

Var
  X, Y : Integer;

Begin
  { _SetViewOrg(x, y, var org) }
  _SetViewOrg(100, 100, X);
  WriteLn('_SetViewOrg(100,100) done');

  { _SetWindow(finvert, x1, y1, x2, y2) }
  _SetWindow(0, 0, 0, 639, 479);
  WriteLn('_SetWindow done');

  { _GetViewCoord(x, y, ...) }
  _GetViewCoord(100, 200);
  WriteLn('_GetViewCoord done');

  { _GetViewCoord_W(x, y, ...) }
  _GetViewCoord_W(100, 200);
  WriteLn('_GetViewCoord_W done');

  { _GetViewCoord_WXY(x, y, ...) }
  _GetViewCoord_WXY(100, 200);
  WriteLn('_GetViewCoord_WXY done');

  { _GetPhysCoord(x, y, var result) }
  _GetPhysCoord(100, 200, X);
  WriteLn('_GetPhysCoord done');

  { _GetWindowCoord(x, y, var result) }
  _GetWindowCoord(100, 200, X);
  WriteLn('_GetWindowCoord done');

  { _GetCurrentPosition(var xy) }
  _GetCurrentPosition(X);
  WriteLn('_GetCurrentPosition done');

  { _GetCurrentPosition_WXY(var wxy) }
  _GetCurrentPosition_WXY(X);
  WriteLn('_GetCurrentPosition_WXY done');

  WriteLn('OK');
End.
