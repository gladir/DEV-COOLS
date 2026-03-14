MODULE TestLiterals;

(* Test des litteraux et constantes Modula-3 *)
(* Exercice pour TODO 03 *)

CONST
  (* Entiers decimaux *)
  Zero  = 0;
  Cent  = 100;
  Big   = 65535;

  (* Entiers hexadecimaux et bases *)
  Hex1  = 16_FF;
  Hex2  = 16_CAFE;
  Oct1  = 8_77;
  Bin1  = 2_1010;

  (* Reel tronque a entier *)
  Pi    = 3.14159;

  (* Caracteres *)
  ChA   = 'A';
  ChNL  = '\n';
  ChTab = '\t';
  ChHex = '\x41';

  (* Chaines TEXT *)
  Hello = "Hello";
  World = "World";
  Msg   = "Hello, Modula-3!\n";

  (* Booleens et NIL *)
  Yes   = TRUE;
  No    = FALSE;
  Nul   = NIL;

  (* Concatenation de chaines constantes *)
  Full  = "Hello" & " " & "World";

  (* Test deduplication *)
  Same  = "Hello";

VAR
  x : INTEGER;

BEGIN
  x := 42;
END TestLiterals.
