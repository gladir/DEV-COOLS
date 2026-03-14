% queens.pl - Exemple PROLOG86 : N-reines, generate-and-test, findall
% Demontre la resolution du probleme des N-reines.

% Generer une permutation
perm([], []).
perm(List, [H|Perm]) :-
    delete(H, List, Rest),
    perm(Rest, Perm).

delete(X, [X|T], T).
delete(X, [H|T], [H|R]) :- delete(X, T, R).

% Verifier que les reines ne s attaquent pas
safe([]).
safe([Q|Qs]) :- no_attack(Q, Qs, 1), safe(Qs).

no_attack(_, [], _).
no_attack(Q, [Q1|Qs], D) :-
    Diff1 is Q1 - Q,
    Diff2 is Q - Q1,
    Diff1 =\= D,
    Diff2 =\= D,
    D1 is D + 1,
    no_attack(Q, Qs, D1).

% Resoudre N-reines pour N=4
queens(Qs) :-
    perm([1, 2, 3, 4], Qs),
    safe(Qs).

% Predicat principal
main :-
    queens(Q),
    write(Q), nl.
