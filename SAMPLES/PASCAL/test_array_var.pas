Program TestArrayVar;
const
  MAX_SYMBOLS = 100;
  MAX_NAME = 32;
type
  PSymbol = ^TSymbol;
  TSymbol = Record
   name: String[MAX_NAME];
   value: Integer;
  End;
var
  symbol_table: Array[1..MAX_SYMBOLS] of PSymbol;
  counts: Array[0..255] of Byte;
  names: Array[1..10] of String;
  fixed: Array[1..5] of Integer;
  count: Integer;
begin
  count := 0;
end.
