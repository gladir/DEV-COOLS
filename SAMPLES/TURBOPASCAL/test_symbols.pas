{ test_symbols.pas - Table des symboles pour TP2JS }
program TestSymbols;
const
  Version = 1;
  AppName = 'TestSymbols';
type
  TColor = (Red, Green, Blue);
  TPoint = record
    X, Y: Integer;
  end;
var
  Counter: Integer;
  Name: String;
  Value: Real;
  Flag: Boolean;
  C: Char;
  P: Pointer;
  LVal: LongInt;
  W: Word;
  B: Byte;
  SI: ShortInt;

procedure DoSomething(X: Integer; Y: Integer);
var
  Tmp: Integer;
begin
  Tmp := X + Y;
  WriteLn('Sum = ', Tmp);
end;

function Add(A, B: Integer): Integer;
begin
  Add := A + B;
end;

begin
  Counter := 42;
  Name := AppName;
  Value := 3.14;
  Flag := True;
  C := 'A';
  LVal := 123456;
  W := $FFFF;
  B := 255;
  SI := -128;
  DoSomething(10, 20);
  Counter := Add(3, 5);
  WriteLn('Counter = ', Counter);
  WriteLn('Name = ', Name);
  WriteLn('Flag = ', Flag);
  if Counter > 0 then
    WriteLn('Counter is positive');
  WriteLn('Test symbols done');
end.
