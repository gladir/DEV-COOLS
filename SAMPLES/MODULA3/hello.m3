(* hello.m3 - Exemple introductif Modula-3 (TODO 25)                    *)
(* Demontre : Wr.PutText, Wr.Nl, variables, constantes, types TEXT,     *)
(* concatenation &, Wr.PutInt, Wr.PutChar, Wr.PutBool, Fmt.Int.        *)

MODULE Hello;

IMPORT Wr, Fmt;

CONST
  Banner  = "=== Bienvenue en Modula-3 ! ===";
  Version = 3;
  Pi      = 314;
  Debug   = TRUE;

VAR
  greeting : TEXT;
  name     : TEXT;
  age      : INTEGER;
  initial  : CHAR;
  ok       : BOOLEAN;

PROCEDURE ShowGreeting() =
BEGIN
  Wr.PutText(Banner);
  Wr.Nl();
  Wr.PutText("Version : ");
  Wr.PutInt(Version);
  Wr.Nl();
END ShowGreeting;

PROCEDURE ShowVariables() =
VAR
  msg : TEXT;
BEGIN
  greeting := "Hello";
  name     := "World";
  age      := 42;
  initial  := 'M';
  ok       := TRUE;

  (* Concatenation de chaines *)
  msg := greeting & ", " & name & "!";
  Wr.PutText(msg);
  Wr.Nl();

  (* Affichage d un entier *)
  Wr.PutText("Age : ");
  Wr.PutInt(age);
  Wr.Nl();

  (* Affichage d un caractere *)
  Wr.PutText("Initiale : ");
  Wr.PutChar(initial);
  Wr.Nl();

  (* Affichage d un booleen *)
  Wr.PutText("Actif : ");
  Wr.PutBool(ok);
  Wr.Nl();
END ShowVariables;

PROCEDURE ShowConversions() =
VAR
  t : TEXT;
BEGIN
  (* Fmt.Int : convertir un entier en TEXT *)
  t := Fmt.Int(Pi);
  Wr.PutText("Pi (approx) = ");
  Wr.PutText(t);
  Wr.Nl();

  (* Constantes booleennes *)
  Wr.PutText("Debug = ");
  Wr.PutBool(Debug);
  Wr.Nl();

  (* NIL *)
  Wr.PutText("NIL teste.");
  Wr.Nl();
END ShowConversions;

BEGIN
  ShowGreeting();
  ShowVariables();
  ShowConversions();
  Wr.PutText("Termine.");
  Wr.Nl();
END Hello.
