{ test_binunary.pas - Test des expressions binaires et unaires (TODO 11) }
program TestBinUnary;

const
  { Arithmetique : precedence correcte }
  Prec1 = 2 + 3 * 4;                  { 14, pas 20 }
  Prec2 = (2 + 3) * 4;                { 20 }
  Prec3 = 10 - 3 + 2;                 { 9 }
  Prec4 = 100 div 10 * 2;             { 20 }
  Prec5 = (10 + 5) * 2 - 3 div 2;    { 29 }

  { Operateurs de base }
  CSum  = 10 + 5;
  CDiff = 10 - 3;
  CProd = 6 * 7;
  CDiv  = 10 / 3;
  CIDiv = 17 div 3;
  CMod  = 17 mod 5;

  { Decalage de bits }
  CShl = 1 shl 4;
  CShr = 256 shr 2;

  { Logique }
  CAndL = true and false;
  COrL  = true or false;
  CNotL = not true;

  { Bitwise }
  CXor  = 255 xor 128;
  CBitA = 15 and 9;
  CBitO = 10 or 5;

  { Comparaison }
  CEq   = 10 = 10;
  CNeq  = 10 <> 5;
  CLt   = 3 < 5;
  CGt   = 10 > 5;
  CLte  = 3 <= 3;
  CGte  = 5 >= 5;

  { Negation }
  CNeg  = -42;
  CPos  = +10;

var
  X: Integer;
  Y: Integer;
  B: Boolean;
  C: Boolean;
  Mask: Integer;
  Flags: Integer;

begin
  { Arithmetique binaire avec precedence }
  X := 2 + 3 * 4;
  Y := (2 + 3) * 4;
  X := 100 div 7;
  Y := 100 mod 7;
  X := (10 + 5) * 2 - 3 div 2;

  { Operateurs logiques (contexte booleen) }
  B := (X > 0) and (Y < 100);
  B := (X = 0) or (Y <> 0);
  B := not B;
  C := true and false;
  C := true or false;
  C := not true;

  { Chaine logique : and/or sur comparaisons }
  B := (X > 0) and (Y > 0) and (X < 1000);
  B := (X = 0) or (Y = 0) or (X = Y);

  { Operateurs bitwise (contexte entier) }
  Mask := 255;
  Flags := 128;
  X := Mask and Flags;
  X := Mask or Flags;
  X := Mask xor Flags;
  X := not Mask;

  { Decalage de bits }
  X := 1 shl 4;
  Y := 256 shr 2;
  X := X shl 1;
  Y := Y shr 1;

  { Unaire }
  X := -X;
  X := +X;

  { Comparaisons }
  B := X = Y;
  B := X <> Y;
  B := X < Y;
  B := X > Y;
  B := X <= Y;
  B := X >= Y;

  { Expression mixte complexe }
  X := (Mask and $0F) shl 4 or (Flags and $F0) shr 4;

  WriteLn('Test binary/unary done');
end.
