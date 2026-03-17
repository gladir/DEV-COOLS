{ test_msgraph_text.pas - Test MSGraph text functions }
{ Compile avec : TPCW32 --quickpascal test_msgraph_text.pas }
{ Teste : _GetTextWindow, _WrapOn, _DisplayCursor,          }
{         _SetTextCursor, _GetTextPosition                   }

Program TestMSGraphText;

Uses MSGraph;

Var
  R : Integer;
  R1, C1, R2, C2 : Integer;

Begin
  { _GetTextWindow(var r1, c1, r2, c2) }
  _GetTextWindow(R1, C1, R2, C2);
  WriteLn('_GetTextWindow done');

  { _WrapOn(option) }
  R := _WrapOn(1);
  WriteLn('_WrapOn(True)=', R);

  R := _WrapOn(0);
  WriteLn('_WrapOn(False)=', R);

  { _DisplayCursor(toggle) }
  R := _DisplayCursor(1);
  WriteLn('_DisplayCursor(True)=', R);

  R := _DisplayCursor(0);
  WriteLn('_DisplayCursor(False)=', R);

  { _SetTextCursor(attr) }
  _SetTextCursor(7);
  WriteLn('_SetTextCursor(7) done');

  { _GetTextPosition(var r, c) }
  _GetTextPosition(R1, C1);
  WriteLn('_GetTextPosition done');

  WriteLn('OK');
End.
