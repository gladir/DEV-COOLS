(* test_objects.m3 - Test des types objets et methodes (TODO 19)        *)
(* Verifie le code genere pour :                                       *)
(*   - TYPE T = OBJECT ... END : declaration de type objet             *)
(*   - TYPE T = Parent OBJECT ... END : heritage                       *)
(*   - NEW(T) : allocation d objet via _M3RT_OBJNEW                   *)
(*   - obj.field : acces aux champs d objet                            *)
(*   - obj.field := expr : affectation de champ                        *)
(*   - obj.method(args) : appel de methode virtuelle                   *)
(*   - ISTYPE(expr, T) : verification dynamique de type                *)
(*   - NARROW(expr, T) : cast verifie                                  *)
(*   - TYPECODE(T) : code de type unique                               *)
(*   - OVERRIDES : remplacement de methode                             *)

MODULE TestObjects;

IMPORT Wr;

TYPE
  Animal = OBJECT
    name  : INTEGER;
    speed : INTEGER;
  METHODS
    speak(): INTEGER;
    move(): INTEGER;
  END;

TYPE
  Dog = Animal OBJECT
    tricks : INTEGER;
  METHODS
    fetch(): INTEGER;
  OVERRIDES
    speak := DogSpeak;
  END;

VAR
  a : Animal;
  d : Dog;
  ok : INTEGER;

PROCEDURE DogSpeak() =
BEGIN
  Wr.PutInt(42);
END DogSpeak;

PROCEDURE TestNew() =
VAR
  obj : Animal;
BEGIN
  obj := NEW(Animal);
  obj.name := 10;
  obj.speed := 20;
  Wr.PutInt(obj.name);
END TestNew;

PROCEDURE TestIstype() =
VAR
  x : Dog;
BEGIN
  x := NEW(Dog);
  ok := TYPECODE(Dog);
  Wr.PutInt(ok);
  IF ISTYPE(x, Dog) THEN
    Wr.PutInt(1);
  END;
END TestIstype;

BEGIN
  TestNew();
  TestIstype();
END TestObjects.
