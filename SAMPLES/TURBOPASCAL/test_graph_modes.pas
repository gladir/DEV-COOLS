{ test_graph_modes.pas - Test Graph mode functions }
program test_graph_modes;
uses Graph;
begin
  { Test GetMaxMode }
  WriteLn('GetMaxMode = ', GetMaxMode);

  { Test GetModeName }
  WriteLn('GetModeName(2) = ', GetModeName(2));

  { Test mode constants }
  WriteLn('VGALo=', VGALo);
  WriteLn('VGAMed=', VGAMed);
  WriteLn('VGAHi=', VGAHi);

  { Test GetPaletteSize }
  WriteLn('GetPaletteSize = ', GetPaletteSize);

  WriteLn('OK');
end.
