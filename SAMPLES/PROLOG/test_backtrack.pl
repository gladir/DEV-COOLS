% test_backtrack.pl - Test du retour arriere / backtracking (TODO 12)

% Faits avec plusieurs clauses (necessite le backtracking)
color(red).
color(green).
color(blue).

% Predicat avec 4 clauses
fruit(apple).
fruit(banana).
fruit(cherry).
fruit(date).

% Faits avec plusieurs arguments et clauses multiples
pair(a, 1).
pair(b, 2).
pair(c, 3).
pair(a, 4).
pair(b, 5).

% Regles avec backtracking sur les faits
colored_fruit(X, C) :- fruit(X), color(C).

% Regle avec variable partagee et backtracking
same_color(X, Y) :- color(X), color(Y).

% Predicat d arite 0 avec plusieurs clauses
greeting :- hello_msg.
greeting :- goodbye_msg.
hello_msg.
goodbye_msg.

% Chaine de regles avec backtracking
grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).
parent(liz, jim).
