/* test_loops.rexx - Test boucles DO / END                         */
/* TODO 14 : DO WHILE, DO UNTIL, DO FOREVER, DO compteur, LEAVE,   */
/*           ITERATE, DO expr                                       */

/* DO WHILE - boucle avec condition testee avant */
i = 0
do while i < 3
  say i
  i = i + 1
end

/* DO FOREVER avec LEAVE */
j = 10
do forever
  say j
  j = j - 1
  if j < 8 then leave
end

/* DO compteur simple : DO var = debut TO fin */
do k = 1 to 5
  say k
end

/* DO compteur avec BY */
do m = 0 to 10 by 3
  say m
end

/* DO expr : repeter N fois */
do 3
  say "boucle"
end

/* DO bloc simple */
do
  say "bloc"
  say "simple"
end

/* DO WHILE avec ITERATE */
n = 0
do while n < 5
  n = n + 1
  if n = 3 then iterate
  say n
end

/* DO UNTIL - repeter jusqu a ce que la condition soit vraie */
p = 1
do until p > 4
  say p
  p = p + 1
end
