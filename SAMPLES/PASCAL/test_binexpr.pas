program test_binexpr;
var
  a, b, c, r: integer;
  ok: boolean;
begin
  { === Test des operations arithmetiques === }
  a := 10;
  b := 3;

  { Addition }
  r := a + b;
  Write('10 + 3 = ');
  WriteLn(r);

  { Soustraction }
  r := a - b;
  Write('10 - 3 = ');
  WriteLn(r);

  { Multiplication }
  r := a * b;
  Write('10 * 3 = ');
  WriteLn(r);

  { Division entiere }
  r := a div b;
  Write('10 div 3 = ');
  WriteLn(r);

  { Modulo }
  r := a mod b;
  Write('10 mod 3 = ');
  WriteLn(r);

  { === Test des operations logiques/bit a bit === }
  a := 12;
  b := 10;

  { AND }
  r := a and b;
  Write('12 and 10 = ');
  WriteLn(r);

  { OR }
  r := a or b;
  Write('12 or 10 = ');
  WriteLn(r);

  { XOR }
  r := a xor b;
  Write('12 xor 10 = ');
  WriteLn(r);

  { SHL }
  r := 1 shl 4;
  Write('1 shl 4 = ');
  WriteLn(r);

  { SHR }
  r := 32 shr 2;
  Write('32 shr 2 = ');
  WriteLn(r);

  { === Test des comparaisons === }
  a := 5;
  b := 10;

  { Egalite }
  r := Ord(a = b);
  Write('5 = 10 -> ');
  WriteLn(r);

  r := Ord(a = 5);
  Write('5 = 5  -> ');
  WriteLn(r);

  { Difference }
  r := Ord(a <> b);
  Write('5 <> 10 -> ');
  WriteLn(r);

  { Inferieur }
  r := Ord(a < b);
  Write('5 < 10 -> ');
  WriteLn(r);

  { Superieur }
  r := Ord(a > b);
  Write('5 > 10 -> ');
  WriteLn(r);

  { Inferieur ou egal }
  r := Ord(a <= b);
  Write('5 <= 10 -> ');
  WriteLn(r);

  { Superieur ou egal }
  r := Ord(a >= b);
  Write('5 >= 10 -> ');
  WriteLn(r);

  { === Test de precedence === }
  { * lie plus fort que + }
  r := 2 + 3 * 4;
  Write('2 + 3 * 4 = ');
  WriteLn(r);

  r := (2 + 3) * 4;
  Write('(2 + 3) * 4 = ');
  WriteLn(r);

  { Expression complexe }
  r := 10 - 2 * 3 + 1;
  Write('10 - 2 * 3 + 1 = ');
  WriteLn(r);

  WriteLn('Fin du test des expressions binaires');
end.
