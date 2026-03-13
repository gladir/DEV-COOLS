program TestTodo15;

{ Test TODO 15 : TABLEAUX, RECORDS, ENSEMBLES ET OBJETS }

type
  TPoint = record
    X: Integer;
    Y: Integer;
  end;

  TColor = (Red, Green, Blue, Yellow, White);

  TIntArray = array[1..5] of Integer;

  TByteArr = array[0..9] of Byte;

var
  pt: TPoint;
  arr: array[1..5] of Integer;
  colors: TIntArray;
  i: Integer;
  b: TByteArr;

begin
  { Test 1 : Record field assignment and access }
  pt.X := 10;
  pt.Y := 20;
  WriteLn('pt.X = ', pt.X);
  WriteLn('pt.Y = ', pt.Y);

  { Test 2 : Array assignment and access }
  arr[1] := 100;
  arr[2] := 200;
  arr[3] := 300;
  arr[4] := 400;
  arr[5] := 500;
  WriteLn('arr[1] = ', arr[1]);
  WriteLn('arr[3] = ', arr[3]);
  WriteLn('arr[5] = ', arr[5]);

  { Test 3 : Named array type }
  colors[1] := 11;
  colors[2] := 22;
  colors[3] := 33;
  WriteLn('colors[2] = ', colors[2]);

  { Test 4 : Byte array }
  b[0] := 65;
  b[1] := 66;
  WriteLn('b[0] = ', b[0]);

  { Test 5 : Array in a loop }
  for i := 1 to 5 do
    arr[i] := i * 10;
  for i := 1 to 5 do
    WriteLn('arr[', i, '] = ', arr[i]);

  { Test 6 : Record field arithmetic }
  pt.X := pt.X + 5;
  WriteLn('pt.X + 5 = ', pt.X);

  { Test 7 : Enum constants }
  i := Ord(Green);
  WriteLn('Ord(Green) = ', i);
end.
