{ test_runtime.pas - Test du runtime JavaScript minimal (TODO 24) }
program TestRuntime;

var
  S, S2: String;
  X, Code: Integer;
  R: Real;

begin
  { _TPR_WriteLn / _TPR_Write }
  WriteLn('=== Test Runtime TODO 24 ===');
  WriteLn;
  Write('Write ');
  Write('works ');
  WriteLn('OK');

  { _TPR_IntToStr / _TPR_RealToStr via formatage }
  WriteLn('=== Formatted output ===');
  X := 42;
  WriteLn('X = ', X:8);
  R := 3.14159;
  WriteLn('R = ', R:10:2);
  WriteLn('R = ', R:8:4);

  { _TPR_StrToInt / _TPR_StrToReal via Val }
  WriteLn;
  WriteLn('=== Val/Str ===');
  Val('123', X, Code);
  WriteLn('Val 123: X=', X, ' Code=', Code);
  Str(X, S);
  WriteLn('Str(123) = "', S, '"');
  Str(R:8:2, S);
  WriteLn('Str(3.14:8:2) = "', S, '"');

  { _TPR_Copy }
  WriteLn;
  WriteLn('=== String operations ===');
  S := 'Hello World';
  S2 := Copy(S, 7, 5);
  WriteLn('Copy(Hello World, 7, 5) = "', S2, '"');

  { _TPR_Pos }
  X := Pos('World', S);
  WriteLn('Pos(World, Hello World) = ', X);

  { _TPR_Delete }
  S := 'Hello World';
  Delete(S, 6, 6);
  WriteLn('After Delete: "', S, '"');

  { _TPR_Insert }
  S := 'Hello';
  Insert(' World', S, 6);
  WriteLn('After Insert: "', S, '"');

  { Length }
  WriteLn('Length(Hello World) = ', Length(S));

  { _TPR_Random }
  WriteLn;
  WriteLn('=== Random ===');
  Randomize;
  X := Random(10);
  WriteLn('Random(10) = ', X);
  R := Random;
  WriteLn('Random = ', R:0:4);

  { _TPR_Args / ParamCount / ParamStr }
  WriteLn;
  WriteLn('=== Args ===');
  WriteLn('ParamCount = ', ParamCount);

  { _TPR_Halt }
  WriteLn;
  WriteLn('Test Runtime done');
end.
