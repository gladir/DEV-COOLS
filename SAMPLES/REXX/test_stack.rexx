/* test_stack.rexx - Tests TODO 22 : PILE DE DONNEES (QUEUE/PUSH/PULL) */

/* Test QUEUE et QUEUED */
say 'Test QUEUE/QUEUED:'
queue 'premier'
queue 'deuxieme'
queue 'troisieme'
say 'Nombre elements:' queued()

/* Test PULL FIFO (QUEUE ajoute en fin) */
say 'Test PULL (FIFO):'
pull ligne
say 'Pull 1:' ligne
pull ligne
say 'Pull 2:' ligne
pull ligne
say 'Pull 3:' ligne
say 'Apres pulls:' queued()

/* Test PUSH (LIFO) et PULL */
say 'Test PUSH/PULL (LIFO):'
push 'A'
push 'B'
push 'C'
say 'Nombre:' queued()
pull val
say 'Pull (dernier push):' val
pull val
say 'Pull:' val
pull val
say 'Pull:' val

/* Test pile vide */
say 'Pile vide:' queued()

say 'Tous les tests de pile passes!'
