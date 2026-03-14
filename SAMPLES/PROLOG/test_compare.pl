% test_compare.pl - Test du TODO 15 : Comparaison et tests de type

% Test 1 : unification =/2
test_unify(X) :- X = hello.

% Test 2 : non-unification \=/2
test_not_unify(X) :- X \= world.

% Test 3 : egalite structurelle ==/2
test_struct_eq(X, Y) :- X == Y.

% Test 4 : inegalite structurelle \==/2
test_struct_neq(X, Y) :- X \== Y.

% Test 5 : ordre standard @</2
test_order_lt(X, Y) :- X @< Y.

% Test 6 : ordre standard @>/2
test_order_gt(X, Y) :- X @> Y.

% Test 7 : var/1
test_var(X) :- var(X).

% Test 8 : nonvar/1
test_nonvar(X) :- nonvar(X).

% Test 9 : atom/1
test_atom(X) :- atom(X).

% Test 10 : number/1
test_number(X) :- number(X).

% Test 11 : integer/1
test_integer(X) :- integer(X).

% Test 12 : compound/1
test_compound(X) :- compound(X).

% Test 13 : is_list/1
test_is_list(X) :- is_list(X).

% Test 14 : callable/1
test_callable(X) :- callable(X).

% Test 15 : functor/3
test_functor(T, N, A) :- functor(T, N, A).

% Test 16 : arg/3
test_arg(N, T, A) :- arg(N, T, A).

% Test 17 : copy_term/2
test_copy(X, Y) :- copy_term(X, Y).

% Test 18 : combinaison
test_combined(X) :- nonvar(X), atom(X), X \== hello.

% Test 19 : ordre standard @=</2
test_order_leq(X, Y) :- X @=< Y.

% Test 20 : ordre standard @>=/2
test_order_geq(X, Y) :- X @>= Y.
