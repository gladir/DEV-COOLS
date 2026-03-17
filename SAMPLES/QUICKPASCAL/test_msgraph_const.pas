{ test_msgraph_const.pas - Test MSGraph constants (QuickPascal mode) }
program test_msgraph_const;
uses MSGraph;
begin
  { Mode video constants }
  WriteLn('_DefaultMode=', _DefaultMode);
  WriteLn('_MaxResMode=', _MaxResMode);
  WriteLn('_MaxColorMode=', _MaxColorMode);
  WriteLn('_TextBW40=', _TextBW40);
  WriteLn('_TextC80=', _TextC80);
  WriteLn('_VRes16Color=', _VRes16Color);
  WriteLn('_MRes256Color=', _MRes256Color);

  { Action constants }
  WriteLn('_GBorder=', _GBorder);
  WriteLn('_GFillInterior=', _GFillInterior);

  { ClearScreen constants }
  WriteLn('_GClearScreen=', _GClearScreen);
  WriteLn('_GViewport=', _GViewport);
  WriteLn('_GWindow=', _GWindow);

  { Error constants }
  WriteLn('_GrOk=', _GrOk);
  WriteLn('_GrError=', _GrError);
  WriteLn('_GrModeNotSupported=', _GrModeNotSupported);

  { PutImage constants }
  WriteLn('_GPSet=', _GPSet);
  WriteLn('_GXor=', _GXor);

  WriteLn('OK');
end.
