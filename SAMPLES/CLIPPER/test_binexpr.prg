* test_binexpr.prg - Test des expressions binaires (TODO 11)
* Arithmetique, concatenation chaines, comparaisons, logique

* Declarations locales
LOCAL a := 10
LOCAL b := 3
LOCAL c := 0

* Arithmetique entiere
c := a + b
c := a - b
c := a * b
c := a / b
c := a % b

* Puissance ** et ^
c := 2 ** 8
c := 3 ^ 4

* Concatenation de chaines (+)
LOCAL s1 := "hello"
LOCAL s2 := " world"
LOCAL s3 := s1 + s2

* Soustraction de chaines (- = trim droite + concat)
LOCAL s4 := "hello   "
LOCAL s5 := "world"
LOCAL s6 := s4 - s5

* Containment $ (sous-chaine)
LOCAL found := "ell" $ "hello"
LOCAL notfound := "xyz" $ "hello"

* Comparaison numerique
LOCAL eq1 := (a == b)
LOCAL lt1 := (a < b)
LOCAL gt1 := (a > b)
LOCAL le1 := (a <= b)
LOCAL ge1 := (a >= b)
LOCAL ne1 := (a != b)
LOCAL ne2 := (a <> b)
LOCAL ne3 := (a # b)

* Comparaison de chaines (= souple)
LOCAL ceq := ("abc" = "abc")
LOCAL cne := ("abc" = "xyz")

* Comparaison exacte de chaines (==)
LOCAL cex1 := ("abc" == "abc")
LOCAL cex2 := ("abc" == "abcd")

* Operateurs logiques .AND. .OR. .NOT.
LOCAL l1 := .T. .AND. .T.
LOCAL l2 := .T. .AND. .F.
LOCAL l3 := .F. .OR. .T.
LOCAL l4 := .F. .OR. .F.
LOCAL l5 := .NOT. .T.
LOCAL l6 := ! .F.

* Expressions combinees
c := (a + b) * 2
c := a ** 2 + b
LOCAL logic := (a > 5) .AND. (b < 10)
