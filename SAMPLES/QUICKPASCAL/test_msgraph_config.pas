{ test_msgraph_config.pas - Test MSGraph configuration/page functions }
{ Compile avec : TPCW32 --quickpascal test_msgraph_config.pas          }
{ Teste : _SetVideoModeRows, _GetActivePage, _GetVisualPage,           }
{         _SetActivePage, _SetVisualPage, _GetVideoConfig               }

Program TestMSGraphConfig;

Uses MSGraph;

Var
  R : Integer;

Begin
  { _SetVideoModeRows(mode, rows) }
  R := _SetVideoModeRows(_TextC80, 25);
  WriteLn('_SetVideoModeRows=', R);

  { _GetActivePage }
  R := _GetActivePage;
  WriteLn('_GetActivePage=', R);

  { _GetVisualPage }
  R := _GetVisualPage;
  WriteLn('_GetVisualPage=', R);

  { _SetActivePage(page) }
  _SetActivePage(0);
  WriteLn('_SetActivePage(0) done');

  { _SetVisualPage(page) }
  _SetVisualPage(0);
  WriteLn('_SetVisualPage(0) done');

  { _GetVideoConfig(var vc) - using integer variable as stub }
  _GetVideoConfig(R);
  WriteLn('_GetVideoConfig done');

  WriteLn('OK');
End.
