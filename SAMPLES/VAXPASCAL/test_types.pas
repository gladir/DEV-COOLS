{ test_types.pas - Test du systeme de types VAX Pascal (TODO 07) }
{ Verifie les types primitifs, les alias VAX, IO_STATUS, VARYING }

PROGRAM TestTypes(Output);

VAR
  i   : INTEGER;
  w   : WORD;
  b   : BYTE;
  c   : CHAR;
  ok  : BOOLEAN;
  s   : STRING;
  r   : REAL;
  d   : DOUBLE;
  p   : ^INTEGER;
  u   : UNSIGNED;
  v   : VARYING [80] OF CHAR;

  { Types VAX predefinis }
  mw  : MACHINE_WORD;
  hw  : HALF_WORD;
  i16 : INTEGER16;
  i32 : INTEGER32;
  sf  : SINGLE;
  df  : D_FLOAT;
  gf  : G_FLOAT;
  qw  : QUADWORD;

  { Enumeration IO_STATUS predefinie }
  st  : IO_STATUS;

BEGIN
  i := 42;
  w := 100;
  b := 255;
  c := 'A';
  ok := TRUE;
  s := 'hello';
  r := 3.14;
  st := IO_OK;
  WriteLn('Types VAX Pascal OK');
END.
