{ Test TODO 10 : declarations de types, enumerations, sous-intervalles }
program test_typedecl(output);

type
  { Enumeration simple }
  Color = (Red, Green, Blue, Yellow);

  { Sous-intervalle entier }
  SmallInt = -32..31;

  { Sous-intervalle positif }
  ByteRange = 0..255;

  { Pointeur }
  PInteger = ^Integer;

  { Tableau simple }
  Vector10 = array[1..10] of Integer;

  { Tableau 2D }
  Matrix = array[1..10, 1..20] of Real;

  { SET OF }
  CharSet = set of Char;

  { RECORD simple }
  Point = record
    X : Integer;
    Y : Integer;
  end;

  { PACKED RECORD }
  PackedRec = packed record
    A : Integer;
    B : Char;
  end;

  { VARYING }
  VString80 = varying [80] of char;

  { Alias de type }
  TEntier = Integer;

  { STRING type }
  ShortStr = string[40];

  { Type procedural }
  TCallback = procedure(N : Integer);

  { Type fonctionnel }
  TCalcFunc = function(A, B : Integer) : Integer;

  { FILE OF }
  IntFile = file of Integer;

var
  C : Color;
  S : SmallInt;
  P : PInteger;
  V : Vector10;
  CS : CharSet;
  Pt : Point;
  VS : VString80;
  I  : TEntier;

begin
  I := 42;
  WriteLn('TODO 10 : type declarations OK');
end.
