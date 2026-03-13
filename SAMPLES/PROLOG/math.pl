% math.pl - Exemple PROLOG86 : arithmetique, is, predicats recursifs
% Demontre l evaluation arithmetique et la recursion.

% Factorielle (recursion classique)
factorial(0, 1).
factorial(N, F) :-
    N > 0,
    N1 is N - 1,
    factorial(N1, F1),
    F is N * F1.

% Fibonacci
fib(0, 0).
fib(1, 1).
fib(N, F) :-
    N > 1,
    N1 is N - 1,
    N2 is N - 2,
    fib(N1, F1),
    fib(N2, F2),
    F is F1 + F2.

% Maximum de deux nombres
max(X, Y, X) :- X >= Y, !.
max(_, Y, Y).

% Minimum de deux nombres
min(X, Y, X) :- X =< Y, !.
min(_, Y, Y).

% Valeur absolue
my_abs(X, X) :- X >= 0, !.
my_abs(X, A) :- A is 0 - X.

% PGCD (algorithme d Euclide)
gcd(X, 0, X) :- X > 0, !.
gcd(X, Y, G) :- Y > 0, R is X mod Y, gcd(Y, R, G).

% Predicat principal
main :-
    factorial(5, F), write(F), nl,
    fib(6, Fib), write(Fib), nl,
    gcd(12, 8, G), write(G), nl.
