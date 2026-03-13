/* test_procs.rexx - Test des procedures et fonctions internes (TODO 17) */

/* Test 1 : CALL simple sans argument, label sans PROCEDURE */
call greeting
say result

/* Test 2 : CALL avec PROCEDURE et RETURN valeur */
call double
say result

/* Test 3 : Fonction utilisateur dans une expression */
x = triple("3")
say x

/* Test 4 : PROCEDURE avec EXPOSE */
count = "0"
call increment
say count

/* Test 5 : SIGNAL (saut inconditionnel) */
signal skip_this
say "NEVER"
skip_this:
say "JUMPED"

exit

/* --- Procedures internes --- */

greeting:
  return "Hello from procedure"

double:
  procedure
  return "14"

triple:
  procedure
  parse arg n
  return n * 3

increment:
  procedure expose count
  count = count + 1
  return
