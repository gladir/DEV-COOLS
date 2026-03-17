{ test_paramcount.pas - Test de ParamCount }
program TestParamCount;
var
  N: Word;
begin
  WriteLn('=== Test ParamCount ===');
  N := ParamCount;
  WriteLn('ParamCount = ', N);
  WriteLn('Done.');
end.
