{ test_pointer.pas - Pointeurs, NEW, ADDRESS, PTR }
program test_pointer;
type
  IntPtr = ^integer;
  Node = record
    value : integer;
    next  : ^Node;
  end;
var
  p    : IntPtr;
  n1   : ^Node;
  n2   : ^Node;
  addr : integer;
begin
  { Allocation dynamique }
  new(p);
  p^ := 42;
  writeln('p^ = ', p^);
  dispose(p);

  { Liste chainee }
  new(n1);
  new(n2);
  n1^.value := 10;
  n1^.next := n2;
  n2^.value := 20;
  n2^.next := nil;

  writeln('n1^ = ', n1^.value);
  writeln('n2^ = ', n2^.value);

  { ADDRESS }
  addr := address(n1^.value);
  writeln('address(n1^.value) = ', addr);

  dispose(n2);
  dispose(n1);
end.
