{ test_graph_info.pas - Test Graph error/info functions }
program test_graph_info;
uses Graph;
begin
  { Test GraphErrorMsg }
  WriteLn('GraphErrorMsg(0) = ', GraphErrorMsg(0));
  WriteLn('GraphErrorMsg(-1) = ', GraphErrorMsg(-1));

  { Test GraphResult before init -> should be 0 }
  WriteLn('GraphResult = ', GraphResult);

  { Test GetDriverName }
  WriteLn('GetDriverName = ', GetDriverName);

  { Test constants }
  WriteLn('Detect=', Detect);
  WriteLn('VGA=', VGA);
  WriteLn('grOk=', grOk);
  WriteLn('grNoInitGraph=', grNoInitGraph);

  WriteLn('OK');
end.
