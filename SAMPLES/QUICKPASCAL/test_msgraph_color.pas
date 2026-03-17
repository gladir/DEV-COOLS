{ test_msgraph_color.pas - Test MSGraph color functions (QuickPascal mode) }
program test_msgraph_color;
uses MSGraph;
begin
  { Test _SetColor / _GetColor }
  _SetColor(12);
  WriteLn('After _SetColor(12): _GetColor=', _GetColor);

  { Test _SetBkColor / _GetBkColor }
  _SetBkColor(4);
  WriteLn('After _SetBkColor(4): _GetBkColor=', _GetBkColor);

  { Test _SetLineStyle / _GetLineStyle }
  _SetLineStyle(3);
  WriteLn('After _SetLineStyle(3): _GetLineStyle=', _GetLineStyle);

  { Test _SetWriteMode / _GetWriteMode }
  _SetWriteMode(1);
  WriteLn('After _SetWriteMode(1): _GetWriteMode=', _GetWriteMode);

  { Test _GrStatus }
  WriteLn('_GrStatus=', _GrStatus);

  WriteLn('OK');
end.
