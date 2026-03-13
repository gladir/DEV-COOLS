% test_arith.pl - Test du TODO 14 : Arithmetique (is et evaluation)

% Fait simple pour write
greeting :- write(hello).

% Test 1 : X is entier simple
test_simple(X) :- X is 42.

% Test 2 : X is addition
test_add(X) :- X is 2 + 3.

% Test 3 : X is soustraction
test_sub(X) :- X is 10 - 4.

% Test 4 : X is multiplication
test_mul(X) :- X is 3 * 7.

% Test 5 : X is division
test_div(X) :- X is 20 / 4.

% Test 6 : X is modulo
test_mod(X) :- X is 17 mod 5.

% Test 7 : X is expression complexe (precedence)
test_complex(X) :- X is 2 + 3 * 4.

% Test 8 : X is avec parentheses
test_paren(X) :- X is (2 + 3) * 4.

% Test 9 : X is negatif unaire
test_neg(X) :- X is -5.

% Test 10 : X is avec variable
test_var(X, Y) :- Y is X + 1.

% Test 11 : abs
test_abs(X) :- X is abs(-7).

% Test 12 : succ
test_succ(X) :- X is succ(9).

% Test 13 : max et min
test_max(X) :- X is max(3, 8).
test_min(X) :- X is min(3, 8).

% Test 14 : comparaison arithmetique
test_gt(X) :- X > 5.
test_lt(X) :- X < 10.
test_eq :- 3 =:= 3.
test_neq :- 3 =\= 4.
test_leq :- 3 =< 5.
test_geq :- 7 >= 3.
