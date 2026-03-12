% test_builtins.pl - Test des predicats predefinis (TODO 18)
% Teste les BIF_xxx, ground/1, =../2, reverse/2, sort/2, msort/2,
% call/1, unify_with_occurs_check/2, read/1

% --- ground/1 ---
test_ground_atom :- ground(hello).
test_ground_int :- ground(42).
test_ground_list :- ground([1,2,3]).

% --- =../2 (univ) ---
test_univ_atom(X) :- hello =.. X.
test_univ_int(X) :- 42 =.. X.
test_univ_var(X, Y) :- X =.. Y.

% --- reverse/2 ---
test_reverse(X) :- reverse([1,2,3], X).
test_reverse_empty(X) :- reverse([], X).

% --- sort/2 ---
test_sort(X) :- sort([3,1,2,1], X).

% --- msort/2 ---
test_msort(X) :- msort([3,1,2,1], X).

% --- call/1 ---
greet :- write(hello), nl.
test_call :- call(greet).

% --- unify_with_occurs_check/2 ---
test_uoc :- unify_with_occurs_check(X, hello), write(X), nl.

% --- Predicats deja implementes, verif via BIF codes ---
test_true :- true.
test_fail_neg :- \+(fail).
test_var(X) :- var(X).
test_nonvar :- nonvar(hello).
test_atom :- atom(hello).
test_number :- number(42).
test_integer :- integer(42).
test_is_list :- is_list([1,2,3]).
test_callable :- callable(hello).
test_copy_term(X) :- copy_term([1,2], X).
test_write :- write(hello), nl.
test_writeln :- writeln(world).
test_atom_length(N) :- atom_length(hello, N).
test_atom_concat(X) :- atom_concat(hel, lo, X).
test_char_code(X) :- char_code(a, X).
