{ test_cstring.pas - Test du type CSTRING (QuickPascal) }
{ Compile avec : TPCW32 --quickpascal test_cstring.pas  }

Program TestCString;

Uses MSGraph;

Var
  S : CString;
  T : CString;

Begin
  S := 'Hello CString';
  T := 'World';
  WriteLn('S = ', S);
  WriteLn('T = ', T);
  WriteLn('Length(S) = ', Length(S));
  WriteLn('Length(T) = ', Length(T));
  WriteLn('Done.');
End.
