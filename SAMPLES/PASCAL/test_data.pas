program TestData;

{ Test typed constants }
const
  MaxItems: Integer = 100;
  MinItems: Integer = 0;
  AppVersion: Byte = 3;
  DebugFlag: Boolean = True;
  AppName: String = 'My Application';
  Separator: Char = '-';

{ Test untyped constants }
const
  PI_APPROX = 3;
  MAX_SIZE = 1024;
  GREETING = 'Hello World';
  IS_RELEASE = FALSE;
  NEG_VAL = -42;

{ Test global variables }
var
  counter: Integer;
  total: LongInt;
  name: String;
  initial: Char;
  flag: Boolean;
  value: Byte;
  items: Array[1..10] Of Integer;
  msg: Array[0..255] Of Char;

{ Test multiple vars on same line }
var
  a, b, c: Integer;
  x, y: Byte;

begin
  counter := MaxItems;
  total := MAX_SIZE;
  flag := DebugFlag;
  WriteLn('Test des donnees termine');
end.
