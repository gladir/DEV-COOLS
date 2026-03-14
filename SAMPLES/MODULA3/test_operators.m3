(* test_operators.m3 - Test des operateurs et precedences Modula-3 (TODO 04) *)
(* Verifie BinOpPrec, EmitBinOp, EmitUnaryOp, ExprFlushToAX            *)

MODULE TestOperators;

CONST
  (* Arithmetique entiere : + - * DIV MOD *)
  Sum  = 10 + 5;       (* 15 *)
  Diff = 10 - 3;       (* 7  *)
  Prod = 4 * 7;        (* 28 *)
  Quot = 20 DIV 3;     (* 6  *)
  Rest = 20 MOD 3;     (* 2  *)

  (* Precedence : * avant + *)
  Prec1 = 2 + 3 * 4;   (* 14, pas 20 *)
  Prec2 = 10 - 2 * 3;  (* 4 *)

  (* Comparaisons : = # < <= > >= *)
  Eq   = 5 = 5;        (* TRUE -> 1 *)
  Neq  = 3 # 4;        (* TRUE -> 1 *)
  Lt   = 2 < 7;        (* TRUE -> 1 *)
  Gt   = 9 > 3;        (* TRUE -> 1 *)
  Le   = 5 <= 5;       (* TRUE -> 1 *)
  Ge   = 10 >= 1;      (* TRUE -> 1 *)
  EqF  = 5 = 6;        (* FALSE -> 0 *)

  (* Logique : AND OR NOT *)
  And1 = TRUE AND TRUE;       (* 1 *)
  And2 = TRUE AND FALSE;      (* 0 *)
  Or1  = FALSE OR TRUE;       (* 1 *)
  Or2  = FALSE OR FALSE;      (* 0 *)

  (* Unaire : + - NOT *)
  Neg  = -42;           (* -42 *)
  Pos  = +42;           (* 42  *)

  (* Concatenation de chaines (constante) *)
  Full = "Hello" & " " & "World";

VAR
  a, b, c : INTEGER;
  ok      : BOOLEAN;

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
  ok := a <= b;
  ok := a >= b;
  ok := TRUE AND FALSE;
  ok := TRUE OR FALSE;
END TestOperators.
