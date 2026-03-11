(* test_arrays.m3 - Test des tableaux (TODO 15)                        *)
(* Verifie le code genere pour :                                       *)
(*   - ARRAY [lo..hi] OF T : tableau a bornes fixes (global et local)  *)
(*   - Acces en lecture arr[i] et ecriture arr[i] := expr              *)
(*   - NUMBER(arr) : nombre d elements du tableau                      *)
(*   - FOR boucle sur indices du tableau                               *)
(*   - Tableau avec borne inferieure non-nulle                         *)

MODULE TestArrays;

IMPORT Wr;

VAR
  data : ARRAY [0..4] OF INTEGER;
  counts : ARRAY [1..3] OF INTEGER;

(* ---- Test 1 : remplir et lire un tableau global ---- *)
PROCEDURE FillArray() =
VAR
  i : INTEGER;
  local_arr : ARRAY [0..2] OF INTEGER;
BEGIN
  (* Remplir le tableau global *)
  data[0] := 10;
  data[1] := 20;
  data[2] := 30;
  data[3] := 40;
  data[4] := 50;

  (* Remplir le tableau a bornes 1..3 *)
  counts[1] := 100;
  counts[2] := 200;
  counts[3] := 300;

  (* Tableau local *)
  local_arr[0] := 7;
  local_arr[1] := 8;
  local_arr[2] := 9;

  (* Lire le tableau local *)
  Wr.PutText("local_arr[1] = ");
  i := local_arr[1];
  Wr.PutInt(i);
  Wr.Nl();
END FillArray;

(* ---- Test 2 : NUMBER et parcours du tableau ---- *)
PROCEDURE PrintArray() =
VAR
  i : INTEGER;
  n : INTEGER;
BEGIN
  n := NUMBER(data);
  Wr.PutText("NUMBER(data) = ");
  Wr.PutInt(n);
  Wr.Nl();

  Wr.PutText("data: ");
  FOR i := 0 TO 4 DO
    Wr.PutInt(data[i]);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END PrintArray;

(* ---- Test 3 : tableau avec borne non-nulle ---- *)
PROCEDURE TestBounds() =
VAR
  j : INTEGER;
BEGIN
  Wr.PutText("counts[1..3]: ");
  FOR j := 1 TO 3 DO
    Wr.PutInt(counts[j]);
    Wr.PutChar(' ');
  END;
  Wr.Nl();
END TestBounds;

(* ---- Test 4 : lecture et ecriture combinee ---- *)
PROCEDURE TestReadWrite() =
VAR
  sum : INTEGER;
BEGIN
  sum := data[0] + data[4];
  Wr.PutText("data[0]+data[4] = ");
  Wr.PutInt(sum);
  Wr.Nl();

  data[2] := data[0] + data[1];
  Wr.PutText("data[2] apres := ");
  Wr.PutInt(data[2]);
  Wr.Nl();
END TestReadWrite;

(* ---- Programme principal ---- *)
BEGIN
  Wr.PutText("=== Test FillArray ==="); Wr.Nl();
  FillArray();

  Wr.PutText("=== Test PrintArray ==="); Wr.Nl();
  PrintArray();

  Wr.PutText("=== Test Bounds ==="); Wr.Nl();
  TestBounds();

  Wr.PutText("=== Test ReadWrite ==="); Wr.Nl();
  TestReadWrite();

  Wr.PutText("=== All array tests done ==="); Wr.Nl();
END TestArrays.
