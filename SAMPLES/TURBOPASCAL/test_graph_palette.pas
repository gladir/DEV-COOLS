{ test_graph_palette.pas - Test Graph palette functions }
program test_graph_palette;
uses Graph;
begin
  { Test SetPalette }
  SetPalette(0, 1);
  WriteLn('SetPalette(0, 1) done');

  { Test SetRGBPalette }
  SetRGBPalette(1, 255, 128, 64);
  WriteLn('SetRGBPalette(1, 255, 128, 64) done');

  { Test SetAllPalette - stub }
  SetAllPalette(0);
  WriteLn('SetAllPalette done');

  { Test GetPalette - stub }
  GetPalette(0);
  WriteLn('GetPalette done');

  { Test GetDefaultPalette - stub }
  GetDefaultPalette(0);
  WriteLn('GetDefaultPalette done');

  { Test GetPaletteSize }
  WriteLn('GetPaletteSize = ', GetPaletteSize);
  if GetPaletteSize = 16 then WriteLn('PaletteSize OK')
  else WriteLn('PaletteSize FAIL');

  { Test SetAspectRatio / GetAspectRatio }
  SetAspectRatio(10000, 10000);
  WriteLn('SetAspectRatio done');

  WriteLn('OK');
end.
