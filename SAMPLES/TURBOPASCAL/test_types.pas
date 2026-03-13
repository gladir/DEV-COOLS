{ test_types.pas - Types et systeme de types pour TP2JS }
program TestTypes;
type
  TColor = (Red, Green, Blue);
  TPoint = record
    X, Y: Integer;
  end;
  TRect = record
    TopLeft, BottomRight: TPoint;
  end;
  TNumbers = array[1..10] of Integer;
  TMatrix = array[1..3, 1..3] of Real;
  TCharSet = set of Char;
  TByteRange = 0..255;
  TName = String[30];
  PInteger = ^Integer;
  TProcNoArg = procedure;
  TFuncInt = function(X: Integer): Integer;
var
  Counter: Integer;
  BigVal: LongInt;
  SmallVal: ShortInt;
  FlagByte: Byte;
  WordVal: Word;
  CompVal: Comp;
  Flag: Boolean;
  Ch: Char;
  Name: String;
  ShortName: TName;
  Value: Real;
  SingleVal: Single;
  DoubleVal: Double;
  ExtVal: Extended;
  P: Pointer;
  PC: PChar;
  Color: TColor;
  Pt: TPoint;
  Rect: TRect;
  Numbers: TNumbers;
  Matrix: TMatrix;
  Vowels: TCharSet;
  F: Text;
begin
  Counter := 42;
  BigVal := 100000;
  SmallVal := -50;
  FlagByte := 200;
  WordVal := 50000;
  Flag := True;
  Ch := 'A';
  Name := 'Hello World';
  Value := 3.14;
  SingleVal := 1.5;
  DoubleVal := 2.718281828;
  Color := Green;
  Pt.X := 10;
  Pt.Y := 20;
  Numbers[1] := 100;
  P := nil;
  WriteLn('Counter = ', Counter);
  WriteLn('BigVal = ', BigVal);
  WriteLn('Flag = ', Flag);
  WriteLn('Char = ', Ch);
  WriteLn('Name = ', Name);
  WriteLn('Value = ', Value:0:2);
  WriteLn('Point = (', Pt.X, ', ', Pt.Y, ')');
  WriteLn('Test types done');
end.
