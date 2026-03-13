/* signal.rex - Exemple REXX : SIGNAL ON NOVALUE, SIGNAL label, conditions */

/* SIGNAL ON - activation du traitement de condition */
say '=== SIGNAL ON ==='
signal on halt name on_halt
say 'SIGNAL ON HALT active'
signal off halt
say 'SIGNAL OFF HALT fait'

signal on novalue name on_novalue
say 'SIGNAL ON NOVALUE active'
signal off novalue
say 'SIGNAL OFF NOVALUE fait'

signal on error name on_error
say 'SIGNAL ON ERROR active'
signal off error
say 'SIGNAL OFF ERROR fait'

signal on syntax name on_syntax
say 'SIGNAL ON SYNTAX active'
signal off syntax
say 'SIGNAL OFF SYNTAX fait'

/* SIGNAL label - saut inconditionnel */
say
say '=== SIGNAL label ==='
signal suite
say 'Ceci est saute'
suite:
say 'Saut effectue avec succes'

/* SIGNAL VALUE - saut dynamique */
say
say '=== SIGNAL VALUE ==='
signal value fin_test
say 'Ceci est saute aussi'
fin_test:
say 'SIGNAL VALUE effectue'

say
say 'Fin du programme signal.rex'
exit

/* --- Handlers de conditions --- */

on_halt:
  say 'Condition HALT interceptee'
  return

on_novalue:
  say 'Condition NOVALUE interceptee'
  return

on_error:
  say 'Condition ERROR interceptee'
  return

on_syntax:
  say 'Condition SYNTAX interceptee'
  return
