% lists.pl - Exemple PROLOG86 : listes, append, member, reverse, tri
% Demontre les operations classiques sur les listes.

% Appartenance a une liste
member(X, [X|_]).
member(X, [_|T]) :- member(X, T).

% Concatenation de listes
append([], L, L).
append([H|T], L, [H|R]) :- append(T, L, R).

% Longueur d une liste
length([], 0).
length([_|T], N) :- length(T, N1), N is N1 + 1.

% Inverser une liste (avec accumulateur)
reverse(L, R) :- rev_acc(L, [], R).
rev_acc([], Acc, Acc).
rev_acc([H|T], Acc, R) :- rev_acc(T, [H|Acc], R).

% Dernier element
last([X], X).
last([_|T], X) :- last(T, X).

% N-ieme element (0-indexe)
nth(0, [X|_], X).
nth(N, [_|T], X) :- N > 0, N1 is N - 1, nth(N1, T, X).

% Supprimer un element
delete(X, [X|T], T).
delete(X, [H|T], [H|R]) :- delete(X, T, R).

% Predicat principal
main :-
    member(b, [a, b, c]),
    write(ok), nl,
    append([1, 2], [3, 4], L),
    write(L), nl,
    length([a, b, c, d], N),
    write(N), nl,
    reverse([1, 2, 3], R),
    write(R), nl.
