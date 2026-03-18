{ test_segment.pas - Test du mot reserve SEGMENT (Apple Pascal) }
{ SEGMENT convertit une procedure/fonction en recouvrement (overlay) }
{ En mode Win32 flat, SEGMENT est accepte mais ignore (pas d overlay) }
program test_segment;

  Segment Procedure DoOverlay;
  Begin
    WriteLn('Segment Procedure OK');
  End;

  Segment Function GetValue: Integer;
  Begin
    GetValue := 42;
  End;

Begin
  DoOverlay;
  WriteLn('GetValue = ', GetValue);
  WriteLn('Done.');
End.
