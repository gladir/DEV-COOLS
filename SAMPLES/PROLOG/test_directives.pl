% test_directives.pl - Test directives and loading (TODO 22)
% Tests: :- module/2, :- use_module/1, :- dynamic/1,
%         :- discontiguous/1, :- ensure_loaded/1,
%         :- op/3, :- initialization/1, :- Goal.

% Test 1: Module declaration
:- module(test_mod, [hello/0, greet/1]).

% Test 2: Use module
:- use_module(lists).

% Test 3: Dynamic predicate declaration
:- dynamic(counter/1).
:- dynamic(memo/2).

% Test 4: Dynamic without parentheses
:- dynamic fact/1.

% Test 5: Discontiguous declaration
:- discontiguous(animal/1).

% Test 6: Ensure loaded
:- ensure_loaded(utils).

% Test 7: Operator definition via directive
:- op(700, xfx, likes).
:- op(600, xfy, then).

% Test 8: Initialization directive
:- initialization(true).

% Some facts for the predicates
hello.
greet(world).
counter(0).
memo(a, 1).
fact(x).
animal(cat).
animal(dog).

% Test 9: Goal directives (general :- Goal.)
test_write :-
    write('directives ok'), nl.

:- test_write.
