Program TestSymbolType;
const
  MAX_SYMBOL_NAME = 32;
type
  TSymbol = Record
   name: String[MAX_SYMBOL_NAME];
   symbol_type: Integer;
   data_type: Integer;
   storage_class: Integer;
   offset: Integer;
   value: Integer;
   defined: Boolean;
   return_type: Integer;
   is_function: Boolean;
   record_size: Integer;
   field_count: Integer;
   unit_name: String[MAX_SYMBOL_NAME];
   is_external: Boolean;
   is_forward: Boolean;
  End;
  PSymbol = ^TSymbol;
var
  count: Integer;
begin
  count := 0;
end.
