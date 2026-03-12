% test_strings.pl - Test des chaines et caracteres (TODO 23)
% Teste char_type/2, upcase_atom/2, downcase_atom/2, atom_string/2,
% number_string/2, string_concat/3, string_length/2

% --- upcase_atom/2 ---
test_upcase(X) :- upcase_atom(hello, X).
test_upcase2(X) :- upcase_atom(abc, X).

% --- downcase_atom/2 ---
test_downcase(X) :- downcase_atom('WORLD', X).

% --- atom_string/2 ---
test_atom_string(X) :- atom_string(hello, X).

% --- number_string/2 ---
test_number_string(X) :- number_string(42, X).

% --- string_concat/3 ---
test_string_concat(X) :- string_concat(hel, lo, X).

% --- string_length/2 ---
test_string_length(X) :- string_length(hello, X).

% --- char_type/2 ---
test_char_type_alpha :- char_type(a, alpha).
test_char_type_digit :- char_type(1, digit).
test_char_type_upper :- char_type('A', upper).
test_char_type_lower :- char_type(a, lower).

% --- Predicat principal de test ---
main :- write(test_strings_ok), nl.
:- main.
