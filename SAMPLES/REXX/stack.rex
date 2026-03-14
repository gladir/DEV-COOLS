/* stack.rex - Exemple REXX : PUSH, QUEUE, PULL, QUEUED */

/* QUEUE (FIFO) - les elements sortent dans l'ordre d'entree */
say '=== QUEUE (FIFO) ==='
queue 'premier'
queue 'deuxieme'
queue 'troisieme'
say 'Elements dans la pile :' queued()

pull ligne
say 'Pull 1 :' ligne
pull ligne
say 'Pull 2 :' ligne
pull ligne
say 'Pull 3 :' ligne
say 'Pile apres pulls :' queued()

/* PUSH (LIFO) - les elements sortent dans l'ordre inverse */
say
say '=== PUSH (LIFO) ==='
push 'A'
push 'B'
push 'C'
say 'Elements :' queued()

pull val
say 'Pull (dernier PUSH) :' val
pull val
say 'Pull :' val
pull val
say 'Pull :' val

/* Melange QUEUE et PUSH */
say
say '=== Melange QUEUE et PUSH ==='
queue 'file1'
queue 'file2'
push 'pile1'
say 'Elements :' queued()

pull v1
say 'Pull 1 :' v1
pull v2
say 'Pull 2 :' v2
pull v3
say 'Pull 3 :' v3

/* Pile vide */
say
say '=== Pile vide ==='
say 'Pile vide :' queued()

say
say 'Fin du programme stack.rex'
