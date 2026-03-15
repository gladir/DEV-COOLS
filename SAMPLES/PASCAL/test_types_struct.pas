Program TestTypesStruct;
{ Test pour TODO 16 : types structures ARRAY, RECORD, SET, STRING }

const
  MAX_SIZE = 10;

type
  { Array simple }
  TIntArray = Array[1..10] of Integer;
  TByteArr = Array[0..255] of Byte;

  { Record simple }
  TPoint = Record
    x: Integer;
    y: Integer;
  end;

  { Record avec champs multiples types }
  TPerson = Record
    name: String;
    age: Integer;
    active: Boolean;
  end;

  { Set de type ordinal }
  TCharSet = Set of Char;

  { String avec longueur maximale }
  TShortStr = String[80];

  { Alias de type simple }
  TMyInt = Integer;
  TMyBool = Boolean;

  { Pointeur }
  PPoint = ^TPoint;

var
  coords: TIntArray;
  buffer: TByteArr;
  origin: TPoint;
  player: TPerson;
  vowels: TCharSet;
  msg: TShortStr;
  count: TMyInt;
  flag: TMyBool;
  ptr: PPoint;

begin
  { Utiliser les variables }
  count := 0;
  flag := true;
  msg := 'Hello World';

  { Acces aux champs du record }
  origin.x := 10;
  origin.y := 20;

  player.name := 'Alice';
  player.age := 30;
  player.active := true;

  { Acces aux elements du tableau }
  coords[1] := 100;
  coords[2] := 200;

  WriteLn('Types structures test');
  WriteLn(msg);
  WriteLn(count);
end.
