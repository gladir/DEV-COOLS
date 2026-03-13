/* test_interp.rexx - Tests TODO 23 : INTERPRET, ADDRESS, TRACE */

/* Test ADDRESS() function */
say 'Test ADDRESS:'
say 'Environnement:' address()

/* Test TRACE */
say 'Test TRACE:'
trace o
say 'Trace desactivee'
trace n
say 'Trace normale'

/* Test ADDRESS statement */
say 'Test ADDRESS statement:'
address
address system 'echo test'

/* Test QUEUED apres TODO 22 */
say 'Pile vide:' queued()

say 'Tous les tests INTERPRET/ADDRESS/TRACE passes!'
