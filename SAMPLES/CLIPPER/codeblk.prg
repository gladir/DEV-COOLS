* codeblk.prg - Exemple Clipper : code blocks, EVAL, closures, AEVAL
* Compilation : CLIPPER86 codeblk.prg

* --- Code block sans parametre ---
LOCAL bHello := {|| 42}
? "EVAL({|| 42}) =", EVAL(bHello)

* --- Code block avec un parametre ---
LOCAL bDouble := {|x| x * 2}
? "Double(5)     =", EVAL(bDouble, 5)
? "Double(13)    =", EVAL(bDouble, 13)

* --- Code block avec deux parametres ---
LOCAL bAdd := {|a, b| a + b}
? "Add(10, 20)   =", EVAL(bAdd, 10, 20)

* --- Code block avec expression complexe ---
LOCAL bCalc := {|n| n * n + 1}
? "Calc(7)       =", EVAL(bCalc, 7)

* --- Code block inline ---
? "Inline        =", EVAL({|x| x + 100}, 23)

* --- AEVAL avec code block (parcours) ---
LOCAL aData := {10, 20, 30, 40, 50}
? "AEVAL affichage :"
AEVAL(aData, {|e| QOut(e)})

* --- AEVAL pour calcul de somme ---
LOCAL nSum
nSum := 0
AEVAL(aData, {|e| nSum := nSum + e})
? "Somme via AEVAL =", nSum

* --- Code block comme argument de fonction ---
LOCAL aList := {5, 3, 8, 1, 9, 2}
? "Avant ASORT :", aList[1], aList[2], aList[3]
ASORT(aList)
? "Apres ASORT :", aList[1], aList[2], aList[3]

* --- Code blocks multiples ---
LOCAL bOps
bOps := {|a, b| a * b}
? "Mul(6, 7) =", EVAL(bOps, 6, 7)

bOps := {|a, b| a - b}
? "Sub(20, 8) =", EVAL(bOps, 20, 8)

? "Fin de codeblk.prg"
RETURN
