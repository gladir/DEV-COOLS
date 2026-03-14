* test_expr.prg - Test des expressions primaires (TODO 10)
* IIF, EVAL, FIELD->, macro &, array access, appel de fonction

* Declarations locales
LOCAL x := 10
LOCAL y := 20
LOCAL z := 0

* IIF : expression conditionnelle inline
z := IIF(x > y, 100, 200)

* IIF avec .T. et .F.
z := IIF(.T., 42, 0)
z := IIF(.F., 0, 99)

* EVAL d un code block (stub appel)
EVAL({|| 42})

* Appel de fonction connue
z := LEN("hello")
z := SUBSTR("abcdef", 2, 3)

* Variable avec acces tableau
LOCAL arr
arr[1]
arr[2, 3]

* Acces champ FIELD
FIELD->NOM

* Macro substitution
LOCAL cCmd := "hello"
&cCmd

* Parentheses
z := (x + y) * 2

* SELF (stub OOP)
SELF

* NIL
z := NIL
