* test_vars.prg - Test TODO 09 : variables et affectations
* Declarations LOCAL, STATIC, PRIVATE, PUBLIC
* Affectations := et composees
* STORE expr TO var1, var2

* Declarations LOCAL avec initialisation
LOCAL x := 10
LOCAL y := 20, z := 30

* Declaration STATIC
STATIC s := 100

* Declaration PRIVATE
PRIVATE p

* Declaration PUBLIC
PUBLIC g := 42

* Affectation simple
x := 5

* Affectation composee
x += 3
y -= 1
z *= 2

* STORE vers plusieurs variables
STORE 99 TO p, g

* Variables implicites (PRIVATE par defaut)
a := 1
b := 2

* PARAMETERS (pour DO...WITH)
PARAMETERS arg1, arg2

* Declaration avec expression
LOCAL w := x + y
