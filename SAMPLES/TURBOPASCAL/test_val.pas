{ test_val.pas - Test de la procedure Val }
program TestVal;
var
  S: String;
  N: Integer;
  Code: Integer;
begin
  { Val avec chaine valide positive }
  S := '42';
  Val(S, N, Code);
  WriteLn('Val(42) = ', N, ' code=', Code);

  { Val avec chaine valide negative }
  S := '-7';
  Val(S, N, Code);
  WriteLn('Val(-7) = ', N, ' code=', Code);

  { Val avec chaine zero }
  S := '0';
  Val(S, N, Code);
  WriteLn('Val(0) = ', N, ' code=', Code);

  { Val avec grand nombre }
  S := '12345';
  Val(S, N, Code);
  WriteLn('Val(12345) = ', N, ' code=', Code);

  WriteLn('Done.');
end.
