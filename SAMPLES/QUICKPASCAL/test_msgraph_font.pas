{ test_msgraph_font.pas - Test MSGraph font functions }
{ Compile avec : TPCW32 --quickpascal test_msgraph_font.pas }
{ Teste : _GetFontInfo, _SetGTextVector, _GetGTextVector     }

Program TestMSGraphFont;

Uses MSGraph;

Var
  R : Integer;
  X, Y : Integer;

Begin
  { _GetFontInfo(var FInfo) }
  R := _GetFontInfo(X);
  WriteLn('_GetFontInfo=', R);

  { _SetGTextVector(x, y) }
  _SetGTextVector(1, 0);
  WriteLn('_SetGTextVector(1,0) done');

  { _GetGTextVector(var x, y) }
  _GetGTextVector(X, Y);
  WriteLn('_GetGTextVector done');

  WriteLn('OK');
End.
