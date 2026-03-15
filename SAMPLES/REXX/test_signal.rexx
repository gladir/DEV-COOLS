/* test_signal.rexx - Test TODO 21 SIGNAL ET TRAITEMENT DE CONDITIONS */

/* Test 1 : SIGNAL ON HALT NAME handler */
signal on halt name halt_handler
SAY "SIGNAL ON HALT active"

/* Test 2 : SIGNAL OFF HALT */
signal off halt
SAY "SIGNAL OFF HALT fait"

/* Test 3 : SIGNAL ON NOVALUE NAME novalue_handler */
signal on novalue name novalue_handler
SAY "SIGNAL ON NOVALUE active"

/* Test 4 : SIGNAL OFF NOVALUE */
signal off novalue
SAY "SIGNAL OFF NOVALUE fait"

/* Test 5 : SIGNAL ON ERROR NAME error_handler */
signal on error name error_handler
SAY "SIGNAL ON ERROR active"
signal off error
SAY "SIGNAL OFF ERROR fait"

/* Test 6 : SIGNAL ON SYNTAX NAME syntax_handler */
signal on syntax name syntax_handler
SAY "SIGNAL ON SYNTAX active"
signal off syntax
SAY "SIGNAL OFF SYNTAX fait"

/* Test 7 : SIGNAL label (saut inconditionnel) */
signal jump_here
SAY "NEVER"
jump_here:
SAY "JUMPED OK"

/* Test 8 : SIGNAL VALUE label */
signal value jump_there
SAY "NEVER2"
jump_there:
SAY "VALUE JUMPED OK"

SAY "Test SIGNAL termine."
exit

/* --- Handlers de conditions --- */

halt_handler:
  SAY "HALT caught"
  return

novalue_handler:
  SAY "NOVALUE caught"
  return

error_handler:
  SAY "ERROR caught"
  return

syntax_handler:
  SAY "SYNTAX caught"
  return
