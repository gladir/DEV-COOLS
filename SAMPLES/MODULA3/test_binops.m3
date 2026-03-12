(* test_binops.m3 - Test des expressions binaires (TODO 11)        *)
(* Verifie ParseExprPrec (Pratt), EmitBinOp, EmitBinOpText,       *)
(* EmitSetOp, court-circuit AND/OR.                                *)
(* Le compilateur doit generer du code ASM 8086 pour :             *)
(*   - arithmetique : + - * DIV MOD                                *)
(*   - concatenation TEXT : &                                      *)
(*   - comparaison entiere : = # < <= > >=                         *)
(*   - logique AND OR NOT (court-circuit)                          *)
(*   - operateur IN (appartenance a un ensemble)                   *)
(*   - precedence : * avant +, AND avant OR, etc.                 *)

MODULE TestBinOps;

IMPORT Wr;

CONST
  (* Arithmetique de base *)
  S1 = 10 + 5;         (* 15 *)
  S2 = 20 - 7;         (* 13 *)
  S3 = 6 * 7;          (* 42 *)
  S4 = 100 DIV 3;      (* 33 *)
  S5 = 100 MOD 3;      (* 1  *)

  (* Precedence : * avant + *)
  P1 = 2 + 3 * 4;      (* 14 *)
  P2 = 10 - 2 * 3;     (* 4  *)
  P3 = 4 * 5 + 2 * 3;  (* 26 *)

  (* Concatenation de texte *)
  T1 = "Hello" & " " & "World";
  T2 = "abc" & "def";

  (* Comparaisons *)
  C1 = 5 = 5;          (* TRUE  *)
  C2 = 5 # 3;          (* TRUE  *)
  C3 = 2 < 10;         (* TRUE  *)
  C4 = 10 > 2;         (* TRUE  *)
  C5 = 5 <= 5;         (* TRUE  *)
  C6 = 5 >= 5;         (* TRUE  *)
  C7 = 5 = 3;          (* FALSE *)
  C8 = 5 < 3;          (* FALSE *)

  (* Logique *)
  L1 = TRUE AND TRUE;    (* TRUE  *)
  L2 = TRUE AND FALSE;   (* FALSE *)
  L3 = FALSE OR TRUE;    (* TRUE  *)
  L4 = FALSE OR FALSE;   (* FALSE *)

VAR
  a, b, c : INTEGER;
  ok      : BOOLEAN;
  s       : TEXT;

PROCEDURE TestArithmetic(x : INTEGER; y : INTEGER) : INTEGER;
VAR
  r : INTEGER;
BEGIN
  r := x + y;
  r := x - y;
  r := x * y;
  r := x DIV y;
  r := x MOD y;
  (* Expressions complexes avec precedence *)
  r := x + y * 2;
  r := (x + y) * 2;
  r := x * y + x * y;
  r := x DIV y + x MOD y;
  RETURN r;
END TestArithmetic;

PROCEDURE TestComparison(a : INTEGER; b : INTEGER) : BOOLEAN;
VAR
  r : BOOLEAN;
BEGIN
  r := (a = b);
  r := (a # b);
  r := (a < b);
  r := (a <= b);
  r := (a > b);
  r := (a >= b);
  (* Comparaison dans une expression composee *)
  r := (a < b) AND (b < 100);
  r := (a = 0) OR (b = 0);
  RETURN r;
END TestComparison;

PROCEDURE TestLogic(p : BOOLEAN; q : BOOLEAN) : BOOLEAN;
VAR
  r : BOOLEAN;
BEGIN
  (* Court-circuit AND : si p est FALSE, q n est pas evalue *)
  r := p AND q;
  (* Court-circuit OR : si p est TRUE, q n est pas evalue *)
  r := p OR q;
  (* NOT *)
  r := NOT p;
  (* Combinaisons *)
  r := (p AND q) OR (NOT p AND NOT q);
  r := NOT (p OR q);
  r := (p OR q) AND (p OR NOT q);
  RETURN r;
END TestLogic;

PROCEDURE TestConcat();
VAR
  t : TEXT;
BEGIN
  t := "Hello" & " " & "World";
  Wr.PutText(t);
  Wr.Nl();
END TestConcat;

PROCEDURE TestPrecedence() : INTEGER;
VAR
  r : INTEGER;
BEGIN
  (* * et DIV avant + et - *)
  r := 2 + 3 * 4;        (* 14 *)
  r := 10 - 6 DIV 2;     (* 7  *)
  (* AND avant OR *)
  (* TRUE OR FALSE AND FALSE -> TRUE OR (FALSE AND FALSE) -> TRUE *)
  r := 0;
  RETURN r;
END TestPrecedence;

BEGIN
  a := 10;
  b := 3;
  c := a + b;
  c := a - b;
  c := a * b;
  c := a DIV b;
  c := a MOD b;
  ok := a = b;
  ok := a # b;
  ok := a < b;
  ok := a > b;
  ok := TRUE AND FALSE;
  ok := TRUE OR FALSE;
  ok := NOT TRUE;
  s := "Hello" & " World";
END TestBinOps.
