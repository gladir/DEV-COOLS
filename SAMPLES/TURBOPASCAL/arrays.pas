{ arrays.pas - ARRAY fixe, multidimensionnel, String (TODO 25) }
program ArraysDemo;

const
  MaxItems = 5;

type
  TIntArray = array[1..MaxItems] of Integer;
  TMatrix = array[1..3, 1..3] of Integer;

var
  Arr: TIntArray;
  Mat: TMatrix;
  Names: array[1..3] of String;
  I, J: Integer;
  S: String;

begin
  { Tableau simple }
  for I := 1 to MaxItems do
    Arr[I] := I * 10;

  WriteLn('Tableau simple:');
  for I := 1 to MaxItems do
    Write(Arr[I], ' ');
  WriteLn;

  { Matrice 3x3 }
  for I := 1 to 3 do
    for J := 1 to 3 do
      Mat[I, J] := I * 10 + J;

  WriteLn('Matrice 3x3:');
  for I := 1 to 3 do
  begin
    for J := 1 to 3 do
      Write(Mat[I, J]:4);
    WriteLn;
  end;

  { Tableau de chaines }
  Names[1] := 'Alice';
  Names[2] := 'Bob';
  Names[3] := 'Charlie';

  WriteLn('Noms:');
  for I := 1 to 3 do
    WriteLn('  ', Names[I]);

  { Operations sur les chaines }
  S := 'Hello, World!';
  WriteLn('S = ', S);
  WriteLn('Length(S) = ', Length(S));
  WriteLn('Copy(S, 1, 5) = ', Copy(S, 1, 5));
  WriteLn('Pos(''World'', S) = ', Pos('World', S));

  WriteLn('Done.');
end.
