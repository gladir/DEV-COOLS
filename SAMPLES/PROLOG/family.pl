% family.pl - Exemple PROLOG86 : faits, regles, requetes, retour arriere
% Demontre un arbre genealogique classique avec des regles deductives.

% Faits : parent(Parent, Enfant)
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).
parent(bob, pat).
parent(pat, jim).

% Faits : genre
male(tom).
male(bob).
male(jim).
female(liz).
female(ann).
female(pat).

% Regles deductives
father(X, Y) :- parent(X, Y), male(X).
mother(X, Y) :- parent(X, Y), female(X).

grandparent(X, Z) :- parent(X, Y), parent(Y, Z).
grandfather(X, Z) :- grandparent(X, Z), male(X).

sibling(X, Y) :- parent(P, X), parent(P, Y), X \== Y.
brother(X, Y) :- sibling(X, Y), male(X).
sister(X, Y) :- sibling(X, Y), female(X).

ancestor(X, Y) :- parent(X, Y).
ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).

% Predicat principal
main :-
    father(tom, bob),
    write(father_ok), nl,
    grandparent(tom, ann),
    write(grandparent_ok), nl,
    sibling(ann, pat),
    write(sibling_ok), nl,
    ancestor(tom, jim),
    write(ancestor_ok), nl.
