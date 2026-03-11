{ test_const.pas - Constantes, litteral octal }
program test_const;
const
  PI_APPROX = 3;
  MAX_SIZE  = 100;
  GREETING  = 'Bonjour';
  HEX_VAL   = %X'FF';
  OCT_VAL   = %O'77';
  FLAG      = true;
begin
  writeln('PI_APPROX = ', PI_APPROX);
  writeln('MAX_SIZE  = ', MAX_SIZE);
  writeln('GREETING  = ', GREETING);
  writeln('HEX_VAL   = ', HEX_VAL);
  writeln('OCT_VAL   = ', OCT_VAL);
  writeln('FLAG      = ', FLAG);
end.
