* test_strings.prg - Test chaines de caracteres (TODO 16)
* Compilation : CLIPPER86 test_strings.prg

* ---- Test 1 : UPPER ----
LOCAL s
s := "hello"
? "Test 1: UPPER ="
?? UPPER(s)

* ---- Test 2 : LOWER ----
? "Test 2: LOWER ="
?? LOWER("WORLD")

* ---- Test 3 : TRIM / RTRIM ----
? "Test 3: TRIM ="
?? TRIM("abc   ")

* ---- Test 4 : LTRIM ----
? "Test 4: LTRIM ="
?? LTRIM("   def")

* ---- Test 5 : ALLTRIM ----
? "Test 5: ALLTRIM ="
?? ALLTRIM("  ghi  ")

* ---- Test 6 : LEFT ----
? "Test 6: LEFT ="
?? LEFT("abcdef", 3)

* ---- Test 7 : RIGHT ----
? "Test 7: RIGHT ="
?? RIGHT("abcdef", 3)

* ---- Test 8 : SUBSTR ----
? "Test 8: SUBSTR ="
?? SUBSTR("abcdef", 2, 3)

* ---- Test 9 : AT ----
LOCAL p
p := AT("cd", "abcdef")
? "Test 9: AT ="
?? p

* ---- Test 10 : RAT ----
LOCAL q
q := RAT("ab", "ababab")
? "Test 10: RAT ="
?? q

* ---- Test 11 : REPLICATE ----
? "Test 11: REPLICATE ="
?? REPLICATE("ab", 3)

* ---- Test 12 : SPACE ----
? "Test 12: SPACE(5) ="
?? SPACE(5)
?? "."

* ---- Test 13 : CHR / ASC ----
LOCAL c
c := CHR(65)
? "Test 13: CHR(65) ="
?? c
? "Test 13: ASC ="
?? ASC(c)

* ---- Test 14 : STR / VAL ----
? "Test 14: STR ="
?? STR(42)
? "Test 14: VAL ="
?? VAL("123")

* ---- Test 15 : PADR ----
? "Test 15: PADR ="
?? PADR("ab", 5)
?? "."

* ---- Test 16 : PADL ----
? "Test 16: PADL ="
?? PADL("ab", 5)
?? "."

* ---- Test 17 : PADC ----
? "Test 17: PADC ="
?? PADC("ab", 6)
?? "."

* ---- Test 18 : STRTRAN ----
? "Test 18: STRTRAN ="
?? STRTRAN("hello world", "world", "terre")

* ---- Test 19 : STUFF ----
? "Test 19: STUFF ="
?? STUFF("abcdef", 3, 2, "XY")

* ---- Test 20 : TRANSFORM ----
? "Test 20: TRANSFORM ="
?? TRANSFORM("test", "@!")

? "Fin des tests chaines"
