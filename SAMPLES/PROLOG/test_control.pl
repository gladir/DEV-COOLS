% test_control.pl - Test TODO 16 : cut, if-then-else, negation
% Teste les constructions de controle de PROLOG86

% --- Cut ! ---
% max avec cut : premiere clause reussit si X >= Y
max(X, Y, X) :- X >= Y, !.
max(_, Y, Y).

% --- true/0 et fail/0 ---
always_true :- true.

% --- Negation par echec \+ ---
animal(cat).
animal(dog).
plant(rose).

not_animal(X) :- \+(animal(X)).

% --- halt est teste implicitement (on ne l appelle pas dans les tests) ---

% --- Requetes ---
?- max(5, 3, X).
?- max(2, 7, Y).
?- always_true.
?- not_animal(rose).
?- animal(cat).
