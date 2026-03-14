/* test_if.rexx - Test IF/THEN/ELSE et SELECT/WHEN/OTHERWISE */
/* TODO 13 : controle de flux conditionnel                     */

/* IF simple avec condition vraie */
x = 1
if x = 1 then say "x vaut 1"

/* IF avec condition fausse */
if x = 2 then say "x vaut 2"

/* IF / ELSE */
y = 5
if y > 3 then say "y est grand"
else say "y est petit"

/* IF avec bloc DO/END */
z = 10
if z = 10 then do
  say "z vaut 10"
  say "dans le bloc DO"
end

/* IF / ELSE avec blocs DO/END */
a = 0
if a = 1 then do
  say "a vaut 1"
end
else do
  say "a ne vaut pas 1"
  say "branche else"
end

/* SELECT / WHEN / OTHERWISE */
code = 2
select
  when code = 1 then say "code un"
  when code = 2 then say "code deux"
  when code = 3 then say "code trois"
  otherwise say "code inconnu"
end

/* NOP dans IF */
b = 0
if b = 0 then nop
else say "b non nul"

/* Expression booleenne */
say 3 > 2
say 1 = 1
