# test_forin.awk - Tests pour TODO 12 (for-in iteration sur tableaux associatifs)
# 15 cas de test

# Cas 1 : for-in simple sur un tableau
BEGIN {
  a["x"] = 1
  a["y"] = 2
  a["z"] = 3
  cnt = 0
  for (k in a)
    cnt = cnt + 1
  print "cas1: cnt=" cnt
}

# Cas 2 : for-in avec bloc
BEGIN {
  b["pomme"] = 10
  b["banane"] = 20
  b["cerise"] = 30
  s = 0
  for (k in b) {
    s = s + b[k]
  }
  print "cas2: s=" s
}

# Cas 3 : for-in sur tableau vide
BEGIN {
  cnt = 0
  for (k in empty)
    cnt = cnt + 1
  print "cas3: cnt=" cnt
}

# Cas 4 : for-in avec un seul element
BEGIN {
  c["seul"] = 42
  v = ""
  for (k in c)
    v = k
  print "cas4: v=" v
}

# Cas 5 : for-in avec print de cle et valeur
BEGIN {
  d["a"] = 1
  d["b"] = 2
  cnt = 0
  for (k in d) {
    cnt = cnt + 1
  }
  print "cas5: cnt=" cnt
}

# Cas 6 : for-in avec break
BEGIN {
  e["x"] = 1
  e["y"] = 2
  e["z"] = 3
  cnt = 0
  for (k in e) {
    cnt = cnt + 1
    if (cnt >= 2)
      break
  }
  print "cas6: cnt=" cnt
}

# Cas 7 : for-in avec continue
BEGIN {
  f["a"] = 1
  f["b"] = 2
  f["c"] = 3
  f["d"] = 4
  cnt = 0
  for (k in f) {
    if (f[k] % 2 == 0)
      continue
    cnt = cnt + 1
  }
  print "cas7: cnt=" cnt
}

# Cas 8 : for-in imbrique dans un for classique
BEGIN {
  g["x"] = 10
  g["y"] = 20
  total = 0
  for (i = 0; i < 3; i = i + 1) {
    for (k in g)
      total = total + g[k]
  }
  print "cas8: total=" total
}

# Cas 9 : for classique imbrique dans for-in
BEGIN {
  h["a"] = 3
  h["b"] = 5
  total = 0
  for (k in h) {
    for (j = 0; j < h[k]; j = j + 1)
      total = total + 1
  }
  print "cas9: total=" total
}

# Cas 10 : for-in imbrique dans for-in
BEGIN {
  p["x"] = 1
  p["y"] = 2
  q["a"] = 10
  q["b"] = 20
  cnt = 0
  for (k1 in p) {
    for (k2 in q) {
      cnt = cnt + 1
    }
  }
  print "cas10: cnt=" cnt
}

# Cas 11 : delete dans for-in (marquer pour suppression)
BEGIN {
  r["x"] = 1
  r["y"] = 2
  r["z"] = 3
  cnt = 0
  for (k in r)
    cnt = cnt + 1
  print "cas11: cnt=" cnt
}

# Cas 12 : for-in avec if/else
BEGIN {
  t["a"] = 1
  t["b"] = -2
  t["c"] = 3
  t["d"] = -4
  pos = 0
  neg = 0
  for (k in t) {
    if (t[k] > 0)
      pos = pos + 1
    else
      neg = neg + 1
  }
  print "cas12: pos=" pos " neg=" neg
}

# Cas 13 : for-in apres while
BEGIN {
  u["m"] = 1
  u["n"] = 2
  i = 0
  while (i < 3)
    i = i + 1
  cnt = 0
  for (k in u)
    cnt = cnt + 1
  print "cas13: i=" i " cnt=" cnt
}

# Cas 14 : for-in avec tableau cree dynamiquement
BEGIN {
  for (i = 0; i < 5; i = i + 1)
    dyn[i] = i * 10
  cnt = 0
  for (k in dyn)
    cnt = cnt + 1
  print "cas14: cnt=" cnt
}

# Cas 15 : for-in combinant multiple tableaux
BEGIN {
  v1["a"] = 1
  v1["b"] = 2
  v2["x"] = 10
  v2["y"] = 20
  v2["z"] = 30
  c1 = 0
  c2 = 0
  for (k in v1)
    c1 = c1 + 1
  for (k in v2)
    c2 = c2 + 1
  print "cas15: c1=" c1 " c2=" c2
}
