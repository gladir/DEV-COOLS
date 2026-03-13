% test_dyndb.pl - Test dynamic database (TODO 19)
% Tests: assert/1, asserta/1, assertz/1, retract/1, abolish/1
% Note: parser only supports simple terms as args (atoms, ints, vars)

test_assertz :- assertz(bird), write('assertz ok'), nl.
test_asserta :- asserta(fish), write('asserta ok'), nl.
test_retract :- retract(bird), write('retract ok'), nl.
test_abolish :- abolish(fish), write('abolish ok'), nl.

:- test_assertz.
:- test_asserta.
:- test_retract.
:- test_abolish.
