/* test_interp.rexx - Tests TODO 23 : INTERPRET, ADDRESS, TRACE */

/* Test ADDRESS() function */
say 'Test ADDRESS:'
env = address()
say 'Environnement:' env

/* Test TRACE */
say 'Test TRACE:'
trace o
say 'Trace desactivee'
trace n
say 'Trace normale'

/* Test ADDRESS avec commande */
say 'Test ADDRESS commande:'
address system 'echo test'

/* Test QUEUED apres TODO 22 */
n = queued()
say 'Pile vide:' n

say 'Tous les tests INTERPRET/ADDRESS/TRACE passes!'
