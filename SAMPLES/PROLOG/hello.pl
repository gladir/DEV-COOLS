% hello.pl - Exemple PROLOG86 : write, nl, atomes, variables
% Demontre les bases de l ecriture et de l unification simple.

% Faits atomiques
greeting(hello).
greeting(bonjour).
target(world).
target(prolog).

% Afficher un message simple
say(X) :- write(X), nl.

% Combiner atome et variable
hello_to(X) :- write(hello), write(' '), write(X), nl.

% Predicat principal
main :-
    say(hello),
    say(world),
    greeting(G),
    target(T),
    write(G), write(' '), write(T), nl.
