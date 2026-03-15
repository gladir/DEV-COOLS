% test_operators.pl - Test user-defined operators (TODO 21)
% Tests: op/3, current_op/3, operator table

% Test 1: Define a custom operator and use current_op to query it
test_op_define :-
    op(700, xfx, likes),
    write('op defined: likes'), nl.

% Test 2: Query a standard operator
test_current_op_std :-
    current_op(P, T, is),
    write('current_op is: '), write(P), write(' '), write(T), nl.

% Test 3: Query the + operator
test_current_op_plus :-
    current_op(P, T, +),
    write('current_op +: '), write(P), write(' '), write(T), nl.

% Test 4: Query a comparison operator
test_current_op_eq :-
    current_op(P, T, =),
    write('current_op =: '), write(P), write(' '), write(T), nl.

% Test 5: Define and query a new operator
test_op_new :-
    op(600, xfy, then),
    current_op(P, T, then),
    write('new op then: '), write(P), write(' '), write(T), nl.

:- test_op_define.
:- test_current_op_std.
:- test_current_op_plus.
:- test_current_op_eq.
:- test_op_new.
