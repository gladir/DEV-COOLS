{ test_absolute.pas - Test variables absolute $Seg:$Ofs (TODO 28) }
program TestAbsolute;

uses Dos;

var
  MemConv : Word absolute $0040:$0013;

begin
  Writeln('Memoire conventionnelle totale : ', MemConv, ' Ko');
end.
