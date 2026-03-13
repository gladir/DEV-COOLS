* test_codeblk.prg - Test des code blocks et EVAL (TODO 18)

* Test 1 : Code block sans parametre
LOCAL b1 := {|| 42}
? EVAL(b1)

* Test 2 : Code block avec un parametre
LOCAL b2 := {|x| x * 2}
? EVAL(b2, 5)

* Test 3 : Code block avec deux parametres
LOCAL b3 := {|a,b| a + b}
? EVAL(b3, 10, 20)

* Test 4 : Code block inline dans EVAL
? EVAL({|| 99})

* Test 5 : Code block avec expression complexe
LOCAL b4 := {|n| n * n + 1}
? EVAL(b4, 7)

* Test 6 : AEVAL avec code block
LOCAL arr := {1, 2, 3}
AEVAL(arr, {|e| QOut(e)})

RETURN
