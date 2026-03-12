(* test_modules.m3 - Test des interfaces et modules (TODO 18)        *)
(* Verifie ParseDataDecls avec IMPORT, FROM...IMPORT, EXPORTS,      *)
(* detection INTERFACE vs MODULE, noms qualifies, REVEAL.            *)
(* Ce fichier teste un MODULE avec clause EXPORTS et imports.        *)

MODULE TestModules EXPORTS TestModulesIntf;

IMPORT Wr, Fmt;
IMPORT Text;
FROM Math IMPORT Sin, Cos;

CONST
  Version = 1;
  Name    = "TestModules";

TYPE
  Color = {Red, Green, Blue};

VAR
  counter : INTEGER;
  label   : TEXT;

REVEAL
  OpaqueType = INTEGER;

PROCEDURE GetVersion(): INTEGER =
BEGIN
  RETURN Version;
END GetVersion;

PROCEDURE Greet() =
BEGIN
  Wr.PutText("Module: ");
  Wr.PutText(Name);
  Wr.Nl();
END Greet;

PROCEDURE TestImports() =
VAR
  t : TEXT;
  n : INTEGER;
BEGIN
  (* Test qualified names from IMPORT *)
  Wr.PutText("Hello from TestModules");
  Wr.Nl();

  (* Test Fmt.Int *)
  t := Fmt.Int(42);
  Wr.PutText(t);
  Wr.Nl();

  (* Test Text.Length *)
  n := Text.Length("abc");
  Wr.PutInt(n);
  Wr.Nl();
END TestImports;

BEGIN
  counter := 0;
  label := "default";
  Greet();
  TestImports();
  Wr.PutText("Modules OK");
  Wr.Nl();
END TestModules.
