% peano.pl - Exemple PROLOG86 : arithmetique de Peano, unification
% Utilise des listes pour representer les nombres de Peano.
% 0 = [], 1 = [s], 2 = [s, s], 3 = [s, s, s], etc.

% Addition de Peano : add(X, Y, Z) signifie X + Y = Z
add([], Y, Y).
add([s|X], Y, [s|Z]) :- add(X, Y, Z).

% Predecessor
pred([s|X], X).

% Inferieur ou egal
leq([], _).
leq([s|X], [s|Y]) :- leq(X, Y).

% Conversion entier -> Peano
to_peano(0, []) :- !.
to_peano(N, [s|P]) :-
    N > 0,
    N1 is N - 1,
    to_peano(N1, P).

% Conversion Peano -> entier
to_int([], 0).
to_int([_|T], N) :-
    to_int(T, N1),
    N is N1 + 1.

% Predicat principal
main :-
    to_peano(2, P2),
    to_peano(3, P3),
    add(P2, P3, Sum),
    to_int(Sum, N),
    write(N), nl,
    leq(P2, P3),
    write(leq_ok), nl.
