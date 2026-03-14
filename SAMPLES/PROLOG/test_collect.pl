% test_collect.pl - Test solution collection (TODO 20)
% Tests: findall/3, bagof/3, setof/3
% Note: parser only supports simple terms, so goals are arity-0 predicates

succeed :- true.

test_findall :-
    findall(a, succeed, Bag),
    write('findall: '), write(Bag), nl.

test_findall_empty :-
    findall(a, fail, Bag),
    write('findall empty: '), write(Bag), nl.

test_bagof :-
    bagof(a, succeed, Bag),
    write('bagof: '), write(Bag), nl.

test_setof :-
    setof(a, succeed, Set),
    write('setof: '), write(Set), nl.

:- test_findall.
:- test_findall_empty.
:- test_bagof.
:- test_setof.
