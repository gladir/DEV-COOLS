{ test_msgraph_stubs.pas - Test MSGraph stub functions (QuickPascal mode) }
program test_msgraph_stubs;
uses MSGraph;
begin
  { Test various stubs that should compile and run }
  _SetViewport(0, 0, 639, 479);
  WriteLn('_SetViewport done');

  _SetClipRgn(0, 0, 639, 479);
  WriteLn('_SetClipRgn done');

  _SetFillMask(0);
  WriteLn('_SetFillMask done');

  _RemapAllPalette(0);
  WriteLn('_RemapAllPalette done');

  WriteLn('_SelectPalette=', _SelectPalette(0));
  WriteLn('_RemapPalette=', _RemapPalette(0, 0));

  _SetTextWindow(1, 1, 25, 80);
  WriteLn('_SetTextWindow done');

  _ScrollTextWindow(1);
  WriteLn('_ScrollTextWindow done');

  _OutText('Hello');
  WriteLn('_OutText done');

  _SetTextPosition(1, 1);
  WriteLn('_SetTextPosition done');

  _SetTextColor(15);
  WriteLn('_SetTextColor done');
  WriteLn('_GetTextColor=', _GetTextColor);

  WriteLn('_SetTextRows=', _SetTextRows(25));
  WriteLn('_GetTextCursor=', _GetTextCursor);

  _UnRegisterFonts;
  WriteLn('_UnRegisterFonts done');

  WriteLn('_RegisterFonts=', _RegisterFonts('test.fon'));
  WriteLn('_SetFont=', _SetFont('t'));

  _OutGText('Hello');
  WriteLn('_OutGText done');

  WriteLn('OK');
end.
