(* test_emitter.m3 - Test de l emetteur de code ASM (TODO 07)       *)
(* Verifie EmitOpen, EmitHeader, EmitDataSeg, EmitClose.            *)
(* Le compilateur doit generer un fichier .asm valide avec les      *)
(* segments _TEXT et _DATA, les buffers internes et les litteraux.  *)

MODULE TestEmitter;

CONST
  Message = "Bonjour Modula-3";
  Version = "1.0";
  Tab     = "A\tB";

VAR
  x : INTEGER;
  y : CARDINAL;

BEGIN
  x := 42;
  y := 100;
  Wr.PutText(Message);
  Wr.Nl();
END TestEmitter.
