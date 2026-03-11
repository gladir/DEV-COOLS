(* test_arrays.m3 - Test des tableaux (TODO 15)                        *)
(* Verifie le code genere pour :                                       *)
(*   - ARRAY [lo..hi] OF T : tableau a bornes fixes (global et local)  *)
(*   - Acces en lecture arr[i] et ecriture arr[i] := expr              *)
(*   - NUMBER(arr) : nombre d elements du tableau                      *)
(*   - FOR boucle sur indices du tableau                               *)
(*   - Tableau avec borne inferieure non-nulle                         *)

MODULE TestArrays;

IMPORT IO;

VAR
  data : ARRAY [0..4] OF INTEGER;
  counts : ARRAY [1..3] OF INTEGER;

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
  i := local_arr[1];
  IO.PutInt(i);
  IO.PutText("\n");
END FillArray;

PROCEDURE PrintArray() =
VAR
  i : INTEGER;
  n : INTEGER;
BEGIN
  n := NUMBER(data);
  IO.PutText("NUMBER(data) = ");
  IO.PutInt(n);
  IO.PutText("\n");

  FOR i := 0 TO 4 DO
    IO.PutInt(data[i]);
    IO.PutText(" ");
  END;
  IO.PutText("\n");
END PrintArray;

PROCEDURE TestBounds() =
VAR
  j : INTEGER;
BEGIN
  FOR j := 1 TO 3 DO
    IO.PutInt(counts[j]);
    IO.PutText(" ");
  END;
  IO.PutText("\n");
END TestBounds;

BEGIN
  FillArray();
  PrintArray();
  TestBounds();
END TestArrays.
