% test_facts.pl - Test de la compilation des faits (TODO 10)

% Faits sans arguments (predicat/0)
hello.
world.

% Faits avec un argument (predicat/1)
animal(cat).
animal(dog).
animal(bird).

% Faits avec deux arguments (predicat/2)
parent(tom, bob).
parent(tom, liz).
parent(bob, ann).

% Faits avec entiers
age(tom, 50).
age(bob, 30).

% Faits avec variable anonyme
likes(_, pizza).

% Fait avec atome special
color(sky, blue).
color(grass, green).
