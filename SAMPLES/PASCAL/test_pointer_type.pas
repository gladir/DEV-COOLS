Program TestPointerType;
const
  MAX_SYMBOL_NAME = 32;
type
  TSymbol = Record
   name: String[MAX_SYMBOL_NAME];
   symbol_type: Integer;
   data_type: Integer;
   value: Integer;
   defined: Boolean;
  End;
  PSymbol = ^TSymbol;
  PNextNode = ^TSymbol;
var
  count: Integer;
begin
  count := 0;
end.
