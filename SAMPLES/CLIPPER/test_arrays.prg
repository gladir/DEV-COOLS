* test_arrays.prg - Test tableaux (TODO 15)
* Compilation : CLIPPER86 test_arrays.prg

* ---- Test 1 : Literal tableau ----
LOCAL a
a := {10, 20, 30}
? "Test 1: a[1] ="
?? a[1]

* ---- Test 2 : LEN ----
? "Test 2: LEN(a) ="
?? LEN(a)

* ---- Test 3 : AADD ----
AADD(a, 40)
? "Test 3: LEN apres AADD ="
?? LEN(a)

* ---- Test 4 : Affectation element ----
a[2] := 99
? "Test 4: a[2] ="
?? a[2]

* ---- Test 5 : ASCAN ----
LOCAL pos
pos := ASCAN(a, 99)
? "Test 5: ASCAN(a,99) ="
?? pos

* ---- Test 6 : AFILL ----
LOCAL b
b := {0, 0, 0}
AFILL(b, 7)
? "Test 6: b[1] ="
?? b[1]

* ---- Test 7 : ACLONE ----
LOCAL c
c := ACLONE(a)
? "Test 7: c[1] ="
?? c[1]

* ---- Test 8 : ASORT ----
LOCAL d
d := {30, 10, 20}
ASORT(d)
? "Test 8: d[1] ="
?? d[1]

* ---- Test 9 : FOR EACH ----
LOCAL e, total
e := {1, 2, 3, 4, 5}
total := 0
FOR EACH x IN e
  total := total + x
NEXT
? "Test 9: total ="
?? total

? "Fin des tests tableaux"
