# test_functions.awk - Tests pour TODO 13 (fonctions utilisateur function/return)
# 15 cas de test

# Cas 1 : fonction simple sans parametre
function hello() {
  print "cas1: hello world"
}
BEGIN { hello() }

# Cas 2 : fonction avec un parametre
function double(n) {
  return n * 2
}
BEGIN { print "cas2: double(5)=" double(5) }

# Cas 3 : fonction avec deux parametres
function add(a, b) {
  return a + b
}
BEGIN { print "cas3: add(3,4)=" add(3, 4) }

# Cas 4 : fonction avec return sans valeur
function greet(name) {
  print "cas4: bonjour " name
  return
}
BEGIN { greet("monde") }

# Cas 5 : fonction avec variable locale
function count_to(n) {
  i = 0
  s = 0
  while (i < n) {
    s = s + i
    i = i + 1
  }
  return s
}
BEGIN { print "cas5: count_to(5)=" count_to(5) }

# Cas 6 : fonction recursive (factorielle)
function fact(n) {
  if (n <= 1)
    return 1
  return n * fact(n - 1)
}
BEGIN { print "cas6: fact(5)=" fact(5) }

# Cas 7 : fonction avec if/else
function abs_val(x) {
  if (x < 0)
    return 0 - x
  else
    return x
}
BEGIN { print "cas7: abs(-3)=" abs_val(-3) " abs(7)=" abs_val(7) }

# Cas 8 : appel de fonction dans une expression
function square(x) {
  return x * x
}
BEGIN { print "cas8: 2+square(3)=" 2 + square(3) }

# Cas 9 : fonctions imbriquees (appel dans appel)
function inc(n) {
  return n + 1
}
function double_inc(n) {
  return double(inc(n))
}
BEGIN { print "cas9: double_inc(4)=" double_inc(4) }

# Cas 10 : fonction appelee plusieurs fois
function triple(n) {
  return n * 3
}
BEGIN {
  a = triple(2)
  b = triple(3)
  c = triple(4)
  print "cas10: triple(2,3,4)=" a "," b "," c
}

# Cas 11 : fonction avec boucle for
function sum_range(start, end_val) {
  s = 0
  for (i = start; i <= end_val; i = i + 1)
    s = s + i
  return s
}
BEGIN { print "cas11: sum_range(1,10)=" sum_range(1, 10) }

# Cas 12 : fonction modifiant une variable globale
function set_global() {
  global_var = 42
}
BEGIN {
  global_var = 0
  set_global()
  print "cas12: global_var=" global_var
}

# Cas 13 : plusieurs fonctions definies avant utilisation
function f1(x) { return x + 1 }
function f2(x) { return x * 2 }
function f3(x) { return f2(f1(x)) }
BEGIN { print "cas13: f3(5)=" f3(5) }

# Cas 14 : fonction recursive fibonacci
function fib(n) {
  if (n <= 0) return 0
  if (n == 1) return 1
  return fib(n - 1) + fib(n - 2)
}
BEGIN { print "cas14: fib(7)=" fib(7) }

# Cas 15 : fonction avec 3 parametres
function clamp(val, lo, hi) {
  if (val < lo) return lo
  if (val > hi) return hi
  return val
}
BEGIN {
  print "cas15: clamp(-5,0,10)=" clamp(-5, 0, 10) " clamp(5,0,10)=" clamp(5, 0, 10) " clamp(15,0,10)=" clamp(15, 0, 10)
}
