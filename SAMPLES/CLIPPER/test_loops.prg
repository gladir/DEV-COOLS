* test_loops.prg - Test boucles DO WHILE / FOR / LOOP / EXIT (TODO 14)
* Compilation : CLIPPER86 test_loops.prg

* ---- Test 1 : DO WHILE simple ----
LOCAL i
i := 0
DO WHILE i < 5
  i := i + 1
ENDDO
? "Test 1: i ="
?? i

* ---- Test 2 : DO WHILE avec EXIT ----
LOCAL j
j := 0
DO WHILE .T.
  j := j + 1
  IF j = 3
    EXIT
  ENDIF
ENDDO
? "Test 2: j ="
?? j

* ---- Test 3 : DO WHILE avec LOOP ----
LOCAL k, total
k := 0
total := 0
DO WHILE k < 10
  k := k + 1
  IF k = 5
    LOOP
  ENDIF
  total := total + k
ENDDO
? "Test 3: total ="
?? total

* ---- Test 4 : FOR simple ----
LOCAL n
n := 0
FOR i := 1 TO 5
  n := n + i
NEXT
? "Test 4: n ="
?? n

* ---- Test 5 : FOR avec STEP ----
LOCAL m
m := 0
FOR i := 0 TO 10 STEP 2
  m := m + 1
NEXT
? "Test 5: m ="
?? m

* ---- Test 6 : FOR avec EXIT ----
LOCAL p
p := 0
FOR i := 1 TO 100
  IF i > 3
    EXIT
  ENDIF
  p := p + i
NEXT
? "Test 6: p ="
?? p

* ---- Test 7 : Boucles imbriquees ----
LOCAL a, b, count
count := 0
FOR a := 1 TO 3
  FOR b := 1 TO 3
    count := count + 1
  NEXT
NEXT
? "Test 7: count ="
?? count

* ---- Test 8 : DO WHILE condition fausse ----
LOCAL never
never := 0
DO WHILE .F.
  never := 1
ENDDO
? "Test 8: never ="
?? never

* ---- Test 9 : FOR avec STEP negatif ----
LOCAL s
s := 0
FOR i := 5 TO 1 STEP -1
  s := s + i
NEXT
? "Test 9: s ="
?? s

? "Fin des tests boucles"
