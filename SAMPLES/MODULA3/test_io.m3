(* test_io.m3 - Test des entrees/sorties (TODO 12)                 *)
(* Verifie les modules Wr, Rd, Stdio, Fmt, Text.                   *)
(* Le compilateur doit generer du code ASM 8086 pour :              *)
(*   - Wr.PutChar, Wr.PutText, Wr.PutInt, Wr.PutReal, Wr.PutBool *)
(*   - Wr.Nl                                                       *)
(*   - Rd.GetChar, Rd.GetLine, Rd.GetInt                           *)
(*   - Stdio.stdout, Stdio.stderr                                  *)
(*   - Fmt.Int, Fmt.Char, Fmt.Bool                                 *)
(*   - Text.Length, Text.GetChar, Text.Sub, Text.Equal, Text.Cat   *)
(*   - EmitRuntime : _M3RT_PRINT, _M3RT_NUMTOSTR, _M3RT_STRTONUM *)
(*     _M3RT_STRLEN, _M3RT_STRCMP, _M3RT_CONCAT, _M3RT_TEXTSUB    *)
(*     _M3RT_READLINE, _M3RT_PRBOOL, _M3RT_FMTBOOL                *)

MODULE TestIO;

IMPORT Wr, Fmt, Text, Stdio;

CONST
  Greeting = "Hello, Modula-3!";
  Name     = "World";

VAR
  s     : TEXT;
  n     : INTEGER;
  ch    : CHAR;
  ok    : BOOLEAN;
  len   : INTEGER;
  h     : INTEGER;

PROCEDURE TestWrModule();
BEGIN
  (* Wr.PutText : ecrire une chaine *)
  Wr.PutText("Hello");
  Wr.PutText(" ");
  Wr.PutText("World");
  Wr.Nl();

  (* Wr.PutChar : ecrire un seul caractere *)
  Wr.PutChar('A');
  Wr.PutChar('B');
  Wr.PutChar('C');
  Wr.Nl();

  (* Wr.PutInt : ecrire un entier *)
  Wr.PutInt(42);
  Wr.Nl();
  Wr.PutInt(0);
  Wr.Nl();
  Wr.PutInt(-123);
  Wr.Nl();

  (* Wr.PutReal : ecrire un reel (approximation entiere) *)
  Wr.PutReal(314);
  Wr.Nl();

  (* Wr.PutBool : ecrire un booleen *)
  Wr.PutBool(TRUE);
  Wr.Nl();
  Wr.PutBool(FALSE);
  Wr.Nl();
END TestWrModule;

PROCEDURE TestFmtModule();
VAR
  t : TEXT;
BEGIN
  (* Fmt.Int : convertir un entier en TEXT *)
  t := Fmt.Int(99);
  Wr.PutText(t);
  Wr.Nl();

  (* Fmt.Char : convertir un caractere en TEXT *)
  t := Fmt.Char('X');
  Wr.PutText(t);
  Wr.Nl();

  (* Fmt.Bool : convertir un booleen en TEXT *)
  t := Fmt.Bool(TRUE);
  Wr.PutText(t);
  Wr.Nl();
  t := Fmt.Bool(FALSE);
  Wr.PutText(t);
  Wr.Nl();
END TestFmtModule;

PROCEDURE TestTextModule();
VAR
  t1, t2, t3 : TEXT;
  ln         : INTEGER;
  c          : CHAR;
  eq         : BOOLEAN;
BEGIN
  t1 := "Hello";
  t2 := " World";

  (* Text.Length *)
  ln := Text.Length(t1);
  Wr.PutInt(ln);
  Wr.Nl();

  (* Text.GetChar *)
  c := Text.GetChar(t1, 0);

  (* Text.Cat : concatenation *)
  t3 := Text.Cat(t1, t2);
  Wr.PutText(t3);
  Wr.Nl();

  (* Text.Equal *)
  eq := Text.Equal(t1, "Hello");
  Wr.PutBool(eq);
  Wr.Nl();

  eq := Text.Equal(t1, "Bye");
  Wr.PutBool(eq);
  Wr.Nl();

  (* Text.Sub : extraction de sous-chaine *)
  t3 := Text.Sub(t1, 1, 3);
  Wr.PutText(t3);
  Wr.Nl();
END TestTextModule;

PROCEDURE TestStdio();
VAR
  out : INTEGER;
  err : INTEGER;
BEGIN
  (* Stdio.stdout -> handle 1 *)
  out := Stdio.stdout;
  Wr.PutInt(out);
  Wr.Nl();

  (* Stdio.stderr -> handle 2 *)
  err := Stdio.stderr;
  Wr.PutInt(err);
  Wr.Nl();
END TestStdio;

BEGIN
  (* Test du module Wr *)
  Wr.PutText("=== Test Wr ===");
  Wr.Nl();
  TestWrModule();

  (* Test du module Fmt *)
  Wr.PutText("=== Test Fmt ===");
  Wr.Nl();
  TestFmtModule();

  (* Test du module Text *)
  Wr.PutText("=== Test Text ===");
  Wr.Nl();
  TestTextModule();

  (* Test du module Stdio *)
  Wr.PutText("=== Test Stdio ===");
  Wr.Nl();
  TestStdio();

  Wr.PutText("Termine.");
  Wr.Nl();
END TestIO.
