* test_dbf.prg - Test des operations sur fichiers DBF (TODO 19)
* Compilateur Clipper86 - generation assembleur 8086

* --- USE : ouvrir un fichier DBF ---
USE clients ALIAS CLI

* --- SELECT : changer de zone de travail ---
SELECT 2
USE produits ALIAS PRD SHARED
SELECT 1

* --- Navigation ---
GO TOP
GO BOTTOM
GO 5
SKIP
SKIP 3
SKIP -1

* --- Fonctions de position ---
LOCAL nRec, nCnt, lEof, lBof, lDel, nFld
nRec := RECNO()
nCnt := RECCOUNT()
lEof := EOF()
lBof := BOF()
lDel := DELETED()
nFld := FCOUNT()

* --- Modification ---
APPEND BLANK
REPLACE nom WITH "Dupont", prenom WITH "Jean"
DELETE
RECALL

* --- SELECT par lettre ---
SELECT A
SELECT B

* --- Fonctions supplementaires ---
? RECNO()
? RECCOUNT()
? EOF()
? BOF()
? USED()
? ALIAS()

* --- Fermeture ---
CLOSE
SELECT 2
CLOSE ALL

* --- PACK et ZAP ---
USE test
PACK
ZAP
CLOSE

* --- LASTREC (synonyme de RECCOUNT) ---
USE fichier
? LASTREC()
CLOSE

* --- USE sans argument (fermer) ---
USE clients
USE

RETURN
