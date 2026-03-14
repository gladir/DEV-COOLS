% test_lists.pl - Test de la compilation des listes (TODO 13)

% Fait avec argument liste vide
empty([]).

% Fait avec liste simple [a, b, c]
letters([a, b, c]).

% Fait avec liste d entiers
numbers([1, 2, 3]).

% Fait avec liste singleton
single([x]).

% Fait avec notation tete|queue
pair([H|T]) :- head(H), tail(T).
head(a).
tail([b, c]).

% Liste dans la tete d une regle
first([X|_], X).

% Liste dans le corps d une regle
make_list(X, Y, Z) :- check([X, Y, Z]).
check([a, b, c]).

% Fait avec liste imbriquee
nested([1, [2, 3], 4]).

% Regle utilisant [H|T] dans la tete
my_head([H|_], H).
my_tail([_|T], T).

% Fait avec liste et atomes melanges
mixed(hello, [1, 2], world).

% Regle avec liste dans les buts du corps
process(X) :- transform(X, [done]).
transform(a, [done]).

% Fait avec liste vide comme argument
clear([], 0).
clear([_|T], N) :- clear(T, N).
