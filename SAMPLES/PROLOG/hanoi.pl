% hanoi.pl - Exemple PROLOG86 : tours de Hanoi, recursion, cut
% Demontre la resolution recursive des tours de Hanoi.

% Cas de base : 0 disque, rien a faire
hanoi(0, _, _, _) :- !.

% Cas recursif : deplacer N disques de Source a Dest via Aux
hanoi(N, Source, Dest, Aux) :-
    N > 0,
    N1 is N - 1,
    hanoi(N1, Source, Aux, Dest),
    write(Source), write(' -> '), write(Dest), nl,
    hanoi(N1, Aux, Dest, Source).

% Predicat principal : resoudre pour 3 disques
main :-
    write('Tours de Hanoi :'), nl,
    hanoi(3, gauche, droite, centre).
