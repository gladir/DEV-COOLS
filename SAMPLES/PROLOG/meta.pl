% meta.pl - Exemple PROLOG86 : assert, retract, call, findall, bagof
% Demontre les predicats meta-logiques et la base dynamique.

% Faits initiaux
color(red).
color(green).
color(blue).

fruit(apple).
fruit(banana).

% Test assert et retract (termes simples)
test_assert :-
    assertz(cherry),
    write(asserted), nl.

test_retract :-
    retract(cherry),
    write(retracted), nl.

% Buts simples pour findall/bagof
goal_color :- color(_).
goal_fruit :- fruit(_).

% Test findall
test_findall :-
    findall(a, goal_color, Colors),
    write(Colors), nl.

% Test bagof
test_bagof :-
    bagof(a, goal_fruit, Fruits),
    write(Fruits), nl.

% Predicat principal
main :-
    test_assert,
    test_retract,
    test_findall,
    test_bagof.
