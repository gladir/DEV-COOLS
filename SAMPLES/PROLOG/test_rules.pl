% test_rules.pl - Test de la compilation des regles (TODO 11)

% Faits de base
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).

male(tom).
male(bob).
female(liz).
female(ann).
female(pat).

% Regle avec un seul but (arite 1)
man(X) :- male(X).
woman(X) :- female(X).

% Regle avec plusieurs buts (conjonction)
father(X, Y) :- parent(X, Y), male(X).
mother(X, Y) :- parent(X, Y), female(X).

% Regle avec variables differentes
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).

% Regle sans arguments dans les buts
hello :- world.
world.

% Regle avec atomes dans le corps
likes(X, pizza) :- human(X).
human(tom).

% Regle avec entier
age_ok(X) :- age(X, 30).
age(bob, 30).
