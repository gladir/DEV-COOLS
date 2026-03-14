(* arrays.m3 - Exemple de tableaux (TODO 25)                            *)
(* Demontre : ARRAY [lo..hi] OF T fixe, tableaux globaux et locaux,    *)
(* acces lecture/ecriture arr[i], NUMBER(arr), boucles FOR sur indices, *)
(* bornes non-nulles, SUBARRAY.                                         *)

MODULE ArrayExample;

IMPORT Wr;

VAR
  data   : ARRAY [0..4] OF INTEGER;
  scores : ARRAY [1..5] OF INTEGER;

(* ---- Remplissage et lecture d un tableau ---- *)
PROCEDURE FillAndPrint() =
VAR
  i : INTEGER;
BEGIN
  (* Remplir *)
  data[0] := 10;
  data[1] := 20;
  data[2] := 30;
  data[3] := 40;
  data[4] := 50;

  (* Afficher *)
  Wr.PutText("data : ");
  FOR i := 0 TO 4 DO
    Wr.PutInt(data[i]);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END FillAndPrint;

(* ---- Tableau avec bornes 1..N ---- *)
PROCEDURE TestBounds() =
VAR
  j : INTEGER;
BEGIN
  scores[1] := 85;
  scores[2] := 92;
  scores[3] := 78;
  scores[4] := 95;
  scores[5] := 88;

  Wr.PutText("scores : ");
  FOR j := 1 TO 5 DO
    Wr.PutInt(scores[j]);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END TestBounds;

(* ---- NUMBER et calcul de somme ---- *)
PROCEDURE TestNumber() =
VAR
  i   : INTEGER;
  n   : INTEGER;
  sum : INTEGER;
BEGIN
  n := NUMBER(data);
  Wr.PutText("NUMBER(data) = ");
  Wr.PutInt(n);
  Wr.Nl();

  sum := 0;
  FOR i := 0 TO 4 DO
    sum := sum + data[i];
  END;
  Wr.PutText("Somme = ");
  Wr.PutInt(sum);
  Wr.Nl();
END TestNumber;

(* ---- Tableau local ---- *)
PROCEDURE TestLocal() =
VAR
  local : ARRAY [0..2] OF INTEGER;
BEGIN
  local[0] := 100;
  local[1] := 200;
  local[2] := 300;

  Wr.PutText("local[1] = ");
  Wr.PutInt(local[1]);
  Wr.Nl();
END TestLocal;

(* ---- Lecture et ecriture combinee ---- *)
PROCEDURE TestReadWrite() =
VAR
  tmp : INTEGER;
BEGIN
  tmp := data[0] + data[4];
  Wr.PutText("data[0]+data[4] = ");
  Wr.PutInt(tmp);
  Wr.Nl();

  data[2] := data[0] + data[1];
  Wr.PutText("data[2] apres := ");
  Wr.PutInt(data[2]);
  Wr.Nl();
END TestReadWrite;

(* ---- Programme principal ---- *)
BEGIN
  Wr.PutText("=== Fill & Print ==="); Wr.Nl();
  FillAndPrint();

  Wr.PutText("=== Bornes 1..5 ==="); Wr.Nl();
  TestBounds();

  Wr.PutText("=== NUMBER ==="); Wr.Nl();
  TestNumber();

  Wr.PutText("=== Local array ==="); Wr.Nl();
  TestLocal();

  Wr.PutText("=== Read/Write ==="); Wr.Nl();
  TestReadWrite();

  Wr.PutText("Termine.");
  Wr.Nl();
END ArrayExample.
