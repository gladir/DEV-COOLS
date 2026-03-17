# test_arrays16.awk - Tests pour TODO 16 (tableaux associatifs et operateur in/delete)
# 15 cas de test

# Cas 1 : affectation simple array[key] = val
BEGIN {
  a["x"] = 10
  print "cas1: a[x]=" a["x"]
}

# Cas 2 : lecture d un tableau
BEGIN {
  b["hello"] = 42
  v = b["hello"]
  print "cas2: v=" v
}

# Cas 3 : plusieurs entrees
BEGIN {
  c["a"] = 1
  c["b"] = 2
  c["c"] = 3
  print "cas3: c[a]=" c["a"] " c[b]=" c["b"] " c[c]=" c["c"]
}

# Cas 4 : operateur in (existe)
BEGIN {
  d["pomme"] = 5
  if ("pomme" in d)
    print "cas4: pomme existe"
}

# Cas 5 : operateur in (n existe pas)
BEGIN {
  e["a"] = 1
  if ("b" in e)
    print "cas5: ERREUR"
  else
    print "cas5: b n existe pas"
}

# Cas 6 : delete array[key]
BEGIN {
  f["x"] = 10
  f["y"] = 20
  delete f["x"]
  if ("x" in f)
    print "cas6: ERREUR"
  else
    print "cas6: x supprime"
}

# Cas 7 : delete array (vider tout)
BEGIN {
  g["a"] = 1
  g["b"] = 2
  g["c"] = 3
  delete g
  cnt = 0
  for (k in g)
    cnt = cnt + 1
  print "cas7: cnt=" cnt
}

# Cas 8 : indice numerique comme cle
BEGIN {
  h[1] = "un"
  h[2] = "deux"
  h[3] = "trois"
  print "cas8: h[2]=" h[2]
}

# Cas 9 : indices multidimensionnels avec SUBSEP
BEGIN {
  m[1,1] = 11
  m[1,2] = 12
  m[2,1] = 21
  print "cas9: m[1,2]=" m[1,2]
}

# Cas 10 : for-in avec operations sur tableau
BEGIN {
  t["x"] = 10
  t["y"] = 20
  t["z"] = 30
  s = 0
  for (k in t)
    s = s + t[k]
  print "cas10: s=" s
}

# Cas 11 : affectation chainee
BEGIN {
  p["a"] = 100
  p["b"] = p["a"] + 50
  print "cas11: p[b]=" p["b"]
}

# Cas 12 : tableau avec valeurs chaine
BEGIN {
  n["prenom"] = "Jean"
  n["nom"] = "Dupont"
  print "cas12: " n["prenom"] " " n["nom"]
}

# Cas 13 : operateur in dans une condition composee
BEGIN {
  q["a"] = 1
  q["b"] = 2
  if (("a" in q) && ("b" in q))
    print "cas13: a et b existent"
}

# Cas 14 : delete puis re-insertion
BEGIN {
  r["x"] = 1
  delete r["x"]
  r["x"] = 99
  print "cas14: r[x]=" r["x"]
}

# Cas 15 : tableau comme compteur
BEGIN {
  w = "hello world hello awk hello"
  # Simuler un split et comptage
  cnt["hello"] = 3
  cnt["world"] = 1
  cnt["awk"] = 1
  total = 0
  for (k in cnt)
    total = total + cnt[k]
  print "cas15: total=" total
}
