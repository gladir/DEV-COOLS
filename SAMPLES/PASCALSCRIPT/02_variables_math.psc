{ 02_variables_math.psc - Variables et calculs }

var
  A, B: Integer;
  Quotient: Real;

begin
  A := 100;
  B := 37;
  Quotient := A / B;

  WScript.Echo('A = ' + IntToStr(A));
  WScript.Echo('B = ' + IntToStr(B));
  WScript.Echo('A + B = ' + IntToStr(A + B));
  WScript.Echo('A - B = ' + IntToStr(A - B));
  WScript.Echo('A * B = ' + IntToStr(A * B));
  WScript.Echo('A div B = ' + IntToStr(A div B));
  WScript.Echo('A mod B = ' + IntToStr(A mod B));
  WScript.Echo('A / B = ' + FloatToStr(Quotient));
end.
