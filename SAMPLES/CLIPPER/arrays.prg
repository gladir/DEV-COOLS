* arrays.prg - Exemple Clipper : tableaux, AADD, ASORT, ASCAN, AEVAL
* Compilation : CLIPPER86 arrays.prg

* --- Creation de tableau litteral ---
LOCAL aFruits
aFruits := {"Pomme", "Banane", "Cerise"}
? "Fruits[1] :", aFruits[1]
? "Fruits[2] :", aFruits[2]
? "Fruits[3] :", aFruits[3]
? "LEN       :", LEN(aFruits)

* --- AADD : ajout dynamique ---
AADD(aFruits, "Date")
AADD(aFruits, "Figue")
? "Apres AADD, LEN =", LEN(aFruits)

* --- Modification d element ---
aFruits[2] := "Mangue"
? "Fruits[2] apres modif :", aFruits[2]

* --- ASCAN : recherche ---
LOCAL nPos
nPos := ASCAN(aFruits, "Cerise")
? "ASCAN Cerise :", nPos

* --- ASORT : tri ---
LOCAL aNum
aNum := {50, 10, 40, 20, 30}
? "Avant ASORT :"
?? aNum[1]
?? ","
?? aNum[2]
?? ","
?? aNum[3]
?? ","
?? aNum[4]
?? ","
?? aNum[5]
ASORT(aNum)
?
? "Apres ASORT :"
?? aNum[1]
?? ","
?? aNum[2]
?? ","
?? aNum[3]
?? ","
?? aNum[4]
?? ","
?? aNum[5]
?

* --- AFILL : remplissage ---
LOCAL aZero
aZero := {0, 0, 0, 0, 0}
AFILL(aZero, 99)
? "AFILL(99) :", aZero[1], aZero[3], aZero[5]

* --- ACLONE : copie ---
LOCAL aCopy
aCopy := ACLONE(aNum)
? "ACLONE[1] :", aCopy[1]

* --- AEVAL : parcours avec code block ---
LOCAL aVals, nTotal
aVals  := {1, 2, 3, 4, 5}
nTotal := 0
AEVAL(aVals, {|e| nTotal := nTotal + e})
? "AEVAL sum 1..5 =", nTotal

* --- FOR EACH : parcours iteratif ---
LOCAL elem
? "FOR EACH :"
FOR EACH elem IN aVals
  ?? " "
  ?? elem
NEXT
?

* --- Tableau bidimensionnel (tableau de tableaux) ---
LOCAL aMatrix
aMatrix := {{1, 2}, {3, 4}, {5, 6}}
? "Matrix[2][1] :", aMatrix[2]

? "Fin de arrays.prg"
