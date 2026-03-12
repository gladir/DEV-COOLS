% test_io.pl - Test TODO 17 : predicats d entrees/sorties
% Teste les predicats I/O de PROLOG86

% --- write/1 avec atomes ---
greet :- write(hello).

% --- writeln/1 avec atomes ---
greet_ln :- writeln(world).

% --- nl/0 ---
newline :- nl.

% --- print/1 ---
show(X) :- print(X).

% --- write_canonical/1 ---
canon(X) :- write_canonical(X).

% --- write/1 avec entiers ---
show_num :- write(42).

% --- tab/1 ---
indent :- tab(4), write(ok).

% --- put_char/1 ---
put_a :- put_char(a).

% --- char_code/2 ---
code_of_a(C) :- char_code(a, C).

% --- atom_length/2 ---
len_hello(N) :- atom_length(hello, N).

% --- atom_chars/2 ---
chars_of(A, Cs) :- atom_chars(A, Cs).

% --- atom_codes/2 ---
codes_of(A, Cs) :- atom_codes(A, Cs).

% --- number_chars/2 ---
num_chars(N, Cs) :- number_chars(N, Cs).

% --- number_codes/2 ---
num_codes(N, Cs) :- number_codes(N, Cs).

% --- Requetes ---
?- greet.
?- greet_ln.
?- newline.
?- show_num.
?- indent.
?- put_a.
?- code_of_a(X).
?- len_hello(N).
