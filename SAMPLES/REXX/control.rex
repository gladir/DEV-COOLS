/* control.rex - Exemple REXX : IF/THEN/ELSE, SELECT/WHEN, DO WHILE/UNTIL */

/* IF / THEN simple */
say '=== IF / THEN ==='
x = 10
if x > 5 then say 'x est superieur a 5'
if x = 10 then say 'x vaut exactement 10'
if x < 0 then say 'ceci ne sera pas affiche'

/* IF / THEN / ELSE */
say
say '=== IF / THEN / ELSE ==='
note = 75
if note >= 60 then say 'Reussite (note:' note || ')'
else say 'Echec (note:' note || ')'

note = 45
if note >= 60 then say 'Reussite'
else say 'Echec (note:' note || ')'

/* IF avec bloc DO/END */
say
say '=== IF avec bloc DO/END ==='
age = 18
if age >= 18 then do
  say 'Vous etes majeur.'
  say 'Acces autorise.'
end
else do
  say 'Vous etes mineur.'
  say 'Acces refuse.'
end

/* SELECT / WHEN / OTHERWISE */
say
say '=== SELECT / WHEN / OTHERWISE ==='
jour = 3
select
  when jour = 1 then say 'Lundi'
  when jour = 2 then say 'Mardi'
  when jour = 3 then say 'Mercredi'
  when jour = 4 then say 'Jeudi'
  when jour = 5 then say 'Vendredi'
  when jour = 6 then say 'Samedi'
  when jour = 7 then say 'Dimanche'
  otherwise say 'Jour invalide'
end

/* DO WHILE */
say
say '=== DO WHILE ==='
compteur = 1
do while compteur <= 5
  say 'Compteur :' compteur
  compteur = compteur + 1
end

/* DO UNTIL */
say
say '=== DO UNTIL ==='
n = 1
do until n > 4
  say 'N =' n
  n = n + 1
end

/* NOP */
val = 0
if val = 0 then nop
else say 'Non nul'
say 'NOP fonctionne correctement.'

say
say 'Fin du programme control.rex'
