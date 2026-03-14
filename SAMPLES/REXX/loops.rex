/* loops.rex - Exemple REXX : DO compteur, DO FOREVER, LEAVE, ITERATE */

/* DO compteur simple : TO */
say '=== DO compteur TO ==='
do i = 1 to 5
  say 'i =' i
end

/* DO compteur avec BY (pas) */
say
say '=== DO compteur BY ==='
do j = 0 to 20 by 5
  say 'j =' j
end

/* DO expr : repeter N fois */
say
say '=== DO N fois ==='
do 3
  say 'Repetition'
end

/* DO FOREVER avec LEAVE */
say
say '=== DO FOREVER + LEAVE ==='
k = 10
do forever
  say 'k =' k
  k = k - 3
  if k < 3 then leave
end
say 'Boucle terminee, k =' k

/* DO WHILE avec ITERATE */
say
say '=== DO WHILE + ITERATE ==='
m = 0
do while m < 8
  m = m + 1
  if m = 3 then iterate
  if m = 6 then iterate
  say 'm =' m
end

/* DO simple (bloc) */
say
say '=== DO bloc simple ==='
do
  say 'Ligne 1 du bloc'
  say 'Ligne 2 du bloc'
end

/* Boucles imbriquees */
say
say '=== Boucles imbriquees ==='
do a = 1 to 3
  do b = 1 to 3
    say a '*' b '=' a * b
  end
end

say
say 'Fin du programme loops.rex'
