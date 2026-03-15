# test_rules.awk - Tests pour TODO 14 (regles pattern-action)
# 15 cas de test

# Cas 1 : BEGIN simple
BEGIN {
  print "cas1: programme demarre"
}

# Cas 2 : BEGIN avec initialisation de variable
BEGIN {
  total = 0
  print "cas2: total initialise a " total
}

# Cas 3 : END simple
END {
  print "cas3: programme termine"
}

# Cas 4 : END avec resume
END {
  print "cas4: total final = " total
}

# Cas 5 : bloc sans pattern (toutes les lignes)
{
  print "cas5: ligne lue"
}

# Cas 6 : pattern regex
/error/ {
  print "cas6: erreur trouvee"
}

# Cas 7 : pattern regex avec impression
/warning/ {
  print "cas7: avertissement"
}

# Cas 8 : expression conditionnelle (NR > 0)
NR > 0 {
  print "cas8: NR positif"
}

# Cas 9 : BEGIN avec boucle
BEGIN {
  s = 0
  for (i = 1; i <= 5; i = i + 1)
    s = s + i
  print "cas9: somme 1..5 = " s
}

# Cas 10 : BEGIN avec if/else
BEGIN {
  x = 42
  if (x > 10)
    print "cas10: x est grand"
  else
    print "cas10: x est petit"
}

# Cas 11 : fonction definie avant BEGIN
function doubler(n) {
  return n * 2
}
BEGIN {
  print "cas11: doubler(7) = " doubler(7)
}

# Cas 12 : multiple BEGIN
BEGIN {
  print "cas12: premier BEGIN"
}
BEGIN {
  print "cas12: deuxieme BEGIN"
}

# Cas 13 : pattern regex avec variable
/hello/ {
  count = count + 1
  print "cas13: hello #" count
}

# Cas 14 : range pattern /debut/,/fin/
/start/,/stop/ {
  print "cas14: dans la plage"
}

# Cas 15 : bloc action avec while
BEGIN {
  n = 1
  while (n <= 3) {
    print "cas15: iteration " n
    n = n + 1
  }
}
