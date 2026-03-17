# test_fields.awk - Tests pour TODO 15 (champs et separateurs)
# 15 cas de test

# Cas 1 : $0 reference (ligne complete)
BEGIN {
  print "cas1: $0 teste"
}

# Cas 2 : $1 reference (premier champ)
{
  print "cas2: premier champ = " $1
}

# Cas 3 : $2 reference (deuxieme champ)
{
  print "cas3: deuxieme champ = " $2
}

# Cas 4 : $NF reference (dernier champ)
{
  print "cas4: dernier champ = " $NF
}

# Cas 5 : champ statique $3
{
  print "cas5: troisieme champ = " $3
}

# Cas 6 : affectation a FS dans BEGIN
BEGIN {
  FS = ":"
  print "cas6: FS = " FS
}

# Cas 7 : OFS en sortie
BEGIN {
  OFS = " | "
  print "cas7: OFS = " OFS
}

# Cas 8 : ORS en sortie
BEGIN {
  ORS = "\n"
  print "cas8: ORS teste"
}

# Cas 9 : RS separateur d enregistrements
BEGIN {
  RS = "\n"
  print "cas9: RS teste"
}

# Cas 10 : affectation a un champ $1 = expr
{
  $1 = "modifie"
  print "cas10: $1 modifie = " $1
}

# Cas 11 : champ dynamique $(expr)
{
  n = 2
  print "cas11: champ dynamique $(" n ") = " $(n)
}

# Cas 12 : NF builtin variable
{
  print "cas12: NF = " NF
}

# Cas 13 : NR builtin variable
{
  print "cas13: NR = " NR
}

# Cas 14 : multiple champs dans un print
{
  print "cas14: " $1 " " $2 " " $3
}

# Cas 15 : boucle sur les champs avec for
{
  for (i = 1; i <= NF; i = i + 1)
    print "cas15: champ " i " = " $(i)
}
