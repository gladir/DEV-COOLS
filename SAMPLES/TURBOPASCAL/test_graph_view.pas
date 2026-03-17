{ test_graph_view.pas - Test Graph viewport and page functions }
program test_graph_view;
uses Graph;
begin
  { Test SetViewPort }
  SetViewPort(10, 20, 630, 460, True);
  WriteLn('SetViewPort(10,20,630,460,True) done');

  { Test ClearDevice }
  ClearDevice;
  WriteLn('ClearDevice done');

  { Test ClearViewPort }
  ClearViewPort;
  WriteLn('ClearViewPort done');

  { Test SetVisualPage / SetActivePage }
  SetVisualPage(0);
  WriteLn('SetVisualPage(0) done');
  SetActivePage(0);
  WriteLn('SetActivePage(0) done');

  { Test GraphDefaults }
  GraphDefaults;
  WriteLn('GraphDefaults done');
  if GetX = 0 then WriteLn('After GraphDefaults: X=0 OK')
  else WriteLn('After GraphDefaults: X=', GetX);

  { Test RestoreCrtMode }
  RestoreCrtMode;
  WriteLn('RestoreCrtMode done');

  { Test SetGraphMode }
  SetGraphMode(VGAHi);
  WriteLn('SetGraphMode(VGAHi) done');

  { Test GetGraphMode }
  WriteLn('GetGraphMode = ', GetGraphMode);

  WriteLn('OK');
end.
