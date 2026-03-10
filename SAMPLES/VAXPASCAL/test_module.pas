{ test_module.pas - MODULE, [EXTERNAL], [GLOBAL], [INHERIT] }
module test_module;

[global] var
  shared_counter : integer;

[global] function get_counter : integer;
begin
  get_counter := shared_counter;
end;

[global] procedure inc_counter;
begin
  shared_counter := shared_counter + 1;
end;

[global] procedure set_counter(val : integer);
begin
  shared_counter := val;
end;

end.
